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

; [General]
Global $__g_Cfg_bStartWithWindows  = False
Global $__g_Cfg_bWrapNavigation    = True
Global $__g_Cfg_bAutoCreateDesktop = False
Global $__g_Cfg_iNumberPadding     = 2
Global $__g_Cfg_sWidgetPosition    = "left"
Global $__g_Cfg_iWidgetOffsetX     = 0
Global $__g_Cfg_bWidgetDragEnabled = False
Global $__g_Cfg_bTrayIconMode     = False
Global $__g_Cfg_bQuickAccessEnabled = False
Global $__g_Cfg_bStartMinimized    = False
Global $__g_Cfg_bListKeyboardNav   = False
Global $__g_Cfg_bAutoUpdateEnabled = False
Global $__g_Cfg_iAutoUpdateInterval = 168

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
Global $__g_Cfg_iHotkeyDesktopCount = 9

; [Scroll]
Global $__g_Cfg_bScrollEnabled     = False
Global $__g_Cfg_sScrollDirection   = "normal"
Global $__g_Cfg_bScrollWrap        = True
Global $__g_Cfg_bListScrollEnabled = False
Global $__g_Cfg_sListScrollAction  = "switch"

; [Hotkeys]
Global $__g_Cfg_sHotkeyNext        = ""
Global $__g_Cfg_sHotkeyPrev        = ""
Global $__g_Cfg_sHotkeyDesktop[10] ; index 1-9
$__g_Cfg_sHotkeyDesktop[0] = 9
For $__i = 1 To 9
    $__g_Cfg_sHotkeyDesktop[$__i] = ""
Next
Global $__g_Cfg_sHotkeyToggleList  = ""

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

; [Display] - List font
Global $__g_Cfg_sListFontName      = ""
Global $__g_Cfg_iListFontSize      = 8

; [Logging]
Global $__g_Cfg_bLoggingEnabled    = False
Global $__g_Cfg_sLogFilePath       = ""
Global $__g_Cfg_sLogLevel          = "info"
Global $__g_Cfg_iLogMaxSizeMB      = 5

; [DesktopColors]
Global $__g_Cfg_bDesktopColorsEnabled = False
Global $__g_Cfg_aDesktopColors[10]
$__g_Cfg_aDesktopColors[0] = 9
$__g_Cfg_aDesktopColors[1] = 0
$__g_Cfg_aDesktopColors[2] = 0
$__g_Cfg_aDesktopColors[3] = 0
$__g_Cfg_aDesktopColors[4] = 0
$__g_Cfg_aDesktopColors[5] = 0
$__g_Cfg_aDesktopColors[6] = 0
$__g_Cfg_aDesktopColors[7] = 0
$__g_Cfg_aDesktopColors[8] = 0
$__g_Cfg_aDesktopColors[9] = 0

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

; Name:        _Cfg_Load
; Description: Reads all values from INI into memory, with validation
Func _Cfg_Load()
    If Not __Cfg_ReadFromFile() Then
        _Log_Warn("Config file not readable, using defaults")
    EndIf

    Local $f = $__g_Cfg_sIniPath

    ; [General]
    $__g_Cfg_bStartWithWindows  = __Cfg_ReadBool($f, "General", "start_with_windows", False)
    $__g_Cfg_bWrapNavigation    = __Cfg_ReadBool($f, "General", "wrap_navigation", True)
    $__g_Cfg_bAutoCreateDesktop = __Cfg_ReadBool($f, "General", "auto_create_desktop", False)
    $__g_Cfg_iNumberPadding     = __Cfg_ReadInt($f, "General", "number_padding", 2, 1, 4)
    $__g_Cfg_sWidgetPosition    = __Cfg_ReadEnum($f, "General", "widget_position", "left", "left|center|right")
    $__g_Cfg_iWidgetOffsetX     = __Cfg_ReadInt($f, "General", "widget_offset_x", 0, -9999, 9999)
    $__g_Cfg_bWidgetDragEnabled = __Cfg_ReadBool($f, "General", "widget_drag_enabled", False)
    $__g_Cfg_bTrayIconMode     = __Cfg_ReadBool($f, "General", "tray_icon_mode", False)
    $__g_Cfg_bQuickAccessEnabled = __Cfg_ReadBool($f, "General", "quick_access_enabled", False)
    $__g_Cfg_bStartMinimized    = __Cfg_ReadBool($f, "General", "start_minimized", False)
    $__g_Cfg_bListKeyboardNav   = __Cfg_ReadBool($f, "General", "list_keyboard_nav", False)
    $__g_Cfg_bAutoUpdateEnabled = __Cfg_ReadBool($f, "General", "auto_update_enabled", False)
    $__g_Cfg_iAutoUpdateInterval = __Cfg_ReadInt($f, "General", "auto_update_interval", 168, 1, 720)

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

    ; [Scroll]
    $__g_Cfg_bScrollEnabled     = __Cfg_ReadBool($f, "Scroll", "scroll_enabled", False)
    $__g_Cfg_sScrollDirection   = __Cfg_ReadEnum($f, "Scroll", "scroll_direction", "normal", "normal|inverted")
    $__g_Cfg_bScrollWrap        = __Cfg_ReadBool($f, "Scroll", "scroll_wrap", True)
    $__g_Cfg_bListScrollEnabled = __Cfg_ReadBool($f, "Scroll", "list_scroll_enabled", False)
    $__g_Cfg_sListScrollAction  = __Cfg_ReadEnum($f, "Scroll", "list_scroll_action", "switch", "switch|scroll")

    ; [Hotkeys]
    $__g_Cfg_iHotkeyDesktopCount = __Cfg_ReadInt($f, "Hotkeys", "hotkey_desktop_count", 9, 1, 20)
    $__g_Cfg_sHotkeyNext       = IniRead($f, "Hotkeys", "hotkey_next", "")
    $__g_Cfg_sHotkeyPrev       = IniRead($f, "Hotkeys", "hotkey_prev", "")
    Local $i
    For $i = 1 To 9
        $__g_Cfg_sHotkeyDesktop[$i] = IniRead($f, "Hotkeys", "hotkey_desktop_" & $i, "")
    Next
    $__g_Cfg_sHotkeyToggleList = IniRead($f, "Hotkeys", "hotkey_toggle_list", "")

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

    ; [Logging]
    $__g_Cfg_bLoggingEnabled    = __Cfg_ReadBool($f, "Logging", "logging_enabled", False)
    $__g_Cfg_sLogFilePath       = IniRead($f, "Logging", "log_file_path", "")
    $__g_Cfg_sLogLevel          = __Cfg_ReadEnum($f, "Logging", "log_level", "info", "error|warn|info|debug")
    $__g_Cfg_iLogMaxSizeMB      = __Cfg_ReadInt($f, "Logging", "log_max_size_mb", 5, 1, 50)

    ; [DesktopColors]
    $__g_Cfg_bDesktopColorsEnabled = __Cfg_ReadBool($f, "DesktopColors", "desktop_colors_enabled", False)
    Local $aDefColors[10] = [9, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    For $i = 1 To 9
        Local $sVal = IniRead($f, "DesktopColors", "desktop_" & $i & "_color", "")
        If $sVal <> "" And StringLeft($sVal, 2) = "0x" Then
            $__g_Cfg_aDesktopColors[$i] = Int($sVal)
        Else
            $__g_Cfg_aDesktopColors[$i] = $aDefColors[$i]
        EndIf
    Next
EndFunc

; Name:        _Cfg_Save
; Description: Writes all in-memory values to the INI file
Func _Cfg_Save()
    Local $f = $__g_Cfg_sIniPath

    ; [General]
    __Cfg_WriteBool($f, "General", "start_with_windows", $__g_Cfg_bStartWithWindows)
    __Cfg_WriteBool($f, "General", "wrap_navigation", $__g_Cfg_bWrapNavigation)
    __Cfg_WriteBool($f, "General", "auto_create_desktop", $__g_Cfg_bAutoCreateDesktop)
    IniWrite($f, "General", "number_padding", $__g_Cfg_iNumberPadding)
    IniWrite($f, "General", "widget_position", $__g_Cfg_sWidgetPosition)
    IniWrite($f, "General", "widget_offset_x", $__g_Cfg_iWidgetOffsetX)
    __Cfg_WriteBool($f, "General", "widget_drag_enabled", $__g_Cfg_bWidgetDragEnabled)
    __Cfg_WriteBool($f, "General", "tray_icon_mode", $__g_Cfg_bTrayIconMode)
    __Cfg_WriteBool($f, "General", "quick_access_enabled", $__g_Cfg_bQuickAccessEnabled)
    __Cfg_WriteBool($f, "General", "start_minimized", $__g_Cfg_bStartMinimized)
    __Cfg_WriteBool($f, "General", "list_keyboard_nav", $__g_Cfg_bListKeyboardNav)
    __Cfg_WriteBool($f, "General", "auto_update_enabled", $__g_Cfg_bAutoUpdateEnabled)
    IniWrite($f, "General", "auto_update_interval", $__g_Cfg_iAutoUpdateInterval)

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

    ; [Logging]
    __Cfg_WriteBool($f, "Logging", "logging_enabled", $__g_Cfg_bLoggingEnabled)
    IniWrite($f, "Logging", "log_file_path", $__g_Cfg_sLogFilePath)
    IniWrite($f, "Logging", "log_level", $__g_Cfg_sLogLevel)
    IniWrite($f, "Logging", "log_max_size_mb", $__g_Cfg_iLogMaxSizeMB)

    ; [DesktopColors]
    __Cfg_WriteBool($f, "DesktopColors", "desktop_colors_enabled", $__g_Cfg_bDesktopColorsEnabled)
    For $i = 1 To 9
        IniWrite($f, "DesktopColors", "desktop_" & $i & "_color", "0x" & Hex($__g_Cfg_aDesktopColors[$i], 6))
    Next

    ; Verify write succeeded
    Local $sVerify = IniRead($f, "General", "wrap_navigation", "")
    If $sVerify = "" Then Return False
    Return True
EndFunc

; Name:        _Cfg_WriteDefaults
; Description: Writes default values for any missing keys (preserves existing user values)
Func _Cfg_WriteDefaults()
    Local $f = $__g_Cfg_sIniPath

    __Cfg_DefaultBool($f, "General", "start_with_windows", False)
    __Cfg_DefaultBool($f, "General", "wrap_navigation", True)
    __Cfg_DefaultBool($f, "General", "auto_create_desktop", False)
    __Cfg_DefaultVal($f, "General", "number_padding", 2)
    __Cfg_DefaultVal($f, "General", "widget_position", "left")
    __Cfg_DefaultVal($f, "General", "widget_offset_x", 0)
    __Cfg_DefaultBool($f, "General", "widget_drag_enabled", False)
    __Cfg_DefaultBool($f, "General", "tray_icon_mode", False)
    __Cfg_DefaultBool($f, "General", "quick_access_enabled", False)
    __Cfg_DefaultBool($f, "General", "start_minimized", False)
    __Cfg_DefaultBool($f, "General", "list_keyboard_nav", False)
    __Cfg_DefaultBool($f, "General", "auto_update_enabled", False)
    __Cfg_DefaultVal($f, "General", "auto_update_interval", 168)

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

    __Cfg_DefaultBool($f, "Scroll", "scroll_enabled", False)
    __Cfg_DefaultVal($f, "Scroll", "scroll_direction", "normal")
    __Cfg_DefaultBool($f, "Scroll", "scroll_wrap", True)
    __Cfg_DefaultBool($f, "Scroll", "list_scroll_enabled", False)
    __Cfg_DefaultVal($f, "Scroll", "list_scroll_action", "switch")

    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_desktop_count", 9)
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_next", "")
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_prev", "")
    Local $i
    For $i = 1 To 9
        __Cfg_DefaultVal($f, "Hotkeys", "hotkey_desktop_" & $i, "")
    Next
    __Cfg_DefaultVal($f, "Hotkeys", "hotkey_toggle_list", "")

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

    __Cfg_DefaultBool($f, "Logging", "logging_enabled", False)
    __Cfg_DefaultVal($f, "Logging", "log_file_path", "")
    __Cfg_DefaultVal($f, "Logging", "log_level", "info")
    __Cfg_DefaultVal($f, "Logging", "log_max_size_mb", 5)

    __Cfg_DefaultBool($f, "DesktopColors", "desktop_colors_enabled", False)
    Local $aDefColors[10] = [9, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    For $i = 1 To 9
        __Cfg_DefaultVal($f, "DesktopColors", "desktop_" & $i & "_color", "0x" & Hex($aDefColors[$i], 6))
    Next
EndFunc

; =============================================
; TYPED GETTERS
; =============================================

; [General]
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
    Return $__g_Cfg_sWidgetPosition
EndFunc
Func _Cfg_GetWidgetOffsetX()
    Return $__g_Cfg_iWidgetOffsetX
EndFunc
Func _Cfg_GetWidgetDragEnabled()
    Return $__g_Cfg_bWidgetDragEnabled
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
    If $i > 20 Then $i = 20
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

; [Logging]
Func _Cfg_GetLoggingEnabled()
    Return $__g_Cfg_bLoggingEnabled
EndFunc
Func _Cfg_GetLogFilePath()
    Return $__g_Cfg_sLogFilePath
EndFunc
Func _Cfg_GetLogLevel()
    Return $__g_Cfg_sLogLevel
EndFunc
Func _Cfg_GetLogMaxSizeMB()
    Return $__g_Cfg_iLogMaxSizeMB
EndFunc

; [DesktopColors]
Func _Cfg_GetDesktopColorsEnabled()
    Return $__g_Cfg_bDesktopColorsEnabled
EndFunc
Func _Cfg_GetDesktopColor($i)
    If $i < 1 Or $i > 9 Then Return 0
    Return $__g_Cfg_aDesktopColors[$i]
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
    If $s <> "left" And $s <> "center" And $s <> "right" Then $s = "left"
    $__g_Cfg_sWidgetPosition = $s
EndFunc
Func _Cfg_SetWidgetOffsetX($i)
    $__g_Cfg_iWidgetOffsetX = Int($i)
EndFunc
Func _Cfg_SetWidgetDragEnabled($b)
    $__g_Cfg_bWidgetDragEnabled = $b
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
    $__g_Cfg_sListFontName = $s
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
    $__g_Cfg_sHotkeyNext = $s
EndFunc
Func _Cfg_SetHotkeyPrev($s)
    $__g_Cfg_sHotkeyPrev = $s
EndFunc
Func _Cfg_SetHotkeyDesktop($i, $s)
    If $i >= 1 And $i <= 9 Then $__g_Cfg_sHotkeyDesktop[$i] = $s
EndFunc
Func _Cfg_SetHotkeyToggleList($s)
    $__g_Cfg_sHotkeyToggleList = $s
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

; [Logging]
Func _Cfg_SetLoggingEnabled($b)
    $__g_Cfg_bLoggingEnabled = $b
EndFunc
Func _Cfg_SetLogFilePath($s)
    $__g_Cfg_sLogFilePath = $s
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

; [DesktopColors]
Func _Cfg_SetDesktopColorsEnabled($b)
    $__g_Cfg_bDesktopColorsEnabled = $b
EndFunc
Func _Cfg_SetDesktopColor($i, $iColor)
    If $i >= 1 And $i <= 9 Then $__g_Cfg_aDesktopColors[$i] = Int($iColor)
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
        If $s = $aAllowed[$i] Then Return $s
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
