#include-once

; ===============================================================
; Tests for includes\UpdateChecker.au3
; Unit tests for version parsing, JSON extraction (no network)
; ===============================================================

Func _RunTest_UpdateChecker()
    _Test_Suite("UpdateChecker")

    ; -- Version tag parsing with regex (same pattern used in _UC_CheckNow) --
    Local $sJsonMock = '{"tag_name": "v26.3", "published_at": "2026-04-10T12:00:00Z", ' & _
        '"assets": [{"name": "DeskSwitcheroo_Portable_v26.3.zip", "size": 2097152, ' & _
        '"browser_download_url": "https://example.com/DeskSwitcheroo_Portable_v26.3.zip"}]}'

    ; Tag name extraction
    Local $aVer = StringRegExp($sJsonMock, '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    _Test_AssertFalse("Version regex matched", @error)
    If Not @error And UBound($aVer) >= 1 Then
        _Test_AssertEqual("Version parsed", $aVer[0], "26.3")
    Else
        _Test_AssertTrue("Version regex returned result", False)
    EndIf

    ; Published date extraction
    Local $aDate = StringRegExp($sJsonMock, '"published_at"\s*:\s*"([^T"]+)', 1)
    _Test_AssertFalse("Date regex matched", @error)
    If Not @error And UBound($aDate) >= 1 Then
        _Test_AssertEqual("Date parsed", $aDate[0], "2026-04-10")
    Else
        _Test_AssertTrue("Date regex returned result", False)
    EndIf

    ; Portable download URL extraction
    Local $aUrl = StringRegExp($sJsonMock, '"browser_download_url"\s*:\s*"([^"]*Portable[^"]*\.zip)"', 1)
    _Test_AssertFalse("URL regex matched", @error)
    If Not @error And UBound($aUrl) >= 1 Then
        _Test_AssertTrue("URL contains Portable", StringInStr($aUrl[0], "Portable") > 0)
        _Test_AssertTrue("URL ends with .zip", StringRight($aUrl[0], 4) = ".zip")
    Else
        _Test_AssertTrue("URL regex returned result", False)
    EndIf

    ; Size extraction
    Local $aSize = StringRegExp($sJsonMock, '"name"\s*:\s*"[^"]*Portable[^"]*"[^}]*"size"\s*:\s*(\d+)', 1)
    _Test_AssertFalse("Size regex matched", @error)
    If Not @error And UBound($aSize) >= 1 Then
        _Test_AssertEqual("Size parsed", Int($aSize[0]), 2097152)
    Else
        _Test_AssertTrue("Size regex returned result", False)
    EndIf

    ; -- Size formatting logic (same as in _UC_DownloadPortable) --
    Local $iBytes = 2097152
    Local $sSizeStr = ""
    If $iBytes > 1048576 Then
        $sSizeStr = StringFormat("%.1f MB", $iBytes / 1048576)
    ElseIf $iBytes > 1024 Then
        $sSizeStr = StringFormat("%.0f KB", $iBytes / 1024)
    Else
        $sSizeStr = $iBytes & " bytes"
    EndIf
    _Test_AssertEqual("2MB formatted", $sSizeStr, "2.0 MB")

    ; KB formatting
    $iBytes = 512000
    If $iBytes > 1048576 Then
        $sSizeStr = StringFormat("%.1f MB", $iBytes / 1048576)
    ElseIf $iBytes > 1024 Then
        $sSizeStr = StringFormat("%.0f KB", $iBytes / 1024)
    Else
        $sSizeStr = $iBytes & " bytes"
    EndIf
    _Test_AssertEqual("500KB formatted", $sSizeStr, "500 KB")

    ; Bytes formatting
    $iBytes = 800
    If $iBytes > 1048576 Then
        $sSizeStr = StringFormat("%.1f MB", $iBytes / 1048576)
    ElseIf $iBytes > 1024 Then
        $sSizeStr = StringFormat("%.0f KB", $iBytes / 1024)
    Else
        $sSizeStr = $iBytes & " bytes"
    EndIf
    _Test_AssertEqual("800 bytes formatted", $sSizeStr, "800 bytes")

    ; -- Version comparison logic --
    _Test_AssertTrue("Different versions detected", "26.3" <> "26.2")
    _Test_AssertFalse("Same versions equal", "26.3" <> "26.3")
    _Test_AssertTrue("Dev vs release", "dev" <> "26.3")

    ; -- Tag without v prefix --
    Local $sJson2 = '{"tag_name": "26.1"}'
    Local $aVer2 = StringRegExp($sJson2, '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    _Test_AssertFalse("Tag without v matched", @error)
    If Not @error And UBound($aVer2) >= 1 Then
        _Test_AssertEqual("Tag without v parsed", $aVer2[0], "26.1")
    EndIf

    ; -- Empty/malformed JSON --
    Local $aVerBad = StringRegExp('{}', '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    _Test_AssertTrue("Empty JSON no match", @error <> 0)

    Local $aVerBad2 = StringRegExp('not json', '"tag_name"\s*:\s*"v?([^"]+)"', 1)
    _Test_AssertTrue("Invalid JSON no match", @error <> 0)

    ; -- No portable asset --
    Local $sJsonNoPort = '{"assets": [{"name": "Setup.exe", "browser_download_url": "https://example.com/Setup.exe"}]}'
    Local $aUrlNone = StringRegExp($sJsonNoPort, '"browser_download_url"\s*:\s*"([^"]*Portable[^"]*\.zip)"', 1)
    _Test_AssertTrue("No portable URL found", @error <> 0)
EndFunc
