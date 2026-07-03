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

; Name:        _CM_ClampToWorkArea
; Description: Pure geometry helper (side-effect free, headless-testable). Given a
;              cursor anchor, a popup size, and a monitor work rect, computes the
;              popup's top-left so it opens down-right of the cursor, flips up/left
;              when it would overflow, and always ends up fully inside the work
;              rect. Also handles a popup larger than the work area and monitors
;              with negative origins (multi-monitor).
; Parameters:  $iCurX, $iCurY - anchor point (cursor), screen coords
;              $iW, $iH - popup width and height
;              $iLeft, $iTop, $iRight, $iBottom - monitor work rect (exclusive R/B)
;              ByRef $iOutX, $iOutY - resolved top-left
Func _CM_ClampToWorkArea($iCurX, $iCurY, $iW, $iH, $iLeft, $iTop, $iRight, $iBottom, ByRef $iOutX, ByRef $iOutY)
    ; Preferred placement: down-right of the cursor.
    Local $iX = $iCurX
    Local $iY = $iCurY
    ; Flip to the other side of the cursor when the preferred side overflows.
    If $iX + $iW > $iRight Then $iX = $iCurX - $iW
    If $iY + $iH > $iBottom Then $iY = $iCurY - $iH
    ; Final clamp: covers post-flip overflow and popups larger than the work area.
    If $iX + $iW > $iRight Then $iX = $iRight - $iW
    If $iX < $iLeft Then $iX = $iLeft
    If $iY + $iH > $iBottom Then $iY = $iBottom - $iH
    If $iY < $iTop Then $iY = $iTop
    $iOutX = $iX
    $iOutY = $iY
EndFunc

; Name:        _CM_GetWorkArea
; Description: Resolves the work area (screen minus taskbar) of the monitor that
;              contains a screen point, via MonitorFromPoint + GetMonitorInfo.
;              Handles multi-monitor layouts including negative coordinates. Falls
;              back to the primary desktop above the taskbar when the monitor query
;              is unavailable.
; Parameters:  $iX, $iY - screen point (may be negative on multi-monitor)
;              ByRef $iLeft, $iTop, $iRight, $iBottom - resolved work rect
;              $iTaskbarY - fallback bottom bound, used only when the query fails
Func _CM_GetWorkArea($iX, $iY, ByRef $iLeft, ByRef $iTop, ByRef $iRight, ByRef $iBottom, $iTaskbarY = 0)
    ; Fallback: primary monitor, above the taskbar when a sane taskbar Y is given.
    $iLeft = 0
    $iTop = 0
    $iRight = @DesktopWidth
    $iBottom = @DesktopHeight
    If $iTaskbarY > 0 And $iTaskbarY < @DesktopHeight Then $iBottom = $iTaskbarY

    ; Pack the POINT (two 32-bit LONGs) into a single INT64 for the by-value
    ; MonitorFromPoint argument (x64 passes an 8-byte POINT in one register).
    Local $tPt = DllStructCreate("int x;int y")
    If @error Then Return
    DllStructSetData($tPt, "x", $iX)
    DllStructSetData($tPt, "y", $iY)
    Local $tI64 = DllStructCreate("int64 v", DllStructGetPtr($tPt))
    If @error Then Return
    Local Const $MONITOR_DEFAULTTONEAREST = 2
    Local $aMon = DllCall("user32.dll", "handle", "MonitorFromPoint", _
        "int64", DllStructGetData($tI64, "v"), "dword", $MONITOR_DEFAULTTONEAREST)
    If @error Or Not IsArray($aMon) Or $aMon[0] = 0 Then Return

    Local $tMI = DllStructCreate("dword cbSize;int mL;int mT;int mR;int mB;int wL;int wT;int wR;int wB;dword dwFlags")
    If @error Then Return
    DllStructSetData($tMI, "cbSize", DllStructGetSize($tMI))
    Local $aInfo = DllCall("user32.dll", "bool", "GetMonitorInfoW", "handle", $aMon[0], "struct*", $tMI)
    If @error Or Not IsArray($aInfo) Or $aInfo[0] = 0 Then Return

    $iLeft = DllStructGetData($tMI, "wL")
    $iTop = DllStructGetData($tMI, "wT")
    $iRight = DllStructGetData($tMI, "wR")
    $iBottom = DllStructGetData($tMI, "wB")
EndFunc

; Name:        _CM_Show
; Description: Creates and shows the themed context menu at the cursor, clamped to
;              the monitor containing the cursor
; Parameters:  $iTaskbarY - Y position of the taskbar (fallback anchor when the
;                            cursor position is unavailable)
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

    ; Anchor at the cursor; fall back to bottom-left above the taskbar when the
    ; cursor position is unavailable.
    Local $iCurX = 0, $iCurY = $iTaskbarY
    Local $aMouse = MouseGetPos()
    If Not @error And IsArray($aMouse) Then
        $iCurX = $aMouse[0]
        $iCurY = $aMouse[1]
    EndIf

    Local $iWaLeft, $iWaTop, $iWaRight, $iWaBottom
    _CM_GetWorkArea($iCurX, $iCurY, $iWaLeft, $iWaTop, $iWaRight, $iWaBottom, $iTaskbarY)

    Local $iMenuX, $iMenuY
    _CM_ClampToWorkArea($iCurX, $iCurY, $iMenuW, $iMenuH, $iWaLeft, $iWaTop, $iWaRight, $iWaBottom, $iMenuX, $iMenuY)

    $__g_CM_hGUI = _Theme_CreatePopup("Menu", $iMenuW, $iMenuH, $iMenuX, $iMenuY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)

    Local $iY = 4

    $__g_CM_iEditID = _Theme_CreateMenuItem("  " & _i18n("ContextMenu.cm_edit_label", "Rename Desktop"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
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
