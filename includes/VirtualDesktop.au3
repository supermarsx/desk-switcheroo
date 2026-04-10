#include-once
#include "Config.au3"
#include "Logger.au3"
#include <WinAPISysWin.au3>

; #INDEX# =======================================================
; Title .........: VirtualDesktop
; Description ....: Wrapper for VirtualDesktopAccessor.dll by Jari Pennanen (Ciantic)
; Author .........: Mariana
; Dependency .....: VirtualDesktopAccessor.dll (https://github.com/Ciantic/VirtualDesktopAccessor)
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_VD_hDLL = -1
Global $__g_VD_bNameSupport = False
Global $__g_VD_iCachedCount = 0
Global $__g_VD_aEnumBuf[4096] ; pre-allocated buffer for EnumWindows callback
Global Const $__g_VD_ENUM_MAX = 16384 ; hard cap on enumerated windows
Global $__g_VD_hEnumCB = 0   ; persistent DllCallback handle (registered once, reused)
Global $__g_VD_pEnumCB = 0   ; callback function pointer

; #INTERNAL HELPERS# ============================================

; Name:        __VD_Call
; Description: Centralized DLL call wrapper with error handling and debug logging.
;              All VirtualDesktopAccessor DLL calls should go through this.
; Parameters:  $sFunc - DLL function name
;              $sRetType - return type (e.g. "int", "handle")
;              $aArgs - array of [type, value] pairs for DLL parameters (empty array for no args)
; Return:      DllCall result array on success, or empty array on failure
Func __VD_Call($sFunc, $sRetType, $aArgs = Default)
    If $__g_VD_hDLL = -1 Then
        _Log_Error("VD_Call: DLL not loaded, cannot call " & $sFunc)
        Local $aEmpty[1] = [0]
        Return SetError(1, 0, $aEmpty)
    EndIf

    Local $aResult
    Switch UBound($aArgs)
        Case 0
            $aResult = DllCall($__g_VD_hDLL, $sRetType, $sFunc)
        Case 2
            $aResult = DllCall($__g_VD_hDLL, $sRetType, $sFunc, $aArgs[0], $aArgs[1])
        Case 4
            $aResult = DllCall($__g_VD_hDLL, $sRetType, $sFunc, $aArgs[0], $aArgs[1], $aArgs[2], $aArgs[3])
        Case 6
            $aResult = DllCall($__g_VD_hDLL, $sRetType, $sFunc, $aArgs[0], $aArgs[1], $aArgs[2], $aArgs[3], $aArgs[4], $aArgs[5])
        Case Else
            _Log_Error("VD_Call: unsupported arg count " & UBound($aArgs) & " for " & $sFunc)
            Local $aEmpty2[1] = [0]
            Return SetError(2, 0, $aEmpty2)
    EndSwitch

    If @error Then
        _Log_Error("VD_Call: DllCall failed for " & $sFunc & " (error=" & @error & ")")
        Local $aEmpty3[1] = [0]
        Return SetError(3, 0, $aEmpty3)
    EndIf

    If Not IsArray($aResult) Then
        _Log_Error("VD_Call: DllCall returned non-array for " & $sFunc)
        Local $aEmpty4[1] = [0]
        Return SetError(4, 0, $aEmpty4)
    EndIf

    _Log_Debug("VD_Call: " & $sFunc & " returned " & $aResult[0])
    Return $aResult
EndFunc

; #FUNCTIONS# ===================================================

; Name:        _VD_IsReady
; Description: Returns whether the DLL is loaded and ready for calls
; Return:      True/False
Func _VD_IsReady()
    Return ($__g_VD_hDLL <> -1)
EndFunc

; Name:        _VD_Init
; Description: Opens the VirtualDesktopAccessor DLL and validates core exports
; Parameters:  $sDllPath - full path to DLL (default: @ScriptDir & "\VirtualDesktopAccessor.dll")
; Return:      True on success, False on failure
Func _VD_Init($sDllPath = Default)
    If $sDllPath = Default Then $sDllPath = @ScriptDir & "\VirtualDesktopAccessor.dll"
    If $__g_VD_hDLL <> -1 Then DllClose($__g_VD_hDLL)
    $__g_VD_hDLL = DllOpen($sDllPath)
    If $__g_VD_hDLL = -1 Then Return False

    ; Validate core DLL exports by test-calling GetDesktopCount
    Local $aTest = DllCall($__g_VD_hDLL, "int", "GetDesktopCount")
    If @error Or Not IsArray($aTest) Or $aTest[0] < 1 Then
        _Log_Error("VD_Init: DLL loaded but GetDesktopCount failed — incompatible DLL version?")
        DllClose($__g_VD_hDLL)
        $__g_VD_hDLL = -1
        Return False
    EndIf

    ; Validate GoToDesktopNumber export exists
    DllCall($__g_VD_hDLL, "int", "GetCurrentDesktopNumber")
    If @error Then
        _Log_Error("VD_Init: GetCurrentDesktopNumber export missing — incompatible DLL version?")
        DllClose($__g_VD_hDLL)
        $__g_VD_hDLL = -1
        Return False
    EndIf

    ; Detect desktop name support (Windows 11+)
    Local $tBuf = DllStructCreate("char[1024]")
    DllCall($__g_VD_hDLL, "int", "GetDesktopName", "int", 0, "ptr", DllStructGetPtr($tBuf), "uint_ptr", 1024)
    $__g_VD_bNameSupport = (@error = 0)
    Return True
EndFunc

; Name:        _VD_GetCount
; Description: Returns the number of virtual desktops
; Return:      Integer >= 1
Func _VD_GetCount()
    ; Return cached value — refreshed by _VD_InvalidateCountCache (event-driven)
    ; Only queries DLL if cache is empty (startup or explicit invalidation)
    If $__g_VD_iCachedCount > 0 Then Return $__g_VD_iCachedCount
    Local $aResult = __VD_Call("GetDesktopCount", "int")
    If @error Or $aResult[0] < 1 Then Return 1
    $__g_VD_iCachedCount = $aResult[0]
    Return $aResult[0]
EndFunc

; Name:        _VD_InvalidateCountCache
; Description: Refreshes the cached desktop count immediately from the DLL.
;              Called from desktop change notifications — no polling needed.
Func _VD_InvalidateCountCache()
    Local $aResult = __VD_Call("GetDesktopCount", "int")
    If Not @error And $aResult[0] >= 1 Then
        $__g_VD_iCachedCount = $aResult[0]
    Else
        $__g_VD_iCachedCount = 0 ; force re-query on next GetCount call
    EndIf
EndFunc

; Name:        _VD_GetCurrent
; Description: Returns the current virtual desktop index (1-based)
; Return:      Integer >= 1
Func _VD_GetCurrent()
    Local $aResult = __VD_Call("GetCurrentDesktopNumber", "int")
    If @error Or $aResult[0] < 0 Then Return 1
    Return $aResult[0] + 1
EndFunc

; Name:        _VD_GoTo
; Description: Switches to a virtual desktop by index (1-based)
; Parameters:  $iDesktop - target desktop index (1-based)
Func _VD_GoTo($iDesktop)
    Local $aArgs[2] = ["int", $iDesktop - 1]
    __VD_Call("GoToDesktopNumber", "int", $aArgs)
EndFunc

; Name:        _VD_HasNameSupport
; Description: Returns whether the DLL supports desktop name get/set (Windows 11+)
; Return:      True/False
Func _VD_HasNameSupport()
    Return $__g_VD_bNameSupport
EndFunc

; Name:        _VD_GetName
; Description: Gets the OS-level name of a virtual desktop (Windows 11+)
; Parameters:  $iDesktop - desktop index (1-based)
; Return:      Name string, or "" if unavailable
Func _VD_GetName($iDesktop)
    If Not $__g_VD_bNameSupport Or $__g_VD_hDLL = -1 Then Return ""
    ; Use char buffer — DllStructGetData returns a string up to the first null
    Local $tBuf = DllStructCreate("char[1024]")
    DllCall($__g_VD_hDLL, "int", "GetDesktopName", "int", $iDesktop - 1, _
        "ptr", DllStructGetPtr($tBuf), "uint_ptr", 1024)
    If @error Then Return ""
    Local $sRaw = DllStructGetData($tBuf, 1)
    If $sRaw = "" Then Return ""
    ; DLL returns UTF-8 bytes — decode via binary round-trip
    Return BinaryToString(StringToBinary($sRaw, 1), 4)
EndFunc

; Name:        _VD_SetName
; Description: Sets the OS-level name of a virtual desktop (Windows 11+)
; Parameters:  $iDesktop - desktop index (1-based)
;              $sName - new name string
; Return:      True on success, False on failure
Func _VD_SetName($iDesktop, $sName)
    If Not $__g_VD_bNameSupport Or $__g_VD_hDLL = -1 Then Return False
    ; Convert to UTF-8 null-terminated byte buffer
    Local $bUtf8 = StringToBinary($sName, 4)
    Local $iLen = BinaryLen($bUtf8)
    Local $tBuf = DllStructCreate("byte[" & ($iLen + 1) & "]")
    If @error Then Return False
    DllStructSetData($tBuf, 1, $bUtf8)
    If @error Then Return False
    DllStructSetData($tBuf, 1, 0, $iLen + 1)
    Local $aResult = DllCall($__g_VD_hDLL, "int", "SetDesktopName", "int", $iDesktop - 1, _
        "ptr", DllStructGetPtr($tBuf))
    If @error Then Return False
    Return True
EndFunc

; Name:        _VD_GetWindowDesktopNumber
; Description: Returns which virtual desktop a window is on (1-based)
; Parameters:  $hWnd - window handle
; Return:      Desktop index (1-based), or 0 if error/pinned
Func _VD_GetWindowDesktopNumber($hWnd)
    Local $aArgs[2] = ["hwnd", $hWnd]
    Local $aResult = __VD_Call("GetWindowDesktopNumber", "int", $aArgs)
    If @error Or $aResult[0] < 0 Then Return 0
    Return $aResult[0] + 1
EndFunc

; Name:        _VD_MoveWindowToDesktop
; Description: Moves a window to a virtual desktop
; Parameters:  $hWnd - window handle
;              $iDesktop - target desktop index (1-based)
; Return:      True on success, False on failure
Func _VD_MoveWindowToDesktop($hWnd, $iDesktop)
    If $__g_VD_hDLL = -1 Then Return False
    ; Verify window still exists (handle may be stale from enumeration)
    Local $aIsWnd = DllCall("user32.dll", "bool", "IsWindow", "hwnd", $hWnd)
    If Not @error And IsArray($aIsWnd) And $aIsWnd[0] = 0 Then Return False
    Local $aResult = DllCall($__g_VD_hDLL, "int", "MoveWindowToDesktopNumber", "hwnd", $hWnd, "int", $iDesktop - 1)
    If @error Then
        _Log_Debug("MoveWindow DllCall FAILED: hwnd=" & $hWnd & " to desktop=" & $iDesktop & " err=" & @error)
        Return False
    EndIf
    If Not IsArray($aResult) Then
        _Log_Debug("MoveWindow non-array result: hwnd=" & $hWnd)
        Return False
    EndIf
    _Log_Debug("MoveWindow: hwnd=" & $hWnd & " to desktop=" & $iDesktop & " ret=" & $aResult[0])
    Return True
EndFunc

; Name:        __VD_EnumWindowsCB
; Description: Callback for Win32 EnumWindows — collects all HWNDs into $__g_VD_aEnumBuf
Func __VD_EnumWindowsCB($hWnd, $lParam)
    #forceref $lParam
    If $__g_VD_aEnumBuf[0] >= $__g_VD_ENUM_MAX Then Return 0 ; stop enumeration at hard cap
    If $__g_VD_aEnumBuf[0] >= UBound($__g_VD_aEnumBuf) - 1 Then
        ReDim $__g_VD_aEnumBuf[UBound($__g_VD_aEnumBuf) * 2]
    EndIf
    $__g_VD_aEnumBuf[0] += 1
    $__g_VD_aEnumBuf[$__g_VD_aEnumBuf[0]] = $hWnd
    Return 1
EndFunc

; Name:        __VD_EnumAllWindows
; Description: Calls Win32 EnumWindows directly to get ALL top-level windows
;              system-wide, bypassing AutoIt's WinList which is virtual-desktop-scoped.
; Return:      Array where [0] = count, [1..N] = HWNDs
Func __VD_EnumAllWindows()
    If UBound($__g_VD_aEnumBuf) < 4096 Then ReDim $__g_VD_aEnumBuf[4096]
    $__g_VD_aEnumBuf[0] = 0
    ; Register callback once and reuse (avoid alloc/free per call)
    If $__g_VD_hEnumCB = 0 Then
        $__g_VD_hEnumCB = DllCallbackRegister("__VD_EnumWindowsCB", "bool", "hwnd;lparam")
        If $__g_VD_hEnumCB = 0 Then
            _Log_Error("EnumAllWindows: DllCallbackRegister failed")
            Local $aEmpty[1] = [0]
            Return $aEmpty
        EndIf
        $__g_VD_pEnumCB = DllCallbackGetPtr($__g_VD_hEnumCB)
    EndIf
    DllCall("user32.dll", "bool", "EnumWindows", "ptr", $__g_VD_pEnumCB, "lparam", 0)
    ReDim $__g_VD_aEnumBuf[$__g_VD_aEnumBuf[0] + 1]
    Return $__g_VD_aEnumBuf
EndFunc

; Name:        _VD_EnumWindowsOnDesktop
; Description: Returns an array of window handles on a given desktop
; Parameters:  $iDesktop - desktop index (1-based)
; Return:      Array where [0] = count, [1..N] = HWNDs
Func _VD_EnumWindowsOnDesktop($iDesktop)
    Local $aAll = __VD_EnumAllWindows()
    Local $aResult[$aAll[0] + 1]
    $aResult[0] = 0
    Local $iTotal = 0, $iFiltered = 0, $iNoDesk = 0
    Local $i
    For $i = 1 To $aAll[0]
        Local $hWnd = $aAll[$i]
        If $hWnd = 0 Then ContinueLoop
        $iTotal += 1
        ; Pre-filter: skip child windows (have an owner/parent)
        If _WinAPI_GetParent($hWnd) <> 0 Then
            $iFiltered += 1
            ContinueLoop
        EndIf
        ; Direct DllCall instead of wrapper to avoid function-call overhead in tight loop
        Local $aDesk = DllCall($__g_VD_hDLL, "int", "GetWindowDesktopNumber", "hwnd", $hWnd)
        If @error Or $aDesk[0] < 0 Then
            $iNoDesk += 1
            ContinueLoop
        EndIf
        If $aDesk[0] + 1 = $iDesktop Then
            $aResult[0] += 1
            $aResult[$aResult[0]] = $hWnd
        EndIf
    Next
    ReDim $aResult[$aResult[0] + 1]
    Return $aResult
EndFunc

; Name:        _VD_SwapDesktops
; Description: Swaps all windows between two desktops (does NOT swap labels)
; Parameters:  $iA, $iB - desktop indices (1-based)
; Return:      True on success
Func _VD_SwapDesktops($iA, $iB)
    _Log_Debug("SwapDesktops: swapping desktop " & $iA & " <-> " & $iB)

    ; Use Win32 EnumWindows directly — AutoIt's WinList("") is virtual-desktop-
    ; scoped on Win10/11 and only returns windows on the current desktop.
    ; EnumWindows returns ALL top-level windows system-wide.
    Local $aAll = __VD_EnumAllWindows()
    Local $aWinA[$aAll[0] + 1], $aWinB[$aAll[0] + 1]
    $aWinA[0] = 0
    $aWinB[0] = 0
    Local $iTotal = 0, $iFiltered = 0, $iNoDesk = 0
    Local $i
    For $i = 1 To $aAll[0]
        Local $hWnd = $aAll[$i]
        If $hWnd = 0 Then ContinueLoop
        $iTotal += 1
        If _WinAPI_GetParent($hWnd) <> 0 Then
            $iFiltered += 1
            ContinueLoop
        EndIf
        Local $aDesk = DllCall($__g_VD_hDLL, "int", "GetWindowDesktopNumber", "hwnd", $hWnd)
        If @error Or $aDesk[0] < 0 Then
            $iNoDesk += 1
            ContinueLoop
        EndIf
        Local $iDesk = $aDesk[0] + 1
        If $iDesk = $iA Then
            $aWinA[0] += 1
            $aWinA[$aWinA[0]] = $hWnd
            _Log_Debug("SwapDesktops: A hwnd=" & $hWnd & " title=" & WinGetTitle($hWnd))
        ElseIf $iDesk = $iB Then
            $aWinB[0] += 1
            $aWinB[$aWinB[0]] = $hWnd
            _Log_Debug("SwapDesktops: B hwnd=" & $hWnd & " title=" & WinGetTitle($hWnd))
        EndIf
    Next
    ReDim $aWinA[$aWinA[0] + 1]
    ReDim $aWinB[$aWinB[0] + 1]

    _Log_Debug("SwapDesktops: EnumWindows total=" & $iTotal & " filtered=" & $iFiltered & " noDesk=" & $iNoDesk & _
        " deskA=" & $aWinA[0] & " deskB=" & $aWinB[0])

    ; Move A's windows to B (small delay between each to avoid COM threading issues)
    Local $iMoved = 0, $iFailed = 0
    For $i = 1 To $aWinA[0]
        If _VD_MoveWindowToDesktop($aWinA[$i], $iB) Then
            $iMoved += 1
        Else
            $iFailed += 1
        EndIf
        If $i < $aWinA[0] Then Sleep(20)
    Next
    ; Delay between the two batches
    If $aWinA[0] > 0 And $aWinB[0] > 0 Then Sleep(50)
    ; Move B's windows to A
    For $i = 1 To $aWinB[0]
        If _VD_MoveWindowToDesktop($aWinB[$i], $iA) Then
            $iMoved += 1
        Else
            $iFailed += 1
        EndIf
        If $i < $aWinB[0] Then Sleep(20)
    Next

    _Log_Debug("SwapDesktops: moved=" & $iMoved & " failed=" & $iFailed)

    ; Allow Windows to process all moves before verification
    If $iMoved > 0 Then Sleep(150)

    ; Verify moves actually worked by spot-checking first window from each set
    Local $bVerified = True
    If $aWinA[0] > 0 Then
        Local $iCheckA = _VD_GetWindowDesktopNumber($aWinA[1])
        _Log_Debug("SwapDesktops VERIFY: A hwnd=" & $aWinA[1] & " should be on " & $iB & ", actually on " & $iCheckA)
        If $iCheckA <> $iB And $iCheckA > 0 Then $bVerified = False
    EndIf
    If $aWinB[0] > 0 Then
        Local $iCheckB = _VD_GetWindowDesktopNumber($aWinB[1])
        _Log_Debug("SwapDesktops VERIFY: B hwnd=" & $aWinB[1] & " should be on " & $iA & ", actually on " & $iCheckB)
        If $iCheckB <> $iA And $iCheckB > 0 Then $bVerified = False
    EndIf

    If Not $bVerified Then
        _Log_Error("SwapDesktops: WINDOW MOVES DID NOT TAKE EFFECT")
    EndIf

    ; Swap OS desktop names
    If _VD_HasNameSupport() Then
        Local $sNameA = _VD_GetName($iA)
        Local $sNameB = _VD_GetName($iB)
        _VD_SetName($iA, $sNameB)
        _VD_SetName($iB, $sNameA)
    EndIf

    ; Swap desktop colors
    Local $iColorA = _Cfg_GetDesktopColor($iA)
    Local $iColorB = _Cfg_GetDesktopColor($iB)
    If $iColorA <> $iColorB Then
        _Cfg_SetDesktopColor($iA, $iColorB)
        _Cfg_SetDesktopColor($iB, $iColorA)
    EndIf

    _Log_Debug("SwapDesktops: complete — moved=" & $iMoved & " failed=" & $iFailed & " verified=" & $bVerified)
    Return $bVerified
EndFunc

; Name:        _VD_RegisterNotify
; Description: Registers a window to receive a message when the virtual desktop changes.
;              The DLL posts the message to the given window via PostMessage.
; Parameters:  $hWnd - window handle to receive the notification
;              $iMsg - custom message ID (e.g. $WM_USER + 200)
; Return:      True on success, False if unsupported
Func _VD_RegisterNotify($hWnd, $iMsg)
    If $__g_VD_hDLL = -1 Then Return False
    DllCall($__g_VD_hDLL, "int", "RegisterPostMessageHook", "hwnd", $hWnd, "uint", $iMsg)
    If @error Then Return False
    Return True
EndFunc

; Name:        _VD_UnregisterNotify
; Description: Unregisters the desktop change notification hook
; Parameters:  $hWnd - the window handle that was registered
Func _VD_UnregisterNotify($hWnd)
    If $__g_VD_hDLL = -1 Then Return
    DllCall($__g_VD_hDLL, "int", "UnregisterPostMessageHook", "hwnd", $hWnd)
EndFunc

; Name:        _VD_CreateDesktop
; Description: Creates a new virtual desktop
; Return:      True on success, False on failure or unsupported
Func _VD_CreateDesktop()
    __VD_Call("CreateDesktop", "int")
    If @error Then Return False
    _VD_InvalidateCountCache()
    Return True
EndFunc

; Name:        _VD_RemoveDesktop
; Description: Removes a virtual desktop. Windows on the removed desktop are
;              moved to the fallback desktop.
; Parameters:  $iDesktop - desktop index to remove (1-based)
;              $iFallback - desktop to move windows to (1-based, default: adjacent)
; Return:      True on success, False on failure or unsupported
Func _VD_RemoveDesktop($iDesktop, $iFallback = Default)
    If $iFallback = Default Then
        If $iDesktop > 1 Then
            $iFallback = $iDesktop - 1
        Else
            $iFallback = 2
        EndIf
    EndIf
    Local $aArgs[4] = ["int", $iDesktop - 1, "int", $iFallback - 1]
    Local $aResult = __VD_Call("RemoveDesktop", "int", $aArgs)
    If @error Then Return False
    _VD_InvalidateCountCache()
    Return True
EndFunc

; Name:        _VD_Shutdown
; Description: Closes the DLL handle
Func _VD_Shutdown()
    If $__g_VD_hEnumCB <> 0 Then
        DllCallbackFree($__g_VD_hEnumCB)
        $__g_VD_hEnumCB = 0
        $__g_VD_pEnumCB = 0
    EndIf
    If $__g_VD_hDLL <> -1 Then
        DllClose($__g_VD_hDLL)
        $__g_VD_hDLL = -1
    EndIf
EndFunc
