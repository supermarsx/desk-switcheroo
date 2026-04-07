#include-once

; ===============================================================
; Tests for includes\Peek.au3
; Unit tests — state machine logic (requires VD_Init for GoTo calls)
; ===============================================================

Func _RunTest_Peek()
    _Test_Suite("Peek")

    ; Ensure VD is initialized for GoTo calls
    Local $sDllDir = StringRegExpReplace(@ScriptDir, "\\[^\\]+$", "")
    Local $sDllPath = $sDllDir & "\VirtualDesktopAccessor.dll"
    _VD_Init($sDllPath)

    ; -- Initial state is inactive --
    _Test_AssertFalse("Initially inactive", _Peek_IsActive())

    ; -- End without start is a no-op --
    _Peek_End()
    _Test_AssertFalse("End without start: still inactive", _Peek_IsActive())

    ; -- Start activates peek --
    Local $iOriginal = _VD_GetCurrent()
    _Peek_Start($iOriginal) ; peek to same desktop to avoid side effects
    _Test_AssertTrue("Start activates peek", _Peek_IsActive())

    ; -- End deactivates peek --
    _Peek_End()
    _Test_AssertFalse("End deactivates peek", _Peek_IsActive())

    ; -- Commit deactivates peek --
    _Peek_Start($iOriginal)
    _Test_AssertTrue("Start again activates", _Peek_IsActive())
    _Peek_Commit()
    _Test_AssertFalse("Commit deactivates peek", _Peek_IsActive())

    ; -- Double start preserves origin --
    ; Start peeking, then peek to another target — origin should stay as the first
    _Peek_Start($iOriginal)
    _Peek_Start($iOriginal) ; second start should not overwrite origin
    _Test_AssertTrue("Double start: still active", _Peek_IsActive())
    _Peek_End() ; should snap back to original
    _Test_AssertFalse("Double start: end works", _Peek_IsActive())

    ; -- Bounce-back too early returns False --
    _Peek_Start($iOriginal)
    _Peek_StartBounceBack()
    Local $bBounced = _Peek_CheckBounce()
    _Test_AssertFalse("Bounce-back too early returns False", $bBounced)
    ; Still active because timer hasn't elapsed
    _Test_AssertTrue("Still active before bounce", _Peek_IsActive())

    ; -- Bounce-back after timer returns True --
    Sleep(600) ; wait for bounce timer ($THEME_TIMER_BOUNCE = 500ms)
    Local $bBouncedAfter = _Peek_CheckBounce()
    _Test_AssertTrue("Bounce-back after 600ms returns True", $bBouncedAfter)
    _Test_AssertFalse("Inactive after bounce-back", _Peek_IsActive())

    ; -- StartBounceBack when not peeking is a no-op --
    _Peek_StartBounceBack()
    _Test_AssertFalse("StartBounceBack when inactive: still inactive", _Peek_IsActive())

    ; Restore desktop
    _VD_GoTo($iOriginal)
EndFunc
