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

; Deferred log-compression cleanup: rotation launches Compress-Archive detached
; (non-blocking) and records the rotated source file here. A later opportunity
; (next rotation check / shutdown) deletes the source once its .zip exists.
Global $__g_Log_aPendCompressSrc[0]           ; rotated source paths awaiting cleanup
Global $__g_Log_aPendCompressTmr[0]           ; matching TimerInit() handles (giveup timer)
Global $__g_Log_iCompressTimeout = 30000      ; ms before abandoning a stuck compression

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
    ; Final chance to clean up any completed detached compression.
    __Log_ProcessPendingCompress()
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

    ; Opportunistic cleanup of any prior detached compression (cheap no-op when idle)
    __Log_ProcessPendingCompress()

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
        If FileExists($sSrc) Then
            If Not FileMove($sSrc, $sDst, 1) Then ContinueLoop ; file locked by external reader
        EndIf
        If FileExists($sSrc & ".zip") Then FileMove($sSrc & ".zip", $sDst & ".zip", 1)
    Next

    ; Current -> .log.1 (may fail if file is locked by external reader)
    If Not FileMove($__g_Log_sFilePath, $__g_Log_sFilePath & ".1", 1) Then
        ; Fallback: truncate in place so logging can continue
        $__g_Log_hFile = FileOpen($__g_Log_sFilePath, 2) ; 2 = overwrite
        If $__g_Log_hFile = -1 Then $__g_Log_hFile = FileOpen($__g_Log_sFilePath, 1)
        Return
    EndIf

    ; Compress .log.1 if enabled — launch detached so a log write that trips
    ; rotation never blocks 0.5-2s waiting for the archiver (R19). The rotated
    ; source is deleted later, once its .zip exists (see __Log_ProcessPendingCompress).
    If $bCompress Then
        Local $sSafePath = StringReplace($__g_Log_sFilePath, "'", "''")
        Run('powershell.exe -NoProfile -Command "Compress-Archive -Path ''' & $sSafePath & '.1'' -DestinationPath ''' & $sSafePath & '.1.zip'' -Force"', "", @SW_HIDE)
        __Log_EnqueuePendingCompress($__g_Log_sFilePath & ".1")
    EndIf

    ; Reopen fresh log file
    $__g_Log_hFile = FileOpen($__g_Log_sFilePath, 1) ; 1 = append
EndFunc

; Name:        __Log_EnqueuePendingCompress
; Description: Records a rotated source file whose detached compression is in flight,
;              so a later pass can delete it once the .zip is produced.
; Parameters:  $sSrc - path of the rotated log file being compressed (e.g. "...log.1")
Func __Log_EnqueuePendingCompress($sSrc)
    Local $n = UBound($__g_Log_aPendCompressSrc)
    ReDim $__g_Log_aPendCompressSrc[$n + 1]
    ReDim $__g_Log_aPendCompressTmr[$n + 1]
    $__g_Log_aPendCompressSrc[$n] = $sSrc
    $__g_Log_aPendCompressTmr[$n] = TimerInit()
EndFunc

; Name:        __Log_ProcessPendingCompress
; Description: Deletes rotated source files whose .zip has been produced. Entries whose
;              compressor is still running (source still locked, or .zip not yet created)
;              are retried on the next call; entries stuck past the timeout are abandoned
;              (the uncompressed source is simply left in place — no data loss).
Func __Log_ProcessPendingCompress()
    Local $n = UBound($__g_Log_aPendCompressSrc)
    If $n = 0 Then Return

    Local $aSrc[0], $aTmr[0], $k = 0
    Local $i
    For $i = 0 To $n - 1
        Local $sSrc = $__g_Log_aPendCompressSrc[$i]
        Local $bKeep = False
        If Not FileExists($sSrc) Then
            ; Source already gone (deleted or rotated away) — nothing left to do.
        ElseIf FileExists($sSrc & ".zip") Then
            ; Archive exists; FileDelete fails while the compressor still holds the
            ; source's read lock, so a failure just means "retry next pass".
            If Not FileDelete($sSrc) Then $bKeep = True
        Else
            ; No .zip yet: compressor still running, or it failed. Retry until timeout.
            If TimerDiff($__g_Log_aPendCompressTmr[$i]) < $__g_Log_iCompressTimeout Then $bKeep = True
        EndIf
        If $bKeep Then
            ReDim $aSrc[$k + 1]
            ReDim $aTmr[$k + 1]
            $aSrc[$k] = $sSrc
            $aTmr[$k] = $__g_Log_aPendCompressTmr[$i]
            $k += 1
        EndIf
    Next
    $__g_Log_aPendCompressSrc = $aSrc
    $__g_Log_aPendCompressTmr = $aTmr
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
