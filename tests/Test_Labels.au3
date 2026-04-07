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

    ; -- Cleanup --
    FileDelete($sTempIni)
EndFunc
