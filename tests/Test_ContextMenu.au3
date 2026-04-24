#include-once

; ===============================================================
; Tests for includes\ContextMenu.au3
; GUI tests — creates actual windows
; ===============================================================

Func _RunTest_ContextMenu()
    _Test_Suite("ContextMenu")

    Local $iTestTaskbarY = @DesktopHeight - 48

    ; -- Initially not visible --
    _Test_AssertFalse("Initially not visible", _CM_IsVisible())
    _Test_AssertEqual("Initially GUI = 0", _CM_GetGUI(), 0)

    ; -- Show creates window --
    _CM_Show($iTestTaskbarY, False)
    _Test_AssertTrue("Show: is visible", _CM_IsVisible())
    _Test_AssertNotEqual("Show: GUI <> 0", _CM_GetGUI(), 0)

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
    _CM_Destroy()

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
