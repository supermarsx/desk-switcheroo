#include-once

; #INDEX# =======================================================
; Title .........: Slideshow
; Description ....: Pure desktop-slideshow engine plus a headless-testable step
;                   state machine. Supersedes the former Carousel (plan t6,
;                   Decision 1). Contains NO desktop switching: the selection /
;                   sequence / timing / loop / break logic are pure functions, and
;                   _SS_Poll() returns the target desktop number for the step now
;                   due — the caller (desktop_switcher.au3) performs the actual
;                   switch via _NavigateTo. This keeps the engine dependency-free
;                   (it never calls _Labels_Load / _VD_* itself; the caller passes
;                   the desktop count and a labels array in) and fully testable with
;                   synthetic names and elapsed times.
; Author .........: Mariana
; ===============================================================
; Index:
;   -- Pure logic --
;   _SS_BuildSelection        Resolve the participating-desktop set (mode+direction)
;   _SS_ParseSequence         Parse a custom CSV of 1-based desktop numbers
;   _SS_ParseDesktopIntervals Parse desktop:ms overrides into a per-desktop table
;   _SS_IntervalForDesktop    Effective step interval for a desktop (bounds-safe)
;   _SS_NextIndex             Next step index with wrap (+ completed-loop count)
;   _SS_LoopExpired           Loop-budget predicate (infinite/count/duration)
;   _SS_ShouldBreakOn         Break-condition predicate for an input event
;   _SS_StepDue               Whether the current step's interval has elapsed
;   -- State machine (module globals; caller performs all switching) --
;   _SS_Start / _SS_Stop / _SS_IsActive
;   _SS_Poll                  0=nothing, -1=loop budget exhausted, else target dtop
;   _SS_ExpectedTarget        Last commanded desktop (manual-switch detection)
;   _SS_CurrentStep           1-based position within the resolved selection
;   _SS_GetSeqLen / _SS_GetCompletedLoops
; ===============================================================

; #CONSTANTS# ===================================================
Global Const $__SS_INTERVAL_MIN = 500        ; per-desktop override floor (ms)
Global Const $__SS_INTERVAL_MAX = 3600000    ; per-desktop override ceiling (ms)

; #INTERNAL GLOBALS (state machine)# ============================
Global $__g_SS_bActive          = False
Global $__g_SS_aSeq[1]                        ; resolved 1-based desktop numbers
Global $__g_SS_iSeqLen          = 0
Global $__g_SS_aIntervals[1]                  ; [0]=default, [d]=ms for desktop d
Global $__g_SS_iStepIdx         = -1          ; index of last commanded step (-1 = none yet)
Global $__g_SS_sLoopMode        = "infinite"
Global $__g_SS_iLoopCount       = 0
Global $__g_SS_iLoopDurationMs  = 0
Global $__g_SS_iCompletedLoops  = 0
Global $__g_SS_hStepTimer       = 0
Global $__g_SS_hTotalTimer      = 0
Global $__g_SS_iCurStepIntervalMs = 0
Global $__g_SS_iExpectedTarget  = 0

; #FUNCTIONS# ===================================================

; =============================================
; PURE LOGIC (headless-testable, no side effects, no switching)
; =============================================

; Name:        _SS_BuildSelection
; Description: Resolves the ordered set of participating desktops for a slideshow.
; Parameters:  $sMode       - all|even|odd|name_contains|custom
;              $sDirection  - forward|backward (backward reverses the result)
;              $iCount      - number of desktops (1..N)
;              $aNames      - 0-based array of desktop labels; $aNames[i-1] is the
;                             label of desktop i (only used by name_contains)
;              $sNameFilter - case-insensitive substring (name_contains only)
;              $sCustomCsv  - CSV of 1-based desktop numbers (custom only)
; Return:      Ordered 1-based array of desktop numbers, or SetError(1) when the
;              selection is empty (caller refuses to start).
Func _SS_BuildSelection($sMode, $sDirection, $iCount, $aNames, $sNameFilter, $sCustomCsv)
    Local $aOut
    Switch StringLower($sMode)
        Case "custom"
            $aOut = _SS_ParseSequence($sCustomCsv, $iCount)
        Case "even"
            $aOut = __SS_RangeByParity($iCount, 0)
        Case "odd"
            $aOut = __SS_RangeByParity($iCount, 1)
        Case "name_contains"
            $aOut = __SS_SelectByName($iCount, $aNames, $sNameFilter)
        Case Else ; "all" (and any unknown mode falls back to all)
            $aOut = __SS_RangeAll($iCount)
    EndSwitch
    If @error Then Return SetError(1, 0, 0)

    If StringLower($sDirection) = "backward" Then $aOut = __SS_Reverse($aOut)
    Return $aOut
EndFunc

; Name:        _SS_ParseSequence
; Description: Parses a CSV of 1-based desktop numbers. Tokens that are non-numeric
;              or outside 1..$iCount are skipped; repeats are preserved.
; Return:      Array of ints, or SetError(1) when nothing valid remains.
Func _SS_ParseSequence($sCsv, $iCount)
    Local $aTokens = StringSplit(StringStripWS($sCsv, 3), ",", 2) ; flag 2: no count element
    Local $aOut[UBound($aTokens)]
    Local $iN = 0
    Local $i
    For $i = 0 To UBound($aTokens) - 1
        Local $sTok = StringStripWS($aTokens[$i], 3)
        If $sTok = "" Then ContinueLoop
        If Not StringIsInt($sTok) Then ContinueLoop
        Local $iVal = Int($sTok)
        If $iVal < 1 Or $iVal > $iCount Then ContinueLoop
        $aOut[$iN] = $iVal
        $iN += 1
    Next
    If $iN < 1 Then Return SetError(1, 0, 0)
    ReDim $aOut[$iN]
    Return $aOut
EndFunc

; Name:        _SS_ParseDesktopIntervals
; Description: Parses "desktop:ms" pairs into a per-desktop interval table indexed
;              by desktop number. Applies in EVERY selection mode (Decision 4).
;              Unlisted / zero / invalid desktops use $iDefaultMs; overrides clamp
;              to 500..3600000 ms.
; Return:      Array sized $iCount+1: [0]=default, [d]=ms for desktop d (1..N).
Func _SS_ParseDesktopIntervals($sCsv, $iCount, $iDefaultMs)
    If $iCount < 0 Then $iCount = 0
    Local $aOut[$iCount + 1]
    $aOut[0] = $iDefaultMs
    Local $d
    For $d = 1 To $iCount
        $aOut[$d] = $iDefaultMs
    Next

    Local $aPairs = StringSplit(StringStripWS($sCsv, 3), ",", 2)
    Local $i
    For $i = 0 To UBound($aPairs) - 1
        Local $sPair = StringStripWS($aPairs[$i], 3)
        If $sPair = "" Then ContinueLoop
        Local $aKV = StringSplit($sPair, ":", 2)
        If UBound($aKV) < 2 Then ContinueLoop
        Local $sK = StringStripWS($aKV[0], 3)
        Local $sV = StringStripWS($aKV[1], 3)
        If Not StringIsInt($sK) Or Not StringIsInt($sV) Then ContinueLoop
        Local $iDesk = Int($sK)
        Local $iMs = Int($sV)
        If $iDesk < 1 Or $iDesk > $iCount Then ContinueLoop
        If $iMs <= 0 Then ContinueLoop
        If $iMs < $__SS_INTERVAL_MIN Then $iMs = $__SS_INTERVAL_MIN
        If $iMs > $__SS_INTERVAL_MAX Then $iMs = $__SS_INTERVAL_MAX
        $aOut[$iDesk] = $iMs
    Next
    Return $aOut
EndFunc

; Name:        _SS_IntervalForDesktop
; Description: Bounds-safe lookup of the effective step interval for a desktop.
; Return:      ms from the table, or $iDefaultMs for out-of-range desktops.
Func _SS_IntervalForDesktop($aIntervals, $iDesktop, $iDefaultMs)
    If Not IsArray($aIntervals) Then Return $iDefaultMs
    If $iDesktop >= 1 And $iDesktop < UBound($aIntervals) Then Return $aIntervals[$iDesktop]
    Return $iDefaultMs
EndFunc

; Name:        _SS_NextIndex
; Description: Advances a 0-based step index by one, wrapping to 0 at the end. Each
;              wrap increments $iCompletedLoops (ByRef). A -1 start index advances to
;              0 without counting a loop (the first desktop shown).
; Return:      Next step index.
Func _SS_NextIndex($iIdx, $iSeqLen, ByRef $iCompletedLoops)
    If $iSeqLen < 1 Then Return 0
    Local $iNext = $iIdx + 1
    If $iNext >= $iSeqLen Then
        $iNext = 0
        $iCompletedLoops += 1
    EndIf
    Return $iNext
EndFunc

; Name:        _SS_LoopExpired
; Description: Loop-budget predicate. infinite never expires; count expires once
;              $iCompletedLoops full passes are done; duration expires once the
;              elapsed total reaches the budget.
; Return:      True/False.
Func _SS_LoopExpired($sMode, $iCompletedLoops, $iMaxLoops, $iElapsedTotalMs, $iMaxDurationMs)
    Switch StringLower($sMode)
        Case "count"
            Return ($iCompletedLoops >= $iMaxLoops)
        Case "duration"
            Return ($iElapsedTotalMs >= $iMaxDurationMs)
        Case Else ; infinite
            Return False
    EndSwitch
EndFunc

; Name:        _SS_ShouldBreakOn
; Description: Whether an input event should stop the slideshow, given the four
;              per-condition config toggles.
; Parameters:  $sEvent - "manual_switch" | "widget_click" | "hotkey" | "any_input"
; Return:      True/False.
Func _SS_ShouldBreakOn($sEvent, $bOnManualSwitch, $bOnWidgetClick, $bOnHotkey, $bOnAnyInput)
    Switch $sEvent
        Case "manual_switch"
            Return $bOnManualSwitch
        Case "widget_click"
            Return $bOnWidgetClick
        Case "hotkey"
            Return $bOnHotkey
        Case "any_input"
            Return $bOnAnyInput
        Case Else
            Return False
    EndSwitch
EndFunc

; Name:        _SS_StepDue
; Description: Whether a step's dwell interval has elapsed.
; Return:      True/False.
Func _SS_StepDue($iElapsedStepMs, $iStepIntervalMs)
    Return ($iElapsedStepMs >= $iStepIntervalMs)
EndFunc

; =============================================
; STATE MACHINE (module globals; caller performs all switching)
; =============================================

; Name:        _SS_Start
; Description: Arms the slideshow state from a resolved sequence + per-desktop
;              interval table. The initial dwell uses the default interval (the user
;              is on their pre-slideshow desktop), so the first switch fires one
;              interval after start rather than instantly.
; Parameters:  $aSeq               - resolved 1-based desktop numbers (from _SS_BuildSelection)
;              $aDesktopIntervalsMs - per-desktop table (from _SS_ParseDesktopIntervals)
;              $sLoopMode           - infinite|count|duration
;              $iLoopCount          - full passes for count mode
;              $iLoopDurationSec    - total seconds for duration mode
; Return:      True armed, or SetError(1)/False on an empty sequence.
Func _SS_Start($aSeq, $aDesktopIntervalsMs, $sLoopMode, $iLoopCount, $iLoopDurationSec)
    If Not IsArray($aSeq) Or UBound($aSeq) < 1 Then Return SetError(1, 0, False)

    $__g_SS_aSeq = $aSeq
    $__g_SS_iSeqLen = UBound($aSeq)
    If IsArray($aDesktopIntervalsMs) And UBound($aDesktopIntervalsMs) >= 1 Then
        $__g_SS_aIntervals = $aDesktopIntervalsMs
    Else
        Local $aFallback[1] = [20000]
        $__g_SS_aIntervals = $aFallback
    EndIf
    $__g_SS_sLoopMode = StringLower($sLoopMode)
    $__g_SS_iLoopCount = $iLoopCount
    $__g_SS_iLoopDurationMs = $iLoopDurationSec * 1000
    $__g_SS_iCompletedLoops = 0
    $__g_SS_iStepIdx = -1
    $__g_SS_iExpectedTarget = 0
    $__g_SS_iCurStepIntervalMs = $__g_SS_aIntervals[0] ; initial dwell = default interval
    $__g_SS_hStepTimer = TimerInit()
    $__g_SS_hTotalTimer = TimerInit()
    $__g_SS_bActive = True
    Return True
EndFunc

; Name:        _SS_Stop
; Description: Disarms the slideshow and resets step/loop state.
Func _SS_Stop()
    $__g_SS_bActive = False
    $__g_SS_iStepIdx = -1
    $__g_SS_iExpectedTarget = 0
    $__g_SS_iCompletedLoops = 0
EndFunc

; Name:        _SS_IsActive
; Return:      Whether the slideshow is currently running.
Func _SS_IsActive()
    Return $__g_SS_bActive
EndFunc

; Name:        _SS_Poll
; Description: Advances the state machine using TimerDiff against the internal step
;              and total timers, delegating every decision to the pure functions
;              above. Performs NO switching.
; Return:      0  - nothing due yet
;              -1 - loop budget exhausted (caller stops + fires "finished")
;              N  - target desktop number for the step now due (caller switches)
Func _SS_Poll()
    If Not $__g_SS_bActive Then Return 0

    ; Duration budget is checked independently of step timing so a long interval
    ; cannot outlast the total-run budget.
    If _SS_LoopExpired($__g_SS_sLoopMode, $__g_SS_iCompletedLoops, $__g_SS_iLoopCount, _
            TimerDiff($__g_SS_hTotalTimer), $__g_SS_iLoopDurationMs) Then Return -1

    If Not _SS_StepDue(TimerDiff($__g_SS_hStepTimer), $__g_SS_iCurStepIntervalMs) Then Return 0

    ; A step is due — advance (may increment the completed-loop count on wrap).
    Local $iNext = _SS_NextIndex($__g_SS_iStepIdx, $__g_SS_iSeqLen, $__g_SS_iCompletedLoops)

    ; Re-check after advancing so count mode stops exactly at the terminal wrap
    ; (the pass that would start loop N+1) instead of visiting the first desktop again.
    If _SS_LoopExpired($__g_SS_sLoopMode, $__g_SS_iCompletedLoops, $__g_SS_iLoopCount, _
            TimerDiff($__g_SS_hTotalTimer), $__g_SS_iLoopDurationMs) Then Return -1

    $__g_SS_iStepIdx = $iNext
    Local $iTarget = $__g_SS_aSeq[$iNext]
    $__g_SS_iExpectedTarget = $iTarget

    ; Reset the dwell timer for the newly-shown desktop's own interval.
    $__g_SS_iCurStepIntervalMs = _SS_IntervalForDesktop($__g_SS_aIntervals, $iTarget, $__g_SS_aIntervals[0])
    $__g_SS_hStepTimer = TimerInit()
    Return $iTarget
EndFunc

; Name:        _SS_ExpectedTarget
; Return:      The last desktop the slideshow commanded (0 if none yet). Used by the
;              caller to distinguish the slideshow's own switch from a manual one.
Func _SS_ExpectedTarget()
    Return $__g_SS_iExpectedTarget
EndFunc

; Name:        _SS_CurrentStep
; Return:      1-based position within the resolved selection (0 before the first step).
Func _SS_CurrentStep()
    Return $__g_SS_iStepIdx + 1
EndFunc

; Name:        _SS_GetSeqLen
; Return:      Length of the resolved selection.
Func _SS_GetSeqLen()
    Return $__g_SS_iSeqLen
EndFunc

; Name:        _SS_GetCompletedLoops
; Return:      Number of full passes completed so far.
Func _SS_GetCompletedLoops()
    Return $__g_SS_iCompletedLoops
EndFunc

; =============================================
; INTERNAL PURE HELPERS
; =============================================

; Name:        __SS_RangeAll
; Description: 1..N ascending. SetError(1) when N < 1.
Func __SS_RangeAll($iCount)
    If $iCount < 1 Then Return SetError(1, 0, 0)
    Local $aOut[$iCount]
    Local $i
    For $i = 0 To $iCount - 1
        $aOut[$i] = $i + 1
    Next
    Return $aOut
EndFunc

; Name:        __SS_RangeByParity
; Description: Desktops whose number has the given parity (even => remainder 0,
;              odd => remainder 1), ascending. SetError(1) when none match.
Func __SS_RangeByParity($iCount, $iRemainder)
    If $iCount < 1 Then Return SetError(1, 0, 0)
    Local $aOut[$iCount]
    Local $iN = 0
    Local $i
    For $i = 1 To $iCount
        If Mod($i, 2) = $iRemainder Then
            $aOut[$iN] = $i
            $iN += 1
        EndIf
    Next
    If $iN < 1 Then Return SetError(1, 0, 0)
    ReDim $aOut[$iN]
    Return $aOut
EndFunc

; Name:        __SS_SelectByName
; Description: Desktops whose label contains $sNameFilter (case-insensitive
;              substring). Empty filter or zero matches => SetError(1).
Func __SS_SelectByName($iCount, $aNames, $sNameFilter)
    If StringStripWS($sNameFilter, 3) = "" Then Return SetError(1, 0, 0)
    If $iCount < 1 Then Return SetError(1, 0, 0)
    Local $aOut[$iCount]
    Local $iN = 0
    Local $i
    For $i = 1 To $iCount
        Local $sName = ""
        If IsArray($aNames) And ($i - 1) < UBound($aNames) Then $sName = $aNames[$i - 1]
        If StringInStr($sName, $sNameFilter) > 0 Then ; flag 0 => case-insensitive
            $aOut[$iN] = $i
            $iN += 1
        EndIf
    Next
    If $iN < 1 Then Return SetError(1, 0, 0)
    ReDim $aOut[$iN]
    Return $aOut
EndFunc

; Name:        __SS_Reverse
; Description: Returns a reversed copy of a 1-D array.
Func __SS_Reverse($aIn)
    Local $iN = UBound($aIn)
    Local $aOut[$iN]
    Local $i
    For $i = 0 To $iN - 1
        $aOut[$i] = $aIn[$iN - 1 - $i]
    Next
    Return $aOut
EndFunc
