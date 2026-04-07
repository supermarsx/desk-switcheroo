#include-once
#include "VirtualDesktop.au3"
#include "Theme.au3"
#include "Config.au3"

; #INDEX# =======================================================
; Title .........: Peek
; Description ....: Desktop peek state machine — temporarily switch desktops on hover, snap back on leave
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_Peek_iOrigin       = 0
Global $__g_Peek_bActive       = False
Global $__g_Peek_bBounceBack   = False
Global $__g_Peek_hBounceTimer  = 0

; #FUNCTIONS# ===================================================

; Name:        _Peek_Start
; Description: Begins peeking at a target desktop. Stores the origin on first call.
; Parameters:  $iTarget - desktop index to peek at (1-based)
Func _Peek_Start($iTarget)
    If Not $__g_Peek_bActive Then
        $__g_Peek_iOrigin = _VD_GetCurrent()
        $__g_Peek_bActive = True
    EndIf
    $__g_Peek_bBounceBack = False
    _VD_GoTo($iTarget)
EndFunc

; Name:        _Peek_StartBounceBack
; Description: Starts the debounced bounce-back timer. Called when cursor leaves peek zone.
Func _Peek_StartBounceBack()
    If Not $__g_Peek_bActive Then Return
    If $__g_Peek_bBounceBack Then Return
    $__g_Peek_bBounceBack = True
    $__g_Peek_hBounceTimer = TimerInit()
EndFunc

; Name:        _Peek_CheckBounce
; Description: Checks if the bounce-back timer has elapsed. Call from main loop.
; Return:      True if bounce-back happened, False otherwise
Func _Peek_CheckBounce()
    If Not $__g_Peek_bBounceBack Then Return False
    If TimerDiff($__g_Peek_hBounceTimer) > _Cfg_GetPeekBounceDelay() Then
        $__g_Peek_bBounceBack = False
        _Peek_End()
        Return True
    EndIf
    Return False
EndFunc

; Name:        _Peek_End
; Description: Snaps back to the original desktop and clears peek state
Func _Peek_End()
    $__g_Peek_bBounceBack = False
    If Not $__g_Peek_bActive Then Return
    _VD_GoTo($__g_Peek_iOrigin)
    $__g_Peek_bActive = False
    $__g_Peek_iOrigin = 0
EndFunc

; Name:        _Peek_Commit
; Description: Accepts the currently peeked desktop as the new active desktop
Func _Peek_Commit()
    $__g_Peek_bBounceBack = False
    $__g_Peek_bActive = False
    $__g_Peek_iOrigin = 0
EndFunc

; Name:        _Peek_IsActive
; Description: Returns whether a peek is currently in progress
; Return:      True/False
Func _Peek_IsActive()
    Return $__g_Peek_bActive
EndFunc
