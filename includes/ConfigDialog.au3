#include-once
#include "Config.au3"
#include "Theme.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ComboConstants.au3>
#include <WinAPISysWin.au3>

; #INDEX# =======================================================
; Title .........: ConfigDialog
; Description ....: Dark-themed tabbed settings window with blocking loop
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_CD_hGUI = 0
Global $__g_CD_bVisible = False

; -- Tab 1: General --
Global $__g_CD_idChkStartWin, $__g_CD_idChkWrapNav, $__g_CD_idChkAutoCreate
Global $__g_CD_idInpPadding, $__g_CD_idCmbPosition, $__g_CD_idInpOffsetX

; -- Tab 2: Display --
Global $__g_CD_idChkShowCount, $__g_CD_idInpCountFont, $__g_CD_idInpOpacity

; -- Tab 3: Scroll --
Global $__g_CD_idChkScroll, $__g_CD_idCmbScrollDir, $__g_CD_idChkScrollWrap
Global $__g_CD_idChkListScroll, $__g_CD_idCmbListAction

; -- Tab 4: Hotkeys --
Global $__g_CD_idInpHkNext, $__g_CD_idInpHkPrev, $__g_CD_idInpHkToggleList
Global $__g_CD_aidInpHkDesktop[10] ; index 1-9

; -- Tab 5: Behavior --
Global $__g_CD_idChkConfirmDel, $__g_CD_idChkMidClick, $__g_CD_idChkMoveWin
Global $__g_CD_idInpPeekDelay, $__g_CD_idInpAutoHide, $__g_CD_idInpTopmost, $__g_CD_idInpCmDelay

; -- Tab 6: Colors --
Global $__g_CD_idChkColorsEnabled
Global $__g_CD_aidInpColor[10]    ; index 1-9
Global $__g_CD_aidLblPreview[10]  ; index 1-9

; -- Buttons --
Global $__g_CD_idBtnApply, $__g_CD_idBtnClose

; #FUNCTIONS# ===================================================

Func _CD_Show()
    Local $iW = 460, $iH = 420
    Local $iX = (@DesktopWidth - $iW) / 2
    Local $iY = (@DesktopHeight - $iH) / 2

    $__g_CD_hGUI = _Theme_CreatePopup("Settings", $iW, $iH, $iX, $iY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Tab control
    Local $idTab = GUICtrlCreateTab(8, 8, 444, 360)
    GUICtrlSetFont($idTab, 9, 400, 0, $THEME_FONT_MAIN)

    ; Build each tab
    __CD_CreateTabGeneral()
    __CD_CreateTabDisplay()
    __CD_CreateTabScroll()
    __CD_CreateTabHotkeys()
    __CD_CreateTabBehavior()
    __CD_CreateTabColors()

    GUICtrlCreateTabItem("") ; end tab items

    ; Apply + Close buttons at bottom, centered
    Local $iBtnW = 80, $iBtnH = 28
    Local $iBtnY = 378
    Local $iGap = 12
    Local $iTotalW = $iBtnW * 2 + $iGap
    Local $iBtnX = ($iW - $iTotalW) / 2

    $__g_CD_idBtnApply = GUICtrlCreateLabel("Apply", $iBtnX, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnApply, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnApply, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnApply, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnApply, 0)

    $__g_CD_idBtnClose = GUICtrlCreateLabel("Close", $iBtnX + $iBtnW + $iGap, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnClose, 0)

    ; Populate controls from config
    __CD_PopulateControls()

    GUISetState(@SW_SHOW, $__g_CD_hGUI)
    $__g_CD_bVisible = True

    ; Blocking message loop
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
; TAB CREATION HELPERS
; =============================================

Func __CD_CreateTabGeneral()
    GUICtrlCreateTabItem("General")

    ; Dark background panel FIRST (behind all controls)
    __CD_CreateTabBackground()

    Local $iX = 20, $iY = 40

    $__g_CD_idChkStartWin = GUICtrlCreateCheckbox("Start with Windows", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkStartWin)
    $iY += 26

    $__g_CD_idChkWrapNav = GUICtrlCreateCheckbox("Wrap navigation at ends", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkWrapNav)
    $iY += 26

    $__g_CD_idChkAutoCreate = GUICtrlCreateCheckbox("Auto-create desktop past end", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkAutoCreate)
    $iY += 32

    ; Number padding
    Local $idLbl = GUICtrlCreateLabel("Number padding (1-4):", $iX, $iY + 2, 160, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpPadding = GUICtrlCreateInput("", $iX + 165, $iY, 50, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpPadding)
    $iY += 30

    ; Widget position
    $idLbl = GUICtrlCreateLabel("Widget position:", $iX, $iY + 2, 160, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idCmbPosition = GUICtrlCreateCombo("", $iX + 165, $iY, 100, 22, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    __CD_StyleCombo($__g_CD_idCmbPosition)
    $iY += 30

    ; Widget X offset
    $idLbl = GUICtrlCreateLabel("Widget X offset (px):", $iX, $iY + 2, 160, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpOffsetX = GUICtrlCreateInput("", $iX + 165, $iY, 80, 22)
    __CD_StyleInput($__g_CD_idInpOffsetX)
EndFunc

Func __CD_CreateTabDisplay()
    GUICtrlCreateTabItem("Display")
    __CD_CreateTabBackground()
    Local $iX = 20, $iY = 40

    $__g_CD_idChkShowCount = GUICtrlCreateCheckbox("Show desktop count (2/5)", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkShowCount)
    $iY += 32

    ; Count font size
    Local $idLbl = GUICtrlCreateLabel("Count font size:", $iX, $iY + 2, 160, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpCountFont = GUICtrlCreateInput("", $iX + 165, $iY, 50, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpCountFont)
    $iY += 30

    ; Widget opacity
    $idLbl = GUICtrlCreateLabel("Widget opacity (50-255):", $iX, $iY + 2, 160, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpOpacity = GUICtrlCreateInput("", $iX + 165, $iY, 50, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpOpacity)
EndFunc

Func __CD_CreateTabScroll()
    GUICtrlCreateTabItem("Scroll")
    __CD_CreateTabBackground()
    Local $iX = 20, $iY = 40

    $__g_CD_idChkScroll = GUICtrlCreateCheckbox("Scroll wheel on widget", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkScroll)
    $iY += 26

    ; Direction
    Local $idLbl = GUICtrlCreateLabel("Direction:", $iX + 20, $iY + 2, 140, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idCmbScrollDir = GUICtrlCreateCombo("", $iX + 165, $iY, 100, 22, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    __CD_StyleCombo($__g_CD_idCmbScrollDir)
    $iY += 28

    $__g_CD_idChkScrollWrap = GUICtrlCreateCheckbox("Wrap at ends", $iX + 20, $iY, 240, 22)
    __CD_StyleCheckbox($__g_CD_idChkScrollWrap)
    $iY += 32

    $__g_CD_idChkListScroll = GUICtrlCreateCheckbox("Scroll on desktop list", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkListScroll)
    $iY += 26

    ; List action
    $idLbl = GUICtrlCreateLabel("List action:", $iX + 20, $iY + 2, 140, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idCmbListAction = GUICtrlCreateCombo("", $iX + 165, $iY, 100, 22, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    __CD_StyleCombo($__g_CD_idCmbListAction)
EndFunc

Func __CD_CreateTabHotkeys()
    GUICtrlCreateTabItem("Hotkeys")
    __CD_CreateTabBackground()
    Local $iX = 20, $iY = 40
    Local $iLblW = 100, $iInpW = 140

    ; Next / Prev
    Local $idLbl = GUICtrlCreateLabel("Next:", $iX, $iY + 2, $iLblW, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpHkNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    __CD_StyleInput($__g_CD_idInpHkNext)
    $iY += 24

    $idLbl = GUICtrlCreateLabel("Prev:", $iX, $iY + 2, $iLblW, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpHkPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    __CD_StyleInput($__g_CD_idInpHkPrev)
    $iY += 24

    ; Desktop 1-9
    For $i = 1 To 9
        $idLbl = GUICtrlCreateLabel("Desktop " & $i & ":", $iX, $iY + 2, $iLblW, 20)
        __CD_StyleLabel($idLbl)
        $__g_CD_aidInpHkDesktop[$i] = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
        __CD_StyleInput($__g_CD_aidInpHkDesktop[$i])
        $iY += 24
    Next

    ; Toggle List
    $idLbl = GUICtrlCreateLabel("Toggle List:", $iX, $iY + 2, $iLblW, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpHkToggleList = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    __CD_StyleInput($__g_CD_idInpHkToggleList)
    $iY += 28

    ; Help text
    $idLbl = GUICtrlCreateLabel("Format: ^=Ctrl  !=Alt  +=Shift  e.g. ^!{RIGHT}", $iX, $iY, 400, 16)
    __CD_StyleLabel($idLbl)
EndFunc

Func __CD_CreateTabBehavior()
    GUICtrlCreateTabItem("Behavior")
    __CD_CreateTabBackground()
    Local $iX = 20, $iY = 40

    $__g_CD_idChkConfirmDel = GUICtrlCreateCheckbox("Confirm before delete", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkConfirmDel)
    $iY += 26

    $__g_CD_idChkMidClick = GUICtrlCreateCheckbox("Middle-click to delete", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkMidClick)
    $iY += 26

    $__g_CD_idChkMoveWin = GUICtrlCreateCheckbox("Move Window Here in menu", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkMoveWin)
    $iY += 32

    ; Peek delay
    Local $idLbl = GUICtrlCreateLabel("Peek delay (ms):", $iX, $iY + 2, 170, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpPeekDelay = GUICtrlCreateInput("", $iX + 175, $iY, 80, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpPeekDelay)
    $iY += 28

    ; Auto-hide timeout
    $idLbl = GUICtrlCreateLabel("Auto-hide timeout (ms):", $iX, $iY + 2, 170, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpAutoHide = GUICtrlCreateInput("", $iX + 175, $iY, 80, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpAutoHide)
    $iY += 28

    ; Topmost interval
    $idLbl = GUICtrlCreateLabel("Topmost interval (ms):", $iX, $iY + 2, 170, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpTopmost = GUICtrlCreateInput("", $iX + 175, $iY, 80, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpTopmost)
    $iY += 28

    ; Menu hide delay
    $idLbl = GUICtrlCreateLabel("Menu hide delay (ms):", $iX, $iY + 2, 170, 20)
    __CD_StyleLabel($idLbl)
    $__g_CD_idInpCmDelay = GUICtrlCreateInput("", $iX + 175, $iY, 80, 22, $ES_NUMBER)
    __CD_StyleInput($__g_CD_idInpCmDelay)
EndFunc

Func __CD_CreateTabColors()
    GUICtrlCreateTabItem("Colors")
    __CD_CreateTabBackground()
    Local $iX = 20, $iY = 40

    $__g_CD_idChkColorsEnabled = GUICtrlCreateCheckbox("Enable desktop colors", $iX, $iY, 260, 22)
    __CD_StyleCheckbox($__g_CD_idChkColorsEnabled)
    $iY += 30

    ; Desktop 1-9 color rows
    For $i = 1 To 9
        Local $idLbl = GUICtrlCreateLabel("Desktop " & $i & ":", $iX, $iY + 2, 80, 20)
        __CD_StyleLabel($idLbl)

        $__g_CD_aidInpColor[$i] = GUICtrlCreateInput("", $iX + 85, $iY, 80, 20)
        __CD_StyleInput($__g_CD_aidInpColor[$i])

        $__g_CD_aidLblPreview[$i] = GUICtrlCreateLabel("", $iX + 175, $iY + 2, 16, 16)
        $iY += 24
    Next
EndFunc

; =============================================
; STYLING HELPERS
; =============================================

Func __CD_StyleCheckbox($idCtrl)
    GUICtrlSetFont($idCtrl, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCtrl, $THEME_FG_NORMAL)
    ; Checkboxes don't support $GUI_BKCOLOR_TRANSPARENT reliably with dark themes
    GUICtrlSetBkColor($idCtrl, $THEME_BG_POPUP)
EndFunc

Func __CD_StyleLabel($idCtrl)
    GUICtrlSetFont($idCtrl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCtrl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idCtrl, $GUI_BKCOLOR_TRANSPARENT)
EndFunc

Func __CD_StyleInput($idCtrl)
    GUICtrlSetFont($idCtrl, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCtrl, $THEME_FG_TEXT)
    GUICtrlSetBkColor($idCtrl, $THEME_BG_INPUT)
EndFunc

Func __CD_StyleCombo($idCtrl)
    GUICtrlSetFont($idCtrl, 9, 400, 0, $THEME_FONT_MAIN)
EndFunc

Func __CD_CreateTabBackground()
    Local $idBg = GUICtrlCreateLabel("", 10, 32, 440, 334)
    GUICtrlSetBkColor($idBg, $THEME_BG_POPUP)
    GUICtrlSetState($idBg, $GUI_DISABLE)
EndFunc

; =============================================
; POPULATE CONTROLS FROM CONFIG
; =============================================

Func __CD_PopulateControls()
    ; Tab 1: General
    If _Cfg_GetStartWithWindows() Then
        GUICtrlSetState($__g_CD_idChkStartWin, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkStartWin, $GUI_UNCHECKED)
    EndIf
    If _Cfg_GetWrapNavigation() Then
        GUICtrlSetState($__g_CD_idChkWrapNav, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkWrapNav, $GUI_UNCHECKED)
    EndIf
    If _Cfg_GetAutoCreateDesktop() Then
        GUICtrlSetState($__g_CD_idChkAutoCreate, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkAutoCreate, $GUI_UNCHECKED)
    EndIf
    GUICtrlSetData($__g_CD_idInpPadding, _Cfg_GetNumberPadding())
    ; Combo boxes: populate items with default selection via second parameter
    GUICtrlSetData($__g_CD_idCmbPosition, "left|center|right", _Cfg_GetWidgetPosition())
    GUICtrlSetData($__g_CD_idInpOffsetX, _Cfg_GetWidgetOffsetX())

    ; Tab 2: Display
    If _Cfg_GetShowCount() Then
        GUICtrlSetState($__g_CD_idChkShowCount, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkShowCount, $GUI_UNCHECKED)
    EndIf
    GUICtrlSetData($__g_CD_idInpCountFont, _Cfg_GetCountFontSize())
    GUICtrlSetData($__g_CD_idInpOpacity, _Cfg_GetThemeAlphaMain())

    ; Tab 3: Scroll
    If _Cfg_GetScrollEnabled() Then
        GUICtrlSetState($__g_CD_idChkScroll, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkScroll, $GUI_UNCHECKED)
    EndIf
    ; Combo boxes: populate items with default selection via second parameter
    GUICtrlSetData($__g_CD_idCmbScrollDir, "normal|inverted", _Cfg_GetScrollDirection())
    If _Cfg_GetScrollWrap() Then
        GUICtrlSetState($__g_CD_idChkScrollWrap, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkScrollWrap, $GUI_UNCHECKED)
    EndIf
    If _Cfg_GetListScrollEnabled() Then
        GUICtrlSetState($__g_CD_idChkListScroll, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkListScroll, $GUI_UNCHECKED)
    EndIf
    GUICtrlSetData($__g_CD_idCmbListAction, "switch|scroll", _Cfg_GetListScrollAction())

    ; Tab 4: Hotkeys
    GUICtrlSetData($__g_CD_idInpHkNext, _Cfg_GetHotkeyNext())
    GUICtrlSetData($__g_CD_idInpHkPrev, _Cfg_GetHotkeyPrev())
    For $i = 1 To 9
        GUICtrlSetData($__g_CD_aidInpHkDesktop[$i], _Cfg_GetHotkeyDesktop($i))
    Next
    GUICtrlSetData($__g_CD_idInpHkToggleList, _Cfg_GetHotkeyToggleList())

    ; Tab 5: Behavior
    If _Cfg_GetConfirmDelete() Then
        GUICtrlSetState($__g_CD_idChkConfirmDel, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkConfirmDel, $GUI_UNCHECKED)
    EndIf
    If _Cfg_GetMiddleClickDelete() Then
        GUICtrlSetState($__g_CD_idChkMidClick, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkMidClick, $GUI_UNCHECKED)
    EndIf
    If _Cfg_GetMoveWindowEnabled() Then
        GUICtrlSetState($__g_CD_idChkMoveWin, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkMoveWin, $GUI_UNCHECKED)
    EndIf
    GUICtrlSetData($__g_CD_idInpPeekDelay, _Cfg_GetPeekBounceDelay())
    GUICtrlSetData($__g_CD_idInpAutoHide, _Cfg_GetAutoHideTimeout())
    GUICtrlSetData($__g_CD_idInpTopmost, _Cfg_GetTopmostInterval())
    GUICtrlSetData($__g_CD_idInpCmDelay, _Cfg_GetCmAutoHideDelay())

    ; Tab 6: Colors
    If _Cfg_GetDesktopColorsEnabled() Then
        GUICtrlSetState($__g_CD_idChkColorsEnabled, $GUI_CHECKED)
    Else
        GUICtrlSetState($__g_CD_idChkColorsEnabled, $GUI_UNCHECKED)
    EndIf
    For $i = 1 To 9
        Local $sHex = Hex(_Cfg_GetDesktopColor($i), 6)
        GUICtrlSetData($__g_CD_aidInpColor[$i], $sHex)
        GUICtrlSetBkColor($__g_CD_aidLblPreview[$i], Int("0x" & $sHex))
    Next
EndFunc

; =============================================
; BLOCKING MESSAGE LOOP
; =============================================

Func __CD_MessageLoop()
    Local $iHovered = 0

    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $__g_CD_hGUI Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $__g_CD_idBtnApply
                    __CD_ApplyChanges()
                Case $__g_CD_idBtnClose
                    ExitLoop
            EndSwitch
        EndIf

        ; Keyboard: Enter = Apply, Escape = Close
        Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And BitAND($retEnter[0], 0x8000) <> 0 Then
            __CD_ApplyChanges()
            ExitLoop
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And BitAND($retEsc[0], 0x8000) <> 0 Then
            ExitLoop
        EndIf

        ; Hover effects on buttons
        Local $aCursor = GUIGetCursorInfo($__g_CD_hGUI)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $__g_CD_idBtnApply Then $iFound = $__g_CD_idBtnApply
            If $aCursor[4] = $__g_CD_idBtnClose Then $iFound = $__g_CD_idBtnClose

            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    _Theme_RemoveHover($iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then
                    _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
                EndIf
            EndIf
        EndIf

        Sleep(10)
    WEnd

    _CD_Destroy()
EndFunc

; =============================================
; APPLY CHANGES
; =============================================

Func __CD_ApplyChanges()
    ; Guard: if the dialog GUI was destroyed, bail out
    If $__g_CD_hGUI = 0 Then Return

    ; Remember previous startup state to detect changes
    Local $bOldStartup = _Cfg_GetStartWithWindows()

    ; Helper: safely read a control, returning "" on error
    ; (GUICtrlRead returns "" for invalid IDs, but we add explicit checks)

    ; Tab 1: General
    _Cfg_SetStartWithWindows(BitAND(GUICtrlRead($__g_CD_idChkStartWin), $GUI_CHECKED) = $GUI_CHECKED)
    _Cfg_SetWrapNavigation(BitAND(GUICtrlRead($__g_CD_idChkWrapNav), $GUI_CHECKED) = $GUI_CHECKED)
    _Cfg_SetAutoCreateDesktop(BitAND(GUICtrlRead($__g_CD_idChkAutoCreate), $GUI_CHECKED) = $GUI_CHECKED)

    Local $sPadding = GUICtrlRead($__g_CD_idInpPadding)
    If StringIsInt($sPadding) Then _Cfg_SetNumberPadding(Int($sPadding))

    Local $sPos = GUICtrlRead($__g_CD_idCmbPosition)
    If $sPos <> "" Then _Cfg_SetWidgetPosition($sPos)

    Local $sOffsetX = GUICtrlRead($__g_CD_idInpOffsetX)
    If $sOffsetX <> "" And StringIsInt($sOffsetX) Then _Cfg_SetWidgetOffsetX(Int($sOffsetX))

    ; Tab 2: Display
    _Cfg_SetShowCount(BitAND(GUICtrlRead($__g_CD_idChkShowCount), $GUI_CHECKED) = $GUI_CHECKED)

    Local $sCountFont = GUICtrlRead($__g_CD_idInpCountFont)
    If StringIsInt($sCountFont) Then _Cfg_SetCountFontSize(Int($sCountFont))

    Local $sOpacity = GUICtrlRead($__g_CD_idInpOpacity)
    If StringIsInt($sOpacity) Then _Cfg_SetThemeAlphaMain(Int($sOpacity))

    ; Tab 3: Scroll
    _Cfg_SetScrollEnabled(BitAND(GUICtrlRead($__g_CD_idChkScroll), $GUI_CHECKED) = $GUI_CHECKED)

    Local $sScrollDir = GUICtrlRead($__g_CD_idCmbScrollDir)
    If $sScrollDir <> "" Then _Cfg_SetScrollDirection($sScrollDir)

    _Cfg_SetScrollWrap(BitAND(GUICtrlRead($__g_CD_idChkScrollWrap), $GUI_CHECKED) = $GUI_CHECKED)
    _Cfg_SetListScrollEnabled(BitAND(GUICtrlRead($__g_CD_idChkListScroll), $GUI_CHECKED) = $GUI_CHECKED)

    Local $sListAction = GUICtrlRead($__g_CD_idCmbListAction)
    If $sListAction <> "" Then _Cfg_SetListScrollAction($sListAction)

    ; Tab 4: Hotkeys
    _Cfg_SetHotkeyNext(GUICtrlRead($__g_CD_idInpHkNext))
    _Cfg_SetHotkeyPrev(GUICtrlRead($__g_CD_idInpHkPrev))
    For $i = 1 To 9
        _Cfg_SetHotkeyDesktop($i, GUICtrlRead($__g_CD_aidInpHkDesktop[$i]))
    Next
    _Cfg_SetHotkeyToggleList(GUICtrlRead($__g_CD_idInpHkToggleList))

    ; Tab 5: Behavior
    _Cfg_SetConfirmDelete(BitAND(GUICtrlRead($__g_CD_idChkConfirmDel), $GUI_CHECKED) = $GUI_CHECKED)
    _Cfg_SetMiddleClickDelete(BitAND(GUICtrlRead($__g_CD_idChkMidClick), $GUI_CHECKED) = $GUI_CHECKED)
    _Cfg_SetMoveWindowEnabled(BitAND(GUICtrlRead($__g_CD_idChkMoveWin), $GUI_CHECKED) = $GUI_CHECKED)

    Local $sPeekDelay = GUICtrlRead($__g_CD_idInpPeekDelay)
    If StringIsInt($sPeekDelay) Then _Cfg_SetPeekBounceDelay(Int($sPeekDelay))

    Local $sAutoHide = GUICtrlRead($__g_CD_idInpAutoHide)
    If StringIsInt($sAutoHide) Then _Cfg_SetAutoHideTimeout(Int($sAutoHide))

    Local $sTopmost = GUICtrlRead($__g_CD_idInpTopmost)
    If StringIsInt($sTopmost) Then _Cfg_SetTopmostInterval(Int($sTopmost))

    Local $sCmDelay = GUICtrlRead($__g_CD_idInpCmDelay)
    If StringIsInt($sCmDelay) Then _Cfg_SetCmAutoHideDelay(Int($sCmDelay))

    ; Tab 6: Colors
    _Cfg_SetDesktopColorsEnabled(BitAND(GUICtrlRead($__g_CD_idChkColorsEnabled), $GUI_CHECKED) = $GUI_CHECKED)
    For $i = 1 To 9
        Local $sHex = GUICtrlRead($__g_CD_aidInpColor[$i])
        ; Strip leading 0x if user typed it
        If StringLeft($sHex, 2) = "0x" Or StringLeft($sHex, 2) = "0X" Then
            $sHex = StringTrimLeft($sHex, 2)
        EndIf
        ; Validate hex string
        If StringLen($sHex) = 6 And StringIsXDigit($sHex) Then
            _Cfg_SetDesktopColor($i, Int("0x" & $sHex))
            ; Update the preview swatch
            GUICtrlSetBkColor($__g_CD_aidLblPreview[$i], Int("0x" & $sHex))
        EndIf
    Next

    ; Persist to INI
    _Cfg_Save()

    ; Handle startup toggle
    Local $bNewStartup = _Cfg_GetStartWithWindows()
    If $bNewStartup <> $bOldStartup Then
        If $bNewStartup Then
            _Cfg_EnableStartup()
        Else
            _Cfg_DisableStartup()
        EndIf
    EndIf
EndFunc
