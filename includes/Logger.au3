#include-once
#include "Config.au3"

; #INDEX# =======================================================
; Title .........: Logger
; Description ....: File-based logging UDF with rotation, level filtering,
;                   and timestamped output
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_Log_bEnabled  = False
Global $__g_Log_sFilePath = ""
Global $__g_Log_iLevel    = 3        ; 1=error, 2=warn, 3=info, 4=debug
Global $__g_Log_hFile     = -1       ; file handle (-1 = closed)
Global $__g_Log_iMaxSize  = 5 * 1024 * 1024  ; default 5 MB, updated from config in _Log_Init

; #FUNCTIONS# ===================================================

; Name:        _Log_Init
; Description: Initializes the logging system from config values.
;              Opens the log file for append and checks rotation.
Func _Log_Init()
    $__g_Log_bEnabled = _Cfg_GetLoggingEnabled()
    If Not $__g_Log_bEnabled Then Return

    ; Apply configured max log size
    $__g_Log_iMaxSize = _Cfg_GetLogMaxSizeMB() * 1024 * 1024

    ; Determine log file path (folder from config + automatic filename)
    Local $sPath = _Cfg_GetLogFilePath()
    $__g_Log_sFilePath = $sPath

    ; Determine log level
    $__g_Log_iLevel = __Log_LevelToInt(_Cfg_GetLogLevel())

    ; Check rotation before opening
    __Log_CheckRotation()

    ; Open for append
    $__g_Log_hFile = FileOpen($__g_Log_sFilePath, 1) ; 1 = append mode
    If $__g_Log_hFile = -1 Then
        $__g_Log_bEnabled = False
        Return
    EndIf

    __Log_Write("INFO", "Logger initialized (level=" & _Cfg_GetLogLevel() & ")")
EndFunc

; Name:        _Log_Shutdown
; Description: Closes the log file handle
Func _Log_Shutdown()
    If $__g_Log_hFile <> -1 Then
        __Log_Write("INFO", "Logger shutting down")
        FileClose($__g_Log_hFile)
        $__g_Log_hFile = -1
    EndIf
EndFunc

; Name:        _Log_Error
; Description: Logs an error-level message
; Parameters:  $sMsg - message text
Func _Log_Error($sMsg)
    If Not $__g_Log_bEnabled Then Return
    If $__g_Log_iLevel >= 1 Then __Log_Write("ERROR", $sMsg)
EndFunc

; Name:        _Log_Warn
; Description: Logs a warning-level message
; Parameters:  $sMsg - message text
Func _Log_Warn($sMsg)
    If Not $__g_Log_bEnabled Then Return
    If $__g_Log_iLevel >= 2 Then __Log_Write("WARN", $sMsg)
EndFunc

; Name:        _Log_Info
; Description: Logs an info-level message
; Parameters:  $sMsg - message text
Func _Log_Info($sMsg)
    If Not $__g_Log_bEnabled Then Return
    If $__g_Log_iLevel >= 3 Then __Log_Write("INFO", $sMsg)
EndFunc

; Name:        _Log_Debug
; Description: Logs a debug-level message
; Parameters:  $sMsg - message text
Func _Log_Debug($sMsg)
    If Not $__g_Log_bEnabled Then Return
    If $__g_Log_iLevel >= 4 Then __Log_Write("DEBUG", $sMsg)
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

; Name:        __Log_Write
; Description: Formats and writes a log line. Checks rotation after write.
; Parameters:  $sLevel - level string (ERROR/WARN/INFO/DEBUG)
;              $sMsg   - message text
Func __Log_Write($sLevel, $sMsg)
    If $__g_Log_hFile = -1 Then Return

    ; Format date portion based on log_date_format config
    Local $sDatePart
    Local $sDateFmt = _Cfg_GetLogDateFormat()
    Switch $sDateFmt
        Case "us"
            $sDatePart = StringFormat("%02d/%02d/%04d", @MON, @MDAY, @YEAR)
        Case "eu"
            $sDatePart = StringFormat("%02d/%02d/%04d", @MDAY, @MON, @YEAR)
        Case Else ; "iso"
            $sDatePart = StringFormat("%04d-%02d-%02d", @YEAR, @MON, @MDAY)
    EndSwitch

    Local $sTimestamp = $sDatePart & " " & StringFormat("%02d:%02d:%02d", @HOUR, @MIN, @SEC)
    Local $sLine = "[" & $sTimestamp & "]"

    ; Optionally include PID
    If _Cfg_GetLogIncludePID() Then
        $sLine &= " [PID:" & @AutoItPID & "]"
    EndIf

    $sLine &= " [" & $sLevel & "] " & $sMsg

    FileWriteLine($__g_Log_hFile, $sLine)

    ; Flush immediately if configured
    If _Cfg_GetLogFlushImmediate() Then FileFlush($__g_Log_hFile)

    ; Check rotation after write
    __Log_CheckRotation()
EndFunc

; Name:        __Log_CheckRotation
; Description: If the log file exceeds max size, rotates it by closing,
;              moving to .bak, and reopening.
Func __Log_CheckRotation()
    If Not $__g_Log_bEnabled Or $__g_Log_hFile = -1 Then Return
    If FileGetSize($__g_Log_sFilePath) <= $__g_Log_iMaxSize Then Return

    ; Close current file
    FileClose($__g_Log_hFile)
    $__g_Log_hFile = -1

    Local $iKeep = _Cfg_GetLogRotateCount()
    Local $bCompress = _Cfg_GetLogCompressOld()

    ; Delete oldest
    Local $sOldest = $__g_Log_sFilePath & "." & $iKeep
    If FileExists($sOldest) Then FileDelete($sOldest)
    If FileExists($sOldest & ".zip") Then FileDelete($sOldest & ".zip")

    ; Shift files: .log.N-1 -> .log.N, ..., .log.1 -> .log.2
    Local $i
    For $i = $iKeep - 1 To 1 Step -1
        Local $sSrc = $__g_Log_sFilePath & "." & $i
        Local $sDst = $__g_Log_sFilePath & "." & ($i + 1)
        If FileExists($sSrc) Then FileMove($sSrc, $sDst, 1)
        If FileExists($sSrc & ".zip") Then FileMove($sSrc & ".zip", $sDst & ".zip", 1)
    Next

    ; Current -> .log.1
    FileMove($__g_Log_sFilePath, $__g_Log_sFilePath & ".1", 1)

    ; Compress .log.1 if enabled (use PowerShell)
    If $bCompress Then
        RunWait('powershell.exe -NoProfile -Command "Compress-Archive -Path ''' & $__g_Log_sFilePath & '.1'' -DestinationPath ''' & $__g_Log_sFilePath & '.1.zip'' -Force"', "", @SW_HIDE)
        If FileExists($__g_Log_sFilePath & ".1.zip") Then FileDelete($__g_Log_sFilePath & ".1")
    EndIf

    ; Reopen fresh log file
    $__g_Log_hFile = FileOpen($__g_Log_sFilePath, 1) ; 1 = append
EndFunc

; Name:        __Log_LevelToInt
; Description: Converts a level string to its numeric value
; Parameters:  $s - level string ("error", "warn", "info", "debug")
; Return:      Integer level (1-4), defaults to 3 (info)
Func __Log_LevelToInt($s)
    Switch StringLower($s)
        Case "error"
            Return 1
        Case "warn"
            Return 2
        Case "info"
            Return 3
        Case "debug"
            Return 4
        Case Else
            Return 3
    EndSwitch
EndFunc
