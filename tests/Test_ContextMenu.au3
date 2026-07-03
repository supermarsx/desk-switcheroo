#include-once

; ===============================================================
; Tests for includes\ContextMenu.au3
; GUI tests — creates actual windows
; ===============================================================

Func _RunTest_ContextMenu()
    _Test_Suite("ContextMenu")

    Local $iTestTaskbarY = @DesktopHeight - 48

    ; -- Clamp helper truth table (pure geometry; work rect 0,0..1920x1040) --
    Local $ox = 0, $oy = 0
    ; Down-right, fully in bounds — no flip, no clamp
    _CM_ClampToWorkArea(100, 100, 170, 300, 0, 0, 1920, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: in-bounds X", $ox, 100)
    _Test_AssertEqual("Clamp: in-bounds Y", $oy, 100)
    ; Near right edge — flips left (right edge of menu at cursor)
    _CM_ClampToWorkArea(1900, 100, 170, 300, 0, 0, 1920, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: right edge flips X", $ox, 1730)
    _Test_AssertEqual("Clamp: right edge keeps Y", $oy, 100)
    ; Near bottom edge — flips up
    _CM_ClampToWorkArea(100, 1000, 170, 300, 0, 0, 1920, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: bottom edge keeps X", $ox, 100)
    _Test_AssertEqual("Clamp: bottom edge flips Y", $oy, 700)
    ; Bottom-right corner — flips both
    _CM_ClampToWorkArea(1900, 1000, 170, 300, 0, 0, 1920, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: corner flips X", $ox, 1730)
    _Test_AssertEqual("Clamp: corner flips Y", $oy, 700)
    ; Menu wider than the work area — clamp to left edge
    _CM_ClampToWorkArea(100, 100, 3000, 300, 0, 0, 1920, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: over-wide menu pinned to left", $ox, 0)
    ; Menu taller than the work area — clamp to top edge
    _CM_ClampToWorkArea(100, 100, 170, 2000, 0, 0, 1920, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: over-tall menu pinned to top", $oy, 0)
    ; Negative-coordinate monitor (left of primary): work rect -1920,0..0x1040
    _CM_ClampToWorkArea(-100, 500, 170, 300, -1920, 0, 0, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: negative monitor flips X", $ox, -270)
    _Test_AssertEqual("Clamp: negative monitor keeps Y", $oy, 500)
    ; Negative-coordinate monitor, near its left edge — clamp to left
    _CM_ClampToWorkArea(-1900, 500, 170, 300, -1920, 0, 0, 1040, $ox, $oy)
    _Test_AssertEqual("Clamp: negative monitor left edge X", $ox, -1900)
    _Test_AssertEqual("Clamp: negative monitor left edge Y", $oy, 500)

    ; -- Work-area helper returns a sane rect --
    Local $wl = 0, $wt = 0, $wr = 0, $wb = 0
    _CM_GetWorkArea(10, 10, $wl, $wt, $wr, $wb, $iTestTaskbarY)
    _Test_AssertTrue("WorkArea: right > left", $wr > $wl)
    _Test_AssertTrue("WorkArea: bottom > top", $wb > $wt)

    ; -- Fallback literal updated to 'Rename Desktop' (guards the source change) --
    Local $sCMSrc = FileRead(@ScriptDir & "\..\includes\ContextMenu.au3")
    _Test_AssertTrue("Edit item fallback = 'Rename Desktop'", _
        StringInStr($sCMSrc, '"ContextMenu.cm_edit_label", "Rename Desktop"') > 0)
    _Test_AssertEqual("Old 'Edit Label' fallback removed", _
        StringInStr($sCMSrc, '"ContextMenu.cm_edit_label", "Edit Label"'), 0)

    ; -- Initially not visible --
    _Test_AssertFalse("Initially not visible", _CM_IsVisible())
    _Test_AssertEqual("Initially GUI = 0", _CM_GetGUI(), 0)

    ; -- Show creates window --
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertTrue("Show: is visible", _CM_IsVisible())
    _Test_AssertNotEqual("Show: GUI <> 0", _CM_GetGUI(), 0)

    ; -- Shown menu stays within the cursor monitor's work area --
    Local $aMenuPos = WinGetPos(_CM_GetGUI())
    If IsArray($aMenuPos) Then
        Local $mwl = 0, $mwt = 0, $mwr = 0, $mwb = 0
        _CM_GetWorkArea($aMenuPos[0], $aMenuPos[1], $mwl, $mwt, $mwr, $mwb, $iTestTaskbarY)
        _Test_AssertTrue("Show: menu left in bounds", $aMenuPos[0] >= $mwl - 1)
        _Test_AssertTrue("Show: menu top in bounds", $aMenuPos[1] >= $mwt - 1)
        _Test_AssertTrue("Show: menu right in bounds", $aMenuPos[0] + $aMenuPos[2] <= $mwr + 1)
        _Test_AssertTrue("Show: menu bottom in bounds", $aMenuPos[1] + $aMenuPos[3] <= $mwb + 1)
    Else
        _Test_Skip("Show: menu placement in bounds")
    EndIf

    ; -- HandleClick with no match returns empty --
    _Test_AssertEqual("HandleClick(0) = empty", _CM_HandleClick(0), "")
    _Test_AssertEqual("HandleClick(-1) = empty", _CM_HandleClick(-1), "")

    ; -- HandleClick with edit control returns 'edit' --
    _Test_AssertEqual("HandleClick(edit) = 'edit'", _CM_HandleClick(_CM_GetEditID()), "edit")

    ; -- HandleClick with toggle control returns 'toggle_list' --
    _Test_AssertEqual("HandleClick(toggle) = 'toggle_list'", _CM_HandleClick(_CM_GetToggleID()), "toggle_list")

    ; -- HandleClick with gather control returns 'gather' --
    _Test_AssertEqual("HandleClick(gather) = 'gather'", _CM_HandleClick(_CM_GetGatherID()), "gather")

    ; -- HandleClick with add control returns 'add' --
    _Test_AssertEqual("HandleClick(add) = 'add'", _CM_HandleClick(_CM_GetAddID()), "add")

    ; -- HandleClick with delete control returns 'delete' --
    _Test_AssertEqual("HandleClick(delete) = 'delete'", _CM_HandleClick(_CM_GetDeleteID()), "delete")

    ; -- HandleClick with about control returns 'about' --
    _Test_AssertEqual("HandleClick(about) = 'about'", _CM_HandleClick(_CM_GetAboutID()), "about")

    ; -- HandleClick with quit control returns 'quit' --
    _Test_AssertEqual("HandleClick(quit) = 'quit'", _CM_HandleClick(_CM_GetQuitID()), "quit")

    ; -- Destroy removes window --
    _CM_Destroy()
    _Test_AssertFalse("Destroy: not visible", _CM_IsVisible())
    _Test_AssertEqual("Destroy: GUI = 0", _CM_GetGUI(), 0)

    ; -- HandleClick with settings returns 'settings' --
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertEqual("HandleClick(settings) = 'settings'", _CM_HandleClick(_CM_GetSettingsID()), "settings")
    _CM_Destroy()

    ; -- Show with list visible changes toggle text --
    _CM_Show($iTestTaskbarY, True)
    _Test_AssertTrue("Show with list: visible", _CM_IsVisible())
    _CM_Destroy()

    ; -- Set Color conditional on desktop colors --
    ; When colors disabled, set_color should not exist
    Local $bColorsWas = _Cfg_GetDesktopColorsEnabled()
    _Cfg_SetDesktopColorsEnabled(False)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertEqual("SetColor hidden when disabled", $__g_CM_iSetColorID, 0)
    _CM_Destroy()

    ; When colors enabled, set_color should exist
    _Cfg_SetDesktopColorsEnabled(True)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertNotEqual("SetColor shown when enabled", $__g_CM_iSetColorID, 0)
    _Test_AssertEqual("HandleClick(set_color)", _CM_HandleClick($__g_CM_iSetColorID), "set_color")
    _DL_ColorPickerDestroy()
    _DL_ColorPickerShow(1, _CM_GetGUI(), _CM_GetSetColorID())
    _Test_AssertTrue("CM SetColor: picker visible", _DL_ColorPickerIsVisible())
    Local $aCtxPos = WinGetPos(_CM_GetGUI())
    Local $aSetColorPos = ControlGetPos(_CM_GetGUI(), "", _CM_GetSetColorID())
    Local $aPickerPos = WinGetPos(_DL_ColorPickerGetGUI())
    _Test_AssertTrue("CM SetColor: ctx pos array", IsArray($aCtxPos))
    _Test_AssertTrue("CM SetColor: parent item pos array", IsArray($aSetColorPos))
    _Test_AssertTrue("CM SetColor: picker pos array", IsArray($aPickerPos))
    If IsArray($aCtxPos) And IsArray($aSetColorPos) And IsArray($aPickerPos) Then
        Local $iExpectedPickerY = $aCtxPos[1] + $aSetColorPos[1]
        If $iExpectedPickerY < 0 Then $iExpectedPickerY = 0
        If $iExpectedPickerY + $aPickerPos[3] > @DesktopHeight Then $iExpectedPickerY = @DesktopHeight - $aPickerPos[3]
        If $iExpectedPickerY < 0 Then $iExpectedPickerY = 0
        _Test_AssertEqual("CM SetColor: aligned to SetColor item", $aPickerPos[1], $iExpectedPickerY)
    Else
        _Test_Skip("CM SetColor: aligned to SetColor item")
    EndIf
    _CM_Destroy()
    _Test_AssertFalse("CM SetColor: picker hidden after menu destroy", _DL_ColorPickerIsVisible())

    ; Restore original state
    _Cfg_SetDesktopColorsEnabled($bColorsWas)

    ; -- Multiple show/destroy cycles don't crash --
    Local $j
    For $j = 1 To 3
        _CM_Show($iTestTaskbarY, False)
        _Test_AssertTrue("Cycle " & $j & ": visible", _CM_IsVisible())
        _CM_Destroy()
        _Test_AssertFalse("Cycle " & $j & ": destroyed", _CM_IsVisible())
    Next

    ; -- All IDs reset after destroy --
    _CM_Destroy()
    _Test_AssertEqual("After destroy: edit=0", _CM_GetEditID(), 0)
    _Test_AssertEqual("After destroy: toggle=0", _CM_GetToggleID(), 0)
    _Test_AssertEqual("After destroy: gather=0", _CM_GetGatherID(), 0)
    _Test_AssertEqual("After destroy: add=0", _CM_GetAddID(), 0)
    _Test_AssertEqual("After destroy: delete=0", _CM_GetDeleteID(), 0)
    _Test_AssertEqual("After destroy: about=0", _CM_GetAboutID(), 0)
    _Test_AssertEqual("After destroy: settings=0", _CM_GetSettingsID(), 0)
    _Test_AssertEqual("After destroy: quit=0", _CM_GetQuitID(), 0)

    ; -- Pin window item conditional on pinning enabled --
    Local $bPinWas = _Cfg_GetPinningEnabled()
    _Cfg_SetPinningEnabled(False)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertEqual("Pin hidden when disabled", $__g_CM_iPinID, 0)
    _CM_Destroy()

    _Cfg_SetPinningEnabled(True)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertNotEqual("Pin shown when enabled", $__g_CM_iPinID, 0)
    _Test_AssertEqual("HandleClick(pin) = 'pin_window'", _CM_HandleClick($__g_CM_iPinID), "pin_window")
    _CM_Destroy()
    _Cfg_SetPinningEnabled($bPinWas)

    ; -- Window list item conditional on window list enabled --
    Local $bWLWas = _Cfg_GetWindowListEnabled()
    _Cfg_SetWindowListEnabled(False)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertEqual("WinList hidden when disabled", $__g_CM_iWinListID, 0)
    _CM_Destroy()

    _Cfg_SetWindowListEnabled(True)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertNotEqual("WinList shown when enabled", $__g_CM_iWinListID, 0)
    _Test_AssertEqual("HandleClick(wl) = 'window_list'", _CM_HandleClick($__g_CM_iWinListID), "window_list")
    _CM_Destroy()
    _Cfg_SetWindowListEnabled($bWLWas)

    ; -- Visibility state through show/destroy cycle --
    _Test_AssertFalse("Pre-cycle: not visible", _CM_IsVisible())
    _Test_AssertEqual("Pre-cycle: GUI = 0", _CM_GetGUI(), 0)
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertTrue("Mid-cycle: visible", _CM_IsVisible())
    _Test_AssertNotEqual("Mid-cycle: GUI <> 0", _CM_GetGUI(), 0)
    _CM_Destroy()
    _Test_AssertFalse("Post-cycle: not visible", _CM_IsVisible())
    _Test_AssertEqual("Post-cycle: GUI = 0", _CM_GetGUI(), 0)
EndFunc
