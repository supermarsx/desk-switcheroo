#include-once
#include "Config.au3"
#include "Logger.au3"
#include <WinAPISysWin.au3>
#include <WindowsConstants.au3>

; #INDEX# =======================================================
; Title .........: TaskbarAutoHide
; Description ....: Detects Windows taskbar auto-hide state and syncs widget
;                   visibility accordingly. When the taskbar slides off-screen
;                   the widget hides; when the taskbar reappears the widget shows.
;                   Runs in-process via AdlibRegister with configurable polling.
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_TAH_bAutoHideActive     = False  ; Windows auto-hide is enabled
Global $__g_TAH_bTaskbarHidden      = False  ; Taskbar is currently hidden (off-screen)
Global $__g_TAH_bHiddenPending      = False  ; One-shot flag: taskbar just hid
Global $__g_TAH_bShownPending       = False  ; One-shot flag: taskbar just showed
Global $__g_TAH_bWidgetHiddenByTAH  = False  ; Widget is currently hidden by this module
Global $__g_TAH_hHideTimer          = 0      ; Debounce timer for hide delay
Global $__g_TAH_hShowTimer          = 0      ; Debounce timer for show delay
Global $__g_TAH_iPollCount          = 0      ; Counter for periodic auto-hide mode recheck
Global $__g_TAH_bHideTimerActive    = False  ; Hide delay timer is running
Global $__g_TAH_bShowTimerActive    = False  ; Show delay timer is running
Global $__g_TAH_bStopping           = False  ; Guard flag to prevent timer callback during stop
Global $__g_TAH_iHysteresisCount    = 0      ; Consecutive polls disagreeing with committed state
Global $__g_TAH_bCursorOverWidget   = False  ; Fed by the main loop; never hide while True

; -- Non-blocking widget fade state machine (advanced by _TAH_FadeTick from the main loop) --
Global $__g_TAH_iFadeState          = 0      ; 0 = idle, 1 = fading out (hide), 2 = fading in (show)
Global $__g_TAH_hFadeGUI            = 0      ; Widget handle being faded
Global $__g_TAH_iFadeAlpha          = 0      ; Current alpha during fade
Global $__g_TAH_iFadeTarget         = 0      ; Target alpha (fade-in)
Global $__g_TAH_iFadeStepAlpha      = 1      ; Alpha delta per tick
Global $__g_TAH_hFadeStepTimer      = 0      ; Throttle timer between fade steps
Global $__g_TAH_hLastToggleTimer    = 0      ; Time since the last hide/show (anti-strobe)

; Require this many consecutive disagreeing polls before flipping the taskbar-hidden state.
; Kills the hide/show oscillation when clicking an auto-hiding taskbar.
Global Const $__TAH_HYSTERESIS_POLLS = 2
; Skip the fade ramp entirely when a hide/show follows the opposite within this window (ms).
Global Const $__TAH_ANTISTROBE_MS    = 400
; Per-fade-step throttle (ms). Matches the old literal Sleep(8) cadence.
Global Const $__TAH_FADE_STEP_MS     = 8

; #FUNCTIONS# ===================================================

; Name:        _TAH_Start
; Description: Starts the taskbar auto-hide monitor via AdlibRegister
Func _TAH_Start()
    If Not _Cfg_GetAutoHideSyncEnabled() Then Return
    $__g_TAH_bStopping = False
    $__g_TAH_iPollCount = 0
    $__g_TAH_bHideTimerActive = False
    $__g_TAH_bShowTimerActive = False
    $__g_TAH_iHysteresisCount = 0
    ; Initial check of auto-hide mode
    __TAH_CheckAutoHideMode()
    ; Initial check of taskbar visibility
    If $__g_TAH_bAutoHideActive Then __TAH_CheckTaskbarVisibility()
    AdlibRegister("__TAH_Poll", _Cfg_GetAutoHidePollInterval())
    _Log_Info("Taskbar auto-hide monitor started (interval: " & _Cfg_GetAutoHidePollInterval() & "ms)")
EndFunc

; Name:        _TAH_Stop
; Description: Stops the taskbar auto-hide monitor and resets state
Func _TAH_Stop()
    $__g_TAH_bStopping = True
    AdlibUnRegister("__TAH_Poll")
    $__g_TAH_bHideTimerActive = False
    $__g_TAH_bShowTimerActive = False
    $__g_TAH_bHiddenPending = False
    $__g_TAH_bShownPending = False
    $__g_TAH_iHysteresisCount = 0
    $__g_TAH_iFadeState = 0
    _Log_Info("Taskbar auto-hide monitor stopped")
EndFunc

; Name:        _TAH_Reset
; Description: Re-check taskbar auto-hide state (call after explorer recovery)
Func _TAH_Reset()
    If Not _Cfg_GetAutoHideSyncEnabled() Then Return
    $__g_TAH_iPollCount = 0
    $__g_TAH_bHideTimerActive = False
    $__g_TAH_bShowTimerActive = False
    __TAH_CheckAutoHideMode()
    If $__g_TAH_bAutoHideActive Then
        __TAH_CheckTaskbarVisibility()
    Else
        ; Auto-hide disabled after recovery — ensure widget is visible
        If $__g_TAH_bWidgetHiddenByTAH Then
            $__g_TAH_bShownPending = True
        EndIf
    EndIf
    _Log_Info("Taskbar auto-hide monitor reset")
EndFunc

; Name:        _TAH_CheckHidden
; Description: Call from main loop. Returns True once when taskbar just hid, then resets.
; Return:      True if hide event pending, False otherwise
Func _TAH_CheckHidden()
    If Not $__g_TAH_bHiddenPending Then Return False
    $__g_TAH_bHiddenPending = False
    Return True
EndFunc

; Name:        _TAH_CheckShown
; Description: Call from main loop. Returns True once when taskbar just showed, then resets.
; Return:      True if show event pending, False otherwise
Func _TAH_CheckShown()
    If Not $__g_TAH_bShownPending Then Return False
    $__g_TAH_bShownPending = False
    Return True
EndFunc

; Name:        _TAH_IsWidgetHidden
; Description: Returns whether the widget is currently hidden by auto-hide sync
; Return:      True/False
Func _TAH_IsWidgetHidden()
    Return $__g_TAH_bWidgetHiddenByTAH
EndFunc

; Name:        _TAH_IsAutoHideEnabled
; Description: Returns whether Windows taskbar auto-hide is currently active
; Return:      True/False
Func _TAH_IsAutoHideEnabled()
    Return $__g_TAH_bAutoHideActive
EndFunc

; Name:        _TAH_SetCursorOverWidget
; Description: Fed each frame by the main loop. When True, the poll never arms a hide so the
;              widget stays put while the user is interacting with it.
Func _TAH_SetCursorOverWidget($bOver)
    $__g_TAH_bCursorOverWidget = $bOver
EndFunc

; Name:        _TAH_IsFading
; Description: Returns whether a non-blocking widget fade is currently in progress.
Func _TAH_IsFading()
    Return ($__g_TAH_iFadeState <> 0)
EndFunc

; Name:        __TAH_ShouldSkipFade
; Description: Snap instead of fade when a fade is already mid-flight, or the opposite toggle
;              happened within the anti-strobe window (kills hide/show strobing).
Func __TAH_ShouldSkipFade()
    If $__g_TAH_iFadeState <> 0 Then Return True
    If $__g_TAH_hLastToggleTimer <> 0 And TimerDiff($__g_TAH_hLastToggleTimer) < $__TAH_ANTISTROBE_MS Then Return True
    Return False
EndFunc

; Name:        __TAH_FadeStepSize
; Description: Alpha delta per tick for a fade covering $iRange over the configured duration.
Func __TAH_FadeStepSize($iRange)
    Local $iSteps = Int(_Cfg_GetAutoHideFadeDuration() / $__TAH_FADE_STEP_MS)
    If $iSteps < 2 Then $iSteps = 2
    Local $iStepSize = Int($iRange / $iSteps)
    If $iStepSize < 1 Then $iStepSize = 1
    Return $iStepSize
EndFunc

; Name:        _TAH_HideWidget
; Description: Hides the widget. With fade enabled, starts a NON-BLOCKING fade-out advanced by
;              _TAH_FadeTick from the main loop (the old version blocked the whole app for the
;              fade duration). The logical hidden state flips immediately.
; Parameters:  $hGUI - handle to the main widget window
Func _TAH_HideWidget($hGUI)
    If $__g_TAH_bWidgetHiddenByTAH Then Return ; already hidden

    $__g_TAH_bWidgetHiddenByTAH = True
    $__g_TAH_hLastToggleTimer = TimerInit()

    If _Cfg_GetAutoHideUseFade() And _Cfg_GetAnimationsEnabled() And Not __TAH_ShouldSkipFade() And IsHWnd($hGUI) Then
        ; Begin fade-out state machine; the window is hidden when alpha reaches 0.
        $__g_TAH_hFadeGUI = $hGUI
        $__g_TAH_iFadeAlpha = _Cfg_GetThemeAlphaMain()
        $__g_TAH_iFadeTarget = 0
        $__g_TAH_iFadeStepAlpha = __TAH_FadeStepSize($__g_TAH_iFadeAlpha)
        $__g_TAH_iFadeState = 1
        $__g_TAH_hFadeStepTimer = TimerInit()
    Else
        ; Instant hide (fade disabled or anti-strobe snap). Cancel any in-flight fade.
        $__g_TAH_iFadeState = 0
        If IsHWnd($hGUI) Then
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
            GUISetState(@SW_HIDE, $hGUI)
        EndIf
    EndIf
    _Log_Debug("Widget hidden by taskbar auto-hide sync")
EndFunc

; Name:        _TAH_ShowWidget
; Description: Shows the widget. With fade enabled, starts a NON-BLOCKING fade-in advanced by
;              _TAH_FadeTick from the main loop.
; Parameters:  $hGUI - handle to the main widget window
;              $iTargetAlpha - target alpha value to restore
Func _TAH_ShowWidget($hGUI, $iTargetAlpha)
    If Not $__g_TAH_bWidgetHiddenByTAH Then Return ; not hidden by us

    $__g_TAH_bWidgetHiddenByTAH = False
    $__g_TAH_hLastToggleTimer = TimerInit()

    If Not IsHWnd($hGUI) Then
        $__g_TAH_iFadeState = 0
        Return
    EndIf

    If _Cfg_GetAutoHideUseFade() And _Cfg_GetAnimationsEnabled() And Not __TAH_ShouldSkipFade() Then
        ; Start transparent, show, then fade in via the tick.
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
        GUISetState(@SW_SHOWNOACTIVATE, $hGUI)
        $__g_TAH_hFadeGUI = $hGUI
        $__g_TAH_iFadeAlpha = 0
        $__g_TAH_iFadeTarget = $iTargetAlpha
        $__g_TAH_iFadeStepAlpha = __TAH_FadeStepSize($iTargetAlpha)
        $__g_TAH_iFadeState = 2
        $__g_TAH_hFadeStepTimer = TimerInit()
    Else
        ; Instant show (fade disabled or anti-strobe snap). Cancel any in-flight fade.
        $__g_TAH_iFadeState = 0
        GUISetState(@SW_SHOWNOACTIVATE, $hGUI)
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
    EndIf
    _Log_Debug("Widget shown by taskbar auto-hide sync")
EndFunc

; Name:        _TAH_FadeTick
; Description: Advances the non-blocking widget fade one step. Call from the main loop.
;              No-op when idle. Replaces the old blocking Sleep(8) fade loops.
Func _TAH_FadeTick()
    If $__g_TAH_iFadeState = 0 Then Return
    Local $hGUI = $__g_TAH_hFadeGUI
    If Not IsHWnd($hGUI) Or Not WinExists($hGUI) Then
        $__g_TAH_iFadeState = 0
        Return
    EndIf
    If TimerDiff($__g_TAH_hFadeStepTimer) < $__TAH_FADE_STEP_MS Then Return
    $__g_TAH_hFadeStepTimer = TimerInit()

    If $__g_TAH_iFadeState = 1 Then
        ; Fade out
        $__g_TAH_iFadeAlpha -= $__g_TAH_iFadeStepAlpha
        If $__g_TAH_iFadeAlpha <= 0 Then
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
            GUISetState(@SW_HIDE, $hGUI)
            $__g_TAH_iFadeState = 0
        Else
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $__g_TAH_iFadeAlpha, $LWA_ALPHA)
        EndIf
    Else
        ; Fade in
        $__g_TAH_iFadeAlpha += $__g_TAH_iFadeStepAlpha
        If $__g_TAH_iFadeAlpha >= $__g_TAH_iFadeTarget Then
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $__g_TAH_iFadeTarget, $LWA_ALPHA)
            $__g_TAH_iFadeState = 0
        Else
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $__g_TAH_iFadeAlpha, $LWA_ALPHA)
        EndIf
    EndIf
EndFunc

; #INTERNAL FUNCTIONS# ==========================================

; Name:        __TAH_Poll
; Description: Periodic check for taskbar auto-hide state (called via AdlibRegister)
Func __TAH_Poll()
    If $__g_TAH_bStopping Then Return
    ; Periodically re-check if auto-hide mode is enabled/disabled in Windows
    $__g_TAH_iPollCount += 1
    If $__g_TAH_iPollCount >= _Cfg_GetAutoHideRecheckCount() Then
        $__g_TAH_iPollCount = 0
        Local $bWasActive = $__g_TAH_bAutoHideActive
        __TAH_CheckAutoHideMode()

        ; Auto-hide was just disabled — show widget if we hid it
        If $bWasActive And Not $__g_TAH_bAutoHideActive Then
            If $__g_TAH_bWidgetHiddenByTAH Then
                $__g_TAH_bShownPending = True
                $__g_TAH_bHideTimerActive = False
            EndIf
            Return
        EndIf
    EndIf

    ; Only check visibility when auto-hide is active
    If Not $__g_TAH_bAutoHideActive Then Return

    __TAH_CheckTaskbarVisibility()

    ; State transitions with debounce
    If $__g_TAH_bTaskbarHidden And Not $__g_TAH_bWidgetHiddenByTAH Then
        ; Never hide while the cursor is over the widget — keep it put during interaction
        If $__g_TAH_bCursorOverWidget Then
            $__g_TAH_bHideTimerActive = False
        Else
            ; Taskbar is hidden but widget is still visible — start hide timer
            If Not $__g_TAH_bHideTimerActive Then
                $__g_TAH_hHideTimer = TimerInit()
                $__g_TAH_bHideTimerActive = True
                $__g_TAH_bShowTimerActive = False ; cancel pending show
            EndIf
            ; Check if hide delay has elapsed
            If $__g_TAH_bHideTimerActive And TimerDiff($__g_TAH_hHideTimer) >= _Cfg_GetAutoHideHideDelay() Then
                $__g_TAH_bHiddenPending = True
                $__g_TAH_bHideTimerActive = False
            EndIf
        EndIf

    ElseIf Not $__g_TAH_bTaskbarHidden And $__g_TAH_bWidgetHiddenByTAH Then
        ; Taskbar is visible but widget is still hidden — start show timer
        If Not $__g_TAH_bShowTimerActive Then
            $__g_TAH_hShowTimer = TimerInit()
            $__g_TAH_bShowTimerActive = True
            $__g_TAH_bHideTimerActive = False ; cancel pending hide
        EndIf
        ; Check if show delay has elapsed
        If $__g_TAH_bShowTimerActive And TimerDiff($__g_TAH_hShowTimer) >= _Cfg_GetAutoHideShowDelay() Then
            $__g_TAH_bShownPending = True
            $__g_TAH_bShowTimerActive = False
        EndIf

    Else
        ; States are in sync — cancel any pending timers
        $__g_TAH_bHideTimerActive = False
        $__g_TAH_bShowTimerActive = False
    EndIf
EndFunc

; Name:        __TAH_CheckAutoHideMode
; Description: Uses SHAppBarMessage to check if Windows taskbar auto-hide is enabled
Func __TAH_CheckAutoHideMode()
    ; ABM_GETSTATE = 0x00000004, ABS_AUTOHIDE = 0x0001
    Local $tABD = DllStructCreate("dword cbSize;hwnd hWnd;uint uCallbackMessage;uint uEdge;" & _
        "long left;long top;long right;long bottom;lparam lParam")
    DllStructSetData($tABD, "cbSize", DllStructGetSize($tABD))
    Local $aRet = DllCall("shell32.dll", "uint_ptr", "SHAppBarMessage", "dword", 0x00000004, "struct*", $tABD)
    If @error Then
        _Log_Warn("SHAppBarMessage failed: " & @error)
        Return
    EndIf
    $__g_TAH_bAutoHideActive = (BitAND($aRet[0], 0x0001) <> 0)
EndFunc

; Name:        __TAH_RawTaskbarHidden
; Description: PURE geometry decision — is the taskbar off-screen given its rect, the screen
;              size, and the hidden threshold? No globals, no API calls (headless-testable).
; Return:      True if the taskbar's visible sliver is within the threshold, else False
Func __TAH_RawTaskbarHidden($iTBX, $iTBY, $iTBW, $iTBH, $iScrW, $iScrH, $iThreshold)
    ; The taskbar window always spans the full edge, so infer the edge from its geometry.
    If $iTBW >= $iTBH Then
        ; Horizontal taskbar (bottom or top)
        If $iTBY >= $iScrH / 2 Then
            Return ($iScrH - $iTBY) <= $iThreshold ; bottom edge
        Else
            Return ($iTBY + $iTBH) <= $iThreshold ; top edge
        EndIf
    Else
        ; Vertical taskbar (left or right) — Windows 10 only
        If $iTBX >= $iScrW / 2 Then
            Return ($iScrW - $iTBX) <= $iThreshold ; right edge
        Else
            Return ($iTBX + $iTBW) <= $iThreshold ; left edge
        EndIf
    EndIf
EndFunc

; Name:        __TAH_HysteresisNext
; Description: PURE hysteresis step. Given a raw reading, the currently committed state, and a
;              running consecutive-disagreement count (ByRef), returns the new committed state.
;              The state only flips after $iThreshold consecutive polls disagree with it, which
;              suppresses the hide/show oscillation seen when clicking an auto-hiding taskbar.
; Parameters:  $bRaw          - raw geometry reading this poll
;              $bCommitted    - the currently committed hidden state
;              $iConsecutive  - ByRef running count of disagreeing polls
;              $iThreshold    - polls required before committing a flip
; Return:      The new committed state
Func __TAH_HysteresisNext($bRaw, $bCommitted, ByRef $iConsecutive, $iThreshold)
    If $bRaw = $bCommitted Then
        $iConsecutive = 0
        Return $bCommitted
    EndIf
    $iConsecutive += 1
    If $iConsecutive >= $iThreshold Then
        $iConsecutive = 0
        Return $bRaw
    EndIf
    Return $bCommitted
EndFunc

; Name:        __TAH_CheckTaskbarVisibility
; Description: Reads the taskbar rect and updates the committed hidden state through hysteresis
Func __TAH_CheckTaskbarVisibility()
    Local $hTB = WinGetHandle("[CLASS:Shell_TrayWnd]")
    If $hTB = 0 Then Return ; taskbar not found (may be restarting)

    Local $aTBPos = WinGetPos($hTB)
    If @error Then Return

    ; $aTBPos: [0]=X, [1]=Y, [2]=Width, [3]=Height
    Local $bRaw = __TAH_RawTaskbarHidden($aTBPos[0], $aTBPos[1], $aTBPos[2], $aTBPos[3], _
        @DesktopWidth, @DesktopHeight, _Cfg_GetAutoHideHiddenThreshold())

    $__g_TAH_bTaskbarHidden = __TAH_HysteresisNext($bRaw, $__g_TAH_bTaskbarHidden, _
        $__g_TAH_iHysteresisCount, $__TAH_HYSTERESIS_POLLS)
EndFunc
