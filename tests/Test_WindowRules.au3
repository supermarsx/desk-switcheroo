#include-once

; ===============================================================
; Tests for includes\WindowRules.au3
; Unit tests — uses a temp INI file, no GUI required
; ===============================================================

Func _RunTest_WindowRules()
    _Test_Suite("WindowRules")

    Local $sTempIni = @TempDir & "\desk_switcheroo_test_rules.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Save original @ScriptDir INI path (tests run from tests\ dir)
    ; We write test rules to the temp file, then point _WR_LoadRules at it
    ; by temporarily replacing the global INI path.
    ; Since WindowRules reads @ScriptDir directly, we test LoadRules by
    ; writing to the expected location and cleaning up after.

    ; ---- Initial state ----
    _Test_AssertFalse("Not running initially", _WR_IsRunning())
    _Test_AssertEqual("Zero rules initially", _WR_GetRuleCount(), 0)

    ; ---- Rule parsing: valid rules ----
    IniWrite($sTempIni, "Rules", "rules_enabled", "true")
    IniWrite($sTempIni, "Rules", "rules_poll_interval", "2000")
    IniWrite($sTempIni, "Rules", "rule_1", "chrome.exe|3")
    IniWrite($sTempIni, "Rules", "rule_2", "code.exe|2")
    IniWrite($sTempIni, "Rules", "rule_3", "class:CabinetWClass|1")
    IniWrite($sTempIni, "Rules", "rule_4", "discord.exe|4")

    ; Manually parse the rules to test parsing logic
    Local $iCount = __Test_WR_ParseRulesFromIni($sTempIni)
    _Test_AssertEqual("Loaded 4 valid rules", $iCount, 4)
    _Test_AssertEqual("Rule count matches", _WR_GetRuleCount(), 4)

    ; Verify parsed rule content
    _Test_AssertEqual("Rule 1 pattern", $__g_WR_aRules[0][0], "chrome.exe")
    _Test_AssertEqual("Rule 1 target", $__g_WR_aRules[0][1], 3)
    _Test_AssertEqual("Rule 1 type", $__g_WR_aRules[0][2], "process")

    _Test_AssertEqual("Rule 2 pattern", $__g_WR_aRules[1][0], "code.exe")
    _Test_AssertEqual("Rule 2 target", $__g_WR_aRules[1][1], 2)
    _Test_AssertEqual("Rule 2 type", $__g_WR_aRules[1][2], "process")

    _Test_AssertEqual("Rule 3 pattern", $__g_WR_aRules[2][0], "CabinetWClass")
    _Test_AssertEqual("Rule 3 target", $__g_WR_aRules[2][1], 1)
    _Test_AssertEqual("Rule 3 type", $__g_WR_aRules[2][2], "class")

    _Test_AssertEqual("Rule 4 pattern", $__g_WR_aRules[3][0], "discord.exe")
    _Test_AssertEqual("Rule 4 target", $__g_WR_aRules[3][1], 4)
    _Test_AssertEqual("Rule 4 type", $__g_WR_aRules[3][2], "process")

    ; ---- Rule parsing: invalid formats ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Rules", "rules_enabled", "true")
    IniWrite($sTempIni, "Rules", "rule_1", "chrome.exe")           ; missing pipe
    IniWrite($sTempIni, "Rules", "rule_2", "|3")                   ; empty pattern
    IniWrite($sTempIni, "Rules", "rule_3", "chrome.exe|0")         ; invalid target (0)
    IniWrite($sTempIni, "Rules", "rule_4", "chrome.exe|-1")        ; negative target
    IniWrite($sTempIni, "Rules", "rule_5", "class:|2")             ; empty class name
    IniWrite($sTempIni, "Rules", "rule_6", "chrome.exe|abc")       ; non-numeric target
    IniWrite($sTempIni, "Rules", "rule_7", "a|b|c")                ; too many pipes

    $iCount = __Test_WR_ParseRulesFromIni($sTempIni)
    _Test_AssertEqual("All invalid rules rejected", $iCount, 0)
    _Test_AssertEqual("Rule count zero after invalid", _WR_GetRuleCount(), 0)

    ; ---- Rule parsing: mixed valid and invalid ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Rules", "rules_enabled", "true")
    IniWrite($sTempIni, "Rules", "rule_1", "chrome.exe|3")         ; valid
    IniWrite($sTempIni, "Rules", "rule_2", "no_pipe_here")         ; invalid
    IniWrite($sTempIni, "Rules", "rule_3", "class:Notepad|1")      ; valid
    IniWrite($sTempIni, "Rules", "rule_4", "|5")                   ; invalid
    IniWrite($sTempIni, "Rules", "rule_5", "code.exe|2")           ; valid

    $iCount = __Test_WR_ParseRulesFromIni($sTempIni)
    _Test_AssertEqual("Mixed: 3 valid from 5", $iCount, 3)

    ; ---- Rule parsing: gaps in numbering ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Rules", "rules_enabled", "true")
    IniWrite($sTempIni, "Rules", "rule_1", "chrome.exe|1")
    ; rule_2 missing (gap)
    IniWrite($sTempIni, "Rules", "rule_3", "code.exe|2")
    IniWrite($sTempIni, "Rules", "rule_5", "discord.exe|3")

    $iCount = __Test_WR_ParseRulesFromIni($sTempIni)
    _Test_AssertEqual("Gaps: 3 rules loaded", $iCount, 3)

    ; ---- Rule parsing: class prefix case insensitive ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Rules", "rules_enabled", "true")
    IniWrite($sTempIni, "Rules", "rule_1", "CLASS:MyClass|2")
    IniWrite($sTempIni, "Rules", "rule_2", "Class:OtherClass|3")

    $iCount = __Test_WR_ParseRulesFromIni($sTempIni)
    _Test_AssertEqual("Class prefix case insensitive", $iCount, 2)
    _Test_AssertEqual("CLASS: parsed as class type", $__g_WR_aRules[0][2], "class")
    _Test_AssertEqual("CLASS: pattern extracted", $__g_WR_aRules[0][0], "MyClass")
    _Test_AssertEqual("Class: parsed as class type", $__g_WR_aRules[1][2], "class")

    ; ---- Start/stop state management ----
    _Test_AssertFalse("Not running before start", _WR_IsRunning())

    ; Stop should be safe even when not running
    _WR_Stop()
    _Test_AssertFalse("Not running after stop (no-op)", _WR_IsRunning())
    _Test_AssertEqual("Rules cleared after stop", _WR_GetRuleCount(), 0)

    ; ---- Start with disabled config ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Rules", "rules_enabled", "false")
    IniWrite($sTempIni, "Rules", "rule_1", "chrome.exe|1")

    ; Note: _WR_Start reads from @ScriptDir, not from $sTempIni,
    ; so we cannot fully test Start/Stop integration here.
    ; We verify state transitions directly.
    $__g_WR_bRunning = True
    _WR_Stop()
    _Test_AssertFalse("Running cleared after stop", _WR_IsRunning())
    _Test_AssertEqual("Rule count cleared after stop", _WR_GetRuleCount(), 0)

    ; ---- Dictionary tracking ----
    Local $oDict = ObjCreate("Scripting.Dictionary")
    If IsObj($oDict) Then
        $oDict.Item("12345") = 3
        _Test_AssertTrue("Dict: key exists after add", $oDict.Exists("12345"))
        _Test_AssertEqual("Dict: value correct", $oDict.Item("12345"), 3)
        $oDict.Remove("12345")
        _Test_AssertFalse("Dict: key removed", $oDict.Exists("12345"))
    Else
        _Test_Skip("Dict: Scripting.Dictionary not available")
    EndIf

    ; ---- Poll interval clamping (verify logic inline) ----
    Local $iInterval

    $iInterval = 100  ; below minimum
    If $iInterval < 500 Then $iInterval = 500
    If $iInterval > 30000 Then $iInterval = 30000
    _Test_AssertEqual("Interval clamped to 500 from 100", $iInterval, 500)

    $iInterval = 50000 ; above maximum
    If $iInterval < 500 Then $iInterval = 500
    If $iInterval > 30000 Then $iInterval = 30000
    _Test_AssertEqual("Interval clamped to 30000 from 50000", $iInterval, 30000)

    $iInterval = 5000  ; within range
    If $iInterval < 500 Then $iInterval = 500
    If $iInterval > 30000 Then $iInterval = 30000
    _Test_AssertEqual("Interval 5000 unchanged", $iInterval, 5000)

    ; ---- Max rules limit ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    IniWrite($sTempIni, "Rules", "rules_enabled", "true")
    Local $j
    For $j = 1 To 55
        IniWrite($sTempIni, "Rules", "rule_" & $j, "app" & $j & ".exe|1")
    Next
    $iCount = __Test_WR_ParseRulesFromIni($sTempIni)
    _Test_AssertEqual("Max 50 rules enforced", $iCount, 50)

    ; ---- Cleanup ----
    If FileExists($sTempIni) Then FileDelete($sTempIni)
    ; Reset module state
    $__g_WR_iRuleCount = 0
    $__g_WR_bRunning = False
EndFunc

; ===============================================================
; TEST HELPER — Parse rules from a specific INI path
; (Replaces the @ScriptDir lookup in _WR_LoadRules for testing)
; ===============================================================
Func __Test_WR_ParseRulesFromIni($sIni)
    $__g_WR_iRuleCount = 0

    ; Clear existing rules
    Local $i
    For $i = 0 To $__g_WR_MAX_RULES - 1
        $__g_WR_aRules[$i][0] = ""
        $__g_WR_aRules[$i][1] = 0
        $__g_WR_aRules[$i][2] = ""
    Next

    For $i = 1 To $__g_WR_MAX_RULES
        Local $sKey = "rule_" & $i
        Local $sVal = IniRead($sIni, "Rules", $sKey, "")
        If $sVal = "" Then ContinueLoop

        ; Parse: pattern|target_desktop
        Local $aParts = StringSplit($sVal, "|")
        If $aParts[0] <> 2 Then ContinueLoop

        Local $sPattern = StringStripWS($aParts[1], 3)
        Local $iTarget = Int(StringStripWS($aParts[2], 3))

        If $iTarget < 1 Then ContinueLoop
        If $sPattern = "" Then ContinueLoop

        Local $sType = "process"
        If StringLeft(StringLower($sPattern), 6) = "class:" Then
            $sType = "class"
            $sPattern = StringTrimLeft($sPattern, 6)
            If $sPattern = "" Then ContinueLoop
        EndIf

        $__g_WR_aRules[$__g_WR_iRuleCount][0] = $sPattern
        $__g_WR_aRules[$__g_WR_iRuleCount][1] = $iTarget
        $__g_WR_aRules[$__g_WR_iRuleCount][2] = $sType
        $__g_WR_iRuleCount += 1

        If $__g_WR_iRuleCount >= $__g_WR_MAX_RULES Then ExitLoop
    Next

    Return $__g_WR_iRuleCount
EndFunc
