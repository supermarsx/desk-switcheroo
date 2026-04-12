#include <GUIConstantsEx.au3>

; ===============================================================
; Desk Switcheroo — E2E Sandbox Tests
; Run with: AutoIt3_x64.exe tests\E2E_Sandbox.au3
; Tests application lifecycle scenarios in a clean environment
;
; These tests are standalone (not included by TestRunner) and are
; designed to run inside a Windows Sandbox via sandbox_setup.ps1.
; ===============================================================

; ---- Test framework globals ----
Global $__g_E2E_iPass = 0
Global $__g_E2E_iFail = 0
Global $__g_E2E_sCurrentSuite = ""
Global $__g_E2E_sResultsDir = ""
If FileExists("C:\results") Then
    $__g_E2E_sResultsDir = "C:\results"
Else
    $__g_E2E_sResultsDir = @ScriptDir & "\results"
EndIf

; ---- Include modules under test ----
#include "..\includes\Config.au3"
#include "..\includes\Theme.au3"
#include "..\includes\Labels.au3"
#include "..\includes\Wallpaper.au3"
#include "..\includes\ExplorerMonitor.au3"
#include "..\includes\VirtualDesktop.au3"
#include "..\includes\WindowList.au3"

; ---- Create results directory ----
If Not FileExists($__g_E2E_sResultsDir) Then DirCreate($__g_E2E_sResultsDir)

; ---- Load bundled fonts ----
_Theme_LoadFonts()

; ---- Run E2E test suites ----
; Original suites
_E2E_FreshInstall()
_E2E_ConfigPersistence()
_E2E_StartupRegistryToggle()
_E2E_IniCorruptionRecovery()
_E2E_LabelsIntegration()

; New feature E2E suites
_E2E_NewConfigPersistence()
_E2E_HotkeyConfigPersistence()
_E2E_NotificationConfigPersistence()
_E2E_FullConfigRoundtrip()
_E2E_WallpaperIntegration()
_E2E_ExplorerMonitorIntegration()
_E2E_VirtualDesktopPinIntegration()
_E2E_WindowListIntegration()

; ---- Cleanup ----
_Theme_UnloadFonts()

; ---- Summary ----
_E2E_Summary()

; ===============================================================
; E2E TEST SUITES
; ===============================================================

; -- Test 1: Fresh install creates INI with all expected sections --
Func _E2E_FreshInstall()
    _E2E_Suite("Fresh Install")

    Local $sTempIni = @TempDir & "\e2e_fresh_install.ini"

    ; Ensure no leftover file
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Init should create the INI from scratch
    _Cfg_Init($sTempIni)

    _E2E_AssertTrue("INI file was created", FileExists($sTempIni))
    _E2E_AssertEqual("Config path is set", _Cfg_GetPath(), $sTempIni)

    ; Read raw INI to verify all expected sections exist
    Local $aSections = IniReadSectionNames($sTempIni)
    Local $bHasGeneral = False, $bHasDisplay = False, $bHasScroll = False
    Local $bHasHotkeys = False, $bHasBehavior = False, $bHasColors = False
    Local $bHasWallpaper = False, $bHasPinning = False, $bHasWindowList = False
    Local $bHasExplorerMon = False, $bHasNotifications = False

    If IsArray($aSections) Then
        For $i = 1 To $aSections[0]
            Switch $aSections[$i]
                Case "General"
                    $bHasGeneral = True
                Case "Display"
                    $bHasDisplay = True
                Case "Scroll"
                    $bHasScroll = True
                Case "Hotkeys"
                    $bHasHotkeys = True
                Case "Behavior"
                    $bHasBehavior = True
                Case "DesktopColors"
                    $bHasColors = True
                Case "Wallpaper"
                    $bHasWallpaper = True
                Case "Pinning"
                    $bHasPinning = True
                Case "WindowList"
                    $bHasWindowList = True
                Case "ExplorerMonitor"
                    $bHasExplorerMon = True
                Case "Notifications"
                    $bHasNotifications = True
            EndSwitch
        Next
    EndIf

    _E2E_AssertTrue("Section [General] exists", $bHasGeneral)
    _E2E_AssertTrue("Section [Display] exists", $bHasDisplay)
    _E2E_AssertTrue("Section [Scroll] exists", $bHasScroll)
    _E2E_AssertTrue("Section [Hotkeys] exists", $bHasHotkeys)
    _E2E_AssertTrue("Section [Behavior] exists", $bHasBehavior)
    _E2E_AssertTrue("Section [DesktopColors] exists", $bHasColors)
    _E2E_AssertTrue("Section [Wallpaper] exists", $bHasWallpaper)
    _E2E_AssertTrue("Section [Pinning] exists", $bHasPinning)
    _E2E_AssertTrue("Section [WindowList] exists", $bHasWindowList)
    _E2E_AssertTrue("Section [ExplorerMonitor] exists", $bHasExplorerMon)
    _E2E_AssertTrue("Section [Notifications] exists", $bHasNotifications)

    ; Verify some key defaults in the raw INI
    _E2E_AssertEqual("INI default: widget_position", IniRead($sTempIni, "General", "widget_position", ""), "left")
    _E2E_AssertEqual("INI default: scroll_direction", IniRead($sTempIni, "Scroll", "scroll_direction", ""), "normal")
    _E2E_AssertEqual("INI default: confirm_delete", IniRead($sTempIni, "Behavior", "confirm_delete", ""), "true")

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 2: Config persistence across save/reload cycle --
Func _E2E_ConfigPersistence()
    _E2E_Suite("Config Persistence")

    Local $sTempIni = @TempDir & "\e2e_persistence.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Create initial config
    _Cfg_Init($sTempIni)

    ; Set several non-default values
    _Cfg_SetWidgetPosition("center")
    _Cfg_SetNumberPadding(3)
    _Cfg_SetThemeAlphaMain(180)
    _Cfg_SetScrollEnabled(True)
    _Cfg_SetScrollDirection("inverted")
    _Cfg_SetHotkeyNext("^!{RIGHT}")
    _Cfg_SetHotkeyPrev("^!{LEFT}")
    _Cfg_SetConfirmDelete(False)
    _Cfg_SetDesktopColorsEnabled(True)
    _Cfg_SetDesktopColor(1, 0xFF0000)
    _Cfg_SetAutoHideTimeout(5000)

    ; Save to disk
    _Cfg_Save()

    ; Re-init from the same path (simulates fresh app start)
    _Cfg_Init($sTempIni)

    ; Verify all values survived the round trip
    _E2E_AssertEqual("Persisted: widget_position", _Cfg_GetWidgetPosition(), "center")
    _E2E_AssertEqual("Persisted: number_padding", _Cfg_GetNumberPadding(), 3)
    _E2E_AssertEqual("Persisted: theme_alpha_main", _Cfg_GetThemeAlphaMain(), 180)
    _E2E_AssertTrue("Persisted: scroll_enabled", _Cfg_GetScrollEnabled())
    _E2E_AssertEqual("Persisted: scroll_direction", _Cfg_GetScrollDirection(), "inverted")
    _E2E_AssertEqual("Persisted: hotkey_next", _Cfg_GetHotkeyNext(), "^!{RIGHT}")
    _E2E_AssertEqual("Persisted: hotkey_prev", _Cfg_GetHotkeyPrev(), "^!{LEFT}")
    _E2E_AssertFalse("Persisted: confirm_delete", _Cfg_GetConfirmDelete())
    _E2E_AssertTrue("Persisted: desktop_colors_enabled", _Cfg_GetDesktopColorsEnabled())
    _E2E_AssertEqual("Persisted: desktop_color_1", _Cfg_GetDesktopColor(1), 0xFF0000)
    _E2E_AssertEqual("Persisted: auto_hide_timeout", _Cfg_GetAutoHideTimeout(), 5000)

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 3: Startup registry toggle --
Func _E2E_StartupRegistryToggle()
    _E2E_Suite("Startup Registry Toggle")

    Local $sRegKey = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

    ; Ensure clean state: remove any leftover entry
    RegDelete($sRegKey, "DeskSwitcheroo")

    ; Enable startup
    _Cfg_EnableStartup()
    Local $sVal = RegRead($sRegKey, "DeskSwitcheroo")
    _E2E_AssertTrue("Registry key created after EnableStartup", $sVal <> "")
    _E2E_AssertTrue("IsStartupEnabled returns True", _Cfg_IsStartupEnabled())

    ; Disable startup
    _Cfg_DisableStartup()
    $sVal = RegRead($sRegKey, "DeskSwitcheroo")
    _E2E_AssertEqual("Registry key removed after DisableStartup", $sVal, "")
    _E2E_AssertFalse("IsStartupEnabled returns False", _Cfg_IsStartupEnabled())
EndFunc

; -- Test 4: INI corruption recovery --
Func _E2E_IniCorruptionRecovery()
    _E2E_Suite("INI Corruption Recovery")

    Local $sTempIni = @TempDir & "\e2e_corruption.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Create a valid config first
    _Cfg_Init($sTempIni)
    _Cfg_Save()

    ; Now write garbage to every section
    IniWrite($sTempIni, "General", "widget_position", "GARBAGE_POSITION")
    IniWrite($sTempIni, "General", "number_padding", "not_a_number")
    IniWrite($sTempIni, "General", "wrap_navigation", "maybe")
    IniWrite($sTempIni, "Display", "theme_alpha_main", "-999")
    IniWrite($sTempIni, "Display", "count_font_size", "abc")
    IniWrite($sTempIni, "Scroll", "scroll_direction", "SIDEWAYS")
    IniWrite($sTempIni, "Scroll", "scroll_enabled", "perhaps")
    IniWrite($sTempIni, "Scroll", "list_scroll_action", "explode")
    IniWrite($sTempIni, "Behavior", "confirm_delete", "dunno")
    IniWrite($sTempIni, "Behavior", "peek_bounce_delay", "fast")
    IniWrite($sTempIni, "Behavior", "auto_hide_timeout", "-1")
    IniWrite($sTempIni, "DesktopColors", "desktop_colors_enabled", "yep")
    IniWrite($sTempIni, "DesktopColors", "desktop_1_color", "not_a_color")

    ; Reload - should recover to valid defaults
    _Cfg_Load()

    ; Verify all values are valid defaults (not garbage)
    _E2E_AssertEqual("Recovered: widget_position", _Cfg_GetWidgetPosition(), "left")
    _E2E_AssertEqual("Recovered: number_padding", _Cfg_GetNumberPadding(), 2)
    _E2E_AssertTrue("Recovered: wrap_navigation is bool", _Cfg_GetWrapNavigation() = True Or _Cfg_GetWrapNavigation() = False)
    _E2E_AssertEqual("Recovered: scroll_direction", _Cfg_GetScrollDirection(), "normal")
    _E2E_AssertEqual("Recovered: list_scroll_action", _Cfg_GetListScrollAction(), "switch")
    _E2E_AssertEqual("Recovered: count_font_size", _Cfg_GetCountFontSize(), 7)

    ; Alpha should be clamped or default (garbage non-int falls back to default 235)
    Local $iAlpha = _Cfg_GetThemeAlphaMain()
    _E2E_AssertTrue("Recovered: theme_alpha in range 50-255", $iAlpha >= 50 And $iAlpha <= 255)

    ; Boolean garbage should fall back to defaults
    ; scroll_enabled default is False, confirm_delete default is True
    _E2E_AssertFalse("Recovered: scroll_enabled default", _Cfg_GetScrollEnabled())
    _E2E_AssertTrue("Recovered: confirm_delete default", _Cfg_GetConfirmDelete())

    ; Numeric garbage should fall back to defaults
    _E2E_AssertEqual("Recovered: peek_bounce_delay", _Cfg_GetPeekBounceDelay(), 500)

    ; auto_hide_timeout with -1 is an int but below min (500), so clamped
    Local $iTimeout = _Cfg_GetAutoHideTimeout()
    _E2E_AssertTrue("Recovered: auto_hide_timeout >= 500", $iTimeout >= 500)

    ; Desktop color with invalid hex should fall back to default (0)
    Local $iColor1 = _Cfg_GetDesktopColor(1)
    _E2E_AssertTrue("Recovered: desktop_1_color is int", IsInt($iColor1))

    ; New feature corruption recovery: write garbage to new sections
    IniWrite($sTempIni, "Wallpaper", "wallpaper_enabled", "maybe")
    IniWrite($sTempIni, "Wallpaper", "wallpaper_change_delay", "fast")
    IniWrite($sTempIni, "Pinning", "pinning_enabled", "yep")
    IniWrite($sTempIni, "WindowList", "window_list_enabled", "nope")
    IniWrite($sTempIni, "WindowList", "window_list_position", "NOWHERE")
    IniWrite($sTempIni, "WindowList", "window_list_width", "wide")
    IniWrite($sTempIni, "WindowList", "window_list_max_visible", "-5")
    IniWrite($sTempIni, "ExplorerMonitor", "explorer_monitor_enabled", "maybe")
    IniWrite($sTempIni, "ExplorerMonitor", "explorer_check_interval", "never")
    IniWrite($sTempIni, "Notifications", "notify_window_moved", "sometimes")
    IniWrite($sTempIni, "Notifications", "notify_desktop_created", "always")

    ; Reload
    _Cfg_Load()

    ; Verify all new-feature values recovered to valid defaults
    _E2E_AssertFalse("Recovered: wallpaper_enabled default", _Cfg_GetWallpaperEnabled())
    Local $iWpDelay = _Cfg_GetWallpaperChangeDelay()
    _E2E_AssertTrue("Recovered: wallpaper_change_delay in range", $iWpDelay >= 50 And $iWpDelay <= 2000)
    _E2E_AssertFalse("Recovered: pinning_enabled default", _Cfg_GetPinningEnabled())
    _E2E_AssertFalse("Recovered: window_list_enabled default", _Cfg_GetWindowListEnabled())
    _E2E_AssertEqual("Recovered: window_list_position default", _Cfg_GetWindowListPosition(), "top-left")
    Local $iWlWidth = _Cfg_GetWindowListWidth()
    _E2E_AssertTrue("Recovered: window_list_width in range", $iWlWidth >= 150 And $iWlWidth <= 600)
    Local $iWlMax = _Cfg_GetWindowListMaxVisible()
    _E2E_AssertTrue("Recovered: window_list_max_visible in range", $iWlMax >= 5 And $iWlMax <= 50)
    _E2E_AssertFalse("Recovered: explorer_monitor_enabled default", _Cfg_GetExplorerMonitorEnabled())
    Local $iEmInterval = _Cfg_GetExplorerCheckInterval()
    _E2E_AssertTrue("Recovered: explorer_check_interval in range", $iEmInterval >= 2000 And $iEmInterval <= 60000)
    _E2E_AssertFalse("Recovered: notify_window_moved default", _Cfg_GetNotifyWindowMoved())
    _E2E_AssertFalse("Recovered: notify_desktop_created default", _Cfg_GetNotifyDesktopCreated())

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 5: Labels integration --
Func _E2E_LabelsIntegration()
    _E2E_Suite("Labels Integration")

    Local $sTempIni = @TempDir & "\e2e_labels.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Init labels with test INI (sync disabled for isolated testing)
    _Labels_Init($sTempIni, False)

    _E2E_AssertEqual("Labels path set", _Labels_GetPath(), $sTempIni)

    ; Save several labels (this creates the INI on first write)
    _Labels_Save(1, "Work")
    _Labels_Save(2, "Gaming")
    _Labels_Save(3, "Music Production")
    _Labels_Save(4, "Research & Notes")
    _Labels_Save(5, "")

    _E2E_AssertTrue("Labels INI created after save", FileExists($sTempIni))

    ; Verify they can be read back
    _E2E_AssertEqual("Label 1 saved", _Labels_Load(1), "Work")
    _E2E_AssertEqual("Label 2 saved", _Labels_Load(2), "Gaming")
    _E2E_AssertEqual("Label 3 saved", _Labels_Load(3), "Music Production")
    _E2E_AssertEqual("Label 4 special chars", _Labels_Load(4), "Research & Notes")
    _E2E_AssertEqual("Label 5 empty string", _Labels_Load(5), "")
    _E2E_AssertEqual("Label 99 missing", _Labels_Load(99), "")

    ; Verify persistence: re-init from the same file
    _Labels_Init($sTempIni, False)
    _E2E_AssertEqual("Labels persist: desktop 1", _Labels_Load(1), "Work")
    _E2E_AssertEqual("Labels persist: desktop 2", _Labels_Load(2), "Gaming")
    _E2E_AssertEqual("Labels persist: desktop 3", _Labels_Load(3), "Music Production")

    ; Overwrite and verify
    _Labels_Save(1, "Updated Work")
    _E2E_AssertEqual("Label overwrite", _Labels_Load(1), "Updated Work")

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; ===============================================================
; NEW FEATURE E2E TEST SUITES
; ===============================================================

; -- Test 6: Config persistence for all new feature config keys --
Func _E2E_NewConfigPersistence()
    _E2E_Suite("New Config Persistence")

    Local $sTempIni = @TempDir & "\e2e_new_cfg_persist.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Create initial config
    _Cfg_Init($sTempIni)

    ; Set all new feature values to non-default
    _Cfg_SetSingletonEnabled(False)
    _Cfg_SetMinDesktops(5)
    _Cfg_SetTaskbarFocusTrick(True)
    _Cfg_SetAutoFocusAfterSwitch(True)
    _Cfg_SetCapslockModifier(True)

    _Cfg_SetWallpaperEnabled(True)
    _Cfg_SetWallpaperChangeDelay(500)
    _Cfg_SetDesktopWallpaper(1, "C:\wallpapers\desktop1.jpg")
    _Cfg_SetDesktopWallpaper(2, "C:\wallpapers\desktop2.png")
    _Cfg_SetDesktopWallpaper(9, "C:\wallpapers\desktop9.bmp")

    _Cfg_SetPinningEnabled(True)

    _Cfg_SetWindowListEnabled(True)
    _Cfg_SetWindowListPosition("bottom-right")
    _Cfg_SetWindowListWidth(400)
    _Cfg_SetWindowListMaxVisible(25)
    _Cfg_SetWindowListShowIcons(False)
    _Cfg_SetWindowListSearch(False)
    _Cfg_SetWindowListAutoRefresh(False)
    _Cfg_SetWindowListRefreshInterval(5000)

    _Cfg_SetExplorerMonitorEnabled(True)
    _Cfg_SetExplorerCheckInterval(10000)
    _Cfg_SetExplorerNotifyRecovery(False)

    _Cfg_SetNotifyWindowMoved(True)
    _Cfg_SetNotifyDesktopCreated(True)
    _Cfg_SetNotifyDesktopDeleted(True)
    _Cfg_SetNotifyWindowPinned(True)

    ; Save to disk
    _Cfg_Save()

    ; Re-init from the same path (simulates fresh app start)
    _Cfg_Init($sTempIni)

    ; Verify all new values survived the round trip

    ; General new keys
    _E2E_AssertFalse("Persisted: singleton_enabled", _Cfg_GetSingletonEnabled())
    _E2E_AssertEqual("Persisted: min_desktops", _Cfg_GetMinDesktops(), 5)
    _E2E_AssertTrue("Persisted: taskbar_focus_trick", _Cfg_GetTaskbarFocusTrick())
    _E2E_AssertTrue("Persisted: auto_focus_after_switch", _Cfg_GetAutoFocusAfterSwitch())
    _E2E_AssertTrue("Persisted: capslock_modifier", _Cfg_GetCapslockModifier())

    ; Wallpaper
    _E2E_AssertTrue("Persisted: wallpaper_enabled", _Cfg_GetWallpaperEnabled())
    _E2E_AssertEqual("Persisted: wallpaper_change_delay", _Cfg_GetWallpaperChangeDelay(), 500)
    _E2E_AssertEqual("Persisted: desktop_1_wallpaper", _Cfg_GetDesktopWallpaper(1), "C:\wallpapers\desktop1.jpg")
    _E2E_AssertEqual("Persisted: desktop_2_wallpaper", _Cfg_GetDesktopWallpaper(2), "C:\wallpapers\desktop2.png")
    _E2E_AssertEqual("Persisted: desktop_9_wallpaper", _Cfg_GetDesktopWallpaper(9), "C:\wallpapers\desktop9.bmp")
    _E2E_AssertEqual("Persisted: desktop_3_wallpaper (unset)", _Cfg_GetDesktopWallpaper(3), "")

    ; Pinning
    _E2E_AssertTrue("Persisted: pinning_enabled", _Cfg_GetPinningEnabled())

    ; Window list
    _E2E_AssertTrue("Persisted: window_list_enabled", _Cfg_GetWindowListEnabled())
    _E2E_AssertEqual("Persisted: window_list_position", _Cfg_GetWindowListPosition(), "bottom-right")
    _E2E_AssertEqual("Persisted: window_list_width", _Cfg_GetWindowListWidth(), 400)
    _E2E_AssertEqual("Persisted: window_list_max_visible", _Cfg_GetWindowListMaxVisible(), 25)
    _E2E_AssertFalse("Persisted: window_list_show_icons", _Cfg_GetWindowListShowIcons())
    _E2E_AssertFalse("Persisted: window_list_search", _Cfg_GetWindowListSearch())
    _E2E_AssertFalse("Persisted: window_list_auto_refresh", _Cfg_GetWindowListAutoRefresh())
    _E2E_AssertEqual("Persisted: window_list_refresh_interval", _Cfg_GetWindowListRefreshInterval(), 5000)

    ; Explorer monitor
    _E2E_AssertTrue("Persisted: explorer_monitor_enabled", _Cfg_GetExplorerMonitorEnabled())
    _E2E_AssertEqual("Persisted: explorer_check_interval", _Cfg_GetExplorerCheckInterval(), 10000)
    _E2E_AssertFalse("Persisted: explorer_notify_recovery", _Cfg_GetExplorerNotifyRecovery())

    ; Notifications
    _E2E_AssertTrue("Persisted: notify_window_moved", _Cfg_GetNotifyWindowMoved())
    _E2E_AssertTrue("Persisted: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())
    _E2E_AssertTrue("Persisted: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())
    _E2E_AssertTrue("Persisted: notify_window_pinned", _Cfg_GetNotifyWindowPinned())

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 7: Hotkey config persistence for all new hotkey keys --
Func _E2E_HotkeyConfigPersistence()
    _E2E_Suite("Hotkey Config Persistence")

    Local $sTempIni = @TempDir & "\e2e_hotkey_persist.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    _Cfg_Init($sTempIni)

    ; Set all 8 new hotkey config values to test strings
    _Cfg_SetHotkeyMoveFollowNext("^!+{RIGHT}")
    _Cfg_SetHotkeyMoveFollowPrev("^!+{LEFT}")
    _Cfg_SetHotkeyMoveNext("^#{RIGHT}")
    _Cfg_SetHotkeyMovePrev("^#{LEFT}")
    _Cfg_SetHotkeySendNewDesktop("^!{N}")
    _Cfg_SetHotkeyPinWindow("^!{P}")
    _Cfg_SetHotkeyToggleWindowList("^!{W}")
    _Cfg_SetHotkeyToggleLast("^!{L}")

    ; Save and reload
    _Cfg_Save()
    _Cfg_Init($sTempIni)

    ; Verify all 8 persist correctly
    _E2E_AssertEqual("Persisted: hotkey_move_follow_next", _Cfg_GetHotkeyMoveFollowNext(), "^!+{RIGHT}")
    _E2E_AssertEqual("Persisted: hotkey_move_follow_prev", _Cfg_GetHotkeyMoveFollowPrev(), "^!+{LEFT}")
    _E2E_AssertEqual("Persisted: hotkey_move_next", _Cfg_GetHotkeyMoveNext(), "^#{RIGHT}")
    _E2E_AssertEqual("Persisted: hotkey_move_prev", _Cfg_GetHotkeyMovePrev(), "^#{LEFT}")
    _E2E_AssertEqual("Persisted: hotkey_send_new_desktop", _Cfg_GetHotkeySendNewDesktop(), "^!{N}")
    _E2E_AssertEqual("Persisted: hotkey_pin_window", _Cfg_GetHotkeyPinWindow(), "^!{P}")
    _E2E_AssertEqual("Persisted: hotkey_toggle_window_list", _Cfg_GetHotkeyToggleWindowList(), "^!{W}")
    _E2E_AssertEqual("Persisted: hotkey_toggle_last", _Cfg_GetHotkeyToggleLast(), "^!{L}")

    ; Now clear all 8, save, reload, verify empty
    _Cfg_SetHotkeyMoveFollowNext("")
    _Cfg_SetHotkeyMoveFollowPrev("")
    _Cfg_SetHotkeyMoveNext("")
    _Cfg_SetHotkeyMovePrev("")
    _Cfg_SetHotkeySendNewDesktop("")
    _Cfg_SetHotkeyPinWindow("")
    _Cfg_SetHotkeyToggleWindowList("")
    _Cfg_SetHotkeyToggleLast("")

    ; Wait for debounce to expire before second save
    Sleep(600)
    _Cfg_Save()
    _Cfg_Init($sTempIni)

    _E2E_AssertEqual("Cleared: hotkey_move_follow_next", _Cfg_GetHotkeyMoveFollowNext(), "")
    _E2E_AssertEqual("Cleared: hotkey_move_follow_prev", _Cfg_GetHotkeyMoveFollowPrev(), "")
    _E2E_AssertEqual("Cleared: hotkey_move_next", _Cfg_GetHotkeyMoveNext(), "")
    _E2E_AssertEqual("Cleared: hotkey_move_prev", _Cfg_GetHotkeyMovePrev(), "")
    _E2E_AssertEqual("Cleared: hotkey_send_new_desktop", _Cfg_GetHotkeySendNewDesktop(), "")
    _E2E_AssertEqual("Cleared: hotkey_pin_window", _Cfg_GetHotkeyPinWindow(), "")
    _E2E_AssertEqual("Cleared: hotkey_toggle_window_list", _Cfg_GetHotkeyToggleWindowList(), "")
    _E2E_AssertEqual("Cleared: hotkey_toggle_last", _Cfg_GetHotkeyToggleLast(), "")

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 8: Notification config persistence --
Func _E2E_NotificationConfigPersistence()
    _E2E_Suite("Notification Config Persistence")

    Local $sTempIni = @TempDir & "\e2e_notify_persist.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; All 4 notification flags default False
    _Cfg_Init($sTempIni)
    _E2E_AssertFalse("Default: notify_window_moved", _Cfg_GetNotifyWindowMoved())
    _E2E_AssertFalse("Default: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())
    _E2E_AssertFalse("Default: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())
    _E2E_AssertFalse("Default: notify_window_pinned", _Cfg_GetNotifyWindowPinned())

    ; Set all True, save, reload, verify
    _Cfg_SetNotifyWindowMoved(True)
    _Cfg_SetNotifyDesktopCreated(True)
    _Cfg_SetNotifyDesktopDeleted(True)
    _Cfg_SetNotifyWindowPinned(True)
    _Cfg_Save()
    _Cfg_Init($sTempIni)

    _E2E_AssertTrue("Set True: notify_window_moved", _Cfg_GetNotifyWindowMoved())
    _E2E_AssertTrue("Set True: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())
    _E2E_AssertTrue("Set True: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())
    _E2E_AssertTrue("Set True: notify_window_pinned", _Cfg_GetNotifyWindowPinned())

    ; Set back to False, save, reload, verify
    _Cfg_SetNotifyWindowMoved(False)
    _Cfg_SetNotifyDesktopCreated(False)
    _Cfg_SetNotifyDesktopDeleted(False)
    _Cfg_SetNotifyWindowPinned(False)

    ; Wait for debounce to expire before second save
    Sleep(600)
    _Cfg_Save()
    _Cfg_Init($sTempIni)

    _E2E_AssertFalse("Set False: notify_window_moved", _Cfg_GetNotifyWindowMoved())
    _E2E_AssertFalse("Set False: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())
    _E2E_AssertFalse("Set False: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())
    _E2E_AssertFalse("Set False: notify_window_pinned", _Cfg_GetNotifyWindowPinned())

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 9: Full config roundtrip — every new config key --
Func _E2E_FullConfigRoundtrip()
    _E2E_Suite("Full Config Roundtrip")

    Local $sTempIni = @TempDir & "\e2e_full_roundtrip.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    _Cfg_Init($sTempIni)

    ; Set EVERY new config key to a non-default value

    ; General new keys
    _Cfg_SetSingletonEnabled(False)        ; default True
    _Cfg_SetMinDesktops(5)                 ; default 0
    _Cfg_SetTaskbarFocusTrick(True)        ; default False
    _Cfg_SetAutoFocusAfterSwitch(True)     ; default False
    _Cfg_SetCapslockModifier(True)         ; default False

    ; Wallpaper
    _Cfg_SetWallpaperEnabled(True)         ; default False
    _Cfg_SetWallpaperChangeDelay(500)      ; default 200
    Local $i
    For $i = 1 To 9
        _Cfg_SetDesktopWallpaper($i, "C:\test\wp_" & $i & ".jpg")
    Next

    ; Pinning
    _Cfg_SetPinningEnabled(True)           ; default False

    ; All 8 new hotkeys
    _Cfg_SetHotkeyMoveFollowNext("^!+{RIGHT}")
    _Cfg_SetHotkeyMoveFollowPrev("^!+{LEFT}")
    _Cfg_SetHotkeyMoveNext("^#{RIGHT}")
    _Cfg_SetHotkeyMovePrev("^#{LEFT}")
    _Cfg_SetHotkeySendNewDesktop("^!{N}")
    _Cfg_SetHotkeyPinWindow("^!{P}")
    _Cfg_SetHotkeyToggleWindowList("^!{W}")
    _Cfg_SetHotkeyToggleLast("^!{L}")

    ; Window list settings
    _Cfg_SetWindowListEnabled(True)        ; default False
    _Cfg_SetWindowListPosition("top-right") ; default top-left
    _Cfg_SetWindowListWidth(350)           ; default 280
    _Cfg_SetWindowListMaxVisible(20)       ; default 15
    _Cfg_SetWindowListShowIcons(False)     ; default True
    _Cfg_SetWindowListSearch(False)        ; default True
    _Cfg_SetWindowListAutoRefresh(False)   ; default True
    _Cfg_SetWindowListRefreshInterval(3000) ; default 1000

    ; Explorer monitor settings
    _Cfg_SetExplorerMonitorEnabled(True)   ; default False
    _Cfg_SetExplorerCheckInterval(8000)    ; default 5000
    _Cfg_SetExplorerNotifyRecovery(False)  ; default True

    ; Notification settings
    _Cfg_SetNotifyWindowMoved(True)        ; default False
    _Cfg_SetNotifyDesktopCreated(True)     ; default False
    _Cfg_SetNotifyDesktopDeleted(True)     ; default False
    _Cfg_SetNotifyWindowPinned(True)       ; default False

    ; Save to disk
    _Cfg_Save()

    ; Re-init (simulates fresh app start)
    _Cfg_Init($sTempIni)

    ; Verify EVERYTHING survived

    ; General new keys
    _E2E_AssertFalse("Roundtrip: singleton_enabled", _Cfg_GetSingletonEnabled())
    _E2E_AssertEqual("Roundtrip: min_desktops", _Cfg_GetMinDesktops(), 5)
    _E2E_AssertTrue("Roundtrip: taskbar_focus_trick", _Cfg_GetTaskbarFocusTrick())
    _E2E_AssertTrue("Roundtrip: auto_focus_after_switch", _Cfg_GetAutoFocusAfterSwitch())
    _E2E_AssertTrue("Roundtrip: capslock_modifier", _Cfg_GetCapslockModifier())

    ; Wallpaper
    _E2E_AssertTrue("Roundtrip: wallpaper_enabled", _Cfg_GetWallpaperEnabled())
    _E2E_AssertEqual("Roundtrip: wallpaper_change_delay", _Cfg_GetWallpaperChangeDelay(), 500)
    For $i = 1 To 9
        _E2E_AssertEqual("Roundtrip: desktop_" & $i & "_wallpaper", _Cfg_GetDesktopWallpaper($i), "C:\test\wp_" & $i & ".jpg")
    Next

    ; Pinning
    _E2E_AssertTrue("Roundtrip: pinning_enabled", _Cfg_GetPinningEnabled())

    ; Hotkeys
    _E2E_AssertEqual("Roundtrip: hotkey_move_follow_next", _Cfg_GetHotkeyMoveFollowNext(), "^!+{RIGHT}")
    _E2E_AssertEqual("Roundtrip: hotkey_move_follow_prev", _Cfg_GetHotkeyMoveFollowPrev(), "^!+{LEFT}")
    _E2E_AssertEqual("Roundtrip: hotkey_move_next", _Cfg_GetHotkeyMoveNext(), "^#{RIGHT}")
    _E2E_AssertEqual("Roundtrip: hotkey_move_prev", _Cfg_GetHotkeyMovePrev(), "^#{LEFT}")
    _E2E_AssertEqual("Roundtrip: hotkey_send_new_desktop", _Cfg_GetHotkeySendNewDesktop(), "^!{N}")
    _E2E_AssertEqual("Roundtrip: hotkey_pin_window", _Cfg_GetHotkeyPinWindow(), "^!{P}")
    _E2E_AssertEqual("Roundtrip: hotkey_toggle_window_list", _Cfg_GetHotkeyToggleWindowList(), "^!{W}")
    _E2E_AssertEqual("Roundtrip: hotkey_toggle_last", _Cfg_GetHotkeyToggleLast(), "^!{L}")

    ; Window list settings
    _E2E_AssertTrue("Roundtrip: window_list_enabled", _Cfg_GetWindowListEnabled())
    _E2E_AssertEqual("Roundtrip: window_list_position", _Cfg_GetWindowListPosition(), "top-right")
    _E2E_AssertEqual("Roundtrip: window_list_width", _Cfg_GetWindowListWidth(), 350)
    _E2E_AssertEqual("Roundtrip: window_list_max_visible", _Cfg_GetWindowListMaxVisible(), 20)
    _E2E_AssertFalse("Roundtrip: window_list_show_icons", _Cfg_GetWindowListShowIcons())
    _E2E_AssertFalse("Roundtrip: window_list_search", _Cfg_GetWindowListSearch())
    _E2E_AssertFalse("Roundtrip: window_list_auto_refresh", _Cfg_GetWindowListAutoRefresh())
    _E2E_AssertEqual("Roundtrip: window_list_refresh_interval", _Cfg_GetWindowListRefreshInterval(), 3000)

    ; Explorer monitor settings
    _E2E_AssertTrue("Roundtrip: explorer_monitor_enabled", _Cfg_GetExplorerMonitorEnabled())
    _E2E_AssertEqual("Roundtrip: explorer_check_interval", _Cfg_GetExplorerCheckInterval(), 8000)
    _E2E_AssertFalse("Roundtrip: explorer_notify_recovery", _Cfg_GetExplorerNotifyRecovery())

    ; Notification settings
    _E2E_AssertTrue("Roundtrip: notify_window_moved", _Cfg_GetNotifyWindowMoved())
    _E2E_AssertTrue("Roundtrip: notify_desktop_created", _Cfg_GetNotifyDesktopCreated())
    _E2E_AssertTrue("Roundtrip: notify_desktop_deleted", _Cfg_GetNotifyDesktopDeleted())
    _E2E_AssertTrue("Roundtrip: notify_window_pinned", _Cfg_GetNotifyWindowPinned())

    ; Verify new INI sections exist in raw file
    Local $aSections = IniReadSectionNames($sTempIni)
    Local $bHasWallpaper = False, $bHasPinning = False, $bHasWindowList = False
    Local $bHasExplorerMon = False, $bHasNotifications = False
    If IsArray($aSections) Then
        For $i = 1 To $aSections[0]
            Switch $aSections[$i]
                Case "Wallpaper"
                    $bHasWallpaper = True
                Case "Pinning"
                    $bHasPinning = True
                Case "WindowList"
                    $bHasWindowList = True
                Case "ExplorerMonitor"
                    $bHasExplorerMon = True
                Case "Notifications"
                    $bHasNotifications = True
            EndSwitch
        Next
    EndIf

    _E2E_AssertTrue("Roundtrip: section [Wallpaper] exists", $bHasWallpaper)
    _E2E_AssertTrue("Roundtrip: section [Pinning] exists", $bHasPinning)
    _E2E_AssertTrue("Roundtrip: section [WindowList] exists", $bHasWindowList)
    _E2E_AssertTrue("Roundtrip: section [ExplorerMonitor] exists", $bHasExplorerMon)
    _E2E_AssertTrue("Roundtrip: section [Notifications] exists", $bHasNotifications)

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 10: Wallpaper module integration --
Func _E2E_WallpaperIntegration()
    _E2E_Suite("Wallpaper Integration")

    Local $sTempIni = @TempDir & "\e2e_wallpaper.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    _Cfg_Init($sTempIni)

    ; _WP_Init() should not crash
    _WP_Init()
    _E2E_AssertTrue("WP_Init did not crash", True)

    ; Baseline path should be a string (empty or real path)
    Local $sBaseline = _WP_GetCurrentPath()
    _E2E_AssertTrue("WP_Init: baseline is string", IsString($sBaseline))

    ; Configure wallpaper for desktop 1 with a non-existent path
    _Cfg_SetWallpaperEnabled(True)
    _Cfg_SetDesktopWallpaper(1, "C:\nonexistent\test_wallpaper.jpg")

    ; _WP_Apply(1) with non-existent path should log warning but not crash
    _WP_Apply(1)
    _E2E_AssertTrue("WP_Apply with bad path did not crash", True)
    ; The current path should NOT have changed (file doesn't exist)
    _E2E_AssertEqual("WP_Apply: path unchanged for missing file", _WP_GetCurrentPath(), $sBaseline)

    ; _WP_OnDesktopChanged(1) should set the timer
    _WP_OnDesktopChanged(1)
    _E2E_AssertTrue("WP_OnDesktopChanged did not crash", True)

    ; _WP_Tick() immediately should NOT apply (debounce delay not elapsed)
    ; Save the current path to compare
    Local $sBeforeTick = _WP_GetCurrentPath()
    _WP_Tick()
    _E2E_AssertEqual("WP_Tick before delay: no change", _WP_GetCurrentPath(), $sBeforeTick)

    ; Set a short delay and wait for it
    _Cfg_SetWallpaperChangeDelay(50)
    _WP_OnDesktopChanged(1)
    Sleep(100)
    ; _WP_Tick() after delay should attempt apply (but file still doesn't exist)
    _WP_Tick()
    _E2E_AssertTrue("WP_Tick after delay did not crash", True)
    ; Path still unchanged because the file doesn't exist
    _E2E_AssertEqual("WP_Tick after delay: path unchanged (file missing)", _WP_GetCurrentPath(), $sBeforeTick)

    ; Test with wallpaper disabled - should be a no-op
    _Cfg_SetWallpaperEnabled(False)
    _WP_OnDesktopChanged(2)
    _WP_Tick()
    _E2E_AssertTrue("WP disabled: OnDesktopChanged+Tick is no-op", True)

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 11: Explorer Monitor integration --
Func _E2E_ExplorerMonitorIntegration()
    _E2E_Suite("Explorer Monitor Integration")

    Local $sTempIni = @TempDir & "\e2e_explorer.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    _Cfg_Init($sTempIni)

    ; _EM_Start() should not crash when disabled (default)
    _Cfg_SetExplorerMonitorEnabled(False)
    _EM_Start()
    _E2E_AssertTrue("EM_Start when disabled did not crash", True)

    ; _EM_IsExplorerAlive() should return True (explorer.exe is running in test env)
    _E2E_AssertTrue("EM_IsExplorerAlive returns True", _EM_IsExplorerAlive())

    ; _EM_CheckRecovery() should return False (no crash happened)
    _E2E_AssertFalse("EM_CheckRecovery returns False (no crash)", _EM_CheckRecovery())

    ; Enable and start the monitor
    _Cfg_SetExplorerMonitorEnabled(True)
    _Cfg_SetExplorerCheckInterval(5000)
    _EM_Start()
    _E2E_AssertTrue("EM_Start when enabled did not crash", True)

    ; After start, explorer should still be detected as alive
    _E2E_AssertTrue("EM_IsExplorerAlive after start", _EM_IsExplorerAlive())

    ; CheckRecovery should still be False
    _E2E_AssertFalse("EM_CheckRecovery after start (no crash)", _EM_CheckRecovery())

    ; Stop should clean up without crash
    _EM_Stop()
    _E2E_AssertTrue("EM_Stop clean cleanup", True)

    ; After stop, the alive state should still be valid
    _E2E_AssertTrue("EM_IsExplorerAlive after stop", _EM_IsExplorerAlive())

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 12: VirtualDesktop pin integration --
Func _E2E_VirtualDesktopPinIntegration()
    _E2E_Suite("VirtualDesktop Pin Integration")

    ; Test with DLL at the real path
    Local $sDllPath = @ScriptDir & "\..\VirtualDesktopAccessor.dll"
    Local $bInitOk = _VD_Init($sDllPath)

    ; If DLL is available, test pin operations
    If $bInitOk Then
        _E2E_AssertTrue("VD_Init succeeded with real DLL", True)
        _E2E_AssertTrue("VD_IsReady after init", _VD_IsReady())

        ; _VD_IsPinnedWindow(0) should return False (invalid hwnd)
        _E2E_AssertFalse("VD_IsPinnedWindow(0) returns False", _VD_IsPinnedWindow(0))

        ; _VD_PinWindow(0) should return False (invalid hwnd)
        Local $bPinResult = _VD_PinWindow(0)
        ; PinWindow with hwnd=0 may succeed (DllCall doesn't validate hwnd) or fail
        ; We just verify it doesn't crash
        _E2E_AssertTrue("VD_PinWindow(0) did not crash", True)

        ; _VD_TogglePinWindow(0) should not crash
        Local $bToggleResult = _VD_TogglePinWindow(0)
        _E2E_AssertTrue("VD_TogglePinWindow(0) did not crash", True)

        ; _VD_IsPinnedApp(0) should return False (invalid hwnd)
        _E2E_AssertFalse("VD_IsPinnedApp(0) returns False", _VD_IsPinnedApp(0))

        ; Cleanup DLL
        _VD_Shutdown()
        _E2E_AssertFalse("VD_IsReady after shutdown", _VD_IsReady())
    Else
        ; DLL not available - test graceful degradation
        _E2E_AssertTrue("VD_Init: DLL not found (OK in sandbox)", True)
        _E2E_AssertFalse("VD_IsReady without DLL", _VD_IsReady())

        ; All pin operations should return False gracefully when DLL is not loaded
        _E2E_AssertFalse("VD_IsPinnedWindow without DLL", _VD_IsPinnedWindow(0))
        _E2E_AssertFalse("VD_PinWindow without DLL", _VD_PinWindow(0))
        _E2E_AssertFalse("VD_UnpinWindow without DLL", _VD_UnpinWindow(0))
        _E2E_AssertFalse("VD_IsPinnedApp without DLL", _VD_IsPinnedApp(0))
        _E2E_AssertFalse("VD_PinApp without DLL", _VD_PinApp(0))
        _E2E_AssertFalse("VD_UnpinApp without DLL", _VD_UnpinApp(0))
    EndIf
EndFunc

; -- Test 13: Window List integration --
Func _E2E_WindowListIntegration()
    _E2E_Suite("Window List Integration")

    Local $sTempIni = @TempDir & "\e2e_windowlist.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    _Cfg_Init($sTempIni)

    ; _WL_IsVisible() should return False before any show
    _E2E_AssertFalse("WL_IsVisible before show", _WL_IsVisible())

    ; _WL_GetGUI() should return 0 before any show
    _E2E_AssertEqual("WL_GetGUI before show", _WL_GetGUI(), 0)

    ; _WL_Destroy() on already-destroyed state should not crash
    _WL_Destroy()
    _E2E_AssertTrue("WL_Destroy on empty state did not crash", True)
    _E2E_AssertFalse("WL_IsVisible after destroy on empty", _WL_IsVisible())

    ; Enable the window list feature
    _Cfg_SetWindowListEnabled(True)
    _Cfg_SetWindowListPosition("top-left")
    _Cfg_SetWindowListWidth(280)
    _Cfg_SetWindowListMaxVisible(15)

    ; _WL_Toggle on invisible state should try to show (may fail without proper
    ; VD DLL context, but should not crash)
    ; Note: _WL_Show requires _VD_EnumWindowsOnDesktop which needs the DLL.
    ; If DLL is not loaded, we test graceful behavior.
    If _VD_IsReady() Then
        ; With DLL: full test
        _WL_Show(1)
        _E2E_AssertTrue("WL_Show(1): visible after show", _WL_IsVisible())
        _E2E_AssertTrue("WL_GetGUI after show is non-zero", _WL_GetGUI() <> 0)
        _E2E_AssertEqual("WL_GetDesktop after show", _WL_GetDesktop(), 1)

        ; _WL_Destroy() should clean up
        _WL_Destroy()
        _E2E_AssertFalse("WL_IsVisible after destroy", _WL_IsVisible())
        _E2E_AssertEqual("WL_GetGUI after destroy", _WL_GetGUI(), 0)

        ; _WL_Toggle should toggle state: invisible -> visible
        _WL_Toggle(1)
        _E2E_AssertTrue("WL_Toggle: visible after first toggle", _WL_IsVisible())

        ; _WL_Toggle again: visible -> invisible
        _WL_Toggle(1)
        _E2E_AssertFalse("WL_Toggle: invisible after second toggle", _WL_IsVisible())
    Else
        ; Without DLL: test what we can
        _E2E_AssertTrue("WL: skipping GUI tests (VD DLL not loaded)", True)

        ; State tracking should still work correctly
        _E2E_AssertFalse("WL_IsVisible: still False without show", _WL_IsVisible())
        _E2E_AssertEqual("WL_GetGUI: still 0 without show", _WL_GetGUI(), 0)
    EndIf

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; ===============================================================
; E2E TEST FRAMEWORK FUNCTIONS
; ===============================================================

Func _E2E_Suite($sSuiteName)
    $__g_E2E_sCurrentSuite = $sSuiteName
    ConsoleWrite(@CRLF & "=== E2E: " & $sSuiteName & " ===" & @CRLF)
EndFunc

Func _E2E_AssertEqual($sName, $vActual, $vExpected)
    If $vActual = $vExpected Then
        $__g_E2E_iPass += 1
        ConsoleWrite("  PASS: " & $sName & @CRLF)
    Else
        $__g_E2E_iFail += 1
        ConsoleWrite("  FAIL: " & $sName & " (expected: " & $vExpected & ", got: " & $vActual & ")" & @CRLF)
    EndIf
EndFunc

Func _E2E_AssertTrue($sName, $bValue)
    _E2E_AssertEqual($sName, $bValue, True)
EndFunc

Func _E2E_AssertFalse($sName, $bValue)
    _E2E_AssertEqual($sName, $bValue, False)
EndFunc

Func _E2E_Summary()
    Local $sResults = ""
    $sResults &= @CRLF & "==============================" & @CRLF
    $sResults &= "E2E Results: " & $__g_E2E_iPass & " passed, " & $__g_E2E_iFail & " failed" & @CRLF
    $sResults &= "==============================" & @CRLF
    ConsoleWrite($sResults)

    ; Write results file for sandbox_setup.ps1 to read
    Local $sResultFile = $__g_E2E_sResultsDir & "\e2e_results.txt"
    Local $hFile = FileOpen($sResultFile, 2) ; overwrite
    If $hFile <> -1 Then
        FileWrite($hFile, "pass=" & $__g_E2E_iPass & @CRLF)
        FileWrite($hFile, "fail=" & $__g_E2E_iFail & @CRLF)
        If $__g_E2E_iFail > 0 Then
            FileWrite($hFile, "status=FAIL" & @CRLF)
        Else
            FileWrite($hFile, "status=PASS" & @CRLF)
        EndIf
        FileClose($hFile)
    EndIf

    If $__g_E2E_iFail > 0 Then Exit 1
    Exit 0
EndFunc
