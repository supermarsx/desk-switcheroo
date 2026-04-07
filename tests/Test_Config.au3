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
    _Test_AssertTrue("INI file created", FileExists($sTempIni))

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
    _Test_AssertEqual("Desktop color out of range", _Cfg_GetDesktopColor(0), 0xFFFFFF)
    _Test_AssertEqual("Desktop color out of range high", _Cfg_GetDesktopColor(10), 0xFFFFFF)
    _Test_AssertEqual("Hotkey desktop out of range", _Cfg_GetHotkeyDesktop(0), "")

    ; -- Hotkey clear --
    _Cfg_SetHotkeyNext("")
    _Test_AssertEqual("Hotkey cleared", _Cfg_GetHotkeyNext(), "")

    ; -- Desktop color defaults exist --
    _Cfg_Load()
    _Test_AssertNotEqual("Color 1 has default", _Cfg_GetDesktopColor(1), 0)
    _Test_AssertNotEqual("Color 2 has default", _Cfg_GetDesktopColor(2), 0)

    ; -- Cleanup --
    FileDelete($sTempIni)
EndFunc
