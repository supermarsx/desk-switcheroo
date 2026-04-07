#include-once

; ===============================================================
; Tests for includes\Theme.au3
; Unit tests — no GUI required
; ===============================================================

Func _RunTest_Theme()
    _Test_Suite("Theme")

    ; -- Color constants in valid range --
    _Test_AssertGreaterEqual("BG_MAIN >= 0x000000", $THEME_BG_MAIN, 0x000000)
    _Test_AssertLessEqual("BG_MAIN <= 0xFFFFFF", $THEME_BG_MAIN, 0xFFFFFF)
    _Test_AssertGreaterEqual("BG_POPUP >= 0x000000", $THEME_BG_POPUP, 0x000000)
    _Test_AssertLessEqual("BG_POPUP <= 0xFFFFFF", $THEME_BG_POPUP, 0xFFFFFF)
    _Test_AssertGreaterEqual("BG_INPUT >= 0x000000", $THEME_BG_INPUT, 0x000000)
    _Test_AssertLessEqual("BG_INPUT <= 0xFFFFFF", $THEME_BG_INPUT, 0xFFFFFF)
    _Test_AssertGreaterEqual("BG_HOVER >= 0x000000", $THEME_BG_HOVER, 0x000000)
    _Test_AssertLessEqual("BG_HOVER <= 0xFFFFFF", $THEME_BG_HOVER, 0xFFFFFF)
    _Test_AssertGreaterEqual("FG_PRIMARY >= 0x000000", $THEME_FG_PRIMARY, 0x000000)
    _Test_AssertLessEqual("FG_PRIMARY <= 0xFFFFFF", $THEME_FG_PRIMARY, 0xFFFFFF)
    _Test_AssertGreaterEqual("FG_WHITE >= 0x000000", $THEME_FG_WHITE, 0x000000)
    _Test_AssertLessEqual("FG_WHITE <= 0xFFFFFF", $THEME_FG_WHITE, 0xFFFFFF)

    ; -- Timer constants are positive --
    _Test_AssertGreaterEqual("TIMER_TOPMOST > 0", $THEME_TIMER_TOPMOST, 1)
    _Test_AssertGreaterEqual("TIMER_POLL > 0", $THEME_TIMER_POLL, 1)
    _Test_AssertGreaterEqual("TIMER_BOUNCE > 0", $THEME_TIMER_BOUNCE, 1)
    _Test_AssertGreaterEqual("TIMER_TEMPLIST > 0", $THEME_TIMER_TEMPLIST, 1)

    ; -- Timer constants are in expected order --
    _Test_AssertTrue("TOPMOST < POLL", $THEME_TIMER_TOPMOST < $THEME_TIMER_POLL)
    _Test_AssertTrue("POLL < BOUNCE", $THEME_TIMER_POLL < $THEME_TIMER_BOUNCE)
    _Test_AssertTrue("BOUNCE < TEMPLIST", $THEME_TIMER_BOUNCE < $THEME_TIMER_TEMPLIST)

    ; -- Dimension constants --
    _Test_AssertEqual("MAIN_WIDTH = 130", $THEME_MAIN_WIDTH, 130)
    _Test_AssertEqual("BTN_WIDTH = 32", $THEME_BTN_WIDTH, 32)
    _Test_AssertEqual("ITEM_HEIGHT = 24", $THEME_ITEM_HEIGHT, 24)
    _Test_AssertEqual("MENU_ITEM_H = 30", $THEME_MENU_ITEM_H, 30)
    _Test_AssertEqual("PEEK_ZONE_W = 20", $THEME_PEEK_ZONE_W, 20)

    ; -- Font constants are non-empty --
    _Test_AssertNotEqual("FONT_MAIN not empty", $THEME_FONT_MAIN, "")
    _Test_AssertNotEqual("FONT_SYMBOL not empty", $THEME_FONT_SYMBOL, "")

    ; -- Alpha values in valid range --
    _Test_AssertGreaterEqual("ALPHA_MAIN >= 0", $THEME_ALPHA_MAIN, 0)
    _Test_AssertLessEqual("ALPHA_MAIN <= 255", $THEME_ALPHA_MAIN, 255)
    _Test_AssertGreaterEqual("ALPHA_POPUP >= 0", $THEME_ALPHA_POPUP, 0)
    _Test_AssertLessEqual("ALPHA_POPUP <= 255", $THEME_ALPHA_POPUP, 255)
    _Test_AssertGreaterEqual("ALPHA_MENU >= 0", $THEME_ALPHA_MENU, 0)
    _Test_AssertLessEqual("ALPHA_MENU <= 255", $THEME_ALPHA_MENU, 255)
    _Test_AssertGreaterEqual("ALPHA_DIALOG >= 0", $THEME_ALPHA_DIALOG, 0)
    _Test_AssertLessEqual("ALPHA_DIALOG <= 255", $THEME_ALPHA_DIALOG, 255)
EndFunc
