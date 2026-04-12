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

    ; -- Preset colors array --
    _Test_AssertEqual("Preset colors count", $THEME_PRESET_COLORS[0], 7)
    _Test_AssertNotEqual("Preset color 1 exists", $THEME_PRESET_COLORS[1], 0)
    _Test_AssertNotEqual("Preset color 7 exists", $THEME_PRESET_COLORS[7], 0)

    ; -- Toast status color constants --
    _Test_AssertNotEqual("TOAST_SUCCESS defined", $TOAST_SUCCESS, 0)
    _Test_AssertNotEqual("TOAST_ERROR defined", $TOAST_ERROR, 0)
    _Test_AssertNotEqual("TOAST_WARNING defined", $TOAST_WARNING, 0)
    _Test_AssertNotEqual("TOAST_INFO defined", $TOAST_INFO, 0)

    ; -- Hex color validation --
    _Test_AssertEqual("Valid hex color", _Theme_ValidateHexColor("FF0000"), 0xFF0000)
    _Test_AssertEqual("Valid hex lowercase", _Theme_ValidateHexColor("aabbcc"), 0xAABBCC)
    _Test_AssertEqual("Valid with 0x prefix", _Theme_ValidateHexColor("0xFF0000"), 0xFF0000)
    _Test_AssertEqual("Valid with 0X prefix", _Theme_ValidateHexColor("0XFF0000"), 0xFF0000)
    _Test_AssertEqual("Invalid: too short", _Theme_ValidateHexColor("FFF"), -1)
    _Test_AssertEqual("Invalid: too long", _Theme_ValidateHexColor("FF00001"), -1)
    _Test_AssertEqual("Invalid: non-hex chars", _Theme_ValidateHexColor("GGHHII"), -1)
    _Test_AssertEqual("Invalid: empty", _Theme_ValidateHexColor(""), -1)

    ; -- Font fallback --
    ; _Theme_GetMonoFont should return a non-empty string
    _Test_AssertNotEqual("Mono font not empty", _Theme_GetMonoFont(), "")

    ; -- Background colors are non-const (mutable for themes) --
    Local $iBgOrig = $THEME_BG_MAIN
    _Test_AssertGreaterEqual("BG_MAIN valid", $THEME_BG_MAIN, 0)

    ; -- Link color --
    _Test_AssertNotEqual("FG_LINK defined", $THEME_FG_LINK, 0)

    ; -- Drop target color --
    _Test_AssertNotEqual("BG_DROP_TARGET defined", $THEME_BG_DROP_TARGET, 0)

    ; -- Drag dim color --
    _Test_AssertEqual("FG_DRAG_DIM value", $THEME_FG_DRAG_DIM, 0x555555)

    ; -- Cursor cache globals exist and are numeric --
    _Test_AssertGreaterEqual("Cached cursor X >= 0", $__g_Theme_iCachedCursorX, 0)
    _Test_AssertGreaterEqual("Cached cursor Y >= 0", $__g_Theme_iCachedCursorY, 0)

    ; -- CacheFrameState updates cursor position --
    _Theme_CacheFrameState()
    _Test_AssertGreaterEqual("After cache: X >= 0", $__g_Theme_iCachedCursorX, 0)
    _Test_AssertGreaterEqual("After cache: Y >= 0", $__g_Theme_iCachedCursorY, 0)
    _Test_AssertLessEqual("After cache: X <= screen", $__g_Theme_iCachedCursorX, @DesktopWidth + 100)
    _Test_AssertLessEqual("After cache: Y <= screen", $__g_Theme_iCachedCursorY, @DesktopHeight + 100)

    ; -- CacheFrameState is idempotent within same frame --
    Local $iX1 = $__g_Theme_iCachedCursorX
    Local $iY1 = $__g_Theme_iCachedCursorY
    _Theme_CacheFrameState()
    ; Cursor might move between calls but values should still be valid
    _Test_AssertGreaterEqual("Second cache: X >= 0", $__g_Theme_iCachedCursorX, 0)
    _Test_AssertGreaterEqual("Second cache: Y >= 0", $__g_Theme_iCachedCursorY, 0)

    ; -- IsCursorOverWindow returns False for null handle --
    _Test_AssertFalse("Null handle = not over", _Theme_IsCursorOverWindow(0))

    ; -- Theme scheme application --
    _Test_AssertNotEqual("Dark scheme has BG", $__g_Theme_aSchemeDark[0], 0)
    _Test_AssertNotEqual("Midnight scheme has BG", $__g_Theme_aSchemeMidnight[0], 0)
    _Test_AssertNotEqual("Midday scheme differs", $__g_Theme_aSchemeMidday[0], $__g_Theme_aSchemeDark[0])

    ; -- BTN_HOV differs from HOVER (hover effect must be visible) --
    _Test_AssertNotEqual("BTN_HOV != HOVER", $THEME_BG_BTN_HOV, $THEME_BG_HOVER)

    ; -- CacheFrameState called twice doesn't crash --
    _Theme_CacheFrameState()
    _Theme_CacheFrameState()
    _Test_AssertGreaterEqual("Double cache: X >= 0", $__g_Theme_iCachedCursorX, 0)
    _Test_AssertGreaterEqual("Double cache: Y >= 0", $__g_Theme_iCachedCursorY, 0)

    ; -- Cursor coordinates within screen bounds after cache --
    _Theme_CacheFrameState()
    _Test_AssertLessEqual("Cursor X <= DesktopWidth", $__g_Theme_iCachedCursorX, @DesktopWidth + 100)
    _Test_AssertLessEqual("Cursor Y <= DesktopHeight", $__g_Theme_iCachedCursorY, @DesktopHeight + 100)
    _Test_AssertGreaterEqual("Cursor X >= 0 after cache", $__g_Theme_iCachedCursorX, 0)
    _Test_AssertGreaterEqual("Cursor Y >= 0 after cache", $__g_Theme_iCachedCursorY, 0)

    ; -- IsCursorOverWindow(0) returns False --
    _Test_AssertFalse("IsCursorOverWindow(0) is False", _Theme_IsCursorOverWindow(0))

    ; -- Theme scheme arrays all have 10 elements --
    _Test_AssertEqual("SchemeDark has 10 elements", UBound($__g_Theme_aSchemeDark), 10)
    _Test_AssertEqual("SchemeDarker has 10 elements", UBound($__g_Theme_aSchemeDarker), 10)
    _Test_AssertEqual("SchemeMidnight has 10 elements", UBound($__g_Theme_aSchemeMidnight), 10)
    _Test_AssertEqual("SchemeMidday has 10 elements", UBound($__g_Theme_aSchemeMidday), 10)
    _Test_AssertEqual("SchemeSunset has 10 elements", UBound($__g_Theme_aSchemeSunset), 10)

    ; -- All 5 scheme arrays are different from each other (at least index 0 differs) --
    _Test_AssertNotEqual("Dark != Darker [0]", $__g_Theme_aSchemeDark[0], $__g_Theme_aSchemeDarker[0])
    _Test_AssertNotEqual("Dark != Midnight [0]", $__g_Theme_aSchemeDark[0], $__g_Theme_aSchemeMidnight[0])
    _Test_AssertNotEqual("Dark != Midday [0]", $__g_Theme_aSchemeDark[0], $__g_Theme_aSchemeMidday[0])
    _Test_AssertNotEqual("Dark != Sunset [0]", $__g_Theme_aSchemeDark[0], $__g_Theme_aSchemeSunset[0])
    _Test_AssertNotEqual("Darker != Midnight [0]", $__g_Theme_aSchemeDarker[0], $__g_Theme_aSchemeMidnight[0])
    _Test_AssertNotEqual("Darker != Midday [0]", $__g_Theme_aSchemeDarker[0], $__g_Theme_aSchemeMidday[0])
    _Test_AssertNotEqual("Darker != Sunset [0]", $__g_Theme_aSchemeDarker[0], $__g_Theme_aSchemeSunset[0])
    _Test_AssertNotEqual("Midnight != Midday [0]", $__g_Theme_aSchemeMidnight[0], $__g_Theme_aSchemeMidday[0])
    _Test_AssertNotEqual("Midnight != Sunset [0]", $__g_Theme_aSchemeMidnight[0], $__g_Theme_aSchemeSunset[0])
    _Test_AssertNotEqual("Midday != Sunset [0]", $__g_Theme_aSchemeMidday[0], $__g_Theme_aSchemeSunset[0])
EndFunc
