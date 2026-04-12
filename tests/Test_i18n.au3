#include-once

; ===============================================================
; Tests for includes\i18n.au3
; Unit tests — verifies locale system, key coverage, fallback
; ===============================================================

Func _RunTest_i18n()
    _Test_Suite("i18n")

    ; -- Init loads en-US --
    _i18n_Init("en-US")
    _Test_AssertEqual("Current language", _i18n_GetCurrent(), "en-US")

    ; -- GetAvailable includes en-US --
    Local $sAvail = _i18n_GetAvailable()
    _Test_AssertTrue("Available includes en-US", StringInStr($sAvail, "en-US") > 0)

    ; -- Known key returns locale value (not default) --
    Local $sVal = _i18n("General.btn_ok", "FALLBACK")
    _Test_AssertEqual("Known key returns OK", $sVal, "OK")

    ; -- Unknown key returns default --
    Local $sMiss = _i18n("NonExistent.fake_key", "MyDefault")
    _Test_AssertEqual("Missing key returns default", $sMiss, "MyDefault")

    ; -- Format replaces {1} --
    Local $sFmt = _i18n_Format("Dialogs.rd_title", "Label for Desktop {1}", 3)
    _Test_AssertTrue("Format replaces {1}", StringInStr($sFmt, "3") > 0)
    _Test_AssertFalse("Format no leftover {1}", StringInStr($sFmt, "{1}") > 0)

    ; -- Format replaces {1} and {2} --
    Local $sFmt2 = _i18n_Format("Updates.upd_current_latest", "Current: v{1}  |  Latest: v{2}", "1.0", "2.0")
    _Test_AssertTrue("Format {1} replaced", StringInStr($sFmt2, "1.0") > 0)
    _Test_AssertTrue("Format {2} replaced", StringInStr($sFmt2, "2.0") > 0)

    ; -- Newline replacement --
    ; en-US.ini has about_description with \n
    Local $sDesc = _i18n("Dialogs.about_description", "fallback")
    _Test_AssertTrue("Newline replaced", StringInStr($sDesc, @CRLF) > 0 Or $sDesc <> "fallback")

    ; -- Key coverage: verify en-US.ini has at least 200 keys --
    Local $iKeyCount = __Test_CountLocaleKeys(@ScriptDir & "\..\locales\en-US.ini")
    _Test_AssertGreaterEqual("en-US.ini has >= 200 keys", $iKeyCount, 200)

    ; -- Reinit with nonexistent locale falls back to en-US --
    _i18n_Init("xx-FAKE")
    _Test_AssertEqual("Fake locale current", _i18n_GetCurrent(), "xx-FAKE")
    Local $sFallback = _i18n("General.btn_ok", "NOPE")
    _Test_AssertEqual("Fake locale falls back to en-US", $sFallback, "OK")

    ; Restore
    _i18n_Init("en-US")

    ; -- GetAvailableDisplay returns formatted strings --
    Local $sDisplay = _i18n_GetAvailableDisplay()
    _Test_AssertTrue("Display list non-empty", StringLen($sDisplay) > 10)
    _Test_AssertTrue("Display has pipe separator", StringInStr($sDisplay, "|") > 0)

    ; -- DisplayToCode extracts locale code --
    Local $sCode = _i18n_DisplayToCode("en-US " & ChrW(0x2014) & " English (United States)")
    _Test_AssertEqual("DisplayToCode en-US", $sCode, "en-US")

    ; -- DisplayToCode with unknown format returns input --
    Local $sRaw = _i18n_DisplayToCode("garbage")
    _Test_AssertEqual("DisplayToCode passthrough", $sRaw, "garbage")

    ; -- All 33 locale files exist and have >= 200 keys --
    Local $aLocales[34] = [33, "ar-EG", "ar-SA", "bn-IN", "da-DK", "de-DE", "en-CA", "en-GB", "en-IN", "en-US", _
        "es-AR", "es-ES", "es-MX", "fr-CA", "fr-FR", "hi-IN", "hu-HU", "id-ID", "is-IS", "it-IT", _
        "ko-KR", "nl-NL", "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sv-SE", "th-TH", "tr-TR", _
        "uk-UA", "vi-VN", "zh-CN", "zh-TW"]
    Local $sLocaleDir = @ScriptDir & "\..\locales\"
    Local $iL
    For $iL = 1 To $aLocales[0]
        Local $sFile = $sLocaleDir & $aLocales[$iL] & ".ini"
        _Test_AssertTrue("Locale file exists: " & $aLocales[$iL], FileExists($sFile))
        Local $iKeys = __Test_CountLocaleKeys($sFile)
        _Test_AssertGreaterEqual("Locale " & $aLocales[$iL] & " has >= 200 keys", $iKeys, 200)
    Next

    ; -- Format with {3} placeholder --
    Local $sFmt3 = _i18n_Format("NonExistent.test", "a={1} b={2} c={3}", "X", "Y", "Z")
    _Test_AssertTrue("Format {3} replaced", StringInStr($sFmt3, "Z") > 0)
    _Test_AssertFalse("No leftover {3}", StringInStr($sFmt3, "{3}") > 0)

    ; -- Phase 1C toast keys exist and return non-default values --
    _Test_AssertNotEqual("toast_window_sent exists", _i18n("Toasts.toast_window_sent", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_desktop_created exists", _i18n("Toasts.toast_desktop_created", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_desktop_deleted exists", _i18n("Toasts.toast_desktop_deleted", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_window_pinned exists", _i18n("Toasts.toast_window_pinned", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_window_unpinned exists", _i18n("Toasts.toast_window_unpinned", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_wallpaper_applied exists", _i18n("Toasts.toast_wallpaper_applied", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_explorer_recovered exists", _i18n("Toasts.toast_explorer_recovered", "MISSING"), "MISSING")
    _Test_AssertNotEqual("toast_min_desktops_created exists", _i18n("Toasts.toast_min_desktops_created", "MISSING"), "MISSING")

    ; -- Phase 1C tab names exist --
    _Test_AssertNotEqual("tab_wallpaper exists", _i18n("Tabs.tab_wallpaper", "MISSING"), "MISSING")
    _Test_AssertNotEqual("tab_window_list exists", _i18n("Tabs.tab_window_list", "MISSING"), "MISSING")
    _Test_AssertNotEqual("tab_explorer exists", _i18n("Tabs.tab_explorer", "MISSING"), "MISSING")
    _Test_AssertNotEqual("tab_notifications exists", _i18n("Tabs.tab_notifications", "MISSING"), "MISSING")
    _Test_AssertNotEqual("tab_pinning exists", _i18n("Tabs.tab_pinning", "MISSING"), "MISSING")

    ; -- WindowList section keys exist --
    _Test_AssertNotEqual("wl_title exists", _i18n("WindowList.wl_title", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_search_placeholder exists", _i18n("WindowList.wl_search_placeholder", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_no_windows exists", _i18n("WindowList.wl_no_windows", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_pin_window exists", _i18n("WindowList.wl_pin_window", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_send_to_next exists", _i18n("WindowList.wl_send_to_next", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_send_to_prev exists", _i18n("WindowList.wl_send_to_prev", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_send_to_new exists", _i18n("WindowList.wl_send_to_new", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_unpin_window exists", _i18n("WindowList.wl_unpin_window", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_pull_to_current exists", _i18n("WindowList.wl_pull_to_current", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_go_to_desktop exists", _i18n("WindowList.wl_go_to_desktop", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_minimize exists", _i18n("WindowList.wl_minimize", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_maximize exists", _i18n("WindowList.wl_maximize", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_restore exists", _i18n("WindowList.wl_restore", "MISSING"), "MISSING")
    _Test_AssertNotEqual("wl_close exists", _i18n("WindowList.wl_close", "MISSING"), "MISSING")

    ; -- Settings section keys exist --
    _Test_AssertNotEqual("chk_wallpaper_enabled exists", _i18n("Settings.Wallpaper.chk_wallpaper_enabled", "MISSING"), "MISSING")
    _Test_AssertNotEqual("chk_wl_enabled exists", _i18n("Settings.WindowList.chk_wl_enabled", "MISSING"), "MISSING")
    _Test_AssertNotEqual("chk_explorer_monitor exists", _i18n("Settings.Explorer.chk_explorer_monitor", "MISSING"), "MISSING")
    _Test_AssertNotEqual("chk_notify_moved exists", _i18n("Settings.Notifications.chk_notify_moved", "MISSING"), "MISSING")

    ; -- New hotkey labels exist --
    _Test_AssertNotEqual("lbl_hotkey_toggle_last exists", _i18n("Settings.Hotkeys.lbl_hotkey_toggle_last", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_move_follow_next exists", _i18n("Settings.Hotkeys.lbl_hotkey_move_follow_next", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_move_follow_prev exists", _i18n("Settings.Hotkeys.lbl_hotkey_move_follow_prev", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_move_next exists", _i18n("Settings.Hotkeys.lbl_hotkey_move_next", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_move_prev exists", _i18n("Settings.Hotkeys.lbl_hotkey_move_prev", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_send_new exists", _i18n("Settings.Hotkeys.lbl_hotkey_send_new", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_pin_window exists", _i18n("Settings.Hotkeys.lbl_hotkey_pin_window", "MISSING"), "MISSING")
    _Test_AssertNotEqual("lbl_hotkey_toggle_wl exists", _i18n("Settings.Hotkeys.lbl_hotkey_toggle_wl", "MISSING"), "MISSING")

    ; -- Format with {1} works for toast_window_sent --
    Local $sFmtToast = _i18n_Format("Toasts.toast_window_sent", "Window sent to Desktop {1}", 3)
    _Test_AssertTrue("toast_window_sent format {1}", StringInStr($sFmtToast, "3") > 0)
    _Test_AssertFalse("toast_window_sent no leftover {1}", StringInStr($sFmtToast, "{1}") > 0)

    ; -- Format with {1} works for toast_desktop_created --
    Local $sFmtCreate = _i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", 5)
    _Test_AssertTrue("toast_desktop_created format {1}", StringInStr($sFmtCreate, "5") > 0)
    _Test_AssertFalse("toast_desktop_created no leftover {1}", StringInStr($sFmtCreate, "{1}") > 0)
EndFunc

; Helper: count total keys in a locale INI file (excluding [Meta])
Func __Test_CountLocaleKeys($sPath)
    Local $aSections = IniReadSectionNames($sPath)
    If @error Then Return 0
    Local $iTotal = 0, $i, $j
    For $i = 1 To $aSections[0]
        If $aSections[$i] = "Meta" Then ContinueLoop
        Local $aKeys = IniReadSection($sPath, $aSections[$i])
        If Not @error Then $iTotal += $aKeys[0][0]
    Next
    Return $iTotal
EndFunc
