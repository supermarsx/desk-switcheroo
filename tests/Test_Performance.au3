#include-once

; ===============================================================
; Performance tests for desk-switcheroo
; Benchmarks critical code paths with threshold assertions
; Run with: AutoIt3.exe tests\TestRunner.au3
; ===============================================================

; ==== HELPER FUNCTIONS ====

Func __Perf_AssertAvgBelow($sName, $fTotalMs, $iIterations, $fMaxAvgMs)
    Local $fAvg = $fTotalMs / $iIterations
    ConsoleWrite("    INFO: " & $sName & ": " & Round($fAvg, 4) & "ms avg (" & $iIterations & " iters, " & Round($fTotalMs, 1) & "ms total)" & @CRLF)
    _Test_AssertLessEqual($sName, Round($fAvg, 4), $fMaxAvgMs)
EndFunc

Func __Perf_AssertTotalBelow($sName, $fTotalMs, $fMaxMs)
    ConsoleWrite("    INFO: " & $sName & ": " & Round($fTotalMs, 1) & "ms" & @CRLF)
    _Test_AssertLessEqual($sName, Round($fTotalMs, 1), $fMaxMs)
EndFunc

Func __Perf_ReportThroughput($sName, $fTotalMs, $iIterations)
    Local $fOpsPerSec = 0
    If $fTotalMs > 0 Then $fOpsPerSec = ($iIterations / $fTotalMs) * 1000
    ConsoleWrite("    INFO: " & $sName & ": " & Round($fOpsPerSec, 0) & " ops/sec (" & $iIterations & " iters in " & Round($fTotalMs, 1) & "ms)" & @CRLF)
EndFunc

Func __Perf_CreateTempIni($sPrefix)
    Local $sPath = @TempDir & "\perf_" & $sPrefix & ".ini"
    If FileExists($sPath) Then FileDelete($sPath)
    Return $sPath
EndFunc

; ==== ENTRY POINT ====

Func _RunTest_Performance()
    _Test_Suite("Performance")
    __Perf_i18n()
    __Perf_Config()
    __Perf_Hooks()
    __Perf_Profiles()
    __Perf_WindowRules()
    __Perf_CLI()
    __Perf_WindowList()
    __Perf_SessionRestore()
EndFunc

; ==== SUITE A: i18n Performance ====

Func __Perf_i18n()
    Local $hTimer, $fTotal, $i

    ; A1. _i18n_Init single locale
    $hTimer = TimerInit()
    For $i = 1 To 5
        _i18n_Init("en-US")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n_Init single locale", $fTotal, 5, 250)

    ; A2. _i18n_Init with fallback (two files)
    $hTimer = TimerInit()
    For $i = 1 To 5
        _i18n_Init("pt-BR")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n_Init fallback locale", $fTotal, 5, 400)
    _i18n_Init("en-US") ; restore

    ; A3. _i18n() hot path — known key
    Local $sResult
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = _i18n("Toasts.toast_saved", "Settings saved")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n lookup known key", $fTotal, 10000, 0.05)

    ; A4. _i18n() — missing key (fallback chain)
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = _i18n("NonExistent.fake_key", "Default")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n lookup missing key", $fTotal, 10000, 0.05)

    ; A5. _i18n_Format with 1 placeholder
    $hTimer = TimerInit()
    For $i = 1 To 5000
        $sResult = _i18n_Format("Toasts.toast_window_sent", "Window sent to Desktop {1}", 3)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n_Format 1 placeholder", $fTotal, 5000, 0.1)

    ; A6. _i18n_Format with 3 placeholders
    $hTimer = TimerInit()
    For $i = 1 To 5000
        $sResult = _i18n_Format("NonExistent.test", "a={1} b={2} c={3}", "X", "Y", "Z")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n_Format 3 placeholders", $fTotal, 5000, 0.15)

    ; A7. Lookup throughput report (info only)
    $hTimer = TimerInit()
    For $i = 1 To 50000
        $sResult = _i18n("Toasts.toast_saved", "Settings saved")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_ReportThroughput("i18n lookup throughput", $fTotal, 50000)

    ; A8. _i18n_GetAvailable dir scan
    $hTimer = TimerInit()
    For $i = 1 To 3
        $sResult = _i18n_GetAvailable()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("i18n_GetAvailable dir scan", $fTotal, 3, 200)
EndFunc

; ==== SUITE B: Config Performance ====

Func __Perf_Config()
    Local $hTimer, $fTotal, $i
    Local $sOrigPath = _Cfg_GetPath()

    ; B1. _Cfg_Init fresh file (writes defaults + loads)
    Local $sTempIni = __Perf_CreateTempIni("cfg_fresh")
    $hTimer = TimerInit()
    For $i = 1 To 3
        If FileExists($sTempIni) Then FileDelete($sTempIni)
        _Cfg_Init($sTempIni)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Cfg_Init fresh file", $fTotal, 3, 500)

    ; B2. _Cfg_Load existing INI (all keys present)
    _Cfg_Init($sTempIni) ; ensure populated
    $hTimer = TimerInit()
    For $i = 1 To 5
        _Cfg_Load()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Cfg_Load existing INI", $fTotal, 5, 200)

    ; B3. _Cfg_Save full config
    $hTimer = TimerInit()
    For $i = 1 To 3
        $__g_Cfg_hSaveTimer = 0 ; bypass debounce
        _Cfg_Save()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Cfg_Save full config", $fTotal, 3, 500)

    ; B4. _Cfg_WriteDefaults (all keys exist, conditional writes skip)
    $hTimer = TimerInit()
    For $i = 1 To 5
        _Cfg_WriteDefaults()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Cfg_WriteDefaults (keys exist)", $fTotal, 5, 300)

    ; B5. Getter throughput (20 getters, in-memory)
    Local $v
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $v = _Cfg_GetLanguage()
        $v = _Cfg_GetWrapNavigation()
        $v = _Cfg_GetShowCount()
        $v = _Cfg_GetTheme()
        $v = _Cfg_GetAnimationsEnabled()
        $v = _Cfg_GetPinningEnabled()
        $v = _Cfg_GetLoggingEnabled()
        $v = _Cfg_GetSingletonEnabled()
        $v = _Cfg_GetTrayIconMode()
        $v = _Cfg_GetScrollEnabled()
        $v = _Cfg_GetWindowListPosition()
        $v = _Cfg_GetWidgetPosition()
        $v = _Cfg_GetOsdEnabled()
        $v = _Cfg_GetOsdPosition()
        $v = _Cfg_GetAutoHideSyncEnabled()
        $v = _Cfg_GetNotificationsEnabled()
        $v = _Cfg_GetAutoCreateDesktop()
        $v = _Cfg_GetNumberPadding()
        $v = _Cfg_GetWidgetDragEnabled()
        $v = _Cfg_GetQuickAccessEnabled()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Config getter throughput (20/iter)", $fTotal, 10000, 0.05)

    ; B6. Setter+getter round-trip (in-memory)
    $hTimer = TimerInit()
    For $i = 1 To 10000
        _Cfg_SetScrollEnabled(True)
        $v = _Cfg_GetScrollEnabled()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Config setter+getter round-trip", $fTotal, 10000, 0.05)

    ; B7. _Cfg_Init with empty file (worst-case first run)
    Local $sTempEmpty = __Perf_CreateTempIni("cfg_empty")
    $hTimer = TimerInit()
    For $i = 1 To 3
        FileDelete($sTempEmpty)
        FileWrite($sTempEmpty, "") ; create empty file
        _Cfg_Init($sTempEmpty)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Cfg_Init empty file", $fTotal, 3, 600)
    FileDelete($sTempEmpty)

    ; B8. Load scaling: minimal vs full INI
    Local $sTempMin = __Perf_CreateTempIni("cfg_min")
    IniWrite($sTempMin, "General", "language", "en-US")
    IniWrite($sTempMin, "General", "wrap_navigation", "true")
    IniWrite($sTempMin, "General", "auto_create_desktop", "false")
    IniWrite($sTempMin, "General", "number_padding", "2")
    IniWrite($sTempMin, "General", "widget_position", "bottom-left")
    _Cfg_Init($sTempMin)
    $hTimer = TimerInit()
    _Cfg_Load()
    Local $fMinimal = TimerDiff($hTimer)
    ; Single cold-ish INI loads are noisy on shared CI runners, so keep a modest headroom here.
    __Perf_AssertTotalBelow("Cfg_Load minimal INI", $fMinimal, 75)
    FileDelete($sTempMin)

    _Cfg_Init($sTempIni) ; full INI
    $hTimer = TimerInit()
    _Cfg_Load()
    Local $fFull = TimerDiff($hTimer)
    __Perf_AssertTotalBelow("Cfg_Load full INI", $fFull, 200)

    ; B9. __Cfg_ReadBool throughput
    $hTimer = TimerInit()
    For $i = 1 To 5000
        __Cfg_ReadBool($sTempIni, "General", "wrap_navigation", True)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("__Cfg_ReadBool throughput", $fTotal, 5000, 0.5)

    ; B10. __Cfg_ReadEnum throughput
    $hTimer = TimerInit()
    For $i = 1 To 5000
        __Cfg_ReadEnum($sTempIni, "General", "widget_position", "bottom-left", _
            "bottom-left|bottom-center|bottom-right|middle-left|middle-right|top-left|top-center|top-right|left|center|right")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("__Cfg_ReadEnum throughput", $fTotal, 5000, 0.5)

    ; Cleanup
    FileDelete($sTempIni)
    FileDelete($sTempIni & ".tmp")
    _Cfg_Init($sOrigPath)
EndFunc

; ==== SUITE C: Hooks Performance ====

Func __Perf_Hooks()
    Local $hTimer, $fTotal, $i, $sResult

    ; C1. __Hooks_SubstituteVars — 3 vars
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = __Hooks_SubstituteVars("echo {desktop} {desktop_name} {prev_desktop}", "desktop=3|desktop_name=Work|prev_desktop=1")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Hooks SubstituteVars 3 vars", $fTotal, 10000, 0.1)

    ; C2. __Hooks_SubstituteVars — 7 vars (max)
    $hTimer = TimerInit()
    For $i = 1 To 5000
        $sResult = __Hooks_SubstituteVars("echo {desktop} {desktop_name} {desktop_count} {prev_desktop} {window_title} {window_process} {profile_name}", _
            "desktop=3|desktop_name=Work|desktop_count=5|prev_desktop=1|window_title=My App|window_process=app.exe|profile_name=default")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Hooks SubstituteVars 7 vars", $fTotal, 5000, 0.15)

    ; C3. __Hooks_IsValidEvent throughput
    $hTimer = TimerInit()
    For $i = 1 To 10000
        __Hooks_IsValidEvent("on_desktop_change")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Hooks IsValidEvent throughput", $fTotal, 10000, 0.1)

    ; C4. __Hooks_ParseHookLine throughput
    Local $aParsed
    $hTimer = TimerInit()
    For $i = 1 To 5000
        $aParsed = __Hooks_ParseHookLine("on_desktop_change_2", "cmd /c echo test")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Hooks ParseHookLine throughput", $fTotal, 5000, 0.15)

    ; C5. _Hooks_Init with 20 hooks
    Local $sOrigPath = _Cfg_GetPath()
    Local $sTempIni = __Perf_CreateTempIni("hooks")
    _Cfg_Init($sTempIni)
    For $i = 1 To 20
        IniWrite($sTempIni, "Hooks", "on_desktop_change_" & $i, "cmd /c echo hook " & $i)
    Next
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "hooks_timeout", "10000")
    $hTimer = TimerInit()
    For $i = 1 To 3
        _Hooks_Init()
        _Hooks_Shutdown()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Hooks Init 20 hooks", $fTotal, 3, 150)

    ; C6. Hooks init scaling: 5 / 20 / 50
    ; 5 hooks
    FileDelete($sTempIni)
    IniWrite($sTempIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sTempIni, "Hooks", "hooks_timeout", "10000")
    For $i = 1 To 5
        IniWrite($sTempIni, "Hooks", "on_desktop_change_" & $i, "cmd /c echo hook " & $i)
    Next
    _Cfg_Init($sTempIni)
    $hTimer = TimerInit()
    For $i = 1 To 3
        _Hooks_Init()
        _Hooks_Shutdown()
    Next
    Local $fH5 = TimerDiff($hTimer) / 3
    __Perf_AssertTotalBelow("Hooks Init 5 hooks avg", $fH5, 200)

    ; 20 hooks
    For $i = 6 To 20
        IniWrite($sTempIni, "Hooks", "on_desktop_change_" & $i, "cmd /c echo hook " & $i)
    Next
    _Cfg_Init($sTempIni)
    $hTimer = TimerInit()
    For $i = 1 To 3
        _Hooks_Init()
        _Hooks_Shutdown()
    Next
    Local $fH20 = TimerDiff($hTimer) / 3
    __Perf_AssertTotalBelow("Hooks Init 20 hooks avg", $fH20, 200)

    ; 50 hooks
    For $i = 21 To 50
        IniWrite($sTempIni, "Hooks", "on_desktop_change_" & $i, "cmd /c echo hook " & $i)
    Next
    _Cfg_Init($sTempIni)
    $hTimer = TimerInit()
    For $i = 1 To 3
        _Hooks_Init()
        _Hooks_Shutdown()
    Next
    Local $fH50 = TimerDiff($hTimer) / 3
    __Perf_AssertTotalBelow("Hooks Init 50 hooks avg", $fH50, 200)
    __Perf_ReportThroughput("Hooks Init scaling (5/20/50)", $fH5 + $fH20 + $fH50, 3)

    ; Cleanup
    FileDelete($sTempIni)
    _Cfg_Init($sOrigPath)
EndFunc

; ==== SUITE D: Profiles Performance ====

Func __Perf_Profiles()
    Local $hTimer, $fTotal, $i, $sResult

    ; D1. __Prof_SanitizeName — typical input
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = __Prof_SanitizeName("My Work Profile!@#$% 2024")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Prof SanitizeName typical", $fTotal, 10000, 0.5)

    ; D2. __Prof_SanitizeName — long input (80 chars)
    Local $sLong = ""
    For $i = 1 To 80
        $sLong &= Chr(65 + Mod($i, 26))
    Next
    $hTimer = TimerInit()
    For $i = 1 To 5000
        $sResult = __Prof_SanitizeName($sLong)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Prof SanitizeName long input", $fTotal, 5000, 0.5)

    ; D3. _Prof_GetProfilePath throughput
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = _Prof_GetProfilePath("MyProfile")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Prof GetProfilePath throughput", $fTotal, 10000, 0.5)

    ; D4. _Prof_ListProfiles with 10 profiles
    Local $sTempDir = @TempDir & "\perf_profiles"
    If FileExists($sTempDir) Then DirRemove($sTempDir, 1)
    DirCreate($sTempDir)
    DirCreate($sTempDir & "\profiles")
    IniWrite($sTempDir & "\desk_switcheroo.ini", "Profiles", "profiles_enabled", "true")
    _Prof_Init($sTempDir)
    For $i = 1 To 10
        Local $sProfileIni = $sTempDir & "\profiles\profile" & $i & ".ini"
        IniWrite($sProfileIni, "Meta", "name", "Profile " & $i)
        IniWrite($sProfileIni, "Meta", "created", "2024-01-01")
    Next
    $hTimer = TimerInit()
    For $i = 1 To 5
        $sResult = _Prof_ListProfiles()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Prof ListProfiles 10 profiles", $fTotal, 5, 200)

    ; D5. __Prof_ReadProfileMeta throughput
    Local $sMetaIni = $sTempDir & "\profiles\profile1.ini"
    $hTimer = TimerInit()
    For $i = 1 To 100
        __Prof_ReadProfileMeta($sMetaIni)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Prof ReadProfileMeta throughput", $fTotal, 100, 5)

    ; Cleanup
    DirRemove($sTempDir, 1)
EndFunc

; ==== SUITE E: Window Rules Performance ====

Func __Perf_WindowRules()
    Local $hTimer, $fTotal, $i

    ; E1. Rule parsing: 10 rules
    Local $sTempIni = __Perf_CreateTempIni("rules10")
    For $i = 1 To 10
        IniWrite($sTempIni, "Rules", "rule_" & $i, "app" & $i & ".exe|" & Mod($i, 5) + 1)
    Next
    $hTimer = TimerInit()
    For $i = 1 To 5
        __Test_WR_ParseRulesFromIni($sTempIni)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("WR parse 10 rules", $fTotal, 5, 100)

    ; E2. Rule parsing: 50 rules
    FileDelete($sTempIni)
    For $i = 1 To 50
        IniWrite($sTempIni, "Rules", "rule_" & $i, "app" & $i & ".exe|" & Mod($i, 5) + 1)
    Next
    $hTimer = TimerInit()
    For $i = 1 To 3
        __Test_WR_ParseRulesFromIni($sTempIni)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("WR parse 50 rules", $fTotal, 3, 300)

    ; E3. Rule parsing scaling: 10 / 25 / 50
    ; 10 rules
    FileDelete($sTempIni)
    For $i = 1 To 10
        IniWrite($sTempIni, "Rules", "rule_" & $i, "app" & $i & ".exe|" & Mod($i, 5) + 1)
    Next
    $hTimer = TimerInit()
    For $i = 1 To 3
        __Test_WR_ParseRulesFromIni($sTempIni)
    Next
    Local $fR10 = TimerDiff($hTimer) / 3

    ; 25 rules
    For $i = 11 To 25
        IniWrite($sTempIni, "Rules", "rule_" & $i, "app" & $i & ".exe|" & Mod($i, 5) + 1)
    Next
    $hTimer = TimerInit()
    For $i = 1 To 3
        __Test_WR_ParseRulesFromIni($sTempIni)
    Next
    Local $fR25 = TimerDiff($hTimer) / 3

    ; 50 rules
    For $i = 26 To 50
        IniWrite($sTempIni, "Rules", "rule_" & $i, "app" & $i & ".exe|" & Mod($i, 5) + 1)
    Next
    $hTimer = TimerInit()
    For $i = 1 To 3
        __Test_WR_ParseRulesFromIni($sTempIni)
    Next
    Local $fR50 = TimerDiff($hTimer) / 3

    __Perf_AssertTotalBelow("WR scaling 10 rules", $fR10, 300)
    __Perf_AssertTotalBelow("WR scaling 25 rules", $fR25, 300)
    __Perf_AssertTotalBelow("WR scaling 50 rules", $fR50, 300)
    ConsoleWrite("    INFO: WR scaling: 10=" & Round($fR10, 1) & "ms, 25=" & Round($fR25, 1) & "ms, 50=" & Round($fR50, 1) & "ms" & @CRLF)

    ; E4. In-memory rule string parsing (no IniRead)
    Local $sVal = "chrome.exe|3"
    Local $aParts, $sPattern, $iTarget, $sType
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $aParts = StringSplit($sVal, "|")
        $sPattern = StringStripWS($aParts[1], 3)
        $iTarget = Int(StringStripWS($aParts[2], 3))
        $sType = "process"
        If StringLeft(StringLower($sPattern), 6) = "class:" Then $sType = "class"
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("WR in-memory string parse", $fTotal, 10000, 0.05)

    ; E5. Dictionary ops (HWND tracking simulation)
    Local $oDict = ObjCreate("Scripting.Dictionary")
    For $i = 1 To 100
        $oDict.Add("0x" & Hex($i, 8), $i)
    Next
    Local $bExists
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $bExists = $oDict.Exists("0x" & Hex(50, 8))
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("Dictionary Exists throughput", $fTotal, 10000, 0.05)
    $oDict.RemoveAll()
    $oDict = 0

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; ==== SUITE F: CLI Performance ====

Func __Perf_CLI()
    Local $hTimer, $fTotal, $i, $sResult

    ; F1. __CLI_EscapeJSON throughput
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = __CLI_EscapeJSON('Desktop "Work" \\ Tab' & @TAB & ' test')
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("CLI EscapeJSON throughput", $fTotal, 10000, 0.05)

    ; F2. _CLI_IsQueryCommand throughput
    Local $sSaveCmd = $__g_CLI_sCommand
    $__g_CLI_sCommand = "--list-desktops"
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $sResult = _CLI_IsQueryCommand()
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("CLI IsQueryCommand throughput", $fTotal, 10000, 0.05)
    $__g_CLI_sCommand = $sSaveCmd
EndFunc

; ==== SUITE G: Window List Position ====

Func __Perf_WindowList()
    Local $hTimer, $fTotal, $i
    Local $iX, $iY

    ; G1. __WL_CalcPosition — all 9 positions
    $hTimer = TimerInit()
    For $i = 1 To 5000
        __WL_CalcPosition("top-left", 300, 400, $iX, $iY)
        __WL_CalcPosition("top-center", 300, 400, $iX, $iY)
        __WL_CalcPosition("top-right", 300, 400, $iX, $iY)
        __WL_CalcPosition("middle-left", 300, 400, $iX, $iY)
        __WL_CalcPosition("middle-center", 300, 400, $iX, $iY)
        __WL_CalcPosition("middle-right", 300, 400, $iX, $iY)
        __WL_CalcPosition("bottom-left", 300, 400, $iX, $iY)
        __WL_CalcPosition("bottom-center", 300, 400, $iX, $iY)
        __WL_CalcPosition("bottom-right", 300, 400, $iX, $iY)
    Next
    $fTotal = TimerDiff($hTimer)
    ; Nine string-dispatch calls per iteration are consistently slower on hosted runners than local dev boxes.
    __Perf_AssertAvgBelow("WL CalcPosition all 9 positions", $fTotal, 5000, 0.35)

    ; G2. __WL_CalcPosition — edge case (oversized triggers clamping)
    $hTimer = TimerInit()
    For $i = 1 To 5000
        __WL_CalcPosition("bottom-right", 99999, 99999, $iX, $iY)
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("WL CalcPosition oversized (clamp)", $fTotal, 5000, 0.05)
EndFunc

; ==== SUITE H: Session Restore Performance ====

Func __Perf_SessionRestore()
    Local $hTimer, $fTotal, $i, $bResult

    ; H1. __SR_IsSystemProcess — non-match (full scan)
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $bResult = __SR_IsSystemProcess("chrome.exe")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("SR IsSystemProcess non-match", $fTotal, 10000, 0.05)

    ; H2. __SR_IsSystemProcess — known match (early exit)
    $hTimer = TimerInit()
    For $i = 1 To 10000
        $bResult = __SR_IsSystemProcess("explorer.exe")
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("SR IsSystemProcess match", $fTotal, 10000, 0.05)

    ; H3. Batch IniWrite scaling (100 entries, simulates session save)
    Local $sTempIni = __Perf_CreateTempIni("session")
    $hTimer = TimerInit()
    For $i = 1 To 3
        FileDelete($sTempIni)
        Local $j
        For $j = 1 To 100
            IniWrite($sTempIni, "Desktop_" & Mod($j, 5) + 1, "window_" & $j, "app" & $j & ".exe|ClassName|100|100|800|600")
        Next
    Next
    $fTotal = TimerDiff($hTimer)
    __Perf_AssertAvgBelow("SR batch IniWrite 100 entries", $fTotal, 3, 500)

    ; Cleanup
    FileDelete($sTempIni)
EndFunc
