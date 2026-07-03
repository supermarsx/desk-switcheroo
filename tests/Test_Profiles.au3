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

    ; _Prof_Init reads the enabled flag from the typed config accessor
    ; (_Cfg_GetProfilesEnabled), so drive it via the setter rather than an INI write.
    Local $bOrigProfEnabled = _Cfg_GetProfilesEnabled()

    ; -- Init with profiles enabled --
    _Cfg_SetProfilesEnabled(True)
    _Prof_Init($sTempBase)
    _Test_AssertTrue("Prof_Init enables feature", _Prof_IsEnabled())

    ; -- Init with profiles disabled --
    _Cfg_SetProfilesEnabled(False)
    _Prof_Init($sTempBase)
    _Test_AssertFalse("Prof_Init respects disabled", _Prof_IsEnabled())

    ; Re-enable for remaining tests
    _Cfg_SetProfilesEnabled(True)
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
    ; R21 — desktop-count wait helper (replaces fixed Sleep during apply)
    ; ============================
    ; Immediate match returns True promptly (no fixed sleep).
    Local $iNowCount = _VD_GetCount()
    Local $hWaitTimer = TimerInit()
    Local $bWaitHit = __Prof_WaitForCount($iNowCount, 200)
    Local $iWaitElapsed = TimerDiff($hWaitTimer)
    _Test_AssertTrue("WaitForCount: matches current count", $bWaitHit)
    _Test_AssertLessEqual("WaitForCount: returns promptly on match", $iWaitElapsed, 100)

    ; Unreachable count times out and returns False, bounded by the timeout.
    $hWaitTimer = TimerInit()
    Local $bWaitMiss = __Prof_WaitForCount($iNowCount + 9999, 50)
    _Test_AssertFalse("WaitForCount: times out on unreachable count", $bWaitMiss)
    _Test_AssertGreaterEqual("WaitForCount: waited at least the timeout", TimerDiff($hWaitTimer), 40)

    ; ============================
    ; P1 — on_profile_load hook fires on load
    ; ============================
    Local $sHookOrigPath = _Cfg_GetPath()
    Local $sHookIni = $sTempBase & "\desk_switcheroo.ini"
    Local $sSentinel = $sTempBase & "\profile_load_hook.flag"
    If FileExists($sSentinel) Then FileDelete($sSentinel)
    ; Snapshot whether _Prof_LoadProfile's @ScriptDir config write target pre-exists,
    ; so a file it creates as a side effect can be cleaned up (C1: hardcoded path).
    Local $sStrayIni = @ScriptDir & "\desk_switcheroo.ini"
    Local $bStrayExisted = FileExists($sStrayIni)

    ; Point config + hooks at a temp INI with an on_profile_load hook that writes a flag.
    _Cfg_Init($sHookIni)
    IniWrite($sHookIni, "Hooks", "hooks_enabled", "true")
    IniWrite($sHookIni, "Hooks", "on_profile_load", 'cmd /c echo {profile} > "' & $sSentinel & '"')
    _Hooks_Init()
    _Cfg_SetProfilesEnabled(True)
    _Prof_Init($sTempBase)

    ; A profile whose desktop_count equals the current count so load performs no
    ; create/remove (keeps this independent of the DLL desktop plumbing).
    Local $iHookCount = _VD_GetCount()
    Local $sHookProfile = _Prof_GetProfilePath("hooktest")
    __Prof_EnsureDir()
    If FileExists($sHookProfile) Then FileDelete($sHookProfile)
    IniWrite($sHookProfile, "Meta", "name", "hooktest")
    IniWrite($sHookProfile, "Meta", "desktop_count", $iHookCount)

    _Test_AssertTrue("LoadProfile succeeds for hook test", _Prof_LoadProfile("hooktest"))

    ; Hook runs async (Run) — poll briefly for the sentinel file to appear.
    Local $hHookTimer = TimerInit()
    While Not FileExists($sSentinel) And TimerDiff($hHookTimer) < 3000
        Sleep(25)
    WEnd
    _Test_AssertTrue("on_profile_load hook fired on load", FileExists($sSentinel))

    ; Cleanup hook state + artifacts, restore config path.
    _Hooks_Shutdown()
    If FileExists($sSentinel) Then FileDelete($sSentinel)
    If Not $bStrayExisted And FileExists($sStrayIni) Then FileDelete($sStrayIni)
    If $sHookOrigPath <> "" Then _Cfg_Init($sHookOrigPath)

    ; ============================
    ; Disabled feature guard
    ; ============================
    _Cfg_SetProfilesEnabled(False)
    _Prof_Init($sTempBase)

    _Test_AssertFalse("Disabled: save rejected", _Prof_SaveProfile("blocked"))
    _Test_AssertFalse("Disabled: delete rejected", _Prof_DeleteProfile("blocked"))
    _Test_AssertFalse("Disabled: load rejected", _Prof_LoadProfile("blocked"))

    ; -- Cleanup: restore original config state so we don't leak into other suites --
    _Cfg_SetProfilesEnabled($bOrigProfEnabled)
    DirRemove($sTempBase, 1)
EndFunc
