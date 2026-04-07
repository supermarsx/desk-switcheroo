#include <GUIConstantsEx.au3>

; ===============================================================
; Desk Switcheroo — E2E Sandbox Tests
; Run with: AutoIt3_x64.exe tests\E2E_Sandbox.au3
; Tests application lifecycle scenarios in a clean environment
;
; These tests are standalone (not included by TestRunner) and are
; designed to run inside a Windows Sandbox via sandbox_setup.ps1.
; ===============================================================

; ---- Test framework globals ----
Global $__g_E2E_iPass = 0
Global $__g_E2E_iFail = 0
Global $__g_E2E_sCurrentSuite = ""
Global $__g_E2E_sResultsDir = ""
If FileExists("C:\results") Then
    $__g_E2E_sResultsDir = "C:\results"
Else
    $__g_E2E_sResultsDir = @ScriptDir & "\results"
EndIf

; ---- Include modules under test ----
#include "..\includes\Config.au3"
#include "..\includes\Theme.au3"
#include "..\includes\Labels.au3"

; ---- Create results directory ----
If Not FileExists($__g_E2E_sResultsDir) Then DirCreate($__g_E2E_sResultsDir)

; ---- Load bundled fonts ----
_Theme_LoadFonts()

; ---- Run E2E test suites ----
_E2E_FreshInstall()
_E2E_ConfigPersistence()
_E2E_StartupRegistryToggle()
_E2E_IniCorruptionRecovery()
_E2E_LabelsIntegration()

; ---- Cleanup ----
_Theme_UnloadFonts()

; ---- Summary ----
_E2E_Summary()

; ===============================================================
; E2E TEST SUITES
; ===============================================================

; -- Test 1: Fresh install creates INI with all expected sections --
Func _E2E_FreshInstall()
    _E2E_Suite("Fresh Install")

    Local $sTempIni = @TempDir & "\e2e_fresh_install.ini"

    ; Ensure no leftover file
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Init should create the INI from scratch
    _Cfg_Init($sTempIni)

    _E2E_AssertTrue("INI file was created", FileExists($sTempIni))
    _E2E_AssertEqual("Config path is set", _Cfg_GetPath(), $sTempIni)

    ; Read raw INI to verify all expected sections exist
    Local $aSections = IniReadSectionNames($sTempIni)
    Local $bHasGeneral = False, $bHasDisplay = False, $bHasScroll = False
    Local $bHasHotkeys = False, $bHasBehavior = False, $bHasColors = False

    If IsArray($aSections) Then
        For $i = 1 To $aSections[0]
            Switch $aSections[$i]
                Case "General"
                    $bHasGeneral = True
                Case "Display"
                    $bHasDisplay = True
                Case "Scroll"
                    $bHasScroll = True
                Case "Hotkeys"
                    $bHasHotkeys = True
                Case "Behavior"
                    $bHasBehavior = True
                Case "DesktopColors"
                    $bHasColors = True
            EndSwitch
        Next
    EndIf

    _E2E_AssertTrue("Section [General] exists", $bHasGeneral)
    _E2E_AssertTrue("Section [Display] exists", $bHasDisplay)
    _E2E_AssertTrue("Section [Scroll] exists", $bHasScroll)
    _E2E_AssertTrue("Section [Hotkeys] exists", $bHasHotkeys)
    _E2E_AssertTrue("Section [Behavior] exists", $bHasBehavior)
    _E2E_AssertTrue("Section [DesktopColors] exists", $bHasColors)

    ; Verify some key defaults in the raw INI
    _E2E_AssertEqual("INI default: widget_position", IniRead($sTempIni, "General", "widget_position", ""), "left")
    _E2E_AssertEqual("INI default: scroll_direction", IniRead($sTempIni, "Scroll", "scroll_direction", ""), "normal")
    _E2E_AssertEqual("INI default: confirm_delete", IniRead($sTempIni, "Behavior", "confirm_delete", ""), "true")

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 2: Config persistence across save/reload cycle --
Func _E2E_ConfigPersistence()
    _E2E_Suite("Config Persistence")

    Local $sTempIni = @TempDir & "\e2e_persistence.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Create initial config
    _Cfg_Init($sTempIni)

    ; Set several non-default values
    _Cfg_SetWidgetPosition("center")
    _Cfg_SetNumberPadding(3)
    _Cfg_SetThemeAlphaMain(180)
    _Cfg_SetScrollEnabled(True)
    _Cfg_SetScrollDirection("inverted")
    _Cfg_SetHotkeyNext("^!{RIGHT}")
    _Cfg_SetHotkeyPrev("^!{LEFT}")
    _Cfg_SetConfirmDelete(False)
    _Cfg_SetDesktopColorsEnabled(True)
    _Cfg_SetDesktopColor(1, 0xFF0000)
    _Cfg_SetAutoHideTimeout(5000)

    ; Save to disk
    _Cfg_Save()

    ; Re-init from the same path (simulates fresh app start)
    _Cfg_Init($sTempIni)

    ; Verify all values survived the round trip
    _E2E_AssertEqual("Persisted: widget_position", _Cfg_GetWidgetPosition(), "center")
    _E2E_AssertEqual("Persisted: number_padding", _Cfg_GetNumberPadding(), 3)
    _E2E_AssertEqual("Persisted: theme_alpha_main", _Cfg_GetThemeAlphaMain(), 180)
    _E2E_AssertTrue("Persisted: scroll_enabled", _Cfg_GetScrollEnabled())
    _E2E_AssertEqual("Persisted: scroll_direction", _Cfg_GetScrollDirection(), "inverted")
    _E2E_AssertEqual("Persisted: hotkey_next", _Cfg_GetHotkeyNext(), "^!{RIGHT}")
    _E2E_AssertEqual("Persisted: hotkey_prev", _Cfg_GetHotkeyPrev(), "^!{LEFT}")
    _E2E_AssertFalse("Persisted: confirm_delete", _Cfg_GetConfirmDelete())
    _E2E_AssertTrue("Persisted: desktop_colors_enabled", _Cfg_GetDesktopColorsEnabled())
    _E2E_AssertEqual("Persisted: desktop_color_1", _Cfg_GetDesktopColor(1), 0xFF0000)
    _E2E_AssertEqual("Persisted: auto_hide_timeout", _Cfg_GetAutoHideTimeout(), 5000)

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 3: Startup registry toggle --
Func _E2E_StartupRegistryToggle()
    _E2E_Suite("Startup Registry Toggle")

    Local $sRegKey = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

    ; Ensure clean state: remove any leftover entry
    RegDelete($sRegKey, "DeskSwitcheroo")

    ; Enable startup
    _Cfg_EnableStartup()
    Local $sVal = RegRead($sRegKey, "DeskSwitcheroo")
    _E2E_AssertTrue("Registry key created after EnableStartup", $sVal <> "")
    _E2E_AssertTrue("IsStartupEnabled returns True", _Cfg_IsStartupEnabled())

    ; Disable startup
    _Cfg_DisableStartup()
    $sVal = RegRead($sRegKey, "DeskSwitcheroo")
    _E2E_AssertEqual("Registry key removed after DisableStartup", $sVal, "")
    _E2E_AssertFalse("IsStartupEnabled returns False", _Cfg_IsStartupEnabled())
EndFunc

; -- Test 4: INI corruption recovery --
Func _E2E_IniCorruptionRecovery()
    _E2E_Suite("INI Corruption Recovery")

    Local $sTempIni = @TempDir & "\e2e_corruption.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Create a valid config first
    _Cfg_Init($sTempIni)
    _Cfg_Save()

    ; Now write garbage to every section
    IniWrite($sTempIni, "General", "widget_position", "GARBAGE_POSITION")
    IniWrite($sTempIni, "General", "number_padding", "not_a_number")
    IniWrite($sTempIni, "General", "wrap_navigation", "maybe")
    IniWrite($sTempIni, "Display", "theme_alpha_main", "-999")
    IniWrite($sTempIni, "Display", "count_font_size", "abc")
    IniWrite($sTempIni, "Scroll", "scroll_direction", "SIDEWAYS")
    IniWrite($sTempIni, "Scroll", "scroll_enabled", "perhaps")
    IniWrite($sTempIni, "Scroll", "list_scroll_action", "explode")
    IniWrite($sTempIni, "Behavior", "confirm_delete", "dunno")
    IniWrite($sTempIni, "Behavior", "peek_bounce_delay", "fast")
    IniWrite($sTempIni, "Behavior", "auto_hide_timeout", "-1")
    IniWrite($sTempIni, "DesktopColors", "desktop_colors_enabled", "yep")
    IniWrite($sTempIni, "DesktopColors", "desktop_1_color", "not_a_color")

    ; Reload - should recover to valid defaults
    _Cfg_Load()

    ; Verify all values are valid defaults (not garbage)
    _E2E_AssertEqual("Recovered: widget_position", _Cfg_GetWidgetPosition(), "left")
    _E2E_AssertEqual("Recovered: number_padding", _Cfg_GetNumberPadding(), 2)
    _E2E_AssertTrue("Recovered: wrap_navigation is bool", _Cfg_GetWrapNavigation() = True Or _Cfg_GetWrapNavigation() = False)
    _E2E_AssertEqual("Recovered: scroll_direction", _Cfg_GetScrollDirection(), "normal")
    _E2E_AssertEqual("Recovered: list_scroll_action", _Cfg_GetListScrollAction(), "switch")
    _E2E_AssertEqual("Recovered: count_font_size", _Cfg_GetCountFontSize(), 7)

    ; Alpha should be clamped or default (garbage non-int falls back to default 235)
    Local $iAlpha = _Cfg_GetThemeAlphaMain()
    _E2E_AssertTrue("Recovered: theme_alpha in range 50-255", $iAlpha >= 50 And $iAlpha <= 255)

    ; Boolean garbage should fall back to defaults
    ; scroll_enabled default is False, confirm_delete default is True
    _E2E_AssertFalse("Recovered: scroll_enabled default", _Cfg_GetScrollEnabled())
    _E2E_AssertTrue("Recovered: confirm_delete default", _Cfg_GetConfirmDelete())

    ; Numeric garbage should fall back to defaults
    _E2E_AssertEqual("Recovered: peek_bounce_delay", _Cfg_GetPeekBounceDelay(), 500)

    ; auto_hide_timeout with -1 is an int but below min (500), so clamped
    Local $iTimeout = _Cfg_GetAutoHideTimeout()
    _E2E_AssertTrue("Recovered: auto_hide_timeout >= 500", $iTimeout >= 500)

    ; Desktop color with invalid hex should fall back to default palette
    Local $iColor1 = _Cfg_GetDesktopColor(1)
    _E2E_AssertEqual("Recovered: desktop_1_color default", $iColor1, 0x4A9EFF)

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; -- Test 5: Labels integration --
Func _E2E_LabelsIntegration()
    _E2E_Suite("Labels Integration")

    Local $sTempIni = @TempDir & "\e2e_labels.ini"
    If FileExists($sTempIni) Then FileDelete($sTempIni)

    ; Init labels with test INI (sync disabled for isolated testing)
    _Labels_Init($sTempIni, False)

    _E2E_AssertEqual("Labels path set", _Labels_GetPath(), $sTempIni)

    ; Save several labels (this creates the INI on first write)
    _Labels_Save(1, "Work")
    _Labels_Save(2, "Gaming")
    _Labels_Save(3, "Music Production")
    _Labels_Save(4, "Research & Notes")
    _Labels_Save(5, "")

    _E2E_AssertTrue("Labels INI created after save", FileExists($sTempIni))

    ; Verify they can be read back
    _E2E_AssertEqual("Label 1 saved", _Labels_Load(1), "Work")
    _E2E_AssertEqual("Label 2 saved", _Labels_Load(2), "Gaming")
    _E2E_AssertEqual("Label 3 saved", _Labels_Load(3), "Music Production")
    _E2E_AssertEqual("Label 4 special chars", _Labels_Load(4), "Research & Notes")
    _E2E_AssertEqual("Label 5 empty string", _Labels_Load(5), "")
    _E2E_AssertEqual("Label 99 missing", _Labels_Load(99), "")

    ; Verify persistence: re-init from the same file
    _Labels_Init($sTempIni, False)
    _E2E_AssertEqual("Labels persist: desktop 1", _Labels_Load(1), "Work")
    _E2E_AssertEqual("Labels persist: desktop 2", _Labels_Load(2), "Gaming")
    _E2E_AssertEqual("Labels persist: desktop 3", _Labels_Load(3), "Music Production")

    ; Overwrite and verify
    _Labels_Save(1, "Updated Work")
    _E2E_AssertEqual("Label overwrite", _Labels_Load(1), "Updated Work")

    ; Cleanup
    FileDelete($sTempIni)
EndFunc

; ===============================================================
; E2E TEST FRAMEWORK FUNCTIONS
; ===============================================================

Func _E2E_Suite($sSuiteName)
    $__g_E2E_sCurrentSuite = $sSuiteName
    ConsoleWrite(@CRLF & "=== E2E: " & $sSuiteName & " ===" & @CRLF)
EndFunc

Func _E2E_AssertEqual($sName, $vActual, $vExpected)
    If $vActual = $vExpected Then
        $__g_E2E_iPass += 1
        ConsoleWrite("  PASS: " & $sName & @CRLF)
    Else
        $__g_E2E_iFail += 1
        ConsoleWrite("  FAIL: " & $sName & " (expected: " & $vExpected & ", got: " & $vActual & ")" & @CRLF)
    EndIf
EndFunc

Func _E2E_AssertTrue($sName, $bValue)
    _E2E_AssertEqual($sName, $bValue, True)
EndFunc

Func _E2E_AssertFalse($sName, $bValue)
    _E2E_AssertEqual($sName, $bValue, False)
EndFunc

Func _E2E_Summary()
    Local $sResults = ""
    $sResults &= @CRLF & "==============================" & @CRLF
    $sResults &= "E2E Results: " & $__g_E2E_iPass & " passed, " & $__g_E2E_iFail & " failed" & @CRLF
    $sResults &= "==============================" & @CRLF
    ConsoleWrite($sResults)

    ; Write results file for sandbox_setup.ps1 to read
    Local $sResultFile = $__g_E2E_sResultsDir & "\e2e_results.txt"
    Local $hFile = FileOpen($sResultFile, 2) ; overwrite
    If $hFile <> -1 Then
        FileWrite($hFile, "pass=" & $__g_E2E_iPass & @CRLF)
        FileWrite($hFile, "fail=" & $__g_E2E_iFail & @CRLF)
        If $__g_E2E_iFail > 0 Then
            FileWrite($hFile, "status=FAIL" & @CRLF)
        Else
            FileWrite($hFile, "status=PASS" & @CRLF)
        EndIf
        FileClose($hFile)
    EndIf

    If $__g_E2E_iFail > 0 Then Exit 1
    Exit 0
EndFunc
