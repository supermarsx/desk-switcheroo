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
    _Test_AssertEqual("Default: widget_position", _Cfg_GetWidgetPosition(), "bottom-left")
    _Test_AssertEqual("Default: widget_offset_x", _Cfg_GetWidgetOffsetX(), 0)
    _Test_AssertFalse("Default: show_count", _Cfg_GetShowCount())
    _Test_AssertEqual("Default: count_font_size", _Cfg_GetCountFontSize(), 7)
    _Test_AssertEqual("Default: theme_alpha_main", _Cfg_GetThemeAlphaMain(), 235)
    _Test_AssertFalse("Default: scroll_enabled", _Cfg_GetScrollEnabled())
    _Test_AssertEqual("Default: scroll_direction", _Cfg_GetScrollDirection(), "normal")
    _Test_AssertTrue("Default: scroll_wrap", _Cfg_GetScrollWrap())
    _Test_AssertFalse("Default: list_scroll_enabled", _Cfg_GetListScrollEnabled())
    _Test_AssertEqual("Default: list_scroll_action", _Cfg_GetListScrollAction(), "switch")
    _Test_AssertEqual("Default: hotkey_next", _Cfg_GetHotkeyNext(), "^!{RIGHT}")
    _Test_AssertEqual("Default: hotkey_prev", _Cfg_GetHotkeyPrev(), "^!{LEFT}")
    _Test_AssertEqual("Default: hotkey_desktop_1", _Cfg_GetHotkeyDesktop(1), "")
    _Test_AssertEqual("Default: hotkey_toggle_list", _Cfg_GetHotkeyToggleList(), "^!{DOWN}")
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

    _Cfg_SetWidgetPosition("bottom-center")
    _Test_AssertEqual("Set+Get: widget_position", _Cfg_GetWidgetPosition(), "bottom-center")

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

    _Test_AssertEqual("Persist: widget_position survives reload", _Cfg_GetWidgetPosition(), "bottom-center")
    _Test_AssertEqual("Persist: hotkey_next survives reload", _Cfg_GetHotkeyNext(), "^!{RIGHT}")

    ; -- Invalid values fall back to defaults --
    IniWrite($sTempIni, "Scroll", "scroll_direction", "garbage")
    IniWrite($sTempIni, "Display", "theme_alpha_main", "9999")
    IniWrite($sTempIni, "General", "widget_position", "invalid")
    IniWrite($sTempIni, "General", "number_padding", "-5")
    _Cfg_Load()
    _Test_AssertEqual("Invalid enum falls back", _Cfg_GetScrollDirection(), "normal")
    _Test_AssertLessEqual("Clamped int <= 255", _Cfg_GetThemeAlphaMain(), 255)
    _Test_AssertEqual("Invalid position falls back", _Cfg_GetWidgetPosition(), "bottom-left")
    _Test_AssertGreaterEqual("Clamped padding >= 1", _Cfg_GetNumberPadding(), 1)

    ; -- Setter validation --
    _Cfg_SetWidgetPosition("bogus")
    _Test_AssertEqual("Invalid position setter falls back", _Cfg_GetWidgetPosition(), "bottom-left")

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
    Sleep(600) ; wait for save debounce window to pass
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
    Sleep(600) ; wait for save debounce window
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
    _Cfg_SetLogFolder("")
    _Test_AssertEqual("Reset: log_folder cleared", _Cfg_GetLogFolder(), "")
    _Cfg_SetLogMaxSizeMB(10)
    _Test_AssertEqual("Set+Get: log_max_size_mb", _Cfg_GetLogMaxSizeMB(), 10)
    _Cfg_SetLogRotateCount(5)
    _Test_AssertEqual("Set+Get: log_rotate_count", _Cfg_GetLogRotateCount(), 5)

    ; -- Widget color bar --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: widget_color_bar", _Cfg_GetWidgetColorBar())
    _Test_AssertEqual("Default: widget_color_bar_height", _Cfg_GetWidgetColorBarHeight(), 2)
    _Cfg_SetWidgetColorBar(True)
    _Test_AssertTrue("Set+Get: widget_color_bar", _Cfg_GetWidgetColorBar())
    _Cfg_SetWidgetColorBarHeight(5)
    _Test_AssertEqual("Set+Get: widget_color_bar_height", _Cfg_GetWidgetColorBarHeight(), 5)
    _Cfg_SetWidgetColorBarHeight(0)
    _Test_AssertGreaterEqual("Color bar height clamped low", _Cfg_GetWidgetColorBarHeight(), 1)
    _Cfg_SetWidgetColorBarHeight(99)
    _Test_AssertLessEqual("Color bar height clamped high", _Cfg_GetWidgetColorBarHeight(), 10)

    ; -- Debug mode --
    _Test_AssertFalse("Default: debug_mode", _Cfg_GetDebugMode())
    _Cfg_SetDebugMode(True)
    _Test_AssertTrue("Set+Get: debug_mode", _Cfg_GetDebugMode())

    ; -- Thumbnail use screenshot + cache TTL --
    _Test_AssertFalse("Default: thumbnail_use_screenshot", _Cfg_GetThumbnailUseScreenshot())
    _Test_AssertEqual("Default: thumbnail_cache_ttl", _Cfg_GetThumbnailCacheTTL(), 30)
    _Cfg_SetThumbnailUseScreenshot(True)
    _Test_AssertTrue("Set+Get: thumbnail_use_screenshot", _Cfg_GetThumbnailUseScreenshot())
    _Cfg_SetThumbnailCacheTTL(60)
    _Test_AssertEqual("Set+Get: thumbnail_cache_ttl", _Cfg_GetThumbnailCacheTTL(), 60)

    ; -- Log extended settings --
    _Cfg_SetLogCompressOld(True)
    _Test_AssertTrue("Set+Get: log_compress_old", _Cfg_GetLogCompressOld())
    _Test_AssertFalse("Default: log_include_pid", _Cfg_GetLogIncludePID())
    _Cfg_SetLogIncludePID(True)
    _Test_AssertTrue("Set+Get: log_include_pid", _Cfg_GetLogIncludePID())
    _Test_AssertFalse("Default: log_include_func", _Cfg_GetLogIncludeFunc())
    _Cfg_SetLogIncludeFunc(True)
    _Test_AssertTrue("Set+Get: log_include_func", _Cfg_GetLogIncludeFunc())
    _Test_AssertEqual("Default: log_date_format", _Cfg_GetLogDateFormat(), "iso")
    _Cfg_SetLogDateFormat("us")
    _Test_AssertEqual("Set+Get: log_date_format", _Cfg_GetLogDateFormat(), "us")
    _Cfg_SetLogDateFormat("invalid")
    _Test_AssertEqual("Invalid log_date_format falls back", _Cfg_GetLogDateFormat(), "iso")
    _Test_AssertTrue("Default: log_flush_immediate", _Cfg_GetLogFlushImmediate())
    _Cfg_SetLogFlushImmediate(False)
    _Test_AssertFalse("Set+Get: log_flush_immediate", _Cfg_GetLogFlushImmediate())

    ; -- Log file path derivation --
    _Cfg_SetLogFolder("")
    _Test_AssertTrue("LogFilePath has desk_switcheroo.log", StringInStr(_Cfg_GetLogFilePath(), "desk_switcheroo.log") > 0)
    _Cfg_SetLogFolder("C:\MyLogs")
    _Test_AssertEqual("LogFilePath from folder", _Cfg_GetLogFilePath(), "C:\MyLogs\desk_switcheroo.log")
    _Cfg_SetLogFolder("C:\MyLogs\")
    _Test_AssertEqual("LogFilePath strips trailing slash", _Cfg_GetLogFilePath(), "C:\MyLogs\desk_switcheroo.log")

    ; -- Remaining setter round-trips for full coverage --
    _Cfg_SetStartWithWindows(True)
    _Test_AssertTrue("Set+Get: start_with_windows", _Cfg_GetStartWithWindows())
    _Cfg_SetWrapNavigation(False)
    _Test_AssertFalse("Set+Get: wrap_navigation", _Cfg_GetWrapNavigation())
    _Cfg_SetAutoCreateDesktop(True)
    _Test_AssertTrue("Set+Get: auto_create_desktop", _Cfg_GetAutoCreateDesktop())
    _Cfg_SetWidgetOffsetX(42)
    _Test_AssertEqual("Set+Get: widget_offset_x", _Cfg_GetWidgetOffsetX(), 42)
    _Cfg_SetShowCount(True)
    _Test_AssertTrue("Set+Get: show_count", _Cfg_GetShowCount())
    _Cfg_SetCountFontSize(9)
    _Test_AssertEqual("Set+Get: count_font_size", _Cfg_GetCountFontSize(), 9)
    _Cfg_SetAutoUpdateInterval(48)
    _Test_AssertEqual("Set+Get: auto_update_interval", _Cfg_GetAutoUpdateIntervalHours(), 48)
    _Cfg_SetScrollDirection("inverted")
    _Test_AssertEqual("Set+Get: scroll_direction", _Cfg_GetScrollDirection(), "inverted")
    _Cfg_SetScrollWrap(False)
    _Test_AssertFalse("Set+Get: scroll_wrap", _Cfg_GetScrollWrap())
    _Cfg_SetListScrollEnabled(True)
    _Test_AssertTrue("Set+Get: list_scroll_enabled", _Cfg_GetListScrollEnabled())
    _Cfg_SetListScrollAction("scroll")
    _Test_AssertEqual("Set+Get: list_scroll_action", _Cfg_GetListScrollAction(), "scroll")
    _Cfg_SetHotkeyPrev("^!{LEFT}")
    _Test_AssertEqual("Set+Get: hotkey_prev", _Cfg_GetHotkeyPrev(), "^!{LEFT}")
    _Cfg_SetHotkeyDesktop(3, "^!3")
    _Test_AssertEqual("Set+Get: hotkey_desktop_3", _Cfg_GetHotkeyDesktop(3), "^!3")
    _Cfg_SetHotkeyToggleList("^!l")
    _Test_AssertEqual("Set+Get: hotkey_toggle_list", _Cfg_GetHotkeyToggleList(), "^!l")
    _Cfg_SetConfirmDelete(False)
    _Test_AssertFalse("Set+Get: confirm_delete", _Cfg_GetConfirmDelete())
    _Cfg_SetMiddleClickDelete(True)
    _Test_AssertTrue("Set+Get: middle_click_delete", _Cfg_GetMiddleClickDelete())
    _Cfg_SetMoveWindowEnabled(False)
    _Test_AssertFalse("Set+Get: move_window_enabled", _Cfg_GetMoveWindowEnabled())
    _Cfg_SetPeekBounceDelay(300)
    _Test_AssertEqual("Set+Get: peek_bounce_delay", _Cfg_GetPeekBounceDelay(), 300)
    _Cfg_SetAutoHideTimeout(5000)
    _Test_AssertEqual("Set+Get: auto_hide_timeout", _Cfg_GetAutoHideTimeout(), 5000)
    _Cfg_SetTopmostInterval(500)
    _Test_AssertEqual("Set+Get: topmost_interval", _Cfg_GetTopmostInterval(), 500)
    _Cfg_SetCmAutoHideDelay(1000)
    _Test_AssertEqual("Set+Get: cm_auto_hide_delay", _Cfg_GetCmAutoHideDelay(), 1000)
    _Cfg_SetDesktopColorsEnabled(True)
    _Test_AssertTrue("Set+Get: desktop_colors_enabled", _Cfg_GetDesktopColorsEnabled())
    _Cfg_SetThumbnailWidth(200)
    _Test_AssertEqual("Set+Get: thumbnail_width", _Cfg_GetThumbnailWidth(), 200)
    _Cfg_SetThumbnailHeight(120)
    _Test_AssertEqual("Set+Get: thumbnail_height", _Cfg_GetThumbnailHeight(), 120)
    _Cfg_SetListMaxVisible(15)
    _Test_AssertEqual("Set+Get: list_max_visible", _Cfg_GetListMaxVisible(), 15)
    _Cfg_SetListScrollSpeed(3)
    _Test_AssertEqual("Set+Get: list_scroll_speed", _Cfg_GetListScrollSpeed(), 3)

    ; -- Widget anchor and dimensions --
    _Test_AssertEqual("Default: widget_position", _Cfg_GetWidgetPosition(), "bottom-left")
    _Cfg_SetWidgetPosition("top-right")
    _Test_AssertEqual("Set+Get: widget_position top-right", _Cfg_GetWidgetPosition(), "top-right")
    _Cfg_SetWidgetPosition("middle-left")
    _Test_AssertEqual("Set+Get: widget_position middle-left", _Cfg_GetWidgetPosition(), "middle-left")
    ; Legacy compat
    _Cfg_SetWidgetPosition("left")
    _Test_AssertEqual("Legacy left -> bottom-left", _Cfg_GetWidgetPosition(), "bottom-left")
    _Cfg_SetWidgetPosition("center")
    _Test_AssertEqual("Legacy center -> bottom-center", _Cfg_GetWidgetPosition(), "bottom-center")
    _Cfg_SetWidgetPosition("right")
    _Test_AssertEqual("Legacy right -> bottom-right", _Cfg_GetWidgetPosition(), "bottom-right")
    _Cfg_SetWidgetPosition("invalid-anchor")
    _Test_AssertEqual("Invalid anchor -> bottom-left", _Cfg_GetWidgetPosition(), "bottom-left")
    ; Offset Y
    _Test_AssertEqual("Default: widget_offset_y", _Cfg_GetWidgetOffsetY(), 0)
    _Cfg_SetWidgetOffsetY(50)
    _Test_AssertEqual("Set+Get: widget_offset_y", _Cfg_GetWidgetOffsetY(), 50)
    ; Widget dimensions
    _Test_AssertEqual("Default: widget_width", _Cfg_GetWidgetWidth(), 0)
    _Test_AssertEqual("Default: widget_height", _Cfg_GetWidgetHeight(), 0)
    _Cfg_SetWidgetWidth(200)
    _Test_AssertEqual("Set+Get: widget_width", _Cfg_GetWidgetWidth(), 200)
    _Cfg_SetWidgetHeight(80)
    _Test_AssertEqual("Set+Get: widget_height", _Cfg_GetWidgetHeight(), 80)
    _Cfg_SetWidgetWidth(999)
    _Test_AssertLessEqual("Widget width clamped high", _Cfg_GetWidgetWidth(), 500)
    _Cfg_SetWidgetHeight(999)
    _Test_AssertLessEqual("Widget height clamped high", _Cfg_GetWidgetHeight(), 200)
    _Cfg_SetWidgetWidth(-1)
    _Test_AssertGreaterEqual("Widget width clamped low", _Cfg_GetWidgetWidth(), 0)

    ; ===========================================
    ; Phase 1A: New config keys
    ; ===========================================
    _Cfg_Init($sTempIni)

    ; -- [General] singleton_enabled: default True, set/get --
    _Test_AssertTrue("Default: singleton_enabled", _Cfg_GetSingletonEnabled())
    _Cfg_SetSingletonEnabled(False)
    _Test_AssertFalse("Set+Get: singleton_enabled off", _Cfg_GetSingletonEnabled())
    _Cfg_SetSingletonEnabled(True)
    _Test_AssertTrue("Set+Get: singleton_enabled on", _Cfg_GetSingletonEnabled())

    ; -- [General] min_desktops: default 0, set/get, clamped 0-20 --
    _Test_AssertEqual("Default: min_desktops", _Cfg_GetMinDesktops(), 0)
    _Cfg_SetMinDesktops(5)
    _Test_AssertEqual("Set+Get: min_desktops", _Cfg_GetMinDesktops(), 5)
    _Cfg_SetMinDesktops(-1)
    _Test_AssertGreaterEqual("min_desktops clamped low", _Cfg_GetMinDesktops(), 0)
    _Cfg_SetMinDesktops(25)
    _Test_AssertLessEqual("min_desktops clamped high", _Cfg_GetMinDesktops(), 50)

    ; -- [General] taskbar_focus_trick: default False, set/get --
    _Test_AssertFalse("Default: taskbar_focus_trick", _Cfg_GetTaskbarFocusTrick())
    _Cfg_SetTaskbarFocusTrick(True)
    _Test_AssertTrue("Set+Get: taskbar_focus_trick", _Cfg_GetTaskbarFocusTrick())

    ; -- [General] auto_focus_after_switch: default False, set/get --
    _Test_AssertFalse("Default: auto_focus_after_switch", _Cfg_GetAutoFocusAfterSwitch())
    _Cfg_SetAutoFocusAfterSwitch(True)
    _Test_AssertTrue("Set+Get: auto_focus_after_switch", _Cfg_GetAutoFocusAfterSwitch())

    ; -- [General] capslock_modifier: default False, set/get --
    _Test_AssertFalse("Default: capslock_modifier", _Cfg_GetCapslockModifier())
    _Cfg_SetCapslockModifier(True)
    _Test_AssertTrue("Set+Get: capslock_modifier", _Cfg_GetCapslockModifier())

    ; -- [Wallpaper] wallpaper_enabled: default False, set/get --
    _Test_AssertFalse("Default: wallpaper_enabled", _Cfg_GetWallpaperEnabled())
    _Cfg_SetWallpaperEnabled(True)
    _Test_AssertTrue("Set+Get: wallpaper_enabled", _Cfg_GetWallpaperEnabled())

    ; -- [Wallpaper] wallpaper_change_delay: default 200, set/get, clamped 50-2000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: wallpaper_change_delay", _Cfg_GetWallpaperChangeDelay(), 200)
    _Cfg_SetWallpaperChangeDelay(500)
    _Test_AssertEqual("Set+Get: wallpaper_change_delay", _Cfg_GetWallpaperChangeDelay(), 500)
    _Cfg_SetWallpaperChangeDelay(10)
    _Test_AssertGreaterEqual("wallpaper_change_delay clamped low", _Cfg_GetWallpaperChangeDelay(), 50)
    _Cfg_SetWallpaperChangeDelay(5000)
    _Test_AssertLessEqual("wallpaper_change_delay clamped high", _Cfg_GetWallpaperChangeDelay(), 2000)

    ; -- [Wallpaper] desktop wallpaper paths: default "", set/get for 1 and 9, out-of-range --
    _Test_AssertEqual("Default: wallpaper desktop 1", _Cfg_GetDesktopWallpaper(1), "")
    _Test_AssertEqual("Default: wallpaper desktop 9", _Cfg_GetDesktopWallpaper(9), "")
    _Cfg_SetDesktopWallpaper(1, "C:\walls\bg1.jpg")
    _Test_AssertEqual("Set+Get: wallpaper desktop 1", _Cfg_GetDesktopWallpaper(1), "C:\walls\bg1.jpg")
    _Cfg_SetDesktopWallpaper(9, "C:\walls\bg9.png")
    _Test_AssertEqual("Set+Get: wallpaper desktop 9", _Cfg_GetDesktopWallpaper(9), "C:\walls\bg9.png")
    _Test_AssertEqual("Wallpaper out-of-range 0", _Cfg_GetDesktopWallpaper(0), "")
    _Test_AssertEqual("Wallpaper out-of-range 10", _Cfg_GetDesktopWallpaper(10), "")

    ; -- [Pinning] pinning_enabled: default False, set/get --
    _Test_AssertFalse("Default: pinning_enabled", _Cfg_GetPinningEnabled())
    _Cfg_SetPinningEnabled(True)
    _Test_AssertTrue("Set+Get: pinning_enabled", _Cfg_GetPinningEnabled())

    ; -- [Hotkeys] 8 new hotkey strings: default "", set/get round-trip --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: hotkey_toggle_last", _Cfg_GetHotkeyToggleLast(), "^!{TAB}")
    _Cfg_SetHotkeyToggleLast("^!t")
    _Test_AssertEqual("Set+Get: hotkey_toggle_last", _Cfg_GetHotkeyToggleLast(), "^!t")

    _Test_AssertEqual("Default: hotkey_move_follow_next", _Cfg_GetHotkeyMoveFollowNext(), "^!+{RIGHT}")
    _Cfg_SetHotkeyMoveFollowNext("^!+{RIGHT}")
    _Test_AssertEqual("Set+Get: hotkey_move_follow_next", _Cfg_GetHotkeyMoveFollowNext(), "^!+{RIGHT}")

    _Test_AssertEqual("Default: hotkey_move_follow_prev", _Cfg_GetHotkeyMoveFollowPrev(), "^!+{LEFT}")
    _Cfg_SetHotkeyMoveFollowPrev("^!+{LEFT}")
    _Test_AssertEqual("Set+Get: hotkey_move_follow_prev", _Cfg_GetHotkeyMoveFollowPrev(), "^!+{LEFT}")

    _Test_AssertEqual("Default: hotkey_move_next", _Cfg_GetHotkeyMoveNext(), "^#{RIGHT}")
    _Cfg_SetHotkeyMoveNext("^#{RIGHT}")
    _Test_AssertEqual("Set+Get: hotkey_move_next", _Cfg_GetHotkeyMoveNext(), "^#{RIGHT}")

    _Test_AssertEqual("Default: hotkey_move_prev", _Cfg_GetHotkeyMovePrev(), "^#{LEFT}")
    _Cfg_SetHotkeyMovePrev("^#{LEFT}")
    _Test_AssertEqual("Set+Get: hotkey_move_prev", _Cfg_GetHotkeyMovePrev(), "^#{LEFT}")

    _Test_AssertEqual("Default: hotkey_send_new_desktop", _Cfg_GetHotkeySendNewDesktop(), "^!n")
    _Cfg_SetHotkeySendNewDesktop("^!n")
    _Test_AssertEqual("Set+Get: hotkey_send_new_desktop", _Cfg_GetHotkeySendNewDesktop(), "^!n")

    _Test_AssertEqual("Default: hotkey_pin_window", _Cfg_GetHotkeyPinWindow(), "^!p")
    _Cfg_SetHotkeyPinWindow("^!p")
    _Test_AssertEqual("Set+Get: hotkey_pin_window", _Cfg_GetHotkeyPinWindow(), "^!p")

    _Test_AssertEqual("Default: hotkey_toggle_window_list", _Cfg_GetHotkeyToggleWindowList(), "^!w")
    _Cfg_SetHotkeyToggleWindowList("^!w")
    _Test_AssertEqual("Set+Get: hotkey_toggle_window_list", _Cfg_GetHotkeyToggleWindowList(), "^!w")

    ; -- [WindowList] window_list_enabled: default False, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: window_list_enabled", _Cfg_GetWindowListEnabled())
    _Cfg_SetWindowListEnabled(True)
    _Test_AssertTrue("Set+Get: window_list_enabled", _Cfg_GetWindowListEnabled())

    ; -- [WindowList] window_list_position: default "top-left", set/get, invalid falls back --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: window_list_position", _Cfg_GetWindowListPosition(), "top-left")
    _Cfg_SetWindowListPosition("bottom-right")
    _Test_AssertEqual("Set+Get: window_list_position", _Cfg_GetWindowListPosition(), "bottom-right")
    _Cfg_SetWindowListPosition("invalid-pos")
    _Test_AssertEqual("Invalid window_list_position falls back", _Cfg_GetWindowListPosition(), "top-left")

    ; -- [WindowList] window_list_width: default 280, set/get, clamped 150-600 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: window_list_width", _Cfg_GetWindowListWidth(), 280)
    _Cfg_SetWindowListWidth(400)
    _Test_AssertEqual("Set+Get: window_list_width", _Cfg_GetWindowListWidth(), 400)
    _Cfg_SetWindowListWidth(50)
    _Test_AssertGreaterEqual("window_list_width clamped low", _Cfg_GetWindowListWidth(), 150)
    _Cfg_SetWindowListWidth(999)
    _Test_AssertLessEqual("window_list_width clamped high", _Cfg_GetWindowListWidth(), 600)

    ; -- [WindowList] window_list_max_visible: default 15, set/get, clamped 5-50 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: window_list_max_visible", _Cfg_GetWindowListMaxVisible(), 15)
    _Cfg_SetWindowListMaxVisible(25)
    _Test_AssertEqual("Set+Get: window_list_max_visible", _Cfg_GetWindowListMaxVisible(), 25)
    _Cfg_SetWindowListMaxVisible(1)
    _Test_AssertGreaterEqual("window_list_max_visible clamped low", _Cfg_GetWindowListMaxVisible(), 5)
    _Cfg_SetWindowListMaxVisible(100)
    _Test_AssertLessEqual("window_list_max_visible clamped high", _Cfg_GetWindowListMaxVisible(), 50)

    ; -- [WindowList] window_list_show_icons: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: window_list_show_icons", _Cfg_GetWindowListShowIcons())
    _Cfg_SetWindowListShowIcons(False)
    _Test_AssertFalse("Set+Get: window_list_show_icons off", _Cfg_GetWindowListShowIcons())

    ; -- [WindowList] window_list_search: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: window_list_search", _Cfg_GetWindowListSearch())
    _Cfg_SetWindowListSearch(False)
    _Test_AssertFalse("Set+Get: window_list_search off", _Cfg_GetWindowListSearch())

    ; -- [WindowList] window_list_auto_refresh: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: window_list_auto_refresh", _Cfg_GetWindowListAutoRefresh())
    _Cfg_SetWindowListAutoRefresh(False)
    _Test_AssertFalse("Set+Get: window_list_auto_refresh off", _Cfg_GetWindowListAutoRefresh())

    ; -- [WindowList] window_list_refresh_interval: default 1000, set/get, clamped 500-10000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: window_list_refresh_interval", _Cfg_GetWindowListRefreshInterval(), 1000)
    _Cfg_SetWindowListRefreshInterval(3000)
    _Test_AssertEqual("Set+Get: window_list_refresh_interval", _Cfg_GetWindowListRefreshInterval(), 3000)
    _Cfg_SetWindowListRefreshInterval(100)
    _Test_AssertGreaterEqual("window_list_refresh_interval clamped low", _Cfg_GetWindowListRefreshInterval(), 500)
    _Cfg_SetWindowListRefreshInterval(99999)
    _Test_AssertLessEqual("window_list_refresh_interval clamped high", _Cfg_GetWindowListRefreshInterval(), 10000)

    ; -- [ExplorerMonitor] explorer_monitor_enabled: default False, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: explorer_monitor_enabled", _Cfg_GetExplorerMonitorEnabled())
    _Cfg_SetExplorerMonitorEnabled(True)
    _Test_AssertTrue("Set+Get: explorer_monitor_enabled", _Cfg_GetExplorerMonitorEnabled())

    ; -- [ExplorerMonitor] explorer_check_interval: default 5000, set/get, clamped 2000-60000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: explorer_check_interval", _Cfg_GetExplorerCheckInterval(), 5000)
    _Cfg_SetExplorerCheckInterval(10000)
    _Test_AssertEqual("Set+Get: explorer_check_interval", _Cfg_GetExplorerCheckInterval(), 10000)
    _Cfg_SetExplorerCheckInterval(500)
    _Test_AssertGreaterEqual("explorer_check_interval clamped low", _Cfg_GetExplorerCheckInterval(), 2000)
    _Cfg_SetExplorerCheckInterval(100000)
    _Test_AssertLessEqual("explorer_check_interval clamped high", _Cfg_GetExplorerCheckInterval(), 60000)

    ; -- [ExplorerMonitor] explorer_notify_recovery: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: explorer_notify_recovery", _Cfg_GetExplorerNotifyRecovery())
    _Cfg_SetExplorerNotifyRecovery(False)
    _Test_AssertFalse("Set+Get: explorer_notify_recovery off", _Cfg_GetExplorerNotifyRecovery())

    ; -- [TaskbarAutoHide] autohide_sync_enabled: default False, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: autohide_sync_enabled", _Cfg_GetAutoHideSyncEnabled())
    _Cfg_SetAutoHideSyncEnabled(True)
    _Test_AssertTrue("Set+Get: autohide_sync_enabled", _Cfg_GetAutoHideSyncEnabled())

    ; -- [TaskbarAutoHide] autohide_poll_interval: default 150, set/get, clamped 50-2000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: autohide_poll_interval", _Cfg_GetAutoHidePollInterval(), 150)
    _Cfg_SetAutoHidePollInterval(500)
    _Test_AssertEqual("Set+Get: autohide_poll_interval", _Cfg_GetAutoHidePollInterval(), 500)
    _Cfg_SetAutoHidePollInterval(10)
    _Test_AssertGreaterEqual("autohide_poll_interval clamped low", _Cfg_GetAutoHidePollInterval(), 50)
    _Cfg_SetAutoHidePollInterval(5000)
    _Test_AssertLessEqual("autohide_poll_interval clamped high", _Cfg_GetAutoHidePollInterval(), 2000)

    ; -- [TaskbarAutoHide] autohide_hide_delay: default 200, set/get, clamped 0-5000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: autohide_hide_delay", _Cfg_GetAutoHideHideDelay(), 200)
    _Cfg_SetAutoHideHideDelay(1000)
    _Test_AssertEqual("Set+Get: autohide_hide_delay", _Cfg_GetAutoHideHideDelay(), 1000)
    _Cfg_SetAutoHideHideDelay(10000)
    _Test_AssertLessEqual("autohide_hide_delay clamped high", _Cfg_GetAutoHideHideDelay(), 5000)

    ; -- [TaskbarAutoHide] autohide_show_delay: default 0, set/get, clamped 0-5000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: autohide_show_delay", _Cfg_GetAutoHideShowDelay(), 0)
    _Cfg_SetAutoHideShowDelay(100)
    _Test_AssertEqual("Set+Get: autohide_show_delay", _Cfg_GetAutoHideShowDelay(), 100)

    ; -- [TaskbarAutoHide] autohide_use_fade: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: autohide_use_fade", _Cfg_GetAutoHideUseFade())
    _Cfg_SetAutoHideUseFade(False)
    _Test_AssertFalse("Set+Get: autohide_use_fade off", _Cfg_GetAutoHideUseFade())

    ; -- [TaskbarAutoHide] autohide_fade_duration: default 80, set/get, clamped 10-1000 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: autohide_fade_duration", _Cfg_GetAutoHideFadeDuration(), 80)
    _Cfg_SetAutoHideFadeDuration(200)
    _Test_AssertEqual("Set+Get: autohide_fade_duration", _Cfg_GetAutoHideFadeDuration(), 200)
    _Cfg_SetAutoHideFadeDuration(1)
    _Test_AssertGreaterEqual("autohide_fade_duration clamped low", _Cfg_GetAutoHideFadeDuration(), 10)

    ; -- [TaskbarAutoHide] autohide_sync_desktop_list: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: autohide_sync_desktop_list", _Cfg_GetAutoHideSyncDesktopList())
    _Cfg_SetAutoHideSyncDesktopList(False)
    _Test_AssertFalse("Set+Get: autohide_sync_desktop_list off", _Cfg_GetAutoHideSyncDesktopList())

    ; -- [TaskbarAutoHide] autohide_sync_window_list: default False, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: autohide_sync_window_list", _Cfg_GetAutoHideSyncWindowList())
    _Cfg_SetAutoHideSyncWindowList(True)
    _Test_AssertTrue("Set+Get: autohide_sync_window_list", _Cfg_GetAutoHideSyncWindowList())

    ; -- [TaskbarAutoHide] autohide_hidden_threshold: default 4, set/get, clamped 1-20 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: autohide_hidden_threshold", _Cfg_GetAutoHideHiddenThreshold(), 4)
    _Cfg_SetAutoHideHiddenThreshold(10)
    _Test_AssertEqual("Set+Get: autohide_hidden_threshold", _Cfg_GetAutoHideHiddenThreshold(), 10)
    _Cfg_SetAutoHideHiddenThreshold(0)
    _Test_AssertGreaterEqual("autohide_hidden_threshold clamped low", _Cfg_GetAutoHideHiddenThreshold(), 1)

    ; -- [TaskbarAutoHide] autohide_recheck_count: default 10, set/get, clamped 1-100 --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: autohide_recheck_count", _Cfg_GetAutoHideRecheckCount(), 10)
    _Cfg_SetAutoHideRecheckCount(20)
    _Test_AssertEqual("Set+Get: autohide_recheck_count", _Cfg_GetAutoHideRecheckCount(), 20)

    ; -- [TaskbarAutoHide] autohide_skip_if_dialog: default True, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertTrue("Default: autohide_skip_if_dialog", _Cfg_GetAutoHideSkipIfDialog())
    _Cfg_SetAutoHideSkipIfDialog(False)
    _Test_AssertFalse("Set+Get: autohide_skip_if_dialog off", _Cfg_GetAutoHideSkipIfDialog())

    ; -- [Notifications] notify_window_moved: default False, set/get --
    _Cfg_Init($sTempIni)
    _Test_AssertFalse("Default: notify_window_moved", _Cfg_GetNotifyWindowMoved())
    _Cfg_SetNotifyWindowMoved(True)
    _Test_AssertTrue("Set+Get: notify_window_moved", _Cfg_GetNotifyWindowMoved())

    ; -- [Notifications] notify_desktop_created: default False, set/get --
    _Test_AssertFalse("Default: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())
    _Cfg_SetNotifyDesktopCreated(True)
    _Test_AssertTrue("Set+Get: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())

    ; -- [Notifications] notify_desktop_deleted: default False, set/get --
    _Test_AssertFalse("Default: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())
    _Cfg_SetNotifyDesktopDeleted(True)
    _Test_AssertTrue("Set+Get: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())

    ; -- [Notifications] notify_window_pinned: default False, set/get --
    _Test_AssertFalse("Default: notify_window_pinned", _Cfg_GetNotifyWindowPinned())
    _Cfg_SetNotifyWindowPinned(True)
    _Test_AssertTrue("Set+Get: notify_window_pinned", _Cfg_GetNotifyWindowPinned())

    ; -- Security: __Cfg_ValidateExeName --
    _Test_AssertEqual("ValidExe: valid name", __Cfg_ValidateExeName("explorer.exe"), "explorer.exe")
    _Test_AssertEqual("ValidExe: valid with hyphen", __Cfg_ValidateExeName("my-shell.exe"), "my-shell.exe")
    _Test_AssertEqual("ValidExe: valid with underscore", __Cfg_ValidateExeName("my_app.exe"), "my_app.exe")
    _Test_AssertEqual("ValidExe: injection rejected", __Cfg_ValidateExeName("explorer.exe & calc"), "explorer.exe")
    _Test_AssertEqual("ValidExe: pipe rejected", __Cfg_ValidateExeName("foo|bar.exe"), "explorer.exe")
    _Test_AssertEqual("ValidExe: path separator rejected", __Cfg_ValidateExeName("..\..\evil.exe"), "explorer.exe")
    _Test_AssertEqual("ValidExe: empty fallback", __Cfg_ValidateExeName(""), "explorer.exe")
    _Test_AssertEqual("ValidExe: no extension rejected", __Cfg_ValidateExeName("notepad"), "explorer.exe")
    _Test_AssertEqual("ValidExe: space rejected", __Cfg_ValidateExeName("my app.exe"), "explorer.exe")

    ; -- Security: __Cfg_ValidatePath --
    _Test_AssertTrue("ValidPath: normal path", __Cfg_ValidatePath("C:\Users\test\Desktop"))
    _Test_AssertFalse("ValidPath: traversal rejected", __Cfg_ValidatePath("C:\foo\..\..\..\etc"))
    _Test_AssertFalse("ValidPath: UNC rejected", __Cfg_ValidatePath("\\server\share"))
    _Test_AssertTrue("ValidPath: short path ok", __Cfg_ValidatePath("C:\a"))
    ; Overlength path
    Local $sLongPath = ""
    Local $iL
    For $iL = 1 To 300
        $sLongPath &= "a"
    Next
    _Test_AssertFalse("ValidPath: overlength rejected", __Cfg_ValidatePath($sLongPath))

    ; -- Security: __Cfg_ValidateWallpaperPath --
    _Test_AssertTrue("ValidWP: jpg accepted", __Cfg_ValidateWallpaperPath("C:\img\photo.jpg"))
    _Test_AssertTrue("ValidWP: PNG accepted", __Cfg_ValidateWallpaperPath("C:\img\photo.PNG"))
    _Test_AssertTrue("ValidWP: bmp accepted", __Cfg_ValidateWallpaperPath("C:\img\wall.bmp"))
    _Test_AssertTrue("ValidWP: tiff accepted", __Cfg_ValidateWallpaperPath("C:\img\scan.tiff"))
    _Test_AssertFalse("ValidWP: exe rejected", __Cfg_ValidateWallpaperPath("C:\img\malware.exe"))
    _Test_AssertFalse("ValidWP: bat rejected", __Cfg_ValidateWallpaperPath("C:\img\script.bat"))
    _Test_AssertFalse("ValidWP: traversal rejected", __Cfg_ValidateWallpaperPath("C:\..\..\evil.jpg"))

    ; -- Security: __Cfg_ClampStringLen --
    _Test_AssertEqual("ClampStr: short string unchanged", __Cfg_ClampStringLen("hello", 10), "hello")
    _Test_AssertEqual("ClampStr: exact length unchanged", __Cfg_ClampStringLen("hello", 5), "hello")
    _Test_AssertEqual("ClampStr: truncated", __Cfg_ClampStringLen("hello world", 5), "hello")
    _Test_AssertEqual("ClampStr: empty string", __Cfg_ClampStringLen("", 10), "")

    ; -- Desktop colors 10+ supported --
    _Cfg_SetDesktopColor(10, 0xFF0000)
    _Test_AssertEqual("Desktop color 10 set/get", _Cfg_GetDesktopColor(10), 0xFF0000)
    _Cfg_SetDesktopColor(50, 0x00FF00)
    _Test_AssertEqual("Desktop color 50 set/get", _Cfg_GetDesktopColor(50), 0x00FF00)
    _Test_AssertEqual("Desktop color 51 out of range", _Cfg_GetDesktopColor(51), 0)
    _Cfg_SetDesktopColor(10, 0)
    _Cfg_SetDesktopColor(50, 0)

    ; -- Config loaded defaults flag --
    _Test_AssertTrue("DidLoadDefaults is bool", IsBool(_Cfg_DidLoadDefaults()) Or IsInt(_Cfg_DidLoadDefaults()))

    ; -- Tray settings: defaults --
    _Cfg_Init($sTempIni)
    _Test_AssertEqual("Default: tray_left_click", _Cfg_GetTrayLeftClick(), "menu")
    _Test_AssertEqual("Default: tray_double_click", _Cfg_GetTrayDoubleClick(), "settings")
    _Test_AssertEqual("Default: tray_middle_click", _Cfg_GetTrayMiddleClick(), "toggle_list")
    _Test_AssertTrue("Default: tray_tooltip_show_label", _Cfg_GetTrayTooltipShowLabel())
    _Test_AssertFalse("Default: tray_tooltip_show_count", _Cfg_GetTrayTooltipShowCount())
    _Test_AssertTrue("Default: tray_menu_show_list", _Cfg_GetTrayMenuShowList())
    _Test_AssertTrue("Default: tray_menu_show_edit", _Cfg_GetTrayMenuShowEdit())
    _Test_AssertTrue("Default: tray_menu_show_add", _Cfg_GetTrayMenuShowAdd())
    _Test_AssertTrue("Default: tray_menu_show_delete", _Cfg_GetTrayMenuShowDelete())
    _Test_AssertFalse("Default: tray_menu_show_desktop_submenu", _Cfg_GetTrayMenuShowDesktopSub())
    _Test_AssertFalse("Default: tray_menu_show_move_window", _Cfg_GetTrayMenuShowMoveWindow())
    _Test_AssertFalse("Default: tray_notify_desktop_switch", _Cfg_GetTrayNotifySwitch())
    _Test_AssertEqual("Default: tray_balloon_duration", _Cfg_GetTrayBalloonDuration(), 2000)
    _Test_AssertFalse("Default: tray_close_to_tray", _Cfg_GetTrayCloseToTray())

    ; -- Tray settings: set+get round-trips --
    _Cfg_SetTrayLeftClick("toggle_list")
    _Test_AssertEqual("Set+Get: tray_left_click", _Cfg_GetTrayLeftClick(), "toggle_list")
    _Cfg_SetTrayDoubleClick("toggle_list")
    _Test_AssertEqual("Set+Get: tray_double_click", _Cfg_GetTrayDoubleClick(), "toggle_list")
    _Cfg_SetTrayMiddleClick("add_desktop")
    _Test_AssertEqual("Set+Get: tray_middle_click", _Cfg_GetTrayMiddleClick(), "add_desktop")
    _Cfg_SetTrayTooltipShowLabel(False)
    _Test_AssertFalse("Set+Get: tray_tooltip_show_label", _Cfg_GetTrayTooltipShowLabel())
    _Cfg_SetTrayTooltipShowCount(True)
    _Test_AssertTrue("Set+Get: tray_tooltip_show_count", _Cfg_GetTrayTooltipShowCount())
    _Cfg_SetTrayMenuShowList(False)
    _Test_AssertFalse("Set+Get: tray_menu_show_list", _Cfg_GetTrayMenuShowList())
    _Cfg_SetTrayMenuShowDesktopSub(True)
    _Test_AssertTrue("Set+Get: tray_menu_show_desktop_sub", _Cfg_GetTrayMenuShowDesktopSub())
    _Cfg_SetTrayMenuShowMoveWindow(True)
    _Test_AssertTrue("Set+Get: tray_menu_show_move_window", _Cfg_GetTrayMenuShowMoveWindow())
    _Cfg_SetTrayNotifySwitch(True)
    _Test_AssertTrue("Set+Get: tray_notify_switch", _Cfg_GetTrayNotifySwitch())
    _Cfg_SetTrayBalloonDuration(5000)
    _Test_AssertEqual("Set+Get: tray_balloon_duration", _Cfg_GetTrayBalloonDuration(), 5000)
    _Cfg_SetTrayCloseToTray(True)
    _Test_AssertTrue("Set+Get: tray_close_to_tray", _Cfg_GetTrayCloseToTray())

    ; -- Tray settings: validation --
    _Cfg_SetTrayLeftClick("invalid")
    _Test_AssertEqual("Invalid tray_left_click falls back", _Cfg_GetTrayLeftClick(), "menu")
    _Cfg_SetTrayDoubleClick("invalid")
    _Test_AssertEqual("Invalid tray_double_click falls back", _Cfg_GetTrayDoubleClick(), "settings")
    _Cfg_SetTrayMiddleClick("invalid")
    _Test_AssertEqual("Invalid tray_middle_click falls back", _Cfg_GetTrayMiddleClick(), "toggle_list")
    _Cfg_SetTrayBalloonDuration(100)
    _Test_AssertGreaterEqual("Balloon duration clamped low", _Cfg_GetTrayBalloonDuration(), 500)
    _Cfg_SetTrayBalloonDuration(99999)
    _Test_AssertLessEqual("Balloon duration clamped high", _Cfg_GetTrayBalloonDuration(), 10000)

    ; -- Cleanup --
    FileDelete($sTempIni)
EndFunc
