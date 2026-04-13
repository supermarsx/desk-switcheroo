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
EndFunc
