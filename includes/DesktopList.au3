#include-once
#include <ScreenCapture.au3>
#include <GDIPlus.au3>
#include "Theme.au3"
#include "Labels.au3"
#include "VirtualDesktop.au3"
#include "Peek.au3"
#include "Config.au3"

; Extern globals from main script (declared here to suppress Au3Check warnings)
Global $iTaskbarY, $iDesktop, $APP_VERSION, $gui

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
Global $__g_DL_iCtxPin       = 0
Global $__g_DL_iCtxHovered   = 0

; -- Color picker submenu state --
Global $__g_DL_hColorGUI = 0
Global $__g_DL_bColorVisible = False
Global $__g_DL_aColorPresetIDs[8]  ; [0]=7, [1-7]=control IDs
Global $__g_DL_iColorNoneID   = 0
Global $__g_DL_iColorCustomID = 0
Global $__g_DL_iColorTarget = 0
Global $__g_DL_iColorHovered = 0
Global $__g_DL_sLastCustomColor = "FF0000"

; -- Scroll offset for large desktop lists --
Global $__g_DL_iScrollOffset = 0
Global $__g_DL_iMaxVisible = 10 ; max items visible at once (updated from config)

; -- Scroll arrow control IDs --
Global $__g_DL_idScrollUp = 0
Global $__g_DL_idScrollDown = 0

; -- Auto-scroll on arrow hover --
Global $__g_DL_hScrollAutoTimer = 0
Global $__g_DL_iScrollAutoDir = 0 ; -1=up, 0=none, 1=down

; -- Thumbnail preview state --
Global $__g_DL_hThumbGUI = 0
Global $__g_DL_bThumbVisible = False
Global $__g_DL_iThumbTarget = 0

; -- Screenshot thumbnail cache --
Global $__g_DL_aThumbCache[21]       ; cached file paths, index 1-20
Global $__g_DL_aThumbCacheTime[21]   ; TimerInit handle when cached, index 1-20
For $__DL_i = 0 To 20
    $__g_DL_aThumbCache[$__DL_i] = ""
    $__g_DL_aThumbCacheTime[$__DL_i] = 0
Next

; #FUNCTIONS# ===================================================

; Name:        _DL_ShowTemp
; Description: Shows the desktop list in temporary auto-hide mode (3 seconds).
;              If the list is pinned via config, shows as persistent (no auto-hide).
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_ShowTemp($iTaskbarY, $iCurrentDesktop)
    ; If pinned in config, show as persistent instead of temp
    If _Cfg_GetDesktopListPinned() Then
        If Not $__g_DL_bVisible Then _DL_Show($iTaskbarY, $iCurrentDesktop)
        $__g_DL_bTemp = False
        Return
    EndIf
    If $__g_DL_bVisible Then
        If $__g_DL_bTemp Then $__g_DL_hTempTimer = TimerInit()
        Return
    EndIf
    _DL_Show($iTaskbarY, $iCurrentDesktop)
    $__g_DL_bTemp = True
    $__g_DL_hTempTimer = TimerInit()
EndFunc

; Name:        _DL_Toggle
; Description: Toggles the desktop list (persistent mode, no auto-hide).
;              When pinned via config, this is a no-op (list stays open).
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_Toggle($iTaskbarY, $iCurrentDesktop)
    ; If pinned via config, never close — ensure list is showing
    If _Cfg_GetDesktopListPinned() Then
        If Not $__g_DL_bVisible Then
            $__g_DL_bTemp = False
            _DL_Show($iTaskbarY, $iCurrentDesktop)
        EndIf
        Return
    EndIf
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

    ; Read max visible from config
    $__g_DL_iMaxVisible = _Cfg_GetListMaxVisible()

    ; Determine if scroll mode is active: only when config enables it AND items exceed max
    Local $bScrollable = (_Cfg_GetListScrollable() And $iCount > $__g_DL_iMaxVisible)

    ; Clamp scroll offset to valid range
    If $__g_DL_iScrollOffset < 0 Then $__g_DL_iScrollOffset = 0
    If $bScrollable And $__g_DL_iScrollOffset > $iCount - $__g_DL_iMaxVisible Then
        $__g_DL_iScrollOffset = $iCount - $__g_DL_iMaxVisible
    EndIf
    If Not $bScrollable Then $__g_DL_iScrollOffset = 0

    ; Calculate visible range
    Local $iVisibleCount = $iCount
    If $bScrollable Then $iVisibleCount = $__g_DL_iMaxVisible
    Local $iStart = $__g_DL_iScrollOffset + 1
    Local $iEnd = $__g_DL_iScrollOffset + $iVisibleCount
    If $iEnd > $iCount Then $iEnd = $iCount

    ; Calculate height: visible items + optional scroll arrows
    Local $iArrowH = 16
    Local $iExtraH = 0
    If $bScrollable Then $iExtraH = $iArrowH * 2

    Local $iListW = $THEME_MAIN_WIDTH + $THEME_PEEK_ZONE_W
    Local $iListH = $iVisibleCount * $THEME_ITEM_HEIGHT + 6 + $iExtraH
    ; Position list relative to widget anchor — above for bottom, below for top, beside for middle
    Local $sAnchor = _Cfg_GetWidgetPosition()
    Local $iListX = 0
    Local $iListY = $iTaskbarY + 2 - $iListH - 2 ; default: above taskbar
    Local $aWP = WinGetPos($gui) ; $gui is the main widget handle (extern global)
    If Not @error And IsArray($aWP) Then
        $iListX = $aWP[0]
        If StringLeft($sAnchor, 3) = "top" Then
            $iListY = $aWP[1] + $aWP[3] + 2 ; below widget
        ElseIf StringLeft($sAnchor, 6) = "middle" Then
            $iListY = $aWP[1] - $iListH - 2 ; above widget (could also go below)
        Else
            $iListY = $aWP[1] - $iListH - 2 ; above widget (bottom anchor)
        EndIf
        ; Keep on screen
        If $iListY < 0 Then $iListY = $aWP[1] + $aWP[3] + 2
        If $iListY + $iListH > @DesktopHeight Then $iListY = $aWP[1] - $iListH - 2
    EndIf

    $__g_DL_hGUI = _Theme_CreatePopup("DesktopList", $iListW, $iListH, $iListX, $iListY)
    If $__g_DL_hGUI = 0 Then
        _Log_Error("DL_Show: Failed to create list GUI")
        Return
    EndIf

    ReDim $__g_DL_aItems[$iVisibleCount + 1]
    ReDim $__g_DL_aPeekBtns[$iVisibleCount + 1]
    $__g_DL_aItems[0] = $iVisibleCount
    $__g_DL_aPeekBtns[0] = $iVisibleCount
    $__g_DL_iHovered = 0
    $__g_DL_iPeekHovered = 0
    $__g_DL_idScrollUp = 0
    $__g_DL_idScrollDown = 0

    Local $iContentY = 3

    ; Up scroll arrow
    If $bScrollable Then
        Local $sUpArrow = ""
        If $__g_DL_iScrollOffset > 0 Then $sUpArrow = ChrW(0x25B2)
        $__g_DL_idScrollUp = GUICtrlCreateLabel($sUpArrow, 4, $iContentY, $iListW - 8, $iArrowH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_idScrollUp, 7, 400, 0, $THEME_FONT_SYMBOL)
        GUICtrlSetColor($__g_DL_idScrollUp, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_DL_idScrollUp, $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_DL_idScrollUp, 0)
        $iContentY += $iArrowH
    EndIf

    Local $i, $iSlot
    For $iSlot = 1 To $iVisibleCount
        $i = $__g_DL_iScrollOffset + $iSlot
        Local $sName = _Labels_Load($i)
        Local $iPad = _Cfg_GetNumberPadding()
        Local $sNum = String($i)
        While StringLen($sNum) < $iPad
            $sNum = "0" & $sNum
        WEnd
        Local $sText
        If _Cfg_GetDesktopListShowNumbers() Then
            $sText = " " & $sNum
            If $sName <> "" Then $sText &= "  " & $sName
        Else
            $sText = " " & ($sName <> "" ? $sName : $sNum)
        EndIf
        Local $iY = $iContentY + ($iSlot - 1) * $THEME_ITEM_HEIGHT
        Local $iBold = 400
        Local $iColor = $THEME_FG_DIM
        Local $iBg = $GUI_BKCOLOR_TRANSPARENT
        If $i = $iCurrentDesktop Then
            $iBold = 700
            $iColor = $THEME_FG_WHITE
            $iBg = $THEME_BG_ACTIVE
        EndIf

        ; Peek zone icon
        $__g_DL_aPeekBtns[$iSlot] = GUICtrlCreateLabel(ChrW(0x25C9), 4, $iY, $THEME_PEEK_ZONE_W, $THEME_ITEM_HEIGHT - 2, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_aPeekBtns[$iSlot], 7, 400, 0, $THEME_FONT_SYMBOL)
        GUICtrlSetColor($__g_DL_aPeekBtns[$iSlot], $THEME_FG_PEEK_DIM)
        GUICtrlSetBkColor($__g_DL_aPeekBtns[$iSlot], $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_DL_aPeekBtns[$iSlot], 0)

        ; Text label
        Local $sFont = _Cfg_GetListFontName()
        If $sFont = "" Then $sFont = _Theme_GetMonoFont()
        Local $iFontSize = _Cfg_GetListFontSize()
        $__g_DL_aItems[$iSlot] = GUICtrlCreateLabel($sText, 4 + $THEME_PEEK_ZONE_W, $iY, $iListW - 8 - $THEME_PEEK_ZONE_W, $THEME_ITEM_HEIGHT - 2, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_aItems[$iSlot], $iFontSize, $iBold, 0, $sFont)
        GUICtrlSetColor($__g_DL_aItems[$iSlot], $iColor)
        GUICtrlSetBkColor($__g_DL_aItems[$iSlot], $iBg)
        GUICtrlSetCursor($__g_DL_aItems[$iSlot], 0)

        ; Desktop color indicator (skip if colors disabled or color is 0/none)
        If _Cfg_GetDesktopColorsEnabled() And $i <= 9 Then
            Local $iClr = _Cfg_GetDesktopColor($i)
            If $iClr <> 0 Then
                Local $iColorInd = GUICtrlCreateLabel("", $iListW - 8, $iY + 2, 4, $THEME_ITEM_HEIGHT - 6)
                GUICtrlSetBkColor($iColorInd, $iClr)
                GUICtrlSetState($iColorInd, $GUI_DISABLE) ; pass clicks through to text label
            EndIf
        EndIf
    Next

    ; Down scroll arrow
    If $bScrollable Then
        Local $iDownY = $iContentY + $iVisibleCount * $THEME_ITEM_HEIGHT
        Local $sDownArrow = ""
        If $iEnd < $iCount Then $sDownArrow = ChrW(0x25BC)
        $__g_DL_idScrollDown = GUICtrlCreateLabel($sDownArrow, 4, $iDownY, $iListW - 8, $iArrowH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_DL_idScrollDown, 7, 400, 0, $THEME_FONT_SYMBOL)
        GUICtrlSetColor($__g_DL_idScrollDown, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_DL_idScrollDown, $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_DL_idScrollDown, 0)
    EndIf

    _Theme_FadeIn($__g_DL_hGUI, Default, "list")
    $__g_DL_bVisible = True
    $__g_DL_iCount = $iCount
EndFunc

; Name:        _DL_Destroy
; Description: Destroys the list GUI and ends any active peek
Func _DL_Destroy()
    _DL_ThumbDestroy()
    _DL_DragReset()
    _DL_CtxDestroy()
    _Peek_End()
    If $__g_DL_hGUI <> 0 Then
        _Theme_FadeOut($__g_DL_hGUI, "list")
        $__g_DL_hGUI = 0
    EndIf
    $__g_DL_bVisible = False
    $__g_DL_iHovered = 0
    $__g_DL_iPeekHovered = 0
    $__g_DL_iCount = 0
    $__g_DL_idScrollUp = 0
    $__g_DL_idScrollDown = 0
EndFunc

; Name:        _DL_HandleClick
; Description: Processes a click on a list item or peek button
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      Target desktop index (1-based), or 0 if no match
Func _DL_HandleClick($msg)
    If $__g_DL_iDragState = 2 Then Return 0 ; only block during active drag, not pending
    If $msg <= 0 Then Return 0
    ; Handle scroll arrow clicks
    If $__g_DL_idScrollUp <> 0 And $msg = $__g_DL_idScrollUp Then Return -1
    If $__g_DL_idScrollDown <> 0 And $msg = $__g_DL_idScrollDown Then Return -2
    If UBound($__g_DL_aItems) < 2 Or $__g_DL_aItems[0] < 1 Then Return 0
    Local $i
    For $i = 1 To $__g_DL_aItems[0]
        If $msg = $__g_DL_aItems[$i] Or $msg = $__g_DL_aPeekBtns[$i] Then
            If _Peek_IsActive() Then
                _Peek_Commit()
            EndIf
            ; Convert visual slot to actual desktop index
            Return $i + $__g_DL_iScrollOffset
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
    Local $iItemBound = UBound($__g_DL_aItems) - 1
    Local $iPeekBound = UBound($__g_DL_aPeekBtns) - 1
    If $iItemBound < 1 Or $__g_DL_aItems[0] < 1 Then Return
    ; Clamp stored count to actual array size (defensive against stale state)
    Local $iItemCount = $__g_DL_aItems[0]
    If $iItemCount > $iItemBound Then $iItemCount = $iItemBound
    Local $iPeekCount = $__g_DL_aPeekBtns[0]
    If $iPeekCount > $iPeekBound Then $iPeekCount = $iPeekBound

    ; Convert current desktop to visual slot (0 if not visible)
    Local $iCurSlot = $iCurrentDesktop - $__g_DL_iScrollOffset
    If $iCurSlot < 1 Or $iCurSlot > $iItemCount Then $iCurSlot = 0

    Local $aCursor = GUIGetCursorInfo($__g_DL_hGUI)
    If @error Then
        ; Cursor left the list
        If $__g_DL_iHovered > 0 And $__g_DL_iHovered <= $iItemCount And $__g_DL_iHovered <> $iCurSlot Then
            _Theme_RemoveHover($__g_DL_aItems[$__g_DL_iHovered], $THEME_FG_DIM)
        EndIf
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <= $iPeekCount Then
            GUICtrlSetColor($__g_DL_aPeekBtns[$__g_DL_iPeekHovered], $THEME_FG_PEEK_DIM)
            $__g_DL_iPeekHovered = 0
        EndIf
        $__g_DL_iHovered = 0
        _DL_ThumbDestroy()
        _Peek_StartBounceBack()
        Return
    EndIf

    ; Find hovered text item (slot index)
    Local $iFound = 0
    Local $i
    For $i = 1 To $iItemCount
        If $aCursor[4] = $__g_DL_aItems[$i] Then
            $iFound = $i
            ExitLoop
        EndIf
    Next

    ; Find hovered peek button (slot index)
    Local $iPeekFound = 0
    For $i = 1 To $iPeekCount
        If $aCursor[4] = $__g_DL_aPeekBtns[$i] Then
            $iPeekFound = $i
            ExitLoop
        EndIf
    Next

    ; Treat peek zone as part of same row for text highlighting
    Local $iEffective = $iFound
    If $iEffective = 0 Then $iEffective = $iPeekFound

    ; Update text hover highlight (using slot indices for array access)
    If $iEffective <> $__g_DL_iHovered Then
        If $__g_DL_iHovered > 0 And $__g_DL_iHovered <= $iItemCount And $__g_DL_iHovered <> $iCurSlot Then
            _Theme_RemoveHover($__g_DL_aItems[$__g_DL_iHovered], $THEME_FG_DIM)
        EndIf
        $__g_DL_iHovered = $iEffective
        If $__g_DL_iHovered > 0 And $__g_DL_iHovered <= $iItemCount And $__g_DL_iHovered <> $iCurSlot Then
            _Theme_ApplyHover($__g_DL_aItems[$__g_DL_iHovered], $THEME_FG_WHITE, $THEME_BG_HOVER)
        EndIf
    EndIf

    ; Show/hide thumbnail preview on hover (convert slot to actual desktop index)
    If _Cfg_GetThumbnailsEnabled() Then
        If $iEffective > 0 Then
            _DL_ThumbShow($iEffective + $__g_DL_iScrollOffset)
        Else
            _DL_ThumbDestroy()
        EndIf
    EndIf

    ; Update peek button hover + trigger peek
    If $iPeekFound <> $__g_DL_iPeekHovered Then
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <= $iPeekCount Then
            GUICtrlSetColor($__g_DL_aPeekBtns[$__g_DL_iPeekHovered], $THEME_FG_PEEK_DIM)
        EndIf
        $__g_DL_iPeekHovered = $iPeekFound
        If $__g_DL_iPeekHovered > 0 And $__g_DL_iPeekHovered <= $iPeekCount Then
            GUICtrlSetColor($__g_DL_aPeekBtns[$__g_DL_iPeekHovered], $THEME_FG_WHITE)
        EndIf

        ; Peek logic (convert slot to actual desktop index)
        Local $iActualPeek = $__g_DL_iPeekHovered + $__g_DL_iScrollOffset
        If $__g_DL_iPeekHovered > 0 And $iActualPeek <> $iCurrentDesktop Then
            _Peek_Start($iActualPeek)
        Else
            _Peek_StartBounceBack()
        EndIf
    EndIf

    ; Auto-scroll on arrow hover (with visual feedback)
    If $__g_DL_idScrollUp <> 0 And $aCursor[4] = $__g_DL_idScrollUp Then
        GUICtrlSetColor($__g_DL_idScrollUp, $THEME_FG_WHITE)
        If $__g_DL_iScrollAutoDir <> -1 Then
            $__g_DL_iScrollAutoDir = -1
            $__g_DL_hScrollAutoTimer = TimerInit()
        ElseIf TimerDiff($__g_DL_hScrollAutoTimer) > 200 Then
            _DL_ScrollUp($iTaskbarY, $iCurrentDesktop)
            $__g_DL_hScrollAutoTimer = TimerInit()
        EndIf
    ElseIf $__g_DL_idScrollDown <> 0 And $aCursor[4] = $__g_DL_idScrollDown Then
        GUICtrlSetColor($__g_DL_idScrollDown, $THEME_FG_WHITE)
        If $__g_DL_iScrollAutoDir <> 1 Then
            $__g_DL_iScrollAutoDir = 1
            $__g_DL_hScrollAutoTimer = TimerInit()
        ElseIf TimerDiff($__g_DL_hScrollAutoTimer) > 200 Then
            _DL_ScrollDown($iTaskbarY, $iCurrentDesktop)
            $__g_DL_hScrollAutoTimer = TimerInit()
        EndIf
    Else
        $__g_DL_iScrollAutoDir = 0
        If $__g_DL_idScrollUp <> 0 Then GUICtrlSetColor($__g_DL_idScrollUp, $THEME_FG_DIM)
        If $__g_DL_idScrollDown <> 0 Then GUICtrlSetColor($__g_DL_idScrollDown, $THEME_FG_DIM)
    EndIf
EndFunc

; Name:        _DL_UpdateHighlight
; Description: Updates the active desktop highlight in the list
; Parameters:  $iCurrentDesktop - currently active desktop (1-based)
Func _DL_UpdateHighlight($iCurrentDesktop)
    If Not $__g_DL_bVisible Then Return
    If UBound($__g_DL_aItems) < 2 Or $__g_DL_aItems[0] < 1 Then Return
    Local $sFont = _Cfg_GetListFontName()
    If $sFont = "" Then $sFont = _Theme_GetMonoFont()
    Local $iFontSize = _Cfg_GetListFontSize()
    ; Convert current desktop to visual slot
    Local $iCurSlot = $iCurrentDesktop - $__g_DL_iScrollOffset
    If $iCurSlot < 1 Or $iCurSlot > $__g_DL_aItems[0] Then $iCurSlot = 0
    Local $i
    For $i = 1 To $__g_DL_aItems[0]
        If $i = $__g_DL_iHovered And $i <> $iCurSlot Then ContinueLoop
        If $i = $iCurSlot Then
            GUICtrlSetFont($__g_DL_aItems[$i], $iFontSize, 700, 0, $sFont)
            GUICtrlSetColor($__g_DL_aItems[$i], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_DL_aItems[$i], $THEME_BG_ACTIVE)
        Else
            GUICtrlSetFont($__g_DL_aItems[$i], $iFontSize, 400, 0, $sFont)
            GUICtrlSetColor($__g_DL_aItems[$i], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_DL_aItems[$i], $GUI_BKCOLOR_TRANSPARENT)
        EndIf
    Next
EndFunc

; Name:        _DL_CheckAutoHide
; Description: Checks if the temp list should auto-hide (3s timeout, cursor not over list or main).
;              When pinned via config, always returns False (never auto-hide).
; Parameters:  $hMainGUI - handle to the main widget GUI
; Return:      True if the list was auto-hidden, False otherwise
Func _DL_CheckAutoHide($hMainGUI)
    If _Cfg_GetDesktopListPinned() Then Return False
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
    ; Convert actual desktop index to visual slot
    Local $iSlot = $iIndex - $__g_DL_iScrollOffset
    If $iSlot < 1 Or $iSlot > $__g_DL_aItems[0] Then Return
    Local $iPad = _Cfg_GetNumberPadding()
    Local $sNum = String($iIndex)
    While StringLen($sNum) < $iPad
        $sNum = "0" & $sNum
    WEnd
    Local $sText
    If _Cfg_GetDesktopListShowNumbers() Then
        $sText = " " & $sNum
        If $sLabel <> "" Then $sText &= "  " & $sLabel
    Else
        $sText = " " & ($sLabel <> "" ? $sLabel : $sNum)
    EndIf
    GUICtrlSetData($__g_DL_aItems[$iSlot], $sText)
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

; Name:        _DL_IsPinned
; Description: Returns whether the desktop list is pinned (persistent config state)
; Return:      True if pinned via config, False otherwise
Func _DL_IsPinned()
    Return _Cfg_GetDesktopListPinned()
EndFunc

; Name:        _DL_SetPinned
; Description: Sets the pin state: updates config, internal state, and saves immediately.
;              When pinning: shows the list persistently.
;              When unpinning: closes the list and resets to normal behavior.
; Parameters:  $bPinned - True to pin, False to unpin
;              $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_SetPinned($bPinned, $iTaskbarY, $iCurrentDesktop)
    _Cfg_SetDesktopListPinned($bPinned)
    _Cfg_Save()
    If $bPinned Then
        ; Pin: show list in persistent mode
        $__g_DL_bTemp = False
        If Not $__g_DL_bVisible Then _DL_Show($iTaskbarY, $iCurrentDesktop)
    Else
        ; Unpin: close the list, return to normal behavior
        If $__g_DL_bVisible Then _DL_Destroy()
        $__g_DL_bTemp = False
    EndIf
EndFunc

; Name:        _DL_GetScrollOffset
; Description: Returns the current scroll offset
; Return:      Integer (0-based offset)
Func _DL_GetScrollOffset()
    Return $__g_DL_iScrollOffset
EndFunc

Func _DL_SetScrollOffset($i)
    $__g_DL_iScrollOffset = $i
EndFunc

; Name:        _DL_ScrollUp
; Description: Scrolls the desktop list up by scroll speed and refreshes in-place
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_ScrollUp($iTaskbarY, $iCurrentDesktop)
    If $__g_DL_iScrollOffset > 0 Then
        Local $iStep = _Cfg_GetListScrollSpeed()
        $__g_DL_iScrollOffset -= $iStep
        If $__g_DL_iScrollOffset < 0 Then $__g_DL_iScrollOffset = 0
        _DL_RefreshScrollView($iCurrentDesktop)
    EndIf
EndFunc

; Name:        _DL_ScrollDown
; Description: Scrolls the desktop list down by scroll speed and refreshes in-place
; Parameters:  $iTaskbarY - Y position of the taskbar
;              $iCurrentDesktop - currently active desktop (1-based)
Func _DL_ScrollDown($iTaskbarY, $iCurrentDesktop)
    If $__g_DL_iScrollOffset + $__g_DL_iMaxVisible < $__g_DL_iCount Then
        Local $iStep = _Cfg_GetListScrollSpeed()
        $__g_DL_iScrollOffset += $iStep
        If $__g_DL_iScrollOffset > $__g_DL_iCount - $__g_DL_iMaxVisible Then
            $__g_DL_iScrollOffset = $__g_DL_iCount - $__g_DL_iMaxVisible
        EndIf
        _DL_RefreshScrollView($iCurrentDesktop)
    EndIf
EndFunc

; Name:        _DL_RefreshScrollView
; Description: Updates existing list controls in-place after scroll offset changes.
;              Avoids flicker by not destroying/recreating the GUI.
; Parameters:  $iCurrentDesktop - currently active desktop (1-based)
Func _DL_RefreshScrollView($iCurrentDesktop)
    If Not $__g_DL_bVisible Or $__g_DL_hGUI = 0 Then Return
    If UBound($__g_DL_aItems) < 2 Or $__g_DL_aItems[0] < 1 Then Return

    Local $sFont = _Cfg_GetListFontName()
    If $sFont = "" Then $sFont = _Theme_GetMonoFont()
    Local $iFontSize = _Cfg_GetListFontSize()
    Local $iPad = _Cfg_GetNumberPadding()

    Local $iSlot, $i
    For $iSlot = 1 To $__g_DL_aItems[0]
        $i = $__g_DL_iScrollOffset + $iSlot
        ; Build display text
        Local $sName = _Labels_Load($i)
        Local $sNum = String($i)
        While StringLen($sNum) < $iPad
            $sNum = "0" & $sNum
        WEnd
        Local $sText
        If _Cfg_GetDesktopListShowNumbers() Then
            $sText = " " & $sNum
            If $sName <> "" Then $sText &= "  " & $sName
        Else
            $sText = " " & ($sName <> "" ? $sName : $sNum)
        EndIf

        ; Update label text
        GUICtrlSetData($__g_DL_aItems[$iSlot], $sText)

        ; Update font/color for active vs inactive
        If $i = $iCurrentDesktop Then
            GUICtrlSetFont($__g_DL_aItems[$iSlot], $iFontSize, 700, 0, $sFont)
            GUICtrlSetColor($__g_DL_aItems[$iSlot], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_DL_aItems[$iSlot], $THEME_BG_ACTIVE)
        Else
            GUICtrlSetFont($__g_DL_aItems[$iSlot], $iFontSize, 400, 0, $sFont)
            GUICtrlSetColor($__g_DL_aItems[$iSlot], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_DL_aItems[$iSlot], $GUI_BKCOLOR_TRANSPARENT)
        EndIf
    Next

    ; Update scroll arrow text (filled vs outline)
    If $__g_DL_idScrollUp <> 0 Then
        If $__g_DL_iScrollOffset > 0 Then
            GUICtrlSetData($__g_DL_idScrollUp, ChrW(0x25B2))
        Else
            GUICtrlSetData($__g_DL_idScrollUp, ChrW(0x25B3))
        EndIf
    EndIf
    If $__g_DL_idScrollDown <> 0 Then
        If $__g_DL_iScrollOffset + $__g_DL_iMaxVisible < $__g_DL_iCount Then
            GUICtrlSetData($__g_DL_idScrollDown, ChrW(0x25BC))
        Else
            GUICtrlSetData($__g_DL_idScrollDown, ChrW(0x25BD))
        EndIf
    EndIf

    ; Reset hover state since items shifted
    $__g_DL_iHovered = 0
    $__g_DL_iPeekHovered = 0
EndFunc

; Name:        _DL_ResetScroll
; Description: Resets the scroll offset to zero (e.g., when desktop count changes)
Func _DL_ResetScroll()
    $__g_DL_iScrollOffset = 0
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
    $__g_DL_iDragStartX = $__g_Theme_iCachedCursorX
    $__g_DL_iDragStartY = $__g_Theme_iCachedCursorY
EndFunc

; Name:        _DL_DragMouseMove
; Description: Called each frame while LMB is held and drag state > 0.
;              Transitions from pending to dragging when threshold is met,
;              and updates the drop target highlight while dragging.
Func _DL_DragMouseMove()
    If $__g_DL_iDragState = 1 Then
        ; Check threshold
        Local $iDX = Abs($__g_Theme_iCachedCursorX - $__g_DL_iDragStartX)
        Local $iDY = Abs($__g_Theme_iCachedCursorY - $__g_DL_iDragStartY)
        If $iDX < $__g_DL_DRAG_THRESHOLD And $iDY < $__g_DL_DRAG_THRESHOLD Then Return
        ; Activate drag
        $__g_DL_iDragState = 2
        _Peek_End()
        _DL_CtxDestroy()
        ; Dim source row
        If $__g_DL_iDragSource >= 1 And $__g_DL_iDragSource <= $__g_DL_aItems[0] Then
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

    ; Adjacent swap chain — _VD_SwapDesktops handles windows, OS names, and colors
    Local $iPos = $iFrom
    While $iPos <> $iTo
        Local $iNext = $iPos + $iStep
        _VD_SwapDesktops($iPos, $iNext)
        Sleep(100) ; let Windows process the window moves between swaps
        ; Swap INI labels (OS names already swapped inside _VD_SwapDesktops)
        Local $sIniA = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $iPos, "")
        Local $sIniB = IniRead($__g_Labels_IniPath, "Labels", "desktop_" & $iNext, "")
        IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $iPos, $sIniB)
        IniWrite($__g_Labels_IniPath, "Labels", "desktop_" & $iNext, $sIniA)
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
    Local $aWP = WinGetPos($__g_DL_hGUI)
    If @error Then Return 0
    If $__g_Theme_iCachedCursorX < $aWP[0] Or $__g_Theme_iCachedCursorX >= $aWP[0] + $aWP[2] Then Return 0
    If $__g_Theme_iCachedCursorY < $aWP[1] Or $__g_Theme_iCachedCursorY >= $aWP[1] + $aWP[3] Then Return 0
    ; Account for scroll arrow height at top (arrows only present when scroll mode is active)
    Local $iArrowH = 0
    If $__g_DL_idScrollUp <> 0 Then $iArrowH = 16
    ; Items start at Y=3+arrowH within the list, each $THEME_ITEM_HEIGHT tall
    Local $iRelY = $__g_Theme_iCachedCursorY - $aWP[1] - 3 - $iArrowH
    If $iRelY < 0 Then Return 0
    Local $iSlot = Int($iRelY / $THEME_ITEM_HEIGHT) + 1
    Local $iVisibleCount = $__g_DL_aItems[0]
    If $iSlot < 1 Or $iSlot > $iVisibleCount Then Return 0
    ; Convert slot to actual desktop index
    Local $iRow = $iSlot + $__g_DL_iScrollOffset
    If $iRow > $__g_DL_iCount Then Return 0
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
    If _Cfg_GetPinningEnabled() Then $iItemCount += 1
    Local $iMenuH = $iItemCount * $THEME_MENU_ITEM_H + $iSepH + 12

    Local $iMenuX = $__g_Theme_iCachedCursorX
    Local $iMenuY = $__g_Theme_iCachedCursorY - $iMenuH
    ; Keep menu on screen
    If $iMenuY < 0 Then $iMenuY = $__g_Theme_iCachedCursorY

    $__g_DL_hCtxGUI = _Theme_CreatePopup("DLCtx", $iMenuW, $iMenuH, $iMenuX, $iMenuY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)
    If $__g_DL_hCtxGUI = 0 Then
        _Log_Error("DL_CtxShow: Failed to create context menu GUI")
        Return
    EndIf

    Local $iY = 4

    $__g_DL_iCtxSwitch = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_switch", "Switch"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_DL_iCtxRename = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_rename", "Rename"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    $__g_DL_iCtxPeek = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_peek", "Peek"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    If _Cfg_GetDesktopColorsEnabled() Then
        $__g_DL_iCtxSetColor = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_set_color", "Set Color") & "  " & ChrW(0x25B6), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    If _Cfg_GetMoveWindowEnabled() Then
        $__g_DL_iCtxMoveWin = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_move_window", "Move Window Here"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    If _Cfg_GetPinningEnabled() Then
        $__g_DL_iCtxPin = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_pin", "Pin to All Desktops"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    $__g_DL_iCtxAdd = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_add_desktop", "Add Desktop"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    ; Separator
    GUICtrlCreateLabel("", 8, $iY + 2, $iMenuW - 16, $iSepH)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += $iSepH + 4

    $__g_DL_iCtxDelete = _Theme_CreateMenuItem("  " & _i18n("DesktopList.dl_delete", "Delete"), 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
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
    $__g_DL_iCtxPin = 0
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
    If $__g_DL_iCtxPin <> 0 And $msg = $__g_DL_iCtxPin Then Return "pin"
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
    If $__g_DL_iCtxPin <> 0 And $aCursor[4] = $__g_DL_iCtxPin Then $iFound = $__g_DL_iCtxPin
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

    ; Auto-show color picker on hover over "Set Color"
    If $iFound = $__g_DL_iCtxSetColor And $__g_DL_iCtxSetColor <> 0 And Not _DL_ColorPickerIsVisible() Then
        _DL_ColorPickerShow($__g_DL_iCtxTarget)
    ElseIf $iFound <> $__g_DL_iCtxSetColor And _DL_ColorPickerIsVisible() Then
        If Not _Theme_IsCursorOverWindow(_DL_ColorPickerGetGUI()) Then
            _DL_ColorPickerDestroy()
        EndIf
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

    ; Position: to the right of DL context menu if open, else near cursor
    Local $iPickerX = 0, $iPickerY = 0
    If $__g_DL_hCtxGUI <> 0 Then
        Local $aCtxPos = WinGetPos($__g_DL_hCtxGUI)
        If Not @error Then
            $iPickerX = $aCtxPos[0] + $aCtxPos[2]
            $iPickerY = $aCtxPos[1]
        EndIf
    EndIf
    If $iPickerX = 0 Then
        ; Fallback: position near cursor (called from main context menu)
        $iPickerX = $__g_Theme_iCachedCursorX + 8
        $iPickerY = $__g_Theme_iCachedCursorY - $iPickerH
    EndIf
    ; Keep on screen
    If $iPickerX + $iPickerW > @DesktopWidth Then $iPickerX = @DesktopWidth - $iPickerW - 4
    If $iPickerX < 0 Then $iPickerX = 0
    If $iPickerY + $iPickerH > @DesktopHeight Then $iPickerY = @DesktopHeight - $iPickerH
    If $iPickerY < 0 Then $iPickerY = 0

    $__g_DL_hColorGUI = _Theme_CreatePopup("ColorPicker", $iPickerW, $iPickerH, $iPickerX, $iPickerY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)

    Local $iY = 6

    ; "None" option at the top (clear color)
    Local $iCurClr = _Cfg_GetDesktopColor($iTarget)
    Local $sNoneText = "  " & _i18n("DesktopList.cp_none", "None")
    If $iCurClr = 0 Then $sNoneText = ChrW(0x2713) & " " & _i18n("DesktopList.cp_none", "None")
    $__g_DL_iColorNoneID = GUICtrlCreateLabel($sNoneText, 6, $iY, $iPickerW - 12, 24, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_DL_iColorNoneID, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_DL_iColorNoneID, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_DL_iColorNoneID, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($__g_DL_iColorNoneID, 0)
    $iY += 26

    ; Separator
    GUICtrlCreateLabel("", 10, $iY, $iPickerW - 20, 1)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += 5

    ; 7 preset colors with names (highlight currently selected)
    Local $aColorNames[8] = [7, "Blue", "Green", "Orange", "Yellow", "Purple", "Pink", "Teal"]
    Local $iCurrentColor = _Cfg_GetDesktopColor($iTarget)
    $__g_DL_aColorPresetIDs[0] = 7
    Local $i
    For $i = 1 To 7
        Local $iColor = $THEME_PRESET_COLORS[$i]
        Local $sCheck = "  " & ChrW(0x25CF) & "  " & $aColorNames[$i]
        If $iColor = $iCurrentColor Then $sCheck = ChrW(0x2713) & " " & ChrW(0x25CF) & "  " & $aColorNames[$i]
        $__g_DL_aColorPresetIDs[$i] = GUICtrlCreateLabel($sCheck, 6, $iY, $iPickerW - 12, 24, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
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
    $__g_DL_iColorCustomID = GUICtrlCreateLabel("  " & _i18n("DesktopList.cp_custom", "Custom..."), 6, $iY, $iPickerW - 12, 24, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
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
    $__g_DL_iColorHovered = 0
    $__g_DL_iColorNoneID = 0
    $__g_DL_iColorCustomID = 0
    Local $i
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
    Local $i
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

; Name:        _DL_ColorPickerCheckHover
; Description: Updates hover highlighting on the color picker popup. Call from main loop.
Func _DL_ColorPickerCheckHover()
    If Not $__g_DL_bColorVisible Or $__g_DL_hColorGUI = 0 Then Return
    Local $aCursor = GUIGetCursorInfo($__g_DL_hColorGUI)
    If @error Then
        If $__g_DL_iColorHovered <> 0 Then
            __DL_ColorPickerRestoreItem($__g_DL_iColorHovered)
            $__g_DL_iColorHovered = 0
        EndIf
        Return
    EndIf

    Local $iFound = 0
    If $aCursor[4] = $__g_DL_iColorNoneID Then $iFound = $__g_DL_iColorNoneID
    If $aCursor[4] = $__g_DL_iColorCustomID Then $iFound = $__g_DL_iColorCustomID
    Local $i
    For $i = 1 To 7
        If $__g_DL_aColorPresetIDs[$i] <> 0 And $aCursor[4] = $__g_DL_aColorPresetIDs[$i] Then
            $iFound = $__g_DL_aColorPresetIDs[$i]
            ExitLoop
        EndIf
    Next

    If $iFound = $__g_DL_iColorHovered Then Return

    If $__g_DL_iColorHovered <> 0 Then
        __DL_ColorPickerRestoreItem($__g_DL_iColorHovered)
    EndIf

    $__g_DL_iColorHovered = $iFound
    If $__g_DL_iColorHovered <> 0 Then
        _Theme_ApplyHover($__g_DL_iColorHovered, $THEME_FG_WHITE, $THEME_BG_HOVER)
    EndIf
EndFunc

; Name:        __DL_ColorPickerRestoreItem
; Description: Restores the original color of a color picker item after hover
; Parameters:  $idCtrl - control ID to restore
Func __DL_ColorPickerRestoreItem($idCtrl)
    If $idCtrl = $__g_DL_iColorNoneID Then
        _Theme_RemoveHover($idCtrl, $THEME_FG_DIM)
        Return
    EndIf
    If $idCtrl = $__g_DL_iColorCustomID Then
        _Theme_RemoveHover($idCtrl, $THEME_FG_MENU)
        Return
    EndIf
    Local $i
    For $i = 1 To 7
        If $__g_DL_aColorPresetIDs[$i] = $idCtrl Then
            _Theme_RemoveHover($idCtrl, $THEME_PRESET_COLORS[$i])
            Return
        EndIf
    Next
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
    GUICtrlCreateLabel(_i18n("DesktopList.cp_hex_color", "Hex color:"), 10, 8, 60, 20, $SS_CENTERIMAGE)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    ; Input field
    Local $idInput = GUICtrlCreateInput($__g_DL_sLastCustomColor, 74, 8, 110, 20)
    GUICtrlSetFont($idInput, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idInput, $THEME_FG_TEXT)
    GUICtrlSetBkColor($idInput, $THEME_BG_INPUT)
    _Theme_FlattenInput($idInput)

    ; OK button
    Local $iBtnW = 50, $iBtnH = 24
    Local $idOK = GUICtrlCreateLabel(_i18n("General.btn_ok", "OK"), 10, $iDlgH - 34, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idOK, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idOK, $THEME_FG_MENU)
    GUICtrlSetBkColor($idOK, $THEME_BG_HOVER)
    GUICtrlSetCursor($idOK, 0)

    ; Cancel button
    Local $idCancel = GUICtrlCreateLabel(_i18n("General.btn_cancel", "Cancel"), 10 + $iBtnW + 10, $iDlgH - 34, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
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
        Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
        If Not @error And IsArray($retEnter) And BitAND($retEnter[0], 0x8000) <> 0 Then
            Local $iValidated2 = _Theme_ValidateHexColor(GUICtrlRead($idInput))
            If $iValidated2 >= 0 Then $iResult = $iValidated2
            ExitLoop
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0 Then ExitLoop

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
    ; Remember successful custom color for next time
    If $iResult >= 0 Then $__g_DL_sLastCustomColor = StringRight("000000" & Hex($iResult, 6), 6)
    Return $iResult
EndFunc

; Name:        _DL_ThumbShow
; Description: Shows a thumbnail preview popup for a desktop
; Parameters:  $iDesktop - desktop index (1-based)
Func _DL_ThumbShow($iDesktop)
    If Not _Cfg_GetThumbnailsEnabled() Then Return
    If $__g_DL_bThumbVisible And $__g_DL_iThumbTarget = $iDesktop Then Return
    _DL_ThumbDestroy()

    $__g_DL_iThumbTarget = $iDesktop
    Local $iW = _Cfg_GetThumbnailWidth()
    Local $iH = _Cfg_GetThumbnailHeight()

    ; Position to the right of the desktop list
    Local $aListPos = WinGetPos($__g_DL_hGUI)
    If @error Then Return
    Local $iX = $aListPos[0] + $aListPos[2] + 4
    ; Calculate Y relative to visible slot, accounting for scroll offset and arrow
    Local $iArrowH = 0
    If $__g_DL_idScrollUp <> 0 Then $iArrowH = 16
    Local $iRow = ($iDesktop - 1 - $__g_DL_iScrollOffset) * $THEME_ITEM_HEIGHT + 3 + $iArrowH
    Local $iY = $aListPos[1] + $iRow
    ; Keep on screen
    If $iX + $iW > @DesktopWidth Then $iX = $aListPos[0] - $iW - 4
    If $iY + $iH > @DesktopHeight Then $iY = @DesktopHeight - $iH

    $__g_DL_hThumbGUI = _Theme_CreatePopup("Thumb", $iW + 4, $iH + 4, $iX, $iY, $THEME_BG_POPUP, $THEME_ALPHA_POPUP)

    ; Create a dark border frame
    GUICtrlCreateLabel("", 0, 0, $iW + 4, $iH + 4)
    GUICtrlSetBkColor(-1, $THEME_BG_BORDER)

    If _Cfg_GetThumbnailUseScreenshot() Then
        ; Screenshot-based thumbnail
        Local $sFile = ""
        Local $iTTL = _Cfg_GetThumbnailCacheTTL() * 1000

        ; Check cache validity
        If $iDesktop >= 1 And $iDesktop <= 20 Then
            If $__g_DL_aThumbCache[$iDesktop] <> "" And FileExists($__g_DL_aThumbCache[$iDesktop]) Then
                If TimerDiff($__g_DL_aThumbCacheTime[$iDesktop]) < $iTTL Then
                    $sFile = $__g_DL_aThumbCache[$iDesktop]
                EndIf
            EndIf

            If $sFile = "" Then
                $sFile = _DL_ThumbCaptureDesktop($iDesktop)
            EndIf
        EndIf

        If $sFile <> "" And FileExists($sFile) Then
            GUICtrlCreatePic($sFile, 2, 2, $iW, $iH)
        Else
            ; Fallback to text preview when screenshot fails
            __DL_ThumbShowText($iDesktop, $iW, $iH)
        EndIf
    Else
        ; Text-based thumbnail preview (default)
        __DL_ThumbShowText($iDesktop, $iW, $iH)
    EndIf

    GUISetState(@SW_SHOWNOACTIVATE, $__g_DL_hThumbGUI)
    $__g_DL_bThumbVisible = True
EndFunc

; Name:        __DL_ThumbShowText
; Description: Renders the text-based thumbnail preview content (window list)
; Parameters:  $iDesktop - desktop index (1-based)
;              $iW - thumbnail width
;              $iH - thumbnail height
Func __DL_ThumbShowText($iDesktop, $iW, $iH)
    Local $sName = _Labels_Load($iDesktop)
    Local $sInfo = "Desktop " & $iDesktop
    If $sName <> "" Then $sInfo &= @CRLF & $sName

    ; Count windows on this desktop
    Local $aWins = _VD_EnumWindowsOnDesktop($iDesktop)
    $sInfo &= @CRLF & @CRLF & $aWins[0] & " window(s)"

    ; List first few window titles
    Local $iMax = 5
    If $aWins[0] < $iMax Then $iMax = $aWins[0]
    Local $i
    For $i = 1 To $iMax
        Local $sTitle = WinGetTitle($aWins[$i])
        If StringLen($sTitle) > 25 Then $sTitle = StringLeft($sTitle, 22) & "..."
        If $sTitle <> "" Then $sInfo &= @CRLF & "  " & $sTitle
    Next
    If $aWins[0] > 5 Then $sInfo &= @CRLF & "  +" & ($aWins[0] - 5) & " more"

    GUICtrlCreateLabel($sInfo, 4, 4, $iW - 4, $iH - 4)
    GUICtrlSetFont(-1, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $THEME_BG_MAIN)
EndFunc

; Name:        _DL_ThumbCaptureDesktop
; Description: Captures a screenshot of a desktop and caches it as a scaled JPG file
; Parameters:  $iDesktop - desktop index (1-based)
; Return:      File path to scaled thumbnail JPG, or "" on failure
Func _DL_ThumbCaptureDesktop($iDesktop)
    Local $iCurrent = _VD_GetCurrent()
    Local $bSwitched = False

    If $iDesktop <> $iCurrent Then
        _VD_GoTo($iDesktop)
        Sleep(150)
        $bSwitched = True
    EndIf

    ; Capture full screen to temp file
    Local $sTempFile = @TempDir & "\desk_switcheroo_thumb_" & $iDesktop & ".bmp"
    _ScreenCapture_Capture($sTempFile, 0, 0, -1, -1, False)

    If $bSwitched Then _VD_GoTo($iCurrent)

    If Not FileExists($sTempFile) Then Return ""

    ; Scale using GDI+
    Local $iW = _Cfg_GetThumbnailWidth()
    Local $iH = _Cfg_GetThumbnailHeight()

    _GDIPlus_Startup()
    Local $hImage = _GDIPlus_ImageLoadFromFile($sTempFile)
    If $hImage = 0 Then
        _GDIPlus_Shutdown()
        FileDelete($sTempFile)
        Return ""
    EndIf

    ; Create scaled bitmap
    Local $hThumb = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
    Local $hGraphics = _GDIPlus_ImageGetGraphicsContext($hThumb)
    _GDIPlus_GraphicsSetInterpolationMode($hGraphics, 7) ; high quality bicubic
    _GDIPlus_GraphicsDrawImageRect($hGraphics, $hImage, 0, 0, $iW, $iH)
    _GDIPlus_GraphicsDispose($hGraphics)
    _GDIPlus_ImageDispose($hImage)

    ; Save scaled thumbnail as JPG
    Local $sThumbFile = @TempDir & "\desk_switcheroo_thumb_" & $iDesktop & "_scaled.jpg"
    Local $sCLSID = _GDIPlus_EncodersGetCLSID("JPG")
    _GDIPlus_ImageSaveToFileEx($hThumb, $sThumbFile, $sCLSID)
    _GDIPlus_ImageDispose($hThumb)
    _GDIPlus_Shutdown()

    ; Clean up full-size temp
    FileDelete($sTempFile)

    If Not FileExists($sThumbFile) Then Return ""

    ; Cache the file path and time
    If $iDesktop >= 1 And $iDesktop <= 20 Then
        $__g_DL_aThumbCache[$iDesktop] = $sThumbFile
        $__g_DL_aThumbCacheTime[$iDesktop] = TimerInit()
    EndIf

    Return $sThumbFile
EndFunc

; Name:        _DL_ThumbClearCache
; Description: Deletes all cached screenshot thumbnail files and resets cache state
Func _DL_ThumbClearCache()
    Local $i
    For $i = 1 To 20
        If $__g_DL_aThumbCache[$i] <> "" And FileExists($__g_DL_aThumbCache[$i]) Then
            FileDelete($__g_DL_aThumbCache[$i])
        EndIf
        $__g_DL_aThumbCache[$i] = ""
        $__g_DL_aThumbCacheTime[$i] = 0
    Next
EndFunc

; Name:        _DL_ThumbDestroy
; Description: Destroys the thumbnail preview popup
Func _DL_ThumbDestroy()
    If $__g_DL_hThumbGUI <> 0 Then
        GUIDelete($__g_DL_hThumbGUI)
        $__g_DL_hThumbGUI = 0
    EndIf
    $__g_DL_bThumbVisible = False
    $__g_DL_iThumbTarget = 0
EndFunc

; Name:        _DL_ThumbIsVisible
; Description: Returns whether the thumbnail popup is currently visible
Func _DL_ThumbIsVisible()
    Return $__g_DL_bThumbVisible
EndFunc

; Name:        _DL_ThumbGetGUI
; Description: Returns the thumbnail popup GUI handle
Func _DL_ThumbGetGUI()
    Return $__g_DL_hThumbGUI
EndFunc
