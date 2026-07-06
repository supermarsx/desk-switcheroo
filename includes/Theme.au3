#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPISysWin.au3>
#include <StaticConstants.au3>

; #INDEX# =======================================================
; Title .........: Theme
; Description ....: Dark theme constants and shared UI helpers
; Author .........: Mariana
; ===============================================================

; #CONSTANTS# ===================================================

; -- Background colors (non-const to allow theme switching at startup) --
Global $THEME_BG_MAIN       = 0x191919
Global $THEME_BG_POPUP      = 0x1E1E1E
Global $THEME_BG_INPUT      = 0x2A2A2A
Global $THEME_BG_HOVER      = 0x333333

; Theme scheme definitions [BG_MAIN, BG_POPUP, BG_INPUT, BG_HOVER, FG_PRIMARY, FG_TEXT, FG_MENU, FG_NORMAL, FG_DIM, FG_LABEL]
Global Const $__g_Theme_aSchemeDark[10]     = [0x191919, 0x1E1E1E, 0x2A2A2A, 0x333333, 0xE8E8E8, 0xE0E0E0, 0xDDDDDD, 0xCCCCCC, 0xAAAAAA, 0x888888]
Global Const $__g_Theme_aSchemeDarker[10]   = [0x0F0F0F, 0x141414, 0x202020, 0x292929, 0xE8E8E8, 0xE0E0E0, 0xDDDDDD, 0xCCCCCC, 0xAAAAAA, 0x888888]
Global Const $__g_Theme_aSchemeMidnight[10] = [0x141824, 0x1A1E2E, 0x242838, 0x2E3348, 0xE8E8E8, 0xE0E0E0, 0xDDDDDD, 0xCCCCCC, 0xAAAAAA, 0x888888]
Global Const $__g_Theme_aSchemeMidday[10]   = [0xD8D8D8, 0xE4E4E4, 0xF0F0F0, 0xC8C8C8, 0x1A1A1A, 0x222222, 0x2A2A2A, 0x333333, 0x666666, 0x888888]
Global Const $__g_Theme_aSchemeSunset[10]   = [0x2D1B2E, 0x3D2040, 0x552850, 0x6E3568, 0xF0D0E8, 0xE8C8E0, 0xE0C0D8, 0xD8B0C8, 0xB088A0, 0x886880]

Global Const $THEME_BG_ACTIVE     = 0x484848
Global Const $THEME_BG_ARROW_HOV  = 0x3A3A4A
Global Const $THEME_BG_BORDER     = 0x444444
Global Const $THEME_BG_BTN_HOV    = 0x4A4A4A
Global Const $THEME_BG_SEPARATOR  = 0x3A3A3A
Global Const $THEME_BG_DROP_TARGET = 0x2A3A5A

; -- Foreground colors (non-const: theme-switched at startup) --
Global $THEME_FG_PRIMARY    = 0xE8E8E8
Global $THEME_FG_TEXT       = 0xE0E0E0
Global $THEME_FG_MENU       = 0xDDDDDD
Global $THEME_FG_NORMAL     = 0xCCCCCC
Global $THEME_FG_DIM        = 0xAAAAAA
Global $THEME_FG_LABEL      = 0x888888
Global Const $THEME_FG_PEEK_DIM   = 0x555555
Global Const $THEME_FG_DRAG_DIM   = 0x555555
Global Const $THEME_FG_LINK       = 0x6699CC
Global Const $THEME_FG_WHITE      = 0xFFFFFF

; -- Alpha values --
Global Const $THEME_ALPHA_MAIN    = 235
Global Const $THEME_ALPHA_POPUP   = 235
Global Const $THEME_ALPHA_MENU    = 240
Global Const $THEME_ALPHA_DIALOG  = 245

; -- Dimensions --
Global Const $THEME_MAIN_WIDTH    = 130
Global Const $THEME_BTN_WIDTH     = 32
Global Const $THEME_ITEM_HEIGHT   = 24
Global Const $THEME_MENU_ITEM_H   = 30
Global Const $THEME_PEEK_ZONE_W   = 20

; -- Fonts --
Global Const $THEME_FONT_MAIN     = "Segoe UI"
Global Const $THEME_FONT_MONO     = "Fira Code"
Global Const $THEME_FONT_MONO_FB  = "Consolas"
Global Const $THEME_FONT_SYMBOL   = "Segoe UI Symbol"

Global $__g_Theme_bFiraLoaded = False

; -- Preset colors for color picker --
Global Const $THEME_PRESET_COLORS[8] = [7, 0x4A9EFF, 0x4AFF7E, 0xFF7E4A, 0xFFD54A, 0xB44AFF, 0xFF4A9E, 0x4AFFCF]

; -- Timer intervals (ms) --
Global Const $THEME_TIMER_TOPMOST  = 300
Global Const $THEME_TIMER_POLL     = 400
Global Const $THEME_TIMER_BOUNCE   = 500
Global Const $THEME_TIMER_TEMPLIST = 3000

; -- Frame-level cursor cache (call _Theme_CacheFrameState once per main loop tick) --
Global $__g_Theme_iCachedCursorX = 0
Global $__g_Theme_iCachedCursorY = 0

; #FUNCTIONS# ===================================================

; Name:        _Theme_CacheFrameState
; Description: Caches cursor position once per frame. Call at the top of the main loop.
;              All subsequent _Theme_IsCursorOverWindow calls use the cached position,
;              eliminating ~20 redundant MouseGetPos() API calls per frame.
Func _Theme_CacheFrameState()
    Local $aMP = MouseGetPos()
    $__g_Theme_iCachedCursorX = $aMP[0]
    $__g_Theme_iCachedCursorY = $aMP[1]
EndFunc

; -- Tooltip registry for themed tooltips --
Global $__g_Theme_aTipIDs[400]
Global $__g_Theme_aTipTexts[400]
Global $__g_Theme_iTipCount = 0
Global $__g_Theme_iLastTipCtrl = 0

; Name:        _Theme_SetTooltip
; Description: Registers a themed tooltip for a control. The tooltip is shown
;              when _Theme_CheckTooltipHover is called and cursor is over the control.
; Parameters:  $idCtrl - control ID
;              $sText - tooltip text
Func _Theme_SetTooltip($idCtrl, $sText)
    If $__g_Theme_iTipCount >= 399 Then Return
    $__g_Theme_iTipCount += 1
    $__g_Theme_aTipIDs[$__g_Theme_iTipCount] = $idCtrl
    $__g_Theme_aTipTexts[$__g_Theme_iTipCount] = $sText
EndFunc

; Name:        _Theme_CheckTooltipHover
; Description: Check if cursor is over any registered tooltip control and show/hide.
;              Call from dialog message loops.
; Parameters:  $hGUI - the GUI handle to check cursor against
Func _Theme_CheckTooltipHover($hGUI)
    If $hGUI = 0 Then Return
    Local $aCursor = GUIGetCursorInfo($hGUI)
    If @error Then
        If $__g_Theme_iLastTipCtrl <> 0 Then
            _Theme_HideTooltip()
            $__g_Theme_iLastTipCtrl = 0
        EndIf
        Return
    EndIf

    Local $iCtrl = $aCursor[4]
    If $iCtrl = $__g_Theme_iLastTipCtrl Then Return ; same control, tooltip already showing

    ; Check if this control has a registered tooltip
    Local $i
    For $i = 1 To $__g_Theme_iTipCount
        If $__g_Theme_aTipIDs[$i] = $iCtrl Then
            $__g_Theme_iLastTipCtrl = $iCtrl
            _Theme_ShowTooltip($__g_Theme_aTipTexts[$i])
            Return
        EndIf
    Next

    ; Cursor over unregistered control — hide tooltip
    If $__g_Theme_iLastTipCtrl <> 0 Then
        _Theme_HideTooltip()
        $__g_Theme_iLastTipCtrl = 0
    EndIf
EndFunc

; Name:        _Theme_ClearTooltips
; Description: Clears all registered tooltips (call when dialog is destroyed)
Func _Theme_ClearTooltips()
    $__g_Theme_iTipCount = 0
    $__g_Theme_iLastTipCtrl = 0
    _Theme_HideTooltip()
EndFunc

; Name:        _Theme_CreatePopup
; Description: Creates a dark-themed popup window (WS_POPUP, topmost, layered)
; Parameters:  $sTitle - window title
;              $iW, $iH - width and height
;              $iX, $iY - position
;              $iBgColor - background color (default: $THEME_BG_POPUP)
;              $iAlpha - opacity 0-255 (default: $THEME_ALPHA_POPUP)
; Return:      GUI handle
Func _Theme_CreatePopup($sTitle, $iW, $iH, $iX, $iY, $iBgColor = $THEME_BG_POPUP, $iAlpha = $THEME_ALPHA_POPUP)
    Local $hGUI = GUICreate($sTitle, $iW, $iH, $iX, $iY, _
        $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
    GUISwitch($hGUI) ; ensure this GUI is active for subsequent GUICtrlCreate* calls
    GUISetBkColor($iBgColor)
    _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iAlpha, $LWA_ALPHA)
    Return $hGUI
EndFunc

; Name:        __Theme_ShouldAnimate
; Description: Checks if animation is enabled for a given location type
; Parameters:  $sType - "list", "menu", "dialog", "toast", "widget" (default: checks master only)
; Return:      True if animation should play
Func __Theme_ShouldAnimate($sType = "")
    If Not _Cfg_GetAnimationsEnabled() Then Return False
    Switch $sType
        Case "list"
            Return _Cfg_GetAnimList()
        Case "menu"
            Return _Cfg_GetAnimMenus()
        Case "dialog"
            Return _Cfg_GetAnimDialogs()
        Case "toast"
            Return _Cfg_GetAnimToasts()
        Case "widget"
            Return _Cfg_GetAnimWidget()
    EndSwitch
    Return True
EndFunc

; Name:        _Theme_FadeIn
; Description: Fades a layered window from alpha 0 to target. Respects per-location animation config.
; Parameters:  $hGUI - window handle
;              $iTargetAlpha - target opacity (default: THEME_ALPHA_POPUP)
;              $sType - animation location type for per-location toggle
Func _Theme_FadeIn($hGUI, $iTargetAlpha = Default, $sType = "")
    If $iTargetAlpha = Default Then $iTargetAlpha = $THEME_ALPHA_POPUP
    If Not __Theme_ShouldAnimate($sType) Then
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
        GUISetState(@SW_SHOW, $hGUI)
        Return
    EndIf
    _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
    GUISetState(@SW_SHOW, $hGUI)
    Local $iStep = _Cfg_GetFadeStep()
    Local $iSleep = __Theme_FadeSleep($iTargetAlpha, $iStep, _Cfg_GetFadeInDuration())
    Local $i
    For $i = 0 To $iTargetAlpha Step $iStep
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $i, $LWA_ALPHA)
        Sleep($iSleep)
    Next
    _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
EndFunc

; Name:        __Theme_FadeSleep
; Description: Derives the per-frame sleep for a blocking fade so that the configured
;              fade_in/out_duration (ms) controls the total fade time: sleep = duration / frames,
;              where frames = ceil(alpha-range / step). When the duration key is 0/unset the legacy
;              fade_sleep_ms value is used instead (unchanged default behavior). The per-frame value
;              is capped at 50 ms (the fade_sleep_ms ceiling) so worst-case blocking can never exceed
;              the prior pathological ceiling of frames * 50 ms.
; Parameters:  $iAlphaRange - total alpha delta to traverse (e.g. target alpha)
;              $iStep       - alpha increment per frame (>= 1)
;              $iDuration   - configured fade duration in ms (0 = use fade_sleep_ms fallback)
; Return:      Per-frame sleep in ms (0..50)
Func __Theme_FadeSleep($iAlphaRange, $iStep, $iDuration)
    If $iStep < 1 Then $iStep = 1
    Local $iSleep
    If $iDuration > 0 Then
        Local $iFrames = Int($iAlphaRange / $iStep)
        If $iFrames < 1 Then $iFrames = 1
        $iSleep = Int($iDuration / $iFrames)
    Else
        $iSleep = _Cfg_GetFadeSleepMs()
    EndIf
    If $iSleep < 0 Then $iSleep = 0
    If $iSleep > 50 Then $iSleep = 50
    Return $iSleep
EndFunc

; Name:        _Theme_FadeOut
; Description: Fades a layered window from current alpha to 0 then deletes it.
; Parameters:  $hGUI - window handle (will be GUIDeleted after fade)
;              $sType - animation location type for per-location toggle
Func _Theme_FadeOut($hGUI, $sType = "")
    If $hGUI = 0 Then Return
    If Not __Theme_ShouldAnimate($sType) Then
        GUIDelete($hGUI)
        Return
    EndIf
    Local $iAlpha = $THEME_ALPHA_POPUP
    Local $iStep = _Cfg_GetFadeStep()
    Local $iSleep = __Theme_FadeSleep($iAlpha, $iStep, _Cfg_GetFadeOutDuration())
    Local $i
    For $i = $iAlpha To 0 Step -$iStep
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $i, $LWA_ALPHA)
        Sleep($iSleep)
    Next
    GUIDelete($hGUI)
EndFunc

; Name:        _Theme_ApplyHover
; Description: Sets hover colors on a control
; Parameters:  $iCtrl - control ID
;              $iFg - foreground color (default: $THEME_FG_WHITE)
;              $iBg - background color (default: $THEME_BG_HOVER)
Func _Theme_ApplyHover($iCtrl, $iFg = $THEME_FG_WHITE, $iBg = $THEME_BG_HOVER)
    GUICtrlSetColor($iCtrl, $iFg)
    GUICtrlSetBkColor($iCtrl, $iBg)
EndFunc

; Name:        _Theme_RemoveHover
; Description: Resets a control to non-hover colors
; Parameters:  $iCtrl - control ID
;              $iFg - foreground color to restore
;              $iBg - background color to restore (default: transparent)
Func _Theme_RemoveHover($iCtrl, $iFg, $iBg = $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($iCtrl, $iFg)
    GUICtrlSetBkColor($iCtrl, $iBg)
EndFunc

; Name:        _Theme_CreateMenuItem
; Description: Creates a label styled as a dark-theme menu item
; Parameters:  $sText - display text
;              $iX, $iY - position
;              $iW, $iH - width and height
;              $iFontSize - font size (default: 10)
; Return:      Control ID
Func _Theme_CreateMenuItem($sText, $iX, $iY, $iW, $iH, $iFontSize = 10)
    Local $iCtrl = GUICtrlCreateLabel($sText, $iX, $iY, $iW, $iH, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($iCtrl, $iFontSize, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($iCtrl, $THEME_FG_MENU)
    GUICtrlSetBkColor($iCtrl, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($iCtrl, 0)
    Return $iCtrl
EndFunc

; Name:        _Theme_Confirm
; Description: Shows a blocking dark-themed Yes/No confirmation dialog.
;              Runs its own message loop and returns when the user decides.
; Parameters:  $sTitle - dialog title text
;              $sMessage - body message text
; Return:      True if user clicked Yes / pressed Enter, False for No / Escape / close
Func _Theme_Confirm($sTitle, $sMessage)
    Local $iDlgW = 320, $iDlgH = 130
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("Confirm", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Title
    GUICtrlCreateLabel($sTitle, 14, 10, $iDlgW - 28, 20)
    GUICtrlSetFont(-1, 10, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Message
    GUICtrlCreateLabel($sMessage, 14, 36, $iDlgW - 28, 46)
    GUICtrlSetFont(-1, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Yes button
    Local $iBtnY = $iDlgH - 36
    Local $iBtnW = 64, $iBtnH = 26
    Local $idYes = GUICtrlCreateLabel(_i18n("General.btn_yes", "Yes"), 14, $iBtnY, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idYes, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idYes, $THEME_FG_MENU)
    GUICtrlSetBkColor($idYes, $THEME_BG_HOVER)
    GUICtrlSetCursor($idYes, 0)

    ; No button
    Local $idNo = GUICtrlCreateLabel(_i18n("General.btn_no", "No"), 14 + $iBtnW + 10, $iBtnY, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idNo, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idNo, $THEME_FG_MENU)
    GUICtrlSetBkColor($idNo, $THEME_BG_HOVER)
    GUICtrlSetCursor($idNo, 0)

    _Theme_FadeIn($hDlg, $THEME_ALPHA_DIALOG, "dialog")

    ; Blocking message loop
    Local $iHovered = 0
    Local $bResult = False
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idYes
                    $bResult = True
                    ExitLoop
                Case $idNo
                    ExitLoop
            EndSwitch
        EndIf

        ; Keyboard: Enter = Yes, Escape = No
        Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And IsArray($retEnter) And BitAND($retEnter[0], 0x8000) <> 0 Then
            $bResult = True
            ExitLoop
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then
            ExitLoop
        EndIf

        ; Hover effects on buttons
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idYes Then $iFound = $idYes
            If $aCursor[4] = $idNo Then $iFound = $idNo

            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    _Theme_RemoveHover($iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then
                    _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
                EndIf
            EndIf
        EndIf

        Sleep(10)
    WEnd

    _Theme_FadeOut($hDlg, "dialog")
    Return $bResult
EndFunc

; Name:        _Theme_Alert
; Description: Shows a blocking dark-themed info dialog with a single Close button.
;              Auto-closes after the specified timeout.
; Parameters:  $sTitle - dialog title text
;              $sMessage - body message text (supports @CRLF for multi-line)
;              $iTimeout - auto-close timeout in ms (default: 5000)
Func _Theme_Alert($sTitle, $sMessage, $iTimeout = 5000)
    Local $iDlgW = 340, $iDlgH = 180
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("Alert", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Title
    GUICtrlCreateLabel($sTitle, 14, 10, $iDlgW - 28, 22)
    GUICtrlSetFont(-1, 11, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Message
    GUICtrlCreateLabel($sMessage, 14, 38, $iDlgW - 28, 94)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Close button
    Local $iBtnW = 64, $iBtnH = 26
    Local $idClose = GUICtrlCreateLabel(_i18n("General.btn_close", "Close"), ($iDlgW - $iBtnW) / 2, $iDlgH - 36, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($idClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($idClose, 0)

    _Theme_FadeIn($hDlg, $THEME_ALPHA_DIALOG, "dialog")

    Local $iHovered = 0
    Local $hTimer = TimerInit()
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            If $aMsg[0] = $GUI_EVENT_CLOSE Or $aMsg[0] = $idClose Then ExitLoop
        EndIf

        ; Keyboard: Enter or Escape closes
        Local $retKey = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And IsArray($retKey) And BitAND($retKey[0], 0x8000) <> 0 Then ExitLoop
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

        ; Timeout
        If TimerDiff($hTimer) >= $iTimeout Then ExitLoop

        ; Hover on button
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idClose Then $iFound = $idClose
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then _Theme_RemoveHover($iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        Sleep(10)
    WEnd

    _Theme_FadeOut($hDlg, "dialog")
EndFunc

; Name:        _Theme_IsCursorOverWindow
; Description: Checks if the mouse cursor is over a given window
; Parameters:  $hWnd - window handle
; Return:      True if cursor is over the window, False otherwise
Func _Theme_IsCursorOverWindow($hWnd)
    If $hWnd = 0 Then Return False
    Local $aWP = WinGetPos($hWnd)
    If @error Then Return False
    If $__g_Theme_iCachedCursorX >= $aWP[0] And $__g_Theme_iCachedCursorX < $aWP[0] + $aWP[2] And _
       $__g_Theme_iCachedCursorY >= $aWP[1] And $__g_Theme_iCachedCursorY < $aWP[1] + $aWP[3] Then Return True
    Return False
EndFunc

; Name:        _Theme_IsCursorInWindowBridge
; Description: Checks whether the cursor is inside the padded bounding area shared
;              by two related popup windows. This is used to keep parent/submenu
;              stacks alive while the cursor crosses the small gap between them.
; Parameters:  $hWndA - first window handle
;              $hWndB - second window handle
;              $iPad - extra padding around the combined bounds (default: 12)
; Return:      True if cursor is within the shared padded area, False otherwise
Func _Theme_IsCursorInWindowBridge($hWndA, $hWndB, $iPad = 12)
    If $hWndA = 0 Or $hWndB = 0 Then Return False

    Local $aA = WinGetPos($hWndA)
    If @error Or Not IsArray($aA) Then Return False
    Local $aB = WinGetPos($hWndB)
    If @error Or Not IsArray($aB) Then Return False

    Local $iLeft = $aA[0]
    If $aB[0] < $iLeft Then $iLeft = $aB[0]
    Local $iTop = $aA[1]
    If $aB[1] < $iTop Then $iTop = $aB[1]

    Local $iRight = $aA[0] + $aA[2]
    If $aB[0] + $aB[2] > $iRight Then $iRight = $aB[0] + $aB[2]
    Local $iBottom = $aA[1] + $aA[3]
    If $aB[1] + $aB[3] > $iBottom Then $iBottom = $aB[1] + $aB[3]

    If $__g_Theme_iCachedCursorX >= $iLeft - $iPad And $__g_Theme_iCachedCursorX < $iRight + $iPad And _
       $__g_Theme_iCachedCursorY >= $iTop - $iPad And $__g_Theme_iCachedCursorY < $iBottom + $iPad Then Return True
    Return False
EndFunc

; Name:        _Theme_RectsIntersect
; Description: PURE geometry test — do two rectangles (given as edges) overlap? Right/bottom edges
;              are exclusive, so rects that merely touch along an edge are NOT counted as
;              overlapping. No globals, no API calls (headless-testable).
; Parameters:  $iL1,$iT1,$iR1,$iB1 - first rect edges (left, top, right, bottom)
;              $iL2,$iT2,$iR2,$iB2 - second rect edges
; Return:      True if the rectangles share any area, else False
Func _Theme_RectsIntersect($iL1, $iT1, $iR1, $iB1, $iL2, $iT2, $iR2, $iB2)
    Return ($iL1 < $iR2 And $iR1 > $iL2 And $iT1 < $iB2 And $iB1 > $iT2)
EndFunc

; Name:        _Theme_IsWidgetOccluded
; Description: PURE decision for the widget's topmost re-assert gate. Given the widget rect and a
;              list of the windows sitting ABOVE it in the z-order (each row: visible flag, topmost
;              flag, and rect edges), decide whether the widget is genuinely buried. A window only
;              occludes the widget when it is visible AND topmost AND its rect overlaps the widget:
;              a non-topmost window can never paint over our WS_EX_TOPMOST widget, so counting it
;              would trigger a needless re-assert / repaint storm. No globals, no API calls, so it
;              is headless-testable — the live z-order walk (see __WidgetIsOccluded) feeds it.
; Parameters:  $iWL,$iWT,$iWR,$iWB - widget rect edges (left, top, right, bottom)
;              $aAbove             - [$iCount][6] array; cols 0=visible,1=topmost,2=L,3=T,4=R,5=B
;              $iCount             - number of valid rows in $aAbove
; Return:      True if any qualifying window occludes the widget, else False
Func _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, ByRef $aAbove, $iCount)
    Local $i
    For $i = 0 To $iCount - 1
        If Not $aAbove[$i][0] Then ContinueLoop ; not visible
        If Not $aAbove[$i][1] Then ContinueLoop ; not topmost — can't paint above our topmost widget
        If _Theme_RectsIntersect($iWL, $iWT, $iWR, $iWB, _
                $aAbove[$i][2], $aAbove[$i][3], $aAbove[$i][4], $aAbove[$i][5]) Then
            Return True
        EndIf
    Next
    Return False
EndFunc

; Name:        _Theme_WindowIsOccluded
; Description: Live z-order probe: is $hWnd (a topmost window) currently buried under another
;              visible topmost window? Walks from $hWnd toward the TOP of the z-order (GW_HWNDPREV),
;              collects the windows painted above it (visible flag, topmost flag, rect), and defers
;              the buried/not-buried call to the pure _Theme_IsWidgetOccluded. Windows owned by
;              $iSkipPid are ignored (the widget passes @AutoItPID so its own list/menus/toasts,
;              which stack above it on purpose, don't count as occluders); pass 0 to skip nothing.
;              Because $hWnd is topmost, everything above it in the z-order is also topmost, so the
;              walk terminates within the small topmost band — a few WinAPI calls.
; Parameters:  $hWnd     - the (topmost) window to test
;              $iSkipPid - process id whose windows are ignored (0 = consider all)
; Return:      True if a qualifying window covers $hWnd, else False
Func _Theme_WindowIsOccluded($hWnd, $iSkipPid = 0)
    Local $aWP = WinGetPos($hWnd)
    If @error Or Not IsArray($aWP) Then Return False
    Local $iWL = $aWP[0], $iWT = $aWP[1]
    Local $iWR = $aWP[0] + $aWP[2], $iWB = $aWP[1] + $aWP[3]

    Local $aAbove[16][6]
    Local $iCount = 0
    Local $hCur = $hWnd
    Local $iGuard = 0
    While $iCount < 16 And $iGuard < 400
        $iGuard += 1
        Local $hPrev = _WinAPI_GetWindow($hCur, $GW_HWNDPREV)
        If @error Or Not $hPrev Then ExitLoop
        $hCur = $hPrev
        If $iSkipPid <> 0 Then
            Local $iPid = 0
            _WinAPI_GetWindowThreadProcessId($hCur, $iPid)
            If $iPid = $iSkipPid Then ContinueLoop
        EndIf
        Local $bVisible = _WinAPI_IsWindowVisible($hCur)
        Local $iExStyle = _WinAPI_GetWindowLong($hCur, $GWL_EXSTYLE)
        Local $bTopmost = (BitAND($iExStyle, $WS_EX_TOPMOST) <> 0)
        Local $tRect = _WinAPI_GetWindowRect($hCur)
        If @error Then ContinueLoop
        $aAbove[$iCount][0] = $bVisible
        $aAbove[$iCount][1] = $bTopmost
        $aAbove[$iCount][2] = DllStructGetData($tRect, "Left")
        $aAbove[$iCount][3] = DllStructGetData($tRect, "Top")
        $aAbove[$iCount][4] = DllStructGetData($tRect, "Right")
        $aAbove[$iCount][5] = DllStructGetData($tRect, "Bottom")
        $iCount += 1
    WEnd

    Return _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aAbove, $iCount)
EndFunc

; =============================================
; TOAST NOTIFICATION
; =============================================

Global $__g_Toast_hGUI = 0
Global $__g_Toast_hTimer = 0
Global $__g_Toast_iDuration = 0
Global $__g_Toast_iFadeStep = 0
Global $__g_Toast_iAlpha = 0
Global $__g_Toast_iFadeInMs = 0        ; duration of the non-blocking fade-in ramp (0 = instant)
Global Const $__g_Toast_iMaxAlpha = 230

; Toast status icon colors
Global Const $TOAST_SUCCESS = 0x4AFF7E ; green
Global Const $TOAST_ERROR   = 0xFF5555 ; red
Global Const $TOAST_WARNING = 0xFFD54A ; yellow
Global Const $TOAST_INFO    = 0x4A9EFF ; blue

; Name:        __Theme_ToastPosition
; Description: Pure mapping from the configured toast_position (_Cfg_GetToastPosition) to on-screen
;              coordinates for a toast of the given size. Supported positions: top-left, top-right,
;              bottom-left, bottom-right, and "widget" (bottom-center, the default). Mirrors the OSD
;              margins (20px edge, 60px bottom lift).
; Parameters:  $iW, $iH - toast width/height
;              $iX, $iY - ByRef outputs
Func __Theme_ToastPosition($iW, $iH, ByRef $iX, ByRef $iY)
    Switch _Cfg_GetToastPosition()
        Case "top-left"
            $iX = 20
            $iY = 20
        Case "top-right"
            $iX = @DesktopWidth - $iW - 20
            $iY = 20
        Case "bottom-left"
            $iX = 20
            $iY = @DesktopHeight - $iH - 60
        Case "bottom-right"
            $iX = @DesktopWidth - $iW - 20
            $iY = @DesktopHeight - $iH - 60
        Case Else ; "widget" (default): bottom-center, near the widget's home position
            $iX = (@DesktopWidth - $iW) / 2
            $iY = @DesktopHeight - $iH - 60
    EndSwitch
EndFunc

; Name:        _Theme_Toast
; Description: Shows a small non-blocking toast notification with a colored status icon.
;              Call _Theme_ToastTick() from the main loop to handle fade-out.
; Parameters:  $sText - message text
;              $iX - X position, or Default to place per the configured toast_position
;              $iY - Y position, or Default to place per the configured toast_position
;              $iDuration - how long to show in ms (default: 2000)
;              $iIconColor - status icon color ($TOAST_SUCCESS/ERROR/WARNING/INFO, default: $TOAST_INFO)
Func _Theme_Toast($sText, $iX = Default, $iY = Default, $iDuration = 2000, $iIconColor = -1)
    If $iIconColor = -1 Then $iIconColor = $TOAST_INFO

    ; Destroy previous toast if still showing
    _Theme_ToastDestroy()

    Local $iIconW = 22
    Local $iTextW = 10 + StringLen($sText) * 7
    Local $iW = $iIconW + $iTextW
    If $iW < 120 Then $iW = 120
    If $iW > 320 Then $iW = 320
    Local $iH = 26

    ; When the caller defers placement (Default x/y), honor the configured toast_position.
    If $iX = Default Or $iY = Default Then __Theme_ToastPosition($iW, $iH, $iX, $iY)

    $__g_Toast_hGUI = GUICreate("Toast", $iW, $iH, $iX, $iY, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
    GUISwitch($__g_Toast_hGUI)
    GUISetBkColor($THEME_BG_POPUP)

    ; Status icon (colored circle)
    GUICtrlCreateLabel(ChrW(0x25CF), 4, 0, $iIconW, $iH, BitOR($SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont(-1, 10, 400, 0, $THEME_FONT_SYMBOL)
    GUICtrlSetColor(-1, $iIconColor)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Text
    GUICtrlCreateLabel($sText, $iIconW + 2, 0, $iW - $iIconW - 6, $iH, $SS_CENTERIMAGE)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Non-blocking fade-in: show transparent and let _Theme_ToastTick() ramp the alpha up over
    ; the main loop. The old version blocked the whole app for the ramp duration (~64 ms).
    If _Cfg_GetAnimationsEnabled() Then
        Local $iSteps = Int($__g_Toast_iMaxAlpha / _Cfg_GetFadeStep())
        If $iSteps < 1 Then $iSteps = 1
        $__g_Toast_iFadeInMs = $iSteps * _Cfg_GetFadeSleepMs()
        $__g_Toast_iAlpha = 0
        _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, 0, $LWA_ALPHA)
        GUISetState(@SW_SHOWNOACTIVATE, $__g_Toast_hGUI)
    Else
        $__g_Toast_iFadeInMs = 0
        $__g_Toast_iAlpha = $__g_Toast_iMaxAlpha
        _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $__g_Toast_iMaxAlpha, $LWA_ALPHA)
        GUISetState(@SW_SHOWNOACTIVATE, $__g_Toast_hGUI)
    EndIf

    $__g_Toast_hTimer = TimerInit()
    $__g_Toast_iDuration = $iDuration
    $__g_Toast_iFadeStep = 0
EndFunc

; Name:        _Theme_IsToastActive
; Description: Returns whether a toast is currently showing (used for the main-loop sleep tier)
Func _Theme_IsToastActive()
    Return ($__g_Toast_hGUI <> 0)
EndFunc

; Name:        _Theme_ToastTick
; Description: Call from main loop. Handles fade-out and cleanup.
; Return:      True if toast is active, False if idle
Func _Theme_ToastTick()
    If $__g_Toast_hGUI = 0 Then Return False

    Local $iElapsed = TimerDiff($__g_Toast_hTimer)

    ; Fade-in phase (non-blocking ramp)
    If $iElapsed < $__g_Toast_iFadeInMs Then
        Local $iInAlpha = Int($__g_Toast_iMaxAlpha * $iElapsed / $__g_Toast_iFadeInMs)
        If $iInAlpha < 0 Then $iInAlpha = 0
        If $iInAlpha > $__g_Toast_iMaxAlpha Then $iInAlpha = $__g_Toast_iMaxAlpha
        If $iInAlpha <> $__g_Toast_iAlpha Then
            $__g_Toast_iAlpha = $iInAlpha
            _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $iInAlpha, $LWA_ALPHA)
        EndIf
        Return True
    EndIf

    ; Visible phase (fade-in offsets the duration so total on-screen time is preserved)
    Local $iVisibleEnd = $__g_Toast_iFadeInMs + $__g_Toast_iDuration
    If $iElapsed < $iVisibleEnd Then
        If $__g_Toast_iAlpha <> $__g_Toast_iMaxAlpha Then
            $__g_Toast_iAlpha = $__g_Toast_iMaxAlpha
            _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $__g_Toast_iMaxAlpha, $LWA_ALPHA)
        EndIf
        Return True
    EndIf

    ; Fade-out phase (configurable duration)
    Local $iFadeElapsed = $iElapsed - $iVisibleEnd
    Local $iFadeMs = _Cfg_GetToastFadeOutDuration()
    If $iFadeMs < 1 Then $iFadeMs = 1
    If $iFadeElapsed < $iFadeMs Then
        Local $iNewAlpha = $__g_Toast_iMaxAlpha - Int($__g_Toast_iMaxAlpha * $iFadeElapsed / $iFadeMs)
        If $iNewAlpha < 0 Then $iNewAlpha = 0
        If $iNewAlpha <> $__g_Toast_iAlpha Then
            $__g_Toast_iAlpha = $iNewAlpha
            _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $__g_Toast_iAlpha, $LWA_ALPHA)
        EndIf
        Return True
    EndIf

    ; Done — destroy
    _Theme_ToastDestroy()
    Return False
EndFunc

; Name:        _Theme_ToastDestroy
; Description: Destroys the toast if visible
Func _Theme_ToastDestroy()
    If $__g_Toast_hGUI <> 0 Then
        GUIDelete($__g_Toast_hGUI)
        $__g_Toast_hGUI = 0
    EndIf
EndFunc

; =============================================
; OSD NOTIFICATION
; =============================================

Global $__g_OSD_hGUI = 0
Global $__g_OSD_hTimer = 0
Global $__g_OSD_iDuration = 0
Global $__g_OSD_iFadeStep = 0
Global $__g_OSD_iAlpha = 0

; Name:        _Theme_ShowOsd
; Description: Shows a large OSD popup for desktop switch notifications.
;              Non-blocking. Call _Theme_OsdTick() from the main loop to
;              handle fade-out and cleanup.
; Parameters:  $sText     - OSD text
;              $iDuration - how long to show in ms
;              $sPosition - position string (e.g. "top-center", "middle-center")
;              $iFontSize - font size for the OSD text
;              $iOpacity  - window opacity (0-255)
;              $iWidth    - width of the OSD window in pixels
Func _Theme_ShowOsd($sText, $iDuration, $sPosition, $iFontSize, $iOpacity, $iWidth)
    _Theme_OsdDestroy()

    Local $iH = $iFontSize * 3
    If $iH < 40 Then $iH = 40
    Local $iW = $iWidth

    ; Calculate position
    Local $iX = 0, $iY = 0
    Switch $sPosition
        Case "top-left"
            $iX = 20
            $iY = 20
        Case "top-center"
            $iX = (@DesktopWidth - $iW) / 2
            $iY = 20
        Case "top-right"
            $iX = @DesktopWidth - $iW - 20
            $iY = 20
        Case "middle-left"
            $iX = 20
            $iY = (@DesktopHeight - $iH) / 2
        Case "middle-center"
            $iX = (@DesktopWidth - $iW) / 2
            $iY = (@DesktopHeight - $iH) / 2
        Case "middle-right"
            $iX = @DesktopWidth - $iW - 20
            $iY = (@DesktopHeight - $iH) / 2
        Case "bottom-left"
            $iX = 20
            $iY = @DesktopHeight - $iH - 60
        Case "bottom-center"
            $iX = (@DesktopWidth - $iW) / 2
            $iY = @DesktopHeight - $iH - 60
        Case "bottom-right"
            $iX = @DesktopWidth - $iW - 20
            $iY = @DesktopHeight - $iH - 60
        Case "widget"
            $iX = (@DesktopWidth - $iW) / 2
            $iY = @DesktopHeight - $iH - 60
    EndSwitch

    $__g_OSD_hGUI = GUICreate("OSD", $iW, $iH, $iX, $iY, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
    GUISwitch($__g_OSD_hGUI)
    GUISetBkColor($THEME_BG_POPUP)

    GUICtrlCreateLabel($sText, 0, 0, $iW, $iH, BitOR($SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont(-1, $iFontSize, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $__g_OSD_iAlpha = $iOpacity
    _WinAPI_SetLayeredWindowAttributes($__g_OSD_hGUI, 0, $__g_OSD_iAlpha, $LWA_ALPHA)
    GUISetState(@SW_SHOWNOACTIVATE, $__g_OSD_hGUI)
    $__g_OSD_iDuration = $iDuration
    $__g_OSD_iFadeStep = 0
    $__g_OSD_hTimer = TimerInit()
EndFunc

; Name:        _Theme_OsdTick
; Description: Call from main loop. Handles fade-out and cleanup.
; Return:      None
Func _Theme_OsdTick()
    If $__g_OSD_hGUI = 0 Or $__g_OSD_hTimer = 0 Then Return
    If $__g_OSD_iFadeStep = 0 Then
        If TimerDiff($__g_OSD_hTimer) >= $__g_OSD_iDuration Then $__g_OSD_iFadeStep = 1
        Return
    EndIf
    $__g_OSD_iAlpha -= 15
    If $__g_OSD_iAlpha <= 0 Then
        _Theme_OsdDestroy()
        Return
    EndIf
    _WinAPI_SetLayeredWindowAttributes($__g_OSD_hGUI, 0, $__g_OSD_iAlpha, $LWA_ALPHA)
EndFunc

; Name:        _Theme_OsdDestroy
; Description: Destroys the OSD window if visible
Func _Theme_OsdDestroy()
    If $__g_OSD_hGUI <> 0 Then
        GUIDelete($__g_OSD_hGUI)
        $__g_OSD_hGUI = 0
    EndIf
    $__g_OSD_hTimer = 0
    $__g_OSD_iDuration = 0
    $__g_OSD_iFadeStep = 0
    $__g_OSD_iAlpha = 0
EndFunc

; =============================================
; THEMED TOOLTIP
; =============================================

Global $__g_Tooltip_hGUI = 0
Global $__g_Tooltip_hTimer = 0

; -- Tooltip geometry (shared by size calc and the show path) --
Global Const $__g_Theme_iTipMaxW  = 400 ; max popup width; text wraps rather than growing wider
Global Const $__g_Theme_iTipMinW  = 80  ; floor so a one-word tip is not a sliver
Global Const $__g_Theme_iTipPadX  = 6   ; inner horizontal padding, each side
Global Const $__g_Theme_iTipPadY  = 5   ; inner vertical padding, each side

; Name:        _Theme_MeasureTextBlock
; Description: Measures the pixel width/height a block of text occupies when drawn
;              in the given font and wrapped at $iMaxW. Honors explicit @CRLF/@LF
;              line breaks AND word-wrap, via DrawText DT_CALCRECT | DT_WORDBREAK,
;              so the height covers every rendered line — the wrapped ones too, not
;              just the count of explicit breaks. Uses a throwaway screen DC, so it
;              needs no window and is cheap enough to call once per tooltip show.
; Parameters:  $sText  - text to measure (may contain @CRLF)
;              $iMaxW  - wrap width in pixels
;              $iFontSz - font point size
;              $sFont  - font face name
;              ByRef $iOutW, $iOutH - resolved pixel width/height (0,0 on failure)
Func _Theme_MeasureTextBlock($sText, $iMaxW, $iFontSz, $sFont, ByRef $iOutW, ByRef $iOutH)
    $iOutW = 0
    $iOutH = 0
    If $sText = "" Or $iMaxW < 1 Then Return SetError(1, 0, 0)

    Local Const $DT_CALCRECT = 0x0400, $DT_WORDBREAK = 0x0010, $DT_NOPREFIX = 0x0800
    Local Const $LOGPIXELSY = 90

    Local $aDC = DllCall("user32.dll", "handle", "GetDC", "hwnd", 0)
    If @error Or Not IsArray($aDC) Or $aDC[0] = 0 Then Return SetError(2, 0, 0)
    Local $hDC = $aDC[0]

    ; Point size -> logical (negative) font height for the DC's DPI.
    Local $iLogPixY = 96
    Local $aCaps = DllCall("gdi32.dll", "int", "GetDeviceCaps", "handle", $hDC, "int", $LOGPIXELSY)
    If Not @error And IsArray($aCaps) And $aCaps[0] > 0 Then $iLogPixY = $aCaps[0]
    Local $iFontHeight = -Int($iFontSz * $iLogPixY / 72)

    Local $hOldFont = 0, $hFont = 0
    Local $aFont = DllCall("gdi32.dll", "handle", "CreateFontW", _
            "int", $iFontHeight, "int", 0, "int", 0, "int", 0, "int", 400, _
            "dword", 0, "dword", 0, "dword", 0, "dword", 1, "dword", 0, _
            "dword", 0, "dword", 0, "dword", 0, "wstr", $sFont)
    If Not @error And IsArray($aFont) And $aFont[0] <> 0 Then
        $hFont = $aFont[0]
        Local $aSel = DllCall("gdi32.dll", "handle", "SelectObject", "handle", $hDC, "handle", $hFont)
        If Not @error And IsArray($aSel) Then $hOldFont = $aSel[0]
    EndIf

    Local $tRect = DllStructCreate("int Left;int Top;int Right;int Bottom")
    DllStructSetData($tRect, "Left", 0)
    DllStructSetData($tRect, "Top", 0)
    DllStructSetData($tRect, "Right", $iMaxW)
    DllStructSetData($tRect, "Bottom", 0)

    DllCall("user32.dll", "int", "DrawTextW", "handle", $hDC, "wstr", $sText, "int", -1, _
            "struct*", $tRect, "uint", BitOR($DT_CALCRECT, $DT_WORDBREAK, $DT_NOPREFIX))

    $iOutW = DllStructGetData($tRect, "Right") - DllStructGetData($tRect, "Left")
    $iOutH = DllStructGetData($tRect, "Bottom") - DllStructGetData($tRect, "Top")

    ; Release everything we touched, in reverse order.
    If $hOldFont <> 0 Then DllCall("gdi32.dll", "handle", "SelectObject", "handle", $hDC, "handle", $hOldFont)
    If $hFont <> 0 Then DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $hFont)
    DllCall("user32.dll", "int", "ReleaseDC", "hwnd", 0, "handle", $hDC)
EndFunc

; Name:        _Theme_TooltipCalcSize
; Description: Resolves the final tooltip window size (padding included) for text,
;              clamping width to a max and letting height grow to fit every wrapped
;              and explicit line. This is the sizing seam the show path and tests
;              share — no clipping regardless of text length. Falls back to an
;              explicit-line-count estimate if GDI measurement is unavailable.
; Parameters:  $sText - tooltip text (may contain @CRLF)
;              ByRef $iOutW, $iOutH - resolved window width/height in pixels
Func _Theme_TooltipCalcSize($sText, ByRef $iOutW, ByRef $iOutH)
    Local $iFontSz = _Cfg_GetTooltipFontSize()
    Local $iLineH = $iFontSz + 6 ; fallback per-line height when GDI is unavailable
    Local $iMaxContentW = $__g_Theme_iTipMaxW - 2 * $__g_Theme_iTipPadX

    Local $iContentW = 0, $iContentH = 0
    If $sText <> "" Then _Theme_MeasureTextBlock($sText, $iMaxContentW, $iFontSz, $THEME_FONT_MAIN, $iContentW, $iContentH)

    If $iContentH <= 0 Then
        ; GDI measurement failed (or empty text): estimate from explicit line breaks.
        Local $aLines = StringSplit($sText, @CRLF, 1)
        $iContentH = $aLines[0] * $iLineH
    EndIf
    If $iContentW <= 0 Then $iContentW = $iMaxContentW

    $iOutW = $iContentW + 2 * $__g_Theme_iTipPadX
    $iOutH = $iContentH + 2 * $__g_Theme_iTipPadY
    If $iOutW < $__g_Theme_iTipMinW Then $iOutW = $__g_Theme_iTipMinW
    If $iOutW > $__g_Theme_iTipMaxW Then $iOutW = $__g_Theme_iTipMaxW
    Local $iMinH = $iLineH + 2 * $__g_Theme_iTipPadY
    If $iOutH < $iMinH Then $iOutH = $iMinH
EndFunc

; Name:        _Theme_ShowTooltip
; Description: Shows a dark-themed tooltip popup near the cursor. Non-blocking.
;              Auto-dismisses after 2.5 seconds or when cursor moves away.
;              Call _Theme_TooltipTick() from the main loop to handle auto-dismiss.
; Parameters:  $sText - tooltip text (supports multi-line via @CRLF)
;              $iX - X position (default: cursor X + 16)
;              $iY - Y position (default: cursor Y + 16)
Func _Theme_ShowTooltip($sText, $iX = -1, $iY = -1)
    _Theme_HideTooltip()

    ; Size to fit the fully rendered (wrapped + multi-line) text — no clipping.
    Local $iW, $iH
    _Theme_TooltipCalcSize($sText, $iW, $iH)

    ; Anchor near the cursor unless an explicit position was given.
    Local $iAnchorX = $iX, $iAnchorY = $iY
    If $iX = -1 Or $iY = -1 Then
        Local $aMP = MouseGetPos()
        If IsArray($aMP) Then
            If $iX = -1 Then $iAnchorX = $aMP[0] + 16
            If $iY = -1 Then $iAnchorY = $aMP[1] + 16
        Else
            If $iX = -1 Then $iAnchorX = 0
            If $iY = -1 Then $iAnchorY = 0
        EndIf
    EndIf

    ; Clamp to the work area of the monitor under the anchor: a tall tooltip near a
    ; screen edge flips/fits instead of running off-screen. Multi-monitor aware.
    Local $iWaL, $iWaT, $iWaR, $iWaB
    _CM_GetWorkArea($iAnchorX, $iAnchorY, $iWaL, $iWaT, $iWaR, $iWaB)
    Local $iPosX, $iPosY
    _CM_ClampToWorkArea($iAnchorX, $iAnchorY, $iW, $iH, $iWaL, $iWaT, $iWaR, $iWaB, $iPosX, $iPosY)

    $__g_Tooltip_hGUI = GUICreate("Tooltip", $iW, $iH, $iPosX, $iPosY, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
    GUISwitch($__g_Tooltip_hGUI)
    GUISetBkColor($THEME_BG_POPUP)
    _WinAPI_SetLayeredWindowAttributes($__g_Tooltip_hGUI, 0, 240, $LWA_ALPHA)

    GUICtrlCreateLabel($sText, $__g_Theme_iTipPadX, $__g_Theme_iTipPadY, _
        $iW - 2 * $__g_Theme_iTipPadX, $iH - 2 * $__g_Theme_iTipPadY)
    GUICtrlSetFont(-1, _Cfg_GetTooltipFontSize(), 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUISetState(@SW_SHOWNOACTIVATE, $__g_Tooltip_hGUI)
    $__g_Tooltip_hTimer = TimerInit()
EndFunc

; Name:        _Theme_HideTooltip
; Description: Hides the themed tooltip if visible
Func _Theme_HideTooltip()
    If $__g_Tooltip_hGUI <> 0 Then
        GUIDelete($__g_Tooltip_hGUI)
        $__g_Tooltip_hGUI = 0
    EndIf
EndFunc

; Name:        _Theme_TooltipTick
; Description: Auto-dismiss tooltip after 2.5 seconds. Call from main loop.
Func _Theme_TooltipTick()
    If $__g_Tooltip_hGUI = 0 Then Return
    If TimerDiff($__g_Tooltip_hTimer) > 2500 Then _Theme_HideTooltip()
EndFunc

; Name:        _Theme_IsTooltipVisible
; Description: Returns whether a themed tooltip is currently showing
Func _Theme_IsTooltipVisible()
    Return ($__g_Tooltip_hGUI <> 0)
EndFunc

; Name:        _Theme_ValidateHexColor
; Description: Validates and parses a hex color string
; Parameters:  $sHex - hex string (with or without "0x" prefix)
; Return:      Color as integer, or -1 if invalid
Func _Theme_ValidateHexColor($sHex)
    $sHex = StringStripWS($sHex, 3)
    If StringLeft($sHex, 2) = "0x" Or StringLeft($sHex, 2) = "0X" Then $sHex = StringTrimLeft($sHex, 2)
    If StringLen($sHex) <> 6 Or Not StringIsXDigit($sHex) Then Return -1
    Return Int("0x" & $sHex)
EndFunc

; Name:        _Theme_LoadFonts
; Description: Loads bundled font files (Fira Code) for this process.
;              Uses FR_PRIVATE so fonts are only available to this app.
;              Call once at startup before creating any GUI controls.
Func _Theme_LoadFonts()
    Local $sFontsDir = @ScriptDir & "\fonts"
    Local $aFiles[2] = ["FiraCode-Regular.ttf", "FiraCode-Bold.ttf"]
    Local $bAnyLoaded = False
    Local $i
    For $i = 0 To UBound($aFiles) - 1
        Local $sPath = $sFontsDir & "\" & $aFiles[$i]
        If FileExists($sPath) Then
            Local $aRet = DllCall("gdi32.dll", "int", "AddFontResourceExW", "wstr", $sPath, "dword", 0x10, "ptr", 0)
            If Not @error And IsArray($aRet) And $aRet[0] > 0 Then $bAnyLoaded = True
        EndIf
    Next
    $__g_Theme_bFiraLoaded = $bAnyLoaded
EndFunc

; Name:        _Theme_GetMonoFont
; Description: Returns the best available monospace font name.
;              Uses Fira Code if loaded, otherwise falls back to Consolas.
; Return:      Font name string
Func _Theme_GetMonoFont()
    If $__g_Theme_bFiraLoaded Then Return $THEME_FONT_MONO
    Return $THEME_FONT_MONO_FB
EndFunc

; Name:        _Theme_UnloadFonts
; Description: Unloads the bundled fonts. Call on shutdown.
Func _Theme_UnloadFonts()
    Local $sFontsDir = @ScriptDir & "\fonts"
    Local $aFiles[2] = ["FiraCode-Regular.ttf", "FiraCode-Bold.ttf"]
    Local $i
    For $i = 0 To UBound($aFiles) - 1
        Local $sPath = $sFontsDir & "\" & $aFiles[$i]
        If FileExists($sPath) Then
            DllCall("gdi32.dll", "bool", "RemoveFontResourceExW", "wstr", $sPath, "dword", 0x10, "ptr", 0)
        EndIf
    Next
EndFunc

; Name:        _Theme_ApplyScheme
; Description: Sets the main background color globals based on the theme name.
;              Must be called at startup after config loads, before any GUI is created.
;              Supported themes: "dark" (default), "darker", "midnight"
; Parameters:  $sTheme - theme name string
Func _Theme_ApplyScheme($sTheme)
    Local $aScheme
    Switch $sTheme
        Case "darker"
            $aScheme = $__g_Theme_aSchemeDarker
        Case "midnight"
            $aScheme = $__g_Theme_aSchemeMidnight
        Case "midday"
            $aScheme = $__g_Theme_aSchemeMidday
        Case "sunset"
            $aScheme = $__g_Theme_aSchemeSunset
        Case Else ; "dark" is default
            $aScheme = $__g_Theme_aSchemeDark
    EndSwitch
    $THEME_BG_MAIN   = $aScheme[0]
    $THEME_BG_POPUP  = $aScheme[1]
    $THEME_BG_INPUT  = $aScheme[2]
    $THEME_BG_HOVER  = $aScheme[3]
    $THEME_FG_PRIMARY = $aScheme[4]
    $THEME_FG_TEXT    = $aScheme[5]
    $THEME_FG_MENU    = $aScheme[6]
    $THEME_FG_NORMAL  = $aScheme[7]
    $THEME_FG_DIM     = $aScheme[8]
    $THEME_FG_LABEL   = $aScheme[9]
EndFunc

; Name:        _Theme_GetAvailableSchemes
; Description: Returns a pipe-delimited string of available theme names
; Return:      String e.g. "dark|darker|midnight"
Func _Theme_GetAvailableSchemes()
    Return "dark|darker|midnight|midday|sunset"
EndFunc

; Name:        _Theme_GetSchemeColors
; Description: Returns the color array for a given theme name
; Parameters:  $sTheme - theme name
; Return:      Array [BG_MAIN, BG_POPUP, BG_INPUT, BG_HOVER] or default scheme if invalid
Func _Theme_GetSchemeColors($sTheme)
    Switch $sTheme
        Case "darker"
            Return $__g_Theme_aSchemeDarker
        Case "midnight"
            Return $__g_Theme_aSchemeMidnight
        Case "midday"
            Return $__g_Theme_aSchemeMidday
        Case "sunset"
            Return $__g_Theme_aSchemeSunset
        Case Else
            Return $__g_Theme_aSchemeDark
    EndSwitch
EndFunc

; Name:        _Theme_FlattenInput
; Description: Removes the 3D sunken border (WS_EX_CLIENTEDGE) from an input
;              control so it blends with the dark theme
; Parameters:  $idCtrl - GUICtrlCreateInput control ID
Func _Theme_FlattenInput($idCtrl)
    Local $hWnd = GUICtrlGetHandle($idCtrl)
    If $hWnd = 0 Then Return
    Local $aEx = DllCall("user32.dll", "long", "GetWindowLongW", "hwnd", $hWnd, "int", -20) ; GWL_EXSTYLE
    If @error Or Not IsArray($aEx) Then Return
    DllCall("user32.dll", "long", "SetWindowLongW", "hwnd", $hWnd, "int", -20, _
        "long", BitAND($aEx[0], BitNOT(0x200))) ; remove WS_EX_CLIENTEDGE
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hWnd, "hwnd", 0, _
        "int", 0, "int", 0, "int", 0, "int", 0, _
        "uint", BitOR(0x0001, 0x0002, 0x0004, 0x0020)) ; SWP_NOSIZE|SWP_NOMOVE|SWP_NOZORDER|SWP_FRAMECHANGED
EndFunc

; =============================================
; WIDGET COLOR-BAR ANIMATION
; =============================================
; The color bar is a thin label at the bottom of the widget, repainted on every
; desktop change. This is a non-blocking tick-driven state machine (house style, like
; _TAH_FadeTick): globals below hold the running animation, _Theme_ColorBarTick advances
; it one TimerDiff-gated step from the main loop, and it is a no-op when idle. The pure
; frame math (_Theme_ColorLerp / _Theme_EaseOutCubic / __Theme_ColorBarFrame) is headless.
;
; Modes (config, _Cfg_GetWidgetColorBarAnim): "none" instant, "grow" width sweeps 0->W
; with ease-out cubic (color set up front), "fade" background lerps from the currently
; displayed color to the target. A new set mid-flight snap-completes the running animation
; to its target, then starts fresh from that visual state (deterministic, no strobe).

Global $__g_CB_idLbl      = 0             ; attached bar control id (0 = not attached, instant only)
Global $__g_CB_iX         = 0             ; attached geometry (restored on every completed frame)
Global $__g_CB_iY         = 0
Global $__g_CB_iW         = 0
Global $__g_CB_iH         = 0
Global $__g_CB_bActive    = False         ; an animation is running
Global $__g_CB_sMode      = "none"        ; running animation mode: none|grow|fade
Global $__g_CB_iFromColor = $THEME_BG_MAIN ; fade start color
Global $__g_CB_iToColor   = $THEME_BG_MAIN ; target color
Global $__g_CB_iBgColor   = $THEME_BG_MAIN ; the "no color" fill (today $THEME_BG_MAIN)
Global $__g_CB_iCurColor  = $THEME_BG_MAIN ; currently displayed color (module-tracked, fade source)
Global $__g_CB_iDurationMs = 300          ; this animation's duration
Global $__g_CB_hTimer     = 0             ; animation start (elapsed = TimerDiff)
Global $__g_CB_hStepTimer = 0             ; per-step throttle timer (0 = apply next tick immediately)

; ~16 ms step gate: a 300 ms animation is ~19 repaints of a 2-10 px label — negligible.
Global Const $__CB_STEP_MS = 16

; Name:        _Theme_ColorLerp
; Description: PURE per-channel RGB linear interpolation between two 0xRRGGBB colors.
;              $fT is clamped to [0,1]; each channel is rounded independently so the
;              endpoints reproduce $iFrom (t=0) and $iTo (t=1) exactly. Headless.
; Parameters:  $iFrom - start color (0xRRGGBB)
;              $iTo   - end color (0xRRGGBB)
;              $fT    - interpolation fraction 0..1
; Return:      Interpolated color (0xRRGGBB)
Func _Theme_ColorLerp($iFrom, $iTo, $fT)
    If $fT < 0 Then $fT = 0
    If $fT > 1 Then $fT = 1
    Local $iFR = BitAND(BitShift($iFrom, 16), 0xFF)
    Local $iFG = BitAND(BitShift($iFrom, 8), 0xFF)
    Local $iFB = BitAND($iFrom, 0xFF)
    Local $iTR = BitAND(BitShift($iTo, 16), 0xFF)
    Local $iTG = BitAND(BitShift($iTo, 8), 0xFF)
    Local $iTB = BitAND($iTo, 0xFF)
    Local $iR = Int(Round($iFR + ($iTR - $iFR) * $fT))
    Local $iG = Int(Round($iFG + ($iTG - $iFG) * $fT))
    Local $iB = Int(Round($iFB + ($iTB - $iFB) * $fT))
    Return BitOR(BitShift($iR, -16), BitShift($iG, -8), $iB)
EndFunc

; Name:        _Theme_EaseOutCubic
; Description: PURE ease-out cubic easing: 1-(1-t)^3. Maps [0,1]->[0,1], monotonically
;              increasing, with 0->0 and 1->1. Fast start, gentle settle — the tasteful
;              default for the grow sweep. Input is clamped to [0,1]. Headless.
; Parameters:  $fT - normalized time 0..1
; Return:      Eased fraction 0..1
Func _Theme_EaseOutCubic($fT)
    If $fT < 0 Then $fT = 0
    If $fT > 1 Then $fT = 1
    Local $fInv = 1 - $fT
    Return 1 - ($fInv * $fInv * $fInv)
EndFunc

; Name:        __Theme_ColorBarFrame
; Description: PURE frame calculator — given the mode and elapsed/total time, returns the
;              [width, color] the bar should show for this frame. "grow" eases the width
;              0->$iW with a constant target color; "fade" holds full width and lerps the
;              color from->to; "none" is the settled full-width target. $iDurationMs<=0 is
;              treated as fully elapsed (final frame). Headless.
; Parameters:  $sMode      - none|grow|fade
;              $iElapsedMs - time since the animation started
;              $iDurationMs- total animation duration
;              $iW         - attached bar width (full)
;              $iFromColor - fade source color
;              $iToColor   - target color
; Return:      [0]=width (px, 0..$iW), [1]=color (0xRRGGBB)
Func __Theme_ColorBarFrame($sMode, $iElapsedMs, $iDurationMs, $iW, $iFromColor, $iToColor)
    Local $aOut[2]
    Local $fT
    If $iDurationMs <= 0 Then
        $fT = 1
    Else
        $fT = $iElapsedMs / $iDurationMs
    EndIf
    If $fT < 0 Then $fT = 0
    If $fT > 1 Then $fT = 1

    Switch $sMode
        Case "grow"
            Local $iWidth = Int(Round(_Theme_EaseOutCubic($fT) * $iW))
            If $iWidth < 0 Then $iWidth = 0
            If $iWidth > $iW Then $iWidth = $iW
            $aOut[0] = $iWidth
            $aOut[1] = $iToColor
        Case "fade"
            $aOut[0] = $iW
            $aOut[1] = _Theme_ColorLerp($iFromColor, $iToColor, $fT)
        Case Else ; "none"
            $aOut[0] = $iW
            $aOut[1] = $iToColor
    EndSwitch
    Return $aOut
EndFunc

; Name:        _Theme_ColorBarAttach
; Description: Registers the color-bar label control and its geometry with the animator.
;              Call after the widget's bar control is created, and again on live-apply if
;              the geometry changes. Resets any in-flight animation (geometry is the anchor
;              every frame restores to) and seeds the tracked displayed color to the "no
;              color" fill so the first _Theme_ColorBarSet has a sane fade source.
; Parameters:  $idLbl - color-bar label control id
;              $iX,$iY,$iW,$iH - the bar's exact attached geometry
Func _Theme_ColorBarAttach($idLbl, $iX, $iY, $iW, $iH)
    $__g_CB_idLbl = $idLbl
    $__g_CB_iX = $iX
    $__g_CB_iY = $iY
    $__g_CB_iW = $iW
    $__g_CB_iH = $iH
    $__g_CB_bActive = False
    $__g_CB_sMode = "none"
    $__g_CB_hStepTimer = 0
    $__g_CB_iCurColor = $THEME_BG_MAIN
EndFunc

; Name:        __Theme_ColorBarSetWidth
; Description: Repositions the bar label to the given width at the attached x/y/height.
;              GUICtrlSetPos on a hidden GUI is safe (the widget may be hidden by TAH
;              mid-animation). No-op when unattached.
Func __Theme_ColorBarSetWidth($iWidth)
    If $__g_CB_idLbl = 0 Then Return
    GUICtrlSetPos($__g_CB_idLbl, $__g_CB_iX, $__g_CB_iY, $iWidth, $__g_CB_iH)
EndFunc

; Name:        __Theme_ColorBarSnap
; Description: Instantly settles the bar to $iColor at full attached width, quiesces the
;              state machine, and records the displayed color. This is both the instant
;              path and the "final frame" / snap-complete path, so completion always
;              restores the exact attached geometry.
Func __Theme_ColorBarSnap($iColor)
    $__g_CB_bActive = False
    $__g_CB_sMode = "none"
    If $__g_CB_idLbl <> 0 Then
        __Theme_ColorBarSetWidth($__g_CB_iW)
        GUICtrlSetBkColor($__g_CB_idLbl, $iColor)
    EndIf
    $__g_CB_iCurColor = $iColor
EndFunc

; Name:        _Theme_ColorBarSet
; Description: Sets the color bar to $iColor. Instant GUICtrlSetBkColor (today's behavior)
;              when not attached, animations are off, mode is "none", $bAnimate is False,
;              the bar has zero width, the duration is degenerate, or the target already
;              matches what's shown. Otherwise starts the grow or fade state machine toward
;              $iColor. A set that arrives mid-animation snap-completes the running one to
;              its target first, then starts fresh from the current visual state.
; Parameters:  $iColor   - target color (0xRRGGBB); already resolved by the caller (equals
;                          $iBgColor in the "no color" case)
;              $iBgColor - the "no color" fill, today $THEME_BG_MAIN
;              $bAnimate - False forces the instant path (init / settings-apply)
Func _Theme_ColorBarSet($iColor, $iBgColor = $THEME_BG_MAIN, $bAnimate = True)
    $__g_CB_iBgColor = $iBgColor

    ; Not attached: the module owns no control — just track the color for callers/tests.
    If $__g_CB_idLbl = 0 Then
        $__g_CB_bActive = False
        $__g_CB_iCurColor = $iColor
        Return
    EndIf

    Local $sMode = _Cfg_GetWidgetColorBarAnim()

    ; Instant path — byte-for-byte today's behavior.
    If Not $bAnimate Or $sMode = "none" Or Not _Cfg_GetAnimationsEnabled() _
            Or $__g_CB_iW <= 0 Or $iColor = $__g_CB_iCurColor Then
        __Theme_ColorBarSnap($iColor)
        Return
    EndIf

    ; Mid-flight retrigger: snap-complete the old animation, then start fresh.
    If $__g_CB_bActive Then __Theme_ColorBarSnap($__g_CB_iToColor)

    Local $iDuration = _Cfg_GetWidgetColorBarAnimDuration()
    If $iDuration < 1 Then
        __Theme_ColorBarSnap($iColor)
        Return
    EndIf

    $__g_CB_sMode = $sMode
    $__g_CB_iFromColor = $__g_CB_iCurColor
    $__g_CB_iToColor = $iColor
    $__g_CB_iDurationMs = $iDuration
    $__g_CB_bActive = True
    $__g_CB_hTimer = TimerInit()
    $__g_CB_hStepTimer = 0 ; first tick applies immediately

    ; Grow: set the target color up front and start from width 0.
    ; Fade: keep full width; the tick lerps the color from the current displayed value.
    If $sMode = "grow" Then
        GUICtrlSetBkColor($__g_CB_idLbl, $iColor)
        __Theme_ColorBarSetWidth(0)
        $__g_CB_iCurColor = $iColor
    EndIf
EndFunc

; Name:        _Theme_ColorBarTick
; Description: Advances the color-bar animation one TimerDiff-gated (~16 ms) step. No-op
;              when idle. Call from _ProcessTimersAndSleep. On the final frame it snaps to
;              the exact attached geometry + target color and quiesces.
Func _Theme_ColorBarTick()
    If Not $__g_CB_bActive Then Return
    If $__g_CB_idLbl = 0 Then
        $__g_CB_bActive = False
        Return
    EndIf
    If $__g_CB_hStepTimer <> 0 And TimerDiff($__g_CB_hStepTimer) < $__CB_STEP_MS Then Return
    $__g_CB_hStepTimer = TimerInit()

    Local $iElapsed = TimerDiff($__g_CB_hTimer)
    If $iElapsed >= $__g_CB_iDurationMs Then
        __Theme_ColorBarSnap($__g_CB_iToColor)
        Return
    EndIf

    Local $aFrame = __Theme_ColorBarFrame($__g_CB_sMode, $iElapsed, $__g_CB_iDurationMs, _
            $__g_CB_iW, $__g_CB_iFromColor, $__g_CB_iToColor)
    Switch $__g_CB_sMode
        Case "grow"
            __Theme_ColorBarSetWidth($aFrame[0])
            $__g_CB_iCurColor = $__g_CB_iToColor
        Case "fade"
            GUICtrlSetBkColor($__g_CB_idLbl, $aFrame[1])
            $__g_CB_iCurColor = $aFrame[1]
    EndSwitch
EndFunc

; Name:        _Theme_ColorBarIsAnimating
; Description: True while a color-bar animation is running (OR-ed into the main loop's
;              fast 5 ms sleep tier so the sweep stays smooth).
Func _Theme_ColorBarIsAnimating()
    Return $__g_CB_bActive
EndFunc
