#include-once

; ===============================================================
; Tests for includes\Slideshow.au3
; PURE / HEADLESS ONLY — never calls _VD_GoTo / _NavigateTo / any switching.
; Selection / sequence / interval / loop / break truth tables + the state machine
; driven with synthetic elapsed times (module globals poked directly for the
; time-dependent cases, exactly as the engine would compute them).
; ===============================================================

; Small helper: render a 1-D array as a CSV for equality asserts.
Func __SS_ArrToStr($a)
    If Not IsArray($a) Then Return "<notarray>"
    Local $s = ""
    Local $i
    For $i = 0 To UBound($a) - 1
        If $i > 0 Then $s &= ","
        $s &= $a[$i]
    Next
    Return $s
EndFunc

Func _RunTest_Slideshow()
    _Test_Suite("Slideshow")

    Local $a, $iErr

    ; ================= _SS_BuildSelection : all =================
    Local $aNoNames[1] = [""]
    $a = _SS_BuildSelection("all", "forward", 1, $aNoNames, "", "")
    _Test_AssertEqual("all N=1 forward", __SS_ArrToStr($a), "1")
    $a = _SS_BuildSelection("all", "forward", 5, $aNoNames, "", "")
    _Test_AssertEqual("all N=5 forward", __SS_ArrToStr($a), "1,2,3,4,5")
    $a = _SS_BuildSelection("all", "backward", 5, $aNoNames, "", "")
    _Test_AssertEqual("all N=5 backward", __SS_ArrToStr($a), "5,4,3,2,1")
    $a = _SS_BuildSelection("all", "forward", 2, $aNoNames, "", "")
    _Test_AssertEqual("all N=2 forward", __SS_ArrToStr($a), "1,2")
    ; unknown mode falls back to all
    $a = _SS_BuildSelection("bogus", "forward", 3, $aNoNames, "", "")
    _Test_AssertEqual("unknown mode -> all", __SS_ArrToStr($a), "1,2,3")

    ; ================= _SS_BuildSelection : even / odd =================
    $a = _SS_BuildSelection("even", "forward", 1, $aNoNames, "", "")
    $iErr = @error
    _Test_AssertEqual("even N=1 -> @error", $iErr, 1)
    $a = _SS_BuildSelection("even", "forward", 2, $aNoNames, "", "")
    _Test_AssertEqual("even N=2 forward", __SS_ArrToStr($a), "2")
    $a = _SS_BuildSelection("even", "forward", 5, $aNoNames, "", "")
    _Test_AssertEqual("even N=5 forward", __SS_ArrToStr($a), "2,4")
    $a = _SS_BuildSelection("even", "backward", 5, $aNoNames, "", "")
    _Test_AssertEqual("even N=5 backward", __SS_ArrToStr($a), "4,2")
    $a = _SS_BuildSelection("odd", "forward", 1, $aNoNames, "", "")
    _Test_AssertEqual("odd N=1 forward", __SS_ArrToStr($a), "1")
    $a = _SS_BuildSelection("odd", "forward", 5, $aNoNames, "", "")
    _Test_AssertEqual("odd N=5 forward", __SS_ArrToStr($a), "1,3,5")
    $a = _SS_BuildSelection("odd", "backward", 5, $aNoNames, "", "")
    _Test_AssertEqual("odd N=5 backward", __SS_ArrToStr($a), "5,3,1")

    ; ================= _SS_BuildSelection : name_contains =================
    ; 0-based: $aNames[i-1] is the label of desktop i.
    Local $aNames[4] = ["Work", "home WORK", "Play", "workshop"]
    ; "work" case-insensitive substring matches desktops 1,2,4 (incl. "workshop" substring)
    $a = _SS_BuildSelection("name_contains", "forward", 4, $aNames, "work", "")
    _Test_AssertEqual("name_contains 'work' (case-insens, substring)", __SS_ArrToStr($a), "1,2,4")
    $a = _SS_BuildSelection("name_contains", "backward", 4, $aNames, "work", "")
    _Test_AssertEqual("name_contains 'work' backward", __SS_ArrToStr($a), "4,2,1")
    ; whole label match still works
    $a = _SS_BuildSelection("name_contains", "forward", 4, $aNames, "Play", "")
    _Test_AssertEqual("name_contains 'Play' single", __SS_ArrToStr($a), "3")
    ; empty filter -> invalid selection
    $a = _SS_BuildSelection("name_contains", "forward", 4, $aNames, "", "")
    $iErr = @error
    _Test_AssertEqual("name_contains empty filter -> @error", $iErr, 1)
    ; zero matches -> invalid selection
    $a = _SS_BuildSelection("name_contains", "forward", 4, $aNames, "zzz", "")
    $iErr = @error
    _Test_AssertEqual("name_contains no match -> @error", $iErr, 1)

    ; ================= _SS_BuildSelection : custom =================
    $a = _SS_BuildSelection("custom", "forward", 5, $aNoNames, "", "1,3,2,5")
    _Test_AssertEqual("custom valid", __SS_ArrToStr($a), "1,3,2,5")
    $a = _SS_BuildSelection("custom", "backward", 5, $aNoNames, "", "1,3,2,5")
    _Test_AssertEqual("custom backward reverses order", __SS_ArrToStr($a), "5,2,3,1")
    $a = _SS_BuildSelection("custom", "forward", 5, $aNoNames, "", "")
    $iErr = @error
    _Test_AssertEqual("custom empty -> @error", $iErr, 1)

    ; ================= _SS_ParseSequence =================
    $a = _SS_ParseSequence("1,3,2,5", 5)
    _Test_AssertEqual("seq valid", __SS_ArrToStr($a), "1,3,2,5")
    $a = _SS_ParseSequence("1,3,2,5", 3)
    _Test_AssertEqual("seq out-of-range skipped", __SS_ArrToStr($a), "1,3,2")
    $a = _SS_ParseSequence("1,1,2", 5)
    _Test_AssertEqual("seq repeats preserved", __SS_ArrToStr($a), "1,1,2")
    $a = _SS_ParseSequence("abc,2,x", 5)
    _Test_AssertEqual("seq garbage tokens skipped", __SS_ArrToStr($a), "2")
    $a = _SS_ParseSequence("0,-1,2", 3)
    _Test_AssertEqual("seq zero/negative skipped", __SS_ArrToStr($a), "2")
    $a = _SS_ParseSequence("", 5)
    $iErr = @error
    _Test_AssertEqual("seq empty -> @error", $iErr, 1)
    $a = _SS_ParseSequence("9,9", 5)
    $iErr = @error
    _Test_AssertEqual("seq all-out-of-range -> @error", $iErr, 1)

    ; ================= _SS_ParseDesktopIntervals + _SS_IntervalForDesktop =================
    Local $aInt = _SS_ParseDesktopIntervals("1:5000,3:8000", 5, 20000)
    _Test_AssertEqual("interval desktop1 override", _SS_IntervalForDesktop($aInt, 1, 20000), 5000)
    _Test_AssertEqual("interval desktop2 default", _SS_IntervalForDesktop($aInt, 2, 20000), 20000)
    _Test_AssertEqual("interval desktop3 override", _SS_IntervalForDesktop($aInt, 3, 20000), 8000)
    _Test_AssertEqual("interval desktop5 default (unlisted)", _SS_IntervalForDesktop($aInt, 5, 20000), 20000)
    ; bounds safety
    _Test_AssertEqual("interval desktop0 -> default", _SS_IntervalForDesktop($aInt, 0, 20000), 20000)
    _Test_AssertEqual("interval desktop N+1 -> default", _SS_IntervalForDesktop($aInt, 6, 20000), 20000)
    ; zero / invalid override -> default; clamps
    Local $aInt2 = _SS_ParseDesktopIntervals("2:0,3:100,4:9999999,5:abc", 5, 1000)
    _Test_AssertEqual("interval 0 -> default", _SS_IntervalForDesktop($aInt2, 2, 1000), 1000)
    _Test_AssertEqual("interval clamped low -> 500", _SS_IntervalForDesktop($aInt2, 3, 1000), 500)
    _Test_AssertEqual("interval clamped high -> 3600000", _SS_IntervalForDesktop($aInt2, 4, 1000), 3600000)
    _Test_AssertEqual("interval non-numeric -> default", _SS_IntervalForDesktop($aInt2, 5, 1000), 1000)
    ; a custom sequence visiting desktop N twice gets N's override at both positions
    ; (lookup is by desktop number, position-independent)
    Local $aIntTwice = _SS_ParseDesktopIntervals("2:5000", 3, 1000)
    _Test_AssertEqual("desktop 2 override (occurrence A)", _SS_IntervalForDesktop($aIntTwice, 2, 1000), 5000)
    _Test_AssertEqual("desktop 2 override (occurrence B)", _SS_IntervalForDesktop($aIntTwice, 2, 1000), 5000)

    ; ================= _SS_NextIndex : wrap + completed-loop counting =================
    Local $iLoops = 0
    Local $iIdx = -1
    $iIdx = _SS_NextIndex($iIdx, 3, $iLoops)
    _Test_AssertEqual("next from -1 -> 0", $iIdx, 0)
    _Test_AssertEqual("no loop counted on first step", $iLoops, 0)
    $iIdx = _SS_NextIndex($iIdx, 3, $iLoops)
    _Test_AssertEqual("next 0 -> 1", $iIdx, 1)
    $iIdx = _SS_NextIndex($iIdx, 3, $iLoops)
    _Test_AssertEqual("next 1 -> 2", $iIdx, 2)
    _Test_AssertEqual("still 0 loops mid-pass", $iLoops, 0)
    $iIdx = _SS_NextIndex($iIdx, 3, $iLoops)
    _Test_AssertEqual("next 2 -> 0 (wrap)", $iIdx, 0)
    _Test_AssertEqual("loop counted on wrap", $iLoops, 1)
    ; single-desktop: every advance after the first is a wrap
    Local $iLoops1 = 0, $iIdx1 = -1
    $iIdx1 = _SS_NextIndex($iIdx1, 1, $iLoops1)
    _Test_AssertEqual("seqLen1 first step no loop", $iLoops1, 0)
    $iIdx1 = _SS_NextIndex($iIdx1, 1, $iLoops1)
    _Test_AssertEqual("seqLen1 second step wraps", $iLoops1, 1)

    ; ================= _SS_LoopExpired truth table =================
    _Test_AssertFalse("infinite never expires (0)", _SS_LoopExpired("infinite", 0, 3, 0, 300000))
    _Test_AssertFalse("infinite never expires (huge)", _SS_LoopExpired("infinite", 9999, 3, 999999999, 300000))
    _Test_AssertFalse("count below max", _SS_LoopExpired("count", 2, 3, 0, 0))
    _Test_AssertTrue("count at exact boundary", _SS_LoopExpired("count", 3, 3, 0, 0))
    _Test_AssertTrue("count past max", _SS_LoopExpired("count", 4, 3, 0, 0))
    _Test_AssertFalse("duration below budget", _SS_LoopExpired("duration", 0, 0, 299999, 300000))
    _Test_AssertTrue("duration at budget", _SS_LoopExpired("duration", 0, 0, 300000, 300000))
    _Test_AssertTrue("duration past budget", _SS_LoopExpired("duration", 0, 0, 300001, 300000))

    ; ================= _SS_ShouldBreakOn : 4 x (on/off) =================
    _Test_AssertTrue("break manual on", _SS_ShouldBreakOn("manual_switch", True, False, False, False))
    _Test_AssertFalse("break manual off", _SS_ShouldBreakOn("manual_switch", False, True, True, True))
    _Test_AssertTrue("break widget on", _SS_ShouldBreakOn("widget_click", False, True, False, False))
    _Test_AssertFalse("break widget off", _SS_ShouldBreakOn("widget_click", True, False, True, True))
    _Test_AssertTrue("break hotkey on", _SS_ShouldBreakOn("hotkey", False, False, True, False))
    _Test_AssertFalse("break hotkey off", _SS_ShouldBreakOn("hotkey", True, True, False, True))
    _Test_AssertTrue("break any_input on", _SS_ShouldBreakOn("any_input", False, False, False, True))
    _Test_AssertFalse("break any_input off", _SS_ShouldBreakOn("any_input", True, True, True, False))
    _Test_AssertFalse("break unknown event", _SS_ShouldBreakOn("bogus", True, True, True, True))

    ; ================= _SS_StepDue =================
    _Test_AssertFalse("step not due", _SS_StepDue(999, 1000))
    _Test_AssertTrue("step due at boundary", _SS_StepDue(1000, 1000))
    _Test_AssertTrue("step due past", _SS_StepDue(1500, 1000))

    ; ================= State machine =================
    _SS_Stop()
    _Test_AssertFalse("inactive initially", _SS_IsActive())

    ; Start refuses an empty sequence
    Local $aEmpty[0]
    Local $bStart = _SS_Start($aEmpty, $aInt, "infinite", 0, 0)
    $iErr = @error
    _Test_AssertFalse("Start empty -> False", $bStart)
    _Test_AssertEqual("Start empty -> @error", $iErr, 1)
    _Test_AssertFalse("Start empty leaves inactive", _SS_IsActive())

    ; Start arms; not due immediately
    Local $aSeq[2] = [1, 2]
    Local $aSeqInt = _SS_ParseDesktopIntervals("", 2, 1000)
    _SS_Start($aSeq, $aSeqInt, "infinite", 0, 0)
    _Test_AssertTrue("active after Start", _SS_IsActive())
    _Test_AssertEqual("ExpectedTarget 0 before first step", _SS_ExpectedTarget(), 0)
    _Test_AssertEqual("Poll not due immediately after start", _SS_Poll(), 0)

    ; Force the step due and verify target + expected-target tracking
    $__g_SS_iCurStepIntervalMs = 0
    _Test_AssertEqual("Poll first due -> seq[0]=1", _SS_Poll(), 1)
    _Test_AssertEqual("ExpectedTarget tracks 1", _SS_ExpectedTarget(), 1)
    _Test_AssertEqual("CurrentStep = 1", _SS_CurrentStep(), 1)
    $__g_SS_iCurStepIntervalMs = 0
    _Test_AssertEqual("Poll second due -> seq[1]=2", _SS_Poll(), 2)
    _Test_AssertEqual("ExpectedTarget tracks 2", _SS_ExpectedTarget(), 2)
    _Test_AssertEqual("CurrentStep = 2", _SS_CurrentStep(), 2)
    $__g_SS_iCurStepIntervalMs = 0
    _Test_AssertEqual("Poll third due wraps -> seq[0]=1", _SS_Poll(), 1)
    _Test_AssertEqual("completed loops = 1 after wrap", _SS_GetCompletedLoops(), 1)
    _SS_Stop()
    _Test_AssertFalse("inactive after Stop", _SS_IsActive())
    _Test_AssertEqual("Poll returns 0 when inactive", _SS_Poll(), 0)

    ; -1 when the loop budget is exhausted (count mode; forced completed-loop state)
    _SS_Start($aSeq, $aSeqInt, "count", 1, 0)
    $__g_SS_iCompletedLoops = 1 ; one full pass already done, budget = 1
    _Test_AssertEqual("Poll -1 when count budget met", _SS_Poll(), -1)
    _SS_Stop()

    ; -1 when the duration budget is exhausted (duration mode; forced zero budget so any
    ; elapsed total is already past it — deterministic, no wall-clock wait)
    _SS_Start($aSeq, $aSeqInt, "duration", 0, 5)
    $__g_SS_iLoopDurationMs = 0
    _Test_AssertEqual("Poll -1 when duration budget met", _SS_Poll(), -1)
    _SS_Stop()

    _Test_AssertFalse("final: inactive", _SS_IsActive())
EndFunc
