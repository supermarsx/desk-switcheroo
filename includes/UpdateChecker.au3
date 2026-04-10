#include-once
#include "Theme.au3"
#include "Config.au3"
#include "Logger.au3"

; #INDEX# =======================================================
; Title .........: UpdateChecker
; Description ....: Auto-update checker and portable download with progress
; Author .........: Mariana
; ===============================================================

; Extern globals from main script
Global $APP_VERSION, $iTaskbarY, $iTaskbarH
Global $__g_hInetDownload, $__g_sInetTempFile

; Name:        _UC_AdlibCheck
; Description: Starts a non-blocking download of the GitHub releases API
Func _UC_AdlibCheck()
    If $__g_hInetDownload <> 0 Then Return
    $__g_sInetTempFile = @TempDir & "\desk_switcheroo_update_check.tmp"
    $__g_hInetDownload = InetGet("https://api.github.com/repos/supermarsx/desk-switcheroo/releases/latest", _
        $__g_sInetTempFile, 1, 1)
    If @error Then
        $__g_hInetDownload = 0
        _Log_Warn("Update check: failed to start download")
    EndIf
EndFunc

; Name:        _UC_CheckResult
; Description: Called from main loop to check if background download completed
Func _UC_CheckResult()
    If $__g_hInetDownload = 0 Then Return
    If Not InetGetInfo($__g_hInetDownload, 2) Then Return

    Local $bSuccess = InetGetInfo($__g_hInetDownload, 3)
    InetClose($__g_hInetDownload)
    $__g_hInetDownload = 0

    If Not $bSuccess Then
        _Log_Warn("Update check: download failed")
        If FileExists($__g_sInetTempFile) Then FileDelete($__g_sInetTempFile)
        Return
    EndIf

    Local $sJson = FileRead($__g_sInetTempFile)
    FileDelete($__g_sInetTempFile)
    If $sJson = "" Then Return

    Local $aMatch = StringRegExp($sJson, '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    If @error Or UBound($aMatch) < 1 Then Return

    Local $sLatest = $aMatch[0]
    _Log_Info("Update check: latest release is v" & $sLatest)

    Static $sLastShown = ""
    If $sLatest <> $sLastShown Then
        $sLastShown = $sLatest
        _Theme_Toast("Update available: v" & $sLatest, 0, $iTaskbarY + $iTaskbarH + 4, 3000, $TOAST_INFO)
    EndIf
EndFunc

; Name:        _UC_FetchReleaseJson
; Description: Non-blocking fetch of GitHub releases API with 10s timeout
; Return:      JSON string, or "" on failure (shows toast on error)
Func __UC_FetchReleaseJson($sLabel)
    Local $iDlgW = 320, $iDlgH = 100
    Local $hDlg = _Theme_CreatePopup($sLabel, $iDlgW, $iDlgH, _
        (@DesktopWidth - $iDlgW) / 2, (@DesktopHeight - $iDlgH) / 2, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)
    GUICtrlCreateLabel($sLabel & "...", 14, 14, $iDlgW - 28, 20)
    GUICtrlSetFont(-1, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUISetState(@SW_SHOW, $hDlg)
    Sleep(50)

    Local $sUrl = "https://api.github.com/repos/supermarsx/desk-switcheroo/releases/latest"
    Local $sTmp = @TempDir & "\ds_uc_" & @AutoItPID & ".tmp"
    Local $hInet = InetGet($sUrl, $sTmp, 1, 1)
    Local $hTimeout = TimerInit()
    While Not InetGetInfo($hInet, 2)
        If TimerDiff($hTimeout) > 10000 Then
            InetClose($hInet)
            FileDelete($sTmp)
            GUIDelete($hDlg)
            _Theme_Toast("Connection timed out", 0, $iTaskbarY + $iTaskbarH + 4, 2000, $TOAST_ERROR)
            Return ""
        EndIf
        Sleep(50)
    WEnd
    InetClose($hInet)
    GUIDelete($hDlg)
    Local $sJson = FileRead($sTmp)
    FileDelete($sTmp)
    If $sJson = "" Then
        _Theme_Toast("Connection failed", 0, $iTaskbarY + $iTaskbarH + 4, 2000, $TOAST_ERROR)
    EndIf
    Return $sJson
EndFunc

; Name:        _UC_CheckNow
; Description: Manually triggers an update check with themed multi-phase dialog
Func _UC_CheckNow()
    _Log_Info("Manual update check triggered")

    Local $sJson = __UC_FetchReleaseJson("Checking for updates")
    If $sJson = "" Then Return

    Local $aVer = StringRegExp($sJson, '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    Local $sLatest = "unknown"
    If Not @error And UBound($aVer) >= 1 Then $sLatest = $aVer[0]

    Local $aDate = StringRegExp($sJson, '"published_at"\s*:\s*"([^T"]+)', 1)
    Local $sDate = "unknown"
    If Not @error And UBound($aDate) >= 1 Then $sDate = $aDate[0]

    If $sLatest = "unknown" Then
        _Theme_Toast("Could not parse release info", 0, $iTaskbarY + $iTaskbarH + 4, 2000, $TOAST_WARNING)
        Return
    EndIf

    _Log_Info("Update check: latest release is v" & $sLatest)
    Local $bUpdateAvailable = ($sLatest <> $APP_VERSION)

    Local $iDlgW = 320, $iDlgH = 140
    Local $hDlg = _Theme_CreatePopup("Update Check", $iDlgW, $iDlgH, _
        (@DesktopWidth - $iDlgW) / 2, (@DesktopHeight - $iDlgH) / 2, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    If $bUpdateAvailable Then
        GUICtrlCreateLabel(ChrW(0x2B06) & " Update available!", 14, 10, $iDlgW - 28, 20)
    Else
        GUICtrlCreateLabel(ChrW(0x2713) & " You're up to date!", 14, 10, $iDlgW - 28, 20)
    EndIf
    GUICtrlSetFont(-1, 10, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $TOAST_SUCCESS)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlCreateLabel("Current: v" & $APP_VERSION & "  |  Latest: v" & $sLatest, 14, 34, $iDlgW - 28, 16)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_DIM)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlCreateLabel("Released: " & $sDate, 14, 52, $iDlgW - 28, 16)
    GUICtrlSetFont(-1, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_LABEL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idDownload = 0
    If $bUpdateAvailable Then
        $idDownload = GUICtrlCreateLabel(ChrW(0x2B07) & " Download", 14, $iDlgH - 40, 100, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($idDownload, 9, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idDownload, $THEME_FG_MENU)
        GUICtrlSetBkColor($idDownload, $THEME_BG_HOVER)
        GUICtrlSetCursor($idDownload, 0)
    EndIf

    Local $idClose = GUICtrlCreateLabel(ChrW(0x2715) & " Close", $iDlgW - 114, $iDlgH - 40, 100, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($idClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($idClose, 0)

    GUISetState(@SW_SHOW, $hDlg)

    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            If $aMsg[0] = $GUI_EVENT_CLOSE Or $aMsg[0] = $idClose Then ExitLoop
            If $idDownload <> 0 And $aMsg[0] = $idDownload Then
                GUIDelete($hDlg)
                _UC_DownloadPortable()
                Return
            EndIf
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], $VK_KEYDOWN) <> 0 Then ExitLoop
        Sleep(10)
    WEnd
    GUIDelete($hDlg)
EndFunc

; Name:        _UC_DownloadPortable
; Description: Fetches release info, shows confirm with details, downloads with progress bar
Func _UC_DownloadPortable()
    _Log_Info("Download latest portable triggered")

    Local $sJson = __UC_FetchReleaseJson("Fetching release info")
    If $sJson = "" Then Return

    Local $aVer = StringRegExp($sJson, '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    Local $sVersion = "unknown"
    If Not @error And UBound($aVer) >= 1 Then $sVersion = $aVer[0]

    Local $aDate = StringRegExp($sJson, '"published_at"\s*:\s*"([^T"]+)', 1)
    Local $sDate = "unknown"
    If Not @error And UBound($aDate) >= 1 Then $sDate = $aDate[0]

    Local $aPortUrl = StringRegExp($sJson, '"browser_download_url"\s*:\s*"([^"]*Portable[^"]*\.zip)"', 1)
    If @error Or UBound($aPortUrl) < 1 Then
        _Theme_Toast("No portable download found", 0, $iTaskbarY + $iTaskbarH + 4, 2000, $TOAST_WARNING)
        Return
    EndIf
    Local $sDownloadUrl = $aPortUrl[0]

    Local $aSize = StringRegExp($sJson, '"name"\s*:\s*"[^"]*Portable[^"]*"[^}]*"size"\s*:\s*(\d+)', 1)
    Local $iSizeBytes = 0
    Local $sSizeStr = "unknown"
    If Not @error And UBound($aSize) >= 1 Then
        $iSizeBytes = Int($aSize[0])
        If $iSizeBytes > 1048576 Then
            $sSizeStr = StringFormat("%.1f MB", $iSizeBytes / 1048576)
        ElseIf $iSizeBytes > 1024 Then
            $sSizeStr = StringFormat("%.0f KB", $iSizeBytes / 1024)
        Else
            $sSizeStr = $iSizeBytes & " bytes"
        EndIf
    EndIf

    ; Confirm dialog
    Local $iDlgW = 320, $iDlgH = 140
    Local $hDlg = _Theme_CreatePopup("Download", $iDlgW, $iDlgH, _
        (@DesktopWidth - $iDlgW) / 2, (@DesktopHeight - $iDlgH) / 2, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    GUICtrlCreateLabel("Download Portable v" & $sVersion & "?", 14, 10, $iDlgW - 28, 20)
    GUICtrlSetFont(-1, 10, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlCreateLabel("Size: " & $sSizeStr & "  |  Released: " & $sDate, 14, 34, $iDlgW - 28, 16)
    GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_DIM)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlCreateLabel("Save to: " & @UserProfileDir & "\Downloads", 14, 52, $iDlgW - 28, 16)
    GUICtrlSetFont(-1, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_LABEL)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idYes = GUICtrlCreateLabel(ChrW(0x2B07) & " Download", 14, $iDlgH - 40, 100, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idYes, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idYes, $THEME_FG_MENU)
    GUICtrlSetBkColor($idYes, $THEME_BG_HOVER)
    GUICtrlSetCursor($idYes, 0)

    Local $idNo = GUICtrlCreateLabel(ChrW(0x2715) & " Cancel", $iDlgW - 114, $iDlgH - 40, 100, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idNo, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idNo, $THEME_FG_MENU)
    GUICtrlSetBkColor($idNo, $THEME_BG_HOVER)
    GUICtrlSetCursor($idNo, 0)

    GUISetState(@SW_SHOW, $hDlg)

    Local $bProceed = False
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            If $aMsg[0] = $GUI_EVENT_CLOSE Or $aMsg[0] = $idNo Then ExitLoop
            If $aMsg[0] = $idYes Then
                $bProceed = True
                ExitLoop
            EndIf
        EndIf
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc) And BitAND($retEsc[0], $VK_KEYDOWN) <> 0 Then ExitLoop
        Sleep(10)
    WEnd
    GUIDelete($hDlg)

    If Not $bProceed Then Return

    ; Download with progress bar
    Local $sDestFile = @UserProfileDir & "\Downloads\DeskSwitcheroo_Portable_v" & $sVersion & ".zip"
    $iDlgH = 90
    $hDlg = _Theme_CreatePopup("Downloading", $iDlgW, $iDlgH, _
        (@DesktopWidth - $iDlgW) / 2, (@DesktopHeight - $iDlgH) / 2, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    GUICtrlCreateLabel("Downloading v" & $sVersion & "...", 14, 10, $iDlgW - 28, 18)
    GUICtrlSetFont(-1, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor(-1, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    GUICtrlCreateLabel("", 14, 38, $iDlgW - 28, 16)
    GUICtrlSetBkColor(-1, $THEME_BG_INPUT)
    Local $idProgBar = GUICtrlCreateLabel("", 14, 38, 1, 16)
    GUICtrlSetBkColor($idProgBar, 0x4A9EFF)

    Local $idProgPct = GUICtrlCreateLabel("0%", 14, 58, $iDlgW - 28, 16)
    GUICtrlSetFont($idProgPct, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idProgPct, $THEME_FG_DIM)
    GUICtrlSetBkColor($idProgPct, $GUI_BKCOLOR_TRANSPARENT)

    GUISetState(@SW_SHOW, $hDlg)

    Local $hDownload = InetGet($sDownloadUrl, $sDestFile, 1, 1)
    Local $iBarW = $iDlgW - 28

    While Not InetGetInfo($hDownload, 2)
        Local $iBytesRead = InetGetInfo($hDownload, 0)
        If $iSizeBytes > 0 Then
            Local $iPct = Int($iBytesRead / $iSizeBytes * 100)
            If $iPct > 100 Then $iPct = 100
            GUICtrlSetPos($idProgBar, 14, 38, Int($iBarW * $iPct / 100), 16)
            GUICtrlSetData($idProgPct, $iPct & "% (" & StringFormat("%.1f", $iBytesRead / 1048576) & " / " & $sSizeStr & ")")
        Else
            GUICtrlSetData($idProgPct, StringFormat("%.1f MB downloaded", $iBytesRead / 1048576))
        EndIf
        Sleep(100)
    WEnd

    Local $bSuccess = InetGetInfo($hDownload, 3)
    InetClose($hDownload)
    GUIDelete($hDlg)

    ; Result dialog
    $iDlgH = 110
    $hDlg = _Theme_CreatePopup("Download Complete", $iDlgW, $iDlgH, _
        (@DesktopWidth - $iDlgW) / 2, (@DesktopHeight - $iDlgH) / 2, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    If $bSuccess Then
        Local $iFinalSize = FileGetSize($sDestFile)
        Local $sFinalSize = StringFormat("%.1f MB", $iFinalSize / 1048576)

        GUICtrlCreateLabel(ChrW(0x2713) & " Download complete!", 14, 10, $iDlgW - 28, 20)
        GUICtrlSetFont(-1, 10, 700, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor(-1, $TOAST_SUCCESS)
        GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

        GUICtrlCreateLabel("Version: v" & $sVersion & "  |  Size: " & $sFinalSize, 14, 34, $iDlgW - 28, 16)
        GUICtrlSetFont(-1, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor(-1, $THEME_FG_NORMAL)
        GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

        GUICtrlCreateLabel("Saved: " & $sDestFile, 14, 52, $iDlgW - 28, 16)
        GUICtrlSetFont(-1, 7, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor(-1, $THEME_FG_DIM)
        GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    Else
        GUICtrlCreateLabel(ChrW(0x2715) & " Download failed", 14, 14, $iDlgW - 28, 20)
        GUICtrlSetFont(-1, 10, 700, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor(-1, $TOAST_ERROR)
        GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    EndIf

    Local $idClose = GUICtrlCreateLabel(ChrW(0x2715) & " Close", ($iDlgW - 80) / 2, $iDlgH - 36, 80, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($idClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($idClose, 0)

    GUISetState(@SW_SHOW, $hDlg)
    While 1
        Local $aMsg2 = GUIGetMsg(1)
        If $aMsg2[1] = $hDlg Then
            If $aMsg2[0] = $GUI_EVENT_CLOSE Or $aMsg2[0] = $idClose Then ExitLoop
        EndIf
        Local $retEsc2 = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        If Not @error And IsArray($retEsc2) And BitAND($retEsc2[0], $VK_KEYDOWN) <> 0 Then ExitLoop
        Sleep(10)
    WEnd
    GUIDelete($hDlg)
EndFunc
