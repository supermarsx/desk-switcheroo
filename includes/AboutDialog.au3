#include-once
#include "Theme.au3"

; #INDEX# =======================================================
; Title .........: AboutDialog
; Description ....: About dialog with credit links and auto-close timeout
; Author .........: Mariana
; ===============================================================

; Extern globals from main script
Global $APP_VERSION, $VK_RETURN, $VK_ESCAPE, $VK_KEYDOWN

; Name:        _ShowAbout
; Description: About dialog with credit links and 15-second auto-close timeout
Func _ShowAbout()
    Local $iDlgW = 350, $iDlgH = 230
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("About", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Icon + Title (side by side)
    Local $sIconPath = @ScriptDir & "\assets\desk_switcheroo.ico"
    Local $iTitleX = 14
    If FileExists($sIconPath) Then
        GUICtrlCreateIcon($sIconPath, -1, 14, 12, 32, 32)
        $iTitleX = 54
    EndIf

    GUICtrlCreateLabel("Desk Switcheroo v" & $APP_VERSION, $iTitleX, 10, $iDlgW - $iTitleX - 14, 22)
    GUICtrlSetFont(-1, 11, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlCreateLabel("Lightweight virtual desktop switcher for Windows." & @CRLF & _
        "Navigate, rename, peek, and manage desktops" & @CRLF & _
        "from a compact taskbar widget." & @CRLF & _
        "Created by supermarsx. Built with AutoIt.", $iTitleX, 36, $iDlgW - $iTitleX - 14, 56)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_NORMAL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $iLY = 90
    GUICtrlCreateLabel("Repository:", 14, $iLY, 70, 16)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_DIM)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idLinkRepo = GUICtrlCreateLabel("github.com/supermarsx/desk-switcheroo", 86, $iLY, 240, 16, $SS_NOTIFY)
    GUICtrlSetFont($idLinkRepo, 8, 400, 4, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLinkRepo, $THEME_FG_LINK)
    GUICtrlSetBkColor($idLinkRepo, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idLinkRepo, 0)

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

    Local $iBtnW = 64, $iBtnH = 26
    Local $idClose = GUICtrlCreateLabel("Close", ($iDlgW - $iBtnW) / 2, $iDlgH - 36, $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($idClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($idClose, 0)

    GUISetState(@SW_SHOW, $hDlg)

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

        Local $retKey = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_RETURN)
        If Not @error And BitAND($retKey[0], $VK_KEYDOWN) <> 0 Then ExitLoop
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $VK_ESCAPE)
        If Not @error And BitAND($retEsc[0], $VK_KEYDOWN) <> 0 Then ExitLoop

        If TimerDiff($hTimer) >= 15000 Then ExitLoop

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
