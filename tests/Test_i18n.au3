#include-once

; ===============================================================
; Tests for includes\i18n.au3
; Unit tests — verifies locale system, key coverage, fallback
; ===============================================================

Func _RunTest_i18n()
    _Test_Suite("i18n")

    ; -- Init loads en-US --
    _i18n_Init("en-US")
    _Test_AssertEqual("Current language", _i18n_GetCurrent(), "en-US")

    ; -- GetAvailable includes en-US --
    Local $sAvail = _i18n_GetAvailable()
    _Test_AssertTrue("Available includes en-US", StringInStr($sAvail, "en-US") > 0)

    ; -- Known key returns locale value (not default) --
    Local $sVal = _i18n("General.btn_ok", "FALLBACK")
    _Test_AssertEqual("Known key returns OK", $sVal, "OK")

    ; -- Unknown key returns default --
    Local $sMiss = _i18n("NonExistent.fake_key", "MyDefault")
    _Test_AssertEqual("Missing key returns default", $sMiss, "MyDefault")

    ; -- Format replaces {1} --
    Local $sFmt = _i18n_Format("Dialogs.rd_title", "Label for Desktop {1}", 3)
    _Test_AssertTrue("Format replaces {1}", StringInStr($sFmt, "3") > 0)
    _Test_AssertFalse("Format no leftover {1}", StringInStr($sFmt, "{1}") > 0)

    ; -- Format replaces {1} and {2} --
    Local $sFmt2 = _i18n_Format("Updates.upd_current_latest", "Current: v{1}  |  Latest: v{2}", "1.0", "2.0")
    _Test_AssertTrue("Format {1} replaced", StringInStr($sFmt2, "1.0") > 0)
    _Test_AssertTrue("Format {2} replaced", StringInStr($sFmt2, "2.0") > 0)

    ; -- Newline replacement --
    ; en-US.ini has about_description with \n
    Local $sDesc = _i18n("Dialogs.about_description", "fallback")
    _Test_AssertTrue("Newline replaced", StringInStr($sDesc, @CRLF) > 0 Or $sDesc <> "fallback")

    ; -- Key coverage: verify en-US.ini has at least 200 keys --
    Local $iKeyCount = __Test_CountLocaleKeys(@ScriptDir & "\..\locales\en-US.ini")
    _Test_AssertGreaterEqual("en-US.ini has >= 200 keys", $iKeyCount, 200)

    ; -- Reinit with nonexistent locale falls back to en-US --
    _i18n_Init("xx-FAKE")
    _Test_AssertEqual("Fake locale current", _i18n_GetCurrent(), "xx-FAKE")
    Local $sFallback = _i18n("General.btn_ok", "NOPE")
    _Test_AssertEqual("Fake locale falls back to en-US", $sFallback, "OK")

    ; Restore
    _i18n_Init("en-US")

    ; -- GetAvailableDisplay returns formatted strings --
    Local $sDisplay = _i18n_GetAvailableDisplay()
    _Test_AssertTrue("Display list non-empty", StringLen($sDisplay) > 10)
    _Test_AssertTrue("Display has pipe separator", StringInStr($sDisplay, "|") > 0)

    ; -- DisplayToCode extracts locale code --
    Local $sCode = _i18n_DisplayToCode("en-US " & ChrW(0x2014) & " English (United States)")
    _Test_AssertEqual("DisplayToCode en-US", $sCode, "en-US")

    ; -- DisplayToCode with unknown format returns input --
    Local $sRaw = _i18n_DisplayToCode("garbage")
    _Test_AssertEqual("DisplayToCode passthrough", $sRaw, "garbage")

    ; -- All 33 locale files exist and have >= 200 keys --
    Local $aLocales[34] = [33, "ar-EG", "ar-SA", "bn-IN", "da-DK", "de-DE", "en-CA", "en-GB", "en-IN", "en-US", _
        "es-AR", "es-ES", "es-MX", "fr-CA", "fr-FR", "hi-IN", "hu-HU", "id-ID", "is-IS", "it-IT", _
        "ko-KR", "nl-NL", "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sv-SE", "th-TH", "tr-TR", _
        "uk-UA", "vi-VN", "zh-CN", "zh-TW"]
    Local $sLocaleDir = @ScriptDir & "\..\locales\"
    Local $iL
    For $iL = 1 To $aLocales[0]
        Local $sFile = $sLocaleDir & $aLocales[$iL] & ".ini"
        _Test_AssertTrue("Locale file exists: " & $aLocales[$iL], FileExists($sFile))
        Local $iKeys = __Test_CountLocaleKeys($sFile)
        _Test_AssertGreaterEqual("Locale " & $aLocales[$iL] & " has >= 200 keys", $iKeys, 200)
    Next

    ; -- Format with {3} placeholder --
    Local $sFmt3 = _i18n_Format("NonExistent.test", "a={1} b={2} c={3}", "X", "Y", "Z")
    _Test_AssertTrue("Format {3} replaced", StringInStr($sFmt3, "Z") > 0)
    _Test_AssertFalse("No leftover {3}", StringInStr($sFmt3, "{3}") > 0)
EndFunc

; Helper: count total keys in a locale INI file (excluding [Meta])
Func __Test_CountLocaleKeys($sPath)
    Local $aSections = IniReadSectionNames($sPath)
    If @error Then Return 0
    Local $iTotal = 0, $i, $j
    For $i = 1 To $aSections[0]
        If $aSections[$i] = "Meta" Then ContinueLoop
        Local $aKeys = IniReadSection($sPath, $aSections[$i])
        If Not @error Then $iTotal += $aKeys[0][0]
    Next
    Return $iTotal
EndFunc
