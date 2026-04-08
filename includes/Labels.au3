#include-once
#include "VirtualDesktop.au3"

; #INDEX# =======================================================
; Title .........: Labels
; Description ....: Desktop label persistence — syncs with OS desktop names when
;                   supported (Windows 11+), falls back to INI file storage
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_Labels_IniPath = ""
Global $__g_Labels_bSyncOS = False
Global $__g_Labels_iLastCount = 0
Global $__g_Labels_sLastHash = ""

; #FUNCTIONS# ===================================================

; Name:        _Labels_Init
; Description: Sets the INI file path and enables OS name sync if supported.
;              On first init with sync enabled, performs a one-time merge:
;              OS names take priority; INI-only names are pushed to the OS.
; Parameters:  $sPath - full path to INI file (default: @ScriptDir & "\desktop_labels.ini")
;              $bSyncOS - enable OS name sync (default: True, auto-disabled if unsupported)
Func _Labels_Init($sPath = Default, $bSyncOS = True)
    If $sPath = Default Then $sPath = @ScriptDir & "\desktop_labels.ini"
    $__g_Labels_IniPath = $sPath
    $__g_Labels_bSyncOS = ($bSyncOS And _VD_HasNameSupport())

    If $__g_Labels_bSyncOS Then _Labels_InitialSync()
EndFunc

; Name:        _Labels_GetPath
; Description: Returns the current INI file path (for testing)
; Return:      Path string
Func _Labels_GetPath()
    Return $__g_Labels_IniPath
EndFunc

; Name:        _Labels_IsSyncEnabled
; Description: Returns whether OS name sync is active
; Return:      True/False
Func _Labels_IsSyncEnabled()
    Return $__g_Labels_bSyncOS
EndFunc

; Name:        _Labels_Load
; Description: Loads a desktop label. Reads from OS when sync is enabled,
;              falls back to INI file.
; Parameters:  $iIndex - desktop index (1-based)
; Return:      Label string, or "" if not set
Func _Labels_Load($iIndex)
    If $__g_Labels_bSyncOS Then
        Local $sOsName = _VD_GetName($iIndex)
        If $sOsName <> "" Then Return $sOsName
    EndIf
    Return IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $iIndex, "")
EndFunc

; Name:        _Labels_Save
; Description: Saves a desktop label. Writes to both OS and INI when sync is
;              enabled, INI-only otherwise.
; Parameters:  $iIndex - desktop index (1-based)
;              $sText - label text
Func _Labels_Save($iIndex, $sText)
    If $__g_Labels_bSyncOS Then _VD_SetName($iIndex, $sText)
    IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $iIndex, $sText)
EndFunc

; Name:        _Labels_SyncFromOS
; Description: Checks if any OS desktop name changed externally (e.g. via Task View)
;              and updates the INI + returns whether anything changed.
;              Call from the main poll loop.
; Return:      True if any name changed, False otherwise
Func _Labels_SyncFromOS()
    If Not $__g_Labels_bSyncOS Then Return False
    Local $bChanged = False
    Local $iCount = _VD_GetCount()

    ; Desktop count changed — re-push all INI names to OS
    If $iCount <> $__g_Labels_iLastCount Then
        _Labels_PushAllToOS($iCount)
        $__g_Labels_iLastCount = $iCount
        Return True
    EndIf

    ; Build a fingerprint of all OS names to detect changes cheaply
    Local $sHash = ""
    Local $aNames[$iCount + 1]
    Local $i
    For $i = 1 To $iCount
        $aNames[$i] = _VD_GetName($i)
        $sHash &= $aNames[$i] & "|"
    Next

    ; If fingerprint unchanged, skip the INI read/write loop entirely
    If $sHash = $__g_Labels_sLastHash Then Return False
    $__g_Labels_sLastHash = $sHash

    ; Normal poll — pull non-empty OS names into INI
    For $i = 1 To $iCount
        Local $sOsName = $aNames[$i]
        ; Skip empty OS reads — don't erase INI labels due to read failures
        ; or race conditions right after SetName
        If $sOsName = "" Then ContinueLoop
        Local $sIniName = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $i, "")
        If $sOsName <> $sIniName Then
            IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $i, $sOsName)
            $bChanged = True
        EndIf
    Next
    Return $bChanged
EndFunc

; Name:        _Labels_InitialSync
; Description: One-time merge on startup: OS names win; INI-only names are pushed to OS.
Func _Labels_InitialSync()
    Local $iCount = _VD_GetCount()
    $__g_Labels_iLastCount = $iCount
    _Labels_PushAllToOS($iCount)
EndFunc

; Name:        _Labels_PushAllToOS
; Description: Pushes all INI labels to the OS for desktops that have no OS name.
;              OS names take priority (are not overwritten).
; Parameters:  $iCount - number of desktops to sync
Func _Labels_PushAllToOS($iCount)
    For $i = 1 To $iCount
        Local $sOsName = _VD_GetName($i)
        Local $sIniName = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $i, "")
        If $sOsName <> "" Then
            ; OS has a name — make INI match
            If $sIniName <> $sOsName Then
                IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $i, $sOsName)
            EndIf
        ElseIf $sIniName <> "" Then
            ; INI has a name but OS doesn't — push to OS
            _VD_SetName($i, $sIniName)
        EndIf
    Next
EndFunc
