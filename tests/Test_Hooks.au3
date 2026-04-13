#include-once

; ===============================================================
; Tests for includes\Hooks.au3
; Unit tests — uses a temp INI file, no GUI required
; ===============================================================

Func _RunTest_Hooks()
    _Test_Suite("Hooks")

    Local $sTempIni = @TempDir & "\desk_switcheroo_test_hooks.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; ---- Save and set INI path for hooks to read ----
    Local $sOrigPath = _Cfg_GetPath()
    _Cfg_Init($sTempIni)

    ; == Disabled by default ==
    _Test_AssertFalse("Hooks disabled by default", _Hooks_Init())
    _Test_AssertFalse("IsEnabled = False when disabled", _Hooks_IsEnabled())
    _Test_AssertEqual("HookCount = 0 when disabled", _Hooks_GetHookCount(), 0)

    ; == Enable hooks with no hook entries ==
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    _Test_AssertTrue("Init returns True when enabled", _Hooks_Init())
    _Test_AssertTrue("IsEnabled = True", _Hooks_IsEnabled())
    _Test_AssertEqual("HookCount = 0 with no entries", _Hooks_GetHookCount(), 0)
    _Hooks_Shutdown()

    ; == Load single hook ==
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo startup")
    _Hooks_Init()
    _Test_AssertEqual("Single hook loaded", _Hooks_GetHookCount(), 1)
    _Hooks_Shutdown()

    ; == Multiple hooks for same event (numbered keys) ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_desktop_change_1", "cmd /c echo first")
    IniWrite($sTempIni, "Hooks", "on_desktop_change_2", "cmd /c echo second")
    IniWrite($sTempIni, "Hooks", "on_desktop_change_3", "cmd /c echo third")
    _Hooks_Init()
    _Test_AssertEqual("Three numbered hooks loaded", _Hooks_GetHookCount(), 3)
    _Hooks_Shutdown()

    ; == Mixed event types ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo start")
    IniWrite($sTempIni, "Hooks", "on_shutdown", "cmd /c echo stop")
    IniWrite($sTempIni, "Hooks", "on_desktop_change", "cmd /c echo change")
    IniWrite($sTempIni, "Hooks", "on_desktop_create", "cmd /c echo create")
    IniWrite($sTempIni, "Hooks", "on_desktop_delete", "cmd /c echo delete")
    IniWrite($sTempIni, "Hooks", "on_window_move", "cmd /c echo move")
    IniWrite($sTempIni, "Hooks", "on_profile_load", "cmd /c echo profile")
    IniWrite($sTempIni, "Hooks", "on_carousel_tick", "cmd /c echo tick")
    _Hooks_Init()
    _Test_AssertEqual("All 8 event types loaded", _Hooks_GetHookCount(), 8)
    _Hooks_Shutdown()

    ; == Invalid event name is ignored ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_invalid_event", "cmd /c echo bad")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo good")
    _Hooks_Init()
    _Test_AssertEqual("Invalid event ignored, valid counted", _Hooks_GetHookCount(), 1)
    _Hooks_Shutdown()

    ; == Empty value is skipped ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_startup", "")
    _Hooks_Init()
    _Test_AssertEqual("Empty value skipped", _Hooks_GetHookCount(), 0)
    _Hooks_Shutdown()

    ; == Config keys (hooks_enabled, hooks_timeout) not counted as hooks ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "hooks_timeout", "5000")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo test")
    _Hooks_Init()
    _Test_AssertEqual("Config keys not counted", _Hooks_GetHookCount(), 1)
    _Hooks_Shutdown()

    ; == Reload hooks clears and reloads ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo one")
    _Hooks_Init()
    _Test_AssertEqual("Initial load = 1", _Hooks_GetHookCount(), 1)
    IniWrite($sTempIni, "Hooks", "on_shutdown", "cmd /c echo two")
    Local $iReloaded = _Hooks_LoadHooks()
    _Test_AssertEqual("Reload returns new count", $iReloaded, 2)
    _Test_AssertEqual("GetHookCount matches reload", _Hooks_GetHookCount(), 2)
    _Hooks_Shutdown()

    ; == Timeout clamping ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "hooks_timeout", "100")
    _Hooks_Init()
    _Test_AssertGreaterEqual("Timeout clamped low >= 1000", $__g_Hooks_iTimeout, 1000)
    _Hooks_Shutdown()

    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "hooks_timeout", "999999")
    _Hooks_Init()
    _Test_AssertLessEqual("Timeout clamped high <= 300000", $__g_Hooks_iTimeout, 300000)
    _Hooks_Shutdown()

    ; == Variable substitution tests ==
    Local $sResult

    ; Basic substitution
    $sResult = __Hooks_SubstituteVars("echo {desktop}", "desktop=3")
    _Test_AssertEqual("SubstVar: single var", $sResult, "echo 3")

    ; Multiple variables
    $sResult = __Hooks_SubstituteVars("echo {desktop} {desktop_name}", "desktop=3|desktop_name=Work")
    _Test_AssertEqual("SubstVar: multiple vars", $sResult, "echo 3 Work")

    ; All supported variables
    $sResult = __Hooks_SubstituteVars("{desktop} {desktop_name} {desktop_count} {prev_desktop} {window_title} {window_process} {profile_name}", _
        "desktop=2|desktop_name=Dev|desktop_count=5|prev_desktop=1|window_title=Notepad|window_process=notepad.exe|profile_name=coding")
    _Test_AssertEqual("SubstVar: all vars", $sResult, "2 Dev 5 1 Notepad notepad.exe coding")

    ; Missing variable left as-is
    $sResult = __Hooks_SubstituteVars("echo {desktop} {missing}", "desktop=3")
    _Test_AssertEqual("SubstVar: missing var unchanged", $sResult, "echo 3 {missing}")

    ; Empty params leaves command unchanged
    $sResult = __Hooks_SubstituteVars("echo {desktop}", "")
    _Test_AssertEqual("SubstVar: empty params", $sResult, "echo {desktop}")

    ; Empty value in pair
    $sResult = __Hooks_SubstituteVars("echo {desktop}", "desktop=")
    _Test_AssertEqual("SubstVar: empty value", $sResult, "echo ")

    ; Variable with special characters in value
    $sResult = __Hooks_SubstituteVars("echo {window_title}", "window_title=My App (v2.0)")
    _Test_AssertEqual("SubstVar: special chars in value", $sResult, "echo My App (v2.0)")

    ; No placeholders in command
    $sResult = __Hooks_SubstituteVars("echo hello", "desktop=3")
    _Test_AssertEqual("SubstVar: no placeholders", $sResult, "echo hello")

    ; == ParseHookLine tests ==
    Local $aParsed

    ; Valid event
    $aParsed = __Hooks_ParseHookLine("on_startup", "cmd /c echo test")
    _Test_AssertTrue("ParseLine: valid returns array", IsArray($aParsed))
    _Test_AssertEqual("ParseLine: event name", $aParsed[0][0], "on_startup")
    _Test_AssertEqual("ParseLine: command", $aParsed[0][1], "cmd /c echo test")

    ; Numbered event
    $aParsed = __Hooks_ParseHookLine("on_desktop_change_2", "cmd /c echo second")
    _Test_AssertTrue("ParseLine: numbered returns array", IsArray($aParsed))
    _Test_AssertEqual("ParseLine: numbered event name", $aParsed[0][0], "on_desktop_change")
    _Test_AssertEqual("ParseLine: numbered command", $aParsed[0][1], "cmd /c echo second")

    ; Invalid event returns 0
    $aParsed = __Hooks_ParseHookLine("on_bogus_event", "cmd /c echo bad")
    _Test_AssertEqual("ParseLine: invalid event returns 0", $aParsed, 0)

    ; Empty value returns 0
    $aParsed = __Hooks_ParseHookLine("on_startup", "")
    _Test_AssertEqual("ParseLine: empty value returns 0", $aParsed, 0)

    ; All valid event names parse correctly
    $aParsed = __Hooks_ParseHookLine("on_desktop_change", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_desktop_change", $aParsed[0][0], "on_desktop_change")
    $aParsed = __Hooks_ParseHookLine("on_desktop_create", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_desktop_create", $aParsed[0][0], "on_desktop_create")
    $aParsed = __Hooks_ParseHookLine("on_desktop_delete", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_desktop_delete", $aParsed[0][0], "on_desktop_delete")
    $aParsed = __Hooks_ParseHookLine("on_window_move", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_window_move", $aParsed[0][0], "on_window_move")
    $aParsed = __Hooks_ParseHookLine("on_profile_load", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_profile_load", $aParsed[0][0], "on_profile_load")
    $aParsed = __Hooks_ParseHookLine("on_startup", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_startup", $aParsed[0][0], "on_startup")
    $aParsed = __Hooks_ParseHookLine("on_shutdown", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_shutdown", $aParsed[0][0], "on_shutdown")
    $aParsed = __Hooks_ParseHookLine("on_carousel_tick", "cmd /c echo")
    _Test_AssertEqual("ParseLine: on_carousel_tick", $aParsed[0][0], "on_carousel_tick")

    ; == IsValidEvent tests ==
    _Test_AssertTrue("ValidEvent: on_desktop_change", __Hooks_IsValidEvent("on_desktop_change"))
    _Test_AssertTrue("ValidEvent: on_startup", __Hooks_IsValidEvent("on_startup"))
    _Test_AssertTrue("ValidEvent: on_carousel_tick", __Hooks_IsValidEvent("on_carousel_tick"))
    _Test_AssertFalse("ValidEvent: invalid name", __Hooks_IsValidEvent("on_fake_event"))
    _Test_AssertFalse("ValidEvent: empty string", __Hooks_IsValidEvent(""))

    ; == Shutdown resets state ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo test")
    _Hooks_Init()
    _Test_AssertTrue("Before shutdown: enabled", _Hooks_IsEnabled())
    _Test_AssertEqual("Before shutdown: count > 0", _Hooks_GetHookCount(), 1)
    _Hooks_Shutdown()
    _Test_AssertFalse("After shutdown: disabled", _Hooks_IsEnabled())
    _Test_AssertEqual("After shutdown: count = 0", _Hooks_GetHookCount(), 0)

    ; == Fire does not crash when disabled ==
    _Hooks_Shutdown()
    _Hooks_Fire("on_startup", "")
    _Test_AssertTrue("Fire while disabled no crash", True)

    ; == Fire does not crash with unknown event ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo test")
    _Hooks_Init()
    _Hooks_Fire("on_nonexistent_event", "")
    _Test_AssertTrue("Fire unknown event no crash", True)
    _Hooks_Shutdown()

    ; == Enabled flag case-insensitive ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "True")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo test")
    _Test_AssertTrue("Enabled: 'True' (mixed case)", _Hooks_Init())
    _Hooks_Shutdown()

    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "TRUE")
    IniWrite($sTempIni, "Hooks", "on_startup", "cmd /c echo test")
    _Test_AssertTrue("Enabled: 'TRUE' (upper case)", _Hooks_Init())
    _Hooks_Shutdown()

    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "false")
    _Test_AssertFalse("Disabled: 'false'", _Hooks_Init())

    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "yes")
    _Test_AssertFalse("Disabled: 'yes' (not 'true')", _Hooks_Init())

    ; == Cleanup temp file ==
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Restore original config path
    If $sOrigPath <> "" Then _Cfg_Init($sOrigPath)
EndFunc
