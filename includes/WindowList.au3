#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include "Theme.au3"
#include "Config.au3"
#include "VirtualDesktop.au3"
#include "Logger.au3"

; Extern globals from main script (declared here to suppress Au3Check warnings)
Global $gui, $iDesktop, $iTaskbarY, $iTaskbarH

; #INDEX# =======================================================
; Title .........: WindowList
; Description ....: Window list panel showing windows on the current desktop
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_WL_hGUI = 0
Global $__g_WL_bVisible = False
Global $__g_WL_iDesktop = 0

; Items
Global $__g_WL_aHWNDs[100]     ; window handles, index 1-N
Global $__g_WL_aItemIDs[100]   ; label control IDs for display
Global $__g_WL_iItemCount = 0
Global $__g_WL_iMaxItems = 99

; Scroll
Global $__g_WL_iScrollOffset = 0
Global $__g_WL_idScrollUp = 0
Global $__g_WL_idScrollDown = 0

; Hover
Global $__g_WL_iHovered = 0

; Search
Global $__g_WL_idSearchInput = 0
Global $__g_WL_sLastSearch = ""

; Context menu
Global $__g_WL_hCtxGUI = 0
Global $__g_WL_bCtxVisible = False
Global $__g_WL_hCtxTarget = 0  ; HWND of targeted window
Global $__g_WL_iCtxHovered = 0

; Context menu item IDs
Global $__g_WL_iCtxSendNext = 0
Global $__g_WL_iCtxSendPrev = 0
Global $__g_WL_iCtxSendNew = 0
Global $__g_WL_iCtxPull = 0
Global $__g_WL_iCtxPin = 0
Global $__g_WL_iCtxMinimize = 0
Global $__g_WL_iCtxMaximize = 0
Global $__g_WL_iCtxRestore = 0
Global $__g_WL_iCtxClose = 0
Global $__g_WL_iCtxGoTo = 0

; Auto-refresh
Global $__g_WL_hRefreshTimer = 0

; Auto-hide
Global $__g_WL_hAutoHideTimer = 0

; #INTERNAL HELPERS# ============================================

; Name:        __WL_TruncateTitle
; Description: Truncates a window title to fit within the panel width
; Parameters:  $sTitle - original window title
;              $iMaxChars - maximum number of characters (default: 35)
; Return:      Truncated string with ellipsis if needed
Func __WL_TruncateTitle($sTitle, $iMaxChars = 35)
    If StringLen($sTitle) > $iMaxChars Then
        Return StringLeft($sTitle, $iMaxChars - 3) & "..."
    EndIf
    Return $sTitle
EndFunc

; Name:        __WL_EnumFilteredWindows
; Description: Enumerates windows on a desktop and filters to valid top-level windows.
;              Populates $__g_WL_aHWNDs with results.
; Parameters:  $iDesktop - desktop index (1-based)
; Return:      Number of valid windows found
Func __WL_EnumFilteredWindows($iDesktop)
    Local $aRaw = _VD_EnumWindowsOnDesktop($iDesktop)
    $__g_WL_iItemCount = 0

    If Not IsArray($aRaw) Or $aRaw[0] < 1 Then Return 0

    ; Ensure buffer is large enough
    If UBound($__g_WL_aHWNDs) < $aRaw[0] + 1 Then
        ReDim $__g_WL_aHWNDs[$aRaw[0] + 1]
    EndIf

    Local $i
    For $i = 1 To $aRaw[0]
        Local $hWnd = $aRaw[$i]
        If $hWnd = 0 Then ContinueLoop

        ; Skip our own GUI
        If $hWnd = $gui Then ContinueLoop

        ; Skip windows without a title
        Local $sTitle = WinGetTitle($hWnd)
        If $sTitle = "" Then ContinueLoop

        ; Skip invisible windows
        Local $iState = WinGetState($hWnd)
        If Not BitAND($iState, 2) Then ContinueLoop

        ; Skip tool windows (WS_EX_TOOLWINDOW without WS_EX_APPWINDOW)
        Local $iExStyle = _WinGetExStyle($hWnd)
        If BitAND($iExStyle, $WS_EX_TOOLWINDOW) And Not BitAND($iExStyle, 0x00040000) Then ContinueLoop

        ; Passed all filters — add to list
        If $__g_WL_iItemCount >= $__g_WL_iMaxItems Then ExitLoop
        $__g_WL_iItemCount += 1
        $__g_WL_aHWNDs[$__g_WL_iItemCount] = $hWnd
    Next

    Return $__g_WL_iItemCount
EndFunc

; Name:        _WinGetExStyle
; Description: Gets the extended window style of a window handle
; Parameters:  $hWnd - window handle
; Return:      Extended style flags, or 0 on error
Func _WinGetExStyle($hWnd)
    Local $aResult = DllCall("user32.dll", "long", "GetWindowLongW", "hwnd", $hWnd, "int", -20)
    If @error Or Not IsArray($aResult) Then Return 0
    Return $aResult[0]
EndFunc

; Name:        __WL_CalcMaxChars
; Description: Calculates the maximum number of characters that fit in the panel width
; Parameters:  $iWidth - panel width in pixels
; Return:      Approximate character limit
Func __WL_CalcMaxChars($iWidth)
    ; Approximate: 7 pixels per character at font size 9, minus padding
    Local $iChars = Int(($iWidth - 20) / 7)
    If $iChars < 15 Then $iChars = 15
    If $iChars > 80 Then $iChars = 80
    Return $iChars
EndFunc

; Name:        __WL_CalcPosition
; Description: Calculates the window list popup position based on config anchor
; Parameters:  $sPosition - anchor string ("top-left", "top-right", "bottom-left", "bottom-right")
;              $iW - popup width
;              $iH - popup height
;              ByRef $iX - receives X position
;              ByRef $iY - receives Y position
Func __WL_CalcPosition($sPosition, $iW, $iH, ByRef $iX, ByRef $iY)
    Switch $sPosition
        Case "top-left"
            $iX = 10
            $iY = 10
        Case "top-right"
            $iX = @DesktopWidth - $iW - 10
            $iY = 10
        Case "bottom-left"
            $iX = 10
            $iY = @DesktopHeight - $iH - 50
        Case "bottom-right"
            $iX = @DesktopWidth - $iW - 10
            $iY = @DesktopHeight - $iH - 50
        Case Else
            ; Default to top-left
            $iX = 10
            $iY = 10
    EndSwitch

    ; Keep on screen
    If $iX < 0 Then $iX = 0
    If $iY < 0 Then $iY = 0
    If $iX + $iW > @DesktopWidth Then $iX = @DesktopWidth - $iW
    If $iY + $iH > @DesktopHeight Then $iY = @DesktopHeight - $iH
EndFunc

; #FUNCTIONS# ===================================================

; Name:        _WL_Show
; Description: Creates and shows the window list GUI for a given desktop
; Parameters:  $iDesktop - desktop index (1-based)
Func _WL_Show($iDesktop)
    If $__g_WL_bVisible Then _WL_Destroy()
    $__g_WL_iDesktop = $iDesktop

    ; Read config
    Local $iListW = _Cfg_GetWindowListWidth()
    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    Local $bShowSearch = _Cfg_GetWindowListSearch()
    Local $sPosition = _Cfg_GetWindowListPosition()

    ; Enumerate windows
    Local $iCount = __WL_EnumFilteredWindows($iDesktop)
    _Log_Debug("WL_Show: desktop=" & $iDesktop & " windows=" & $iCount)

    ; Determine if scroll mode is active
    Local $bScrollable = ($iCount > $iMaxVisible)

    ; Clamp scroll offset
    If $__g_WL_iScrollOffset < 0 Then $__g_WL_iScrollOffset = 0
    If $bScrollable And $__g_WL_iScrollOffset > $iCount - $iMaxVisible Then
        $__g_WL_iScrollOffset = $iCount - $iMaxVisible
    EndIf
    If Not $bScrollable Then $__g_WL_iScrollOffset = 0

    ; Calculate visible range
    Local $iVisibleCount = $iCount
    If $bScrollable Then $iVisibleCount = $iMaxVisible
    Local $iStart = $__g_WL_iScrollOffset + 1
    Local $iEnd = $__g_WL_iScrollOffset + $iVisibleCount
    If $iEnd > $iCount Then $iEnd = $iCount

    ; Calculate dimensions
    Local $iArrowH = 16
    Local $iSearchH = 0
    If $bShowSearch Then $iSearchH = 28
    Local $iExtraH = 0
    If $bScrollable Then $iExtraH = $iArrowH * 2

    ; Title bar height
    Local $iTitleH = 24

    ; Handle empty state
    Local $iEmptyH = 0
    If $iCount = 0 Then $iEmptyH = $THEME_ITEM_HEIGHT

    Local $iListH = $iTitleH + $iSearchH + $iVisibleCount * $THEME_ITEM_HEIGHT + $iEmptyH + 6 + $iExtraH

    ; Calculate position
    Local $iListX = 0, $iListY = 0
    __WL_CalcPosition($sPosition, $iListW, $iListH, $iListX, $iListY)

    ; Create popup
    $__g_WL_hGUI = _Theme_CreatePopup("WindowList", $iListW, $iListH, $iListX, $iListY)
    If $__g_WL_hGUI = 0 Then
        _Log_Error("WL_Show: Failed to create window list GUI")
        Return
    EndIf

    ; Ensure item ID array is large enough
    If UBound($__g_WL_aItemIDs) < $iVisibleCount + 1 Then
        ReDim $__g_WL_aItemIDs[$iVisibleCount + 1]
    EndIf

    $__g_WL_iHovered = 0
    $__g_WL_idScrollUp = 0
    $__g_WL_idScrollDown = 0
    $__g_WL_idSearchInput = 0

    Local $iContentY = 3

    ; Title label
    Local $sTitleText = _i18n_Format("WindowList.wl_title", "Windows on Desktop {1}", $iDesktop)
    Local $idTitle = GUICtrlCreateLabel(" " & $sTitleText, 4, $iContentY, $iListW - 8, $iTitleH, _
        BitOR($SS_CENTERIMAGE, $SS_LEFT))
    GUICtrlSetFont($idTitle, 9, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idTitle, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idTitle, $GUI_BKCOLOR_TRANSPARENT)
    $iContentY += $iTitleH

    ; Search input
    If $bShowSearch Then
        $__g_WL_idSearchInput = GUICtrlCreateInput("", 6, $iContentY + 2, $iListW - 12, $iSearchH - 4, _
            BitOR($ES_AUTOHSCROLL, $ES_LEFT))
        GUICtrlSetFont($__g_WL_idSearchInput, 9, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_WL_idSearchInput, $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_WL_idSearchInput, $THEME_BG_INPUT)
        GUICtrlSetTip($__g_WL_idSearchInput, _i18n("WindowList.wl_search_tip", "Type to search windows..."))
        $iContentY += $iSearchH
    EndIf

    ; Up scroll arrow
    If $bScrollable Then
        Local $sUpArrow = ""
        If $__g_WL_iScrollOffset > 0 Then $sUpArrow = ChrW(0x25B2)
        $__g_WL_idScrollUp = GUICtrlCreateLabel($sUpArrow, 4, $iContentY, $iListW - 8, $iArrowH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_WL_idScrollUp, 7, 400, 0, $THEME_FONT_SYMBOL)
        GUICtrlSetColor($__g_WL_idScrollUp, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_WL_idScrollUp, $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_WL_idScrollUp, 0)
        $iContentY += $iArrowH
    EndIf

    ; Calculate max characters for title truncation
    Local $iMaxChars = __WL_CalcMaxChars($iListW)

    ; Window items
    If $iCount = 0 Then
        ; Show empty state message
        Local $idEmpty = GUICtrlCreateLabel("  " & _i18n("WindowList.wl_empty", "No windows"), _
            4, $iContentY, $iListW - 8, $THEME_ITEM_HEIGHT, _
            BitOR($SS_CENTERIMAGE, $SS_LEFT))
        GUICtrlSetFont($idEmpty, 9, 400, 2, $THEME_FONT_MAIN) ; italic
        GUICtrlSetColor($idEmpty, $THEME_FG_DIM)
        GUICtrlSetBkColor($idEmpty, $GUI_BKCOLOR_TRANSPARENT)
    Else
        Local $iSlot
        For $iSlot = 1 To $iVisibleCount
            Local $iIdx = $__g_WL_iScrollOffset + $iSlot
            If $iIdx > $iCount Then ExitLoop

            Local $hWnd = $__g_WL_aHWNDs[$iIdx]
            Local $sTitle = WinGetTitle($hWnd)
            $sTitle = __WL_TruncateTitle($sTitle, $iMaxChars)

            ; Check if window is pinned — add indicator
            Local $bPinned = _VD_IsPinnedWindow($hWnd)
            Local $sPrefix = "  "
            If $bPinned Then $sPrefix = " " & ChrW(0x2022) & " " ; bullet for pinned

            Local $iY = $iContentY + ($iSlot - 1) * $THEME_ITEM_HEIGHT
            $__g_WL_aItemIDs[$iSlot] = GUICtrlCreateLabel($sPrefix & $sTitle, 4, $iY, $iListW - 8, $THEME_ITEM_HEIGHT, _
                BitOR($SS_LEFT, $SS_CENTERIMAGE, $SS_NOTIFY))
            GUICtrlSetFont($__g_WL_aItemIDs[$iSlot], 9, 400, 0, $THEME_FONT_MAIN)
            GUICtrlSetColor($__g_WL_aItemIDs[$iSlot], $THEME_FG_NORMAL)
            GUICtrlSetBkColor($__g_WL_aItemIDs[$iSlot], $GUI_BKCOLOR_TRANSPARENT)
            GUICtrlSetCursor($__g_WL_aItemIDs[$iSlot], 0)
        Next
    EndIf

    ; Down scroll arrow
    If $bScrollable Then
        Local $iDownY = $iContentY + $iVisibleCount * $THEME_ITEM_HEIGHT
        Local $sDownArrow = ""
        If $iEnd < $iCount Then $sDownArrow = ChrW(0x25BC)
        $__g_WL_idScrollDown = GUICtrlCreateLabel($sDownArrow, 4, $iDownY, $iListW - 8, $iArrowH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_WL_idScrollDown, 7, 400, 0, $THEME_FONT_SYMBOL)
        GUICtrlSetColor($__g_WL_idScrollDown, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_WL_idScrollDown, $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetCursor($__g_WL_idScrollDown, 0)
    EndIf

    _Theme_FadeIn($__g_WL_hGUI, Default, "list")
    $__g_WL_bVisible = True

    ; Start auto-refresh timer if enabled
    If _Cfg_GetWindowListAutoRefresh() Then
        $__g_WL_hRefreshTimer = TimerInit()
    EndIf

    ; Initialize auto-hide timer
    $__g_WL_hAutoHideTimer = TimerInit()
EndFunc

; Name:        _WL_Destroy
; Description: Destroys the window list GUI and resets all state
Func _WL_Destroy()
    _WL_CtxDestroy()
    If $__g_WL_hGUI <> 0 Then
        _Theme_FadeOut($__g_WL_hGUI, "list")
        $__g_WL_hGUI = 0
    EndIf
    $__g_WL_bVisible = False
    $__g_WL_iDesktop = 0
    $__g_WL_iHovered = 0
    $__g_WL_iItemCount = 0
    $__g_WL_iScrollOffset = 0
    $__g_WL_idScrollUp = 0
    $__g_WL_idScrollDown = 0
    $__g_WL_idSearchInput = 0
    $__g_WL_sLastSearch = ""
    $__g_WL_hRefreshTimer = 0
    $__g_WL_hAutoHideTimer = 0
EndFunc

; Name:        _WL_Toggle
; Description: Toggles the window list panel visibility
; Parameters:  $iDesktop - desktop index (1-based)
Func _WL_Toggle($iDesktop)
    If $__g_WL_bVisible Then
        _WL_Destroy()
    Else
        _WL_Show($iDesktop)
    EndIf
EndFunc

; Name:        _WL_IsVisible
; Description: Returns whether the window list is currently visible
; Return:      True/False
Func _WL_IsVisible()
    Return $__g_WL_bVisible
EndFunc

; Name:        _WL_GetGUI
; Description: Returns the window list GUI handle
; Return:      GUI handle or 0
Func _WL_GetGUI()
    Return $__g_WL_hGUI
EndFunc

; Name:        _WL_Refresh
; Description: Rebuilds the window list (e.g. on desktop change or auto-refresh tick)
; Parameters:  $iDesktop - desktop index (1-based)
Func _WL_Refresh($iDesktop)
    If Not $__g_WL_bVisible Then Return
    ; Save scroll offset to restore after rebuild
    Local $iSavedScroll = $__g_WL_iScrollOffset
    _WL_Destroy()
    $__g_WL_iScrollOffset = $iSavedScroll
    _WL_Show($iDesktop)
EndFunc

; Name:        _WL_CheckAutoRefresh
; Description: Checks if auto-refresh interval has elapsed and refreshes if so.
;              Call from main loop.
; Parameters:  $iDesktop - current desktop index (1-based)
Func _WL_CheckAutoRefresh($iDesktop)
    If Not $__g_WL_bVisible Then Return
    If Not _Cfg_GetWindowListAutoRefresh() Then Return
    If $__g_WL_hRefreshTimer = 0 Then Return
    If TimerDiff($__g_WL_hRefreshTimer) < _Cfg_GetWindowListRefreshInterval() Then Return

    ; Don't refresh while context menu is open
    If $__g_WL_bCtxVisible Then
        $__g_WL_hRefreshTimer = TimerInit()
        Return
    EndIf

    _WL_Refresh($iDesktop)
EndFunc

; Name:        _WL_HandleClick
; Description: Processes a click on a window list item or scroll arrow
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      Window HWND if a window item was clicked, -1 for scroll up, -2 for scroll down, or 0 for no match
Func _WL_HandleClick($msg)
    If $msg <= 0 Then Return 0

    ; Handle scroll arrow clicks
    If $__g_WL_idScrollUp <> 0 And $msg = $__g_WL_idScrollUp Then Return -1
    If $__g_WL_idScrollDown <> 0 And $msg = $__g_WL_idScrollDown Then Return -2

    ; Match against window item IDs
    If $__g_WL_iItemCount < 1 Then Return 0

    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    Local $iVisibleCount = $__g_WL_iItemCount
    If $iVisibleCount > $iMaxVisible Then $iVisibleCount = $iMaxVisible

    Local $iSlot
    For $iSlot = 1 To $iVisibleCount
        If $iSlot >= UBound($__g_WL_aItemIDs) Then ExitLoop
        If $msg = $__g_WL_aItemIDs[$iSlot] Then
            ; Convert visual slot to actual window index
            Local $iIdx = $iSlot + $__g_WL_iScrollOffset
            If $iIdx >= 1 And $iIdx <= $__g_WL_iItemCount And $iIdx < UBound($__g_WL_aHWNDs) Then
                Return $__g_WL_aHWNDs[$iIdx]
            EndIf
        EndIf
    Next

    Return 0
EndFunc

; Name:        _WL_CheckHover
; Description: Manages hover highlighting on the window list. Call from main loop.
Func _WL_CheckHover()
    If Not $__g_WL_bVisible Or $__g_WL_hGUI = 0 Then Return
    If $__g_WL_iItemCount < 1 Then Return

    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    Local $iVisibleCount = $__g_WL_iItemCount
    If $iVisibleCount > $iMaxVisible Then $iVisibleCount = $iMaxVisible

    Local $aCursor = GUIGetCursorInfo($__g_WL_hGUI)
    If @error Then
        ; Cursor left the window list
        If $__g_WL_iHovered > 0 And $__g_WL_iHovered < UBound($__g_WL_aItemIDs) Then
            _Theme_RemoveHover($__g_WL_aItemIDs[$__g_WL_iHovered], $THEME_FG_NORMAL)
        EndIf
        $__g_WL_iHovered = 0
        Return
    EndIf

    ; Find hovered item (slot index)
    Local $iFound = 0
    Local $iSlot
    For $iSlot = 1 To $iVisibleCount
        If $iSlot >= UBound($__g_WL_aItemIDs) Then ExitLoop
        If $aCursor[4] = $__g_WL_aItemIDs[$iSlot] Then
            $iFound = $iSlot
            ExitLoop
        EndIf
    Next

    ; Update hover highlight
    If $iFound <> $__g_WL_iHovered Then
        ; Remove old hover
        If $__g_WL_iHovered > 0 And $__g_WL_iHovered <= $iVisibleCount And $__g_WL_iHovered < UBound($__g_WL_aItemIDs) Then
            _Theme_RemoveHover($__g_WL_aItemIDs[$__g_WL_iHovered], $THEME_FG_NORMAL)
        EndIf
        $__g_WL_iHovered = $iFound
        ; Apply new hover
        If $__g_WL_iHovered > 0 And $__g_WL_iHovered <= $iVisibleCount And $__g_WL_iHovered < UBound($__g_WL_aItemIDs) Then
            _Theme_ApplyHover($__g_WL_aItemIDs[$__g_WL_iHovered], $THEME_FG_WHITE, $THEME_BG_HOVER)
        EndIf
    EndIf

    ; Scroll arrow hover highlighting
    If $__g_WL_idScrollUp <> 0 And $aCursor[4] = $__g_WL_idScrollUp Then
        GUICtrlSetColor($__g_WL_idScrollUp, $THEME_FG_WHITE)
    ElseIf $__g_WL_idScrollUp <> 0 Then
        GUICtrlSetColor($__g_WL_idScrollUp, $THEME_FG_DIM)
    EndIf

    If $__g_WL_idScrollDown <> 0 And $aCursor[4] = $__g_WL_idScrollDown Then
        GUICtrlSetColor($__g_WL_idScrollDown, $THEME_FG_WHITE)
    ElseIf $__g_WL_idScrollDown <> 0 Then
        GUICtrlSetColor($__g_WL_idScrollDown, $THEME_FG_DIM)
    EndIf

    ; Reset auto-hide timer when cursor is over the list
    $__g_WL_hAutoHideTimer = TimerInit()
EndFunc

; Name:        _WL_CheckAutoHide
; Description: Auto-hides the window list if cursor is not over it or the main GUI
; Parameters:  $hMainGUI - handle to the main widget GUI
; Return:      True if the list was auto-hidden, False otherwise
Func _WL_CheckAutoHide($hMainGUI)
    If Not $__g_WL_bVisible Then Return False
    If $__g_WL_bCtxVisible Then Return False ; don't auto-hide while context menu is open
    If $__g_WL_hAutoHideTimer = 0 Then Return False
    If TimerDiff($__g_WL_hAutoHideTimer) <= _Cfg_GetAutoHideTimeout() Then Return False
    If _Theme_IsCursorOverWindow($__g_WL_hGUI) Then Return False
    If _Theme_IsCursorOverWindow($hMainGUI) Then Return False
    _WL_Destroy()
    Return True
EndFunc

; Name:        _WL_ScrollUp
; Description: Scrolls the window list up by one item and refreshes in-place
Func _WL_ScrollUp()
    If $__g_WL_iScrollOffset > 0 Then
        $__g_WL_iScrollOffset -= 1
        __WL_RefreshScrollView()
    EndIf
EndFunc

; Name:        _WL_ScrollDown
; Description: Scrolls the window list down by one item and refreshes in-place
Func _WL_ScrollDown()
    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    If $__g_WL_iScrollOffset + $iMaxVisible < $__g_WL_iItemCount Then
        $__g_WL_iScrollOffset += 1
        __WL_RefreshScrollView()
    EndIf
EndFunc

; Name:        __WL_RefreshScrollView
; Description: Updates existing list controls in-place after scroll offset changes.
;              Avoids flicker by not destroying/recreating the GUI.
Func __WL_RefreshScrollView()
    If Not $__g_WL_bVisible Or $__g_WL_hGUI = 0 Then Return
    If $__g_WL_iItemCount < 1 Then Return

    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    Local $iVisibleCount = $__g_WL_iItemCount
    If $iVisibleCount > $iMaxVisible Then $iVisibleCount = $iMaxVisible

    Local $iListW = _Cfg_GetWindowListWidth()
    Local $iMaxChars = __WL_CalcMaxChars($iListW)

    Local $iSlot
    For $iSlot = 1 To $iVisibleCount
        If $iSlot >= UBound($__g_WL_aItemIDs) Then ExitLoop
        Local $iIdx = $__g_WL_iScrollOffset + $iSlot
        If $iIdx > $__g_WL_iItemCount Or $iIdx >= UBound($__g_WL_aHWNDs) Then ExitLoop

        Local $hWnd = $__g_WL_aHWNDs[$iIdx]
        Local $sTitle = WinGetTitle($hWnd)
        $sTitle = __WL_TruncateTitle($sTitle, $iMaxChars)

        Local $bPinned = _VD_IsPinnedWindow($hWnd)
        Local $sPrefix = "  "
        If $bPinned Then $sPrefix = " " & ChrW(0x2022) & " "

        GUICtrlSetData($__g_WL_aItemIDs[$iSlot], $sPrefix & $sTitle)
        GUICtrlSetColor($__g_WL_aItemIDs[$iSlot], $THEME_FG_NORMAL)
        GUICtrlSetBkColor($__g_WL_aItemIDs[$iSlot], $GUI_BKCOLOR_TRANSPARENT)
    Next

    ; Update scroll arrow text (filled vs empty based on scroll position)
    If $__g_WL_idScrollUp <> 0 Then
        If $__g_WL_iScrollOffset > 0 Then
            GUICtrlSetData($__g_WL_idScrollUp, ChrW(0x25B2))
        Else
            GUICtrlSetData($__g_WL_idScrollUp, "")
        EndIf
    EndIf
    If $__g_WL_idScrollDown <> 0 Then
        If $__g_WL_iScrollOffset + $iMaxVisible < $__g_WL_iItemCount Then
            GUICtrlSetData($__g_WL_idScrollDown, ChrW(0x25BC))
        Else
            GUICtrlSetData($__g_WL_idScrollDown, "")
        EndIf
    EndIf

    ; Reset hover state since items shifted
    $__g_WL_iHovered = 0
EndFunc

; Name:        _WL_SearchFilter
; Description: Filters window list items by search query (case-insensitive)
; Parameters:  $sQuery - search string (empty string shows all)
Func _WL_SearchFilter($sQuery)
    If Not $__g_WL_bVisible Or $__g_WL_hGUI = 0 Then Return
    If $__g_WL_iItemCount < 1 Then Return

    $__g_WL_sLastSearch = $sQuery

    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    Local $iVisibleCount = $__g_WL_iItemCount
    If $iVisibleCount > $iMaxVisible Then $iVisibleCount = $iMaxVisible

    Local $iSlot
    For $iSlot = 1 To $iVisibleCount
        If $iSlot >= UBound($__g_WL_aItemIDs) Then ExitLoop
        Local $iIdx = $__g_WL_iScrollOffset + $iSlot
        If $iIdx > $__g_WL_iItemCount Or $iIdx >= UBound($__g_WL_aHWNDs) Then ExitLoop

        If $sQuery = "" Then
            ; Show all items
            GUICtrlSetState($__g_WL_aItemIDs[$iSlot], $GUI_SHOW)
        Else
            ; Check if window title contains query (case-insensitive)
            Local $hWnd = $__g_WL_aHWNDs[$iIdx]
            Local $sTitle = WinGetTitle($hWnd)
            If StringInStr(StringLower($sTitle), StringLower($sQuery)) Then
                GUICtrlSetState($__g_WL_aItemIDs[$iSlot], $GUI_SHOW)
            Else
                GUICtrlSetState($__g_WL_aItemIDs[$iSlot], $GUI_HIDE)
            EndIf
        EndIf
    Next
EndFunc

; Name:        _WL_CheckSearchInput
; Description: Reads the search input and applies filter if changed. Call from main loop.
Func _WL_CheckSearchInput()
    If Not $__g_WL_bVisible Or $__g_WL_idSearchInput = 0 Then Return
    Local $sQuery = GUICtrlRead($__g_WL_idSearchInput)
    If $sQuery <> $__g_WL_sLastSearch Then
        _WL_SearchFilter($sQuery)
    EndIf
EndFunc

; Name:        _WL_GetDesktop
; Description: Returns the desktop index the window list was opened for
; Return:      Desktop index (1-based), or 0 if not visible
Func _WL_GetDesktop()
    Return $__g_WL_iDesktop
EndFunc

; =============================================
; WINDOW LIST — CONTEXT MENU
; =============================================

; Name:        _WL_CtxShow
; Description: Creates and shows a context menu for a window in the list
; Parameters:  $hTargetWnd - window handle of the targeted window
Func _WL_CtxShow($hTargetWnd)
    If $__g_WL_bCtxVisible Then _WL_CtxDestroy()
    $__g_WL_hCtxTarget = $hTargetWnd

    ; Determine available actions based on window state
    Local $iWinState = WinGetState($hTargetWnd)
    Local $bMinimized = BitAND($iWinState, 16) ; 16 = minimized
    Local $bMaximized = BitAND($iWinState, 32) ; 32 = maximized
    Local $bPinned = _VD_IsPinnedWindow($hTargetWnd)

    ; Check if window is on a different desktop
    Local $iWinDesktop = _VD_GetWindowDesktopNumber($hTargetWnd)
    Local $bDifferentDesktop = ($iWinDesktop > 0 And $iWinDesktop <> $__g_WL_iDesktop)

    ; Count menu items to calculate height
    Local $iMenuW = 200
    Local $iSepH = 1
    Local $iItemCount = 4 ; send_next, send_prev, send_new, pin
    If $bDifferentDesktop Then $iItemCount += 2 ; goto + pull

    ; Window state actions: always show at least one of minimize/maximize/restore
    If $bMinimized Then
        $iItemCount += 1 ; restore only
    ElseIf $bMaximized Then
        $iItemCount += 2 ; minimize + restore
    Else
        $iItemCount += 2 ; minimize + maximize
    EndIf
    $iItemCount += 1 ; close

    ; 2 separators
    Local $iMenuH = $iItemCount * $THEME_MENU_ITEM_H + 2 * ($iSepH + 4) + 12

    ; Position near cursor
    Local $iMenuX = $__g_Theme_iCachedCursorX
    Local $iMenuY = $__g_Theme_iCachedCursorY - $iMenuH
    ; Keep menu on screen
    If $iMenuY < 0 Then $iMenuY = $__g_Theme_iCachedCursorY
    If $iMenuX + $iMenuW > @DesktopWidth Then $iMenuX = @DesktopWidth - $iMenuW - 4
    If $iMenuX < 0 Then $iMenuX = 0

    $__g_WL_hCtxGUI = _Theme_CreatePopup("WLCtx", $iMenuW, $iMenuH, $iMenuX, $iMenuY, $THEME_BG_POPUP, $THEME_ALPHA_MENU)
    If $__g_WL_hCtxGUI = 0 Then
        _Log_Error("WL_CtxShow: Failed to create context menu GUI")
        Return
    EndIf

    ; Reset all item IDs
    $__g_WL_iCtxSendNext = 0
    $__g_WL_iCtxSendPrev = 0
    $__g_WL_iCtxSendNew = 0
    $__g_WL_iCtxPull = 0
    $__g_WL_iCtxPin = 0
    $__g_WL_iCtxGoTo = 0
    $__g_WL_iCtxMinimize = 0
    $__g_WL_iCtxMaximize = 0
    $__g_WL_iCtxRestore = 0
    $__g_WL_iCtxClose = 0

    Local $iY = 4

    ; Send to Next Desktop
    $__g_WL_iCtxSendNext = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_send_next", "Send to Next Desktop"), _
        4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    ; Send to Previous Desktop
    $__g_WL_iCtxSendPrev = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_send_prev", "Send to Previous Desktop"), _
        4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    ; Send to New Desktop
    $__g_WL_iCtxSendNew = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_send_new", "Send to New Desktop"), _
        4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    ; Pull to current (only if window is on a different desktop)
    If $bDifferentDesktop Then
        $__g_WL_iCtxPull = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_pull_to_current", "Pull to Current Desktop"), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    ; Separator
    GUICtrlCreateLabel("", 8, $iY + 2, $iMenuW - 16, $iSepH)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += $iSepH + 4

    ; Pin / Unpin
    Local $sPinText = ""
    If $bPinned Then
        $sPinText = "  " & _i18n("WindowList.wl_unpin", "Unpin from All Desktops")
    Else
        $sPinText = "  " & _i18n("WindowList.wl_pin", "Pin to All Desktops")
    EndIf
    $__g_WL_iCtxPin = _Theme_CreateMenuItem($sPinText, 4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    $iY += $THEME_MENU_ITEM_H

    ; Go to Window's Desktop (only if on different desktop)
    If $bDifferentDesktop Then
        $__g_WL_iCtxGoTo = _Theme_CreateMenuItem("  " & _i18n_Format("WindowList.wl_goto", "Go to Desktop {1}", $iWinDesktop), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    ; Separator
    GUICtrlCreateLabel("", 8, $iY + 2, $iMenuW - 16, $iSepH)
    GUICtrlSetBkColor(-1, $THEME_BG_SEPARATOR)
    $iY += $iSepH + 4

    ; Window state actions
    If $bMinimized Then
        ; Minimized: show Restore only
        $__g_WL_iCtxRestore = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_restore", "Restore"), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    ElseIf $bMaximized Then
        ; Maximized: show Minimize + Restore
        $__g_WL_iCtxMinimize = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_minimize", "Minimize"), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
        $__g_WL_iCtxRestore = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_restore", "Restore"), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    Else
        ; Normal: show Minimize + Maximize
        $__g_WL_iCtxMinimize = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_minimize", "Minimize"), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
        $__g_WL_iCtxMaximize = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_maximize", "Maximize"), _
            4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
        $iY += $THEME_MENU_ITEM_H
    EndIf

    ; Close (red text for danger)
    $__g_WL_iCtxClose = _Theme_CreateMenuItem("  " & _i18n("WindowList.wl_close", "Close"), _
        4, $iY, $iMenuW - 8, $THEME_MENU_ITEM_H)
    GUICtrlSetColor($__g_WL_iCtxClose, 0xCC6666) ; muted red for danger

    GUISetState(@SW_SHOW, $__g_WL_hCtxGUI)
    $__g_WL_bCtxVisible = True
    $__g_WL_iCtxHovered = 0
EndFunc

; Name:        _WL_CtxDestroy
; Description: Destroys the window list context menu and resets state
Func _WL_CtxDestroy()
    If $__g_WL_hCtxGUI <> 0 Then
        GUIDelete($__g_WL_hCtxGUI)
        $__g_WL_hCtxGUI = 0
    EndIf
    $__g_WL_bCtxVisible = False
    $__g_WL_hCtxTarget = 0
    $__g_WL_iCtxHovered = 0
    $__g_WL_iCtxSendNext = 0
    $__g_WL_iCtxSendPrev = 0
    $__g_WL_iCtxSendNew = 0
    $__g_WL_iCtxPull = 0
    $__g_WL_iCtxPin = 0
    $__g_WL_iCtxGoTo = 0
    $__g_WL_iCtxMinimize = 0
    $__g_WL_iCtxMaximize = 0
    $__g_WL_iCtxRestore = 0
    $__g_WL_iCtxClose = 0
EndFunc

; Name:        _WL_CtxIsVisible
; Description: Returns whether the window list context menu is visible
; Return:      True/False
Func _WL_CtxIsVisible()
    Return $__g_WL_bCtxVisible
EndFunc

; Name:        _WL_CtxGetGUI
; Description: Returns the window list context menu GUI handle
; Return:      GUI handle or 0
Func _WL_CtxGetGUI()
    Return $__g_WL_hCtxGUI
EndFunc

; Name:        _WL_GetCtxTarget
; Description: Returns the window handle targeted by the context menu
; Return:      Window HWND, or 0 if no menu
Func _WL_GetCtxTarget()
    Return $__g_WL_hCtxTarget
EndFunc

; Name:        _WL_CtxHandleClick
; Description: Processes a click on a window list context menu item
; Parameters:  $msg - GUI message from GUIGetMsg
; Return:      Action string: "send_next", "send_prev", "send_new", "pull", "pin",
;              "goto", "minimize", "maximize", "restore", "close", or "" if no match
Func _WL_CtxHandleClick($msg)
    If $msg <= 0 Then Return ""
    If $__g_WL_iCtxSendNext <> 0 And $msg = $__g_WL_iCtxSendNext Then Return "send_next"
    If $__g_WL_iCtxSendPrev <> 0 And $msg = $__g_WL_iCtxSendPrev Then Return "send_prev"
    If $__g_WL_iCtxSendNew <> 0 And $msg = $__g_WL_iCtxSendNew Then Return "send_new"
    If $__g_WL_iCtxPull <> 0 And $msg = $__g_WL_iCtxPull Then Return "pull"
    If $__g_WL_iCtxPin <> 0 And $msg = $__g_WL_iCtxPin Then Return "pin"
    If $__g_WL_iCtxGoTo <> 0 And $msg = $__g_WL_iCtxGoTo Then Return "goto"
    If $__g_WL_iCtxMinimize <> 0 And $msg = $__g_WL_iCtxMinimize Then Return "minimize"
    If $__g_WL_iCtxMaximize <> 0 And $msg = $__g_WL_iCtxMaximize Then Return "maximize"
    If $__g_WL_iCtxRestore <> 0 And $msg = $__g_WL_iCtxRestore Then Return "restore"
    If $__g_WL_iCtxClose <> 0 And $msg = $__g_WL_iCtxClose Then Return "close"
    Return ""
EndFunc

; Name:        _WL_CtxCheckHover
; Description: Updates hover highlighting on the window list context menu. Call from main loop.
Func _WL_CtxCheckHover()
    If Not $__g_WL_bCtxVisible Or $__g_WL_hCtxGUI = 0 Then Return
    Local $aCursor = GUIGetCursorInfo($__g_WL_hCtxGUI)
    If @error Then
        ; Cursor left the context menu
        If $__g_WL_iCtxHovered <> 0 Then
            Local $iFg = $THEME_FG_MENU
            If $__g_WL_iCtxHovered = $__g_WL_iCtxClose Then $iFg = 0xCC6666
            _Theme_RemoveHover($__g_WL_iCtxHovered, $iFg)
            $__g_WL_iCtxHovered = 0
        EndIf
        Return
    EndIf

    ; Find which item is hovered
    Local $iFound = 0
    If $__g_WL_iCtxSendNext <> 0 And $aCursor[4] = $__g_WL_iCtxSendNext Then $iFound = $__g_WL_iCtxSendNext
    If $__g_WL_iCtxSendPrev <> 0 And $aCursor[4] = $__g_WL_iCtxSendPrev Then $iFound = $__g_WL_iCtxSendPrev
    If $__g_WL_iCtxSendNew <> 0 And $aCursor[4] = $__g_WL_iCtxSendNew Then $iFound = $__g_WL_iCtxSendNew
    If $__g_WL_iCtxPull <> 0 And $aCursor[4] = $__g_WL_iCtxPull Then $iFound = $__g_WL_iCtxPull
    If $__g_WL_iCtxPin <> 0 And $aCursor[4] = $__g_WL_iCtxPin Then $iFound = $__g_WL_iCtxPin
    If $__g_WL_iCtxGoTo <> 0 And $aCursor[4] = $__g_WL_iCtxGoTo Then $iFound = $__g_WL_iCtxGoTo
    If $__g_WL_iCtxMinimize <> 0 And $aCursor[4] = $__g_WL_iCtxMinimize Then $iFound = $__g_WL_iCtxMinimize
    If $__g_WL_iCtxMaximize <> 0 And $aCursor[4] = $__g_WL_iCtxMaximize Then $iFound = $__g_WL_iCtxMaximize
    If $__g_WL_iCtxRestore <> 0 And $aCursor[4] = $__g_WL_iCtxRestore Then $iFound = $__g_WL_iCtxRestore
    If $__g_WL_iCtxClose <> 0 And $aCursor[4] = $__g_WL_iCtxClose Then $iFound = $__g_WL_iCtxClose

    ; No change — skip update
    If $iFound = $__g_WL_iCtxHovered Then Return

    ; Remove old hover
    If $__g_WL_iCtxHovered <> 0 Then
        Local $iFgOld = $THEME_FG_MENU
        If $__g_WL_iCtxHovered = $__g_WL_iCtxClose Then $iFgOld = 0xCC6666
        _Theme_RemoveHover($__g_WL_iCtxHovered, $iFgOld)
    EndIf

    ; Apply new hover
    $__g_WL_iCtxHovered = $iFound
    If $__g_WL_iCtxHovered <> 0 Then
        _Theme_ApplyHover($__g_WL_iCtxHovered, $THEME_FG_WHITE, $THEME_BG_HOVER)
    EndIf
EndFunc

; Name:        _WL_CtxCheckAutoHide
; Description: Auto-dismisses the context menu when cursor moves away from both
;              the context menu and the window list
; Return:      True if dismissed, False otherwise
Func _WL_CtxCheckAutoHide()
    If Not $__g_WL_bCtxVisible Or $__g_WL_hCtxGUI = 0 Then Return False
    If _Theme_IsCursorOverWindow($__g_WL_hCtxGUI) Then Return False
    If _Theme_IsCursorOverWindow($__g_WL_hGUI) Then Return False
    _WL_CtxDestroy()
    Return True
EndFunc

; Name:        _WL_GetItemAtPos
; Description: Returns which window list row the mouse cursor is over
; Return:      Window HWND if cursor is over an item, or 0 if none
Func _WL_GetItemAtPos()
    If Not $__g_WL_bVisible Or $__g_WL_hGUI = 0 Then Return 0
    If $__g_WL_iItemCount < 1 Then Return 0

    Local $iMaxVisible = _Cfg_GetWindowListMaxVisible()
    Local $iVisibleCount = $__g_WL_iItemCount
    If $iVisibleCount > $iMaxVisible Then $iVisibleCount = $iMaxVisible

    Local $aCursor = GUIGetCursorInfo($__g_WL_hGUI)
    If @error Then Return 0

    Local $iSlot
    For $iSlot = 1 To $iVisibleCount
        If $iSlot >= UBound($__g_WL_aItemIDs) Then ExitLoop
        If $aCursor[4] = $__g_WL_aItemIDs[$iSlot] Then
            Local $iIdx = $iSlot + $__g_WL_iScrollOffset
            If $iIdx >= 1 And $iIdx <= $__g_WL_iItemCount And $iIdx < UBound($__g_WL_aHWNDs) Then
                Return $__g_WL_aHWNDs[$iIdx]
            EndIf
        EndIf
    Next

    Return 0
EndFunc
