#include <GDIPlus.au3>
#include <File.au3>

; ============================================================
; Desk Switcheroo Icon Generator
; Generates assets/desk_switcheroo.ico with multiple sizes
; using GDI+ drawing routines.
; ============================================================

; Sizes to generate
Global $aSizes[4] = [16, 32, 48, 256]
Global $sOutputDir = @ScriptDir & "\..\assets"
Global $sOutputFile = $sOutputDir & "\desk_switcheroo.ico"

; Ensure output directory exists
If Not FileExists($sOutputDir) Then DirCreate($sOutputDir)

_GDIPlus_Startup()

; Generate PNG data for each size
Global $aPngData[4] ; array of binary PNG data
For $i = 0 To 3
    $aPngData[$i] = _GenerateIconPng($aSizes[$i])
Next

; Build ICO file
_BuildIcoFile($sOutputFile, $aSizes, $aPngData)

_GDIPlus_Shutdown()

ConsoleWrite("Icon generated: " & $sOutputFile & @CRLF)
Exit 0

; ============================================================
; Draw the monitor icon at the given size and return PNG binary
; ============================================================
Func _GenerateIconPng($iSize)
    Local $hBitmap = _GDIPlus_BitmapCreateFromScan0($iSize, $iSize)
    Local $hGraphics = _GDIPlus_ImageGetGraphicsContext($hBitmap)

    ; High quality rendering
    _GDIPlus_GraphicsSetSmoothingMode($hGraphics, 4) ; AntiAlias
    _GDIPlus_GraphicsSetPixelOffsetMode($hGraphics, 4) ; Half

    ; Clear to transparent
    _GDIPlus_GraphicsClear($hGraphics, 0x00000000)

    ; Scale factors
    Local $fScale = $iSize / 256.0

    ; Colors
    Local $clrOutline = 0xFF2D7DD2   ; Blue outline
    Local $clrFill = 0xFFFFFFFF      ; White fill
    Local $clrDotActive = 0xFF2D7DD2 ; Blue dot (active)
    Local $clrDotInactive = 0xFFB0B0B0 ; Gray dot (inactive)
    Local $clrStand = 0xFF2D7DD2     ; Blue stand

    ; Pens and brushes
    Local $hPenOutline = _GDIPlus_PenCreate($clrOutline, 8 * $fScale)
    Local $hBrushFill = _GDIPlus_BrushCreateSolid($clrFill)
    Local $hBrushActive = _GDIPlus_BrushCreateSolid($clrDotActive)
    Local $hBrushInactive = _GDIPlus_BrushCreateSolid($clrDotInactive)
    Local $hPenStand = _GDIPlus_PenCreate($clrStand, 10 * $fScale)

    ; Monitor body dimensions (rounded rectangle)
    Local $fMonX = 20 * $fScale
    Local $fMonY = 20 * $fScale
    Local $fMonW = 216 * $fScale
    Local $fMonH = 150 * $fScale
    Local $fRadius = 16 * $fScale

    ; Draw monitor body - filled rounded rect
    Local $hPath = _GDIPlus_PathCreate()
    _AddRoundedRect($hPath, $fMonX, $fMonY, $fMonW, $fMonH, $fRadius)
    _GDIPlus_GraphicsFillPath($hGraphics, $hPath, $hBrushFill)
    _GDIPlus_GraphicsDrawPath($hGraphics, $hPath, $hPenOutline)
    _GDIPlus_PathDispose($hPath)

    ; Draw 2x2 grid of dots inside the monitor
    ; Layout:  [active]  [inactive]
    ;          [inactive] [active]
    Local $fCenterX = $fMonX + $fMonW / 2
    Local $fCenterY = $fMonY + $fMonH / 2
    Local $fDotR = 18 * $fScale  ; dot radius
    Local $fSpacing = 40 * $fScale ; spacing from center

    ; Top-left dot (active)
    _GDIPlus_GraphicsFillEllipse($hGraphics, $fCenterX - $fSpacing - $fDotR, $fCenterY - $fSpacing - $fDotR, $fDotR * 2, $fDotR * 2, $hBrushActive)
    ; Top-right dot (inactive)
    _GDIPlus_GraphicsFillEllipse($hGraphics, $fCenterX + $fSpacing - $fDotR, $fCenterY - $fSpacing - $fDotR, $fDotR * 2, $fDotR * 2, $hBrushInactive)
    ; Bottom-left dot (inactive)
    _GDIPlus_GraphicsFillEllipse($hGraphics, $fCenterX - $fSpacing - $fDotR, $fCenterY + $fSpacing - $fDotR, $fDotR * 2, $fDotR * 2, $hBrushInactive)
    ; Bottom-right dot (active)
    _GDIPlus_GraphicsFillEllipse($hGraphics, $fCenterX + $fSpacing - $fDotR, $fCenterY + $fSpacing - $fDotR, $fDotR * 2, $fDotR * 2, $hBrushActive)

    ; Draw stand/base
    Local $fStandTopY = $fMonY + $fMonH
    Local $fStandBottomY = $fStandTopY + 30 * $fScale
    Local $fStandMidX = $fCenterX

    ; Vertical neck
    _GDIPlus_GraphicsDrawLine($hGraphics, $fStandMidX, $fStandTopY, $fStandMidX, $fStandBottomY, $hPenStand)
    ; Horizontal base
    Local $fBaseHalfW = 40 * $fScale
    _GDIPlus_GraphicsDrawLine($hGraphics, $fStandMidX - $fBaseHalfW, $fStandBottomY, $fStandMidX + $fBaseHalfW, $fStandBottomY, $hPenStand)

    ; Cleanup drawing objects
    _GDIPlus_PenDispose($hPenOutline)
    _GDIPlus_BrushDispose($hBrushFill)
    _GDIPlus_BrushDispose($hBrushActive)
    _GDIPlus_BrushDispose($hBrushInactive)
    _GDIPlus_PenDispose($hPenStand)
    _GDIPlus_GraphicsDispose($hGraphics)

    ; Encode to PNG in memory
    Local $sCLSID = _GDIPlus_EncodersGetCLSID("PNG")
    Local $sTempPng = @TempDir & "\desk_switcheroo_" & $iSize & ".png"
    _GDIPlus_ImageSaveToFileEx($hBitmap, $sTempPng, $sCLSID)
    _GDIPlus_BitmapDispose($hBitmap)

    ; Read PNG binary
    Local $hFile = FileOpen($sTempPng, 16) ; binary mode
    Local $bData = FileRead($hFile)
    FileClose($hFile)
    FileDelete($sTempPng)

    Return $bData
EndFunc

; ============================================================
; Add a rounded rectangle to a GDI+ path
; ============================================================
Func _AddRoundedRect(ByRef $hPath, $fX, $fY, $fW, $fH, $fR)
    ; Top-left arc
    _GDIPlus_PathAddArc($hPath, $fX, $fY, $fR * 2, $fR * 2, 180, 90)
    ; Top edge
    _GDIPlus_PathAddLine($hPath, $fX + $fR, $fY, $fX + $fW - $fR, $fY)
    ; Top-right arc
    _GDIPlus_PathAddArc($hPath, $fX + $fW - $fR * 2, $fY, $fR * 2, $fR * 2, 270, 90)
    ; Right edge
    _GDIPlus_PathAddLine($hPath, $fX + $fW, $fY + $fR, $fX + $fW, $fY + $fH - $fR)
    ; Bottom-right arc
    _GDIPlus_PathAddArc($hPath, $fX + $fW - $fR * 2, $fY + $fH - $fR * 2, $fR * 2, $fR * 2, 0, 90)
    ; Bottom edge
    _GDIPlus_PathAddLine($hPath, $fX + $fW - $fR, $fY + $fH, $fX + $fR, $fY + $fH)
    ; Bottom-left arc
    _GDIPlus_PathAddArc($hPath, $fX, $fY + $fH - $fR * 2, $fR * 2, $fR * 2, 90, 90)
    ; Left edge
    _GDIPlus_PathAddLine($hPath, $fX, $fY + $fH - $fR, $fX, $fY + $fR)
    ; Close the path
    _GDIPlus_PathCloseFigure($hPath)
EndFunc

; ============================================================
; Build an ICO file from PNG data arrays
; ICO format:
;   6 bytes: header (reserved=0, type=1, count=N)
;   N * 16 bytes: directory entries
;   PNG data blocks
; ============================================================
Func _BuildIcoFile($sPath, ByRef $aSizes, ByRef $aPngData)
    Local $iCount = UBound($aSizes)

    ; Calculate offsets
    Local $iHeaderSize = 6
    Local $iDirSize = $iCount * 16
    Local $iDataOffset = $iHeaderSize + $iDirSize

    ; Build the ICO binary
    Local $tHeader = DllStructCreate("ushort reserved; ushort type; ushort count")
    DllStructSetData($tHeader, "reserved", 0)
    DllStructSetData($tHeader, "type", 1) ; 1 = ICO
    DllStructSetData($tHeader, "count", $iCount)

    Local $hFile = FileOpen($sPath, 2 + 16) ; write + binary
    If $hFile = -1 Then
        ConsoleWrite("Error: Cannot create " & $sPath & @CRLF)
        Return
    EndIf

    ; Write header
    FileWrite($hFile, DllStructGetData(DllStructCreate("byte[6]", DllStructGetPtr($tHeader)), 1))

    ; Calculate data offsets for each entry
    Local $aOffsets[$iCount]
    Local $iCurrentOffset = $iDataOffset
    For $i = 0 To $iCount - 1
        $aOffsets[$i] = $iCurrentOffset
        $iCurrentOffset += BinaryLen($aPngData[$i])
    Next

    ; Write directory entries
    For $i = 0 To $iCount - 1
        Local $iW = $aSizes[$i]
        Local $iH = $aSizes[$i]
        ; Width and Height: 0 means 256
        Local $bW = ($iW >= 256) ? 0 : $iW
        Local $bH = ($iH >= 256) ? 0 : $iH
        Local $iPngLen = BinaryLen($aPngData[$i])

        Local $tEntry = DllStructCreate("byte width; byte height; byte colorcount; byte reserved; ushort planes; ushort bitcount; dword size; dword offset")
        DllStructSetData($tEntry, "width", $bW)
        DllStructSetData($tEntry, "height", $bH)
        DllStructSetData($tEntry, "colorcount", 0)
        DllStructSetData($tEntry, "reserved", 0)
        DllStructSetData($tEntry, "planes", 1)
        DllStructSetData($tEntry, "bitcount", 32)
        DllStructSetData($tEntry, "size", $iPngLen)
        DllStructSetData($tEntry, "offset", $aOffsets[$i])

        FileWrite($hFile, DllStructGetData(DllStructCreate("byte[16]", DllStructGetPtr($tEntry)), 1))
    Next

    ; Write PNG data blocks
    For $i = 0 To $iCount - 1
        FileWrite($hFile, $aPngData[$i])
    Next

    FileClose($hFile)
    ConsoleWrite("ICO file written: " & $sPath & " (" & $iCount & " sizes)" & @CRLF)
EndFunc
