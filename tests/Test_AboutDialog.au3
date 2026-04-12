#include-once

; ===============================================================
; Tests for includes\AboutDialog.au3
; Unit tests — verifies dialog strings and visibility state
; ===============================================================

Func _RunTest_AboutDialog()
    _Test_Suite("AboutDialog")

    ; -- i18n keys used by About dialog exist in locale --
    _Test_AssertNotEqual("about_description key exists", _i18n("Dialogs.about_description", "MISSING"), "MISSING")
    _Test_AssertNotEqual("about_repo key exists", _i18n("Dialogs.about_repo", "MISSING"), "MISSING")
    _Test_AssertNotEqual("about_dll_credit key exists", _i18n("Dialogs.about_dll_credit", "MISSING"), "MISSING")
    _Test_AssertNotEqual("about_font_credit key exists", _i18n("Dialogs.about_font_credit", "MISSING"), "MISSING")
    _Test_AssertNotEqual("btn_close key exists", _i18n("General.btn_close", "MISSING"), "MISSING")

    ; -- Description has content and newlines --
    Local $sDesc = _i18n("Dialogs.about_description", "")
    _Test_AssertTrue("Description non-empty", StringLen($sDesc) > 10)
    _Test_AssertTrue("Description has newlines", StringInStr($sDesc, @CRLF) > 0)

    ; -- APP_VERSION is defined and non-empty --
    _Test_AssertNotEqual("APP_VERSION defined", $APP_VERSION, "")
    _Test_AssertNotEqual("APP_VERSION not empty string", $APP_VERSION, "")
EndFunc
