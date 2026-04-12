#include-once

Func _RunTest_Wallpaper()
    _Test_Suite("Wallpaper")

    ; -- Init doesn't crash --
    _WP_Init()
    _Test_AssertTrue("WP_Init completed", True)

    ; -- Baseline path should be a string (may be empty on headless CI) --
    _Test_AssertTrue("Baseline is string", IsString(_WP_GetCurrentPath()))

    ; -- Config defaults --
    _Test_AssertFalse("Wallpaper disabled by default", _Cfg_GetWallpaperEnabled())
    _Test_AssertEqual("Default change delay", _Cfg_GetWallpaperChangeDelay(), 200)
    _Test_AssertEqual("Default desktop 1 wallpaper", _Cfg_GetDesktopWallpaper(1), "")

    ; -- Change delay clamped to 50-2000 --
    Local $iDelayWas = _Cfg_GetWallpaperChangeDelay()
    _Cfg_SetWallpaperChangeDelay(10)
    _Test_AssertEqual("Delay clamped min 50", _Cfg_GetWallpaperChangeDelay(), 50)
    _Cfg_SetWallpaperChangeDelay(5000)
    _Test_AssertEqual("Delay clamped max 2000", _Cfg_GetWallpaperChangeDelay(), 2000)
    _Cfg_SetWallpaperChangeDelay(500)
    _Test_AssertEqual("Delay normal value 500", _Cfg_GetWallpaperChangeDelay(), 500)
    _Cfg_SetWallpaperChangeDelay($iDelayWas)

    ; -- Desktop wallpaper paths default "" for desktops 1-9 --
    Local $iW
    For $iW = 1 To 9
        _Test_AssertEqual("Default wallpaper desktop " & $iW, _Cfg_GetDesktopWallpaper($iW), "")
    Next

    ; -- Set/Get wallpaper paths for desktops 1-9 --
    For $iW = 1 To 9
        _Cfg_SetDesktopWallpaper($iW, "C:\test_" & $iW & ".jpg")
        _Test_AssertEqual("Set wallpaper desktop " & $iW, _Cfg_GetDesktopWallpaper($iW), "C:\test_" & $iW & ".jpg")
    Next
    ; Reset back to defaults
    For $iW = 1 To 9
        _Cfg_SetDesktopWallpaper($iW, "")
    Next

    ; -- Out-of-range desktop wallpaper returns "" --
    _Test_AssertEqual("Wallpaper desktop 0 = empty", _Cfg_GetDesktopWallpaper(0), "")
    _Test_AssertEqual("Wallpaper desktop 10 = empty", _Cfg_GetDesktopWallpaper(10), "")
EndFunc
