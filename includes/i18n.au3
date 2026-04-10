#include-once

; #INDEX# =======================================================
; Title .........: i18n
; Description ....: Internationalization system — loads INI-based locale files
;                   and provides O(1) string lookups with fallback chain.
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_i18n_sLang = "en-US"
Global $__g_i18n_oStrings = 0    ; Scripting.Dictionary for current locale
Global $__g_i18n_oFallback = 0   ; Scripting.Dictionary for en-US.ini (always loaded)
Global $__g_i18n_sLocaleDir = ""

; #FUNCTIONS# ===================================================

; Name:        _i18n_Init
; Description: Loads locale files into memory. Always loads en-US.ini as fallback.
;              If $sLang is not "en-US", also loads <lang>.ini as primary.
; Parameters:  $sLang - ISO locale code (e.g. "en-US", "pt-PT", "en-GB")
; Return:      True on success
Func _i18n_Init($sLang = "en-US")
    $__g_i18n_sLocaleDir = @ScriptDir & "\locales"
    $__g_i18n_sLang = $sLang

    ; Always load English as fallback
    $__g_i18n_oFallback = ObjCreate("Scripting.Dictionary")
    If Not IsObj($__g_i18n_oFallback) Then Return False
    Local $sEnPath = $__g_i18n_sLocaleDir & "\en-US.ini"
    If FileExists($sEnPath) Then __i18n_LoadFile($sEnPath, $__g_i18n_oFallback)

    ; Load requested locale if different from English
    If $sLang <> "en-US" Then
        $__g_i18n_oStrings = ObjCreate("Scripting.Dictionary")
        If Not IsObj($__g_i18n_oStrings) Then
            $__g_i18n_oStrings = 0
            Return True ; fall back to English
        EndIf
        Local $sLangPath = $__g_i18n_sLocaleDir & "\" & $sLang & ".ini"
        If FileExists($sLangPath) Then
            __i18n_LoadFile($sLangPath, $__g_i18n_oStrings)
        Else
            $__g_i18n_oStrings = 0 ; locale not found, use English
        EndIf
    EndIf

    Return True
EndFunc

; Name:        _i18n
; Description: Returns a translated string for the given key.
;              Fallback: current locale -> en-US.ini -> $sDefault parameter.
; Parameters:  $sKey - dot-notation key (e.g. "ContextMenu.cm_quit")
;              $sDefault - hardcoded English fallback (never returns blank)
; Return:      Translated string
Func _i18n($sKey, $sDefault = "")
    ; Check current locale first
    If IsObj($__g_i18n_oStrings) And $__g_i18n_oStrings.Exists($sKey) Then
        Return StringReplace($__g_i18n_oStrings.Item($sKey), "\n", @CRLF)
    EndIf
    ; Check English fallback
    If IsObj($__g_i18n_oFallback) And $__g_i18n_oFallback.Exists($sKey) Then
        Return StringReplace($__g_i18n_oFallback.Item($sKey), "\n", @CRLF)
    EndIf
    ; Ultimate fallback: hardcoded default
    Return $sDefault
EndFunc

; Name:        _i18n_Format
; Description: Returns a translated string with {1},{2},{3} placeholders replaced.
; Parameters:  $sKey - dot-notation key
;              $sDefault - hardcoded English fallback with placeholders
;              $p1, $p2, $p3 - replacement values
; Return:      Formatted translated string
Func _i18n_Format($sKey, $sDefault, $p1 = Default, $p2 = Default, $p3 = Default)
    Local $sResult = _i18n($sKey, $sDefault)
    If $p1 <> Default Then $sResult = StringReplace($sResult, "{1}", $p1)
    If $p2 <> Default Then $sResult = StringReplace($sResult, "{2}", $p2)
    If $p3 <> Default Then $sResult = StringReplace($sResult, "{3}", $p3)
    Return $sResult
EndFunc

; Name:        _i18n_GetAvailable
; Description: Scans locales/ folder for available language files.
; Return:      Pipe-delimited string of language codes (e.g. "en|pt-PT|es")
Func _i18n_GetAvailable()
    Local $sResult = ""
    Local $hSearch = FileFindFirstFile($__g_i18n_sLocaleDir & "\*.ini")
    If $hSearch = -1 Then Return "en-US"
    While 1
        Local $sFile = FileFindNextFile($hSearch)
        If @error Then ExitLoop
        Local $sCode = StringTrimRight($sFile, 4) ; remove .ini
        If $sResult <> "" Then $sResult &= "|"
        $sResult &= $sCode
    WEnd
    FileClose($hSearch)
    If $sResult = "" Then $sResult = "en-US"
    Return $sResult
EndFunc

; Name:        _i18n_GetCurrent
; Description: Returns the current language code
; Return:      Locale code string (e.g. "en-US", "pt-PT")
Func _i18n_GetCurrent()
    Return $__g_i18n_sLang
EndFunc

; #INTERNAL HELPERS# ============================================

; Name:        __i18n_LoadFile
; Description: Loads all sections from an INI file into a Scripting.Dictionary.
;              Keys stored as "section.key" format for O(1) lookup.
; Parameters:  $sPath - full path to INI file
;              $oDict - Scripting.Dictionary object (ByRef)
Func __i18n_LoadFile($sPath, ByRef $oDict)
    If Not IsObj($oDict) Then Return

    Local $aSections = IniReadSectionNames($sPath)
    If @error Then Return

    Local $i, $j
    For $i = 1 To $aSections[0]
        Local $sSection = $aSections[$i]
        Local $aKeys = IniReadSection($sPath, $sSection)
        If @error Then ContinueLoop
        For $j = 1 To $aKeys[0][0]
            Local $sFullKey = $sSection & "." & $aKeys[$j][0]
            If $oDict.Exists($sFullKey) Then
                $oDict.Item($sFullKey) = $aKeys[$j][1]
            Else
                $oDict.Add($sFullKey, $aKeys[$j][1])
            EndIf
        Next
    Next
EndFunc
