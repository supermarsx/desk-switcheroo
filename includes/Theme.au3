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

; -- Background colors --
Global Const $THEME_BG_MAIN       = 0x191919
Global Const $THEME_BG_POPUP      = 0x1E1E1E
Global Const $THEME_BG_INPUT      = 0x2A2A2A
Global Const $THEME_BG_HOVER      = 0x333333
Global Const $THEME_BG_ACTIVE     = 0x484848
Global Const $THEME_BG_ARROW_HOV  = 0x3A3A4A
Global Const $THEME_BG_BORDER     = 0x444444
Global Const $THEME_BG_BTN_HOV    = 0x4A4A4A
Global Const $THEME_BG_SEPARATOR  = 0x3A3A3A
Global Const $THEME_BG_DROP_TARGET = 0x2A3A5A

; -- Foreground colors --
Global Const $THEME_FG_PRIMARY    = 0xE8E8E8
Global Const $THEME_FG_TEXT       = 0xE0E0E0
Global Const $THEME_FG_MENU       = 0xDDDDDD
Global Const $THEME_FG_NORMAL     = 0xCCCCCC
Global Const $THEME_FG_DIM        = 0xAAAAAA
Global Const $THEME_FG_LABEL      = 0x888888
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

; -- Timer intervals (ms) --
Global Const $THEME_TIMER_TOPMOST  = 300
Global Const $THEME_TIMER_POLL     = 400
Global Const $THEME_TIMER_BOUNCE   = 500
Global Const $THEME_TIMER_TEMPLIST = 3000

; #FUNCTIONS# ===================================================

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
    Local $idYes = GUICtrlCreateLabel("Yes", 14, $iBtnY, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idYes, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idYes, $THEME_FG_MENU)
    GUICtrlSetBkColor($idYes, $THEME_BG_HOVER)
    GUICtrlSetCursor($idYes, 0)

    ; No button
    Local $idNo = GUICtrlCreateLabel("No", 14 + $iBtnW + 10, $iBtnY, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idNo, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idNo, $THEME_FG_MENU)
    GUICtrlSetBkColor($idNo, $THEME_BG_HOVER)
    GUICtrlSetCursor($idNo, 0)

    GUISetState(@SW_SHOW, $hDlg)

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
        If Not @error And BitAND($retEnter[0], 0x8000) <> 0 Then
            $bResult = True
            ExitLoop
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And BitAND($retEsc[0], 0x8000) <> 0 Then
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

    GUIDelete($hDlg)
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
    Local $idClose = GUICtrlCreateLabel("Close", ($iDlgW - $iBtnW) / 2, $iDlgH - 36, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($idClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($idClose, 0)

    GUISetState(@SW_SHOW, $hDlg)

    Local $iHovered = 0
    Local $hTimer = TimerInit()
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            If $aMsg[0] = $GUI_EVENT_CLOSE Or $aMsg[0] = $idClose Then ExitLoop
        EndIf

        ; Keyboard: Enter or Escape closes
        Local $retKey = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And BitAND($retKey[0], 0x8000) <> 0 Then ExitLoop
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

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

    GUIDelete($hDlg)
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

; Name:        _Theme_Toast
; Description: Shows a small non-blocking toast notification below the main widget.
;              Call _Theme_ToastTick() from the main loop to handle fade-out.
; Parameters:  $sText - message text
;              $iX - X position (default: 0)
;              $iY - Y position below widget
;              $iDuration - how long to show in ms (default: 2000)
;              $iBgColor - background color (default: $THEME_BG_POPUP)
;              $iFgColor - text color (default: $THEME_FG_PRIMARY)
Func _Theme_Toast($sText, $iX, $iY, $iDuration = 2000, $iBgColor = -1, $iFgColor = -1)
    If $iBgColor = -1 Then $iBgColor = $THEME_BG_POPUP
    If $iFgColor = -1 Then $iFgColor = $THEME_FG_PRIMARY

    ; Destroy previous toast if still showing
    _Theme_ToastDestroy()

    Local $iW = 10 + StringLen($sText) * 7
    If $iW < 100 Then $iW = 100
    If $iW > 300 Then $iW = 300
    Local $iH = 24

    $__g_Toast_hGUI = GUICreate("Toast", $iW, $iH, $iX, $iY, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
    GUISetBkColor($iBgColor)

    GUICtrlCreateLabel($sText, 0, 0, $iW, $iH, BitOR($SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $iFgColor)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $__g_Toast_iAlpha = 220
    _WinAPI_SetLayeredWindowAttributes($__g_Toast_hGUI, 0, $__g_Toast_iAlpha, $LWA_ALPHA)
    GUISetState(@SW_SHOWNOACTIVATE, $__g_Toast_hGUI)

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

    ; Fade-out phase (300ms)
    Local $iFadeElapsed = $iElapsed - $__g_Toast_iDuration
    If $iFadeElapsed < 300 Then
        Local $iNewAlpha = 220 - Int(220 * $iFadeElapsed / 300)
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

; Name:        _Theme_LoadFonts
; Description: Loads bundled font files (Fira Code) for this process.
;              Uses FR_PRIVATE so fonts are only available to this app.
;              Call once at startup before creating any GUI controls.
Func _Theme_LoadFonts()
    Local $sFontsDir = @ScriptDir & "\fonts"
    Local $aFiles[2] = ["FiraCode-Regular.ttf", "FiraCode-Bold.ttf"]
    For $i = 0 To UBound($aFiles) - 1
        Local $sPath = $sFontsDir & "\" & $aFiles[$i]
        If FileExists($sPath) Then
            DllCall("gdi32.dll", "int", "AddFontResourceExW", "wstr", $sPath, "dword", 0x10, "ptr", 0)
        EndIf
    Next
EndFunc

; Name:        _Theme_UnloadFonts
; Description: Unloads the bundled fonts. Call on shutdown.
Func _Theme_UnloadFonts()
    Local $sFontsDir = @ScriptDir & "\fonts"
    Local $aFiles[2] = ["FiraCode-Regular.ttf", "FiraCode-Bold.ttf"]
    For $i = 0 To UBound($aFiles) - 1
        Local $sPath = $sFontsDir & "\" & $aFiles[$i]
        If FileExists($sPath) Then
            DllCall("gdi32.dll", "bool", "RemoveFontResourceExW", "wstr", $sPath, "dword", 0x10, "ptr", 0)
        EndIf
    Next
EndFunc
