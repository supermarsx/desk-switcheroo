#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPISysWin.au3>
#include <StaticConstants.au3>

#include "includes\Config.au3"
#include "includes\Logger.au3"
#include "includes\Theme.au3"
#include "includes\Labels.au3"
#include "includes\VirtualDesktop.au3"
#include "includes\Peek.au3"
#include "includes\ContextMenu.au3"
#include "includes\RenameDialog.au3"
#include "includes\DesktopList.au3"
#include "includes\ConfigDialog.au3"

; ---- Ensure cleanup on unexpected exit ----
Global $__g_bShuttingDown = False
OnAutoItExitRegister("_OnExit")

; ---- Singleton: kill previous instance on relaunch ----
Local $sMutexName = "DesktopSwitcherMutex_7F3A"
Local $hMutex = DllCall("kernel32.dll", "handle", "CreateMutexW", "ptr", 0, "bool", True, "wstr", $sMutexName)
Local $aLastErr = DllCall("kernel32.dll", "dword", "GetLastError")
If Not @error And IsArray($aLastErr) And $aLastErr[0] = 183 Then
    Local $aProcs = ProcessList(@AutoItExe)
    For $p = 1 To $aProcs[0][0]
        If $aProcs[$p][1] <> @AutoItPID Then
            ProcessClose($aProcs[$p][1])
        EndIf
    Next
    Sleep(200)
EndIf

; ---- Load bundled fonts ----
_Theme_LoadFonts()

; ---- Initialize config ----
_Cfg_Init()

; ---- Tray icon visibility ----
If Not _Cfg_GetTrayIconMode() Then Opt("TrayIconHide", 1)

; ---- Initialize logging ----
_Log_Init()

; ---- Startup checks ----
_RunStartupChecks()

; ---- Log font status ----
If $__g_Theme_bFiraLoaded Then
    _Log_Info("Fira Code font loaded successfully")
Else
    _Log_Warn("Fira Code font not available, falling back to " & $THEME_FONT_MONO_FB)
EndIf

; ---- Parse command-line arguments ----
Global $bAutoStart = False
If $CmdLine[0] >= 1 Then
    For $c = 1 To $CmdLine[0]
        If $CmdLine[$c] = "-autostart" Then $bAutoStart = True
    Next
EndIf

; ---- Initialize modules ----
If Not _VD_Init() Then
    Local $sDllPath = @ScriptDir & "\VirtualDesktopAccessor.dll"
    Local $sDllExists = FileExists($sDllPath) ? "Yes" : "No"
    Local $sDllSize = FileExists($sDllPath) ? String(FileGetSize($sDllPath)) & " bytes" : "N/A"
    Local $sErrDetail = "Failed to load VirtualDesktopAccessor.dll." & @CRLF & @CRLF & _
        "Path: " & $sDllPath & @CRLF & _
        "File exists: " & $sDllExists & @CRLF & _
        "File size: " & $sDllSize & @CRLF & @CRLF & _
        "Make sure the DLL is in the same folder as this script."
    _Log_Error("VirtualDesktopAccessor.dll init failed - path=" & $sDllPath & " exists=" & $sDllExists & " size=" & $sDllSize)
    MsgBox(16, "Desk Switcheroo", $sErrDetail)
    Exit 1
EndIf
_Labels_Init()
_RD_Init()

; ---- Globals ----
Global $iDesktop = _VD_GetCurrent()
Global $gui, $lblNum, $lblName, $lblLeft, $lblRight
Global $iTaskbarH, $iTaskbarY
Global $bHoverLeft = False, $bHoverRight = False
Global $iRenameTarget = 0
Global $bDesktopChanged = False
Global $bNamesChanged = False
Global $__g_iLastCursorX = -1, $__g_iLastCursorY = -1
Global Const $WM_VD_NOTIFY = 0x04C8 ; WM_USER + 200

; -- Triple-click to edit --
Global $__g_iClickCount = 0
Global $__g_hClickTimer = 0

; -- Widget drag --
Global $__g_bWidgetDragging = False
Global $__g_iWidgetDragOffsetX = 0
Global $__g_bWidgetDragPending = False
Global $__g_iWidgetDragStartX = 0

; -- Quick-access number input --
Global $__g_bQuickAccessActive = False
Global $__g_hQuickAccessTimer = 0

; ---- Tray icon mode globals ----
Global $__g_bTrayMode = False
Global $__g_iTrayToggleList = 0, $__g_iTrayEditLabel = 0
Global $__g_iTrayAddDesktop = 0, $__g_iTrayDelDesktop = 0
Global $__g_iTraySettings = 0, $__g_iTrayAbout = 0, $__g_iTrayQuit = 0

; ---- Config file watcher global ----
Global $__g_sCfgFileTime = ""

; ---- Get taskbar dimensions ----
Local $hTaskbar = WinGetHandle("[CLASS:Shell_TrayWnd]")
Local $aTaskbarPos = WinGetPos($hTaskbar)
$iTaskbarH = $aTaskbarPos[3]
$iTaskbarY = $aTaskbarPos[1]

Local $iTopMargin = 2
Local $iInnerH = $iTaskbarH - $iTopMargin
Local $iBtnW = $THEME_BTN_WIDTH
Local $iCenterX = $iBtnW
Local $iCenterW = $THEME_MAIN_WIDTH - (2 * $iBtnW)

; ---- Create main GUI ----
$gui = GUICreate(String($iDesktop), $THEME_MAIN_WIDTH, $iInnerH, 0, $iTaskbarY + $iTopMargin, _
    $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
GUISetBkColor($THEME_BG_MAIN)
_WinAPI_SetLayeredWindowAttributes($gui, 0, _Cfg_GetThemeAlphaMain(), $LWA_ALPHA)

; Left arrow
$lblLeft = GUICtrlCreateLabel(ChrW(9664), 0, 0, $iBtnW, $iInnerH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblLeft, 9, 400, 0, $THEME_FONT_SYMBOL)
GUICtrlSetColor($lblLeft, $THEME_FG_NORMAL)
GUICtrlSetBkColor($lblLeft, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetCursor($lblLeft, 0)

; Desktop number
$lblNum = GUICtrlCreateLabel(String($iDesktop), $iCenterX, 2, $iCenterW, $iInnerH * 0.55, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblNum, 13, 700, 0, $THEME_FONT_MAIN)
GUICtrlSetColor($lblNum, $THEME_FG_PRIMARY)
GUICtrlSetBkColor($lblNum, $GUI_BKCOLOR_TRANSPARENT)

; Desktop label
Local $sLabel = _Labels_Load($iDesktop)
$lblName = GUICtrlCreateLabel($sLabel, $iCenterX, $iInnerH * 0.52, $iCenterW, $iInnerH * 0.42, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblName, 7, 400, 0, $THEME_FONT_MAIN)
GUICtrlSetColor($lblName, $THEME_FG_LABEL)
GUICtrlSetBkColor($lblName, $GUI_BKCOLOR_TRANSPARENT)

; Right arrow
$lblRight = GUICtrlCreateLabel(ChrW(9654), $THEME_MAIN_WIDTH - $iBtnW, 0, $iBtnW, $iInnerH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblRight, 9, 400, 0, $THEME_FONT_SYMBOL)
GUICtrlSetColor($lblRight, $THEME_FG_NORMAL)
GUICtrlSetBkColor($lblRight, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetCursor($lblRight, 0)

GUISetState(@SW_SHOW)

; ---- Register messages ----
GUIRegisterMsg($WM_ACTIVATE, "_WM_ACTIVATE")
GUIRegisterMsg($WM_WINDOWPOSCHANGING, "_WM_POSCHANGING")
GUIRegisterMsg($WM_CTLCOLOREDIT, "_WM_CTLCOLOREDIT_Delegate")

; ---- Register mouse wheel handler if scroll is enabled ----
If _Cfg_GetScrollEnabled() Or _Cfg_GetListScrollEnabled() Then GUIRegisterMsg(0x020A, "_WM_MOUSEWHEEL")

; ---- Event-driven desktop change notification ----
_VD_RegisterNotify($gui, $WM_VD_NOTIFY)
GUIRegisterMsg($WM_VD_NOTIFY, "_WM_DESKTOPCHANGE")

; ---- Periodic tasks (adlib) ----
AdlibRegister("_ForceTopMost", _Cfg_GetTopmostInterval())
AdlibRegister("_AdlibSyncNames", 2000)

; ---- Register hotkeys ----
_RegisterHotkeys()

; ---- Tray icon mode (if enabled) ----
If _Cfg_GetTrayIconMode() Then _InitTrayMode()

; ---- Config file watcher (if enabled) ----
If _Cfg_GetConfigWatcherEnabled() Then
    $__g_sCfgFileTime = FileGetTime(_Cfg_GetPath(), 0, 1)
    AdlibRegister("_AdlibConfigWatcher", _Cfg_GetConfigWatcherInterval())
EndIf

_Log_Info("Startup complete")

; ---- Main loop ----
Local $bRightWasDown = False
Local $bLeftWasDown = False
Local $bMiddleWasDown = False

While 1
    Local $aMsg = GUIGetMsg(1)
    Local $msg = $aMsg[0]
    Local $hFrom = $aMsg[1]

    ; Tray icon messages (if in tray mode)
    _CheckTrayMessages()

    ; Main GUI events
    If $hFrom = $gui Then
        Switch $msg
            Case $GUI_EVENT_CLOSE
                _Shutdown()
            Case $lblLeft
                Local $iCount = _VD_GetCount()
                If $iDesktop > 1 Then
                    _VD_GoTo($iDesktop - 1)
                ElseIf _Cfg_GetWrapNavigation() Then
                    _VD_GoTo($iCount)
                EndIf
                Sleep(50)
                _RefreshIndex()
            Case $lblRight
                Local $iCount2 = _VD_GetCount()
                If $iDesktop < $iCount2 Then
                    _VD_GoTo($iDesktop + 1)
                ElseIf _Cfg_GetAutoCreateDesktop() Then
                    _VD_CreateDesktop()
                    Sleep(100)
                    _VD_GoTo($iDesktop + 1)
                ElseIf _Cfg_GetWrapNavigation() Then
                    _VD_GoTo(1)
                EndIf
                Sleep(50)
                _RefreshIndex()
            Case $lblNum, $lblName
                If _Cfg_GetQuickAccessEnabled() And $msg = $lblNum And $__g_iClickCount >= 2 Then
                    _QuickAccess_Show()
                Else
                    _DL_ShowTemp($iTaskbarY, $iDesktop)
                EndIf
        EndSwitch
    EndIf

    ; Context menu events
    If _CM_IsVisible() And $hFrom = _CM_GetGUI() Then
        Local $sAction = _CM_HandleClick($msg)
        Switch $sAction
            Case "edit"
                _CM_Destroy()
                $iRenameTarget = $iDesktop
                _RD_Show($iDesktop, $iTaskbarY)
            Case "toggle_list"
                _CM_Destroy()
                _DL_Toggle($iTaskbarY, $iDesktop)
            Case "add"
                _CM_Destroy()
                _VD_CreateDesktop()
                Sleep(100)
                _RefreshIndex()
            Case "delete"
                _CM_Destroy()
                If _VD_GetCount() <= 1 Then
                    _Theme_Confirm("Cannot Delete", "This is the last desktop.")
                Else
                    Local $sDelCurName = _Labels_Load($iDesktop)
                    Local $sDelCurLabel = "Desktop " & $iDesktop
                    If $sDelCurName <> "" Then $sDelCurLabel &= ' ("' & $sDelCurName & '")'
                    If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm("Delete " & $sDelCurLabel & "?", _
                            "Windows will be moved to an adjacent desktop.") Then
                        _VD_RemoveDesktop($iDesktop)
                        Sleep(100)
                        _RefreshIndex()
                    EndIf
                EndIf
            Case "settings"
                _CM_Destroy()
                _CD_Show()
            Case "about"
                _CM_Destroy()
                _ShowAbout()
            Case "quit"
                _Shutdown()
        EndSwitch
    EndIf

    ; Desktop list events
    If _DL_IsVisible() And $hFrom = _DL_GetGUI() Then
        Local $iTarget = _DL_HandleClick($msg)
        If $iTarget > 0 Then
            _DL_CtxDestroy()
            _VD_GoTo($iTarget)
            Sleep(50)
            _RefreshIndex()
        EndIf
    EndIf

    ; Desktop list context menu events
    If _DL_CtxIsVisible() And $hFrom = _DL_CtxGetGUI() Then
        Local $sDLAction = _DL_CtxHandleClick($msg)
        Local $iCtxTarget = _DL_CtxGetTarget()
        Switch $sDLAction
            Case "switch"
                _DL_CtxDestroy()
                _VD_GoTo($iCtxTarget)
                Sleep(50)
                _RefreshIndex()
            Case "rename"
                _DL_CtxDestroy()
                $iRenameTarget = $iCtxTarget
                _RD_Show($iCtxTarget, $iTaskbarY)
            Case "peek"
                _DL_CtxDestroy()
                _Peek_Start($iCtxTarget)
            Case "set_color"
                _DL_ColorPickerShow($iCtxTarget)
            Case "move_window"
                _DL_CtxDestroy()
                Local $hActiveWin = WinGetHandle("[ACTIVE]")
                If $hActiveWin <> 0 And $hActiveWin <> $gui Then
                    _VD_MoveWindowToDesktop($hActiveWin, $iCtxTarget)
                EndIf
            Case "add"
                _DL_CtxDestroy()
                _VD_CreateDesktop()
                Sleep(100)
                _RefreshIndex()
            Case "delete"
                _DL_CtxDestroy()
                If _VD_GetCount() <= 1 Then
                    _Theme_Confirm("Cannot Delete", "This is the last desktop.")
                Else
                    Local $sDelName = _Labels_Load($iCtxTarget)
                    Local $sDelLabel = "Desktop " & $iCtxTarget
                    If $sDelName <> "" Then $sDelLabel &= ' ("' & $sDelName & '")'
                    If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm("Delete " & $sDelLabel & "?", _
                        "Windows will be moved to an adjacent desktop.") Then
                        _VD_RemoveDesktop($iCtxTarget)
                        Sleep(100)
                        _RefreshIndex()
                    EndIf
                EndIf
        EndSwitch
    EndIf

    ; Color picker events
    If _DL_ColorPickerIsVisible() And $hFrom = _DL_ColorPickerGetGUI() Then
        Local $vColorResult = _DL_ColorPickerHandleClick($msg)
        If $vColorResult <> "" Then
            Local $iColorTarget = _DL_ColorPickerGetTarget()
            If $vColorResult = "none" Then
                ; Clear color — set to 0 (transparent/disabled for this desktop)
                _Cfg_SetDesktopColor($iColorTarget, 0)
                _Cfg_SetDesktopColorsEnabled(True)
                _Cfg_Save()
            ElseIf $vColorResult = "custom" Then
                Local $iCustomColor = _DL_ColorPickerCustomDialog()
                If $iCustomColor >= 0 Then
                    _Cfg_SetDesktopColor($iColorTarget, $iCustomColor)
                    _Cfg_SetDesktopColorsEnabled(True)
                    _Cfg_Save()
                EndIf
            Else
                _Cfg_SetDesktopColor($iColorTarget, Int($vColorResult))
                _Cfg_SetDesktopColorsEnabled(True)
                _Cfg_Save()
            EndIf
            _DL_ColorPickerDestroy()
            _DL_CtxDestroy()
            _DL_Refresh($iTaskbarY, $iDesktop)
        EndIf
    EndIf

    ; Rename dialog events
    If _RD_IsVisible() And $hFrom = _RD_GetGUI() Then
        Local $sRDAction = _RD_HandleEvent($msg)
        Switch $sRDAction
            Case "close", "cancel"
                _RD_SetCancelled()
                _RD_Destroy()
            Case "submit"
                If Not $__g_RD_bCancelled Then
                    Local $sNewLabel = _RD_Submit($iRenameTarget)
                    If $iRenameTarget = $iDesktop Then
                        GUICtrlSetData($lblName, $sNewLabel)
                    EndIf
                    _DL_UpdateItemText($iRenameTarget, $sNewLabel)
                EndIf
        EndSwitch
    EndIf

    ; Key handling for rename dialog
    If _RD_IsVisible() Then
        Local $sKey = _RD_CheckKeys()
        Switch $sKey
            Case "submit"
                If Not $__g_RD_bCancelled Then
                    Local $sNewLabel2 = _RD_Submit($iRenameTarget)
                    If $iRenameTarget = $iDesktop Then
                        GUICtrlSetData($lblName, $sNewLabel2)
                    EndIf
                    _DL_UpdateItemText($iRenameTarget, $sNewLabel2)
                EndIf
            Case "cancel"
                _RD_SetCancelled()
                _RD_Destroy()
        EndSwitch
    EndIf

    ; Right-click detection
    Local $rBtn = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x02)
    If @error Or Not IsArray($rBtn) Then ContinueLoop
    Local $bRightDown = (BitAND($rBtn[0], 0x8000) <> 0)

    If $bRightWasDown And Not $bRightDown Then
        ; Right-click during drag -> cancel drag
        If _DL_IsDragging() Then
            _DL_DragCancel($iDesktop)
        Else
            Local $aCursorPos = MouseGetPos()
            Local $aWinPos = WinGetPos($gui)

            ; Right-click over main widget -> toggle widget context menu
            If $aCursorPos[0] >= $aWinPos[0] And $aCursorPos[0] < $aWinPos[0] + $aWinPos[2] And _
               $aCursorPos[1] >= $aWinPos[1] And $aCursorPos[1] < $aWinPos[1] + $aWinPos[3] Then
                _DL_CtxDestroy()
                If _CM_IsVisible() Then
                    _CM_Destroy()
                Else
                    _CM_Show($iTaskbarY, _DL_IsVisible())
                EndIf

            ; Right-click over desktop list -> show per-item context menu
            ElseIf _DL_IsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()) Then
                _CM_Destroy()
                Local $iRightClickRow = _DL_GetItemAtPos()
                If $iRightClickRow > 0 Then
                    If _DL_CtxIsVisible() Then
                        _DL_CtxDestroy()
                    Else
                        _DL_CtxShow($iRightClickRow)
                    EndIf
                EndIf

            Else
                If _CM_IsVisible() Then _CM_Destroy()
                If _DL_CtxIsVisible() Then _DL_CtxDestroy()
            EndIf
        EndIf
    EndIf
    $bRightWasDown = $bRightDown

    ; Middle-click detection
    Local $mBtn = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x04)
    If @error Or Not IsArray($mBtn) Then ContinueLoop
    Local $bMiddleDown = (BitAND($mBtn[0], 0x8000) <> 0)

    If $bMiddleWasDown And Not $bMiddleDown Then
        If _Cfg_GetMiddleClickDelete() And _DL_IsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()) Then
            Local $iMiddleClickRow = _DL_GetItemAtPos()
            If $iMiddleClickRow > 0 Then
                If _VD_GetCount() <= 1 Then
                    _Theme_Confirm("Cannot Delete", "This is the last desktop.")
                Else
                    Local $sDelMCName = _Labels_Load($iMiddleClickRow)
                    Local $sDelMCLabel = "Desktop " & $iMiddleClickRow
                    If $sDelMCName <> "" Then $sDelMCLabel &= ' ("' & $sDelMCName & '")'
                    If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm("Delete " & $sDelMCLabel & "?", _
                        "Windows will be moved to an adjacent desktop.") Then
                        _VD_RemoveDesktop($iMiddleClickRow)
                        Sleep(100)
                        _RefreshIndex()
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf
    $bMiddleWasDown = $bMiddleDown

    ; Left-click drag detection for desktop list + triple-click + widget drag
    Local $lBtn = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x01)
    If @error Or Not IsArray($lBtn) Then ContinueLoop
    Local $bLeftDown = (BitAND($lBtn[0], 0x8000) <> 0)

    If $bLeftDown And Not $bLeftWasDown Then
        ; Track click count for triple-click
        If TimerDiff($__g_hClickTimer) < 500 Then
            $__g_iClickCount += 1
        Else
            $__g_iClickCount = 1
        EndIf
        $__g_hClickTimer = TimerInit()

        ; Triple-click to edit: takes priority over drag
        If $__g_iClickCount >= 3 And _DL_IsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()) Then
            Local $iTripleRow = _DL_GetItemAtPos()
            If $iTripleRow > 0 Then
                $__g_iClickCount = 0
                $iRenameTarget = $iTripleRow
                _RD_Show($iTripleRow, $iTaskbarY)
            EndIf
        ; LMB just pressed -- start drag tracking if over desktop list
        ElseIf _DL_IsVisible() And Not _DL_CtxIsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()) Then
            _DL_DragMouseDown()
        ; Widget drag: LMB on center of widget (not arrows, not when list visible)
        ElseIf _Cfg_GetWidgetDragEnabled() And Not _DL_IsVisible() And _Theme_IsCursorOverWindow($gui) Then
            Local $aCurWidget = GUIGetCursorInfo($gui)
            If Not @error And $aCurWidget[4] <> $lblLeft And $aCurWidget[4] <> $lblRight Then
                Local $aWPDrag = WinGetPos($gui)
                Local $aMPDrag = MouseGetPos()
                $__g_iWidgetDragOffsetX = $aMPDrag[0] - $aWPDrag[0]
                $__g_iWidgetDragStartX = $aMPDrag[0]
                $__g_bWidgetDragPending = True
                $__g_bWidgetDragging = False
            EndIf
        EndIf
    EndIf

    If $bLeftDown And _DL_IsDragging() Then
        _DL_DragMouseMove()
    EndIf

    ; Widget drag: check threshold and move
    If $bLeftDown And $__g_bWidgetDragPending And Not $__g_bWidgetDragging Then
        Local $aMPWD = MouseGetPos()
        If Abs($aMPWD[0] - $__g_iWidgetDragStartX) >= 5 Then
            $__g_bWidgetDragging = True
        EndIf
    EndIf

    If $bLeftDown And $__g_bWidgetDragging Then
        Local $aMPWD2 = MouseGetPos()
        Local $iNewX = $aMPWD2[0] - $__g_iWidgetDragOffsetX
        ; Clamp to screen bounds
        If $iNewX < 0 Then $iNewX = 0
        If $iNewX + $THEME_MAIN_WIDTH > @DesktopWidth Then $iNewX = @DesktopWidth - $THEME_MAIN_WIDTH
        WinMove($gui, "", $iNewX, $iTaskbarY + 2)
    EndIf

    ; LMB released
    If Not $bLeftDown And $bLeftWasDown Then
        ; Widget drag end
        If $__g_bWidgetDragging Then
            Local $aFinalPos = WinGetPos($gui)
            _Cfg_SetWidgetPosition("left")
            _Cfg_SetWidgetOffsetX($aFinalPos[0])
            _Cfg_Save()
            $__g_bWidgetDragging = False
            $__g_bWidgetDragPending = False
        ElseIf $__g_bWidgetDragPending Then
            ; Threshold not met — reset, normal click handled by GUIGetMsg
            $__g_bWidgetDragPending = False
        EndIf

        ; Desktop list drag end
        If _DL_IsDragging() Then
            Local $iNewCurrent = _DL_DragMouseUp($iDesktop, $iTaskbarY)
            If $iNewCurrent > 0 Then
                _VD_GoTo($iNewCurrent)
                Sleep(50)
                _RefreshIndex()
            EndIf
        EndIf
    EndIf

    ; Escape cancels drag
    If _DL_IsDragging() Then
        Local $retEscDrag = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And BitAND($retEscDrag[0], 0x8000) <> 0 Then
            _DL_DragCancel($iDesktop)
        EndIf
    EndIf

    $bLeftWasDown = $bLeftDown

    ; Quick-access number input polling
    If $__g_bQuickAccessActive Then _QuickAccess_Check()

    ; Event-driven desktop change (flag set by _WM_DESKTOPCHANGE)
    If $bDesktopChanged Then
        $bDesktopChanged = False
        _RefreshIndex()
    EndIf

    ; Event-driven name sync (flag set by _AdlibSyncNames)
    If $bNamesChanged Then
        $bNamesChanged = False
        _ApplyDesktopChange()
    EndIf

    ; Lazy hover check: skip when cursor hasn't moved and no state changed
    Local $aCurPos = MouseGetPos()
    Local $bCursorMoved = ($aCurPos[0] <> $__g_iLastCursorX Or $aCurPos[1] <> $__g_iLastCursorY)
    If $bCursorMoved Then
        $__g_iLastCursorX = $aCurPos[0]
        $__g_iLastCursorY = $aCurPos[1]
    EndIf

    ; Check if cursor is over any of our windows
    Local $bCursorActive = _Theme_IsCursorOverWindow($gui)
    If Not $bCursorActive And _DL_IsVisible() Then $bCursorActive = _Theme_IsCursorOverWindow(_DL_GetGUI())
    If Not $bCursorActive And _CM_IsVisible() Then $bCursorActive = _Theme_IsCursorOverWindow(_CM_GetGUI())
    If Not $bCursorActive And _DL_CtxIsVisible() Then $bCursorActive = _Theme_IsCursorOverWindow(_DL_CtxGetGUI())
    If Not $bCursorActive And _DL_ColorPickerIsVisible() Then $bCursorActive = _Theme_IsCursorOverWindow(_DL_ColorPickerGetGUI())
    If Not $bCursorActive And _RD_IsVisible() Then $bCursorActive = _Theme_IsCursorOverWindow(_RD_GetGUI())

    ; Hover effects -- only when cursor moved or drag active, and only for the window under cursor
    If $bCursorActive And ($bCursorMoved Or _DL_IsDragging() Or $bDesktopChanged Or $bNamesChanged) Then
        If _Theme_IsCursorOverWindow($gui) Then _CheckHover()
        If _DL_IsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()) Then _DL_CheckHover($iDesktop)
        If _CM_IsVisible() And _Theme_IsCursorOverWindow(_CM_GetGUI()) Then _CM_CheckHover()
        If _DL_CtxIsVisible() And _Theme_IsCursorOverWindow(_DL_CtxGetGUI()) Then _DL_CtxCheckHover()
        If _RD_IsVisible() And _Theme_IsCursorOverWindow(_RD_GetGUI()) Then _RD_CheckHover()
    EndIf

    ; Toast fade-out tick
    _Theme_ToastTick()

    ; Peek bounce-back
    _Peek_CheckBounce()

    ; Auto-hide temp list and context menus
    _DL_CheckAutoHide($gui)
    _CM_CheckAutoHide($gui)
    _DL_CtxCheckAutoHide()

    ; Dynamic sleep: responsive when active, lightweight when idle
    If $bCursorActive Then
        Sleep(5)
    Else
        Sleep(30)
    EndIf
WEnd

; =============================================
; MAIN HELPERS
; =============================================

Func _ApplyDesktopChange()
    If _Cfg_GetShowCount() Then
        Local $iTotal = _VD_GetCount()
        GUICtrlSetData($lblNum, String($iDesktop) & "/" & String($iTotal))
        GUICtrlSetFont($lblNum, _Cfg_GetCountFontSize(), 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetData($lblNum, String($iDesktop))
        GUICtrlSetFont($lblNum, 13, 700, 0, $THEME_FONT_MAIN)
    EndIf
    GUICtrlSetData($lblName, _Labels_Load($iDesktop))
    WinSetTitle($gui, "", String($iDesktop))
    _DL_Refresh($iTaskbarY, $iDesktop)
    If $__g_bTrayMode Then TraySetToolTip("Desk Switcheroo - Desktop " & $iDesktop)
EndFunc

; Name:        _ApplySettingsLive
; Description: Reloads all runtime state from config after Settings Apply.
;              Called by ConfigDialog after saving.
Func _ApplySettingsLive()
    ; Re-register hotkeys with new bindings
    _UnregisterHotkeys()
    _RegisterHotkeys()

    ; Update widget opacity
    _WinAPI_SetLayeredWindowAttributes($gui, 0, _Cfg_GetThemeAlphaMain(), $LWA_ALPHA)

    ; Update topmost interval
    AdlibUnRegister("_ForceTopMost")
    If Not _Cfg_GetTrayIconMode() Then
        AdlibRegister("_ForceTopMost", _Cfg_GetTopmostInterval())
    EndIf

    ; Update config watcher
    AdlibUnRegister("_AdlibConfigWatcher")
    If _Cfg_GetConfigWatcherEnabled() Then
        $__g_sCfgFileTime = FileGetTime(_Cfg_GetPath(), 0, 1)
        AdlibRegister("_AdlibConfigWatcher", _Cfg_GetConfigWatcherInterval())
    EndIf

    ; Refresh display (count format, label, list)
    _ApplyDesktopChange()

    ; Force reposition with new widget position/offset
    _ForceTopMost()
EndFunc

Func _RefreshIndex()
    $iDesktop = _VD_GetCurrent()
    _ApplyDesktopChange()
    _ForceTopMost()
EndFunc

; =============================================
; QUICK-ACCESS NUMBER INPUT
; =============================================

; Name:        _QuickAccess_Show
; Description: Activates quick-access mode: replaces desktop number with "_" prompt
Func _QuickAccess_Show()
    $__g_bQuickAccessActive = True
    $__g_hQuickAccessTimer = TimerInit()
    GUICtrlSetData($lblNum, "_")
EndFunc

; Name:        _QuickAccess_Check
; Description: Polls VK_1-VK_9 for quick desktop jump. 3s timeout. Escape cancels.
Func _QuickAccess_Check()
    If Not $__g_bQuickAccessActive Then Return

    ; Check for escape
    Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
    If Not @error And BitAND($retEsc[0], 0x8000) <> 0 Then
        _QuickAccess_Cancel()
        Return
    EndIf

    ; Check 3s timeout
    If TimerDiff($__g_hQuickAccessTimer) > 3000 Then
        _QuickAccess_Cancel()
        Return
    EndIf

    ; Poll VK_1 (0x31) through VK_9 (0x39)
    For $i = 0x31 To 0x39
        Local $retKey = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $i)
        If Not @error And BitAND($retKey[0], 0x8000) <> 0 Then
            Local $iTarget = $i - 0x30 ; 1-9
            $__g_bQuickAccessActive = False
            _VD_GoTo($iTarget)
            Sleep(50)
            _RefreshIndex()
            Return
        EndIf
    Next
EndFunc

; Name:        _QuickAccess_Cancel
; Description: Cancels quick-access mode and restores the display
Func _QuickAccess_Cancel()
    $__g_bQuickAccessActive = False
    _ApplyDesktopChange()
EndFunc

; =============================================
; EVENT-DRIVEN CALLBACKS
; =============================================

Func _WM_DESKTOPCHANGE($hWnd, $iMsg, $wParam, $lParam)
    _VD_InvalidateCountCache()
    If Not _Peek_IsActive() Then $bDesktopChanged = True
    Return $GUI_RUNDEFMSG
EndFunc

Func _AdlibSyncNames()
    If _Peek_IsActive() Then Return
    If _Labels_SyncFromOS() Then $bNamesChanged = True
EndFunc

Func _CheckHover()
    Local $aCursor = GUIGetCursorInfo($gui)
    If @error Then Return

    If $aCursor[4] = $lblLeft Then
        If Not $bHoverLeft Then
            _Theme_ApplyHover($lblLeft, $THEME_FG_WHITE, $THEME_BG_ARROW_HOV)
            $bHoverLeft = True
        EndIf
    Else
        If $bHoverLeft Then
            _Theme_RemoveHover($lblLeft, $THEME_FG_NORMAL)
            $bHoverLeft = False
        EndIf
    EndIf

    If $aCursor[4] = $lblRight Then
        If Not $bHoverRight Then
            _Theme_ApplyHover($lblRight, $THEME_FG_WHITE, $THEME_BG_ARROW_HOV)
            $bHoverRight = True
        EndIf
    Else
        If $bHoverRight Then
            _Theme_RemoveHover($lblRight, $THEME_FG_NORMAL)
            $bHoverRight = False
        EndIf
    EndIf
EndFunc

; =============================================
; SCROLL WHEEL HANDLER
; =============================================

Func _WM_MOUSEWHEEL($hWnd, $iMsg, $wParam, $lParam)
    Local $iDelta = BitShift(BitAND($wParam, 0xFFFF0000), 16)
    ; Convert to signed
    If $iDelta > 32767 Then $iDelta -= 65536

    ; Check if scroll is over the desktop list
    If _DL_IsVisible() And $hWnd = _DL_GetGUI() Then
        If Not _Cfg_GetListScrollEnabled() Then Return $GUI_RUNDEFMSG

        ; List scroll: navigate desktops via scroll on list
        Local $iDir = ($iDelta > 0) ? -1 : 1
        If _Cfg_GetScrollDirection() = "inverted" Then $iDir = -$iDir
        Local $iCount = _VD_GetCount()
        Local $iNew = $iDesktop + $iDir
        If $iNew < 1 Then
            If _Cfg_GetScrollWrap() Then
                $iNew = $iCount
            Else
                Return $GUI_RUNDEFMSG
            EndIf
        ElseIf $iNew > $iCount Then
            If _Cfg_GetScrollWrap() Then
                $iNew = 1
            Else
                Return $GUI_RUNDEFMSG
            EndIf
        EndIf
        _VD_GoTo($iNew)
        Sleep(50)
        _RefreshIndex()
        Return 0
    EndIf

    ; Check if scroll is over the main widget
    If $hWnd = $gui Then
        If Not _Cfg_GetScrollEnabled() Then Return $GUI_RUNDEFMSG

        Local $iDir2 = ($iDelta > 0) ? -1 : 1
        If _Cfg_GetScrollDirection() = "inverted" Then $iDir2 = -$iDir2
        Local $iCount2 = _VD_GetCount()
        Local $iNew2 = $iDesktop + $iDir2
        If $iNew2 < 1 Then
            If _Cfg_GetScrollWrap() Then
                $iNew2 = $iCount2
            Else
                Return $GUI_RUNDEFMSG
            EndIf
        ElseIf $iNew2 > $iCount2 Then
            If _Cfg_GetScrollWrap() Then
                $iNew2 = 1
            Else
                Return $GUI_RUNDEFMSG
            EndIf
        EndIf
        _VD_GoTo($iNew2)
        Sleep(50)
        _RefreshIndex()
        Return 0
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; =============================================
; TOPMOST ENFORCEMENT
; =============================================

Func _ForceTopMost()
    ; Don't steal focus from blocking dialogs (Settings, About, Confirm)
    If _CD_IsVisible() Then Return

    ; Skip topmost enforcement in tray mode (no widget to manage)
    If $__g_bTrayMode Then Return

    ; Re-read taskbar dimensions in case screen resized or taskbar moved
    Local $bTaskbarMoved = False
    Local $hTB = WinGetHandle("[CLASS:Shell_TrayWnd]")
    If $hTB Then
        Local $aTBPos = WinGetPos($hTB)
        If Not @error Then
            If $aTBPos[1] <> $iTaskbarY Or $aTBPos[3] <> $iTaskbarH Then
                $iTaskbarY = $aTBPos[1]
                $iTaskbarH = $aTBPos[3]
                $bTaskbarMoved = True
            EndIf
        EndIf
    EndIf

    ; Always keep topmost flag (cheap)
    WinSetOnTop($gui, "", 1)

    ; Only reposition if taskbar moved
    If $bTaskbarMoved Then
        Local $iWidgetX = 0
        Local $sPos = _Cfg_GetWidgetPosition()
        Local $iOffset = _Cfg_GetWidgetOffsetX()
        Switch $sPos
            Case "left"
                $iWidgetX = $iOffset
            Case "center"
                $iWidgetX = (@DesktopWidth / 2) - ($THEME_MAIN_WIDTH / 2) + $iOffset
            Case "right"
                $iWidgetX = @DesktopWidth - $THEME_MAIN_WIDTH + $iOffset
        EndSwitch

        DllCall("user32.dll", "bool", "SetWindowPos", _
            "hwnd", $gui, "hwnd", $HWND_TOPMOST, _
            "int", $iWidgetX, "int", $iTaskbarY + 2, _
            "int", $THEME_MAIN_WIDTH, "int", $iTaskbarH - 2, _
            "uint", BitOR($SWP_NOACTIVATE, $SWP_SHOWWINDOW))
    EndIf

    ; Always verify TOPMOST style bit - other windows can steal it
    Local $iStyle = _WinAPI_GetWindowLong($gui, $GWL_EXSTYLE)
    If BitAND($iStyle, $WS_EX_TOPMOST) = 0 Then
        _WinAPI_SetWindowLong($gui, $GWL_EXSTYLE, BitOR($iStyle, $WS_EX_TOPMOST))
        ; Lost topmost - force full reposition to recover
        Local $iWidgetX2 = 0
        Local $sPos2 = _Cfg_GetWidgetPosition()
        Local $iOffset2 = _Cfg_GetWidgetOffsetX()
        Switch $sPos2
            Case "left"
                $iWidgetX2 = $iOffset2
            Case "center"
                $iWidgetX2 = (@DesktopWidth / 2) - ($THEME_MAIN_WIDTH / 2) + $iOffset2
            Case "right"
                $iWidgetX2 = @DesktopWidth - $THEME_MAIN_WIDTH + $iOffset2
        EndSwitch
        DllCall("user32.dll", "bool", "SetWindowPos", _
            "hwnd", $gui, "hwnd", $HWND_TOPMOST, _
            "int", $iWidgetX2, "int", $iTaskbarY + 2, _
            "int", $THEME_MAIN_WIDTH, "int", $iTaskbarH - 2, _
            "uint", BitOR($SWP_NOACTIVATE, $SWP_SHOWWINDOW))
    EndIf
EndFunc

Func _WM_ACTIVATE($hWnd, $iMsg, $wParam, $lParam)
    _ForceTopMost()
    Return $GUI_RUNDEFMSG
EndFunc

Func _WM_POSCHANGING($hWnd, $iMsg, $wParam, $lParam)
    Local $tPos = DllStructCreate("uint;uint;int;int;int;int;uint", $lParam)
    DllStructSetData($tPos, 2, $HWND_TOPMOST)
    Return $GUI_RUNDEFMSG
EndFunc

Func _WM_CTLCOLOREDIT_Delegate($hWnd, $iMsg, $wParam, $lParam)
    Return _RD_WM_CTLCOLOREDIT($hWnd, $iMsg, $wParam, $lParam)
EndFunc

; =============================================
; HOTKEY REGISTRATION
; =============================================

Func _RegisterHotkeys()
    Local $sKey
    $sKey = _Cfg_GetHotkeyNext()
    If $sKey <> "" Then HotKeySet($sKey, "_HK_Next")
    $sKey = _Cfg_GetHotkeyPrev()
    If $sKey <> "" Then HotKeySet($sKey, "_HK_Prev")
    For $i = 1 To 9
        $sKey = _Cfg_GetHotkeyDesktop($i)
        If $sKey <> "" Then HotKeySet($sKey, "_HK_Desktop" & $i)
    Next
    $sKey = _Cfg_GetHotkeyToggleList()
    If $sKey <> "" Then HotKeySet($sKey, "_HK_ToggleList")
EndFunc

Func _UnregisterHotkeys()
    Local $sKey
    $sKey = _Cfg_GetHotkeyNext()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyPrev()
    If $sKey <> "" Then HotKeySet($sKey)
    For $i = 1 To 9
        $sKey = _Cfg_GetHotkeyDesktop($i)
        If $sKey <> "" Then HotKeySet($sKey)
    Next
    $sKey = _Cfg_GetHotkeyToggleList()
    If $sKey <> "" Then HotKeySet($sKey)
EndFunc

; ---- Hotkey callback functions ----
Func _HK_Next()
    Local $iCount = _VD_GetCount()
    If $iDesktop < $iCount Then
        _VD_GoTo($iDesktop + 1)
    ElseIf _Cfg_GetAutoCreateDesktop() Then
        _VD_CreateDesktop()
        Sleep(100)
        _VD_GoTo($iDesktop + 1)
    ElseIf _Cfg_GetWrapNavigation() Then
        _VD_GoTo(1)
    EndIf
    Sleep(50)
    _RefreshIndex()
EndFunc

Func _HK_Prev()
    Local $iCount = _VD_GetCount()
    If $iDesktop > 1 Then
        _VD_GoTo($iDesktop - 1)
    ElseIf _Cfg_GetWrapNavigation() Then
        _VD_GoTo($iCount)
    EndIf
    Sleep(50)
    _RefreshIndex()
EndFunc

Func _HK_Desktop1()
    _VD_GoTo(1)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop2()
    _VD_GoTo(2)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop3()
    _VD_GoTo(3)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop4()
    _VD_GoTo(4)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop5()
    _VD_GoTo(5)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop6()
    _VD_GoTo(6)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop7()
    _VD_GoTo(7)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop8()
    _VD_GoTo(8)
    Sleep(50)
    _RefreshIndex()
EndFunc
Func _HK_Desktop9()
    _VD_GoTo(9)
    Sleep(50)
    _RefreshIndex()
EndFunc

Func _HK_ToggleList()
    _DL_Toggle($iTaskbarY, $iDesktop)
EndFunc

; =============================================
; ABOUT DIALOG
; =============================================

Func _ShowAbout()
    Local $iDlgW = 350, $iDlgH = 230
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("About", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Title
    GUICtrlCreateLabel("Desk Switcheroo", 14, 10, $iDlgW - 28, 22)
    GUICtrlSetFont(-1, 11, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Description
    GUICtrlCreateLabel("Lightweight virtual desktop switcher for Windows." & @CRLF & _
        "Navigate, rename, peek, and manage desktops" & @CRLF & _
        "from a compact taskbar widget. Built with AutoIt.", 14, 36, $iDlgW - 28, 48)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Repo link
    Local $iLY = 90
    GUICtrlCreateLabel("Repository:", 14, $iLY, 70, 16)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_DIM)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idLinkRepo = GUICtrlCreateLabel("github.com/supermarsx/desk-switcheroo", 86, $iLY, 240, 16, $SS_NOTIFY)
    GUICtrlSetFont($idLinkRepo, 8, 400, 4, $THEME_FONT_MAIN) ; 4 = underline
    GUICtrlSetColor($idLinkRepo, $THEME_FG_LINK)
    GUICtrlSetBkColor($idLinkRepo, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idLinkRepo, 0)

    ; DLL credit + link
    $iLY += 22
    GUICtrlCreateLabel("VirtualDesktopAccessor.dll by Ciantic (MIT)", 14, $iLY, $iDlgW - 28, 16)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_DIM)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $iLY += 16
    Local $idLinkDLL = GUICtrlCreateLabel("github.com/Ciantic/VirtualDesktopAccessor", 14, $iLY, $iDlgW - 28, 16, $SS_NOTIFY)
    GUICtrlSetFont($idLinkDLL, 8, 400, 4, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLinkDLL, $THEME_FG_LINK)
    GUICtrlSetBkColor($idLinkDLL, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idLinkDLL, 0)

    ; Font credit + link
    $iLY += 22
    GUICtrlCreateLabel("Fira Code font by Nikita Prokopov (OFL)", 14, $iLY, $iDlgW - 28, 16)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_DIM)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $iLY += 16
    Local $idLinkFont = GUICtrlCreateLabel("github.com/tonsky/FiraCode", 14, $iLY, $iDlgW - 28, 16, $SS_NOTIFY)
    GUICtrlSetFont($idLinkFont, 8, 400, 4, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLinkFont, $THEME_FG_LINK)
    GUICtrlSetBkColor($idLinkFont, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idLinkFont, 0)

    ; Close button
    Local $iBtnW = 64, $iBtnH = 26
    Local $idClose = GUICtrlCreateLabel("Close", ($iDlgW - $iBtnW) / 2, $iDlgH - 36, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($idClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($idClose, 0)

    GUISetState(@SW_SHOW, $hDlg)

    ; Blocking message loop with 5s timeout
    Local $iHovered = 0
    Local $hTimer = TimerInit()
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idClose
                    ExitLoop
                Case $idLinkRepo
                    ShellExecute("https://github.com/supermarsx/desk-switcheroo")
                Case $idLinkDLL
                    ShellExecute("https://github.com/Ciantic/VirtualDesktopAccessor")
                Case $idLinkFont
                    ShellExecute("https://github.com/tonsky/FiraCode")
            EndSwitch
        EndIf

        ; Keyboard: Enter or Escape closes
        Local $retKey = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And BitAND($retKey[0], 0x8000) <> 0 Then ExitLoop
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

        ; 15 second timeout
        If TimerDiff($hTimer) >= 15000 Then ExitLoop

        ; Hover on close button
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idClose Then $iFound = $idClose
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then _Theme_RemoveHover($iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        Sleep(10)
    WEnd

    GUIDelete($hDlg)
EndFunc

; =============================================
; TRAY ICON MODE
; =============================================

Func _InitTrayMode()
    $__g_bTrayMode = True
    GUISetState(@SW_HIDE, $gui)
    Opt("TrayMenuMode", 3) ; no default menu items
    $__g_iTrayToggleList = TrayCreateItem("Show Desktop List")
    $__g_iTrayEditLabel = TrayCreateItem("Edit Label")
    TrayCreateItem("") ; separator
    $__g_iTrayAddDesktop = TrayCreateItem("Add Desktop")
    $__g_iTrayDelDesktop = TrayCreateItem("Delete Desktop")
    TrayCreateItem("")
    $__g_iTraySettings = TrayCreateItem("Settings")
    $__g_iTrayAbout = TrayCreateItem("About")
    TrayCreateItem("")
    $__g_iTrayQuit = TrayCreateItem("Quit")
    TraySetToolTip("Desk Switcheroo - Desktop " & $iDesktop)
    If FileExists(@ScriptDir & "\assets\desk_switcheroo.ico") Then
        TraySetIcon(@ScriptDir & "\assets\desk_switcheroo.ico")
    EndIf
    TraySetState(1)
EndFunc

Func _CheckTrayMessages()
    If Not $__g_bTrayMode Then Return
    Local $iTrayMsg = TrayGetMsg()
    Switch $iTrayMsg
        Case $__g_iTrayToggleList
            _DL_Toggle($iTaskbarY, $iDesktop)
        Case $__g_iTrayEditLabel
            $iRenameTarget = $iDesktop
            _RD_Show($iDesktop, $iTaskbarY)
        Case $__g_iTrayAddDesktop
            _VD_CreateDesktop()
            Sleep(100)
            _RefreshIndex()
        Case $__g_iTrayDelDesktop
            If _VD_GetCount() > 1 Then
                If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm("Delete Desktop " & $iDesktop & "?", "Windows will be moved to an adjacent desktop.") Then
                    _VD_RemoveDesktop($iDesktop)
                    Sleep(100)
                    _RefreshIndex()
                EndIf
            EndIf
        Case $__g_iTraySettings
            _CD_Show()
        Case $__g_iTrayAbout
            _ShowAbout()
        Case $__g_iTrayQuit
            _Shutdown()
    EndSwitch
EndFunc

; =============================================
; CONFIG FILE WATCHER
; =============================================

Func _AdlibConfigWatcher()
    Local $sNewTime = FileGetTime(_Cfg_GetPath(), 0, 1)
    If @error Then Return
    If $sNewTime = $__g_sCfgFileTime Then Return
    $__g_sCfgFileTime = $sNewTime
    _UnregisterHotkeys()
    _Cfg_Load()
    _RegisterHotkeys()
    _ApplyDesktopChange()
    AdlibUnRegister("_ForceTopMost")
    AdlibRegister("_ForceTopMost", _Cfg_GetTopmostInterval())
EndFunc

; =============================================
; CLEANUP
; =============================================

Func _OnExit()
    _Shutdown()
EndFunc

Func _Shutdown()
    If $__g_bShuttingDown Then Return
    $__g_bShuttingDown = True
    _UnregisterHotkeys()
    AdlibUnRegister("_ForceTopMost")
    AdlibUnRegister("_AdlibSyncNames")
    AdlibUnRegister("_AdlibConfigWatcher")
    If $gui Then _VD_UnregisterNotify($gui)
    _RD_Shutdown()
    _VD_Shutdown()
    _Theme_UnloadFonts()
    _Log_Shutdown()
    Exit
EndFunc

; Name:        _RunStartupChecks
; Description: Performs environment validation at startup. Shows errors and exits
;              if critical checks fail; logs results for all checks.
Func _RunStartupChecks()
    ; Check taskbar exists
    Local $hTaskbarChk = WinGetHandle("[CLASS:Shell_TrayWnd]")
    If $hTaskbarChk = 0 Then
        _Log_Error("Startup check failed: taskbar not found (Shell_TrayWnd)")
        MsgBox(16, "Desk Switcheroo", "Cannot find the Windows taskbar." & @CRLF & _
            "Desk Switcheroo requires the taskbar to be running.")
        Exit 1
    EndIf
    _Log_Debug("Startup check: taskbar found")

    ; Check taskbar dimensions valid
    Local $aChkPos = WinGetPos($hTaskbarChk)
    If Not @error And IsArray($aChkPos) Then
        If $aChkPos[3] <= 10 Then
            _Log_Error("Startup check failed: taskbar height too small (" & $aChkPos[3] & "px)")
            MsgBox(16, "Desk Switcheroo", "Taskbar height is invalid (" & $aChkPos[3] & "px)." & @CRLF & _
                "Desk Switcheroo requires a visible taskbar.")
            Exit 1
        EndIf
        _Log_Debug("Startup check: taskbar dimensions valid (" & $aChkPos[2] & "x" & $aChkPos[3] & ")")
    EndIf

    ; Check config writable
    Local $sTestKey = "__startup_test__"
    IniWrite(_Cfg_GetPath(), "General", $sTestKey, "1")
    Local $sReadBack = IniRead(_Cfg_GetPath(), "General", $sTestKey, "")
    IniDelete(_Cfg_GetPath(), "General", $sTestKey)
    If $sReadBack <> "1" Then
        _Log_Error("Startup check failed: config file not writable at " & _Cfg_GetPath())
        MsgBox(16, "Desk Switcheroo", "Cannot write to config file:" & @CRLF & _Cfg_GetPath() & @CRLF & _
            "Check file permissions.")
        Exit 1
    EndIf
    _Log_Debug("Startup check: config file writable")

    ; Check not running as SYSTEM user
    If @UserName = "SYSTEM" Then
        _Log_Error("Startup check failed: running as SYSTEM user")
        MsgBox(16, "Desk Switcheroo", "Desk Switcheroo should not run as the SYSTEM user." & @CRLF & _
            "Please run it as a normal user account.")
        Exit 1
    EndIf
    _Log_Debug("Startup check: running as user " & @UserName)

    _Log_Info("All startup checks passed")
EndFunc
