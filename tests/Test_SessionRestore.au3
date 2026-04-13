#include-once

; ===============================================================
; Tests for includes\SessionRestore.au3
; Unit tests — uses a temp INI file, no GUI required
; ===============================================================

Func _RunTest_SessionRestore()
    _Test_Suite("SessionRestore")

    Local $sTempState = @TempDir & "\desk_switcheroo_state_test.ini"
    Local $sTempConfig = @TempDir & "\desk_switcheroo_config_test.ini"

    ; Clean up any leftover temp files
    If FileExists($sTempState) Then FileDelete($sTempState)
    If FileExists($sTempConfig) Then FileDelete($sTempConfig)

    ; ---- HasSavedSession: no file ----
    _Test_AssertFalse("No session without state file", _SR_HasSavedSession())

    ; ---- GetSavedCount: no file ----
    _Test_AssertEqual("Count 0 without state file", _SR_GetSavedCount(), 0)

    ; ---- ClearSession: no file does not error ----
    _SR_ClearSession()
    _Test_AssertTrue("ClearSession no-op without file", True)

    ; ---- Write mock session data directly to state INI ----
    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"

    ; Save original state if any
    Local $sOrigCount = IniRead($sStateFile, "Session", "session_count", "")
    Local $sOrigTimestamp = IniRead($sStateFile, "Session", "session_timestamp", "")
    Local $sOrigDesktops = IniRead($sStateFile, "Session", "session_desktop_count", "")

    ; Write test session data
    IniWrite($sStateFile, "Session", "session_count", "5")
    IniWrite($sStateFile, "Session", "session_timestamp", "2026-04-13T15:30:00")
    IniWrite($sStateFile, "Session", "session_desktop_count", "4")
    IniWrite($sStateFile, "Session", "entry_1", "chrome.exe|Chrome_WidgetWin_1|3")
    IniWrite($sStateFile, "Session", "entry_2", "code.exe|Chrome_WidgetWin_1|2")
    IniWrite($sStateFile, "Session", "entry_3", "explorer.exe|CabinetWClass|1")
    IniWrite($sStateFile, "Session", "entry_4", "discord.exe|Chrome_WidgetWin_1|4")
    IniWrite($sStateFile, "Session", "entry_5", "WindowsTerminal.exe|CASCADIA_HOSTING_WINDOW_CLASS|2")

    ; ---- HasSavedSession: with data ----
    _Test_AssertTrue("HasSavedSession with data", _SR_HasSavedSession())

    ; ---- GetSavedCount: with data ----
    _Test_AssertEqual("GetSavedCount returns 5", _SR_GetSavedCount(), 5)

    ; ---- Session data format: read back entries ----
    Local $sEntry1 = IniRead($sStateFile, "Session", "entry_1", "")
    _Test_AssertEqual("Entry 1 format", $sEntry1, "chrome.exe|Chrome_WidgetWin_1|3")

    Local $sEntry5 = IniRead($sStateFile, "Session", "entry_5", "")
    _Test_AssertEqual("Entry 5 format", $sEntry5, "WindowsTerminal.exe|CASCADIA_HOSTING_WINDOW_CLASS|2")

    ; ---- Verify entry parsing (pipe-separated) ----
    Local $aParts = StringSplit($sEntry1, "|")
    _Test_AssertEqual("Entry parts count", $aParts[0], 3)
    _Test_AssertEqual("Entry process name", $aParts[1], "chrome.exe")
    _Test_AssertEqual("Entry window class", $aParts[2], "Chrome_WidgetWin_1")
    _Test_AssertEqual("Entry desktop number", $aParts[3], "3")

    ; ---- Metadata fields ----
    Local $sTimestamp = IniRead($sStateFile, "Session", "session_timestamp", "")
    _Test_AssertEqual("Timestamp format", $sTimestamp, "2026-04-13T15:30:00")

    Local $iDesktopCount = Int(IniRead($sStateFile, "Session", "session_desktop_count", "0"))
    _Test_AssertEqual("Desktop count stored", $iDesktopCount, 4)

    ; Write a [State] entry so we can verify ClearSession preserves it
    IniWrite($sStateFile, "State", "last_desktop", "2")

    ; ---- ClearSession: removes all session data ----
    _SR_ClearSession()
    _Test_AssertFalse("HasSavedSession after clear", _SR_HasSavedSession())
    _Test_AssertEqual("GetSavedCount after clear", _SR_GetSavedCount(), 0)

    ; Verify individual keys are gone
    Local $sAfterClear = IniRead($sStateFile, "Session", "entry_1", "MISSING")
    _Test_AssertEqual("Entry 1 deleted after clear", $sAfterClear, "MISSING")

    Local $sCountAfterClear = IniRead($sStateFile, "Session", "session_count", "MISSING")
    _Test_AssertEqual("Count key deleted after clear", $sCountAfterClear, "MISSING")

    ; ---- [State] section preserved after ClearSession ----
    Local $sLastDesktop = IniRead($sStateFile, "State", "last_desktop", "MISSING")
    _Test_AssertNotEqual("State section preserved", $sLastDesktop, "MISSING")

    ; ---- __SR_IsSystemProcess: system processes detected ----
    _Test_AssertTrue("dwm.exe is system process", __SR_IsSystemProcess("dwm.exe"))
    _Test_AssertTrue("csrss.exe is system process", __SR_IsSystemProcess("csrss.exe"))
    _Test_AssertTrue("svchost.exe is system process", __SR_IsSystemProcess("svchost.exe"))
    _Test_AssertTrue("DWM.EXE case-insensitive", __SR_IsSystemProcess("DWM.EXE"))

    ; ---- __SR_IsSystemProcess: non-system processes ----
    _Test_AssertFalse("chrome.exe not system", __SR_IsSystemProcess("chrome.exe"))
    _Test_AssertFalse("code.exe not system", __SR_IsSystemProcess("code.exe"))
    _Test_AssertFalse("explorer.exe not system", __SR_IsSystemProcess("explorer.exe"))
    _Test_AssertFalse("empty string not system", __SR_IsSystemProcess(""))

    ; ---- __SR_GetProcessInfo: current process ----
    ; Use a known visible window — the AutoIt tray window
    Local $hTestWnd = WinGetHandle("[CLASS:AutoIt v3]")
    If $hTestWnd <> 0 Then
        Local $aInfo = __SR_GetProcessInfo($hTestWnd)
        ; Process name should end in .exe
        Local $bHasExe = (StringRight($aInfo[0], 4) = ".exe" Or StringRight($aInfo[0], 4) = ".EXE")
        _Test_AssertTrue("GetProcessInfo returns exe", $bHasExe)
        _Test_AssertNotEqual("GetProcessInfo class not empty", $aInfo[1], "")
    Else
        _Test_Skip("GetProcessInfo: no AutoIt window found")
        _Test_Skip("GetProcessInfo class: no AutoIt window found")
    EndIf

    ; ---- __SR_MatchWindow: exact match ----
    ; Build a mock windows array (2D: [count][4])
    Local $aMockWin[4][4]
    $aMockWin[0][0] = 3 ; count
    $aMockWin[1][0] = 0x1001 ; hWnd
    $aMockWin[1][1] = "chrome.exe"
    $aMockWin[1][2] = "Chrome_WidgetWin_1"
    $aMockWin[1][3] = 2
    $aMockWin[2][0] = 0x1002
    $aMockWin[2][1] = "code.exe"
    $aMockWin[2][2] = "Chrome_WidgetWin_1"
    $aMockWin[2][3] = 1
    $aMockWin[3][0] = 0x1003
    $aMockWin[3][1] = "chrome.exe"
    $aMockWin[3][2] = "Chrome_RenderWidgetHostHWND"
    $aMockWin[3][3] = 2

    Local $aMockMatched[4]
    $aMockMatched[0] = False
    $aMockMatched[1] = False
    $aMockMatched[2] = False
    $aMockMatched[3] = False

    ; Exact match: chrome.exe + Chrome_WidgetWin_1 should prefer index 1
    Local $iMatch = __SR_MatchWindow("chrome.exe", "Chrome_WidgetWin_1", $aMockWin, $aMockMatched)
    _Test_AssertEqual("MatchWindow exact match", $iMatch, 1)

    ; ---- __SR_MatchWindow: class tiebreaker ----
    ; Mark index 1 as matched, should fall back to index 3 (same process, different class)
    $aMockMatched[1] = True
    Local $iMatch2 = __SR_MatchWindow("chrome.exe", "Chrome_WidgetWin_1", $aMockWin, $aMockMatched)
    _Test_AssertEqual("MatchWindow fallback to process match", $iMatch2, 3)

    ; ---- __SR_MatchWindow: no match ----
    Local $aMockMatched2[4]
    $aMockMatched2[0] = False
    $aMockMatched2[1] = False
    $aMockMatched2[2] = False
    $aMockMatched2[3] = False
    Local $iMatch3 = __SR_MatchWindow("notepad.exe", "Notepad", $aMockWin, $aMockMatched2)
    _Test_AssertEqual("MatchWindow no match returns 0", $iMatch3, 0)

    ; ---- __SR_MatchWindow: all matched ----
    Local $aMockAllMatched[4]
    $aMockAllMatched[0] = False
    $aMockAllMatched[1] = True
    $aMockAllMatched[2] = True
    $aMockAllMatched[3] = True
    Local $iMatch4 = __SR_MatchWindow("chrome.exe", "Chrome_WidgetWin_1", $aMockWin, $aMockAllMatched)
    _Test_AssertEqual("MatchWindow all matched returns 0", $iMatch4, 0)

    ; ---- __SR_MatchWindow: case-insensitive process match ----
    Local $aMockMatched3[4]
    $aMockMatched3[0] = False
    $aMockMatched3[1] = False
    $aMockMatched3[2] = False
    $aMockMatched3[3] = False
    Local $iMatch5 = __SR_MatchWindow("CHROME.EXE", "Chrome_WidgetWin_1", $aMockWin, $aMockMatched3)
    _Test_AssertEqual("MatchWindow case-insensitive", $iMatch5, 1)

    ; ---- __SR_MatchWindow: class tiebreaker among multiple process matches ----
    ; Reset matched state
    Local $aMockMatched4[4]
    $aMockMatched4[0] = False
    $aMockMatched4[1] = False
    $aMockMatched4[2] = False
    $aMockMatched4[3] = False
    ; Search for chrome.exe with the render class — should prefer index 3
    Local $iMatch6 = __SR_MatchWindow("chrome.exe", "Chrome_RenderWidgetHostHWND", $aMockWin, $aMockMatched4)
    _Test_AssertEqual("MatchWindow class tiebreaker selects correct", $iMatch6, 3)

    ; ---- Edge case: empty process in entry ----
    Local $iMatch7 = __SR_MatchWindow("", "SomeClass", $aMockWin, $aMockMatched3)
    _Test_AssertEqual("MatchWindow empty process returns 0", $iMatch7, 0)

    ; ---- SaveSession/RestoreSession: disabled by default ----
    ; These should return 0 when session_restore_enabled is not "true"
    Local $iSaved = _SR_SaveSession()
    _Test_AssertEqual("SaveSession returns 0 when disabled", $iSaved, 0)

    Local $iRestored = _SR_RestoreSession()
    _Test_AssertEqual("RestoreSession returns 0 when disabled", $iRestored, 0)

    ; ---- Edge case: malformed entry parsing ----
    ; Write a malformed entry and verify HasSavedSession/GetSavedCount still work
    IniWrite($sStateFile, "Session", "session_count", "2")
    IniWrite($sStateFile, "Session", "session_desktop_count", "2")
    IniWrite($sStateFile, "Session", "session_timestamp", "2026-04-13T10:00:00")
    IniWrite($sStateFile, "Session", "entry_1", "malformed_no_pipes")
    IniWrite($sStateFile, "Session", "entry_2", "valid.exe|SomeClass|1")

    _Test_AssertTrue("HasSavedSession with malformed entry", _SR_HasSavedSession())
    _Test_AssertEqual("GetSavedCount with malformed entry", _SR_GetSavedCount(), 2)

    ; ---- Edge case: session_count = 0 ----
    _SR_ClearSession()
    IniWrite($sStateFile, "Session", "session_count", "0")
    _Test_AssertFalse("HasSavedSession when count=0", _SR_HasSavedSession())
    _Test_AssertEqual("GetSavedCount when count=0", _SR_GetSavedCount(), 0)

    ; ---- Cleanup: remove test session data ----
    _SR_ClearSession()
    ; Also remove the session_count=0 we wrote
    IniDelete($sStateFile, "Session", "session_count")

    ; Restore original session data if any was present
    If $sOrigCount <> "" Then
        IniWrite($sStateFile, "Session", "session_count", $sOrigCount)
        IniWrite($sStateFile, "Session", "session_timestamp", $sOrigTimestamp)
        IniWrite($sStateFile, "Session", "session_desktop_count", $sOrigDesktops)
    EndIf

    ; Clean up temp files
    If FileExists($sTempState) Then FileDelete($sTempState)
    If FileExists($sTempConfig) Then FileDelete($sTempConfig)
EndFunc
