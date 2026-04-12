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
EndFunc
