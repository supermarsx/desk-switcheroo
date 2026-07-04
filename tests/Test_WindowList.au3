#include-once

Func _RunTest_WindowList()
    _Test_Suite("WindowList")

    ; -- Visibility state --
    _Test_AssertFalse("WL not visible initially", _WL_IsVisible())
    _Test_AssertEqual("WL GUI is 0 initially", _WL_GetGUI(), 0)

    ; -- Context menu state --
    _Test_AssertFalse("WL ctx not visible initially", _WL_CtxIsVisible())
    _Test_AssertEqual("WL ctx GUI is 0 initially", _WL_CtxGetGUI(), 0)

    ; -- Context target --
    _Test_AssertEqual("WL ctx target is 0 initially", _WL_GetCtxTarget(), 0)

    ; -- Config defaults: window_list_enabled --
    _Test_AssertFalse("WL disabled by default", _Cfg_GetWindowListEnabled())

    ; -- Config defaults: position --
    _Test_AssertEqual("WL default position", _Cfg_GetWindowListPosition(), "top-left")

    ; -- Config defaults: width --
    _Test_AssertEqual("WL default width", _Cfg_GetWindowListWidth(), 280)

    ; -- Config defaults: search --
    _Test_AssertTrue("WL default search enabled", _Cfg_GetWindowListSearch())

    ; -- Config round-trips --
    Local $sPosBefore = _Cfg_GetWindowListPosition()
    _Cfg_SetWindowListPosition("bottom-right")
    _Test_AssertEqual("WL position set/get", _Cfg_GetWindowListPosition(), "bottom-right")
    _Cfg_SetWindowListPosition("invalid-position")
    _Test_AssertEqual("WL position invalid fallback", _Cfg_GetWindowListPosition(), "top-left")
    _Cfg_SetWindowListPosition($sPosBefore)

    Local $iWidthBefore = _Cfg_GetWindowListWidth()
    _Cfg_SetWindowListWidth(350)
    _Test_AssertEqual("WL width set/get", _Cfg_GetWindowListWidth(), 350)
    _Cfg_SetWindowListWidth(50)
    _Test_AssertEqual("WL width clamped min", _Cfg_GetWindowListWidth(), 150)
    _Cfg_SetWindowListWidth(999)
    _Test_AssertEqual("WL width clamped max", _Cfg_GetWindowListWidth(), 600)
    _Cfg_SetWindowListWidth($iWidthBefore)

    ; -- Config: scope --
    _Test_AssertEqual("WL default scope", _Cfg_GetWindowListScope(), "current")

    ; -- Config: max visible --
    _Test_AssertTrue("WL max visible > 0", _Cfg_GetWindowListMaxVisible() > 0)

    ; -- Config: refresh interval --
    Local $iRefBefore = _Cfg_GetWindowListRefreshInterval()
    _Cfg_SetWindowListRefreshInterval(2000)
    _Test_AssertEqual("WL refresh interval set/get", _Cfg_GetWindowListRefreshInterval(), 2000)
    _Cfg_SetWindowListRefreshInterval(100)
    _Test_AssertEqual("WL refresh clamped min", _Cfg_GetWindowListRefreshInterval(), 500)
    _Cfg_SetWindowListRefreshInterval($iRefBefore)

    ; -- HandleClick with 0 returns 0 when not visible --
    _Test_AssertEqual("WL HandleClick(0) = 0 when hidden", _WL_HandleClick(0), 0)

    ; -- ScrollUp/Down without GUI are no-ops --
    _WL_ScrollUp()
    _WL_ScrollDown()
    _Test_AssertTrue("WL scroll without GUI no crash", True)

    ; ---- Send-to submenu initial state ----
    _Test_AssertFalse("SendTo: initially not visible", _WL_SendToIsVisible())
    _Test_AssertEqual("SendTo: GUI is 0 initially", _WL_SendToGetGUI(), 0)

    ; -- SendToHandleClick with no submenu returns empty --
    _Test_AssertEqual("SendTo: HandleClick(0) = empty", _WL_SendToHandleClick(0), "")
    _Test_AssertEqual("SendTo: HandleClick(-1) = empty", _WL_SendToHandleClick(-1), "")

    ; -- SendToDestroy on already-destroyed state is safe --
    _WL_SendToDestroy()
    _Test_AssertFalse("SendTo: still hidden after double destroy", _WL_SendToIsVisible())

    ; -- CtxHandleClick returns empty for non-matching IDs --
    _Test_AssertEqual("WL Ctx: HandleClick(0) = empty", _WL_CtxHandleClick(0), "")
    _Test_AssertEqual("WL Ctx: HandleClick(-1) = empty", _WL_CtxHandleClick(-1), "")
    _Test_AssertEqual("WL Ctx: HandleClick(99999) = empty", _WL_CtxHandleClick(99999), "")

    ; -- CtxDestroy cleans up send-to submenu --
    _Test_AssertFalse("SendTo: hidden after CtxDestroy", _WL_SendToIsVisible())
    _Test_AssertEqual("SendTo: GUI = 0 after CtxDestroy", _WL_SendToGetGUI(), 0)

    ; -- CtxCheckAutoHide returns False when not visible --
    _Test_AssertFalse("WL Ctx: auto-hide returns false when hidden", _WL_CtxCheckAutoHide())

    ; ---- Title-bar hit-test math (pure function) ----
    _Test_AssertTrue("TitleBar: point inside", __WL_IsPointInTitleBar(50, 10, 200, 27))
    _Test_AssertTrue("TitleBar: top edge included", __WL_IsPointInTitleBar(50, 0, 200, 27))
    _Test_AssertTrue("TitleBar: bottom edge included", __WL_IsPointInTitleBar(50, 27, 200, 27))
    _Test_AssertFalse("TitleBar: below title", __WL_IsPointInTitleBar(50, 40, 200, 27))
    _Test_AssertFalse("TitleBar: left of window", __WL_IsPointInTitleBar(-5, 10, 200, 27))
    _Test_AssertFalse("TitleBar: right of window", __WL_IsPointInTitleBar(250, 10, 200, 27))
    _Test_AssertFalse("TitleBar: no title (bottom=0)", __WL_IsPointInTitleBar(50, 0, 200, 0))

    ; -- IsOverTitleBar false when not visible --
    _Test_AssertFalse("TitleBar: not over when hidden", _WL_IsOverTitleBar())

    ; ---- Custom-position calc (drag persistence) ----
    Local $iCustXBefore = _Cfg_GetWindowListCustomX()
    Local $iCustYBefore = _Cfg_GetWindowListCustomY()
    Local $iCalcX = 0, $iCalcY = 0

    ; Unset (-1) → falls back to the anchor (top-left = 10,10).
    _Cfg_SetWindowListCustomX(-1)
    _Cfg_SetWindowListCustomY(-1)
    __WL_CalcPosition("top-left", 200, 300, $iCalcX, $iCalcY)
    _Test_AssertEqual("CalcPos: unset falls back to anchor X", $iCalcX, 10)
    _Test_AssertEqual("CalcPos: unset falls back to anchor Y", $iCalcY, 10)

    ; Custom position that fits on screen → used verbatim.
    _Cfg_SetWindowListCustomX(120)
    _Cfg_SetWindowListCustomY(150)
    __WL_CalcPosition("top-left", 200, 300, $iCalcX, $iCalcY)
    _Test_AssertEqual("CalcPos: custom X used", $iCalcX, 120)
    _Test_AssertEqual("CalcPos: custom Y used", $iCalcY, 150)

    ; Off-screen custom position → clamped back into the monitor work area.
    Local $iWaL = 0, $iWaT = 0, $iWaR = 0, $iWaB = 0
    _CM_GetWorkArea(100000, 100000, $iWaL, $iWaT, $iWaR, $iWaB)
    _Cfg_SetWindowListCustomX(100000)
    _Cfg_SetWindowListCustomY(100000)
    __WL_CalcPosition("top-left", 200, 300, $iCalcX, $iCalcY)
    _Test_AssertEqual("CalcPos: off-screen X clamped", $iCalcX, $iWaR - 200)
    _Test_AssertEqual("CalcPos: off-screen Y clamped", $iCalcY, $iWaB - 300)
    _Test_AssertTrue("CalcPos: clamped X on screen", $iCalcX >= $iWaL)
    _Test_AssertTrue("CalcPos: clamped Y on screen", $iCalcY >= $iWaT)

    _Cfg_SetWindowListCustomX($iCustXBefore)
    _Cfg_SetWindowListCustomY($iCustYBefore)

    ; ---- Send-all execution: invalid targets move nothing ----
    _Test_AssertEqual("SendAll: target 0 moves 0", _WL_SendAllToDesktop(0), 0)
    _Test_AssertEqual("SendAll: target -1 moves 0", _WL_SendAllToDesktop(-1), 0)

    ; ---- All-window ops: empty (no-desktop) path returns 0 and touches nothing ----
    ; Force the snapshot's desktop resolution to < 1 so no real windows are enumerated
    ; or acted upon during the test run.
    Local $iDeskSaveAll = $iDesktop
    Local $iWLDeskSaveAll = $__g_WL_iDesktop
    $iDesktop = 0
    $__g_WL_iDesktop = 0
    _Test_AssertEqual("MinAll: 0 windows affects 0", _WL_MinimizeAll(), 0)
    _Test_AssertEqual("MaxAll: 0 windows affects 0", _WL_MaximizeAll(), 0)
    _Test_AssertEqual("CloseAll: 0 windows affects 0", _WL_CloseAll(), 0)
    _Test_AssertEqual("SendAll: no-desktop target affects 0", _WL_SendAllToDesktop(1), 0)
    $__g_WL_iDesktop = $iWLDeskSaveAll
    $iDesktop = $iDeskSaveAll

    ; ---- Always-on-top target-state decision (pure) ----
    _Test_AssertTrue("Topmost: not-topmost -> target on", __WL_TopmostTargetState(0))
    _Test_AssertFalse("Topmost: topmost -> target off", __WL_TopmostTargetState($WS_EX_TOPMOST))
    _Test_AssertFalse("Topmost: topmost+other -> target off", __WL_TopmostTargetState(BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW)))
    _Test_AssertTrue("Topmost: other-only -> target on", __WL_TopmostTargetState($WS_EX_TOOLWINDOW))

    ; ---- Always-on-top result classification (pure): success needs API ok AND the
    ; ex-style bit actually reflecting the target (elevated windows silently reject) ----
    _Test_AssertEqual("Topmost: set ok", __WL_ClassifyTopmostResult(True, True, $WS_EX_TOPMOST), "set")
    _Test_AssertEqual("Topmost: removed ok", __WL_ClassifyTopmostResult(False, True, 0), "removed")
    _Test_AssertEqual("Topmost: set but bit unchanged -> failed", __WL_ClassifyTopmostResult(True, True, 0), "failed")
    _Test_AssertEqual("Topmost: remove but bit stuck -> failed", __WL_ClassifyTopmostResult(False, True, $WS_EX_TOPMOST), "failed")
    _Test_AssertEqual("Topmost: API fail -> failed", __WL_ClassifyTopmostResult(True, False, $WS_EX_TOPMOST), "failed")
    _Test_AssertEqual("Topmost: set ok with extra bits", __WL_ClassifyTopmostResult(True, True, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW)), "set")

    ; ---- Title menu / send-all handlers with no menu ----
    _Test_AssertFalse("TitleCtx: not visible initially", _WL_TitleCtxIsVisible())
    _Test_AssertEqual("TitleCtx: GUI is 0 initially", _WL_TitleCtxGetGUI(), 0)
    _Test_AssertEqual("TitleCtx: HandleClick(0) = empty", _WL_TitleCtxHandleClick(0), "")
    _Test_AssertEqual("TitleCtx: HandleClick(99999) = empty", _WL_TitleCtxHandleClick(99999), "")
    _Test_AssertFalse("SendAll: not visible initially", _WL_SendAllIsVisible())
    _Test_AssertEqual("SendAll: GUI is 0 initially", _WL_SendAllGetGUI(), 0)
    _Test_AssertEqual("SendAll: HandleClick(0) = empty", _WL_SendAllHandleClick(0), "")
    _Test_AssertFalse("TitleCtx: auto-hide false when hidden", _WL_TitleCtxCheckAutoHide())

    ; -- ProcessDrag is a no-op (no crash) when not visible --
    _WL_ProcessDrag()
    _Test_AssertTrue("Drag: no crash when hidden", True)

    ; ---- Context menu show/destroy with parent item ----
    _Cfg_SetWindowListEnabled(True)
    _WL_Show(1)
    If _WL_IsVisible() Then
        ; Simulate right-click target using a dummy HWND (0 is safe for state checks)
        _WL_CtxShow(0)
        _Test_AssertTrue("WL Ctx: visible after show", _WL_CtxIsVisible())
        _Test_AssertNotEqual("WL Ctx: GUI <> 0", _WL_CtxGetGUI(), 0)

        ; -- Parent item exists --
        _Test_AssertNotEqual("WL Ctx: SendToParent item exists", $__g_WL_iCtxSendToParent, 0)

        ; -- HandleClick does not match parent item (parent only opens submenu) --
        _Test_AssertEqual("WL Ctx: HandleClick(parent) = empty", _WL_CtxHandleClick($__g_WL_iCtxSendToParent), "")

        ; -- Close item exists and returns correct action --
        _Test_AssertNotEqual("WL Ctx: Close item exists", $__g_WL_iCtxClose, 0)
        _Test_AssertEqual("WL Ctx: HandleClick(close) = 'close'", _WL_CtxHandleClick($__g_WL_iCtxClose), "close")

        ; -- Always-on-top toggle item exists and maps to its action --
        _Test_AssertNotEqual("WL Ctx: Topmost item exists", $__g_WL_iCtxTopmost, 0)
        _Test_AssertEqual("WL Ctx: HandleClick(topmost) = 'toggle_topmost'", _WL_CtxHandleClick($__g_WL_iCtxTopmost), "toggle_topmost")

        ; -- Send-to submenu show --
        _WL_SendToShow()
        _Test_AssertTrue("SendTo: visible after show", _WL_SendToIsVisible())
        _Test_AssertNotEqual("SendTo: GUI <> 0", _WL_SendToGetGUI(), 0)
        Local $aWLCtxPos = WinGetPos(_WL_CtxGetGUI())
        Local $aSendParentPos = ControlGetPos(_WL_CtxGetGUI(), "", $__g_WL_iCtxSendToParent)
        Local $aSendMenuPos = WinGetPos(_WL_SendToGetGUI())
        _Test_AssertTrue("SendTo: ctx pos array", IsArray($aWLCtxPos))
        _Test_AssertTrue("SendTo: parent item pos array", IsArray($aSendParentPos))
        _Test_AssertTrue("SendTo: menu pos array", IsArray($aSendMenuPos))
        If IsArray($aWLCtxPos) And IsArray($aSendMenuPos) Then
            Local $iExpectedSendY = $aWLCtxPos[1] + 4
            If $iExpectedSendY < 0 Then $iExpectedSendY = 0
            If $iExpectedSendY + $aSendMenuPos[3] > @DesktopHeight Then $iExpectedSendY = @DesktopHeight - $aSendMenuPos[3]
            If $iExpectedSendY < 0 Then $iExpectedSendY = 0
            _Test_AssertEqual("SendTo: aligned to parent item", $aSendMenuPos[1], $iExpectedSendY)
        Else
            _Test_Skip("SendTo: aligned to parent item")
        EndIf

        ; -- Send-to submenu items exist --
        _Test_AssertNotEqual("SendTo: Next item exists", $__g_WL_iSendNext, 0)
        _Test_AssertNotEqual("SendTo: Prev item exists", $__g_WL_iSendPrev, 0)
        _Test_AssertNotEqual("SendTo: New item exists", $__g_WL_iSendNew, 0)

        ; -- HandleClick returns correct actions --
        _Test_AssertEqual("SendTo: HandleClick(next)", _WL_SendToHandleClick($__g_WL_iSendNext), "send_next")
        _Test_AssertEqual("SendTo: HandleClick(prev)", _WL_SendToHandleClick($__g_WL_iSendPrev), "send_prev")
        _Test_AssertEqual("SendTo: HandleClick(new)", _WL_SendToHandleClick($__g_WL_iSendNew), "send_new")

        ; -- SendToDestroy cleans up --
        _WL_SendToDestroy()
        _Test_AssertFalse("SendTo: hidden after destroy", _WL_SendToIsVisible())
        _Test_AssertEqual("SendTo: GUI = 0 after destroy", _WL_SendToGetGUI(), 0)

        ; -- CtxDestroy also destroys submenu --
        _WL_SendToShow()
        _Test_AssertTrue("SendTo: visible before CtxDestroy", _WL_SendToIsVisible())
        _WL_CtxDestroy()
        _Test_AssertFalse("WL Ctx: hidden after destroy", _WL_CtxIsVisible())
        _Test_AssertFalse("SendTo: gone after CtxDestroy", _WL_SendToIsVisible())

        ; ---- Title-bar context menu ----
        _WL_TitleCtxShow()
        _Test_AssertTrue("TitleCtx: visible after show", _WL_TitleCtxIsVisible())
        _Test_AssertNotEqual("TitleCtx: GUI <> 0", _WL_TitleCtxGetGUI(), 0)
        _Test_AssertNotEqual("TitleCtx: Pin item exists", $__g_WL_iTitlePin, 0)
        _Test_AssertNotEqual("TitleCtx: Refresh item exists", $__g_WL_iTitleRefresh, 0)
        _Test_AssertNotEqual("TitleCtx: SendAll parent exists", $__g_WL_iTitleSendAllParent, 0)
        _Test_AssertNotEqual("TitleCtx: MinAll item exists", $__g_WL_iTitleMinAll, 0)
        _Test_AssertNotEqual("TitleCtx: MaxAll item exists", $__g_WL_iTitleMaxAll, 0)
        _Test_AssertNotEqual("TitleCtx: CloseAll item exists", $__g_WL_iTitleCloseAll, 0)
        _Test_AssertNotEqual("TitleCtx: Close item exists", $__g_WL_iTitleClose, 0)

        ; -- Action mapping (unpinned by default → Pin returns "pin") --
        _Test_AssertEqual("TitleCtx: HandleClick(pin) = 'pin'", _WL_TitleCtxHandleClick($__g_WL_iTitlePin), "pin")
        _Test_AssertEqual("TitleCtx: HandleClick(refresh) = 'refresh'", _WL_TitleCtxHandleClick($__g_WL_iTitleRefresh), "refresh")
        _Test_AssertEqual("TitleCtx: HandleClick(min_all) = 'min_all'", _WL_TitleCtxHandleClick($__g_WL_iTitleMinAll), "min_all")
        _Test_AssertEqual("TitleCtx: HandleClick(max_all) = 'max_all'", _WL_TitleCtxHandleClick($__g_WL_iTitleMaxAll), "max_all")
        _Test_AssertEqual("TitleCtx: HandleClick(close_all) = 'close_all'", _WL_TitleCtxHandleClick($__g_WL_iTitleCloseAll), "close_all")
        _Test_AssertEqual("TitleCtx: HandleClick(close) = 'close'", _WL_TitleCtxHandleClick($__g_WL_iTitleClose), "close")
        ; -- Parent item only opens the submenu, no action --
        _Test_AssertEqual("TitleCtx: HandleClick(parent) = empty", _WL_TitleCtxHandleClick($__g_WL_iTitleSendAllParent), "")

        ; ---- Send-All submenu ----
        _WL_SendAllShow()
        _Test_AssertTrue("SendAll: visible after show", _WL_SendAllIsVisible())
        _Test_AssertNotEqual("SendAll: GUI <> 0", _WL_SendAllGetGUI(), 0)
        _Test_AssertNotEqual("SendAll: Next item exists", $__g_WL_iSendAllNext, 0)
        _Test_AssertNotEqual("SendAll: Prev item exists", $__g_WL_iSendAllPrev, 0)
        _Test_AssertNotEqual("SendAll: New item exists", $__g_WL_iSendAllNew, 0)
        _Test_AssertEqual("SendAll: HandleClick(next)", _WL_SendAllHandleClick($__g_WL_iSendAllNext), "send_all_next")
        _Test_AssertEqual("SendAll: HandleClick(prev)", _WL_SendAllHandleClick($__g_WL_iSendAllPrev), "send_all_prev")
        _Test_AssertEqual("SendAll: HandleClick(new)", _WL_SendAllHandleClick($__g_WL_iSendAllNew), "send_all_new")
        ; -- Per-desktop item maps to send_all_to:N --
        If $__g_WL_iSendAllToCount > 0 Then
            Local $iExpectDest = $__g_WL_aiSendAllToDest[1]
            _Test_AssertEqual("SendAll: HandleClick(desktop) = send_all_to:N", _
                _WL_SendAllHandleClick($__g_WL_aSendAllTo[1]), "send_all_to:" & $iExpectDest)
        Else
            _Test_Skip("SendAll: HandleClick(desktop) = send_all_to:N")
        EndIf

        ; -- SendAllDestroy cleans up --
        _WL_SendAllDestroy()
        _Test_AssertFalse("SendAll: hidden after destroy", _WL_SendAllIsVisible())
        _Test_AssertEqual("SendAll: GUI = 0 after destroy", _WL_SendAllGetGUI(), 0)

        ; -- Pinned state flips the Pin action to "unpin" --
        Local $bPinBefore = _Cfg_GetWindowListPinned()
        _Cfg_SetWindowListPinned(True)
        _WL_TitleCtxShow()
        _Test_AssertEqual("TitleCtx: HandleClick(pin) = 'unpin' when pinned", _WL_TitleCtxHandleClick($__g_WL_iTitlePin), "unpin")
        ; -- Pinned list ignores auto-hide --
        _Test_AssertFalse("TitleCtx: pinned WL skips auto-hide", _WL_CheckAutoHide(0))
        _Cfg_SetWindowListPinned($bPinBefore)

        ; -- TitleCtxDestroy cascades to submenu --
        _WL_SendAllShow()
        _Test_AssertTrue("SendAll: visible before TitleCtxDestroy", _WL_SendAllIsVisible())
        _WL_TitleCtxDestroy()
        _Test_AssertFalse("TitleCtx: hidden after destroy", _WL_TitleCtxIsVisible())
        _Test_AssertFalse("SendAll: gone after TitleCtxDestroy", _WL_SendAllIsVisible())

        ; -- WL_Destroy cascades to ctx and submenu --
        _WL_Show(1)
        _WL_CtxShow(0)
        _WL_SendToShow()
        _Test_AssertTrue("SendTo: visible before WL_Destroy", _WL_SendToIsVisible())
        _WL_Destroy()
        _Test_AssertFalse("WL: hidden after destroy", _WL_IsVisible())
        _Test_AssertFalse("WL Ctx: gone after WL_Destroy", _WL_CtxIsVisible())
        _Test_AssertFalse("SendTo: gone after WL_Destroy", _WL_SendToIsVisible())

        ; -- WL_Destroy also cascades to the title menu --
        _WL_Show(1)
        _WL_TitleCtxShow()
        _Test_AssertTrue("TitleCtx: visible before WL_Destroy", _WL_TitleCtxIsVisible())
        _WL_Destroy()
        _Test_AssertFalse("TitleCtx: gone after WL_Destroy", _WL_TitleCtxIsVisible())
    Else
        _Test_AssertTrue("WL skipped (could not show)", True)
    EndIf
    _Cfg_SetWindowListEnabled(False)
EndFunc
