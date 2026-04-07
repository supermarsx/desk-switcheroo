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

    ; -- Show with list visible changes toggle text --
    _CM_Show($iTestTaskbarY, True)
    _Test_AssertTrue("Show with list: visible", _CM_IsVisible())
    _CM_Destroy()
EndFunc
