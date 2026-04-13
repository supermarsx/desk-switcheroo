#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPISysWin.au3>
#include <StaticConstants.au3>

; ---- Named constants (declared before includes so UDFs can reference them) ----
Global Const $VK_LBUTTON = 0x01
Global Const $VK_RBUTTON = 0x02
Global Const $VK_MBUTTON = 0x04
Global Const $VK_RETURN  = 0x0D
Global Const $VK_ESCAPE  = 0x1B
Global Const $VK_UP      = 0x26
Global Const $VK_DOWN    = 0x28
Global Const $VK_1       = 0x31
Global Const $VK_9       = 0x39
Global Const $VK_KEYDOWN = 0x8000
Global Const $TRIPLE_CLICK_MS = 500
Global Const $QUICK_ACCESS_TIMEOUT = 3000
Global Const $DESKTOP_LIMIT_HARD = 50 ; absolute safety cap

#include "includes\Config.au3"
#include "includes\Logger.au3"
#include "includes\Theme.au3"
#include "includes\Labels.au3"
#include "includes\VirtualDesktop.au3"
#include "includes\Wallpaper.au3"
#include "includes\Peek.au3"
#include "includes\ContextMenu.au3"
#include "includes\RenameDialog.au3"
#include "includes\DesktopList.au3"
#include "includes\WindowList.au3"
#include "includes\ConfigDialog.au3"
#include "includes\AboutDialog.au3"
#include "includes\UpdateChecker.au3"
#include "includes\ExplorerMonitor.au3"
#include "includes\i18n.au3"

; ---- App version (read from VERSION file or fallback) ----
Global $APP_VERSION = "dev"
Local $__sVerFile = @ScriptDir & "\VERSION"
If FileExists($__sVerFile) Then
    $APP_VERSION = StringStripWS(FileRead($__sVerFile), 3)
    If $APP_VERSION = "" Then $APP_VERSION = "dev"
EndIf

; ---- Error handling and crash recovery ----
Global $__g_bShuttingDown = False
Global $__g_bPeekWasActive = False
Global $__g_bWasCursorActive = False
Global $__g_oErrorHandler = ObjEvent("AutoIt.Error", "_OnAutoItError")
OnAutoItExitRegister("_OnExit")

; ---- Singleton: kill previous instance on relaunch ----
; Read singleton_enabled directly from INI (before _Cfg_Init)
Local $__sSingletonIni = @ScriptDir & "\desk_switcheroo.ini"
Local $__bSingleton = True
If FileExists($__sSingletonIni) Then
    Local $__sVal = StringLower(IniRead($__sSingletonIni, "General", "singleton_enabled", "true"))
    If $__sVal = "false" Or $__sVal = "0" Then $__bSingleton = False
EndIf
If $__bSingleton Then
    Local $sMutexName = "DesktopSwitcherMutex_7F3A"
    Local $hMutex = DllCall("kernel32.dll", "handle", "CreateMutexW", "ptr", 0, "bool", True, "wstr", $sMutexName)
    Local $aLastErr = DllCall("kernel32.dll", "dword", "GetLastError")
    If Not @error And IsArray($aLastErr) And $aLastErr[0] = 183 Then
        ; Previous instance running — kill only instances of THIS script (not all AutoIt)
        If @Compiled Then
            ; Compiled: ProcessList(@AutoItExe) only finds our own exe
            Local $aProcs = ProcessList(@AutoItExe)
            Local $p
            For $p = 1 To $aProcs[0][0]
                If $aProcs[$p][1] <> @AutoItPID Then ProcessClose($aProcs[$p][1])
            Next
        Else
            ; Source mode: find AutoIt processes running our specific script
            Local $aProcs = ProcessList("AutoIt3_x64.exe")
            If $aProcs[0][0] = 0 Then $aProcs = ProcessList("AutoIt3.exe")
            Local $p
            For $p = 1 To $aProcs[0][0]
                If $aProcs[$p][1] <> @AutoItPID Then
                    ; Check command line to verify it's running our script
                    Local $sCmdLine = ""
                    Local $aWMI = ObjGet("winmgmts:\\.\root\cimv2").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" & $aProcs[$p][1])
                    For $oProc In $aWMI
                        $sCmdLine = $oProc.CommandLine
                    Next
                    If StringInStr($sCmdLine, "desktop_switcher.au3") Then ProcessClose($aProcs[$p][1])
                EndIf
            Next
        EndIf
        Sleep(200)
    EndIf
EndIf

; ---- Load bundled fonts ----
_Theme_LoadFonts()

; ---- Initialize config ----
_Cfg_Init()

; ---- Initialize i18n ----
_i18n_Init(_Cfg_GetLanguage())

; ---- Apply theme scheme ----
_Theme_ApplyScheme(_Cfg_GetTheme())

; ---- Tray icon visibility ----
If Not _Cfg_GetTrayIconMode() Then Opt("TrayIconHide", 1)

; ---- Initialize wallpaper management ----
_WP_Init()

; ---- Initialize logging ----
_Log_Init()

; ---- Start explorer crash monitor ----
_EM_Start()

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
    Local $c
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

; ---- Auto-ensure minimum desktops ----
Local $__iMinDesktops = _Cfg_GetMinDesktops()
If $__iMinDesktops > 0 Then
    Local $__iCurCount = _VD_GetCount()
    If $__iCurCount < $__iMinDesktops Then
        Local $__iCreated = 0
        While _VD_GetCount() < $__iMinDesktops And _VD_GetCount() < _GetDesktopLimit()
            _VD_CreateDesktop()
            $__iCreated += 1
            Sleep(100)
        WEnd
        If $__iCreated > 0 Then
            _Log_Info("Auto-created " & $__iCreated & " desktop(s) to meet minimum of " & $__iMinDesktops)
        EndIf
    EndIf
EndIf

; ---- Globals ----
Global $iDesktop = _VD_GetCurrent()
Global $iPrevDesktop = 1
Global $gui, $lblNum, $lblName, $lblLeft, $lblRight, $lblColorBar
Global $iTaskbarH, $iTaskbarY
Global $bHoverLeft = False, $bHoverRight = False
Global $iRenameTarget = 0
Global $hMoveWindowTarget = 0   ; last known external foreground window
Global $hLastExternalWindow = 0 ; continuously tracked
Global $__g_hInetDownload = 0   ; background update download handle
Global $__g_sInetTempFile = ""  ; temp file for update check
Global $bDesktopChanged = False
Global $bNamesChanged = False
Global $__g_iLastCursorX = -1, $__g_iLastCursorY = -1
Global $__g_hFgTrackTimer = 0
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

; ---- Auto-update checker global ----
Global $__g_hUpdateTimer = 0
Global $__g_hUpdatePollTimer = 0

; ---- Get taskbar dimensions ----
Local $hTaskbar = WinGetHandle("[CLASS:Shell_TrayWnd]")
Local $aTaskbarPos = WinGetPos($hTaskbar)
$iTaskbarH = $aTaskbarPos[3]
$iTaskbarY = $aTaskbarPos[1]

Local $iTopMargin = 2
Local $iInnerH = $iTaskbarH - $iTopMargin
; Apply custom dimension overrides (0 = use defaults)
Global $__g_iWidgetW = _Cfg_GetWidgetWidth()
If $__g_iWidgetW <= 0 Then $__g_iWidgetW = $THEME_MAIN_WIDTH
Global $__g_iWidgetH = _Cfg_GetWidgetHeight()
If $__g_iWidgetH <= 0 Then $__g_iWidgetH = $iInnerH
Local $iBtnW = $THEME_BTN_WIDTH
Local $iCenterX = $iBtnW
Local $iCenterW = $__g_iWidgetW - (2 * $iBtnW)

; ---- Create main GUI ----
Local $aInitPos = __CalcWidgetXY()
$gui = GUICreate(String($iDesktop), $__g_iWidgetW, $__g_iWidgetH, $aInitPos[0], $aInitPos[1], _
    $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))
GUISetBkColor($THEME_BG_MAIN)
_WinAPI_SetLayeredWindowAttributes($gui, 0, _Cfg_GetThemeAlphaMain(), $LWA_ALPHA)

; Left arrow
$lblLeft = GUICtrlCreateLabel(ChrW(9664), 0, 0, $iBtnW, $__g_iWidgetH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblLeft, 9, 400, 0, $THEME_FONT_SYMBOL)
GUICtrlSetColor($lblLeft, $THEME_FG_NORMAL)
GUICtrlSetBkColor($lblLeft, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetCursor($lblLeft, 0)

; Desktop number
$lblNum = GUICtrlCreateLabel(String($iDesktop), $iCenterX, 2, $iCenterW, $__g_iWidgetH * 0.55, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblNum, 13, 700, 0, $THEME_FONT_MAIN)
GUICtrlSetColor($lblNum, $THEME_FG_PRIMARY)
GUICtrlSetBkColor($lblNum, $GUI_BKCOLOR_TRANSPARENT)

; Desktop label
Local $sLabel = _Labels_Load($iDesktop)
$lblName = GUICtrlCreateLabel($sLabel, $iCenterX, $__g_iWidgetH * 0.52, $iCenterW, $__g_iWidgetH * 0.42, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblName, 7, 400, 0, $THEME_FONT_MAIN)
GUICtrlSetColor($lblName, $THEME_FG_LABEL)
GUICtrlSetBkColor($lblName, $GUI_BKCOLOR_TRANSPARENT)

; Right arrow
$lblRight = GUICtrlCreateLabel(ChrW(9654), $__g_iWidgetW - $iBtnW, 0, $iBtnW, $__g_iWidgetH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
GUICtrlSetFont($lblRight, 9, 400, 0, $THEME_FONT_SYMBOL)
GUICtrlSetColor($lblRight, $THEME_FG_NORMAL)
GUICtrlSetBkColor($lblRight, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetCursor($lblRight, 0)

; Color bar — thin accent at bottom showing the current desktop's color
Local $iBarH = _Cfg_GetWidgetColorBarHeight()
$lblColorBar = GUICtrlCreateLabel("", 0, $__g_iWidgetH - $iBarH, $__g_iWidgetW, $iBarH)
_UpdateWidgetColorBar()

; Widget fade-in on startup
If __Theme_ShouldAnimate("widget") Then
    _WinAPI_SetLayeredWindowAttributes($gui, 0, 0, $LWA_ALPHA)
    GUISetState(@SW_SHOW)
    Local $iWStep = _Cfg_GetFadeStep()
    Local $iWSleep = _Cfg_GetFadeSleepMs()
    Local $iWTarget = _Cfg_GetThemeAlphaMain()
    Local $iWS
    For $iWS = 0 To $iWTarget Step $iWStep
        _WinAPI_SetLayeredWindowAttributes($gui, 0, $iWS, $LWA_ALPHA)
        Sleep($iWSleep)
    Next
    _WinAPI_SetLayeredWindowAttributes($gui, 0, $iWTarget, $LWA_ALPHA)
Else
    GUISetState(@SW_SHOW)
EndIf

; Start minimized if autostart flag or config says so
If $bAutoStart Or _Cfg_GetStartMinimized() Then
    GUISetState(@SW_HIDE, $gui)
EndIf

; ---- Register messages ----
GUIRegisterMsg($WM_ACTIVATE, "_WM_ACTIVATE")
GUIRegisterMsg($WM_WINDOWPOSCHANGING, "_WM_POSCHANGING")
GUIRegisterMsg($WM_CTLCOLOREDIT, "_WM_CTLCOLOREDIT_Delegate")

; ---- Register mouse wheel handler if scroll is enabled ----
If _Cfg_GetScrollEnabled() Or _Cfg_GetListScrollEnabled() Then GUIRegisterMsg(0x020A, "_WM_MOUSEWHEEL")

; ---- Event-driven desktop change notification ----
_VD_RegisterNotify($gui, $WM_VD_NOTIFY)
GUIRegisterMsg($WM_VD_NOTIFY, "_WM_DESKTOPCHANGE")

; ---- Register TaskbarCreated message for explorer restart detection ----
Global $__g_iWM_TaskbarCreated = 0
Local $aRegMsg = DllCall("user32.dll", "uint", "RegisterWindowMessageW", "wstr", "TaskbarCreated")
If Not @error And IsArray($aRegMsg) Then
    $__g_iWM_TaskbarCreated = $aRegMsg[0]
    If $__g_iWM_TaskbarCreated <> 0 Then GUIRegisterMsg($__g_iWM_TaskbarCreated, "_WM_TASKBARCREATED")
EndIf

; ---- Periodic tasks (adlib) ----
AdlibRegister("_ForceTopMost", _Cfg_GetTopmostInterval())
AdlibRegister("_AdlibSyncNames", _Cfg_GetNameSyncInterval())
AdlibRegister("_CheckDLLHealth", _Cfg_GetDllCheckInterval())

; ---- Register hotkeys ----
_RegisterHotkeys()

; ---- Tray icon mode (if enabled) ----
If _Cfg_GetTrayIconMode() Then _InitTrayMode()

; ---- Config file watcher (if enabled) ----
If _Cfg_GetConfigWatcherEnabled() Then
    $__g_sCfgFileTime = FileGetTime(_Cfg_GetPath(), 0, 1)
    AdlibRegister("_AdlibConfigWatcher", _Cfg_GetConfigWatcherInterval())
EndIf

; ---- Auto-update checker (if enabled) ----
If _Cfg_GetAutoUpdateEnabled() Then
    AdlibRegister("_UC_AdlibCheck", _Cfg_GetAutoUpdateInterval())
EndIf

; ---- Restore persisted window state ----
Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
If FileExists($sStateFile) Then
    Local $iSavedScroll = Int(IniRead($sStateFile, "State", "scroll_offset", 0))
    If $iSavedScroll > 0 Then _DL_SetScrollOffset($iSavedScroll)
EndIf

; ---- Auto-show pinned desktop list ----
If _Cfg_GetDesktopListPinned() Then
    _DL_Show($iTaskbarY, $iDesktop)
    _Log_Info("Desktop list pinned — auto-showing on startup")
EndIf

; Apply Windows widgets toggle on startup
If _Cfg_GetDisableWinWidgets() Then _ApplyWinWidgetsToggle()

_Log_Info("Startup complete")

; ---- Startup update check (if enabled and enough days have passed) ----
If _Cfg_GetUpdateCheckOnStartup() Then
    Local $sLastCheck = IniRead(_Cfg_GetPath(), "Updates", "_last_check_date", "0")
    Local $iToday = Int(@YEAR & @MON & @MDAY)
    Local $iLast = Int($sLastCheck)
    If $iToday - $iLast >= _Cfg_GetUpdateCheckDays() Then
        IniWrite(_Cfg_GetPath(), "Updates", "_last_check_date", String($iToday))
        _UC_AdlibCheck()
        _Log_Info("Startup update check triggered")
    EndIf
EndIf

; ---- Main loop ----
Global $bRightWasDown = False
Global $bLeftWasDown = False
Global $bMiddleWasDown = False

While 1
    _Theme_CacheFrameState()
    Local $aMsg = GUIGetMsg(1)
    _CheckTrayMessages()
    _ProcessGUIEvents($aMsg[0], $aMsg[1])
    If Not _ProcessMouseInput() Then ContinueLoop
    _ProcessKeyboardInput()
    _ProcessEventFlags()
    Local $bActive = _ProcessHoverAndVisuals()
    _ProcessTimersAndSleep($bActive)
WEnd

; Name:        _ProcessGUIEvents
; Description: Handles GUI messages from all windows (widget, menus, dialogs, color picker)
; Parameters:  $msg - GUI message, $hFrom - source GUI handle
Func _ProcessGUIEvents($msg, $hFrom)
    ; Main GUI events
    If $hFrom = $gui Then
        Switch $msg
            Case $GUI_EVENT_CLOSE
                _Shutdown()
            Case $lblLeft
                _Log_Debug("Click: left arrow (prev desktop)")
                Local $iCount = _VD_GetCount()
                If $iDesktop > 1 Then
                    _VD_GoTo($iDesktop - 1)
                ElseIf _Cfg_GetWrapNavigation() Then
                    _VD_GoTo($iCount)
                EndIf
                Sleep(50)
                _RefreshIndex()
            Case $lblRight
                _Log_Debug("Click: right arrow (next desktop)")
                Local $iCount2 = _VD_GetCount()
                If $iDesktop < $iCount2 Then
                    _VD_GoTo($iDesktop + 1)
                ElseIf _Cfg_GetAutoCreateDesktop() Then
                    If _VD_GetCount() >= _GetDesktopLimit() Then
                        _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
                    Else
                        _VD_CreateDesktop()
                        Sleep(100)
                        If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
                            _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
                        EndIf
                        _VD_GoTo($iDesktop + 1)
                    EndIf
                ElseIf _Cfg_GetWrapNavigation() Then
                    _VD_GoTo(1)
                EndIf
                Sleep(50)
                _RefreshIndex()
            Case $lblNum, $lblName
                If _Cfg_GetQuickAccessEnabled() And $msg = $lblNum And $__g_iClickCount >= 2 Then
                    _Log_Debug("Click: quick-access mode activated")
                    _QuickAccess_Show()
                ElseIf _DL_IsPinned() Then
                    ; Pinned: do nothing — list stays open permanently
                    _Log_Debug("Click: widget number — list is pinned, ignoring")
                ElseIf _DL_IsVisible() Then
                    _Log_Debug("Click: widget number — closing desktop list")
                    _DL_Destroy()
                Else
                    _Log_Debug("Click: widget number — opening desktop list")
                    _DL_ShowTemp($iTaskbarY, $iDesktop)
                EndIf
        EndSwitch
    EndIf

    ; Context menu events
    If _CM_IsVisible() And $hFrom = _CM_GetGUI() Then
        Local $sAction = _CM_HandleClick($msg)
        If $sAction <> "" Then _Log_Debug("Context menu: " & $sAction)
        Switch $sAction
            Case "edit"
                _CM_Destroy()
                $iRenameTarget = $iDesktop
                _RD_Show($iDesktop, $iTaskbarY)
            Case "set_color"
                _DL_ColorPickerShow($iDesktop)
            Case "toggle_list"
                _CM_Destroy()
                _DL_SetPinned(Not _DL_IsPinned(), $iTaskbarY, $iDesktop)
            Case "add"
                _CM_Destroy()
                If _VD_GetCount() >= _GetDesktopLimit() Then
                    _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
                Else
                    _VD_CreateDesktop()
                    Sleep(100)
                    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
                        _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
                    EndIf
                    _RefreshIndex()
                EndIf
            Case "delete"
                _CM_Destroy()
                If _VD_GetCount() <= 1 Then
                    _Theme_Confirm(_i18n("Dialogs.confirm_cannot_delete_title", "Cannot Delete"), _i18n("Dialogs.confirm_cannot_delete_msg", "This is the last desktop."))
                Else
                    Local $sDelCurName = _Labels_Load($iDesktop)
                    Local $sDelCurLabel = "Desktop " & $iDesktop
                    If $sDelCurName <> "" Then $sDelCurLabel &= ' ("' & $sDelCurName & '")'
                    If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm(_i18n_Format("Dialogs.confirm_delete_title", "Delete {1}?", $sDelCurLabel), _
                            _i18n("Dialogs.confirm_delete_msg", "Windows will be moved to an adjacent desktop.")) Then
                        _VD_RemoveDesktop($iDesktop)
                        Sleep(100)
                        If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopDeleted() Then
                            _Theme_Toast(_i18n("Toasts.toast_desktop_deleted", "Desktop deleted"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                        EndIf
                        _RefreshIndex()
                    EndIf
                EndIf
            Case "pin_window"
                _CM_Destroy()
                Local $hFg = WinGetHandle("[ACTIVE]")
                If $hFg <> 0 Then _VD_PinWindow($hFg)
            Case "window_list"
                _CM_Destroy()
                _WL_Toggle($iDesktop)
            Case "settings"
                _CM_Destroy()
                _CD_Show()
            Case "about"
                _CM_Destroy()
                _ShowAbout()
            Case "crash"
                _CM_Destroy()
                ; Intentional crash for testing — user picks crash type
                __TriggerTestCrash()
            Case "quit"
                _Shutdown()
        EndSwitch
    EndIf

    ; Desktop list events
    If _DL_IsVisible() And $hFrom = _DL_GetGUI() Then
        Local $iTarget = _DL_HandleClick($msg)
        If $iTarget = -1 Then
            ; Scroll up arrow clicked
            _DL_ScrollUp($iTaskbarY, $iDesktop)
        ElseIf $iTarget = -2 Then
            ; Scroll down arrow clicked
            _DL_ScrollDown($iTaskbarY, $iDesktop)
        ElseIf $iTarget > 0 Then
            _Log_Debug("Click: desktop list item " & $iTarget & " — switching")
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
        If $sDLAction <> "" Then _Log_Debug("List context menu: " & $sDLAction & " (target=" & $iCtxTarget & ")")
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
                If $hMoveWindowTarget <> 0 Then
                    _VD_MoveWindowToDesktop($hMoveWindowTarget, $iCtxTarget)
                    $hMoveWindowTarget = 0
                EndIf
            Case "add"
                _DL_CtxDestroy()
                If _VD_GetCount() >= _GetDesktopLimit() Then
                    _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
                Else
                    _VD_CreateDesktop()
                    Sleep(100)
                    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
                        _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
                    EndIf
                    _RefreshIndex()
                EndIf
            Case "delete"
                _DL_CtxDestroy()
                If _VD_GetCount() <= 1 Then
                    _Theme_Confirm(_i18n("Dialogs.confirm_cannot_delete_title", "Cannot Delete"), _i18n("Dialogs.confirm_cannot_delete_msg", "This is the last desktop."))
                Else
                    Local $sDelName = _Labels_Load($iCtxTarget)
                    Local $sDelLabel = "Desktop " & $iCtxTarget
                    If $sDelName <> "" Then $sDelLabel &= ' ("' & $sDelName & '")'
                    If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm(_i18n_Format("Dialogs.confirm_delete_title", "Delete {1}?", $sDelLabel), _
                        _i18n("Dialogs.confirm_delete_msg", "Windows will be moved to an adjacent desktop.")) Then
                        _VD_RemoveDesktop($iCtxTarget)
                        Sleep(100)
                        If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopDeleted() Then
                            _Theme_Toast(_i18n("Toasts.toast_desktop_deleted", "Desktop deleted"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                        EndIf
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
            ; Full rebuild to show updated color indicators
            _DL_Destroy()
            _DL_Show($iTaskbarY, $iDesktop)
        EndIf
    EndIf

    ; Window list events
    If _WL_IsVisible() And $hFrom = _WL_GetGUI() Then
        Local $hClickedWnd = _WL_HandleClick($msg)
        If $hClickedWnd <> 0 Then
            ; Single click on a window item — activate it
            WinActivate($hClickedWnd)
        EndIf
    EndIf

    ; Window list context menu events
    If _WL_CtxIsVisible() And $hFrom = _WL_CtxGetGUI() Then
        Local $sWLAction = _WL_CtxHandleClick($msg)
        Local $hWLTarget = _WL_GetCtxTarget()
        If $sWLAction <> "" Then _Log_Debug("WindowList ctx: " & $sWLAction)
        Switch $sWLAction
            Case "send_next"
                Local $iWLNext = $iDesktop + 1
                If $iWLNext > _VD_GetCount() And _Cfg_GetWrapNavigation() Then $iWLNext = 1
                If $iWLNext >= 1 And $iWLNext <= _VD_GetCount() Then
                    _VD_MoveWindowToDesktop($hWLTarget, $iWLNext)
                    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then _Theme_Toast(_i18n_Format("Toasts.toast_window_sent", "Window sent to Desktop {1}", $iWLNext), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                    _WL_Refresh($iDesktop)
                EndIf
            Case "send_prev"
                Local $iWLPrev = $iDesktop - 1
                If $iWLPrev < 1 And _Cfg_GetWrapNavigation() Then $iWLPrev = _VD_GetCount()
                If $iWLPrev >= 1 And $iWLPrev <= _VD_GetCount() Then
                    _VD_MoveWindowToDesktop($hWLTarget, $iWLPrev)
                    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then _Theme_Toast(_i18n_Format("Toasts.toast_window_sent", "Window sent to Desktop {1}", $iWLPrev), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                    _WL_Refresh($iDesktop)
                EndIf
            Case "send_new"
                If _VD_GetCount() < _GetDesktopLimit() Then
                    _VD_CreateDesktop()
                    Sleep(100)
                    Local $iWLNew = _VD_GetCount()
                    _VD_MoveWindowToDesktop($hWLTarget, $iWLNew)
                    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then _Theme_Toast(_i18n_Format("Toasts.toast_window_sent", "Window sent to Desktop {1}", $iWLNew), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                    _WL_Refresh($iDesktop)
                EndIf
            Case "pin"
                If _Cfg_GetPinningEnabled() Then
                    Local $bWasPinnedWL = _VD_IsPinnedWindow($hWLTarget)
                    _VD_TogglePinWindow($hWLTarget)
                    If _Cfg_GetNotificationsEnabled() And Not $bWasPinnedWL And _Cfg_GetNotifyWindowPinned() Then
                        _Theme_Toast(_i18n("Toasts.toast_window_pinned", "Window pinned to all desktops"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                    ElseIf _Cfg_GetNotificationsEnabled() And $bWasPinnedWL And _Cfg_GetNotifyWindowUnpinned() Then
                        _Theme_Toast(_i18n("Toasts.toast_window_unpinned", "Window unpinned"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                    EndIf
                    _WL_Refresh($iDesktop)
                EndIf
            Case "goto"
                Local $iWinDesk = _VD_GetWindowDesktopNumber($hWLTarget)
                If $iWinDesk > 0 And $iWinDesk <> $iDesktop Then
                    _VD_GoTo($iWinDesk)
                    Sleep(50)
                    _RefreshIndex()
                EndIf
            Case "pull"
                _VD_MoveWindowToDesktop($hWLTarget, $iDesktop)
                If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then _Theme_Toast(_i18n_Format("Toasts.toast_window_sent", "Window sent to Desktop {1}", $iDesktop), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                _WL_Refresh($iDesktop)
            Case "minimize"
                WinSetState($hWLTarget, "", @SW_MINIMIZE)
            Case "maximize"
                WinSetState($hWLTarget, "", @SW_MAXIMIZE)
            Case "restore"
                WinSetState($hWLTarget, "", @SW_RESTORE)
            Case "close"
                WinClose($hWLTarget)
                Sleep(200)
                _WL_Refresh($iDesktop)
        EndSwitch
        _WL_CtxDestroy()
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
EndFunc

; Name:        _ProcessMouseInput
; Description: Handles raw mouse button state for right-click, middle-click, left-click/drag
; Return:      False if the main loop should ContinueLoop, True otherwise
Func _ProcessMouseInput()
    ; Right-click detection
    Local $rBtn = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_RBUTTON)
    If @error Or Not IsArray($rBtn) Then Return False
    Local $bRightDown = (BitAND($rBtn[0], $VK_KEYDOWN) <> 0)

    If $bRightWasDown And Not $bRightDown Then
        ; Right-click during drag -> cancel drag
        If _DL_IsDragging() Then
            _DL_DragCancel($iDesktop)
        Else
            Local $aWinPos = WinGetPos($gui)

            ; Right-click over main widget -> toggle widget context menu
            If $__g_Theme_iCachedCursorX >= $aWinPos[0] And $__g_Theme_iCachedCursorX < $aWinPos[0] + $aWinPos[2] And _
               $__g_Theme_iCachedCursorY >= $aWinPos[1] And $__g_Theme_iCachedCursorY < $aWinPos[1] + $aWinPos[3] Then
                _DL_CtxDestroy()
                If _CM_IsVisible() Then
                    _Log_Debug("Click: right-click — closing context menu")
                    _CM_Destroy()
                Else
                    _Log_Debug("Click: right-click — opening context menu")
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
                        ; Use last tracked external window for Move Window Here
                        $hMoveWindowTarget = $hLastExternalWindow
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
    Local $mBtn = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_MBUTTON)
    If @error Or Not IsArray($mBtn) Then Return False
    Local $bMiddleDown = (BitAND($mBtn[0], $VK_KEYDOWN) <> 0)

    If $bMiddleWasDown And Not $bMiddleDown Then
        If _Cfg_GetMiddleClickDelete() And _DL_IsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()) Then
            Local $iMiddleClickRow = _DL_GetItemAtPos()
            If $iMiddleClickRow > 0 Then
                If _VD_GetCount() <= 1 Then
                    _Theme_Confirm(_i18n("Dialogs.confirm_cannot_delete_title", "Cannot Delete"), _i18n("Dialogs.confirm_cannot_delete_msg", "This is the last desktop."))
                Else
                    Local $sDelMCName = _Labels_Load($iMiddleClickRow)
                    Local $sDelMCLabel = "Desktop " & $iMiddleClickRow
                    If $sDelMCName <> "" Then $sDelMCLabel &= ' ("' & $sDelMCName & '")'
                    If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm(_i18n_Format("Dialogs.confirm_delete_title", "Delete {1}?", $sDelMCLabel), _
                        _i18n("Dialogs.confirm_delete_msg", "Windows will be moved to an adjacent desktop.")) Then
                        _VD_RemoveDesktop($iMiddleClickRow)
                        Sleep(100)
                        If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopDeleted() Then
                            _Theme_Toast(_i18n("Toasts.toast_desktop_deleted", "Desktop deleted"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                        EndIf
                        _RefreshIndex()
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf
    $bMiddleWasDown = $bMiddleDown

    ; Left-click drag detection for desktop list + triple-click + widget drag
    Local $lBtn = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_LBUTTON)
    If @error Or Not IsArray($lBtn) Then Return False
    Local $bLeftDown = (BitAND($lBtn[0], $VK_KEYDOWN) <> 0)

    If $bLeftDown And Not $bLeftWasDown Then
        ; Track click count for triple-click
        If TimerDiff($__g_hClickTimer) < $TRIPLE_CLICK_MS Then
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
                $__g_iWidgetDragOffsetX = $__g_Theme_iCachedCursorX - $aWPDrag[0]
                $__g_iWidgetDragStartX = $__g_Theme_iCachedCursorX
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
        If Abs($__g_Theme_iCachedCursorX - $__g_iWidgetDragStartX) >= 5 Then
            $__g_bWidgetDragging = True
        EndIf
    EndIf

    If $bLeftDown And $__g_bWidgetDragging Then
        Local $iNewX = $__g_Theme_iCachedCursorX - $__g_iWidgetDragOffsetX
        ; Clamp to screen bounds
        If $iNewX < 0 Then $iNewX = 0
        If $iNewX + $__g_iWidgetW > @DesktopWidth Then $iNewX = @DesktopWidth - $__g_iWidgetW
        WinMove($gui, "", $iNewX, $iTaskbarY + 2)
    EndIf

    ; LMB released
    If Not $bLeftDown And $bLeftWasDown Then
        ; Widget drag end
        If $__g_bWidgetDragging Then
            ; On drag release, determine anchor from final position
            Local $aFinalPos = WinGetPos($gui)
            Local $iFinalX = $aFinalPos[0]
            Local $iFinalY = $aFinalPos[1]
            Local $iScreenW = @DesktopWidth
            Local $iScreenH = @DesktopHeight
            Local $iThirdX = $iScreenW / 3
            Local $iThirdY = $iScreenH / 3
            ; Determine vertical zone
            Local $sV = "bottom"
            If $iFinalY < $iThirdY Then
                $sV = "top"
            ElseIf $iFinalY < $iThirdY * 2 Then
                $sV = "middle"
            EndIf
            ; Determine horizontal zone
            Local $sH = "left"
            If $iFinalX > $iThirdX * 2 Then
                $sH = "right"
            ElseIf $iFinalX > $iThirdX Then
                $sH = "center"
            EndIf
            ; middle-center is not a valid anchor — snap to bottom-center
            Local $sAnchor = $sV & "-" & $sH
            If $sAnchor = "middle-center" Then $sAnchor = "bottom-center"
            _Cfg_SetWidgetPosition($sAnchor)
            ; Compute offsets relative to the new anchor
            Local $aRef = __CalcWidgetXY() ; recalc with offsets=0 would be ideal, but we already set the anchor
            _Cfg_SetWidgetOffsetX(0)
            _Cfg_SetWidgetOffsetY(0)
            Local $aBase = __CalcWidgetXY()
            _Cfg_SetWidgetOffsetX($iFinalX - $aBase[0])
            _Cfg_SetWidgetOffsetY($iFinalY - $aBase[1])
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
        Local $retEscDrag = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_ESCAPE)
        If Not @error And IsArray($retEscDrag) And BitAND($retEscDrag[0], $VK_KEYDOWN) <> 0 Then
            _DL_DragCancel($iDesktop)
        EndIf
    EndIf

    $bLeftWasDown = $bLeftDown

    Return True
EndFunc

; Name:        _ProcessKeyboardInput
; Description: Handles keyboard navigation, quick-access, and escape-cancel during drag
Func _ProcessKeyboardInput()
    ; Keyboard navigation in desktop list
    If _Cfg_GetListKeyboardNav() And _DL_IsVisible() And Not _DL_IsDragging() Then
        Local $retUp = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_UP)
        If Not @error And IsArray($retUp) And BitAND($retUp[0], 0x0001) <> 0 Then
            If $iDesktop > 1 Then
                _VD_GoTo($iDesktop - 1)
                Sleep(50)
                _RefreshIndex()
            EndIf
        EndIf
        Local $retDown = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_DOWN)
        If Not @error And IsArray($retDown) And BitAND($retDown[0], 0x0001) <> 0 Then
            If $iDesktop < _VD_GetCount() Then
                _VD_GoTo($iDesktop + 1)
                Sleep(50)
                _RefreshIndex()
            EndIf
        EndIf
    EndIf

    ; Quick-access number input polling
    If $__g_bQuickAccessActive Then _QuickAccess_Check()
EndFunc

; Name:        _ProcessEventFlags
; Description: Processes event-driven flags (desktop change, name sync, explorer recovery)
Func _ProcessEventFlags()
    ; Explorer crash notification
    If _EM_CheckCrash() And _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyExplorerCrash() Then
        _Theme_Toast(_i18n("Toasts.toast_explorer_crashed", "Shell process crashed"), 0, $iTaskbarY + $iTaskbarH + 4, 3000, $TOAST_ERROR)
    EndIf

    ; Explorer crash recovery
    If _EM_CheckRecovery() Then
        _Log_Info("Explorer recovery: reinitializing")
        _VD_Init()
        ; Re-register desktop change hook
        _VD_RegisterNotify($gui, $WM_VD_NOTIFY)
        ; Show notification
        If _Cfg_GetNotificationsEnabled() And (_Cfg_GetExplorerNotifyRecovery() Or _Cfg_GetNotifyExplorerRecovery()) Then
            _Theme_Toast(_i18n("Toasts.toast_explorer_recovered", "Explorer recovered — reinitializing"), 0, $iTaskbarY + $iTaskbarH + 4, 3000, $TOAST_WARNING)
        EndIf
    EndIf

    ; Event-driven desktop change (flag set by _WM_DESKTOPCHANGE)
    If $bDesktopChanged And Not _Peek_IsActive() Then
        $bDesktopChanged = False
        _RefreshIndex()
    EndIf

    ; Event-driven name sync (flag set by _AdlibSyncNames)
    If $bNamesChanged Then
        $bNamesChanged = False
        _ApplyDesktopChange()
    EndIf

    ; Track last external foreground window (for Move Window Here) — debounced to 200ms
    If TimerDiff($__g_hFgTrackTimer) >= 200 Then
        $__g_hFgTrackTimer = TimerInit()
        Local $hFg = WinGetHandle("[ACTIVE]")
        If $hFg <> 0 And $hFg <> $gui And (Not _DL_IsVisible() Or $hFg <> _DL_GetGUI()) And _
           (Not _CM_IsVisible() Or $hFg <> _CM_GetGUI()) And _
           (Not _DL_CtxIsVisible() Or $hFg <> _DL_CtxGetGUI()) And _
           (Not _RD_IsVisible() Or $hFg <> _RD_GetGUI()) And _
           (Not _CD_IsVisible() Or $hFg <> _CD_GetGUI()) Then
            $hLastExternalWindow = $hFg
        EndIf
    EndIf
EndFunc

; Name:        _ProcessHoverAndVisuals
; Description: Handles cursor tracking, hover effects, peek indicator, hover clear
; Return:      True if cursor is over any of our windows (for sleep decision)
Func _ProcessHoverAndVisuals()
    ; Lazy hover check: skip when cursor hasn't moved and no state changed
    Local $bCursorMoved = ($__g_Theme_iCachedCursorX <> $__g_iLastCursorX Or $__g_Theme_iCachedCursorY <> $__g_iLastCursorY)
    If $bCursorMoved Then
        $__g_iLastCursorX = $__g_Theme_iCachedCursorX
        $__g_iLastCursorY = $__g_Theme_iCachedCursorY
    EndIf

    ; Skip all hit-testing when nothing changed (cursor still, no events, no drag)
    Local $bStateChanged = ($bCursorMoved Or _DL_IsDragging() Or $bDesktopChanged Or $bNamesChanged)
    If Not $bStateChanged And Not $__g_bWasCursorActive Then Return False

    ; Single-pass hit-test: determine which window (if any) the cursor is over
    Local $bOverWidget = _Theme_IsCursorOverWindow($gui)
    Local $bOverDL = (_DL_IsVisible() And _Theme_IsCursorOverWindow(_DL_GetGUI()))
    Local $bOverCM = (_CM_IsVisible() And _Theme_IsCursorOverWindow(_CM_GetGUI()))
    Local $bOverCtx = (_DL_CtxIsVisible() And _Theme_IsCursorOverWindow(_DL_CtxGetGUI()))
    Local $bOverCP = (_DL_ColorPickerIsVisible() And _Theme_IsCursorOverWindow(_DL_ColorPickerGetGUI()))
    Local $bOverRD = (_RD_IsVisible() And _Theme_IsCursorOverWindow(_RD_GetGUI()))
    Local $bOverThumb = (_DL_ThumbIsVisible() And _Theme_IsCursorOverWindow(_DL_ThumbGetGUI()))
    Local $bOverWL = (_WL_IsVisible() And _Theme_IsCursorOverWindow(_WL_GetGUI()))
    Local $bOverWLCtx = (_WL_CtxIsVisible() And _Theme_IsCursorOverWindow(_WL_CtxGetGUI()))
    Local $bCursorActive = ($bOverWidget Or $bOverDL Or $bOverCM Or $bOverCtx Or $bOverCP Or $bOverRD Or $bOverThumb Or $bOverWL Or $bOverWLCtx)

    ; Hover effects — reuse hit-test results (no redundant WinGetPos calls)
    If $bCursorActive And $bStateChanged Then
        If $bOverWidget Then _CheckHover()
        If _DL_IsVisible() Then _DL_CheckHover($iDesktop) ; always call — clears hover via @error when cursor not over list
        If $bOverCM Then _CM_CheckHover()
        If $bOverCtx Then _DL_CtxCheckHover()
        If $bOverCP Then _DL_ColorPickerCheckHover()
        If $bOverRD Then _RD_CheckHover()
        If $bOverWL Then _WL_CheckHover()
        If $bOverWLCtx Then _WL_CtxCheckHover()
    EndIf

    ; Clear hover states when cursor leaves all windows (prevents stuck highlights)
    If $__g_bWasCursorActive And Not $bCursorActive Then
        If $bHoverLeft Then
            _Theme_RemoveHover($lblLeft, $THEME_FG_NORMAL)
            $bHoverLeft = False
        EndIf
        If $bHoverRight Then
            _Theme_RemoveHover($lblRight, $THEME_FG_NORMAL)
            $bHoverRight = False
        EndIf
        If _DL_IsVisible() Then _DL_CheckHover($iDesktop)
    EndIf
    $__g_bWasCursorActive = $bCursorActive

    Return $bCursorActive
EndFunc

; Name:        _ProcessTimersAndSleep
; Description: Handles toast, update check, peek bounce, auto-hide, and dynamic sleep
; Parameters:  $bCursorActive - whether cursor is over any window
Func _ProcessTimersAndSleep($bCursorActive)
    ; Toast fade-out tick
    _Theme_ToastTick()

    ; Themed tooltip auto-dismiss
    _Theme_TooltipTick()

    ; Check non-blocking update download result (rate-limited)
    If TimerDiff($__g_hUpdatePollTimer) >= _Cfg_GetUpdatePollInterval() Then
        _UC_CheckResult()
        $__g_hUpdatePollTimer = TimerInit()
    EndIf

    ; Peek bounce-back
    _Peek_CheckBounce()

    ; Peek visual indicator on widget (only update on state change to avoid flicker)
    Local $bPeekNow = _Peek_IsActive()
    If $bPeekNow <> $__g_bPeekWasActive Then
        If $bPeekNow Then
            GUICtrlSetColor($lblNum, $THEME_FG_LINK)
        Else
            GUICtrlSetColor($lblNum, $THEME_FG_PRIMARY)
        EndIf
        $__g_bPeekWasActive = $bPeekNow
    EndIf

    ; Wallpaper debounce tick
    _WP_Tick()

    ; Auto-hide temp list and context menus
    _DL_CheckAutoHide($gui)
    _CM_CheckAutoHide($gui)
    _DL_CtxCheckAutoHide()

    ; Window list auto-hide, auto-refresh, search polling
    If _WL_IsVisible() Then
        _WL_CheckAutoHide($gui)
        _WL_CheckAutoRefresh($iDesktop)
        _WL_CheckSearchInput()
    EndIf
    _WL_CtxCheckAutoHide()

    ; Dynamic sleep: responsive when interactive, lightweight when idle
    ; 3 tiers: active hover (5ms), popups visible (15ms), fully idle (100ms)
    If $bCursorActive Then
        Sleep(5)
    ElseIf _DL_IsVisible() Or _CM_IsVisible() Or _DL_CtxIsVisible() Or _DL_ColorPickerIsVisible() Then
        Sleep(15)
    Else
        Sleep(100)
    EndIf
EndFunc

; =============================================
; MAIN HELPERS
; =============================================

; Name:        _UpdateWidgetColorBar
; Description: Shows/hides the thin color accent at the bottom of the widget
Func _UpdateWidgetColorBar()
    If Not _Cfg_GetWidgetColorBar() Or Not _Cfg_GetDesktopColorsEnabled() Then
        GUICtrlSetBkColor($lblColorBar, $THEME_BG_MAIN)
        Return
    EndIf
    Local $iColor = _Cfg_GetDesktopColor($iDesktop)
    If $iColor = 0 Then
        GUICtrlSetBkColor($lblColorBar, $THEME_BG_MAIN)
    Else
        GUICtrlSetBkColor($lblColorBar, $iColor)
    EndIf
EndFunc

; Name:        _ApplyDesktopChange
; Description: Updates widget display labels and list after desktop change
Func _ApplyDesktopChange()
    ; Lock window to batch all updates into a single repaint (prevents flicker)
    DllCall("user32.dll", "bool", "LockWindowUpdate", "hwnd", $gui)

    If _Cfg_GetShowCount() Then
        Local $iTotal = _VD_GetCount()
        GUICtrlSetData($lblNum, String($iDesktop) & "/" & String($iTotal))
        GUICtrlSetFont($lblNum, _Cfg_GetCountFontSize(), 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetData($lblNum, String($iDesktop))
        GUICtrlSetFont($lblNum, 13, 700, 0, $THEME_FONT_MAIN)
    EndIf
    GUICtrlSetData($lblName, _Labels_Load($iDesktop))
    _UpdateWidgetColorBar()
    WinSetTitle($gui, "", String($iDesktop))

    ; Unlock — triggers a single repaint with all changes applied
    DllCall("user32.dll", "bool", "LockWindowUpdate", "hwnd", 0)
    _DL_Refresh($iTaskbarY, $iDesktop)
    If $__g_bTrayMode Then TraySetToolTip(_i18n_Format("Tray.tray_tooltip", "Desk Switcheroo - Desktop {1}", $iDesktop))
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

    ; Apply Windows widgets toggle (Win11 taskbar widgets button)
    _ApplyWinWidgetsToggle()

    ; Handle tray mode toggle
    Local $bNewTrayMode = _Cfg_GetTrayIconMode()
    If $bNewTrayMode And Not $__g_bTrayMode Then
        _InitTrayMode()
    ElseIf Not $bNewTrayMode And $__g_bTrayMode Then
        ; Disable tray mode: show widget, hide tray
        $__g_bTrayMode = False
        Opt("TrayIconHide", 1)
        GUISetState(@SW_SHOW, $gui)
        AdlibRegister("_ForceTopMost", _Cfg_GetTopmostInterval())
    EndIf

    ; Update config watcher
    AdlibUnRegister("_AdlibConfigWatcher")
    If _Cfg_GetConfigWatcherEnabled() Then
        $__g_sCfgFileTime = FileGetTime(_Cfg_GetPath(), 0, 1)
        AdlibRegister("_AdlibConfigWatcher", _Cfg_GetConfigWatcherInterval())
    EndIf

    ; Update auto-update checker
    AdlibUnRegister("_UC_AdlibCheck")
    If _Cfg_GetAutoUpdateEnabled() Then
        AdlibRegister("_UC_AdlibCheck", _Cfg_GetAutoUpdateInterval())
    EndIf

    ; Refresh display (count format, label, list)
    _ApplyDesktopChange()

    ; Rebuild desktop list to apply scroll/font/color changes immediately
    If _DL_IsVisible() Then
        _DL_Destroy()
        _DL_Show($iTaskbarY, $iDesktop)
    EndIf

    ; Re-register scroll wheel handler (unregister first to avoid duplicates)
    GUIRegisterMsg(0x020A, "")
    If _Cfg_GetScrollEnabled() Or _Cfg_GetListScrollEnabled() Then
        GUIRegisterMsg(0x020A, "_WM_MOUSEWHEEL")
    EndIf

    ; Force reposition with new widget position/offset
    _ForceTopMost()
EndFunc

; Name:        _RefreshIndex
; Description: Gets current desktop from OS, tracks previous desktop, auto-focuses, and updates display
Func _RefreshIndex()
    Local $iOld = $iDesktop
    $iDesktop = _VD_GetCurrent()
    If $iDesktop <> $iOld Then
        _Log_Debug("Desktop changed: " & $iOld & " -> " & $iDesktop)
        If $iOld > 0 Then $iPrevDesktop = $iOld
        If _Cfg_GetAutoFocusAfterSwitch() Then _AutoFocusTopWindow()
        _WP_OnDesktopChanged($iDesktop)
        If _WL_IsVisible() Then _WL_Refresh($iDesktop)
    EndIf
    _ApplyDesktopChange()
    _ForceTopMost()
EndFunc

; Name:        _GetDesktopLimit
; Description: Returns the effective desktop limit (config max_desktops, or hard cap if 0/unlimited)
; Return:      Integer limit
Func _GetDesktopLimit()
    Local $iMax = _Cfg_GetMaxDesktops()
    If $iMax <= 0 Then Return $DESKTOP_LIMIT_HARD
    Return $iMax
EndFunc

; Name:        _ApplyWinWidgetsToggle
; Description: Hides or shows the Windows 11 Widgets button on the taskbar
;              via the TaskbarDa registry key. Requires explorer refresh to take effect.
Func _ApplyWinWidgetsToggle()
    Local $sKey = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    If _Cfg_GetDisableWinWidgets() Then
        RegWrite($sKey, "TaskbarDa", "REG_DWORD", 0)
        _Log_Debug("Windows widgets: disabled (TaskbarDa=0)")
    Else
        RegWrite($sKey, "TaskbarDa", "REG_DWORD", 1)
        _Log_Debug("Windows widgets: enabled (TaskbarDa=1)")
    EndIf
EndFunc

; Name:        _AutoFocusTopWindow
; Description: Activates the topmost visible, non-minimized window on the current desktop
Func _AutoFocusTopWindow()
    Local $aWindows = _VD_EnumWindowsOnDesktop($iDesktop)
    If Not IsArray($aWindows) Or $aWindows[0] = 0 Then Return
    Local $i
    For $i = 1 To $aWindows[0]
        Local $hW = $aWindows[$i]
        Local $iState = WinGetState($hW)
        If $iState <> 0 And BitAND($iState, 16) = 0 Then ; visible and not minimized
            WinActivate($hW)
            Return
        EndIf
    Next
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
    Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_ESCAPE)
    If Not @error And IsArray($retEsc) And BitAND($retEsc[0], $VK_KEYDOWN) <> 0 Then
        _QuickAccess_Cancel()
        Return
    EndIf

    ; Check 3s timeout
    If TimerDiff($__g_hQuickAccessTimer) > $QUICK_ACCESS_TIMEOUT Then
        _QuickAccess_Cancel()
        Return
    EndIf

    ; Poll VK_1 through VK_9
    Local $i
    For $i = $VK_1 To $VK_9
        Local $retKey = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $i)
        If Not @error And IsArray($retKey) And BitAND($retKey[0], $VK_KEYDOWN) <> 0 Then
            Local $iTarget = $i - $VK_1 + 1
            $__g_bQuickAccessActive = False
            If $iTarget > _VD_GetCount() Then
                _QuickAccess_Cancel()
                Return
            EndIf
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

; Name:        _WM_DESKTOPCHANGE
; Description: WM handler for VD desktop change notification
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      $GUI_RUNDEFMSG
Func _WM_DESKTOPCHANGE($hWnd, $iMsg, $wParam, $lParam)
    _VD_InvalidateCountCache()
    $bDesktopChanged = True  ; Always set flag; main loop checks peek state
    Return $GUI_RUNDEFMSG
EndFunc

; Name:        _WM_TASKBARCREATED
; Description: WM handler for explorer.exe restart (TaskbarCreated broadcast)
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      $GUI_RUNDEFMSG
Func _WM_TASKBARCREATED($hWnd, $iMsg, $wParam, $lParam)
    _Log_Info("WM_TASKBARCREATED received — explorer restarted")
    $__g_EM_bRecoveryPending = True
    Return $GUI_RUNDEFMSG
EndFunc

; Name:        _AdlibSyncNames
; Description: Periodic callback to sync OS desktop names
Func _AdlibSyncNames()
    If _Peek_IsActive() Then Return
    If _Labels_SyncFromOS() Then $bNamesChanged = True
EndFunc

; Update checker functions extracted to includes\UpdateChecker.au3
; (_UC_AdlibCheck, _UC_CheckResult, _UC_CheckNow, _UC_DownloadPortable)

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

; Name:        __ScrollNavigate
; Description: Navigate to adjacent desktop with optional wrap
; Parameters:  $iDirection - +1 for next, -1 for prev
;              $bWrap - whether to wrap at ends
Func __ScrollNavigate($iDirection, $bWrap)
    Local $iCount = _VD_GetCount()
    Local $iNew = $iDesktop + $iDirection
    If $iNew < 1 Then
        If Not $bWrap Then Return
        $iNew = $iCount
    ElseIf $iNew > $iCount Then
        If Not $bWrap Then Return
        $iNew = 1
    EndIf
    _VD_GoTo($iNew)
    Sleep(50)
    _RefreshIndex()
EndFunc

; Name:        _WM_MOUSEWHEEL
; Description: WM handler for mouse scroll wheel events on widget and list
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      0 if handled, $GUI_RUNDEFMSG otherwise
Func _WM_MOUSEWHEEL($hWnd, $iMsg, $wParam, $lParam)
    Local $iDelta = BitShift(BitAND($wParam, 0xFFFF0000), 16)
    ; Convert to signed
    If $iDelta > 32767 Then $iDelta -= 65536

    ; Check if scroll is over the desktop list
    If _DL_IsVisible() And $hWnd = _DL_GetGUI() Then
        If Not _Cfg_GetListScrollEnabled() Then Return $GUI_RUNDEFMSG

        ; "scroll" action scrolls the list view, "switch" switches desktops
        If _Cfg_GetListScrollAction() = "scroll" Then
            If $iDelta > 0 Then
                _DL_ScrollUp($iTaskbarY, $iDesktop)
            Else
                _DL_ScrollDown($iTaskbarY, $iDesktop)
            EndIf
            Return 0
        EndIf

        Local $iDir = ($iDelta > 0) ? -1 : 1
        If _Cfg_GetScrollDirection() = "inverted" Then $iDir = -$iDir
        __ScrollNavigate($iDir, _Cfg_GetScrollWrap())
        Return 0
    EndIf

    ; Check if scroll is over the main widget
    If $hWnd = $gui Then
        If Not _Cfg_GetScrollEnabled() Then Return $GUI_RUNDEFMSG

        Local $iDir2 = ($iDelta > 0) ? -1 : 1
        If _Cfg_GetScrollDirection() = "inverted" Then $iDir2 = -$iDir2
        __ScrollNavigate($iDir2, _Cfg_GetScrollWrap())
        Return 0
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; =============================================
; TOPMOST ENFORCEMENT
; =============================================

; Name:        __CalcWidgetXY
; Description: Calculates widget X,Y position based on anchor setting + offsets.
; Return:      2-element array [X, Y]
Func __CalcWidgetXY()
    Local $sAnchor = _Cfg_GetWidgetPosition()
    Local $iOX = _Cfg_GetWidgetOffsetX()
    Local $iOY = _Cfg_GetWidgetOffsetY()
    Local $iSW = @DesktopWidth
    Local $iSH = @DesktopHeight
    Local $iWW = $__g_iWidgetW
    Local $iWH = $__g_iWidgetH
    Local $aXY[2] = [0, $iTaskbarY + 2]

    ; Legacy compat
    If $sAnchor = "left" Then $sAnchor = "bottom-left"
    If $sAnchor = "center" Then $sAnchor = "bottom-center"
    If $sAnchor = "right" Then $sAnchor = "bottom-right"

    Switch $sAnchor
        Case "bottom-left"
            $aXY[0] = $iOX
            $aXY[1] = $iTaskbarY + 2 + $iOY
        Case "bottom-center"
            $aXY[0] = ($iSW / 2) - ($iWW / 2) + $iOX
            $aXY[1] = $iTaskbarY + 2 + $iOY
        Case "bottom-right"
            $aXY[0] = $iSW - $iWW + $iOX
            $aXY[1] = $iTaskbarY + 2 + $iOY
        Case "middle-left"
            $aXY[0] = $iOX
            $aXY[1] = ($iSH / 2) - ($iWH / 2) + $iOY
        Case "middle-right"
            $aXY[0] = $iSW - $iWW + $iOX
            $aXY[1] = ($iSH / 2) - ($iWH / 2) + $iOY
        Case "top-left"
            $aXY[0] = $iOX
            $aXY[1] = $iOY
        Case "top-center"
            $aXY[0] = ($iSW / 2) - ($iWW / 2) + $iOX
            $aXY[1] = $iOY
        Case "top-right"
            $aXY[0] = $iSW - $iWW + $iOX
            $aXY[1] = $iOY
        Case Else
            $aXY[0] = $iOX
            $aXY[1] = $iTaskbarY + 2 + $iOY
    EndSwitch
    Return $aXY
EndFunc

; Name:        _ForceTopMost
; Description: Taskbar tracking and topmost enforcement for the widget
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
        Local $aPos = __CalcWidgetXY()
        DllCall("user32.dll", "bool", "SetWindowPos", _
            "hwnd", $gui, "hwnd", $HWND_TOPMOST, _
            "int", $aPos[0], "int", $aPos[1], _
            "int", $__g_iWidgetW, "int", $__g_iWidgetH, _
            "uint", BitOR($SWP_NOACTIVATE, $SWP_SHOWWINDOW))
    EndIf

    ; Always verify TOPMOST style bit - other windows can steal it
    Local $iStyle = _WinAPI_GetWindowLong($gui, $GWL_EXSTYLE)
    If BitAND($iStyle, $WS_EX_TOPMOST) = 0 Then
        _WinAPI_SetWindowLong($gui, $GWL_EXSTYLE, BitOR($iStyle, $WS_EX_TOPMOST))
        Local $aPos2 = __CalcWidgetXY()
        DllCall("user32.dll", "bool", "SetWindowPos", _
            "hwnd", $gui, "hwnd", $HWND_TOPMOST, _
            "int", $aPos2[0], "int", $aPos2[1], _
            "int", $__g_iWidgetW, "int", $__g_iWidgetH, _
            "uint", BitOR($SWP_NOACTIVATE, $SWP_SHOWWINDOW))
    EndIf
EndFunc

; Name:        _WM_ACTIVATE
; Description: WM handler for window activation; re-enforces topmost
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      $GUI_RUNDEFMSG
Func _WM_ACTIVATE($hWnd, $iMsg, $wParam, $lParam)
    _ForceTopMost()
    Return $GUI_RUNDEFMSG
EndFunc

; Name:        _WM_POSCHANGING
; Description: WM handler for window position changes; forces topmost z-order
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      $GUI_RUNDEFMSG
Func _WM_POSCHANGING($hWnd, $iMsg, $wParam, $lParam)
    Local $tPos = DllStructCreate("uint;uint;int;int;int;int;uint", $lParam)
    DllStructSetData($tPos, 2, $HWND_TOPMOST)
    Return $GUI_RUNDEFMSG
EndFunc

; Name:        _WM_CTLCOLOREDIT_Delegate
; Description: Delegates WM_CTLCOLOREDIT to rename dialog for dark input styling
; Parameters:  $hWnd, $iMsg, $wParam, $lParam - standard Windows message params
; Return:      Brush handle from _RD_WM_CTLCOLOREDIT
Func _WM_CTLCOLOREDIT_Delegate($hWnd, $iMsg, $wParam, $lParam)
    Return _RD_WM_CTLCOLOREDIT($hWnd, $iMsg, $wParam, $lParam)
EndFunc

; =============================================
; HOTKEY REGISTRATION
; =============================================

; Name:        _RegisterHotkeys
; Description: Registers all configured global hotkeys
Func _RegisterHotkeys()
    If Not _Cfg_GetHotkeysEnabled() Then Return
    Local $sKey, $i, $iRet
    $sKey = _Cfg_GetHotkeyNext()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_Next")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (next)")
    EndIf
    $sKey = _Cfg_GetHotkeyPrev()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_Prev")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (prev)")
    EndIf
    For $i = 1 To 9
        $sKey = _Cfg_GetHotkeyDesktop($i)
        If $sKey <> "" Then
            $iRet = HotKeySet($sKey, "_HK_Desktop" & $i)
            If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (desktop " & $i & ")")
        EndIf
    Next
    $sKey = _Cfg_GetHotkeyToggleList()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_ToggleList")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (toggle list)")
    EndIf
    $sKey = _Cfg_GetHotkeyToggleLast()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_ToggleLast")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (toggle last)")
    EndIf
    $sKey = _Cfg_GetHotkeyMoveFollowNext()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_MoveFollowNext")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (move+follow next)")
    EndIf
    $sKey = _Cfg_GetHotkeyMoveFollowPrev()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_MoveFollowPrev")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (move+follow prev)")
    EndIf
    $sKey = _Cfg_GetHotkeyMoveNext()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_MoveNext")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (move next)")
    EndIf
    $sKey = _Cfg_GetHotkeyMovePrev()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_MovePrev")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (move prev)")
    EndIf
    $sKey = _Cfg_GetHotkeySendNewDesktop()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_SendNewDesktop")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (send new desktop)")
    EndIf
    $sKey = _Cfg_GetHotkeyPinWindow()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_PinWindow")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (pin window)")
    EndIf
    $sKey = _Cfg_GetHotkeyToggleWindowList()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_ToggleWindowList")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (toggle window list)")
    EndIf
    $sKey = _Cfg_GetHotkeyOpenSettings()
    If $sKey <> "" Then
        If HotKeySet($sKey, "_HK_OpenSettings") = 0 Then _Log_Warn("Hotkey failed: " & $sKey & " (settings)")
    EndIf
    $sKey = _Cfg_GetHotkeyAddDesktop()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_AddDesktop")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (add desktop)")
    EndIf
    $sKey = _Cfg_GetHotkeyDeleteDesktop()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_DeleteDesktop")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (delete desktop)")
    EndIf
    $sKey = _Cfg_GetHotkeyRenameDesktop()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_RenameDesktop")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (rename desktop)")
    EndIf
    $sKey = _Cfg_GetHotkeyCloseWindow()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_CloseWindow")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (close window)")
    EndIf
    $sKey = _Cfg_GetHotkeyMinimizeWindow()
    If $sKey <> "" Then
        $iRet = HotKeySet($sKey, "_HK_MinimizeWindow")
        If $iRet = 0 Then _Log_Warn("Hotkey registration failed: " & $sKey & " (minimize window)")
    EndIf
EndFunc

; Name:        _UnregisterHotkeys
; Description: Unregisters all global hotkeys
Func _UnregisterHotkeys()
    Local $sKey, $i
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
    $sKey = _Cfg_GetHotkeyToggleLast()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyMoveFollowNext()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyMoveFollowPrev()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyMoveNext()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyMovePrev()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeySendNewDesktop()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyPinWindow()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyToggleWindowList()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyOpenSettings()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyAddDesktop()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyDeleteDesktop()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyRenameDesktop()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyCloseWindow()
    If $sKey <> "" Then HotKeySet($sKey)
    $sKey = _Cfg_GetHotkeyMinimizeWindow()
    If $sKey <> "" Then HotKeySet($sKey)
EndFunc

; Name:        _HK_Next
; Description: Hotkey callback to switch to next desktop (with wrap/auto-create)
Func _HK_Next()
    Local $iCount = _VD_GetCount()
    If $iDesktop < $iCount Then
        _VD_GoTo($iDesktop + 1)
    ElseIf _Cfg_GetAutoCreateDesktop() Then
        If _VD_GetCount() >= _GetDesktopLimit() Then
            _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
        Else
            _VD_CreateDesktop()
            Sleep(100)
            If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
                _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
            EndIf
            _VD_GoTo($iDesktop + 1)
        EndIf
    ElseIf _Cfg_GetWrapNavigation() Then
        _VD_GoTo(1)
    EndIf
    Sleep(50)
    _RefreshIndex()
EndFunc

; Name:        _HK_Prev
; Description: Hotkey callback to switch to previous desktop (with wrap)
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

; Name:        _HK_Desktop1 through _HK_Desktop9
; Description: Hotkey callbacks to switch directly to desktop 1-9
Func _HK_Desktop1()
    If 1 <= _VD_GetCount() Then
        _VD_GoTo(1)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop2()
    If 2 <= _VD_GetCount() Then
        _VD_GoTo(2)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop3()
    If 3 <= _VD_GetCount() Then
        _VD_GoTo(3)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop4()
    If 4 <= _VD_GetCount() Then
        _VD_GoTo(4)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop5()
    If 5 <= _VD_GetCount() Then
        _VD_GoTo(5)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop6()
    If 6 <= _VD_GetCount() Then
        _VD_GoTo(6)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop7()
    If 7 <= _VD_GetCount() Then
        _VD_GoTo(7)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop8()
    If 8 <= _VD_GetCount() Then
        _VD_GoTo(8)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc
Func _HK_Desktop9()
    If 9 <= _VD_GetCount() Then
        _VD_GoTo(9)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc

; Name:        _HK_ToggleList
; Description: Hotkey callback to toggle the desktop list panel.
;              When pinned, this is a no-op (list stays open).
Func _HK_ToggleList()
    _DL_Toggle($iTaskbarY, $iDesktop)
EndFunc

; Name:        _HK_OpenSettings
; Description: Global hotkey handler: opens the Settings dialog
Func _HK_OpenSettings()
    If Not _CD_IsVisible() Then _CD_Show()
EndFunc

; Name:        _HK_ToggleLast
; Description: Hotkey callback to switch to the previously active desktop
Func _HK_ToggleLast()
    If $iPrevDesktop > 0 And $iPrevDesktop <> $iDesktop And $iPrevDesktop <= _VD_GetCount() Then
        _Log_Debug("Hotkey: toggle last -> desktop " & $iPrevDesktop)
        _VD_GoTo($iPrevDesktop)
        Sleep(50)
        _RefreshIndex()
    EndIf
EndFunc

; Name:        _HK_MoveFollowNext
; Description: Hotkey callback to move the active window to the next desktop and follow it
Func _HK_MoveFollowNext()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    Local $iCount = _VD_GetCount()
    Local $iTarget = $iDesktop + 1
    If $iTarget > $iCount Then
        If _Cfg_GetWrapNavigation() Then
            $iTarget = 1
        Else
            Return
        EndIf
    EndIf
    _Log_Debug("Hotkey: move+follow next -> window " & $hWnd & " to desktop " & $iTarget)
    _VD_MoveWindowToDesktop($hWnd, $iTarget)
    _VD_GoTo($iTarget)
    Sleep(50)
    _RefreshIndex()
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then
        Local $sTitle = WinGetTitle($hWnd)
        If $sTitle = "" Then $sTitle = "Window"
        _Theme_Toast($sTitle & " -> Desktop " & $iTarget, 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _HK_MoveFollowPrev
; Description: Hotkey callback to move the active window to the previous desktop and follow it
Func _HK_MoveFollowPrev()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    Local $iCount = _VD_GetCount()
    Local $iTarget = $iDesktop - 1
    If $iTarget < 1 Then
        If _Cfg_GetWrapNavigation() Then
            $iTarget = $iCount
        Else
            Return
        EndIf
    EndIf
    _Log_Debug("Hotkey: move+follow prev -> window " & $hWnd & " to desktop " & $iTarget)
    _VD_MoveWindowToDesktop($hWnd, $iTarget)
    _VD_GoTo($iTarget)
    Sleep(50)
    _RefreshIndex()
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then
        Local $sTitle = WinGetTitle($hWnd)
        If $sTitle = "" Then $sTitle = "Window"
        _Theme_Toast($sTitle & " -> Desktop " & $iTarget, 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _HK_MoveNext
; Description: Hotkey callback to move the active window to the next desktop (stay on current)
Func _HK_MoveNext()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    Local $iCount = _VD_GetCount()
    Local $iTarget = $iDesktop + 1
    If $iTarget > $iCount Then
        If _Cfg_GetWrapNavigation() Then
            $iTarget = 1
        Else
            Return
        EndIf
    EndIf
    _Log_Debug("Hotkey: move next -> window " & $hWnd & " to desktop " & $iTarget)
    _VD_MoveWindowToDesktop($hWnd, $iTarget)
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then
        Local $sTitle = WinGetTitle($hWnd)
        If $sTitle = "" Then $sTitle = "Window"
        _Theme_Toast($sTitle & " -> Desktop " & $iTarget, 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _HK_MovePrev
; Description: Hotkey callback to move the active window to the previous desktop (stay on current)
Func _HK_MovePrev()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    Local $iCount = _VD_GetCount()
    Local $iTarget = $iDesktop - 1
    If $iTarget < 1 Then
        If _Cfg_GetWrapNavigation() Then
            $iTarget = $iCount
        Else
            Return
        EndIf
    EndIf
    _Log_Debug("Hotkey: move prev -> window " & $hWnd & " to desktop " & $iTarget)
    _VD_MoveWindowToDesktop($hWnd, $iTarget)
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then
        Local $sTitle = WinGetTitle($hWnd)
        If $sTitle = "" Then $sTitle = "Window"
        _Theme_Toast($sTitle & " -> Desktop " & $iTarget, 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _HK_SendNewDesktop
; Description: Hotkey callback to create a new desktop and move the active window to it
Func _HK_SendNewDesktop()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    If _VD_GetCount() >= _GetDesktopLimit() Then
        _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
        Return
    EndIf
    _Log_Debug("Hotkey: send to new desktop -> window " & $hWnd)
    _VD_CreateDesktop()
    Sleep(100)
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
        _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
    EndIf
    Local $iNewDesk = _VD_GetCount()
    _VD_MoveWindowToDesktop($hWnd, $iNewDesk)
    _RefreshIndex()
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyWindowMoved() Then
        Local $sTitle = WinGetTitle($hWnd)
        If $sTitle = "" Then $sTitle = "Window"
        _Theme_Toast($sTitle & " -> Desktop " & $iNewDesk, 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _HK_PinWindow
; Description: Hotkey callback to toggle pin state of the active window across all desktops
Func _HK_PinWindow()
    If Not _Cfg_GetPinningEnabled() Then Return
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    _Log_Debug("Hotkey: toggle pin window -> " & $hWnd)
    Local $bPinned = _VD_TogglePinWindow($hWnd)
    If _Cfg_GetNotificationsEnabled() And $bPinned And _Cfg_GetNotifyWindowPinned() Then
        _Theme_Toast(_i18n("Toasts.toast_window_pinned", "Window pinned to all desktops"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    ElseIf _Cfg_GetNotificationsEnabled() And Not $bPinned And _Cfg_GetNotifyWindowUnpinned() Then
        _Theme_Toast(_i18n("Toasts.toast_window_unpinned", "Window unpinned"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _HK_ToggleWindowList
; Description: Hotkey callback to toggle the window list panel
Func _HK_ToggleWindowList()
    If Not _Cfg_GetWindowListEnabled() Then Return
    _Log_Debug("Hotkey: toggle window list")
    _WL_Toggle($iDesktop)
EndFunc

; Name:        _HK_AddDesktop
; Description: Hotkey callback to create a new virtual desktop
Func _HK_AddDesktop()
    If _VD_GetCount() >= _GetDesktopLimit() Then
        _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
        Return
    EndIf
    _Log_Debug("Hotkey: add desktop")
    _VD_CreateDesktop()
    Sleep(100)
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
        _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
    EndIf
    _RefreshIndex()
EndFunc

; Name:        _HK_DeleteDesktop
; Description: Hotkey callback to delete the current virtual desktop
Func _HK_DeleteDesktop()
    If _VD_GetCount() <= 1 Then
        _Theme_Confirm(_i18n("Dialogs.confirm_cannot_delete_title", "Cannot Delete"), _i18n("Dialogs.confirm_cannot_delete_msg", "This is the last desktop."))
        Return
    EndIf
    Local $sDelCurName = _Labels_Load($iDesktop)
    Local $sDelCurLabel = "Desktop " & $iDesktop
    If $sDelCurName <> "" Then $sDelCurLabel &= ' ("' & $sDelCurName & '")'
    If _Cfg_GetConfirmDelete() And Not _Theme_Confirm(_i18n_Format("Dialogs.confirm_delete_title", "Delete {1}?", $sDelCurLabel), _
            _i18n("Dialogs.confirm_delete_msg", "Windows will be moved to an adjacent desktop.")) Then Return
    _Log_Debug("Hotkey: delete desktop " & $iDesktop)
    _VD_RemoveDesktop($iDesktop)
    Sleep(100)
    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopDeleted() Then
        _Theme_Toast(_i18n("Toasts.toast_desktop_deleted", "Desktop deleted"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
    EndIf
    _RefreshIndex()
EndFunc

; Name:        _HK_RenameDesktop
; Description: Hotkey callback to open rename dialog for the current desktop
Func _HK_RenameDesktop()
    _Log_Debug("Hotkey: rename desktop " & $iDesktop)
    $iRenameTarget = $iDesktop
    _RD_Show($iDesktop, $iTaskbarY)
EndFunc

; Name:        _HK_CloseWindow
; Description: Hotkey callback to close the active window
Func _HK_CloseWindow()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    _Log_Debug("Hotkey: close window -> " & $hWnd)
    WinClose($hWnd)
EndFunc

; Name:        _HK_MinimizeWindow
; Description: Hotkey callback to minimize the active window
Func _HK_MinimizeWindow()
    Local $hWnd = WinGetHandle("[ACTIVE]")
    If $hWnd = $gui Then Return
    _Log_Debug("Hotkey: minimize window -> " & $hWnd)
    WinSetState($hWnd, "", @SW_MINIMIZE)
EndFunc

; About dialog extracted to includes\AboutDialog.au3


; =============================================
; TRAY ICON MODE
; =============================================

; Name:        _InitTrayMode
; Description: Initialize system tray icon and menu, hide widget
Func _InitTrayMode()
    $__g_bTrayMode = True
    GUISetState(@SW_HIDE, $gui)
    Opt("TrayMenuMode", 3) ; no default menu items
    $__g_iTrayToggleList = TrayCreateItem(_i18n("Tray.tray_show_list", "Show Desktop List"))
    $__g_iTrayEditLabel = TrayCreateItem(_i18n("Tray.tray_edit_label", "Edit Label"))
    TrayCreateItem("") ; separator
    $__g_iTrayAddDesktop = TrayCreateItem(_i18n("Tray.tray_add_desktop", "Add Desktop"))
    $__g_iTrayDelDesktop = TrayCreateItem(_i18n("Tray.tray_delete_desktop", "Delete Desktop"))
    TrayCreateItem("")
    $__g_iTraySettings = TrayCreateItem(_i18n("Tray.tray_settings", "Settings"))
    $__g_iTrayAbout = TrayCreateItem(_i18n("Tray.tray_about", "About"))
    TrayCreateItem("")
    $__g_iTrayQuit = TrayCreateItem(_i18n("Tray.tray_quit", "Quit"))
    ; Validate tray menu creation
    If $__g_iTrayToggleList = 0 Or $__g_iTrayQuit = 0 Then
        _Log_Error("Tray menu creation failed")
        $__g_bTrayMode = False
        GUISetState(@SW_SHOW, $gui)
        Return
    EndIf
    TraySetToolTip(_i18n_Format("Tray.tray_tooltip", "Desk Switcheroo - Desktop {1}", $iDesktop))
    If FileExists(@ScriptDir & "\assets\desk_switcheroo.ico") Then
        TraySetIcon(@ScriptDir & "\assets\desk_switcheroo.ico")
    EndIf
    TraySetState(1)
EndFunc

; Name:        _CheckTrayMessages
; Description: Poll tray menu for clicks and dispatch actions
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
            If _VD_GetCount() >= _GetDesktopLimit() Then
                _Theme_Toast(_i18n("Toasts.toast_desktop_limit", "Desktop limit reached"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_WARNING)
            Else
                _VD_CreateDesktop()
                Sleep(100)
                If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopCreated() Then
                    _Theme_Toast(_i18n_Format("Toasts.toast_desktop_created", "Desktop {1} created", _VD_GetCount()), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_SUCCESS)
                EndIf
                _RefreshIndex()
            EndIf
        Case $__g_iTrayDelDesktop
            If _VD_GetCount() > 1 Then
                If Not _Cfg_GetConfirmDelete() Or _Theme_Confirm("Delete Desktop " & $iDesktop & "?", _i18n("Dialogs.confirm_delete_msg", "Windows will be moved to an adjacent desktop.")) Then
                    _VD_RemoveDesktop($iDesktop)
                    Sleep(100)
                    If _Cfg_GetNotificationsEnabled() And _Cfg_GetNotifyDesktopDeleted() Then
                        _Theme_Toast(_i18n("Toasts.toast_desktop_deleted", "Desktop deleted"), 0, $iTaskbarY + $iTaskbarH + 4, 1500, $TOAST_INFO)
                    EndIf
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

; Name:        _AdlibConfigWatcher
; Description: Watch config file for external changes and reload if modified
; Name:        _CheckDLLHealth
; Description: Verifies the VD DLL is still responding; logs error if not
Func _CheckDLLHealth()
    If Not _VD_IsReady() Then
        _Log_Error("VirtualDesktopAccessor DLL handle lost — attempting reload")
        _VD_Init()
    EndIf
EndFunc

Func _AdlibConfigWatcher()
    Local $sNewTime = FileGetTime(_Cfg_GetPath(), 0, 1)
    If @error Then Return
    If $sNewTime = $__g_sCfgFileTime Then Return
    $__g_sCfgFileTime = $sNewTime
    _Log_Info("Config file changed externally, reloading")
    _UnregisterHotkeys()
    _Cfg_Load()
    _Log_Info("Config reloaded from file watcher")
    _RegisterHotkeys()
    _ApplyDesktopChange()
    AdlibUnRegister("_ForceTopMost")
    AdlibRegister("_ForceTopMost", _Cfg_GetTopmostInterval())
EndFunc

; =============================================
; CLEANUP
; =============================================

; Name:        _OnExit
; Description: Exit callback registered with OnAutoItExitRegister
; Name:        __WriteCrashLog
; Description: Writes crash report IMMEDIATELY to file (bypasses Logger in case Logger crashed)
; Parameters:  $sReason - crash reason header
;              $sDetails - error details
; Name:        __TriggerTestCrash
; Description: Triggers a test crash — writes crash log first, then causes a COM error
;              which fires _OnAutoItError and shows the crash dialog
Func __TriggerTestCrash()
    Local $iW = 300, $iH = 230
    Local $hDlg = GUICreate("Trigger Crash", $iW, $iH, _
        (@DesktopWidth - $iW) / 2, (@DesktopHeight - $iH) / 2, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUISetBkColor(0x1E1E1E)

    GUICtrlCreateLabel(ChrW(0x26A0) & "  " & _i18n("Errors.err_crash_select", "Select crash type:"), 14, 10, $iW - 28, 22)
    GUICtrlSetFont(-1, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor(-1, 0xFF5555)
    GUICtrlSetBkColor(-1, 0x1E1E1E)

    Local $idCOM = GUICtrlCreateLabel("  " & _i18n("Errors.err_crash_com", "COM Error (shows crash dialog)"), 14, 42, $iW - 28, 28, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCOM, 8, 400, 0, "Segoe UI")
    GUICtrlSetColor($idCOM, 0xCCCCCC)
    GUICtrlSetBkColor($idCOM, 0x333333)
    GUICtrlSetCursor($idCOM, 0)

    Local $idArray = GUICtrlCreateLabel("  " & _i18n("Errors.err_crash_array", "Array bounds (fatal, writes log)"), 14, 76, $iW - 28, 28, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idArray, 8, 400, 0, "Segoe UI")
    GUICtrlSetColor($idArray, 0xCCCCCC)
    GUICtrlSetBkColor($idArray, 0x333333)
    GUICtrlSetCursor($idArray, 0)

    Local $idDivZero = GUICtrlCreateLabel("  " & _i18n("Errors.err_crash_div", "Division by zero (fatal, writes log)"), 14, 110, $iW - 28, 28, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idDivZero, 8, 400, 0, "Segoe UI")
    GUICtrlSetColor($idDivZero, 0xCCCCCC)
    GUICtrlSetBkColor($idDivZero, 0x333333)
    GUICtrlSetCursor($idDivZero, 0)

    Local $idExit = GUICtrlCreateLabel("  " & _i18n("Errors.err_crash_exit", "Forced Exit code 99 (writes log)"), 14, 144, $iW - 28, 28, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idExit, 8, 400, 0, "Segoe UI")
    GUICtrlSetColor($idExit, 0xCCCCCC)
    GUICtrlSetBkColor($idExit, 0x333333)
    GUICtrlSetCursor($idExit, 0)

    Local $idCancel = GUICtrlCreateLabel(_i18n("General.btn_cancel", "Cancel"), ($iW - 80) / 2, $iH - 36, 80, 28, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCancel, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idCancel, 0xDDDDDD)
    GUICtrlSetBkColor($idCancel, 0x333333)
    GUICtrlSetCursor($idCancel, 0)

    GUISetState(@SW_SHOW, $hDlg)

    Local $iHovered = 0
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE, $idCancel
                    GUIDelete($hDlg)
                    Return
                Case $idCOM
                    GUIDelete($hDlg)
                    _Log_Warn("DEBUG: COM error crash triggered")
                    Local $oCrash = ObjCreate("__DeskSwitcheroo.IntentionalCrash")
                    $oCrash.CrashNow()
                    Return
                Case $idArray
                    GUIDelete($hDlg)
                    _Log_Warn("DEBUG: Array bounds crash triggered")
                    Local $aCrash[1]
                    $aCrash[999] = "crash"
                    Return
                Case $idDivZero
                    GUIDelete($hDlg)
                    _Log_Warn("DEBUG: Division by zero crash triggered")
                    Local $iZero = 0
                    Local $iCrash = 1 / $iZero
                    Return
                Case $idExit
                    GUIDelete($hDlg)
                    _Log_Warn("DEBUG: Forced exit crash triggered")
                    Exit 99
            EndSwitch
        EndIf
        ; Hover effects
        Local $aCur = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iF = 0
            If $aCur[4] = $idCOM Then $iF = $idCOM
            If $aCur[4] = $idArray Then $iF = $idArray
            If $aCur[4] = $idDivZero Then $iF = $idDivZero
            If $aCur[4] = $idExit Then $iF = $idExit
            If $aCur[4] = $idCancel Then $iF = $idCancel
            If $iF <> $iHovered Then
                If $iHovered <> 0 Then
                    GUICtrlSetColor($iHovered, 0xCCCCCC)
                    GUICtrlSetBkColor($iHovered, 0x333333)
                EndIf
                $iHovered = $iF
                If $iHovered <> 0 Then
                    GUICtrlSetColor($iHovered, 0xFFFFFF)
                    GUICtrlSetBkColor($iHovered, 0x484848)
                EndIf
            EndIf
        EndIf
        Sleep(10)
    WEnd
EndFunc

Func __WriteCrashLog($sReason, $sDetails)
    Local $sTimestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "." & @MSEC
    ; Use @ScriptDir with fallback to @TempDir if script dir is unwritable
    Local $sCrashDir = @ScriptDir
    Local $hTest = FileOpen($sCrashDir & "\__write_test.tmp", 2)
    If $hTest = -1 Then
        $sCrashDir = @TempDir
    Else
        FileClose($hTest)
        FileDelete($sCrashDir & "\__write_test.tmp")
    EndIf
    Local $sCrashFile = $sCrashDir & "\crash_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log"

    Local $sReport = "=== DESK SWITCHEROO CRASH REPORT ===" & @CRLF
    $sReport &= "Timestamp: " & $sTimestamp & @CRLF
    $sReport &= "Reason: " & $sReason & @CRLF
    $sReport &= @CRLF

    ; Error details
    $sReport &= "--- Error Details ---" & @CRLF
    $sReport &= $sDetails & @CRLF
    $sReport &= @CRLF

    ; App state snapshot
    $sReport &= "--- App State ---" & @CRLF
    $sReport &= "Version: " & $APP_VERSION & @CRLF
    $sReport &= "Current Desktop: " & $iDesktop & @CRLF
    $sReport &= "Script Line: " & @ScriptLineNumber & @CRLF
    $sReport &= "Shutting Down: " & $__g_bShuttingDown & @CRLF
    $sReport &= "Peek Active: " & _Peek_IsActive() & @CRLF
    $sReport &= "DL Visible: " & _DL_IsVisible() & @CRLF
    $sReport &= "CM Visible: " & _CM_IsVisible() & @CRLF
    $sReport &= "CD Visible: " & _CD_IsVisible() & @CRLF
    $sReport &= "RD Visible: " & _RD_IsVisible() & @CRLF
    $sReport &= "Tray Mode: " & $__g_bTrayMode & @CRLF
    $sReport &= "Dragging: " & _DL_IsDragging() & @CRLF
    $sReport &= @CRLF

    ; System info
    $sReport &= "--- System Info ---" & @CRLF
    $sReport &= "AutoIt: " & @AutoItVersion & " (" & @AutoItX64 & "-bit)" & @CRLF
    $sReport &= "OS: " & @OSVersion & " " & @OSArch & " (Build " & @OSBuild & ")" & @CRLF
    $sReport &= "User: " & @UserName & @CRLF
    $sReport &= "PID: " & @AutoItPID & @CRLF
    $sReport &= "Script: " & @ScriptFullPath & @CRLF
    $sReport &= "Working Dir: " & @WorkingDir & @CRLF
    $sReport &= @CRLF
    $sReport &= "=== END CRASH REPORT ===" & @CRLF

    ; Write immediately — don't use Logger (it might be the crash source)
    Local $hFile = FileOpen($sCrashFile, 2) ; 2 = overwrite
    If $hFile <> -1 Then
        FileWrite($hFile, $sReport)
        FileFlush($hFile)
        FileClose($hFile)
    EndIf

    ; Also try to log via Logger (may fail if Logger is broken)
    _Log_Error("CRASH: " & $sReason & " | " & StringReplace($sDetails, @CRLF, " | "))

    ; Show custom crash dialog (standalone — doesn't depend on any app state)
    __ShowCrashDialog($sReason, $sDetails, $sCrashFile)
EndFunc

; Name:        __ShowCrashDialog
; Description: Shows a standalone dark-themed crash dialog. Uses raw GUICreate
;              (not _Theme_CreatePopup) to avoid depending on Theme module state.
; Parameters:  $sReason - crash reason, $sDetails - details, $sCrashFile - log path
Func __ShowCrashDialog($sReason, $sDetails, $sCrashFile)
    Local $iW = 420, $iH = 280
    Local $hDlg = GUICreate("Desk Switcheroo — Error", $iW, $iH, _
        (@DesktopWidth - $iW) / 2, (@DesktopHeight - $iH) / 2, $WS_POPUP, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUISetBkColor(0x1E1E1E)

    ; Red warning icon + title
    GUICtrlCreateLabel(ChrW(0x26A0) & "  " & _i18n("Errors.err_crash_title", "Desk Switcheroo has crashed"), 14, 12, $iW - 28, 24)
    GUICtrlSetFont(-1, 11, 700, 0, "Segoe UI")
    GUICtrlSetColor(-1, 0xFF5555)
    GUICtrlSetBkColor(-1, 0x1E1E1E)

    ; Reason
    GUICtrlCreateLabel($sReason, 14, 42, $iW - 28, 18)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor(-1, 0xE8E8E8)
    GUICtrlSetBkColor(-1, 0x1E1E1E)

    ; Details (scrollable-ish — just show first few lines)
    Local $sShort = $sDetails
    If StringLen($sShort) > 300 Then $sShort = StringLeft($sShort, 300) & "..."
    GUICtrlCreateLabel($sShort, 14, 66, $iW - 28, 90)
    GUICtrlSetFont(-1, 7, 400, 0, "Consolas")
    GUICtrlSetColor(-1, 0xCCCCCC)
    GUICtrlSetBkColor(-1, 0x2A2A2A)

    ; Crash log path
    GUICtrlCreateLabel(_i18n_Format("Errors.err_crash_log", "Crash log: {1}", $sCrashFile), 14, 164, $iW - 28, 14)
    GUICtrlSetFont(-1, 7, 400, 0, "Segoe UI")
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, 0x1E1E1E)

    ; Buttons
    Local $iBtnY = $iH - 44
    Local $idCopy = GUICtrlCreateLabel(_i18n("Errors.err_copy_report", "Copy Report"), 14, $iBtnY, 100, 28, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCopy, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idCopy, 0xDDDDDD)
    GUICtrlSetBkColor($idCopy, 0x333333)
    GUICtrlSetCursor($idCopy, 0)

    Local $idOpen = GUICtrlCreateLabel(_i18n("Errors.err_open_log", "Open Log"), 124, $iBtnY, 100, 28, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idOpen, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idOpen, 0x6699CC)
    GUICtrlSetBkColor($idOpen, 0x333333)
    GUICtrlSetCursor($idOpen, 0)

    Local $idRestart = GUICtrlCreateLabel(ChrW(0x21BB) & " Restart", 234, $iBtnY, 80, 28, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idRestart, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idRestart, 0x6699CC)
    GUICtrlSetBkColor($idRestart, 0x333333)
    GUICtrlSetCursor($idRestart, 0)

    Local $idClose = GUICtrlCreateLabel(_i18n("General.btn_close", "Close"), $iW - 84, $iBtnY, 70, 28, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idClose, 0xDDDDDD)
    GUICtrlSetBkColor($idClose, 0x333333)
    GUICtrlSetCursor($idClose, 0)

    GUISetState(@SW_SHOW, $hDlg)

    Local $iHov = 0
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idClose
                    ExitLoop
                Case $idRestart
                    GUIDelete($hDlg)
                    If @Compiled Then
                        Run('"' & @ScriptFullPath & '"')
                    Else
                        Run('"' & @AutoItExe & '" "' & @ScriptFullPath & '"')
                    EndIf
                    Return
                Case $idCopy
                    ClipPut(FileRead($sCrashFile))
                    GUICtrlSetData($idCopy, _i18n("Errors.err_copied", "Copied!"))
                    GUICtrlSetColor($idCopy, 0x4AFF7E)
                Case $idOpen
                    ShellExecute($sCrashFile)
            EndSwitch
        EndIf
        ; Hover effects on buttons
        Local $aCur2 = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iF2 = 0
            If $aCur2[4] = $idCopy Then $iF2 = $idCopy
            If $aCur2[4] = $idOpen Then $iF2 = $idOpen
            If $aCur2[4] = $idRestart Then $iF2 = $idRestart
            If $aCur2[4] = $idClose Then $iF2 = $idClose
            If $iF2 <> $iHov Then
                If $iHov <> 0 Then
                    Local $iFgR = 0xDDDDDD
                    If $iHov = $idOpen Or $iHov = $idRestart Then $iFgR = 0x6699CC
                    GUICtrlSetColor($iHov, $iFgR)
                    GUICtrlSetBkColor($iHov, 0x333333)
                EndIf
                $iHov = $iF2
                If $iHov <> 0 Then
                    GUICtrlSetColor($iHov, 0xFFFFFF)
                    GUICtrlSetBkColor($iHov, 0x484848)
                EndIf
            EndIf
        EndIf
        Sleep(10)
    WEnd
    GUIDelete($hDlg)
EndFunc

; Name:        _OnAutoItError
; Description: COM/AutoIt error handler — writes crash report IMMEDIATELY
Func _OnAutoItError()
    Local $sDetails = "Error Number: 0x" & Hex($__g_oErrorHandler.number, 8) & @CRLF
    $sDetails &= "Description: " & $__g_oErrorHandler.description & @CRLF
    $sDetails &= "WinDescription: " & $__g_oErrorHandler.windescription & @CRLF
    $sDetails &= "Script Line: " & $__g_oErrorHandler.scriptline & @CRLF
    $sDetails &= "Source: " & $__g_oErrorHandler.source & @CRLF
    $sDetails &= "HelpFile: " & $__g_oErrorHandler.helpfile & @CRLF
    $sDetails &= "HelpContext: " & $__g_oErrorHandler.helpcontext & @CRLF
    $sDetails &= "LastDllError: " & $__g_oErrorHandler.lastdllerror & @CRLF
    $sDetails &= "RetCode: " & $__g_oErrorHandler.retcode

    __WriteCrashLog("COM/AutoIt Error", $sDetails)
EndFunc

; Name:        _OnExit
; Description: Exit callback — writes crash report if exit was unexpected
Func _OnExit()
    If Not $__g_bShuttingDown Then
        ; Capture as much info as possible about why we're exiting
        Local $sDetails = "Exit Code: " & @exitCode & @CRLF
        $sDetails &= "Exit Method: " & @exitMethod & @CRLF
        $sDetails &= "Script Line: " & @ScriptLineNumber & @CRLF
        $sDetails &= "Error Code: " & @error & @CRLF
        $sDetails &= "Extended: " & @extended & @CRLF

        ; Check if there's a COM error object with info
        If IsObj($__g_oErrorHandler) Then
            $sDetails &= "COM Error: 0x" & Hex($__g_oErrorHandler.number, 8) & @CRLF
            $sDetails &= "COM Desc: " & $__g_oErrorHandler.description & @CRLF
            $sDetails &= "COM Line: " & $__g_oErrorHandler.scriptline & @CRLF
            $sDetails &= "COM Source: " & $__g_oErrorHandler.source
        EndIf

        ; Write crash log immediately (bypasses Logger)
        __WriteCrashLog("Unexpected Exit / Fatal Error", $sDetails)
    EndIf
    _Shutdown()
EndFunc

; Name:        _Shutdown
; Description: Cleanup and exit with reentrancy guard
Func _Shutdown()
    If $__g_bShuttingDown Then Return
    ; Quit confirmation (skip if already shutting down from OnExit)
    If _Cfg_GetConfirmQuit() Then
        If Not _Theme_Confirm(_i18n("Dialogs.confirm_quit_title", "Quit Desk Switcheroo?"), _i18n("Dialogs.confirm_quit_msg", "Are you sure you want to exit?")) Then Return
    EndIf
    $__g_bShuttingDown = True

    ; Stop all periodic tasks first (prevent interference during fade)
    _EM_Stop()
    _UnregisterHotkeys()
    AdlibUnRegister("_ForceTopMost")
    AdlibUnRegister("_AdlibSyncNames")
    AdlibUnRegister("_AdlibConfigWatcher")
    AdlibUnRegister("_UC_AdlibCheck")
    AdlibUnRegister("_CheckDLLHealth")

    ; Gracefully close visible popups (no animation — just clean up)
    If _DL_CtxIsVisible() Then _DL_CtxDestroy()
    If _CM_IsVisible() Then _CM_Destroy()
    If _RD_IsVisible() Then _RD_Destroy()
    _Theme_ToastDestroy()

    ; Fade out window list and desktop list if visible
    If _WL_IsVisible() Then _WL_Destroy()
    If _DL_IsVisible() Then _DL_Destroy()

    ; Fade out main widget
    If $gui And Not $__g_bTrayMode Then
        If __Theme_ShouldAnimate("widget") Then
            Local $iAlpha = _Cfg_GetThemeAlphaMain()
            Local $iStep = _Cfg_GetFadeStep() * 2
            Local $iSleep = _Cfg_GetFadeSleepMs()
            Local $i
            For $i = $iAlpha To 0 Step -$iStep
                _WinAPI_SetLayeredWindowAttributes($gui, 0, $i, $LWA_ALPHA)
                Sleep($iSleep)
            Next
        EndIf
    EndIf

    ; Persist window state for next launch
    Local $sStateFile = @ScriptDir & "\desk_switcheroo_state.ini"
    IniWrite($sStateFile, "State", "last_desktop", $iDesktop)
    IniWrite($sStateFile, "State", "list_visible", False)
    IniWrite($sStateFile, "State", "scroll_offset", _DL_GetScrollOffset())

    ; Clean up resources
    If $gui Then _VD_UnregisterNotify($gui)
    _DL_ThumbClearCache()
    _RD_Shutdown()
    _VD_Shutdown()
    _Theme_UnloadFonts()
    _Log_Info("Shutdown complete — exiting gracefully")
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
