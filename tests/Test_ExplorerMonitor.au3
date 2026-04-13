#include-once

Func _RunTest_ExplorerMonitor()
    _Test_Suite("ExplorerMonitor")

    ; -- Explorer should be alive in test environment --
    _Test_AssertTrue("Explorer alive", _EM_IsExplorerAlive())

    ; -- No recovery pending --
    _Test_AssertFalse("No recovery pending", _EM_CheckRecovery())

    ; -- CheckRecovery returns False on second call (flag cleared) --
    _Test_AssertFalse("No recovery pending (second call)", _EM_CheckRecovery())

    ; -- Config defaults --
    _Test_AssertFalse("Explorer monitor disabled by default", _Cfg_GetExplorerMonitorEnabled())
    _Test_AssertEqual("Default check interval", _Cfg_GetExplorerCheckInterval(), 5000)
    _Test_AssertTrue("Default notify recovery", _Cfg_GetExplorerNotifyRecovery())

    ; -- Config defaults for retry/backoff --
    _Test_AssertEqual("Default max retries", _Cfg_GetMonitorMaxRetries(), 0)
    _Test_AssertEqual("Default retry delay", _Cfg_GetMonitorRetryDelay(), 5000)
    _Test_AssertTrue("Default exp backoff enabled", _Cfg_GetMonitorExpBackoff())
    _Test_AssertEqual("Default max retry delay", _Cfg_GetMonitorMaxRetryDelay(), 60000)
    _Test_AssertFalse("Default auto restart disabled", _Cfg_GetMonitorAutoRestart())

    ; -- Retry count starts at 0 --
    _Test_AssertEqual("Retry count = 0", _EM_GetRetryCount(), 0)

    ; -- Current delay matches configured delay --
    _Test_AssertEqual("Current delay = config", _EM_GetCurrentDelay(), _Cfg_GetMonitorRetryDelay())

    ; -- CheckCrash returns False initially --
    _Test_AssertFalse("No crash pending", _EM_CheckCrash())

    ; -- CheckCrash one-shot behavior --
    $__g_EM_bCrashPending = True
    _Test_AssertTrue("CheckCrash first call = True", _EM_CheckCrash())
    _Test_AssertFalse("CheckCrash second call = False", _EM_CheckCrash())

    ; -- Start is no-op when disabled --
    _Cfg_SetExplorerMonitorEnabled(False)
    _EM_Start()
    _Test_AssertTrue("EM Start no crash when disabled", True)

    ; -- Stop resets retry count --
    $__g_EM_iRetryCount = 5
    _EM_Stop()
    _Test_AssertEqual("EM Stop resets retry count", _EM_GetRetryCount(), 0)

    ; -- Shell process name validation --
    _Test_AssertEqual("Default shell process", _Cfg_GetShellProcessName(), "explorer.exe")
    _Cfg_SetShellProcessName("explorer.exe & calc")
    _Test_AssertEqual("Injection rejected", _Cfg_GetShellProcessName(), "explorer.exe")
    _Cfg_SetShellProcessName("my-shell.exe")
    _Test_AssertEqual("Valid exe accepted", _Cfg_GetShellProcessName(), "my-shell.exe")
    _Cfg_SetShellProcessName("")
    _Test_AssertEqual("Empty fallback to explorer", _Cfg_GetShellProcessName(), "explorer.exe")
    _Cfg_SetShellProcessName("explorer.exe")
EndFunc
