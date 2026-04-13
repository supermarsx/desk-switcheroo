#include-once

; ===============================================================
; Tests for includes\Profiles.au3
; Unit tests — uses a temp directory, no GUI required
; ===============================================================

Func _RunTest_Profiles()
    _Test_Suite("Profiles")

    ; -- Setup: use temp directory as base so we don't pollute the real profiles dir --
    Local $sTempBase = @TempDir & "\desk_switcheroo_test_profiles"
    If FileExists($sTempBase) Then DirRemove($sTempBase, 1)
    DirCreate($sTempBase)

    ; Create a mock config INI with profiles enabled
    Local $sTempIni = $sTempBase & "\desk_switcheroo.ini"
    IniWrite($sTempIni, "Profiles", "profiles_enabled", "true")
    IniWrite($sTempIni, "DesktopColors", "desktop_1_color", "0x4A9EFF")
    IniWrite($sTempIni, "DesktopColors", "desktop_2_color", "0xFF5555")
    IniWrite($sTempIni, "Wallpaper", "desktop_1_wallpaper", "C:\Wallpapers\code.jpg")
    IniWrite($sTempIni, "Wallpaper", "desktop_2_wallpaper", "")

    ; -- Init with profiles enabled --
    _Prof_Init($sTempBase)
    _Test_AssertTrue("Prof_Init enables feature", _Prof_IsEnabled())

    ; -- Init with profiles disabled --
    IniWrite($sTempIni, "Profiles", "profiles_enabled", "false")
    _Prof_Init($sTempBase)
    _Test_AssertFalse("Prof_Init respects disabled", _Prof_IsEnabled())

    ; Re-enable for remaining tests
    IniWrite($sTempIni, "Profiles", "profiles_enabled", "true")
    _Prof_Init($sTempBase)

    ; ============================
    ; Name sanitization
    ; ============================

    ; -- Alphanumeric passthrough --
    _Test_AssertEqual("Sanitize: alphanumeric", __Prof_SanitizeName("Work2024"), "work2024")

    ; -- Underscore and dash allowed --
    _Test_AssertEqual("Sanitize: underscore+dash", __Prof_SanitizeName("my_profile-1"), "my_profile-1")

    ; -- Special characters stripped --
    _Test_AssertEqual("Sanitize: special chars", __Prof_SanitizeName("w@o#r$k!"), "work")

    ; -- Spaces stripped --
    _Test_AssertEqual("Sanitize: spaces", __Prof_SanitizeName("my profile"), "myprofile")

    ; -- Empty after strip defaults to "default" --
    _Test_AssertEqual("Sanitize: empty becomes default", __Prof_SanitizeName("@#$%"), "default")

    ; -- Completely empty string --
    _Test_AssertEqual("Sanitize: empty string", __Prof_SanitizeName(""), "default")

    ; -- Too long truncated to 64 --
    Local $sLong = ""
    Local $iL
    For $iL = 1 To 80
        $sLong &= "a"
    Next
    Local $sSanitized = __Prof_SanitizeName($sLong)
    _Test_AssertEqual("Sanitize: truncated to 64", StringLen($sSanitized), 64)

    ; -- Lowercased --
    _Test_AssertEqual("Sanitize: lowercased", __Prof_SanitizeName("MyProfile"), "myprofile")

    ; -- Unicode/non-ASCII stripped --
    _Test_AssertEqual("Sanitize: unicode stripped", __Prof_SanitizeName(ChrW(0x00E9) & "test"), "test")

    ; ============================
    ; Profile path generation
    ; ============================

    ; -- Path contains sanitized name --
    Local $sPath = _Prof_GetProfilePath("Work")
    _Test_AssertTrue("Path ends with .ini", StringRight($sPath, 4) = ".ini")
    _Test_AssertTrue("Path contains sanitized name", StringInStr($sPath, "\work.ini") > 0)

    ; -- Path with special chars is sanitized --
    Local $sPath2 = _Prof_GetProfilePath("My Work!")
    _Test_AssertTrue("Path sanitized special", StringInStr($sPath2, "\mywork.ini") > 0)

    ; ============================
    ; Profile existence check
    ; ============================

    ; -- Non-existent profile --
    _Test_AssertFalse("Exists: non-existent", _Prof_ProfileExists("nonexistent"))

    ; -- Create a dummy profile and check --
    Local $sDummyPath = _Prof_GetProfilePath("dummy")
    __Prof_EnsureDir()
    IniWrite($sDummyPath, "Meta", "name", "dummy")
    _Test_AssertTrue("Exists: after creation", _Prof_ProfileExists("dummy"))

    ; ============================
    ; Profile listing
    ; ============================

    ; -- List with one profile --
    Local $sList = _Prof_ListProfiles()
    _Test_AssertTrue("List: contains dummy", StringInStr($sList, "dummy") > 0)

    ; -- Add second profile and list --
    Local $sDummy2Path = _Prof_GetProfilePath("second")
    IniWrite($sDummy2Path, "Meta", "name", "second")
    $sList = _Prof_ListProfiles()
    _Test_AssertTrue("List: contains dummy after add", StringInStr($sList, "dummy") > 0)
    _Test_AssertTrue("List: contains second", StringInStr($sList, "second") > 0)
    _Test_AssertTrue("List: pipe-delimited", StringInStr($sList, "|") > 0)

    ; -- List from empty directory --
    FileDelete($sDummyPath)
    FileDelete($sDummy2Path)
    $sList = _Prof_ListProfiles()
    _Test_AssertEqual("List: empty dir returns empty", $sList, "")

    ; ============================
    ; Profile delete
    ; ============================

    ; -- Delete non-existent profile --
    _Test_AssertFalse("Delete: non-existent", _Prof_DeleteProfile("nonexistent"))

    ; -- Delete existing profile --
    Local $sDelPath = _Prof_GetProfilePath("todelete")
    IniWrite($sDelPath, "Meta", "name", "todelete")
    _Test_AssertTrue("Delete: existing profile", _Prof_DeleteProfile("todelete"))
    _Test_AssertFalse("Delete: gone after delete", _Prof_ProfileExists("todelete"))

    ; ============================
    ; Profile save format validation
    ; ============================

    ; -- Save creates INI with correct structure --
    ; (Note: _Prof_SaveProfile depends on _VD_GetCount and _Labels_Load which
    ;  may not be fully functional in test env without DLL. We test what we can.)
    Local $sSavePath = _Prof_GetProfilePath("testprofile")
    If FileExists($sSavePath) Then FileDelete($sSavePath)

    ; Write a profile manually and verify read-back
    IniWrite($sSavePath, "Meta", "name", "Test Profile")
    IniWrite($sSavePath, "Meta", "created", "2026-04-13T15:30:00")
    IniWrite($sSavePath, "Meta", "modified", "2026-04-13T15:30:00")
    IniWrite($sSavePath, "Meta", "desktop_count", "3")
    IniWrite($sSavePath, "Labels", "label_1", "Email")
    IniWrite($sSavePath, "Labels", "label_2", "Code")
    IniWrite($sSavePath, "Labels", "label_3", "Docs")
    IniWrite($sSavePath, "Colors", "color_1", "0x4A9EFF")
    IniWrite($sSavePath, "Colors", "color_2", "0x4AFF7E")
    IniWrite($sSavePath, "Colors", "color_3", "")
    IniWrite($sSavePath, "Wallpapers", "wallpaper_1", "C:\Wallpapers\email.jpg")
    IniWrite($sSavePath, "Wallpapers", "wallpaper_2", "")
    IniWrite($sSavePath, "Wallpapers", "wallpaper_3", "")

    ; Verify Meta read-back
    Local $aMeta = __Prof_ReadProfileMeta($sSavePath)
    _Test_AssertEqual("Save fmt: meta name", $aMeta[0], "Test Profile")
    _Test_AssertEqual("Save fmt: meta created", $aMeta[1], "2026-04-13T15:30:00")
    _Test_AssertEqual("Save fmt: meta count", $aMeta[3], 3)

    ; Verify Labels read-back
    _Test_AssertEqual("Save fmt: label 1", IniRead($sSavePath, "Labels", "label_1", ""), "Email")
    _Test_AssertEqual("Save fmt: label 2", IniRead($sSavePath, "Labels", "label_2", ""), "Code")
    _Test_AssertEqual("Save fmt: label 3", IniRead($sSavePath, "Labels", "label_3", ""), "Docs")

    ; Verify Colors read-back
    _Test_AssertEqual("Save fmt: color 1", IniRead($sSavePath, "Colors", "color_1", ""), "0x4A9EFF")
    _Test_AssertEqual("Save fmt: color 2", IniRead($sSavePath, "Colors", "color_2", ""), "0x4AFF7E")

    ; Verify Wallpapers read-back
    _Test_AssertEqual("Save fmt: wallpaper 1", IniRead($sSavePath, "Wallpapers", "wallpaper_1", ""), "C:\Wallpapers\email.jpg")

    ; ============================
    ; ReadProfileMeta on missing file
    ; ============================
    Local $aEmpty = __Prof_ReadProfileMeta(@TempDir & "\nonexistent_profile.ini")
    _Test_AssertEqual("Meta: missing file returns empty", UBound($aEmpty), 0)

    ; ============================
    ; Disabled feature guard
    ; ============================
    IniWrite($sTempIni, "Profiles", "profiles_enabled", "false")
    _Prof_Init($sTempBase)

    _Test_AssertFalse("Disabled: save rejected", _Prof_SaveProfile("blocked"))
    _Test_AssertFalse("Disabled: delete rejected", _Prof_DeleteProfile("blocked"))
    _Test_AssertFalse("Disabled: load rejected", _Prof_LoadProfile("blocked"))

    ; -- Cleanup --
    DirRemove($sTempBase, 1)
EndFunc
