#include-once

Func _RunTest_Wallpaper()
    _Test_Suite("Wallpaper")

    _WP_Init()
    ; Baseline path should be a string (may be empty on headless CI)
    _Test_AssertTrue("Baseline is string", IsString(_WP_GetCurrentPath()))

    ; Config defaults
    _Test_AssertFalse("Wallpaper disabled by default", _Cfg_GetWallpaperEnabled())
    _Test_AssertEqual("Default change delay", _Cfg_GetWallpaperChangeDelay(), 200)
    _Test_AssertEqual("Default desktop 1 wallpaper", _Cfg_GetDesktopWallpaper(1), "")
EndFunc
