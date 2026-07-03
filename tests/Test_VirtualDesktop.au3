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

    ; -- EnumWindowsAllDesktops: single-pass 2D [count][2], desktops 1-based, and the
    ;    per-desktop enum equals the all-desktops rows filtered to that desktop --
    Local $aAllD = _VD_EnumWindowsAllDesktops()
    _Test_AssertTrue("EnumWindowsAllDesktops is array", IsArray($aAllD))
    _Test_AssertEqual("EnumWindowsAllDesktops width 2", UBound($aAllD, 2), 2)
    _Test_AssertGreaterEqual("EnumWindowsAllDesktops count >= 0", $aAllD[0][0], 0)
    Local $iAllOnCur = 0, $bDesksValid = True, $kk
    For $kk = 1 To $aAllD[0][0]
        If $aAllD[$kk][1] < 1 Then $bDesksValid = False
        If $aAllD[$kk][1] = $iCurrent Then $iAllOnCur += 1
    Next
    _Test_AssertTrue("EnumWindowsAllDesktops desktops are 1-based", $bDesksValid)
    Local $aOnCur = _VD_EnumWindowsOnDesktop($iCurrent)
    _Test_AssertEqual("On-desktop enum matches all-desktops filter", $aOnCur[0], $iAllOnCur)

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

    ; -- Native-OSD suppression policy: 2x2 truth table --
    ; Suppress when disable_native_osd OR osd_enabled. Save & restore config.
    Local $bOrigDisable = _Cfg_GetDisableNativeOsd()
    Local $bOrigOsd = _Cfg_GetOsdEnabled()

    _Cfg_SetDisableNativeOsd(False)
    _Cfg_SetOsdEnabled(False)
    _Test_AssertFalse("SuppressOsd: toggle off + osd off => False", __VD_ShouldSuppressNativeOsd())

    _Cfg_SetDisableNativeOsd(True)
    _Cfg_SetOsdEnabled(False)
    _Test_AssertTrue("SuppressOsd: toggle on + osd off => True", __VD_ShouldSuppressNativeOsd())

    _Cfg_SetDisableNativeOsd(False)
    _Cfg_SetOsdEnabled(True)
    _Test_AssertTrue("SuppressOsd: toggle off + osd on => True", __VD_ShouldSuppressNativeOsd())

    _Cfg_SetDisableNativeOsd(True)
    _Cfg_SetOsdEnabled(True)
    _Test_AssertTrue("SuppressOsd: toggle on + osd on => True", __VD_ShouldSuppressNativeOsd())

    ; Restore original config
    _Cfg_SetDisableNativeOsd($bOrigDisable)
    _Cfg_SetOsdEnabled($bOrigOsd)

    ; -- Client-area animation get/set/restore round-trips (no persist, no broadcast) --
    Local $iAnim = __VD_GetClientAreaAnimation()
    _Test_AssertTrue("GetClientAreaAnimation returns 0/1/-1", ($iAnim = 0 Or $iAnim = 1 Or $iAnim = -1))
    If $iAnim = 0 Or $iAnim = 1 Then
        __VD_SetClientAreaAnimation($iAnim = 0) ; flip
        _Test_AssertEqual("SetClientAreaAnimation flips value", __VD_GetClientAreaAnimation(), ($iAnim = 0) ? 1 : 0)
        __VD_SetClientAreaAnimation($iAnim = 1) ; restore original
        _Test_AssertEqual("Client-area animation restored", __VD_GetClientAreaAnimation(), $iAnim)
    EndIf

    ; -- _VD_GoTo switches and does not error; leaves system setting unchanged --
    ; Force suppression on so the guard path is exercised, then confirm the animation
    ; setting is the same before and after the switch (guard restores it).
    ; Note: GoToDesktopNumber commits the switch asynchronously (COM), so poll for the
    ; result with a settle rather than reading immediately (see _VD_SwapDesktops delays).
    _Cfg_SetDisableNativeOsd(True)
    Local $iAnimBefore = __VD_GetClientAreaAnimation()
    Local $iCurBefore = _VD_GetCurrent()
    If _VD_GetCount() >= 2 Then
        Local $iOther = ($iCurBefore = 1) ? 2 : 1
        _VD_GoTo($iOther)
        _Test_AssertEqual("_VD_GoTo switched to target", __VD_TestWaitDesktop($iOther), $iOther)
        _VD_GoTo($iCurBefore)
        _Test_AssertEqual("_VD_GoTo returned to original", __VD_TestWaitDesktop($iCurBefore), $iCurBefore)
    Else
        ; Single desktop: switching to it is a no-op but must not error
        _VD_GoTo($iCurBefore)
        _Test_AssertEqual("_VD_GoTo no-op stays on desktop", _VD_GetCurrent(), $iCurBefore)
    EndIf
    ; The restore is deferred (one-shot Adlib); flush it so we can assert the system
    ; setting is left exactly as before the switch — never permanently altered.
    __VD_FlushAnimRestore()
    _Test_AssertEqual("_VD_GoTo restored client-area animation", __VD_GetClientAreaAnimation(), $iAnimBefore)
    _Cfg_SetDisableNativeOsd($bOrigDisable)

    ; -- Deferred native-OSD-suppression restore: pending, re-arm, flush --
    ; Force the guard's "animations ON" branch so the restore is actually deferred,
    ; then verify the pending flag, that rapid re-switches re-arm (stay pending), and
    ; that flush restores the flag and clears pending. Machine state is saved/restored.
    Local $iAnimSaved = __VD_GetClientAreaAnimation()
    If $iAnimSaved = 0 Or $iAnimSaved = 1 Then
        __VD_FlushAnimRestore() ; clean slate
        __VD_SetClientAreaAnimation(True) ; animations ON
        _Cfg_SetDisableNativeOsd(True)    ; suppression ON
        Local $iCurDR = _VD_GetCurrent()

        _VD_GoTo($iCurDR)
        _Test_AssertTrue("Deferred restore pending after suppressed switch", __VD_AnimRestorePending())
        _Test_AssertEqual("Animation held OFF during deferral", __VD_GetClientAreaAnimation(), 0)

        ; Rapid re-switch re-arms the one-shot timer; still pending, still held OFF.
        _VD_GoTo($iCurDR)
        _Test_AssertTrue("Deferred restore still pending after rapid re-switch", __VD_AnimRestorePending())
        _Test_AssertEqual("Animation still held OFF after re-switch", __VD_GetClientAreaAnimation(), 0)

        ; Flush restores the flag immediately and clears pending; second flush no-ops.
        __VD_FlushAnimRestore()
        _Test_AssertFalse("Pending cleared after flush", __VD_AnimRestorePending())
        _Test_AssertEqual("Animation restored ON after flush", __VD_GetClientAreaAnimation(), 1)
        __VD_FlushAnimRestore()
        _Test_AssertFalse("Pending stays cleared on second flush", __VD_AnimRestorePending())

        ; Restore original machine + config state.
        __VD_SetClientAreaAnimation($iAnimSaved = 1)
        _Cfg_SetDisableNativeOsd($bOrigDisable)
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

; Polls _VD_GetCurrent until it equals $iTarget or a timeout elapses. GoToDesktopNumber
; commits asynchronously, so a fresh switch is not always visible on the very next read.
Func __VD_TestWaitDesktop($iTarget, $iTimeoutMs = 1000)
    Local $hTimer = TimerInit()
    Do
        If _VD_GetCurrent() = $iTarget Then Return $iTarget
        Sleep(50)
    Until TimerDiff($hTimer) > $iTimeoutMs
    Return _VD_GetCurrent()
EndFunc
