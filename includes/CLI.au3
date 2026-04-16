#include-once
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include "Config.au3"
#include "Logger.au3"
#include "VirtualDesktop.au3"
#include "Labels.au3"

; #INDEX# =======================================================
; Title .........: CLI
; Description ....: Command-line interface and WM_COPYDATA IPC support.
;                   Parses CLI arguments, sends commands to a running
;                   instance via IPC, or executes locally for query commands.
; Author .........: Mariana
; ===============================================================

; #INDEX OF FUNCTIONS# ==========================================
;   _CLI_ParseArgs           Parse command-line arguments
;   _CLI_HasCommand          Check if CLI command was provided
;   _CLI_GetCommand          Get the parsed command name
;   _CLI_GetCommandArg       Get the command argument value
;   _CLI_ExecuteLocal        Execute a command locally (no IPC)
;   _CLI_SendToRunning       Send command to running instance via IPC
;   _CLI_RegisterIPC         Register WM_COPYDATA handler in running instance
;   _CLI_HandleIPC           Process received IPC command
;   __CLI_PrintHelp          Print usage information
;   __CLI_PrintStatus        Print JSON status
;   __CLI_PrintDesktops      Print desktop list
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_CLI_sCommand = ""
Global $__g_CLI_sArg = ""
Global $__g_CLI_sArg2 = ""
Global $__g_CLI_hIPCWin = 0
Global Const $__g_CLI_IPC_MAGIC = 0x44534B ; "DSK"
Global Const $__g_CLI_IPC_TITLE = "DeskSwitcheroo_IPC"

; #FUNCTIONS# ===================================================

; Name:        _CLI_ParseArgs
; Description: Parses $CmdLine array into command name and argument.
;              Strips leading --, -, / from command name.
;              Stores result in globals: $__g_CLI_sCommand, $__g_CLI_sArg, $__g_CLI_sArg2
; Return:      True if a CLI command was found, False otherwise
Func _CLI_ParseArgs()
    $__g_CLI_sCommand = ""
    $__g_CLI_sArg = ""
    $__g_CLI_sArg2 = ""

    If $CmdLine[0] < 1 Then Return False

    Local $i
    For $i = 1 To $CmdLine[0]
        Local $sToken = $CmdLine[$i]

        ; Skip the legacy -autostart flag (handled by main app)
        If $sToken = "-autostart" Then ContinueLoop

        ; Strip prefix: --, -, /
        Local $sCmd = $sToken
        If StringLeft($sCmd, 2) = "--" Then
            $sCmd = StringTrimLeft($sCmd, 2)
        ElseIf StringLeft($sCmd, 1) = "-" Then
            $sCmd = StringTrimLeft($sCmd, 1)
        ElseIf StringLeft($sCmd, 1) = "/" Then
            $sCmd = StringTrimLeft($sCmd, 1)
        Else
            ; Not a command prefix — skip
            ContinueLoop
        EndIf

        $sCmd = StringLower($sCmd)
        If $sCmd = "" Then ContinueLoop

        $__g_CLI_sCommand = $sCmd

        ; Collect next argument(s) if present
        If $i + 1 <= $CmdLine[0] Then
            Local $sNext = $CmdLine[$i + 1]
            ; Only treat as argument if it doesn't look like another flag
            If StringLeft($sNext, 1) <> "-" And StringLeft($sNext, 1) <> "/" Then
                $__g_CLI_sArg = $sNext
                ; Check for a second argument (e.g. --rename N "label")
                If $i + 2 <= $CmdLine[0] Then
                    Local $sNext2 = $CmdLine[$i + 2]
                    If StringLeft($sNext2, 1) <> "-" And StringLeft($sNext2, 1) <> "/" Then
                        $__g_CLI_sArg2 = $sNext2
                    EndIf
                EndIf
            EndIf
        EndIf

        Return True
    Next

    Return False
EndFunc

; Name:        _CLI_HasCommand
; Description: Returns whether a CLI command was parsed
; Return:      True/False
Func _CLI_HasCommand()
    Return ($__g_CLI_sCommand <> "")
EndFunc

; Name:        _CLI_GetCommand
; Description: Returns the parsed command name (lowercase, no prefix)
; Return:      Command string, or "" if none
Func _CLI_GetCommand()
    Return $__g_CLI_sCommand
EndFunc

; Name:        _CLI_GetCommandArg
; Description: Returns the first argument value for the command
; Return:      Argument string, or "" if none
Func _CLI_GetCommandArg()
    Return $__g_CLI_sArg
EndFunc

; Name:        _CLI_GetCommandArg2
; Description: Returns the second argument value for the command (e.g. label for --rename)
; Return:      Argument string, or "" if none
Func _CLI_GetCommandArg2()
    Return $__g_CLI_sArg2
EndFunc

; Name:        _CLI_IsQueryCommand
; Description: Returns whether the current command is a read-only query
;              that can be executed without a running GUI instance
; Return:      True/False
Func _CLI_IsQueryCommand()
    Switch $__g_CLI_sCommand
        Case "list-desktops", "get-current", "status", "help", "version"
            Return True
        Case Else
            Return False
    EndSwitch
EndFunc

; Name:        _CLI_ExecuteLocal
; Description: Executes the current CLI command locally (no IPC).
;              Used for query commands or when no running instance exists.
; Return:      True if command was handled, False if unknown command
Func _CLI_ExecuteLocal()
    If $__g_CLI_sCommand = "" Then Return False

    Switch $__g_CLI_sCommand
        Case "help"
            __CLI_PrintHelp()
        Case "version"
            __CLI_PrintVersion()
        Case "list-desktops"
            __CLI_PrintDesktops()
        Case "get-current"
            __CLI_PrintCurrent()
        Case "status"
            __CLI_PrintStatus()
        Case "goto"
            If $__g_CLI_sArg = "" Or Not StringIsInt($__g_CLI_sArg) Then
                ConsoleWrite("Error: --goto requires a desktop number" & @CRLF)
                Return False
            EndIf
            Local $iTarget = Int($__g_CLI_sArg)
            If $iTarget < 1 Or $iTarget > _VD_GetCount() Then
                ConsoleWrite("Error: desktop number out of range (1-" & _VD_GetCount() & ")" & @CRLF)
                Return False
            EndIf
            _VD_GoTo($iTarget)
            _Log_Info("CLI: goto desktop " & $iTarget)
        Case "next"
            Local $iCur = _VD_GetCurrent()
            Local $iCount = _VD_GetCount()
            Local $iNext = $iCur + 1
            If $iNext > $iCount Then
                If _Cfg_GetWrapNavigation() Then
                    $iNext = 1
                Else
                    $iNext = $iCount
                EndIf
            EndIf
            _VD_GoTo($iNext)
            _Log_Info("CLI: next desktop -> " & $iNext)
        Case "prev"
            Local $iCur = _VD_GetCurrent()
            Local $iPrev = $iCur - 1
            If $iPrev < 1 Then
                If _Cfg_GetWrapNavigation() Then
                    $iPrev = _VD_GetCount()
                Else
                    $iPrev = 1
                EndIf
            EndIf
            _VD_GoTo($iPrev)
            _Log_Info("CLI: prev desktop -> " & $iPrev)
        Case "add-desktop"
            _VD_CreateDesktop()
            _Log_Info("CLI: created new desktop")
        Case "remove-desktop"
            If $__g_CLI_sArg = "" Or Not StringIsInt($__g_CLI_sArg) Then
                ConsoleWrite("Error: --remove-desktop requires a desktop number" & @CRLF)
                Return False
            EndIf
            Local $iRemove = Int($__g_CLI_sArg)
            If $iRemove < 1 Or $iRemove > _VD_GetCount() Then
                ConsoleWrite("Error: desktop number out of range (1-" & _VD_GetCount() & ")" & @CRLF)
                Return False
            EndIf
            Local $iCliOldCount = _VD_GetCount()
            _VD_RemoveDesktop($iRemove)
            _Labels_RemoveAndShift($iRemove, $iCliOldCount)
            _Log_Info("CLI: removed desktop " & $iRemove)
        Case "rename"
            If $__g_CLI_sArg = "" Or Not StringIsInt($__g_CLI_sArg) Then
                ConsoleWrite("Error: --rename requires a desktop number and label" & @CRLF)
                Return False
            EndIf
            If $__g_CLI_sArg2 = "" Then
                ConsoleWrite("Error: --rename requires a label as second argument" & @CRLF)
                Return False
            EndIf
            Local $iRenIdx = Int($__g_CLI_sArg)
            _Labels_Save($iRenIdx, $__g_CLI_sArg2)
            _Log_Info("CLI: renamed desktop " & $iRenIdx & " to '" & $__g_CLI_sArg2 & "'")
        Case "move-window"
            If $__g_CLI_sArg = "" Or Not StringIsInt($__g_CLI_sArg) Then
                ConsoleWrite("Error: --move-window requires a desktop number" & @CRLF)
                Return False
            EndIf
            Local $iMoveDest = Int($__g_CLI_sArg)
            Local $hActive = WinGetHandle("[ACTIVE]")
            If $hActive = 0 Then
                ConsoleWrite("Error: no active window found" & @CRLF)
                Return False
            EndIf
            _VD_MoveWindowToDesktop($hActive, $iMoveDest)
            _Log_Info("CLI: moved active window to desktop " & $iMoveDest)
        Case "toggle-list", "toggle-carousel", "load-profile", "save-profile"
            ; These require a running GUI instance — cannot execute locally
            ConsoleWrite("Error: --" & $__g_CLI_sCommand & " requires a running instance" & @CRLF)
            Return False
        Case Else
            ConsoleWrite("Error: unknown command '--" & $__g_CLI_sCommand & "'" & @CRLF)
            __CLI_PrintHelp()
            Return False
    EndSwitch

    Return True
EndFunc

; Name:        _CLI_BuildIPCString
; Description: Builds the IPC command string from current parsed command
; Return:      Command string (e.g. "goto 3", "rename 2 Work")
Func _CLI_BuildIPCString()
    Local $s = $__g_CLI_sCommand
    If $__g_CLI_sArg <> "" Then $s &= " " & $__g_CLI_sArg
    If $__g_CLI_sArg2 <> "" Then $s &= " " & $__g_CLI_sArg2
    Return $s
EndFunc

; Name:        _CLI_SendToRunning
; Description: Sends the current CLI command to a running instance via WM_COPYDATA.
;              Finds the hidden IPC window by title and sends the command string.
; Return:      True if message was sent, False if no running instance found
Func _CLI_SendToRunning()
    ; Find the hidden IPC window
    Local $hTarget = WinGetHandle("[TITLE:" & $__g_CLI_IPC_TITLE & ";CLASS:AutoIt v3 GUI]")
    If @error Or $hTarget = 0 Then
        _Log_Debug("CLI_SendToRunning: IPC window not found")
        Return False
    EndIf

    Local $sCmd = _CLI_BuildIPCString()
    If $sCmd = "" Then Return False

    ; Build COPYDATASTRUCT: {dwData, cbData, lpData}
    Local $iLen = StringLen($sCmd) + 1
    Local $tStr = DllStructCreate("char str[" & $iLen & "]")
    DllStructSetData($tStr, "str", $sCmd)

    Local $tData = DllStructCreate("dword dwData;dword cbData;ptr lpData")
    DllStructSetData($tData, "dwData", $__g_CLI_IPC_MAGIC)
    DllStructSetData($tData, "cbData", $iLen)
    DllStructSetData($tData, "lpData", DllStructGetPtr($tStr))

    ; Send WM_COPYDATA (0x004A) via SendMessage
    DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $hTarget, _
        "uint", $WM_COPYDATA, "wparam", 0, "lparam", DllStructGetPtr($tData))
    If @error Then
        _Log_Error("CLI_SendToRunning: SendMessage failed (error=" & @error & ")")
        Return False
    EndIf

    _Log_Info("CLI: sent IPC command '" & $sCmd & "'")
    Return True
EndFunc

; Name:        _CLI_RegisterIPC
; Description: Creates a hidden window and registers WM_COPYDATA handler.
;              Call once during app startup so the running instance can
;              receive commands from new CLI invocations.
Func _CLI_RegisterIPC()
    ; Create a tiny hidden tool window for IPC
    $__g_CLI_hIPCWin = GUICreate($__g_CLI_IPC_TITLE, 1, 1, -1, -1, $WS_POPUP, $WS_EX_TOOLWINDOW)
    If $__g_CLI_hIPCWin = 0 Then
        _Log_Error("CLI_RegisterIPC: failed to create IPC window")
        Return False
    EndIf
    GUIRegisterMsg($WM_COPYDATA, "_CLI_HandleIPC")
    _Log_Info("CLI: IPC handler registered (hwnd=" & $__g_CLI_hIPCWin & ")")
    Return True
EndFunc

; Name:        _CLI_UnregisterIPC
; Description: Destroys the hidden IPC window
Func _CLI_UnregisterIPC()
    If $__g_CLI_hIPCWin <> 0 Then
        GUIDelete($__g_CLI_hIPCWin)
        $__g_CLI_hIPCWin = 0
        _Log_Info("CLI: IPC handler unregistered")
    EndIf
EndFunc

; Name:        _CLI_GetIPCWindow
; Description: Returns the IPC window handle (for testing)
; Return:      Window handle, or 0 if not registered
Func _CLI_GetIPCWindow()
    Return $__g_CLI_hIPCWin
EndFunc

; Name:        _CLI_HandleIPC
; Description: WM_COPYDATA handler. Validates magic number, extracts command
;              string, and dispatches to __CLI_ProcessIPCCommand.
; Parameters:  Standard Windows message handler params
; Return:      0 if handled, $GUI_RUNDEFMSG otherwise
Func _CLI_HandleIPC($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $wParam
    ; Read COPYDATASTRUCT from lParam
    Local $tData = DllStructCreate("dword dwData;dword cbData;ptr lpData", $lParam)
    If @error Then Return $GUI_RUNDEFMSG

    ; Validate magic number
    If DllStructGetData($tData, "dwData") <> $__g_CLI_IPC_MAGIC Then Return $GUI_RUNDEFMSG

    ; Extract command string
    Local $iCbData = DllStructGetData($tData, "cbData")
    If $iCbData < 1 Or $iCbData > 4096 Then Return $GUI_RUNDEFMSG
    Local $tStr = DllStructCreate("char str[" & $iCbData & "]", DllStructGetData($tData, "lpData"))
    If @error Then Return $GUI_RUNDEFMSG
    Local $sCmd = DllStructGetData($tStr, "str")
    If $sCmd = "" Then Return $GUI_RUNDEFMSG

    _Log_Info("CLI: IPC received '" & $sCmd & "'")
    __CLI_ProcessIPCCommand($sCmd)
    Return 0
EndFunc

; =============================================
; INTERNAL HELPERS
; =============================================

; Name:        __CLI_ProcessIPCCommand
; Description: Parses and executes a command string received via IPC.
;              The string format is: "command [arg1 [arg2]]"
; Parameters:  $sCmd - raw command string
Func __CLI_ProcessIPCCommand($sCmd)
    ; Split command string into parts
    Local $aParts = StringSplit(StringStripWS($sCmd, 3), " ", 2)
    If UBound($aParts) < 1 Then Return

    Local $sCommand = StringLower($aParts[0])
    Local $sArg1 = ""
    Local $sArg2 = ""
    If UBound($aParts) > 1 Then $sArg1 = $aParts[1]
    ; For rename, join remaining parts as the label (may contain spaces)
    If UBound($aParts) > 2 Then
        Local $i
        $sArg2 = $aParts[2]
        For $i = 3 To UBound($aParts) - 1
            $sArg2 &= " " & $aParts[$i]
        Next
    EndIf

    ; Temporarily set globals so _CLI_ExecuteLocal works
    Local $sSavCmd = $__g_CLI_sCommand
    Local $sSavArg = $__g_CLI_sArg
    Local $sSavArg2 = $__g_CLI_sArg2
    $__g_CLI_sCommand = $sCommand
    $__g_CLI_sArg = $sArg1
    $__g_CLI_sArg2 = $sArg2

    ; Handle GUI-specific commands that _CLI_ExecuteLocal cannot do
    Switch $sCommand
        Case "toggle-list"
            _Log_Info("CLI IPC: toggle-list (forwarded to main loop)")
            ; Set a flag that the main loop can pick up
            $__g_CLI_sIPCPending = "toggle-list"
        Case "toggle-carousel"
            _Log_Info("CLI IPC: toggle-carousel (forwarded to main loop)")
            $__g_CLI_sIPCPending = "toggle-carousel"
        Case "load-profile"
            _Log_Info("CLI IPC: load-profile '" & $sArg1 & "' (forwarded to main loop)")
            $__g_CLI_sIPCPending = "load-profile"
            $__g_CLI_sIPCPendingArg = $sArg1
        Case "save-profile"
            _Log_Info("CLI IPC: save-profile '" & $sArg1 & "' (forwarded to main loop)")
            $__g_CLI_sIPCPending = "save-profile"
            $__g_CLI_sIPCPendingArg = $sArg1
        Case Else
            _CLI_ExecuteLocal()
    EndSwitch

    ; Restore globals
    $__g_CLI_sCommand = $sSavCmd
    $__g_CLI_sArg = $sSavArg
    $__g_CLI_sArg2 = $sSavArg2
EndFunc

; Pending IPC command for main loop to pick up (GUI-specific commands)
Global $__g_CLI_sIPCPending = ""
Global $__g_CLI_sIPCPendingArg = ""

; Name:        _CLI_CheckIPCPending
; Description: Call from the main loop to check if an IPC command needs
;              GUI-level handling (toggle-list, toggle-carousel, profiles).
; Return:      Command string if pending, "" if none. Clears the pending flag.
Func _CLI_CheckIPCPending()
    If $__g_CLI_sIPCPending = "" Then Return ""
    Local $sCmd = $__g_CLI_sIPCPending
    $__g_CLI_sIPCPending = ""
    Return $sCmd
EndFunc

; Name:        _CLI_GetIPCPendingArg
; Description: Returns and clears the argument for a pending IPC command
; Return:      Argument string, or ""
Func _CLI_GetIPCPendingArg()
    Local $s = $__g_CLI_sIPCPendingArg
    $__g_CLI_sIPCPendingArg = ""
    Return $s
EndFunc

; Name:        __CLI_PrintHelp
; Description: Prints usage information to stdout
Func __CLI_PrintHelp()
    ConsoleWrite("Desk Switcheroo — Command-line interface" & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("Usage: desk_switcheroo [options]" & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("Navigation:" & @CRLF)
    ConsoleWrite("  --goto N              Switch to desktop N (1-based)" & @CRLF)
    ConsoleWrite("  --next                Switch to next desktop" & @CRLF)
    ConsoleWrite("  --prev                Switch to previous desktop" & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("Desktop management:" & @CRLF)
    ConsoleWrite("  --add-desktop         Create a new virtual desktop" & @CRLF)
    ConsoleWrite("  --remove-desktop N    Remove desktop N" & @CRLF)
    ConsoleWrite('  --rename N "label"    Rename desktop N' & @CRLF)
    ConsoleWrite("  --move-window N       Move active window to desktop N" & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("Query:" & @CRLF)
    ConsoleWrite("  --list-desktops       List all desktops (number and name)" & @CRLF)
    ConsoleWrite("  --get-current         Print current desktop number" & @CRLF)
    ConsoleWrite("  --status              Print JSON status" & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("GUI control:" & @CRLF)
    ConsoleWrite("  --toggle-list         Toggle the desktop list panel" & @CRLF)
    ConsoleWrite("  --toggle-carousel     Toggle carousel mode" & @CRLF)
    ConsoleWrite('  --load-profile "name" Load a named profile' & @CRLF)
    ConsoleWrite('  --save-profile "name" Save current state as named profile' & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("Information:" & @CRLF)
    ConsoleWrite("  --help                Print this usage information" & @CRLF)
    ConsoleWrite("  --version             Print version number" & @CRLF)
    ConsoleWrite("" & @CRLF)
    ConsoleWrite("Prefix styles: --command, -command, /command are all accepted." & @CRLF)
    ConsoleWrite("If a running instance exists, commands are sent via IPC." & @CRLF)
EndFunc

; Name:        __CLI_PrintVersion
; Description: Prints the application version to stdout
Func __CLI_PrintVersion()
    ConsoleWrite($APP_VERSION & @CRLF)
EndFunc

; Name:        __CLI_PrintCurrent
; Description: Prints the current desktop number to stdout
Func __CLI_PrintCurrent()
    ConsoleWrite(_VD_GetCurrent() & @CRLF)
EndFunc

; Name:        __CLI_PrintDesktops
; Description: Prints all desktops (number and label) to stdout, one per line
Func __CLI_PrintDesktops()
    Local $iCount = _VD_GetCount()
    Local $i
    For $i = 1 To $iCount
        Local $sLabel = _Labels_Load($i)
        If $sLabel = "" Then $sLabel = "Desktop " & $i
        ConsoleWrite($i & ": " & $sLabel & @CRLF)
    Next
EndFunc

; Name:        __CLI_PrintStatus
; Description: Prints JSON status to stdout with current desktop, count, and labels
Func __CLI_PrintStatus()
    Local $iCurrent = _VD_GetCurrent()
    Local $iCount = _VD_GetCount()

    ; Build JSON manually (no JSON UDF in AutoIt)
    Local $sJSON = '{"current":' & $iCurrent & ',"count":' & $iCount & ',"desktops":['
    Local $i
    For $i = 1 To $iCount
        If $i > 1 Then $sJSON &= ","
        Local $sLabel = _Labels_Load($i)
        If $sLabel = "" Then $sLabel = "Desktop " & $i
        ; Escape special JSON characters in label
        $sLabel = StringReplace($sLabel, '\', '\\')
        $sLabel = StringReplace($sLabel, '"', '\"')
        $sJSON &= '{"id":' & $i & ',"name":"' & $sLabel & '"}'
    Next
    $sJSON &= "]}"

    ConsoleWrite($sJSON & @CRLF)
EndFunc

; Name:        __CLI_EscapeJSON
; Description: Escapes a string for safe inclusion in JSON output
; Parameters:  $s - input string
; Return:      Escaped string
Func __CLI_EscapeJSON($s)
    $s = StringReplace($s, '\', '\\')
    $s = StringReplace($s, '"', '\"')
    $s = StringReplace($s, @CR, '\r')
    $s = StringReplace($s, @LF, '\n')
    $s = StringReplace($s, @TAB, '\t')
    Return $s
EndFunc
