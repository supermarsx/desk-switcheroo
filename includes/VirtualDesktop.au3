#include-once
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
Global $__g_VD_hCountTimer = 0

; #FUNCTIONS# ===================================================

; Name:        _VD_Init
; Description: Opens the VirtualDesktopAccessor DLL
; Parameters:  $sDllPath - full path to DLL (default: @ScriptDir & "\VirtualDesktopAccessor.dll")
; Return:      True on success, False on failure
Func _VD_Init($sDllPath = Default)
    If $sDllPath = Default Then $sDllPath = @ScriptDir & "\VirtualDesktopAccessor.dll"
    If $__g_VD_hDLL <> -1 Then DllClose($__g_VD_hDLL)
    $__g_VD_hDLL = DllOpen($sDllPath)
    If $__g_VD_hDLL = -1 Then Return False
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
    ; Return cached value if fresh (< 500ms old)
    If $__g_VD_iCachedCount > 0 Then
        Local $iElapsed = TimerDiff($__g_VD_hCountTimer)
        If $iElapsed < 500 Then Return $__g_VD_iCachedCount
    EndIf
    If $__g_VD_hDLL = -1 Then Return 1
    Local $aResult = DllCall($__g_VD_hDLL, "int", "GetDesktopCount")
    If @error Or Not IsArray($aResult) Or $aResult[0] < 1 Then Return 1
    $__g_VD_iCachedCount = $aResult[0]
    $__g_VD_hCountTimer = TimerInit()
    Return $aResult[0]
EndFunc

; Name:        _VD_InvalidateCountCache
; Description: Forces the next _VD_GetCount() call to query the DLL
Func _VD_InvalidateCountCache()
    $__g_VD_iCachedCount = 0
EndFunc

; Name:        _VD_GetCurrent
; Description: Returns the current virtual desktop index (1-based)
; Return:      Integer >= 1
Func _VD_GetCurrent()
    If $__g_VD_hDLL = -1 Then Return 1
    Local $aResult = DllCall($__g_VD_hDLL, "int", "GetCurrentDesktopNumber")
    If @error Or Not IsArray($aResult) Or $aResult[0] < 0 Then Return 1
    Return $aResult[0] + 1
EndFunc

; Name:        _VD_GoTo
; Description: Switches to a virtual desktop by index (1-based)
; Parameters:  $iDesktop - target desktop index (1-based)
Func _VD_GoTo($iDesktop)
    If $__g_VD_hDLL = -1 Then Return
    DllCall($__g_VD_hDLL, "int", "GoToDesktopNumber", "int", $iDesktop - 1)
    ; @error is non-critical here — the switch simply won't happen
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
    If @error Or $aResult[0] <> 0 Then Return False
    Return True
EndFunc

; Name:        _VD_GetWindowDesktopNumber
; Description: Returns which virtual desktop a window is on (1-based)
; Parameters:  $hWnd - window handle
; Return:      Desktop index (1-based), or 0 if error/pinned
Func _VD_GetWindowDesktopNumber($hWnd)
    If $__g_VD_hDLL = -1 Then Return 0
    Local $aResult = DllCall($__g_VD_hDLL, "int", "GetWindowDesktopNumber", "hwnd", $hWnd)
    If @error Or Not IsArray($aResult) Or $aResult[0] < 0 Then Return 0
    Return $aResult[0] + 1
EndFunc

; Name:        _VD_MoveWindowToDesktop
; Description: Moves a window to a virtual desktop
; Parameters:  $hWnd - window handle
;              $iDesktop - target desktop index (1-based)
; Return:      True on success, False on failure
Func _VD_MoveWindowToDesktop($hWnd, $iDesktop)
    If $__g_VD_hDLL = -1 Then Return False
    DllCall($__g_VD_hDLL, "int", "MoveWindowToDesktopNumber", "hwnd", $hWnd, "int", $iDesktop - 1)
    If @error Then Return False
    Return True
EndFunc

; Name:        _VD_EnumWindowsOnDesktop
; Description: Returns an array of window handles on a given desktop
; Parameters:  $iDesktop - desktop index (1-based)
; Return:      Array where [0] = count, [1..N] = HWNDs
Func _VD_EnumWindowsOnDesktop($iDesktop)
    Local $aAll = WinList("")
    Local $aResult[$aAll[0][0] + 1]
    $aResult[0] = 0
    Local $i
    For $i = 1 To $aAll[0][0]
        Local $hWnd = $aAll[$i][1]
        If $hWnd = 0 Then ContinueLoop
        ; Pre-filter: skip windows with empty title (phantom/child windows)
        If $aAll[$i][0] = "" Then ContinueLoop
        ; Pre-filter: skip windows that are children (have a parent)
        If _WinAPI_GetParent($hWnd) <> 0 Then ContinueLoop
        ; Skip invisible windows
        If Not BitAND(WinGetState($hWnd), 2) Then ContinueLoop
        ; Direct DllCall instead of wrapper to avoid function-call overhead in tight loop
        Local $aDesk = DllCall($__g_VD_hDLL, "int", "GetWindowDesktopNumber", "hwnd", $hWnd)
        If @error Or $aDesk[0] < 0 Then ContinueLoop
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
    Local $aWinA = _VD_EnumWindowsOnDesktop($iA)
    Local $aWinB = _VD_EnumWindowsOnDesktop($iB)
    ; Move A's windows to B
    Local $i
    For $i = 1 To $aWinA[0]
        _VD_MoveWindowToDesktop($aWinA[$i], $iB)
    Next
    ; Move B's windows to A
    For $i = 1 To $aWinB[0]
        _VD_MoveWindowToDesktop($aWinB[$i], $iA)
    Next
    Return True
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
    If $__g_VD_hDLL = -1 Then Return False
    DllCall($__g_VD_hDLL, "int", "CreateDesktop")
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
    If $__g_VD_hDLL = -1 Then Return False
    Local $aResult = DllCall($__g_VD_hDLL, "int", "RemoveDesktop", "int", $iDesktop - 1, "int", $iFallback - 1)
    If @error Then Return False
    _VD_InvalidateCountCache()
    Return True
EndFunc

; Name:        _VD_Shutdown
; Description: Closes the DLL handle
Func _VD_Shutdown()
    If $__g_VD_hDLL <> -1 Then
        DllClose($__g_VD_hDLL)
        $__g_VD_hDLL = -1
    EndIf
EndFunc
