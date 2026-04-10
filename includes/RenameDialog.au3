#include-once
#include <EditConstants.au3>
#include "Theme.au3"
#include "Labels.au3"

; #INDEX# =======================================================
; Title .........: RenameDialog
; Description ....: Dark-themed rename dialog for editing desktop labels
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_RD_hGUI          = 0
Global $__g_RD_bVisible      = False
Global $__g_RD_iInputField   = 0
Global $__g_RD_iBtnOk        = 0
Global $__g_RD_iBtnCancel    = 0
Global $__g_RD_iHovered      = 0
Global $__g_RD_bCancelled    = False
Global $__g_RD_hBrush        = 0

; #FUNCTIONS# ===================================================

; Name:        _RD_Init
; Description: Creates the GDI brush for input field styling. Call once at startup.
Func _RD_Init()
    Local $aResult = DllCall("gdi32.dll", "handle", "CreateSolidBrush", "dword", $THEME_BG_INPUT)
    If @error Or Not IsArray($aResult) Then
        $__g_RD_hBrush = 0
    Else
        $__g_RD_hBrush = $aResult[0]
    EndIf
EndFunc

; Name:        _RD_Show
; Description: Creates and shows the rename dialog
; Parameters:  $iDesktop - current desktop index (1-based)
;              $iTaskbarY - Y position of the taskbar
Func _RD_Show($iDesktop, $iTaskbarY)
    If $__g_RD_bVisible Then Return
    Local $sOld = _Labels_Load($iDesktop)

    Local $iDlgW = 280, $iDlgH = 110
    Local $iDlgX = 20
    Local $iDlgY = $iTaskbarY - $iDlgH - 10

    $__g_RD_hGUI = _Theme_CreatePopup("Rename", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Title
    GUICtrlCreateLabel("Label for Desktop " & $iDesktop, 12, 10, $iDlgW - 24, 18)
    GUICtrlSetFont(-1, 10, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Dark border around input
    GUICtrlCreateLabel("", 11, 35, $iDlgW - 22, 28)
    GUICtrlSetBkColor(-1, $THEME_BG_BORDER)

    ; Input field
    $__g_RD_iInputField = GUICtrlCreateInput($sOld, 12, 36, $iDlgW - 24, 26, $ES_AUTOHSCROLL)
    GUICtrlSetFont($__g_RD_iInputField, 10, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_RD_iInputField, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_RD_iInputField, $THEME_BG_INPUT)

    ; OK button
    $__g_RD_iBtnOk = GUICtrlCreateLabel("OK", 12, 74, 56, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_RD_iBtnOk, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_RD_iBtnOk, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_RD_iBtnOk, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_RD_iBtnOk, 0)

    ; Cancel button
    $__g_RD_iBtnCancel = GUICtrlCreateLabel("Cancel", 76, 74, 56, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_RD_iBtnCancel, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_RD_iBtnCancel, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_RD_iBtnCancel, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_RD_iBtnCancel, 0)

    GUISetState(@SW_SHOW, $__g_RD_hGUI)
    GUICtrlSetState($__g_RD_iInputField, $GUI_FOCUS)
    $__g_RD_bVisible = True
    $__g_RD_iHovered = 0
    $__g_RD_bCancelled = False
EndFunc

; Name:        _RD_Submit
; Description: Reads the input, saves the label, and destroys the dialog
; Parameters:  $iDesktop - desktop index to save label for (1-based)
; Return:      The new label string
Func _RD_Submit($iDesktop)
    If Not $__g_RD_bVisible Or $__g_RD_bCancelled Then Return ""
    Local $sResult = StringStripWS(GUICtrlRead($__g_RD_iInputField), 3)
    _RD_Destroy()
    _Labels_Save($iDesktop, $sResult)
    Return $sResult
EndFunc

; Name:        _RD_Destroy
; Description: Destroys the rename dialog and resets state
Func _RD_Destroy()
    If $__g_RD_hGUI <> 0 Then
        GUIDelete($__g_RD_hGUI)
        $__g_RD_hGUI = 0
    EndIf
    $__g_RD_bVisible = False
    $__g_RD_iInputField = 0
    $__g_RD_iBtnOk = 0
    $__g_RD_iBtnCancel = 0
    $__g_RD_iHovered = 0
EndFunc

; Name:        _RD_CheckHover
; Description: Updates hover highlighting on dialog buttons. Call from main loop.
Func _RD_CheckHover()
    If Not $__g_RD_bVisible Or $__g_RD_hGUI = 0 Then Return
    Local $aCursor = GUIGetCursorInfo($__g_RD_hGUI)
    If @error Then
        If $__g_RD_iHovered <> 0 Then
            _Theme_RemoveHover($__g_RD_iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
            $__g_RD_iHovered = 0
        EndIf
        Return
    EndIf

    Local $iFound = 0
    If $aCursor[4] = $__g_RD_iBtnOk Then $iFound = $__g_RD_iBtnOk
    If $aCursor[4] = $__g_RD_iBtnCancel Then $iFound = $__g_RD_iBtnCancel

    If $iFound = $__g_RD_iHovered Then Return

    If $__g_RD_iHovered <> 0 Then
        _Theme_RemoveHover($__g_RD_iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
    EndIf

    $__g_RD_iHovered = $iFound
    If $__g_RD_iHovered <> 0 Then
        _Theme_ApplyHover($__g_RD_iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
    EndIf
EndFunc

; Name:        _RD_HandleEvent
; Description: Processes a GUI message from the rename dialog
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      "submit", "cancel", "close", or ""
Func _RD_HandleEvent($msg)
    If $msg = $GUI_EVENT_CLOSE Then Return "close"
    If $msg = $__g_RD_iBtnOk Then Return "submit"
    If $msg = $__g_RD_iBtnCancel Then Return "cancel"
    Return ""
EndFunc

; Name:        _RD_CheckKeys
; Description: Checks for Enter/Escape key presses (non-blocking)
; Return:      "submit" for Enter, "cancel" for Escape, "" for neither
Func _RD_CheckKeys()
    If Not $__g_RD_bVisible Or $__g_RD_bCancelled Then Return ""
    Local Const $VK_RETURN = 0x0D
    Local Const $VK_ESCAPE = 0x1B
    ; Enter key
    Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_RETURN)
    If Not @error And IsArray($retEnter) And BitAND($retEnter[0], 0x8000) <> 0 Then Return "submit"
    ; Escape key
    Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_ESCAPE)
    If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then Return "cancel"
    Return ""
EndFunc

; Name:        _RD_WM_CTLCOLOREDIT
; Description: WM_CTLCOLOREDIT handler for dark input field styling.
;              Register via GUIRegisterMsg in main and delegate here.
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      Brush handle
Func _RD_WM_CTLCOLOREDIT($hWnd, $iMsg, $wParam, $lParam)
    If $__g_RD_hGUI = 0 Or $hWnd <> $__g_RD_hGUI Then Return $GUI_RUNDEFMSG
    DllCall("gdi32.dll", "int", "SetTextColor", "handle", $wParam, "dword", $THEME_FG_TEXT)
    DllCall("gdi32.dll", "int", "SetBkColor", "handle", $wParam, "dword", $THEME_BG_INPUT)
    Return $__g_RD_hBrush
EndFunc

; Name:        _RD_IsVisible
; Description: Returns whether the rename dialog is currently visible
; Return:      True/False
Func _RD_IsVisible()
    Return $__g_RD_bVisible
EndFunc

; Name:        _RD_GetGUI
; Description: Returns the rename dialog GUI handle
; Return:      GUI handle or 0
Func _RD_GetGUI()
    Return $__g_RD_hGUI
EndFunc

; Name:        _RD_GetInputField
; Description: Returns the input field control ID (for testing)
; Return:      Control ID or 0
Func _RD_GetInputField()
    Return $__g_RD_iInputField
EndFunc

; Name:        _RD_GetBtnOk
; Description: Returns the OK button control ID (for testing)
; Return:      Control ID or 0
Func _RD_GetBtnOk()
    Return $__g_RD_iBtnOk
EndFunc

; Name:        _RD_GetBtnCancel
; Description: Returns the Cancel button control ID (for testing)
; Return:      Control ID or 0
Func _RD_GetBtnCancel()
    Return $__g_RD_iBtnCancel
EndFunc

; Name:        _RD_SetCancelled
; Description: Marks the dialog as cancelled (prevents submit)
Func _RD_SetCancelled()
    $__g_RD_bCancelled = True
EndFunc

; Name:        _RD_Shutdown
; Description: Cleans up GDI resources. Call on exit.
Func _RD_Shutdown()
    If $__g_RD_hBrush <> 0 Then
        DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $__g_RD_hBrush)
        $__g_RD_hBrush = 0
    EndIf
EndFunc
