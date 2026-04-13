#include-once
#include "Config.au3"
#include "Logger.au3"

; #INDEX# =======================================================
; Title .........: Hooks
; Description ....: Event hook system for extensibility. Executes
;                   arbitrary commands or scripts when specific
;                   application events fire. Hooks are configured in
;                   the [Hooks] INI section and are disabled by default.
; Author .........: Mariana
; ===============================================================
; Index:
;   _Hooks_Init              Initialize hook system
;   _Hooks_Shutdown          Clean up hook system
;   _Hooks_Fire              Fire an event, execute matching hooks
;   _Hooks_LoadHooks         Load hooks from config INI
;   _Hooks_GetHookCount      Get total number of registered hooks
;   _Hooks_IsEnabled         Check if hook system is enabled
;   _Hooks_TestHook          Execute a hook for testing (synchronous)
;   __Hooks_Execute          Execute a single hook command
;   __Hooks_SubstituteVars   Replace variables in hook command
;   __Hooks_ParseHookLine    Parse a hook config line
;   __Hooks_CheckTimeouts    Kill hook processes that exceeded timeout
; ===============================================================

; #CONSTANTS# ===================================================
Global Const $__HOOKS_MAX_HOOKS = 100
Global Const $__HOOKS_MAX_PIDS  = 20
Global Const $__HOOKS_EVENTS    = "on_desktop_change|on_desktop_create|on_desktop_delete|" & _
                                  "on_window_move|on_profile_load|on_startup|on_shutdown|on_carousel_tick"

; #INTERNAL GLOBALS# ============================================
Global $__g_Hooks_bEnabled    = False
Global $__g_Hooks_aHooks[$__HOOKS_MAX_HOOKS][3] ; [event_name, command_template, index]
Global $__g_Hooks_iHookCount  = 0
Global $__g_Hooks_iTimeout    = 10000            ; default 10 s, updated from config
Global $__g_Hooks_aPIDs[$__HOOKS_MAX_PIDS]       ; running hook PIDs
Global $__g_Hooks_aTimers[$__HOOKS_MAX_PIDS]     ; TimerInit() for each PID slot
Global $__g_Hooks_iPIDCount   = 0

; #FUNCTIONS# ===================================================

; Name:        _Hooks_Init
; Description: Loads hooks from INI, sets up state. Returns True if enabled.
; Return:      True if hook system is enabled, False otherwise
Func _Hooks_Init()
    ; Reset state
    $__g_Hooks_bEnabled   = False
    $__g_Hooks_iHookCount = 0
    $__g_Hooks_iPIDCount  = 0

    Local $sIniPath = _Cfg_GetPath()
    If $sIniPath = "" Then Return False

    ; Check enabled flag
    Local $sEnabled = IniRead($sIniPath, "Hooks", "hooks_enabled", "false")
    If StringLower(StringStripWS($sEnabled, 3)) <> "true" Then
        _Log_Debug("Hooks: system disabled by config")
        Return False
    EndIf

    ; Read timeout
    Local $sTimeout = IniRead($sIniPath, "Hooks", "hooks_timeout", "10000")
    $__g_Hooks_iTimeout = Int($sTimeout)
    If $__g_Hooks_iTimeout < 1000 Then $__g_Hooks_iTimeout = 1000
    If $__g_Hooks_iTimeout > 300000 Then $__g_Hooks_iTimeout = 300000

    ; Load hooks
    Local $iCount = _Hooks_LoadHooks()

    $__g_Hooks_bEnabled = True
    _Log_Info("Hooks: initialized (" & $iCount & " hooks, timeout=" & $__g_Hooks_iTimeout & "ms)")
    Return True
EndFunc

; Name:        _Hooks_Shutdown
; Description: Cleans up the hook system, kills any running hook processes
Func _Hooks_Shutdown()
    If Not $__g_Hooks_bEnabled Then Return

    ; Kill any still-running hook PIDs
    Local $i
    For $i = 0 To $__g_Hooks_iPIDCount - 1
        If $__g_Hooks_aPIDs[$i] > 0 And ProcessExists($__g_Hooks_aPIDs[$i]) Then
            ProcessClose($__g_Hooks_aPIDs[$i])
            _Log_Debug("Hooks: killed PID " & $__g_Hooks_aPIDs[$i] & " on shutdown")
        EndIf
        $__g_Hooks_aPIDs[$i] = 0
    Next
    $__g_Hooks_iPIDCount = 0

    $__g_Hooks_bEnabled   = False
    $__g_Hooks_iHookCount = 0
    _Log_Info("Hooks: shutdown complete")
EndFunc

; Name:        _Hooks_Fire
; Description: Fire an event, execute all matching hooks.
; Parameters:  $sEvent  - event name (e.g. "on_desktop_change")
;              $sParams - pipe-delimited key=value pairs for variable substitution
;                         e.g. "desktop=3|desktop_name=Work|prev_desktop=1"
Func _Hooks_Fire($sEvent, $sParams = "")
    If Not $__g_Hooks_bEnabled Then Return

    ; Clean up finished/timed-out processes before launching new ones
    __Hooks_CheckTimeouts()

    Local $iMatched = 0
    Local $i
    For $i = 0 To $__g_Hooks_iHookCount - 1
        If $__g_Hooks_aHooks[$i][0] = $sEvent Then
            Local $sCmd = __Hooks_SubstituteVars($__g_Hooks_aHooks[$i][1], $sParams)
            __Hooks_Execute($sCmd, False)
            $iMatched += 1
        EndIf
    Next

    If $iMatched > 0 Then
        _Log_Debug("Hooks: fired " & $sEvent & " (" & $iMatched & " hooks)")
    EndIf
EndFunc

; Name:        _Hooks_LoadHooks
; Description: Reads hooks from the [Hooks] INI section. Clears existing hooks first.
; Return:      Number of hooks loaded
Func _Hooks_LoadHooks()
    $__g_Hooks_iHookCount = 0

    Local $sIniPath = _Cfg_GetPath()
    If $sIniPath = "" Then Return 0

    Local $aSection = IniReadSection($sIniPath, "Hooks")
    If @error Then Return 0

    Local $i
    For $i = 1 To $aSection[0][0]
        Local $sKey   = StringLower(StringStripWS($aSection[$i][0], 3))
        Local $sValue = StringStripWS($aSection[$i][1], 3)

        ; Skip config keys (not hook definitions)
        If $sKey = "hooks_enabled" Or $sKey = "hooks_timeout" Then ContinueLoop
        If $sValue = "" Then ContinueLoop

        ; Parse: could be a single command or comma-separated list
        Local $aResult = __Hooks_ParseHookLine($sKey, $sValue)
        If Not IsArray($aResult) Then ContinueLoop

        Local $j
        For $j = 0 To UBound($aResult, 1) - 1
            If $__g_Hooks_iHookCount >= $__HOOKS_MAX_HOOKS Then
                _Log_Warn("Hooks: max hook count (" & $__HOOKS_MAX_HOOKS & ") reached, ignoring remaining")
                ExitLoop 2
            EndIf
            $__g_Hooks_aHooks[$__g_Hooks_iHookCount][0] = $aResult[$j][0] ; event name
            $__g_Hooks_aHooks[$__g_Hooks_iHookCount][1] = $aResult[$j][1] ; command template
            $__g_Hooks_aHooks[$__g_Hooks_iHookCount][2] = $__g_Hooks_iHookCount ; index
            $__g_Hooks_iHookCount += 1
        Next
    Next

    _Log_Debug("Hooks: loaded " & $__g_Hooks_iHookCount & " hooks from config")
    Return $__g_Hooks_iHookCount
EndFunc

; Name:        _Hooks_GetHookCount
; Description: Returns the total number of registered hooks
; Return:      Integer
Func _Hooks_GetHookCount()
    Return $__g_Hooks_iHookCount
EndFunc

; Name:        _Hooks_IsEnabled
; Description: Returns whether the hook system is enabled and initialized
; Return:      True/False
Func _Hooks_IsEnabled()
    Return $__g_Hooks_bEnabled
EndFunc

; Name:        _Hooks_TestHook
; Description: Execute a hook synchronously for testing. Performs variable
;              substitution and runs the command with RunWait().
; Parameters:  $sCommand - command template string
;              $sParams  - pipe-delimited key=value pairs (optional)
; Return:      Process exit code, or -1 on failure
Func _Hooks_TestHook($sCommand, $sParams = "")
    Local $sCmd = __Hooks_SubstituteVars($sCommand, $sParams)
    Return __Hooks_Execute($sCmd, True)
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

; Name:        __Hooks_Execute
; Description: Executes a single hook command.
; Parameters:  $sCmd  - the fully substituted command string
;              $bSync - True for synchronous (RunWait), False for async (Run)
; Return:      Exit code (sync) or PID (async), -1 on failure
Func __Hooks_Execute($sCmd, $bSync = False)
    If StringStripWS($sCmd, 3) = "" Then
        _Log_Warn("Hooks: empty command, skipping")
        Return -1
    EndIf

    _Log_Info("Hooks: executing: " & $sCmd)

    If $bSync Then
        Local $iExit = RunWait($sCmd, @ScriptDir, @SW_HIDE)
        If @error Then
            _Log_Warn("Hooks: RunWait failed for: " & $sCmd & " (error " & @error & ")")
            Return -1
        EndIf
        Return $iExit
    Else
        Local $iPID = Run($sCmd, @ScriptDir, @SW_HIDE)
        If $iPID = 0 Then
            _Log_Warn("Hooks: failed to execute: " & $sCmd & " (error " & @error & ")")
            Return -1
        EndIf

        ; Track PID for timeout management
        If $__g_Hooks_iPIDCount < $__HOOKS_MAX_PIDS Then
            $__g_Hooks_aPIDs[$__g_Hooks_iPIDCount]   = $iPID
            $__g_Hooks_aTimers[$__g_Hooks_iPIDCount]  = TimerInit()
            $__g_Hooks_iPIDCount += 1
        Else
            _Log_Debug("Hooks: PID tracking full, cannot track PID " & $iPID)
        EndIf

        Return $iPID
    EndIf
EndFunc

; Name:        __Hooks_SubstituteVars
; Description: Replaces {varname} placeholders in a command string with values.
; Parameters:  $sCmd    - command string with placeholders
;              $sParams - pipe-delimited key=value pairs
; Return:      Command string with substitutions applied
Func __Hooks_SubstituteVars($sCmd, $sParams)
    If $sParams = "" Then Return $sCmd

    Local $aPairs = StringSplit($sParams, "|")
    Local $i
    For $i = 1 To $aPairs[0]
        Local $aPair = StringSplit($aPairs[$i], "=", 2)
        If UBound($aPair) >= 2 Then
            $sCmd = StringReplace($sCmd, "{" & $aPair[0] & "}", $aPair[1])
        EndIf
    Next
    Return $sCmd
EndFunc

; Name:        __Hooks_ParseHookLine
; Description: Parses a hook config key and value into event name + commands.
;              Handles numbered keys (on_desktop_change_1) and single keys
;              (on_desktop_change). Does NOT split on comma to avoid breaking
;              commands that contain commas (e.g. PowerShell arguments).
; Parameters:  $sKey   - INI key (e.g. "on_desktop_change" or "on_desktop_change_2")
;              $sValue - command string
; Return:      2D array [N][2] of [event_name, command], or 0 on failure
Func __Hooks_ParseHookLine($sKey, $sValue)
    If $sValue = "" Then Return 0

    ; Strip trailing numeric suffix to get base event name (e.g. on_desktop_change_2 -> on_desktop_change)
    Local $sEvent = $sKey
    Local $aMatch = StringRegExp($sKey, "^(.+)_(\d+)$", 1)
    If Not @error And IsArray($aMatch) Then
        ; Verify the base is a known event, otherwise treat the whole key as the event name
        Local $sBase = $aMatch[0]
        If __Hooks_IsValidEvent($sBase) Then
            $sEvent = $sBase
        EndIf
    EndIf

    ; Validate event name
    If Not __Hooks_IsValidEvent($sEvent) Then
        _Log_Warn("Hooks: unknown event '" & $sKey & "', ignoring")
        Return 0
    EndIf

    ; Return as single-element 2D array
    Local $aResult[1][2]
    $aResult[0][0] = $sEvent
    $aResult[0][1] = $sValue
    Return $aResult
EndFunc

; Name:        __Hooks_IsValidEvent
; Description: Checks whether an event name is in the known events list
; Parameters:  $sEvent - event name to check
; Return:      True/False
Func __Hooks_IsValidEvent($sEvent)
    Local $aEvents = StringSplit($__HOOKS_EVENTS, "|")
    Local $i
    For $i = 1 To $aEvents[0]
        If $aEvents[$i] = $sEvent Then Return True
    Next
    Return False
EndFunc

; Name:        __Hooks_CheckTimeouts
; Description: Checks tracked PIDs and kills any that have exceeded the timeout.
;              Compacts the PID tracking array by removing finished/killed entries.
Func __Hooks_CheckTimeouts()
    Local $iNewCount = 0
    Local $i
    For $i = 0 To $__g_Hooks_iPIDCount - 1
        If $__g_Hooks_aPIDs[$i] = 0 Then ContinueLoop

        If Not ProcessExists($__g_Hooks_aPIDs[$i]) Then
            ; Process finished naturally
            $__g_Hooks_aPIDs[$i] = 0
            ContinueLoop
        EndIf

        ; Check timeout
        If TimerDiff($__g_Hooks_aTimers[$i]) > $__g_Hooks_iTimeout Then
            _Log_Warn("Hooks: killing PID " & $__g_Hooks_aPIDs[$i] & " (exceeded " & $__g_Hooks_iTimeout & "ms timeout)")
            ProcessClose($__g_Hooks_aPIDs[$i])
            $__g_Hooks_aPIDs[$i] = 0
            ContinueLoop
        EndIf

        ; Still running within timeout — compact into array
        If $iNewCount <> $i Then
            $__g_Hooks_aPIDs[$iNewCount]   = $__g_Hooks_aPIDs[$i]
            $__g_Hooks_aTimers[$iNewCount]  = $__g_Hooks_aTimers[$i]
        EndIf
        $iNewCount += 1
    Next

    ; Zero out remaining slots
    For $i = $iNewCount To $__g_Hooks_iPIDCount - 1
        $__g_Hooks_aPIDs[$i] = 0
    Next
    $__g_Hooks_iPIDCount = $iNewCount
EndFunc
