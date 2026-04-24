#include-once
#include "Theme.au3"
#include "Config.au3"

; Extern globals from main script (declared here to suppress Au3Check warnings)
Global $iDesktop

; #INDEX# =======================================================
; Title .........: ContextMenu
; Description ....: Dark-themed right-click context menu for the desktop switcher widget
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_CM_hGUI       = 0
Global $__g_CM_bVisible   = False
Global $__g_CM_iEditID    = 0
Global $__g_CM_iSetColorID = 0
Global $__g_CM_iToggleID  = 0
Global $__g_CM_iGatherID  = 0
Global $__g_CM_iAddID     = 0
Global $__g_CM_iDeleteID  = 0
Global $__g_CM_iAboutID   = 0
Global $__g_CM_iSettingsID = 0
Global $__g_CM_iQuitID    = 0
Global $__g_CM_iCrashID   = 0
Global $__g_CM_iPinID     = 0
Global $__g_CM_iWinListID = 0
Global $__g_CM_iCarouselID = 0
Global $__g_CM_iHovered   = 0
Global $__g_CM_hHideTimer = 0
Global $__g_CM_bHideArmed = False

; #FUNCTIONS# ===================================================

; Name:        _CM_Show
; Description: Creates and shows the themed context menu above the taskbar
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $bListVisible - whether the desktop list is currently showing
Func _CM_Show($iTaskbarY, $bListVisible)
    Local $iMenuW = 170
    Local $iSepH = 1
    Local $iItemCount = 8
    If _Cfg_GetDesktopColorsEnabled() Then $iItemCount += 1
    If _Cfg_GetPinningEnabled() Then $iItemCount += 1
    If _Cfg_GetWindowListEnabled() Then $iItemCount += 1
    If _Cfg_GetDebugMode() Then $iItemCount += 1
    If _Cfg_GetCarouselEnabled() And _Cfg_GetCarouselShowInMenu() Then $iItemCount += 1
    Local $iMenuH = $iItemCount * $THEME_MENU_ITEM_H + 2 * $iSepH + 20
    Local $iMenuX = 0
    Local $iMenuY = $iTaskbarY - $iMenuH

    $__g_CM_hGUI = _Theme_CreatePopup("Menu", $iMenuW, $iMenuH, $iMenuX, $iMenuY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)

    Local $iY = 4

    $__g_CM_iEditID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_edit_label", "Edit Label"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    If _Cfg_GetDesktopColorsEnabled() Then
        $__g_CM_iSetColorID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_set_color", "Set Color") & "  " & ChrW(0x25B6), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    Local $sToggle = "  " & _i18n("ContextMenu.cm_pin_list", "Pin Desktop List")
    If _DL_IsPinned() Then $sToggle = "  " & _i18n("ContextMenu.cm_unpin_list", "Unpin Desktop List")
    $__g_CM_iToggleID = _Theme_CreateMenuItem($sToggle, 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_CM_iGatherID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_gather_windows", "Pull All Windows Here"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    If _Cfg_GetPinningEnabled() Then
        $__g_CM_iPinID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_pin_window", "Pin Active Window"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    If _Cfg_GetWindowListEnabled() Then
        $__g_CM_iWinListID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_window_list", "Window List"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    If _Cfg_GetCarouselEnabled() And _Cfg_GetCarouselShowInMenu() Then
        Local $sCarouselLbl = "  " & _i18n("ContextMenu.cm_toggle_carousel", "Toggle Carousel")
        If _CarouselIsActive() Then $sCarouselLbl &= "  " & ChrW(0x25CF)
        $__g_CM_iCarouselID = _Theme_CreateMenuItem($sCarouselLbl, 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    ; Separator
    GUICtrlCreateLabel("", 8, $iY + 2, $iMenuW - 16, $iSepH)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += $iSepH + 4

    $__g_CM_iAddID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_add_desktop", "Add Desktop"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_CM_iDeleteID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_delete_desktop", "Delete Desktop"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    GUICtrlSetColor($__g_CM_iDeleteID, 0xCC6666)
    $iY += $THEME_MENU_ITEM_H

    ; Separator
    GUICtrlCreateLabel("", 8, $iY + 2, $iMenuW - 16, $iSepH)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += $iSepH + 4

    $__g_CM_iAboutID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_about", "About"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_CM_iSettingsID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_settings", "Settings"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    If _Cfg_GetDebugMode() Then
        $__g_CM_iCrashID = _Theme_CreateMenuItem("  " & ChrW(0x26A0) & " " & _i18n("ContextMenu.cm_trigger_crash", "Trigger Crash"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        GUICtrlSetColor($__g_CM_iCrashID, 0xFF5555)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    $__g_CM_iQuitID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_quit", "Quit"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)

    _Theme_FadeIn($__g_CM_hGUI, $THEME_ALPHA_MENU, "menu")
    $__g_CM_bVisible = True
EndFunc

; Name:        _CM_Destroy
; Description: Destroys the context menu GUI and resets state
Func _CM_Destroy()
    If $__g_CM_hGUI <> 0 And _DL_ColorPickerIsVisible() Then
        _DL_ColorPickerDestroy()
    EndIf
    If $__g_CM_hGUI <> 0 Then
        _Theme_FadeOut($__g_CM_hGUI, "menu")
        $__g_CM_hGUI = 0
    EndIf
    $__g_CM_bVisible = False
    $__g_CM_iEditID = 0
    $__g_CM_iSetColorID = 0
    $__g_CM_iToggleID = 0
    $__g_CM_iGatherID = 0
    $__g_CM_iAddID = 0
    $__g_CM_iDeleteID = 0
    $__g_CM_iAboutID = 0
    $__g_CM_iSettingsID = 0
    $__g_CM_iQuitID = 0
    $__g_CM_iCrashID = 0
    $__g_CM_iPinID = 0
    $__g_CM_iWinListID = 0
    $__g_CM_iCarouselID = 0
    $__g_CM_iHovered = 0
    $__g_CM_bHideArmed = False
EndFunc

; Name:        _CM_CheckHover
; Description: Updates hover highlighting on menu items. Call from main loop.
; Parameters:  $iTargetDesktop - current desktop index for Set Color submenu
Func _CM_CheckHover($iTargetDesktop = 0)
    If Not $__g_CM_bVisible Or $__g_CM_hGUI = 0 Then Return
    Local $aCursor = GUIGetCursorInfo($__g_CM_hGUI)
    If @error Then
        If $__g_CM_iHovered <> 0 Then
            _Theme_RemoveHover($__g_CM_iHovered, $THEME_FG_MENU)
            $__g_CM_iHovered = 0
        EndIf
        Return
    EndIf

    Local $iFound = 0
    If $aCursor[4] = $__g_CM_iEditID Then $iFound = $__g_CM_iEditID
    If $__g_CM_iSetColorID <> 0 And $aCursor[4] = $__g_CM_iSetColorID Then $iFound = $__g_CM_iSetColorID
    If $aCursor[4] = $__g_CM_iToggleID Then $iFound = $__g_CM_iToggleID
    If $aCursor[4] = $__g_CM_iGatherID Then $iFound = $__g_CM_iGatherID
    If $__g_CM_iPinID <> 0 And $aCursor[4] = $__g_CM_iPinID Then $iFound = $__g_CM_iPinID
    If $__g_CM_iWinListID <> 0 And $aCursor[4] = $__g_CM_iWinListID Then $iFound = $__g_CM_iWinListID
    If $aCursor[4] = $__g_CM_iAddID Then $iFound = $__g_CM_iAddID
    If $aCursor[4] = $__g_CM_iDeleteID Then $iFound = $__g_CM_iDeleteID
    If $aCursor[4] = $__g_CM_iAboutID Then $iFound = $__g_CM_iAboutID
    If $aCursor[4] = $__g_CM_iSettingsID Then $iFound = $__g_CM_iSettingsID
    If $__g_CM_iCarouselID <> 0 And $aCursor[4] = $__g_CM_iCarouselID Then $iFound = $__g_CM_iCarouselID
    If $__g_CM_iCrashID <> 0 And $aCursor[4] = $__g_CM_iCrashID Then $iFound = $__g_CM_iCrashID
    If $aCursor[4] = $__g_CM_iQuitID Then $iFound = $__g_CM_iQuitID

    If $iFound = $__g_CM_iHovered Then Return

    If $__g_CM_iHovered <> 0 Then
        Local $iFg = $THEME_FG_MENU
        If $__g_CM_iHovered = $__g_CM_iDeleteID Then $iFg = 0xCC6666
        If $__g_CM_iHovered = $__g_CM_iCrashID Then $iFg = 0xFF5555
        _Theme_RemoveHover($__g_CM_iHovered, $iFg)
    EndIf

    $__g_CM_iHovered = $iFound
    If $__g_CM_iHovered <> 0 Then
        _Theme_ApplyHover($__g_CM_iHovered, $THEME_FG_WHITE, $THEME_BG_HOVER)
    EndIf

    ; Auto-show color picker on hover over "Set Color"
    If $iFound = $__g_CM_iSetColorID And $__g_CM_iSetColorID <> 0 And $iTargetDesktop > 0 And Not _DL_ColorPickerIsVisible() Then
        _DL_ColorPickerShow($iTargetDesktop, $__g_CM_hGUI, $__g_CM_iSetColorID)
    ElseIf $iFound <> $__g_CM_iSetColorID And _DL_ColorPickerIsVisible() Then
        If Not _Theme_IsCursorOverWindow(_DL_ColorPickerGetGUI()) Then
            _DL_ColorPickerDestroy()
        EndIf
    EndIf
EndFunc

; Name:        _CM_HandleClick
; Description: Processes a GUI message and returns the action
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      "edit", "toggle_list", "gather", "add", "delete", "about", "settings", "quit", or ""
Func _CM_HandleClick($msg)
    If $msg = $__g_CM_iEditID Then Return "edit"
    If $__g_CM_iSetColorID <> 0 And $msg = $__g_CM_iSetColorID Then Return "set_color"
    If $msg = $__g_CM_iToggleID Then Return "toggle_list"
    If $msg = $__g_CM_iGatherID Then Return "gather"
    If $__g_CM_iPinID <> 0 And $msg = $__g_CM_iPinID Then Return "pin_window"
    If $__g_CM_iWinListID <> 0 And $msg = $__g_CM_iWinListID Then Return "window_list"
    If $msg = $__g_CM_iAddID Then Return "add"
    If $msg = $__g_CM_iDeleteID Then Return "delete"
    If $msg = $__g_CM_iAboutID Then Return "about"
    If $msg = $__g_CM_iSettingsID Then Return "settings"
    If $__g_CM_iCrashID <> 0 And $msg = $__g_CM_iCrashID Then Return "crash"
    If $__g_CM_iCarouselID <> 0 And $msg = $__g_CM_iCarouselID Then Return "carousel"
    If $msg = $__g_CM_iQuitID Then Return "quit"
    Return ""
EndFunc

; Name:        _CM_IsVisible
; Description: Returns whether the context menu is currently visible
; Return:      True/False
Func _CM_IsVisible()
    Return $__g_CM_bVisible
EndFunc

; Name:        _CM_GetEditID
; Description: Returns the Edit menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetEditID()
    Return $__g_CM_iEditID
EndFunc

; Name:        _CM_GetToggleID
; Description: Returns the Toggle menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetToggleID()
    Return $__g_CM_iToggleID
EndFunc

; Name:        _CM_GetAddID
; Description: Returns the Add Desktop menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetAddID()
    Return $__g_CM_iAddID
EndFunc

; Name:        _CM_GetSetColorID
; Description: Returns the Set Color menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetSetColorID()
    Return $__g_CM_iSetColorID
EndFunc

; Name:        _CM_GetGatherID
; Description: Returns the Gather Windows menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetGatherID()
    Return $__g_CM_iGatherID
EndFunc

; Name:        _CM_GetDeleteID
; Description: Returns the Delete Desktop menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetDeleteID()
    Return $__g_CM_iDeleteID
EndFunc

; Name:        _CM_GetAboutID
; Description: Returns the About menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetAboutID()
    Return $__g_CM_iAboutID
EndFunc

; Name:        _CM_GetQuitID
; Description: Returns the Quit menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetQuitID()
    Return $__g_CM_iQuitID
EndFunc

; Name:        _CM_GetSettingsID
; Description: Returns the Settings menu item control ID (for testing)
; Return:      Control ID or 0
Func _CM_GetSettingsID()
    Return $__g_CM_iSettingsID
EndFunc

; Name:        _CM_CheckAutoHide
; Description: Checks if the context menu should auto-dismiss (cursor outside menu)
; Parameters:  $hMainGUI - handle to the main widget GUI
; Return:      True if the menu was dismissed, False otherwise
Func _CM_CheckAutoHide($hMainGUI)
    If Not $__g_CM_bVisible Or $__g_CM_hGUI = 0 Then Return False
    If _Theme_IsCursorOverWindow($__g_CM_hGUI) Or _Theme_IsCursorOverWindow($hMainGUI) Or _
       (_DL_ColorPickerIsVisible() And (_Theme_IsCursorOverWindow(_DL_ColorPickerGetGUI()) Or _
        _Theme_IsCursorInWindowBridge($__g_CM_hGUI, _DL_ColorPickerGetGUI()))) Then
        $__g_CM_bHideArmed = False
        Return False
    EndIf
    If Not $__g_CM_bHideArmed Then
        $__g_CM_bHideArmed = True
        $__g_CM_hHideTimer = TimerInit()
        Return False
    EndIf
    If TimerDiff($__g_CM_hHideTimer) < _Cfg_GetCmAutoHideDelay() Then Return False
    _CM_Destroy()
    Return True
EndFunc

; Name:        _CM_GetGUI
; Description: Returns the context menu GUI handle
; Return:      GUI handle or 0
Func _CM_GetGUI()
    Return $__g_CM_hGUI
EndFunc
