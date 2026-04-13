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
    _Test_AssertEqual("Wallpaper desktop 51 = empty", _Cfg_GetDesktopWallpaper(51), "")

    ; -- Desktops 10+ now supported (expanded from 9 to 50) --
    _Cfg_SetDesktopWallpaper(10, "C:\test_10.jpg")
    _Test_AssertEqual("Wallpaper desktop 10 works", _Cfg_GetDesktopWallpaper(10), "C:\test_10.jpg")
    _Cfg_SetDesktopWallpaper(25, "C:\test_25.png")
    _Test_AssertEqual("Wallpaper desktop 25 works", _Cfg_GetDesktopWallpaper(25), "C:\test_25.png")
    _Cfg_SetDesktopWallpaper(50, "C:\test_50.bmp")
    _Test_AssertEqual("Wallpaper desktop 50 works", _Cfg_GetDesktopWallpaper(50), "C:\test_50.bmp")
    _Cfg_SetDesktopWallpaper(10, "")
    _Cfg_SetDesktopWallpaper(25, "")
    _Cfg_SetDesktopWallpaper(50, "")

    ; -- Path traversal rejected --
    _Cfg_SetDesktopWallpaper(1, "C:\foo\..\..\..\Windows\System32\cmd.exe")
    _Test_AssertEqual("Path traversal rejected", _Cfg_GetDesktopWallpaper(1), "")

    ; -- UNC path rejected --
    _Cfg_SetDesktopWallpaper(1, "\\server\share\evil.jpg")
    _Test_AssertEqual("UNC path rejected", _Cfg_GetDesktopWallpaper(1), "")

    ; -- Invalid extension rejected --
    _Cfg_SetDesktopWallpaper(1, "C:\test.exe")
    _Test_AssertEqual("EXE extension rejected", _Cfg_GetDesktopWallpaper(1), "")

    ; -- Valid extensions accepted --
    _Cfg_SetDesktopWallpaper(1, "C:\test.jpg")
    _Test_AssertEqual("JPG accepted", _Cfg_GetDesktopWallpaper(1), "C:\test.jpg")
    _Cfg_SetDesktopWallpaper(1, "C:\test.png")
    _Test_AssertEqual("PNG accepted", _Cfg_GetDesktopWallpaper(1), "C:\test.png")
    _Cfg_SetDesktopWallpaper(1, "C:\test.bmp")
    _Test_AssertEqual("BMP accepted", _Cfg_GetDesktopWallpaper(1), "C:\test.bmp")
    _Cfg_SetDesktopWallpaper(1, "")

    ; -- Apply is no-op when disabled --
    _Cfg_SetWallpaperEnabled(False)
    _WP_Apply(1)
    _Test_AssertTrue("WP Apply no crash when disabled", True)

    ; -- Apply with empty path does nothing --
    _Cfg_SetWallpaperEnabled(True)
    _WP_Apply(1)
    _Test_AssertTrue("WP Apply no crash with empty path", True)
    _Cfg_SetWallpaperEnabled(False)

    ; -- Tick is no-op when timer is 0 --
    _WP_Tick()
    _Test_AssertTrue("WP Tick no crash when idle", True)
EndFunc
