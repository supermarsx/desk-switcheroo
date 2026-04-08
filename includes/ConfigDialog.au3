#include-once
#include "Config.au3"
#include "Theme.au3"
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
Global $__g_CD_aidTabBtn[8] ; index 1-7
Global Const $__g_CD_aTabNames = "General,Display,Scroll,Hotkeys,Behavior,Colors,Logging"

; -- Controls per tab (arrays of IDs to show/hide) --
Global $__g_CD_aidTabCtrls[8][40] ; [tab 1-7][up to 40 controls per tab]
Global $__g_CD_aiTabCtrlCount[8]  ; how many controls per tab

; -- Tab 1: General --
Global $__g_CD_idChkStartWin, $__g_CD_idChkWrapNav, $__g_CD_idChkAutoCreate
Global $__g_CD_idInpPadding, $__g_CD_idInpOffsetX
Global $__g_CD_idLblPosition ; label that cycles left/center/right

; -- Tab 2: Display --
Global $__g_CD_idChkShowCount, $__g_CD_idInpCountFont, $__g_CD_idInpOpacity
Global $__g_CD_idLblTheme

; -- Tab 3: Scroll --
Global $__g_CD_idChkScroll, $__g_CD_idChkScrollWrap
Global $__g_CD_idChkListScroll
Global $__g_CD_idLblScrollDir, $__g_CD_idLblListAction

; -- Tab 4: Hotkeys --
Global $__g_CD_idInpHkNext, $__g_CD_idInpHkPrev, $__g_CD_idInpHkToggleList
Global $__g_CD_aidInpHkDesktop[10] ; index 1-9

; -- Tab 1 extras: General --
Global $__g_CD_idChkWidgetDrag, $__g_CD_idChkTrayMode, $__g_CD_idChkQuickAccess
Global $__g_CD_idChkListKeyNav

; -- Tab 5: Behavior --
Global $__g_CD_idChkConfirmDel, $__g_CD_idChkMidClick, $__g_CD_idChkMoveWin
Global $__g_CD_idInpPeekDelay, $__g_CD_idInpAutoHide, $__g_CD_idInpTopmost, $__g_CD_idInpCmDelay
Global $__g_CD_idChkConfigWatcher, $__g_CD_idInpWatcherInterval

; -- Tab 6: Colors --
Global $__g_CD_idChkColorsEnabled
Global $__g_CD_aidInpColor[10]    ; index 1-9
Global $__g_CD_aidLblPreview[10]  ; index 1-9

; -- Tab 7: Logging --
Global $__g_CD_idChkLogging, $__g_CD_idInpLogPath, $__g_CD_idLblLogLevel

; -- Buttons --
Global $__g_CD_idBtnApply, $__g_CD_idBtnClose
Global $__g_CD_idBtnImport, $__g_CD_idBtnExport, $__g_CD_idBtnRestart

; -- Checkbox state tracking --
Global $__g_CD_aChkIDs[20]     ; control IDs
Global $__g_CD_aChkStates[20]  ; boolean states
Global $__g_CD_aChkTexts[20]   ; original text per checkbox
Global $__g_CD_iChkCount = 0

; -- Reset button --
Global $__g_CD_idBtnReset


; #FUNCTIONS# ===================================================

Func _CD_Show()
    Local $iW = 460, $iH = 475
    Local $iX = (@DesktopWidth - $iW) / 2
    Local $iY = (@DesktopHeight - $iH) / 2

    $__g_CD_hGUI = _Theme_CreatePopup("Settings", $iW, $iH, $iX, $iY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Reset state
    $__g_CD_iChkCount = 0
    Local $t
    For $t = 1 To 7
        $__g_CD_aiTabCtrlCount[$t] = 0
    Next

    ; Create custom tab bar
    Local $aNames = StringSplit($__g_CD_aTabNames, ",")
    Local $iTabW = 60, $iTabH = 26, $iTabX = 10, $iTabY = 8
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
    Local $idContentBg = GUICtrlCreateLabel("", 8, 38, $iW - 16, 352)
    GUICtrlSetBkColor($idContentBg, $THEME_BG_MAIN)
    GUICtrlSetState($idContentBg, $GUI_DISABLE)

    ; Build each tab's controls
    __CD_BuildTabGeneral()
    __CD_BuildTabDisplay()
    __CD_BuildTabScroll()
    __CD_BuildTabHotkeys()
    __CD_BuildTabBehavior()
    __CD_BuildTabColors()
    __CD_BuildTabLogging()

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
    For $t = 1 To 7
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
    For $t = 1 To 7
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
    $iY += 26
    $__g_CD_idChkWrapNav = __CD_CreateCheckbox("Wrap navigation at ends", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkAutoCreate = __CD_CreateCheckbox("Auto-create desktop past end", $iX, $iY, 300, $t)
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
    $iY += 30

    $__g_CD_idLblPosition = __CD_CreateCycleLabel("Widget position:", $iX, $iY, 165, 90, $t)
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
    $iY += 34

    $__g_CD_idChkWidgetDrag = __CD_CreateCheckbox("Enable widget drag", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkTrayMode = __CD_CreateCheckbox("Tray icon mode", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkQuickAccess = __CD_CreateCheckbox("Quick-access number input", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkListKeyNav = __CD_CreateCheckbox("Keyboard nav in list", $iX, $iY, 300, $t)
EndFunc

Func __CD_BuildTabDisplay()
    Local $t = 2, $iX = 20, $iY = 50

    $__g_CD_idChkShowCount = __CD_CreateCheckbox("Show desktop count (2/5)", $iX, $iY, 300, $t)
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
    $iY += 30

    $__g_CD_idLblTheme = __CD_CreateCycleLabel("Theme:", $iX, $iY, 165, 90, $t)
    $iY += 26

    Local $idThemeHint = GUICtrlCreateLabel("Theme change requires restart", $iX + 20, $iY, 250, 16)
    GUICtrlSetFont($idThemeHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idThemeHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idThemeHint, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idThemeHint)
EndFunc

Func __CD_BuildTabScroll()
    Local $t = 3, $iX = 20, $iY = 50

    $__g_CD_idChkScroll = __CD_CreateCheckbox("Scroll wheel on widget", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idLblScrollDir = __CD_CreateCycleLabel("Direction:", $iX + 20, $iY, 145, 90, $t)
    $iY += 26
    $__g_CD_idChkScrollWrap = __CD_CreateCheckbox("Wrap at ends", $iX + 20, $iY, 280, $t)
    $iY += 34
    $__g_CD_idChkListScroll = __CD_CreateCheckbox("Scroll on desktop list", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idLblListAction = __CD_CreateCycleLabel("List action:", $iX + 20, $iY, 145, 90, $t)
EndFunc

Func __CD_BuildTabHotkeys()
    Local $t = 4, $iX = 20, $iY = 50
    Local $iLblW = 100, $iInpW = 150, $i

    Local $aLabels[13] = [12, "Next:", "Prev:", "Desktop 1:", "Desktop 2:", "Desktop 3:", _
        "Desktop 4:", "Desktop 5:", "Desktop 6:", "Desktop 7:", "Desktop 8:", "Desktop 9:", "Toggle List:"]

    ; Next
    Local $idLbl = GUICtrlCreateLabel($aLabels[1], $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkNext, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkNext)
    $iY += 24

    ; Prev
    $idLbl = GUICtrlCreateLabel($aLabels[2], $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkPrev, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkPrev)
    $iY += 24

    ; Desktop 1-9
    For $i = 1 To 9
        $idLbl = GUICtrlCreateLabel($aLabels[$i + 2], $iX, $iY + 2, $iLblW, 18)
        GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idLbl, $THEME_FG_DIM)
        GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idLbl)
        $__g_CD_aidInpHkDesktop[$i] = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
        GUICtrlSetFont($__g_CD_aidInpHkDesktop[$i], 9, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidInpHkDesktop[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidInpHkDesktop[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidInpHkDesktop[$i])
        $iY += 24
    Next

    ; Toggle List
    $idLbl = GUICtrlCreateLabel($aLabels[12], $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpHkToggleList = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkToggleList, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkToggleList, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkToggleList, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idInpHkToggleList)
    $iY += 28

    ; Help
    $idLbl = GUICtrlCreateLabel("^=Ctrl  !=Alt  +=Shift  e.g. ^!{RIGHT}", $iX, $iY, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
EndFunc

Func __CD_BuildTabBehavior()
    Local $t = 5, $iX = 20, $iY = 50

    $__g_CD_idChkConfirmDel = __CD_CreateCheckbox("Confirm before delete", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkMidClick = __CD_CreateCheckbox("Middle-click to delete", $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkMoveWin = __CD_CreateCheckbox("Move Window Here in menu", $iX, $iY, 300, $t)
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
    $iY += 34

    $__g_CD_idChkConfigWatcher = __CD_CreateCheckbox("Config file watcher", $iX, $iY, 300, $t)
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
EndFunc

Func __CD_BuildTabColors()
    Local $t = 6, $iX = 20, $iY = 50, $i

    $__g_CD_idChkColorsEnabled = __CD_CreateCheckbox("Enable desktop colors", $iX, $iY, 300, $t)
    $iY += 30

    For $i = 1 To 9
        Local $idLbl = GUICtrlCreateLabel("Desktop " & $i & ":", $iX, $iY + 2, 80, 18)
        GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idLbl, $THEME_FG_DIM)
        GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idLbl)

        $__g_CD_aidInpColor[$i] = GUICtrlCreateInput("", $iX + 85, $iY, 80, 20)
        GUICtrlSetFont($__g_CD_aidInpColor[$i], 9, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidInpColor[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidInpColor[$i], $THEME_BG_INPUT)
        __CD_RegCtrl($t, $__g_CD_aidInpColor[$i])

        $__g_CD_aidLblPreview[$i] = GUICtrlCreateLabel("", $iX + 175, $iY + 2, 16, 16)
        __CD_RegCtrl($t, $__g_CD_aidLblPreview[$i])
        $iY += 24
    Next
EndFunc

Func __CD_BuildTabLogging()
    Local $t = 7, $iX = 20, $iY = 50

    $__g_CD_idChkLogging = __CD_CreateCheckbox("Enable logging", $iX, $iY, 300, $t)
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
    $iY += 30

    $__g_CD_idLblLogLevel = __CD_CreateCycleLabel("Log level:", $iX, $iY, 100, 90, $t)
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

    ; Colors
    __CD_SetCheckState($__g_CD_idChkColorsEnabled, _Cfg_GetDesktopColorsEnabled())
    For $i = 1 To 9
        Local $sHex = Hex(_Cfg_GetDesktopColor($i), 6)
        GUICtrlSetData($__g_CD_aidInpColor[$i], $sHex)
        GUICtrlSetBkColor($__g_CD_aidLblPreview[$i], Int("0x" & $sHex))
    Next

    ; Logging
    __CD_SetCheckState($__g_CD_idChkLogging, _Cfg_GetLoggingEnabled())
    GUICtrlSetData($__g_CD_idInpLogPath, _Cfg_GetLogFilePath())
    GUICtrlSetData($__g_CD_idLblLogLevel, _Cfg_GetLogLevel())
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
            EndSwitch

            ; Tab button clicks
            For $t = 1 To 7
                If $id = $__g_CD_aidTabBtn[$t] Then
                    __CD_SwitchTab($t)
                    ExitLoop
                EndIf
            Next

            ; Checkbox clicks (label-based, handle box + text clicks)
            __CD_HandleCheckboxClick($id)

            ; Cycle label clicks
            If $id = $__g_CD_idLblPosition Then __CD_CycleValue($id, "left|center|right")
            If $id = $__g_CD_idLblScrollDir Then __CD_CycleValue($id, "normal|inverted")
            If $id = $__g_CD_idLblListAction Then __CD_CycleValue($id, "switch|scroll")
            If $id = $__g_CD_idLblTheme Then __CD_CycleValue($id, "dark|darker|midnight")
            If $id = $__g_CD_idLblLogLevel Then __CD_CycleValue($id, "error|warn|info|debug")
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
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    Local $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnReset Then $iFgRestore = 0xCC6666
                    If $iHovered = $__g_CD_idBtnImport Or $iHovered = $__g_CD_idBtnExport Then $iFgRestore = $THEME_FG_DIM
                    If $iHovered = $__g_CD_idBtnRestart Then $iFgRestore = $THEME_FG_LINK
                    _Theme_RemoveHover($iHovered, $iFgRestore, $THEME_BG_HOVER)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        ; Tick toast fade-out while dialog is open
        _Theme_ToastTick()

        Sleep(10)
    WEnd

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

    ; Colors
    _Cfg_SetDesktopColorsEnabled(__CD_GetCheckState($__g_CD_idChkColorsEnabled))
    For $i = 1 To 9
        Local $iValidColor = _Theme_ValidateHexColor(GUICtrlRead($__g_CD_aidInpColor[$i]))
        If $iValidColor >= 0 Then
            _Cfg_SetDesktopColor($i, $iValidColor)
            GUICtrlSetBkColor($__g_CD_aidLblPreview[$i], $iValidColor)
        EndIf
    Next

    ; Logging
    _Cfg_SetLoggingEnabled(__CD_GetCheckState($__g_CD_idChkLogging))
    _Cfg_SetLogFilePath(GUICtrlRead($__g_CD_idInpLogPath))
    _Cfg_SetLogLevel(GUICtrlRead($__g_CD_idLblLogLevel))

    _Cfg_Save()

    ; Apply changes live to the running app
    _ApplySettingsLive()

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
