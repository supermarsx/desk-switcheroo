#include-once

Func _RunTest_ExplorerMonitor()
    _Test_Suite("ExplorerMonitor")

    ; Explorer should be alive
    _Test_AssertTrue("Explorer alive", _EM_IsExplorerAlive())

    ; No recovery pending
    _Test_AssertFalse("No recovery pending", _EM_CheckRecovery())

    ; Config defaults
    _Test_AssertFalse("Explorer monitor disabled by default", _Cfg_GetExplorerMonitorEnabled())
    _Test_AssertEqual("Default check interval", _Cfg_GetExplorerCheckInterval(), 5000)
    _Test_AssertTrue("Default notify recovery", _Cfg_GetExplorerNotifyRecovery())
EndFunc
