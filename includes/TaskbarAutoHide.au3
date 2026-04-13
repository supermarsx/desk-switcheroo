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

; #FUNCTIONS# ===================================================

; Name:        _TAH_Start
; Description: Starts the taskbar auto-hide monitor via AdlibRegister
Func _TAH_Start()
    If Not _Cfg_GetAutoHideSyncEnabled() Then Return
    $__g_TAH_bStopping = False
    $__g_TAH_iPollCount = 0
    $__g_TAH_bHideTimerActive = False
    $__g_TAH_bShowTimerActive = False
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

; Name:        _TAH_HideWidget
; Description: Hides the widget (with optional fade animation)
; Parameters:  $hGUI - handle to the main widget window
Func _TAH_HideWidget($hGUI)
    If $__g_TAH_bWidgetHiddenByTAH Then Return ; already hidden

    If _Cfg_GetAutoHideUseFade() And _Cfg_GetAnimationsEnabled() Then
        ; Fade out: animate alpha from current to 0
        Local $iAlpha = _Cfg_GetThemeAlphaMain()
        Local $iDuration = _Cfg_GetAutoHideFadeDuration()
        Local $iSteps = Int($iDuration / 8)
        If $iSteps < 2 Then $iSteps = 2
        Local $iStepSize = Int($iAlpha / $iSteps)
        If $iStepSize < 1 Then $iStepSize = 1

        Local $iCurrent = $iAlpha
        For $i = 1 To $iSteps
            If Not IsHWnd($hGUI) Or Not WinExists($hGUI) Then ExitLoop
            $iCurrent -= $iStepSize
            If $iCurrent < 0 Then $iCurrent = 0
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iCurrent, $LWA_ALPHA)
            Sleep(8)
        Next
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
    EndIf

    GUISetState(@SW_HIDE, $hGUI)
    $__g_TAH_bWidgetHiddenByTAH = True
    _Log_Debug("Widget hidden by taskbar auto-hide sync")
EndFunc

; Name:        _TAH_ShowWidget
; Description: Shows the widget (with optional fade animation)
; Parameters:  $hGUI - handle to the main widget window
;              $iTargetAlpha - target alpha value to restore
Func _TAH_ShowWidget($hGUI, $iTargetAlpha)
    If Not $__g_TAH_bWidgetHiddenByTAH Then Return ; not hidden by us

    If _Cfg_GetAutoHideUseFade() And _Cfg_GetAnimationsEnabled() Then
        ; Start fully transparent, then show and fade in
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
        GUISetState(@SW_SHOWNOACTIVATE, $hGUI)

        Local $iDuration = _Cfg_GetAutoHideFadeDuration()
        Local $iSteps = Int($iDuration / 8)
        If $iSteps < 2 Then $iSteps = 2
        Local $iStepSize = Int($iTargetAlpha / $iSteps)
        If $iStepSize < 1 Then $iStepSize = 1

        Local $iCurrent = 0
        For $i = 1 To $iSteps
            If Not IsHWnd($hGUI) Or Not WinExists($hGUI) Then ExitLoop
            $iCurrent += $iStepSize
            If $iCurrent > $iTargetAlpha Then $iCurrent = $iTargetAlpha
            _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iCurrent, $LWA_ALPHA)
            Sleep(8)
        Next
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
    Else
        GUISetState(@SW_SHOWNOACTIVATE, $hGUI)
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
    EndIf

    $__g_TAH_bWidgetHiddenByTAH = False
    _Log_Debug("Widget shown by taskbar auto-hide sync")
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

; Name:        __TAH_CheckTaskbarVisibility
; Description: Checks whether the taskbar is currently visible or hidden off-screen
Func __TAH_CheckTaskbarVisibility()
    Local $hTB = WinGetHandle("[CLASS:Shell_TrayWnd]")
    If $hTB = 0 Then Return ; taskbar not found (may be restarting)

    Local $aTBPos = WinGetPos($hTB)
    If @error Then Return

    ; $aTBPos: [0]=X, [1]=Y, [2]=Width, [3]=Height
    Local $iTBX = $aTBPos[0]
    Local $iTBY = $aTBPos[1]
    Local $iTBW = $aTBPos[2]
    Local $iTBH = $aTBPos[3]
    Local $iThreshold = _Cfg_GetAutoHideHiddenThreshold()
    Local $iScrW = @DesktopWidth
    Local $iScrH = @DesktopHeight

    ; Determine taskbar edge and check if hidden
    ; The taskbar window always spans the full edge, so we check which edge
    ; it occupies based on its dimensions and position
    Local $bHidden = False

    If $iTBW >= $iTBH Then
        ; Horizontal taskbar (bottom or top)
        If $iTBY >= $iScrH / 2 Then
            ; Bottom edge: hidden when visible height is <= threshold
            $bHidden = ($iScrH - $iTBY) <= $iThreshold
        Else
            ; Top edge: hidden when visible height is <= threshold
            $bHidden = ($iTBY + $iTBH) <= $iThreshold
        EndIf
    Else
        ; Vertical taskbar (left or right) — Windows 10 only
        If $iTBX >= $iScrW / 2 Then
            ; Right edge: hidden when visible width is <= threshold
            $bHidden = ($iScrW - $iTBX) <= $iThreshold
        Else
            ; Left edge: hidden when visible width is <= threshold
            $bHidden = ($iTBX + $iTBW) <= $iThreshold
        EndIf
    EndIf

    $__g_TAH_bTaskbarHidden = $bHidden
EndFunc
