#include-once

; ===============================================================
; Tests for includes\RenameDialog.au3
; GUI tests — creates actual windows, requires Labels module
; ===============================================================

Func _RunTest_RenameDialog()
    _Test_Suite("RenameDialog")

    ; Set up Labels with temp INI
    Local $sTempIni = @TempDir & "\desk_switcheroo_test_rd.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    _Labels_Init($sTempIni, False)
    _Labels_Save(1, "OldLabel")

    ; Init the rename dialog module
    _RD_Init()

    Local $iTestTaskbarY = @DesktopHeight - 48

    ; -- Initially not visible --
    _Test_AssertFalse("Initially not visible", _RD_IsVisible())
    _Test_AssertEqual("Initially GUI = 0", _RD_GetGUI(), 0)

    ; -- Show creates dialog --
    _RD_Show(1, $iTestTaskbarY)
    _Test_AssertTrue("Show: is visible", _RD_IsVisible())
    _Test_AssertNotEqual("Show: GUI <> 0", _RD_GetGUI(), 0)

    ; -- Destroy removes dialog --
    _RD_Destroy()
    _Test_AssertFalse("Destroy: not visible", _RD_IsVisible())
    _Test_AssertEqual("Destroy: GUI = 0", _RD_GetGUI(), 0)

    ; -- Submit returns text and persists label --
    _RD_Show(1, $iTestTaskbarY)
    ; Set input text programmatically
    GUICtrlSetData(_RD_GetInputField(), "Gaming")
    Local $sResult = _RD_Submit(1)
    _Test_AssertEqual("Submit returns input text", $sResult, "Gaming")
    _Test_AssertEqual("Submit persists label", _Labels_Load(1), "Gaming")
    _Test_AssertFalse("Not visible after submit", _RD_IsVisible())

    ; -- Cancel does not save --
    _Labels_Save(1, "BeforeCancel")
    _RD_Show(1, $iTestTaskbarY)
    GUICtrlSetData(_RD_GetInputField(), "ShouldNotSave")
    _RD_SetCancelled()
    _RD_Destroy()
    _Test_AssertEqual("Cancel preserves old label", _Labels_Load(1), "BeforeCancel")

    ; -- Empty submit saves empty --
    _RD_Show(1, $iTestTaskbarY)
    GUICtrlSetData(_RD_GetInputField(), "")
    Local $sEmpty = _RD_Submit(1)
    _Test_AssertEqual("Empty submit returns empty", $sEmpty, "")
    _Test_AssertEqual("Empty submit persists empty", _Labels_Load(1), "")

    ; -- HandleEvent returns correct actions --
    _RD_Show(1, $iTestTaskbarY)
    _Test_AssertEqual("HandleEvent(close)", _RD_HandleEvent($GUI_EVENT_CLOSE), "close")
    _Test_AssertEqual("HandleEvent(ok)", _RD_HandleEvent(_RD_GetBtnOk()), "submit")
    _Test_AssertEqual("HandleEvent(cancel)", _RD_HandleEvent(_RD_GetBtnCancel()), "cancel")
    _Test_AssertEqual("HandleEvent(0) = empty", _RD_HandleEvent(0), "")
    _RD_Destroy()

    ; -- Cleanup --
    _RD_Shutdown()
    FileDelete($sTempIni)
EndFunc
