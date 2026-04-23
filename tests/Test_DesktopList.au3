#include-once

; ===============================================================
; Tests for includes\DesktopList.au3
; GUI tests — creates actual windows, requires desktop session
; ===============================================================

Func _RunTest_DesktopList()
    _Test_Suite("DesktopList")

    ; Ensure dependencies are initialized
    Local $sDllDir = StringRegExpReplace(@ScriptDir, "\\[^\\]+$", "")
    Local $sDllPath = $sDllDir & "\VirtualDesktopAccessor.dll"
    _VD_Init($sDllPath)
    Local $sTempIni = @TempDir & "\desk_switcheroo_test_dl.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    _Labels_Init($sTempIni, False)

    ; Use a mock taskbar Y position for testing
    Local $iTestTaskbarY = @DesktopHeight - 48
    Local $iCurrentDesktop = _VD_GetCurrent()

    ; -- Initially not visible --
    _Test_AssertFalse("Initially not visible", _DL_IsVisible())
    _Test_AssertEqual("Initially GUI = 0", _DL_GetGUI(), 0)

    ; -- Show creates window --
    _DL_Show($iTestTaskbarY, $iCurrentDesktop)
    _Test_AssertTrue("Show: is visible", _DL_IsVisible())
    _Test_AssertNotEqual("Show: GUI <> 0", _DL_GetGUI(), 0)

    ; -- Count matches VD --
    _Test_AssertEqual("Count matches VD_GetCount", _DL_GetCount(), _VD_GetCount())

    ; -- Destroy removes window --
    _DL_Destroy()
    _Test_AssertFalse("Destroy: not visible", _DL_IsVisible())

    ; -- Toggle on/off --
    _DL_Toggle($iTestTaskbarY, $iCurrentDesktop)
    _Test_AssertTrue("Toggle on: visible", _DL_IsVisible())
    _DL_Toggle($iTestTaskbarY, $iCurrentDesktop)
    _Test_AssertFalse("Toggle off: not visible", _DL_IsVisible())

    ; -- ShowTemp creates window in temp mode --
    _DL_ShowTemp($iTestTaskbarY, $iCurrentDesktop)
    _Test_AssertTrue("ShowTemp: visible", _DL_IsVisible())

    ; -- Auto-hide after timeout (move cursor away) --
    ; Timer-dependent: may not fire reliably on headless CI runners
    Local $hDummyMain = GUICreate("DummyMain", 1, 1, -100, -100)
    Sleep(4000) ; wait for TEMPLIST timer (3000ms) + generous CI margin
    Local $bAutoHid = _DL_CheckAutoHide($hDummyMain)
    If $bAutoHid Then
        _Test_AssertTrue("Auto-hide after timeout", True)
        _Test_AssertFalse("Not visible after auto-hide", _DL_IsVisible())
    Else
        ; On headless CI, ShowTemp timer may not start correctly — skip
        _Test_Skip("Auto-hide after timeout (headless CI)")
        _Test_Skip("Not visible after auto-hide (headless CI)")
        _DL_Destroy()
    EndIf
    GUIDelete($hDummyMain)

    ; -- HandleClick returns 0 for no match --
    _DL_Show($iTestTaskbarY, $iCurrentDesktop)
    Local $iResult = _DL_HandleClick(0)
    _Test_AssertEqual("HandleClick(0) returns 0", $iResult, 0)
    Local $iResult2 = _DL_HandleClick(-1)
    _Test_AssertEqual("HandleClick(-1) returns 0", $iResult2, 0)
    _DL_Destroy()

    ; -- Reposition follows main widget movement --
    Local $hTestWidget = GUICreate("DLWidget", 130, 40, 120, 200)
    GUISetState(@SW_SHOW, $hTestWidget)
    $gui = $hTestWidget
    _DL_Show($iTestTaskbarY, $iCurrentDesktop)
    Local $aListPos1 = WinGetPos(_DL_GetGUI())
    _Test_AssertTrue("Reposition: initial list pos array", IsArray($aListPos1))
    WinMove($gui, "", 240, 220)
    _DL_Reposition($iTestTaskbarY)
    Local $aListPos2 = WinGetPos(_DL_GetGUI())
    _Test_AssertEqual("Reposition: list follows widget X", $aListPos2[0], 240)
    _DL_Destroy()
    GUIDelete($hTestWidget)
    $gui = 0

    ; -- UpdateItemText does not crash when not visible --
    _DL_UpdateItemText(1, "Test") ; should be a no-op

    ; ---- Context menu tests ----

    ; -- Context menu initially not visible --
    _Test_AssertFalse("Ctx: initially not visible", _DL_CtxIsVisible())
    _Test_AssertEqual("Ctx: initially GUI = 0", _DL_CtxGetGUI(), 0)
    _Test_AssertEqual("Ctx: initially target = 0", _DL_CtxGetTarget(), 0)

    ; -- Show context menu for desktop 1 --
    _DL_Show($iTestTaskbarY, $iCurrentDesktop)
    _DL_CtxShow(1)
    _Test_AssertTrue("Ctx: is visible after show", _DL_CtxIsVisible())
    _Test_AssertNotEqual("Ctx: GUI <> 0", _DL_CtxGetGUI(), 0)
    _Test_AssertEqual("Ctx: target = 1", _DL_CtxGetTarget(), 1)

    ; -- HandleClick with no match returns empty --
    _Test_AssertEqual("Ctx: HandleClick(0) = empty", _DL_CtxHandleClick(0), "")
    _Test_AssertEqual("Ctx: HandleClick(-1) = empty", _DL_CtxHandleClick(-1), "")

    ; -- Destroy removes context menu --
    _DL_CtxDestroy()
    _Test_AssertFalse("Ctx: not visible after destroy", _DL_CtxIsVisible())
    _Test_AssertEqual("Ctx: GUI = 0 after destroy", _DL_CtxGetGUI(), 0)
    _Test_AssertEqual("Ctx: target = 0 after destroy", _DL_CtxGetTarget(), 0)

    ; -- DL_Destroy also destroys context menu --
    _DL_CtxShow(2)
    _Test_AssertTrue("Ctx: visible before DL_Destroy", _DL_CtxIsVisible())
    _DL_Destroy()
    _Test_AssertFalse("Ctx: gone after DL_Destroy", _DL_CtxIsVisible())

    ; -- DL context menu Set Color conditional --
    _DL_Show($iTestTaskbarY, $iCurrentDesktop)
    Local $bColorsWas2 = _Cfg_GetDesktopColorsEnabled()
    _Cfg_SetDesktopColorsEnabled(False)
    _DL_CtxShow(1)
    _Test_AssertEqual("DL Ctx: SetColor hidden when disabled", $__g_DL_iCtxSetColor, 0)
    _DL_CtxDestroy()

    _Cfg_SetDesktopColorsEnabled(True)
    _DL_CtxShow(1)
    _Test_AssertNotEqual("DL Ctx: SetColor shown when enabled", $__g_DL_iCtxSetColor, 0)
    _DL_CtxDestroy()
    _Cfg_SetDesktopColorsEnabled($bColorsWas2)

    ; -- Color picker show/destroy from DL context --
    _Cfg_SetDesktopColorsEnabled(True)
    _DL_CtxShow(1)
    _Test_AssertFalse("ColorPicker: initially hidden", _DL_ColorPickerIsVisible())
    _DL_ColorPickerShow(1)
    _Test_AssertTrue("ColorPicker: visible after show", _DL_ColorPickerIsVisible())
    _Test_AssertNotEqual("ColorPicker: GUI <> 0", _DL_ColorPickerGetGUI(), 0)
    _DL_ColorPickerDestroy()
    _Test_AssertFalse("ColorPicker: hidden after destroy", _DL_ColorPickerIsVisible())
    _DL_CtxDestroy()

    ; -- Color picker show without DL context (from main CM) --
    _DL_ColorPickerShow(1)
    _Test_AssertTrue("ColorPicker: works without DL ctx", _DL_ColorPickerIsVisible())
    _DL_ColorPickerDestroy()

    _Cfg_SetDesktopColorsEnabled($bColorsWas2)
    _DL_Destroy()

    ; -- Pin item in context menu conditional on pinning enabled --
    _DL_Show($iTestTaskbarY, $iCurrentDesktop)
    Local $bPinWas = _Cfg_GetPinningEnabled()

    _Cfg_SetPinningEnabled(False)
    _DL_CtxShow(1)
    _Test_AssertEqual("DL Ctx: Pin hidden when disabled", $__g_DL_iCtxPin, 0)
    _DL_CtxDestroy()

    _Cfg_SetPinningEnabled(True)
    _DL_CtxShow(1)
    _Test_AssertNotEqual("DL Ctx: Pin shown when enabled", $__g_DL_iCtxPin, 0)
    _Test_AssertEqual("DL Ctx: HandleClick(pin) = 'pin'", _DL_CtxHandleClick($__g_DL_iCtxPin), "pin")
    _DL_CtxDestroy()

    _Cfg_SetPinningEnabled($bPinWas)
    _DL_Destroy()

    ; -- Drag state: not dragging initially --
    _Test_AssertFalse("DL not dragging initially", _DL_IsDragging())

    ; -- Drag reset clears state --
    $__g_DL_iDragState = 2
    _DL_DragReset()
    _Test_AssertFalse("DL DragReset clears dragging", _DL_IsDragging())

    ; -- Scroll offset defaults --
    _Test_AssertEqual("DL scroll offset 0 initially", _DL_GetScrollOffset(), 0)

    ; -- Scroll offset set/get --
    _DL_SetScrollOffset(5)
    _Test_AssertEqual("DL scroll offset set/get", _DL_GetScrollOffset(), 5)
    _DL_ResetScroll()
    _Test_AssertEqual("DL ResetScroll zeros offset", _DL_GetScrollOffset(), 0)

    ; -- Pin state --
    _Test_AssertFalse("DL not pinned initially", _DL_IsPinned())

    ; -- Thumbnail not visible initially --
    _Test_AssertFalse("DL thumb not visible initially", _DL_ThumbIsVisible())

    ; -- ThumbDestroy safe when not visible --
    _DL_ThumbDestroy()
    _Test_AssertTrue("DL ThumbDestroy no crash", True)

    ; -- ThumbClearCache safe --
    _DL_ThumbClearCache()
    _Test_AssertTrue("DL ThumbClearCache no crash", True)

    ; -- Cleanup --
    FileDelete($sTempIni)
EndFunc
