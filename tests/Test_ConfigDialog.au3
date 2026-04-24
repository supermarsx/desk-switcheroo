#include-once

; ===============================================================
; Tests for includes\ConfigDialog.au3
; Unit tests for pure logic functions (no GUI required)
; ===============================================================

Func _RunTest_ConfigDialog()
    _Test_Suite("ConfigDialog")

    ; -- VK to AutoIt key mappings --
    _Test_AssertEqual("VK 0x08 = BS", __CD_VKToAutoItKey(0x08), "BS")
    _Test_AssertEqual("VK 0x09 = TAB", __CD_VKToAutoItKey(0x09), "TAB")
    _Test_AssertEqual("VK 0x0D = ENTER", __CD_VKToAutoItKey(0x0D), "ENTER")
    _Test_AssertEqual("VK 0x1B = ESC", __CD_VKToAutoItKey(0x1B), "ESC")
    _Test_AssertEqual("VK 0x20 = SPACE", __CD_VKToAutoItKey(0x20), "SPACE")
    _Test_AssertEqual("VK 0x25 = LEFT", __CD_VKToAutoItKey(0x25), "LEFT")
    _Test_AssertEqual("VK 0x26 = UP", __CD_VKToAutoItKey(0x26), "UP")
    _Test_AssertEqual("VK 0x27 = RIGHT", __CD_VKToAutoItKey(0x27), "RIGHT")
    _Test_AssertEqual("VK 0x28 = DOWN", __CD_VKToAutoItKey(0x28), "DOWN")
    _Test_AssertEqual("VK 0x2D = INSERT", __CD_VKToAutoItKey(0x2D), "INSERT")
    _Test_AssertEqual("VK 0x2E = DELETE", __CD_VKToAutoItKey(0x2E), "DELETE")

    ; Digit keys
    _Test_AssertEqual("VK 0x30 = 0", __CD_VKToAutoItKey(0x30), "0")
    _Test_AssertEqual("VK 0x39 = 9", __CD_VKToAutoItKey(0x39), "9")

    ; Letter keys (lowercase)
    _Test_AssertEqual("VK 0x41 = a", __CD_VKToAutoItKey(0x41), "a")
    _Test_AssertEqual("VK 0x5A = z", __CD_VKToAutoItKey(0x5A), "z")
    _Test_AssertEqual("VK 0x4D = m", __CD_VKToAutoItKey(0x4D), "m")

    ; Function keys
    _Test_AssertEqual("VK 0x70 = F1", __CD_VKToAutoItKey(0x70), "F1")
    _Test_AssertEqual("VK 0x7B = F12", __CD_VKToAutoItKey(0x7B), "F12")
    _Test_AssertEqual("VK 0x75 = F6", __CD_VKToAutoItKey(0x75), "F6")

    ; Numpad keys
    _Test_AssertEqual("VK 0x60 = NUMPAD0", __CD_VKToAutoItKey(0x60), "NUMPAD0")
    _Test_AssertEqual("VK 0x69 = NUMPAD9", __CD_VKToAutoItKey(0x69), "NUMPAD9")
    _Test_AssertEqual("VK 0x6A = NUMPADMULT", __CD_VKToAutoItKey(0x6A), "NUMPADMULT")
    _Test_AssertEqual("VK 0x6B = NUMPADADD", __CD_VKToAutoItKey(0x6B), "NUMPADADD")
    _Test_AssertEqual("VK 0x6D = NUMPADSUB", __CD_VKToAutoItKey(0x6D), "NUMPADSUB")
    _Test_AssertEqual("VK 0x6F = NUMPADDIV", __CD_VKToAutoItKey(0x6F), "NUMPADDIV")

    ; Punctuation
    _Test_AssertEqual("VK 0xBA = ;", __CD_VKToAutoItKey(0xBA), ";")
    _Test_AssertEqual("VK 0xBB = =", __CD_VKToAutoItKey(0xBB), "=")
    _Test_AssertEqual("VK 0xBD = -", __CD_VKToAutoItKey(0xBD), "-")

    ; Navigation
    _Test_AssertEqual("VK 0x21 = PGUP", __CD_VKToAutoItKey(0x21), "PGUP")
    _Test_AssertEqual("VK 0x22 = PGDN", __CD_VKToAutoItKey(0x22), "PGDN")
    _Test_AssertEqual("VK 0x23 = END", __CD_VKToAutoItKey(0x23), "END")
    _Test_AssertEqual("VK 0x24 = HOME", __CD_VKToAutoItKey(0x24), "HOME")

    ; Unknown VK returns hex in braces
    _Test_AssertEqual("Unknown VK 0xFF", __CD_VKToAutoItKey(0xFF), "{FF}")
    _Test_AssertEqual("Unknown VK 0x01", __CD_VKToAutoItKey(0x01), "{01}")

    ; -- Build hotkey string --
    _Test_AssertEqual("Ctrl+A", __CD_BuildHotkeyString(True, False, False, False, "A"), "^A")
    _Test_AssertEqual("Alt+F1", __CD_BuildHotkeyString(False, True, False, False, "F1"), "!{F1}")
    _Test_AssertEqual("Shift+LEFT", __CD_BuildHotkeyString(False, False, True, False, "LEFT"), "+{LEFT}")
    _Test_AssertEqual("Win+D", __CD_BuildHotkeyString(False, False, False, True, "D"), "#D")
    _Test_AssertEqual("Ctrl+Alt+DELETE", __CD_BuildHotkeyString(True, True, False, False, "DELETE"), "^!{DELETE}")
    _Test_AssertEqual("All mods + RIGHT", __CD_BuildHotkeyString(True, True, True, True, "RIGHT"), "^!+#{RIGHT}")
    _Test_AssertEqual("No mods + S", __CD_BuildHotkeyString(False, False, False, False, "S"), "S")
    _Test_AssertEqual("No mods + ESC", __CD_BuildHotkeyString(False, False, False, False, "ESC"), "{ESC}")
    _Test_AssertEqual("Empty key", __CD_BuildHotkeyString(True, True, False, False, ""), "^!")
    _Test_AssertEqual("Key with spaces", __CD_BuildHotkeyString(False, False, False, False, "  F5  "), "{F5}")
    _Test_AssertEqual("Single char key", __CD_BuildHotkeyString(True, False, False, False, "1"), "^1")

    ; -- Additional VK edge cases --
    _Test_AssertEqual("VK 0x6E = NUMPADDOT", __CD_VKToAutoItKey(0x6E), "NUMPADDOT")
    _Test_AssertEqual("VK 0xC0 = ``", __CD_VKToAutoItKey(0xC0), "``")
    _Test_AssertEqual("VK 0xDB = [", __CD_VKToAutoItKey(0xDB), "[")
    _Test_AssertEqual("VK 0xDC = \", __CD_VKToAutoItKey(0xDC), "\")
    _Test_AssertEqual("VK 0xDD = ]", __CD_VKToAutoItKey(0xDD), "]")

    ; -- Additional punctuation VK --
    _Test_AssertEqual("VK 0xBC = ,", __CD_VKToAutoItKey(0xBC), ",")
    _Test_AssertEqual("VK 0xBE = .", __CD_VKToAutoItKey(0xBE), ".")
    _Test_AssertEqual("VK 0xBF = /", __CD_VKToAutoItKey(0xBF), "/")
    _Test_AssertEqual("VK 0xDE = '", __CD_VKToAutoItKey(0xDE), "'")

    ; -- Build hotkey string with each modifier individually --
    _Test_AssertEqual("Ctrl only + B", __CD_BuildHotkeyString(True, False, False, False, "B"), "^B")
    _Test_AssertEqual("Alt only + B", __CD_BuildHotkeyString(False, True, False, False, "B"), "!B")
    _Test_AssertEqual("Shift only + B", __CD_BuildHotkeyString(False, False, True, False, "B"), "+B")
    _Test_AssertEqual("Win only + B", __CD_BuildHotkeyString(False, False, False, True, "B"), "#B")

    ; -- Build hotkey string with numpad keys (single-char returns) --
    _Test_AssertEqual("Ctrl+NUMPAD0", __CD_BuildHotkeyString(True, False, False, False, "NUMPAD0"), "^{NUMPAD0}")
    _Test_AssertEqual("Alt+NUMPADADD", __CD_BuildHotkeyString(False, True, False, False, "NUMPADADD"), "!{NUMPADADD}")
    _Test_AssertEqual("Shift+NUMPADDOT", __CD_BuildHotkeyString(False, False, True, False, "NUMPADDOT"), "+{NUMPADDOT}")
    _Test_AssertEqual("No mods + NUMPADSUB", __CD_BuildHotkeyString(False, False, False, False, "NUMPADSUB"), "{NUMPADSUB}")

    ; -- Build hotkey string with single-char numpad result keys --
    ; Keys like ";" are single char so no braces
    _Test_AssertEqual("Ctrl+;", __CD_BuildHotkeyString(True, False, False, False, ";"), "^;")
    _Test_AssertEqual("Alt+=", __CD_BuildHotkeyString(False, True, False, False, "="), "!=")
    _Test_AssertEqual("Shift+-", __CD_BuildHotkeyString(False, False, True, False, "-"), "+-")
    _Test_AssertEqual("Win+[", __CD_BuildHotkeyString(False, False, False, True, "["), "#[")

    ; -- Dialog visibility (before show) --
    _Test_AssertFalse("CD not visible initially", _CD_IsVisible())
    _Test_AssertEqual("CD GUI handle is 0", _CD_GetGUI(), 0)

    ; -- Updates status labels refresh from persisted check state --
    Local $sTempIni = @TempDir & "\desk_switcheroo_cd_update_labels.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    _Cfg_Init($sTempIni)
    _Cfg_SetUpdateCheckDays(5)

    Local $hGui = GUICreate("CD Update Labels Test", 240, 80)
    $__g_CD_hGUI = $hGui
    $__g_CD_idLblLastChecked = GUICtrlCreateLabel("", 10, 10, 220, 18)
    $__g_CD_idLblNextCheck = GUICtrlCreateLabel("", 10, 34, 220, 18)

    IniWrite($sTempIni, "Updates", "_last_check_date", "20260424")
    _CD_RefreshUpdateStatusLabels()
    _Test_AssertEqual("Refresh labels: last checked text", GUICtrlRead($__g_CD_idLblLastChecked), "Last checked: 20260424")
    _Test_AssertEqual("Refresh labels: next check text", GUICtrlRead($__g_CD_idLblNextCheck), "Next check: ~20260424 + 5d")

    IniWrite($sTempIni, "Updates", "_last_check_date", "0")
    _CD_RefreshUpdateStatusLabels()
    _Test_AssertEqual("Refresh labels: zero stamp shows Never", GUICtrlRead($__g_CD_idLblLastChecked), "Last checked: Never")
    _Test_AssertEqual("Refresh labels: zero stamp shows N/A", GUICtrlRead($__g_CD_idLblNextCheck), "Next check: N/A")

    GUIDelete($hGui)
    $__g_CD_hGUI = 0
    $__g_CD_idLblLastChecked = 0
    $__g_CD_idLblNextCheck = 0
    FileDelete($sTempIni)
EndFunc
