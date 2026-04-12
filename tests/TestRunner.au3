#include <GUIConstantsEx.au3>

; ===============================================================
; Desk Switcheroo — Test Runner
; Run with: AutoIt3.exe tests\TestRunner.au3
; Exit code: 0 = all pass, 1 = failures
; ===============================================================

; ---- Test framework globals ----
Global $__g_Test_iPass = 0
Global $__g_Test_iFail = 0
Global $__g_Test_sCurrentSuite = ""

; ---- Stubs for globals/functions defined in desktop_switcher.au3 ----
; These are needed by ConfigDialog, AboutDialog, UpdateChecker includes
Global $APP_VERSION = "test"
Global Const $VK_LBUTTON = 0x01, $VK_RBUTTON = 0x02, $VK_MBUTTON = 0x04
Global Const $VK_RETURN = 0x0D, $VK_ESCAPE = 0x1B
Global Const $VK_UP = 0x26, $VK_DOWN = 0x28
Global Const $VK_1 = 0x31, $VK_9 = 0x39
Global Const $VK_KEYDOWN = 0x8000
Global Const $TRIPLE_CLICK_MS = 500, $QUICK_ACCESS_TIMEOUT = 3000, $DESKTOP_LIMIT = 20
Global $iTaskbarY = 0, $iTaskbarH = 0
Global $__g_hInetDownload = 0, $__g_sInetTempFile = ""
Func _ApplySettingsLive()
EndFunc
Func _Shutdown()
EndFunc

; ---- Include modules under test ----
#include "..\includes\Config.au3"
#include "..\includes\Theme.au3"
#include "..\includes\Labels.au3"
#include "..\includes\VirtualDesktop.au3"
#include "..\includes\Peek.au3"
#include "..\includes\ContextMenu.au3"
#include "..\includes\RenameDialog.au3"
#include "..\includes\DesktopList.au3"
#include "..\includes\Logger.au3"
#include "..\includes\i18n.au3"
#include "..\includes\ConfigDialog.au3"
#include "..\includes\AboutDialog.au3"
#include "..\includes\UpdateChecker.au3"
#include "..\includes\WindowList.au3"
#include "..\includes\Wallpaper.au3"
#include "..\includes\ExplorerMonitor.au3"

; ---- Include test files ----
#include "Test_Theme.au3"
#include "Test_Labels.au3"
#include "Test_VirtualDesktop.au3"
#include "Test_Peek.au3"
#include "Test_DesktopList.au3"
#include "Test_ContextMenu.au3"
#include "Test_RenameDialog.au3"
#include "Test_Config.au3"
#include "Test_Logger.au3"
#include "Test_i18n.au3"
#include "Test_ConfigDialog.au3"
#include "Test_UpdateChecker.au3"
#include "Test_AboutDialog.au3"
#include "Test_WindowList.au3"
#include "Test_Wallpaper.au3"
#include "Test_ExplorerMonitor.au3"

; ---- Load bundled fonts ----
_Theme_LoadFonts()

; ---- Initialize i18n ----
_i18n_Init("en-US")

; ---- Run all test suites ----
_RunTest_Config()
_RunTest_Theme()
_RunTest_Labels()
_RunTest_VirtualDesktop()
_RunTest_Peek()
_RunTest_DesktopList()
_RunTest_ContextMenu()
_RunTest_RenameDialog()
_RunTest_Logger()
_RunTest_i18n()
_RunTest_ConfigDialog()
_RunTest_UpdateChecker()
_RunTest_AboutDialog()
_RunTest_WindowList()
_RunTest_Wallpaper()
_RunTest_ExplorerMonitor()

; ---- Cleanup ----
_VD_Shutdown()
_Theme_UnloadFonts()

; ---- Summary ----
_Test_Summary()

; ===============================================================
; TEST FRAMEWORK FUNCTIONS
; ===============================================================

Func _Test_Suite($sSuiteName)
    $__g_Test_sCurrentSuite = $sSuiteName
    ConsoleWrite(@CRLF & "=== " & $sSuiteName & " ===" & @CRLF)
EndFunc

Func _Test_AssertEqual($sName, $vActual, $vExpected)
    If $vActual = $vExpected Then
        $__g_Test_iPass += 1
        ConsoleWrite("  PASS: " & $sName & @CRLF)
    Else
        $__g_Test_iFail += 1
        ConsoleWrite("  FAIL: " & $sName & " (expected: " & $vExpected & ", got: " & $vActual & ")" & @CRLF)
    EndIf
EndFunc

Func _Test_AssertNotEqual($sName, $vActual, $vUnexpected)
    If $vActual <> $vUnexpected Then
        $__g_Test_iPass += 1
        ConsoleWrite("  PASS: " & $sName & @CRLF)
    Else
        $__g_Test_iFail += 1
        ConsoleWrite("  FAIL: " & $sName & " (should not be: " & $vUnexpected & ")" & @CRLF)
    EndIf
EndFunc

Func _Test_AssertTrue($sName, $bValue)
    _Test_AssertEqual($sName, $bValue, True)
EndFunc

Func _Test_AssertFalse($sName, $bValue)
    _Test_AssertEqual($sName, $bValue, False)
EndFunc

Func _Test_Skip($sName)
    $__g_Test_iPass += 1
    ConsoleWrite("  SKIP: " & $sName & @CRLF)
EndFunc

Func _Test_AssertGreaterEqual($sName, $vActual, $vMin)
    If $vActual >= $vMin Then
        $__g_Test_iPass += 1
        ConsoleWrite("  PASS: " & $sName & @CRLF)
    Else
        $__g_Test_iFail += 1
        ConsoleWrite("  FAIL: " & $sName & " (expected >= " & $vMin & ", got: " & $vActual & ")" & @CRLF)
    EndIf
EndFunc

Func _Test_AssertLessEqual($sName, $vActual, $vMax)
    If $vActual <= $vMax Then
        $__g_Test_iPass += 1
        ConsoleWrite("  PASS: " & $sName & @CRLF)
    Else
        $__g_Test_iFail += 1
        ConsoleWrite("  FAIL: " & $sName & " (expected <= " & $vMax & ", got: " & $vActual & ")" & @CRLF)
    EndIf
EndFunc

Func _Test_Summary()
    ConsoleWrite(@CRLF & "==============================" & @CRLF)
    ConsoleWrite("Results: " & $__g_Test_iPass & " passed, " & $__g_Test_iFail & " failed" & @CRLF)
    ConsoleWrite("==============================" & @CRLF)
    If $__g_Test_iFail > 0 Then Exit 1
    Exit 0
EndFunc
