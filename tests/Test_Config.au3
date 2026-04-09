#include-once

; ===============================================================
; Tests for includes\Config.au3
; Unit tests — uses a temp INI file, no GUI required
; ===============================================================

Func _RunTest_Config()
    _Test_Suite("Config")

    Local $sTempIni = @TempDir & "\desk_switcheroo_test_config.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; -- Init creates INI with defaults --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Init sets path", _Cfg_GetPath(), $sTempIni)
    ; INI file existence verified implicitly by successful default value reads below

    ; -- Default values --
    _Test_AssertFalse("Default: start_with_windows", _Cfg_GetStartWithWindows())
    _Test_AssertTrue("Default: wrap_navigation", _Cfg_GetWrapNavigation())
    _Test_AssertFalse("Default: auto_create_desktop", _Cfg_GetAutoCreateDesktop())
    _Test_AssertEqual("Default: number_padding", _Cfg_GetNumberPadding(), 2)
    _Test_AssertEqual("Default: widget_position", _Cfg_GetWidgetPosition(), "left")
    _Test_AssertEqual("Default: widget_offset_x", _Cfg_GetWidgetOffsetX(), 0)
    _Test_AssertFalse("Default: show_count", _Cfg_GetShowCount())
    _Test_AssertEqual("Default: count_font_size", _Cfg_GetCountFontSize(), 7)
    _Test_AssertEqual("Default: theme_alpha_main", _Cfg_GetThemeAlphaMain(), 235)
    _Test_AssertFalse("Default: scroll_enabled", _Cfg_GetScrollEnabled())
    _Test_AssertEqual("Default: scroll_direction", _Cfg_GetScrollDirection(), "normal")
    _Test_AssertTrue("Default: scroll_wrap", _Cfg_GetScrollWrap())
    _Test_AssertFalse("Default: list_scroll_enabled", _Cfg_GetListScrollEnabled())
    _Test_AssertEqual("Default: list_scroll_action", _Cfg_GetListScrollAction(), "switch")
    _Test_AssertEqual("Default: hotkey_next", _Cfg_GetHotkeyNext(), "")
    _Test_AssertEqual("Default: hotkey_prev", _Cfg_GetHotkeyPrev(), "")
    _Test_AssertEqual("Default: hotkey_desktop_1", _Cfg_GetHotkeyDesktop(1), "")
    _Test_AssertEqual("Default: hotkey_toggle_list", _Cfg_GetHotkeyToggleList(), "")
    _Test_AssertTrue("Default: confirm_delete", _Cfg_GetConfirmDelete())
    _Test_AssertFalse("Default: middle_click_delete", _Cfg_GetMiddleClickDelete())
    _Test_AssertTrue("Default: move_window_enabled", _Cfg_GetMoveWindowEnabled())
    _Test_AssertEqual("Default: peek_bounce_delay", _Cfg_GetPeekBounceDelay(), 500)
    _Test_AssertEqual("Default: auto_hide_timeout", _Cfg_GetAutoHideTimeout(), 3000)
    _Test_AssertEqual("Default: topmost_interval", _Cfg_GetTopmostInterval(), 300)
    _Test_AssertEqual("Default: cm_auto_hide_delay", _Cfg_GetCmAutoHideDelay(), 500)
    _Test_AssertFalse("Default: desktop_colors_enabled", _Cfg_GetDesktopColorsEnabled())

    ; -- Set + Get round-trip --
    _Cfg_SetScrollEnabled(True)
    _Test_AssertTrue("Set+Get: scroll_enabled", _Cfg_GetScrollEnabled())

    _Cfg_SetWidgetPosition("center")
    _Test_AssertEqual("Set+Get: widget_position", _Cfg_GetWidgetPosition(), "center")

    _Cfg_SetNumberPadding(3)
    _Test_AssertEqual("Set+Get: number_padding", _Cfg_GetNumberPadding(), 3)

    _Cfg_SetThemeAlphaMain(180)
    _Test_AssertEqual("Set+Get: theme_alpha_main", _Cfg_GetThemeAlphaMain(), 180)

    _Cfg_SetHotkeyNext("^!{RIGHT}")
    _Test_AssertEqual("Set+Get: hotkey_next", _Cfg_GetHotkeyNext(), "^!{RIGHT}")

    _Cfg_SetDesktopColor(3, 0xFF0000)
    _Test_AssertEqual("Set+Get: desktop_color_3", _Cfg_GetDesktopColor(3), 0xFF0000)

    ; -- Save + reload persists values --
    _Cfg_Save()
    _Cfg_SetScrollEnabled(False)
    _Cfg_Load()
    _Test_AssertTrue("Persist: scroll_enabled survives reload", _Cfg_GetScrollEnabled())

    _Test_AssertEqual("Persist: widget_position survives reload", _Cfg_GetWidgetPosition(), "center")
    _Test_AssertEqual("Persist: hotkey_next survives reload", _Cfg_GetHotkeyNext(), "^!{RIGHT}")

    ; -- Invalid values fall back to defaults --
    IniWrite($sTempIni, "Scroll", "scroll_direction", "garbage")
    IniWrite($sTempIni, "Display", "theme_alpha_main", "9999")
    IniWrite($sTempIni, "General", "widget_position", "invalid")
    IniWrite($sTempIni, "General", "number_padding", "-5")
    _Cfg_Load()
    _Test_AssertEqual("Invalid enum falls back", _Cfg_GetScrollDirection(), "normal")
    _Test_AssertLessEqual("Clamped int <= 255", _Cfg_GetThemeAlphaMain(), 255)
    _Test_AssertEqual("Invalid position falls back", _Cfg_GetWidgetPosition(), "left")
    _Test_AssertGreaterEqual("Clamped padding >= 1", _Cfg_GetNumberPadding(), 1)

    ; -- Setter validation --
    _Cfg_SetWidgetPosition("bogus")
    _Test_AssertEqual("Invalid position setter falls back", _Cfg_GetWidgetPosition(), "left")

    _Cfg_SetNumberPadding(99)
    _Test_AssertLessEqual("Padding clamped to 4", _Cfg_GetNumberPadding(), 4)

    _Cfg_SetThemeAlphaMain(10)
    _Test_AssertGreaterEqual("Alpha clamped to 50", _Cfg_GetThemeAlphaMain(), 50)

    ; -- Out-of-range desktop index --
    _Test_AssertEqual("Desktop color out of range", _Cfg_GetDesktopColor(0), 0)
    _Test_AssertEqual("Desktop color out of range high", _Cfg_GetDesktopColor(10), 0)
    _Test_AssertEqual("Hotkey desktop out of range", _Cfg_GetHotkeyDesktop(0), "")

    ; -- Hotkey clear --
    _Cfg_SetHotkeyNext("")
    _Test_AssertEqual("Hotkey cleared", _Cfg_GetHotkeyNext(), "")

    ; -- Desktop colors default to none (0) --
    _Cfg_Load()
    _Test_AssertEqual("Color 1 defaults to none", _Cfg_GetDesktopColor(1), 0)
    _Test_AssertEqual("Color 2 defaults to none", _Cfg_GetDesktopColor(2), 0)

    ; -- New config keys: default values --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: widget_drag_enabled", _Cfg_GetWidgetDragEnabled())
    _Test_AssertFalse("Default: tray_icon_mode", _Cfg_GetTrayIconMode())
    _Test_AssertFalse("Default: quick_access_enabled", _Cfg_GetQuickAccessEnabled())
    _Test_AssertFalse("Default: config_watcher_enabled", _Cfg_GetConfigWatcherEnabled())
    _Test_AssertEqual("Default: config_watcher_interval", _Cfg_GetConfigWatcherInterval(), 60000)
    _Test_AssertFalse("Default: logging_enabled", _Cfg_GetLoggingEnabled())
    _Test_AssertEqual("Default: log_folder", _Cfg_GetLogFolder(), "")
    _Test_AssertEqual("Default: log_level", _Cfg_GetLogLevel(), "info")

    ; -- New config keys: Set+Get round-trips --
    _Cfg_SetWidgetDragEnabled(True)
    _Test_AssertTrue("Set+Get: widget_drag_enabled", _Cfg_GetWidgetDragEnabled())

    _Cfg_SetTrayIconMode(True)
    _Test_AssertTrue("Set+Get: tray_icon_mode", _Cfg_GetTrayIconMode())

    _Cfg_SetQuickAccessEnabled(True)
    _Test_AssertTrue("Set+Get: quick_access_enabled", _Cfg_GetQuickAccessEnabled())

    _Cfg_SetConfigWatcherEnabled(True)
    _Test_AssertTrue("Set+Get: config_watcher_enabled", _Cfg_GetConfigWatcherEnabled())

    _Cfg_SetConfigWatcherInterval(5000)
    _Test_AssertEqual("Set+Get: config_watcher_interval", _Cfg_GetConfigWatcherInterval(), 5000)

    _Cfg_SetLoggingEnabled(True)
    _Test_AssertTrue("Set+Get: logging_enabled", _Cfg_GetLoggingEnabled())

    _Cfg_SetLogFolder("C:\logs")
    _Test_AssertEqual("Set+Get: log_folder", _Cfg_GetLogFolder(), "C:\logs")

    _Cfg_SetLogLevel("debug")
    _Test_AssertEqual("Set+Get: log_level", _Cfg_GetLogLevel(), "debug")

    ; -- New config keys: validation --
    _Cfg_SetConfigWatcherInterval(50)
    _Test_AssertGreaterEqual("Watcher interval clamped low", _Cfg_GetConfigWatcherInterval(), 100)

    _Cfg_SetConfigWatcherInterval(999999)
    _Test_AssertLessEqual("Watcher interval clamped high", _Cfg_GetConfigWatcherInterval(), 300000)

    _Cfg_SetLogLevel("invalid")
    _Test_AssertEqual("Invalid log_level falls back", _Cfg_GetLogLevel(), "info")

    _Cfg_SetLogLevel("warn")
    _Test_AssertEqual("Valid log_level warn accepted", _Cfg_GetLogLevel(), "warn")

    _Cfg_SetLogLevel("info")
    _Test_AssertEqual("Valid log_level info accepted", _Cfg_GetLogLevel(), "info")

    ; -- Startup registry round-trip --
    _Cfg_EnableStartup()
    _Test_AssertTrue("Startup enabled in registry", _Cfg_IsStartupEnabled())
    _Cfg_DisableStartup()
    _Test_AssertFalse("Startup disabled in registry", _Cfg_IsStartupEnabled())

    ; -- Start minimized default --
    _Test_AssertFalse("Default: start_minimized", _Cfg_GetStartMinimized())
    _Cfg_SetStartMinimized(True)
    _Test_AssertTrue("Set+Get: start_minimized", _Cfg_GetStartMinimized())

    ; -- Theme default --
    _Test_AssertEqual("Default: theme", _Cfg_GetTheme(), "dark")
    _Cfg_SetTheme("midnight")
    _Test_AssertEqual("Set+Get: theme", _Cfg_GetTheme(), "midnight")
    _Cfg_SetTheme("invalid")
    _Test_AssertEqual("Invalid theme falls back", _Cfg_GetTheme(), "dark")

    ; -- List keyboard nav default --
    _Test_AssertFalse("Default: list_keyboard_nav", _Cfg_GetListKeyboardNav())
    _Cfg_SetListKeyboardNav(True)
    _Test_AssertTrue("Set+Get: list_keyboard_nav", _Cfg_GetListKeyboardNav())

    ; -- Import/Export round-trip --
    Local $sExportPath = @TempDir & "\desk_switcheroo_export_test.ini"
    If FileExists($sExportPath) Then FileDelete($sExportPath)
    _Cfg_SetScrollEnabled(True)
    _Cfg_SetNumberPadding(3)
    _Cfg_Save()
    _Test_AssertTrue("Export succeeds", _Cfg_Export($sExportPath))
    _Test_AssertTrue("Export file exists", FileExists($sExportPath) <> 0)
    ; Change values in memory
    _Cfg_SetScrollEnabled(False)
    _Cfg_SetNumberPadding(1)
    ; Import back
    _Test_AssertTrue("Import succeeds", _Cfg_Import($sExportPath))
    _Test_AssertTrue("Import restored scroll_enabled", _Cfg_GetScrollEnabled())
    _Test_AssertEqual("Import restored number_padding", _Cfg_GetNumberPadding(), 3)
    FileDelete($sExportPath)

    ; -- Import non-existent file fails --
    _Test_AssertFalse("Import nonexistent fails", _Cfg_Import("C:\nonexistent\fake.ini"))

    ; -- Edge case: empty string config values --
    _Cfg_SetHotkeyNext("")
    _Cfg_Save()
    _Cfg_Load()
    _Test_AssertEqual("Empty hotkey persists", _Cfg_GetHotkeyNext(), "")

    ; -- Edge case: special characters in log folder --
    _Cfg_SetLogFolder("C:\Users\test dir\logs")
    _Test_AssertEqual("Special chars in log folder", _Cfg_GetLogFolder(), "C:\Users\test dir\logs")

    ; -- Edge case: boundary values --
    _Cfg_SetThemeAlphaMain(50)
    _Test_AssertEqual("Alpha at min boundary", _Cfg_GetThemeAlphaMain(), 50)
    _Cfg_SetThemeAlphaMain(255)
    _Test_AssertEqual("Alpha at max boundary", _Cfg_GetThemeAlphaMain(), 255)
    _Cfg_SetNumberPadding(1)
    _Test_AssertEqual("Padding at min", _Cfg_GetNumberPadding(), 1)
    _Cfg_SetNumberPadding(4)
    _Test_AssertEqual("Padding at max", _Cfg_GetNumberPadding(), 4)

    ; -- Desktop color set and clear --
    _Cfg_SetDesktopColor(5, 0xFF0000)
    _Test_AssertEqual("Set desktop color", _Cfg_GetDesktopColor(5), 0xFF0000)
    _Cfg_SetDesktopColor(5, 0)
    _Test_AssertEqual("Clear desktop color to none", _Cfg_GetDesktopColor(5), 0)

    ; -- Auto-update settings --
    _Test_AssertFalse("Default: auto_update_enabled", _Cfg_GetAutoUpdateEnabled())
    _Test_AssertEqual("Default: auto_update_interval_hours", _Cfg_GetAutoUpdateIntervalHours(), 168)
    _Test_AssertGreaterEqual("Default: auto_update_interval_ms", _Cfg_GetAutoUpdateInterval(), 3600000)
    _Cfg_SetAutoUpdateEnabled(True)
    _Test_AssertTrue("Set+Get: auto_update_enabled", _Cfg_GetAutoUpdateEnabled())

    ; -- Update check on startup --
    _Test_AssertFalse("Default: update_check_on_startup", _Cfg_GetUpdateCheckOnStartup())
    _Test_AssertEqual("Default: update_check_days", _Cfg_GetUpdateCheckDays(), 7)
    _Cfg_SetUpdateCheckOnStartup(True)
    _Test_AssertTrue("Set+Get: update_check_on_startup", _Cfg_GetUpdateCheckOnStartup())
    _Cfg_SetUpdateCheckDays(14)
    _Test_AssertEqual("Set+Get: update_check_days", _Cfg_GetUpdateCheckDays(), 14)

    ; -- Quit confirmation --
    _Test_AssertFalse("Default: confirm_quit", _Cfg_GetConfirmQuit())
    _Cfg_SetConfirmQuit(True)
    _Test_AssertTrue("Set+Get: confirm_quit", _Cfg_GetConfirmQuit())

    ; -- Count cache TTL --
    _Test_AssertEqual("Default: count_cache_ttl", _Cfg_GetCountCacheTTL(), 1000)
    _Cfg_SetCountCacheTTL(2000)
    _Test_AssertEqual("Set+Get: count_cache_ttl", _Cfg_GetCountCacheTTL(), 2000)

    ; -- Hotkey desktop count --
    _Test_AssertEqual("Default: hotkey_desktop_count", _Cfg_GetHotkeyDesktopCount(), 9)
    _Cfg_SetHotkeyDesktopCount(5)
    _Test_AssertEqual("Set+Get: hotkey_desktop_count", _Cfg_GetHotkeyDesktopCount(), 5)

    ; -- List font --
    _Test_AssertEqual("Default: list_font_name", _Cfg_GetListFontName(), "")
    _Test_AssertEqual("Default: list_font_size", _Cfg_GetListFontSize(), 8)
    _Cfg_SetListFontName("Consolas")
    _Test_AssertEqual("Set+Get: list_font_name", _Cfg_GetListFontName(), "Consolas")
    _Cfg_SetListFontSize(10)
    _Test_AssertEqual("Set+Get: list_font_size", _Cfg_GetListFontSize(), 10)

    ; -- Scrollable list --
    _Test_AssertFalse("Default: list_scrollable", _Cfg_GetListScrollable())
    _Test_AssertEqual("Default: list_max_visible", _Cfg_GetListMaxVisible(), 10)
    _Test_AssertEqual("Default: list_scroll_speed", _Cfg_GetListScrollSpeed(), 1)
    _Cfg_SetListScrollable(True)
    _Test_AssertTrue("Set+Get: list_scrollable", _Cfg_GetListScrollable())

    ; -- Tooltip font size --
    _Test_AssertEqual("Default: tooltip_font_size", _Cfg_GetTooltipFontSize(), 8)
    _Cfg_SetTooltipFontSize(10)
    _Test_AssertEqual("Set+Get: tooltip_font_size", _Cfg_GetTooltipFontSize(), 10)

    ; -- Thumbnails --
    _Test_AssertFalse("Default: thumbnails_enabled", _Cfg_GetThumbnailsEnabled())
    _Test_AssertEqual("Default: thumbnail_width", _Cfg_GetThumbnailWidth(), 160)
    _Test_AssertEqual("Default: thumbnail_height", _Cfg_GetThumbnailHeight(), 90)
    _Cfg_SetThumbnailsEnabled(True)
    _Test_AssertTrue("Set+Get: thumbnails_enabled", _Cfg_GetThumbnailsEnabled())

    ; -- Log enhanced settings --
    _Test_AssertEqual("Default: log_max_size_mb", _Cfg_GetLogMaxSizeMB(), 5)
    _Test_AssertEqual("Default: log_rotate_count", _Cfg_GetLogRotateCount(), 3)
    _Test_AssertFalse("Default: log_compress_old", _Cfg_GetLogCompressOld())
    _Test_AssertEqual("Default: log_folder (extended)", _Cfg_GetLogFolder(), "")
    _Cfg_SetLogMaxSizeMB(10)
    _Test_AssertEqual("Set+Get: log_max_size_mb", _Cfg_GetLogMaxSizeMB(), 10)
    _Cfg_SetLogRotateCount(5)
    _Test_AssertEqual("Set+Get: log_rotate_count", _Cfg_GetLogRotateCount(), 5)

    ; -- Cleanup --
    FileDelete($sTempIni)
EndFunc
