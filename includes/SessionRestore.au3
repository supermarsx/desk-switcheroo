#include-once
#include "Logger.au3"
#include "VirtualDesktop.au3"
#include <WinAPISysWin.au3>
#include <WinAPIProc.au3>

; #INDEX# =======================================================
; Title .........: SessionRestore
; Description ....: Save/restore window-to-desktop assignments
; Author .........: Mariana
; ===============================================================

; #FUNCTIONS# ===================================================
;   _SR_SaveSession       Save current window assignments
;   _SR_RestoreSession    Restore windows to saved desktops
;   _SR_ClearSession      Clear saved session data
;   _SR_HasSavedSession   Check if session data exists
;   _SR_GetSavedCount     Get count of saved window entries
;   __SR_EnumAllWindows   Enumerate windows across all desktops
;   __SR_MatchWindow      Match a saved entry to a running window
;   __SR_GetProcessInfo   Get process name and class for a window
; ===============================================================

; #INTERNAL CONSTANTS# ==========================================
Global Const $__g_SR_SECTION = "Session"
Global Const $__g_SR_MAX_DESKTOPS = 50
; System processes to skip during enumeration
Global Const $__g_SR_aSkipProcs = StringSplit("dwm.exe|csrss.exe|smss.exe|wininit.exe|winlogon.exe|lsass.exe|services.exe|svchost.exe|fontdrvhost.exe|sihost.exe|taskhostw.exe|ShellExperienceHost.exe|SearchHost.exe|StartMenuExperienceHost.exe|RuntimeBroker.exe|TextInputHost.exe|ctfmon.exe|SecurityHealthSystray.exe|dllhost.exe", "|")

; #FUNCTIONS# ===================================================

; Name:        _SR_SaveSession
; Description: Enumerate all desktops, save window assignments to state INI.
;              Feature must be enabled in config (Session/session_restore_enabled=true).
; Return:      Count of entries saved, or 0 if disabled/error
Func _SR_SaveSession()
    Local $sIni = @ScriptDir & "\desk_switcheroo.ini"
    Local $bEnabled = (IniRead($sIni, "Session", "session_restore_enabled", "false") = "true")
    If Not $bEnabled Then
        _Log_Debug("SessionRestore: save skipped — feature disabled")
        Return 0
    EndIf

    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
    Local $iDesktopCount = _VD_GetCount()
    If $iDesktopCount < 1 Then $iDesktopCount = 1
    If $iDesktopCount > $__g_SR_MAX_DESKTOPS Then $iDesktopCount = $__g_SR_MAX_DESKTOPS

    ; Clear previous session data
    _SR_ClearSession()

    ; Enumerate all windows and group by desktop
    Local $aWindows = __SR_EnumAllWindows()
    Local $iEntryCount = 0

    Local $i
    For $i = 1 To $aWindows[0][0]
        Local $hWnd = $aWindows[$i][0]
        Local $sProc = $aWindows[$i][1]
        Local $sClass = $aWindows[$i][2]
        Local $iDesk = $aWindows[$i][3]

        ; Skip windows on desktops beyond the count (pinned windows return 0)
        If $iDesk < 1 Or $iDesk > $iDesktopCount Then ContinueLoop

        $iEntryCount += 1
        Local $sEntry = $sProc & "|" & $sClass & "|" & $iDesk
        IniWrite($sStateFile, $__g_SR_SECTION, "entry_" & $iEntryCount, $sEntry)
        _Log_Debug("SessionRestore: saved entry_" & $iEntryCount & " = " & $sEntry)
    Next

    ; Write metadata
    Local $sTimestamp = StringFormat("%04d-%02d-%02dT%02d:%02d:%02d", @YEAR, @MON, @MDAY, @HOUR, @MIN, @SEC)
    IniWrite($sStateFile, $__g_SR_SECTION, "session_count", $iEntryCount)
    IniWrite($sStateFile, $__g_SR_SECTION, "session_timestamp", $sTimestamp)
    IniWrite($sStateFile, $__g_SR_SECTION, "session_desktop_count", $iDesktopCount)

    _Log_Info("SessionRestore: saved " & $iEntryCount & " window entries across " & $iDesktopCount & " desktops")
    Return $iEntryCount
EndFunc

; Name:        _SR_RestoreSession
; Description: Read saved state, match running windows, move them to saved desktops.
;              Feature must be enabled in config (Session/session_restore_enabled=true).
; Return:      Count of windows successfully restored, or 0 if disabled/error
Func _SR_RestoreSession()
    Local $sIni = @ScriptDir & "\desk_switcheroo.ini"
    Local $bEnabled = (IniRead($sIni, "Session", "session_restore_enabled", "false") = "true")
    If Not $bEnabled Then
        _Log_Debug("SessionRestore: restore skipped — feature disabled")
        Return 0
    EndIf

    If Not _SR_HasSavedSession() Then
        _Log_Info("SessionRestore: no saved session data found")
        Return 0
    EndIf

    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
    Local $iSavedCount = Int(IniRead($sStateFile, $__g_SR_SECTION, "session_count", "0"))
    Local $iSavedDesktops = Int(IniRead($sStateFile, $__g_SR_SECTION, "session_desktop_count", "0"))
    Local $iCurrentDesktops = _VD_GetCount()

    If $iSavedCount < 1 Then
        _Log_Info("SessionRestore: saved session has 0 entries")
        Return 0
    EndIf

    _Log_Info("SessionRestore: restoring " & $iSavedCount & " entries (saved desktops=" & $iSavedDesktops & ", current=" & $iCurrentDesktops & ")")

    ; Read all saved entries into arrays
    Local $aSavedProc[$iSavedCount + 1]
    Local $aSavedClass[$iSavedCount + 1]
    Local $aSavedDesk[$iSavedCount + 1]
    $aSavedProc[0] = $iSavedCount
    $aSavedClass[0] = $iSavedCount
    $aSavedDesk[0] = $iSavedCount

    Local $i
    For $i = 1 To $iSavedCount
        Local $sEntry = IniRead($sStateFile, $__g_SR_SECTION, "entry_" & $i, "")
        If $sEntry = "" Then
            $aSavedProc[$i] = ""
            $aSavedClass[$i] = ""
            $aSavedDesk[$i] = 0
            ContinueLoop
        EndIf
        Local $aParts = StringSplit($sEntry, "|")
        If $aParts[0] < 3 Then
            $aSavedProc[$i] = ""
            $aSavedClass[$i] = ""
            $aSavedDesk[$i] = 0
            ContinueLoop
        EndIf
        $aSavedProc[$i] = $aParts[1]
        $aSavedClass[$i] = $aParts[2]
        $aSavedDesk[$i] = Int($aParts[3])
    Next

    ; Enumerate current windows
    Local $aWindows = __SR_EnumAllWindows()

    ; Track which running windows have already been matched (avoid double-move)
    Local $aMatched[$aWindows[0][0] + 1]
    For $i = 0 To $aWindows[0][0]
        $aMatched[$i] = False
    Next

    Local $iRestored = 0

    ; For each saved entry, find a matching running window
    For $i = 1 To $iSavedCount
        If $aSavedProc[$i] = "" Then ContinueLoop
        Local $iTargetDesk = $aSavedDesk[$i]

        ; Skip if target desktop does not exist
        If $iTargetDesk < 1 Or $iTargetDesk > $iCurrentDesktops Then
            _Log_Debug("SessionRestore: skipping entry_" & $i & " — target desktop " & $iTargetDesk & " exceeds current count " & $iCurrentDesktops)
            ContinueLoop
        EndIf

        ; Find best match among running windows
        Local $iBestIdx = __SR_MatchWindow($aSavedProc[$i], $aSavedClass[$i], $aWindows, $aMatched)

        If $iBestIdx > 0 Then
            Local $hMatchWnd = $aWindows[$iBestIdx][0]
            Local $iCurrentDesk = $aWindows[$iBestIdx][3]

            ; Don't move if already on the correct desktop
            If $iCurrentDesk = $iTargetDesk Then
                _Log_Debug("SessionRestore: " & $aSavedProc[$i] & " already on desktop " & $iTargetDesk)
                $aMatched[$iBestIdx] = True
                ContinueLoop
            EndIf

            ; Move window to saved desktop
            Local $bMoved = _VD_MoveWindowToDesktop($hMatchWnd, $iTargetDesk)
            If $bMoved Then
                $iRestored += 1
                $aMatched[$iBestIdx] = True
                _Log_Info("SessionRestore: moved " & $aSavedProc[$i] & " (class=" & $aSavedClass[$i] & ") to desktop " & $iTargetDesk)
            Else
                _Log_Warn("SessionRestore: failed to move " & $aSavedProc[$i] & " to desktop " & $iTargetDesk)
            EndIf
        Else
            _Log_Debug("SessionRestore: no match found for " & $aSavedProc[$i] & " (class=" & $aSavedClass[$i] & ")")
        EndIf
    Next

    _Log_Info("SessionRestore: restored " & $iRestored & " of " & $iSavedCount & " saved windows")
    Return $iRestored
EndFunc

; Name:        _SR_ClearSession
; Description: Delete [Session] section from state INI
Func _SR_ClearSession()
    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
    If Not FileExists($sStateFile) Then Return
    ; Read all keys in the section and delete them
    Local $aKeys = IniReadSection($sStateFile, $__g_SR_SECTION)
    If @error Then Return
    Local $i
    For $i = 1 To $aKeys[0][0]
        IniDelete($sStateFile, $__g_SR_SECTION, $aKeys[$i][0])
    Next
EndFunc

; Name:        _SR_HasSavedSession
; Description: Check if session data exists in state INI
; Return:      True if [Session] section exists with entries, False otherwise
Func _SR_HasSavedSession()
    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
    If Not FileExists($sStateFile) Then Return False
    Local $iCount = Int(IniRead($sStateFile, $__g_SR_SECTION, "session_count", "0"))
    Return ($iCount > 0)
EndFunc

; Name:        _SR_GetSavedCount
; Description: Get count of saved window entries
; Return:      Integer count of saved entries, or 0 if none
Func _SR_GetSavedCount()
    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
    If Not FileExists($sStateFile) Then Return 0
    Return Int(IniRead($sStateFile, $__g_SR_SECTION, "session_count", "0"))
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

; Name:        __SR_EnumAllWindows
; Description: Enumerate visible top-level windows across all desktops.
;              Returns a 2D array: [0]=count, [N][0]=hWnd, [N][1]=process, [N][2]=class, [N][3]=desktop
; Return:      Array where [0] = count, [1..N] = window info arrays
Func __SR_EnumAllWindows()
    Local $aList = WinList()
    ; Pre-allocate result as 2D array: [count+1][4]
    Local $aResult[$aList[0][0] + 1][4]
    $aResult[0][0] = 0

    Local $i
    For $i = 1 To $aList[0][0]
        Local $sTitle = $aList[$i][0]
        Local $hWnd = $aList[$i][1]

        ; Skip windows with empty titles
        If $sTitle = "" Then ContinueLoop

        ; Skip non-visible windows
        If BitAND(WinGetState($hWnd), 2) = 0 Then ContinueLoop

        ; Get process and class info
        Local $aInfo = __SR_GetProcessInfo($hWnd)
        Local $sProc = $aInfo[0]
        Local $sClass = $aInfo[1]

        ; Skip empty process or class
        If $sProc = "" Or $sClass = "" Then ContinueLoop

        ; Skip system processes
        If __SR_IsSystemProcess($sProc) Then ContinueLoop

        ; Skip explorer.exe desktop window (Progman / WorkerW classes)
        If StringLower($sProc) = "explorer.exe" Then
            If $sClass = "Progman" Or $sClass = "WorkerW" Then ContinueLoop
        EndIf

        ; Get desktop number for this window
        Local $iDesk = _VD_GetWindowDesktopNumber($hWnd)
        If $iDesk < 1 Then ContinueLoop

        ; Add to result
        $aResult[0][0] += 1
        Local $idx = $aResult[0][0]
        $aResult[$idx][0] = $hWnd
        $aResult[$idx][1] = $sProc
        $aResult[$idx][2] = $sClass
        $aResult[$idx][3] = $iDesk
    Next

    ; Trim array to actual size
    ReDim $aResult[$aResult[0][0] + 1][4]
    Return $aResult
EndFunc

; Name:        __SR_MatchWindow
; Description: Find the best match for a saved entry among running windows.
;              Match by process name primarily, window class as tiebreaker.
; Parameters:  $sProc    - saved process name
;              $sClass   - saved window class
;              $aWindows - 2D array from __SR_EnumAllWindows
;              $aMatched - boolean array of already-matched indices
; Return:      Index into $aWindows of best match, or 0 if no match
Func __SR_MatchWindow($sProc, $sClass, ByRef $aWindows, ByRef $aMatched)
    Local $iBestIdx = 0
    Local $bClassMatch = False
    Local $sProcLower = StringLower($sProc)

    Local $i
    For $i = 1 To $aWindows[0][0]
        ; Skip already-matched windows
        If $aMatched[$i] Then ContinueLoop

        ; Primary match: process name (case-insensitive)
        If StringLower($aWindows[$i][1]) <> $sProcLower Then ContinueLoop

        ; This window matches by process name
        If $iBestIdx = 0 Then
            ; First process name match
            $iBestIdx = $i
            $bClassMatch = ($aWindows[$i][2] = $sClass)
        Else
            ; Multiple process name matches — prefer class match
            If Not $bClassMatch And $aWindows[$i][2] = $sClass Then
                $iBestIdx = $i
                $bClassMatch = True
            EndIf
        EndIf

        ; Exact match (process + class) — no need to keep looking
        If $bClassMatch Then ExitLoop
    Next

    Return $iBestIdx
EndFunc

; Name:        __SR_GetProcessInfo
; Description: Get process name and window class for a window handle
; Parameters:  $hWnd - window handle
; Return:      Array [0]=process name, [1]=class name
Func __SR_GetProcessInfo($hWnd)
    Local $aResult[2] = ["", ""]

    ; Get process name via PID
    Local $iPID = WinGetProcess($hWnd)
    If $iPID > 0 Then
        ; Use _WinAPI_GetProcessFileName for full path, then extract filename
        Local $sFullPath = _WinAPI_GetProcessFileName($iPID)
        If $sFullPath <> "" Then
            ; Extract just the filename from the full path
            Local $iLastSlash = StringInStr($sFullPath, "\", 0, -1)
            If $iLastSlash > 0 Then
                $aResult[0] = StringMid($sFullPath, $iLastSlash + 1)
            Else
                $aResult[0] = $sFullPath
            EndIf
        EndIf
    EndIf

    ; Get window class
    Local $sClass = _WinAPI_GetClassName($hWnd)
    If $sClass <> "" Then $aResult[1] = $sClass

    Return $aResult
EndFunc

; Name:        __SR_IsSystemProcess
; Description: Check if a process name is in the system skip list
; Parameters:  $sProc - process name
; Return:      True if system process, False otherwise
Func __SR_IsSystemProcess($sProc)
    Local $sProcLower = StringLower($sProc)
    Local $i
    For $i = 1 To $__g_SR_aSkipProcs[0]
        If $sProcLower = StringLower($__g_SR_aSkipProcs[$i]) Then Return True
    Next
    Return False
EndFunc
