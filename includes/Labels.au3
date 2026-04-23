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
Global $__g_Labels_aCache[21]  ; in-memory cache, index 1-20
Global $__g_Labels_bCacheDirty = True

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
    ; Return from cache if valid
    If Not $__g_Labels_bCacheDirty And $iIndex >= 1 And $iIndex <= 20 Then
        Return $__g_Labels_aCache[$iIndex]
    EndIf
    If $__g_Labels_bSyncOS Then
        Local $sOsName = _VD_GetName($iIndex)
        If $sOsName <> "" Then
            If $iIndex >= 1 And $iIndex <= 20 Then $__g_Labels_aCache[$iIndex] = $sOsName
            Return $sOsName
        EndIf
    EndIf
    Local $sLabel = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $iIndex, "")
    If $iIndex >= 1 And $iIndex <= 20 Then $__g_Labels_aCache[$iIndex] = $sLabel
    Return $sLabel
EndFunc

; Name:        _Labels_InvalidateCache
; Description: Marks label cache as dirty so next Load reads from source
Func _Labels_InvalidateCache()
    $__g_Labels_bCacheDirty = True
EndFunc

; Name:        _Labels_Save
; Description: Saves a desktop label. Writes to both OS and INI when sync is
;              enabled, INI-only otherwise.
; Parameters:  $iIndex - desktop index (1-based)
;              $sText - label text
Func _Labels_Save($iIndex, $sText)
    If $__g_Labels_bSyncOS Then _VD_SetName($iIndex, $sText)
    IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $iIndex, $sText)
    ; Update cache
    If $iIndex >= 1 And $iIndex <= 20 Then $__g_Labels_aCache[$iIndex] = $sText
EndFunc

; Name:        _Labels_Swap
; Description: Swaps two stored labels so Switcheroo stays aligned after a desktop
;              reorder. When requested, also swaps the OS names.
; Parameters:  $iA, $iB - desktop indices (1-based)
;              $bOsAlreadySwapped - True when the caller already swapped OS names
; Return:      True on success, False on invalid input
Func _Labels_Swap($iA, $iB, $bOsAlreadySwapped = False)
    If $iA < 1 Or $iB < 1 Then Return False
    If $iA = $iB Then Return True
    If $__g_Labels_IniPath = "" Then Return False

    Local $sLabelA = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $iA, "")
    Local $sLabelB = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $iB, "")

    If $__g_Labels_bSyncOS And Not $bOsAlreadySwapped Then
        _VD_SetName($iA, $sLabelB)
        _VD_SetName($iB, $sLabelA)
    EndIf

    IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $iA, $sLabelB)
    IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $iB, $sLabelA)

    ; Force fresh reads so the next UI refresh uses the swapped labels immediately.
    _Labels_InvalidateCache()
    $__g_Labels_sLastHash = ""
    Return True
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

    ; Normal poll — pull non-empty OS names into INI + update cache
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
        If $i <= 20 Then $__g_Labels_aCache[$i] = $sOsName
    Next
    $__g_Labels_bCacheDirty = False
    Return $bChanged
EndFunc

; Name:        _Labels_RemoveAndShift
; Description: Shifts labels down after a desktop is removed at $iRemovedIndex,
;              and purges the orphan slot at the old last position. Called AFTER
;              _VD_RemoveDesktop. Labels become authoritative regardless of whether
;              Windows preserved OS names across the remove.
; Parameters:  $iRemovedIndex - index of the removed desktop (1-based)
;              $iOldCount - desktop count BEFORE the removal
Func _Labels_RemoveAndShift($iRemovedIndex, $iOldCount)
    If $iRemovedIndex < 1 Or $iOldCount < 1 Or $iRemovedIndex > $iOldCount Then Return
    If $__g_Labels_IniPath = "" Then Return

    ; Collect → shift → write: snapshot all old labels first so writes don't
    ; pollute later reads. Prefer OS name when sync is on, fall back to INI.
    Local $aLabels[$iOldCount + 1]
    Local $i
    For $i = 1 To $iOldCount
        Local $s = ""
        If $__g_Labels_bSyncOS Then $s = _VD_GetName($i)
        If $s = "" Then $s = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $i, "")
        $aLabels[$i] = $s
    Next

    ; Shift positions iRemovedIndex+1..iOldCount down by 1 (no-op when removing
    ; the last desktop). _Labels_Save handles OS + INI + cache.
    For $i = $iRemovedIndex To $iOldCount - 1
        _Labels_Save($i, $aLabels[$i + 1])
    Next

    ; Purge orphan at old last position
    IniDelete($__g_Labels_IniPath, "Labels", "desktop_" & $iOldCount)
    If $iOldCount >= 1 And $iOldCount <= 20 Then $__g_Labels_aCache[$iOldCount] = ""
    If $__g_Labels_bSyncOS Then _VD_SetName($iOldCount, "")

    ; Update sync trackers so the next poll runs the normal pull-from-OS path
    ; instead of re-pushing INI via the count-change branch.
    $__g_Labels_iLastCount = $iOldCount - 1
    $__g_Labels_sLastHash = ""
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
    Local $i
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
