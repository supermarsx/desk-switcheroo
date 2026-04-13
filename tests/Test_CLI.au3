#include-once

; ===============================================================
; Tests for includes\CLI.au3
; Unit tests — no running instance required, tests parsing and output
; ===============================================================

Func _RunTest_CLI()
    _Test_Suite("CLI")

    ; ---- Argument parsing: initial state ----
    ; Before any parsing, command should be empty
    _Test_AssertEqual("Initial command empty", _CLI_GetCommand(), "")
    _Test_AssertFalse("Initial HasCommand false", _CLI_HasCommand())
    _Test_AssertEqual("Initial arg empty", _CLI_GetCommandArg(), "")
    _Test_AssertEqual("Initial arg2 empty", _CLI_GetCommandArg2(), "")

    ; ---- Manual parsing tests via globals ----
    ; We cannot call _CLI_ParseArgs directly in tests because $CmdLine is read-only,
    ; so we test the internal globals and helper functions instead.

    ; -- Command prefix stripping (simulate by setting globals) --
    $__g_CLI_sCommand = "goto"
    $__g_CLI_sArg = "3"
    $__g_CLI_sArg2 = ""
    _Test_AssertTrue("HasCommand after set", _CLI_HasCommand())
    _Test_AssertEqual("GetCommand returns goto", _CLI_GetCommand(), "goto")
    _Test_AssertEqual("GetCommandArg returns 3", _CLI_GetCommandArg(), "3")
    _Test_AssertEqual("GetCommandArg2 returns empty", _CLI_GetCommandArg2(), "")

    ; -- Rename command with two args --
    $__g_CLI_sCommand = "rename"
    $__g_CLI_sArg = "2"
    $__g_CLI_sArg2 = "Work Desktop"
    _Test_AssertEqual("Rename command", _CLI_GetCommand(), "rename")
    _Test_AssertEqual("Rename arg1", _CLI_GetCommandArg(), "2")
    _Test_AssertEqual("Rename arg2", _CLI_GetCommandArg2(), "Work Desktop")

    ; -- No-arg commands --
    $__g_CLI_sCommand = "next"
    $__g_CLI_sArg = ""
    $__g_CLI_sArg2 = ""
    _Test_AssertTrue("next HasCommand", _CLI_HasCommand())
    _Test_AssertEqual("next command name", _CLI_GetCommand(), "next")
    _Test_AssertEqual("next arg empty", _CLI_GetCommandArg(), "")

    $__g_CLI_sCommand = "prev"
    _Test_AssertEqual("prev command name", _CLI_GetCommand(), "prev")

    $__g_CLI_sCommand = "help"
    _Test_AssertEqual("help command name", _CLI_GetCommand(), "help")

    $__g_CLI_sCommand = "version"
    _Test_AssertEqual("version command name", _CLI_GetCommand(), "version")

    ; -- Query command detection --
    $__g_CLI_sCommand = "list-desktops"
    _Test_AssertTrue("list-desktops is query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "get-current"
    _Test_AssertTrue("get-current is query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "status"
    _Test_AssertTrue("status is query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "help"
    _Test_AssertTrue("help is query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "version"
    _Test_AssertTrue("version is query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "goto"
    _Test_AssertFalse("goto is not query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "next"
    _Test_AssertFalse("next is not query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "toggle-list"
    _Test_AssertFalse("toggle-list is not query", _CLI_IsQueryCommand())

    $__g_CLI_sCommand = "add-desktop"
    _Test_AssertFalse("add-desktop is not query", _CLI_IsQueryCommand())

    ; -- Empty command --
    $__g_CLI_sCommand = ""
    $__g_CLI_sArg = ""
    _Test_AssertFalse("Empty command: HasCommand false", _CLI_HasCommand())
    _Test_AssertFalse("Empty command: IsQuery false", _CLI_IsQueryCommand())

    ; ---- IPC string building ----
    $__g_CLI_sCommand = "goto"
    $__g_CLI_sArg = "5"
    $__g_CLI_sArg2 = ""
    _Test_AssertEqual("IPC string: goto 5", _CLI_BuildIPCString(), "goto 5")

    $__g_CLI_sCommand = "next"
    $__g_CLI_sArg = ""
    $__g_CLI_sArg2 = ""
    _Test_AssertEqual("IPC string: next", _CLI_BuildIPCString(), "next")

    $__g_CLI_sCommand = "rename"
    $__g_CLI_sArg = "3"
    $__g_CLI_sArg2 = "Gaming"
    _Test_AssertEqual("IPC string: rename 3 Gaming", _CLI_BuildIPCString(), "rename 3 Gaming")

    $__g_CLI_sCommand = "load-profile"
    $__g_CLI_sArg = "MyProfile"
    $__g_CLI_sArg2 = ""
    _Test_AssertEqual("IPC string: load-profile", _CLI_BuildIPCString(), "load-profile MyProfile")

    $__g_CLI_sCommand = ""
    $__g_CLI_sArg = ""
    _Test_AssertEqual("IPC string: empty cmd", _CLI_BuildIPCString(), "")

    ; ---- IPC pending mechanism ----
    ; Initially no pending command
    _Test_AssertEqual("No pending IPC initially", _CLI_CheckIPCPending(), "")
    _Test_AssertEqual("No pending arg initially", _CLI_GetIPCPendingArg(), "")

    ; Simulate a pending command
    $__g_CLI_sIPCPending = "toggle-list"
    $__g_CLI_sIPCPendingArg = ""
    _Test_AssertEqual("Pending IPC: toggle-list", _CLI_CheckIPCPending(), "toggle-list")
    ; Should be cleared after read
    _Test_AssertEqual("Pending cleared after read", _CLI_CheckIPCPending(), "")

    $__g_CLI_sIPCPending = "load-profile"
    $__g_CLI_sIPCPendingArg = "WorkMode"
    _Test_AssertEqual("Pending IPC: load-profile", _CLI_CheckIPCPending(), "load-profile")
    _Test_AssertEqual("Pending arg: WorkMode", _CLI_GetIPCPendingArg(), "WorkMode")
    ; Both should be cleared
    _Test_AssertEqual("Pending cleared", _CLI_CheckIPCPending(), "")
    _Test_AssertEqual("Pending arg cleared", _CLI_GetIPCPendingArg(), "")

    ; ---- IPC magic constant ----
    _Test_AssertEqual("IPC magic = 0x44534B", $__g_CLI_IPC_MAGIC, 0x44534B)

    ; ---- IPC window title constant ----
    _Test_AssertEqual("IPC title", $__g_CLI_IPC_TITLE, "DeskSwitcheroo_IPC")

    ; ---- Help text output ----
    ; We cannot capture ConsoleWrite output in AutoIt tests, but we can
    ; verify the function exists and doesn't crash
    $__g_CLI_sCommand = "help"
    $__g_CLI_sArg = ""
    $__g_CLI_sArg2 = ""
    Local $bHelpOk = _CLI_ExecuteLocal()
    _Test_AssertTrue("Help command executes", $bHelpOk)

    ; ---- Version output ----
    $__g_CLI_sCommand = "version"
    Local $bVerOk = _CLI_ExecuteLocal()
    _Test_AssertTrue("Version command executes", $bVerOk)

    ; ---- Unknown command returns False ----
    $__g_CLI_sCommand = "nonexistent-command"
    Local $bUnknown = _CLI_ExecuteLocal()
    _Test_AssertFalse("Unknown command returns false", $bUnknown)

    ; ---- Empty command returns False ----
    $__g_CLI_sCommand = ""
    Local $bEmpty = _CLI_ExecuteLocal()
    _Test_AssertFalse("Empty command returns false", $bEmpty)

    ; ---- GUI-only commands fail locally ----
    $__g_CLI_sCommand = "toggle-list"
    Local $bToggle = _CLI_ExecuteLocal()
    _Test_AssertFalse("toggle-list fails locally", $bToggle)

    $__g_CLI_sCommand = "toggle-carousel"
    Local $bCarousel = _CLI_ExecuteLocal()
    _Test_AssertFalse("toggle-carousel fails locally", $bCarousel)

    $__g_CLI_sCommand = "load-profile"
    $__g_CLI_sArg = "Test"
    Local $bLoadProf = _CLI_ExecuteLocal()
    _Test_AssertFalse("load-profile fails locally", $bLoadProf)

    $__g_CLI_sCommand = "save-profile"
    $__g_CLI_sArg = "Test"
    Local $bSaveProf = _CLI_ExecuteLocal()
    _Test_AssertFalse("save-profile fails locally", $bSaveProf)

    ; ---- goto validation: missing arg ----
    $__g_CLI_sCommand = "goto"
    $__g_CLI_sArg = ""
    Local $bGotoNoArg = _CLI_ExecuteLocal()
    _Test_AssertFalse("goto without arg fails", $bGotoNoArg)

    ; ---- goto validation: non-integer arg ----
    $__g_CLI_sCommand = "goto"
    $__g_CLI_sArg = "abc"
    Local $bGotoNaN = _CLI_ExecuteLocal()
    _Test_AssertFalse("goto with non-integer fails", $bGotoNaN)

    ; ---- remove-desktop validation: missing arg ----
    $__g_CLI_sCommand = "remove-desktop"
    $__g_CLI_sArg = ""
    Local $bRemNoArg = _CLI_ExecuteLocal()
    _Test_AssertFalse("remove-desktop without arg fails", $bRemNoArg)

    ; ---- rename validation: missing args ----
    $__g_CLI_sCommand = "rename"
    $__g_CLI_sArg = ""
    $__g_CLI_sArg2 = ""
    Local $bRenNoArg = _CLI_ExecuteLocal()
    _Test_AssertFalse("rename without args fails", $bRenNoArg)

    $__g_CLI_sCommand = "rename"
    $__g_CLI_sArg = "2"
    $__g_CLI_sArg2 = ""
    Local $bRenNoLabel = _CLI_ExecuteLocal()
    _Test_AssertFalse("rename without label fails", $bRenNoLabel)

    ; ---- move-window validation: missing arg ----
    $__g_CLI_sCommand = "move-window"
    $__g_CLI_sArg = ""
    Local $bMoveNoArg = _CLI_ExecuteLocal()
    _Test_AssertFalse("move-window without arg fails", $bMoveNoArg)

    $__g_CLI_sCommand = "move-window"
    $__g_CLI_sArg = "xyz"
    Local $bMoveNaN = _CLI_ExecuteLocal()
    _Test_AssertFalse("move-window with non-integer fails", $bMoveNaN)

    ; ---- JSON escape helper ----
    _Test_AssertEqual("JSON escape backslash", __CLI_EscapeJSON("a\b"), "a\\b")
    _Test_AssertEqual("JSON escape quote", __CLI_EscapeJSON('a"b'), 'a\"b')
    _Test_AssertEqual("JSON escape tab", __CLI_EscapeJSON("a" & @TAB & "b"), "a\tb")
    _Test_AssertEqual("JSON escape plain", __CLI_EscapeJSON("hello"), "hello")
    _Test_AssertEqual("JSON escape empty", __CLI_EscapeJSON(""), "")

    ; ---- IPC window lifecycle ----
    ; Register creates a window
    _Test_AssertEqual("IPC window initially 0", _CLI_GetIPCWindow(), 0)
    Local $bReg = _CLI_RegisterIPC()
    _Test_AssertTrue("RegisterIPC succeeds", $bReg)
    _Test_AssertNotEqual("IPC window created", _CLI_GetIPCWindow(), 0)

    ; Unregister destroys it
    _CLI_UnregisterIPC()
    _Test_AssertEqual("IPC window destroyed", _CLI_GetIPCWindow(), 0)

    ; ---- Cleanup globals ----
    $__g_CLI_sCommand = ""
    $__g_CLI_sArg = ""
    $__g_CLI_sArg2 = ""
    $__g_CLI_sIPCPending = ""
    $__g_CLI_sIPCPendingArg = ""
EndFunc
