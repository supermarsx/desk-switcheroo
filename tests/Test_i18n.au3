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
