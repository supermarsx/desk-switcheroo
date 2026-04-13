#include-once
#include "Logger.au3"
#include "VirtualDesktop.au3"
#include <WinAPISysWin.au3>
#include <WinAPIProc.au3>

; #INDEX# =======================================================
; Title .........: WindowRules
; Description ....: Automatic window-to-desktop rule engine. Polls for
;                   top-level windows and moves them to target desktops
;                   based on process name or window class rules defined
;                   in the INI config [Rules] section.
; Author .........: Mariana
; ===============================================================
; Config keys (read directly from INI — Config.au3 getters to be added later):
;   [Rules]
;   rules_enabled        = false           ; enable/disable rule engine
;   rules_poll_interval  = 2000            ; poll interval in ms (500-30000)
;   rule_1               = chrome.exe|3    ; process_name|target_desktop
;   rule_2               = class:CabinetWClass|1  ; class:ClassName|target_desktop
;   ...up to rule_50
; ===============================================================
; Index:
;   _WR_Start           Start rule polling
;   _WR_Stop            Stop rule polling
;   _WR_LoadRules       Load rules from config
;   _WR_GetRuleCount    Get number of active rules
;   _WR_IsRunning       Check if rule engine is active
;   __WR_Poll           Internal polling callback
;   __WR_MatchWindow    Check if window matches any rule
;   __WR_ApplyRule      Move window to target desktop
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_WR_aRules[50][3]     ; [N][0]=pattern, [N][1]=target desktop, [N][2]=type ("process" or "class")
Global $__g_WR_iRuleCount = 0
Global $__g_WR_dictMoved = 0     ; Scripting.Dictionary keyed by HWND string
Global $__g_WR_bRunning = False
Global $__g_WR_iCleanupCounter = 0
Global Const $__g_WR_MAX_RULES = 50
Global Const $__g_WR_CLEANUP_INTERVAL = 10 ; clean stale HWNDs every N polls

; #FUNCTIONS# ===================================================

; Name:        _WR_Start
; Description: Loads rules from config and starts polling via AdlibRegister.
;              Does nothing if rules are disabled or no valid rules found.
; Return:      True if started, False otherwise
Func _WR_Start()
    Local $sIni = @ScriptDir & "\desk_switcheroo.ini"
    Local $bEnabled = (IniRead($sIni, "Rules", "rules_enabled", "false") = "true")
    If Not $bEnabled Then
        _Log_Debug("WindowRules: disabled in config")
        Return False
    EndIf

    ; Load rules from INI
    Local $iLoaded = _WR_LoadRules()
    If $iLoaded = 0 Then
        _Log_Info("WindowRules: no valid rules found, not starting")
        Return False
    EndIf

    ; Create moved-HWND tracker
    If Not IsObj($__g_WR_dictMoved) Then
        $__g_WR_dictMoved = ObjCreate("Scripting.Dictionary")
        If Not IsObj($__g_WR_dictMoved) Then
            _Log_Warn("WindowRules: failed to create Dictionary, cannot start")
            Return False
        EndIf
    EndIf

    ; Read poll interval with clamping
    Local $iInterval = Int(IniRead($sIni, "Rules", "rules_poll_interval", "2000"))
    If $iInterval < 500 Then $iInterval = 500
    If $iInterval > 30000 Then $iInterval = 30000

    $__g_WR_bRunning = True
    $__g_WR_iCleanupCounter = 0
    AdlibRegister("__WR_Poll", $iInterval)
    _Log_Info("WindowRules: started (" & $iLoaded & " rules, interval: " & $iInterval & "ms)")
    Return True
EndFunc

; Name:        _WR_Stop
; Description: Stops rule polling and clears internal state
Func _WR_Stop()
    AdlibUnRegister("__WR_Poll")
    $__g_WR_bRunning = False
    $__g_WR_iRuleCount = 0
    $__g_WR_iCleanupCounter = 0
    If IsObj($__g_WR_dictMoved) Then $__g_WR_dictMoved.RemoveAll()
    _Log_Info("WindowRules: stopped")
EndFunc

; Name:        _WR_LoadRules
; Description: Parses rules from the [Rules] section of the INI file.
;              Rule format: rule_N=process_name.exe|target_desktop
;                       or: rule_N=class:ClassName|target_desktop
; Return:      Number of valid rules loaded
Func _WR_LoadRules()
    Local $sIni = @ScriptDir & "\desk_switcheroo.ini"
    $__g_WR_iRuleCount = 0

    ; Clear existing rules
    Local $i
    For $i = 0 To $__g_WR_MAX_RULES - 1
        $__g_WR_aRules[$i][0] = ""
        $__g_WR_aRules[$i][1] = 0
        $__g_WR_aRules[$i][2] = ""
    Next

    For $i = 1 To $__g_WR_MAX_RULES
        Local $sKey = "rule_" & $i
        Local $sVal = IniRead($sIni, "Rules", $sKey, "")
        If $sVal = "" Then ContinueLoop

        ; Parse: pattern|target_desktop
        Local $aParts = StringSplit($sVal, "|")
        If $aParts[0] <> 2 Then
            _Log_Warn("WindowRules: invalid rule format: " & $sKey & "=" & $sVal)
            ContinueLoop
        EndIf

        Local $sPattern = StringStripWS($aParts[1], 3) ; 3 = strip leading+trailing
        Local $iTarget = Int(StringStripWS($aParts[2], 3))

        ; Validate target desktop (must be >= 1)
        If $iTarget < 1 Then
            _Log_Warn("WindowRules: invalid target desktop in rule: " & $sKey & "=" & $sVal)
            ContinueLoop
        EndIf

        ; Validate pattern is not empty
        If $sPattern = "" Then
            _Log_Warn("WindowRules: empty pattern in rule: " & $sKey & "=" & $sVal)
            ContinueLoop
        EndIf

        ; Determine type: class or process
        Local $sType = "process"
        If StringLeft(StringLower($sPattern), 6) = "class:" Then
            $sType = "class"
            $sPattern = StringTrimLeft($sPattern, 6)
            If $sPattern = "" Then
                _Log_Warn("WindowRules: empty class name in rule: " & $sKey & "=" & $sVal)
                ContinueLoop
            EndIf
        EndIf

        ; Store rule
        $__g_WR_aRules[$__g_WR_iRuleCount][0] = $sPattern
        $__g_WR_aRules[$__g_WR_iRuleCount][1] = $iTarget
        $__g_WR_aRules[$__g_WR_iRuleCount][2] = $sType
        $__g_WR_iRuleCount += 1
        _Log_Debug("WindowRules: loaded rule " & $__g_WR_iRuleCount & ": " & $sType & "=" & $sPattern & " -> desktop " & $iTarget)

        If $__g_WR_iRuleCount >= $__g_WR_MAX_RULES Then ExitLoop
    Next

    _Log_Info("WindowRules: loaded " & $__g_WR_iRuleCount & " rules")
    Return $__g_WR_iRuleCount
EndFunc

; Name:        _WR_GetRuleCount
; Description: Returns the number of loaded rules
; Return:      Integer (0 if no rules loaded)
Func _WR_GetRuleCount()
    Return $__g_WR_iRuleCount
EndFunc

; Name:        _WR_IsRunning
; Description: Returns whether the rule engine polling is active
; Return:      True/False
Func _WR_IsRunning()
    Return $__g_WR_bRunning
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

; Name:        __WR_Poll
; Description: Periodic callback — enumerates all top-level windows and applies
;              matching rules. Called via AdlibRegister.
Func __WR_Poll()
    If Not $__g_WR_bRunning Or $__g_WR_iRuleCount = 0 Then Return

    ; Enumerate all top-level windows (cross-desktop, same as VirtualDesktop.au3)
    Local $aWindows = WinList()
    If Not IsArray($aWindows) Then Return

    Local $i
    For $i = 1 To $aWindows[0][0]
        Local $hWnd = $aWindows[$i][1]
        If $hWnd = 0 Then ContinueLoop

        ; Skip windows with no title (typically not user-visible)
        If $aWindows[$i][0] = "" Then ContinueLoop

        ; Skip already-moved windows
        Local $sHwnd = String($hWnd)
        If IsObj($__g_WR_dictMoved) And $__g_WR_dictMoved.Exists($sHwnd) Then ContinueLoop

        ; Check against rules
        Local $iMatchIdx = __WR_MatchWindow($hWnd)
        If $iMatchIdx >= 0 Then
            __WR_ApplyRule($hWnd, $iMatchIdx)
        EndIf
    Next

    ; Periodic cleanup of stale HWND entries
    $__g_WR_iCleanupCounter += 1
    If $__g_WR_iCleanupCounter >= $__g_WR_CLEANUP_INTERVAL Then
        $__g_WR_iCleanupCounter = 0
        __WR_CleanupStaleHwnds()
    EndIf
EndFunc

; Name:        __WR_MatchWindow
; Description: Checks if a window matches any loaded rule by process name or class.
; Parameters:  $hWnd - window handle
; Return:      Rule index (0-based) on match, or -1 if no match
Func __WR_MatchWindow($hWnd)
    ; Get process name for this window
    Local $iPid = WinGetProcess($hWnd)
    Local $sProcess = ""
    If $iPid > 0 Then
        ; Use _WinAPI_GetProcessFileName for full path, then extract just the filename
        Local $sFullPath = _WinAPI_GetProcessFileName($iPid)
        If $sFullPath <> "" Then
            ; Extract filename from full path
            Local $aParts = StringSplit($sFullPath, "\")
            If $aParts[0] > 0 Then $sProcess = $aParts[$aParts[0]]
        EndIf
    EndIf

    ; Get window class
    Local $sClass = _WinAPI_GetClassName($hWnd)

    ; Check each rule
    Local $i
    For $i = 0 To $__g_WR_iRuleCount - 1
        If $__g_WR_aRules[$i][2] = "process" Then
            If StringLower($sProcess) = StringLower($__g_WR_aRules[$i][0]) Then Return $i
        ElseIf $__g_WR_aRules[$i][2] = "class" Then
            If $sClass = $__g_WR_aRules[$i][0] Then Return $i
        EndIf
    Next

    Return -1
EndFunc

; Name:        __WR_ApplyRule
; Description: Moves a window to the target desktop specified by a rule,
;              if not already on the correct desktop. Tracks moved HWND.
; Parameters:  $hWnd      - window handle
;              $iRuleIdx  - index into $__g_WR_aRules
Func __WR_ApplyRule($hWnd, $iRuleIdx)
    Local $iTarget = $__g_WR_aRules[$iRuleIdx][1]
    Local $sPattern = $__g_WR_aRules[$iRuleIdx][0]
    Local $sType = $__g_WR_aRules[$iRuleIdx][2]

    ; Check current desktop of the window
    Local $iCurrent = _VD_GetWindowDesktopNumber($hWnd)

    ; Already on target desktop — just track and skip
    If $iCurrent = $iTarget Then
        If IsObj($__g_WR_dictMoved) Then $__g_WR_dictMoved.Item(String($hWnd)) = $iTarget
        Return
    EndIf

    ; Validate target desktop exists
    Local $iCount = _VD_GetCount()
    If $iTarget > $iCount Then
        _Log_Warn("WindowRules: target desktop " & $iTarget & " exceeds count " & $iCount & _
            " for rule " & $sType & "=" & $sPattern)
        Return
    EndIf

    ; Move the window
    Local $sTitle = WinGetTitle($hWnd)
    _Log_Info("WindowRules: moving '" & $sTitle & "' (" & $sType & "=" & $sPattern & ") " & _
        "from desktop " & $iCurrent & " to desktop " & $iTarget)
    Local $bOk = _VD_MoveWindowToDesktop($hWnd, $iTarget)
    If $bOk Then
        _Log_Debug("WindowRules: move succeeded for hwnd=" & $hWnd)
    Else
        _Log_Warn("WindowRules: move FAILED for hwnd=" & $hWnd & " (" & $sPattern & ")")
    EndIf

    ; Track HWND regardless of success to avoid repeated attempts on the same window
    If IsObj($__g_WR_dictMoved) Then $__g_WR_dictMoved.Item(String($hWnd)) = $iTarget
EndFunc

; Name:        __WR_CleanupStaleHwnds
; Description: Removes entries from the moved-HWND tracker for windows that
;              no longer exist (handle became invalid).
Func __WR_CleanupStaleHwnds()
    If Not IsObj($__g_WR_dictMoved) Then Return
    If $__g_WR_dictMoved.Count = 0 Then Return

    Local $aKeys = $__g_WR_dictMoved.Keys()
    Local $iRemoved = 0
    Local $i
    For $i = 0 To UBound($aKeys) - 1
        Local $hWnd = HWnd($aKeys[$i])
        ; Check if window still exists via user32.dll IsWindow
        Local $aIsWnd = DllCall("user32.dll", "bool", "IsWindow", "hwnd", $hWnd)
        If Not @error And IsArray($aIsWnd) And $aIsWnd[0] = 0 Then
            $__g_WR_dictMoved.Remove($aKeys[$i])
            $iRemoved += 1
        EndIf
    Next

    If $iRemoved > 0 Then
        _Log_Debug("WindowRules: cleaned up " & $iRemoved & " stale HWND entries (" & $__g_WR_dictMoved.Count & " remaining)")
    EndIf
EndFunc
