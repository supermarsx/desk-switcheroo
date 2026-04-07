#include-once

; ===============================================================
; Tests for includes\VirtualDesktop.au3
; Integration tests — requires VirtualDesktopAccessor.dll present
; ===============================================================

Func _RunTest_VirtualDesktop()
    _Test_Suite("VirtualDesktop")

    ; -- Init with bad path fails --
    Local $bBadInit = _VD_Init("C:\nonexistent_path\fake.dll")
    _Test_AssertFalse("Init with bad path returns False", $bBadInit)

    ; -- Init with real DLL succeeds --
    Local $sDllDir = StringRegExpReplace(@ScriptDir, "\\[^\\]+$", "")
    Local $sDllPath = $sDllDir & "\VirtualDesktopAccessor.dll"
    Local $bGoodInit = _VD_Init($sDllPath)
    _Test_AssertTrue("Init with real DLL returns True", $bGoodInit)

    ; Skip remaining tests if DLL failed to load
    If Not $bGoodInit Then
        ConsoleWrite("  SKIP: DLL not available, skipping remaining VD tests" & @CRLF)
        Return
    EndIf

    ; -- GetCount returns >= 1 --
    Local $iCount = _VD_GetCount()
    _Test_AssertGreaterEqual("GetCount >= 1", $iCount, 1)

    ; -- GetCurrent returns >= 1 --
    Local $iCurrent = _VD_GetCurrent()
    _Test_AssertGreaterEqual("GetCurrent >= 1", $iCurrent, 1)

    ; -- GetCurrent returns <= GetCount --
    _Test_AssertLessEqual("GetCurrent <= GetCount", $iCurrent, $iCount)

    ; -- GetCurrent is consistent --
    Local $iCurrent2 = _VD_GetCurrent()
    _Test_AssertEqual("GetCurrent consistent across calls", $iCurrent2, $iCurrent)

    ; -- Name support detection --
    ; HasNameSupport should return a boolean (True on Win11+, False on Win10)
    Local $bNameSupport = _VD_HasNameSupport()
    ConsoleWrite("  INFO: Name support = " & $bNameSupport & @CRLF)

    If $bNameSupport Then
        ; -- GetName returns a string --
        Local $sName = _VD_GetName(1)
        ; Name can be empty (default) or a string — just check it doesn't crash
        ConsoleWrite("  INFO: Desktop 1 OS name = '" & $sName & "'" & @CRLF)

        ; -- SetName + GetName round-trip --
        Local $sOriginal = _VD_GetName($iCurrent)
        Local $sTestName = "SwitcherooTest"
        Local $bSet = _VD_SetName($iCurrent, $sTestName)
        _Test_AssertTrue("SetName returns True", $bSet)

        Local $sReadBack = _VD_GetName($iCurrent)
        _Test_AssertEqual("GetName after SetName", $sReadBack, $sTestName)

        ; Restore original name
        _VD_SetName($iCurrent, $sOriginal)
        Local $sRestored = _VD_GetName($iCurrent)
        _Test_AssertEqual("Name restored after test", $sRestored, $sOriginal)
    Else
        ConsoleWrite("  SKIP: Name functions not supported on this OS" & @CRLF)
        ; -- GetName returns empty when unsupported --
        _Test_AssertEqual("GetName empty when unsupported", _VD_GetName(1), "")
        ; -- SetName returns False when unsupported --
        _Test_AssertFalse("SetName fails when unsupported", _VD_SetName(1, "Test"))
    EndIf
EndFunc
