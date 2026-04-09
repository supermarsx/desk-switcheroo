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
Global $__g_CD_aidTabBtn[9] ; index 1-9
Global Const $__g_CD_aTabNames = "General,Display,Scroll,Hotkeys,Behavior,Logging,Updates,Desktops"

; -- Controls per tab (arrays of IDs to show/hide) --
Global $__g_CD_aidTabCtrls[9][100] ; [tab 1-9][up to 40 controls per tab]
Global $__g_CD_aiTabCtrlCount[9]  ; how many controls per tab

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
Global $__g_CD_idBtnHkBuild[13]    ; index 0-11 for each hotkey row "..." button

; -- Tab 1 extras: General --
Global $__g_CD_idChkWidgetDrag, $__g_CD_idChkTrayMode, $__g_CD_idChkQuickAccess
Global $__g_CD_idChkListKeyNav

; -- Tab 8: Updates --
Global $__g_CD_idChkAutoUpdate, $__g_CD_idInpUpdateInterval
Global $__g_CD_idChkUpdateOnStartup, $__g_CD_idInpUpdateCheckDays
Global $__g_CD_idBtnCheckNow, $__g_CD_idBtnDownloadLatest
Global $__g_CD_iContentH = 450

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
Global $__g_CD_idChkLogging, $__g_CD_idInpLogPath, $__g_CD_idLblLogLevel
Global $__g_CD_idInpLogMaxSize
Global $__g_CD_idInpLogRotateCount, $__g_CD_idChkLogCompress
Global $__g_CD_idChkLogPID, $__g_CD_idLblLogDateFormat, $__g_CD_idChkLogFlush

; -- Tab 5: Behavior extras --
Global $__g_CD_idChkConfirmQuit

; -- Buttons --
Global $__g_CD_idBtnApply, $__g_CD_idBtnClose
Global $__g_CD_idBtnImport, $__g_CD_idBtnExport, $__g_CD_idBtnRestart

; -- Checkbox state tracking --
Global $__g_CD_aChkIDs[30]     ; control IDs
Global $__g_CD_aChkStates[30]  ; boolean states
Global $__g_CD_aChkTexts[30]   ; original text per checkbox
Global $__g_CD_iChkCount = 0

; -- Tab 9: Desktops --
Global $__g_CD_aidDeskLabel[21]   ; input fields for desktop labels, index 1-20
Global $__g_CD_aidDeskColor[21]   ; input fields for desktop colors, index 1-20
Global $__g_CD_aidDeskPreview[21] ; color preview labels, index 1-20
Global $__g_CD_iDeskCount = 0     ; how many desktop rows were created

; -- Reset button --
Global $__g_CD_idBtnReset


; #FUNCTIONS# ===================================================

Func _CD_Show()
    Local $iW = 460
    ; Dynamic height: use up to 80% of screen, minimum 570
    Local $iMaxH = Int(@DesktopHeight * 0.8)
    Local $iH = 620
    If $iH > $iMaxH Then $iH = $iMaxH
    If $iH < 570 Then $iH = 570
    Local $iX = (@DesktopWidth - $iW) / 2
    Local $iY = (@DesktopHeight - $iH) / 2

    $__g_CD_hGUI = _Theme_CreatePopup("Settings", $iW, $iH, $iX, $iY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Reset state
    $__g_CD_iChkCount = 0
    Local $t
    For $t = 1 To 8
        $__g_CD_aiTabCtrlCount[$t] = 0
    Next

    ; Create custom tab bar
    Local $aNames = StringSplit($__g_CD_aTabNames, ",")
    Local $iTabW = 52, $iTabH = 26, $iTabX = 10, $iTabY = 8
    For $t = 1 To $aNames[0]
        $__g_CD_aidTabBtn[$t] = GUICtrlCreateLabel($aNames[$t], $iTabX, $iTabY, $iTabW, $iTabH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidTabBtn[$t], 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_MAIN)
        GUICtrlSetCursor($__g_CD_aidTabBtn[$t], 0)
        $iTabX += $iTabW + 2
    Next

    ; Content area background (disabled so it doesn't intercept clicks on controls above)
    $__g_CD_iContentH = $iH - 120 ; leave room for tab bar + buttons
    Local $iContentH = $__g_CD_iContentH
    Local $idContentBg = GUICtrlCreateLabel("", 8, 38, $iW - 16, $iContentH)
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

    ; Import + Export + Restart buttons (top row)
    Local $iBtnW = 80, $iBtnH = 26
    Local $iGap = 10
    Local $iRow1Y = $iH - 70
    Local $iRow1TotalW = $iBtnW * 3 + $iGap * 2
    Local $iRow1X = ($iW - $iRow1TotalW) / 2

    $__g_CD_idBtnImport = GUICtrlCreateLabel(ChrW(0x2B07) & " Import", $iRow1X, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnImport, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnImport, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnImport, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnImport, 0)

    $__g_CD_idBtnExport = GUICtrlCreateLabel(ChrW(0x2B06) & " Export", $iRow1X + $iBtnW + $iGap, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnExport, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnExport, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnExport, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnExport, 0)

    $__g_CD_idBtnRestart = GUICtrlCreateLabel(ChrW(0x21BB) & " Restart", $iRow1X + ($iBtnW + $iGap) * 2, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnRestart, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnRestart, $THEME_FG_LINK)
    GUICtrlSetBkColor($__g_CD_idBtnRestart, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnRestart, 0)

    ; Apply + Reset + Close buttons (bottom row)
    Local $iRow2Y = $iH - 38
    Local $iTotalW = $iBtnW * 3 + $iGap * 2
    Local $iBtnX = ($iW - $iTotalW) / 2

    $__g_CD_idBtnApply = GUICtrlCreateLabel(ChrW(0x2713) & " Apply", $iBtnX, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnApply, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnApply, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnApply, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnApply, 0)

    $__g_CD_idBtnReset = GUICtrlCreateLabel(ChrW(0x21BA) & " Reset", $iBtnX + $iBtnW + $iGap, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnReset, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnReset, 0xCC6666)
    GUICtrlSetBkColor($__g_CD_idBtnReset, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnReset, 0)

    $__g_CD_idBtnClose = GUICtrlCreateLabel(ChrW(0x2715) & " Close", $iBtnX + ($iBtnW + $iGap) * 2, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnClose, 0)

    ; Load config values into controls
    __CD_PopulateControls()

    ; Show first tab
    __CD_SwitchTab(1)

    GUISetState(@SW_SHOW, $__g_CD_hGUI)
    $__g_CD_bVisible = True

    ; Blocking loop
    __CD_MessageLoop()
EndFunc

Func _CD_Destroy()
    If $__g_CD_hGUI <> 0 Then GUIDelete($__g_CD_hGUI)
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
    $__g_CD_iActiveTab = $iTab
    ; Update tab button styles
    Local $t, $c
    For $t = 1 To 8
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
    For $t = 1 To 8
        Local $iState = $GUI_HIDE
        If $t = $iTab Then $iState = $GUI_SHOW
        For $c = 0 To $__g_CD_aiTabCtrlCount[$t] - 1
            GUICtrlSetState($__g_CD_aidTabCtrls[$t][$c], $iState)
        Next
    Next
EndFunc

Func __CD_RegCtrl($iTab, $idCtrl)
    Local $c = $__g_CD_aiTabCtrlCount[$iTab]
    $__g_CD_aidTabCtrls[$iTab][$c] = $idCtrl
    $__g_CD_aiTabCtrlCount[$iTab] = $c + 1
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
    Local $t = 1, $iX = 20, $iY = 50

    $__g_CD_idChkStartWin = __CD_CreateCheckbox("Start with Windows", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkStartWin, "Launch Desk Switcheroo automatically when you log in")
    $iY += 26
    $__g_CD_idChkWrapNav = __CD_CreateCheckbox("Wrap navigation at ends", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWrapNav, "Left arrow on first desktop goes to last, and vice versa")
    $iY += 26
    $__g_CD_idChkAutoCreate = __CD_CreateCheckbox("Auto-create desktop past end", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoCreate, "Right arrow on last desktop creates a new one")
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel("Number padding (1-4):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpPadding = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpPadding, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpPadding, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpPadding, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpPadding)
    _Theme_SetTooltip($__g_CD_idInpPadding, "Zero-pad desktop numbers (2 = '01', 3 = '001')")
    $iY += 30

    $__g_CD_idLblPosition = __CD_CreateCycleLabel("Widget position:", $iX, $iY, 165, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblPosition, "Click to cycle: left, center, or right on taskbar")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Widget X offset (px):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpOffsetX = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22)
    GUICtrlSetFont($__g_CD_idInpOffsetX, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOffsetX, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOffsetX, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpOffsetX)
    _Theme_SetTooltip($__g_CD_idInpOffsetX, "Fine-tune widget position in pixels")
    $iY += 34

    $__g_CD_idChkWidgetDrag = __CD_CreateCheckbox("Enable widget drag", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWidgetDrag, "Hold and drag the widget to reposition it on the taskbar")
    $iY += 26
    $__g_CD_idChkTrayMode = __CD_CreateCheckbox("Tray icon mode", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayMode, "Run as system tray icon instead of taskbar widget (requires restart)")
    $iY += 26
    $__g_CD_idChkQuickAccess = __CD_CreateCheckbox("Quick-access number input", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkQuickAccess, "Double-click the number to type a desktop number (1-9) to jump to")
    $iY += 26
    $__g_CD_idChkListKeyNav = __CD_CreateCheckbox("Keyboard nav in list", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListKeyNav, "Use Up/Down arrow keys to navigate when the desktop list is open")
EndFunc

Func __CD_BuildTabDisplay()
    Local $t = 2, $iX = 20, $iY = 50

    $__g_CD_idChkShowCount = __CD_CreateCheckbox("Show desktop count (2/5)", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkShowCount, "Show total count next to current number (e.g. '2/5')")
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel("Count font size:", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpCountFont = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCountFont, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCountFont, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCountFont, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpCountFont)
    _Theme_SetTooltip($__g_CD_idInpCountFont, "Font size for the desktop number on the widget")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Widget opacity (50-255):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpOpacity = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOpacity, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOpacity, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOpacity, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpOpacity)
    _Theme_SetTooltip($__g_CD_idInpOpacity, "Widget transparency (50 = very transparent, 255 = fully opaque)")
    $iY += 30

    $__g_CD_idLblTheme = __CD_CreateCycleLabel("Theme:", $iX, $iY, 165, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblTheme, "Click to cycle color scheme (requires restart)")
    $iY += 26

    Local $idThemeHint = GUICtrlCreateLabel("Theme change requires restart", $iX + 20, $iY, 250, 16)
    GUICtrlSetFont($idThemeHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idThemeHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idThemeHint, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idThemeHint)
    $iY += 30

    $__g_CD_idChkThumbnails = __CD_CreateCheckbox("Show desktop thumbnails on hover", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkThumbnails, "Show a preview popup with window list when hovering a desktop")
    $iY += 34

    $idLbl = GUICtrlCreateLabel("Thumbnail width (px):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpThumbW = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbW, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbW, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbW, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpThumbW)
    _Theme_SetTooltip($__g_CD_idInpThumbW, "Size of the thumbnail preview popup in pixels")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Thumbnail height (px):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpThumbH = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbH, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbH, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbH, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpThumbH)
    _Theme_SetTooltip($__g_CD_idInpThumbH, "Size of the thumbnail preview popup in pixels")
    $iY += 30

    $__g_CD_idChkThumbScreenshot = __CD_CreateCheckbox("Use real desktop screenshots", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkThumbScreenshot, "Capture actual desktop screenshots instead of text preview (briefly switches desktops)")
    $iY += 34

    $idLbl = GUICtrlCreateLabel("Screenshot cache TTL (s):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpThumbCacheTTL = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbCacheTTL, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbCacheTTL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbCacheTTL, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpThumbCacheTTL)
    _Theme_SetTooltip($__g_CD_idInpThumbCacheTTL, "How many seconds before cached screenshots expire (5-300)")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("List font name:", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListFont = GUICtrlCreateInput("", $iX + 170, $iY, 200, 22)
    GUICtrlSetFont($__g_CD_idInpListFont, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListFont, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListFont, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListFont)
    _Theme_SetTooltip($__g_CD_idInpListFont, "Font for desktop list items (empty = default Fira Code/Consolas)")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("List font size (6-14):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListFontSize = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListFontSize, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListFontSize)
    _Theme_SetTooltip($__g_CD_idInpListFontSize, "Font size for desktop list items")
    $iY += 34

    $__g_CD_idChkListScrollable = __CD_CreateCheckbox("Scrollable desktop list", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListScrollable, "Enable scrolling when many desktops (shows scroll arrows)")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Max visible items (3-30):", $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListMaxVisible = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListMaxVisible, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListMaxVisible, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListMaxVisible, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListMaxVisible)
    _Theme_SetTooltip($__g_CD_idInpListMaxVisible, "Maximum items visible before scrolling activates")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Scroll speed (items, 1-5):", $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpListScrollSpeed = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListScrollSpeed, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListScrollSpeed, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListScrollSpeed, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpListScrollSpeed)
    _Theme_SetTooltip($__g_CD_idInpListScrollSpeed, "Number of items to scroll per step")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Tooltip font size (6-12):", $iX, $iY + 2, 185, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpTooltipFontSize = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTooltipFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTooltipFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTooltipFontSize, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpTooltipFontSize)
    _Theme_SetTooltip($__g_CD_idInpTooltipFontSize, "Font size for dark-themed tooltips")
EndFunc

Func __CD_BuildTabScroll()
    Local $t = 3, $iX = 20, $iY = 50

    $__g_CD_idChkScroll = __CD_CreateCheckbox("Scroll wheel on widget", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkScroll, "Use mouse wheel on the widget to cycle desktops")
    $iY += 26
    $__g_CD_idLblScrollDir = __CD_CreateCycleLabel("Direction:", $iX + 20, $iY, 145, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblScrollDir, "Click to toggle: normal or inverted scroll direction")
    $iY += 26
    $__g_CD_idChkScrollWrap = __CD_CreateCheckbox("Wrap at ends", $iX + 20, $iY, 280, $t)
    _Theme_SetTooltip($__g_CD_idChkScrollWrap, "Scroll past last desktop wraps to first")
    $iY += 34
    $__g_CD_idChkListScroll = __CD_CreateCheckbox("Scroll on desktop list", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListScroll, "Use mouse wheel on the desktop list panel")
    $iY += 26
    $__g_CD_idLblListAction = __CD_CreateCycleLabel("List action:", $iX + 20, $iY, 145, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblListAction, "Click to toggle: 'switch' changes desktops, 'scroll' scrolls the list")
EndFunc

Func __CD_BuildTabHotkeys()
    Local $t = 4, $iX = 20, $iY = 50
    Local $iLblW = 100, $iInpW = 130, $iBtnBuildW = 24, $i

    ; Dynamic label: "Desktop N:" generated per iteration below

    ; Next (build index 0)
    Local $idLbl = GUICtrlCreateLabel("Next:", $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkNext, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkNext)
    _Theme_SetTooltip($__g_CD_idInpHkNext, "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}")
    $__g_CD_idBtnHkBuild[0] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[0], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[0], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[0], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[0], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[0])
    _Theme_SetTooltip($__g_CD_idBtnHkBuild[0], "Open hotkey builder to visually create a key combination")
    $iY += 24

    ; Prev (build index 1)
    $idLbl = GUICtrlCreateLabel("Prev:", $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkPrev, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkPrev)
    _Theme_SetTooltip($__g_CD_idInpHkPrev, "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}")
    $__g_CD_idBtnHkBuild[1] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[1], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[1], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[1], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[1], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[1])
    _Theme_SetTooltip($__g_CD_idBtnHkBuild[1], "Open hotkey builder to visually create a key combination")
    $iY += 24

    ; Desktop hotkeys (build index 2+, count from config)
    Local $iHkCount = _Cfg_GetHotkeyDesktopCount()
    If $iHkCount > 9 Then $iHkCount = 9 ; limited by array size
    For $i = 1 To $iHkCount
        $idLbl = GUICtrlCreateLabel("Desktop " & $i & ":", $iX, $iY + 2, $iLblW, 18)
        GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idLbl, $THEME_FG_DIM)
        GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idLbl)
        $__g_CD_aidInpHkDesktop[$i] = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
        GUICtrlSetFont($__g_CD_aidInpHkDesktop[$i], 9, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidInpHkDesktop[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidInpHkDesktop[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidInpHkDesktop[$i])
        _Theme_SetTooltip($__g_CD_aidInpHkDesktop[$i], "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}")
        $__g_CD_idBtnHkBuild[$i + 1] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_idBtnHkBuild[$i + 1], 8, 700, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_idBtnHkBuild[$i + 1], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idBtnHkBuild[$i + 1], $THEME_BG_HOVER)
        GUICtrlSetCursor($__g_CD_idBtnHkBuild[$i + 1], 0)
        __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[$i + 1])
        _Theme_SetTooltip($__g_CD_idBtnHkBuild[$i + 1], "Open hotkey builder to visually create a key combination")
        $iY += 24
    Next

    ; Toggle List (build index 11)
    $idLbl = GUICtrlCreateLabel("Toggle List:", $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkToggleList = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkToggleList, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkToggleList, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkToggleList, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkToggleList)
    _Theme_SetTooltip($__g_CD_idInpHkToggleList, "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}")
    $__g_CD_idBtnHkBuild[11] = GUICtrlCreateLabel("...", $iX + $iLblW + $iInpW + 4, $iY, $iBtnBuildW, 20, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnHkBuild[11], 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnHkBuild[11], $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnHkBuild[11], $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnHkBuild[11], 0)
    __CD_RegCtrl($t, $__g_CD_idBtnHkBuild[11])
    _Theme_SetTooltip($__g_CD_idBtnHkBuild[11], "Open hotkey builder to visually create a key combination")
    $iY += 28

    ; Help
    $idLbl = GUICtrlCreateLabel("^=Ctrl  !=Alt  +=Shift  #=Win  e.g. ^!{RIGHT}", $iX, $iY, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
EndFunc

Func __CD_BuildTabBehavior()
    Local $t = 5, $iX = 20, $iY = 50

    $__g_CD_idChkConfirmDel = __CD_CreateCheckbox("Confirm before delete", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmDel, "Show confirmation dialog before deleting a desktop")
    $iY += 26
    $__g_CD_idChkMidClick = __CD_CreateCheckbox("Middle-click to delete", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMidClick, "Middle-click a desktop in the list to delete it")
    $iY += 26
    $__g_CD_idChkMoveWin = __CD_CreateCheckbox("Move Window Here in menu", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMoveWin, "Show 'Move Window Here' in the desktop right-click menu")
    $iY += 34

    Local $aFields[5][2] = [["Peek delay (ms):", ""], ["Auto-hide timeout (ms):", ""], _
        ["Topmost interval (ms):", ""], ["Menu hide delay (ms):", ""]]

    $aFields[0][1] = "peek"
    $aFields[1][1] = "autohide"
    $aFields[2][1] = "topmost"
    $aFields[3][1] = "cmdelay"

    Local $idLbl
    $idLbl = GUICtrlCreateLabel("Peek delay (ms):", $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpPeekDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpPeekDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpPeekDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpPeekDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpPeekDelay)
    _Theme_SetTooltip($__g_CD_idInpPeekDelay, "Time in milliseconds (1000ms = 1 second)")
    $iY += 28

    $idLbl = GUICtrlCreateLabel("Auto-hide timeout (ms):", $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpAutoHide = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHide, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHide, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHide, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHide)
    _Theme_SetTooltip($__g_CD_idInpAutoHide, "Time in milliseconds (1000ms = 1 second)")
    $iY += 28

    $idLbl = GUICtrlCreateLabel("Topmost interval (ms):", $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpTopmost = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTopmost, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTopmost, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTopmost, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpTopmost)
    _Theme_SetTooltip($__g_CD_idInpTopmost, "Time in milliseconds (1000ms = 1 second)")
    $iY += 28

    $idLbl = GUICtrlCreateLabel("Menu hide delay (ms):", $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpCmDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCmDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCmDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCmDelay, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpCmDelay)
    _Theme_SetTooltip($__g_CD_idInpCmDelay, "Time in milliseconds (1000ms = 1 second)")
    $iY += 34

    $__g_CD_idChkConfigWatcher = __CD_CreateCheckbox("Config file watcher", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfigWatcher, "Automatically reload settings when the INI file changes")
    $iY += 28

    $idLbl = GUICtrlCreateLabel("Watcher interval (ms):", $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWatcherInterval = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWatcherInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWatcherInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWatcherInterval, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpWatcherInterval)
    _Theme_SetTooltip($__g_CD_idInpWatcherInterval, "Time in milliseconds (1000ms = 1 second)")
    $iY += 28

    $idLbl = GUICtrlCreateLabel("Count cache TTL (ms):", $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpCountCacheTTL = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCountCacheTTL, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCountCacheTTL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCountCacheTTL, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpCountCacheTTL)
    _Theme_SetTooltip($__g_CD_idInpCountCacheTTL, "How long to cache desktop count before re-querying (ms)")
    $iY += 30

    $__g_CD_idChkConfirmQuit = __CD_CreateCheckbox("Confirm before quitting", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmQuit, "Show a confirmation dialog before exiting Desk Switcheroo")
EndFunc


Func __CD_BuildTabLogging()
    Local $t = 6, $iX = 20, $iY = 50

    $__g_CD_idChkLogging = __CD_CreateCheckbox("Enable logging", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogging, "Write debug information to a log file for troubleshooting")
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel("Log file path:", $iX, $iY + 2, 100, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogPath = GUICtrlCreateInput("", $iX + 105, $iY, 300, 22)
    GUICtrlSetFont($__g_CD_idInpLogPath, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogPath, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogPath, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpLogPath)
    _Theme_SetTooltip($__g_CD_idInpLogPath, "Full path to log file (empty = desk_switcheroo.log in script folder)")
    $iY += 30

    $__g_CD_idLblLogLevel = __CD_CreateCycleLabel("Log level:", $iX, $iY, 100, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblLogLevel, "Click to cycle: error, warn, info, debug (debug is most verbose)")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Max log size (MB):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogMaxSize = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpLogMaxSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogMaxSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogMaxSize, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpLogMaxSize)
    _Theme_SetTooltip($__g_CD_idInpLogMaxSize, "Rotate log file when it exceeds this size")
    $iY += 30

    $idLbl = GUICtrlCreateLabel("Rotate count (1-10):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogRotateCount = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpLogRotateCount, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogRotateCount, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogRotateCount, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpLogRotateCount)
    _Theme_SetTooltip($__g_CD_idInpLogRotateCount, "Number of rotated log files to keep (1-10)")
    $iY += 30

    $__g_CD_idChkLogCompress = __CD_CreateCheckbox("Compress old logs", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogCompress, "Zip old log files when rotating (uses PowerShell)")
    $iY += 34

    $__g_CD_idChkLogPID = __CD_CreateCheckbox("Include PID in log", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogPID, "Add process ID [PID:XXXX] to each log line after the timestamp")
    $iY += 34

    $__g_CD_idLblLogDateFormat = __CD_CreateCycleLabel("Date format:", $iX, $iY, 100, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblLogDateFormat, "Click to cycle: iso (YYYY-MM-DD), us (MM/DD/YYYY), eu (DD/MM/YYYY)")
    $iY += 30

    $__g_CD_idChkLogFlush = __CD_CreateCheckbox("Flush immediately", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogFlush, "Flush log file after every write (vs buffered I/O)")
EndFunc

Func __CD_BuildTabUpdates()
    Local $t = 7, $iX = 20, $iY = 50

    ; Current version display
    Local $idVerLbl = GUICtrlCreateLabel("Current version: v" & $APP_VERSION, $iX, $iY, 300, 18)
    GUICtrlSetFont($idVerLbl, 9, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idVerLbl, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idVerLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idVerLbl)
    $iY += 26

    $__g_CD_idChkAutoUpdate = __CD_CreateCheckbox("Auto-check for updates", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoUpdate, "Periodically check GitHub for new releases")
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel("Check interval (hours):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpUpdateInterval = GUICtrlCreateInput("", $iX + 170, $iY, 100, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpUpdateInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpUpdateInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpUpdateInterval, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpUpdateInterval)
    _Theme_SetTooltip($__g_CD_idInpUpdateInterval, "How often to check for updates (in hours)")
    $iY += 34

    $__g_CD_idChkUpdateOnStartup = __CD_CreateCheckbox("Check on startup", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkUpdateOnStartup, "Check for updates when the application starts (respects day interval)")
    $iY += 34

    Local $idLblDays = GUICtrlCreateLabel("Check every (days):", $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblDays, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblDays, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblDays, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblDays)
    $__g_CD_idInpUpdateCheckDays = GUICtrlCreateInput("", $iX + 170, $iY, 100, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpUpdateCheckDays, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpUpdateCheckDays, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpUpdateCheckDays, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpUpdateCheckDays)
    _Theme_SetTooltip($__g_CD_idInpUpdateCheckDays, "Minimum days between startup update checks (1-90)")
    $iY += 34

    $__g_CD_idBtnCheckNow = GUICtrlCreateLabel(ChrW(0x21BB) & " Check Now", $iX, $iY, 120, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnCheckNow, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnCheckNow, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnCheckNow, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnCheckNow, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnCheckNow)
    _Theme_SetTooltip($__g_CD_idBtnCheckNow, "Check for updates right now")

    $__g_CD_idBtnDownloadLatest = GUICtrlCreateLabel(ChrW(0x2B07) & " Download Latest", $iX + 130, $iY, 140, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnDownloadLatest, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnDownloadLatest, $THEME_FG_LINK)
    GUICtrlSetBkColor($__g_CD_idBtnDownloadLatest, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnDownloadLatest, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnDownloadLatest)
    _Theme_SetTooltip($__g_CD_idBtnDownloadLatest, "Download the latest portable version to your Downloads folder")
EndFunc

Func __CD_BuildTabDesktops()
    Local $t = 8, $iX = 20, $iY = 50

    ; Enable desktop colors checkbox (moved from removed Colors tab)
    $__g_CD_idChkColorsEnabled = __CD_CreateCheckbox("Enable desktop colors", $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkColorsEnabled, "Show colored indicators next to desktop names in the list")
    $iY += 28

    ; Get current desktop count, limit to what fits in content area
    Local $iCount = _VD_GetCount()
    Local $iMaxRows = Int(($__g_CD_iContentH - 100) / 24) ; 100px for checkbox + header + padding
    If $iMaxRows < 3 Then $iMaxRows = 3
    If $iCount > $iMaxRows Then $iCount = $iMaxRows
    If $iCount > 20 Then $iCount = 20
    $__g_CD_iDeskCount = $iCount

    ; Header
    Local $idHdr = GUICtrlCreateLabel("Desktop    Label                     Color", $iX, $iY, 400, 16)
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

; =============================================
; POPULATE FROM CONFIG
; =============================================

Func __CD_PopulateControls()
    Local $i
    ; General
    __CD_SetCheckState($__g_CD_idChkStartWin, _Cfg_GetStartWithWindows())
    __CD_SetCheckState($__g_CD_idChkWrapNav, _Cfg_GetWrapNavigation())
    __CD_SetCheckState($__g_CD_idChkAutoCreate, _Cfg_GetAutoCreateDesktop())
    GUICtrlSetData($__g_CD_idInpPadding, _Cfg_GetNumberPadding())
    GUICtrlSetData($__g_CD_idLblPosition, _Cfg_GetWidgetPosition())
    GUICtrlSetData($__g_CD_idInpOffsetX, _Cfg_GetWidgetOffsetX())
    __CD_SetCheckState($__g_CD_idChkWidgetDrag, _Cfg_GetWidgetDragEnabled())
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

    ; Logging
    __CD_SetCheckState($__g_CD_idChkLogging, _Cfg_GetLoggingEnabled())
    GUICtrlSetData($__g_CD_idInpLogPath, _Cfg_GetLogFilePath())
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
EndFunc

; =============================================
; BLOCKING MESSAGE LOOP
; =============================================

Func __CD_MessageLoop()
    Local $iHovered = 0, $t

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
                    _CheckUpdateNow()
                Case $__g_CD_idBtnDownloadLatest
                    _DownloadLatestPortable()
            EndSwitch

            ; Tab button clicks
            For $t = 1 To 8
                If $id = $__g_CD_aidTabBtn[$t] Then
                    __CD_SwitchTab($t)
                    ExitLoop
                EndIf
            Next

            ; Checkbox clicks (label-based, handle box + text clicks)
            __CD_HandleCheckboxClick($id)

            ; Hotkey builder "..." button clicks
            __CD_HandleHotkeyBuildClick($id)

            ; Cycle label clicks
            If $id = $__g_CD_idLblPosition Then __CD_CycleValue($id, "left|center|right")
            If $id = $__g_CD_idLblScrollDir Then __CD_CycleValue($id, "normal|inverted")
            If $id = $__g_CD_idLblListAction Then __CD_CycleValue($id, "switch|scroll")
            If $id = $__g_CD_idLblTheme Then __CD_CycleValue($id, _Theme_GetAvailableSchemes())
            If $id = $__g_CD_idLblLogLevel Then __CD_CycleValue($id, "error|warn|info|debug")
            If $id = $__g_CD_idLblLogDateFormat Then __CD_CycleValue($id, "iso|us|eu")
        EndIf

        ; Escape closes
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

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
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    Local $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnReset Then $iFgRestore = 0xCC6666
                    If $iHovered = $__g_CD_idBtnImport Or $iHovered = $__g_CD_idBtnExport Then $iFgRestore = $THEME_FG_DIM
                    If $iHovered = $__g_CD_idBtnRestart Then $iFgRestore = $THEME_FG_LINK
                    If $iHovered = $__g_CD_idBtnCheckNow Then $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnDownloadLatest Then $iFgRestore = $THEME_FG_LINK
                    _Theme_RemoveHover($iHovered, $iFgRestore, $THEME_BG_HOVER)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        ; Tick toast fade-out while dialog is open
        _Theme_ToastTick()

        ; Themed tooltip hover check
        _Theme_CheckTooltipHover($__g_CD_hGUI)

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
    Local $i
    Local $bOldStartup = _Cfg_IsStartupEnabled()

    ; General
    _Cfg_SetStartWithWindows(__CD_GetCheckState($__g_CD_idChkStartWin))
    _Cfg_SetWrapNavigation(__CD_GetCheckState($__g_CD_idChkWrapNav))
    _Cfg_SetAutoCreateDesktop(__CD_GetCheckState($__g_CD_idChkAutoCreate))
    Local $s = GUICtrlRead($__g_CD_idInpPadding)
    If StringIsInt($s) Then _Cfg_SetNumberPadding(Int($s))
    _Cfg_SetWidgetPosition(GUICtrlRead($__g_CD_idLblPosition))
    $s = GUICtrlRead($__g_CD_idInpOffsetX)
    If $s <> "" And StringIsInt($s) Then _Cfg_SetWidgetOffsetX(Int($s))
    _Cfg_SetWidgetDragEnabled(__CD_GetCheckState($__g_CD_idChkWidgetDrag))
    _Cfg_SetTrayIconMode(__CD_GetCheckState($__g_CD_idChkTrayMode))
    _Cfg_SetQuickAccessEnabled(__CD_GetCheckState($__g_CD_idChkQuickAccess))
    _Cfg_SetListKeyboardNav(__CD_GetCheckState($__g_CD_idChkListKeyNav))

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

    ; Logging
    _Cfg_SetLoggingEnabled(__CD_GetCheckState($__g_CD_idChkLogging))
    _Cfg_SetLogFilePath(GUICtrlRead($__g_CD_idInpLogPath))
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
        Local $aErrPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast("Failed to save settings", $aErrPos[0], $aErrPos[1] + $aErrPos[3] + 4, 2000, $TOAST_ERROR)
        EndIf
        Return
    EndIf

    ; Apply changes live to the running app
    _ApplySettingsLive()

    ; Rebuild desktop list to reflect font/color changes
    If _DL_IsVisible() Then
        _DL_Destroy()
        _DL_Show($iTaskbarY, $iDesktop)
    EndIf

    ; Startup toggle with verification
    Local $sToastMsg = "Settings saved"
    Local $iToastIcon = $TOAST_SUCCESS
    If _Cfg_GetStartWithWindows() <> $bOldStartup Then
        If _Cfg_GetStartWithWindows() Then
            If _Cfg_EnableStartup() Then
                $sToastMsg = "Settings saved — startup enabled"
            Else
                $sToastMsg = "Settings saved — startup failed"
                $iToastIcon = $TOAST_ERROR
            EndIf
        Else
            If _Cfg_DisableStartup() Then
                $sToastMsg = "Settings saved — startup disabled"
            Else
                $sToastMsg = "Settings saved — startup removal failed"
                $iToastIcon = $TOAST_ERROR
            EndIf
        EndIf
    EndIf

    ; Theme change notification
    If _Cfg_GetTheme() <> $sOldTheme Then
        $sToastMsg = "Theme changed — restart required"
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
    If Not _Theme_Confirm("Reset Settings", "Reset all settings to defaults?") Then Return

    Local $sPath = _Cfg_GetPath()
    FileDelete($sPath)
    _Cfg_Init($sPath)
    __CD_PopulateControls()

    Local $aPos = WinGetPos($__g_CD_hGUI)
    If Not @error Then
        _Theme_Toast("Reset to defaults", $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_WARNING)
    EndIf
EndFunc

; Name:        __CD_ImportSettings
; Description: Opens a file dialog to import settings from an external INI file
Func __CD_ImportSettings()
    Local $sPath = FileOpenDialog("Import Settings", @DesktopDir, "INI Files (*.ini)", 1, "", $__g_CD_hGUI)
    If $sPath = "" Or @error Then Return
    If _Cfg_Import($sPath) Then
        _ApplySettingsLive()
        __CD_PopulateControls()
        Local $aPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast("Settings imported", $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_SUCCESS)
        EndIf
    Else
        Local $aPos2 = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast("Import failed", $aPos2[0], $aPos2[1] + $aPos2[3] + 4, 1500, $TOAST_ERROR)
        EndIf
    EndIf
EndFunc

; Name:        __CD_ExportSettings
; Description: Opens a file dialog to export current settings to an INI file
Func __CD_ExportSettings()
    Local $sPath = FileSaveDialog("Export Settings", @DesktopDir, "INI Files (*.ini)", 16, "desk_switcheroo.ini", $__g_CD_hGUI)
    If $sPath = "" Or @error Then Return
    ; Ensure .ini extension
    If StringRight($sPath, 4) <> ".ini" Then $sPath &= ".ini"
    If _Cfg_Export($sPath) Then
        Local $aPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast("Settings exported", $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_SUCCESS)
        EndIf
    Else
        Local $aPos2 = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast("Export failed", $aPos2[0], $aPos2[1] + $aPos2[3] + 4, 1500, $TOAST_ERROR)
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
    ; Index 0=Next, 1=Prev, 2-10=Desktop 1-9, 11=Toggle List
    Local $idInput = 0
    If $id = $__g_CD_idBtnHkBuild[0] Then
        $idInput = $__g_CD_idInpHkNext
    ElseIf $id = $__g_CD_idBtnHkBuild[1] Then
        $idInput = $__g_CD_idInpHkPrev
    ElseIf $id = $__g_CD_idBtnHkBuild[11] Then
        $idInput = $__g_CD_idInpHkToggleList
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
    Local $idTitle = GUICtrlCreateLabel("Hotkey Builder", 10, 8, $iDlgW - 20, 18)
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
    Local $idKeyLbl = GUICtrlCreateLabel("Key:", 16, $iKeyY + 2, 35, 18)
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
    _Theme_SetTooltip($idCapture, "Press to capture a key (waits 5 seconds)")

    ; Hint
    Local $idHint = GUICtrlCreateLabel("e.g.: LEFT, RIGHT, F1-F12, 1-9, A-Z", 16, $iKeyY + 26, 250, 14)
    GUICtrlSetFont($idHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idHint, $GUI_BKCOLOR_TRANSPARENT)

    ; Preview
    Local $iPreviewY = $iKeyY + 48
    Local $idPreviewLbl = GUICtrlCreateLabel("Preview:", 16, $iPreviewY + 2, 50, 18)
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
    Local $idOK = GUICtrlCreateLabel("OK", ($iDlgW / 2) - $iBtnW - 8, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idOK, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idOK, $THEME_FG_MENU)
    GUICtrlSetBkColor($idOK, $THEME_BG_HOVER)
    GUICtrlSetCursor($idOK, 0)

    Local $idCancel = GUICtrlCreateLabel("Cancel", ($iDlgW / 2) + 8, $iBtnY, $iBtnW, $iBtnH, _
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
                    GUICtrlSetData($idKeyInput, "Press a key...")
                    Local $sCaptured = __CD_CaptureKeyPress()
                    If $sCaptured <> "" Then
                        GUICtrlSetData($idKeyInput, $sCaptured)
                        ; Auto-detect modifiers held during capture
                        Local $retModCtrl = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x11)
                        If Not @error And BitAND($retModCtrl[0], 0x8000) <> 0 Then
                            $bCtrl = True
                            GUICtrlSetData($idChkCtrl, "  [x]  Ctrl")
                            GUICtrlSetColor($idChkCtrl, $THEME_FG_WHITE)
                        EndIf
                        Local $retModAlt = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x12)
                        If Not @error And BitAND($retModAlt[0], 0x8000) <> 0 Then
                            $bAlt = True
                            GUICtrlSetData($idChkAlt, "  [x]  Alt")
                            GUICtrlSetColor($idChkAlt, $THEME_FG_WHITE)
                        EndIf
                        Local $retModShift = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x10)
                        If Not @error And BitAND($retModShift[0], 0x8000) <> 0 Then
                            $bShift = True
                            GUICtrlSetData($idChkShift, "  [x]  Shift")
                            GUICtrlSetColor($idChkShift, $THEME_FG_WHITE)
                        EndIf
                        Local $retModWin = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x5B)
                        If Not @error And BitAND($retModWin[0], 0x8000) <> 0 Then
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
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idOK Then $iFound = $idOK
            If $aCursor[4] = $idCancel Then $iFound = $idCancel
            If $aCursor[4] = $idCapture Then $iFound = $idCapture
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then _Theme_RemoveHover($iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
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
            If Not @error And BitAND($ret[0], 0x0001) <> 0 Then
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
