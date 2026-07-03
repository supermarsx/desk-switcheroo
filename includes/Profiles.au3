#include-once
#include <File.au3>
#include "Config.au3"
#include "Labels.au3"
#include "VirtualDesktop.au3"
#include "Logger.au3"
#include "Hooks.au3"

; #INDEX# =======================================================
; Title .........: Profiles
; Description ....: Named desktop profile management — save/load/delete desktop
;                   configurations (count, labels, colors, wallpapers) as INI files
; Author .........: Mariana
; ===============================================================
; Index:
;   _Prof_SaveProfile       Save current state as named profile
;   _Prof_LoadProfile       Load and apply a named profile
;   _Prof_DeleteProfile     Delete a named profile
;   _Prof_ListProfiles      List all available profile names
;   _Prof_ProfileExists     Check if a profile exists
;   _Prof_GetProfilePath    Get filesystem path for a profile
;   _Prof_IsEnabled         Check if profiles feature is enabled
;   __Prof_SanitizeName     Sanitize profile name for filesystem
;   __Prof_EnsureDir        Ensure profiles directory exists
;   __Prof_ReadProfileMeta  Read profile metadata (name, date, desktop count)
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_Prof_bEnabled = False
Global $__g_Prof_sDir = ""

; #FUNCTIONS# ===================================================

; Name:        _Prof_Init
; Description: Initializes the profiles module. Reads enabled state from config.
; Parameters:  $sBaseDir - base directory (default: @ScriptDir)
Func _Prof_Init($sBaseDir = Default)
    If $sBaseDir = Default Then $sBaseDir = @ScriptDir
    $__g_Prof_sDir = $sBaseDir & "\profiles"
    ; Single source of truth: the typed config accessor (loaded from the INI by
    ; _Cfg_Load) rather than a second direct IniRead against a hardcoded path.
    $__g_Prof_bEnabled = _Cfg_GetProfilesEnabled()
    _Log_Debug("Profiles: init enabled=" & $__g_Prof_bEnabled & " dir=" & $__g_Prof_sDir)
EndFunc

; Name:        _Prof_IsEnabled
; Description: Returns whether the profiles feature is enabled in config
; Return:      True/False
Func _Prof_IsEnabled()
    Return $__g_Prof_bEnabled
EndFunc

; Name:        _Prof_GetProfilePath
; Description: Returns the full filesystem path for a named profile
; Parameters:  $sName - profile name (will be sanitized)
; Return:      Full path string
Func _Prof_GetProfilePath($sName)
    Local $sClean = __Prof_SanitizeName($sName)
    Return $__g_Prof_sDir & "\" & $sClean & ".ini"
EndFunc

; Name:        _Prof_ProfileExists
; Description: Checks whether a named profile exists on disk
; Parameters:  $sName - profile name
; Return:      True if profile INI file exists, False otherwise
Func _Prof_ProfileExists($sName)
    Return FileExists(_Prof_GetProfilePath($sName))
EndFunc

; Name:        _Prof_SaveProfile
; Description: Snapshots the current desktop state (count, labels, colors,
;              wallpapers) into a named profile INI file. Creates the profiles
;              directory if needed. Overwrites if the profile already exists.
; Parameters:  $sName - profile name
; Return:      True on success, False on failure
Func _Prof_SaveProfile($sName)
    If Not $__g_Prof_bEnabled Then
        _Log_Warn("Profiles: save rejected — feature disabled")
        Return False
    EndIf

    Local $sClean = __Prof_SanitizeName($sName)
    If $sClean = "" Then
        _Log_Error("Profiles: save failed — empty name after sanitization")
        Return False
    EndIf

    __Prof_EnsureDir()

    Local $sPath = _Prof_GetProfilePath($sName)
    Local $iCount = _VD_GetCount()
    Local $sMainIni = @ScriptDir & "\desk_switcheroo.ini"

    ; Delete existing file to start fresh
    If FileExists($sPath) Then FileDelete($sPath)

    ; [Meta]
    Local $sNow = @YEAR & "-" & @MON & "-" & @MDAY & "T" & @HOUR & ":" & @MIN & ":" & @SEC
    IniWrite($sPath, "Meta", "name", $sName)
    IniWrite($sPath, "Meta", "created", $sNow)
    IniWrite($sPath, "Meta", "modified", $sNow)
    IniWrite($sPath, "Meta", "desktop_count", $iCount)

    ; Per-desktop data
    Local $i
    For $i = 1 To $iCount
        ; Labels
        Local $sLabel = _Labels_Load($i)
        IniWrite($sPath, "Labels", "label_" & $i, $sLabel)

        ; Colors — read from main config INI [DesktopColors] section
        Local $sColor = IniRead($sMainIni, "DesktopColors", "desktop_" & $i & "_color", "")
        IniWrite($sPath, "Colors", "color_" & $i, $sColor)

        ; Wallpapers — read from main config INI [Wallpaper] section
        Local $sWallpaper = IniRead($sMainIni, "Wallpaper", "desktop_" & $i & "_wallpaper", "")
        IniWrite($sPath, "Wallpapers", "wallpaper_" & $i, $sWallpaper)
    Next

    _Log_Info("Profiles: saved '" & $sClean & "' with " & $iCount & " desktops")
    Return True
EndFunc

; Name:        _Prof_LoadProfile
; Description: Reads a named profile and applies it: adjusts desktop count,
;              sets labels, colors, and wallpapers. Triggers a config reload.
; Parameters:  $sName - profile name
; Return:      True on success, False on failure
Func _Prof_LoadProfile($sName)
    If Not $__g_Prof_bEnabled Then
        _Log_Warn("Profiles: load rejected — feature disabled")
        Return False
    EndIf

    Local $sPath = _Prof_GetProfilePath($sName)
    If Not FileExists($sPath) Then
        _Log_Error("Profiles: load failed — profile not found: " & $sPath)
        Return False
    EndIf

    ; Read target desktop count
    Local $iTarget = Int(IniRead($sPath, "Meta", "desktop_count", "0"))
    If $iTarget < 1 Then
        _Log_Error("Profiles: load failed — invalid desktop_count in profile")
        Return False
    EndIf

    ; Adjust desktop count
    Local $iCurrent = _VD_GetCount()
    Local $i

    If $iTarget > $iCurrent Then
        ; Create additional desktops — poll the count instead of a fixed 100 ms wait
        ; so the common case proceeds as soon as the create is reflected.
        For $i = 1 To ($iTarget - $iCurrent)
            _VD_CreateDesktop()
            __Prof_WaitForCount($iCurrent + $i)
        Next
    ElseIf $iTarget < $iCurrent Then
        ; Remove excess desktops from the end (poll the count, see above)
        For $i = $iCurrent To ($iTarget + 1) Step -1
            _VD_RemoveDesktop($i)
            __Prof_WaitForCount($i - 1)
        Next
    EndIf

    ; Apply per-desktop settings
    Local $sMainIni = @ScriptDir & "\desk_switcheroo.ini"

    For $i = 1 To $iTarget
        ; Labels
        Local $sLabel = IniRead($sPath, "Labels", "label_" & $i, "")
        _Labels_Save($i, $sLabel)

        ; Colors — write to main config INI [DesktopColors] section
        Local $sColor = IniRead($sPath, "Colors", "color_" & $i, "")
        If $sColor <> "" Then
            IniWrite($sMainIni, "DesktopColors", "desktop_" & $i & "_color", $sColor)
        Else
            IniWrite($sMainIni, "DesktopColors", "desktop_" & $i & "_color", "")
        EndIf

        ; Wallpapers — write to main config INI [Wallpaper] section
        Local $sWallpaper = IniRead($sPath, "Wallpapers", "wallpaper_" & $i, "")
        IniWrite($sMainIni, "Wallpaper", "desktop_" & $i & "_wallpaper", $sWallpaper)
    Next

    ; Trigger config reload so in-memory state reflects the INI changes
    _Cfg_Load()

    ; Fire the profile-load hook here (not at the hotkey call site) so hotkey AND CLI
    ; loads both notify. Async fire (default) is correct — no blocking on the handler.
    _Hooks_Fire("on_profile_load", "profile=" & __Prof_SanitizeName($sName) & "|desktop_count=" & $iTarget)

    _Log_Info("Profiles: loaded '" & __Prof_SanitizeName($sName) & "' with " & $iTarget & " desktops")
    Return True
EndFunc

; Name:        _Prof_DeleteProfile
; Description: Deletes a named profile's INI file from disk
; Parameters:  $sName - profile name
; Return:      True on success, False if not found or delete failed
Func _Prof_DeleteProfile($sName)
    If Not $__g_Prof_bEnabled Then
        _Log_Warn("Profiles: delete rejected — feature disabled")
        Return False
    EndIf

    Local $sPath = _Prof_GetProfilePath($sName)
    If Not FileExists($sPath) Then
        _Log_Warn("Profiles: delete failed — profile not found: " & $sPath)
        Return False
    EndIf

    Local $bResult = FileDelete($sPath)
    If $bResult Then
        _Log_Info("Profiles: deleted '" & __Prof_SanitizeName($sName) & "'")
    Else
        _Log_Error("Profiles: delete failed for '" & __Prof_SanitizeName($sName) & "'")
    EndIf
    Return $bResult
EndFunc

; Name:        _Prof_ListProfiles
; Description: Returns a pipe-delimited string of available profile names
;              (derived from filenames in the profiles directory)
; Return:      String e.g. "work|gaming|study", or "" if none
Func _Prof_ListProfiles()
    If Not FileExists($__g_Prof_sDir) Then Return ""
    Local $aFiles = _FileListToArray($__g_Prof_sDir, "*.ini", 1) ; 1 = files only
    If @error Then Return ""
    Local $sResult = ""
    Local $i
    For $i = 1 To $aFiles[0]
        Local $sName = StringTrimRight($aFiles[$i], 4) ; remove .ini
        If $sResult <> "" Then $sResult &= "|"
        $sResult &= $sName
    Next
    Return $sResult
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

; Name:        __Prof_WaitForCount
; Description: Polls the virtual-desktop count until it reaches $iExpected or the
;              timeout elapses, re-querying the DLL each poll. Replaces a fixed per-step
;              Sleep during profile apply so the common case returns as soon as a
;              create/remove is reflected instead of always blocking the full delay.
; Parameters:  $iExpected  - the desktop count to wait for
;              $iTimeoutMs - max time to wait, ms (default 200)
;              $iPollMs    - poll interval, ms (default 10)
; Return:      True if the count reached $iExpected, False on timeout
Func __Prof_WaitForCount($iExpected, $iTimeoutMs = 200, $iPollMs = 10)
    Local $hTimer = TimerInit()
    Do
        _VD_InvalidateCountCache()
        If _VD_GetCount() = $iExpected Then Return True
        Sleep($iPollMs)
    Until TimerDiff($hTimer) > $iTimeoutMs
    Return False
EndFunc

; Name:        __Prof_SanitizeName
; Description: Sanitizes a profile name for filesystem safety.
;              Allows only alphanumeric, underscore, and dash characters.
;              Defaults to "default" if empty after cleaning. Caps at 64 chars.
; Parameters:  $sName - raw profile name
; Return:      Sanitized lowercase string
Func __Prof_SanitizeName($sName)
    Local $sClean = StringRegExpReplace($sName, "[^a-zA-Z0-9_\-]", "")
    If $sClean = "" Then $sClean = "default"
    If StringLen($sClean) > 64 Then $sClean = StringLeft($sClean, 64)
    Return StringLower($sClean)
EndFunc

; Name:        __Prof_EnsureDir
; Description: Creates the profiles directory if it does not exist
Func __Prof_EnsureDir()
    If Not FileExists($__g_Prof_sDir) Then
        DirCreate($__g_Prof_sDir)
        _Log_Debug("Profiles: created directory " & $__g_Prof_sDir)
    EndIf
EndFunc

; Name:        __Prof_ReadProfileMeta
; Description: Reads profile metadata from an INI file.
;              Returns an array: [0]=name, [1]=created, [2]=modified, [3]=desktop_count
; Parameters:  $sPath - full path to the profile INI
; Return:      Array with 4 elements, or empty array on failure
Func __Prof_ReadProfileMeta($sPath)
    If Not FileExists($sPath) Then
        Local $aEmpty[0]
        Return SetError(1, 0, $aEmpty)
    EndIf
    Local $aMeta[4]
    $aMeta[0] = IniRead($sPath, "Meta", "name", "")
    $aMeta[1] = IniRead($sPath, "Meta", "created", "")
    $aMeta[2] = IniRead($sPath, "Meta", "modified", "")
    $aMeta[3] = Int(IniRead($sPath, "Meta", "desktop_count", "0"))
    Return $aMeta
EndFunc
