#include-once
#include "Config.au3"
#include "Logger.au3"

; #INDEX# =======================================================
; Title .........: ExplorerMonitor
; Description ....: Monitors explorer.exe and triggers recovery on crash
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_EM_bExplorerAlive = True
Global $__g_EM_bRecoveryPending = False

; #FUNCTIONS# ===================================================

; Name:        _EM_Start
; Description: Starts the explorer monitor via AdlibRegister
Func _EM_Start()
    If Not _Cfg_GetExplorerMonitorEnabled() Then Return
    $__g_EM_bExplorerAlive = (ProcessExists("explorer.exe") > 0)
    AdlibRegister("__EM_Poll", _Cfg_GetExplorerCheckInterval())
    _Log_Info("Explorer monitor started (interval: " & _Cfg_GetExplorerCheckInterval() & "ms)")
EndFunc

; Name:        _EM_Stop
; Description: Stops the explorer monitor
Func _EM_Stop()
    AdlibUnRegister("__EM_Poll")
    _Log_Info("Explorer monitor stopped")
EndFunc

; Name:        __EM_Poll
; Description: Periodic check for explorer.exe (called via AdlibRegister)
Func __EM_Poll()
    Local $bAlive = (ProcessExists("explorer.exe") > 0)
    If Not $bAlive And $__g_EM_bExplorerAlive Then
        ; Explorer just died
        $__g_EM_bExplorerAlive = False
        _Log_Warn("Explorer.exe crash detected")
    ElseIf $bAlive And Not $__g_EM_bExplorerAlive Then
        ; Explorer recovered
        $__g_EM_bExplorerAlive = True
        $__g_EM_bRecoveryPending = True
        _Log_Info("Explorer.exe recovered")
    EndIf
EndFunc

; Name:        _EM_CheckRecovery
; Description: Call from main loop. If recovery is pending, returns True once and resets flag.
;              The caller should reinitialize DLL, widget, hooks, etc.
; Return:      True if recovery just happened, False otherwise
Func _EM_CheckRecovery()
    If Not $__g_EM_bRecoveryPending Then Return False
    $__g_EM_bRecoveryPending = False
    Return True
EndFunc

; Name:        _EM_IsExplorerAlive
; Description: Returns whether explorer.exe is currently running
; Return:      True/False
Func _EM_IsExplorerAlive()
    Return $__g_EM_bExplorerAlive
EndFunc
