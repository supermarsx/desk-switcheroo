#include-once
#include "Config.au3"
#include "Logger.au3"

; #INDEX# =======================================================
; Title .........: Wallpaper
; Description ....: Per-desktop wallpaper management via SystemParametersInfo
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_WP_sCurrentPath = ""
Global $__g_WP_hTimer = 0
Global $__g_WP_iPendingDesktop = 0

; #FUNCTIONS# ===================================================

; Name:        _WP_Init
; Description: Reads the current system wallpaper as baseline
Func _WP_Init()
    $__g_WP_sCurrentPath = RegRead("HKEY_CURRENT_USER\Control Panel\Desktop", "Wallpaper")
    If @error Then $__g_WP_sCurrentPath = ""
    _Log_Debug("Wallpaper: baseline path = " & $__g_WP_sCurrentPath)
EndFunc

; Name:        _WP_OnDesktopChanged
; Description: Called when the active desktop changes. Starts a debounce timer.
; Parameters:  $iDesktop - the new active desktop (1-based)
Func _WP_OnDesktopChanged($iDesktop)
    If Not _Cfg_GetWallpaperEnabled() Then Return
    $__g_WP_iPendingDesktop = $iDesktop
    $__g_WP_hTimer = TimerInit()
EndFunc

; Name:        _WP_Tick
; Description: Called from main loop. Applies wallpaper after debounce delay.
Func _WP_Tick()
    If $__g_WP_hTimer = 0 Then Return
    If TimerDiff($__g_WP_hTimer) < _Cfg_GetWallpaperChangeDelay() Then Return
    $__g_WP_hTimer = 0
    _WP_Apply($__g_WP_iPendingDesktop)
EndFunc

; Name:        _WP_Apply
; Description: Applies the configured wallpaper for a desktop
; Parameters:  $iDesktop - desktop index (1-based)
Func _WP_Apply($iDesktop)
    If Not _Cfg_GetWallpaperEnabled() Then Return
    Local $sPath = _Cfg_GetDesktopWallpaper($iDesktop)
    If $sPath = "" Then Return ; no wallpaper configured for this desktop
    If Not FileExists($sPath) Then
        _Log_Warn("Wallpaper: file not found: " & $sPath)
        Return
    EndIf
    If $sPath = $__g_WP_sCurrentPath Then Return ; already applied
    $__g_WP_sCurrentPath = $sPath
    ; SPI_SETDESKWALLPAPER = 0x0014, SPIF_UPDATEINIFILE = 0x01, SPIF_SENDCHANGE = 0x02
    DllCall("user32.dll", "int", "SystemParametersInfoW", _
        "uint", 0x0014, "uint", 0, "wstr", $sPath, "uint", 0x03)
    If @error Then
        _Log_Error("Wallpaper: SystemParametersInfoW failed for " & $sPath)
    Else
        _Log_Info("Wallpaper: applied " & $sPath & " for desktop " & $iDesktop)
    EndIf
EndFunc

; Name:        _WP_GetCurrentPath
; Description: Returns the currently applied wallpaper path
; Return:      String path or ""
Func _WP_GetCurrentPath()
    Return $__g_WP_sCurrentPath
EndFunc
