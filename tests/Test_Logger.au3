#include-once

Func _RunTest_Logger()
    _Test_Suite("Logger")

    ; Test with temp log file
    Local $sTempLog = @TempDir & "\desk_switcheroo_test_log.log"
    If FileExists($sTempLog) Then FileDelete($sTempLog)

    _Cfg_SetLoggingEnabled(True)
    _Cfg_SetLogFilePath($sTempLog)
    _Cfg_SetLogLevel("debug")
    _Log_Init()

    ; Write test messages
    _Log_Error("Test error")
    _Log_Warn("Test warn")
    _Log_Info("Test info")
    _Log_Debug("Test debug")
    _Log_Shutdown()

    ; Verify
    _Test_AssertTrue("Log file created", FileExists($sTempLog))
    Local $sContent = FileRead($sTempLog)
    _Test_AssertTrue("Contains ERROR", StringInStr($sContent, "[ERROR]") > 0)
    _Test_AssertTrue("Contains WARN", StringInStr($sContent, "[WARN]") > 0)
    _Test_AssertTrue("Contains INFO", StringInStr($sContent, "[INFO]") > 0)
    _Test_AssertTrue("Contains DEBUG", StringInStr($sContent, "[DEBUG]") > 0)
    _Test_AssertTrue("Has timestamp", StringRegExp($sContent, "\[\d{4}-\d{2}-\d{2}"))

    ; Test level filtering
    FileDelete($sTempLog)
    _Cfg_SetLogLevel("error")
    _Log_Init()
    _Log_Info("Should not appear")
    _Log_Error("Should appear")
    _Log_Shutdown()
    $sContent = FileRead($sTempLog)
    _Test_AssertTrue("Error level: has ERROR", StringInStr($sContent, "Should appear") > 0)
    _Test_AssertFalse("Error level: no INFO", StringInStr($sContent, "Should not appear") > 0)

    ; -- Logging when disabled does nothing --
    _Cfg_SetLoggingEnabled(False)
    _Log_Init()
    _Log_Info("Should not write")
    _Log_Shutdown()
    ; File should not exist or be empty
    Local $sTempLog2 = @TempDir & "\desk_switcheroo_test_log2.log"
    _Cfg_SetLogFilePath($sTempLog2)
    ; Don't enable logging - verify no writes
    _Log_Info("Ghost write")
    _Test_AssertFalse("No log when disabled", FileExists($sTempLog2) And FileGetSize($sTempLog2) > 0)
    If FileExists($sTempLog2) Then FileDelete($sTempLog2)

    ; -- All level names accepted --
    _Cfg_SetLogLevel("error")
    _Test_AssertEqual("Level error accepted", _Cfg_GetLogLevel(), "error")
    _Cfg_SetLogLevel("warn")
    _Test_AssertEqual("Level warn accepted", _Cfg_GetLogLevel(), "warn")
    _Cfg_SetLogLevel("info")
    _Test_AssertEqual("Level info accepted", _Cfg_GetLogLevel(), "info")
    _Cfg_SetLogLevel("debug")
    _Test_AssertEqual("Level debug accepted", _Cfg_GetLogLevel(), "debug")

    ; Cleanup
    FileDelete($sTempLog)
    If FileExists($sTempLog & ".bak") Then FileDelete($sTempLog & ".bak")
    _Cfg_SetLoggingEnabled(False)
EndFunc
