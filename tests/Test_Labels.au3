#include-once

; ===============================================================
; Tests for includes\Labels.au3
; Unit tests — uses a temp INI file, no GUI required
; ===============================================================

Func _RunTest_Labels()
    _Test_Suite("Labels")

    ; Use a temp file for testing
    Local $sTempIni = @TempDir & "\desk_switcheroo_test_labels.ini"
    ; Clean up from previous runs
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; -- Init sets path (sync disabled for isolated INI testing) --
    _Labels_Init($sTempIni, False)
    _Test_AssertEqual("Init sets path", _Labels_GetPath(), $sTempIni)
    _Test_AssertFalse("Sync disabled in test mode", _Labels_IsSyncEnabled())

    ; -- Save and load --
    _Labels_Save(1, "Work")
    _Test_AssertEqual("Save+Load desktop 1", _Labels_Load(1), "Work")

    ; -- Load missing returns empty --
    _Test_AssertEqual("Load missing key returns empty", _Labels_Load(99), "")

    ; -- Overwrite existing --
    _Labels_Save(1, "Gaming")
    _Test_AssertEqual("Overwrite: new value", _Labels_Load(1), "Gaming")

    ; -- Empty string --
    _Labels_Save(2, "")
    _Test_AssertEqual("Save empty string", _Labels_Load(2), "")

    ; -- Special characters --
    _Labels_Save(3, "My Desktop #3!")
    _Test_AssertEqual("Special characters", _Labels_Load(3), "My Desktop #3!")

    ; -- Multiple desktops --
    _Labels_Save(1, "Alpha")
    _Labels_Save(2, "Beta")
    _Labels_Save(3, "Gamma")
    _Labels_Save(4, "Delta")
    _Labels_Save(5, "Epsilon")
    _Test_AssertEqual("Multi: desktop 1", _Labels_Load(1), "Alpha")
    _Test_AssertEqual("Multi: desktop 2", _Labels_Load(2), "Beta")
    _Test_AssertEqual("Multi: desktop 3", _Labels_Load(3), "Gamma")
    _Test_AssertEqual("Multi: desktop 4", _Labels_Load(4), "Delta")
    _Test_AssertEqual("Multi: desktop 5", _Labels_Load(5), "Epsilon")

    ; -- Unicode characters in labels --
    _Labels_Save(1, "Área de Trabalho")
    _Test_AssertEqual("Unicode label", _Labels_Load(1), "Área de Trabalho")

    ; -- Very long label --
    Local $sLong = ""
    Local $j
    For $j = 1 To 50
        $sLong &= "A"
    Next
    _Labels_Save(1, $sLong)
    _Test_AssertEqual("Long label length", StringLen(_Labels_Load(1)), 50)

    ; -- Label with equals sign (INI edge case) --
    _Labels_Save(1, "key=value")
    _Test_AssertEqual("Label with equals", _Labels_Load(1), "key=value")

    ; -- Sync enabled check --
    _Test_AssertFalse("Sync disabled in test", _Labels_IsSyncEnabled())

    ; -- SyncFromOS returns false when disabled --
    _Test_AssertFalse("SyncFromOS false when disabled", _Labels_SyncFromOS())

    ; -- Deferred sync cooldown helper --
    _Labels_DeferSync(2)
    _Test_AssertEqual("Deferred sync polls set", _Labels_GetDeferredSyncPolls(), 2)
    _Test_AssertTrue("Deferred sync consume #1", __Labels_ConsumeSyncCooldown())
    _Test_AssertEqual("Deferred sync polls decremented", _Labels_GetDeferredSyncPolls(), 1)
    _Labels_DeferSync(3)
    _Test_AssertEqual("Deferred sync keeps larger cooldown", _Labels_GetDeferredSyncPolls(), 3)
    _Test_AssertTrue("Deferred sync consume #2", __Labels_ConsumeSyncCooldown())
    _Test_AssertTrue("Deferred sync consume #3", __Labels_ConsumeSyncCooldown())
    _Test_AssertTrue("Deferred sync consume #4", __Labels_ConsumeSyncCooldown())
    _Test_AssertFalse("Deferred sync exhausted", __Labels_ConsumeSyncCooldown())

    ; -- Cache tests --
    _Labels_Save(1, "CachedLabel")
    _Test_AssertEqual("Label cached after save", _Labels_Load(1), "CachedLabel")
    ; Invalidate and verify reload works
    _Labels_InvalidateCache()
    _Test_AssertEqual("Label reloads after invalidate", _Labels_Load(1), "CachedLabel")

    ; -- Swap: updates stored labels and forces immediate reload --
    FileDelete($sTempIni)
    _Labels_InvalidateCache()
    _Labels_Save(1, "Alpha")
    _Labels_Save(2, "Beta")
    _Labels_Swap(1, 2)
    _Test_AssertEqual("Swap: pos 1 = old Beta", _Labels_Load(1), "Beta")
    _Test_AssertEqual("Swap: pos 2 = old Alpha", _Labels_Load(2), "Alpha")
    _Test_AssertEqual("Swap: INI pos 1", IniRead($sTempIni, "Labels", "desktop_1", ""), "Beta")
    _Test_AssertEqual("Swap: INI pos 2", IniRead($sTempIni, "Labels", "desktop_2", ""), "Alpha")
    _Test_AssertEqual("Swap: no cooldown when sync disabled", _Labels_GetDeferredSyncPolls(), 0)

    ; -- RemoveAndShift: middle removal shifts higher labels down --
    FileDelete($sTempIni)
    _Labels_InvalidateCache()
    _Labels_Save(1, "A")
    _Labels_Save(2, "B")
    _Labels_Save(3, "C")
    _Labels_Save(4, "D")
    _Labels_Save(5, "E")
    _Labels_RemoveAndShift(3, 5)
    _Labels_InvalidateCache()
    _Test_AssertEqual("Shift: pos 1 unchanged", _Labels_Load(1), "A")
    _Test_AssertEqual("Shift: pos 2 unchanged", _Labels_Load(2), "B")
    _Test_AssertEqual("Shift: pos 3 = old D", _Labels_Load(3), "D")
    _Test_AssertEqual("Shift: pos 4 = old E", _Labels_Load(4), "E")
    _Test_AssertEqual("Shift: pos 5 cleared", _Labels_Load(5), "")
    ; Verify orphan key is actually removed (not just empty-valued)
    _Test_AssertEqual("Shift: orphan key purged", IniRead($sTempIni, "Labels", "desktop_5", "MISSING"), "MISSING")

    ; -- RemoveAndShift: end removal just purges the orphan --
    FileDelete($sTempIni)
    _Labels_InvalidateCache()
    _Labels_Save(1, "A")
    _Labels_Save(2, "B")
    _Labels_Save(3, "C")
    _Labels_RemoveAndShift(3, 3)
    _Labels_InvalidateCache()
    _Test_AssertEqual("End-shift: pos 1 unchanged", _Labels_Load(1), "A")
    _Test_AssertEqual("End-shift: pos 2 unchanged", _Labels_Load(2), "B")
    _Test_AssertEqual("End-shift: pos 3 purged", IniRead($sTempIni, "Labels", "desktop_3", "MISSING"), "MISSING")

    ; -- RemoveAndShift: removing the first desktop shifts all down --
    FileDelete($sTempIni)
    _Labels_InvalidateCache()
    _Labels_Save(1, "A")
    _Labels_Save(2, "B")
    _Labels_Save(3, "C")
    _Labels_RemoveAndShift(1, 3)
    _Labels_InvalidateCache()
    _Test_AssertEqual("First-shift: pos 1 = old B", _Labels_Load(1), "B")
    _Test_AssertEqual("First-shift: pos 2 = old C", _Labels_Load(2), "C")
    _Test_AssertEqual("First-shift: pos 3 purged", IniRead($sTempIni, "Labels", "desktop_3", "MISSING"), "MISSING")

    ; -- Cleanup --
    FileDelete($sTempIni)
EndFunc
