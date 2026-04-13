#include-once

Func _RunTest_Logger()
    _Test_Suite("Logger")

    ; Test with temp log folder (filename is auto-generated as desk_switcheroo.log)
    Local $sTempFolder = @TempDir & "\desk_switcheroo_test_logs"
    DirCreate($sTempFolder)
    Local $sTempLog = $sTempFolder & "\desk_switcheroo.log"
    If FileExists($sTempLog) Then FileDelete($sTempLog)

    _Cfg_SetLoggingEnabled(True)
    _Cfg_SetLogFolder($sTempFolder)
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
    Local $sTempFolder2 = @TempDir & "\desk_switcheroo_test_logs2"
    DirCreate($sTempFolder2)
    Local $sTempLog2 = $sTempFolder2 & "\desk_switcheroo.log"
    _Cfg_SetLogFolder($sTempFolder2)
    ; Don't enable logging - verify no writes
    _Log_Info("Ghost write")
    _Test_AssertFalse("No log when disabled", FileExists($sTempLog2) And FileGetSize($sTempLog2) > 0)
    If FileExists($sTempLog2) Then FileDelete($sTempLog2)
    DirRemove($sTempFolder2)

    ; -- All level names accepted --
    _Cfg_SetLogLevel("error")
    _Test_AssertEqual("Level error accepted", _Cfg_GetLogLevel(), "error")
    _Cfg_SetLogLevel("warn")
    _Test_AssertEqual("Level warn accepted", _Cfg_GetLogLevel(), "warn")
    _Cfg_SetLogLevel("info")
    _Test_AssertEqual("Level info accepted", _Cfg_GetLogLevel(), "info")
    _Cfg_SetLogLevel("debug")
    _Test_AssertEqual("Level debug accepted", _Cfg_GetLogLevel(), "debug")

    ; -- Log date format variants --
    _Cfg_SetLogDateFormat("us")
    _Test_AssertEqual("Date format us accepted", _Cfg_GetLogDateFormat(), "us")
    _Cfg_SetLogDateFormat("eu")
    _Test_AssertEqual("Date format eu accepted", _Cfg_GetLogDateFormat(), "eu")
    _Cfg_SetLogDateFormat("iso")
    _Test_AssertEqual("Date format iso accepted", _Cfg_GetLogDateFormat(), "iso")
    _Cfg_SetLogDateFormat("invalid")
    _Test_AssertEqual("Date format invalid fallback", _Cfg_GetLogDateFormat(), "iso")

    ; -- PID inclusion config --
    _Cfg_SetLogIncludePID(True)
    _Test_AssertTrue("PID inclusion enabled", _Cfg_GetLogIncludePID())
    _Cfg_SetLogIncludePID(False)
    _Test_AssertFalse("PID inclusion disabled", _Cfg_GetLogIncludePID())

    ; -- Log max size config --
    _Cfg_SetLogMaxSizeMB(5)
    _Test_AssertEqual("Max size set/get", _Cfg_GetLogMaxSizeMB(), 5)

    ; -- Log rotate count config --
    Local $iRotBefore = _Cfg_GetLogRotateCount()
    _Cfg_SetLogRotateCount(5)
    _Test_AssertEqual("Rotate count set/get", _Cfg_GetLogRotateCount(), 5)
    _Cfg_SetLogRotateCount($iRotBefore)

    ; -- Log compress old config --
    _Cfg_SetLogCompressOld(True)
    _Test_AssertTrue("Compress old enabled", _Cfg_GetLogCompressOld())
    _Cfg_SetLogCompressOld(False)

    ; -- Log flush immediate config --
    _Cfg_SetLogFlushImmediate(False)
    _Test_AssertFalse("Flush immediate disabled", _Cfg_GetLogFlushImmediate())
    _Cfg_SetLogFlushImmediate(True)

    ; -- Log folder path validation --
    _Cfg_SetLogFolder("%APPDATA%")
    _Test_AssertTrue("Log path expanded", StringInStr(_Cfg_GetLogFilePath(), @AppDataDir) > 0)
    _Cfg_SetLogFolder("%APPDATA%\..\..\evil")
    _Test_AssertTrue("Log path traversal rejected", StringInStr(_Cfg_GetLogFilePath(), @ScriptDir) > 0)
    _Cfg_SetLogFolder("")

    ; Cleanup
    FileDelete($sTempLog)
    If FileExists($sTempLog & ".bak") Then FileDelete($sTempLog & ".bak")
    DirRemove($sTempFolder, 1)
    _Cfg_SetLoggingEnabled(False)
EndFunc
