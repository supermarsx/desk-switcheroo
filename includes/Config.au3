#include-once
#include "Logger.au3"

; #INDEX# =======================================================
; Title .........: Config
; Description ....: Configuration management — INI-backed settings with typed
;                   getters/setters, validation, and default handling
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_Cfg_sIniPath = ""
Global $__g_Cfg_hSaveTimer = 0
Global Const $__g_Cfg_SAVE_DEBOUNCE = 500 ; ms between saves
Global Const $__g_Cfg_MAX_DESKTOPS = 50
Global $__g_Cfg_bLoadedDefaults = False

; [General]
Global $__g_Cfg_sLanguage          = "en-US"
Global $__g_Cfg_bStartWithWindows  = False
Global $__g_Cfg_bWrapNavigation    = True
Global $__g_Cfg_bAutoCreateDesktop = False
Global $__g_Cfg_iNumberPadding     = 2
Global $__g_Cfg_sWidgetPosition    = "bottom-left"
Global $__g_Cfg_iWidgetOffsetX     = 0
Global $__g_Cfg_iWidgetOffsetY     = 0
Global $__g_Cfg_iWidgetWidth       = 0  ; 0 = auto (THEME_MAIN_WIDTH)
Global $__g_Cfg_iWidgetHeight      = 0  ; 0 = auto (taskbar height)
Global $__g_Cfg_bWidgetDragEnabled = False
Global $__g_Cfg_bWidgetColorBar   = False
Global $__g_Cfg_iWidgetColorBarH  = 2
Global $__g_Cfg_bTrayIconMode     = False
Global $__g_Cfg_bQuickAccessEnabled = False
Global $__g_Cfg_bStartMinimized    = False
Global $__g_Cfg_bListKeyboardNav   = False
Global $__g_Cfg_bAutoUpdateEnabled = False
Global $__g_Cfg_iAutoUpdateInterval = 168
Global $__g_Cfg_bSingletonEnabled   = True
Global $__g_Cfg_iMinDesktops        = 0
Global $__g_Cfg_iMaxDesktops        = 0       ; 0 = unlimited
Global $__g_Cfg_bTaskbarFocusTrick  = False
Global $__g_Cfg_bAutoFocusAfterSwitch = False
Global $__g_Cfg_bCapslockModifier   = False
Global $__g_Cfg_bDisableWinWidgets  = False
Global $__g_Cfg_bDesktopListPinned  = False

; [Updates]
Global $__g_Cfg_bUpdateCheckOnStartup = False
Global $__g_Cfg_iUpdateCheckDays      = 7

; [Display]
Global $__g_Cfg_bShowCount         = False
Global $__g_Cfg_iCountFontSize     = 7
Global $__g_Cfg_iThemeAlphaMain    = 235
Global $__g_Cfg_sTheme             = "dark"
Global $__g_Cfg_bThumbnailsEnabled = False
Global $__g_Cfg_iThumbnailWidth    = 160
Global $__g_Cfg_iThumbnailHeight   = 90
Global $__g_Cfg_bListScrollable    = False
Global $__g_Cfg_iListMaxVisible    = 10
Global $__g_Cfg_iListScrollSpeed   = 1
Global $__g_Cfg_iTooltipFontSize   = 8
Global $__g_Cfg_bThumbnailUseScreenshot = False
Global $__g_Cfg_iThumbnailCacheTTL = 30
Global $__g_Cfg_bDesktopListShowNumbers = True
Global $__g_Cfg_iHotkeyDesktopCount = 9

; [Scroll]
Global $__g_Cfg_bScrollEnabled     = False
Global $__g_Cfg_sScrollDirection   = "normal"
Global $__g_Cfg_bScrollWrap        = True
Global $__g_Cfg_bListScrollEnabled = False
Global $__g_Cfg_sListScrollAction  = "switch"

; [Hotkeys]
Global $__g_Cfg_sHotkeyNext        = "^!{RIGHT}"
Global $__g_Cfg_sHotkeyPrev        = "^!{LEFT}"
Global $__g_Cfg_sHotkeyDesktop[10] ; index 1-9
$__g_Cfg_sHotkeyDesktop[0] = 9
For $__i = 1 To 9
    $__g_Cfg_sHotkeyDesktop[$__i] = ""
Next
Global $__g_Cfg_sHotkeyToggleList  = "^!{DOWN}"
Global $__g_Cfg_sHotkeyToggleLast  = "^!{TAB}"
Global $__g_Cfg_sHotkeyMoveFollowNext = "^!+{RIGHT}"
Global $__g_Cfg_sHotkeyMoveFollowPrev = "^!+{LEFT}"
Global $__g_Cfg_sHotkeyMoveNext    = "^#{RIGHT}"
Global $__g_Cfg_sHotkeyMovePrev    = "^#{LEFT}"
Global $__g_Cfg_sHotkeySendNewDesktop = "^!n"
Global $__g_Cfg_sHotkeyPinWindow   = "^!p"
Global $__g_Cfg_sHotkeyToggleWindowList = "^!w"
Global $__g_Cfg_sHotkeyOpenSettings = "^!s"
Global $__g_Cfg_bHotkeysEnabled = True
Global $__g_Cfg_sHotkeyAddDesktop   = "^!{INSERT}"
Global $__g_Cfg_sHotkeyDeleteDesktop = ""
Global $__g_Cfg_sHotkeyRenameDesktop = "^!r"
Global $__g_Cfg_sHotkeyCloseWindow  = ""
Global $__g_Cfg_sHotkeyMinimizeWindow = ""
Global $__g_Cfg_sHotkeyToggleCarousel = ""
Global $__g_Cfg_sHotkeyTaskView     = ""

; [Behavior]
Global $__g_Cfg_bConfirmDelete     = True
Global $__g_Cfg_bMiddleClickDelete = False
Global $__g_Cfg_bMoveWindowEnabled = True
Global $__g_Cfg_iPeekBounceDelay   = 500
Global $__g_Cfg_iAutoHideTimeout   = 3000
Global $__g_Cfg_iTopmostInterval   = 300
Global $__g_Cfg_iCmAutoHideDelay   = 500
Global $__g_Cfg_bConfigWatcherEnabled = False
Global $__g_Cfg_iConfigWatcherInterval = 60000
Global $__g_Cfg_iCountCacheTTL = 1000
Global $__g_Cfg_iNameSyncInterval  = 2000
Global $__g_Cfg_iDllCheckInterval  = 30000
Global $__g_Cfg_iUpdatePollInterval = 500
Global $__g_Cfg_bConfirmQuit       = False
Global $__g_Cfg_bConfirmRestart    = False
Global $__g_Cfg_bDebugMode         = False

; [Display] - List font
Global $__g_Cfg_sListFontName      = ""
Global $__g_Cfg_iListFontSize      = 8

; [Animations]
Global $__g_Cfg_bAnimationsEnabled = True
Global $__g_Cfg_iFadeInDuration    = 80   ; ms total for fade-in
Global $__g_Cfg_iFadeOutDuration   = 80   ; ms total for fade-out
Global $__g_Cfg_iFadeStep          = 30   ; alpha increment per frame
Global $__g_Cfg_iToastFadeOutMs    = 300  ; toast fade-out duration
Global $__g_Cfg_iFadeSleepMs       = 8    ; sleep per fade frame
; Per-location animation toggles
Global $__g_Cfg_bAnimList          = True  ; desktop list
Global $__g_Cfg_bAnimMenus         = True  ; context menus
Global $__g_Cfg_bAnimDialogs       = True  ; settings, about, rename, confirm
Global $__g_Cfg_bAnimToasts        = True  ; toast notifications
Global $__g_Cfg_bAnimWidget        = True  ; main widget show/hide
Global $__g_Cfg_iAnimHoverSpeed    = 0    ; ms for hover fade (0 = instant)
Global $__g_Cfg_sToastPosition     = "widget" ; top-left|top-right|bottom-left|bottom-right|widget

; [Logging]
Global $__g_Cfg_bLoggingEnabled    = False
Global $__g_Cfg_sLogFolder          = ""
Global $__g_Cfg_sLogLevel          = "info"
Global $__g_Cfg_iLogMaxSizeMB      = 5
Global $__g_Cfg_iLogRotateCount    = 3
Global $__g_Cfg_bLogCompressOld    = False
Global $__g_Cfg_bLogIncludePID     = False
Global $__g_Cfg_bLogIncludeFunc    = False
Global $__g_Cfg_sLogDateFormat     = "iso"
Global $__g_Cfg_bLogFlushImmediate = True

; [DesktopColors]
Global $__g_Cfg_bDesktopColorsEnabled = False
Global $__g_Cfg_aDesktopColors[$__g_Cfg_MAX_DESKTOPS + 1]
$__g_Cfg_aDesktopColors[0] = $__g_Cfg_MAX_DESKTOPS
For $__i = 1 To $__g_Cfg_MAX_DESKTOPS
    $__g_Cfg_aDesktopColors[$__i] = 0
Next

; [Wallpaper]
Global $__g_Cfg_bWallpaperEnabled    = False
Global $__g_Cfg_iWallpaperChangeDelay = 200
Global $__g_Cfg_aDesktopWallpaper[$__g_Cfg_MAX_DESKTOPS + 1]
$__g_Cfg_aDesktopWallpaper[0] = $__g_Cfg_MAX_DESKTOPS
For $__i = 1 To $__g_Cfg_MAX_DESKTOPS
    $__g_Cfg_aDesktopWallpaper[$__i] = ""
Next

; [Pinning]
Global $__g_Cfg_bPinningEnabled      = False

; [WindowList]
Global $__g_Cfg_bWindowListEnabled   = False
Global $__g_Cfg_sWindowListPosition  = "top-left"
Global $__g_Cfg_iWindowListWidth     = 280
Global $__g_Cfg_iWindowListMaxVisible = 15
Global $__g_Cfg_bWindowListShowIcons = True
Global $__g_Cfg_bWindowListSearch    = True
Global $__g_Cfg_bWindowListAutoRefresh = True
Global $__g_Cfg_iWindowListRefreshInterval = 1000

; [ExplorerMonitor]
Global $__g_Cfg_bExplorerMonitorEnabled  = False
Global $__g_Cfg_sShellProcessName        = "explorer.exe"
Global $__g_Cfg_iExplorerCheckInterval   = 5000
Global $__g_Cfg_iMonitorMaxRetries       = 0       ; 0 = unlimited
Global $__g_Cfg_iMonitorRetryDelay       = 5000
Global $__g_Cfg_bMonitorExpBackoff       = True
Global $__g_Cfg_iMonitorMaxRetryDelay    = 60000
Global $__g_Cfg_bMonitorAutoRestart      = False
Global $__g_Cfg_iMonitorRestartDelay     = 2000
Global $__g_Cfg_bExplorerNotifyRecovery  = True

; [TaskbarAutoHide]
Global $__g_Cfg_bAutoHideSyncEnabled      = False
Global $__g_Cfg_iAutoHidePollInterval     = 150
Global $__g_Cfg_iAutoHideHideDelay        = 200
Global $__g_Cfg_iAutoHideShowDelay        = 0
Global $__g_Cfg_bAutoHideUseFade          = True
Global $__g_Cfg_iAutoHideFadeDuration     = 80
Global $__g_Cfg_bAutoHideSyncDesktopList  = True
Global $__g_Cfg_bAutoHideSyncWindowList   = False
Global $__g_Cfg_iAutoHideHiddenThreshold  = 4
Global $__g_Cfg_iAutoHideRecheckCount     = 10
Global $__g_Cfg_bAutoHideSkipIfDialog     = True

; [Notifications]
Global $__g_Cfg_bNotificationsEnabled   = True
Global $__g_Cfg_bNotifyWindowMoved      = False
Global $__g_Cfg_bNotifyDesktopCreated   = False
Global $__g_Cfg_bNotifyDesktopDeleted   = False
Global $__g_Cfg_bNotifyWindowPinned     = False
Global $__g_Cfg_bNotifyWindowUnpinned   = False
Global $__g_Cfg_bNotifyExplorerRecovery = False
Global $__g_Cfg_bNotifyExplorerCrash    = False
Global $__g_Cfg_sWindowListScope        = "current" ; "current" or "all"

; [Notifications] OSD
Global $__g_Cfg_bOsdEnabled            = False
Global $__g_Cfg_bOsdShowName           = True
Global $__g_Cfg_bOsdShowNumber         = True
Global $__g_Cfg_iOsdDuration           = 1500
Global $__g_Cfg_sOsdPosition           = "top-center"
Global $__g_Cfg_iOsdFontSize           = 14
Global $__g_Cfg_iOsdOpacity            = 220
Global $__g_Cfg_sOsdFormat             = "{number}: {name}"

; [Rules]
Global $__g_Cfg_bRulesEnabled          = False
Global $__g_Cfg_iRulesPollInterval     = 2000

; [Session]
Global $__g_Cfg_bSessionRestoreEnabled = False

; [Hooks]
Global $__g_Cfg_bHooksEnabled          = False
Global $__g_Cfg_iHooksTimeout          = 10000

; [Profiles]
Global $__g_Cfg_bProfilesEnabled       = False

; [Carousel]
Global $__g_Cfg_bCarouselEnabled       = False
Global $__g_Cfg_iCarouselInterval      = 20000
Global $__g_Cfg_bCarouselShowInMenu    = True
Global $__g_Cfg_bNotifyCarouselToggle  = True

; [Tray]
Global $__g_Cfg_sTrayLeftClick          = "menu"
Global $__g_Cfg_sTrayDoubleClick        = "settings"
Global $__g_Cfg_sTrayMiddleClick        = "toggle_list"
Global $__g_Cfg_bTrayTooltipShowLabel   = True
Global $__g_Cfg_bTrayTooltipShowCount   = False
Global $__g_Cfg_bTrayMenuShowList       = True
Global $__g_Cfg_bTrayMenuShowEdit       = True
Global $__g_Cfg_bTrayMenuShowAdd        = True
Global $__g_Cfg_bTrayMenuShowDelete     = True
Global $__g_Cfg_bTrayMenuShowDesktopSub = False
Global $__g_Cfg_bTrayMenuShowMoveWindow = False
Global $__g_Cfg_bTrayNotifySwitch       = False
Global $__g_Cfg_iTrayBalloonDuration    = 2000
Global $__g_Cfg_bTrayCloseToTray        = False

; #FUNCTIONS# ===================================================

; Name:        _Cfg_Init
; Description: Initializes the config system. Creates INI with defaults if missing.
; Parameters:  $sPath - INI file path (default: @ScriptDir & "\desk_switcheroo.ini")
Func _Cfg_Init($sPath = Default)
    If $sPath = Default Then $sPath = @ScriptDir & "\desk_switcheroo.ini"
    $__g_Cfg_sIniPath = $sPath

    ; First run: copy prod example if available
    If Not FileExists($sPath) Then
        Local $sExample = @ScriptDir & "\examples\desk_switcheroo.prod.ini"
        If FileExists($sExample) Then
            FileCopy($sExample, $sPath)
        EndIf
    EndIf

    _Cfg_WriteDefaults()
    _Cfg_Load()
EndFunc

; Name:        _Cfg_GetPath
; Description: Returns the config INI file path
Func _Cfg_GetPath()
    Return $__g_Cfg_sIniPath
EndFunc
Func _Cfg_DidLoadDefaults()
    Return $__g_Cfg_bLoadedDefaults
EndFunc

; Name:        _Cfg_Load
; Description: Reads all values from INI into memory, with validation
Func _Cfg_Load()
    If Not __Cfg_ReadFromFile() Then
        _Log_Warn("Config file not readable, using defaults")
        $__g_Cfg_bLoadedDefaults = True
    EndIf

    Local $f = $__g_Cfg_sIniPath

    ; [General]
    $__g_Cfg_sLanguage          = IniRead($f, "General", "language", "en-US")
    $__g_Cfg_bStartWithWindows  = __Cfg_ReadBool($f, "General", "start_with_windows", False)
    $__g_Cfg_bWrapNavigation    = __Cfg_ReadBool($f, "General", "wrap_navigation", True)
    $__g_Cfg_bAutoCreateDesktop = __Cfg_ReadBool($f, "General", "auto_create_desktop", False)
    $__g_Cfg_iNumberPadding     = __Cfg_ReadInt($f, "General", "number_padding", 2, 1, 4)
    $__g_Cfg_sWidgetPosition    = __Cfg_ReadEnum($f, "General", "widget_position", "bottom-left", _
        "bottom-left|bottom-center|bottom-right|middle-left|middle-right|top-left|top-center|top-right|left|center|right")
    $__g_Cfg_iWidgetOffsetX     = __Cfg_ReadInt($f, "General", "widget_offset_x", 0, -9999, 9999)
    $__g_Cfg_iWidgetOffsetY     = __Cfg_ReadInt($f, "General", "widget_offset_y", 0, -9999, 9999)
    $__g_Cfg_iWidgetWidth       = __Cfg_ReadInt($f, "General", "widget_width", 0, 0, 500)
    $__g_Cfg_iWidgetHeight      = __Cfg_ReadInt($f, "General", "widget_height", 0, 0, 200)
    $__g_Cfg_bWidgetDragEnabled = __Cfg_ReadBool($f, "General", "widget_drag_enabled", False)
    $__g_Cfg_bWidgetColorBar   = __Cfg_ReadBool($f, "General", "widget_color_bar", False)
    $__g_Cfg_iWidgetColorBarH  = __Cfg_ReadInt($f, "General", "widget_color_bar_height", 2, 1, 10)
    $__g_Cfg_bTrayIconMode     = __Cfg_ReadBool($f, "General", "tray_icon_mode", False)
    $__g_Cfg_bQuickAccessEnabled = __Cfg_ReadBool($f, "General", "quick_access_enabled", False)
    $__g_Cfg_bStartMinimized    = __Cfg_ReadBool($f, "General", "start_minimized", False)
    $__g_Cfg_bListKeyboardNav   = __Cfg_ReadBool($f, "General", "list_keyboard_nav", False)
    $__g_Cfg_bAutoUpdateEnabled = __Cfg_ReadBool($f, "General", "auto_update_enabled", False)
    $__g_Cfg_iAutoUpdateInterval = __Cfg_ReadInt($f, "General", "auto_update_interval", 168, 1, 720)
    $__g_Cfg_bSingletonEnabled   = __Cfg_ReadBool($f, "General", "singleton_enabled", True)
    $__g_Cfg_iMinDesktops        = __Cfg_ReadInt($f, "General", "min_desktops", 0, 0, 50)
    $__g_Cfg_iMaxDesktops        = __Cfg_ReadInt($f, "General", "max_desktops", 0, 0, 50)
    $__g_Cfg_bTaskbarFocusTrick  = __Cfg_ReadBool($f, "General", "taskbar_focus_trick", False)
    $__g_Cfg_bAutoFocusAfterSwitch = __Cfg_ReadBool($f, "General", "auto_focus_after_switch", False)
    $__g_Cfg_bCapslockModifier   = __Cfg_ReadBool($f, "General", "capslock_modifier", False)
    $__g_Cfg_bDisableWinWidgets  = __Cfg_ReadBool($f, "General", "disable_win_widgets", False)
    $__g_Cfg_bDesktopListPinned  = __Cfg_ReadBool($f, "General", "desktop_list_pinned", False)

    ; [Updates]
    $__g_Cfg_bUpdateCheckOnStartup = __Cfg_ReadBool($f, "Updates", "update_check_on_startup", False)
    $__g_Cfg_iUpdateCheckDays      = __Cfg_ReadInt($f, "Updates", "update_check_days", 7, 1, 90)

    ; [Display]
    $__g_Cfg_bShowCount         = __Cfg_ReadBool($f, "Display", "show_count", False)
    $__g_Cfg_iCountFontSize     = __Cfg_ReadInt($f, "Display", "count_font_size", 7, 4, 20)
    $__g_Cfg_iThemeAlphaMain    = __Cfg_ReadInt($f, "Display", "theme_alpha_main", 235, 50, 255)
    $__g_Cfg_sTheme             = __Cfg_ReadEnum($f, "Display", "theme", "dark", "dark|darker|midnight|midday|sunset")
    $__g_Cfg_bThumbnailsEnabled = __Cfg_ReadBool($f, "Display", "thumbnails_enabled", False)
    $__g_Cfg_iThumbnailWidth    = __Cfg_ReadInt($f, "Display", "thumbnail_width", 160, 80, 320)
    $__g_Cfg_iThumbnailHeight   = __Cfg_ReadInt($f, "Display", "thumbnail_height", 90, 45, 180)
    $__g_Cfg_sListFontName      = IniRead($f, "Display", "list_font_name", "")
    $__g_Cfg_iListFontSize      = __Cfg_ReadInt($f, "Display", "list_font_size", 8, 6, 14)
    $__g_Cfg_bListScrollable    = __Cfg_ReadBool($f, "Display", "list_scrollable", False)
    $__g_Cfg_iListMaxVisible    = __Cfg_ReadInt($f, "Display", "list_max_visible", 10, 3, 30)
    $__g_Cfg_iListScrollSpeed   = __Cfg_ReadInt($f, "Display", "list_scroll_speed", 1, 1, 5)
    $__g_Cfg_iTooltipFontSize   = __Cfg_ReadInt($f, "Display", "tooltip_font_size", 8, 6, 12)
    $__g_Cfg_bThumbnailUseScreenshot = __Cfg_ReadBool($f, "Display", "thumbnail_use_screenshot", False)
    $__g_Cfg_iThumbnailCacheTTL = __Cfg_ReadInt($f, "Display", "thumbnail_cache_ttl", 30, 5, 300)
    $__g_Cfg_bDesktopListShowNumbers = __Cfg_ReadBool($f, "Display", "desktop_list_show_numbers", True)

    ; [Scroll]
    $__g_Cfg_bScrollEnabled     = __Cfg_ReadBool($f, "Scroll", "scroll_enabled", False)
    $__g_Cfg_sScrollDirection   = __Cfg_ReadEnum($f, "Scroll", "scroll_direction", "normal", "normal|inverted")
    $__g_Cfg_bScrollWrap        = __Cfg_ReadBool($f, "Scroll", "scroll_wrap", True)
    $__g_Cfg_bListScrollEnabled = __Cfg_ReadBool($f, "Scroll", "list_scroll_enabled", False)
    $__g_Cfg_sListScrollAction  = __Cfg_ReadEnum($f, "Scroll", "list_scroll_action", "switch", "switch|scroll")

    ; [Hotkeys]
    $__g_Cfg_iHotkeyDesktopCount = __Cfg_ReadInt($f, "Hotkeys", "hotkey_desktop_count", 9, 1, 9)
    $__g_Cfg_sHotkeyNext       = IniRead($f, "Hotkeys", "hotkey_next", "^!{RIGHT}")
    $__g_Cfg_sHotkeyPrev       = IniRead($f, "Hotkeys", "hotkey_prev", "^!{LEFT}")
    Local $i
    For $i = 1 To 9
        $__g_Cfg_sHotkeyDesktop[$i] = IniRead($f, "Hotkeys", "hotkey_desktop_" & $i, "")
    Next
    $__g_Cfg_sHotkeyToggleList = IniRead($f, "Hotkeys", "hotkey_toggle_list", "^!{DOWN}")
    $__g_Cfg_sHotkeyToggleLast = IniRead($f, "Hotkeys", "hotkey_toggle_last", "^!{TAB}")
    $__g_Cfg_sHotkeyMoveFollowNext = IniRead($f, "Hotkeys", "hotkey_move_follow_next", "^!+{RIGHT}")
    $__g_Cfg_sHotkeyMoveFollowPrev = IniRead($f, "Hotkeys", "hotkey_move_follow_prev", "^!+{LEFT}")
    $__g_Cfg_sHotkeyMoveNext    = IniRead($f, "Hotkeys", "hotkey_move_next", "^#{RIGHT}")
    $__g_Cfg_sHotkeyMovePrev    = IniRead($f, "Hotkeys", "hotkey_move_prev", "^#{LEFT}")
    $__g_Cfg_sHotkeySendNewDesktop = IniRead($f, "Hotkeys", "hotkey_send_new_desktop", "^!n")
    $__g_Cfg_sHotkeyPinWindow   = IniRead($f, "Hotkeys", "hotkey_pin_window", "^!p")
    $__g_Cfg_sHotkeyToggleWindowList = IniRead($f, "Hotkeys", "hotkey_toggle_window_list", "^!w")
    $__g_Cfg_sHotkeyOpenSettings = IniRead($f, "Hotkeys", "hotkey_open_settings", "^!s")
    $__g_Cfg_bHotkeysEnabled = __Cfg_ReadBool($f, "Hotkeys", "hotkeys_enabled", True)
    $__g_Cfg_sHotkeyAddDesktop   = IniRead($f, "Hotkeys", "hotkey_add_desktop", "^!{INSERT}")
    $__g_Cfg_sHotkeyDeleteDesktop = IniRead($f, "Hotkeys", "hotkey_delete_desktop", "")
    $__g_Cfg_sHotkeyRenameDesktop = IniRead($f, "Hotkeys", "hotkey_rename_desktop", "^!r")
    $__g_Cfg_sHotkeyCloseWindow  = IniRead($f, "Hotkeys", "hotkey_close_window", "")
    $__g_Cfg_sHotkeyMinimizeWindow = IniRead($f, "Hotkeys", "hotkey_minimize_window", "")
    $__g_Cfg_sHotkeyToggleCarousel = IniRead($f, "Hotkeys", "hotkey_toggle_carousel", "")
    $__g_Cfg_sHotkeyTaskView     = IniRead($f, "Hotkeys", "hotkey_task_view", "")

    ; [Behavior]
    $__g_Cfg_bConfirmDelete     = __Cfg_ReadBool($f, "Behavior", "confirm_delete", True)
    $__g_Cfg_bMiddleClickDelete = __Cfg_ReadBool($f, "Behavior", "middle_click_delete", False)
    $__g_Cfg_bMoveWindowEnabled = __Cfg_ReadBool($f, "Behavior", "move_window_enabled", True)
    $__g_Cfg_iPeekBounceDelay   = __Cfg_ReadInt($f, "Behavior", "peek_bounce_delay", 500, 100, 5000)
    $__g_Cfg_iAutoHideTimeout   = __Cfg_ReadInt($f, "Behavior", "auto_hide_timeout", 3000, 500, 30000)
    $__g_Cfg_iTopmostInterval   = __Cfg_ReadInt($f, "Behavior", "topmost_interval", 300, 100, 5000)
    $__g_Cfg_iCmAutoHideDelay   = __Cfg_ReadInt($f, "Behavior", "cm_auto_hide_delay", 500, 100, 5000)
    $__g_Cfg_bConfigWatcherEnabled = __Cfg_ReadBool($f, "Behavior", "config_watcher_enabled", False)
    $__g_Cfg_iConfigWatcherInterval = __Cfg_ReadInt($f, "Behavior", "config_watcher_interval", 60000, 5000, 300000)
    $__g_Cfg_iCountCacheTTL = __Cfg_ReadInt($f, "Behavior", "count_cache_ttl", 1000, 100, 10000)
    $__g_Cfg_iNameSyncInterval = __Cfg_ReadInt($f, "Behavior", "name_sync_interval", 2000, 500, 60000)
    $__g_Cfg_iDllCheckInterval = __Cfg_ReadInt($f, "Behavior", "dll_check_interval", 30000, 5000, 300000)
    $__g_Cfg_iUpdatePollInterval = __Cfg_ReadInt($f, "Behavior", "update_poll_interval", 500, 100, 5000)
    $__g_Cfg_bConfirmQuit       = __Cfg_ReadBool($f, "Behavior", "confirm_quit", False)
    $__g_Cfg_bConfirmRestart    = __Cfg_ReadBool($f, "Behavior", "confirm_restart", False)
    $__g_Cfg_bDebugMode         = __Cfg_ReadBool($f, "Behavior", "debug_mode", False)

    ; [Logging]
    ; [Animations]
    $__g_Cfg_bAnimationsEnabled = __Cfg_ReadBool($f, "Animations", "animations_enabled", True)
    $__g_Cfg_iFadeInDuration    = __Cfg_ReadInt($f, "Animations", "fade_in_duration", 80, 0, 500)
    $__g_Cfg_iFadeOutDuration   = __Cfg_ReadInt($f, "Animations", "fade_out_duration", 80, 0, 500)
    $__g_Cfg_iFadeStep          = __Cfg_ReadInt($f, "Animations", "fade_step", 30, 5, 255)
    $__g_Cfg_iToastFadeOutMs    = __Cfg_ReadInt($f, "Animations", "toast_fade_out_duration", 300, 0, 1000)
    $__g_Cfg_iFadeSleepMs       = __Cfg_ReadInt($f, "Animations", "fade_sleep_ms", 8, 1, 50)
    $__g_Cfg_bAnimList          = __Cfg_ReadBool($f, "Animations", "anim_list", True)
    $__g_Cfg_bAnimMenus         = __Cfg_ReadBool($f, "Animations", "anim_menus", True)
    $__g_Cfg_bAnimDialogs       = __Cfg_ReadBool($f, "Animations", "anim_dialogs", True)
    $__g_Cfg_bAnimToasts        = __Cfg_ReadBool($f, "Animations", "anim_toasts", True)
    $__g_Cfg_bAnimWidget        = __Cfg_ReadBool($f, "Animations", "anim_widget", True)
    $__g_Cfg_iAnimHoverSpeed    = __Cfg_ReadInt($f, "Animations", "anim_hover_speed", 0, 0, 50)
    $__g_Cfg_sToastPosition     = __Cfg_ReadEnum($f, "Animations", "toast_position", "widget", _
        "top-left|top-right|bottom-left|bottom-right|widget")

    $__g_Cfg_bLoggingEnabled    = __Cfg_ReadBool($f, "Logging", "logging_enabled", False)
    $__g_Cfg_sLogFolder         = IniRead($f, "Logging", "log_folder", "")
    $__g_Cfg_sLogLevel          = __Cfg_ReadEnum($f, "Logging", "log_level", "info", "error|warn|info|debug")
    $__g_Cfg_iLogMaxSizeMB      = __Cfg_ReadInt($f, "Logging", "log_max_size_mb", 5, 1, 50)
    $__g_Cfg_iLogRotateCount    = __Cfg_ReadInt($f, "Logging", "log_rotate_count", 3, 1, 10)
    $__g_Cfg_bLogCompressOld    = __Cfg_ReadBool($f, "Logging", "log_compress_old", False)
    $__g_Cfg_bLogIncludePID     = __Cfg_ReadBool($f, "Logging", "log_include_pid", False)
    $__g_Cfg_bLogIncludeFunc    = __Cfg_ReadBool($f, "Logging", "log_include_func", False)
    $__g_Cfg_sLogDateFormat     = __Cfg_ReadEnum($f, "Logging", "log_date_format", "iso", "iso|us|eu")
    $__g_Cfg_bLogFlushImmediate = __Cfg_ReadBool($f, "Logging", "log_flush_immediate", True)

    ; [DesktopColors]
    $__g_Cfg_bDesktopColorsEnabled = __Cfg_ReadBool($f, "DesktopColors", "desktop_colors_enabled", False)
    For $i = 1 To $__g_Cfg_MAX_DESKTOPS
        Local $sVal = IniRead($f, "DesktopColors", "desktop_" & $i & "_color", "")
        If $sVal <> "" And StringLeft($sVal, 2) = "0x" Then
            $__g_Cfg_aDesktopColors[$i] = Int($sVal)
        Else
            $__g_Cfg_aDesktopColors[$i] = 0
        EndIf
    Next

    ; [Wallpaper]
    $__g_Cfg_bWallpaperEnabled    = __Cfg_ReadBool($f, "Wallpaper", "wallpaper_enabled", False)
    $__g_Cfg_iWallpaperChangeDelay = __Cfg_ReadInt($f, "Wallpaper", "wallpaper_change_delay", 200, 50, 2000)
    For $i = 1 To $__g_Cfg_MAX_DESKTOPS
        $__g_Cfg_aDesktopWallpaper[$i] = IniRead($f, "Wallpaper", "desktop_" & $i & "_wallpaper", "")
        If $__g_Cfg_aDesktopWallpaper[$i] <> "" And Not __Cfg_ValidateWallpaperPath($__g_Cfg_aDesktopWallpaper[$i]) Then
            _Log_Warn("Config: rejected invalid wallpaper path for desktop " & $i & ": " & $__g_Cfg_aDesktopWallpaper[$i])
            $__g_Cfg_aDesktopWallpaper[$i] = ""
        EndIf
    Next

    ; [Pinning]
    $__g_Cfg_bPinningEnabled      = __Cfg_ReadBool($f, "Pinning", "pinning_enabled", False)

    ; [WindowList]
    $__g_Cfg_bWindowListEnabled   = __Cfg_ReadBool($f, "WindowList", "window_list_enabled", False)
    $__g_Cfg_sWindowListPosition  = __Cfg_ReadEnum($f, "WindowList", "window_list_position", "top-left", _
        "top-left|top-right|bottom-left|bottom-right")
    $__g_Cfg_iWindowListWidth     = __Cfg_ReadInt($f, "WindowList", "window_list_width", 280, 150, 600)
    $__g_Cfg_iWindowListMaxVisible = __Cfg_ReadInt($f, "WindowList", "window_list_max_visible", 15, 5, 50)
    $__g_Cfg_bWindowListShowIcons = __Cfg_ReadBool($f, "WindowList", "window_list_show_icons", True)
    $__g_Cfg_bWindowListSearch    = __Cfg_ReadBool($f, "WindowList", "window_list_search", True)
    $__g_Cfg_bWindowListAutoRefresh = __Cfg_ReadBool($f, "WindowList", "window_list_auto_refresh", True)
    $__g_Cfg_iWindowListRefreshInterval = __Cfg_ReadInt($f, "WindowList", "window_list_refresh_interval", 1000, 500, 10000)

    ; [ExplorerMonitor]
    $__g_Cfg_bExplorerMonitorEnabled = __Cfg_ReadBool($f, "ExplorerMonitor", "explorer_monitor_enabled", False)
    $__g_Cfg_sShellProcessName       = __Cfg_ValidateExeName(IniRead($f, "ExplorerMonitor", "shell_process_name", "explorer.exe"))
    $__g_Cfg_iExplorerCheckInterval  = __Cfg_ReadInt($f, "ExplorerMonitor", "explorer_check_interval", 5000, 2000, 60000)
    $__g_Cfg_iMonitorMaxRetries      = __Cfg_ReadInt($f, "ExplorerMonitor", "monitor_max_retries", 0, 0, 100)
    $__g_Cfg_iMonitorRetryDelay      = __Cfg_ReadInt($f, "ExplorerMonitor", "monitor_retry_delay", 5000, 1000, 60000)
    $__g_Cfg_bMonitorExpBackoff      = __Cfg_ReadBool($f, "ExplorerMonitor", "monitor_exp_backoff", True)
    $__g_Cfg_iMonitorMaxRetryDelay   = __Cfg_ReadInt($f, "ExplorerMonitor", "monitor_max_retry_delay", 60000, 5000, 300000)
    $__g_Cfg_bMonitorAutoRestart     = __Cfg_ReadBool($f, "ExplorerMonitor", "monitor_auto_restart", False)
    $__g_Cfg_iMonitorRestartDelay    = __Cfg_ReadInt($f, "ExplorerMonitor", "monitor_restart_delay", 2000, 500, 10000)
    $__g_Cfg_bExplorerNotifyRecovery = __Cfg_ReadBool($f, "ExplorerMonitor", "explorer_notify_recovery", True)

    ; [TaskbarAutoHide]
    $__g_Cfg_bAutoHideSyncEnabled      = __Cfg_ReadBool($f, "TaskbarAutoHide", "autohide_sync_enabled", False)
    $__g_Cfg_iAutoHidePollInterval     = __Cfg_ReadInt($f, "TaskbarAutoHide", "autohide_poll_interval", 150, 50, 2000)
    $__g_Cfg_iAutoHideHideDelay        = __Cfg_ReadInt($f, "TaskbarAutoHide", "autohide_hide_delay", 200, 0, 5000)
    $__g_Cfg_iAutoHideShowDelay        = __Cfg_ReadInt($f, "TaskbarAutoHide", "autohide_show_delay", 0, 0, 5000)
    $__g_Cfg_bAutoHideUseFade          = __Cfg_ReadBool($f, "TaskbarAutoHide", "autohide_use_fade", True)
    $__g_Cfg_iAutoHideFadeDuration     = __Cfg_ReadInt($f, "TaskbarAutoHide", "autohide_fade_duration", 80, 10, 1000)
    $__g_Cfg_bAutoHideSyncDesktopList  = __Cfg_ReadBool($f, "TaskbarAutoHide", "autohide_sync_desktop_list", True)
    $__g_Cfg_bAutoHideSyncWindowList   = __Cfg_ReadBool($f, "TaskbarAutoHide", "autohide_sync_window_list", False)
    $__g_Cfg_iAutoHideHiddenThreshold  = __Cfg_ReadInt($f, "TaskbarAutoHide", "autohide_hidden_threshold", 4, 1, 20)
    $__g_Cfg_iAutoHideRecheckCount     = __Cfg_ReadInt($f, "TaskbarAutoHide", "autohide_recheck_count", 10, 1, 100)
    $__g_Cfg_bAutoHideSkipIfDialog     = __Cfg_ReadBool($f, "TaskbarAutoHide", "autohide_skip_if_dialog", True)

    ; [Notifications]
    $__g_Cfg_bNotificationsEnabled   = __Cfg_ReadBool($f, "Notifications", "notifications_enabled", True)
    $__g_Cfg_bNotifyWindowMoved      = __Cfg_ReadBool($f, "Notifications", "notify_window_moved", False)
    $__g_Cfg_bNotifyDesktopCreated   = __Cfg_ReadBool($f, "Notifications", "notify_desktop_created", False)
    $__g_Cfg_bNotifyDesktopDeleted   = __Cfg_ReadBool($f, "Notifications", "notify_desktop_deleted", False)
    $__g_Cfg_bNotifyWindowPinned     = __Cfg_ReadBool($f, "Notifications", "notify_window_pinned", False)
    $__g_Cfg_bNotifyWindowUnpinned   = __Cfg_ReadBool($f, "Notifications", "notify_window_unpinned", False)
    $__g_Cfg_bNotifyExplorerRecovery = __Cfg_ReadBool($f, "Notifications", "notify_explorer_recovery", False)
    $__g_Cfg_bNotifyExplorerCrash    = __Cfg_ReadBool($f, "Notifications", "notify_explorer_crash", False)
    $__g_Cfg_sWindowListScope        = __Cfg_ReadEnum($f, "WindowList", "window_list_scope", "current", "current|all")

    ; [Notifications] OSD
    $__g_Cfg_bOsdEnabled             = __Cfg_ReadBool($f, "Notifications", "osd_enabled", False)
    $__g_Cfg_bOsdShowName            = __Cfg_ReadBool($f, "Notifications", "osd_show_name", True)
    $__g_Cfg_bOsdShowNumber          = __Cfg_ReadBool($f, "Notifications", "osd_show_number", True)
    $__g_Cfg_iOsdDuration            = __Cfg_ReadInt($f, "Notifications", "osd_duration", 1500, 500, 5000)
    $__g_Cfg_sOsdPosition            = __Cfg_ReadEnum($f, "Notifications", "osd_position", "top-center", _
        "top-left|top-center|top-right|middle-left|middle-center|middle-right|bottom-left|bottom-center|bottom-right|widget")
    $__g_Cfg_iOsdFontSize            = __Cfg_ReadInt($f, "Notifications", "osd_font_size", 14, 8, 48)
    $__g_Cfg_iOsdOpacity             = __Cfg_ReadInt($f, "Notifications", "osd_opacity", 220, 0, 255)
    $__g_Cfg_sOsdFormat              = IniRead($f, "Notifications", "osd_format", "{number}: {name}")

    ; [Rules]
    $__g_Cfg_bRulesEnabled           = __Cfg_ReadBool($f, "Rules", "rules_enabled", False)
    $__g_Cfg_iRulesPollInterval      = __Cfg_ReadInt($f, "Rules", "rules_poll_interval", 2000, 500, 30000)

    ; [Session]
    $__g_Cfg_bSessionRestoreEnabled  = __Cfg_ReadBool($f, "Session", "session_restore_enabled", False)

    ; [Hooks]
    $__g_Cfg_bHooksEnabled           = __Cfg_ReadBool($f, "Hooks", "hooks_enabled", False)
    $__g_Cfg_iHooksTimeout           = __Cfg_ReadInt($f, "Hooks", "hooks_timeout", 10000, 1000, 300000)

    ; [Profiles]
    $__g_Cfg_bProfilesEnabled        = __Cfg_ReadBool($f, "Profiles", "profiles_enabled", False)

    ; [Carousel]
    $__g_Cfg_bCarouselEnabled      = __Cfg_ReadBool($f, "Carousel", "carousel_enabled", False)
    $__g_Cfg_iCarouselInterval     = __Cfg_ReadInt($f, "Carousel", "carousel_interval", 20000, 3000, 300000)
    $__g_Cfg_bCarouselShowInMenu   = __Cfg_ReadBool($f, "Carousel", "carousel_show_in_menu", True)
    $__g_Cfg_bNotifyCarouselToggle = __Cfg_ReadBool($f, "Carousel", "notify_carousel_toggle", True)

    ; [Tray]
    $__g_Cfg_sTrayLeftClick          = __Cfg_ReadEnum($f, "Tray", "tray_left_click", "menu", "menu|toggle_list|next_desktop|nothing")
    $__g_Cfg_sTrayDoubleClick        = __Cfg_ReadEnum($f, "Tray", "tray_double_click", "settings", "settings|toggle_list|menu|nothing")
    $__g_Cfg_sTrayMiddleClick        = __Cfg_ReadEnum($f, "Tray", "tray_middle_click", "toggle_list", "toggle_list|add_desktop|toggle_carousel|nothing")
    $__g_Cfg_bTrayTooltipShowLabel   = __Cfg_ReadBool($f, "Tray", "tray_tooltip_show_label", True)
    $__g_Cfg_bTrayTooltipShowCount   = __Cfg_ReadBool($f, "Tray", "tray_tooltip_show_count", False)
    $__g_Cfg_bTrayMenuShowList       = __Cfg_ReadBool($f, "Tray", "tray_menu_show_list", True)
    $__g_Cfg_bTrayMenuShowEdit       = __Cfg_ReadBool($f, "Tray", "tray_menu_show_edit", True)
    $__g_Cfg_bTrayMenuShowAdd        = __Cfg_ReadBool($f, "Tray", "tray_menu_show_add", True)
    $__g_Cfg_bTrayMenuShowDelete     = __Cfg_ReadBool($f, "Tray", "tray_menu_show_delete", True)
    $__g_Cfg_bTrayMenuShowDesktopSub = __Cfg_ReadBool($f, "Tray", "tray_menu_show_desktop_submenu", False)
    $__g_Cfg_bTrayMenuShowMoveWindow = __Cfg_ReadBool($f, "Tray", "tray_menu_show_move_window", False)
    $__g_Cfg_bTrayNotifySwitch       = __Cfg_ReadBool($f, "Tray", "tray_notify_desktop_switch", False)
    $__g_Cfg_iTrayBalloonDuration    = __Cfg_ReadInt($f, "Tray", "tray_balloon_duration", 2000, 500, 10000)
    $__g_Cfg_bTrayCloseToTray        = __Cfg_ReadBool($f, "Tray", "tray_close_to_tray", False)
EndFunc

; Name:        _Cfg_Save
; Description: Writes all in-memory values to the INI file
Func _Cfg_Save()
    ; Debounce: skip if saved less than 500ms ago (skip check on first call)
    If $__g_Cfg_hSaveTimer <> 0 And TimerDiff($__g_Cfg_hSaveTimer) < $__g_Cfg_SAVE_DEBOUNCE Then Return True
    $__g_Cfg_hSaveTimer = TimerInit()
    ; Write to temp file first, then rename for atomic save (prevents corruption on crash)
    Local $f = $__g_Cfg_sIniPath & ".tmp"
    If FileExists($f) Then FileDelete($f)
    ; Copy existing file as base (preserves sections we don't write)
    If FileExists($__g_Cfg_sIniPath) Then FileCopy($__g_Cfg_sIniPath, $f, 1)

    ; [General]
    IniWrite($f, "General", "language", $__g_Cfg_sLanguage)
    __Cfg_WriteBool($f, "General", "start_with_windows", $__g_Cfg_bStartWithWindows)
    __Cfg_WriteBool($f, "General", "wrap_navigation", $__g_Cfg_bWrapNavigation)
    __Cfg_WriteBool($f, "General", "auto_create_desktop", $__g_Cfg_bAutoCreateDesktop)
    IniWrite($f, "General", "number_padding", $__g_Cfg_iNumberPadding)
    IniWrite($f, "General", "widget_position", $__g_Cfg_sWidgetPosition)
    IniWrite($f, "General", "widget_offset_x", $__g_Cfg_iWidgetOffsetX)
    IniWrite($f, "General", "widget_offset_y", $__g_Cfg_iWidgetOffsetY)
    IniWrite($f, "General", "widget_width", $__g_Cfg_iWidgetWidth)
    IniWrite($f, "General", "widget_height", $__g_Cfg_iWidgetHeight)
    __Cfg_WriteBool($f, "General", "widget_drag_enabled", $__g_Cfg_bWidgetDragEnabled)
    __Cfg_WriteBool($f, "General", "widget_color_bar", $__g_Cfg_bWidgetColorBar)
    IniWrite($f, "General", "widget_color_bar_height", $__g_Cfg_iWidgetColorBarH)
    __Cfg_WriteBool($f, "General", "tray_icon_mode", $__g_Cfg_bTrayIconMode)
    __Cfg_WriteBool($f, "General", "quick_access_enabled", $__g_Cfg_bQuickAccessEnabled)
    __Cfg_WriteBool($f, "General", "start_minimized", $__g_Cfg_bStartMinimized)
    __Cfg_WriteBool($f, "General", "list_keyboard_nav", $__g_Cfg_bListKeyboardNav)
    __Cfg_WriteBool($f, "General", "auto_update_enabled", $__g_Cfg_bAutoUpdateEnabled)
    IniWrite($f, "General", "auto_update_interval", $__g_Cfg_iAutoUpdateInterval)
    __Cfg_WriteBool($f, "General", "singleton_enabled", $__g_Cfg_bSingletonEnabled)
    IniWrite($f, "General", "min_desktops", $__g_Cfg_iMinDesktops)
    IniWrite($f, "General", "max_desktops", $__g_Cfg_iMaxDesktops)
    __Cfg_WriteBool($f, "General", "taskbar_focus_trick", $__g_Cfg_bTaskbarFocusTrick)
    __Cfg_WriteBool($f, "General", "auto_focus_after_switch", $__g_Cfg_bAutoFocusAfterSwitch)
    __Cfg_WriteBool($f, "General", "capslock_modifier", $__g_Cfg_bCapslockModifier)
    __Cfg_WriteBool($f, "General", "disable_win_widgets", $__g_Cfg_bDisableWinWidgets)
    __Cfg_WriteBool($f, "General", "desktop_list_pinned", $__g_Cfg_bDesktopListPinned)

    ; [Updates]
    __Cfg_WriteBool($f, "Updates", "update_check_on_startup", $__g_Cfg_bUpdateCheckOnStartup)
    IniWrite($f, "Updates", "update_check_days", $__g_Cfg_iUpdateCheckDays)

    ; [Display]
    __Cfg_WriteBool($f, "Display", "show_count", $__g_Cfg_bShowCount)
    IniWrite($f, "Display", "count_font_size", $__g_Cfg_iCountFontSize)
    IniWrite($f, "Display", "theme_alpha_main", $__g_Cfg_iThemeAlphaMain)
    IniWrite($f, "Display", "theme", $__g_Cfg_sTheme)
    __Cfg_WriteBool($f, "Display", "thumbnails_enabled", $__g_Cfg_bThumbnailsEnabled)
    IniWrite($f, "Display", "thumbnail_width", $__g_Cfg_iThumbnailWidth)
    IniWrite($f, "Display", "thumbnail_height", $__g_Cfg_iThumbnailHeight)
    IniWrite($f, "Display", "list_font_name", $__g_Cfg_sListFontName)
    IniWrite($f, "Display", "list_font_size", $__g_Cfg_iListFontSize)
    __Cfg_WriteBool($f, "Display", "list_scrollable", $__g_Cfg_bListScrollable)
    IniWrite($f, "Display", "list_max_visible", $__g_Cfg_iListMaxVisible)
    IniWrite($f, "Display", "list_scroll_speed", $__g_Cfg_iListScrollSpeed)
    IniWrite($f, "Display", "tooltip_font_size", $__g_Cfg_iTooltipFontSize)
    __Cfg_WriteBool($f, "Display", "thumbnail_use_screenshot", $__g_Cfg_bThumbnailUseScreenshot)
    IniWrite($f, "Display", "thumbnail_cache_ttl", $__g_Cfg_iThumbnailCacheTTL)
    __Cfg_WriteBool($f, "Display", "desktop_list_show_numbers", $__g_Cfg_bDesktopListShowNumbers)

    ; [Scroll]
    __Cfg_WriteBool($f, "Scroll", "scroll_enabled", $__g_Cfg_bScrollEnabled)
    IniWrite($f, "Scroll", "scroll_direction", $__g_Cfg_sScrollDirection)
    __Cfg_WriteBool($f, "Scroll", "scroll_wrap", $__g_Cfg_bScrollWrap)
    __Cfg_WriteBool($f, "Scroll", "list_scroll_enabled", $__g_Cfg_bListScrollEnabled)
    IniWrite($f, "Scroll", "list_scroll_action", $__g_Cfg_sListScrollAction)

    ; [Hotkeys]
    IniWrite($f, "Hotkeys", "hotkey_desktop_count", $__g_Cfg_iHotkeyDesktopCount)
    IniWrite($f, "Hotkeys", "hotkey_next", $__g_Cfg_sHotkeyNext)
    IniWrite($f, "Hotkeys", "hotkey_prev", $__g_Cfg_sHotkeyPrev)
    Local $i
    For $i = 1 To 9
        IniWrite($f, "Hotkeys", "hotkey_desktop_" & $i, $__g_Cfg_sHotkeyDesktop[$i])
    Next
    IniWrite($f, "Hotkeys", "hotkey_toggle_list", $__g_Cfg_sHotkeyToggleList)
    IniWrite($f, "Hotkeys", "hotkey_toggle_last", $__g_Cfg_sHotkeyToggleLast)
    IniWrite($f, "Hotkeys", "hotkey_move_follow_next", $__g_Cfg_sHotkeyMoveFollowNext)
    IniWrite($f, "Hotkeys", "hotkey_move_follow_prev", $__g_Cfg_sHotkeyMoveFollowPrev)
    IniWrite($f, "Hotkeys", "hotkey_move_next", $__g_Cfg_sHotkeyMoveNext)
    IniWrite($f, "Hotkeys", "hotkey_move_prev", $__g_Cfg_sHotkeyMovePrev)
    IniWrite($f, "Hotkeys", "hotkey_send_new_desktop", $__g_Cfg_sHotkeySendNewDesktop)
    IniWrite($f, "Hotkeys", "hotkey_pin_window", $__g_Cfg_sHotkeyPinWindow)
    IniWrite($f, "Hotkeys", "hotkey_toggle_window_list", $__g_Cfg_sHotkeyToggleWindowList)
    IniWrite($f, "Hotkeys", "hotkey_open_settings", $__g_Cfg_sHotkeyOpenSettings)
    __Cfg_WriteBool($f, "Hotkeys", "hotkeys_enabled", $__g_Cfg_bHotkeysEnabled)
    IniWrite($f, "Hotkeys", "hotkey_add_desktop", $__g_Cfg_sHotkeyAddDesktop)
    IniWrite($f, "Hotkeys", "hotkey_delete_desktop", $__g_Cfg_sHotkeyDeleteDesktop)
    IniWrite($f, "Hotkeys", "hotkey_rename_desktop", $__g_Cfg_sHotkeyRenameDesktop)
    IniWrite($f, "Hotkeys", "hotkey_close_window", $__g_Cfg_sHotkeyCloseWindow)
    IniWrite($f, "Hotkeys", "hotkey_minimize_window", $__g_Cfg_sHotkeyMinimizeWindow)
    IniWrite($f, "Hotkeys", "hotkey_toggle_carousel", $__g_Cfg_sHotkeyToggleCarousel)
    IniWrite($f, "Hotkeys", "hotkey_task_view", $__g_Cfg_sHotkeyTaskView)

    ; [Behavior]
    __Cfg_WriteBool($f, "Behavior", "confirm_delete", $__g_Cfg_bConfirmDelete)
    __Cfg_WriteBool($f, "Behavior", "middle_click_delete", $__g_Cfg_bMiddleClickDelete)
    __Cfg_WriteBool($f, "Behavior", "move_window_enabled", $__g_Cfg_bMoveWindowEnabled)
    IniWrite($f, "Behavior", "peek_bounce_delay", $__g_Cfg_iPeekBounceDelay)
    IniWrite($f, "Behavior", "auto_hide_timeout", $__g_Cfg_iAutoHideTimeout)
    IniWrite($f, "Behavior", "topmost_interval", $__g_Cfg_iTopmostInterval)
    IniWrite($f, "Behavior", "cm_auto_hide_delay", $__g_Cfg_iCmAutoHideDelay)
    __Cfg_WriteBool($f, "Behavior", "config_watcher_enabled", $__g_Cfg_bConfigWatcherEnabled)
    IniWrite($f, "Behavior", "config_watcher_interval", $__g_Cfg_iConfigWatcherInterval)
    IniWrite($f, "Behavior", "count_cache_ttl", $__g_Cfg_iCountCacheTTL)
    IniWrite($f, "Behavior", "name_sync_interval", $__g_Cfg_iNameSyncInterval)
    IniWrite($f, "Behavior", "dll_check_interval", $__g_Cfg_iDllCheckInterval)
    IniWrite($f, "Behavior", "update_poll_interval", $__g_Cfg_iUpdatePollInterval)
    __Cfg_WriteBool($f, "Behavior", "confirm_quit", $__g_Cfg_bConfirmQuit)
    __Cfg_WriteBool($f, "Behavior", "confirm_restart", $__g_Cfg_bConfirmRestart)
    __Cfg_WriteBool($f, "Behavior", "debug_mode", $__g_Cfg_bDebugMode)

    ; [Logging]
    ; [Animations]
    __Cfg_WriteBool($f, "Animations", "animations_enabled", $__g_Cfg_bAnimationsEnabled)
    IniWrite($f, "Animations", "fade_in_duration", $__g_Cfg_iFadeInDuration)
    IniWrite($f, "Animations", "fade_out_duration", $__g_Cfg_iFadeOutDuration)
    IniWrite($f, "Animations", "fade_step", $__g_Cfg_iFadeStep)
    IniWrite($f, "Animations", "toast_fade_out_duration", $__g_Cfg_iToastFadeOutMs)
    IniWrite($f, "Animations", "fade_sleep_ms", $__g_Cfg_iFadeSleepMs)
    __Cfg_WriteBool($f, "Animations", "anim_list", $__g_Cfg_bAnimList)
    __Cfg_WriteBool($f, "Animations", "anim_menus", $__g_Cfg_bAnimMenus)
    __Cfg_WriteBool($f, "Animations", "anim_dialogs", $__g_Cfg_bAnimDialogs)
    __Cfg_WriteBool($f, "Animations", "anim_toasts", $__g_Cfg_bAnimToasts)
    __Cfg_WriteBool($f, "Animations", "anim_widget", $__g_Cfg_bAnimWidget)
    IniWrite($f, "Animations", "anim_hover_speed", $__g_Cfg_iAnimHoverSpeed)
    IniWrite($f, "Animations", "toast_position", $__g_Cfg_sToastPosition)

    __Cfg_WriteBool($f, "Logging", "logging_enabled", $__g_Cfg_bLoggingEnabled)
    IniWrite($f, "Logging", "log_folder", $__g_Cfg_sLogFolder)
    IniWrite($f, "Logging", "log_level", $__g_Cfg_sLogLevel)
    IniWrite($f, "Logging", "log_max_size_mb", $__g_Cfg_iLogMaxSizeMB)
    IniWrite($f, "Logging", "log_rotate_count", $__g_Cfg_iLogRotateCount)
    __Cfg_WriteBool($f, "Logging", "log_compress_old", $__g_Cfg_bLogCompressOld)
    __Cfg_WriteBool($f, "Logging", "log_include_pid", $__g_Cfg_bLogIncludePID)
    __Cfg_WriteBool($f, "Logging", "log_include_func", $__g_Cfg_bLogIncludeFunc)
    IniWrite($f, "Logging", "log_date_format", $__g_Cfg_sLogDateFormat)
    __Cfg_WriteBool($f, "Logging", "log_flush_immediate", $__g_Cfg_bLogFlushImmediate)

    ; [DesktopColors]
    __Cfg_WriteBool($f, "DesktopColors", "desktop_colors_enabled", $__g_Cfg_bDesktopColorsEnabled)
    For $i = 1 To $__g_Cfg_MAX_DESKTOPS
        If $__g_Cfg_aDesktopColors[$i] <> 0 Then
            IniWrite($f, "DesktopColors", "desktop_" & $i & "_color", "0x" & Hex($__g_Cfg_aDesktopColors[$i], 6))
        EndIf
    Next

    ; [Wallpaper]
    __Cfg_WriteBool($f, "Wallpaper", "wallpaper_enabled", $__g_Cfg_bWallpaperEnabled)
    IniWrite($f, "Wallpaper", "wallpaper_change_delay", $__g_Cfg_iWallpaperChangeDelay)
    For $i = 1 To $__g_Cfg_MAX_DESKTOPS
        If $__g_Cfg_aDesktopWallpaper[$i] <> "" Then
            IniWrite($f, "Wallpaper", "desktop_" & $i & "_wallpaper", $__g_Cfg_aDesktopWallpaper[$i])
        EndIf
    Next

    ; [Pinning]
    __Cfg_WriteBool($f, "Pinning", "pinning_enabled", $__g_Cfg_bPinningEnabled)

    ; [WindowList]
    __Cfg_WriteBool($f, "WindowList", "window_list_enabled", $__g_Cfg_bWindowListEnabled)
    IniWrite($f, "WindowList", "window_list_position", $__g_Cfg_sWindowListPosition)
    IniWrite($f, "WindowList", "window_list_width", $__g_Cfg_iWindowListWidth)
    IniWrite($f, "WindowList", "window_list_max_visible", $__g_Cfg_iWindowListMaxVisible)
    __Cfg_WriteBool($f, "WindowList", "window_list_show_icons", $__g_Cfg_bWindowListShowIcons)
    __Cfg_WriteBool($f, "WindowList", "window_list_search", $__g_Cfg_bWindowListSearch)
    __Cfg_WriteBool($f, "WindowList", "window_list_auto_refresh", $__g_Cfg_bWindowListAutoRefresh)
    IniWrite($f, "WindowList", "window_list_refresh_interval", $__g_Cfg_iWindowListRefreshInterval)

    ; [ExplorerMonitor]
    __Cfg_WriteBool($f, "ExplorerMonitor", "explorer_monitor_enabled", $__g_Cfg_bExplorerMonitorEnabled)
    IniWrite($f, "ExplorerMonitor", "shell_process_name", $__g_Cfg_sShellProcessName)
    IniWrite($f, "ExplorerMonitor", "explorer_check_interval", $__g_Cfg_iExplorerCheckInterval)
    IniWrite($f, "ExplorerMonitor", "monitor_max_retries", $__g_Cfg_iMonitorMaxRetries)
    IniWrite($f, "ExplorerMonitor", "monitor_retry_delay", $__g_Cfg_iMonitorRetryDelay)
    __Cfg_WriteBool($f, "ExplorerMonitor", "monitor_exp_backoff", $__g_Cfg_bMonitorExpBackoff)
    IniWrite($f, "ExplorerMonitor", "monitor_max_retry_delay", $__g_Cfg_iMonitorMaxRetryDelay)
    __Cfg_WriteBool($f, "ExplorerMonitor", "monitor_auto_restart", $__g_Cfg_bMonitorAutoRestart)
    IniWrite($f, "ExplorerMonitor", "monitor_restart_delay", $__g_Cfg_iMonitorRestartDelay)
    __Cfg_WriteBool($f, "ExplorerMonitor", "explorer_notify_recovery", $__g_Cfg_bExplorerNotifyRecovery)

    ; [TaskbarAutoHide]
    __Cfg_WriteBool($f, "TaskbarAutoHide", "autohide_sync_enabled", $__g_Cfg_bAutoHideSyncEnabled)
    IniWrite($f, "TaskbarAutoHide", "autohide_poll_interval", $__g_Cfg_iAutoHidePollInterval)
    IniWrite($f, "TaskbarAutoHide", "autohide_hide_delay", $__g_Cfg_iAutoHideHideDelay)
    IniWrite($f, "TaskbarAutoHide", "autohide_show_delay", $__g_Cfg_iAutoHideShowDelay)
    __Cfg_WriteBool($f, "TaskbarAutoHide", "autohide_use_fade", $__g_Cfg_bAutoHideUseFade)
    IniWrite($f, "TaskbarAutoHide", "autohide_fade_duration", $__g_Cfg_iAutoHideFadeDuration)
    __Cfg_WriteBool($f, "TaskbarAutoHide", "autohide_sync_desktop_list", $__g_Cfg_bAutoHideSyncDesktopList)
    __Cfg_WriteBool($f, "TaskbarAutoHide", "autohide_sync_window_list", $__g_Cfg_bAutoHideSyncWindowList)
    IniWrite($f, "TaskbarAutoHide", "autohide_hidden_threshold", $__g_Cfg_iAutoHideHiddenThreshold)
    IniWrite($f, "TaskbarAutoHide", "autohide_recheck_count", $__g_Cfg_iAutoHideRecheckCount)
    __Cfg_WriteBool($f, "TaskbarAutoHide", "autohide_skip_if_dialog", $__g_Cfg_bAutoHideSkipIfDialog)

    ; [Notifications]
    __Cfg_WriteBool($f, "Notifications", "notifications_enabled", $__g_Cfg_bNotificationsEnabled)
    __Cfg_WriteBool($f, "Notifications", "notify_window_moved", $__g_Cfg_bNotifyWindowMoved)
    __Cfg_WriteBool($f, "Notifications", "notify_desktop_created", $__g_Cfg_bNotifyDesktopCreated)
    __Cfg_WriteBool($f, "Notifications", "notify_desktop_deleted", $__g_Cfg_bNotifyDesktopDeleted)
    __Cfg_WriteBool($f, "Notifications", "notify_window_pinned", $__g_Cfg_bNotifyWindowPinned)
    __Cfg_WriteBool($f, "Notifications", "notify_window_unpinned", $__g_Cfg_bNotifyWindowUnpinned)
    __Cfg_WriteBool($f, "Notifications", "notify_explorer_recovery", $__g_Cfg_bNotifyExplorerRecovery)
    __Cfg_WriteBool($f, "Notifications", "notify_explorer_crash", $__g_Cfg_bNotifyExplorerCrash)
    IniWrite($f, "WindowList", "window_list_scope", $__g_Cfg_sWindowListScope)

    ; [Notifications] OSD
    __Cfg_WriteBool($f, "Notifications", "osd_enabled", $__g_Cfg_bOsdEnabled)
    __Cfg_WriteBool($f, "Notifications", "osd_show_name", $__g_Cfg_bOsdShowName)
    __Cfg_WriteBool($f, "Notifications", "osd_show_number", $__g_Cfg_bOsdShowNumber)
    IniWrite($f, "Notifications", "osd_duration", $__g_Cfg_iOsdDuration)
    IniWrite($f, "Notifications", "osd_position", $__g_Cfg_sOsdPosition)
    IniWrite($f, "Notifications", "osd_font_size", $__g_Cfg_iOsdFontSize)
    IniWrite($f, "Notifications", "osd_opacity", $__g_Cfg_iOsdOpacity)
    IniWrite($f, "Notifications", "osd_format", $__g_Cfg_sOsdFormat)

    ; [Rules]
    __Cfg_WriteBool($f, "Rules", "rules_enabled", $__g_Cfg_bRulesEnabled)
    IniWrite($f, "Rules", "rules_poll_interval", $__g_Cfg_iRulesPollInterval)

    ; [Session]
    __Cfg_WriteBool($f, "Session", "session_restore_enabled", $__g_Cfg_bSessionRestoreEnabled)

    ; [Hooks]
    __Cfg_WriteBool($f, "Hooks", "hooks_enabled", $__g_Cfg_bHooksEnabled)
    IniWrite($f, "Hooks", "hooks_timeout", $__g_Cfg_iHooksTimeout)

    ; [Profiles]
    __Cfg_WriteBool($f, "Profiles", "profiles_enabled", $__g_Cfg_bProfilesEnabled)

    ; [Carousel]
    __Cfg_WriteBool($f, "Carousel", "carousel_enabled", $__g_Cfg_bCarouselEnabled)
    IniWrite($f, "Carousel", "carousel_interval", $__g_Cfg_iCarouselInterval)
    __Cfg_WriteBool($f, "Carousel", "carousel_show_in_menu", $__g_Cfg_bCarouselShowInMenu)
    __Cfg_WriteBool($f, "Carousel", "notify_carousel_toggle", $__g_Cfg_bNotifyCarouselToggle)

    ; [Tray]
    IniWrite($f, "Tray", "tray_left_click", $__g_Cfg_sTrayLeftClick)
    IniWrite($f, "Tray", "tray_double_click", $__g_Cfg_sTrayDoubleClick)
    IniWrite($f, "Tray", "tray_middle_click", $__g_Cfg_sTrayMiddleClick)
    __Cfg_WriteBool($f, "Tray", "tray_tooltip_show_label", $__g_Cfg_bTrayTooltipShowLabel)
    __Cfg_WriteBool($f, "Tray", "tray_tooltip_show_count", $__g_Cfg_bTrayTooltipShowCount)
    __Cfg_WriteBool($f, "Tray", "tray_menu_show_list", $__g_Cfg_bTrayMenuShowList)
    __Cfg_WriteBool($f, "Tray", "tray_menu_show_edit", $__g_Cfg_bTrayMenuShowEdit)
    __Cfg_WriteBool($f, "Tray", "tray_menu_show_add", $__g_Cfg_bTrayMenuShowAdd)
    __Cfg_WriteBool($f, "Tray", "tray_menu_show_delete", $__g_Cfg_bTrayMenuShowDelete)
    __Cfg_WriteBool($f, "Tray", "tray_menu_show_desktop_submenu", $__g_Cfg_bTrayMenuShowDesktopSub)
    __Cfg_WriteBool($f, "Tray", "tray_menu_show_move_window", $__g_Cfg_bTrayMenuShowMoveWindow)
    __Cfg_WriteBool($f, "Tray", "tray_notify_desktop_switch", $__g_Cfg_bTrayNotifySwitch)
    IniWrite($f, "Tray", "tray_balloon_duration", $__g_Cfg_iTrayBalloonDuration)
    __Cfg_WriteBool($f, "Tray", "tray_close_to_tray", $__g_Cfg_bTrayCloseToTray)

    ; Verify write succeeded before replacing original (check multiple sections)
    Local $sVerify1 = IniRead($f, "General", "wrap_navigation", "")
    Local $sVerify2 = IniRead($f, "General", "language", "")
    Local $sVerify3 = IniRead($f, "Behavior", "confirm_delete", "")
    If $sVerify1 = "" Or $sVerify2 = "" Or $sVerify3 = "" Then
        _Log_Error("Config save verification failed: temp file appears corrupt")
        FileDelete($f)
        Return False
    EndIf
    ; Atomic replace: FileMove with overwrite flag (no delete gap)
    If Not FileMove($f, $__g_Cfg_sIniPath, 1) Then
        _Log_Error("Config save failed: could not replace INI file")
        FileDelete($f)
        Return False
    EndIf
    Return True
EndFunc

; Name:        _Cfg_WriteDefaults
; Description: Writes default values for any missing keys (preserves existing user values)
Func _Cfg_WriteDefaults()
    Local $f = $__g_Cfg_sIniPath

    __Cfg_DefaultVal($f, "General", "language", "en-US")
    __Cfg_DefaultBool($f, "General", "start_with_windows", False)
    __Cfg_DefaultBool($f, "General", "wrap_navigation", True)
    __Cfg_DefaultBool($f, "General", "auto_create_desktop", False)
    __Cfg_DefaultVal($f, "General", "number_padding", 2)
    __Cfg_DefaultVal($f, "General", "widget_position", "bottom-left")
    __Cfg_DefaultVal($f, "General", "widget_offset_x", 0)
    __Cfg_DefaultVal($f, "General", "widget_offset_y", 0)
    __Cfg_DefaultVal($f, "General", "widget_width", 0)
    __Cfg_DefaultVal($f, "General", "widget_height", 0)
    __Cfg_DefaultBool($f, "General", "widget_drag_enabled", False)
    __Cfg_DefaultBool($f, "General", "widget_color_bar", False)
    __Cfg_DefaultVal($f, "General", "widget_color_bar_height", 2)
    __Cfg_DefaultBool($f, "General", "tray_icon_mode", False)
    __Cfg_DefaultBool($f, "General", "quick_access_enabled", False)
    __Cfg_DefaultBool($f, "General", "start_minimized", False)
    __Cfg_DefaultBool($f, "General", "list_keyboard_nav", False)
    __Cfg_DefaultBool($f, "General", "auto_update_enabled", False)
    __Cfg_DefaultVal($f, "General", "auto_update_interval", 168)
    __Cfg_DefaultBool($f, "General", "singleton_enabled", True)
    __Cfg_DefaultVal($f, "General", "min_desktops", 0)
    __Cfg_DefaultVal($f, "General", "max_desktops", 0)
    __Cfg_DefaultBool($f, "General", "taskbar_focus_trick", False)
    __Cfg_DefaultBool($f, "General", "auto_focus_after_switch", False)
    __Cfg_DefaultBool($f, "General", "capslock_modifier", False)
    __Cfg_DefaultBool($f, "General", "disable_win_widgets", False)
    __Cfg_DefaultBool($f, "General", "desktop_list_pinned", False)

    __Cfg_DefaultBool($f, "Updates", "update_check_on_startup", False)
    __Cfg_DefaultVal($f, "Updates", "update_check_days", 7)

    __Cfg_DefaultBool($f, "Display", "show_count", False)
    __Cfg_DefaultVal($f, "Display", "count_font_size", 7)
    __Cfg_DefaultVal($f, "Display", "theme_alpha_main", 235)
    __Cfg_DefaultVal($f, "Display", "theme", "dark")
    __Cfg_DefaultBool($f, "Display", "thumbnails_enabled", False)
    __Cfg_DefaultVal($f, "Display", "thumbnail_width", 160)
    __Cfg_DefaultVal($f, "Display", "thumbnail_height", 90)
    __Cfg_DefaultVal($f, "Display", "list_font_name", "")
    __Cfg_DefaultVal($f, "Display", "list_font_size", 8)
    __Cfg_DefaultBool($f, "Display", "list_scrollable", False)
    __Cfg_DefaultVal($f, "Display", "list_max_visible", 10)
    __Cfg_DefaultVal($f, "Display", "list_scroll_speed", 1)
    __Cfg_DefaultVal($f, "Display", "tooltip_font_size", 8)
    __Cfg_DefaultBool($f, "Display", "thumbnail_use_screenshot", False)
    __Cfg_DefaultVal($f, "Display", "thumbnail_cache_ttl", 30)
    __Cfg_DefaultBool($f, "Display", "desktop_list_show_numbers", True)

    __Cfg_DefaultBool($f, "Scroll", "scroll_enabled", False)
    __Cfg_DefaultVal($f, "Scroll", "scroll_direction", "normal")
    __Cfg_DefaultBool($f, "Scroll", "scroll_wrap", True)
    __Cfg_DefaultBool($f, "Scroll", "list_scroll_enabled", False)
    __Cfg_DefaultVal($f, "Scroll", "list_scroll_action", "switch")

    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_desktop_count", 9)
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_next", "^!{RIGHT}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_prev", "^!{LEFT}")
    Local $i
    For $i = 1 To 9
        __Cfg_DefaultVal($f, "Hotkeys", "hotkey_desktop_" & $i, "")
    Next
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_toggle_list", "^!{DOWN}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_toggle_last", "^!{TAB}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_move_follow_next", "^!+{RIGHT}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_move_follow_prev", "^!+{LEFT}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_move_next", "^#{RIGHT}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_move_prev", "^#{LEFT}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_send_new_desktop", "^!n")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_pin_window", "^!p")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_toggle_window_list", "^!w")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_open_settings", "^!s")
    __Cfg_DefaultBool($f, "Hotkeys", "hotkeys_enabled", True)
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_add_desktop", "^!{INSERT}")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_delete_desktop", "")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_rename_desktop", "^!r")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_close_window", "")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_minimize_window", "")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_toggle_carousel", "")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_task_view", "")

    __Cfg_DefaultBool($f, "Behavior", "confirm_delete", True)
    __Cfg_DefaultBool($f, "Behavior", "middle_click_delete", False)
    __Cfg_DefaultBool($f, "Behavior", "move_window_enabled", True)
    __Cfg_DefaultVal($f, "Behavior", "peek_bounce_delay", 500)
    __Cfg_DefaultVal($f, "Behavior", "auto_hide_timeout", 3000)
    __Cfg_DefaultVal($f, "Behavior", "topmost_interval", 300)
    __Cfg_DefaultVal($f, "Behavior", "cm_auto_hide_delay", 500)
    __Cfg_DefaultBool($f, "Behavior", "config_watcher_enabled", False)
    __Cfg_DefaultVal($f, "Behavior", "config_watcher_interval", 60000)
    __Cfg_DefaultVal($f, "Behavior", "count_cache_ttl", 1000)
    __Cfg_DefaultVal($f, "Behavior", "name_sync_interval", 2000)
    __Cfg_DefaultVal($f, "Behavior", "dll_check_interval", 30000)
    __Cfg_DefaultVal($f, "Behavior", "update_poll_interval", 500)
    __Cfg_DefaultBool($f, "Behavior", "confirm_quit", False)
    __Cfg_DefaultBool($f, "Behavior", "confirm_restart", False)
    __Cfg_DefaultBool($f, "Behavior", "debug_mode", False)

    __Cfg_DefaultBool($f, "Animations", "animations_enabled", True)
    __Cfg_DefaultVal($f, "Animations", "fade_in_duration", 80)
    __Cfg_DefaultVal($f, "Animations", "fade_out_duration", 80)
    __Cfg_DefaultVal($f, "Animations", "fade_step", 30)
    __Cfg_DefaultVal($f, "Animations", "toast_fade_out_duration", 300)
    __Cfg_DefaultVal($f, "Animations", "fade_sleep_ms", 8)
    __Cfg_DefaultBool($f, "Animations", "anim_list", True)
    __Cfg_DefaultBool($f, "Animations", "anim_menus", True)
    __Cfg_DefaultBool($f, "Animations", "anim_dialogs", True)
    __Cfg_DefaultBool($f, "Animations", "anim_toasts", True)
    __Cfg_DefaultBool($f, "Animations", "anim_widget", True)
    __Cfg_DefaultVal($f, "Animations", "anim_hover_speed", 0)
    __Cfg_DefaultVal($f, "Animations", "toast_position", "widget")

    __Cfg_DefaultBool($f, "Logging", "logging_enabled", False)
    __Cfg_DefaultVal($f, "Logging", "log_folder", "")
    __Cfg_DefaultVal($f, "Logging", "log_level", "info")
    __Cfg_DefaultVal($f, "Logging", "log_max_size_mb", 5)
    __Cfg_DefaultVal($f, "Logging", "log_rotate_count", 3)
    __Cfg_DefaultBool($f, "Logging", "log_compress_old", False)
    __Cfg_DefaultBool($f, "Logging", "log_include_pid", False)
    __Cfg_DefaultBool($f, "Logging", "log_include_func", False)
    __Cfg_DefaultVal($f, "Logging", "log_date_format", "iso")
    __Cfg_DefaultBool($f, "Logging", "log_flush_immediate", True)

    __Cfg_DefaultBool($f, "DesktopColors", "desktop_colors_enabled", False)
    Local $aDefColors[10] = [9, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    For $i = 1 To 9
        __Cfg_DefaultVal($f, "DesktopColors", "desktop_" & $i & "_color", "0x" & Hex($aDefColors[$i], 6))
    Next

    __Cfg_DefaultBool($f, "Wallpaper", "wallpaper_enabled", False)
    __Cfg_DefaultVal($f, "Wallpaper", "wallpaper_change_delay", 200)
    For $i = 1 To 9
        __Cfg_DefaultVal($f, "Wallpaper", "desktop_" & $i & "_wallpaper", "")
    Next

    __Cfg_DefaultBool($f, "Pinning", "pinning_enabled", False)

    __Cfg_DefaultBool($f, "WindowList", "window_list_enabled", False)
    __Cfg_DefaultVal($f, "WindowList", "window_list_position", "top-left")
    __Cfg_DefaultVal($f, "WindowList", "window_list_width", 280)
    __Cfg_DefaultVal($f, "WindowList", "window_list_max_visible", 15)
    __Cfg_DefaultBool($f, "WindowList", "window_list_show_icons", True)
    __Cfg_DefaultBool($f, "WindowList", "window_list_search", True)
    __Cfg_DefaultBool($f, "WindowList", "window_list_auto_refresh", True)
    __Cfg_DefaultVal($f, "WindowList", "window_list_refresh_interval", 1000)

    __Cfg_DefaultBool($f, "ExplorerMonitor", "explorer_monitor_enabled", False)
    __Cfg_DefaultVal($f, "ExplorerMonitor", "shell_process_name", "explorer.exe")
    __Cfg_DefaultVal($f, "ExplorerMonitor", "explorer_check_interval", 5000)
    __Cfg_DefaultVal($f, "ExplorerMonitor", "monitor_max_retries", 0)
    __Cfg_DefaultVal($f, "ExplorerMonitor", "monitor_retry_delay", 5000)
    __Cfg_DefaultBool($f, "ExplorerMonitor", "monitor_exp_backoff", True)
    __Cfg_DefaultVal($f, "ExplorerMonitor", "monitor_max_retry_delay", 60000)
    __Cfg_DefaultBool($f, "ExplorerMonitor", "monitor_auto_restart", False)
    __Cfg_DefaultVal($f, "ExplorerMonitor", "monitor_restart_delay", 2000)
    __Cfg_DefaultBool($f, "ExplorerMonitor", "explorer_notify_recovery", True)

    __Cfg_DefaultBool($f, "TaskbarAutoHide", "autohide_sync_enabled", False)
    __Cfg_DefaultVal($f, "TaskbarAutoHide", "autohide_poll_interval", 150)
    __Cfg_DefaultVal($f, "TaskbarAutoHide", "autohide_hide_delay", 200)
    __Cfg_DefaultVal($f, "TaskbarAutoHide", "autohide_show_delay", 0)
    __Cfg_DefaultBool($f, "TaskbarAutoHide", "autohide_use_fade", True)
    __Cfg_DefaultVal($f, "TaskbarAutoHide", "autohide_fade_duration", 80)
    __Cfg_DefaultBool($f, "TaskbarAutoHide", "autohide_sync_desktop_list", True)
    __Cfg_DefaultBool($f, "TaskbarAutoHide", "autohide_sync_window_list", False)
    __Cfg_DefaultVal($f, "TaskbarAutoHide", "autohide_hidden_threshold", 4)
    __Cfg_DefaultVal($f, "TaskbarAutoHide", "autohide_recheck_count", 10)
    __Cfg_DefaultBool($f, "TaskbarAutoHide", "autohide_skip_if_dialog", True)

    __Cfg_DefaultBool($f, "Notifications", "notifications_enabled", True)
    __Cfg_DefaultBool($f, "Notifications", "notify_window_moved", False)
    __Cfg_DefaultBool($f, "Notifications", "notify_desktop_created", False)
    __Cfg_DefaultBool($f, "Notifications", "notify_desktop_deleted", False)
    __Cfg_DefaultBool($f, "Notifications", "notify_window_pinned", False)
    __Cfg_DefaultBool($f, "Notifications", "notify_window_unpinned", False)
    __Cfg_DefaultBool($f, "Notifications", "notify_explorer_recovery", False)
    __Cfg_DefaultBool($f, "Notifications", "notify_explorer_crash", False)
    __Cfg_DefaultVal($f, "WindowList", "window_list_scope", "current")

    ; [Notifications] OSD
    __Cfg_DefaultBool($f, "Notifications", "osd_enabled", False)
    __Cfg_DefaultBool($f, "Notifications", "osd_show_name", True)
    __Cfg_DefaultBool($f, "Notifications", "osd_show_number", True)
    __Cfg_DefaultVal($f, "Notifications", "osd_duration", 1500)
    __Cfg_DefaultVal($f, "Notifications", "osd_position", "top-center")
    __Cfg_DefaultVal($f, "Notifications", "osd_font_size", 14)
    __Cfg_DefaultVal($f, "Notifications", "osd_opacity", 220)
    __Cfg_DefaultVal($f, "Notifications", "osd_format", "{number}: {name}")

    ; [Rules]
    __Cfg_DefaultBool($f, "Rules", "rules_enabled", False)
    __Cfg_DefaultVal($f, "Rules", "rules_poll_interval", 2000)

    ; [Session]
    __Cfg_DefaultBool($f, "Session", "session_restore_enabled", False)

    ; [Hooks]
    __Cfg_DefaultBool($f, "Hooks", "hooks_enabled", False)
    __Cfg_DefaultVal($f, "Hooks", "hooks_timeout", 10000)

    ; [Profiles]
    __Cfg_DefaultBool($f, "Profiles", "profiles_enabled", False)

    ; [Carousel]
    __Cfg_DefaultBool($f, "Carousel", "carousel_enabled", False)
    __Cfg_DefaultVal($f, "Carousel", "carousel_interval", 20000)
    __Cfg_DefaultBool($f, "Carousel", "carousel_show_in_menu", True)
    __Cfg_DefaultBool($f, "Carousel", "notify_carousel_toggle", True)

    ; [Tray]
    __Cfg_DefaultVal($f, "Tray", "tray_left_click", "menu")
    __Cfg_DefaultVal($f, "Tray", "tray_double_click", "settings")
    __Cfg_DefaultVal($f, "Tray", "tray_middle_click", "toggle_list")
    __Cfg_DefaultBool($f, "Tray", "tray_tooltip_show_label", True)
    __Cfg_DefaultBool($f, "Tray", "tray_tooltip_show_count", False)
    __Cfg_DefaultBool($f, "Tray", "tray_menu_show_list", True)
    __Cfg_DefaultBool($f, "Tray", "tray_menu_show_edit", True)
    __Cfg_DefaultBool($f, "Tray", "tray_menu_show_add", True)
    __Cfg_DefaultBool($f, "Tray", "tray_menu_show_delete", True)
    __Cfg_DefaultBool($f, "Tray", "tray_menu_show_desktop_submenu", False)
    __Cfg_DefaultBool($f, "Tray", "tray_menu_show_move_window", False)
    __Cfg_DefaultBool($f, "Tray", "tray_notify_desktop_switch", False)
    __Cfg_DefaultVal($f, "Tray", "tray_balloon_duration", 2000)
    __Cfg_DefaultBool($f, "Tray", "tray_close_to_tray", False)
EndFunc

; =============================================
; TYPED GETTERS
; =============================================

; [General]
Func _Cfg_GetLanguage()
    Return $__g_Cfg_sLanguage
EndFunc
Func _Cfg_SetLanguage($s)
    $__g_Cfg_sLanguage = $s
EndFunc
Func _Cfg_GetStartWithWindows()
    Return $__g_Cfg_bStartWithWindows
EndFunc
Func _Cfg_GetWrapNavigation()
    Return $__g_Cfg_bWrapNavigation
EndFunc
Func _Cfg_GetAutoCreateDesktop()
    Return $__g_Cfg_bAutoCreateDesktop
EndFunc
Func _Cfg_GetNumberPadding()
    Return $__g_Cfg_iNumberPadding
EndFunc
Func _Cfg_GetWidgetPosition()
    ; Normalize legacy values on read
    If $__g_Cfg_sWidgetPosition = "left" Then Return "bottom-left"
    If $__g_Cfg_sWidgetPosition = "center" Then Return "bottom-center"
    If $__g_Cfg_sWidgetPosition = "right" Then Return "bottom-right"
    Return $__g_Cfg_sWidgetPosition
EndFunc
Func _Cfg_GetWidgetOffsetX()
    Return $__g_Cfg_iWidgetOffsetX
EndFunc
Func _Cfg_GetWidgetDragEnabled()
    Return $__g_Cfg_bWidgetDragEnabled
EndFunc
Func _Cfg_GetWidgetColorBar()
    Return $__g_Cfg_bWidgetColorBar
EndFunc
Func _Cfg_GetWidgetColorBarHeight()
    Return $__g_Cfg_iWidgetColorBarH
EndFunc
Func _Cfg_GetTrayIconMode()
    Return $__g_Cfg_bTrayIconMode
EndFunc
Func _Cfg_GetQuickAccessEnabled()
    Return $__g_Cfg_bQuickAccessEnabled
EndFunc
Func _Cfg_GetStartMinimized()
    Return $__g_Cfg_bStartMinimized
EndFunc
Func _Cfg_GetListKeyboardNav()
    Return $__g_Cfg_bListKeyboardNav
EndFunc
Func _Cfg_GetAutoUpdateEnabled()
    Return $__g_Cfg_bAutoUpdateEnabled
EndFunc
Func _Cfg_GetAutoUpdateInterval()
    Return $__g_Cfg_iAutoUpdateInterval * 3600000
EndFunc
Func _Cfg_GetAutoUpdateIntervalHours()
    Return $__g_Cfg_iAutoUpdateInterval
EndFunc
Func _Cfg_GetSingletonEnabled()
    Return $__g_Cfg_bSingletonEnabled
EndFunc
Func _Cfg_GetMinDesktops()
    Return $__g_Cfg_iMinDesktops
EndFunc
Func _Cfg_GetMaxDesktops()
    Return $__g_Cfg_iMaxDesktops
EndFunc
Func _Cfg_GetTaskbarFocusTrick()
    Return $__g_Cfg_bTaskbarFocusTrick
EndFunc
Func _Cfg_GetAutoFocusAfterSwitch()
    Return $__g_Cfg_bAutoFocusAfterSwitch
EndFunc
Func _Cfg_GetCapslockModifier()
    Return $__g_Cfg_bCapslockModifier
EndFunc
Func _Cfg_GetDisableWinWidgets()
    Return $__g_Cfg_bDisableWinWidgets
EndFunc

; [Updates]
Func _Cfg_GetUpdateCheckOnStartup()
    Return $__g_Cfg_bUpdateCheckOnStartup
EndFunc
Func _Cfg_GetUpdateCheckDays()
    Return $__g_Cfg_iUpdateCheckDays
EndFunc

; [Display]
Func _Cfg_GetShowCount()
    Return $__g_Cfg_bShowCount
EndFunc
Func _Cfg_GetCountFontSize()
    Return $__g_Cfg_iCountFontSize
EndFunc
Func _Cfg_GetThemeAlphaMain()
    Return $__g_Cfg_iThemeAlphaMain
EndFunc
Func _Cfg_GetTheme()
    Return $__g_Cfg_sTheme
EndFunc
Func _Cfg_GetThumbnailsEnabled()
    Return $__g_Cfg_bThumbnailsEnabled
EndFunc
Func _Cfg_GetThumbnailWidth()
    Return $__g_Cfg_iThumbnailWidth
EndFunc
Func _Cfg_GetThumbnailHeight()
    Return $__g_Cfg_iThumbnailHeight
EndFunc
Func _Cfg_GetListFontName()
    Return $__g_Cfg_sListFontName
EndFunc
Func _Cfg_GetListFontSize()
    Return $__g_Cfg_iListFontSize
EndFunc
Func _Cfg_GetListScrollable()
    Return $__g_Cfg_bListScrollable
EndFunc
Func _Cfg_GetListMaxVisible()
    Return $__g_Cfg_iListMaxVisible
EndFunc
Func _Cfg_GetListScrollSpeed()
    Return $__g_Cfg_iListScrollSpeed
EndFunc
Func _Cfg_GetTooltipFontSize()
    Return $__g_Cfg_iTooltipFontSize
EndFunc
Func _Cfg_GetThumbnailUseScreenshot()
    Return $__g_Cfg_bThumbnailUseScreenshot
EndFunc
Func _Cfg_GetThumbnailCacheTTL()
    Return $__g_Cfg_iThumbnailCacheTTL
EndFunc
Func _Cfg_GetDesktopListShowNumbers()
    Return $__g_Cfg_bDesktopListShowNumbers
EndFunc

; [Scroll]
Func _Cfg_GetScrollEnabled()
    Return $__g_Cfg_bScrollEnabled
EndFunc
Func _Cfg_GetScrollDirection()
    Return $__g_Cfg_sScrollDirection
EndFunc
Func _Cfg_GetScrollWrap()
    Return $__g_Cfg_bScrollWrap
EndFunc
Func _Cfg_GetListScrollEnabled()
    Return $__g_Cfg_bListScrollEnabled
EndFunc
Func _Cfg_GetListScrollAction()
    Return $__g_Cfg_sListScrollAction
EndFunc

; [Hotkeys]
Func _Cfg_GetHotkeyDesktopCount()
    Return $__g_Cfg_iHotkeyDesktopCount
EndFunc
Func _Cfg_SetHotkeyDesktopCount($i)
    If $i < 1 Then $i = 1
    If $i > 9 Then $i = 9
    $__g_Cfg_iHotkeyDesktopCount = $i
EndFunc
Func _Cfg_GetHotkeyNext()
    Return $__g_Cfg_sHotkeyNext
EndFunc
Func _Cfg_GetHotkeyPrev()
    Return $__g_Cfg_sHotkeyPrev
EndFunc
Func _Cfg_GetHotkeyDesktop($i)
    If $i < 1 Or $i > 9 Then Return ""
    Return $__g_Cfg_sHotkeyDesktop[$i]
EndFunc
Func _Cfg_GetHotkeyToggleList()
    Return $__g_Cfg_sHotkeyToggleList
EndFunc
Func _Cfg_GetHotkeyToggleLast()
    Return $__g_Cfg_sHotkeyToggleLast
EndFunc
Func _Cfg_GetHotkeyMoveFollowNext()
    Return $__g_Cfg_sHotkeyMoveFollowNext
EndFunc
Func _Cfg_GetHotkeyMoveFollowPrev()
    Return $__g_Cfg_sHotkeyMoveFollowPrev
EndFunc
Func _Cfg_GetHotkeyMoveNext()
    Return $__g_Cfg_sHotkeyMoveNext
EndFunc
Func _Cfg_GetHotkeyMovePrev()
    Return $__g_Cfg_sHotkeyMovePrev
EndFunc
Func _Cfg_GetHotkeySendNewDesktop()
    Return $__g_Cfg_sHotkeySendNewDesktop
EndFunc
Func _Cfg_GetHotkeyPinWindow()
    Return $__g_Cfg_sHotkeyPinWindow
EndFunc
Func _Cfg_GetHotkeyToggleWindowList()
    Return $__g_Cfg_sHotkeyToggleWindowList
EndFunc
Func _Cfg_GetHotkeyOpenSettings()
    Return $__g_Cfg_sHotkeyOpenSettings
EndFunc
Func _Cfg_GetHotkeysEnabled()
    Return $__g_Cfg_bHotkeysEnabled
EndFunc

; [Behavior]
Func _Cfg_GetConfirmDelete()
    Return $__g_Cfg_bConfirmDelete
EndFunc
Func _Cfg_GetMiddleClickDelete()
    Return $__g_Cfg_bMiddleClickDelete
EndFunc
Func _Cfg_GetMoveWindowEnabled()
    Return $__g_Cfg_bMoveWindowEnabled
EndFunc
Func _Cfg_GetPeekBounceDelay()
    Return $__g_Cfg_iPeekBounceDelay
EndFunc
Func _Cfg_GetAutoHideTimeout()
    Return $__g_Cfg_iAutoHideTimeout
EndFunc
Func _Cfg_GetTopmostInterval()
    Return $__g_Cfg_iTopmostInterval
EndFunc
Func _Cfg_GetCmAutoHideDelay()
    Return $__g_Cfg_iCmAutoHideDelay
EndFunc
Func _Cfg_GetConfigWatcherEnabled()
    Return $__g_Cfg_bConfigWatcherEnabled
EndFunc
Func _Cfg_GetConfigWatcherInterval()
    Return $__g_Cfg_iConfigWatcherInterval
EndFunc
Func _Cfg_GetCountCacheTTL()
    Return $__g_Cfg_iCountCacheTTL
EndFunc
Func _Cfg_GetNameSyncInterval()
    Return $__g_Cfg_iNameSyncInterval
EndFunc
Func _Cfg_GetDllCheckInterval()
    Return $__g_Cfg_iDllCheckInterval
EndFunc
Func _Cfg_GetUpdatePollInterval()
    Return $__g_Cfg_iUpdatePollInterval
EndFunc
Func _Cfg_GetConfirmQuit()
    Return $__g_Cfg_bConfirmQuit
EndFunc
Func _Cfg_GetConfirmRestart()
    Return $__g_Cfg_bConfirmRestart
EndFunc
Func _Cfg_GetDebugMode()
    Return $__g_Cfg_bDebugMode
EndFunc

; [Logging]
Func _Cfg_GetAnimationsEnabled()
    Return $__g_Cfg_bAnimationsEnabled
EndFunc
Func _Cfg_GetFadeInDuration()
    Return $__g_Cfg_iFadeInDuration
EndFunc
Func _Cfg_GetFadeOutDuration()
    Return $__g_Cfg_iFadeOutDuration
EndFunc
Func _Cfg_GetFadeStep()
    Return $__g_Cfg_iFadeStep
EndFunc
Func _Cfg_GetToastFadeOutDuration()
    Return $__g_Cfg_iToastFadeOutMs
EndFunc
Func _Cfg_GetFadeSleepMs()
    Return $__g_Cfg_iFadeSleepMs
EndFunc
Func _Cfg_SetAnimationsEnabled($b)
    $__g_Cfg_bAnimationsEnabled = $b
EndFunc
Func _Cfg_SetFadeInDuration($i)
    If $i < 0 Then $i = 0
    If $i > 500 Then $i = 500
    $__g_Cfg_iFadeInDuration = $i
EndFunc
Func _Cfg_SetFadeOutDuration($i)
    If $i < 0 Then $i = 0
    If $i > 500 Then $i = 500
    $__g_Cfg_iFadeOutDuration = $i
EndFunc
Func _Cfg_SetFadeStep($i)
    If $i < 5 Then $i = 5
    If $i > 255 Then $i = 255
    $__g_Cfg_iFadeStep = $i
EndFunc
Func _Cfg_SetToastFadeOutDuration($i)
    If $i < 0 Then $i = 0
    If $i > 1000 Then $i = 1000
    $__g_Cfg_iToastFadeOutMs = $i
EndFunc
Func _Cfg_SetFadeSleepMs($i)
    If $i < 1 Then $i = 1
    If $i > 50 Then $i = 50
    $__g_Cfg_iFadeSleepMs = $i
EndFunc
Func _Cfg_GetAnimList()
    Return $__g_Cfg_bAnimList
EndFunc
Func _Cfg_GetAnimMenus()
    Return $__g_Cfg_bAnimMenus
EndFunc
Func _Cfg_GetAnimDialogs()
    Return $__g_Cfg_bAnimDialogs
EndFunc
Func _Cfg_GetAnimToasts()
    Return $__g_Cfg_bAnimToasts
EndFunc
Func _Cfg_GetAnimWidget()
    Return $__g_Cfg_bAnimWidget
EndFunc
Func _Cfg_SetAnimList($b)
    $__g_Cfg_bAnimList = $b
EndFunc
Func _Cfg_SetAnimMenus($b)
    $__g_Cfg_bAnimMenus = $b
EndFunc
Func _Cfg_SetAnimDialogs($b)
    $__g_Cfg_bAnimDialogs = $b
EndFunc
Func _Cfg_SetAnimToasts($b)
    $__g_Cfg_bAnimToasts = $b
EndFunc
Func _Cfg_SetAnimWidget($b)
    $__g_Cfg_bAnimWidget = $b
EndFunc
Func _Cfg_GetAnimHoverSpeed()
    Return $__g_Cfg_iAnimHoverSpeed
EndFunc
Func _Cfg_SetAnimHoverSpeed($i)
    If $i < 0 Then $i = 0
    If $i > 50 Then $i = 50
    $__g_Cfg_iAnimHoverSpeed = $i
EndFunc
Func _Cfg_GetToastPosition()
    Return $__g_Cfg_sToastPosition
EndFunc
Func _Cfg_SetToastPosition($s)
    Local $aValid = "top-left|top-right|bottom-left|bottom-right|widget"
    If Not StringInStr($aValid, $s) Then $s = "widget"
    $__g_Cfg_sToastPosition = $s
EndFunc
Func _Cfg_GetLoggingEnabled()
    Return $__g_Cfg_bLoggingEnabled
EndFunc
Func _Cfg_GetLogFolder()
    Return $__g_Cfg_sLogFolder
EndFunc
Func _Cfg_GetLogLevel()
    Return $__g_Cfg_sLogLevel
EndFunc
Func _Cfg_GetLogMaxSizeMB()
    Return $__g_Cfg_iLogMaxSizeMB
EndFunc
Func _Cfg_GetLogRotateCount()
    Return $__g_Cfg_iLogRotateCount
EndFunc
Func _Cfg_GetLogCompressOld()
    Return $__g_Cfg_bLogCompressOld
EndFunc
Func _Cfg_GetLogFilePath()
    Local $sFolder = $__g_Cfg_sLogFolder
    If $sFolder = "" Then Return @ScriptDir & "\desk_switcheroo.log"
    $sFolder = StringReplace($sFolder, "%APPDATA%", @AppDataDir)
    $sFolder = StringReplace($sFolder, "%TEMP%", @TempDir)
    $sFolder = StringReplace($sFolder, "%SCRIPTDIR%", @ScriptDir)
    ; Reject directory traversal and UNC paths after expansion
    If StringInStr($sFolder, "..") Or StringLeft($sFolder, 2) = "\\" Then
        _Log_Warn("Config: rejected log folder path: " & $sFolder)
        Return @ScriptDir & "\desk_switcheroo.log"
    EndIf
    ; Strip trailing backslash
    If StringRight($sFolder, 1) = "\" Then $sFolder = StringTrimRight($sFolder, 1)
    Return $sFolder & "\desk_switcheroo.log"
EndFunc
Func _Cfg_GetLogIncludePID()
    Return $__g_Cfg_bLogIncludePID
EndFunc
Func _Cfg_GetLogIncludeFunc()
    Return $__g_Cfg_bLogIncludeFunc
EndFunc
Func _Cfg_GetLogDateFormat()
    Return $__g_Cfg_sLogDateFormat
EndFunc
Func _Cfg_GetLogFlushImmediate()
    Return $__g_Cfg_bLogFlushImmediate
EndFunc

; [DesktopColors]
Func _Cfg_GetDesktopColorsEnabled()
    Return $__g_Cfg_bDesktopColorsEnabled
EndFunc
Func _Cfg_GetDesktopColor($i)
    If $i < 1 Or $i > $__g_Cfg_MAX_DESKTOPS Then Return 0
    Return $__g_Cfg_aDesktopColors[$i]
EndFunc

; [Wallpaper]
Func _Cfg_GetWallpaperEnabled()
    Return $__g_Cfg_bWallpaperEnabled
EndFunc
Func _Cfg_GetWallpaperChangeDelay()
    Return $__g_Cfg_iWallpaperChangeDelay
EndFunc
Func _Cfg_GetDesktopWallpaper($i)
    If $i < 1 Or $i > $__g_Cfg_MAX_DESKTOPS Then Return ""
    Return $__g_Cfg_aDesktopWallpaper[$i]
EndFunc

; [Pinning]
Func _Cfg_GetPinningEnabled()
    Return $__g_Cfg_bPinningEnabled
EndFunc

; [WindowList]
Func _Cfg_GetWindowListEnabled()
    Return $__g_Cfg_bWindowListEnabled
EndFunc
Func _Cfg_GetWindowListPosition()
    Return $__g_Cfg_sWindowListPosition
EndFunc
Func _Cfg_GetWindowListWidth()
    Return $__g_Cfg_iWindowListWidth
EndFunc
Func _Cfg_GetWindowListMaxVisible()
    Return $__g_Cfg_iWindowListMaxVisible
EndFunc
Func _Cfg_GetWindowListShowIcons()
    Return $__g_Cfg_bWindowListShowIcons
EndFunc
Func _Cfg_GetWindowListSearch()
    Return $__g_Cfg_bWindowListSearch
EndFunc
Func _Cfg_GetWindowListAutoRefresh()
    Return $__g_Cfg_bWindowListAutoRefresh
EndFunc
Func _Cfg_GetWindowListRefreshInterval()
    Return $__g_Cfg_iWindowListRefreshInterval
EndFunc

; [ExplorerMonitor]
Func _Cfg_GetExplorerMonitorEnabled()
    Return $__g_Cfg_bExplorerMonitorEnabled
EndFunc
Func _Cfg_GetShellProcessName()
    Return $__g_Cfg_sShellProcessName
EndFunc
Func _Cfg_GetExplorerCheckInterval()
    Return $__g_Cfg_iExplorerCheckInterval
EndFunc
Func _Cfg_GetMonitorMaxRetries()
    Return $__g_Cfg_iMonitorMaxRetries
EndFunc
Func _Cfg_GetMonitorRetryDelay()
    Return $__g_Cfg_iMonitorRetryDelay
EndFunc
Func _Cfg_GetMonitorExpBackoff()
    Return $__g_Cfg_bMonitorExpBackoff
EndFunc
Func _Cfg_GetMonitorMaxRetryDelay()
    Return $__g_Cfg_iMonitorMaxRetryDelay
EndFunc
Func _Cfg_GetMonitorAutoRestart()
    Return $__g_Cfg_bMonitorAutoRestart
EndFunc
Func _Cfg_GetMonitorRestartDelay()
    Return $__g_Cfg_iMonitorRestartDelay
EndFunc
Func _Cfg_GetExplorerNotifyRecovery()
    Return $__g_Cfg_bExplorerNotifyRecovery
EndFunc

; [TaskbarAutoHide]
Func _Cfg_GetAutoHideSyncEnabled()
    Return $__g_Cfg_bAutoHideSyncEnabled
EndFunc
Func _Cfg_GetAutoHidePollInterval()
    Return $__g_Cfg_iAutoHidePollInterval
EndFunc
Func _Cfg_GetAutoHideHideDelay()
    Return $__g_Cfg_iAutoHideHideDelay
EndFunc
Func _Cfg_GetAutoHideShowDelay()
    Return $__g_Cfg_iAutoHideShowDelay
EndFunc
Func _Cfg_GetAutoHideUseFade()
    Return $__g_Cfg_bAutoHideUseFade
EndFunc
Func _Cfg_GetAutoHideFadeDuration()
    Return $__g_Cfg_iAutoHideFadeDuration
EndFunc
Func _Cfg_GetAutoHideSyncDesktopList()
    Return $__g_Cfg_bAutoHideSyncDesktopList
EndFunc
Func _Cfg_GetAutoHideSyncWindowList()
    Return $__g_Cfg_bAutoHideSyncWindowList
EndFunc
Func _Cfg_GetAutoHideHiddenThreshold()
    Return $__g_Cfg_iAutoHideHiddenThreshold
EndFunc
Func _Cfg_GetAutoHideRecheckCount()
    Return $__g_Cfg_iAutoHideRecheckCount
EndFunc
Func _Cfg_GetAutoHideSkipIfDialog()
    Return $__g_Cfg_bAutoHideSkipIfDialog
EndFunc

; [Notifications]
Func _Cfg_GetNotificationsEnabled()
    Return $__g_Cfg_bNotificationsEnabled
EndFunc
Func _Cfg_GetNotifyWindowMoved()
    Return $__g_Cfg_bNotifyWindowMoved
EndFunc
Func _Cfg_GetNotifyDesktopCreated()
    Return $__g_Cfg_bNotifyDesktopCreated
EndFunc
Func _Cfg_GetNotifyDesktopDeleted()
    Return $__g_Cfg_bNotifyDesktopDeleted
EndFunc
Func _Cfg_GetNotifyWindowPinned()
    Return $__g_Cfg_bNotifyWindowPinned
EndFunc
Func _Cfg_GetNotifyWindowUnpinned()
    Return $__g_Cfg_bNotifyWindowUnpinned
EndFunc
Func _Cfg_GetNotifyExplorerRecovery()
    Return $__g_Cfg_bNotifyExplorerRecovery
EndFunc
Func _Cfg_GetWindowListScope()
    Return $__g_Cfg_sWindowListScope
EndFunc

; [Notifications] OSD
Func _Cfg_GetOsdEnabled()
    Return $__g_Cfg_bOsdEnabled
EndFunc
Func _Cfg_GetOsdShowName()
    Return $__g_Cfg_bOsdShowName
EndFunc
Func _Cfg_GetOsdShowNumber()
    Return $__g_Cfg_bOsdShowNumber
EndFunc
Func _Cfg_GetOsdDuration()
    Return $__g_Cfg_iOsdDuration
EndFunc
Func _Cfg_GetOsdPosition()
    Return $__g_Cfg_sOsdPosition
EndFunc
Func _Cfg_GetOsdFontSize()
    Return $__g_Cfg_iOsdFontSize
EndFunc
Func _Cfg_GetOsdOpacity()
    Return $__g_Cfg_iOsdOpacity
EndFunc
Func _Cfg_GetOsdFormat()
    Return $__g_Cfg_sOsdFormat
EndFunc

; [Rules]
Func _Cfg_GetRulesEnabled()
    Return $__g_Cfg_bRulesEnabled
EndFunc
Func _Cfg_GetRulesPollInterval()
    Return $__g_Cfg_iRulesPollInterval
EndFunc

; [Session]
Func _Cfg_GetSessionRestoreEnabled()
    Return $__g_Cfg_bSessionRestoreEnabled
EndFunc

; [Hooks]
Func _Cfg_GetHooksEnabled()
    Return $__g_Cfg_bHooksEnabled
EndFunc
Func _Cfg_GetHooksTimeout()
    Return $__g_Cfg_iHooksTimeout
EndFunc

; [Profiles]
Func _Cfg_GetProfilesEnabled()
    Return $__g_Cfg_bProfilesEnabled
EndFunc

; =============================================
; TYPED SETTERS
; =============================================

; [General]
Func _Cfg_SetStartWithWindows($b)
    $__g_Cfg_bStartWithWindows = $b
EndFunc
Func _Cfg_SetWrapNavigation($b)
    $__g_Cfg_bWrapNavigation = $b
EndFunc
Func _Cfg_SetAutoCreateDesktop($b)
    $__g_Cfg_bAutoCreateDesktop = $b
EndFunc
Func _Cfg_SetNumberPadding($i)
    If $i < 1 Then $i = 1
    If $i > 4 Then $i = 4
    $__g_Cfg_iNumberPadding = $i
EndFunc
Func _Cfg_SetWidgetPosition($s)
    ; Accept legacy values
    If $s = "left" Then $s = "bottom-left"
    If $s = "center" Then $s = "bottom-center"
    If $s = "right" Then $s = "bottom-right"
    Local $sValid = "bottom-left|bottom-center|bottom-right|middle-left|middle-right|top-left|top-center|top-right"
    If Not StringInStr("|" & $sValid & "|", "|" & $s & "|") Then $s = "bottom-left"
    $__g_Cfg_sWidgetPosition = $s
EndFunc
Func _Cfg_SetWidgetOffsetX($i)
    $__g_Cfg_iWidgetOffsetX = Int($i)
EndFunc
Func _Cfg_GetWidgetOffsetY()
    Return $__g_Cfg_iWidgetOffsetY
EndFunc
Func _Cfg_SetWidgetOffsetY($i)
    $__g_Cfg_iWidgetOffsetY = Int($i)
EndFunc
Func _Cfg_GetWidgetWidth()
    Return $__g_Cfg_iWidgetWidth
EndFunc
Func _Cfg_SetWidgetWidth($i)
    If $i < 0 Then $i = 0
    If $i > 500 Then $i = 500
    $__g_Cfg_iWidgetWidth = Int($i)
EndFunc
Func _Cfg_GetWidgetHeight()
    Return $__g_Cfg_iWidgetHeight
EndFunc
Func _Cfg_SetWidgetHeight($i)
    If $i < 0 Then $i = 0
    If $i > 200 Then $i = 200
    $__g_Cfg_iWidgetHeight = Int($i)
EndFunc
Func _Cfg_SetWidgetDragEnabled($b)
    $__g_Cfg_bWidgetDragEnabled = $b
EndFunc
Func _Cfg_SetWidgetColorBar($b)
    $__g_Cfg_bWidgetColorBar = $b
EndFunc
Func _Cfg_SetWidgetColorBarHeight($i)
    If $i < 1 Then $i = 1
    If $i > 10 Then $i = 10
    $__g_Cfg_iWidgetColorBarH = $i
EndFunc
Func _Cfg_SetTrayIconMode($b)
    $__g_Cfg_bTrayIconMode = $b
EndFunc
Func _Cfg_SetQuickAccessEnabled($b)
    $__g_Cfg_bQuickAccessEnabled = $b
EndFunc
Func _Cfg_SetStartMinimized($b)
    $__g_Cfg_bStartMinimized = $b
EndFunc
Func _Cfg_SetListKeyboardNav($b)
    $__g_Cfg_bListKeyboardNav = $b
EndFunc
Func _Cfg_SetAutoUpdateEnabled($b)
    $__g_Cfg_bAutoUpdateEnabled = $b
EndFunc
Func _Cfg_SetAutoUpdateInterval($iHours)
    If $iHours < 1 Then $iHours = 1
    If $iHours > 720 Then $iHours = 720
    $__g_Cfg_iAutoUpdateInterval = $iHours
EndFunc
Func _Cfg_SetSingletonEnabled($b)
    $__g_Cfg_bSingletonEnabled = $b
EndFunc
Func _Cfg_SetMinDesktops($i)
    If $i < 0 Then $i = 0
    If $i > 50 Then $i = 50
    $__g_Cfg_iMinDesktops = $i
EndFunc
Func _Cfg_SetMaxDesktops($i)
    If $i < 0 Then $i = 0
    If $i > 50 Then $i = 50
    $__g_Cfg_iMaxDesktops = $i
EndFunc
Func _Cfg_SetTaskbarFocusTrick($b)
    $__g_Cfg_bTaskbarFocusTrick = $b
EndFunc
Func _Cfg_SetAutoFocusAfterSwitch($b)
    $__g_Cfg_bAutoFocusAfterSwitch = $b
EndFunc
Func _Cfg_SetCapslockModifier($b)
    $__g_Cfg_bCapslockModifier = $b
EndFunc
Func _Cfg_SetDisableWinWidgets($b)
    $__g_Cfg_bDisableWinWidgets = $b
EndFunc
Func _Cfg_GetDesktopListPinned()
    Return $__g_Cfg_bDesktopListPinned
EndFunc
Func _Cfg_SetDesktopListPinned($b)
    $__g_Cfg_bDesktopListPinned = $b
EndFunc

; [Updates]
Func _Cfg_SetUpdateCheckOnStartup($b)
    $__g_Cfg_bUpdateCheckOnStartup = $b
EndFunc
Func _Cfg_SetUpdateCheckDays($i)
    If $i < 1 Then $i = 1
    If $i > 90 Then $i = 90
    $__g_Cfg_iUpdateCheckDays = $i
EndFunc

; [Display]
Func _Cfg_SetShowCount($b)
    $__g_Cfg_bShowCount = $b
EndFunc
Func _Cfg_SetCountFontSize($i)
    If $i < 4 Then $i = 4
    If $i > 20 Then $i = 20
    $__g_Cfg_iCountFontSize = $i
EndFunc
Func _Cfg_SetThemeAlphaMain($i)
    If $i < 50 Then $i = 50
    If $i > 255 Then $i = 255
    $__g_Cfg_iThemeAlphaMain = $i
EndFunc
Func _Cfg_SetTheme($s)
    If $s <> "dark" And $s <> "darker" And $s <> "midnight" And $s <> "midday" And $s <> "sunset" Then $s = "dark"
    $__g_Cfg_sTheme = $s
EndFunc
Func _Cfg_SetThumbnailsEnabled($b)
    $__g_Cfg_bThumbnailsEnabled = $b
EndFunc
Func _Cfg_SetThumbnailWidth($i)
    If $i < 80 Then $i = 80
    If $i > 320 Then $i = 320
    $__g_Cfg_iThumbnailWidth = $i
EndFunc
Func _Cfg_SetThumbnailHeight($i)
    If $i < 45 Then $i = 45
    If $i > 180 Then $i = 180
    $__g_Cfg_iThumbnailHeight = $i
EndFunc
Func _Cfg_SetListFontName($s)
    $__g_Cfg_sListFontName = __Cfg_ClampStringLen($s, 64)
EndFunc
Func _Cfg_SetListFontSize($i)
    If $i < 6 Then $i = 6
    If $i > 14 Then $i = 14
    $__g_Cfg_iListFontSize = $i
EndFunc
Func _Cfg_SetListScrollable($b)
    $__g_Cfg_bListScrollable = $b
EndFunc
Func _Cfg_SetListMaxVisible($i)
    If $i < 3 Then $i = 3
    If $i > 30 Then $i = 30
    $__g_Cfg_iListMaxVisible = $i
EndFunc
Func _Cfg_SetListScrollSpeed($i)
    If $i < 1 Then $i = 1
    If $i > 5 Then $i = 5
    $__g_Cfg_iListScrollSpeed = $i
EndFunc
Func _Cfg_SetTooltipFontSize($i)
    If $i < 6 Then $i = 6
    If $i > 12 Then $i = 12
    $__g_Cfg_iTooltipFontSize = $i
EndFunc
Func _Cfg_SetThumbnailUseScreenshot($b)
    $__g_Cfg_bThumbnailUseScreenshot = $b
EndFunc
Func _Cfg_SetThumbnailCacheTTL($i)
    If $i < 5 Then $i = 5
    If $i > 300 Then $i = 300
    $__g_Cfg_iThumbnailCacheTTL = $i
EndFunc
Func _Cfg_SetDesktopListShowNumbers($b)
    $__g_Cfg_bDesktopListShowNumbers = $b
EndFunc

; [Scroll]
Func _Cfg_SetScrollEnabled($b)
    $__g_Cfg_bScrollEnabled = $b
EndFunc
Func _Cfg_SetScrollDirection($s)
    If $s <> "normal" And $s <> "inverted" Then $s = "normal"
    $__g_Cfg_sScrollDirection = $s
EndFunc
Func _Cfg_SetScrollWrap($b)
    $__g_Cfg_bScrollWrap = $b
EndFunc
Func _Cfg_SetListScrollEnabled($b)
    $__g_Cfg_bListScrollEnabled = $b
EndFunc
Func _Cfg_SetListScrollAction($s)
    If $s <> "switch" And $s <> "scroll" Then $s = "switch"
    $__g_Cfg_sListScrollAction = $s
EndFunc

; [Hotkeys]
Func _Cfg_SetHotkeyNext($s)
    $__g_Cfg_sHotkeyNext = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyPrev($s)
    $__g_Cfg_sHotkeyPrev = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyDesktop($i, $s)
    If $i >= 1 And $i <= 9 Then $__g_Cfg_sHotkeyDesktop[$i] = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyToggleList($s)
    $__g_Cfg_sHotkeyToggleList = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyToggleLast($s)
    $__g_Cfg_sHotkeyToggleLast = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyMoveFollowNext($s)
    $__g_Cfg_sHotkeyMoveFollowNext = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyMoveFollowPrev($s)
    $__g_Cfg_sHotkeyMoveFollowPrev = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyMoveNext($s)
    $__g_Cfg_sHotkeyMoveNext = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyMovePrev($s)
    $__g_Cfg_sHotkeyMovePrev = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeySendNewDesktop($s)
    $__g_Cfg_sHotkeySendNewDesktop = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyPinWindow($s)
    $__g_Cfg_sHotkeyPinWindow = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyToggleWindowList($s)
    $__g_Cfg_sHotkeyToggleWindowList = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeyOpenSettings($s)
    $__g_Cfg_sHotkeyOpenSettings = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_SetHotkeysEnabled($b)
    $__g_Cfg_bHotkeysEnabled = $b
EndFunc
Func _Cfg_GetHotkeyAddDesktop()
    Return $__g_Cfg_sHotkeyAddDesktop
EndFunc
Func _Cfg_SetHotkeyAddDesktop($s)
    $__g_Cfg_sHotkeyAddDesktop = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_GetHotkeyDeleteDesktop()
    Return $__g_Cfg_sHotkeyDeleteDesktop
EndFunc
Func _Cfg_SetHotkeyDeleteDesktop($s)
    $__g_Cfg_sHotkeyDeleteDesktop = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_GetHotkeyRenameDesktop()
    Return $__g_Cfg_sHotkeyRenameDesktop
EndFunc
Func _Cfg_SetHotkeyRenameDesktop($s)
    $__g_Cfg_sHotkeyRenameDesktop = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_GetHotkeyCloseWindow()
    Return $__g_Cfg_sHotkeyCloseWindow
EndFunc
Func _Cfg_SetHotkeyCloseWindow($s)
    $__g_Cfg_sHotkeyCloseWindow = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_GetHotkeyMinimizeWindow()
    Return $__g_Cfg_sHotkeyMinimizeWindow
EndFunc
Func _Cfg_SetHotkeyMinimizeWindow($s)
    $__g_Cfg_sHotkeyMinimizeWindow = __Cfg_ClampStringLen($s, 32)
EndFunc

; [Behavior]
Func _Cfg_SetConfirmDelete($b)
    $__g_Cfg_bConfirmDelete = $b
EndFunc
Func _Cfg_SetMiddleClickDelete($b)
    $__g_Cfg_bMiddleClickDelete = $b
EndFunc
Func _Cfg_SetMoveWindowEnabled($b)
    $__g_Cfg_bMoveWindowEnabled = $b
EndFunc
Func _Cfg_SetPeekBounceDelay($i)
    If $i < 100 Then $i = 100
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iPeekBounceDelay = $i
EndFunc
Func _Cfg_SetAutoHideTimeout($i)
    If $i < 500 Then $i = 500
    If $i > 30000 Then $i = 30000
    $__g_Cfg_iAutoHideTimeout = $i
EndFunc
Func _Cfg_SetTopmostInterval($i)
    If $i < 100 Then $i = 100
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iTopmostInterval = $i
EndFunc
Func _Cfg_SetCmAutoHideDelay($i)
    If $i < 100 Then $i = 100
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iCmAutoHideDelay = $i
EndFunc
Func _Cfg_SetConfigWatcherEnabled($b)
    $__g_Cfg_bConfigWatcherEnabled = $b
EndFunc
Func _Cfg_SetConfigWatcherInterval($i)
    If $i < 5000 Then $i = 5000
    If $i > 300000 Then $i = 300000
    $__g_Cfg_iConfigWatcherInterval = $i
EndFunc
Func _Cfg_SetCountCacheTTL($i)
    If $i < 100 Then $i = 100
    If $i > 10000 Then $i = 10000
    $__g_Cfg_iCountCacheTTL = $i
EndFunc
Func _Cfg_SetNameSyncInterval($i)
    If $i < 500 Then $i = 500
    If $i > 60000 Then $i = 60000
    $__g_Cfg_iNameSyncInterval = $i
EndFunc
Func _Cfg_SetDllCheckInterval($i)
    If $i < 5000 Then $i = 5000
    If $i > 300000 Then $i = 300000
    $__g_Cfg_iDllCheckInterval = $i
EndFunc
Func _Cfg_SetUpdatePollInterval($i)
    If $i < 100 Then $i = 100
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iUpdatePollInterval = $i
EndFunc
Func _Cfg_SetConfirmQuit($b)
    $__g_Cfg_bConfirmQuit = $b
EndFunc
Func _Cfg_SetConfirmRestart($b)
    $__g_Cfg_bConfirmRestart = $b
EndFunc
Func _Cfg_SetDebugMode($b)
    $__g_Cfg_bDebugMode = $b
EndFunc

; [Logging]
Func _Cfg_SetLoggingEnabled($b)
    $__g_Cfg_bLoggingEnabled = $b
EndFunc
Func _Cfg_SetLogFolder($s)
    $__g_Cfg_sLogFolder = __Cfg_ClampStringLen($s, 260)
EndFunc
Func _Cfg_SetLogLevel($s)
    If $s <> "error" And $s <> "warn" And $s <> "info" And $s <> "debug" Then $s = "info"
    $__g_Cfg_sLogLevel = $s
EndFunc
Func _Cfg_SetLogMaxSizeMB($i)
    If $i < 1 Then $i = 1
    If $i > 50 Then $i = 50
    $__g_Cfg_iLogMaxSizeMB = $i
EndFunc
Func _Cfg_SetLogRotateCount($i)
    If $i < 1 Then $i = 1
    If $i > 10 Then $i = 10
    $__g_Cfg_iLogRotateCount = $i
EndFunc
Func _Cfg_SetLogCompressOld($b)
    $__g_Cfg_bLogCompressOld = $b
EndFunc
Func _Cfg_SetLogIncludePID($b)
    $__g_Cfg_bLogIncludePID = $b
EndFunc
Func _Cfg_SetLogIncludeFunc($b)
    $__g_Cfg_bLogIncludeFunc = $b
EndFunc
Func _Cfg_SetLogDateFormat($s)
    If $s <> "iso" And $s <> "us" And $s <> "eu" Then $s = "iso"
    $__g_Cfg_sLogDateFormat = $s
EndFunc
Func _Cfg_SetLogFlushImmediate($b)
    $__g_Cfg_bLogFlushImmediate = $b
EndFunc

; [DesktopColors]
Func _Cfg_SetDesktopColorsEnabled($b)
    $__g_Cfg_bDesktopColorsEnabled = $b
EndFunc
Func _Cfg_SetDesktopColor($i, $iColor)
    If $i >= 1 And $i <= $__g_Cfg_MAX_DESKTOPS Then $__g_Cfg_aDesktopColors[$i] = Int($iColor)
EndFunc

; [Wallpaper]
Func _Cfg_SetWallpaperEnabled($b)
    $__g_Cfg_bWallpaperEnabled = $b
EndFunc
Func _Cfg_SetWallpaperChangeDelay($i)
    If $i < 50 Then $i = 50
    If $i > 2000 Then $i = 2000
    $__g_Cfg_iWallpaperChangeDelay = $i
EndFunc
Func _Cfg_SetDesktopWallpaper($i, $s)
    If $i < 1 Or $i > $__g_Cfg_MAX_DESKTOPS Then Return
    If $s <> "" And Not __Cfg_ValidateWallpaperPath($s) Then Return
    $__g_Cfg_aDesktopWallpaper[$i] = __Cfg_ClampStringLen($s, 260)
EndFunc

; [Pinning]
Func _Cfg_SetPinningEnabled($b)
    $__g_Cfg_bPinningEnabled = $b
EndFunc

; [WindowList]
Func _Cfg_SetWindowListEnabled($b)
    $__g_Cfg_bWindowListEnabled = $b
EndFunc
Func _Cfg_SetWindowListPosition($s)
    Local $sValid = "top-left|top-right|bottom-left|bottom-right"
    If Not StringInStr("|" & $sValid & "|", "|" & $s & "|") Then $s = "top-left"
    $__g_Cfg_sWindowListPosition = $s
EndFunc
Func _Cfg_SetWindowListWidth($i)
    If $i < 150 Then $i = 150
    If $i > 600 Then $i = 600
    $__g_Cfg_iWindowListWidth = $i
EndFunc
Func _Cfg_SetWindowListMaxVisible($i)
    If $i < 5 Then $i = 5
    If $i > 50 Then $i = 50
    $__g_Cfg_iWindowListMaxVisible = $i
EndFunc
Func _Cfg_SetWindowListShowIcons($b)
    $__g_Cfg_bWindowListShowIcons = $b
EndFunc
Func _Cfg_SetWindowListSearch($b)
    $__g_Cfg_bWindowListSearch = $b
EndFunc
Func _Cfg_SetWindowListAutoRefresh($b)
    $__g_Cfg_bWindowListAutoRefresh = $b
EndFunc
Func _Cfg_SetWindowListRefreshInterval($i)
    If $i < 500 Then $i = 500
    If $i > 10000 Then $i = 10000
    $__g_Cfg_iWindowListRefreshInterval = $i
EndFunc

; [ExplorerMonitor]
Func _Cfg_SetExplorerMonitorEnabled($b)
    $__g_Cfg_bExplorerMonitorEnabled = $b
EndFunc
Func _Cfg_SetShellProcessName($s)
    $__g_Cfg_sShellProcessName = __Cfg_ValidateExeName($s)
EndFunc
Func _Cfg_SetExplorerCheckInterval($i)
    If $i < 2000 Then $i = 2000
    If $i > 60000 Then $i = 60000
    $__g_Cfg_iExplorerCheckInterval = $i
EndFunc
Func _Cfg_SetMonitorMaxRetries($i)
    If $i < 0 Then $i = 0
    If $i > 100 Then $i = 100
    $__g_Cfg_iMonitorMaxRetries = $i
EndFunc
Func _Cfg_SetMonitorRetryDelay($i)
    If $i < 1000 Then $i = 1000
    If $i > 60000 Then $i = 60000
    $__g_Cfg_iMonitorRetryDelay = $i
EndFunc
Func _Cfg_SetMonitorExpBackoff($b)
    $__g_Cfg_bMonitorExpBackoff = $b
EndFunc
Func _Cfg_SetMonitorMaxRetryDelay($i)
    If $i < 5000 Then $i = 5000
    If $i > 300000 Then $i = 300000
    $__g_Cfg_iMonitorMaxRetryDelay = $i
EndFunc
Func _Cfg_SetMonitorAutoRestart($b)
    $__g_Cfg_bMonitorAutoRestart = $b
EndFunc
Func _Cfg_SetMonitorRestartDelay($i)
    If $i < 500 Then $i = 500
    If $i > 10000 Then $i = 10000
    $__g_Cfg_iMonitorRestartDelay = $i
EndFunc
Func _Cfg_SetExplorerNotifyRecovery($b)
    $__g_Cfg_bExplorerNotifyRecovery = $b
EndFunc

; [TaskbarAutoHide]
Func _Cfg_SetAutoHideSyncEnabled($b)
    $__g_Cfg_bAutoHideSyncEnabled = $b
EndFunc
Func _Cfg_SetAutoHidePollInterval($i)
    If $i < 50 Then $i = 50
    If $i > 2000 Then $i = 2000
    $__g_Cfg_iAutoHidePollInterval = $i
EndFunc
Func _Cfg_SetAutoHideHideDelay($i)
    If $i < 0 Then $i = 0
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iAutoHideHideDelay = $i
EndFunc
Func _Cfg_SetAutoHideShowDelay($i)
    If $i < 0 Then $i = 0
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iAutoHideShowDelay = $i
EndFunc
Func _Cfg_SetAutoHideUseFade($b)
    $__g_Cfg_bAutoHideUseFade = $b
EndFunc
Func _Cfg_SetAutoHideFadeDuration($i)
    If $i < 10 Then $i = 10
    If $i > 1000 Then $i = 1000
    $__g_Cfg_iAutoHideFadeDuration = $i
EndFunc
Func _Cfg_SetAutoHideSyncDesktopList($b)
    $__g_Cfg_bAutoHideSyncDesktopList = $b
EndFunc
Func _Cfg_SetAutoHideSyncWindowList($b)
    $__g_Cfg_bAutoHideSyncWindowList = $b
EndFunc
Func _Cfg_SetAutoHideHiddenThreshold($i)
    If $i < 1 Then $i = 1
    If $i > 20 Then $i = 20
    $__g_Cfg_iAutoHideHiddenThreshold = $i
EndFunc
Func _Cfg_SetAutoHideRecheckCount($i)
    If $i < 1 Then $i = 1
    If $i > 100 Then $i = 100
    $__g_Cfg_iAutoHideRecheckCount = $i
EndFunc
Func _Cfg_SetAutoHideSkipIfDialog($b)
    $__g_Cfg_bAutoHideSkipIfDialog = $b
EndFunc

; [Notifications]
Func _Cfg_SetNotificationsEnabled($b)
    $__g_Cfg_bNotificationsEnabled = $b
EndFunc
Func _Cfg_SetNotifyWindowMoved($b)
    $__g_Cfg_bNotifyWindowMoved = $b
EndFunc
Func _Cfg_SetNotifyDesktopCreated($b)
    $__g_Cfg_bNotifyDesktopCreated = $b
EndFunc
Func _Cfg_SetNotifyDesktopDeleted($b)
    $__g_Cfg_bNotifyDesktopDeleted = $b
EndFunc
Func _Cfg_SetNotifyWindowPinned($b)
    $__g_Cfg_bNotifyWindowPinned = $b
EndFunc
Func _Cfg_SetNotifyWindowUnpinned($b)
    $__g_Cfg_bNotifyWindowUnpinned = $b
EndFunc
Func _Cfg_SetNotifyExplorerRecovery($b)
    $__g_Cfg_bNotifyExplorerRecovery = $b
EndFunc
Func _Cfg_GetNotifyExplorerCrash()
    Return $__g_Cfg_bNotifyExplorerCrash
EndFunc
Func _Cfg_SetNotifyExplorerCrash($b)
    $__g_Cfg_bNotifyExplorerCrash = $b
EndFunc
Func _Cfg_SetWindowListScope($s)
    Local $aValid = "current|all"
    If Not StringInStr($aValid, $s) Then $s = "current"
    $__g_Cfg_sWindowListScope = $s
EndFunc

; [Notifications] OSD
Func _Cfg_SetOsdEnabled($b)
    $__g_Cfg_bOsdEnabled = $b
EndFunc
Func _Cfg_SetOsdShowName($b)
    $__g_Cfg_bOsdShowName = $b
EndFunc
Func _Cfg_SetOsdShowNumber($b)
    $__g_Cfg_bOsdShowNumber = $b
EndFunc
Func _Cfg_SetOsdDuration($i)
    If $i < 500 Then $i = 500
    If $i > 5000 Then $i = 5000
    $__g_Cfg_iOsdDuration = $i
EndFunc
Func _Cfg_SetOsdPosition($s)
    $__g_Cfg_sOsdPosition = $s
EndFunc
Func _Cfg_SetOsdFontSize($i)
    If $i < 8 Then $i = 8
    If $i > 48 Then $i = 48
    $__g_Cfg_iOsdFontSize = $i
EndFunc
Func _Cfg_SetOsdOpacity($i)
    If $i < 0 Then $i = 0
    If $i > 255 Then $i = 255
    $__g_Cfg_iOsdOpacity = $i
EndFunc
Func _Cfg_SetOsdFormat($s)
    $__g_Cfg_sOsdFormat = $s
EndFunc

; [Rules]
Func _Cfg_SetRulesEnabled($b)
    $__g_Cfg_bRulesEnabled = $b
EndFunc
Func _Cfg_SetRulesPollInterval($i)
    If $i < 500 Then $i = 500
    If $i > 30000 Then $i = 30000
    $__g_Cfg_iRulesPollInterval = $i
EndFunc

; [Session]
Func _Cfg_SetSessionRestoreEnabled($b)
    $__g_Cfg_bSessionRestoreEnabled = $b
EndFunc

; [Hooks]
Func _Cfg_SetHooksEnabled($b)
    $__g_Cfg_bHooksEnabled = $b
EndFunc
Func _Cfg_SetHooksTimeout($i)
    If $i < 1000 Then $i = 1000
    If $i > 300000 Then $i = 300000
    $__g_Cfg_iHooksTimeout = $i
EndFunc

; [Profiles]
Func _Cfg_SetProfilesEnabled($b)
    $__g_Cfg_bProfilesEnabled = $b
EndFunc

; [Carousel]
Func _Cfg_GetCarouselEnabled()
    Return $__g_Cfg_bCarouselEnabled
EndFunc
Func _Cfg_SetCarouselEnabled($b)
    $__g_Cfg_bCarouselEnabled = $b
EndFunc
Func _Cfg_GetCarouselInterval()
    Return $__g_Cfg_iCarouselInterval
EndFunc
Func _Cfg_SetCarouselInterval($i)
    If $i < 3000 Then $i = 3000
    If $i > 300000 Then $i = 300000
    $__g_Cfg_iCarouselInterval = $i
EndFunc
Func _Cfg_GetCarouselShowInMenu()
    Return $__g_Cfg_bCarouselShowInMenu
EndFunc
Func _Cfg_SetCarouselShowInMenu($b)
    $__g_Cfg_bCarouselShowInMenu = $b
EndFunc
Func _Cfg_GetNotifyCarouselToggle()
    Return $__g_Cfg_bNotifyCarouselToggle
EndFunc
Func _Cfg_SetNotifyCarouselToggle($b)
    $__g_Cfg_bNotifyCarouselToggle = $b
EndFunc
Func _Cfg_GetHotkeyToggleCarousel()
    Return $__g_Cfg_sHotkeyToggleCarousel
EndFunc
Func _Cfg_SetHotkeyToggleCarousel($s)
    $__g_Cfg_sHotkeyToggleCarousel = __Cfg_ClampStringLen($s, 32)
EndFunc
Func _Cfg_GetHotkeyTaskView()
    Return $__g_Cfg_sHotkeyTaskView
EndFunc
Func _Cfg_SetHotkeyTaskView($s)
    $__g_Cfg_sHotkeyTaskView = __Cfg_ClampStringLen($s, 32)
EndFunc

; [Tray]
Func _Cfg_GetTrayLeftClick()
    Return $__g_Cfg_sTrayLeftClick
EndFunc
Func _Cfg_SetTrayLeftClick($s)
    Local $sValid = "menu|toggle_list|next_desktop|nothing"
    If Not StringInStr("|" & $sValid & "|", "|" & $s & "|") Then $s = "menu"
    $__g_Cfg_sTrayLeftClick = $s
EndFunc
Func _Cfg_GetTrayDoubleClick()
    Return $__g_Cfg_sTrayDoubleClick
EndFunc
Func _Cfg_SetTrayDoubleClick($s)
    Local $sValid = "settings|toggle_list|menu|nothing"
    If Not StringInStr("|" & $sValid & "|", "|" & $s & "|") Then $s = "settings"
    $__g_Cfg_sTrayDoubleClick = $s
EndFunc
Func _Cfg_GetTrayMiddleClick()
    Return $__g_Cfg_sTrayMiddleClick
EndFunc
Func _Cfg_SetTrayMiddleClick($s)
    Local $sValid = "toggle_list|add_desktop|toggle_carousel|nothing"
    If Not StringInStr("|" & $sValid & "|", "|" & $s & "|") Then $s = "toggle_list"
    $__g_Cfg_sTrayMiddleClick = $s
EndFunc
Func _Cfg_GetTrayTooltipShowLabel()
    Return $__g_Cfg_bTrayTooltipShowLabel
EndFunc
Func _Cfg_SetTrayTooltipShowLabel($b)
    $__g_Cfg_bTrayTooltipShowLabel = $b
EndFunc
Func _Cfg_GetTrayTooltipShowCount()
    Return $__g_Cfg_bTrayTooltipShowCount
EndFunc
Func _Cfg_SetTrayTooltipShowCount($b)
    $__g_Cfg_bTrayTooltipShowCount = $b
EndFunc
Func _Cfg_GetTrayMenuShowList()
    Return $__g_Cfg_bTrayMenuShowList
EndFunc
Func _Cfg_SetTrayMenuShowList($b)
    $__g_Cfg_bTrayMenuShowList = $b
EndFunc
Func _Cfg_GetTrayMenuShowEdit()
    Return $__g_Cfg_bTrayMenuShowEdit
EndFunc
Func _Cfg_SetTrayMenuShowEdit($b)
    $__g_Cfg_bTrayMenuShowEdit = $b
EndFunc
Func _Cfg_GetTrayMenuShowAdd()
    Return $__g_Cfg_bTrayMenuShowAdd
EndFunc
Func _Cfg_SetTrayMenuShowAdd($b)
    $__g_Cfg_bTrayMenuShowAdd = $b
EndFunc
Func _Cfg_GetTrayMenuShowDelete()
    Return $__g_Cfg_bTrayMenuShowDelete
EndFunc
Func _Cfg_SetTrayMenuShowDelete($b)
    $__g_Cfg_bTrayMenuShowDelete = $b
EndFunc
Func _Cfg_GetTrayMenuShowDesktopSub()
    Return $__g_Cfg_bTrayMenuShowDesktopSub
EndFunc
Func _Cfg_SetTrayMenuShowDesktopSub($b)
    $__g_Cfg_bTrayMenuShowDesktopSub = $b
EndFunc
Func _Cfg_GetTrayMenuShowMoveWindow()
    Return $__g_Cfg_bTrayMenuShowMoveWindow
EndFunc
Func _Cfg_SetTrayMenuShowMoveWindow($b)
    $__g_Cfg_bTrayMenuShowMoveWindow = $b
EndFunc
Func _Cfg_GetTrayNotifySwitch()
    Return $__g_Cfg_bTrayNotifySwitch
EndFunc
Func _Cfg_SetTrayNotifySwitch($b)
    $__g_Cfg_bTrayNotifySwitch = $b
EndFunc
Func _Cfg_GetTrayBalloonDuration()
    Return $__g_Cfg_iTrayBalloonDuration
EndFunc
Func _Cfg_SetTrayBalloonDuration($i)
    If $i < 500 Then $i = 500
    If $i > 10000 Then $i = 10000
    $__g_Cfg_iTrayBalloonDuration = $i
EndFunc
Func _Cfg_GetTrayCloseToTray()
    Return $__g_Cfg_bTrayCloseToTray
EndFunc
Func _Cfg_SetTrayCloseToTray($b)
    $__g_Cfg_bTrayCloseToTray = $b
EndFunc

; =============================================
; STARTUP WITH WINDOWS
; =============================================

Func _Cfg_EnableStartup()
    Local $sKey = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Local $sCmd
    If @Compiled Then
        $sCmd = '"' & @ScriptFullPath & '" -autostart'
    Else
        $sCmd = '"' & @AutoItExe & '" "' & @ScriptFullPath & '" -autostart'
    EndIf
    RegWrite($sKey, "DeskSwitcheroo", "REG_SZ", $sCmd)
    ; Verify it was written
    Return (_Cfg_IsStartupEnabled())
EndFunc

Func _Cfg_DisableStartup()
    RegDelete("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "DeskSwitcheroo")
    ; Verify it was removed
    Return (Not _Cfg_IsStartupEnabled())
EndFunc

Func _Cfg_IsStartupEnabled()
    Local $sVal = RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "DeskSwitcheroo")
    Return ($sVal <> "")
EndFunc

; =============================================
; IMPORT / EXPORT
; =============================================

; Name:        _Cfg_Export
; Description: Exports current config to a specified INI file path
; Parameters:  $sDestPath - destination file path
; Return:      True on success, False on failure
Func _Cfg_Export($sDestPath)
    _Cfg_Save() ; ensure in-memory is persisted first
    Return FileCopy(_Cfg_GetPath(), $sDestPath, 1) ; 1 = overwrite
EndFunc

; Name:        _Cfg_Import
; Description: Imports config from a specified INI file, replacing current settings
; Parameters:  $sSrcPath - source file path
; Return:      True on success, False on failure
Func _Cfg_Import($sSrcPath)
    If Not FileExists($sSrcPath) Then Return False
    FileCopy($sSrcPath, _Cfg_GetPath(), 1)
    _Cfg_Load()
    Return True
EndFunc

; =============================================
; PERSISTENCE LAYER
; =============================================

; Name:        __Cfg_ReadFromFile
; Description: Checks if the INI file exists and is readable
; Return:      True if file is readable, False otherwise
Func __Cfg_ReadFromFile()
    Local $f = $__g_Cfg_sIniPath
    If Not FileExists($f) Then Return False
    Local $sTest = IniRead($f, "General", "wrap_navigation", Chr(0))
    If $sTest = Chr(0) Then Return False
    Return True
EndFunc

; Name:        __Cfg_WriteToFile
; Description: Wraps _Cfg_Save() with error checking — saves and verifies
; Return:      True if write succeeded, False otherwise
Func __Cfg_WriteToFile()
    Local $bResult = _Cfg_Save()
    Return $bResult
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

Func __Cfg_ReadBool($f, $sSection, $sKey, $bDefault)
    Local $s = StringLower(IniRead($f, $sSection, $sKey, ""))
    If $s = "true" Or $s = "1" Then Return True
    If $s = "false" Or $s = "0" Then Return False
    Return $bDefault
EndFunc

Func __Cfg_ReadInt($f, $sSection, $sKey, $iDefault, $iMin = -2147483648, $iMax = 2147483647)
    Local $s = IniRead($f, $sSection, $sKey, "")
    If $s = "" Or Not StringIsInt($s) Then Return $iDefault
    Local $i = Int($s)
    If $i < $iMin Then Return $iMin
    If $i > $iMax Then Return $iMax
    Return $i
EndFunc

Func __Cfg_ReadEnum($f, $sSection, $sKey, $sDefault, $sAllowed)
    Local $s = StringLower(IniRead($f, $sSection, $sKey, ""))
    Local $aAllowed = StringSplit($sAllowed, "|")
    Local $i
    For $i = 1 To $aAllowed[0]
        If $s = StringLower($aAllowed[$i]) Then Return $aAllowed[$i]
    Next
    Return $sDefault
EndFunc

Func __Cfg_WriteBool($f, $sSection, $sKey, $bValue)
    If $bValue Then
        IniWrite($f, $sSection, $sKey, "true")
    Else
        IniWrite($f, $sSection, $sKey, "false")
    EndIf
EndFunc

Func __Cfg_DefaultVal($f, $sSection, $sKey, $vDefault)
    Local $s = IniRead($f, $sSection, $sKey, Chr(0))
    If $s = Chr(0) Then IniWrite($f, $sSection, $sKey, $vDefault)
EndFunc

Func __Cfg_DefaultBool($f, $sSection, $sKey, $bDefault)
    Local $s = IniRead($f, $sSection, $sKey, Chr(0))
    If $s = Chr(0) Then __Cfg_WriteBool($f, $sSection, $sKey, $bDefault)
EndFunc

; Validates a process/exe name: must be a simple filename ending in .exe
; Returns the validated name or "explorer.exe" as fallback
Func __Cfg_ValidateExeName($s)
    $s = StringStripWS($s, 3)
    If StringLen($s) = 0 Or StringLen($s) > 64 Then Return "explorer.exe"
    If Not StringRegExp($s, '(?i)^[A-Za-z0-9_\-]+\.exe$') Then Return "explorer.exe"
    Return $s
EndFunc

; Validates a file path: rejects directory traversal, UNC paths, and overlength
; Returns True if valid, False if rejected
Func __Cfg_ValidatePath($s, $iMaxLen = 260)
    If StringLen($s) > $iMaxLen Then Return False
    If StringInStr($s, "..") Then Return False
    If StringLeft($s, 2) = "\\" Then Return False
    Return True
EndFunc

; Validates a wallpaper file path: must pass path validation + have image extension
; Returns True if valid, False if rejected
Func __Cfg_ValidateWallpaperPath($s)
    If Not __Cfg_ValidatePath($s, 260) Then Return False
    If Not StringRegExp($s, '(?i)\.(bmp|jpg|jpeg|png|gif|tif|tiff)$') Then Return False
    Return True
EndFunc

; Clamps a string to a maximum length
Func __Cfg_ClampStringLen($s, $iMax)
    If StringLen($s) > $iMax Then Return StringLeft($s, $iMax)
    Return $s
EndFunc
