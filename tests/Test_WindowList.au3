#include-once

Func _RunTest_WindowList()
    _Test_Suite("WindowList")

    ; Visibility state
    _Test_AssertFalse("WL not visible initially", _WL_IsVisible())
    _Test_AssertEqual("WL GUI is 0", _WL_GetGUI(), 0)

    ; Context menu state
    _Test_AssertFalse("WL ctx not visible", _WL_CtxIsVisible())
    _Test_AssertEqual("WL ctx GUI is 0", _WL_CtxGetGUI(), 0)
EndFunc
