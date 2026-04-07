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

; ---- Include modules under test ----
#include "..\includes\Config.au3"
#include "..\includes\Theme.au3"
#include "..\includes\Labels.au3"
#include "..\includes\VirtualDesktop.au3"
#include "..\includes\Peek.au3"
#include "..\includes\ContextMenu.au3"
#include "..\includes\RenameDialog.au3"
#include "..\includes\DesktopList.au3"

; ---- Include test files ----
#include "Test_Theme.au3"
#include "Test_Labels.au3"
#include "Test_VirtualDesktop.au3"
#include "Test_Peek.au3"
#include "Test_DesktopList.au3"
#include "Test_ContextMenu.au3"
#include "Test_RenameDialog.au3"
#include "Test_Config.au3"

; ---- Load bundled fonts ----
_Theme_LoadFonts()

; ---- Run all test suites ----
_RunTest_Config()
_RunTest_Theme()
_RunTest_Labels()
_RunTest_VirtualDesktop()
_RunTest_Peek()
_RunTest_DesktopList()
_RunTest_ContextMenu()
_RunTest_RenameDialog()

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
