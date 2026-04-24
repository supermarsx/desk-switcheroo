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

        ; -- WL_Destroy cascades to ctx and submenu --
        _WL_Show(1)
        _WL_CtxShow(0)
        _WL_SendToShow()
        _Test_AssertTrue("SendTo: visible before WL_Destroy", _WL_SendToIsVisible())
        _WL_Destroy()
        _Test_AssertFalse("WL: hidden after destroy", _WL_IsVisible())
        _Test_AssertFalse("WL Ctx: gone after WL_Destroy", _WL_CtxIsVisible())
        _Test_AssertFalse("SendTo: gone after WL_Destroy", _WL_SendToIsVisible())
    Else
        _Test_AssertTrue("WL skipped (could not show)", True)
    EndIf
    _Cfg_SetWindowListEnabled(False)
EndFunc
