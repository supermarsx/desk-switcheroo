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

    ; -- Dialog visibility (before show) --
    _Test_AssertFalse("CD not visible initially", _CD_IsVisible())
    _Test_AssertEqual("CD GUI handle is 0", _CD_GetGUI(), 0)
EndFunc
