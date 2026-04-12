#include-once
#include "Config.au3"
#include "Logger.au3"

; #INDEX# =======================================================
; Title .........: ExplorerMonitor
; Description ....: Monitors a shell process (default: explorer.exe) with
;                   configurable retry logic, exponential backoff, and
;                   optional auto-restart. Runs in-process via AdlibRegister
;                   (inherently excluded from singleton check).
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_EM_bShellAlive = True
Global $__g_EM_bRecoveryPending = False
Global $__g_EM_iRetryCount = 0
Global $__g_EM_iCurrentDelay = 0
Global $__g_EM_hCrashTimer = 0
Global $__g_EM_bWaitingForRecovery = False

; #FUNCTIONS# ===================================================

; Name:        _EM_Start
; Description: Starts the shell monitor via AdlibRegister
Func _EM_Start()
    If Not _Cfg_GetExplorerMonitorEnabled() Then Return
    Local $sProc = _Cfg_GetShellProcessName()
    $__g_EM_bShellAlive = (ProcessExists($sProc) > 0)
    $__g_EM_iRetryCount = 0
    $__g_EM_iCurrentDelay = _Cfg_GetMonitorRetryDelay()
    $__g_EM_bWaitingForRecovery = False
    AdlibRegister("__EM_Poll", _Cfg_GetExplorerCheckInterval())
    _Log_Info("Shell monitor started: " & $sProc & " (interval: " & _Cfg_GetExplorerCheckInterval() & "ms)")
EndFunc

; Name:        _EM_Stop
; Description: Stops the shell monitor and resets state
Func _EM_Stop()
    AdlibUnRegister("__EM_Poll")
    $__g_EM_bWaitingForRecovery = False
    $__g_EM_iRetryCount = 0
    _Log_Info("Shell monitor stopped")
EndFunc

; Name:        __EM_Poll
; Description: Periodic check for shell process (called via AdlibRegister)
Func __EM_Poll()
    Local $sProc = _Cfg_GetShellProcessName()
    Local $bAlive = (ProcessExists($sProc) > 0)

    If Not $bAlive And $__g_EM_bShellAlive Then
        ; Shell just died
        $__g_EM_bShellAlive = False
        $__g_EM_hCrashTimer = TimerInit()
        $__g_EM_iRetryCount = 0
        $__g_EM_iCurrentDelay = _Cfg_GetMonitorRetryDelay()
        $__g_EM_bWaitingForRecovery = True
        _Log_Warn($sProc & " crash detected")

        ; Attempt auto-restart if configured
        If _Cfg_GetMonitorAutoRestart() Then
            _Log_Info("Auto-restart: waiting " & _Cfg_GetMonitorRestartDelay() & "ms before restarting " & $sProc)
            ; Delay handled on next poll cycle via $__g_EM_bWaitingForRecovery
        EndIf

    ElseIf Not $bAlive And $__g_EM_bWaitingForRecovery Then
        ; Shell still dead — check retry logic
        Local $iMaxRetries = _Cfg_GetMonitorMaxRetries()
        If $iMaxRetries > 0 And $__g_EM_iRetryCount >= $iMaxRetries Then
            _Log_Warn("Shell monitor: max retries (" & $iMaxRetries & ") exhausted for " & $sProc)
            $__g_EM_bWaitingForRecovery = False
            Return
        EndIf

        If TimerDiff($__g_EM_hCrashTimer) >= $__g_EM_iCurrentDelay Then
            $__g_EM_iRetryCount += 1

            If _Cfg_GetMonitorAutoRestart() Then
                _Log_Info("Shell monitor: restart attempt " & $__g_EM_iRetryCount & " for " & $sProc)
                Run($sProc)
            Else
                _Log_Info("Shell monitor: waiting for " & $sProc & " (attempt " & $__g_EM_iRetryCount & ")")
            EndIf

            ; Reset timer for next retry
            $__g_EM_hCrashTimer = TimerInit()

            ; Apply exponential backoff
            If _Cfg_GetMonitorExpBackoff() Then
                $__g_EM_iCurrentDelay = $__g_EM_iCurrentDelay * 2
                If $__g_EM_iCurrentDelay > _Cfg_GetMonitorMaxRetryDelay() Then
                    $__g_EM_iCurrentDelay = _Cfg_GetMonitorMaxRetryDelay()
                EndIf
            EndIf
        EndIf

    ElseIf $bAlive And Not $__g_EM_bShellAlive Then
        ; Shell recovered (either auto-restarted or manually by user)
        $__g_EM_bShellAlive = True
        $__g_EM_bRecoveryPending = True
        $__g_EM_bWaitingForRecovery = False
        $__g_EM_iRetryCount = 0
        $__g_EM_iCurrentDelay = _Cfg_GetMonitorRetryDelay()
        _Log_Info($sProc & " recovered after " & $__g_EM_iRetryCount & " retries")
    EndIf
EndFunc

; Name:        _EM_CheckRecovery
; Description: Call from main loop. Returns True once on recovery, then resets.
; Return:      True if recovery just happened, False otherwise
Func _EM_CheckRecovery()
    If Not $__g_EM_bRecoveryPending Then Return False
    $__g_EM_bRecoveryPending = False
    Return True
EndFunc

; Name:        _EM_IsShellAlive
; Description: Returns whether the monitored shell process is running
; Return:      True/False
Func _EM_IsShellAlive()
    Return $__g_EM_bShellAlive
EndFunc

; Name:        _EM_IsExplorerAlive
; Description: Alias for backward compatibility
; Return:      True/False
Func _EM_IsExplorerAlive()
    Return $__g_EM_bShellAlive
EndFunc

; Name:        _EM_GetRetryCount
; Description: Returns the current retry attempt count
; Return:      Integer (0 if no crash or recovered)
Func _EM_GetRetryCount()
    Return $__g_EM_iRetryCount
EndFunc

; Name:        _EM_GetCurrentDelay
; Description: Returns the current retry delay (may be escalated by backoff)
; Return:      Integer milliseconds
Func _EM_GetCurrentDelay()
    Return $__g_EM_iCurrentDelay
EndFunc
