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

; #FUNCTIONS# ===================================================

; -- Tooltip registry for themed tooltips --
Global $__g_Theme_aTipIDs[200]
Global $__g_Theme_aTipTexts[200]
Global $__g_Theme_iTipCount = 0
Global $__g_Theme_iLastTipCtrl = 0

; Name:        _Theme_SetTooltip
; Description: Registers a themed tooltip for a control. The tooltip is shown
;              when _Theme_CheckTooltipHover is called and cursor is over the control.
; Parameters:  $idCtrl - control ID
;              $sText - tooltip text
Func _Theme_SetTooltip($idCtrl, $sText)
    If $__g_Theme_iTipCount >= 199 Then Return
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
    GUISetBkColor($iBgColor)
    _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iAlpha, $LWA_ALPHA)
    Return $hGUI
EndFunc

; Name:        _Theme_FadeIn
; Description: Fades a layered window from alpha 0 to target. Respects animation config.
; Parameters:  $hGUI - window handle
;              $iTargetAlpha - target opacity (default: THEME_ALPHA_POPUP)
Func _Theme_FadeIn($hGUI, $iTargetAlpha = Default)
    If $iTargetAlpha = Default Then $iTargetAlpha = $THEME_ALPHA_POPUP
    If Not _Cfg_GetAnimationsEnabled() Then
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
        GUISetState(@SW_SHOW, $hGUI)
        Return
    EndIf
    _WinAPI_SetLayeredWindowAttributes($hGUI, 0, 0, $LWA_ALPHA)
    GUISetState(@SW_SHOW, $hGUI)
    Local $iStep = _Cfg_GetFadeStep()
    Local $iSleep = _Cfg_GetFadeSleepMs()
    Local $i
    For $i = 0 To $iTargetAlpha Step $iStep
        _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $i, $LWA_ALPHA)
        Sleep($iSleep)
    Next
    _WinAPI_SetLayeredWindowAttributes($hGUI, 0, $iTargetAlpha, $LWA_ALPHA)
EndFunc

; Name:        _Theme_FadeOut
; Description: Fades a layered window from current alpha to 0 then deletes it.
; Parameters:  $hGUI - window handle (will be GUIDeleted after fade)
Func _Theme_FadeOut($hGUI)
    If $hGUI = 0 Then Return
    If Not _Cfg_GetAnimationsEnabled() Then
        GUIDelete($hGUI)
        Return
    EndIf
    Local $iAlpha = $THEME_ALPHA_POPUP
    Local $iStep = _Cfg_GetFadeStep()
    Local $iSleep = _Cfg_GetFadeSleepMs()
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

    _Theme_FadeIn($hDlg, $THEME_ALPHA_DIALOG)

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

    _Theme_FadeOut($hDlg)
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

    _Theme_FadeIn($hDlg, $THEME_ALPHA_DIALOG)

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

    _Theme_FadeOut($hDlg)
EndFunc

; Name:        _Theme_IsCursorOverWindow
; Description: Checks if the mouse cursor is over a given window
; Parameters:  $hWnd - window handle
; Return:      True if cursor is over the window, False otherwise
Func _Theme_IsCursorOverWindow($hWnd)
    If $hWnd = 0 Then Return False
    Local $aMP = MouseGetPos()
    Local $aWP = WinGetPos($hWnd)
    If @error Then Return False
    If $aMP[0] >= $aWP[0] And $aMP[0] < $aWP[0] + $aWP[2] And _
       $aMP[1] >= $aWP[1] And $aMP[1] < $aWP[1] + $aWP[3] Then Return True
    Return False
EndFunc

; =============================================
; TOAST NOTIFICATION
; =============================================

Global $__g_Toast_hGUI = 0
Global $__g_Toast_hTimer = 0
Global $__g_Toast_iDuration = 0
Global $__g_Toast_iFadeStep = 0
Global $__g_Toast_iAlpha = 0

; Toast status icon colors
Global Const $TOAST_SUCCESS = 0x4AFF7E ; green
Global Const $TOAST_ERROR   = 0xFF5555 ; red
Global Const $TOAST_WARNING = 0xFFD54A ; yellow
Global Const $TOAST_INFO    = 0x4A9EFF ; blue

; Name:        _Theme_Toast
; Description: Shows a small non-blocking toast notification with a colored status icon.
;              Call _Theme_ToastTick() from the main loop to handle fade-out.
; Parameters:  $sText - message text
;              $iX - X position
;              $iY - Y position
;              $iDuration - how long to show in ms (default: 2000)
;              $iIconColor - status icon color ($TOAST_SUCCESS/ERROR/WARNING/INFO, default: $TOAST_INFO)
Func _Theme_Toast($sText, $iX, $iY, $iDuration = 2000, $iIconColor = -1)
    If $iIconColor = -1 Then $iIconColor = $TOAST_INFO

    ; Destroy previous toast if still showing
    _Theme_ToastDestroy()

    Local $iIconW = 22
    Local $iTextW = 10 + StringLen($sText) * 7
    Local $iW = $iIconW + $iTextW
    If $iW < 120 Then $iW = 120
    If $iW > 320 Then $iW = 320
    Local $iH = 26

    $__g_Toast_hGUI = GUICreate("Toast", $iW, $iH, $iX, $iY, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
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

    $__g_Toast_iAlpha = 230
    If _Cfg_GetAnimationsEnabled() Then
        _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, 0, $LWA_ALPHA)
        GUISetState(@SW_SHOWNOACTIVATE, $__g_Toast_hGUI)
        Local $iToastStep = _Cfg_GetFadeStep()
        Local $iToastSleep = _Cfg_GetFadeSleepMs()
        Local $iTS
        For $iTS = 0 To $__g_Toast_iAlpha Step $iToastStep
            _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $iTS, $LWA_ALPHA)
            Sleep($iToastSleep)
        Next
        _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $__g_Toast_iAlpha, $LWA_ALPHA)
    Else
        _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $__g_Toast_iAlpha, $LWA_ALPHA)
        GUISetState(@SW_SHOWNOACTIVATE, $__g_Toast_hGUI)
    EndIf

    $__g_Toast_hTimer = TimerInit()
    $__g_Toast_iDuration = $iDuration
    $__g_Toast_iFadeStep = 0
EndFunc

; Name:        _Theme_ToastTick
; Description: Call from main loop. Handles fade-out and cleanup.
; Return:      True if toast is active, False if idle
Func _Theme_ToastTick()
    If $__g_Toast_hGUI = 0 Then Return False

    Local $iElapsed = TimerDiff($__g_Toast_hTimer)

    ; Visible phase
    If $iElapsed < $__g_Toast_iDuration Then Return True

    ; Fade-out phase (configurable duration)
    Local $iFadeElapsed = $iElapsed - $__g_Toast_iDuration
    Local $iFadeMs = _Cfg_GetToastFadeOutDuration()
    If $iFadeMs < 1 Then $iFadeMs = 1
    If $iFadeElapsed < $iFadeMs Then
        Local $iNewAlpha = 230 - Int(230 * $iFadeElapsed / $iFadeMs)
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
; THEMED TOOLTIP
; =============================================

Global $__g_Tooltip_hGUI = 0
Global $__g_Tooltip_hTimer = 0

; Name:        _Theme_ShowTooltip
; Description: Shows a dark-themed tooltip popup near the cursor. Non-blocking.
;              Auto-dismisses after 2.5 seconds or when cursor moves away.
;              Call _Theme_TooltipTick() from the main loop to handle auto-dismiss.
; Parameters:  $sText - tooltip text (supports multi-line via @CRLF)
;              $iX - X position (default: cursor X + 16)
;              $iY - Y position (default: cursor Y + 16)
Func _Theme_ShowTooltip($sText, $iX = -1, $iY = -1)
    _Theme_HideTooltip()

    If $iX = -1 Or $iY = -1 Then
        Local $aMP = MouseGetPos()
        If $iX = -1 Then $iX = $aMP[0] + 16
        If $iY = -1 Then $iY = $aMP[1] + 16
    EndIf

    ; Calculate size based on text
    Local $aLines = StringSplit($sText, @CRLF, 1)
    Local $iMaxLen = 0
    Local $i
    For $i = 1 To $aLines[0]
        If StringLen($aLines[$i]) > $iMaxLen Then $iMaxLen = StringLen($aLines[$i])
    Next
    Local $iFontSz = _Cfg_GetTooltipFontSize()
    Local $iCharW = Int($iFontSz * 0.75) + 1
    Local $iLineH = $iFontSz + 6
    Local $iW = $iMaxLen * $iCharW + 16
    If $iW < 80 Then $iW = 80
    If $iW > 400 Then $iW = 400
    Local $iH = $aLines[0] * $iLineH + 10
    If $iH < $iLineH + 6 Then $iH = $iLineH + 6

    ; Keep on screen
    If $iX + $iW > @DesktopWidth Then $iX = @DesktopWidth - $iW - 4
    If $iY + $iH > @DesktopHeight Then $iY = $iY - $iH - 32

    $__g_Tooltip_hGUI = GUICreate("Tooltip", $iW, $iH, $iX, $iY, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
    GUISetBkColor($THEME_BG_POPUP)
    _WinAPI_SetLayeredWindowAttributes($__g_Tooltip_hGUI, 0, 240, $LWA_ALPHA)

    GUICtrlCreateLabel($sText, 6, 4, $iW - 12, $iH - 8)
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
