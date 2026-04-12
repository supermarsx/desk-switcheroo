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

    ; -- _VD_IsReady after successful init --
    _Test_AssertTrue("IsReady after init", _VD_IsReady())

    ; -- InvalidateCountCache forces requery --
    _VD_InvalidateCountCache()
    Local $iCount3 = _VD_GetCount()
    _Test_AssertGreaterEqual("GetCount after invalidate >= 1", $iCount3, 1)

    ; -- EnumWindowsOnDesktop returns array with count at [0] --
    Local $aEnum = _VD_EnumWindowsOnDesktop($iCurrent)
    _Test_AssertTrue("EnumWindowsOnDesktop is array", IsArray($aEnum))
    _Test_AssertGreaterEqual("EnumWindowsOnDesktop count >= 0", $aEnum[0], 0)

    ; -- GetWindowDesktopNumber for invalid handle returns 0 --
    _Test_AssertEqual("GetWindowDesktopNumber(0) = 0", _VD_GetWindowDesktopNumber(0), 0)

    ; -- MoveWindowToDesktop with invalid handle returns False --
    _Test_AssertFalse("MoveWindowToDesktop(0) fails", _VD_MoveWindowToDesktop(0, 1))

    ; -- Pin wrapper functions with hwnd 0 (DLL accepts without error) --
    _Test_AssertFalse("IsPinnedWindow(0) returns False", _VD_IsPinnedWindow(0))
    _Test_AssertFalse("IsPinnedApp(0) returns False", _VD_IsPinnedApp(0))
    ; Pin/Unpin/Toggle with hwnd 0: DLL doesn't fail, just test no crash
    _VD_PinWindow(0)
    _Test_AssertTrue("PinWindow(0) no crash", True)
    _VD_UnpinWindow(0)
    _Test_AssertTrue("UnpinWindow(0) no crash", True)
    _VD_TogglePinWindow(0)
    _Test_AssertTrue("TogglePinWindow(0) no crash", True)

    ; -- Pin/unpin on a real window handle should not crash --
    ; Find our own AutoIt window as a safe test target
    Local $hSelf = WinGetHandle("[CLASS:AutoIt v3]")
    If $hSelf <> 0 Then
        ; IsPinnedWindow should return True or False without crashing
        Local $bPinState = _VD_IsPinnedWindow($hSelf)
        _Test_AssertTrue("IsPinnedWindow returns bool", ($bPinState = True Or $bPinState = False))

        Local $bAppPinState = _VD_IsPinnedApp($hSelf)
        _Test_AssertTrue("IsPinnedApp returns bool", ($bAppPinState = True Or $bAppPinState = False))

        ; PinWindow / UnpinWindow should not crash on real handle
        Local $bPinOk = _VD_PinWindow($hSelf)
        _Test_AssertTrue("PinWindow on real hwnd returns True", $bPinOk)

        Local $bUnpinOk = _VD_UnpinWindow($hSelf)
        _Test_AssertTrue("UnpinWindow on real hwnd returns True", $bUnpinOk)

        ; TogglePinWindow should not crash on real handle
        Local $bToggle1 = _VD_TogglePinWindow($hSelf)
        _Test_AssertTrue("TogglePinWindow returns bool", ($bToggle1 = True Or $bToggle1 = False))
        ; Toggle back to restore original state
        _VD_TogglePinWindow($hSelf)
    Else
        ConsoleWrite("  SKIP: No AutoIt window found for pin/unpin real-handle tests" & @CRLF)
    EndIf

    ; -- Shutdown cleans up --
    _VD_Shutdown()
    _Test_AssertFalse("IsReady after shutdown", _VD_IsReady())

    ; -- Pin functions should return False after shutdown (DLL not loaded) --
    _Test_AssertFalse("IsPinnedWindow after shutdown", _VD_IsPinnedWindow(0))
    _Test_AssertFalse("IsPinnedApp after shutdown", _VD_IsPinnedApp(0))
    _Test_AssertFalse("PinWindow after shutdown", _VD_PinWindow(0))
    _Test_AssertFalse("UnpinWindow after shutdown", _VD_UnpinWindow(0))

    ; Re-init for other tests that may need it
    _VD_Init($sDllPath)
EndFunc
