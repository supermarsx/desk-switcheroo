; Desk Switcheroo NSIS Installer Script
; Requires NSIS 3.x with MUI2

!include "MUI2.nsh"
!include "FileFunc.nsh"

; ============================================================
; General Settings
; ============================================================
Name "Desk Switcheroo"
OutFile "..\build\DeskSwitcheroo_Setup.exe"
InstallDir "$PROGRAMFILES64\DeskSwitcheroo"
InstallDirRegKey HKLM "Software\DeskSwitcheroo" "InstallDir"
RequestExecutionLevel admin
Unicode True

; Version info
!define PRODUCT_NAME "Desk Switcheroo"
!define PRODUCT_PUBLISHER "supermarsx"
!define PRODUCT_WEB_SITE "https://github.com/supermarsx/desk-switcheroo"

; Executable metadata
VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "Desk Switcheroo"
VIAddVersionKey "CompanyName" "supermarsx"
VIAddVersionKey "LegalCopyright" "MIT License"
VIAddVersionKey "FileDescription" "Desk Switcheroo Virtual Desktop Switcher"
VIAddVersionKey "FileVersion" "1.0.0.0"
VIAddVersionKey "ProductVersion" "1.0.0.0"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeskSwitcheroo"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; ============================================================
; MUI Settings
; ============================================================
!define MUI_ABORTWARNING
!define MUI_ICON "..\assets\desk_switcheroo.ico"
!define MUI_UNICON "..\assets\desk_switcheroo.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME

; License page
!insertmacro MUI_PAGE_LICENSE "..\license.md"

; Components page
!insertmacro MUI_PAGE_COMPONENTS

; Directory page
!insertmacro MUI_PAGE_DIRECTORY

; Install files page
!insertmacro MUI_PAGE_INSTFILES

; Finish page
!define MUI_FINISHPAGE_RUN "$INSTDIR\DeskSwitcheroo.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Desk Switcheroo"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Language
!insertmacro MUI_LANGUAGE "English"

; ============================================================
; Installer Sections
; ============================================================

Section "Core Files (required)" SecCore
    SectionIn RO ; Read-only, cannot be deselected

    SetOutPath "$INSTDIR"
    File "..\build\DeskSwitcheroo.exe"
    File "..\build\VirtualDesktopAccessor.dll"

    ; Write install dir to registry
    WriteRegStr HKLM "Software\DeskSwitcheroo" "InstallDir" "$INSTDIR"

    ; Create uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Write uninstall info to registry
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\DeskSwitcheroo.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"

    ; Calculate installed size
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"

    ; Start Menu shortcuts
    CreateDirectory "$SMPROGRAMS\Desk Switcheroo"
    CreateShortCut "$SMPROGRAMS\Desk Switcheroo\Desk Switcheroo.lnk" "$INSTDIR\DeskSwitcheroo.exe"
    CreateShortCut "$SMPROGRAMS\Desk Switcheroo\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Fira Code Fonts" SecFonts
    SetOutPath "$INSTDIR\fonts"
    File /nonfatal /r "..\build\fonts\*.*"
SectionEnd

Section "Desktop Shortcut" SecDesktop
    CreateShortCut "$DESKTOP\Desk Switcheroo.lnk" "$INSTDIR\DeskSwitcheroo.exe"
SectionEnd

Section "Start with Windows" SecAutostart
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "DeskSwitcheroo" "$INSTDIR\DeskSwitcheroo.exe"
SectionEnd

; ============================================================
; Section Descriptions
; ============================================================
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCore} "Core application files (required)."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecFonts} "Install Fira Code fonts used for the desktop overlay display."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Create a shortcut on the desktop."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecAutostart} "Automatically start Desk Switcheroo when Windows starts."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ============================================================
; Uninstaller Section
; ============================================================
Section "Uninstall"
    ; Kill running instance
    ExecWait 'taskkill /F /IM DeskSwitcheroo.exe' $0

    ; Remove files
    Delete "$INSTDIR\DeskSwitcheroo.exe"
    Delete "$INSTDIR\VirtualDesktopAccessor.dll"
    Delete "$INSTDIR\Uninstall.exe"

    ; Remove fonts directory
    RMDir /r "$INSTDIR\fonts"

    ; Remove install directory (only if empty or ours)
    RMDir /r "$INSTDIR"

    ; Remove Start Menu shortcuts
    Delete "$SMPROGRAMS\Desk Switcheroo\Desk Switcheroo.lnk"
    Delete "$SMPROGRAMS\Desk Switcheroo\Uninstall.lnk"
    RMDir "$SMPROGRAMS\Desk Switcheroo"

    ; Remove Desktop shortcut
    Delete "$DESKTOP\Desk Switcheroo.lnk"

    ; Remove autostart registry entry
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "DeskSwitcheroo"

    ; Remove application registry keys
    DeleteRegKey HKLM "Software\DeskSwitcheroo"
    DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
SectionEnd
