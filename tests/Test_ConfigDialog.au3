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

    ; -- Sub-tab hover hit-test (pure) --
    Local $aSubBtns[4] = [101, 102, 103, 104]
    _Test_AssertEqual("SubHover: cursor over non-active returns that btn", __CD_SubTabHoverHit($aSubBtns, 4, 0, 103), 103)
    _Test_AssertEqual("SubHover: cursor over active is excluded", __CD_SubTabHoverHit($aSubBtns, 4, 2, 103), 0)
    _Test_AssertEqual("SubHover: cursor over first non-active", __CD_SubTabHoverHit($aSubBtns, 4, 3, 101), 101)
    _Test_AssertEqual("SubHover: cursor over nothing returns 0", __CD_SubTabHoverHit($aSubBtns, 4, 0, 999), 0)
    _Test_AssertEqual("SubHover: count limits scan", __CD_SubTabHoverHit($aSubBtns, 2, 0, 103), 0)

    ; -- Nesting-safe lock depth counter (hGUI=0 skips the real LockWindowUpdate) --
    $__g_CD_hGUI = 0
    $__g_CD_iLockDepth = 0
    __CD_LockBegin()
    _Test_AssertEqual("Lock: depth 1 after first begin", $__g_CD_iLockDepth, 1)
    __CD_LockBegin()
    _Test_AssertEqual("Lock: depth 2 after nested begin", $__g_CD_iLockDepth, 2)
    __CD_LockEnd()
    _Test_AssertEqual("Lock: depth 1 after inner end", $__g_CD_iLockDepth, 1)
    __CD_LockEnd()
    _Test_AssertEqual("Lock: depth 0 after outer end", $__g_CD_iLockDepth, 0)
    __CD_LockEnd()
    _Test_AssertEqual("Lock: depth clamps at 0 (no underflow)", $__g_CD_iLockDepth, 0)

    ; -- Settings search: registry, matcher, navigation mapping (t1-e11, pure) --
    __CD_SearchReset()
    _Test_AssertEqual("Search: empty registry count 0", $__g_CD_iSearchCount, 0)
    _Test_AssertEqual("Search: empty query yields 0 results", __CD_SearchMatch("widget"), 0)

    ; Synthetic registry spanning several tabs / sub-tabs (label + tooltip)
    __CD_SearchAdd(201, 1, 1, "General > Widget > Enable widget drag", "Enable widget drag", "Hold and drag the widget", $GUI_BKCOLOR_TRANSPARENT)
    __CD_SearchAdd(202, 1, 2, "General > Desktop > Wrap navigation", "Wrap navigation at ends", "Left arrow on first desktop goes to last", $GUI_BKCOLOR_TRANSPARENT)
    __CD_SearchAdd(203, 2, 1, "Display > Appearance > Opacity", "Widget opacity", "Widget transparency 50-255", $THEME_BG_INPUT)
    __CD_SearchAdd(204, 4, 1, "Behavior > Interaction > Disable native OSD", "Disable native OSD", "Suppress the Windows switch animation", $GUI_BKCOLOR_TRANSPARENT)
    __CD_SearchAdd(205, 10, 0, "Window List > Draggable window list", "Draggable window list", "Drag the window list to reposition", $GUI_BKCOLOR_TRANSPARENT)
    _Test_AssertEqual("Search: registry count after 5 adds", $__g_CD_iSearchCount, 5)

    ; Coverage helper: contributing vs non-contributing tabs
    _Test_AssertTrue("Search: tab 1 contributes", __CD_SearchTabContributes(1))
    _Test_AssertTrue("Search: tab 10 contributes", __CD_SearchTabContributes(10))
    _Test_AssertFalse("Search: tab 5 has no entries", __CD_SearchTabContributes(5))

    ; Matcher: case-insensitive substring over label AND tooltip
    _Test_AssertEqual("Search: 'widget' matches (label+tooltip)", __CD_SearchMatch("widget"), 2)
    _Test_AssertEqual("Search: 'WIDGET' is case-insensitive", __CD_SearchMatch("WIDGET"), 2)
    _Test_AssertEqual("Search: 'navigation' matches label", __CD_SearchMatch("navigation"), 1)
    _Test_AssertEqual("Search: 'animation' matches tooltip only", __CD_SearchMatch("animation"), 1)
    _Test_AssertEqual("Search: 'window list' multi-word substring", __CD_SearchMatch("window list"), 1)
    _Test_AssertEqual("Search: no-match query yields 0", __CD_SearchMatch("zzznomatch"), 0)
    _Test_AssertEqual("Search: empty query yields 0", __CD_SearchMatch(""), 0)
    _Test_AssertEqual("Search: whitespace query yields 0", __CD_SearchMatch("   "), 0)

    ; Result indices point at the matched registry entries
    __CD_SearchMatch("osd")
    _Test_AssertEqual("Search: 'osd' single match count", $__g_CD_iSearchResultCount, 1)
    _Test_AssertEqual("Search: 'osd' result index -> entry 3", $__g_CD_aSearchResultIdx[0], 3)

    ; Navigation mapping: sets the right sub-tab/page global for the entry's tab
    $__g_CD_iGenActiveSub = 99
    __CD_SetActiveSubForTab(1, 2)
    _Test_AssertEqual("Nav: tab1 sub2 -> GenActiveSub", $__g_CD_iGenActiveSub, 2)
    $__g_CD_iDispActiveSub = 99
    __CD_SetActiveSubForTab(2, 1)
    _Test_AssertEqual("Nav: tab2 sub1 -> DispActiveSub", $__g_CD_iDispActiveSub, 1)
    $__g_CD_iHkActiveSub = 99
    __CD_SetActiveSubForTab(3, 3)
    _Test_AssertEqual("Nav: tab3 sub3 -> HkActiveSub", $__g_CD_iHkActiveSub, 3)
    $__g_CD_iBhvActiveSub = 99
    __CD_SetActiveSubForTab(4, 4)
    _Test_AssertEqual("Nav: tab4 sub4 -> BhvActiveSub", $__g_CD_iBhvActiveSub, 4)
    $__g_CD_iDeskPage = 99
    __CD_SetActiveSubForTab(7, 3)
    _Test_AssertEqual("Nav: tab7 page3 -> DeskPage", $__g_CD_iDeskPage, 3)
    ; sub 0 (tab with no sub-tabs) is a no-op — no global clobbered
    $__g_CD_iGenActiveSub = 5
    __CD_SetActiveSubForTab(10, 0)
    _Test_AssertEqual("Nav: sub 0 is a no-op", $__g_CD_iGenActiveSub, 5)

    ; -- Results-panel close decision (t2-b): panel must survive mouse motion --
    ; __CD_SearchShouldCloseOnClick($id, $bRowClicked, $idSearchInput). Positive ids are
    ; control clicks; negative ids are GUIGetMsg events. Input id fixed at 300 here.
    Local $idInput = 300
    ; Keep open on mere motion / non-click events (the reported regression)
    _Test_AssertFalse("Close?: mouse-move keeps panel", __CD_SearchShouldCloseOnClick($GUI_EVENT_MOUSEMOVE, False, $idInput))
    _Test_AssertFalse("Close?: primary-up keeps panel", __CD_SearchShouldCloseOnClick($GUI_EVENT_PRIMARYUP, False, $idInput))
    _Test_AssertFalse("Close?: secondary-up keeps panel", __CD_SearchShouldCloseOnClick($GUI_EVENT_SECONDARYUP, False, $idInput))
    _Test_AssertFalse("Close?: idle (no event) keeps panel", __CD_SearchShouldCloseOnClick(0, False, $idInput))
    ; Keep open when interacting with the search input or a result row
    _Test_AssertFalse("Close?: click search input keeps panel", __CD_SearchShouldCloseOnClick($idInput, False, $idInput))
    _Test_AssertFalse("Close?: click result row keeps panel (navigate)", __CD_SearchShouldCloseOnClick(250, True, $idInput))
    ; Close only on a genuine click-away
    _Test_AssertTrue("Close?: click another control closes", __CD_SearchShouldCloseOnClick(250, False, $idInput))
    _Test_AssertTrue("Close?: primary-down on background closes", __CD_SearchShouldCloseOnClick($GUI_EVENT_PRIMARYDOWN, False, $idInput))
    _Test_AssertTrue("Close?: secondary-down on background closes", __CD_SearchShouldCloseOnClick($GUI_EVENT_SECONDARYDOWN, False, $idInput))
    ; A row click takes precedence even over a real click id (navigate, don't just close)
    _Test_AssertFalse("Close?: row click precedence over control id", __CD_SearchShouldCloseOnClick(250, True, $idInput))

    ; Regression 2026-07-03: search results must survive mouse movement.
    ; The original bug closed the panel on every GUIGetMsg mouse-move event. This replays
    ; the failure as an ORDERED event sequence (a transition, not isolated states): the
    ; panel is open, the mouse wanders across the dialog, and $bOpen -- mirroring the
    ; message loop, which flips visibility off only when the decision says "close" -- must
    ; stay True through all motion, then flip False on each genuine click-away.
    Local $bOpen = True
    Local $idRow = 250, $idOther = 260
    ; Mouse drifts over background, input, panel and rows; releases buttons; goes idle.
    Local $aWander[6] = [$GUI_EVENT_MOUSEMOVE, $GUI_EVENT_MOUSEMOVE, $GUI_EVENT_PRIMARYUP, _
            $GUI_EVENT_SECONDARYUP, $GUI_EVENT_MOUSEMOVE, 0]
    Local $wi
    For $wi = 0 To UBound($aWander) - 1
        If __CD_SearchShouldCloseOnClick($aWander[$wi], False, $idInput) Then $bOpen = False
        _Test_AssertTrue("Regression seq: panel open after motion event " & $aWander[$wi], $bOpen)
    Next
    ; A result-row click is classified as navigate (not click-away), so the decision keeps
    ; $bOpen True here; the actual close happens in __CD_SearchNavigate (see real-GUI test).
    If __CD_SearchShouldCloseOnClick($idRow, True, $idInput) Then $bOpen = False
    _Test_AssertTrue("Regression seq: row click routes to navigate, not click-away", $bOpen)
    ; Now each genuine click-away trigger flips the panel closed (fresh $bOpen each time).
    $bOpen = True
    If __CD_SearchShouldCloseOnClick($GUI_EVENT_PRIMARYDOWN, False, $idInput) Then $bOpen = False
    _Test_AssertFalse("Regression seq: click on background closes", $bOpen)
    $bOpen = True
    If __CD_SearchShouldCloseOnClick($GUI_EVENT_SECONDARYDOWN, False, $idInput) Then $bOpen = False
    _Test_AssertFalse("Regression seq: right-click on background closes", $bOpen)
    $bOpen = True
    If __CD_SearchShouldCloseOnClick($idOther, False, $idInput) Then $bOpen = False
    _Test_AssertFalse("Regression seq: click another control closes", $bOpen)

    ; -- Search result descriptions: registry stores the raw tooltip (t5-b2, pure) --
    ; The description line shown under each result is harvested from the setting's tooltip,
    ; so __CD_SearchAdd must retain the raw tip alongside the match blob. The 5 synthetic
    ; entries above supply the tips.
    _Test_AssertEqual("Desc: entry 0 keeps raw tooltip", $__g_CD_aSearchTip[0], "Hold and drag the widget")
    _Test_AssertEqual("Desc: entry 2 keeps raw tooltip", $__g_CD_aSearchTip[2], "Widget transparency 50-255")
    _Test_AssertEqual("Desc: entry 4 keeps raw tooltip", $__g_CD_aSearchTip[4], "Drag the window list to reposition")

    ; -- __CD_SearchFormatDesc: tooltip -> single dim description line (t5-b2, pure) --
    ; Empty tooltip yields "" so the row renders its tab path only (graceful fallback);
    ; newlines/tabs/space-runs collapse to single spaces; over-long text is ellipsised.
    _Test_AssertEqual("FormatDesc: empty tip -> '' (tab-path fallback)", __CD_SearchFormatDesc(""), "")
    _Test_AssertEqual("FormatDesc: whitespace-only tip -> ''", __CD_SearchFormatDesc("   " & @TAB & @CRLF), "")
    _Test_AssertEqual("FormatDesc: plain text passes through", __CD_SearchFormatDesc("Simple description"), "Simple description")
    _Test_AssertEqual("FormatDesc: newlines collapse to single spaces", __CD_SearchFormatDesc("line one" & @CRLF & "line two"), "line one line two")
    _Test_AssertEqual("FormatDesc: tabs collapse to spaces", __CD_SearchFormatDesc("a" & @TAB & "b"), "a b")
    _Test_AssertEqual("FormatDesc: space runs collapse to one", __CD_SearchFormatDesc("a     b   c"), "a b c")
    _Test_AssertEqual("FormatDesc: leading/trailing WS stripped", __CD_SearchFormatDesc("  padded  "), "padded")
    ; At/under the cap the text is untouched; over the cap it is cut to $iMaxChars with an
    ; ellipsis as the final glyph (so the label never spills its row).
    _Test_AssertEqual("FormatDesc: at cap is unchanged", __CD_SearchFormatDesc("abcdefghij", 10), "abcdefghij")
    Local $sCut = __CD_SearchFormatDesc("abcdefghijklmnop", 10)
    _Test_AssertEqual("FormatDesc: over cap truncated to maxChars", StringLen($sCut), 10)
    _Test_AssertEqual("FormatDesc: truncation ends with ellipsis", StringRight($sCut, 1), ChrW(0x2026))
    _Test_AssertEqual("FormatDesc: truncation keeps the head", StringLeft($sCut, 9), "abcdefghi")

    ; -- Highlight flash phase logic (t5-b2, pure) --
    ; __CD_PulsePhaseAt = floor(elapsed / step); even phases show the highlight, odd
    ; phases restore, and phase >= $__g_CD_PULSE_PHASES ends the flash. With the shipped
    ; 150ms step / 6 phases this yields 3 visible on-cycles.
    _Test_AssertEqual("Pulse: t=0 -> phase 0", __CD_PulsePhaseAt(0, 150), 0)
    _Test_AssertEqual("Pulse: t=149 -> still phase 0", __CD_PulsePhaseAt(149, 150), 0)
    _Test_AssertEqual("Pulse: t=150 -> phase 1", __CD_PulsePhaseAt(150, 150), 1)
    _Test_AssertEqual("Pulse: t=300 -> phase 2", __CD_PulsePhaseAt(300, 150), 2)
    _Test_AssertEqual("Pulse: t=900 -> phase 6 (finished)", __CD_PulsePhaseAt(900, 150), 6)
    _Test_AssertTrue("Pulse: end phase reaches PULSE_PHASES", __CD_PulsePhaseAt(900, 150) >= $__g_CD_PULSE_PHASES)
    _Test_AssertEqual("Pulse: zero step clamps to 1 (no div-by-zero)", __CD_PulsePhaseAt(5, 0), 5)
    _Test_AssertTrue("Pulse: phase 0 is on", __CD_PulseIsOn(0))
    _Test_AssertFalse("Pulse: phase 1 is off", __CD_PulseIsOn(1))
    _Test_AssertTrue("Pulse: phase 2 is on", __CD_PulseIsOn(2))
    _Test_AssertFalse("Pulse: phase 5 is off", __CD_PulseIsOn(5))
    ; The shipped config produces an even phase count (starts and would-be-restored balance)
    ; and an odd number of visible on-cycles = PULSE_PHASES / 2 = 3.
    _Test_AssertEqual("Pulse: 6 phases => 3 visible flashes", Int($__g_CD_PULSE_PHASES / 2), 3)

    ; -- Two-line row decision: description present vs tab-path fallback (t5-b2, pure) --
    ; A tipped entry renders a non-empty description; an entry whose tip is blank renders
    ; only its tab path. Model the render decision the filter makes via __CD_SearchFormatDesc.
    __CD_SearchAdd(206, 1, 1, "General > Widget > No-tip control", "No-tip control", "", $THEME_BG_INPUT)
    _Test_AssertTrue("Row: tipped entry -> non-empty desc", __CD_SearchFormatDesc($__g_CD_aSearchTip[0]) <> "")
    _Test_AssertEqual("Row: blank-tip entry -> empty desc (fallback)", __CD_SearchFormatDesc($__g_CD_aSearchTip[5]), "")

    ; Restore registry so later assertions / suites start clean
    __CD_SearchReset()

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

    ; -- Regression 2026-07-03 (real GUI): search results must survive mouse movement --
    ; Builds the ACTUAL search UI, injects a query through the real filter path, then
    ; replays the message loop's real close conditional against a sequence of mouse
    ; events and every explicit close trigger, asserting the real panel-visible state
    ; ($__g_CD_bSearchResultsVisible, owned by the real show/hide functions) after each.
    Local $hGuiSearch = GUICreate("CD Search Regression Test", 540, 480)
    $__g_CD_hGUI = $hGuiSearch
    $__g_CD_iContentH = 360
    __CD_BuildSearchUI()

    ; Registry with rows that match "widget" (2 of 3), filtered through real code.
    __CD_SearchReset()
    __CD_SearchAdd(1001, 1, 1, "General > Widget > Enable widget drag", "Enable widget drag", "Hold and drag the widget", $GUI_BKCOLOR_TRANSPARENT)
    __CD_SearchAdd(1002, 2, 1, "Display > Appearance > Widget opacity", "Widget opacity", "Widget transparency", $THEME_BG_INPUT)
    __CD_SearchAdd(1003, 10, 0, "Window List > Draggable window list", "Draggable window list", "Drag to reposition", $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlSetData($__g_CD_idSearchInput, "widget")
    __CD_SearchApplyFilter()
    _Test_AssertTrue("Regression GUI: panel visible after typing 'widget'", $__g_CD_bSearchResultsVisible)
    _Test_AssertEqual("Regression GUI: 2 rows matched 'widget'", $__g_CD_iSearchResultCount, 2)
    _Test_AssertTrue("Regression GUI: row 0 populated via real path", StringLen(GUICtrlRead($__g_CD_aidSearchRowLbl[0])) > 0)

    Local $idRealRow = $__g_CD_aidSearchRowLbl[0]
    Local $idOtherCtrl = GUICtrlCreateButton("x", 0, 0, 10, 10) ; stands in for a tab / Apply button

    ; Replay the loop's search-close conditional across a SEQUENCE of mouse events. The
    ; panel must remain visible through all motion -- this is the exact regression.
    Local $aMotion[6] = [$GUI_EVENT_MOUSEMOVE, $GUI_EVENT_MOUSEMOVE, $GUI_EVENT_PRIMARYUP, _
            $GUI_EVENT_SECONDARYUP, $GUI_EVENT_MOUSEMOVE, 0]
    Local $mi
    For $mi = 0 To UBound($aMotion) - 1
        Local $ev = $aMotion[$mi]
        Local $bRow = ($ev = $idRealRow) ; negative motion events never equal a positive row id
        If $__g_CD_bSearchResultsVisible And __CD_SearchShouldCloseOnClick($ev, $bRow, $__g_CD_idSearchInput) Then __CD_SearchHideResults()
        _Test_AssertTrue("Regression GUI: panel still visible after event " & $ev, $__g_CD_bSearchResultsVisible)
    Next

    ; Close trigger 1: genuine click on the dialog background.
    If $__g_CD_bSearchResultsVisible And __CD_SearchShouldCloseOnClick($GUI_EVENT_PRIMARYDOWN, False, $__g_CD_idSearchInput) Then __CD_SearchHideResults()
    _Test_AssertFalse("Regression GUI: click-outside (background) closes panel", $__g_CD_bSearchResultsVisible)

    ; Close trigger 2: click another control (input still holds 'widget' -> re-show first).
    __CD_SearchApplyFilter()
    _Test_AssertTrue("Regression GUI: panel re-shown for control-click test", $__g_CD_bSearchResultsVisible)
    If $__g_CD_bSearchResultsVisible And __CD_SearchShouldCloseOnClick($idOtherCtrl, ($idOtherCtrl = $idRealRow), $__g_CD_idSearchInput) Then __CD_SearchHideResults()
    _Test_AssertFalse("Regression GUI: click another control closes panel", $__g_CD_bSearchResultsVisible)

    ; Close trigger 3: selecting a result row -> the loop routes it to navigate (decision
    ; is not click-away), whose panel-close half is __CD_SearchClear (real path).
    __CD_SearchApplyFilter()
    _Test_AssertFalse("Regression GUI: row click is not a click-away", __CD_SearchShouldCloseOnClick($idRealRow, True, $__g_CD_idSearchInput))
    __CD_SearchClear()
    _Test_AssertFalse("Regression GUI: result-row selection closes panel", $__g_CD_bSearchResultsVisible)
    _Test_AssertEqual("Regression GUI: selection cleared the query", GUICtrlRead($__g_CD_idSearchInput), "")

    ; Close trigger 4: the query is cleared -> the real filter hides the panel.
    GUICtrlSetData($__g_CD_idSearchInput, "widget")
    __CD_SearchApplyFilter()
    _Test_AssertTrue("Regression GUI: panel re-shown before query-clear", $__g_CD_bSearchResultsVisible)
    GUICtrlSetData($__g_CD_idSearchInput, "")
    __CD_SearchApplyFilter()
    _Test_AssertFalse("Regression GUI: cleared query hides panel", $__g_CD_bSearchResultsVisible)

    ; Close trigger 5: Escape -> the loop calls __CD_SearchClear while the panel is open.
    GUICtrlSetData($__g_CD_idSearchInput, "widget")
    __CD_SearchApplyFilter()
    _Test_AssertTrue("Regression GUI: panel re-shown before Escape", $__g_CD_bSearchResultsVisible)
    __CD_SearchClear()
    _Test_AssertFalse("Regression GUI: Escape closes panel", $__g_CD_bSearchResultsVisible)

    GUIDelete($hGuiSearch)
    $__g_CD_hGUI = 0
    $__g_CD_idSearchInput = 0
    $__g_CD_idSearchPanelBg = 0
    $__g_CD_idSearchCountLbl = 0
    Local $rc
    For $rc = 0 To $__g_CD_SEARCH_ROWS - 1
        $__g_CD_aidSearchRowLbl[$rc] = 0
        $__g_CD_aSearchRowEntry[$rc] = -1
    Next
    $__g_CD_bSearchResultsVisible = False
    $__g_CD_sSearchLast = ""
    $__g_CD_iSearchRowHovered = 0
    __CD_SearchReset()

    ; ============================================================
    ; t6-d: Slideshow sub-tab + color-bar animation rows
    ; ============================================================

    ; -- Option constants match the Config schema enum sets (pure) --
    _Test_AssertEqual("Slideshow selmode option list", $CD_OPT_SLIDESHOW_SELMODE, "all|even|odd|name_contains|custom")
    _Test_AssertEqual("Slideshow direction option list", $CD_OPT_SLIDESHOW_DIRECTION, "forward|backward")
    _Test_AssertEqual("Slideshow loop-mode option list", $CD_OPT_SLIDESHOW_LOOPMODE, "infinite|count|duration")
    _Test_AssertEqual("Color-bar anim option list", $CD_OPT_COLOR_BAR_ANIM, "none|grow|fade")
    ; Carousel -> Slideshow tray-enum rename regression (t6-a widened the enum)
    _Test_AssertTrue("Tray middle-click enum uses toggle_slideshow", StringInStr($CD_OPT_TRAY_MIDDLE, "toggle_slideshow") > 0)
    _Test_AssertFalse("Tray middle-click enum drops toggle_carousel", StringInStr($CD_OPT_TRAY_MIDDLE, "toggle_carousel") > 0)

    ; -- Combo apply/populate seam: localize -> delocalize round-trips every value --
    ; Exactly what populate (__CD_SetLocalizedOptions) and apply (__CD_DelocalizeOptionValue)
    ; do for the four new dropdowns, so a broken option-label key would surface here.
    __CD_TestOptionRoundTrip("Options.slideshow_selection_mode", $CD_OPT_SLIDESHOW_SELMODE)
    __CD_TestOptionRoundTrip("Options.slideshow_direction", $CD_OPT_SLIDESHOW_DIRECTION)
    __CD_TestOptionRoundTrip("Options.slideshow_loop_mode", $CD_OPT_SLIDESHOW_LOOPMODE)
    __CD_TestOptionRoundTrip("Options.color_bar_anim", $CD_OPT_COLOR_BAR_ANIM)

    ; -- Real GUI: build General + Behavior tabs to validate the new controls --
    Local $sSsIni = @TempDir & "\desk_switcheroo_cd_slideshow.ini"
    If FileExists($sSsIni) Then FileDelete($sSsIni)
    _Cfg_Init($sSsIni)

    Local $hGuiSs = GUICreate("CD Slideshow Test", 540, 700)
    $__g_CD_hGUI = $hGuiSs
    ; _CD_Show normally resets these; do it by hand for the partial build.
    $__g_CD_iChkCount = 0
    $__g_CD_aiTabCtrlCount[1] = 0
    $__g_CD_aiTabCtrlCount[4] = 0
    __CD_BuildTabGeneral()
    __CD_BuildTabBehavior()

    ; Control-count: the rebuilt Slideshow sub-tab registers 28 controls (was 5 for Carousel)
    _Test_AssertEqual("Slideshow sub-tab registers 28 controls", $__g_CD_iBhvSlideshowCount, 28)
    _Test_AssertTrue("Slideshow enable checkbox created", $__g_CD_idChkSlideshowEnabled <> 0)
    _Test_AssertTrue("Slideshow selection-mode combo created", $__g_CD_idCmbSlideshowSelMode <> 0)
    _Test_AssertTrue("Slideshow sequence input created", $__g_CD_idInpSlideshowSequence <> 0)
    _Test_AssertTrue("Color-bar anim combo created", $__g_CD_idCmbColorBarAnim <> 0)

    ; Populate round-trip: set config, run the real populate path, read controls back.
    _Cfg_SetSlideshowEnabled(True)
    _Cfg_SetSlideshowInterval(12345)
    _Cfg_SetSlideshowSelectionMode("even")
    _Cfg_SetSlideshowDirection("backward")
    _Cfg_SetSlideshowNameFilter("dev")
    _Cfg_SetSlideshowSequence("3,1,2")
    _Cfg_SetSlideshowDesktopIntervals("1:5000,3:8000")
    _Cfg_SetSlideshowLoopMode("count")
    _Cfg_SetSlideshowLoopCount(7)
    _Cfg_SetWidgetColorBarAnim("fade")
    _Cfg_SetWidgetColorBarAnimDuration(750)
    __CD_PopulateControls()
    _Test_AssertTrue("Populate: slideshow enabled checkbox on", __CD_GetCheckState($__g_CD_idChkSlideshowEnabled))
    _Test_AssertEqual("Populate: interval field", GUICtrlRead($__g_CD_idInpSlideshowInterval), "12345")
    _Test_AssertEqual("Populate: selection-mode combo", GUICtrlRead($__g_CD_idCmbSlideshowSelMode), __CD_LocalizeOptionValue("Options.slideshow_selection_mode", "even"))
    _Test_AssertEqual("Populate: direction combo", GUICtrlRead($__g_CD_idCmbSlideshowDirection), __CD_LocalizeOptionValue("Options.slideshow_direction", "backward"))
    _Test_AssertEqual("Populate: name filter field", GUICtrlRead($__g_CD_idInpSlideshowNameFilter), "dev")
    _Test_AssertEqual("Populate: custom sequence field", GUICtrlRead($__g_CD_idInpSlideshowSequence), "3,1,2")
    _Test_AssertEqual("Populate: per-desktop intervals field", GUICtrlRead($__g_CD_idInpSlideshowDesktopIntervals), "1:5000,3:8000")
    _Test_AssertEqual("Populate: loop-mode combo", GUICtrlRead($__g_CD_idCmbSlideshowLoopMode), __CD_LocalizeOptionValue("Options.slideshow_loop_mode", "count"))
    _Test_AssertEqual("Populate: loop count field", GUICtrlRead($__g_CD_idInpSlideshowLoopCount), "7")
    _Test_AssertEqual("Populate: color-bar anim combo", GUICtrlRead($__g_CD_idCmbColorBarAnim), __CD_LocalizeOptionValue("Options.color_bar_anim", "fade"))
    _Test_AssertEqual("Populate: color-bar anim duration field", GUICtrlRead($__g_CD_idInpColorBarAnimDur), "750")

    ; Search harvest: the new rows are tooltip-indexed and thus discoverable.
    __CD_BuildSearchIndex()
    _Test_AssertTrue("Search: 'slideshow' finds the new rows", __CD_SearchMatch("slideshow") >= 8)
    _Test_AssertTrue("Search: 'animation' finds the color-bar row", __CD_SearchMatch("animation") >= 1)

    ; Sub-tab switch stays flicker-locked (lock depth balances back to 0).
    $__g_CD_iLockDepth = 0
    __CD_SwitchBhvSub(3)
    _Test_AssertEqual("Switch to Slideshow sub-tab sets active index", $__g_CD_iBhvActiveSub, 3)
    _Test_AssertEqual("Sub-tab switch balances the flicker lock", $__g_CD_iLockDepth, 0)

    GUIDelete($hGuiSs)
    $__g_CD_hGUI = 0
    __CD_SearchReset()
    FileDelete($sSsIni)
EndFunc

; Asserts every option value survives localize -> delocalize (the combo apply/populate seam).
Func __CD_TestOptionRoundTrip($sBase, $sOptions)
    Local $aOpts = StringSplit($sOptions, "|")
    Local $i
    For $i = 1 To $aOpts[0]
        Local $sDisplay = __CD_LocalizeOptionValue($sBase, $aOpts[$i])
        _Test_AssertEqual("Round-trip " & $sBase & " = " & $aOpts[$i], _
            __CD_DelocalizeOptionValue($sBase, $sOptions, $sDisplay), $aOpts[$i])
    Next
EndFunc
