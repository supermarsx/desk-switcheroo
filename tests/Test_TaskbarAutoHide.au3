#include-once

; ===============================================================
; Tests for includes\TaskbarAutoHide.au3
; Unit tests — state-based testing via global flags
; ===============================================================

Func _RunTest_TaskbarAutoHide()
    _Test_Suite("TaskbarAutoHide")

    ; -- Initial state defaults --
    _Test_AssertFalse("TAH auto-hide not active initially", _TAH_IsAutoHideEnabled())
    _Test_AssertFalse("TAH widget not hidden initially", _TAH_IsWidgetHidden())

    ; -- CheckHidden returns False when no event pending --
    _Test_AssertFalse("TAH CheckHidden = False initially", _TAH_CheckHidden())

    ; -- CheckShown returns False when no event pending --
    _Test_AssertFalse("TAH CheckShown = False initially", _TAH_CheckShown())

    ; -- CheckHidden one-shot behavior --
    $__g_TAH_bHiddenPending = True
    _Test_AssertTrue("TAH CheckHidden first call = True", _TAH_CheckHidden())
    _Test_AssertFalse("TAH CheckHidden second call = False", _TAH_CheckHidden())

    ; -- CheckShown one-shot behavior --
    $__g_TAH_bShownPending = True
    _Test_AssertTrue("TAH CheckShown first call = True", _TAH_CheckShown())
    _Test_AssertFalse("TAH CheckShown second call = False", _TAH_CheckShown())

    ; -- Start is no-op when sync disabled --
    _Cfg_SetAutoHideSyncEnabled(False)
    _TAH_Start()
    ; No crash = success
    _Test_AssertTrue("TAH Start no-op when disabled", True)

    ; -- Stop resets all pending and timer flags --
    $__g_TAH_bHideTimerActive = True
    $__g_TAH_bShowTimerActive = True
    $__g_TAH_bHiddenPending = True
    $__g_TAH_bShownPending = True
    _TAH_Stop()
    _Test_AssertFalse("TAH Stop: hide timer cleared", $__g_TAH_bHideTimerActive)
    _Test_AssertFalse("TAH Stop: show timer cleared", $__g_TAH_bShowTimerActive)
    _Test_AssertFalse("TAH Stop: hidden pending cleared", $__g_TAH_bHiddenPending)
    _Test_AssertFalse("TAH Stop: shown pending cleared", $__g_TAH_bShownPending)

    ; -- Reset when auto-hide off but widget hidden → sets ShownPending --
    $__g_TAH_bAutoHideActive = False
    $__g_TAH_bWidgetHiddenByTAH = True
    _Cfg_SetAutoHideSyncEnabled(True)
    _TAH_Reset()
    _Test_AssertTrue("TAH Reset: ShownPending when widget hidden", _TAH_CheckShown())
    $__g_TAH_bWidgetHiddenByTAH = False
    _Cfg_SetAutoHideSyncEnabled(False)
    _TAH_Stop()

    ; -- HideWidget skip when already hidden --
    $__g_TAH_bWidgetHiddenByTAH = True
    _TAH_HideWidget(0)
    _Test_AssertTrue("TAH HideWidget no crash when already hidden", True)
    $__g_TAH_bWidgetHiddenByTAH = False

    ; -- ShowWidget skip when not hidden by TAH --
    $__g_TAH_bWidgetHiddenByTAH = False
    _TAH_ShowWidget(0, 235)
    _Test_AssertTrue("TAH ShowWidget no crash when not hidden", True)

    ; -- Config defaults --
    _Test_AssertFalse("TAH default sync disabled", _Cfg_GetAutoHideSyncEnabled())
    _Test_AssertTrue("TAH poll interval > 0", _Cfg_GetAutoHidePollInterval() > 0)
    _Test_AssertTrue("TAH hide delay >= 0", _Cfg_GetAutoHideHideDelay() >= 0)
    _Test_AssertTrue("TAH show delay >= 0", _Cfg_GetAutoHideShowDelay() >= 0)

    ; -- Stopping guard flag --
    _Test_AssertTrue("TAH stopping flag set after Stop", $__g_TAH_bStopping)

    ; -- Stop resets hysteresis + fade state --
    $__g_TAH_iHysteresisCount = 5
    $__g_TAH_iFadeState = 2
    _TAH_Stop()
    _Test_AssertEqual("TAH Stop resets hysteresis count", $__g_TAH_iHysteresisCount, 0)
    _Test_AssertEqual("TAH Stop resets fade state", $__g_TAH_iFadeState, 0)

    ; ===========================================================
    ; Pure decision function: __TAH_RawTaskbarHidden
    ; Args: TBX, TBY, TBW, TBH, ScrW, ScrH, threshold
    ; ===========================================================
    ; Bottom taskbar (horizontal), 1920x1080, 40px tall, threshold 4
    _Test_AssertFalse("Raw: bottom visible", __TAH_RawTaskbarHidden(0, 1040, 1920, 40, 1920, 1080, 4))
    _Test_AssertTrue("Raw: bottom hidden (2px sliver)", __TAH_RawTaskbarHidden(0, 1078, 1920, 40, 1920, 1080, 4))
    ; Top taskbar
    _Test_AssertFalse("Raw: top visible", __TAH_RawTaskbarHidden(0, 0, 1920, 40, 1920, 1080, 4))
    _Test_AssertTrue("Raw: top hidden", __TAH_RawTaskbarHidden(0, -38, 1920, 40, 1920, 1080, 4))
    ; Vertical right taskbar (TBW < TBH)
    _Test_AssertFalse("Raw: right visible", __TAH_RawTaskbarHidden(1880, 0, 40, 1080, 1920, 1080, 4))
    _Test_AssertTrue("Raw: right hidden", __TAH_RawTaskbarHidden(1918, 0, 40, 1080, 1920, 1080, 4))
    ; Vertical left taskbar
    _Test_AssertFalse("Raw: left visible", __TAH_RawTaskbarHidden(0, 0, 40, 1080, 1920, 1080, 4))
    _Test_AssertTrue("Raw: left hidden", __TAH_RawTaskbarHidden(-38, 0, 40, 1080, 1920, 1080, 4))
    ; Threshold boundary: exactly at threshold counts as hidden (<=)
    _Test_AssertTrue("Raw: sliver == threshold is hidden", __TAH_RawTaskbarHidden(0, 1076, 1920, 40, 1920, 1080, 4))
    _Test_AssertFalse("Raw: sliver > threshold is visible", __TAH_RawTaskbarHidden(0, 1075, 1920, 40, 1920, 1080, 4))

    ; ===========================================================
    ; Pure hysteresis: __TAH_HysteresisNext (ByRef count)
    ; ===========================================================
    Local $iHyst = 0
    ; Agreement never flips and resets the streak
    _Test_AssertFalse("Hyst: agree keeps False", __TAH_HysteresisNext(False, False, $iHyst, 2))
    _Test_AssertEqual("Hyst: agree count 0", $iHyst, 0)
    ; First disagreement does not flip (threshold 2)
    _Test_AssertFalse("Hyst: 1st disagree no flip", __TAH_HysteresisNext(True, False, $iHyst, 2))
    _Test_AssertEqual("Hyst: count 1 after 1st", $iHyst, 1)
    ; Second consecutive disagreement flips and resets count
    _Test_AssertTrue("Hyst: 2nd disagree flips", __TAH_HysteresisNext(True, False, $iHyst, 2))
    _Test_AssertEqual("Hyst: count reset after flip", $iHyst, 0)
    ; An intervening agreement resets a partial streak (no strobe)
    $iHyst = 0
    __TAH_HysteresisNext(True, False, $iHyst, 3) ; count 1
    __TAH_HysteresisNext(True, False, $iHyst, 3) ; count 2
    _Test_AssertEqual("Hyst: streak at 2 of 3", $iHyst, 2)
    _Test_AssertFalse("Hyst: agreement returns committed", __TAH_HysteresisNext(False, False, $iHyst, 3))
    _Test_AssertEqual("Hyst: agreement resets streak", $iHyst, 0)
    ; Threshold of 1 flips immediately
    $iHyst = 0
    _Test_AssertTrue("Hyst: threshold 1 flips immediately", __TAH_HysteresisNext(True, False, $iHyst, 1))

    ; ===========================================================
    ; Fade state machine + guards
    ; ===========================================================
    $__g_TAH_iFadeState = 0
    $__g_TAH_hLastToggleTimer = 0
    _Test_AssertFalse("TAH not fading initially", _TAH_IsFading())
    _Test_AssertGreaterEqual("FadeStepSize >= 1", __TAH_FadeStepSize(235), 1)

    ; Cursor-over-widget setter feeds the poll guard
    _TAH_SetCursorOverWidget(True)
    _Test_AssertTrue("TAH cursor-over-widget True", $__g_TAH_bCursorOverWidget)
    _TAH_SetCursorOverWidget(False)
    _Test_AssertFalse("TAH cursor-over-widget False", $__g_TAH_bCursorOverWidget)

    ; Anti-strobe / mid-fade snap decision
    $__g_TAH_iFadeState = 0
    $__g_TAH_hLastToggleTimer = 0
    _Test_AssertFalse("SkipFade: idle no recent toggle", __TAH_ShouldSkipFade())
    $__g_TAH_iFadeState = 1
    _Test_AssertTrue("SkipFade: mid-fade snaps", __TAH_ShouldSkipFade())
    $__g_TAH_iFadeState = 0
    $__g_TAH_hLastToggleTimer = TimerInit()
    _Test_AssertTrue("SkipFade: recent toggle snaps", __TAH_ShouldSkipFade())
    $__g_TAH_hLastToggleTimer = 0

    ; FadeTick is a safe no-op when idle
    $__g_TAH_iFadeState = 0
    _TAH_FadeTick()
    _Test_AssertTrue("TAH FadeTick no-op when idle", True)
    ; FadeTick with an invalid handle mid-fade resets state (no crash)
    $__g_TAH_iFadeState = 1
    $__g_TAH_hFadeGUI = 0
    _TAH_FadeTick()
    _Test_AssertEqual("TAH FadeTick clears state on bad handle", $__g_TAH_iFadeState, 0)
EndFunc
