#include-once
#include "Config.au3"
#include "Theme.au3"
#include "DesktopList.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <WinAPISysWin.au3>

; #INDEX# =======================================================
; Title .........: ConfigDialog
; Description ....: Fully dark-themed settings window using custom label-based
;                   tabs and checkboxes (no native controls that resist theming)
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_CD_hGUI = 0
Global $__g_CD_bVisible = False
Global $__g_CD_iActiveTab = 0

; -- Tab button IDs --
Global $__g_CD_aidTabBtn[14] ; index 1-13
Global Const $__g_CD_aTabNames = "General,Display,Scroll,Hotkeys,Behavior,Logging,Updates,Desktops,Animations,Wallpaper,Window List,Explorer,Notifications"

; -- Controls per tab (arrays of IDs to show/hide + scroll) --
Global $__g_CD_aidTabCtrls[14][100] ; [tab 1-13][up to 100 controls per tab]
Global $__g_CD_aiTabCtrlY[14][100]  ; original Y position per control
Global $__g_CD_aiTabCtrlCount[14]   ; how many controls per tab
Global $__g_CD_aiTabScroll[14]      ; current scroll offset per tab (px)
Global $__g_CD_iContentTop = 84     ; top of content area (3-row tab bar)
Global $__g_CD_iScrollStep = 30     ; pixels per scroll step

; -- Tab 1: General --
Global $__g_CD_idChkStartWin, $__g_CD_idChkWrapNav, $__g_CD_idChkAutoCreate
Global $__g_CD_idInpPadding, $__g_CD_idInpOffsetX
Global $__g_CD_idLblPosition ; label that cycles left/center/right

; -- Tab 2: Display --
Global $__g_CD_idChkShowCount, $__g_CD_idInpCountFont, $__g_CD_idInpOpacity
Global $__g_CD_idLblTheme
Global $__g_CD_idChkThumbnails, $__g_CD_idInpThumbW, $__g_CD_idInpThumbH
Global $__g_CD_idChkThumbScreenshot, $__g_CD_idInpThumbCacheTTL

; -- Tab 3: Scroll --
Global $__g_CD_idChkScroll, $__g_CD_idChkScrollWrap
Global $__g_CD_idChkListScroll
Global $__g_CD_idLblScrollDir, $__g_CD_idLblListAction

; -- Tab 4: Hotkeys --
Global $__g_CD_idInpHkNext, $__g_CD_idInpHkPrev, $__g_CD_idInpHkToggleList
Global $__g_CD_aidInpHkDesktop[10] ; index 1-9
Global $__g_CD_idBtnHkBuild[21]    ; index 0-19 for each hotkey row "..." button

; -- Tab 1 extras: General --
Global $__g_CD_idChkWidgetDrag, $__g_CD_idChkWidgetColorBar, $__g_CD_idChkTrayMode, $__g_CD_idChkQuickAccess
Global $__g_CD_idChkListKeyNav
Global $__g_CD_idLblLanguage
Global $__g_CD_idComboOverlay = 0
Global $__g_CD_bDropdownOpen = False
Global $__g_CD_iSavedHighlight = 0, $__g_CD_iSavedHighlightText = 0

; -- Tab 8: Updates --
Global $__g_CD_idChkAutoUpdate, $__g_CD_idInpUpdateInterval
Global $__g_CD_idChkUpdateOnStartup, $__g_CD_idInpUpdateCheckDays
Global $__g_CD_idBtnCheckNow, $__g_CD_idBtnDownloadLatest
Global $__g_CD_iContentH = 450

; -- Tab 9: Animations --
Global $__g_CD_idChkAnimEnabled
Global $__g_CD_idChkAnimList, $__g_CD_idChkAnimMenus, $__g_CD_idChkAnimDialogs
Global $__g_CD_idChkAnimToasts, $__g_CD_idChkAnimWidget
Global $__g_CD_idInpFadeIn, $__g_CD_idInpFadeOut
Global $__g_CD_idInpFadeStep, $__g_CD_idInpFadeSleep
Global $__g_CD_idInpToastFadeOut

; -- Tab 10: Wallpaper --
Global $__g_CD_idChkWallpaper, $__g_CD_idInpWallpaperDelay
Global $__g_CD_aidWallpaperPath[10]   ; index 1-9
Global $__g_CD_aidWallpaperBrowse[10] ; index 1-9

; -- Tab 11: Window List --
Global $__g_CD_idChkWLEnabled, $__g_CD_idLblWLPosition
Global $__g_CD_idInpWLWidth, $__g_CD_idInpWLMaxVisible
Global $__g_CD_idChkWLIcons, $__g_CD_idChkWLSearch
Global $__g_CD_idChkWLAutoRefresh, $__g_CD_idInpWLRefreshInterval

; -- Tab 12: Explorer --
Global $__g_CD_idChkExplorerMonitor, $__g_CD_idInpExplorerInterval, $__g_CD_idChkExplorerNotify
Global $__g_CD_idInpShellProcess, $__g_CD_idInpMaxRetries, $__g_CD_idInpRetryDelay
Global $__g_CD_idChkExpBackoff, $__g_CD_idInpMaxRetryDelay
Global $__g_CD_idChkAutoRestart, $__g_CD_idInpRestartDelay

; -- Tab 13: Notifications --
Global $__g_CD_idChkNotifyMoved, $__g_CD_idChkNotifyCreated, $__g_CD_idChkNotifyDeleted, $__g_CD_idChkNotifyPinned
Global $__g_CD_idChkNotifyUnpinned, $__g_CD_idChkNotifyExplorerRecov
Global $__g_CD_idLblWLScope

; -- Tab 1 extras: General --
Global $__g_CD_idChkSingleton, $__g_CD_idChkTaskbarFocus, $__g_CD_idChkAutoFocus
Global $__g_CD_idChkCapslockMod, $__g_CD_idInpMinDesktops

; -- Tab 4 extras: Hotkeys --
Global $__g_CD_idInpHkLastDesktop, $__g_CD_idInpHkMoveFollowNext, $__g_CD_idInpHkMoveFollowPrev
Global $__g_CD_idInpHkMoveToNext, $__g_CD_idInpHkMoveToPrev
Global $__g_CD_idInpHkSendToNew, $__g_CD_idInpHkPinWindow, $__g_CD_idInpHkToggleWL

; -- Tab 5: Behavior --
Global $__g_CD_idChkConfirmDel, $__g_CD_idChkMidClick, $__g_CD_idChkMoveWin
Global $__g_CD_idInpPeekDelay, $__g_CD_idInpAutoHide, $__g_CD_idInpTopmost, $__g_CD_idInpCmDelay
Global $__g_CD_idChkConfigWatcher, $__g_CD_idInpWatcherInterval
Global $__g_CD_idInpCountCacheTTL

; -- Colors checkbox (in Desktops tab) --
Global $__g_CD_idChkColorsEnabled

; -- Tab 2: Display extras --
Global $__g_CD_idInpListFont, $__g_CD_idInpListFontSize, $__g_CD_idInpTooltipFontSize
Global $__g_CD_idChkListScrollable, $__g_CD_idInpListMaxVisible, $__g_CD_idInpListScrollSpeed

; -- Tab 7: Logging --
Global $__g_CD_idChkLogging, $__g_CD_idInpLogPath, $__g_CD_idBtnLogBrowse, $__g_CD_idLblLogLevel
Global $__g_CD_idInpLogMaxSize
Global $__g_CD_idInpLogRotateCount, $__g_CD_idChkLogCompress
Global $__g_CD_idChkLogPID, $__g_CD_idLblLogDateFormat, $__g_CD_idChkLogFlush

; -- Tab 5: Behavior extras --
Global $__g_CD_idChkConfirmQuit, $__g_CD_idChkDebugMode

; -- Buttons --
Global $__g_CD_idBtnApply, $__g_CD_idBtnClose
Global $__g_CD_idBtnImport, $__g_CD_idBtnExport, $__g_CD_idBtnRestart

; -- Checkbox state tracking --
Global $__g_CD_aChkIDs[80]     ; control IDs (2 per checkbox: box + text)
Global $__g_CD_aChkStates[80]  ; boolean states
Global $__g_CD_aChkTexts[80]   ; original text per checkbox
Global $__g_CD_iChkCount = 0
Global $__g_CD_hBrushCombo = 0 ; GDI brush for combo dropdown theming

; -- Tab 9: Desktops --
Global $__g_CD_aidDeskLabel[21]   ; input fields for desktop labels, index 1-20
Global $__g_CD_aidDeskColor[21]   ; input fields for desktop colors, index 1-20
Global $__g_CD_aidDeskPreview[21] ; color preview labels, index 1-20
Global $__g_CD_iDeskCount = 0     ; how many desktop rows were created

; -- Reset button --
Global $__g_CD_idBtnReset


; #FUNCTIONS# ===================================================

Func _CD_Show()
    _Log_Info("Settings dialog opened")
    Local $iW = 460
    ; Dynamic height: use up to 85% of screen, minimum 600
    Local $iMaxH = Int(@DesktopHeight * 0.85)
    Local $iH = 700
    If $iH > $iMaxH Then $iH = $iMaxH
    If $iH < 600 Then $iH = 600
    Local $iX = (@DesktopWidth - $iW) / 2
    Local $iY = (@DesktopHeight - $iH) / 2

    $__g_CD_hGUI = _Theme_CreatePopup("Settings", $iW, $iH, $iX, $iY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Reset state
    $__g_CD_iChkCount = 0
    Local $t
    For $t = 1 To 13
        $__g_CD_aiTabCtrlCount[$t] = 0
        $__g_CD_aiTabScroll[$t] = 0
    Next

    ; Create custom tab bar (3 rows: 5 + 5 + 3 tabs)
    Local $aNames = StringSplit($__g_CD_aTabNames, ",")
    Local $iTabW = 84, $iTabH = 22, $iTabX = 10, $iTabY = 8
    Local $iTabsPerRow = 5
    For $t = 1 To $aNames[0]
        If $t = $iTabsPerRow + 1 Or $t = $iTabsPerRow * 2 + 1 Then
            ; Start next row
            $iTabX = 10
            $iTabY += $iTabH + 2
        EndIf
        $__g_CD_aidTabBtn[$t] = GUICtrlCreateLabel($aNames[$t], $iTabX, $iTabY, $iTabW, $iTabH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidTabBtn[$t], 7, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_MAIN)
        GUICtrlSetCursor($__g_CD_aidTabBtn[$t], 0)
        $iTabX += $iTabW + 2
    Next

    ; Content area background (disabled so it doesn't intercept clicks on controls above)
    $__g_CD_iContentH = $iH - 168 ; leave room for 3-row tab bar + buttons
    Local $iContentH = $__g_CD_iContentH
    Local $idContentBg = GUICtrlCreateLabel("", 8, 84, $iW - 16, $iContentH)
    GUICtrlSetBkColor($idContentBg, $THEME_BG_MAIN)
    GUICtrlSetState($idContentBg, $GUI_DISABLE)

    ; Build each tab's controls
    __CD_BuildTabGeneral()
    __CD_BuildTabDisplay()
    __CD_BuildTabScroll()
    __CD_BuildTabHotkeys()
    __CD_BuildTabBehavior()
    __CD_BuildTabLogging()
    __CD_BuildTabUpdates()
    __CD_BuildTabDesktops()
    __CD_BuildTabAnimations()
    __CD_BuildTabWallpaper()
    __CD_BuildTabWindowList()
    __CD_BuildTabExplorer()
    __CD_BuildTabNotifications()

    ; Import + Export + Restart buttons (top row)
    Local $iBtnW = 80, $iBtnH = 26
    Local $iGap = 10
    Local $iRow1Y = $iH - 70
    Local $iRow1TotalW = $iBtnW * 3 + $iGap * 2
    Local $iRow1X = ($iW - $iRow1TotalW) / 2

    $__g_CD_idBtnImport = GUICtrlCreateLabel(ChrW(0x2B07) & " " & _i18n("General.btn_import", "Import"), $iRow1X, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnImport, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnImport, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnImport, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnImport, 0)

    $__g_CD_idBtnExport = GUICtrlCreateLabel(ChrW(0x2B06) & " " & _i18n("General.btn_export", "Export"), $iRow1X + $iBtnW + $iGap, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnExport, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnExport, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnExport, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnExport, 0)

    $__g_CD_idBtnRestart = GUICtrlCreateLabel(ChrW(0x21BB) & " " & _i18n("General.btn_restart", "Restart"), $iRow1X + ($iBtnW + $iGap) * 2, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnRestart, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnRestart, $THEME_FG_LINK)
    GUICtrlSetBkColor($__g_CD_idBtnRestart, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnRestart, 0)

    ; Apply + Reset + Close buttons (bottom row)
    Local $iRow2Y = $iH - 38
    Local $iTotalW = $iBtnW * 3 + $iGap * 2
    Local $iBtnX = ($iW - $iTotalW) / 2

    $__g_CD_idBtnApply = GUICtrlCreateLabel(ChrW(0x2713) & " " & _i18n("General.btn_apply", "Apply"), $iBtnX, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnApply, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnApply, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnApply, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnApply, 0)

    $__g_CD_idBtnReset = GUICtrlCreateLabel(ChrW(0x21BA) & " " & _i18n("General.btn_reset", "Reset"), $iBtnX + $iBtnW + $iGap, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnReset, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnReset, 0xCC6666)
    GUICtrlSetBkColor($__g_CD_idBtnReset, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnReset, 0)

    $__g_CD_idBtnClose = GUICtrlCreateLabel(ChrW(0x2715) & " " & _i18n("General.btn_close", "Close"), $iBtnX + ($iBtnW + $iGap) * 2, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnClose, 0)

    ; Load config values into controls
    __CD_PopulateControls()

    ; Show first tab
    __CD_SwitchTab(1)

    ; Create GDI brush for combo dropdown theming
    Local $aBrush = DllCall("gdi32.dll", "handle", "CreateSolidBrush", "dword", $THEME_BG_INPUT)
    If Not @error And IsArray($aBrush) Then $__g_CD_hBrushCombo = $aBrush[0]
    GUIRegisterMsg(0x0134, "__CD_WM_CTLCOLORLISTBOX") ; WM_CTLCOLORLISTBOX
    ; NOTE: WM_CTLCOLORSTATIC (0x0138) intentionally NOT registered here.
    ; Registering it breaks runtime GUICtrlSetBkColor on ALL label controls
    ; (AutoIt returns stale brushes via $GUI_RUNDEFMSG), which kills button/tab hover.
    ; The combo face is already themed via GUICtrlSetColor/BkColor at creation.

    _Theme_FadeIn($__g_CD_hGUI, $THEME_ALPHA_DIALOG, "dialog")
    $__g_CD_bVisible = True

    ; Blocking loop
    __CD_MessageLoop()
EndFunc

Func _CD_Destroy()
    _Log_Info("Settings dialog closed")
    ; Restore system highlight colors if dropdown was open
    If $__g_CD_bDropdownOpen Then
        Local $aElems = DllStructCreate("int[2]")
        Local $aColors = DllStructCreate("dword[2]")
        DllStructSetData($aElems, 1, 13, 1)
        DllStructSetData($aElems, 1, 14, 2)
        DllStructSetData($aColors, 1, $__g_CD_iSavedHighlight, 1)
        DllStructSetData($aColors, 1, $__g_CD_iSavedHighlightText, 2)
        DllCall("user32.dll", "bool", "SetSysColors", "int", 2, "struct*", $aElems, "struct*", $aColors)
        $__g_CD_bDropdownOpen = False
    EndIf
    GUIRegisterMsg(0x0134, "") ; unregister WM_CTLCOLORLISTBOX
    If $__g_CD_hBrushCombo <> 0 Then
        DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $__g_CD_hBrushCombo)
        $__g_CD_hBrushCombo = 0
    EndIf
    If $__g_CD_hGUI <> 0 Then _Theme_FadeOut($__g_CD_hGUI, "dialog")
    $__g_CD_hGUI = 0
    $__g_CD_bVisible = False
EndFunc

Func _CD_IsVisible()
    Return $__g_CD_bVisible
EndFunc

Func _CD_GetGUI()
    Return $__g_CD_hGUI
EndFunc

; =============================================
; CUSTOM TAB SWITCHING
; =============================================

Func __CD_SwitchTab($iTab)
    _Log_Debug("Settings: switched to tab " & $iTab)
    $__g_CD_iActiveTab = $iTab

    ; Reset scroll for the new tab (restore controls to original Y)
    If $__g_CD_aiTabScroll[$iTab] <> 0 Then
        $__g_CD_aiTabScroll[$iTab] = 0
        Local $sc
        For $sc = 0 To $__g_CD_aiTabCtrlCount[$iTab] - 1
            Local $idSc = $__g_CD_aidTabCtrls[$iTab][$sc]
            Local $aSc = ControlGetPos($__g_CD_hGUI, "", $idSc)
            If Not @error And IsArray($aSc) Then
                GUICtrlSetPos($idSc, $aSc[0], $__g_CD_aiTabCtrlY[$iTab][$sc], $aSc[2], $aSc[3])
            EndIf
        Next
    EndIf

    ; Lock window to prevent repaint during bulk control state changes
    DllCall("user32.dll", "bool", "LockWindowUpdate", "hwnd", $__g_CD_hGUI)

    ; Update tab button styles
    Local $t, $c
    For $t = 1 To 13
        If $t = $iTab Then
            GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_ACTIVE)
            GUICtrlSetFont($__g_CD_aidTabBtn[$t], 8, 700, 0, $THEME_FONT_MAIN)
        Else
            GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_MAIN)
            GUICtrlSetFont($__g_CD_aidTabBtn[$t], 8, 400, 0, $THEME_FONT_MAIN)
        EndIf
    Next
    ; Show/hide controls per tab
    For $t = 1 To 13
        Local $iState = $GUI_HIDE
        If $t = $iTab Then $iState = $GUI_SHOW
        For $c = 0 To $__g_CD_aiTabCtrlCount[$t] - 1
            GUICtrlSetState($__g_CD_aidTabCtrls[$t][$c], $iState)
        Next
    Next

    ; Unlock window — triggers a single repaint with all changes applied
    DllCall("user32.dll", "bool", "LockWindowUpdate", "hwnd", 0)
EndFunc

Func __CD_RegCtrl($iTab, $idCtrl)
    Local $c = $__g_CD_aiTabCtrlCount[$iTab]
    $__g_CD_aidTabCtrls[$iTab][$c] = $idCtrl
    $__g_CD_aiTabCtrlCount[$iTab] = $c + 1
EndFunc

; Name:        __CD_ScrollTab
; Description: Scrolls the active tab's controls by a pixel delta
; Parameters:  $iDelta - positive = scroll down (content moves up), negative = scroll up
Func __CD_ScrollTab($iDelta)
    Local $iTab = $__g_CD_iActiveTab
    Local $c

    ; Lazy-init: capture original Y positions on first scroll attempt
    If $__g_CD_aiTabCtrlY[$iTab][0] = 0 And $__g_CD_aiTabCtrlCount[$iTab] > 0 Then
        For $c = 0 To $__g_CD_aiTabCtrlCount[$iTab] - 1
            Local $aInit = ControlGetPos($__g_CD_hGUI, "", $__g_CD_aidTabCtrls[$iTab][$c])
            If Not @error And IsArray($aInit) Then
                $__g_CD_aiTabCtrlY[$iTab][$c] = $aInit[1]
            EndIf
        Next
    EndIf

    Local $iNewScroll = $__g_CD_aiTabScroll[$iTab] + $iDelta

    ; Clamp: don't scroll above 0 (top)
    If $iNewScroll < 0 Then $iNewScroll = 0

    ; Clamp: find max content Y to determine max scroll
    Local $iMaxY = 0
    For $c = 0 To $__g_CD_aiTabCtrlCount[$iTab] - 1
        If $__g_CD_aiTabCtrlY[$iTab][$c] > $iMaxY Then $iMaxY = $__g_CD_aiTabCtrlY[$iTab][$c]
    Next
    Local $iMaxScroll = $iMaxY - $__g_CD_iContentTop - $__g_CD_iContentH + 60
    If $iMaxScroll < 0 Then $iMaxScroll = 0
    If $iNewScroll > $iMaxScroll Then $iNewScroll = $iMaxScroll

    If $iNewScroll = $__g_CD_aiTabScroll[$iTab] Then Return ; no change

    $__g_CD_aiTabScroll[$iTab] = $iNewScroll

    ; Move all controls for this tab
    For $c = 0 To $__g_CD_aiTabCtrlCount[$iTab] - 1
        Local $idCtrl = $__g_CD_aidTabCtrls[$iTab][$c]
        Local $iOrigY = $__g_CD_aiTabCtrlY[$iTab][$c]
        Local $aCtrlPos = ControlGetPos($__g_CD_hGUI, "", $idCtrl)
        If Not @error And IsArray($aCtrlPos) Then
            GUICtrlSetPos($idCtrl, $aCtrlPos[0], $iOrigY - $iNewScroll, $aCtrlPos[2], $aCtrlPos[3])
        EndIf
    Next
EndFunc

; =============================================
; LABEL-BASED CHECKBOX (single label per checkbox)
; =============================================

Func __CD_CreateCheckbox($sText, $iX, $iY, $iW, $iTab)
    $__g_CD_iChkCount += 1
    Local $idx = $__g_CD_iChkCount
    Local $id = GUICtrlCreateLabel("  [ ]  " & $sText, $iX, $iY, $iW, 22, _
        BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($id, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($id, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($id, 0)
    __CD_RegCtrl($iTab, $id)
    $__g_CD_aChkIDs[$idx] = $id
    $__g_CD_aChkStates[$idx] = False
    $__g_CD_aChkTexts[$idx] = $sText
    Return $id
EndFunc

Func __CD_SetCheckState($id, $bChecked)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $id Then
            $__g_CD_aChkStates[$i] = $bChecked
            If $bChecked Then
                GUICtrlSetData($id, "  [x]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($id, $THEME_FG_WHITE)
            Else
                GUICtrlSetData($id, "  [ ]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($id, $THEME_FG_PRIMARY)
            EndIf
            Return
        EndIf
    Next
EndFunc

Func __CD_GetCheckState($id)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $id Then Return $__g_CD_aChkStates[$i]
    Next
    Return False
EndFunc

Func __CD_HandleCheckboxClick($msg)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $msg Then
            $__g_CD_aChkStates[$i] = Not $__g_CD_aChkStates[$i]
            If $__g_CD_aChkStates[$i] Then
                GUICtrlSetData($msg, "  [x]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($msg, $THEME_FG_WHITE)
            Else
                GUICtrlSetData($msg, "  [ ]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($msg, $THEME_FG_PRIMARY)
            EndIf
            Return True
        EndIf
    Next
    Return False
EndFunc

; =============================================
; CUSTOM CYCLING LABEL (replaces combo box)
; =============================================

Func __CD_CreateCycleLabel($sLabel, $iX, $iY, $iLblW, $iValW, $iTab)
    Local $idLbl = GUICtrlCreateLabel($sLabel, $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($iTab, $idLbl)

    Local $idVal = GUICtrlCreateLabel("", $iX + $iLblW, $iY, $iValW, 22, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idVal, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idVal, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idVal, $THEME_BG_INPUT)
    GUICtrlSetCursor($idVal, 0)
    __CD_RegCtrl($iTab, $idVal)

    Return $idVal
EndFunc

Func __CD_CycleValue($id, $sOptions)
    Local $aCur = GUICtrlRead($id)
    Local $aOpts = StringSplit($sOptions, "|")
    Local $i
    For $i = 1 To $aOpts[0]
        If $aOpts[$i] = $aCur Then
            Local $iNext = Mod($i, $aOpts[0]) + 1
            GUICtrlSetData($id, $aOpts[$iNext])
            Return
        EndIf
    Next
    GUICtrlSetData($id, $aOpts[1])
EndFunc

; =============================================
; TAB BUILDERS
; =============================================

Func __CD_BuildTabGeneral()
    Local $t = 1, $iX = 20, $iY = 94

    $__g_CD_idChkStartWin = __CD_CreateCheckbox(_i18n("Settings.General.chk_start_windows", "Start with Windows"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkStartWin, _i18n("Settings.General.tip_start_windows", "Launch Desk Switcheroo automatically when you log in"))
    $iY += 26
    $__g_CD_idChkWrapNav = __CD_CreateCheckbox(_i18n("Settings.General.chk_wrap_nav", "Wrap navigation at ends"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWrapNav, _i18n("Settings.General.tip_wrap_nav", "Left arrow on first desktop goes to last, and vice versa"))
    $iY += 26
    $__g_CD_idChkAutoCreate = __CD_CreateCheckbox(_i18n("Settings.General.chk_auto_create", "Auto-create desktop past end"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoCreate, _i18n("Settings.General.tip_auto_create", "Right arrow on last desktop creates a new one"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_padding", "Number padding (1-4):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpPadding = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpPadding, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpPadding, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpPadding, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpPadding)
    _Theme_SetTooltip($__g_CD_idInpPadding, _i18n("Settings.General.tip_padding", "Zero-pad desktop numbers (2 = '01', 3 = '001')"))
    $iY += 30

    $__g_CD_idLblPosition = __CD_CreateCycleLabel(_i18n("Settings.General.lbl_widget_anchor", "Widget anchor:"), $iX, $iY, 165, 110, $t)
    _Theme_SetTooltip($__g_CD_idLblPosition, _i18n("Settings.General.tip_widget_anchor", "Click to cycle screen anchor position"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_widget_offset_x", "Widget X offset (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpOffsetX = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22)
    GUICtrlSetFont($__g_CD_idInpOffsetX, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOffsetX, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOffsetX, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpOffsetX)
    _Theme_SetTooltip($__g_CD_idInpOffsetX, _i18n("Settings.General.tip_widget_offset", "Fine-tune widget position in pixels"))
    $iY += 34

    $__g_CD_idChkWidgetDrag = __CD_CreateCheckbox(_i18n("Settings.General.chk_widget_drag", "Enable widget drag"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWidgetDrag, _i18n("Settings.General.tip_widget_drag", "Hold and drag the widget to reposition it on the taskbar"))
    $iY += 26
    $__g_CD_idChkWidgetColorBar = __CD_CreateCheckbox(_i18n("Settings.General.chk_color_bar", "Widget color bar"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWidgetColorBar, _i18n("Settings.General.tip_color_bar", "Show a colored accent on the widget matching the current desktop color"))
    $iY += 26
    $__g_CD_idChkTrayMode = __CD_CreateCheckbox(_i18n("Settings.General.chk_tray_mode", "Tray icon mode"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayMode, _i18n("Settings.General.tip_tray_mode", "Run as system tray icon instead of taskbar widget (requires restart)"))
    $iY += 26
    $__g_CD_idChkQuickAccess = __CD_CreateCheckbox(_i18n("Settings.General.chk_quick_access", "Quick-access number input"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkQuickAccess, _i18n("Settings.General.tip_quick_access", "Double-click the number to type a desktop number (1-9) to jump to"))
    $iY += 26
    $__g_CD_idChkListKeyNav = __CD_CreateCheckbox(_i18n("Settings.General.chk_list_key_nav", "Keyboard nav in list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListKeyNav, _i18n("Settings.General.tip_list_key_nav", "Use Up/Down arrow keys to navigate when the desktop list is open"))
    $iY += 34
    Local $idLangLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_language", "Language:"), $iX, $iY + 2, 80, 18)
    GUICtrlSetFont($idLangLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLangLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLangLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLangLbl)
    $__g_CD_idLblLanguage = GUICtrlCreateCombo("", $iX + 85, $iY, 310, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblLanguage, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idLblLanguage, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblLanguage, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idLblLanguage)
    ; Themed overlay for combo face (WM_CTLCOLORSTATIC can't be used without breaking hover)
    $__g_CD_idComboOverlay = GUICtrlCreateLabel("", $iX + 85, $iY, 310, 22, BitOR($SS_LEFT, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idComboOverlay, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idComboOverlay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idComboOverlay, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idComboOverlay, 0)
    __CD_RegCtrl($t, $__g_CD_idComboOverlay)
    _Theme_SetTooltip($__g_CD_idComboOverlay, _i18n("Settings.General.tip_language", "Select a language (requires restart)"))
    $iY += 34

    $__g_CD_idChkSingleton = __CD_CreateCheckbox(_i18n("Settings.General.chk_singleton", "Single instance mode"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkSingleton, _i18n("Settings.General.tip_singleton", "Kill previous instance when relaunching"))
    $iY += 26
    $__g_CD_idChkTaskbarFocus = __CD_CreateCheckbox(_i18n("Settings.General.chk_taskbar_focus", "Focus taskbar before switch"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTaskbarFocus, _i18n("Settings.General.tip_taskbar_focus", "Set focus to the taskbar before switching desktops (workaround for focus issues)"))
    $iY += 26
    $__g_CD_idChkAutoFocus = __CD_CreateCheckbox(_i18n("Settings.General.chk_auto_focus", "Auto-focus after switch"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoFocus, _i18n("Settings.General.tip_auto_focus", "Automatically focus the foreground window after switching desktops"))
    $iY += 26
    $__g_CD_idChkCapslockMod = __CD_CreateCheckbox(_i18n("Settings.General.chk_capslock_mod", "CapsLock modifier"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkCapslockMod, _i18n("Settings.General.tip_capslock_mod", "Use CapsLock as an additional modifier key for hotkeys"))
    $iY += 34

    Local $idMinLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_min_desktops", "Min desktops on startup (0-20):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idMinLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idMinLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idMinLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idMinLbl)
    $__g_CD_idInpMinDesktops = GUICtrlCreateInput("", $iX + 205, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMinDesktops, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMinDesktops, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMinDesktops, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpMinDesktops)
    _Theme_SetTooltip($__g_CD_idInpMinDesktops, _i18n("Settings.General.tip_min_desktops", "Ensure at least this many desktops exist on startup"))
EndFunc

Func __CD_BuildTabDisplay()
    Local $t = 2, $iX = 20, $iY = 94

    $__g_CD_idChkShowCount = __CD_CreateCheckbox(_i18n("Settings.Display.chk_show_count", "Show desktop count (2/5)"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkShowCount, _i18n("Settings.Display.tip_show_count", "Show total count next to current number (e.g. '2/5')"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_count_font", "Count font size:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpCountFont = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCountFont, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCountFont, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCountFont, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpCountFont)
    _Theme_SetTooltip($__g_CD_idInpCountFont, _i18n("Settings.Display.tip_count_font", "Font size for the desktop number on the widget"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_opacity", "Widget opacity (50-255):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpOpacity = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOpacity, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOpacity, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOpacity, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpOpacity)
    _Theme_SetTooltip($__g_CD_idInpOpacity, _i18n("Settings.Display.tip_opacity", "Widget transparency (50 = very transparent, 255 = fully opaque)"))
    $iY += 30

    $__g_CD_idLblTheme = __CD_CreateCycleLabel(_i18n("Settings.Display.lbl_theme", "Theme:"), $iX, $iY, 165, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblTheme, _i18n("Settings.Display.tip_theme", "Click to cycle color scheme (requires restart)"))
    $iY += 26

    Local $idThemeHint = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_theme_hint", "Theme change requires restart"), $iX + 20, $iY, 250, 16)
    GUICtrlSetFont($idThemeHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idThemeHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idThemeHint, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idThemeHint)
    $iY += 30

    $__g_CD_idChkThumbnails = __CD_CreateCheckbox(_i18n("Settings.Display.chk_thumbnails", "Show desktop thumbnails on hover"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkThumbnails, _i18n("Settings.Display.tip_thumbnails", "Show a preview popup with window list when hovering a desktop"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_thumb_width", "Thumbnail width (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpThumbW = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbW, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbW, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbW, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpThumbW)
    _Theme_SetTooltip($__g_CD_idInpThumbW, _i18n("Settings.Display.tip_thumb_width", "Size of the thumbnail preview popup in pixels"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_thumb_height", "Thumbnail height (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpThumbH = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbH, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbH, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbH, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpThumbH)
    _Theme_SetTooltip($__g_CD_idInpThumbH, _i18n("Settings.Display.tip_thumb_height", "Size of the thumbnail preview popup in pixels"))
    $iY += 30

    $__g_CD_idChkThumbScreenshot = __CD_CreateCheckbox(_i18n("Settings.Display.chk_thumb_screenshot", "Use real desktop screenshots"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkThumbScreenshot, _i18n("Settings.Display.tip_thumb_screenshot", "Capture actual desktop screenshots instead of text preview (briefly switches desktops)"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_thumb_cache_ttl", "Screenshot cache TTL (s):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpThumbCacheTTL = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbCacheTTL, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbCacheTTL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbCacheTTL, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpThumbCacheTTL)
    _Theme_SetTooltip($__g_CD_idInpThumbCacheTTL, _i18n("Settings.Display.tip_thumb_cache_ttl", "How many seconds before cached screenshots expire (5-300)"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_font", "List font name:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListFont = GUICtrlCreateInput("", $iX + 170, $iY, 200, 22)
    GUICtrlSetFont($__g_CD_idInpListFont, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListFont, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListFont, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListFont)
    _Theme_SetTooltip($__g_CD_idInpListFont, _i18n("Settings.Display.tip_list_font", "Font for desktop list items (empty = default Fira Code/Consolas)"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_font_size", "List font size (6-14):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListFontSize = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListFontSize, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListFontSize)
    _Theme_SetTooltip($__g_CD_idInpListFontSize, _i18n("Settings.Display.tip_list_font_size", "Font size for desktop list items"))
    $iY += 34

    $__g_CD_idChkListScrollable = __CD_CreateCheckbox(_i18n("Settings.Display.chk_list_scrollable", "Scrollable desktop list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListScrollable, _i18n("Settings.Display.tip_list_scrollable", "Enable scrolling when many desktops (shows scroll arrows)"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_max_visible", "Max visible items (3-30):"), $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListMaxVisible = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListMaxVisible, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListMaxVisible, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListMaxVisible, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListMaxVisible)
    _Theme_SetTooltip($__g_CD_idInpListMaxVisible, _i18n("Settings.Display.tip_list_max_visible", "Maximum items visible before scrolling activates"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_scroll_speed", "Scroll speed (items, 1-5):"), $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListScrollSpeed = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListScrollSpeed, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListScrollSpeed, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListScrollSpeed, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListScrollSpeed)
    _Theme_SetTooltip($__g_CD_idInpListScrollSpeed, _i18n("Settings.Display.tip_list_scroll_speed", "Number of items to scroll per step"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_tooltip_font", "Tooltip font size (6-12):"), $iX, $iY + 2, 185, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpTooltipFontSize = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTooltipFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTooltipFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTooltipFontSize, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpTooltipFontSize)
    _Theme_SetTooltip($__g_CD_idInpTooltipFontSize, _i18n("Settings.Display.tip_tooltip_font", "Font size for dark-themed tooltips"))
EndFunc

Func __CD_BuildTabScroll()
    Local $t = 3, $iX = 20, $iY = 94

    $__g_CD_idChkScroll = __CD_CreateCheckbox(_i18n("Settings.Scroll.chk_scroll_enabled", "Scroll wheel on widget"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkScroll, _i18n("Settings.Scroll.tip_scroll_enabled", "Use mouse wheel on the widget to cycle desktops"))
    $iY += 26
    $__g_CD_idLblScrollDir = __CD_CreateCycleLabel(_i18n("Settings.Scroll.lbl_scroll_dir", "Direction:"), $iX + 20, $iY, 145, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblScrollDir, _i18n("Settings.Scroll.tip_scroll_dir", "Click to toggle: normal or inverted scroll direction"))
    $iY += 26
    $__g_CD_idChkScrollWrap = __CD_CreateCheckbox(_i18n("Settings.Scroll.chk_scroll_wrap", "Wrap at ends"), $iX + 20, $iY, 280, $t)
    _Theme_SetTooltip($__g_CD_idChkScrollWrap, _i18n("Settings.Scroll.tip_scroll_wrap", "Scroll past last desktop wraps to first"))
    $iY += 34
    $__g_CD_idChkListScroll = __CD_CreateCheckbox(_i18n("Settings.Scroll.chk_list_scroll", "Scroll on desktop list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListScroll, _i18n("Settings.Scroll.tip_list_scroll", "Use mouse wheel on the desktop list panel"))
    $iY += 26
    $__g_CD_idLblListAction = __CD_CreateCycleLabel(_i18n("Settings.Scroll.lbl_list_scroll_action", "List action:"), $iX + 20, $iY, 145, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblListAction, _i18n("Settings.Scroll.tip_list_scroll_action", "Click to toggle: 'switch' changes desktops, 'scroll' scrolls the list"))
EndFunc

Func __CD_BuildTabHotkeys()
    Local $t = 4, $iX = 20, $iY = 94
    Local $iLblW = 100, $iInpW = 130, $iBtnBuildW = 24, $i

    ; Dynamic label: "Desktop N:" generated per iteration below

    ; Next (build index 0)
    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_next", "Next:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkNext, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkNext)
    _Theme_SetTooltip($__g_CD_idInpHkNext, _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
    $__g_CD_idBtnHkBuild[0] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[0], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[0], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[0], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[0], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[0])
    _Theme_SetTooltip($__g_CD_idBtnHkBuild[0], _i18n("Settings.Hotkeys.tip_hotkey_builder", "Open hotkey builder to visually create a key combination"))
    $iY += 24

    ; Prev (build index 1)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_prev", "Prev:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkPrev, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkPrev)
    _Theme_SetTooltip($__g_CD_idInpHkPrev, _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
    $__g_CD_idBtnHkBuild[1] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[1], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[1], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[1], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[1], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[1])
    _Theme_SetTooltip($__g_CD_idBtnHkBuild[1], _i18n("Settings.Hotkeys.tip_hotkey_builder", "Open hotkey builder to visually create a key combination"))
    $iY += 24

    ; Desktop hotkeys (build index 2+, count from config)
    Local $iHkCount = _Cfg_GetHotkeyDesktopCount()
    If $iHkCount > 9 Then $iHkCount = 9 ; limited by array size
    For $i = 1 To $iHkCount
        $idLbl = GUICtrlCreateLabel(_i18n_Format("Settings.Hotkeys.lbl_hotkey_desktop", "Desktop {1}:", $i), $iX, $iY + 2, $iLblW, 18)
        GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idLbl, $THEME_FG_DIM)
        GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idLbl)
        $__g_CD_aidInpHkDesktop[$i] = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
        GUICtrlSetFont($__g_CD_aidInpHkDesktop[$i], 9, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidInpHkDesktop[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidInpHkDesktop[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidInpHkDesktop[$i])
        _Theme_SetTooltip($__g_CD_aidInpHkDesktop[$i], _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
        $__g_CD_idBtnHkBuild[$i + 1] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_idBtnHkBuild[$i + 1], 8, 700, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_idBtnHkBuild[$i + 1], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idBtnHkBuild[$i + 1], $THEME_BG_HOVER)
        GUICtrlSetCursor($__g_CD_idBtnHkBuild[$i + 1], 0)
        __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[$i + 1])
        _Theme_SetTooltip($__g_CD_idBtnHkBuild[$i + 1], _i18n("Settings.Hotkeys.tip_hotkey_builder", "Open hotkey builder to visually create a key combination"))
        $iY += 24
    Next

    ; Toggle List (build index 11)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_toggle", "Toggle List:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkToggleList = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkToggleList, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkToggleList, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkToggleList, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkToggleList)
    _Theme_SetTooltip($__g_CD_idInpHkToggleList, _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
    $__g_CD_idBtnHkBuild[11] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[11], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[11], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[11], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[11], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[11])
    _Theme_SetTooltip($__g_CD_idBtnHkBuild[11], _i18n("Settings.Hotkeys.tip_hotkey_builder", "Open hotkey builder to visually create a key combination"))
    $iY += 28

    ; Additional hotkey rows
    ; Last Desktop (build index 12)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_last", "Last Desktop:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkLastDesktop = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkLastDesktop, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkLastDesktop, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkLastDesktop, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkLastDesktop)
    $__g_CD_idBtnHkBuild[12] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[12], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[12], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[12], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[12], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[12])
    $iY += 24

    ; Move+Follow Next (build index 13)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_mf_next", "Move+Follow Next:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkMoveFollowNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveFollowNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveFollowNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveFollowNext, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveFollowNext)
    $__g_CD_idBtnHkBuild[13] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[13], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[13], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[13], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[13], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[13])
    $iY += 24

    ; Move+Follow Prev (build index 14)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_mf_prev", "Move+Follow Prev:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkMoveFollowPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveFollowPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveFollowPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveFollowPrev, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveFollowPrev)
    $__g_CD_idBtnHkBuild[14] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[14], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[14], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[14], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[14], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[14])
    $iY += 24

    ; Move to Next (build index 15)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_move_next", "Move to Next:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkMoveToNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveToNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveToNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveToNext, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveToNext)
    $__g_CD_idBtnHkBuild[15] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[15], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[15], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[15], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[15], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[15])
    $iY += 24

    ; Move to Prev (build index 16)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_move_prev", "Move to Prev:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkMoveToPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveToPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveToPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveToPrev, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveToPrev)
    $__g_CD_idBtnHkBuild[16] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[16], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[16], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[16], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[16], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[16])
    $iY += 24

    ; Send to New (build index 17)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_send_new", "Send to New:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkSendToNew = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkSendToNew, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkSendToNew, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkSendToNew, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkSendToNew)
    $__g_CD_idBtnHkBuild[17] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[17], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[17], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[17], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[17], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[17])
    $iY += 24

    ; Pin Window (build index 18)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_pin", "Pin Window:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkPinWindow = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkPinWindow, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkPinWindow, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkPinWindow, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkPinWindow)
    $__g_CD_idBtnHkBuild[18] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[18], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[18], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[18], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[18], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[18])
    $iY += 24

    ; Toggle Window List (build index 19)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_wl", "Toggle WinList:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkToggleWL = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkToggleWL, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkToggleWL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkToggleWL, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkToggleWL)
    $__g_CD_idBtnHkBuild[19] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[19], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[19], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[19], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[19], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[19])
    $iY += 28

    ; Help
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_format_help", "^=Ctrl  !=Alt  +=Shift  #=Win  e.g. ^!{RIGHT}"), $iX, $iY, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
EndFunc

Func __CD_BuildTabBehavior()
    Local $t = 5, $iX = 20, $iY = 94

    $__g_CD_idChkConfirmDel = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_confirm_delete", "Confirm before delete"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmDel, _i18n("Settings.Behavior.tip_confirm_delete", "Show confirmation dialog before deleting a desktop"))
    $iY += 26
    $__g_CD_idChkMidClick = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_middle_click", "Middle-click to delete"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMidClick, _i18n("Settings.Behavior.tip_middle_click", "Middle-click a desktop in the list to delete it"))
    $iY += 26
    $__g_CD_idChkMoveWin = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_move_window", "Move Window Here in menu"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMoveWin, _i18n("Settings.Behavior.tip_move_window", "Show 'Move Window Here' in the desktop right-click menu"))
    $iY += 34

    Local $aFields[5][2] = [["Peek delay (ms):", ""], ["Auto-hide timeout (ms):", ""], _
        ["Topmost interval (ms):", ""], ["Menu hide delay (ms):", ""]]

    $aFields[0][1] = "peek"
    $aFields[1][1] = "autohide"
    $aFields[2][1] = "topmost"
    $aFields[3][1] = "cmdelay"

    Local $idLbl
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_peek_delay", "Peek delay (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpPeekDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpPeekDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpPeekDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpPeekDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpPeekDelay)
    _Theme_SetTooltip($__g_CD_idInpPeekDelay, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_auto_hide", "Auto-hide timeout (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpAutoHide = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHide, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHide, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHide, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHide)
    _Theme_SetTooltip($__g_CD_idInpAutoHide, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_topmost", "Topmost interval (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpTopmost = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTopmost, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTopmost, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTopmost, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpTopmost)
    _Theme_SetTooltip($__g_CD_idInpTopmost, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_cm_delay", "Menu hide delay (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpCmDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCmDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCmDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCmDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpCmDelay)
    _Theme_SetTooltip($__g_CD_idInpCmDelay, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 34

    $__g_CD_idChkConfigWatcher = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_config_watcher", "Config file watcher"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfigWatcher, _i18n("Settings.Behavior.tip_config_watcher", "Automatically reload settings when the INI file changes"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_watcher_interval", "Watcher interval (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWatcherInterval = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWatcherInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWatcherInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWatcherInterval, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpWatcherInterval)
    _Theme_SetTooltip($__g_CD_idInpWatcherInterval, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_count_cache", "Count cache TTL (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpCountCacheTTL = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCountCacheTTL, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCountCacheTTL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCountCacheTTL, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpCountCacheTTL)
    _Theme_SetTooltip($__g_CD_idInpCountCacheTTL, _i18n("Settings.Behavior.tip_count_cache", "How long to cache desktop count before re-querying (ms)"))
    $iY += 30

    $__g_CD_idChkConfirmQuit = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_confirm_quit", "Confirm before quitting"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmQuit, _i18n("Settings.Behavior.tip_confirm_quit", "Show a confirmation dialog before exiting Desk Switcheroo"))
    $iY += 26
    $__g_CD_idChkDebugMode = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_debug_mode", "Debug mode"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkDebugMode, _i18n("Settings.Behavior.tip_debug_mode", "Enables debug features: Trigger Crash in context menu, verbose logging"))
EndFunc


Func __CD_BuildTabLogging()
    Local $t = 6, $iX = 20, $iY = 94

    $__g_CD_idChkLogging = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_logging", "Enable logging"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogging, _i18n("Settings.Logging.tip_logging", "Write debug information to a log file for troubleshooting"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_folder", "Log folder:"), $iX, $iY + 2, 100, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogPath = GUICtrlCreateInput("", $iX + 105, $iY, 248, 22)
    GUICtrlSetFont($__g_CD_idInpLogPath, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogPath, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogPath, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpLogPath)
    _Theme_SetTooltip($__g_CD_idInpLogPath, _i18n("Settings.Logging.tip_log_folder", "Folder for log files (empty = script folder). Supports %APPDATA%, %TEMP%, %SCRIPTDIR%"))
    $__g_CD_idBtnLogBrowse = GUICtrlCreateLabel(_i18n("General.btn_browse", "Browse"), $iX + 105 + 252, $iY, 48, 22, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnLogBrowse, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnLogBrowse, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnLogBrowse, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnLogBrowse, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnLogBrowse)
    $iY += 30

    $__g_CD_idLblLogLevel = __CD_CreateCycleLabel(_i18n("Settings.Logging.lbl_log_level", "Log level:"), $iX, $iY, 100, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblLogLevel, _i18n("Settings.Logging.tip_log_level", "Click to cycle: error, warn, info, debug (debug is most verbose)"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_max_size", "Max log size (MB):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogMaxSize = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpLogMaxSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogMaxSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogMaxSize, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpLogMaxSize)
    _Theme_SetTooltip($__g_CD_idInpLogMaxSize, _i18n("Settings.Logging.tip_log_max_size", "Rotate log file when it exceeds this size"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_rotate", "Rotate count (1-10):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogRotateCount = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpLogRotateCount, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogRotateCount, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogRotateCount, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpLogRotateCount)
    _Theme_SetTooltip($__g_CD_idInpLogRotateCount, _i18n("Settings.Logging.tip_log_rotate", "Number of rotated log files to keep (1-10)"))
    $iY += 30

    $__g_CD_idChkLogCompress = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_log_compress", "Compress old logs"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogCompress, _i18n("Settings.Logging.tip_log_compress", "Zip old log files when rotating (uses PowerShell)"))
    $iY += 34

    $__g_CD_idChkLogPID = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_log_pid", "Include PID in log"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogPID, _i18n("Settings.Logging.tip_log_pid", "Add process ID [PID:XXXX] to each log line after the timestamp"))
    $iY += 34

    $__g_CD_idLblLogDateFormat = __CD_CreateCycleLabel(_i18n("Settings.Logging.lbl_log_date", "Date format:"), $iX, $iY, 100, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblLogDateFormat, _i18n("Settings.Logging.tip_log_date", "Click to cycle: iso (YYYY-MM-DD), us (MM/DD/YYYY), eu (DD/MM/YYYY)"))
    $iY += 30

    $__g_CD_idChkLogFlush = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_log_flush", "Flush immediately"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogFlush, _i18n("Settings.Logging.tip_log_flush", "Flush log file after every write (vs buffered I/O)"))
EndFunc

Func __CD_BuildTabUpdates()
    Local $t = 7, $iX = 20, $iY = 94

    ; Current version display
    Local $idVerLbl = GUICtrlCreateLabel(_i18n_Format("Settings.Updates.lbl_current_version", "Current version: v{1}", $APP_VERSION), $iX, $iY, 300, 18)
    GUICtrlSetFont($idVerLbl, 9, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idVerLbl, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idVerLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idVerLbl)
    $iY += 26

    $__g_CD_idChkAutoUpdate = __CD_CreateCheckbox(_i18n("Settings.Updates.chk_auto_update", "Auto-check for updates"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoUpdate, _i18n("Settings.Updates.tip_auto_update", "Periodically check GitHub for new releases"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Updates.lbl_update_interval", "Check interval (hours):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpUpdateInterval = GUICtrlCreateInput("", $iX + 170, $iY, 100, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpUpdateInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpUpdateInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpUpdateInterval, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpUpdateInterval)
    _Theme_SetTooltip($__g_CD_idInpUpdateInterval, _i18n("Settings.Updates.tip_update_interval", "How often to check for updates (in hours)"))
    $iY += 34

    $__g_CD_idChkUpdateOnStartup = __CD_CreateCheckbox(_i18n("Settings.Updates.chk_check_startup", "Check on startup"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkUpdateOnStartup, _i18n("Settings.Updates.tip_check_startup", "Check for updates when the application starts (respects day interval)"))
    $iY += 34

    Local $idLblDays = GUICtrlCreateLabel(_i18n("Settings.Updates.lbl_check_days", "Check every (days):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblDays, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblDays, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblDays, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblDays)
    $__g_CD_idInpUpdateCheckDays = GUICtrlCreateInput("", $iX + 170, $iY, 100, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpUpdateCheckDays, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpUpdateCheckDays, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpUpdateCheckDays, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpUpdateCheckDays)
    _Theme_SetTooltip($__g_CD_idInpUpdateCheckDays, _i18n("Settings.Updates.tip_check_days", "Minimum days between startup update checks (1-90)"))
    $iY += 34

    $__g_CD_idBtnCheckNow = GUICtrlCreateLabel(ChrW(0x21BB) & " " & _i18n("Settings.Updates.btn_check_now", "Check Now"), $iX, $iY, 120, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnCheckNow, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnCheckNow, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnCheckNow, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnCheckNow, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnCheckNow)
    _Theme_SetTooltip($__g_CD_idBtnCheckNow, _i18n("Settings.Updates.tip_check_now", "Check for updates right now"))

    $__g_CD_idBtnDownloadLatest = GUICtrlCreateLabel(ChrW(0x2B07) & " " & _i18n("Settings.Updates.btn_download", "Download Latest"), $iX + 130, $iY, 140, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnDownloadLatest, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnDownloadLatest, $THEME_FG_LINK)
    GUICtrlSetBkColor($__g_CD_idBtnDownloadLatest, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnDownloadLatest, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnDownloadLatest)
    _Theme_SetTooltip($__g_CD_idBtnDownloadLatest, _i18n("Settings.Updates.tip_download", "Download the latest portable version to your Downloads folder"))
EndFunc

Func __CD_BuildTabDesktops()
    Local $t = 8, $iX = 20, $iY = 94

    ; Enable desktop colors checkbox (moved from removed Colors tab)
    $__g_CD_idChkColorsEnabled = __CD_CreateCheckbox(_i18n("Settings.Desktops.chk_colors_enabled", "Enable desktop colors"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkColorsEnabled, _i18n("Settings.Desktops.tip_colors_enabled", "Show colored indicators next to desktop names in the list"))
    $iY += 28

    ; Get current desktop count, limit to what fits in content area
    Local $iCount = _VD_GetCount()
    Local $iMaxRows = Int(($__g_CD_iContentH - 100) / 24) ; 100px for checkbox + header + padding
    If $iMaxRows < 3 Then $iMaxRows = 3
    If $iCount > $iMaxRows Then $iCount = $iMaxRows
    If $iCount > 20 Then $iCount = 20
    $__g_CD_iDeskCount = $iCount

    ; Header
    Local $idHdr = GUICtrlCreateLabel(_i18n("Settings.Desktops.lbl_desktop_header", "Desktop    Label                     Color"), $iX, $iY, 400, 16)
    GUICtrlSetFont($idHdr, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHdr, $THEME_FG_DIM)
    GUICtrlSetBkColor($idHdr, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idHdr)
    $iY += 20

    Local $i
    For $i = 1 To $iCount
        ; Desktop number
        Local $idNum = GUICtrlCreateLabel(StringRight("0" & $i, 2), $iX, $iY + 2, 30, 18)
        GUICtrlSetFont($idNum, 8, 700, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($idNum, $THEME_FG_PRIMARY)
        GUICtrlSetBkColor($idNum, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idNum)

        ; Label input
        $__g_CD_aidDeskLabel[$i] = GUICtrlCreateInput("", $iX + 35, $iY, 180, 20)
        GUICtrlSetFont($__g_CD_aidDeskLabel[$i], 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidDeskLabel[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidDeskLabel[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidDeskLabel[$i])

        ; Color hex input
        $__g_CD_aidDeskColor[$i] = GUICtrlCreateInput("", $iX + 225, $iY, 70, 20)
        GUICtrlSetFont($__g_CD_aidDeskColor[$i], 8, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidDeskColor[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidDeskColor[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidDeskColor[$i])

        ; Color preview
        $__g_CD_aidDeskPreview[$i] = GUICtrlCreateLabel("", $iX + 305, $iY + 2, 16, 16)
        __CD_RegCtrl($t, $__g_CD_aidDeskPreview[$i])

        $iY += 24
    Next
EndFunc

Func __CD_BuildTabWallpaper()
    Local $t = 10, $iX = 20, $iY = 94

    $__g_CD_idChkWallpaper = __CD_CreateCheckbox(_i18n("Settings.Wallpaper.chk_wallpaper_enabled", "Enable per-desktop wallpaper"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWallpaper, _i18n("Settings.Wallpaper.tip_wallpaper_enabled", "Automatically change wallpaper when switching desktops"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Wallpaper.lbl_wallpaper_delay", "Change delay (ms, 50-2000):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWallpaperDelay = GUICtrlCreateInput("", $iX + 205, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWallpaperDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWallpaperDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWallpaperDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpWallpaperDelay)
    _Theme_SetTooltip($__g_CD_idInpWallpaperDelay, _i18n("Settings.Wallpaper.tip_wallpaper_delay", "Delay before applying wallpaper after switching (ms)"))
    $iY += 34

    Local $i
    For $i = 1 To 9
        $idLbl = GUICtrlCreateLabel(_i18n_Format("Settings.Wallpaper.lbl_desktop_n", "Desktop {1}:", $i), $iX, $iY + 2, 65, 18)
        GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idLbl, $THEME_FG_DIM)
        GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idLbl)
        $__g_CD_aidWallpaperPath[$i] = GUICtrlCreateInput("", $iX + 70, $iY, 270, 20)
        GUICtrlSetFont($__g_CD_aidWallpaperPath[$i], 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidWallpaperPath[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidWallpaperPath[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidWallpaperPath[$i])
        $__g_CD_aidWallpaperBrowse[$i] = GUICtrlCreateLabel("...", $iX + 344, $iY, 24, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidWallpaperBrowse[$i], 8, 700, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidWallpaperBrowse[$i], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidWallpaperBrowse[$i], $THEME_BG_HOVER)
        GUICtrlSetCursor($__g_CD_aidWallpaperBrowse[$i], 0)
        __CD_RegCtrl($t, $__g_CD_aidWallpaperBrowse[$i])
        $iY += 24
    Next
EndFunc

Func __CD_BuildTabWindowList()
    Local $t = 11, $iX = 20, $iY = 94

    $__g_CD_idChkWLEnabled = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_enabled", "Enable window list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLEnabled, _i18n("Settings.WindowList.tip_wl_enabled", "Show a panel listing windows on the current desktop"))
    $iY += 34

    $__g_CD_idLblWLScope = __CD_CreateCycleLabel(_i18n("Settings.WindowList.lbl_wl_scope", "Window scope:"), $iX, $iY, 165, 110, $t)
    _Theme_SetTooltip($__g_CD_idLblWLScope, _i18n("Settings.WindowList.tip_wl_scope", "Show windows from current desktop only or all desktops"))
    $iY += 30

    $__g_CD_idLblWLPosition = __CD_CreateCycleLabel(_i18n("Settings.WindowList.lbl_wl_position", "Panel position:"), $iX, $iY, 165, 110, $t)
    _Theme_SetTooltip($__g_CD_idLblWLPosition, _i18n("Settings.WindowList.tip_wl_position", "Click to cycle panel position on screen"))
    $iY += 30

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_width", "Panel width (150-600):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWLWidth = GUICtrlCreateInput("", $iX + 170, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWLWidth, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWLWidth, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWLWidth, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpWLWidth)
    _Theme_SetTooltip($__g_CD_idInpWLWidth, _i18n("Settings.WindowList.tip_wl_width", "Width of the window list panel in pixels"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_max_visible", "Max visible windows (5-50):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWLMaxVisible = GUICtrlCreateInput("", $iX + 170, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWLMaxVisible, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWLMaxVisible, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWLMaxVisible, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpWLMaxVisible)
    _Theme_SetTooltip($__g_CD_idInpWLMaxVisible, _i18n("Settings.WindowList.tip_wl_max_visible", "Maximum number of windows shown before scrolling"))
    $iY += 34

    $__g_CD_idChkWLIcons = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_icons", "Show app icons"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLIcons, _i18n("Settings.WindowList.tip_wl_icons", "Display application icons next to window titles"))
    $iY += 26
    $__g_CD_idChkWLSearch = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_search", "Show search bar"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLSearch, _i18n("Settings.WindowList.tip_wl_search", "Show a search/filter bar at the top of the window list"))
    $iY += 26
    $__g_CD_idChkWLAutoRefresh = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_auto_refresh", "Auto-refresh"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLAutoRefresh, _i18n("Settings.WindowList.tip_wl_auto_refresh", "Automatically update the window list at regular intervals"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_refresh_interval", "Refresh interval (ms, 500-10000):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWLRefreshInterval = GUICtrlCreateInput("", $iX + 205, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWLRefreshInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWLRefreshInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWLRefreshInterval, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpWLRefreshInterval)
    _Theme_SetTooltip($__g_CD_idInpWLRefreshInterval, _i18n("Settings.WindowList.tip_wl_refresh_interval", "How often to refresh the window list (ms)"))
EndFunc

Func __CD_BuildTabExplorer()
    Local $t = 12, $iX = 20, $iY = 94

    $__g_CD_idChkExplorerMonitor = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_explorer_monitor", "Enable shell monitor"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkExplorerMonitor, _i18n("Settings.Explorer.tip_explorer_monitor", "Monitor the shell process and attempt recovery on crash"))
    $iY += 34

    ; Shell process name
    Local $idLblProc = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_shell_process", "Shell process:"), $iX, $iY + 2, 120, 18)
    GUICtrlSetFont($idLblProc, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblProc, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblProc, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblProc)
    $__g_CD_idInpShellProcess = GUICtrlCreateInput("", $iX + 125, $iY, 160, 22)
    GUICtrlSetFont($__g_CD_idInpShellProcess, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpShellProcess, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpShellProcess, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpShellProcess)
    _Theme_SetTooltip($__g_CD_idInpShellProcess, _i18n("Settings.Explorer.tip_shell_process", "Process name to monitor (default: explorer.exe)"))
    $iY += 30

    ; Check interval
    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_explorer_interval", "Check interval (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpExplorerInterval = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpExplorerInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpExplorerInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpExplorerInterval, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpExplorerInterval)
    _Theme_SetTooltip($__g_CD_idInpExplorerInterval, _i18n("Settings.Explorer.tip_explorer_interval", "How often to check if the shell is alive (ms)"))
    $iY += 30

    ; Auto-restart
    $__g_CD_idChkAutoRestart = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_auto_restart", "Auto-restart on crash"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoRestart, _i18n("Settings.Explorer.tip_auto_restart", "Attempt to restart the shell process automatically when a crash is detected"))
    $iY += 26

    ; Restart delay
    Local $idLblRD = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_restart_delay", "Restart delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblRD, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblRD, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblRD, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblRD)
    $__g_CD_idInpRestartDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpRestartDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpRestartDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpRestartDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpRestartDelay)
    _Theme_SetTooltip($__g_CD_idInpRestartDelay, _i18n("Settings.Explorer.tip_restart_delay", "Wait this long before attempting restart (ms)"))
    $iY += 34

    ; Max retries
    Local $idLblMR = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_max_retries", "Max retries (0=unlimited):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblMR, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblMR, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblMR, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblMR)
    $__g_CD_idInpMaxRetries = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMaxRetries, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMaxRetries, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMaxRetries, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpMaxRetries)
    _Theme_SetTooltip($__g_CD_idInpMaxRetries, _i18n("Settings.Explorer.tip_max_retries", "Maximum restart attempts (0 = unlimited)"))
    $iY += 30

    ; Retry delay
    Local $idLblRDl = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_retry_delay", "Retry delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblRDl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblRDl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblRDl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblRDl)
    $__g_CD_idInpRetryDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpRetryDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpRetryDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpRetryDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpRetryDelay)
    _Theme_SetTooltip($__g_CD_idInpRetryDelay, _i18n("Settings.Explorer.tip_retry_delay", "Initial delay between retry attempts (ms)"))
    $iY += 30

    ; Exponential backoff
    $__g_CD_idChkExpBackoff = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_exp_backoff", "Exponential backoff"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkExpBackoff, _i18n("Settings.Explorer.tip_exp_backoff", "Double the retry delay after each failed attempt"))
    $iY += 26

    ; Max retry delay
    Local $idLblMD = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_max_retry_delay", "Max retry delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblMD, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblMD, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblMD, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblMD)
    $__g_CD_idInpMaxRetryDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMaxRetryDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMaxRetryDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMaxRetryDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpMaxRetryDelay)
    _Theme_SetTooltip($__g_CD_idInpMaxRetryDelay, _i18n("Settings.Explorer.tip_max_retry_delay", "Maximum delay cap for exponential backoff (ms)"))
    $iY += 34

    ; Notify on recovery
    $__g_CD_idChkExplorerNotify = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_explorer_notify", "Notify on recovery"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkExplorerNotify, _i18n("Settings.Explorer.tip_explorer_notify", "Show a toast when the shell is recovered after a crash"))
EndFunc

Func __CD_BuildTabNotifications()
    Local $t = 13, $iX = 20, $iY = 94

    $__g_CD_idChkNotifyMoved = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_moved", "Window sent to desktop"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyMoved, _i18n("Settings.Notifications.tip_notify_moved", "Show a toast when a window is moved to another desktop"))
    $iY += 26
    $__g_CD_idChkNotifyCreated = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_created", "Desktop created"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyCreated, _i18n("Settings.Notifications.tip_notify_created", "Show a toast when a new desktop is created"))
    $iY += 26
    $__g_CD_idChkNotifyDeleted = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_deleted", "Desktop deleted"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyDeleted, _i18n("Settings.Notifications.tip_notify_deleted", "Show a toast when a desktop is deleted"))
    $iY += 26
    $__g_CD_idChkNotifyPinned = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_pinned", "Window pinned"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyPinned, _i18n("Settings.Notifications.tip_notify_pinned", "Show a toast when a window is pinned to all desktops"))
    $iY += 26
    $__g_CD_idChkNotifyUnpinned = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_unpinned", "Window unpinned"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyUnpinned, _i18n("Settings.Notifications.tip_notify_unpinned", "Show a toast when a window is unpinned"))
    $iY += 26
    $__g_CD_idChkNotifyExplorerRecov = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_explorer", "Shell monitor recovery"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyExplorerRecov, _i18n("Settings.Notifications.tip_notify_explorer", "Show a toast when the shell process recovers from a crash"))
EndFunc

; =============================================
; POPULATE FROM CONFIG
; =============================================

Func __CD_BuildTabAnimations()
    Local $t = 9, $iX = 20, $iY = 94

    $__g_CD_idChkAnimEnabled = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_enabled", "Enable animations"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAnimEnabled, _i18n("Settings.Animations.tip_enabled", "Master toggle for all fade-in/fade-out animations"))
    $iY += 28

    ; Per-location toggles
    $__g_CD_idChkAnimList = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_list", "Desktop list"), $iX + 20, $iY, 130, $t)
    $__g_CD_idChkAnimMenus = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_menus", "Menus"), $iX + 155, $iY, 100, $t)
    $__g_CD_idChkAnimDialogs = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_dialogs", "Dialogs"), $iX + 260, $iY, 100, $t)
    $iY += 24
    $__g_CD_idChkAnimToasts = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_toasts", "Toasts"), $iX + 20, $iY, 130, $t)
    $__g_CD_idChkAnimWidget = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_widget", "Widget"), $iX + 155, $iY, 100, $t)
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_in", "Fade-in duration (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeIn = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeIn, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeIn, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeIn, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpFadeIn)
    _Theme_SetTooltip($__g_CD_idInpFadeIn, _i18n("Settings.Animations.tip_fade_in", "Total time for fade-in effect in milliseconds (0 = instant)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_out", "Fade-out duration (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeOut = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeOut, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeOut, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeOut, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpFadeOut)
    _Theme_SetTooltip($__g_CD_idInpFadeOut, _i18n("Settings.Animations.tip_fade_out", "Total time for fade-out effect in milliseconds (0 = instant)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_step", "Fade step (alpha, 5-255):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeStep = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeStep, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeStep, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeStep, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpFadeStep)
    _Theme_SetTooltip($__g_CD_idInpFadeStep, _i18n("Settings.Animations.tip_fade_step", "Alpha increment per frame (higher = faster, fewer frames)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_sleep", "Frame delay (ms, 1-50):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeSleep = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeSleep, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeSleep, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeSleep, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpFadeSleep)
    _Theme_SetTooltip($__g_CD_idInpFadeSleep, _i18n("Settings.Animations.tip_fade_sleep", "Sleep between fade frames (lower = smoother but more CPU)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_toast_fade", "Toast fade-out (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpToastFadeOut = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpToastFadeOut, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpToastFadeOut, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpToastFadeOut, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpToastFadeOut)
    _Theme_SetTooltip($__g_CD_idInpToastFadeOut, _i18n("Settings.Animations.tip_toast_fade", "Duration of toast notification fade-out in milliseconds"))
EndFunc

Func __CD_PopulateControls()
    Local $i
    ; General
    __CD_SetCheckState($__g_CD_idChkStartWin, _Cfg_GetStartWithWindows())
    __CD_SetCheckState($__g_CD_idChkWrapNav, _Cfg_GetWrapNavigation())
    __CD_SetCheckState($__g_CD_idChkAutoCreate, _Cfg_GetAutoCreateDesktop())
    GUICtrlSetData($__g_CD_idInpPadding, _Cfg_GetNumberPadding())
    GUICtrlSetData($__g_CD_idLblPosition, _Cfg_GetWidgetPosition())
    ; Populate language dropdown with all available locales
    Local $sLangCode = _Cfg_GetLanguage()
    Local $sAllDisplay = _i18n_GetAvailableDisplay()
    Local $sCurrentDisplay = ""
    ; Build combo items (pipe-delimited) and find current
    Local $aLangs = StringSplit($sAllDisplay, "|")
    Local $sComboList = ""
    Local $iL
    For $iL = 1 To $aLangs[0]
        If $sComboList <> "" Then $sComboList &= "|"
        $sComboList &= $aLangs[$iL]
        If StringLeft($aLangs[$iL], StringLen($sLangCode)) = $sLangCode Then $sCurrentDisplay = $aLangs[$iL]
    Next
    GUICtrlSetData($__g_CD_idLblLanguage, $sComboList, $sCurrentDisplay)
    GUICtrlSetData($__g_CD_idComboOverlay, " " & $sCurrentDisplay & "  " & ChrW(0x25BE))
    GUICtrlSetData($__g_CD_idInpOffsetX, _Cfg_GetWidgetOffsetX())
    __CD_SetCheckState($__g_CD_idChkWidgetDrag, _Cfg_GetWidgetDragEnabled())
    __CD_SetCheckState($__g_CD_idChkWidgetColorBar, _Cfg_GetWidgetColorBar())
    __CD_SetCheckState($__g_CD_idChkTrayMode, _Cfg_GetTrayIconMode())
    __CD_SetCheckState($__g_CD_idChkQuickAccess, _Cfg_GetQuickAccessEnabled())
    __CD_SetCheckState($__g_CD_idChkListKeyNav, _Cfg_GetListKeyboardNav())

    ; Display
    __CD_SetCheckState($__g_CD_idChkShowCount, _Cfg_GetShowCount())
    GUICtrlSetData($__g_CD_idInpCountFont, _Cfg_GetCountFontSize())
    GUICtrlSetData($__g_CD_idInpOpacity, _Cfg_GetThemeAlphaMain())
    GUICtrlSetData($__g_CD_idLblTheme, _Cfg_GetTheme())
    __CD_SetCheckState($__g_CD_idChkThumbnails, _Cfg_GetThumbnailsEnabled())
    GUICtrlSetData($__g_CD_idInpThumbW, _Cfg_GetThumbnailWidth())
    GUICtrlSetData($__g_CD_idInpThumbH, _Cfg_GetThumbnailHeight())
    __CD_SetCheckState($__g_CD_idChkThumbScreenshot, _Cfg_GetThumbnailUseScreenshot())
    GUICtrlSetData($__g_CD_idInpThumbCacheTTL, _Cfg_GetThumbnailCacheTTL())
    GUICtrlSetData($__g_CD_idInpListFont, _Cfg_GetListFontName())
    GUICtrlSetData($__g_CD_idInpListFontSize, _Cfg_GetListFontSize())
    GUICtrlSetData($__g_CD_idInpTooltipFontSize, _Cfg_GetTooltipFontSize())
    __CD_SetCheckState($__g_CD_idChkListScrollable, _Cfg_GetListScrollable())
    GUICtrlSetData($__g_CD_idInpListMaxVisible, _Cfg_GetListMaxVisible())
    GUICtrlSetData($__g_CD_idInpListScrollSpeed, _Cfg_GetListScrollSpeed())

    ; Scroll
    __CD_SetCheckState($__g_CD_idChkScroll, _Cfg_GetScrollEnabled())
    GUICtrlSetData($__g_CD_idLblScrollDir, _Cfg_GetScrollDirection())
    __CD_SetCheckState($__g_CD_idChkScrollWrap, _Cfg_GetScrollWrap())
    __CD_SetCheckState($__g_CD_idChkListScroll, _Cfg_GetListScrollEnabled())
    GUICtrlSetData($__g_CD_idLblListAction, _Cfg_GetListScrollAction())

    ; Hotkeys
    GUICtrlSetData($__g_CD_idInpHkNext, _Cfg_GetHotkeyNext())
    GUICtrlSetData($__g_CD_idInpHkPrev, _Cfg_GetHotkeyPrev())
    For $i = 1 To 9
        GUICtrlSetData($__g_CD_aidInpHkDesktop[$i], _Cfg_GetHotkeyDesktop($i))
    Next
    GUICtrlSetData($__g_CD_idInpHkToggleList, _Cfg_GetHotkeyToggleList())

    ; Behavior
    __CD_SetCheckState($__g_CD_idChkConfirmDel, _Cfg_GetConfirmDelete())
    __CD_SetCheckState($__g_CD_idChkMidClick, _Cfg_GetMiddleClickDelete())
    __CD_SetCheckState($__g_CD_idChkMoveWin, _Cfg_GetMoveWindowEnabled())
    GUICtrlSetData($__g_CD_idInpPeekDelay, _Cfg_GetPeekBounceDelay())
    GUICtrlSetData($__g_CD_idInpAutoHide, _Cfg_GetAutoHideTimeout())
    GUICtrlSetData($__g_CD_idInpTopmost, _Cfg_GetTopmostInterval())
    GUICtrlSetData($__g_CD_idInpCmDelay, _Cfg_GetCmAutoHideDelay())
    __CD_SetCheckState($__g_CD_idChkConfigWatcher, _Cfg_GetConfigWatcherEnabled())
    GUICtrlSetData($__g_CD_idInpWatcherInterval, _Cfg_GetConfigWatcherInterval())
    GUICtrlSetData($__g_CD_idInpCountCacheTTL, _Cfg_GetCountCacheTTL())
    __CD_SetCheckState($__g_CD_idChkConfirmQuit, _Cfg_GetConfirmQuit())
    __CD_SetCheckState($__g_CD_idChkDebugMode, _Cfg_GetDebugMode())

    ; Logging
    __CD_SetCheckState($__g_CD_idChkLogging, _Cfg_GetLoggingEnabled())
    GUICtrlSetData($__g_CD_idInpLogPath, _Cfg_GetLogFolder())
    GUICtrlSetData($__g_CD_idLblLogLevel, _Cfg_GetLogLevel())
    GUICtrlSetData($__g_CD_idInpLogMaxSize, _Cfg_GetLogMaxSizeMB())
    GUICtrlSetData($__g_CD_idInpLogRotateCount, _Cfg_GetLogRotateCount())
    __CD_SetCheckState($__g_CD_idChkLogCompress, _Cfg_GetLogCompressOld())
    __CD_SetCheckState($__g_CD_idChkLogPID, _Cfg_GetLogIncludePID())
    GUICtrlSetData($__g_CD_idLblLogDateFormat, _Cfg_GetLogDateFormat())
    __CD_SetCheckState($__g_CD_idChkLogFlush, _Cfg_GetLogFlushImmediate())

    ; Updates
    __CD_SetCheckState($__g_CD_idChkAutoUpdate, _Cfg_GetAutoUpdateEnabled())
    GUICtrlSetData($__g_CD_idInpUpdateInterval, _Cfg_GetAutoUpdateIntervalHours())
    __CD_SetCheckState($__g_CD_idChkUpdateOnStartup, _Cfg_GetUpdateCheckOnStartup())
    GUICtrlSetData($__g_CD_idInpUpdateCheckDays, _Cfg_GetUpdateCheckDays())

    ; Desktops
    For $i = 1 To $__g_CD_iDeskCount
        GUICtrlSetData($__g_CD_aidDeskLabel[$i], _Labels_Load($i))
        Local $iClr = _Cfg_GetDesktopColor($i)
        If $iClr > 0 Then
            GUICtrlSetData($__g_CD_aidDeskColor[$i], Hex($iClr, 6))
            GUICtrlSetBkColor($__g_CD_aidDeskPreview[$i], $iClr)
        Else
            GUICtrlSetData($__g_CD_aidDeskColor[$i], "")
            GUICtrlSetBkColor($__g_CD_aidDeskPreview[$i], $THEME_BG_INPUT)
        EndIf
    Next

    ; Animations
    __CD_SetCheckState($__g_CD_idChkAnimEnabled, _Cfg_GetAnimationsEnabled())
    __CD_SetCheckState($__g_CD_idChkAnimList, _Cfg_GetAnimList())
    __CD_SetCheckState($__g_CD_idChkAnimMenus, _Cfg_GetAnimMenus())
    __CD_SetCheckState($__g_CD_idChkAnimDialogs, _Cfg_GetAnimDialogs())
    __CD_SetCheckState($__g_CD_idChkAnimToasts, _Cfg_GetAnimToasts())
    __CD_SetCheckState($__g_CD_idChkAnimWidget, _Cfg_GetAnimWidget())
    GUICtrlSetData($__g_CD_idInpFadeIn, _Cfg_GetFadeInDuration())
    GUICtrlSetData($__g_CD_idInpFadeOut, _Cfg_GetFadeOutDuration())
    GUICtrlSetData($__g_CD_idInpFadeStep, _Cfg_GetFadeStep())
    GUICtrlSetData($__g_CD_idInpFadeSleep, _Cfg_GetFadeSleepMs())
    GUICtrlSetData($__g_CD_idInpToastFadeOut, _Cfg_GetToastFadeOutDuration())

    ; General extras
    __CD_SetCheckState($__g_CD_idChkSingleton, _Cfg_GetSingletonEnabled())
    __CD_SetCheckState($__g_CD_idChkTaskbarFocus, _Cfg_GetTaskbarFocusTrick())
    __CD_SetCheckState($__g_CD_idChkAutoFocus, _Cfg_GetAutoFocusAfterSwitch())
    __CD_SetCheckState($__g_CD_idChkCapslockMod, _Cfg_GetCapslockModifier())
    GUICtrlSetData($__g_CD_idInpMinDesktops, _Cfg_GetMinDesktops())

    ; Hotkeys extras
    GUICtrlSetData($__g_CD_idInpHkLastDesktop, _Cfg_GetHotkeyToggleLast())
    GUICtrlSetData($__g_CD_idInpHkMoveFollowNext, _Cfg_GetHotkeyMoveFollowNext())
    GUICtrlSetData($__g_CD_idInpHkMoveFollowPrev, _Cfg_GetHotkeyMoveFollowPrev())
    GUICtrlSetData($__g_CD_idInpHkMoveToNext, _Cfg_GetHotkeyMoveNext())
    GUICtrlSetData($__g_CD_idInpHkMoveToPrev, _Cfg_GetHotkeyMovePrev())
    GUICtrlSetData($__g_CD_idInpHkSendToNew, _Cfg_GetHotkeySendNewDesktop())
    GUICtrlSetData($__g_CD_idInpHkPinWindow, _Cfg_GetHotkeyPinWindow())
    GUICtrlSetData($__g_CD_idInpHkToggleWL, _Cfg_GetHotkeyToggleWindowList())

    ; Wallpaper
    __CD_SetCheckState($__g_CD_idChkWallpaper, _Cfg_GetWallpaperEnabled())
    GUICtrlSetData($__g_CD_idInpWallpaperDelay, _Cfg_GetWallpaperChangeDelay())
    For $i = 1 To 9
        GUICtrlSetData($__g_CD_aidWallpaperPath[$i], _Cfg_GetDesktopWallpaper($i))
    Next

    ; Window List
    __CD_SetCheckState($__g_CD_idChkWLEnabled, _Cfg_GetWindowListEnabled())
    GUICtrlSetData($__g_CD_idLblWLPosition, _Cfg_GetWindowListPosition())
    GUICtrlSetData($__g_CD_idInpWLWidth, _Cfg_GetWindowListWidth())
    GUICtrlSetData($__g_CD_idInpWLMaxVisible, _Cfg_GetWindowListMaxVisible())
    __CD_SetCheckState($__g_CD_idChkWLIcons, _Cfg_GetWindowListShowIcons())
    __CD_SetCheckState($__g_CD_idChkWLSearch, _Cfg_GetWindowListSearch())
    __CD_SetCheckState($__g_CD_idChkWLAutoRefresh, _Cfg_GetWindowListAutoRefresh())
    GUICtrlSetData($__g_CD_idInpWLRefreshInterval, _Cfg_GetWindowListRefreshInterval())

    ; Explorer
    __CD_SetCheckState($__g_CD_idChkExplorerMonitor, _Cfg_GetExplorerMonitorEnabled())
    GUICtrlSetData($__g_CD_idInpShellProcess, _Cfg_GetShellProcessName())
    GUICtrlSetData($__g_CD_idInpExplorerInterval, _Cfg_GetExplorerCheckInterval())
    __CD_SetCheckState($__g_CD_idChkAutoRestart, _Cfg_GetMonitorAutoRestart())
    GUICtrlSetData($__g_CD_idInpRestartDelay, _Cfg_GetMonitorRestartDelay())
    GUICtrlSetData($__g_CD_idInpMaxRetries, _Cfg_GetMonitorMaxRetries())
    GUICtrlSetData($__g_CD_idInpRetryDelay, _Cfg_GetMonitorRetryDelay())
    __CD_SetCheckState($__g_CD_idChkExpBackoff, _Cfg_GetMonitorExpBackoff())
    GUICtrlSetData($__g_CD_idInpMaxRetryDelay, _Cfg_GetMonitorMaxRetryDelay())
    __CD_SetCheckState($__g_CD_idChkExplorerNotify, _Cfg_GetExplorerNotifyRecovery())

    ; Notifications
    __CD_SetCheckState($__g_CD_idChkNotifyMoved, _Cfg_GetNotifyWindowMoved())
    __CD_SetCheckState($__g_CD_idChkNotifyCreated, _Cfg_GetNotifyDesktopCreated())
    __CD_SetCheckState($__g_CD_idChkNotifyDeleted, _Cfg_GetNotifyDesktopDeleted())
    __CD_SetCheckState($__g_CD_idChkNotifyPinned, _Cfg_GetNotifyWindowPinned())
    __CD_SetCheckState($__g_CD_idChkNotifyUnpinned, _Cfg_GetNotifyWindowUnpinned())
    __CD_SetCheckState($__g_CD_idChkNotifyExplorerRecov, _Cfg_GetNotifyExplorerRecovery())
    GUICtrlSetData($__g_CD_idLblWLScope, _Cfg_GetWindowListScope())
EndFunc

; =============================================
; BLOCKING MESSAGE LOOP
; =============================================

Func __CD_MessageLoop()
    Local $iHovered = 0, $iTabHovered = 0, $t

    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $__g_CD_hGUI Then
            Local $id = $aMsg[0]
            Switch $id
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $__g_CD_idBtnApply
                    __CD_ApplyChanges()
                Case $__g_CD_idBtnReset
                    __CD_ResetDefaults()
                Case $__g_CD_idBtnImport
                    __CD_ImportSettings()
                Case $__g_CD_idBtnExport
                    __CD_ExportSettings()
                Case $__g_CD_idBtnRestart
                    __CD_RestartApp()
                    ExitLoop
                Case $__g_CD_idBtnClose
                    ExitLoop
                Case $__g_CD_idBtnCheckNow
                    _UC_CheckNow()
                Case $__g_CD_idBtnDownloadLatest
                    _UC_DownloadPortable()
                Case $__g_CD_idBtnLogBrowse
                    Local $sFolder = FileSelectFolder("Select log folder", "", 7, GUICtrlRead($__g_CD_idInpLogPath), $__g_CD_hGUI)
                    If $sFolder <> "" Then GUICtrlSetData($__g_CD_idInpLogPath, $sFolder)
            EndSwitch

            ; Wallpaper browse button clicks
            Local $iBrowseIdx
            For $iBrowseIdx = 1 To 9
                If $id = $__g_CD_aidWallpaperBrowse[$iBrowseIdx] Then
                    Local $sWpFile = FileOpenDialog("Select wallpaper", "", "Images (*.jpg;*.jpeg;*.png;*.bmp)", 1, "", $__g_CD_hGUI)
                    If $sWpFile <> "" Then GUICtrlSetData($__g_CD_aidWallpaperPath[$iBrowseIdx], $sWpFile)
                EndIf
            Next

            ; Tab button clicks
            For $t = 1 To 13
                If $id = $__g_CD_aidTabBtn[$t] Then
                    $iTabHovered = 0
                    __CD_SwitchTab($t)
                    ExitLoop
                EndIf
            Next

            ; Checkbox clicks (label-based, handle box + text clicks)
            __CD_HandleCheckboxClick($id)

            ; Hotkey builder "..." button clicks
            __CD_HandleHotkeyBuildClick($id)

            ; Cycle label clicks
            If $id = $__g_CD_idLblPosition Then __CD_CycleValue($id, "bottom-left|bottom-center|bottom-right|middle-left|middle-right|top-left|top-center|top-right")
            If $id = $__g_CD_idLblScrollDir Then __CD_CycleValue($id, "normal|inverted")
            If $id = $__g_CD_idLblListAction Then __CD_CycleValue($id, "switch|scroll")
            If $id = $__g_CD_idLblTheme Then __CD_CycleValue($id, _Theme_GetAvailableSchemes())
            If $id = $__g_CD_idLblLogLevel Then __CD_CycleValue($id, "error|warn|info|debug")
            If $id = $__g_CD_idLblLogDateFormat Then __CD_CycleValue($id, "iso|us|eu")
            If $id = $__g_CD_idLblWLPosition Then __CD_CycleValue($id, "top-left|top-right|bottom-left|bottom-right")
            If $id = $__g_CD_idLblWLScope Then __CD_CycleValue($id, "current|all")
            ; Language combo overlay click — toggle dropdown
            If $id = $__g_CD_idComboOverlay Then
                Local $hCombo = GUICtrlGetHandle($__g_CD_idLblLanguage)
                If $hCombo <> 0 Then
                    ; Save system highlight colors and override with dark theme
                    $__g_CD_iSavedHighlight = DllCall("user32.dll", "dword", "GetSysColor", "int", 13)[0] ; COLOR_HIGHLIGHT
                    $__g_CD_iSavedHighlightText = DllCall("user32.dll", "dword", "GetSysColor", "int", 14)[0] ; COLOR_HIGHLIGHTTEXT
                    Local $aElems = DllStructCreate("int[2]")
                    Local $aColors = DllStructCreate("dword[2]")
                    DllStructSetData($aElems, 1, 13, 1) ; COLOR_HIGHLIGHT
                    DllStructSetData($aElems, 1, 14, 2) ; COLOR_HIGHLIGHTTEXT
                    DllStructSetData($aColors, 1, $THEME_BG_HOVER, 1)
                    DllStructSetData($aColors, 1, $THEME_FG_WHITE, 2)
                    DllCall("user32.dll", "bool", "SetSysColors", "int", 2, "struct*", $aElems, "struct*", $aColors)
                    $__g_CD_bDropdownOpen = True
                    DllCall("user32.dll", "bool", "SendMessageW", "hwnd", $hCombo, "uint", 0x014F, "wparam", 1, "lparam", 0) ; CB_SHOWDROPDOWN
                EndIf
            EndIf
            ; Sync overlay on combo selection change
            If $id = $__g_CD_idLblLanguage Then
                GUICtrlSetData($__g_CD_idComboOverlay, " " & GUICtrlRead($__g_CD_idLblLanguage) & "  " & ChrW(0x25BE))
            EndIf
        EndIf

        ; Escape closes
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

        ; Scroll tab content with mouse wheel (peek for WM_MOUSEWHEEL)
        Local $tMsg = DllStructCreate("uint msg;hwnd hwnd;uint wParam;long lParam;dword time;int x;int y")
        Local $aPeek = DllCall("user32.dll", "bool", "PeekMessageW", "struct*", $tMsg, "hwnd", $__g_CD_hGUI, "uint", 0x020A, "uint", 0x020A, "uint", 1)
        If Not @error And IsArray($aPeek) And $aPeek[0] Then
            Local $iWheelDelta = BitShift(BitAND(DllStructGetData($tMsg, "wParam"), 0xFFFF0000), 16)
            If $iWheelDelta > 32767 Then $iWheelDelta -= 65536
            If $iWheelDelta > 0 Then
                __CD_ScrollTab(-$__g_CD_iScrollStep)
            ElseIf $iWheelDelta < 0 Then
                __CD_ScrollTab($__g_CD_iScrollStep)
            EndIf
        EndIf

        ; Ensure ConfigDialog is the "current" GUI for GUIGetCursorInfo
        ; (tooltip creation via GUICreate switches it away, breaking $aCursor[4])
        GUISwitch($__g_CD_hGUI)

        ; Button hover
        Local $aCursor = GUIGetCursorInfo($__g_CD_hGUI)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $__g_CD_idBtnApply Then $iFound = $__g_CD_idBtnApply
            If $aCursor[4] = $__g_CD_idBtnReset Then $iFound = $__g_CD_idBtnReset
            If $aCursor[4] = $__g_CD_idBtnClose Then $iFound = $__g_CD_idBtnClose
            If $aCursor[4] = $__g_CD_idBtnImport Then $iFound = $__g_CD_idBtnImport
            If $aCursor[4] = $__g_CD_idBtnExport Then $iFound = $__g_CD_idBtnExport
            If $aCursor[4] = $__g_CD_idBtnRestart Then $iFound = $__g_CD_idBtnRestart
            If $aCursor[4] = $__g_CD_idBtnCheckNow Then $iFound = $__g_CD_idBtnCheckNow
            If $aCursor[4] = $__g_CD_idBtnDownloadLatest Then $iFound = $__g_CD_idBtnDownloadLatest
            If $aCursor[4] = $__g_CD_idBtnLogBrowse Then $iFound = $__g_CD_idBtnLogBrowse
            If $__g_CD_idComboOverlay <> 0 And $aCursor[4] = $__g_CD_idComboOverlay Then $iFound = $__g_CD_idComboOverlay
            ; Cycle labels
            If $aCursor[4] = $__g_CD_idLblPosition Then $iFound = $__g_CD_idLblPosition
            If $aCursor[4] = $__g_CD_idLblScrollDir Then $iFound = $__g_CD_idLblScrollDir
            If $aCursor[4] = $__g_CD_idLblListAction Then $iFound = $__g_CD_idLblListAction
            If $aCursor[4] = $__g_CD_idLblTheme Then $iFound = $__g_CD_idLblTheme
            If $aCursor[4] = $__g_CD_idLblLogLevel Then $iFound = $__g_CD_idLblLogLevel
            If $aCursor[4] = $__g_CD_idLblLogDateFormat Then $iFound = $__g_CD_idLblLogDateFormat
            If $__g_CD_idLblWLPosition <> 0 And $aCursor[4] = $__g_CD_idLblWLPosition Then $iFound = $__g_CD_idLblWLPosition
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    Local $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnReset Then $iFgRestore = 0xCC6666
                    If $iHovered = $__g_CD_idBtnImport Or $iHovered = $__g_CD_idBtnExport Then $iFgRestore = $THEME_FG_DIM
                    If $iHovered = $__g_CD_idBtnRestart Then $iFgRestore = $THEME_FG_LINK
                    If $iHovered = $__g_CD_idBtnCheckNow Then $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnDownloadLatest Then $iFgRestore = $THEME_FG_LINK
                    If $iHovered = $__g_CD_idBtnLogBrowse Then $iFgRestore = $THEME_FG_DIM
                    If $iHovered = $__g_CD_idComboOverlay Then $iFgRestore = $THEME_FG_TEXT
                    If $iHovered = $__g_CD_idLblPosition Or $iHovered = $__g_CD_idLblScrollDir Or _
                       $iHovered = $__g_CD_idLblListAction Or $iHovered = $__g_CD_idLblTheme Or _
                       $iHovered = $__g_CD_idLblLogLevel Or $iHovered = $__g_CD_idLblLogDateFormat Or _
                       $iHovered = $__g_CD_idLblWLPosition Then $iFgRestore = $THEME_FG_PRIMARY
                    Local $iBgRestore = $THEME_BG_HOVER
                    If $iHovered = $__g_CD_idComboOverlay Or $iHovered = $__g_CD_idLblPosition Or _
                       $iHovered = $__g_CD_idLblScrollDir Or $iHovered = $__g_CD_idLblListAction Or _
                       $iHovered = $__g_CD_idLblTheme Or $iHovered = $__g_CD_idLblLogLevel Or _
                       $iHovered = $__g_CD_idLblLogDateFormat Or $iHovered = $__g_CD_idLblWLPosition Then $iBgRestore = $THEME_BG_INPUT
                    _Theme_RemoveHover($iHovered, $iFgRestore, $iBgRestore)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf

            ; Tab hover (inactive tabs highlight on mouseover)
            Local $iTabFound = 0
            For $t = 1 To 13
                If $aCursor[4] = $__g_CD_aidTabBtn[$t] And $t <> $__g_CD_iActiveTab Then
                    $iTabFound = $t
                    ExitLoop
                EndIf
            Next
            If $iTabFound <> $iTabHovered Then
                ; Remove old tab hover
                If $iTabHovered <> 0 And $iTabHovered <> $__g_CD_iActiveTab Then
                    GUICtrlSetColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_FG_DIM)
                    GUICtrlSetBkColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_BG_MAIN)
                EndIf
                $iTabHovered = $iTabFound
                ; Apply new tab hover
                If $iTabHovered <> 0 Then
                    GUICtrlSetColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_FG_NORMAL)
                    GUICtrlSetBkColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_BG_HOVER)
                EndIf
            EndIf
        EndIf

        ; Tick toast fade-out while dialog is open
        _Theme_ToastTick()

        ; Themed tooltip hover check
        _Theme_CheckTooltipHover($__g_CD_hGUI)

        ; Restore system highlight colors when combo dropdown closes
        If $__g_CD_bDropdownOpen Then
            Local $hCmb = GUICtrlGetHandle($__g_CD_idLblLanguage)
            If $hCmb <> 0 Then
                Local $aDropped = DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $hCmb, "uint", 0x0157, "wparam", 0, "lparam", 0) ; CB_GETDROPPEDSTATE
                If Not @error And IsArray($aDropped) And $aDropped[0] = 0 Then
                    $__g_CD_bDropdownOpen = False
                    Local $aElems2 = DllStructCreate("int[2]")
                    Local $aColors2 = DllStructCreate("dword[2]")
                    DllStructSetData($aElems2, 1, 13, 1)
                    DllStructSetData($aElems2, 1, 14, 2)
                    DllStructSetData($aColors2, 1, $__g_CD_iSavedHighlight, 1)
                    DllStructSetData($aColors2, 1, $__g_CD_iSavedHighlightText, 2)
                    DllCall("user32.dll", "bool", "SetSysColors", "int", 2, "struct*", $aElems2, "struct*", $aColors2)
                EndIf
            EndIf
        EndIf

        ; Live color preview update
        __CD_UpdateColorPreviews()

        Sleep(10)
    WEnd

    _Theme_ClearTooltips()
    _Theme_ToastDestroy()
    _CD_Destroy()
EndFunc

; =============================================
; APPLY CHANGES
; =============================================

Func __CD_ApplyChanges()
    If $__g_CD_hGUI = 0 Then Return
    _Log_Info("Settings: applying changes")
    Local $i
    Local $bOldStartup = _Cfg_IsStartupEnabled()

    ; General
    _Cfg_SetStartWithWindows(__CD_GetCheckState($__g_CD_idChkStartWin))
    _Cfg_SetWrapNavigation(__CD_GetCheckState($__g_CD_idChkWrapNav))
    _Cfg_SetAutoCreateDesktop(__CD_GetCheckState($__g_CD_idChkAutoCreate))
    Local $s = GUICtrlRead($__g_CD_idInpPadding)
    If StringIsInt($s) Then _Cfg_SetNumberPadding(Int($s))
    _Cfg_SetWidgetPosition(GUICtrlRead($__g_CD_idLblPosition))
    Local $sOldLang = _Cfg_GetLanguage()
    _Cfg_SetLanguage(_i18n_DisplayToCode(GUICtrlRead($__g_CD_idLblLanguage)))
    $s = GUICtrlRead($__g_CD_idInpOffsetX)
    If $s <> "" And StringIsInt($s) Then _Cfg_SetWidgetOffsetX(Int($s))
    _Cfg_SetWidgetDragEnabled(__CD_GetCheckState($__g_CD_idChkWidgetDrag))
    _Cfg_SetWidgetColorBar(__CD_GetCheckState($__g_CD_idChkWidgetColorBar))
    _Cfg_SetTrayIconMode(__CD_GetCheckState($__g_CD_idChkTrayMode))
    _Cfg_SetQuickAccessEnabled(__CD_GetCheckState($__g_CD_idChkQuickAccess))
    _Cfg_SetListKeyboardNav(__CD_GetCheckState($__g_CD_idChkListKeyNav))
    _Cfg_SetSingletonEnabled(__CD_GetCheckState($__g_CD_idChkSingleton))
    _Cfg_SetTaskbarFocusTrick(__CD_GetCheckState($__g_CD_idChkTaskbarFocus))
    _Cfg_SetAutoFocusAfterSwitch(__CD_GetCheckState($__g_CD_idChkAutoFocus))
    _Cfg_SetCapslockModifier(__CD_GetCheckState($__g_CD_idChkCapslockMod))
    $s = GUICtrlRead($__g_CD_idInpMinDesktops)
    If StringIsInt($s) Then _Cfg_SetMinDesktops(Int($s))

    ; Display
    _Cfg_SetShowCount(__CD_GetCheckState($__g_CD_idChkShowCount))
    $s = GUICtrlRead($__g_CD_idInpCountFont)
    If StringIsInt($s) Then _Cfg_SetCountFontSize(Int($s))
    $s = GUICtrlRead($__g_CD_idInpOpacity)
    If StringIsInt($s) Then _Cfg_SetThemeAlphaMain(Int($s))
    Local $sOldTheme = _Cfg_GetTheme()
    _Cfg_SetTheme(GUICtrlRead($__g_CD_idLblTheme))
    _Cfg_SetThumbnailsEnabled(__CD_GetCheckState($__g_CD_idChkThumbnails))
    $s = GUICtrlRead($__g_CD_idInpThumbW)
    If StringIsInt($s) Then _Cfg_SetThumbnailWidth(Int($s))
    $s = GUICtrlRead($__g_CD_idInpThumbH)
    If StringIsInt($s) Then _Cfg_SetThumbnailHeight(Int($s))
    _Cfg_SetThumbnailUseScreenshot(__CD_GetCheckState($__g_CD_idChkThumbScreenshot))
    $s = GUICtrlRead($__g_CD_idInpThumbCacheTTL)
    If StringIsInt($s) Then _Cfg_SetThumbnailCacheTTL(Int($s))
    _Cfg_SetListFontName(GUICtrlRead($__g_CD_idInpListFont))
    $s = GUICtrlRead($__g_CD_idInpListFontSize)
    If StringIsInt($s) Then _Cfg_SetListFontSize(Int($s))
    $s = GUICtrlRead($__g_CD_idInpTooltipFontSize)
    If StringIsInt($s) Then _Cfg_SetTooltipFontSize(Int($s))
    _Cfg_SetListScrollable(__CD_GetCheckState($__g_CD_idChkListScrollable))
    $s = GUICtrlRead($__g_CD_idInpListMaxVisible)
    If StringIsInt($s) Then _Cfg_SetListMaxVisible(Int($s))
    $s = GUICtrlRead($__g_CD_idInpListScrollSpeed)
    If StringIsInt($s) Then _Cfg_SetListScrollSpeed(Int($s))

    ; Scroll
    _Cfg_SetScrollEnabled(__CD_GetCheckState($__g_CD_idChkScroll))
    _Cfg_SetScrollDirection(GUICtrlRead($__g_CD_idLblScrollDir))
    _Cfg_SetScrollWrap(__CD_GetCheckState($__g_CD_idChkScrollWrap))
    _Cfg_SetListScrollEnabled(__CD_GetCheckState($__g_CD_idChkListScroll))
    _Cfg_SetListScrollAction(GUICtrlRead($__g_CD_idLblListAction))

    ; Hotkeys
    _Cfg_SetHotkeyNext(GUICtrlRead($__g_CD_idInpHkNext))
    _Cfg_SetHotkeyPrev(GUICtrlRead($__g_CD_idInpHkPrev))
    For $i = 1 To 9
        _Cfg_SetHotkeyDesktop($i, GUICtrlRead($__g_CD_aidInpHkDesktop[$i]))
    Next
    _Cfg_SetHotkeyToggleList(GUICtrlRead($__g_CD_idInpHkToggleList))
    _Cfg_SetHotkeyToggleLast(GUICtrlRead($__g_CD_idInpHkLastDesktop))
    _Cfg_SetHotkeyMoveFollowNext(GUICtrlRead($__g_CD_idInpHkMoveFollowNext))
    _Cfg_SetHotkeyMoveFollowPrev(GUICtrlRead($__g_CD_idInpHkMoveFollowPrev))
    _Cfg_SetHotkeyMoveNext(GUICtrlRead($__g_CD_idInpHkMoveToNext))
    _Cfg_SetHotkeyMovePrev(GUICtrlRead($__g_CD_idInpHkMoveToPrev))
    _Cfg_SetHotkeySendNewDesktop(GUICtrlRead($__g_CD_idInpHkSendToNew))
    _Cfg_SetHotkeyPinWindow(GUICtrlRead($__g_CD_idInpHkPinWindow))
    _Cfg_SetHotkeyToggleWindowList(GUICtrlRead($__g_CD_idInpHkToggleWL))

    ; Behavior
    _Cfg_SetConfirmDelete(__CD_GetCheckState($__g_CD_idChkConfirmDel))
    _Cfg_SetMiddleClickDelete(__CD_GetCheckState($__g_CD_idChkMidClick))
    _Cfg_SetMoveWindowEnabled(__CD_GetCheckState($__g_CD_idChkMoveWin))
    $s = GUICtrlRead($__g_CD_idInpPeekDelay)
    If StringIsInt($s) Then _Cfg_SetPeekBounceDelay(Int($s))
    $s = GUICtrlRead($__g_CD_idInpAutoHide)
    If StringIsInt($s) Then _Cfg_SetAutoHideTimeout(Int($s))
    $s = GUICtrlRead($__g_CD_idInpTopmost)
    If StringIsInt($s) Then _Cfg_SetTopmostInterval(Int($s))
    $s = GUICtrlRead($__g_CD_idInpCmDelay)
    If StringIsInt($s) Then _Cfg_SetCmAutoHideDelay(Int($s))
    _Cfg_SetConfigWatcherEnabled(__CD_GetCheckState($__g_CD_idChkConfigWatcher))
    $s = GUICtrlRead($__g_CD_idInpWatcherInterval)
    If StringIsInt($s) Then _Cfg_SetConfigWatcherInterval(Int($s))
    $s = GUICtrlRead($__g_CD_idInpCountCacheTTL)
    If StringIsInt($s) Then _Cfg_SetCountCacheTTL(Int($s))
    _Cfg_SetConfirmQuit(__CD_GetCheckState($__g_CD_idChkConfirmQuit))
    _Cfg_SetDebugMode(__CD_GetCheckState($__g_CD_idChkDebugMode))

    ; Logging
    _Cfg_SetLoggingEnabled(__CD_GetCheckState($__g_CD_idChkLogging))
    _Cfg_SetLogFolder(GUICtrlRead($__g_CD_idInpLogPath))
    _Cfg_SetLogLevel(GUICtrlRead($__g_CD_idLblLogLevel))
    $s = GUICtrlRead($__g_CD_idInpLogMaxSize)
    If StringIsInt($s) Then _Cfg_SetLogMaxSizeMB(Int($s))
    $s = GUICtrlRead($__g_CD_idInpLogRotateCount)
    If StringIsInt($s) Then _Cfg_SetLogRotateCount(Int($s))
    _Cfg_SetLogCompressOld(__CD_GetCheckState($__g_CD_idChkLogCompress))
    _Cfg_SetLogIncludePID(__CD_GetCheckState($__g_CD_idChkLogPID))
    _Cfg_SetLogDateFormat(GUICtrlRead($__g_CD_idLblLogDateFormat))
    _Cfg_SetLogFlushImmediate(__CD_GetCheckState($__g_CD_idChkLogFlush))

    ; Updates
    _Cfg_SetAutoUpdateEnabled(__CD_GetCheckState($__g_CD_idChkAutoUpdate))
    $s = GUICtrlRead($__g_CD_idInpUpdateInterval)
    If StringIsInt($s) Then _Cfg_SetAutoUpdateInterval(Int($s))
    _Cfg_SetUpdateCheckOnStartup(__CD_GetCheckState($__g_CD_idChkUpdateOnStartup))
    $s = GUICtrlRead($__g_CD_idInpUpdateCheckDays)
    If StringIsInt($s) Then _Cfg_SetUpdateCheckDays(Int($s))

    ; Desktops - save labels and colors
    For $i = 1 To $__g_CD_iDeskCount
        Local $sLabel = GUICtrlRead($__g_CD_aidDeskLabel[$i])
        _Labels_Save($i, $sLabel)

        Local $sHex = GUICtrlRead($__g_CD_aidDeskColor[$i])
        Local $iClr = _Theme_ValidateHexColor($sHex)
        If $iClr >= 0 Then
            _Cfg_SetDesktopColor($i, $iClr)
            _Cfg_SetDesktopColorsEnabled(True)
        ElseIf $sHex = "" Then
            _Cfg_SetDesktopColor($i, 0) ; none
        EndIf
    Next

    If Not _Cfg_Save() Then
        _Log_Error("Settings: failed to save config file")
        Local $aErrPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_save_failed", "Failed to save settings"), $aErrPos[0], $aErrPos[1] + $aErrPos[3] + 4, 2000, $TOAST_ERROR)
        EndIf
        Return
    EndIf
    _Log_Info("Settings: saved successfully")

    ; Animations
    _Cfg_SetAnimationsEnabled(__CD_GetCheckState($__g_CD_idChkAnimEnabled))
    _Cfg_SetAnimList(__CD_GetCheckState($__g_CD_idChkAnimList))
    _Cfg_SetAnimMenus(__CD_GetCheckState($__g_CD_idChkAnimMenus))
    _Cfg_SetAnimDialogs(__CD_GetCheckState($__g_CD_idChkAnimDialogs))
    _Cfg_SetAnimToasts(__CD_GetCheckState($__g_CD_idChkAnimToasts))
    _Cfg_SetAnimWidget(__CD_GetCheckState($__g_CD_idChkAnimWidget))
    _Cfg_SetFadeInDuration(Int(GUICtrlRead($__g_CD_idInpFadeIn)))
    _Cfg_SetFadeOutDuration(Int(GUICtrlRead($__g_CD_idInpFadeOut)))
    _Cfg_SetFadeStep(Int(GUICtrlRead($__g_CD_idInpFadeStep)))
    _Cfg_SetFadeSleepMs(Int(GUICtrlRead($__g_CD_idInpFadeSleep)))
    _Cfg_SetToastFadeOutDuration(Int(GUICtrlRead($__g_CD_idInpToastFadeOut)))

    ; Wallpaper
    _Cfg_SetWallpaperEnabled(__CD_GetCheckState($__g_CD_idChkWallpaper))
    $s = GUICtrlRead($__g_CD_idInpWallpaperDelay)
    If StringIsInt($s) Then _Cfg_SetWallpaperChangeDelay(Int($s))
    For $i = 1 To 9
        _Cfg_SetDesktopWallpaper($i, GUICtrlRead($__g_CD_aidWallpaperPath[$i]))
    Next

    ; Window List
    _Cfg_SetWindowListEnabled(__CD_GetCheckState($__g_CD_idChkWLEnabled))
    _Cfg_SetWindowListPosition(GUICtrlRead($__g_CD_idLblWLPosition))
    $s = GUICtrlRead($__g_CD_idInpWLWidth)
    If StringIsInt($s) Then _Cfg_SetWindowListWidth(Int($s))
    $s = GUICtrlRead($__g_CD_idInpWLMaxVisible)
    If StringIsInt($s) Then _Cfg_SetWindowListMaxVisible(Int($s))
    _Cfg_SetWindowListShowIcons(__CD_GetCheckState($__g_CD_idChkWLIcons))
    _Cfg_SetWindowListSearch(__CD_GetCheckState($__g_CD_idChkWLSearch))
    _Cfg_SetWindowListAutoRefresh(__CD_GetCheckState($__g_CD_idChkWLAutoRefresh))
    $s = GUICtrlRead($__g_CD_idInpWLRefreshInterval)
    If StringIsInt($s) Then _Cfg_SetWindowListRefreshInterval(Int($s))

    ; Explorer
    _Cfg_SetExplorerMonitorEnabled(__CD_GetCheckState($__g_CD_idChkExplorerMonitor))
    _Cfg_SetShellProcessName(GUICtrlRead($__g_CD_idInpShellProcess))
    $s = GUICtrlRead($__g_CD_idInpExplorerInterval)
    If StringIsInt($s) Then _Cfg_SetExplorerCheckInterval(Int($s))
    _Cfg_SetMonitorAutoRestart(__CD_GetCheckState($__g_CD_idChkAutoRestart))
    $s = GUICtrlRead($__g_CD_idInpRestartDelay)
    If StringIsInt($s) Then _Cfg_SetMonitorRestartDelay(Int($s))
    $s = GUICtrlRead($__g_CD_idInpMaxRetries)
    If StringIsInt($s) Then _Cfg_SetMonitorMaxRetries(Int($s))
    $s = GUICtrlRead($__g_CD_idInpRetryDelay)
    If StringIsInt($s) Then _Cfg_SetMonitorRetryDelay(Int($s))
    _Cfg_SetMonitorExpBackoff(__CD_GetCheckState($__g_CD_idChkExpBackoff))
    $s = GUICtrlRead($__g_CD_idInpMaxRetryDelay)
    If StringIsInt($s) Then _Cfg_SetMonitorMaxRetryDelay(Int($s))
    _Cfg_SetExplorerNotifyRecovery(__CD_GetCheckState($__g_CD_idChkExplorerNotify))

    ; Notifications
    _Cfg_SetNotifyWindowMoved(__CD_GetCheckState($__g_CD_idChkNotifyMoved))
    _Cfg_SetNotifyDesktopCreated(__CD_GetCheckState($__g_CD_idChkNotifyCreated))
    _Cfg_SetNotifyDesktopDeleted(__CD_GetCheckState($__g_CD_idChkNotifyDeleted))
    _Cfg_SetNotifyWindowPinned(__CD_GetCheckState($__g_CD_idChkNotifyPinned))
    _Cfg_SetNotifyWindowUnpinned(__CD_GetCheckState($__g_CD_idChkNotifyUnpinned))
    _Cfg_SetNotifyExplorerRecovery(__CD_GetCheckState($__g_CD_idChkNotifyExplorerRecov))
    _Cfg_SetWindowListScope(GUICtrlRead($__g_CD_idLblWLScope))

    ; Apply changes live to the running app
    _ApplySettingsLive()

    ; Rebuild desktop list to reflect font/color changes
    If _DL_IsVisible() Then
        _DL_Destroy()
        _DL_Show($iTaskbarY, $iDesktop)
    EndIf

    ; Startup toggle with verification
    Local $sToastMsg = _i18n("Toasts.toast_saved", "Settings saved")
    Local $iToastIcon = $TOAST_SUCCESS
    If _Cfg_GetStartWithWindows() <> $bOldStartup Then
        If _Cfg_GetStartWithWindows() Then
            If _Cfg_EnableStartup() Then
                $sToastMsg = _i18n("Toasts.toast_saved_startup_on", "Settings saved (startup enabled)")
            Else
                $sToastMsg = _i18n("Toasts.toast_saved_startup_fail", "Settings saved (startup failed)")
                $iToastIcon = $TOAST_ERROR
            EndIf
        Else
            If _Cfg_DisableStartup() Then
                $sToastMsg = _i18n("Toasts.toast_saved_startup_off", "Settings saved (startup disabled)")
            Else
                $sToastMsg = _i18n("Toasts.toast_saved_startup_remove_fail", "Settings saved (startup removal failed)")
                $iToastIcon = $TOAST_ERROR
            EndIf
        EndIf
    EndIf

    ; Theme change notification
    If _Cfg_GetTheme() <> $sOldTheme Then
        $sToastMsg = _i18n("Toasts.toast_theme_changed", "Theme changed (restart required)")
        $iToastIcon = $TOAST_WARNING
    EndIf

    ; Language change notification
    If _Cfg_GetLanguage() <> $sOldLang Then
        $sToastMsg = _i18n("Toasts.toast_language_changed", "Language changed (restart required)")
        $iToastIcon = $TOAST_WARNING
    EndIf

    ; Toast notification
    Local $aPos = WinGetPos($__g_CD_hGUI)
    If Not @error Then
        _Theme_Toast($sToastMsg, $aPos[0], $aPos[1] + $aPos[3] + 4, 2000, $iToastIcon)
    EndIf
EndFunc

; Name:        __CD_UpdateColorPreviews
; Description: Updates color preview swatches only when values actually change (throttled)
Global $__g_CD_hColorUpdateTimer = 0
Global $__g_CD_aLastDeskColor[21] ; cached last-applied color per desktop

Func __CD_UpdateColorPreviews()
    If $__g_CD_iActiveTab <> 8 Then Return
    ; Throttle: only check every 250ms to avoid flicker
    If TimerDiff($__g_CD_hColorUpdateTimer) < 250 Then Return
    $__g_CD_hColorUpdateTimer = TimerInit()

    Local $i
    For $i = 1 To $__g_CD_iDeskCount
        If $__g_CD_aidDeskColor[$i] = 0 Then ContinueLoop
        Local $sHex = GUICtrlRead($__g_CD_aidDeskColor[$i])
        Local $iClr = _Theme_ValidateHexColor($sHex)
        If $iClr >= 0 And $iClr <> $__g_CD_aLastDeskColor[$i] Then
            $__g_CD_aLastDeskColor[$i] = $iClr
            GUICtrlSetBkColor($__g_CD_aidDeskPreview[$i], $iClr)
        EndIf
    Next
EndFunc

Func __CD_ResetDefaults()
    _Log_Info("Settings: reset to defaults requested")
    If Not _Theme_Confirm(_i18n("Dialogs.confirm_reset_title", "Reset Settings"), _i18n("Dialogs.confirm_reset_msg", "Reset all settings to defaults?")) Then
        _Log_Info("Settings: reset cancelled by user")
        Return
    EndIf
    _Log_Info("Settings: resetting to defaults")

    Local $sPath = _Cfg_GetPath()
    FileDelete($sPath)
    _Cfg_Init($sPath)
    __CD_PopulateControls()

    Local $aPos = WinGetPos($__g_CD_hGUI)
    If Not @error Then
        _Theme_Toast(_i18n("Toasts.toast_reset", "Reset to defaults"), $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_WARNING)
    EndIf
EndFunc

; Name:        __CD_ImportSettings
; Description: Opens a file dialog to import settings from an external INI file
Func __CD_ImportSettings()
    Local $sPath = FileOpenDialog("Import Settings", @DesktopDir, "INI Files (*.ini)", 1, "", $__g_CD_hGUI)
    If $sPath = "" Or @error Then
        _Log_Debug("Settings: import cancelled")
        Return
    EndIf
    _Log_Info("Settings: importing from " & $sPath)
    If _Cfg_Import($sPath) Then
        _Log_Info("Settings: import successful")
        _ApplySettingsLive()
        __CD_PopulateControls()
        Local $aPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_imported", "Settings imported"), $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_SUCCESS)
        EndIf
    Else
        Local $aPos2 = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_import_failed", "Import failed"), $aPos2[0], $aPos2[1] + $aPos2[3] + 4, 1500, $TOAST_ERROR)
        EndIf
    EndIf
EndFunc

; Name:        __CD_ExportSettings
; Description: Opens a file dialog to export current settings to an INI file
Func __CD_ExportSettings()
    Local $sPath = FileSaveDialog("Export Settings", @DesktopDir, "INI Files (*.ini)", 16, "desk_switcheroo.ini", $__g_CD_hGUI)
    If $sPath = "" Or @error Then
        _Log_Debug("Settings: export cancelled")
        Return
    EndIf
    _Log_Info("Settings: exporting to " & $sPath)
    ; Ensure .ini extension
    If StringRight($sPath, 4) <> ".ini" Then $sPath &= ".ini"
    If _Cfg_Export($sPath) Then
        Local $aPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_exported", "Settings exported"), $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_SUCCESS)
        EndIf
    Else
        Local $aPos2 = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_export_failed", "Export failed"), $aPos2[0], $aPos2[1] + $aPos2[3] + 4, 1500, $TOAST_ERROR)
        EndIf
    EndIf
EndFunc

; =============================================
; HOTKEY BUILDER
; =============================================

; Name:        __CD_HandleHotkeyBuildClick
; Description: Checks if a hotkey build "..." button was clicked and opens the builder
; Parameters:  $id - control ID from GUIGetMsg
Func __CD_HandleHotkeyBuildClick($id)
    ; Map build button index to corresponding input control
    ; Index 0=Next, 1=Prev, 2-10=Desktop 1-9, 11=Toggle List, 12-19=new hotkeys
    Local $idInput = 0
    If $id = $__g_CD_idBtnHkBuild[0] Then
        $idInput = $__g_CD_idInpHkNext
    ElseIf $id = $__g_CD_idBtnHkBuild[1] Then
        $idInput = $__g_CD_idInpHkPrev
    ElseIf $id = $__g_CD_idBtnHkBuild[11] Then
        $idInput = $__g_CD_idInpHkToggleList
    ElseIf $id = $__g_CD_idBtnHkBuild[12] Then
        $idInput = $__g_CD_idInpHkLastDesktop
    ElseIf $id = $__g_CD_idBtnHkBuild[13] Then
        $idInput = $__g_CD_idInpHkMoveFollowNext
    ElseIf $id = $__g_CD_idBtnHkBuild[14] Then
        $idInput = $__g_CD_idInpHkMoveFollowPrev
    ElseIf $id = $__g_CD_idBtnHkBuild[15] Then
        $idInput = $__g_CD_idInpHkMoveToNext
    ElseIf $id = $__g_CD_idBtnHkBuild[16] Then
        $idInput = $__g_CD_idInpHkMoveToPrev
    ElseIf $id = $__g_CD_idBtnHkBuild[17] Then
        $idInput = $__g_CD_idInpHkSendToNew
    ElseIf $id = $__g_CD_idBtnHkBuild[18] Then
        $idInput = $__g_CD_idInpHkPinWindow
    ElseIf $id = $__g_CD_idBtnHkBuild[19] Then
        $idInput = $__g_CD_idInpHkToggleWL
    Else
        Local $i
        For $i = 1 To 9
            If $id = $__g_CD_idBtnHkBuild[$i + 1] Then
                $idInput = $__g_CD_aidInpHkDesktop[$i]
                ExitLoop
            EndIf
        Next
    EndIf
    If $idInput = 0 Then Return

    Local $sResult = __CD_ShowHotkeyBuilder()
    If $sResult <> "" Then GUICtrlSetData($idInput, $sResult)
EndFunc

; Name:        __CD_ShowHotkeyBuilder
; Description: Shows a dialog to visually build a hotkey string
; Return:      AutoIt hotkey string (e.g. "^!{RIGHT}") or "" if cancelled
Func __CD_ShowHotkeyBuilder()
    Local $iDlgW = 280, $iDlgH = 220
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("HotkeyBuilder", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Title label
    Local $idTitle = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_title", "Hotkey Builder"), 10, 8, $iDlgW - 20, 18)
    GUICtrlSetFont($idTitle, 9, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idTitle, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idTitle, $GUI_BKCOLOR_TRANSPARENT)

    ; Modifier checkboxes (label-based toggle)
    Local $iChkY = 34
    Local $idChkCtrl = GUICtrlCreateLabel("  [ ]  Ctrl", 16, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkCtrl, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkCtrl, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkCtrl, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkCtrl, 0)

    Local $idChkAlt = GUICtrlCreateLabel("  [ ]  Alt", 146, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkAlt, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkAlt, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkAlt, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkAlt, 0)

    $iChkY += 26
    Local $idChkShift = GUICtrlCreateLabel("  [ ]  Shift", 16, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkShift, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkShift, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkShift, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkShift, 0)

    Local $idChkWin = GUICtrlCreateLabel("  [ ]  Win", 146, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkWin, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkWin, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkWin, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkWin, 0)

    ; Key input
    Local $iKeyY = $iChkY + 32
    Local $idKeyLbl = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_key", "Key:"), 16, $iKeyY + 2, 35, 18)
    GUICtrlSetFont($idKeyLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idKeyLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idKeyLbl, $GUI_BKCOLOR_TRANSPARENT)

    Local $idKeyInput = GUICtrlCreateInput("", 55, $iKeyY, 120, 22)
    GUICtrlSetFont($idKeyInput, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idKeyInput, $THEME_FG_TEXT)
    GUICtrlSetBkColor($idKeyInput, $THEME_BG_INPUT)

    ; Capture button
    Local $iX = 16
    Local $idCapture = GUICtrlCreateLabel(ChrW(0x23CE) & " Capture", $iX + 165, $iKeyY, 80, 22, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCapture, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCapture, $THEME_FG_MENU)
    GUICtrlSetBkColor($idCapture, $THEME_BG_HOVER)
    GUICtrlSetCursor($idCapture, 0)
    _Theme_SetTooltip($idCapture, _i18n("HotkeyBuilder.hkb_tip_capture", "Press to capture a key (waits 5 seconds)"))

    ; Hint
    Local $idHint = GUICtrlCreateLabel("e.g.: LEFT, RIGHT, F1-F12, 1-9, A-Z", 16, $iKeyY + 26, 250, 14)
    GUICtrlSetFont($idHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idHint, $GUI_BKCOLOR_TRANSPARENT)

    ; Preview
    Local $iPreviewY = $iKeyY + 48
    Local $idPreviewLbl = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_preview", "Preview:"), 16, $iPreviewY + 2, 50, 18)
    GUICtrlSetFont($idPreviewLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idPreviewLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idPreviewLbl, $GUI_BKCOLOR_TRANSPARENT)

    Local $idPreview = GUICtrlCreateLabel("", 70, $iPreviewY, 190, 22, $SS_CENTERIMAGE)
    GUICtrlSetFont($idPreview, 10, 700, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idPreview, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idPreview, $THEME_BG_INPUT)

    ; OK / Cancel buttons
    Local $iBtnW = 60, $iBtnH = 26
    Local $iBtnY = $iDlgH - 38
    Local $idOK = GUICtrlCreateLabel(_i18n("General.btn_ok", "OK"), ($iDlgW / 2) - $iBtnW - 8, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idOK, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idOK, $THEME_FG_MENU)
    GUICtrlSetBkColor($idOK, $THEME_BG_HOVER)
    GUICtrlSetCursor($idOK, 0)

    Local $idCancel = GUICtrlCreateLabel(_i18n("General.btn_cancel", "Cancel"), ($iDlgW / 2) + 8, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCancel, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCancel, $THEME_FG_MENU)
    GUICtrlSetBkColor($idCancel, $THEME_BG_HOVER)
    GUICtrlSetCursor($idCancel, 0)

    GUISetState(@SW_SHOW, $hDlg)

    ; Checkbox states
    Local $bCtrl = False, $bAlt = False, $bShift = False, $bWin = False
    Local $sLastKey = "", $sResult = ""
    Local $iHovered = 0

    ; Blocking loop
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idOK
                    $sResult = __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, GUICtrlRead($idKeyInput))
                    ExitLoop
                Case $idCancel
                    ExitLoop
                Case $idChkCtrl
                    $bCtrl = Not $bCtrl
                    GUICtrlSetData($idChkCtrl, $bCtrl ? "  [x]  Ctrl" : "  [ ]  Ctrl")
                    GUICtrlSetColor($idChkCtrl, $bCtrl ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idChkAlt
                    $bAlt = Not $bAlt
                    GUICtrlSetData($idChkAlt, $bAlt ? "  [x]  Alt" : "  [ ]  Alt")
                    GUICtrlSetColor($idChkAlt, $bAlt ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idChkShift
                    $bShift = Not $bShift
                    GUICtrlSetData($idChkShift, $bShift ? "  [x]  Shift" : "  [ ]  Shift")
                    GUICtrlSetColor($idChkShift, $bShift ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idChkWin
                    $bWin = Not $bWin
                    GUICtrlSetData($idChkWin, $bWin ? "  [x]  Win" : "  [ ]  Win")
                    GUICtrlSetColor($idChkWin, $bWin ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idCapture
                    ; Set input to "Press a key..." and capture
                    GUICtrlSetData($idKeyInput, _i18n("HotkeyBuilder.hkb_press_key", "Press a key..."))
                    Local $sCaptured = __CD_CaptureKeyPress()
                    If $sCaptured <> "" Then
                        GUICtrlSetData($idKeyInput, $sCaptured)
                        ; Auto-detect modifiers held during capture
                        Local $retModCtrl = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x11)
                        If Not @error And IsArray($retModCtrl) And BitAND($retModCtrl[0], 0x8000) <> 0 Then
                            $bCtrl = True
                            GUICtrlSetData($idChkCtrl, "  [x]  Ctrl")
                            GUICtrlSetColor($idChkCtrl, $THEME_FG_WHITE)
                        EndIf
                        Local $retModAlt = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x12)
                        If Not @error And IsArray($retModAlt) And BitAND($retModAlt[0], 0x8000) <> 0 Then
                            $bAlt = True
                            GUICtrlSetData($idChkAlt, "  [x]  Alt")
                            GUICtrlSetColor($idChkAlt, $THEME_FG_WHITE)
                        EndIf
                        Local $retModShift = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x10)
                        If Not @error And IsArray($retModShift) And BitAND($retModShift[0], 0x8000) <> 0 Then
                            $bShift = True
                            GUICtrlSetData($idChkShift, "  [x]  Shift")
                            GUICtrlSetColor($idChkShift, $THEME_FG_WHITE)
                        EndIf
                        Local $retModWin = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x5B)
                        If Not @error And IsArray($retModWin) And BitAND($retModWin[0], 0x8000) <> 0 Then
                            $bWin = True
                            GUICtrlSetData($idChkWin, "  [x]  Win")
                            GUICtrlSetColor($idChkWin, $THEME_FG_WHITE)
                        EndIf
                    Else
                        GUICtrlSetData($idKeyInput, "")
                    EndIf
            EndSwitch
        EndIf

        ; Update preview when key input changes
        Local $sCurKey = GUICtrlRead($idKeyInput)
        If $sCurKey <> $sLastKey Or $aMsg[0] = $idChkCtrl Or $aMsg[0] = $idChkAlt Or $aMsg[0] = $idChkShift Or $aMsg[0] = $idChkWin Then
            $sLastKey = $sCurKey
            GUICtrlSetData($idPreview, " " & __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, $sCurKey))
        EndIf

        ; Escape closes, Enter confirms
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop
        Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And IsArray($retEnter) And BitAND($retEnter[0], 0x8000) <> 0 Then
            $sResult = __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, GUICtrlRead($idKeyInput))
            ExitLoop
        EndIf

        ; Button hover
        GUISwitch($hDlg)
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idOK Then $iFound = $idOK
            If $aCursor[4] = $idCancel Then $iFound = $idCancel
            If $aCursor[4] = $idCapture Then $iFound = $idCapture
            If $aCursor[4] = $idChkCtrl Then $iFound = $idChkCtrl
            If $aCursor[4] = $idChkAlt Then $iFound = $idChkAlt
            If $aCursor[4] = $idChkShift Then $iFound = $idChkShift
            If $aCursor[4] = $idChkWin Then $iFound = $idChkWin
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    Local $iFgR = $THEME_FG_MENU
                    ; Checkboxes restore to their toggle color
                    If $iHovered = $idChkCtrl Then $iFgR = ($bCtrl ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    If $iHovered = $idChkAlt Then $iFgR = ($bAlt ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    If $iHovered = $idChkShift Then $iFgR = ($bShift ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    If $iHovered = $idChkWin Then $iFgR = ($bWin ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    _Theme_RemoveHover($iHovered, $iFgR, $THEME_BG_HOVER)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        Sleep(10)
    WEnd

    GUIDelete($hDlg)
    Return $sResult
EndFunc

; Name:        __CD_CaptureKeyPress
; Description: Polls all virtual keys looking for a new keypress (non-modifier).
;              Waits up to 5 seconds for a key to be pressed.
; Return:      AutoIt key name string, or "" on timeout
Func __CD_CaptureKeyPress()
    ; Flush any currently-held keys by waiting for all to be released
    Local $hFlush = TimerInit()
    While TimerDiff($hFlush) < 300
        Sleep(10)
    WEnd

    Local $hTimeout = TimerInit()
    While TimerDiff($hTimeout) < 5000
        Local $i
        For $i = 0x08 To 0xFE
            ; Skip modifier keys themselves
            If $i = 0x10 Or $i = 0x11 Or $i = 0x12 Or $i = 0x5B Or $i = 0x5C Then ContinueLoop
            Local $ret = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $i)
            If Not @error And IsArray($ret) And BitAND($ret[0], 0x0001) <> 0 Then
                Return __CD_VKToAutoItKey($i)
            EndIf
        Next
        Sleep(10)
    WEnd
    Return "" ; timeout
EndFunc

; Name:        __CD_VKToAutoItKey
; Description: Converts a Windows virtual key code to an AutoIt key name
; Parameters:  $iVK - virtual key code (0x08-0xFE)
; Return:      AutoIt key name string
Func __CD_VKToAutoItKey($iVK)
    Switch $iVK
        Case 0x08
            Return "BS"
        Case 0x09
            Return "TAB"
        Case 0x0D
            Return "ENTER"
        Case 0x1B
            Return "ESC"
        Case 0x20
            Return "SPACE"
        Case 0x21
            Return "PGUP"
        Case 0x22
            Return "PGDN"
        Case 0x23
            Return "END"
        Case 0x24
            Return "HOME"
        Case 0x25
            Return "LEFT"
        Case 0x26
            Return "UP"
        Case 0x27
            Return "RIGHT"
        Case 0x28
            Return "DOWN"
        Case 0x2D
            Return "INSERT"
        Case 0x2E
            Return "DELETE"
        Case 0x30 To 0x39
            Return Chr($iVK)
        Case 0x41 To 0x5A
            Return StringLower(Chr($iVK))
        Case 0x60
            Return "NUMPAD0"
        Case 0x61
            Return "NUMPAD1"
        Case 0x62
            Return "NUMPAD2"
        Case 0x63
            Return "NUMPAD3"
        Case 0x64
            Return "NUMPAD4"
        Case 0x65
            Return "NUMPAD5"
        Case 0x66
            Return "NUMPAD6"
        Case 0x67
            Return "NUMPAD7"
        Case 0x68
            Return "NUMPAD8"
        Case 0x69
            Return "NUMPAD9"
        Case 0x6A
            Return "NUMPADMULT"
        Case 0x6B
            Return "NUMPADADD"
        Case 0x6D
            Return "NUMPADSUB"
        Case 0x6E
            Return "NUMPADDOT"
        Case 0x6F
            Return "NUMPADDIV"
        Case 0x70 To 0x7B
            Return "F" & ($iVK - 0x6F)
        Case 0xBA
            Return ";"
        Case 0xBB
            Return "="
        Case 0xBC
            Return ","
        Case 0xBD
            Return "-"
        Case 0xBE
            Return "."
        Case 0xBF
            Return "/"
        Case 0xC0
            Return "``"
        Case 0xDB
            Return "["
        Case 0xDC
            Return "\"
        Case 0xDD
            Return "]"
        Case 0xDE
            Return "'"
        Case Else
            Return "{" & Hex($iVK, 2) & "}"
    EndSwitch
EndFunc

; Name:        __CD_BuildHotkeyString
; Description: Constructs an AutoIt hotkey string from modifier flags and key name
; Parameters:  $bCtrl  - True if Ctrl modifier
;              $bAlt   - True if Alt modifier
;              $bShift - True if Shift modifier
;              $bWin   - True if Win modifier
;              $sKey   - key name (e.g. "RIGHT", "F1", "A")
; Return:      Hotkey string (e.g. "^!{RIGHT}")
Func __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, $sKey)
    Local $s = ""
    If $bCtrl Then $s &= "^"
    If $bAlt Then $s &= "!"
    If $bShift Then $s &= "+"
    If $bWin Then $s &= "#"

    $sKey = StringStripWS($sKey, 3) ; trim leading+trailing
    If $sKey = "" Then Return $s

    ; Single character keys don't need braces
    If StringLen($sKey) = 1 Then
        $s &= $sKey
    Else
        ; Multi-char keys get wrapped in braces (e.g. LEFT -> {LEFT})
        $s &= "{" & StringUpper($sKey) & "}"
    EndIf

    Return $s
EndFunc

; Name:        __CD_RestartApp
; Description: Relaunches the application and exits the current instance
Func __CD_RestartApp()
    _CD_Destroy()
    Local $sCmd
    If @Compiled Then
        $sCmd = '"' & @ScriptFullPath & '"'
    Else
        $sCmd = '"' & @AutoItExe & '" "' & @ScriptFullPath & '"'
    EndIf
    Run($sCmd)
    _Shutdown()
EndFunc

; Name:        __CD_WM_CTLCOLORLISTBOX
; Description: WM handler to theme combo dropdown list with dark colors
Func __CD_WM_CTLCOLORLISTBOX($hWnd, $iMsg, $wParam, $lParam)
    If $__g_CD_hBrushCombo = 0 Then Return $GUI_RUNDEFMSG
    DllCall("gdi32.dll", "int", "SetTextColor", "handle", $wParam, "dword", $THEME_FG_TEXT)
    DllCall("gdi32.dll", "int", "SetBkColor", "handle", $wParam, "dword", $THEME_BG_INPUT)
    DllCall("gdi32.dll", "int", "SetBkMode", "handle", $wParam, "int", 1) ; OPAQUE
    Return $__g_CD_hBrushCombo
EndFunc

