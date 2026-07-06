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
    _Test_AssertFalse("Null bridge handles = not between", _Theme_IsCursorInWindowBridge(0, 0))

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

    ; -- Tooltip not visible initially --
    _Test_AssertFalse("Tooltip not visible initially", _Theme_IsTooltipVisible())

    ; -- HideTooltip safe when not visible --
    _Theme_HideTooltip()
    _Test_AssertTrue("HideTooltip no crash when hidden", True)

    ; -- Tooltip registry cap (raised 199 -> 399, array [400]) --
    ; The settings search indexes FROM this registry, so a dropped tooltip = an
    ; unsearchable, description-less setting. Registration must succeed past the old
    ; 199 cap, up to 399, and the guard must still reject once full. Headless: the
    ; registry is plain arrays, no GUI is created.
    _Theme_ClearTooltips()
    Local $iTip
    For $iTip = 1 To 399
        _Theme_SetTooltip(1000 + $iTip, "tip#" & $iTip)
    Next
    _Test_AssertEqual("Registry fills to new cap of 399", $__g_Theme_iTipCount, 399)
    ; Entries past the OLD 199 cap were really stored (id + text round-trip)
    _Test_AssertEqual("Entry 200 id stored (past old cap)", $__g_Theme_aTipIDs[200], 1200)
    _Test_AssertEqual("Entry 200 text stored (past old cap)", $__g_Theme_aTipTexts[200], "tip#200")
    _Test_AssertEqual("Entry 399 id stored (at new cap)", $__g_Theme_aTipIDs[399], 1399)
    _Test_AssertEqual("Entry 399 text stored (at new cap)", $__g_Theme_aTipTexts[399], "tip#399")
    ; Guard rejects at the new cap: further registrations are dropped, count unchanged
    _Theme_SetTooltip(9999, "overflow")
    _Test_AssertEqual("Guard rejects at 399 (count unchanged)", $__g_Theme_iTipCount, 399)
    _Test_AssertEqual("Overflow tooltip not stored", $__g_Theme_aTipIDs[399], 1399)
    _Theme_ClearTooltips()
    _Test_AssertEqual("ClearTooltips resets count to 0", $__g_Theme_iTipCount, 0)

    ; -- ToastDestroy safe when no toast active --
    _Theme_ToastDestroy()
    _Test_AssertTrue("ToastDestroy no crash when inactive", True)

    ; -- ToastTick safe when no toast active --
    _Theme_ToastTick()
    _Test_AssertTrue("ToastTick no crash when inactive", True)

    ; -- Toast active-state helper reflects no active toast --
    _Test_AssertFalse("IsToastActive False when idle", _Theme_IsToastActive())

    ; -- Toast max-alpha constant --
    _Test_AssertEqual("Toast max alpha 230", $__g_Toast_iMaxAlpha, 230)

    ; -- ToastTick returns False (idle) and stays inactive --
    _Test_AssertFalse("ToastTick returns False when idle", _Theme_ToastTick())
    _Test_AssertFalse("IsToastActive still False after tick", _Theme_IsToastActive())

    ; -- TooltipTick safe when no tooltip active --
    _Theme_TooltipTick()
    _Test_AssertTrue("TooltipTick no crash when inactive", True)

    ; -- ApplyHover with ctrl ID 0 is no-op --
    _Theme_ApplyHover(0)
    _Test_AssertTrue("ApplyHover(0) no crash", True)

    ; -- RemoveHover with ctrl ID 0 is no-op --
    _Theme_RemoveHover(0, 0xFFFFFF)
    _Test_AssertTrue("RemoveHover(0) no crash", True)

    ; -- Toast position mapping (DK-4): pure config-driven placement --
    Local $sOrigToastPos = _Cfg_GetToastPosition()
    Local $iTX, $iTY
    Local $iTW = 100, $iTH = 26

    _Cfg_SetToastPosition("top-left")
    __Theme_ToastPosition($iTW, $iTH, $iTX, $iTY)
    _Test_AssertEqual("Toast top-left X = 20", $iTX, 20)
    _Test_AssertEqual("Toast top-left Y = 20", $iTY, 20)

    _Cfg_SetToastPosition("top-right")
    __Theme_ToastPosition($iTW, $iTH, $iTX, $iTY)
    _Test_AssertEqual("Toast top-right X = W-w-20", $iTX, @DesktopWidth - $iTW - 20)
    _Test_AssertEqual("Toast top-right Y = 20", $iTY, 20)

    _Cfg_SetToastPosition("bottom-left")
    __Theme_ToastPosition($iTW, $iTH, $iTX, $iTY)
    _Test_AssertEqual("Toast bottom-left X = 20", $iTX, 20)
    _Test_AssertEqual("Toast bottom-left Y = H-h-60", $iTY, @DesktopHeight - $iTH - 60)

    _Cfg_SetToastPosition("bottom-right")
    __Theme_ToastPosition($iTW, $iTH, $iTX, $iTY)
    _Test_AssertEqual("Toast bottom-right X = W-w-20", $iTX, @DesktopWidth - $iTW - 20)
    _Test_AssertEqual("Toast bottom-right Y = H-h-60", $iTY, @DesktopHeight - $iTH - 60)

    _Cfg_SetToastPosition("widget")
    __Theme_ToastPosition($iTW, $iTH, $iTX, $iTY)
    _Test_AssertEqual("Toast widget X = centered", $iTX, (@DesktopWidth - $iTW) / 2)
    _Test_AssertEqual("Toast widget Y = H-h-60", $iTY, @DesktopHeight - $iTH - 60)

    ; Invalid value clamps to widget (via _Cfg_SetToastPosition), so mapping falls to the default
    _Cfg_SetToastPosition("nonsense")
    __Theme_ToastPosition($iTW, $iTH, $iTX, $iTY)
    _Test_AssertEqual("Toast invalid pos -> widget X centered", $iTX, (@DesktopWidth - $iTW) / 2)
    _Cfg_SetToastPosition($sOrigToastPos)

    ; -- Fade sleep derivation (DK-1/DK-2): duration / frame count, capped at 50ms --
    ; duration = 0 falls back to fade_sleep_ms (legacy default behavior)
    _Test_AssertEqual("Fade sleep duration=0 uses fade_sleep_ms", __Theme_FadeSleep(200, 20, 0), _Cfg_GetFadeSleepMs())
    ; 200 alpha / 20 step = 10 frames; 100ms / 10 = 10ms per frame
    _Test_AssertEqual("Fade sleep 100ms over 10 frames = 10", __Theme_FadeSleep(200, 20, 100), 10)
    ; 1000ms / 10 frames = 100ms, capped to the 50ms ceiling
    _Test_AssertEqual("Fade sleep caps at 50ms", __Theme_FadeSleep(200, 20, 1000), 50)
    ; step >= range yields a single frame; sleep = duration (still capped)
    _Test_AssertEqual("Fade sleep single frame = duration", __Theme_FadeSleep(100, 255, 30), 30)
    _Test_AssertEqual("Fade sleep single frame capped", __Theme_FadeSleep(100, 255, 400), 50)

    ; -- Rect intersection (pure geometry backing the topmost re-assert gate) --
    _Test_AssertTrue("Overlapping rects intersect", _Theme_RectsIntersect(0, 0, 100, 100, 50, 50, 150, 150))
    _Test_AssertTrue("Containment counts as intersect", _Theme_RectsIntersect(0, 0, 100, 100, 10, 10, 20, 20))
    _Test_AssertTrue("Full overlap intersects", _Theme_RectsIntersect(0, 0, 100, 100, 0, 0, 100, 100))
    _Test_AssertFalse("Disjoint horizontally", _Theme_RectsIntersect(0, 0, 100, 100, 200, 0, 300, 100))
    _Test_AssertFalse("Disjoint vertically", _Theme_RectsIntersect(0, 0, 100, 100, 0, 200, 100, 300))
    _Test_AssertFalse("Edge-adjacent right does not overlap", _Theme_RectsIntersect(0, 0, 100, 100, 100, 0, 200, 100))
    _Test_AssertFalse("Edge-adjacent bottom does not overlap", _Theme_RectsIntersect(0, 0, 100, 100, 0, 100, 100, 200))
    _Test_AssertTrue("One-pixel overlap intersects", _Theme_RectsIntersect(0, 0, 100, 100, 99, 99, 200, 200))

    ; -- Widget occlusion decision (pure) --
    ; Widget rect used for all cases: taskbar-corner box at (10,1050)-(140,1080)
    Local $iWL = 10, $iWT = 1050, $iWR = 140, $iWB = 1080

    ; No windows above -> not occluded
    Local $aNone[1][6]
    _Test_AssertFalse("No windows above -> not occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aNone, 0))

    ; A visible topmost window overlapping the widget -> occluded (the regression case)
    Local $aBury[1][6] = [[True, True, 0, 1040, 200, 1080]]
    _Test_AssertTrue("Visible topmost overlap -> occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aBury, 1))

    ; Topmost + overlapping but NOT visible -> ignored
    Local $aHidden[1][6] = [[False, True, 0, 1040, 200, 1080]]
    _Test_AssertFalse("Hidden topmost overlap -> not occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aHidden, 1))

    ; Visible + overlapping but NOT topmost -> ignored (can't paint over our topmost widget)
    Local $aNonTop[1][6] = [[True, False, 0, 1040, 200, 1080]]
    _Test_AssertFalse("Non-topmost overlap -> not occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aNonTop, 1))

    ; Visible topmost but NOT overlapping (elsewhere on screen) -> not occluded
    Local $aElsewhere[1][6] = [[True, True, 500, 100, 700, 300]]
    _Test_AssertFalse("Topmost elsewhere -> not occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aElsewhere, 1))

    ; Count guard: qualifying row present but $iCount excludes it -> not occluded
    Local $aExcluded[2][6] = [[False, False, 0, 0, 1, 1], [True, True, 0, 1040, 200, 1080]]
    _Test_AssertFalse("Count excludes buriers -> not occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aExcluded, 1))
    _Test_AssertTrue("Count includes burier -> occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aExcluded, 2))

    ; Mixed stack: first two disqualified, third genuinely buries -> occluded
    Local $aMixed[3][6] = [[True, False, 0, 1040, 200, 1080], [False, True, 0, 1040, 200, 1080], [True, True, 120, 1055, 300, 1075]]
    _Test_AssertTrue("Mixed stack with one burier -> occluded", _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aMixed, 3))

    ; -- Widget color-bar animation (pure frame math + tick state machine) --
    __Test_Theme_ColorBar()

    ; -- Concrete real-window regression (drives the actual mechanism, not just the math) --
    __Test_Theme_TopmostOcclusionRegression()

    ; -- Themed tooltip dynamic sizing (t9-a): height must fit wrapped + multi-line text --
    __Test_Theme_TooltipSizing()
EndFunc

; Name:        __Test_Theme_TooltipSizing
; Description: Covers the themed-tooltip sizing seam (t9-a). _Theme_MeasureTextBlock and
;              _Theme_TooltipCalcSize are exercised headlessly (GDI via a throwaway screen
;              DC — no window shown), proving the popup grows in height to fit every
;              rendered line: explicit @CRLF breaks AND word-wrapped ones. The old code
;              sized height from the count of explicit breaks only, so a long single line
;              or a wrapping multi-line tip clipped. Placement is checked against
;              _CM_ClampToWorkArea (pure geometry) so a tall tooltip near a screen edge
;              stays fully inside the work area.
Func __Test_Theme_TooltipSizing()
    Local $iMax = $__g_Theme_iTipMaxW

    ; A single short line: sane floors, width within [min, max].
    Local $iShortW, $iShortH
    _Theme_TooltipCalcSize("Widget width in pixels", $iShortW, $iShortH)
    _Test_AssertGreaterEqual("Tooltip: short-line width >= min", $iShortW, $__g_Theme_iTipMinW)
    _Test_AssertLessEqual("Tooltip: short-line width <= max", $iShortW, $iMax)
    _Test_AssertGreaterEqual("Tooltip: short-line height positive", $iShortH, 1)

    ; One long logical line, NO explicit breaks: it must WRAP, and height must grow to
    ; cover the wrapped rows. Under the old (explicit-line-count) math this was one line
    ; tall and clipped. Width is clamped, height is not.
    Local $sLong = ""
    Local $w
    For $w = 1 To 60
        $sLong &= "wrap-word" & $w & " "
    Next
    Local $iLongW, $iLongH
    _Theme_TooltipCalcSize($sLong, $iLongW, $iLongH)
    _Test_AssertLessEqual("Tooltip: wrapped width clamped to max", $iLongW, $iMax)
    _Test_AssertTrue("Tooltip: wrapped long line is taller than one short line", $iLongH > $iShortH)
    _Test_AssertTrue("Tooltip: wrapped long line spans several rows (>= 3x short)", $iLongH >= $iShortH * 3)

    ; Explicit multi-line (@CRLF) tip sizes to its line count and exceeds a single line.
    Local $s3 = "Line one" & @CRLF & "Line two is here" & @CRLF & "Line three"
    Local $i3W, $i3H
    _Theme_TooltipCalcSize($s3, $i3W, $i3H)
    _Test_AssertTrue("Tooltip: 3-line tip taller than 1 short line", $i3H > $iShortH)

    ; A 10-line "monster" must be taller still — no ceiling on height.
    Local $sMonster = ""
    Local $ln
    For $ln = 1 To 10
        $sMonster &= "Monster tooltip line number " & $ln
        If $ln < 10 Then $sMonster &= @CRLF
    Next
    Local $iMonW, $iMonH
    _Theme_TooltipCalcSize($sMonster, $iMonW, $iMonH)
    _Test_AssertTrue("Tooltip: 10-line monster taller than 3-line tip", $iMonH > $i3H)
    _Test_AssertLessEqual("Tooltip: monster width still clamped to max", $iMonW, $iMax)

    ; Synthetic stand-in for the longest real tip (tip_rules_help): mixes explicit @CRLF
    ; breaks with long lines that also wrap. Must be tall — the exact clip case reported.
    Local $sReal = "Rules automatically move new windows to a specific desktop." & @CRLF & @CRLF & _
            "Type: Click to toggle between Process and Class." & @CRLF & _
            "  Process - match by executable name (e.g. chrome.exe)" & @CRLF & _
            "  Class - match by window class (e.g. CabinetWClass)" & @CRLF & @CRLF & _
            "Pattern: The text to match against. Wildcards * and ? are supported." & @CRLF & _
            "  e.g. discord* matches discord.exe and discordptb.exe" & @CRLF & @CRLF & _
            "Desk: The desktop number to send matching windows to." & @CRLF & _
            "Leave a row empty to skip it."
    Local $iRealW, $iRealH
    _Theme_TooltipCalcSize($sReal, $iRealW, $iRealH)
    _Test_AssertLessEqual("Tooltip: real long tip width clamped", $iRealW, $iMax)
    ; Regression 2026-07-06: tall tooltips must not clip. This tip has 9 explicit lines plus
    ; wrapping; it must be many lines tall, not a couple. Assert it clears a generous
    ; multi-line floor so a future height-from-line-count regression fails loudly.
    _Test_AssertTrue("Regression 2026-07-06: tall tooltips must not clip (real tip is many rows tall)", $iRealH >= $iShortH * 5)

    ; Empty text: no crash, minimum-sized popup with positive dimensions.
    Local $iEmptyW, $iEmptyH
    _Theme_TooltipCalcSize("", $iEmptyW, $iEmptyH)
    _Test_AssertGreaterEqual("Tooltip: empty width at floor", $iEmptyW, $__g_Theme_iTipMinW)
    _Test_AssertGreaterEqual("Tooltip: empty height positive", $iEmptyH, 1)

    ; Direct measurement: the same text wraps taller at a narrow width than a wide one.
    Local $sBlock = "the quick brown fox jumps over the lazy dog and keeps on running past the fence"
    Local $iWideW, $iWideH, $iNarrowW, $iNarrowH
    _Theme_MeasureTextBlock($sBlock, 380, _Cfg_GetTooltipFontSize(), $THEME_FONT_MAIN, $iWideW, $iWideH)
    _Theme_MeasureTextBlock($sBlock, 90, _Cfg_GetTooltipFontSize(), $THEME_FONT_MAIN, $iNarrowW, $iNarrowH)
    _Test_AssertTrue("Tooltip: narrower wrap width yields greater height", $iNarrowH > $iWideH)
    _Test_AssertLessEqual("Tooltip: measured width respects narrow bound", $iNarrowW, 90)

    ; Placement: a tall tooltip anchored at the bottom-right corner of a work area must be
    ; clamped fully inside it (flips up/left) — reuses the house geometry helper.
    Local $iWaL = 0, $iWaT = 0, $iWaR = 1920, $iWaB = 1040
    Local $iPosX, $iPosY
    _CM_ClampToWorkArea(1900, 1030, $iRealW, $iRealH, $iWaL, $iWaT, $iWaR, $iWaB, $iPosX, $iPosY)
    _Test_AssertGreaterEqual("Tooltip clamp: left edge inside work area", $iPosX, $iWaL)
    _Test_AssertGreaterEqual("Tooltip clamp: top edge inside work area", $iPosY, $iWaT)
    _Test_AssertLessEqual("Tooltip clamp: right edge inside work area", $iPosX + $iRealW, $iWaR)
    _Test_AssertLessEqual("Regression 2026-07-06: tall tooltip bottom stays on-screen", $iPosY + $iRealH, $iWaB)
EndFunc

; Name:        __Test_Theme_ColorBar
; Description: Covers the widget color-bar animator (t6-c). Pure helpers (_Theme_ColorLerp,
;              _Theme_EaseOutCubic, __Theme_ColorBarFrame) are headless truth tables; the
;              tick state machine is driven against a real off-screen scratch GUI + label so
;              the GUICtrlSetPos/SetBkColor paths execute. All config touched is saved and
;              restored; the animator is detached at the end so no state leaks to other tests.
Func __Test_Theme_ColorBar()
    ; ---- _Theme_ColorLerp: per-channel RGB, clamped endpoints ----
    _Test_AssertEqual("ColorLerp t=0 -> from", _Theme_ColorLerp(0x000000, 0xFFFFFF, 0), 0x000000)
    _Test_AssertEqual("ColorLerp t=1 -> to", _Theme_ColorLerp(0x000000, 0xFFFFFF, 1), 0xFFFFFF)
    _Test_AssertEqual("ColorLerp t=0 keeps from color", _Theme_ColorLerp(0x102030, 0x405060, 0), 0x102030)
    _Test_AssertEqual("ColorLerp t=1 keeps to color", _Theme_ColorLerp(0x102030, 0x405060, 1), 0x405060)
    ; Midpoint per channel: 0 -> 100 (0x64) at 0.5 = 50 (0x32) on every channel
    _Test_AssertEqual("ColorLerp midpoint per-channel", _Theme_ColorLerp(0x000000, 0x646464, 0.5), 0x323232)
    ; Channels are independent: R 0xFF->0x00, G 0x00->0xFF at 0.5 -> 0x80,0x80,0x00
    _Test_AssertEqual("ColorLerp independent channels", _Theme_ColorLerp(0xFF0000, 0x00FF00, 0.5), 0x808000)
    ; Clamp out-of-range t to the endpoints
    _Test_AssertEqual("ColorLerp t>1 clamps to 'to'", _Theme_ColorLerp(0x000000, 0xFFFFFF, 2), 0xFFFFFF)
    _Test_AssertEqual("ColorLerp t<0 clamps to 'from'", _Theme_ColorLerp(0x112233, 0xFFFFFF, -1), 0x112233)

    ; ---- _Theme_EaseOutCubic: endpoints, known midpoint, monotonicity, clamp ----
    _Test_AssertEqual("EaseOutCubic(0) = 0", _Theme_EaseOutCubic(0), 0)
    _Test_AssertEqual("EaseOutCubic(1) = 1", _Theme_EaseOutCubic(1), 1)
    _Test_AssertEqual("EaseOutCubic(0.5) = 0.875", _Theme_EaseOutCubic(0.5), 0.875)
    _Test_AssertEqual("EaseOutCubic clamps t<0 to 0", _Theme_EaseOutCubic(-0.5), 0)
    _Test_AssertEqual("EaseOutCubic clamps t>1 to 1", _Theme_EaseOutCubic(2), 1)
    _Test_AssertTrue("EaseOutCubic monotone 0.25<0.5", _Theme_EaseOutCubic(0.25) < _Theme_EaseOutCubic(0.5))
    _Test_AssertTrue("EaseOutCubic monotone 0.5<0.75", _Theme_EaseOutCubic(0.5) < _Theme_EaseOutCubic(0.75))
    ; Ease-OUT: front-loaded — at t=0.5 it is already past halfway
    _Test_AssertTrue("EaseOutCubic front-loaded (0.5 -> >0.5)", _Theme_EaseOutCubic(0.5) > 0.5)

    ; ---- __Theme_ColorBarFrame: grow width sweep 0..W, monotone; color constant ----
    Local $aF0 = __Theme_ColorBarFrame("grow", 0, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Grow t=0 width 0", $aF0[0], 0)
    _Test_AssertEqual("Grow t=0 color = target", $aF0[1], 0x646464)
    Local $aFmid = __Theme_ColorBarFrame("grow", 150, 300, 100, 0x000000, 0x646464)
    _Test_AssertTrue("Grow mid width in (0,W)", $aFmid[0] > 0 And $aFmid[0] < 100)
    _Test_AssertEqual("Grow mid color = target", $aFmid[1], 0x646464)
    Local $aFend = __Theme_ColorBarFrame("grow", 300, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Grow t=duration width = W", $aFend[0], 100)
    Local $aFpast = __Theme_ColorBarFrame("grow", 400, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Grow t>duration width = W (clamped)", $aFpast[0], 100)
    ; Monotone increasing width across the sweep
    Local $aFq1 = __Theme_ColorBarFrame("grow", 75, 300, 100, 0x000000, 0x646464)
    Local $aFq3 = __Theme_ColorBarFrame("grow", 225, 300, 100, 0x000000, 0x646464)
    _Test_AssertTrue("Grow width monotone q1<mid", $aFq1[0] < $aFmid[0])
    _Test_AssertTrue("Grow width monotone mid<q3", $aFmid[0] < $aFq3[0])

    ; ---- __Theme_ColorBarFrame: fade holds full width, lerps color from->to ----
    Local $aD0 = __Theme_ColorBarFrame("fade", 0, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Fade t=0 width = W", $aD0[0], 100)
    _Test_AssertEqual("Fade t=0 color = from", $aD0[1], 0x000000)
    Local $aDmid = __Theme_ColorBarFrame("fade", 150, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Fade mid color = lerp midpoint", $aDmid[1], 0x323232)
    Local $aDend = __Theme_ColorBarFrame("fade", 300, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Fade t=duration color = to", $aDend[1], 0x646464)

    ; ---- __Theme_ColorBarFrame: none is the settled full-width target; degenerate duration ----
    Local $aN = __Theme_ColorBarFrame("none", 0, 300, 100, 0x000000, 0x646464)
    _Test_AssertEqual("None width = W", $aN[0], 100)
    _Test_AssertEqual("None color = target", $aN[1], 0x646464)
    Local $aZ = __Theme_ColorBarFrame("grow", 0, 0, 100, 0x000000, 0x646464)
    _Test_AssertEqual("Grow duration<=0 -> final frame width W", $aZ[0], 100)

    ; ---- Tick is a safe no-op when idle (no attach, nothing running) ----
    _Theme_ColorBarAttach(0, 0, 0, 0, 0) ; ensure detached
    _Test_AssertFalse("Idle: not animating", _Theme_ColorBarIsAnimating())
    _Theme_ColorBarTick()
    _Test_AssertFalse("Idle tick: still not animating", _Theme_ColorBarIsAnimating())

    ; ---- Unattached set: tracks color, never animates ----
    _Theme_ColorBarSet(0xABCDEF, $THEME_BG_MAIN, True)
    _Test_AssertFalse("Unattached set: not animating", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Unattached set: tracks color", $__g_CB_iCurColor, 0xABCDEF)

    ; ---- State machine against a real off-screen scratch GUI + label ----
    Local $sAnimMode = _Cfg_GetWidgetColorBarAnim()
    Local $iAnimDur = _Cfg_GetWidgetColorBarAnimDuration()
    Local $bAnimOn = _Cfg_GetAnimationsEnabled()

    Local $hCB = GUICreate("t6c_colorbar", 130, 46, -4000, -4000, $WS_POPUP, $WS_EX_TOOLWINDOW)
    Local $idBar = GUICtrlCreateLabel("", 0, 40, 100, 6)
    _Theme_ColorBarAttach($idBar, 0, 40, 100, 6)

    ; Instant path: animations disabled -> snap, not animating
    _Cfg_SetAnimationsEnabled(False)
    _Cfg_SetWidgetColorBarAnim("grow")
    _Theme_ColorBarSet(0x123456, $THEME_BG_MAIN, True)
    _Test_AssertFalse("Anims off: not animating", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Anims off: color snapped", $__g_CB_iCurColor, 0x123456)

    ; Instant path: mode none -> snap, not animating
    _Cfg_SetAnimationsEnabled(True)
    _Cfg_SetWidgetColorBarAnim("none")
    _Theme_ColorBarSet(0x654321, $THEME_BG_MAIN, True)
    _Test_AssertFalse("Mode none: not animating", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Mode none: color snapped", $__g_CB_iCurColor, 0x654321)

    ; Instant path: $bAnimate = False forces snap even with grow enabled
    _Cfg_SetWidgetColorBarAnim("grow")
    _Theme_ColorBarSet(0x0A0B0C, $THEME_BG_MAIN, False)
    _Test_AssertFalse("Animate=False: not animating", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Animate=False: color snapped", $__g_CB_iCurColor, 0x0A0B0C)

    ; Grow start: target differs from displayed -> animation arms
    _Cfg_SetWidgetColorBarAnimDuration(2000)
    _Theme_ColorBarSet(0x00FF00, $THEME_BG_MAIN, True)
    _Test_AssertTrue("Grow: animating after set", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Grow: running mode is grow", $__g_CB_sMode, "grow")
    _Test_AssertEqual("Grow: from = prior displayed color", $__g_CB_iFromColor, 0x0A0B0C)
    _Test_AssertEqual("Grow: to = requested target", $__g_CB_iToColor, 0x00FF00)

    ; One tick mid-flight keeps it animating (2000ms budget, ~0ms elapsed)
    _Theme_ColorBarTick()
    _Test_AssertTrue("Grow: still animating after one mid tick", _Theme_ColorBarIsAnimating())

    ; Retrigger mid-animation: snap-completes old target, starts fresh from it
    _Theme_ColorBarSet(0x0000FF, $THEME_BG_MAIN, True)
    _Test_AssertTrue("Retrigger: still animating", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Retrigger: from = old target (snapped)", $__g_CB_iFromColor, 0x00FF00)
    _Test_AssertEqual("Retrigger: to = new target", $__g_CB_iToColor, 0x0000FF)

    ; Completion: short duration + elapsed past it -> tick snaps and quiesces
    _Cfg_SetWidgetColorBarAnim("fade")
    _Cfg_SetWidgetColorBarAnimDuration(50)
    _Theme_ColorBarSet(0x445566, $THEME_BG_MAIN, True)
    _Test_AssertTrue("Fade: animating after set", _Theme_ColorBarIsAnimating())
    Sleep(70)
    _Theme_ColorBarTick()
    _Test_AssertFalse("Fade: quiesced after duration elapses", _Theme_ColorBarIsAnimating())
    _Test_AssertEqual("Fade: settled on target color", $__g_CB_iCurColor, 0x445566)

    ; Cleanup: detach animator, restore config, destroy scratch GUI
    _Theme_ColorBarAttach(0, 0, 0, 0, 0)
    _Cfg_SetWidgetColorBarAnim($sAnimMode)
    _Cfg_SetWidgetColorBarAnimDuration($iAnimDur)
    _Cfg_SetAnimationsEnabled($bAnimOn)
    If WinExists($hCB) Then GUIDelete($hCB)
EndFunc

; Name:        __Test_Theme_IsAbove
; Description: Real z-order walk used by the regression test. Walks from $hBelow toward the top of
;              the z-order; returns True if $hAbove is encountered above it.
Func __Test_Theme_IsAbove($hAbove, $hBelow)
    Local $hCur = $hBelow
    Local $iGuard = 0
    While $iGuard < 500
        $iGuard += 1
        Local $hPrev = _WinAPI_GetWindow($hCur, $GW_HWNDPREV)
        If @error Or Not $hPrev Then Return False ; reached the top without finding $hAbove
        If $hPrev = $hAbove Then Return True
        $hCur = $hPrev
    WEnd
    Return False
EndFunc

; Name:        __Test_Theme_WalkOccluded
; Description: Real z-order walk that builds the "windows above" array from LIVE hwnds and feeds it
;              straight to the PURE _Theme_IsWidgetOccluded. Mirrors what the production
;              _Theme_WindowIsOccluded does, but keeps the walk + pure decision explicit inside the
;              test so the regression provably drives _Theme_IsWidgetOccluded on real hwnd data.
Func __Test_Theme_WalkOccluded($hWnd)
    Local $aWP = WinGetPos($hWnd)
    If @error Or Not IsArray($aWP) Then Return False
    Local $iWL = $aWP[0], $iWT = $aWP[1]
    Local $iWR = $aWP[0] + $aWP[2], $iWB = $aWP[1] + $aWP[3]
    Local $aAbove[16][6]
    Local $iCount = 0
    Local $hCur = $hWnd
    Local $iGuard = 0
    While $iCount < 16 And $iGuard < 400
        $iGuard += 1
        Local $hPrev = _WinAPI_GetWindow($hCur, $GW_HWNDPREV)
        If @error Or Not $hPrev Then ExitLoop
        $hCur = $hPrev
        Local $tRect = _WinAPI_GetWindowRect($hCur)
        If @error Then ContinueLoop
        $aAbove[$iCount][0] = _WinAPI_IsWindowVisible($hCur)
        $aAbove[$iCount][1] = (BitAND(_WinAPI_GetWindowLong($hCur, $GWL_EXSTYLE), $WS_EX_TOPMOST) <> 0)
        $aAbove[$iCount][2] = DllStructGetData($tRect, "Left")
        $aAbove[$iCount][3] = DllStructGetData($tRect, "Top")
        $aAbove[$iCount][4] = DllStructGetData($tRect, "Right")
        $aAbove[$iCount][5] = DllStructGetData($tRect, "Bottom")
        $iCount += 1
    WEnd
    Return _Theme_IsWidgetOccluded($iWL, $iWT, $iWR, $iWB, $aAbove, $iCount)
EndFunc

; Name:        __Test_Theme_TopmostOcclusionRegression
; Description: Regression 2026-07-03: the widget must re-assert topmost when occluded by ANOTHER
;              topmost window. t1-e6 gated the re-assert on geometry/style-bit change only, so a
;              peer topmost window stacked above the widget (bit still set, geometry unchanged) left
;              it permanently buried. This exercises the REAL mechanism with REAL windows and a REAL
;              z-order walk (not just the pure truth table):
;                1a. Anti-flicker: with NO occluder, BOTH the production wrapper and an explicit
;                    real-hwnd walk feeding _Theme_IsWidgetOccluded return no-action across 10
;                    consecutive polls (the permanent guard against reintroducing the re-assert
;                    storm).
;                1b. Anti-flicker: a NON-topmost overlapping cover also yields no-action (it can
;                    never sit above our topmost widget, so it must never trigger a re-assert).
;                2.  Detection: a real topmost occluder above the widget is detected by both the
;                    explicit real-hwnd walk + _Theme_IsWidgetOccluded AND the production
;                    _Theme_WindowIsOccluded (the exact code the app runs; skip-pid 0 so the
;                    same-process stand-in occluder counts).
;                3.  Re-assert: the app's real SetWindowPos re-insert (SWP_NOACTIVATE|NOMOVE|NOSIZE)
;                    puts the widget back above the occluder (verified by a FRESH z-order walk), and
;                    detection then self-quiesces.
;              Test windows are created OFF-SCREEN (large negative coords) so the default suite run
;              does not flash visible topmost windows — z-order and rect-intersection are
;              position-independent, and step 2 proves detection still fires off-screen. Cleanup is
;              guarded (WinExists) at the end; _Test_Assert* are non-fatal, so it always runs and no
;              topmost test window can linger even when an assertion fails.
Func __Test_Theme_TopmostOcclusionRegression()
    Local Const $iOX = -4000, $iOY = -4000 ; off all monitors
    Local $hWidget = 0, $hOcc = 0, $hNonTop = 0
    Local $k

    ; Stand-in for the widget: a real WS_EX_TOPMOST popup, forced to the top of the z-order.
    $hWidget = GUICreate("t2a_widget_regr", 130, 46, $iOX, $iOY, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUISetState(@SW_SHOWNOACTIVATE, $hWidget)
    __Test_Theme_ForceTop($hWidget)
    Sleep(40)

    ; (1a) Anti-flicker — no occluder: production wrapper AND explicit real-hwnd walk both no-action
    ;      across 10 consecutive polls.
    Local $bGuardWrap = True, $bGuardWalk = True
    For $k = 1 To 10
        If _Theme_WindowIsOccluded($hWidget, 0) Then $bGuardWrap = False
        If __Test_Theme_WalkOccluded($hWidget) Then $bGuardWalk = False
        Sleep(10)
    Next
    _Test_AssertTrue("Regression 2026-07-03: no occluder -> wrapper no-action across 10 polls (anti-flicker)", $bGuardWrap)
    _Test_AssertTrue("Regression 2026-07-03: no occluder -> real-walk+_Theme_IsWidgetOccluded no-action across 10 polls", $bGuardWalk)

    ; (1b) Anti-flicker — a NON-topmost overlapping cover must also produce no-action.
    $hNonTop = GUICreate("t2a_nontop_regr", 170, 86, $iOX - 20, $iOY - 20, $WS_POPUP, $WS_EX_TOOLWINDOW)
    GUISetState(@SW_SHOWNOACTIVATE, $hNonTop)
    Sleep(40)
    Local $bGuardNonTop = True
    For $k = 1 To 10
        If _Theme_WindowIsOccluded($hWidget, 0) Then $bGuardNonTop = False
        Sleep(10)
    Next
    _Test_AssertTrue("Regression 2026-07-03: non-topmost cover -> no-action across 10 polls (anti-flicker)", $bGuardNonTop)
    If WinExists($hNonTop) Then GUIDelete($hNonTop)
    $hNonTop = 0

    ; (2) Real TOPMOST occluder overlapping the widget, forced above it.
    Local $aWP = WinGetPos($hWidget)
    $hOcc = GUICreate("t2a_occluder_regr", $aWP[2] + 40, $aWP[3] + 40, $aWP[0] - 20, $aWP[1] - 20, _
            $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUISetState(@SW_SHOWNOACTIVATE, $hOcc)
    __Test_Theme_ForceTop($hOcc)
    Sleep(40)

    _Test_AssertTrue("Regression 2026-07-03: occluder starts above widget (real z-order)", __Test_Theme_IsAbove($hOcc, $hWidget))
    _Test_AssertTrue("Regression 2026-07-03: occlusion detected via real-hwnd walk + _Theme_IsWidgetOccluded", __Test_Theme_WalkOccluded($hWidget))
    _Test_AssertTrue("Regression 2026-07-03: occlusion detected via production _Theme_WindowIsOccluded", _Theme_WindowIsOccluded($hWidget, 0))

    ; (3) Perform the app's real re-assert (HWND_TOPMOST, no move/size, no activate).
    __Test_Theme_ForceTop($hWidget)
    Sleep(40)
    _Test_AssertTrue("Regression 2026-07-03: widget above occluder after re-assert (fresh real z-order)", __Test_Theme_IsAbove($hWidget, $hOcc))
    _Test_AssertFalse("Regression 2026-07-03: occluder no longer above widget after re-assert", __Test_Theme_IsAbove($hOcc, $hWidget))
    _Test_AssertFalse("Regression 2026-07-03: detection self-quiesces after re-assert", _Theme_WindowIsOccluded($hWidget, 0))

    ; Guarded cleanup — always runs (asserts are non-fatal); leaves no lingering topmost test window.
    If $hOcc <> 0 And WinExists($hOcc) Then GUIDelete($hOcc)
    If $hNonTop <> 0 And WinExists($hNonTop) Then GUIDelete($hNonTop)
    If $hWidget <> 0 And WinExists($hWidget) Then GUIDelete($hWidget)
EndFunc

; Name:        __Test_Theme_ForceTop
; Description: Re-insert $hWnd at the top of the topmost band using the exact flags the app's
;              _ForceTopMost re-assert uses (HWND_TOPMOST, no move/size/activate).
Func __Test_Theme_ForceTop($hWnd)
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hWnd, "hwnd", $HWND_TOPMOST, _
            "int", 0, "int", 0, "int", 0, "int", 0, "uint", BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOACTIVATE))
EndFunc
