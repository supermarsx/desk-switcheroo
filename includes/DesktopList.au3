#include-once
#include "Theme.au3"
#include "Labels.au3"
#include "VirtualDesktop.au3"
#include "Peek.au3"
#include "Config.au3"

; #INDEX# =======================================================
; Title .........: DesktopList
; Description ....: Desktop list panel showing all virtual desktops with peek support
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_DL_hGUI          = 0
Global $__g_DL_bVisible      = False
Global $__g_DL_aItems[1]
Global $__g_DL_aPeekBtns[1]
Global $__g_DL_iCount        = 0
Global $__g_DL_iHovered      = 0
Global $__g_DL_iPeekHovered  = 0
Global $__g_DL_bTemp         = False
Global $__g_DL_hTempTimer    = 0

; -- Drag-and-drop reorder state --
Global $__g_DL_iDragState     = 0   ; 0=idle, 1=mousedown-pending, 2=dragging
Global $__g_DL_iDragSource    = 0   ; source row (1-based)
Global $__g_DL_iDragTarget    = 0   ; current drop target (1-based)
Global $__g_DL_iDragStartX    = 0
Global $__g_DL_iDragStartY    = 0
Global Const $__g_DL_DRAG_THRESHOLD = 5

; -- Per-item context menu state --
Global $__g_DL_hCtxGUI       = 0
Global $__g_DL_bCtxVisible   = False
Global $__g_DL_iCtxTarget    = 0
Global $__g_DL_iCtxSwitch    = 0
Global $__g_DL_iCtxRename    = 0
Global $__g_DL_iCtxPeek      = 0
Global $__g_DL_iCtxSetColor  = 0
Global $__g_DL_iCtxMoveWin   = 0
Global $__g_DL_iCtxAdd       = 0
Global $__g_DL_iCtxDelete    = 0
Global $__g_DL_iCtxHovered   = 0

; -- Color picker submenu state --
Global $__g_DL_hColorGUI = 0
Global $__g_DL_bColorVisible = False
Global $__g_DL_aColorPresetIDs[8]  ; [0]=7, [1-7]=control IDs
Global $__g_DL_iColorNoneID   = 0
Global $__g_DL_iColorCustomID = 0
Global $__g_DL_iColorTarget = 0

; #FUNCTIONS# ===================================================

; Name:        _DL_ShowTemp
; Description: Shows the desktop list in temporary auto-hide mode (3 seconds)
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_ShowTemp($iTaskbarY, $iCurrentDesktop)
    If $__g_DL_bVisible Then
        If $__g_DL_bTemp Then $__g_DL_hTempTimer = TimerInit()
        Return
    EndIf
    _DL_Show($iTaskbarY, $iCurrentDesktop)
    $__g_DL_bTemp = True
    $__g_DL_hTempTimer = TimerInit()
EndFunc

; Name:        _DL_Toggle
; Description: Toggles the desktop list (persistent mode, no auto-hide)
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_Toggle($iTaskbarY, $iCurrentDesktop)
    $__g_DL_bTemp = False
    If $__g_DL_bVisible Then
        _DL_Destroy()
    Else
        _DL_Show($iTaskbarY, $iCurrentDesktop)
    EndIf
EndFunc

; Name:        _DL_Show
; Description: Creates and shows the desktop list GUI
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_Show($iTaskbarY, $iCurrentDesktop)
    Local $iCount = _VD_GetCount()
    If $iCount < 1 Then $iCount = 1

    Local $iListW = $THEME_MAIN_WIDTH + $THEME_PEEK_ZONE_W
    Local $iListH = $iCount * $THEME_ITEM_HEIGHT + 6
    Local $iListY = $iTaskbarY + 2 - $iListH - 2

    $__g_DL_hGUI = _Theme_CreatePopup("DesktopList", $iListW, $iListH, 0, $iListY)

    ReDim $__g_DL_aItems[$iCount + 1]
    ReDim $__g_DL_aPeekBtns[$iCount + 1]
    $__g_DL_aItems[0] = $iCount
    $__g_DL_aPeekBtns[0] = $iCount
    $__g_DL_iHovered = 0
    $__g_DL_iPeekHovered = 0

    Local $i
    For $i = 1 To $iCount
        Local $sName = _Labels_Load($i)
        Local $iPad = _Cfg_GetNumberPadding()
        Local $sNum = String($i)
        While StringLen($sNum) < $iPad
            $sNum = "0" & $sNum
        WEnd
        Local $sText = " " & $sNum
        If $sName <> "" Then $sText &= "  " & $sName
        Local $iY = 3 + ($i - 1) * $THEME_ITEM_HEIGHT
        Local $iBold = 400
        Local $iColor = $THEME_FG_DIM
        Local $iBg = $GUI_BKCOLOR_TRANSPARENT
        If $i = $iCurrentDesktop Then
            $iBold = 700
            $iColor = $THEME_FG_WHITE
            $iBg = $THEME_BG_ACTIVE
        EndIf

        ; Peek zone icon
        $__g_DL_aPeekBtns[$i] = GUICtrlCreateLabel(ChrW(0x25C9), 4, $iY, $THEME_PEEK_ZONE_W, $THEME_ITEM_HEIGHT - 2, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_aPeekBtns[$i], 7, 400, 0, $THEME_FONT_SYMBOL)
        GUICtrlSetColor($__g_DL_aPeekBtns[$i], $THEME_FG_PEEK_DIM)
        GUICtrlSetBkColor($__g_DL_aPeekBtns[$i], $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_DL_aPeekBtns[$i], 0)

        ; Text label
        $__g_DL_aItems[$i] = GUICtrlCreateLabel($sText, 4 + $THEME_PEEK_ZONE_W, $iY, $iListW - 8 - $THEME_PEEK_ZONE_W, $THEME_ITEM_HEIGHT - 2, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_aItems[$i], 8, $iBold, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_DL_aItems[$i], $iColor)
        GUICtrlSetBkColor($__g_DL_aItems[$i], $iBg)
        GUICtrlSetCursor($__g_DL_aItems[$i], 0)

        ; Desktop color indicator (skip if colors disabled or color is 0/none)
        If _Cfg_GetDesktopColorsEnabled() And $i <= 9 Then
            Local $iClr = _Cfg_GetDesktopColor($i)
            If $iClr <> 0 Then
                Local $iColorInd = GUICtrlCreateLabel("", $iListW - 8, $iY + 2, 4, $THEME_ITEM_HEIGHT - 6)
                GUICtrlSetBkColor($iColorInd, $iClr)
            EndIf
        EndIf
    Next

    GUISetState(@SW_SHOW, $__g_DL_hGUI)
    $__g_DL_bVisible = True
    $__g_DL_iCount = $iCount
EndFunc

; Name:        _DL_Destroy
; Description: Destroys the list GUI and ends any active peek
Func _DL_Destroy()
    _DL_DragReset()
    _DL_CtxDestroy()
    _Peek_End()
    If $__g_DL_hGUI <> 0 Then
        GUIDelete($__g_DL_hGUI)
        $__g_DL_hGUI = 0
    EndIf
    $__g_DL_bVisible = False
    $__g_DL_iHovered = 0
    $__g_DL_iPeekHovered = 0
    $__g_DL_iCount = 0
EndFunc

; Name:        _DL_HandleClick
; Description: Processes a click on a list item or peek button
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      Target desktop index (1-based), or 0 if no match
Func _DL_HandleClick($msg)
    If $__g_DL_iDragState > 0 Then Return 0
    If $msg <= 0 Then Return 0
    If UBound($__g_DL_aItems) < 2 Or $__g_DL_aItems[0] < 1 Then Return 0
    Local $i
    For $i = 1 To $__g_DL_aItems[0]
        If $msg = $__g_DL_aItems[$i] Or $msg = $__g_DL_aPeekBtns[$i] Then
            If _Peek_IsActive() Then
                _Peek_Commit()
            EndIf
            Return $i
        EndIf
    Next
    Return 0
EndFunc

; Name:        _DL_CheckHover
; Description: Manages hover highlighting and peek triggering on the list. Call from main loop.
; Parameters:  $iCurrentDesktop - currently active desktop (1-based)
Func _DL_CheckHover($iCurrentDesktop)
    If Not $__g_DL_bVisible Or $__g_DL_hGUI = 0 Then Return
    If $__g_DL_iDragState = 2 Then Return ; drag controls visuals during active drag
    If UBound($__g_DL_aItems) < 2 Or $__g_DL_aItems[0] < 1 Then Return
    Local $aCursor = GUIGetCursorInfo($__g_DL_hGUI)
    If @error Then
        ; Cursor left the list
        If $__g_DL_iHovered > 0 And $__g_DL_iHovered <= $__g_DL_aItems[0] And $__g_DL_iHovered <> $iCurrentDesktop Then
            _Theme_RemoveHover($__g_DL_aItems[$__g_DL_iHovered], $THEME_FG_DIM)
        EndIf
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <= $__g_DL_aPeekBtns[0] Then
            GUICtrlSetColor($__g_DL_aPeekBtns[$__g_DL_iPeekHovered], $THEME_FG_PEEK_DIM)
            $__g_DL_iPeekHovered = 0
        EndIf
        $__g_DL_iHovered = 0
        _Peek_StartBounceBack()
        Return
    EndIf

    ; Find hovered text item
    Local $iFound = 0
    Local $i
    For $i = 1 To $__g_DL_aItems[0]
        If $aCursor[4] = $__g_DL_aItems[$i] Then
            $iFound = $i
            ExitLoop
        EndIf
    Next

    ; Find hovered peek button
    Local $iPeekFound = 0
    For $i = 1 To $__g_DL_aPeekBtns[0]
        If $aCursor[4] = $__g_DL_aPeekBtns[$i] Then
            $iPeekFound = $i
            ExitLoop
        EndIf
    Next

    ; Treat peek zone as part of same row for text highlighting
    Local $iEffective = $iFound
    If $iEffective = 0 Then $iEffective = $iPeekFound

    ; Update text hover highlight
    If $iEffective <> $__g_DL_iHovered Then
        If $__g_DL_iHovered > 0 And $__g_DL_iHovered <= $__g_DL_aItems[0] And $__g_DL_iHovered <> $iCurrentDesktop Then
            _Theme_RemoveHover($__g_DL_aItems[$__g_DL_iHovered], $THEME_FG_DIM)
        EndIf
        $__g_DL_iHovered = $iEffective
        If $__g_DL_iHovered > 0 And $__g_DL_iHovered <= $__g_DL_aItems[0] And $__g_DL_iHovered <> $iCurrentDesktop Then
            _Theme_ApplyHover($__g_DL_aItems[$__g_DL_iHovered], $THEME_FG_WHITE, $THEME_BG_HOVER)
        EndIf
    EndIf

    ; Update peek button hover + trigger peek
    If $iPeekFound <> $__g_DL_iPeekHovered Then
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <= $__g_DL_aPeekBtns[0] Then
            GUICtrlSetColor($__g_DL_aPeekBtns[$__g_DL_iPeekHovered], $THEME_FG_PEEK_DIM)
        EndIf
        $__g_DL_iPeekHovered = $iPeekFound
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <= $__g_DL_aPeekBtns[0] Then
            GUICtrlSetColor($__g_DL_aPeekBtns[$__g_DL_iPeekHovered], $THEME_FG_WHITE)
        EndIf

        ; Peek logic
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <> $iCurrentDesktop Then
            _Peek_Start($__g_DL_iPeekHovered)
        Else
            _Peek_StartBounceBack()
        EndIf
    EndIf
EndFunc

; Name:        _DL_UpdateHighlight
; Description: Updates the active desktop highlight in the list
; Parameters:  $iCurrentDesktop - currently active desktop (1-based)
Func _DL_UpdateHighlight($iCurrentDesktop)
    If Not $__g_DL_bVisible Then Return
    If UBound($__g_DL_aItems) < 2 Or $__g_DL_aItems[0] < 1 Then Return
    Local $i
    For $i = 1 To $__g_DL_aItems[0]
        If $i = $__g_DL_iHovered And $i <> $iCurrentDesktop Then ContinueLoop
        If $i = $iCurrentDesktop Then
            GUICtrlSetFont($__g_DL_aItems[$i], 8, 700, 0, $THEME_FONT_MONO)
            GUICtrlSetColor($__g_DL_aItems[$i], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_DL_aItems[$i], $THEME_BG_ACTIVE)
        Else
            GUICtrlSetFont($__g_DL_aItems[$i], 8, 400, 0, $THEME_FONT_MONO)
            GUICtrlSetColor($__g_DL_aItems[$i], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_DL_aItems[$i], $GUI_BKCOLOR_TRANSPARENT)
        EndIf
    Next
EndFunc

; Name:        _DL_CheckAutoHide
; Description: Checks if the temp list should auto-hide (3s timeout, cursor not over list or main)
; Parameters:  $hMainGUI - handle to the main widget GUI
; Return:      True if the list was auto-hidden, False otherwise
Func _DL_CheckAutoHide($hMainGUI)
    If Not $__g_DL_bTemp Or Not $__g_DL_bVisible Then Return False
    If $__g_DL_bCtxVisible Then Return False ; don't auto-hide while context menu is open
    If $__g_DL_bColorVisible Then Return False ; don't auto-hide while color picker is open
    If $__g_DL_iDragState > 0 Then Return False ; don't auto-hide during drag
    If TimerDiff($__g_DL_hTempTimer) <= _Cfg_GetAutoHideTimeout() Then Return False
    If _Theme_IsCursorOverWindow($__g_DL_hGUI) Or _Theme_IsCursorOverWindow($hMainGUI) Then Return False
    _DL_Destroy()
    $__g_DL_bTemp = False
    Return True
EndFunc

; Name:        _DL_Refresh
; Description: Rebuilds the list if desktop count changed, otherwise updates highlight
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_Refresh($iTaskbarY, $iCurrentDesktop)
    If Not $__g_DL_bVisible Then Return
    Local $iCount = _VD_GetCount()
    If $iCount <> $__g_DL_iCount Then
        _DL_Destroy()
        _DL_Show($iTaskbarY, $iCurrentDesktop)
    Else
        _DL_UpdateHighlight($iCurrentDesktop)
    EndIf
EndFunc

; Name:        _DL_UpdateItemText
; Description: Updates the display text of a single list item (e.g., after rename)
; Parameters:  $iIndex - desktop index (1-based)
;              $sLabel - new label text
Func _DL_UpdateItemText($iIndex, $sLabel)
    If Not $__g_DL_bVisible Then Return
    If $iIndex < 1 Or $iIndex > $__g_DL_aItems[0] Then Return
    Local $iPad = _Cfg_GetNumberPadding()
    Local $sNum = String($iIndex)
    While StringLen($sNum) < $iPad
        $sNum = "0" & $sNum
    WEnd
    Local $sText = " " & $sNum
    If $sLabel <> "" Then $sText &= "  " & $sLabel
    GUICtrlSetData($__g_DL_aItems[$iIndex], $sText)
EndFunc

; Name:        _DL_IsVisible
; Description: Returns whether the desktop list is currently visible
; Return:      True/False
Func _DL_IsVisible()
    Return $__g_DL_bVisible
EndFunc

; Name:        _DL_GetGUI
; Description: Returns the desktop list GUI handle
; Return:      GUI handle or 0
Func _DL_GetGUI()
    Return $__g_DL_hGUI
EndFunc

; Name:        _DL_GetCount
; Description: Returns the desktop count at time of list creation
; Return:      Integer
Func _DL_GetCount()
    Return $__g_DL_iCount
EndFunc

; =============================================
; DESKTOP LIST — DRAG-AND-DROP REORDER
; =============================================

; Name:        _DL_IsDragging
; Description: Returns whether a drag operation is in progress
; Return:      True if drag state > 0
Func _DL_IsDragging()
    Return ($__g_DL_iDragState > 0)
EndFunc

; Name:        _DL_DragMouseDown
; Description: Called when LMB is pressed over the desktop list. Enters pending state.
Func _DL_DragMouseDown()
    If $__g_DL_iDragState <> 0 Then Return
    If $__g_DL_iCount <= 1 Then Return
    Local $iRow = _DL_GetItemAtPos()
    If $iRow <= 0 Then Return
    $__g_DL_iDragState = 1
    $__g_DL_iDragSource = $iRow
    $__g_DL_iDragTarget = 0
    Local $aMP = MouseGetPos()
    $__g_DL_iDragStartX = $aMP[0]
    $__g_DL_iDragStartY = $aMP[1]
EndFunc

; Name:        _DL_DragMouseMove
; Description: Called each frame while LMB is held and drag state > 0.
;              Transitions from pending to dragging when threshold is met,
;              and updates the drop target highlight while dragging.
Func _DL_DragMouseMove()
    Local $aMP = MouseGetPos()

    If $__g_DL_iDragState = 1 Then
        ; Check threshold
        Local $iDX = Abs($aMP[0] - $__g_DL_iDragStartX)
        Local $iDY = Abs($aMP[1] - $__g_DL_iDragStartY)
        If $iDX < $__g_DL_DRAG_THRESHOLD And $iDY < $__g_DL_DRAG_THRESHOLD Then Return
        ; Activate drag
        $__g_DL_iDragState = 2
        _Peek_End()
        _DL_CtxDestroy()
        ; Dim source row
        If $__g_DL_iDragSource >= 1 And $__g_DL_iDragSource <= $__g_DL_iCount Then
            GUICtrlSetColor($__g_DL_aItems[$__g_DL_iDragSource], $THEME_FG_DRAG_DIM)
            GUICtrlSetBkColor($__g_DL_aItems[$__g_DL_iDragSource], $GUI_BKCOLOR_TRANSPARENT)
        EndIf
    EndIf

    If $__g_DL_iDragState = 2 Then
        ; Update drop target
        Local $iRow = _DL_GetItemAtPos()
        If $iRow = $__g_DL_iDragTarget Then Return ; no change

        ; Remove old target highlight
        If $__g_DL_iDragTarget > 0 And $__g_DL_iDragTarget <= $__g_DL_iCount And $__g_DL_iDragTarget <> $__g_DL_iDragSource Then
            GUICtrlSetColor($__g_DL_aItems[$__g_DL_iDragTarget], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_DL_aItems[$__g_DL_iDragTarget], $GUI_BKCOLOR_TRANSPARENT)
        EndIf

        $__g_DL_iDragTarget = $iRow

        ; Apply new target highlight
        If $__g_DL_iDragTarget > 0 And $__g_DL_iDragTarget <= $__g_DL_iCount And $__g_DL_iDragTarget <> $__g_DL_iDragSource Then
            GUICtrlSetColor($__g_DL_aItems[$__g_DL_iDragTarget], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_DL_aItems[$__g_DL_iDragTarget], $THEME_BG_DROP_TARGET)
        EndIf
    EndIf
EndFunc

; Name:        _DL_DragMouseUp
; Description: Called when LMB is released during a drag operation.
;              If still pending (threshold not met), returns the source as a normal click target.
;              If dragging, performs reorder and rebuilds the list.
; Parameters:  $iCurrentDesktop - currently active desktop (1-based)
;              $iTaskbarY - taskbar Y position for list rebuild
; Return:      New position of current desktop (for _VD_GoTo), or 0 for no-op / normal click
Func _DL_DragMouseUp($iCurrentDesktop, $iTaskbarY)
    Local $iState = $__g_DL_iDragState
    Local $iSource = $__g_DL_iDragSource
    Local $iTarget = $__g_DL_iDragTarget

    If $iState = 1 Then
        ; Threshold not met — treat as normal click
        _DL_DragReset()
        Return 0
    EndIf

    If $iState = 2 Then
        If $iTarget <= 0 Or $iTarget = $iSource Then
            ; Dropped outside or on same position — cancel
            _DL_DragCancel($iCurrentDesktop)
            Return 0
        EndIf
        ; Perform reorder
        Local $iNewCurrent = _DL_DragPerformReorder($iSource, $iTarget, $iCurrentDesktop)
        _DL_DragReset()
        ; Rebuild list
        _DL_Destroy()
        _DL_Show($iTaskbarY, $iNewCurrent)
        Return $iNewCurrent
    EndIf

    _DL_DragReset()
    Return 0
EndFunc

; Name:        _DL_DragCancel
; Description: Cancels an active drag and restores all visuals
; Parameters:  $iCurrentDesktop - currently active desktop for highlight restore
Func _DL_DragCancel($iCurrentDesktop)
    _DL_DragReset()
    _DL_UpdateHighlight($iCurrentDesktop)
EndFunc

; Name:        _DL_DragReset
; Description: Resets all drag state variables to idle
Func _DL_DragReset()
    $__g_DL_iDragState = 0
    $__g_DL_iDragSource = 0
    $__g_DL_iDragTarget = 0
    $__g_DL_iDragStartX = 0
    $__g_DL_iDragStartY = 0
EndFunc

; Name:        _DL_DragPerformReorder
; Description: Executes the adjacent-swap chain to move a desktop from one position
;              to another. Swaps windows and labels for each pair.
; Parameters:  $iFrom - source position (1-based)
;              $iTo - target position (1-based)
;              $iCurrentDesktop - current desktop before reorder
; Return:      New position of current desktop after reorder
Func _DL_DragPerformReorder($iFrom, $iTo, $iCurrentDesktop)
    If $iFrom = $iTo Then Return $iCurrentDesktop

    Local $iStep = 1
    If $iFrom > $iTo Then $iStep = -1

    ; Adjacent swap chain
    Local $iPos = $iFrom
    While $iPos <> $iTo
        Local $iNext = $iPos + $iStep
        ; Swap windows
        _VD_SwapDesktops($iPos, $iNext)
        ; Swap labels
        Local $sLabelA = _Labels_Load($iPos)
        Local $sLabelB = _Labels_Load($iNext)
        _Labels_Save($iPos, $sLabelB)
        _Labels_Save($iNext, $sLabelA)
        $iPos = $iNext
    WEnd

    ; Compute where the current desktop ended up
    If $iCurrentDesktop = $iFrom Then
        Return $iTo
    ElseIf $iFrom < $iTo And $iCurrentDesktop > $iFrom And $iCurrentDesktop <= $iTo Then
        Return $iCurrentDesktop - 1
    ElseIf $iFrom > $iTo And $iCurrentDesktop >= $iTo And $iCurrentDesktop < $iFrom Then
        Return $iCurrentDesktop + 1
    EndIf
    Return $iCurrentDesktop
EndFunc

; =============================================
; DESKTOP LIST — PER-ITEM CONTEXT MENU
; =============================================

; Name:        _DL_GetItemAtPos
; Description: Returns which desktop row the mouse cursor is over in the list
; Return:      Desktop index (1-based), or 0 if none
Func _DL_GetItemAtPos()
    If Not $__g_DL_bVisible Or $__g_DL_hGUI = 0 Then Return 0
    Local $aMP = MouseGetPos()
    Local $aWP = WinGetPos($__g_DL_hGUI)
    If @error Then Return 0
    If $aMP[0] < $aWP[0] Or $aMP[0] >= $aWP[0] + $aWP[2] Then Return 0
    If $aMP[1] < $aWP[1] Or $aMP[1] >= $aWP[1] + $aWP[3] Then Return 0
    ; Items start at Y=3 within the list, each $THEME_ITEM_HEIGHT tall
    Local $iRelY = $aMP[1] - $aWP[1] - 3
    If $iRelY < 0 Then Return 0
    Local $iRow = Int($iRelY / $THEME_ITEM_HEIGHT) + 1
    If $iRow < 1 Or $iRow > $__g_DL_iCount Then Return 0
    Return $iRow
EndFunc

; Name:        _DL_CtxShow
; Description: Creates and shows a right-click context menu for a desktop list item
; Parameters:  $iTarget - desktop index the menu targets (1-based)
Func _DL_CtxShow($iTarget)
    If $__g_DL_bCtxVisible Then _DL_CtxDestroy()
    $__g_DL_iCtxTarget = $iTarget

    Local $iMenuW = 150
    Local $iSepH = 1
    Local $iItemCount = 5
    If _Cfg_GetDesktopColorsEnabled() Then $iItemCount += 1
    If _Cfg_GetMoveWindowEnabled() Then $iItemCount += 1
    Local $iMenuH = $iItemCount * $THEME_MENU_ITEM_H + $iSepH + 12

    Local $aMP = MouseGetPos()
    Local $iMenuX = $aMP[0]
    Local $iMenuY = $aMP[1] - $iMenuH
    ; Keep menu on screen
    If $iMenuY < 0 Then $iMenuY = $aMP[1]

    $__g_DL_hCtxGUI = _Theme_CreatePopup("DLCtx", $iMenuW, $iMenuH, $iMenuX, $iMenuY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)

    Local $iY = 4

    $__g_DL_iCtxSwitch = _Theme_CreateMenuItem("  Switch", 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_DL_iCtxRename = _Theme_CreateMenuItem("  Rename", 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_DL_iCtxPeek = _Theme_CreateMenuItem("  Peek", 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_DL_iCtxSetColor = _Theme_CreateMenuItem("  Set Color  " & ChrW(0x25B6), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    If _Cfg_GetMoveWindowEnabled() Then
        $__g_DL_iCtxMoveWin = _Theme_CreateMenuItem("  Move Window Here", 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    $__g_DL_iCtxAdd = _Theme_CreateMenuItem("  Add Desktop", 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    ; Separator
    GUICtrlCreateLabel("", 8, $iY + 2, $iMenuW - 16, $iSepH)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += $iSepH + 4

    $__g_DL_iCtxDelete = _Theme_CreateMenuItem("  Delete", 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    GUICtrlSetColor($__g_DL_iCtxDelete, 0xCC6666) ; muted red for danger

    GUISetState(@SW_SHOW, $__g_DL_hCtxGUI)
    $__g_DL_bCtxVisible = True
    $__g_DL_iCtxHovered = 0
EndFunc

; Name:        _DL_CtxDestroy
; Description: Destroys the desktop list context menu and resets state
Func _DL_CtxDestroy()
    _DL_ColorPickerDestroy()
    If $__g_DL_hCtxGUI <> 0 Then
        GUIDelete($__g_DL_hCtxGUI)
        $__g_DL_hCtxGUI = 0
    EndIf
    $__g_DL_bCtxVisible = False
    $__g_DL_iCtxTarget = 0
    $__g_DL_iCtxSwitch = 0
    $__g_DL_iCtxRename = 0
    $__g_DL_iCtxSetColor = 0
    $__g_DL_iCtxMoveWin = 0
    $__g_DL_iCtxAdd = 0
    $__g_DL_iCtxPeek = 0
    $__g_DL_iCtxDelete = 0
    $__g_DL_iCtxHovered = 0
EndFunc

; Name:        _DL_CtxHandleClick
; Description: Processes a click on a desktop list context menu item
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      "switch", "rename", "peek", "delete", or "" if no match
Func _DL_CtxHandleClick($msg)
    If $msg = $__g_DL_iCtxSwitch Then Return "switch"
    If $msg = $__g_DL_iCtxRename Then Return "rename"
    If $msg = $__g_DL_iCtxPeek Then Return "peek"
    If $__g_DL_iCtxSetColor <> 0 And $msg = $__g_DL_iCtxSetColor Then Return "set_color"
    If $__g_DL_iCtxMoveWin <> 0 And $msg = $__g_DL_iCtxMoveWin Then Return "move_window"
    If $msg = $__g_DL_iCtxAdd Then Return "add"
    If $msg = $__g_DL_iCtxDelete Then Return "delete"
    Return ""
EndFunc

; Name:        _DL_CtxCheckHover
; Description: Updates hover highlighting on the desktop list context menu. Call from main loop.
Func _DL_CtxCheckHover()
    If Not $__g_DL_bCtxVisible Or $__g_DL_hCtxGUI = 0 Then Return
    Local $aCursor = GUIGetCursorInfo($__g_DL_hCtxGUI)
    If @error Then
        If $__g_DL_iCtxHovered <> 0 Then
            Local $iFg = $THEME_FG_MENU
            If $__g_DL_iCtxHovered = $__g_DL_iCtxDelete Then $iFg = 0xCC6666
            _Theme_RemoveHover($__g_DL_iCtxHovered, $iFg)
            $__g_DL_iCtxHovered = 0
        EndIf
        Return
    EndIf

    Local $iFound = 0
    If $aCursor[4] = $__g_DL_iCtxSwitch Then $iFound = $__g_DL_iCtxSwitch
    If $aCursor[4] = $__g_DL_iCtxRename Then $iFound = $__g_DL_iCtxRename
    If $aCursor[4] = $__g_DL_iCtxPeek Then $iFound = $__g_DL_iCtxPeek
    If $__g_DL_iCtxSetColor <> 0 And $aCursor[4] = $__g_DL_iCtxSetColor Then $iFound = $__g_DL_iCtxSetColor
    If $__g_DL_iCtxMoveWin <> 0 And $aCursor[4] = $__g_DL_iCtxMoveWin Then $iFound = $__g_DL_iCtxMoveWin
    If $aCursor[4] = $__g_DL_iCtxAdd Then $iFound = $__g_DL_iCtxAdd
    If $aCursor[4] = $__g_DL_iCtxDelete Then $iFound = $__g_DL_iCtxDelete

    If $iFound = $__g_DL_iCtxHovered Then Return

    If $__g_DL_iCtxHovered <> 0 Then
        Local $iFgOld = $THEME_FG_MENU
        If $__g_DL_iCtxHovered = $__g_DL_iCtxDelete Then $iFgOld = 0xCC6666
        _Theme_RemoveHover($__g_DL_iCtxHovered, $iFgOld)
    EndIf

    $__g_DL_iCtxHovered = $iFound
    If $__g_DL_iCtxHovered <> 0 Then
        _Theme_ApplyHover($__g_DL_iCtxHovered, $THEME_FG_WHITE, $THEME_BG_HOVER)
    EndIf
EndFunc

; Name:        _DL_CtxCheckAutoHide
; Description: Auto-dismisses the context menu when cursor moves away
; Return:      True if dismissed, False otherwise
Func _DL_CtxCheckAutoHide()
    If Not $__g_DL_bCtxVisible Or $__g_DL_hCtxGUI = 0 Then Return False
    If _Theme_IsCursorOverWindow($__g_DL_hCtxGUI) Then Return False
    If _Theme_IsCursorOverWindow($__g_DL_hGUI) Then Return False
    If $__g_DL_bColorVisible And _Theme_IsCursorOverWindow($__g_DL_hColorGUI) Then Return False
    _DL_CtxDestroy()
    Return True
EndFunc

; Name:        _DL_CtxIsVisible
; Description: Returns whether the desktop list context menu is visible
; Return:      True/False
Func _DL_CtxIsVisible()
    Return $__g_DL_bCtxVisible
EndFunc

; Name:        _DL_CtxGetGUI
; Description: Returns the desktop list context menu GUI handle
; Return:      GUI handle or 0
Func _DL_CtxGetGUI()
    Return $__g_DL_hCtxGUI
EndFunc

; Name:        _DL_CtxGetTarget
; Description: Returns the desktop index targeted by the context menu
; Return:      Desktop index (1-based), or 0 if no menu
Func _DL_CtxGetTarget()
    Return $__g_DL_iCtxTarget
EndFunc

; =============================================
; DESKTOP LIST — COLOR PICKER SUBMENU
; =============================================

; Name:        _DL_ColorPickerShow
; Description: Creates a color picker popup to the right of the context menu
; Parameters:  $iTarget - desktop index (1-based) to set color for
Func _DL_ColorPickerShow($iTarget)
    If $__g_DL_bColorVisible Then _DL_ColorPickerDestroy()
    $__g_DL_iColorTarget = $iTarget

    Local $iPickerW = 130
    Local $iPickerH = 280

    ; Position to the right of the context menu
    Local $aCtxPos = WinGetPos($__g_DL_hCtxGUI)
    Local $iPickerX = $aCtxPos[0] + $aCtxPos[2]
    Local $iPickerY = $aCtxPos[1]
    ; Keep on screen
    If $iPickerX + $iPickerW > @DesktopWidth Then $iPickerX = $aCtxPos[0] - $iPickerW
    If $iPickerY + $iPickerH > @DesktopHeight Then $iPickerY = @DesktopHeight - $iPickerH

    $__g_DL_hColorGUI = _Theme_CreatePopup("ColorPicker", $iPickerW, $iPickerH, $iPickerX, $iPickerY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)

    Local $iY = 6

    ; "None" option at the top (clear color)
    $__g_DL_iColorNoneID = GUICtrlCreateLabel("  None", 6, $iY, $iPickerW - 12, 24, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_DL_iColorNoneID, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_DL_iColorNoneID, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_DL_iColorNoneID, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($__g_DL_iColorNoneID, 0)
    $iY += 26

    ; Separator
    GUICtrlCreateLabel("", 10, $iY, $iPickerW - 20, 1)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += 5

    ; 7 preset colors with names
    Local $aColorNames[8] = [7, "Blue", "Green", "Orange", "Yellow", "Purple", "Pink", "Teal"]
    $__g_DL_aColorPresetIDs[0] = 7
    Local $i
    For $i = 1 To 7
        Local $iColor = $THEME_PRESET_COLORS[$i]
        $__g_DL_aColorPresetIDs[$i] = GUICtrlCreateLabel("  " & ChrW(0x25CF) & "  " & $aColorNames[$i], 6, $iY, $iPickerW - 12, 24, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_aColorPresetIDs[$i], 9, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_DL_aColorPresetIDs[$i], $iColor)
        GUICtrlSetBkColor($__g_DL_aColorPresetIDs[$i], $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_DL_aColorPresetIDs[$i], 0)
        $iY += 26
    Next

    ; Separator
    GUICtrlCreateLabel("", 10, $iY, $iPickerW - 20, 1)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += 5

    ; Custom... text row
    $__g_DL_iColorCustomID = GUICtrlCreateLabel("  Custom...", 6, $iY, $iPickerW - 12, 24, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_DL_iColorCustomID, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_DL_iColorCustomID, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_DL_iColorCustomID, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($__g_DL_iColorCustomID, 0)

    GUISetState(@SW_SHOW, $__g_DL_hColorGUI)
    $__g_DL_bColorVisible = True
EndFunc

; Name:        _DL_ColorPickerDestroy
; Description: Destroys the color picker popup
Func _DL_ColorPickerDestroy()
    If $__g_DL_hColorGUI <> 0 Then
        GUIDelete($__g_DL_hColorGUI)
        $__g_DL_hColorGUI = 0
    EndIf
    $__g_DL_bColorVisible = False
    $__g_DL_iColorTarget = 0
    $__g_DL_iColorNoneID = 0
    $__g_DL_iColorCustomID = 0
    For $i = 1 To 7
        $__g_DL_aColorPresetIDs[$i] = 0
    Next
EndFunc

; Name:        _DL_ColorPickerHandleClick
; Description: Processes a click in the color picker popup
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      Color value (int) if preset clicked, "custom" if Custom clicked, "" if no match
Func _DL_ColorPickerHandleClick($msg)
    If $msg <= 0 Then Return ""
    If $msg = $__g_DL_iColorNoneID Then Return "none"
    For $i = 1 To 7
        If $msg = $__g_DL_aColorPresetIDs[$i] Then Return $THEME_PRESET_COLORS[$i]
    Next
    If $msg = $__g_DL_iColorCustomID Then Return "custom"
    Return ""
EndFunc

; Name:        _DL_ColorPickerIsVisible
; Description: Returns whether the color picker is currently visible
; Return:      True/False
Func _DL_ColorPickerIsVisible()
    Return $__g_DL_bColorVisible
EndFunc

; Name:        _DL_ColorPickerGetGUI
; Description: Returns the color picker GUI handle
; Return:      GUI handle or 0
Func _DL_ColorPickerGetGUI()
    Return $__g_DL_hColorGUI
EndFunc

; Name:        _DL_ColorPickerGetTarget
; Description: Returns the desktop index targeted by the color picker
; Return:      Desktop index (1-based)
Func _DL_ColorPickerGetTarget()
    Return $__g_DL_iColorTarget
EndFunc

; Name:        _DL_ColorPickerCustomDialog
; Description: Shows a blocking dialog with a hex color input and OK/Cancel buttons
; Return:      Color value (int) or -1 if cancelled
Func _DL_ColorPickerCustomDialog()
    Local $iDlgW = 200, $iDlgH = 80
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("CustomColor", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Hex label
    GUICtrlCreateLabel("Hex color:", 10, 8, 60, 20, $SS_CENTERIMAGE)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Input field
    Local $idInput = GUICtrlCreateInput("FF0000", 74, 8, 110, 20)
    GUICtrlSetFont($idInput, 9, 400, 0, $THEME_FONT_MONO)

    ; OK button
    Local $iBtnW = 50, $iBtnH = 24
    Local $idOK = GUICtrlCreateLabel("OK", 10, $iDlgH - 34, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idOK, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idOK, $THEME_FG_MENU)
    GUICtrlSetBkColor($idOK, $THEME_BG_HOVER)
    GUICtrlSetCursor($idOK, 0)

    ; Cancel button
    Local $idCancel = GUICtrlCreateLabel("Cancel", 10 + $iBtnW + 10, $iDlgH - 34, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCancel, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCancel, $THEME_FG_MENU)
    GUICtrlSetBkColor($idCancel, $THEME_BG_HOVER)
    GUICtrlSetCursor($idCancel, 0)

    GUISetState(@SW_SHOW, $hDlg)

    ; Blocking message loop
    Local $iResult = -1
    Local $iHovered = 0
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idOK
                    Local $iValidated = _Theme_ValidateHexColor(GUICtrlRead($idInput))
                    If $iValidated >= 0 Then $iResult = $iValidated
                    ExitLoop
                Case $idCancel
                    ExitLoop
            EndSwitch
        EndIf

        ; Keyboard: Enter = OK, Escape = Cancel
        Local Const $VK_RETURN = 0x0D
        Local Const $VK_ESCAPE = 0x1B
        Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_RETURN)
        If Not @error And BitAND($retEnter[0], 0x8000) <> 0 Then
            Local $iValidated2 = _Theme_ValidateHexColor(GUICtrlRead($idInput))
            If $iValidated2 >= 0 Then $iResult = $iValidated2
            ExitLoop
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_ESCAPE)
        If Not @error And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

        ; Hover effects on buttons
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idOK Then $iFound = $idOK
            If $aCursor[4] = $idCancel Then $iFound = $idCancel
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then _Theme_RemoveHover($iHovered, $THEME_FG_MENU, $THEME_BG_HOVER)
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        Sleep(10)
    WEnd

    GUIDelete($hDlg)
    Return $iResult
EndFunc
