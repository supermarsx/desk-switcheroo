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

    ; Portable asset block extraction and field parsing
    Local $sBlock = __UC_FindAssetBlock($sJsonMock, "Portable")
    _Test_AssertTrue("Asset block found", $sBlock <> "")

    Local $sUrl = __UC_ExtractField($sBlock, "browser_download_url")
    _Test_AssertTrue("URL contains Portable", StringInStr($sUrl, "Portable") > 0)
    _Test_AssertTrue("URL ends with .zip", StringRight($sUrl, 4) = ".zip")

    Local $sSize = __UC_ExtractField($sBlock, "size", True)
    _Test_AssertEqual("Size parsed", Int($sSize), 2097152)

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
    Local $sBlockNone = __UC_FindAssetBlock($sJsonNoPort, "Portable")
    _Test_AssertEqual("No portable block found", $sBlockNone, "")

    ; -- Multiple assets: portable not first in list --
    Local $sJsonMulti = '{"tag_name": "v26.4", "assets": [' & _
        '{"name": "DeskSwitcheroo_Setup.exe", "size": 5242880, "browser_download_url": "https://example.com/DeskSwitcheroo_Setup.exe"}, ' & _
        '{"name": "DeskSwitcheroo_Source.tar.gz", "size": 1048576, "browser_download_url": "https://example.com/DeskSwitcheroo_Source.tar.gz"}, ' & _
        '{"name": "DeskSwitcheroo_Portable_v26.4.zip", "size": 3145728, "browser_download_url": "https://example.com/DeskSwitcheroo_Portable_v26.4.zip"}' & _
        ']}'
    Local $sBlockMulti = __UC_FindAssetBlock($sJsonMulti, "Portable")
    _Test_AssertTrue("Multi-asset: block found", $sBlockMulti <> "")
    Local $sUrlMulti = __UC_ExtractField($sBlockMulti, "browser_download_url")
    _Test_AssertTrue("Multi-asset: correct URL", StringInStr($sUrlMulti, "Portable_v26.4.zip") > 0)
    Local $sSizeMulti = __UC_ExtractField($sBlockMulti, "size", True)
    _Test_AssertEqual("Multi-asset: correct size", Int($sSizeMulti), 3145728)

    ; -- Size field before name field (reversed field order) --
    Local $sJsonReversed = '{"assets": [' & _
        '{"size": 4194304, "browser_download_url": "https://example.com/DeskSwitcheroo_Portable_v26.5.zip", "name": "DeskSwitcheroo_Portable_v26.5.zip"}' & _
        ']}'
    Local $sBlockRev = __UC_FindAssetBlock($sJsonReversed, "Portable")
    _Test_AssertTrue("Reversed fields: block found", $sBlockRev <> "")
    Local $sSizeRev = __UC_ExtractField($sBlockRev, "size", True)
    _Test_AssertEqual("Reversed fields: size parsed", Int($sSizeRev), 4194304)
    Local $sUrlRev = __UC_ExtractField($sBlockRev, "browser_download_url")
    _Test_AssertTrue("Reversed fields: URL found", StringInStr($sUrlRev, "Portable") > 0)

    ; -- Missing size field (graceful fallback) --
    Local $sJsonNoSize = '{"assets": [' & _
        '{"name": "DeskSwitcheroo_Portable_v26.6.zip", "browser_download_url": "https://example.com/DeskSwitcheroo_Portable_v26.6.zip"}' & _
        ']}'
    Local $sBlockNoSize = __UC_FindAssetBlock($sJsonNoSize, "Portable")
    _Test_AssertTrue("No size: block found", $sBlockNoSize <> "")
    Local $sSizeNone = __UC_ExtractField($sBlockNoSize, "size", True)
    _Test_AssertEqual("No size: returns empty", $sSizeNone, "")
    ; URL should still work even without size
    Local $sUrlNoSize = __UC_ExtractField($sBlockNoSize, "browser_download_url")
    _Test_AssertTrue("No size: URL still works", StringInStr($sUrlNoSize, "Portable") > 0)

    ; -- ExtractField on empty block --
    _Test_AssertEqual("Empty block returns empty", __UC_ExtractField("", "size", True), "")
    _Test_AssertEqual("Empty block string field", __UC_ExtractField("", "name"), "")

    ; -- Real GitHub structure with nested objects (uploader:{...}) --
    Local $sJsonNested = '{"tag_name": "v26.6", "assets": [' & _
        '{"name": "DeskSwitcheroo_Setup.exe", "size": 5242880, "uploader": {"login": "bot", "id": 123}, "browser_download_url": "https://example.com/DeskSwitcheroo_Setup.exe"}, ' & _
        '{"name": "DeskSwitcheroo_Portable.zip", "size": 2097152, "uploader": {"login": "bot", "id": 123}, "browser_download_url": "https://example.com/DeskSwitcheroo_Portable.zip"}, ' & _
        '{"name": "DeskSwitcheroo_Source.zip", "size": 1048576, "uploader": {"login": "bot", "id": 123}, "browser_download_url": "https://example.com/DeskSwitcheroo_Source.zip"}' & _
        ']}'
    Local $sBlockNested = __UC_FindAssetBlock($sJsonNested, "Portable")
    _Test_AssertTrue("Nested objects: block found", $sBlockNested <> "")
    Local $sUrlNested = __UC_ExtractField($sBlockNested, "browser_download_url")
    _Test_AssertTrue("Nested objects: correct URL", StringInStr($sUrlNested, "Portable.zip") > 0)
    Local $sSizeNested = __UC_ExtractField($sBlockNested, "size", True)
    _Test_AssertEqual("Nested objects: correct size", Int($sSizeNested), 2097152)
    Local $sNameNested = __UC_ExtractField($sBlockNested, "name")
    _Test_AssertEqual("Nested objects: correct name", $sNameNested, "DeskSwitcheroo_Portable.zip")

    ; -- No version in filename (real naming: DeskSwitcheroo_Portable.zip) --
    Local $sJsonNoVer = '{"assets": [{"name": "DeskSwitcheroo_Portable.zip", "size": 3000000, "browser_download_url": "https://example.com/DeskSwitcheroo_Portable.zip"}]}'
    Local $sBlockNoVer = __UC_FindAssetBlock($sJsonNoVer, "Portable")
    _Test_AssertTrue("No version in name: block found", $sBlockNoVer <> "")
    Local $sUrlNoVer = __UC_ExtractField($sBlockNoVer, "browser_download_url")
    _Test_AssertTrue("No version in name: URL found", StringInStr($sUrlNoVer, "Portable.zip") > 0)
EndFunc
