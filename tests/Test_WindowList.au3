#include-once

Func _RunTest_WindowList()
    _Test_Suite("WindowList")

    ; -- Visibility state --
    _Test_AssertFalse("WL not visible initially", _WL_IsVisible())
    _Test_AssertEqual("WL GUI is 0 initially", _WL_GetGUI(), 0)

    ; -- Context menu state --
    _Test_AssertFalse("WL ctx not visible initially", _WL_CtxIsVisible())
    _Test_AssertEqual("WL ctx GUI is 0 initially", _WL_CtxGetGUI(), 0)

    ; -- Context target --
    _Test_AssertEqual("WL ctx target is 0 initially", _WL_GetCtxTarget(), 0)

    ; -- Config defaults: window_list_enabled --
    _Test_AssertFalse("WL disabled by default", _Cfg_GetWindowListEnabled())

    ; -- Config defaults: position --
    _Test_AssertEqual("WL default position", _Cfg_GetWindowListPosition(), "top-left")

    ; -- Config defaults: width --
    _Test_AssertEqual("WL default width", _Cfg_GetWindowListWidth(), 280)

    ; -- Config defaults: search --
    _Test_AssertTrue("WL default search enabled", _Cfg_GetWindowListSearch())

    ; -- Config round-trips --
    Local $sPosBefore = _Cfg_GetWindowListPosition()
    _Cfg_SetWindowListPosition("bottom-right")
    _Test_AssertEqual("WL position set/get", _Cfg_GetWindowListPosition(), "bottom-right")
    _Cfg_SetWindowListPosition("invalid-position")
    _Test_AssertEqual("WL position invalid fallback", _Cfg_GetWindowListPosition(), "top-left")
    _Cfg_SetWindowListPosition($sPosBefore)

    Local $iWidthBefore = _Cfg_GetWindowListWidth()
    _Cfg_SetWindowListWidth(350)
    _Test_AssertEqual("WL width set/get", _Cfg_GetWindowListWidth(), 350)
    _Cfg_SetWindowListWidth(50)
    _Test_AssertEqual("WL width clamped min", _Cfg_GetWindowListWidth(), 150)
    _Cfg_SetWindowListWidth(999)
    _Test_AssertEqual("WL width clamped max", _Cfg_GetWindowListWidth(), 600)
    _Cfg_SetWindowListWidth($iWidthBefore)

    ; -- Config: scope --
    _Test_AssertEqual("WL default scope", _Cfg_GetWindowListScope(), "current")

    ; -- Config: max visible --
    _Test_AssertTrue("WL max visible > 0", _Cfg_GetWindowListMaxVisible() > 0)

    ; -- Config: refresh interval --
    Local $iRefBefore = _Cfg_GetWindowListRefreshInterval()
    _Cfg_SetWindowListRefreshInterval(2000)
    _Test_AssertEqual("WL refresh interval set/get", _Cfg_GetWindowListRefreshInterval(), 2000)
    _Cfg_SetWindowListRefreshInterval(100)
    _Test_AssertEqual("WL refresh clamped min", _Cfg_GetWindowListRefreshInterval(), 500)
    _Cfg_SetWindowListRefreshInterval($iRefBefore)

    ; -- HandleClick with 0 returns 0 when not visible --
    _Test_AssertEqual("WL HandleClick(0) = 0 when hidden", _WL_HandleClick(0), 0)

    ; -- ScrollUp/Down without GUI are no-ops --
    _WL_ScrollUp()
    _WL_ScrollDown()
    _Test_AssertTrue("WL scroll without GUI no crash", True)
EndFunc
