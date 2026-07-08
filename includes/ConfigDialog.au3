#include-once
#include "Config.au3"
#include "Theme.au3"
#include "DesktopList.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <WinAPISysWin.au3>

; #INDEX# =======================================================
; Title .........: ConfigDialog
; Description ....: Fully dark-themed settings window using custom label-based
;                   tabs and checkboxes (no native controls that resist theming)
; Author .........: Mariana
; ===============================================================

; #INTERNAL GLOBALS# ============================================
Global $__g_CD_hGUI = 0
Global $__g_CD_bVisible = False
Global $__g_CD_iActiveTab = 0

; -- Tab button IDs --
Global $__g_CD_aidTabBtn[16] ; index 1-14
Global Const $__g_CD_iTabCount = 14

; -- Controls per tab (arrays of IDs to show/hide + scroll) --
Global Const $__g_CD_MAX_CTRLS = 200
Global $__g_CD_aidTabCtrls[16][$__g_CD_MAX_CTRLS] ; [tab 1-14][up to 200 controls per tab]
Global $__g_CD_aiTabCtrlY[16][$__g_CD_MAX_CTRLS]  ; original Y position per control
Global $__g_CD_aiTabCtrlX[16][$__g_CD_MAX_CTRLS]  ; cached X position per control
Global $__g_CD_aiTabCtrlW[16][$__g_CD_MAX_CTRLS]  ; cached width per control
Global $__g_CD_aiTabCtrlH[16][$__g_CD_MAX_CTRLS]  ; cached height per control
Global $__g_CD_aiTabCtrlCount[16]   ; how many controls per tab
Global $__g_CD_aiTabScroll[16]      ; current scroll offset per tab (px)
Global $__g_CD_abTabYInit[16]       ; True once original Y positions captured for this tab
Global $__g_CD_iContentTop = 84     ; top of content area (3-row tab bar)
Global $__g_CD_iContentBottom = 0   ; bottom of content area (set in _CD_Show)
Global $__g_CD_iScrollStep = 30     ; pixels per scroll step

; -- Scroll indicator labels --
Global $__g_CD_idScrollUp = 0, $__g_CD_idScrollDn = 0

; -- Tab 1: General --
Global $__g_CD_idChkStartWin, $__g_CD_idChkWrapNav, $__g_CD_idChkAutoCreate
Global $__g_CD_idInpPadding, $__g_CD_idInpOffsetX
Global $__g_CD_idInpOffsetY, $__g_CD_idInpWidgetWidth, $__g_CD_idInpWidgetHeight, $__g_CD_idInpColorBarH
Global $__g_CD_idCmbColorBarAnim, $__g_CD_idInpColorBarAnimDur
Global $__g_CD_idLblPosition ; label that cycles left/center/right

; -- Tab 2: Display --
Global $__g_CD_idChkShowCount, $__g_CD_idInpCountFont, $__g_CD_idInpOpacity
Global $__g_CD_idLblTheme
Global $__g_CD_idChkThumbnails, $__g_CD_idInpThumbW, $__g_CD_idInpThumbH
Global $__g_CD_idChkThumbScreenshot, $__g_CD_idInpThumbCacheTTL

; -- Scroll (General sub-tab 4) --
Global $__g_CD_idChkScroll, $__g_CD_idChkScrollWrap
Global $__g_CD_idChkListScroll
Global $__g_CD_idLblScrollDir, $__g_CD_idLblListAction

; -- Tab 3: Hotkeys --
Global $__g_CD_idInpHkNext, $__g_CD_idInpHkPrev, $__g_CD_idInpHkToggleList
Global $__g_CD_aidInpHkDesktop[10] ; index 1-9
; Dynamic hotkey-builder registry: parallel arrays map each "..." button to its input.
; Populated by __CD_RegHkBuilder as rows are built (count-agnostic, replaces the old
; fixed 28-slot array + if-chain). Sized generously for all current + future rows.
Global $__g_CD_aHkBuildBtn[64], $__g_CD_aHkBuildInp[64], $__g_CD_iHkBuildCount = 0

; -- Main-loop callbacks (registered by desktop_switcher.au3 at startup) --
; String names invoked via Call(); empty until registered so headless tests no-op.
; Suspend/resume gate global hotkeys for the hotkey builder's whole lifetime (t8-c wires
; them to _UnregisterHotkeys/_RegisterHotkeys; until then they are no-ops). $sCbMainTick
; is used by t8-c's async-settings tick.
Global $__g_CD_sCbHkSuspend = "", $__g_CD_sCbHkResume = "", $__g_CD_sCbMainTick = ""
; Test seam: counts suspend/resume dispatches so pairing can be asserted headlessly.
Global $__g_CD_iHkSuspendCalls = 0, $__g_CD_iHkResumeCalls = 0

; -- Tab 1 extras: General --
Global $__g_CD_idChkWidgetDrag, $__g_CD_idChkWidgetColorBar, $__g_CD_idChkTrayMode, $__g_CD_idChkQuickAccess
Global $__g_CD_idChkListKeyNav
Global $__g_CD_idLblLanguage
Global $__g_CD_idComboOverlay = 0
Global $__g_CD_bDropdownOpen = False
Global $__g_CD_iSavedHighlight = 0, $__g_CD_iSavedHighlightText = 0

; -- Tab 6: Updates --
Global $__g_CD_idChkAutoUpdate, $__g_CD_idInpUpdateInterval
Global $__g_CD_idChkUpdateOnStartup, $__g_CD_idInpUpdateCheckDays
Global $__g_CD_idBtnCheckNow, $__g_CD_idBtnDownloadLatest
Global $__g_CD_iContentH = 450

; -- Tab 8: Animations --
Global $__g_CD_idChkAnimEnabled
Global $__g_CD_idChkAnimList, $__g_CD_idChkAnimMenus, $__g_CD_idChkAnimDialogs
Global $__g_CD_idChkAnimToasts, $__g_CD_idChkAnimWidget
Global $__g_CD_idInpFadeIn, $__g_CD_idInpFadeOut
Global $__g_CD_idInpFadeStep, $__g_CD_idInpFadeSleep
Global $__g_CD_idInpToastFadeOut
Global $__g_CD_idLblToastPosition

; -- Tab 9: OSD --
Global $__g_CD_idChkWallpaper, $__g_CD_idInpWallpaperDelay
Global $__g_CD_aidWallpaperPath[51]   ; index 1-50
Global $__g_CD_aidWallpaperBrowse[51] ; index 1-50

; -- Tab 10: Window List --
Global $__g_CD_idChkWLEnabled, $__g_CD_idLblWLPosition
Global $__g_CD_idInpWLWidth, $__g_CD_idInpWLMaxVisible
Global $__g_CD_idChkWLSearch
Global $__g_CD_idChkWLAutoRefresh, $__g_CD_idInpWLRefreshInterval
Global $__g_CD_idChkWLDraggable

; -- Tab 11: Explorer --
Global $__g_CD_idChkExplorerMonitor, $__g_CD_idInpExplorerInterval, $__g_CD_idChkExplorerNotify
Global $__g_CD_idInpShellProcess, $__g_CD_idInpMaxRetries, $__g_CD_idInpRetryDelay
Global $__g_CD_idChkExpBackoff, $__g_CD_idInpMaxRetryDelay
Global $__g_CD_idChkAutoRestart, $__g_CD_idInpRestartDelay

; -- Tab 12: Notifications --
Global $__g_CD_idChkNotificationsEnabled
Global $__g_CD_idChkNotifyMoved, $__g_CD_idChkNotifyCreated, $__g_CD_idChkNotifyDeleted, $__g_CD_idChkNotifyPinned
Global $__g_CD_idChkNotifyUnpinned, $__g_CD_idChkNotifyExplorerRecov, $__g_CD_idChkNotifyExplorerCrash
Global $__g_CD_idLblWLScope

; -- Tab 9: OSD Toast --
Global $__g_CD_idChkOsdEnabled = 0
Global $__g_CD_idChkOsdShowName = 0
Global $__g_CD_idChkOsdShowNumber = 0
Global $__g_CD_idInpOsdDuration = 0
Global $__g_CD_idCycOsdPosition = 0
Global $__g_CD_idInpOsdFontSize = 0
Global $__g_CD_idInpOsdOpacity = 0
Global $__g_CD_idInpOsdFormat = 0
Global $__g_CD_idInpOsdWidth = 0

; -- Tab 13: Taskbar Auto-Hide --
Global $__g_CD_idChkAutoHideSync, $__g_CD_idInpAutoHidePoll
Global $__g_CD_idInpAutoHideHideDelay, $__g_CD_idInpAutoHideShowDelay
Global $__g_CD_idChkAutoHideFade, $__g_CD_idInpAutoHideFadeDur
Global $__g_CD_idChkAutoHideSyncDL, $__g_CD_idChkAutoHideSyncWL
Global $__g_CD_idInpAutoHideThreshold, $__g_CD_idInpAutoHideRecheck
Global $__g_CD_idChkAutoHideSkipDialog

; -- Tab 14: Tray --
Global $__g_CD_idLblTrayLeftClick, $__g_CD_idLblTrayDoubleClick, $__g_CD_idLblTrayMiddleClick
Global $__g_CD_idChkTrayTooltipLabel, $__g_CD_idChkTrayTooltipCount
Global $__g_CD_idChkTrayMenuList, $__g_CD_idChkTrayMenuEdit, $__g_CD_idChkTrayMenuAdd
Global $__g_CD_idChkTrayMenuDelete, $__g_CD_idChkTrayMenuDesktopSub, $__g_CD_idChkTrayMenuMoveWin
Global $__g_CD_idChkTrayNotifySwitch, $__g_CD_idInpTrayBalloonDur
Global $__g_CD_idChkTrayCloseToTray

; -- Tab 6: Updates (info labels) --
Global $__g_CD_idLblLastChecked, $__g_CD_idLblNextCheck

Global Const $CD_OPT_WIDGET_POS = "bottom-left|bottom-center|bottom-right|middle-left|middle-right|top-left|top-center|top-right"
Global Const $CD_OPT_SCROLL_DIR = "normal|inverted"
Global Const $CD_OPT_LIST_ACTION = "switch|scroll"
Global Const $CD_OPT_LOG_LEVEL = "error|warn|info|debug"
Global Const $CD_OPT_LOG_DATE = "iso|us|eu"
Global Const $CD_OPT_THEME = "dark|darker|midnight|midday|sunset"
Global Const $CD_OPT_PANEL_POS = "top-left|top-center|top-right|middle-left|middle-center|middle-right|bottom-left|bottom-center|bottom-right"
Global Const $CD_OPT_WINDOW_SCOPE = "current|all"
Global Const $CD_OPT_OSD_POS = $CD_OPT_PANEL_POS & "|widget"
Global Const $CD_OPT_TOAST_POS = "top-left|top-right|bottom-left|bottom-right|widget"
Global Const $CD_OPT_TRAY_LEFT = "menu|toggle_list|next_desktop|nothing"
Global Const $CD_OPT_TRAY_DOUBLE = "settings|toggle_list|menu|nothing"
Global Const $CD_OPT_TRAY_MIDDLE = "toggle_list|add_desktop|toggle_slideshow|nothing"
Global Const $CD_OPT_SLIDESHOW_SELMODE = "all|even|odd|name_contains|custom"
Global Const $CD_OPT_SLIDESHOW_DIRECTION = "forward|backward"
Global Const $CD_OPT_SLIDESHOW_LOOPMODE = "infinite|count|duration"
Global Const $CD_OPT_COLOR_BAR_ANIM = "none|grow|fade"

; -- Tab 1 extras: General --
Global $__g_CD_idChkSingleton, $__g_CD_idChkTaskbarFocus, $__g_CD_idChkAutoFocus
Global $__g_CD_idChkStartMinimized, $__g_CD_idChkDisableWinWidgets, $__g_CD_idInpMinDesktops, $__g_CD_idInpMaxDesktops

; -- Tab 1: General sub-tabs --
Global $__g_CD_idGenSubWidget = 0, $__g_CD_idGenSubDesktop = 0, $__g_CD_idGenSubSystem = 0, $__g_CD_idGenSubScroll = 0
Global $__g_CD_aGenWidgetCtrls[50]   ; Widget sub-tab control IDs
Global $__g_CD_iGenWidgetCount = 0
Global $__g_CD_aGenDesktopCtrls[50]  ; Desktop sub-tab control IDs
Global $__g_CD_iGenDesktopCount = 0
Global $__g_CD_aGenSystemCtrls[50]   ; System sub-tab control IDs
Global $__g_CD_iGenSystemCount = 0
Global $__g_CD_aGenScrollCtrls[50]   ; Scroll sub-tab control IDs
Global $__g_CD_iGenScrollCount = 0
Global $__g_CD_iGenActiveSub = 1     ; 1=Widget, 2=Desktop, 3=System, 4=Scroll

; -- Tab 2: Display sub-tabs --
Global $__g_CD_idDispSubAppearance = 0, $__g_CD_idDispSubThumbnails = 0
Global $__g_CD_aDispAppearanceCtrls[50]
Global $__g_CD_iDispAppearanceCount = 0
Global $__g_CD_aDispThumbnailsCtrls[50]
Global $__g_CD_iDispThumbnailsCount = 0
Global $__g_CD_iDispActiveSub = 1

; -- Tab 3 extras: Hotkeys --
Global $__g_CD_idInpHkLastDesktop, $__g_CD_idInpHkMoveFollowNext, $__g_CD_idInpHkMoveFollowPrev
Global $__g_CD_idInpHkMoveToNext, $__g_CD_idInpHkMoveToPrev
Global $__g_CD_idInpHkSendToNew, $__g_CD_idInpHkPinWindow, $__g_CD_idInpHkToggleWL
Global $__g_CD_idChkHotkeysEnabled, $__g_CD_idInpHkOpenSettings
Global $__g_CD_idInpHkAddDesktop, $__g_CD_idInpHkDeleteDesktop, $__g_CD_idInpHkRenameDesktop
Global $__g_CD_idInpHkCloseWindow, $__g_CD_idInpHkMinimizeWindow
Global $__g_CD_idInpHkTaskView
Global $__g_CD_idInpHkMaximizeWindow, $__g_CD_idInpHkRestoreWindow, $__g_CD_idInpHkGatherWindows
Global $__g_CD_idInpHkToggleRules, $__g_CD_idInpHkToggleSession, $__g_CD_idInpHkToggleOsd, $__g_CD_idInpHkToggleWidget
Global $__g_CD_idInpHkLoadNextProfile, $__g_CD_idInpHkLoadPrevProfile, $__g_CD_idInpHkSwapDesktops
Global $__g_CD_aidInpHkMoveToDesktop[10] ; index 1-9, send active window to desktop N

; -- Tab 3: Hotkey sub-tabs --
Global $__g_CD_idHkSubNav = 0, $__g_CD_idHkSubWin = 0, $__g_CD_idHkSubDesk = 0
Global $__g_CD_idHkSubSend = 0, $__g_CD_idHkSubActions = 0
Global $__g_CD_aHkNavCtrls[50]   ; Navigation sub-tab control IDs
Global $__g_CD_iHkNavCount = 0
Global $__g_CD_aHkWinCtrls[50]   ; Windows sub-tab control IDs
Global $__g_CD_iHkWinCount = 0
Global $__g_CD_aHkDeskCtrls[50]  ; Desktops sub-tab control IDs
Global $__g_CD_iHkDeskCount = 0
Global $__g_CD_aHkSendCtrls[50]    ; Send sub-tab control IDs
Global $__g_CD_iHkSendCount = 0
Global $__g_CD_aHkActionsCtrls[50] ; Actions sub-tab control IDs
Global $__g_CD_iHkActionsCount = 0
Global $__g_CD_iHkActiveSub = 1  ; 1=Nav, 2=Win, 3=Desk, 4=Send, 5=Actions

; -- Tab 4: Behavior --
Global $__g_CD_idChkConfirmDel, $__g_CD_idChkMidClick, $__g_CD_idChkMoveWin, $__g_CD_idChkMoveHereClick
Global $__g_CD_idInpPeekDelay, $__g_CD_idInpAutoHide, $__g_CD_idInpTopmost, $__g_CD_idInpCmDelay
Global $__g_CD_idChkConfigWatcher, $__g_CD_idInpWatcherInterval
Global $__g_CD_idInpCtxDelay
Global $__g_CD_idChkDisableNativeOsd
Global $__g_CD_idChkPinningEnabled

; -- Colors checkbox (in Desktops tab) --
Global $__g_CD_idChkColorsEnabled

; -- Tab 2: Display extras --
Global $__g_CD_idInpListFont, $__g_CD_idInpListFontSize, $__g_CD_idInpTooltipFontSize
Global $__g_CD_idChkListScrollable, $__g_CD_idInpListMaxVisible, $__g_CD_idInpListScrollSpeed
Global $__g_CD_idChkDLShowNumbers

; -- Tab 5: Logging --
Global $__g_CD_idChkLogging, $__g_CD_idInpLogPath, $__g_CD_idBtnLogBrowse, $__g_CD_idLblLogLevel
Global $__g_CD_idInpLogMaxSize
Global $__g_CD_idInpLogRotateCount, $__g_CD_idChkLogCompress
Global $__g_CD_idChkLogPID, $__g_CD_idLblLogDateFormat, $__g_CD_idChkLogFlush

; -- Tab 4: Behavior extras --
Global $__g_CD_idChkConfirmQuit, $__g_CD_idChkConfirmRestart, $__g_CD_idChkDebugMode

; -- Tab 4: Slideshow (supersedes Carousel) --
Global $__g_CD_idChkSlideshowEnabled, $__g_CD_idInpSlideshowInterval
Global $__g_CD_idCmbSlideshowSelMode, $__g_CD_idCmbSlideshowDirection
Global $__g_CD_idInpSlideshowNameFilter, $__g_CD_idInpSlideshowSequence, $__g_CD_idInpSlideshowDesktopIntervals
Global $__g_CD_idCmbSlideshowLoopMode, $__g_CD_idInpSlideshowLoopCount, $__g_CD_idInpSlideshowLoopDuration
Global $__g_CD_idChkSlideshowAutostart, $__g_CD_idInpSlideshowAutostartDelay
Global $__g_CD_idChkSlideshowMenu, $__g_CD_idChkNotifySlideshow
Global $__g_CD_idChkSlideshowBreakManual, $__g_CD_idChkSlideshowBreakWidget
Global $__g_CD_idChkSlideshowBreakHotkey, $__g_CD_idChkSlideshowBreakInput

; -- Tab 4: Behavior sub-tabs --
Global $__g_CD_idBhvSubInteract = 0, $__g_CD_idBhvSubTimers = 0, $__g_CD_idBhvSubSlideshow = 0, $__g_CD_idBhvSubRules = 0
Global $__g_CD_aBhvInteractCtrls[50]
Global $__g_CD_iBhvInteractCount = 0
Global $__g_CD_aBhvTimersCtrls[50]
Global $__g_CD_iBhvTimersCount = 0
Global $__g_CD_aBhvSlideshowCtrls[50]
Global $__g_CD_iBhvSlideshowCount = 0
Global $__g_CD_aBhvRulesCtrls[50]
Global $__g_CD_iBhvRulesCount = 0
Global $__g_CD_iBhvActiveSub = 1     ; 1=Interaction, 2=Timers, 3=Slideshow, 4=Rules

; -- Tab 4: Rules engine controls --
Global $__g_CD_idChkRulesEnabled = 0
Global $__g_CD_idInpRulesPollInterval = 0
Global Const $__g_CD_iRuleRowCount = 10
Global $__g_CD_aidRuleType[11]     ; cycle labels: "Process" / "Class"
Global $__g_CD_aidRulePattern[11]  ; pattern input fields
Global $__g_CD_aidRuleDesktop[11]  ; target desktop number inputs

; -- Tab 3: Slideshow hotkey --
Global $__g_CD_idInpHkSlideshow

; -- Buttons --
Global $__g_CD_idBtnApply, $__g_CD_idBtnClose
Global $__g_CD_idBtnImport, $__g_CD_idBtnExport, $__g_CD_idBtnRestart

; -- Checkbox state tracking --
Global $__g_CD_aChkIDs[100]     ; control IDs (2 per checkbox: box + text)
Global $__g_CD_aChkStates[100]  ; boolean states
Global $__g_CD_aChkTexts[100]   ; original text per checkbox
Global $__g_CD_iChkCount = 0
Global $__g_CD_hBrushCombo = 0 ; GDI brush for combo dropdown theming

; -- Tab 7: Desktops --
Global $__g_CD_aidDeskLabel[51]   ; input fields for desktop labels, index 1-50
Global $__g_CD_aidDeskColor[51]   ; input fields for desktop colors, index 1-50
Global $__g_CD_aidDeskPreview[51] ; color preview labels, index 1-50
Global $__g_CD_aidDeskNum[51]     ; desktop number labels, index 1-50
Global $__g_CD_iDeskCount = 0     ; how many desktop rows were created

; -- Desktops tab pagination --
Global $__g_CD_iDeskPage = 1         ; current page (1-based)
Global $__g_CD_iDeskPageCount = 1    ; total pages
Global Const $__g_CD_DESK_PER_PAGE = 15
Global $__g_CD_aidDeskPageBtn[6]     ; page sub-tab buttons, index 1-5 (up to 50 desktops / 10 per page)

; -- Reset button --
Global $__g_CD_idBtnReset

; -- Settings search (t1-e11) --
Global Const $__g_CD_SEARCH_MAX = 250        ; registry capacity
Global Const $__g_CD_SEARCH_ROWS = 10        ; visible result rows
Global $__g_CD_aSearchCtrl[$__g_CD_SEARCH_MAX]       ; navigable/highlight control id
Global $__g_CD_aSearchTab[$__g_CD_SEARCH_MAX]        ; main tab 1-14
Global $__g_CD_aSearchSub[$__g_CD_SEARCH_MAX]        ; sub-tab index (0 = none)
Global $__g_CD_aSearchRow[$__g_CD_SEARCH_MAX]        ; display row "Tab > Sub > Label"
Global $__g_CD_aSearchTip[$__g_CD_SEARCH_MAX]        ; raw tooltip text -> description line + hover elaborate
Global $__g_CD_aSearchBlob[$__g_CD_SEARCH_MAX]       ; lowercased "label tooltip" match text
Global $__g_CD_aSearchRestoreBg[$__g_CD_SEARCH_MAX]  ; bkcolor restored after highlight pulse
Global $__g_CD_iSearchCount = 0                      ; registry size
Global $__g_CD_aSearchResultIdx[$__g_CD_SEARCH_MAX]  ; matched registry indices
Global $__g_CD_iSearchResultCount = 0
; results panel controls
Global $__g_CD_idSearchInput = 0
Global $__g_CD_idSearchPanelBg = 0
Global $__g_CD_idSearchCountLbl = 0
Global $__g_CD_aidSearchRowLbl[$__g_CD_SEARCH_ROWS]  ; result row labels (line 1: tab path)
Global $__g_CD_aidSearchDescLbl[$__g_CD_SEARCH_ROWS] ; result row descriptions (line 2: dim tooltip)
Global $__g_CD_aiSearchRowTipSlot[$__g_CD_SEARCH_ROWS] ; Theme tooltip registry slot per row (0 = none)
Global $__g_CD_aSearchRowEntry[$__g_CD_SEARCH_ROWS]  ; entry index shown in each row
Global $__g_CD_bSearchResultsVisible = False
Global $__g_CD_sSearchLast = ""                      ; last query processed (incremental poll)
Global $__g_CD_iSearchRowHovered = 0                 ; currently hovered result row index (1-based; 0 = none)
; highlight flash — a few on/off pulses on the navigated-to control (no Sleep; driven by the message loop)
Global Const $__g_CD_PULSE_STEP = 150                ; ms per on/off half-cycle
Global Const $__g_CD_PULSE_PHASES = 6                ; total half-cycles => 3 visible flashes
Global $__g_CD_iPulseCtrl = 0
Global $__g_CD_iPulseRestoreBg = 0
Global $__g_CD_hPulseTimer = 0
Global $__g_CD_iPulsePhase = -1                      ; last-applied flash phase (-1 = idle)
; escape edge detection (close-results vs close-dialog)
Global $__g_CD_bEscWasDown = False


; #FUNCTIONS# ===================================================

; Returns the extended window style that gives the Settings window a Windows
; taskbar button: strips $WS_EX_TOOLWINDOW (0x00000080, which suppresses the
; taskbar button and hides the window from Alt+Tab) and sets $WS_EX_APPWINDOW
; (0x00040000, which forces a taskbar button). All other bits (TOPMOST, LAYERED,
; etc.) are preserved. Pure/unit-testable — no GUI required.
Func __CD_TaskbarExStyle($iEx)
    $iEx = BitAND($iEx, BitNOT($WS_EX_TOOLWINDOW)) ; clear 0x00000080
    $iEx = BitOR($iEx, $WS_EX_APPWINDOW)           ; set 0x00040000
    Return $iEx
EndFunc

Func _CD_Show()
    ; Reentry guard (guard 1): with async settings the ctx-menu "settings", tray, hotkey
    ; and relayed-IPC open paths all stay reachable while the dialog is already up. Never
    ; nest a second blocking message loop — just surface and flash the existing dialog.
    If $__g_CD_bVisible Then
        If $__g_CD_hGUI <> 0 Then
            WinActivate($__g_CD_hGUI)
            ; Brief caption flash for feedback (FLASHW_CAPTION=1, 2 flashes, default rate).
            Local $tFlash = DllStructCreate("uint;hwnd;dword;uint;dword")
            DllStructSetData($tFlash, 1, DllStructGetSize($tFlash))
            DllStructSetData($tFlash, 2, $__g_CD_hGUI)
            DllStructSetData($tFlash, 3, 1)
            DllStructSetData($tFlash, 4, 2)
            DllStructSetData($tFlash, 5, 0)
            DllCall("user32.dll", "bool", "FlashWindowEx", "struct*", $tFlash)
        EndIf
        _Log_Info("Settings dialog already open — focusing existing instance")
        Return
    EndIf
    _Log_Info("Settings dialog opened")
    Local $iW = 540
    ; Dynamic height: use up to 85% of screen, minimum 600
    Local $iMaxH = Int(@DesktopHeight * 0.85)
    Local $iH = 700
    If $iH > $iMaxH Then $iH = $iMaxH
    If $iH < 600 Then $iH = 600
    Local $iX = (@DesktopWidth - $iW) / 2
    Local $iY = (@DesktopHeight - $iH) / 2

    $__g_CD_hGUI = _Theme_CreatePopup("Settings", $iW, $iH, $iX, $iY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Give the Settings window a taskbar button so the user can resurface it if it
    ; falls behind other windows. _Theme_CreatePopup sets $WS_EX_TOOLWINDOW on every
    ; popup, which suppresses the taskbar button; here (Settings-only) we clear that
    ; bit and set $WS_EX_APPWINDOW. Applied while the window is still hidden (GUICreate
    ; makes it hidden until _Theme_FadeIn's first GUISetState below), so the shell
    ; evaluates the app-window bit at button-creation time — no hide/show toggle needed.
    ; TOPMOST/LAYERED and all other bits are preserved by __CD_TaskbarExStyle.
    Local $iCDExStyle = _WinAPI_GetWindowLong($__g_CD_hGUI, $GWL_EXSTYLE)
    _WinAPI_SetWindowLong($__g_CD_hGUI, $GWL_EXSTYLE, __CD_TaskbarExStyle($iCDExStyle))
    ; Set the app icon so the taskbar entry isn't blank on uncompiled runs (the
    ; compiled exe already embeds it via build.ps1). Guarded by FileExists.
    If FileExists(@ScriptDir & "\assets\desk_switcheroo.ico") Then _
        GUISetIcon(@ScriptDir & "\assets\desk_switcheroo.ico", -1, $__g_CD_hGUI)

    ; Reset state
    $__g_CD_iChkCount = 0
    __CD_SearchReset()
    $__g_CD_bSearchResultsVisible = False
    $__g_CD_sSearchLast = ""
    $__g_CD_iSearchRowHovered = 0
    $__g_CD_iPulseCtrl = 0
    $__g_CD_iPulsePhase = -1
    $__g_CD_bEscWasDown = False
    Local $t
    For $t = 1 To 14
        $__g_CD_aiTabCtrlCount[$t] = 0
        $__g_CD_aiTabScroll[$t] = 0
        $__g_CD_abTabYInit[$t] = False
    Next

    ; Create custom tab bar (3 rows: 5 + 5 + 4 tabs)
    Local $iTabW = 102, $iTabH = 22, $iTabX = 10, $iTabY = 8
    Local $iTabsPerRow = 5
    For $t = 1 To $__g_CD_iTabCount
        If $t = $iTabsPerRow + 1 Or $t = $iTabsPerRow * 2 + 1 Then
            ; Start next row
            $iTabX = 10
            $iTabY += $iTabH + 2
        EndIf
        $__g_CD_aidTabBtn[$t] = GUICtrlCreateLabel(__CD_GetMainTabLabel($t), $iTabX, $iTabY, $iTabW, $iTabH, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidTabBtn[$t], 7, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_MAIN)
        GUICtrlSetCursor($__g_CD_aidTabBtn[$t], 0)
        $iTabX += $iTabW + 2
    Next

    ; Content area background (disabled so it doesn't intercept clicks on controls above)
    $__g_CD_iContentH = $iH - 168 ; leave room for 3-row tab bar + buttons
    $__g_CD_iContentBottom = $__g_CD_iContentTop + $__g_CD_iContentH ; bottom of visible content area
    Local $iContentH = $__g_CD_iContentH
    Local $idContentBg = GUICtrlCreateLabel("", 8, 84, $iW - 16, $iContentH)
    GUICtrlSetBkColor($idContentBg, $THEME_BG_MAIN)
    GUICtrlSetState($idContentBg, $GUI_DISABLE)

    ; Build each tab's controls
    __CD_BuildTabGeneral()
    __CD_BuildTabDisplay()
    __CD_BuildTabHotkeys()
    __CD_BuildTabBehavior()
    __CD_BuildTabLogging()
    __CD_BuildTabUpdates()
    __CD_BuildTabDesktops()
    __CD_BuildTabAnimations()
    __CD_BuildTabOSD()
    __CD_BuildTabWindowList()
    __CD_BuildTabExplorer()
    __CD_BuildTabNotifications()
    __CD_BuildTabTaskbar()
    __CD_BuildTabTray()

    ; Import + Export + Restart buttons (top row)
    Local $iBtnW = 80, $iBtnH = 26
    Local $iGap = 10
    Local $iRow1Y = $iH - 70
    Local $iRow1TotalW = $iBtnW * 3 + $iGap * 2
    Local $iRow1X = ($iW - $iRow1TotalW) / 2

    $__g_CD_idBtnImport = GUICtrlCreateLabel(ChrW(0x2B07) & " " & _i18n("General.btn_import", "Import"), $iRow1X, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnImport, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnImport, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnImport, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnImport, 0)

    $__g_CD_idBtnExport = GUICtrlCreateLabel(ChrW(0x2B06) & " " & _i18n("General.btn_export", "Export"), $iRow1X + $iBtnW + $iGap, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnExport, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnExport, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnExport, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnExport, 0)

    $__g_CD_idBtnRestart = GUICtrlCreateLabel(ChrW(0x21BB) & " " & _i18n("General.btn_restart", "Restart"), $iRow1X + ($iBtnW + $iGap) * 2, $iRow1Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnRestart, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnRestart, $THEME_FG_LINK)
    GUICtrlSetBkColor($__g_CD_idBtnRestart, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnRestart, 0)

    ; Apply + Reset + Close buttons (bottom row)
    Local $iRow2Y = $iH - 38
    Local $iTotalW = $iBtnW * 3 + $iGap * 2
    Local $iBtnX = ($iW - $iTotalW) / 2

    $__g_CD_idBtnApply = GUICtrlCreateLabel(ChrW(0x2713) & " " & _i18n("General.btn_apply", "Apply"), $iBtnX, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnApply, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnApply, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnApply, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnApply, 0)

    $__g_CD_idBtnReset = GUICtrlCreateLabel(ChrW(0x21BA) & " " & _i18n("General.btn_reset", "Reset"), $iBtnX + $iBtnW + $iGap, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnReset, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnReset, 0xCC6666)
    GUICtrlSetBkColor($__g_CD_idBtnReset, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnReset, 0)

    $__g_CD_idBtnClose = GUICtrlCreateLabel(ChrW(0x2715) & " " & _i18n("General.btn_close", "Close"), $iBtnX + ($iBtnW + $iGap) * 2, $iRow2Y, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnClose, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnClose, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnClose, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnClose, 0)

    ; Search box (chrome) + results panel (overlay), created last so they draw on top
    __CD_BuildSearchUI()

    ; Load config values into controls
    __CD_PopulateControls()

    ; Harvest the searchable registry now that every control + tooltip exists
    __CD_BuildSearchIndex()

    ; Show first tab
    __CD_SwitchTab(1)

    ; Create GDI brush for combo dropdown theming
    Local $aBrush = DllCall("gdi32.dll", "handle", "CreateSolidBrush", "dword", $THEME_BG_INPUT)
    If Not @error And IsArray($aBrush) Then $__g_CD_hBrushCombo = $aBrush[0]
    GUIRegisterMsg(0x0134, "__CD_WM_CTLCOLORLISTBOX") ; WM_CTLCOLORLISTBOX
    ; NOTE: WM_CTLCOLORSTATIC (0x0138) intentionally NOT registered here.
    ; Registering it breaks runtime GUICtrlSetBkColor on ALL label controls
    ; (AutoIt returns stale brushes via $GUI_RUNDEFMSG), which kills button/tab hover.
    ; The combo face is already themed via GUICtrlSetColor/BkColor at creation.

    _Theme_FadeIn($__g_CD_hGUI, $THEME_ALPHA_DIALOG, "dialog")
    $__g_CD_bVisible = True

    ; Blocking loop
    __CD_MessageLoop()
EndFunc

Func _CD_Destroy()
    _Log_Info("Settings dialog closed")
    ; Restore system highlight colors if dropdown was open
    If $__g_CD_bDropdownOpen Then
        Local $aElems = DllStructCreate("int[2]")
        Local $aColors = DllStructCreate("dword[2]")
        DllStructSetData($aElems, 1, 13, 1)
        DllStructSetData($aElems, 1, 14, 2)
        DllStructSetData($aColors, 1, $__g_CD_iSavedHighlight, 1)
        DllStructSetData($aColors, 1, $__g_CD_iSavedHighlightText, 2)
        DllCall("user32.dll", "bool", "SetSysColors", "int", 2, "struct*", $aElems, "struct*", $aColors)
        $__g_CD_bDropdownOpen = False
    EndIf
    GUIRegisterMsg(0x0134, "") ; unregister WM_CTLCOLORLISTBOX
    If $__g_CD_hBrushCombo <> 0 Then
        DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $__g_CD_hBrushCombo)
        $__g_CD_hBrushCombo = 0
    EndIf
    If $__g_CD_hGUI <> 0 Then _Theme_FadeOut($__g_CD_hGUI, "dialog")
    $__g_CD_hGUI = 0
    $__g_CD_idLblLastChecked = 0
    $__g_CD_idLblNextCheck = 0
    $__g_CD_bVisible = False
    ; Reset settings-search transient state (controls are gone with the GUI)
    $__g_CD_bSearchResultsVisible = False
    $__g_CD_sSearchLast = ""
    $__g_CD_iSearchRowHovered = 0
    $__g_CD_iPulseCtrl = 0
    $__g_CD_iPulsePhase = -1
    $__g_CD_idSearchInput = 0
EndFunc

Func _CD_IsVisible()
    Return $__g_CD_bVisible
EndFunc

Func _CD_GetGUI()
    Return $__g_CD_hGUI
EndFunc

; Name:        _CD_RegisterMainCallbacks
; Description: Registers the main-loop bridge callbacks (invoked by string via Call()).
;              desktop_switcher.au3 calls this at startup after _RegisterHotkeys():
;                _CD_RegisterMainCallbacks("_UnregisterHotkeys", "_RegisterHotkeys", "_MainTick_FromDialog")
;              Until then the strings are empty and every wrapper below no-ops, which is
;              exactly what headless tests want (no live hotkey mutation, no main tick).
Func _CD_RegisterMainCallbacks($sSuspendHk, $sResumeHk, $sMainTick)
    $__g_CD_sCbHkSuspend = $sSuspendHk
    $__g_CD_sCbHkResume = $sResumeHk
    $__g_CD_sCbMainTick = $sMainTick
EndFunc

; Suspend global hotkeys (builder open). No-op until t8-c registers _UnregisterHotkeys.
Func __CD_HkSuspend()
    $__g_CD_iHkSuspendCalls += 1
    If $__g_CD_sCbHkSuspend <> "" Then Call($__g_CD_sCbHkSuspend)
EndFunc

; Resume global hotkeys (builder closed). No-op until t8-c registers _RegisterHotkeys.
Func __CD_HkResume()
    $__g_CD_iHkResumeCalls += 1
    If $__g_CD_sCbHkResume <> "" Then Call($__g_CD_sCbHkResume)
EndFunc

; =============================================
; CUSTOM TAB SWITCHING
; =============================================

; -- Nesting-safe LockWindowUpdate on the settings GUI --
; Only the outermost Begin/End pair actually toggles LockWindowUpdate, so a
; tab switch that also drives a sub-tab switch produces a single repaint
; instead of two. Every __CD_LockBegin() must be paired with __CD_LockEnd().
; Reusable by later features that batch show/hide (e.g. settings search, t1-e11).
Global $__g_CD_iLockDepth = 0
; -- Sub-tab hover tracking (single hovered sub-tab button across all groups) --
Global $__g_CD_iSubTabHovered = 0

Func __CD_LockBegin()
    If $__g_CD_iLockDepth = 0 And $__g_CD_hGUI <> 0 Then
        DllCall("user32.dll", "bool", "LockWindowUpdate", "hwnd", $__g_CD_hGUI)
    EndIf
    $__g_CD_iLockDepth += 1
EndFunc

Func __CD_LockEnd()
    If $__g_CD_iLockDepth <= 0 Then Return
    $__g_CD_iLockDepth -= 1
    If $__g_CD_iLockDepth = 0 Then
        DllCall("user32.dll", "bool", "LockWindowUpdate", "hwnd", 0)
    EndIf
EndFunc

; Name:        __CD_SubTabHoverHit
; Description: Returns the sub-tab button (from $aBtns) currently under the cursor,
;              or 0. The active sub-tab is excluded so hover never restyles it.
; Parameters:  $aBtns       - 0-based array of sub-tab button control IDs
;              $iCount      - number of valid entries in $aBtns
;              $iActiveIdx  - 0-based index of the active sub-tab (excluded)
;              $iCursorCtrl - control ID under the cursor ($aCursor[4])
Func __CD_SubTabHoverHit($aBtns, $iCount, $iActiveIdx, $iCursorCtrl)
    Local $i
    For $i = 0 To $iCount - 1
        If $aBtns[$i] = $iCursorCtrl And $i <> $iActiveIdx Then Return $aBtns[$i]
    Next
    Return 0
EndFunc

Func __CD_SwitchTab($iTab)
    _Log_Debug("Settings: switched to tab " & $iTab)
    $__g_CD_iActiveTab = $iTab

    ; Lock window to prevent repaint during bulk control state changes.
    ; Sub-tab sync runs inside the same locked span so the whole tab change
    ; repaints exactly once (was: unlocked before the sub-tab switch = double flash).
    __CD_LockBegin()

    ; Update tab button styles
    Local $t, $c
    For $t = 1 To 14
        If $t = $iTab Then
            GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_ACTIVE)
            GUICtrlSetFont($__g_CD_aidTabBtn[$t], 8, 700, 0, $THEME_FONT_MAIN)
        Else
            GUICtrlSetColor($__g_CD_aidTabBtn[$t], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_CD_aidTabBtn[$t], $THEME_BG_MAIN)
            GUICtrlSetFont($__g_CD_aidTabBtn[$t], 8, 400, 0, $THEME_FONT_MAIN)
        EndIf
    Next
    ; Hide all inactive tab controls first, then show the active tab's controls
    For $t = 1 To 14
        If $t <> $iTab Then
            For $c = 0 To $__g_CD_aiTabCtrlCount[$t] - 1
                GUICtrlSetState($__g_CD_aidTabCtrls[$t][$c], $GUI_HIDE)
            Next
        EndIf
    Next
    For $c = 0 To $__g_CD_aiTabCtrlCount[$iTab] - 1
        GUICtrlSetState($__g_CD_aidTabCtrls[$iTab][$c], $GUI_SHOW)
    Next

    ; For tabs with sub-tabs, apply sub-tab visibility (still inside the lock —
    ; these functions nest __CD_LockBegin/End harmlessly via the depth counter)
    If $iTab = 1 Then __CD_SwitchGenSub($__g_CD_iGenActiveSub)
    If $iTab = 2 Then __CD_SwitchDispSub($__g_CD_iDispActiveSub)
    If $iTab = 3 Then __CD_SwitchHkSub($__g_CD_iHkActiveSub)
    If $iTab = 4 Then __CD_SwitchBhvSub($__g_CD_iBhvActiveSub)
    If $iTab = 7 Then __CD_SwitchDeskPage($__g_CD_iDeskPage)

    ; Unlock — triggers a single repaint with all changes (tab + sub-tab) applied
    __CD_LockEnd()
EndFunc

Func __CD_RegCtrl($iTab, $idCtrl)
    If $idCtrl = 0 Then Return ; skip failed control creation
    Local $c = $__g_CD_aiTabCtrlCount[$iTab]
    If $c >= $__g_CD_MAX_CTRLS Then Return ; prevent array overflow
    $__g_CD_aidTabCtrls[$iTab][$c] = $idCtrl
    ; Capture original position and dimensions immediately (controls exist when registered)
    Local $aPos = ControlGetPos($__g_CD_hGUI, "", $idCtrl)
    If Not @error And IsArray($aPos) Then
        $__g_CD_aiTabCtrlX[$iTab][$c] = $aPos[0]
        $__g_CD_aiTabCtrlY[$iTab][$c] = $aPos[1]
        $__g_CD_aiTabCtrlW[$iTab][$c] = $aPos[2]
        $__g_CD_aiTabCtrlH[$iTab][$c] = $aPos[3]
        $__g_CD_abTabYInit[$iTab] = True
    EndIf
    $__g_CD_aiTabCtrlCount[$iTab] = $c + 1
EndFunc

; Name:        __CD_EnsureYInit
; Description: No-op (scroll system removed, sub-tabs used instead)
Func __CD_EnsureYInit($iTab)
    #forceref $iTab
    Return
EndFunc

; Name:        __CD_GetTabMaxScroll
; Description: No-op (scroll system removed, sub-tabs used instead)
Func __CD_GetTabMaxScroll($iTab)
    #forceref $iTab
    Return 0
EndFunc

; Name:        __CD_UpdateScrollIndicators
; Description: No-op (scroll system removed, sub-tabs used instead)
Func __CD_UpdateScrollIndicators()
    Return
EndFunc

; Name:        __CD_ScrollTab
; Description: No-op (scroll system removed, sub-tabs used instead)
Func __CD_ScrollTab($iDelta)
    #forceref $iDelta
    Return
EndFunc

; =============================================
; LABEL-BASED CHECKBOX (single label per checkbox)
; =============================================

Func __CD_CreateCheckbox($sText, $iX, $iY, $iW, $iTab)
    $__g_CD_iChkCount += 1
    Local $idx = $__g_CD_iChkCount
    Local $id = GUICtrlCreateLabel("  [ ]  " & $sText, $iX, $iY, $iW, 22, _
        BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($id, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($id, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($id, 0)
    __CD_RegCtrl($iTab, $id)
    $__g_CD_aChkIDs[$idx] = $id
    $__g_CD_aChkStates[$idx] = False
    $__g_CD_aChkTexts[$idx] = $sText
    Return $id
EndFunc

Func __CD_SetCheckState($id, $bChecked)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $id Then
            $__g_CD_aChkStates[$i] = $bChecked
            If $bChecked Then
                GUICtrlSetData($id, "  [x]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($id, $THEME_FG_WHITE)
            Else
                GUICtrlSetData($id, "  [ ]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($id, $THEME_FG_PRIMARY)
            EndIf
            Return
        EndIf
    Next
EndFunc

Func __CD_GetCheckState($id)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $id Then Return $__g_CD_aChkStates[$i]
    Next
    Return False
EndFunc

Func __CD_HandleCheckboxClick($msg)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $msg Then
            $__g_CD_aChkStates[$i] = Not $__g_CD_aChkStates[$i]
            If $__g_CD_aChkStates[$i] Then
                GUICtrlSetData($msg, "  [x]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($msg, $THEME_FG_WHITE)
            Else
                GUICtrlSetData($msg, "  [ ]  " & $__g_CD_aChkTexts[$i])
                GUICtrlSetColor($msg, $THEME_FG_PRIMARY)
            EndIf
            Return True
        EndIf
    Next
    Return False
EndFunc

; =============================================
; CUSTOM CYCLING LABEL (replaces combo box)
; =============================================

Func __CD_CreateCycleLabel($sLabel, $iX, $iY, $iLblW, $iValW, $iTab)
    Local $idLbl = GUICtrlCreateLabel($sLabel, $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($iTab, $idLbl)

    Local $idVal = GUICtrlCreateLabel("", $iX + $iLblW, $iY, $iValW, 22, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idVal, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idVal, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idVal, $THEME_BG_INPUT)
    GUICtrlSetCursor($idVal, 0)
    __CD_RegCtrl($iTab, $idVal)

    Return $idVal
EndFunc

Func __CD_CycleValue($id, $sOptions)
    Local $aCur = GUICtrlRead($id)
    Local $aOpts = StringSplit($sOptions, "|")
    Local $i
    For $i = 1 To $aOpts[0]
        If $aOpts[$i] = $aCur Then
            Local $iNext = Mod($i, $aOpts[0]) + 1
            GUICtrlSetData($id, $aOpts[$iNext])
            Return
        EndIf
    Next
    GUICtrlSetData($id, $aOpts[1])
EndFunc

Func __CD_GetOptionKey($sValue)
    Local $sKey = StringLower($sValue)
    $sKey = StringReplace($sKey, "-", "_")
    $sKey = StringReplace($sKey, " ", "_")
    Return $sKey
EndFunc

Func __CD_LocalizeOptionValue($sKeyBase, $sValue)
    Return _i18n($sKeyBase & "_" & __CD_GetOptionKey($sValue), $sValue)
EndFunc

Func __CD_LocalizeOptionList($sKeyBase, $sOptions)
    Local $aOpts = StringSplit($sOptions, "|")
    Local $sLocalized = ""
    Local $i
    For $i = 1 To $aOpts[0]
        If $sLocalized <> "" Then $sLocalized &= "|"
        $sLocalized &= __CD_LocalizeOptionValue($sKeyBase, $aOpts[$i])
    Next
    Return $sLocalized
EndFunc

Func __CD_DelocalizeOptionValue($sKeyBase, $sOptions, $sDisplay)
    Local $aOpts = StringSplit($sOptions, "|")
    Local $i
    For $i = 1 To $aOpts[0]
        If __CD_LocalizeOptionValue($sKeyBase, $aOpts[$i]) = $sDisplay Then Return $aOpts[$i]
    Next
    Return $sDisplay
EndFunc

Func __CD_SetLocalizedOptions($id, $sKeyBase, $sOptions, $sSelectedValue)
    GUICtrlSetData($id, __CD_LocalizeOptionList($sKeyBase, $sOptions), __CD_LocalizeOptionValue($sKeyBase, $sSelectedValue))
EndFunc

Func __CD_CycleLocalizedValue($id, $sKeyBase, $sOptions)
    Local $sCurrent = __CD_DelocalizeOptionValue($sKeyBase, $sOptions, GUICtrlRead($id))
    Local $aOpts = StringSplit($sOptions, "|")
    Local $i
    For $i = 1 To $aOpts[0]
        If $aOpts[$i] = $sCurrent Then
            Local $iNext = Mod($i, $aOpts[0]) + 1
            GUICtrlSetData($id, __CD_LocalizeOptionValue($sKeyBase, $aOpts[$iNext]))
            Return
        EndIf
    Next
    GUICtrlSetData($id, __CD_LocalizeOptionValue($sKeyBase, $aOpts[1]))
EndFunc

Func __CD_GetHotkeyModifierLabel($sKey, $sDefault, $bChecked)
    Return "  [" & ($bChecked ? "x" : " ") & "]  " & _i18n($sKey, $sDefault)
EndFunc

Func __CD_GetMainTabLabel($iTab)
    Switch $iTab
        Case 1
            Return _i18n("Tabs.tab_general", "General")
        Case 2
            Return _i18n("Tabs.tab_display", "Display")
        Case 3
            Return _i18n("Tabs.tab_hotkeys", "Hotkeys")
        Case 4
            Return _i18n("Tabs.tab_behavior", "Behavior")
        Case 5
            Return _i18n("Tabs.tab_logging", "Logging")
        Case 6
            Return _i18n("Tabs.tab_updates", "Updates")
        Case 7
            Return _i18n("Tabs.tab_desktops", "Desktops")
        Case 8
            Return _i18n("Tabs.tab_animations", "Animations")
        Case 9
            Return _i18n("Extra.tab_osd", "OSD")
        Case 10
            Return _i18n("Tabs.tab_window_list", "Window List")
        Case 11
            Return _i18n("Tabs.tab_explorer", "Explorer")
        Case 12
            Return _i18n("Tabs.tab_notifications", "Notifications")
        Case 13
            Return _i18n("Extra.tab_taskbar", "Taskbar")
        Case 14
            Return _i18n("Tabs.tab_tray", "Tray")
    EndSwitch
    Return ""
EndFunc

; =============================================
; TAB BUILDERS
; =============================================

Func __CD_BuildTabGeneral()
    Local $t = 1, $iX = 20, $iY = 94
    Local $idLbl, $iContentStartY

    ; Reset sub-tab tracking
    $__g_CD_iGenWidgetCount = 0
    $__g_CD_iGenDesktopCount = 0
    $__g_CD_iGenSystemCount = 0
    $__g_CD_iGenScrollCount = 0
    $__g_CD_iGenActiveSub = 1

    ; Sub-tab buttons
    Local $iSubY = $iY
    Local $iSubBtnW = 80
    Local $iSubGap = 4

    $__g_CD_idGenSubWidget = GUICtrlCreateLabel(_i18n("Options.sub_general_widget", "Widget"), $iX, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idGenSubWidget, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idGenSubWidget, $THEME_FG_WHITE)
    GUICtrlSetBkColor($__g_CD_idGenSubWidget, $THEME_BG_ACTIVE)
    GUICtrlSetCursor($__g_CD_idGenSubWidget, 0)
    __CD_RegCtrl($t, $__g_CD_idGenSubWidget)

    $__g_CD_idGenSubDesktop = GUICtrlCreateLabel(_i18n("Options.sub_general_desktop", "Desktop"), $iX + $iSubBtnW + $iSubGap, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idGenSubDesktop, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idGenSubDesktop, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idGenSubDesktop, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idGenSubDesktop, 0)
    __CD_RegCtrl($t, $__g_CD_idGenSubDesktop)

    $__g_CD_idGenSubSystem = GUICtrlCreateLabel(_i18n("Options.sub_general_system", "System"), $iX + ($iSubBtnW + $iSubGap) * 2, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idGenSubSystem, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idGenSubSystem, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idGenSubSystem, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idGenSubSystem, 0)
    __CD_RegCtrl($t, $__g_CD_idGenSubSystem)

    $__g_CD_idGenSubScroll = GUICtrlCreateLabel(_i18n("Options.sub_general_scroll", "Scroll"), $iX + ($iSubBtnW + $iSubGap) * 3, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idGenSubScroll, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idGenSubScroll, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idGenSubScroll, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idGenSubScroll, 0)
    __CD_RegCtrl($t, $__g_CD_idGenSubScroll)

    $iY += 30 ; space below sub-tabs
    $iContentStartY = $iY

    ; ========================================
    ; Sub-tab 1: Widget
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idLblPosition = __CD_CreateCycleLabel(_i18n("Settings.General.lbl_widget_anchor", "Widget anchor:"), $iX, $iY, 165, 110, $t)
    _Theme_SetTooltip($__g_CD_idLblPosition, _i18n("Settings.General.tip_widget_anchor", "Click to cycle screen anchor position"))
    ; Cycle label creates 2 controls: text label (id-1) + value label (id). Register both.
    __CD_RegGenSub(1, $__g_CD_idLblPosition - 1)
    __CD_RegGenSub(1, $__g_CD_idLblPosition)
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_widget_offset_x", "Widget X offset (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idInpOffsetX = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22)
    GUICtrlSetFont($__g_CD_idInpOffsetX, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOffsetX, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOffsetX, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOffsetX)
    __CD_RegCtrl($t, $__g_CD_idInpOffsetX)
    __CD_RegGenSub(1, $__g_CD_idInpOffsetX)
    _Theme_SetTooltip($__g_CD_idInpOffsetX, _i18n("Settings.General.tip_widget_offset", "Fine-tune widget position in pixels"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_widget_offset_y", "Widget Y offset (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idInpOffsetY = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22)
    GUICtrlSetFont($__g_CD_idInpOffsetY, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOffsetY, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOffsetY, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOffsetY)
    __CD_RegCtrl($t, $__g_CD_idInpOffsetY)
    __CD_RegGenSub(1, $__g_CD_idInpOffsetY)
    _Theme_SetTooltip($__g_CD_idInpOffsetY, _i18n("Settings.General.tip_widget_offset", "Fine-tune widget position in pixels"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_widget_width", "Widget width (0=auto):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idInpWidgetWidth = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWidgetWidth, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWidgetWidth, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWidgetWidth, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWidgetWidth)
    __CD_RegCtrl($t, $__g_CD_idInpWidgetWidth)
    __CD_RegGenSub(1, $__g_CD_idInpWidgetWidth)
    _Theme_SetTooltip($__g_CD_idInpWidgetWidth, _i18n("Settings.General.tip_widget_width", "Widget width in pixels (0 = automatic)"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_widget_height", "Widget height (0=auto):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idInpWidgetHeight = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWidgetHeight, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWidgetHeight, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWidgetHeight, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWidgetHeight)
    __CD_RegCtrl($t, $__g_CD_idInpWidgetHeight)
    __CD_RegGenSub(1, $__g_CD_idInpWidgetHeight)
    _Theme_SetTooltip($__g_CD_idInpWidgetHeight, _i18n("Settings.General.tip_widget_height", "Widget height in pixels (0 = automatic)"))
    $iY += 34

    $__g_CD_idChkWidgetDrag = __CD_CreateCheckbox(_i18n("Settings.General.chk_widget_drag", "Enable widget drag"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWidgetDrag, _i18n("Settings.General.tip_widget_drag", "Hold and drag the widget to reposition it on the taskbar"))
    __CD_RegGenSub(1, $__g_CD_idChkWidgetDrag)
    $iY += 26
    $__g_CD_idChkWidgetColorBar = __CD_CreateCheckbox(_i18n("Settings.General.chk_color_bar", "Widget color bar"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWidgetColorBar, _i18n("Settings.General.tip_color_bar", "Show a colored accent on the widget matching the current desktop color"))
    __CD_RegGenSub(1, $__g_CD_idChkWidgetColorBar)
    $iY += 26

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_color_bar_height", "Color bar height (px):"), $iX + 20, $iY + 2, 145, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idInpColorBarH = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpColorBarH, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpColorBarH, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpColorBarH, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpColorBarH)
    __CD_RegCtrl($t, $__g_CD_idInpColorBarH)
    __CD_RegGenSub(1, $__g_CD_idInpColorBarH)
    _Theme_SetTooltip($__g_CD_idInpColorBarH, _i18n("Settings.General.tip_color_bar_height", "Height of the widget color bar in pixels (1-10)"))
    $iY += 34

    ; Color bar animation (mode + duration), indented under the color-bar rows
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_color_bar_anim", "Color bar animation:"), $iX + 20, $iY + 2, 145, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idCmbColorBarAnim = GUICtrlCreateCombo("", $iX + 170, $iY, 110, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idCmbColorBarAnim, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idCmbColorBarAnim, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idCmbColorBarAnim, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idCmbColorBarAnim, 0)
    __CD_RegCtrl($t, $__g_CD_idCmbColorBarAnim)
    __CD_RegGenSub(1, $__g_CD_idCmbColorBarAnim)
    _Theme_SetTooltip($__g_CD_idCmbColorBarAnim, _i18n("Settings.General.tip_color_bar_anim", "How the color bar transitions when the desktop changes (none, grow, or fade)"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_color_bar_anim_duration", "Color bar anim duration (ms):"), $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(1, $idLbl)
    $__g_CD_idInpColorBarAnimDur = GUICtrlCreateInput("", $iX + 190, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpColorBarAnimDur, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpColorBarAnimDur, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpColorBarAnimDur, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpColorBarAnimDur)
    __CD_RegCtrl($t, $__g_CD_idInpColorBarAnimDur)
    __CD_RegGenSub(1, $__g_CD_idInpColorBarAnimDur)
    _Theme_SetTooltip($__g_CD_idInpColorBarAnimDur, _i18n("Settings.General.tip_color_bar_anim_duration", "How long the color bar grow/fade animation takes (50-2000ms)"))
    $iY += 34

    $__g_CD_idChkTrayMode = __CD_CreateCheckbox(_i18n("Settings.General.chk_tray_mode", "Tray icon mode"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayMode, _i18n("Settings.General.tip_tray_mode", "Run as system tray icon instead of taskbar widget (requires restart)"))
    __CD_RegGenSub(1, $__g_CD_idChkTrayMode)
    $iY += 26
    $__g_CD_idChkQuickAccess = __CD_CreateCheckbox(_i18n("Settings.General.chk_quick_access", "Quick-access number input"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkQuickAccess, _i18n("Settings.General.tip_quick_access", "Double-click the number to type a desktop number (1-9) to jump to"))
    __CD_RegGenSub(1, $__g_CD_idChkQuickAccess)
    $iY += 26
    $__g_CD_idChkListKeyNav = __CD_CreateCheckbox(_i18n("Settings.General.chk_list_key_nav", "Keyboard nav in list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListKeyNav, _i18n("Settings.General.tip_list_key_nav", "Use Up/Down arrow keys to navigate when the desktop list is open"))
    __CD_RegGenSub(1, $__g_CD_idChkListKeyNav)

    ; ========================================
    ; Sub-tab 2: Desktop
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkWrapNav = __CD_CreateCheckbox(_i18n("Settings.General.chk_wrap_nav", "Wrap navigation at ends"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWrapNav, _i18n("Settings.General.tip_wrap_nav", "Left arrow on first desktop goes to last, and vice versa"))
    __CD_RegGenSub(2, $__g_CD_idChkWrapNav)
    $iY += 26
    $__g_CD_idChkAutoCreate = __CD_CreateCheckbox(_i18n("Settings.General.chk_auto_create", "Auto-create desktop past end"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoCreate, _i18n("Settings.General.tip_auto_create", "Right arrow on last desktop creates a new one"))
    __CD_RegGenSub(2, $__g_CD_idChkAutoCreate)
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_padding", "Number padding (1-4):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegGenSub(2, $idLbl)
    $__g_CD_idInpPadding = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpPadding, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpPadding, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpPadding, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpPadding)
    __CD_RegCtrl($t, $__g_CD_idInpPadding)
    __CD_RegGenSub(2, $__g_CD_idInpPadding)
    _Theme_SetTooltip($__g_CD_idInpPadding, _i18n("Settings.General.tip_padding", "Zero-pad desktop numbers (2 = '01', 3 = '001')"))
    $iY += 34

    Local $idMinLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_min_desktops", "Min desktops on startup (0-20):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idMinLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idMinLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idMinLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idMinLbl)
    __CD_RegGenSub(2, $idMinLbl)
    $__g_CD_idInpMinDesktops = GUICtrlCreateInput("", $iX + 205, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMinDesktops, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMinDesktops, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMinDesktops, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpMinDesktops)
    __CD_RegCtrl($t, $__g_CD_idInpMinDesktops)
    __CD_RegGenSub(2, $__g_CD_idInpMinDesktops)
    _Theme_SetTooltip($__g_CD_idInpMinDesktops, _i18n("Settings.General.tip_min_desktops", "Ensure at least this many desktops exist on startup"))
    $iY += 30

    Local $idMaxLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_max_desktops", "Max desktops (0=unlimited):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idMaxLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idMaxLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idMaxLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idMaxLbl)
    __CD_RegGenSub(2, $idMaxLbl)
    $__g_CD_idInpMaxDesktops = GUICtrlCreateInput("", $iX + 205, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMaxDesktops, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMaxDesktops, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMaxDesktops, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpMaxDesktops)
    __CD_RegCtrl($t, $__g_CD_idInpMaxDesktops)
    __CD_RegGenSub(2, $__g_CD_idInpMaxDesktops)
    _Theme_SetTooltip($__g_CD_idInpMaxDesktops, _i18n("Settings.General.tip_max_desktops", "Maximum number of desktops allowed (0 = unlimited)"))

    ; ========================================
    ; Sub-tab 3: System
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkStartWin = __CD_CreateCheckbox(_i18n("Settings.General.chk_start_windows", "Start with Windows"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkStartWin, _i18n("Settings.General.tip_start_windows", "Launch Desk Switcheroo automatically when you log in"))
    __CD_RegGenSub(3, $__g_CD_idChkStartWin)
    $iY += 26
    $__g_CD_idChkSingleton = __CD_CreateCheckbox(_i18n("Settings.General.chk_singleton", "Single instance mode"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkSingleton, _i18n("Settings.General.tip_singleton", "Kill previous instance when relaunching"))
    __CD_RegGenSub(3, $__g_CD_idChkSingleton)
    $iY += 34

    Local $idLangLbl = GUICtrlCreateLabel(_i18n("Settings.General.lbl_language", "Language:"), $iX, $iY + 2, 80, 18)
    GUICtrlSetFont($idLangLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLangLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLangLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLangLbl)
    __CD_RegGenSub(3, $idLangLbl)
    $__g_CD_idLblLanguage = GUICtrlCreateCombo("", $iX + 85, $iY, 310, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblLanguage, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idLblLanguage, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblLanguage, $THEME_BG_INPUT)
    __CD_RegCtrl($t, $__g_CD_idLblLanguage)
    __CD_RegGenSub(3, $__g_CD_idLblLanguage)
    ; Themed overlay for combo face (WM_CTLCOLORSTATIC can't be used without breaking hover)
    $__g_CD_idComboOverlay = GUICtrlCreateLabel("", $iX + 85, $iY, 310, 22, BitOR($SS_LEFT, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idComboOverlay, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idComboOverlay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idComboOverlay, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idComboOverlay, 0)
    __CD_RegCtrl($t, $__g_CD_idComboOverlay)
    __CD_RegGenSub(3, $__g_CD_idComboOverlay)
    _Theme_SetTooltip($__g_CD_idComboOverlay, _i18n("Settings.General.tip_language", "Select a language (requires restart)"))
    $iY += 34

    $__g_CD_idChkTaskbarFocus = __CD_CreateCheckbox(_i18n("Settings.General.chk_taskbar_focus", "Focus taskbar before switch"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTaskbarFocus, _i18n("Settings.General.tip_taskbar_focus", "Set focus to the taskbar before switching desktops (workaround for focus issues)"))
    __CD_RegGenSub(3, $__g_CD_idChkTaskbarFocus)
    $iY += 26
    $__g_CD_idChkAutoFocus = __CD_CreateCheckbox(_i18n("Settings.General.chk_auto_focus", "Auto-focus after switch"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoFocus, _i18n("Settings.General.tip_auto_focus", "Automatically focus the foreground window after switching desktops"))
    __CD_RegGenSub(3, $__g_CD_idChkAutoFocus)
    $iY += 26
    $__g_CD_idChkStartMinimized = __CD_CreateCheckbox(_i18n("Settings.General.chk_start_minimized", "Start minimized"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkStartMinimized, _i18n("Settings.General.tip_start_minimized", "Start the application minimized (hidden) on launch"))
    __CD_RegGenSub(3, $__g_CD_idChkStartMinimized)
    $iY += 26
    $__g_CD_idChkDisableWinWidgets = __CD_CreateCheckbox(_i18n("Settings.General.chk_disable_widgets", "Disable Windows widgets"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkDisableWinWidgets, _i18n("Settings.General.tip_disable_widgets", "Hide the Windows 11 Widgets button from the taskbar to free up space"))
    __CD_RegGenSub(3, $__g_CD_idChkDisableWinWidgets)

    ; ========================================
    ; Sub-tab 4: Scroll
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkScroll = __CD_CreateCheckbox(_i18n("Settings.Scroll.chk_scroll_enabled", "Scroll wheel on widget"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkScroll, _i18n("Settings.Scroll.tip_scroll_enabled", "Use mouse wheel on the widget to cycle desktops"))
    __CD_RegGenSub(4, $__g_CD_idChkScroll)
    $iY += 26
    $__g_CD_idLblScrollDir = __CD_CreateCycleLabel(_i18n("Settings.Scroll.lbl_scroll_dir", "Direction:"), $iX + 20, $iY, 145, 90, $t)
    _Theme_SetTooltip($__g_CD_idLblScrollDir, _i18n("Settings.Scroll.tip_scroll_dir", "Click to toggle: normal or inverted scroll direction"))
    __CD_RegGenSub(4, $__g_CD_idLblScrollDir - 1)
    __CD_RegGenSub(4, $__g_CD_idLblScrollDir)
    $iY += 26
    $__g_CD_idChkScrollWrap = __CD_CreateCheckbox(_i18n("Settings.Scroll.chk_scroll_wrap", "Wrap at ends"), $iX + 20, $iY, 280, $t)
    _Theme_SetTooltip($__g_CD_idChkScrollWrap, _i18n("Settings.Scroll.tip_scroll_wrap", "Scroll past last desktop wraps to first"))
    __CD_RegGenSub(4, $__g_CD_idChkScrollWrap)
    $iY += 34
    $__g_CD_idChkListScroll = __CD_CreateCheckbox(_i18n("Settings.Scroll.chk_list_scroll", "Scroll on desktop list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListScroll, _i18n("Settings.Scroll.tip_list_scroll", "Use mouse wheel on the desktop list panel"))
    __CD_RegGenSub(4, $__g_CD_idChkListScroll)
    $iY += 26
    Local $idLblLA = GUICtrlCreateLabel(_i18n("Settings.Scroll.lbl_list_scroll_action", "List action:"), $iX + 20, $iY + 2, 145, 18)
    GUICtrlSetFont($idLblLA, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblLA, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblLA, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblLA)
    __CD_RegGenSub(4, $idLblLA)
    $__g_CD_idLblListAction = GUICtrlCreateCombo("", $iX + 20 + 145, $iY, 90, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblListAction, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblListAction, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblListAction, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblListAction, 0)
    __CD_RegCtrl($t, $__g_CD_idLblListAction)
    __CD_RegGenSub(4, $__g_CD_idLblListAction)
    _Theme_SetTooltip($__g_CD_idLblListAction, _i18n("Settings.Scroll.tip_list_scroll_action", "Select action: 'switch' changes desktops, 'scroll' scrolls the list"))

    ; Apply initial sub-tab visibility
    __CD_SwitchGenSub(1)
EndFunc

Func __CD_BuildTabDisplay()
    Local $t = 2, $iX = 20, $iY = 94
    Local $idLbl, $iContentStartY

    ; Reset sub-tab tracking
    $__g_CD_iDispAppearanceCount = 0
    $__g_CD_iDispThumbnailsCount = 0
    $__g_CD_iDispActiveSub = 1

    ; Sub-tab buttons
    Local $iSubY = $iY
    Local $iSubBtnW = 90
    Local $iSubGap = 4

    $__g_CD_idDispSubAppearance = GUICtrlCreateLabel(_i18n("Options.sub_display_appearance", "Appearance"), $iX, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idDispSubAppearance, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idDispSubAppearance, $THEME_FG_WHITE)
    GUICtrlSetBkColor($__g_CD_idDispSubAppearance, $THEME_BG_ACTIVE)
    GUICtrlSetCursor($__g_CD_idDispSubAppearance, 0)
    __CD_RegCtrl($t, $__g_CD_idDispSubAppearance)

    $__g_CD_idDispSubThumbnails = GUICtrlCreateLabel(_i18n("Options.sub_display_thumbnails", "Thumbnails"), $iX + $iSubBtnW + $iSubGap, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idDispSubThumbnails, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idDispSubThumbnails, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idDispSubThumbnails, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idDispSubThumbnails, 0)
    __CD_RegCtrl($t, $__g_CD_idDispSubThumbnails)

    $iY += 30 ; space below sub-tabs
    $iContentStartY = $iY

    ; ========================================
    ; Sub-tab 1: Appearance
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkShowCount = __CD_CreateCheckbox(_i18n("Settings.Display.chk_show_count", "Show desktop count (2/5)"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkShowCount, _i18n("Settings.Display.tip_show_count", "Show total count next to current number (e.g. '2/5')"))
    __CD_RegDispSub(1, $__g_CD_idChkShowCount)
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_count_font", "Count font size:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpCountFont = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCountFont, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCountFont, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCountFont, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpCountFont)
    __CD_RegCtrl($t, $__g_CD_idInpCountFont)
    __CD_RegDispSub(1, $__g_CD_idInpCountFont)
    _Theme_SetTooltip($__g_CD_idInpCountFont, _i18n("Settings.Display.tip_count_font", "Font size for the desktop number on the widget"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_opacity", "Widget opacity (50-255):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpOpacity = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOpacity, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOpacity, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOpacity, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOpacity)
    __CD_RegCtrl($t, $__g_CD_idInpOpacity)
    __CD_RegDispSub(1, $__g_CD_idInpOpacity)
    _Theme_SetTooltip($__g_CD_idInpOpacity, _i18n("Settings.Display.tip_opacity", "Widget transparency (50 = very transparent, 255 = fully opaque)"))
    $iY += 30

    Local $idLblTheme = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_theme", "Theme:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblTheme, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblTheme, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblTheme, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblTheme)
    __CD_RegDispSub(1, $idLblTheme)
    $__g_CD_idLblTheme = GUICtrlCreateCombo("", $iX + 165, $iY, 90, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblTheme, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblTheme, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblTheme, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblTheme, 0)
    __CD_RegCtrl($t, $__g_CD_idLblTheme)
    __CD_RegDispSub(1, $__g_CD_idLblTheme)
    _Theme_SetTooltip($__g_CD_idLblTheme, _i18n("Settings.Display.tip_theme", "Select color scheme (requires restart)"))
    $iY += 26

    Local $idThemeHint = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_theme_hint", "Theme change requires restart"), $iX + 20, $iY, 250, 16)
    GUICtrlSetFont($idThemeHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idThemeHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idThemeHint, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idThemeHint)
    __CD_RegDispSub(1, $idThemeHint)
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_font", "List font name:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpListFont = GUICtrlCreateInput("", $iX + 170, $iY, 200, 22)
    GUICtrlSetFont($__g_CD_idInpListFont, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListFont, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListFont, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpListFont)
    __CD_RegCtrl($t, $__g_CD_idInpListFont)
    __CD_RegDispSub(1, $__g_CD_idInpListFont)
    _Theme_SetTooltip($__g_CD_idInpListFont, _i18n("Settings.Display.tip_list_font", "Font for desktop list items (empty = default Fira Code/Consolas)"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_font_size", "List font size (6-14):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpListFontSize = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListFontSize, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpListFontSize)
    __CD_RegCtrl($t, $__g_CD_idInpListFontSize)
    __CD_RegDispSub(1, $__g_CD_idInpListFontSize)
    _Theme_SetTooltip($__g_CD_idInpListFontSize, _i18n("Settings.Display.tip_list_font_size", "Font size for desktop list items"))
    $iY += 34

    $__g_CD_idChkDLShowNumbers = __CD_CreateCheckbox(_i18n("Settings.Display.chk_dl_numbers", "Show desktop numbers in list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkDLShowNumbers, _i18n("Settings.Display.tip_dl_numbers", "Show desktop number prefix (1, 2, 3...) in the desktop list"))
    __CD_RegDispSub(1, $__g_CD_idChkDLShowNumbers)
    $iY += 26

    $__g_CD_idChkListScrollable = __CD_CreateCheckbox(_i18n("Settings.Display.chk_list_scrollable", "Scrollable desktop list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkListScrollable, _i18n("Settings.Display.tip_list_scrollable", "Enable scrolling when many desktops (shows scroll arrows)"))
    __CD_RegDispSub(1, $__g_CD_idChkListScrollable)
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_max_visible", "Max visible items (3-30):"), $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpListMaxVisible = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListMaxVisible, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListMaxVisible, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListMaxVisible, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpListMaxVisible)
    __CD_RegCtrl($t, $__g_CD_idInpListMaxVisible)
    __CD_RegDispSub(1, $__g_CD_idInpListMaxVisible)
    _Theme_SetTooltip($__g_CD_idInpListMaxVisible, _i18n("Settings.Display.tip_list_max_visible", "Maximum items visible before scrolling activates"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_list_scroll_speed", "Scroll speed (items, 1-5):"), $iX + 20, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpListScrollSpeed = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpListScrollSpeed, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpListScrollSpeed, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpListScrollSpeed, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpListScrollSpeed)
    __CD_RegCtrl($t, $__g_CD_idInpListScrollSpeed)
    __CD_RegDispSub(1, $__g_CD_idInpListScrollSpeed)
    _Theme_SetTooltip($__g_CD_idInpListScrollSpeed, _i18n("Settings.Display.tip_list_scroll_speed", "Number of items to scroll per step"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_tooltip_font", "Tooltip font size (6-12):"), $iX, $iY + 2, 185, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(1, $idLbl)
    $__g_CD_idInpTooltipFontSize = GUICtrlCreateInput("", $iX + 190, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTooltipFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTooltipFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTooltipFontSize, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpTooltipFontSize)
    __CD_RegCtrl($t, $__g_CD_idInpTooltipFontSize)
    __CD_RegDispSub(1, $__g_CD_idInpTooltipFontSize)
    _Theme_SetTooltip($__g_CD_idInpTooltipFontSize, _i18n("Settings.Display.tip_tooltip_font", "Font size for dark-themed tooltips"))

    ; ========================================
    ; Sub-tab 2: Thumbnails
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkThumbnails = __CD_CreateCheckbox(_i18n("Settings.Display.chk_thumbnails", "Show desktop thumbnails on hover"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkThumbnails, _i18n("Settings.Display.tip_thumbnails", "Show a preview popup with window list when hovering a desktop"))
    __CD_RegDispSub(2, $__g_CD_idChkThumbnails)
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_thumb_width", "Thumbnail width (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(2, $idLbl)
    $__g_CD_idInpThumbW = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbW, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbW, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbW, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpThumbW)
    __CD_RegCtrl($t, $__g_CD_idInpThumbW)
    __CD_RegDispSub(2, $__g_CD_idInpThumbW)
    _Theme_SetTooltip($__g_CD_idInpThumbW, _i18n("Settings.Display.tip_thumb_width", "Size of the thumbnail preview popup in pixels"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_thumb_height", "Thumbnail height (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(2, $idLbl)
    $__g_CD_idInpThumbH = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbH, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbH, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbH, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpThumbH)
    __CD_RegCtrl($t, $__g_CD_idInpThumbH)
    __CD_RegDispSub(2, $__g_CD_idInpThumbH)
    _Theme_SetTooltip($__g_CD_idInpThumbH, _i18n("Settings.Display.tip_thumb_height", "Size of the thumbnail preview popup in pixels"))
    $iY += 30

    $__g_CD_idChkThumbScreenshot = __CD_CreateCheckbox(_i18n("Settings.Display.chk_thumb_screenshot", "Use real desktop screenshots"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkThumbScreenshot, _i18n("Settings.Display.tip_thumb_screenshot", "Capture actual desktop screenshots instead of text preview (briefly switches desktops)"))
    __CD_RegDispSub(2, $__g_CD_idChkThumbScreenshot)
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Display.lbl_thumb_cache_ttl", "Screenshot cache TTL (s):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegDispSub(2, $idLbl)
    $__g_CD_idInpThumbCacheTTL = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpThumbCacheTTL, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpThumbCacheTTL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpThumbCacheTTL, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpThumbCacheTTL)
    __CD_RegCtrl($t, $__g_CD_idInpThumbCacheTTL)
    __CD_RegDispSub(2, $__g_CD_idInpThumbCacheTTL)
    _Theme_SetTooltip($__g_CD_idInpThumbCacheTTL, _i18n("Settings.Display.tip_thumb_cache_ttl", "How many seconds before cached screenshots expire (5-300)"))

    ; Apply initial sub-tab visibility
    __CD_SwitchDispSub(1)
EndFunc

Func __CD_BuildTabHotkeys()
    Local $t = 3, $iX = 20, $iY = 94
    Local $iLblW = 100, $iInpW = 130, $i
    Local $idLbl, $iContentStartY

    ; Reset sub-tab tracking
    $__g_CD_iHkNavCount = 0
    $__g_CD_iHkWinCount = 0
    $__g_CD_iHkDeskCount = 0
    $__g_CD_iHkSendCount = 0
    $__g_CD_iHkActionsCount = 0
    $__g_CD_iHkBuildCount = 0
    $__g_CD_iHkActiveSub = 1

    ; Sub-tab buttons for Hotkeys
    Local $iSubY = $iY
    Local $iSubBtnW = 84
    Local $iSubGap = 4

    $__g_CD_idHkSubNav = GUICtrlCreateLabel(_i18n("Options.sub_hotkeys_navigation", "Navigation"), $iX, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idHkSubNav, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idHkSubNav, $THEME_FG_WHITE)
    GUICtrlSetBkColor($__g_CD_idHkSubNav, $THEME_BG_ACTIVE)
    GUICtrlSetCursor($__g_CD_idHkSubNav, 0)
    __CD_RegCtrl($t, $__g_CD_idHkSubNav)

    $__g_CD_idHkSubWin = GUICtrlCreateLabel(_i18n("Options.sub_hotkeys_windows", "Windows"), $iX + $iSubBtnW + $iSubGap, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idHkSubWin, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idHkSubWin, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idHkSubWin, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idHkSubWin, 0)
    __CD_RegCtrl($t, $__g_CD_idHkSubWin)

    $__g_CD_idHkSubDesk = GUICtrlCreateLabel(_i18n("Options.sub_hotkeys_desktops", "Desktops"), $iX + ($iSubBtnW + $iSubGap) * 2, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idHkSubDesk, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idHkSubDesk, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idHkSubDesk, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idHkSubDesk, 0)
    __CD_RegCtrl($t, $__g_CD_idHkSubDesk)

    $__g_CD_idHkSubSend = GUICtrlCreateLabel(_i18n("Options.sub_hotkeys_send", "Send"), $iX + ($iSubBtnW + $iSubGap) * 3, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idHkSubSend, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idHkSubSend, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idHkSubSend, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idHkSubSend, 0)
    __CD_RegCtrl($t, $__g_CD_idHkSubSend)

    $__g_CD_idHkSubActions = GUICtrlCreateLabel(_i18n("Options.sub_hotkeys_actions", "Actions"), $iX + ($iSubBtnW + $iSubGap) * 4, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idHkSubActions, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idHkSubActions, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idHkSubActions, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idHkSubActions, 0)
    __CD_RegCtrl($t, $__g_CD_idHkSubActions)

    $iY += 30 ; space below sub-tabs
    $iContentStartY = $iY

    ; ========================================
    ; Group 1: Navigation (sub-tab 1)
    ; ========================================
    $iY = $iContentStartY

    ; Enable global hotkeys checkbox
    $__g_CD_idChkHotkeysEnabled = __CD_CreateCheckbox(_i18n("Settings.Hotkeys.chk_hotkeys_enabled", "Enable global hotkeys"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkHotkeysEnabled, _i18n("Settings.Hotkeys.tip_hotkeys_enabled", "Master toggle for all keyboard shortcuts"))
    __CD_RegHkSub(1, $__g_CD_idChkHotkeysEnabled)
    $iY += 28

    ; Next (build index 0)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_next", "Next:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkNext, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkNext)
    __CD_RegCtrl($t, $__g_CD_idInpHkNext)
    __CD_RegHkSub(1, $__g_CD_idInpHkNext)
    _Theme_SetTooltip($__g_CD_idInpHkNext, _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkNext)
    $iY += 24

    ; Prev (build index 1)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_prev", "Prev:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkPrev, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkPrev)
    __CD_RegCtrl($t, $__g_CD_idInpHkPrev)
    __CD_RegHkSub(1, $__g_CD_idInpHkPrev)
    _Theme_SetTooltip($__g_CD_idInpHkPrev, _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkPrev)
    $iY += 24

    ; Toggle List (build index 11)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_toggle", "Toggle List:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkToggleList = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkToggleList, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkToggleList, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkToggleList, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkToggleList)
    __CD_RegCtrl($t, $__g_CD_idInpHkToggleList)
    __CD_RegHkSub(1, $__g_CD_idInpHkToggleList)
    _Theme_SetTooltip($__g_CD_idInpHkToggleList, _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkToggleList)
    $iY += 24

    ; Last Desktop (build index 12)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_last", "Last Desktop:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkLastDesktop = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkLastDesktop, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkLastDesktop, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkLastDesktop, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkLastDesktop)
    __CD_RegCtrl($t, $__g_CD_idInpHkLastDesktop)
    __CD_RegHkSub(1, $__g_CD_idInpHkLastDesktop)
    _Theme_SetTooltip($__g_CD_idInpHkLastDesktop, _i18n("Settings.Hotkeys.tip_hotkey_toggle_last", "Global hotkey to jump to the last-active desktop"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkLastDesktop)
    $iY += 24

    ; Open Settings (build index 20)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_settings", "Open Settings:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkOpenSettings = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkOpenSettings, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkOpenSettings, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkOpenSettings, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkOpenSettings)
    __CD_RegCtrl($t, $__g_CD_idInpHkOpenSettings)
    __CD_RegHkSub(1, $__g_CD_idInpHkOpenSettings)
    _Theme_SetTooltip($__g_CD_idInpHkOpenSettings, _i18n("Settings.Hotkeys.tip_hotkey_settings", "Global hotkey to open the settings dialog"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkOpenSettings)
    $iY += 28

    ; Add Desktop (build index 21)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_add_desktop", "Add desktop:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkAddDesktop = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkAddDesktop, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkAddDesktop, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkAddDesktop, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkAddDesktop)
    __CD_RegCtrl($t, $__g_CD_idInpHkAddDesktop)
    __CD_RegHkSub(1, $__g_CD_idInpHkAddDesktop)
    _Theme_SetTooltip($__g_CD_idInpHkAddDesktop, _i18n("Settings.Hotkeys.tip_hotkey_add_desktop", "Global hotkey to create a new virtual desktop"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkAddDesktop)
    $iY += 24

    ; Delete Desktop (build index 22)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_delete_desktop", "Delete desktop:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkDeleteDesktop = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkDeleteDesktop, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkDeleteDesktop, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkDeleteDesktop, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkDeleteDesktop)
    __CD_RegCtrl($t, $__g_CD_idInpHkDeleteDesktop)
    __CD_RegHkSub(1, $__g_CD_idInpHkDeleteDesktop)
    _Theme_SetTooltip($__g_CD_idInpHkDeleteDesktop, _i18n("Settings.Hotkeys.tip_hotkey_delete_desktop", "Global hotkey to delete the current virtual desktop"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkDeleteDesktop)
    $iY += 24

    ; Rename Desktop (build index 23)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_rename_desktop", "Rename desktop:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkRenameDesktop = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkRenameDesktop, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkRenameDesktop, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkRenameDesktop, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkRenameDesktop)
    __CD_RegCtrl($t, $__g_CD_idInpHkRenameDesktop)
    __CD_RegHkSub(1, $__g_CD_idInpHkRenameDesktop)
    _Theme_SetTooltip($__g_CD_idInpHkRenameDesktop, _i18n("Settings.Hotkeys.tip_hotkey_rename_desktop", "Global hotkey to rename the current desktop label"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkRenameDesktop)
    $iY += 28

    ; Toggle Slideshow (build index 27)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_slideshow", "Toggle slideshow:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)
    $__g_CD_idInpHkSlideshow = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkSlideshow, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkSlideshow, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkSlideshow, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkSlideshow)
    __CD_RegCtrl($t, $__g_CD_idInpHkSlideshow)
    __CD_RegHkSub(1, $__g_CD_idInpHkSlideshow)
    _Theme_SetTooltip($__g_CD_idInpHkSlideshow, _i18n("Settings.Hotkeys.tip_hotkey_slideshow", "Global hotkey to start or stop the desktop slideshow"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 1, $__g_CD_idInpHkSlideshow)
    $iY += 28

    ; Format help (Navigation)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_format_help", "^=Ctrl  !=Alt  +=Shift  #=Win  e.g. ^!{RIGHT}"), $iX, $iY, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(1, $idLbl)

    ; ========================================
    ; Group 2: Windows (sub-tab 2)
    ; ========================================
    $iY = $iContentStartY

    ; Move+Follow Next (build index 13)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_mf_next", "Move+Follow Next:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkMoveFollowNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveFollowNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveFollowNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveFollowNext, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkMoveFollowNext)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveFollowNext)
    __CD_RegHkSub(2, $__g_CD_idInpHkMoveFollowNext)
    _Theme_SetTooltip($__g_CD_idInpHkMoveFollowNext, _i18n("Settings.Hotkeys.tip_hotkey_move_follow_next", "Global hotkey to move the active window to the next desktop and follow it there"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkMoveFollowNext)
    $iY += 24

    ; Move+Follow Prev (build index 14)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_mf_prev", "Move+Follow Prev:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkMoveFollowPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveFollowPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveFollowPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveFollowPrev, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkMoveFollowPrev)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveFollowPrev)
    __CD_RegHkSub(2, $__g_CD_idInpHkMoveFollowPrev)
    _Theme_SetTooltip($__g_CD_idInpHkMoveFollowPrev, _i18n("Settings.Hotkeys.tip_hotkey_move_follow_prev", "Global hotkey to move the active window to the previous desktop and follow it there"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkMoveFollowPrev)
    $iY += 24

    ; Move to Next (build index 15)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_move_next", "Move to Next:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkMoveToNext = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveToNext, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveToNext, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveToNext, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkMoveToNext)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveToNext)
    __CD_RegHkSub(2, $__g_CD_idInpHkMoveToNext)
    _Theme_SetTooltip($__g_CD_idInpHkMoveToNext, _i18n("Settings.Hotkeys.tip_hotkey_move_next", "Global hotkey to move the active window to the next desktop (you stay on the current one)"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkMoveToNext)
    $iY += 24

    ; Move to Prev (build index 16)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_move_prev", "Move to Prev:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkMoveToPrev = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMoveToPrev, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMoveToPrev, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMoveToPrev, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkMoveToPrev)
    __CD_RegCtrl($t, $__g_CD_idInpHkMoveToPrev)
    __CD_RegHkSub(2, $__g_CD_idInpHkMoveToPrev)
    _Theme_SetTooltip($__g_CD_idInpHkMoveToPrev, _i18n("Settings.Hotkeys.tip_hotkey_move_prev", "Global hotkey to move the active window to the previous desktop (you stay on the current one)"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkMoveToPrev)
    $iY += 24

    ; Send to New (build index 17)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_send_new", "Send to New:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkSendToNew = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkSendToNew, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkSendToNew, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkSendToNew, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkSendToNew)
    __CD_RegCtrl($t, $__g_CD_idInpHkSendToNew)
    __CD_RegHkSub(2, $__g_CD_idInpHkSendToNew)
    _Theme_SetTooltip($__g_CD_idInpHkSendToNew, _i18n("Settings.Hotkeys.tip_hotkey_send_new", "Global hotkey to create a new desktop and send the active window to it"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkSendToNew)
    $iY += 24

    ; Pin Window (build index 18)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_pin", "Pin Window:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkPinWindow = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkPinWindow, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkPinWindow, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkPinWindow, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkPinWindow)
    __CD_RegCtrl($t, $__g_CD_idInpHkPinWindow)
    __CD_RegHkSub(2, $__g_CD_idInpHkPinWindow)
    _Theme_SetTooltip($__g_CD_idInpHkPinWindow, _i18n("Settings.Hotkeys.tip_hotkey_pin_window", "Global hotkey to pin or unpin the active window on all desktops"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkPinWindow)
    $iY += 24

    ; Toggle Window List (build index 19)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_wl", "Toggle WinList:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkToggleWL = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkToggleWL, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkToggleWL, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkToggleWL, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkToggleWL)
    __CD_RegCtrl($t, $__g_CD_idInpHkToggleWL)
    __CD_RegHkSub(2, $__g_CD_idInpHkToggleWL)
    _Theme_SetTooltip($__g_CD_idInpHkToggleWL, _i18n("Settings.Hotkeys.tip_hotkey_toggle_wl", "Global hotkey to open or close the window list"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkToggleWL)
    $iY += 24

    ; Close Window (build index 24)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_close_window", "Close window:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkCloseWindow = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkCloseWindow, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkCloseWindow, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkCloseWindow, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkCloseWindow)
    __CD_RegCtrl($t, $__g_CD_idInpHkCloseWindow)
    __CD_RegHkSub(2, $__g_CD_idInpHkCloseWindow)
    _Theme_SetTooltip($__g_CD_idInpHkCloseWindow, _i18n("Settings.Hotkeys.tip_hotkey_close_window", "Global hotkey to close the active window"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkCloseWindow)
    $iY += 24

    ; Minimize Window (build index 25)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_minimize_window", "Minimize window:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(2, $idLbl)
    $__g_CD_idInpHkMinimizeWindow = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkMinimizeWindow, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkMinimizeWindow, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkMinimizeWindow, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkMinimizeWindow)
    __CD_RegCtrl($t, $__g_CD_idInpHkMinimizeWindow)
    __CD_RegHkSub(2, $__g_CD_idInpHkMinimizeWindow)
    _Theme_SetTooltip($__g_CD_idInpHkMinimizeWindow, _i18n("Settings.Hotkeys.tip_hotkey_minimize_window", "Global hotkey to minimize the active window"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 2, $__g_CD_idInpHkMinimizeWindow)
    $iY += 24

    $__g_CD_idInpHkMaximizeWindow = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_maximize_window", "Maximize window:"), 2, _i18n("Settings.Hotkeys.tip_hotkey_maximize_window", "Global hotkey to maximize the active window"))
    $__g_CD_idInpHkRestoreWindow = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_restore_window", "Restore window:"), 2, _i18n("Settings.Hotkeys.tip_hotkey_restore_window", "Global hotkey to restore the active window"))
    $__g_CD_idInpHkGatherWindows = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_gather_windows", "Gather windows:"), 2, _i18n("Settings.Hotkeys.tip_hotkey_gather_windows", "Global hotkey to gather all windows to the current desktop"))

    ; ========================================
    ; Group 3: Desktops (sub-tab 3)
    ; ========================================
    $iY = $iContentStartY

    ; Desktop hotkeys (build index 2+, count from config)
    Local $iHkCount = 9 ; always render all 9 desktop-hotkey rows (registration is hardcoded 1..9)
    For $i = 1 To $iHkCount
        $idLbl = GUICtrlCreateLabel(_i18n_Format("Settings.Hotkeys.lbl_hotkey_desktop", "Desktop {1}:", $i), $iX, $iY + 2, $iLblW, 18)
        GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($idLbl, $THEME_FG_DIM)
        GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $idLbl)
        __CD_RegHkSub(3, $idLbl)
        $__g_CD_aidInpHkDesktop[$i] = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
        GUICtrlSetFont($__g_CD_aidInpHkDesktop[$i], 9, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidInpHkDesktop[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidInpHkDesktop[$i], $THEME_BG_INPUT)
        _Theme_FlattenInput($__g_CD_aidInpHkDesktop[$i])
        __CD_RegCtrl($t, $__g_CD_aidInpHkDesktop[$i])
        __CD_RegHkSub(3, $__g_CD_aidInpHkDesktop[$i])
        _Theme_SetTooltip($__g_CD_aidInpHkDesktop[$i], _i18n("Settings.Hotkeys.tip_hotkey_format", "AutoIt hotkey format: ^=Ctrl !=Alt +=Shift #=Win e.g. ^!{RIGHT}"))
        __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 3, $__g_CD_aidInpHkDesktop[$i])
        $iY += 24
    Next

    ; Task View (build index 26)
    $iY += 6 ; extra spacing before Task View
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_hotkey_task_view", "Open Task View:"), $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(3, $idLbl)
    $__g_CD_idInpHkTaskView = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($__g_CD_idInpHkTaskView, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpHkTaskView, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpHkTaskView, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpHkTaskView)
    __CD_RegCtrl($t, $__g_CD_idInpHkTaskView)
    __CD_RegHkSub(3, $__g_CD_idInpHkTaskView)
    _Theme_SetTooltip($__g_CD_idInpHkTaskView, _i18n("Settings.Hotkeys.tip_hotkey_task_view", "Global hotkey to open Windows Task View (Win+Tab)"))
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, 3, $__g_CD_idInpHkTaskView)
    $iY += 24

    ; Format help (Desktops)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_format_help", "^=Ctrl  !=Alt  +=Shift  #=Win  e.g. ^!{RIGHT}"), $iX, $iY + 4, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(3, $idLbl)

    ; ========================================
    ; Group 4: Send to Desktop (sub-tab 4)
    ; ========================================
    $iY = $iContentStartY
    For $i = 1 To 9
        $__g_CD_aidInpHkMoveToDesktop[$i] = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n_Format("Settings.Hotkeys.lbl_hotkey_move_to_desktop", "To Desktop {1}:", $i), 4, _i18n("Settings.Hotkeys.tip_hotkey_move_to_desktop", "Global hotkey to send the active window to this desktop"))
    Next

    ; Format help (Send)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_format_help", "^=Ctrl  !=Alt  +=Shift  #=Win  e.g. ^!{RIGHT}"), $iX, $iY + 4, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(4, $idLbl)

    ; ========================================
    ; Group 5: Actions (sub-tab 5)
    ; ========================================
    $iY = $iContentStartY
    $__g_CD_idInpHkToggleRules = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_toggle_rules", "Toggle rules:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_toggle_rules", "Global hotkey to toggle the window rules engine on or off"))
    $__g_CD_idInpHkToggleSession = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_toggle_session", "Toggle session:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_toggle_session", "Global hotkey to save or restore the window session"))
    $__g_CD_idInpHkToggleOsd = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_toggle_osd", "Toggle OSD:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_toggle_osd", "Global hotkey to toggle the on-screen desktop display"))
    $__g_CD_idInpHkToggleWidget = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_toggle_widget", "Toggle widget:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_toggle_widget", "Global hotkey to show or hide the widget"))
    $__g_CD_idInpHkLoadNextProfile = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_load_next_profile", "Next profile:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_load_next_profile", "Global hotkey to load the next configuration profile"))
    $__g_CD_idInpHkLoadPrevProfile = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_load_prev_profile", "Prev profile:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_load_prev_profile", "Global hotkey to load the previous configuration profile"))
    $__g_CD_idInpHkSwapDesktops = __CD_AddHkRow($iX, $iY, $iLblW, $iInpW, _i18n("Settings.Hotkeys.lbl_hotkey_swap_desktops", "Swap desktops:"), 5, _i18n("Settings.Hotkeys.tip_hotkey_swap_desktops", "Global hotkey to swap the current desktop with the next one"))

    ; Format help (Actions)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Hotkeys.lbl_format_help", "^=Ctrl  !=Alt  +=Shift  #=Win  e.g. ^!{RIGHT}"), $iX, $iY + 4, 380, 16)
    GUICtrlSetFont($idLbl, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegHkSub(5, $idLbl)

    ; Show only Navigation group by default
    __CD_SwitchHkSub(1)
EndFunc

; Name:        __CD_AddHkRow
; Description: Builds one hotkey row (label + input + "..." builder button + tooltips),
;              registers all controls to tab 3 and the given hotkey sub-tab, advances
;              $iY, and returns the input control ID.
Func __CD_AddHkRow($iX, ByRef $iY, $iLblW, $iInpW, $sLblText, $iSub, $sTipText)
    Local $idLbl = GUICtrlCreateLabel($sLblText, $iX, $iY + 2, $iLblW, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl(3, $idLbl)
    __CD_RegHkSub($iSub, $idLbl)
    Local $idInp = GUICtrlCreateInput("", $iX + $iLblW, $iY, $iInpW, 20)
    GUICtrlSetFont($idInp, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idInp, $THEME_FG_TEXT)
    GUICtrlSetBkColor($idInp, $THEME_BG_INPUT)
    _Theme_FlattenInput($idInp)
    __CD_RegCtrl(3, $idInp)
    __CD_RegHkSub($iSub, $idInp)
    _Theme_SetTooltip($idInp, $sTipText)
    __CD_AddHkBuildBtn($iX + $iLblW + $iInpW + 4, $iY, $iSub, $idInp)
    $iY += 24
    Return $idInp
EndFunc

; Name:        __CD_RegHkBuilder
; Description: Appends a ("..." button -> input) pair to the hotkey-builder registry so
;              __CD_HandleHotkeyBuildClick can dispatch the click to the right input.
Func __CD_RegHkBuilder($idBtn, $idInp)
    If $__g_CD_iHkBuildCount >= UBound($__g_CD_aHkBuildBtn) Then Return
    $__g_CD_aHkBuildBtn[$__g_CD_iHkBuildCount] = $idBtn
    $__g_CD_aHkBuildInp[$__g_CD_iHkBuildCount] = $idInp
    $__g_CD_iHkBuildCount += 1
EndFunc

; Name:        __CD_AddHkBuildBtn
; Description: Creates one styled "..." hotkey-builder button at ($iBtnX, $iY), registers
;              it to tab 3 + the given hotkey sub-tab, sets its tooltip, and records the
;              button->input mapping. Returns the button control ID.
Func __CD_AddHkBuildBtn($iBtnX, $iY, $iSub, $idInput)
    Local $idBtn = GUICtrlCreateLabel("...", $iBtnX, $iY, 24, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idBtn, 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idBtn, $THEME_FG_DIM)
    GUICtrlSetBkColor($idBtn, $THEME_BG_HOVER)
    GUICtrlSetCursor($idBtn, 0)
    __CD_RegCtrl(3, $idBtn)
    __CD_RegHkSub($iSub, $idBtn)
    _Theme_SetTooltip($idBtn, _i18n("Settings.Hotkeys.tip_hotkey_builder", "Open hotkey builder to visually create a key combination"))
    __CD_RegHkBuilder($idBtn, $idInput)
    Return $idBtn
EndFunc

; Name:        __CD_RegHkSub
; Description: Register a control ID to a hotkey sub-section for show/hide toggling
Func __CD_RegHkSub($iSub, $idCtrl)
    Switch $iSub
        Case 1
            $__g_CD_aHkNavCtrls[$__g_CD_iHkNavCount] = $idCtrl
            $__g_CD_iHkNavCount += 1
        Case 2
            $__g_CD_aHkWinCtrls[$__g_CD_iHkWinCount] = $idCtrl
            $__g_CD_iHkWinCount += 1
        Case 3
            $__g_CD_aHkDeskCtrls[$__g_CD_iHkDeskCount] = $idCtrl
            $__g_CD_iHkDeskCount += 1
        Case 4
            $__g_CD_aHkSendCtrls[$__g_CD_iHkSendCount] = $idCtrl
            $__g_CD_iHkSendCount += 1
        Case 5
            $__g_CD_aHkActionsCtrls[$__g_CD_iHkActionsCount] = $idCtrl
            $__g_CD_iHkActionsCount += 1
    EndSwitch
EndFunc

; Name:        __CD_SwitchHkSub
; Description: Switches the active hotkey sub-tab, showing/hiding control groups
Func __CD_SwitchHkSub($iSub)
    $__g_CD_iHkActiveSub = $iSub
    $__g_CD_iSubTabHovered = 0 ; this switch fully restyles every button; drop stale hover
    __CD_LockBegin()
    ; Show/hide sub-section controls
    Local $i
    For $i = 0 To $__g_CD_iHkNavCount - 1
        If $iSub = 1 Then
            GUICtrlSetState($__g_CD_aHkNavCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aHkNavCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iHkWinCount - 1
        If $iSub = 2 Then
            GUICtrlSetState($__g_CD_aHkWinCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aHkWinCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iHkDeskCount - 1
        If $iSub = 3 Then
            GUICtrlSetState($__g_CD_aHkDeskCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aHkDeskCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iHkSendCount - 1
        If $iSub = 4 Then
            GUICtrlSetState($__g_CD_aHkSendCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aHkSendCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iHkActionsCount - 1
        If $iSub = 5 Then
            GUICtrlSetState($__g_CD_aHkActionsCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aHkActionsCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    ; Update sub-tab button styles
    If $iSub = 1 Then
        GUICtrlSetColor($__g_CD_idHkSubNav, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idHkSubNav, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idHkSubNav, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idHkSubNav, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idHkSubNav, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idHkSubNav, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 2 Then
        GUICtrlSetColor($__g_CD_idHkSubWin, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idHkSubWin, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idHkSubWin, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idHkSubWin, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idHkSubWin, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idHkSubWin, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 3 Then
        GUICtrlSetColor($__g_CD_idHkSubDesk, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idHkSubDesk, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idHkSubDesk, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idHkSubDesk, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idHkSubDesk, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idHkSubDesk, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 4 Then
        GUICtrlSetColor($__g_CD_idHkSubSend, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idHkSubSend, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idHkSubSend, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idHkSubSend, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idHkSubSend, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idHkSubSend, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 5 Then
        GUICtrlSetColor($__g_CD_idHkSubActions, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idHkSubActions, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idHkSubActions, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idHkSubActions, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idHkSubActions, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idHkSubActions, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    __CD_LockEnd()
EndFunc

Func __CD_RegGenSub($iSub, $idCtrl)
    Switch $iSub
        Case 1
            $__g_CD_aGenWidgetCtrls[$__g_CD_iGenWidgetCount] = $idCtrl
            $__g_CD_iGenWidgetCount += 1
        Case 2
            $__g_CD_aGenDesktopCtrls[$__g_CD_iGenDesktopCount] = $idCtrl
            $__g_CD_iGenDesktopCount += 1
        Case 3
            $__g_CD_aGenSystemCtrls[$__g_CD_iGenSystemCount] = $idCtrl
            $__g_CD_iGenSystemCount += 1
        Case 4
            $__g_CD_aGenScrollCtrls[$__g_CD_iGenScrollCount] = $idCtrl
            $__g_CD_iGenScrollCount += 1
    EndSwitch
EndFunc

Func __CD_SwitchGenSub($iSub)
    $__g_CD_iGenActiveSub = $iSub
    $__g_CD_iSubTabHovered = 0 ; this switch fully restyles every button; drop stale hover
    __CD_LockBegin()
    Local $i
    For $i = 0 To $__g_CD_iGenWidgetCount - 1
        If $iSub = 1 Then
            GUICtrlSetState($__g_CD_aGenWidgetCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aGenWidgetCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iGenDesktopCount - 1
        If $iSub = 2 Then
            GUICtrlSetState($__g_CD_aGenDesktopCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aGenDesktopCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iGenSystemCount - 1
        If $iSub = 3 Then
            GUICtrlSetState($__g_CD_aGenSystemCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aGenSystemCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iGenScrollCount - 1
        If $iSub = 4 Then
            GUICtrlSetState($__g_CD_aGenScrollCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aGenScrollCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    ; Update sub-tab button styles
    If $iSub = 1 Then
        GUICtrlSetColor($__g_CD_idGenSubWidget, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idGenSubWidget, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idGenSubWidget, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idGenSubWidget, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idGenSubWidget, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idGenSubWidget, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 2 Then
        GUICtrlSetColor($__g_CD_idGenSubDesktop, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idGenSubDesktop, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idGenSubDesktop, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idGenSubDesktop, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idGenSubDesktop, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idGenSubDesktop, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 3 Then
        GUICtrlSetColor($__g_CD_idGenSubSystem, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idGenSubSystem, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idGenSubSystem, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idGenSubSystem, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idGenSubSystem, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idGenSubSystem, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 4 Then
        GUICtrlSetColor($__g_CD_idGenSubScroll, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idGenSubScroll, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idGenSubScroll, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idGenSubScroll, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idGenSubScroll, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idGenSubScroll, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    __CD_LockEnd()
EndFunc

Func __CD_RegDispSub($iSub, $idCtrl)
    Switch $iSub
        Case 1
            $__g_CD_aDispAppearanceCtrls[$__g_CD_iDispAppearanceCount] = $idCtrl
            $__g_CD_iDispAppearanceCount += 1
        Case 2
            $__g_CD_aDispThumbnailsCtrls[$__g_CD_iDispThumbnailsCount] = $idCtrl
            $__g_CD_iDispThumbnailsCount += 1
    EndSwitch
EndFunc

Func __CD_SwitchDispSub($iSub)
    $__g_CD_iDispActiveSub = $iSub
    $__g_CD_iSubTabHovered = 0 ; this switch fully restyles every button; drop stale hover
    __CD_LockBegin()
    Local $i
    For $i = 0 To $__g_CD_iDispAppearanceCount - 1
        If $iSub = 1 Then
            GUICtrlSetState($__g_CD_aDispAppearanceCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aDispAppearanceCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iDispThumbnailsCount - 1
        If $iSub = 2 Then
            GUICtrlSetState($__g_CD_aDispThumbnailsCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aDispThumbnailsCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    ; Update sub-tab button styles
    If $iSub = 1 Then
        GUICtrlSetColor($__g_CD_idDispSubAppearance, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idDispSubAppearance, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idDispSubAppearance, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idDispSubAppearance, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idDispSubAppearance, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idDispSubAppearance, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 2 Then
        GUICtrlSetColor($__g_CD_idDispSubThumbnails, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idDispSubThumbnails, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idDispSubThumbnails, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idDispSubThumbnails, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idDispSubThumbnails, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idDispSubThumbnails, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    __CD_LockEnd()
EndFunc

Func __CD_RegBhvSub($iSub, $idCtrl)
    Switch $iSub
        Case 1
            $__g_CD_aBhvInteractCtrls[$__g_CD_iBhvInteractCount] = $idCtrl
            $__g_CD_iBhvInteractCount += 1
        Case 2
            $__g_CD_aBhvTimersCtrls[$__g_CD_iBhvTimersCount] = $idCtrl
            $__g_CD_iBhvTimersCount += 1
        Case 3
            $__g_CD_aBhvSlideshowCtrls[$__g_CD_iBhvSlideshowCount] = $idCtrl
            $__g_CD_iBhvSlideshowCount += 1
        Case 4
            $__g_CD_aBhvRulesCtrls[$__g_CD_iBhvRulesCount] = $idCtrl
            $__g_CD_iBhvRulesCount += 1
    EndSwitch
EndFunc

Func __CD_SwitchBhvSub($iSub)
    $__g_CD_iBhvActiveSub = $iSub
    $__g_CD_iSubTabHovered = 0 ; this switch fully restyles every button; drop stale hover
    __CD_LockBegin()
    Local $i
    For $i = 0 To $__g_CD_iBhvInteractCount - 1
        If $iSub = 1 Then
            GUICtrlSetState($__g_CD_aBhvInteractCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aBhvInteractCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iBhvTimersCount - 1
        If $iSub = 2 Then
            GUICtrlSetState($__g_CD_aBhvTimersCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aBhvTimersCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iBhvSlideshowCount - 1
        If $iSub = 3 Then
            GUICtrlSetState($__g_CD_aBhvSlideshowCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aBhvSlideshowCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    For $i = 0 To $__g_CD_iBhvRulesCount - 1
        If $iSub = 4 Then
            GUICtrlSetState($__g_CD_aBhvRulesCtrls[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aBhvRulesCtrls[$i], $GUI_HIDE)
        EndIf
    Next
    ; Update sub-tab button styles
    If $iSub = 1 Then
        GUICtrlSetColor($__g_CD_idBhvSubInteract, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idBhvSubInteract, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idBhvSubInteract, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idBhvSubInteract, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idBhvSubInteract, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idBhvSubInteract, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 2 Then
        GUICtrlSetColor($__g_CD_idBhvSubTimers, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idBhvSubTimers, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idBhvSubTimers, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idBhvSubTimers, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idBhvSubTimers, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idBhvSubTimers, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 3 Then
        GUICtrlSetColor($__g_CD_idBhvSubSlideshow, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idBhvSubSlideshow, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idBhvSubSlideshow, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idBhvSubSlideshow, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idBhvSubSlideshow, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idBhvSubSlideshow, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    If $iSub = 4 Then
        GUICtrlSetColor($__g_CD_idBhvSubRules, $THEME_FG_WHITE)
        GUICtrlSetBkColor($__g_CD_idBhvSubRules, $THEME_BG_ACTIVE)
        GUICtrlSetFont($__g_CD_idBhvSubRules, 7, 700, 0, $THEME_FONT_MAIN)
    Else
        GUICtrlSetColor($__g_CD_idBhvSubRules, $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_idBhvSubRules, $THEME_BG_MAIN)
        GUICtrlSetFont($__g_CD_idBhvSubRules, 7, 400, 0, $THEME_FONT_MAIN)
    EndIf
    __CD_LockEnd()
EndFunc

Func __CD_BuildTabBehavior()
    Local $t = 4, $iX = 20, $iY = 94
    Local $idLbl, $iContentStartY

    ; Reset sub-tab tracking
    $__g_CD_iBhvInteractCount = 0
    $__g_CD_iBhvTimersCount = 0
    $__g_CD_iBhvSlideshowCount = 0
    $__g_CD_iBhvRulesCount = 0
    $__g_CD_iBhvActiveSub = 1

    ; Sub-tab buttons (4 buttons: Interaction, Timers, Slideshow, Rules)
    Local $iSubY = $iY
    Local $iSubBtnW = 80
    Local $iSubGap = 4

    $__g_CD_idBhvSubInteract = GUICtrlCreateLabel(_i18n("Settings.Behavior.sub_interaction", "Interaction"), $iX, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBhvSubInteract, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBhvSubInteract, $THEME_FG_WHITE)
    GUICtrlSetBkColor($__g_CD_idBhvSubInteract, $THEME_BG_ACTIVE)
    GUICtrlSetCursor($__g_CD_idBhvSubInteract, 0)
    __CD_RegCtrl($t, $__g_CD_idBhvSubInteract)

    $__g_CD_idBhvSubTimers = GUICtrlCreateLabel(_i18n("Settings.Behavior.sub_timers", "Timers"), $iX + $iSubBtnW + $iSubGap, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBhvSubTimers, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBhvSubTimers, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBhvSubTimers, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idBhvSubTimers, 0)
    __CD_RegCtrl($t, $__g_CD_idBhvSubTimers)

    $__g_CD_idBhvSubSlideshow = GUICtrlCreateLabel(_i18n("Settings.Behavior.sub_slideshow", "Slideshow"), $iX + ($iSubBtnW + $iSubGap) * 2, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBhvSubSlideshow, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBhvSubSlideshow, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBhvSubSlideshow, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idBhvSubSlideshow, 0)
    __CD_RegCtrl($t, $__g_CD_idBhvSubSlideshow)

    $__g_CD_idBhvSubRules = GUICtrlCreateLabel(_i18n("Settings.Behavior.sub_rules", "Rules"), $iX + ($iSubBtnW + $iSubGap) * 3, $iSubY, $iSubBtnW, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBhvSubRules, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBhvSubRules, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBhvSubRules, $THEME_BG_MAIN)
    GUICtrlSetCursor($__g_CD_idBhvSubRules, 0)
    __CD_RegCtrl($t, $__g_CD_idBhvSubRules)

    $iY += 30
    $iContentStartY = $iY

    ; ========================================
    ; Sub-tab 1: Interaction
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkConfirmDel = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_confirm_delete", "Confirm before delete"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmDel, _i18n("Settings.Behavior.tip_confirm_delete", "Show confirmation dialog before deleting a desktop"))
    __CD_RegBhvSub(1, $__g_CD_idChkConfirmDel)
    $iY += 26
    $__g_CD_idChkMidClick = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_middle_click", "Middle-click to delete"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMidClick, _i18n("Settings.Behavior.tip_middle_click", "Middle-click a desktop in the list to delete it"))
    __CD_RegBhvSub(1, $__g_CD_idChkMidClick)
    $iY += 26
    $__g_CD_idChkMoveWin = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_move_window", "Move Window Here in menu"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMoveWin, _i18n("Settings.Behavior.tip_move_window", "Show 'Move Window Here' in the desktop right-click menu"))
    __CD_RegBhvSub(1, $__g_CD_idChkMoveWin)
    $iY += 26
    $__g_CD_idChkMoveHereClick = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_move_here_click", "Click Move Here to move window"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkMoveHereClick, _i18n("Settings.Behavior.tip_move_here_click", "When enabled, clicking Move Here in the desktop list menu immediately moves the active window to that desktop (hover still opens the submenu)"))
    __CD_RegBhvSub(1, $__g_CD_idChkMoveHereClick)
    $iY += 34

    $__g_CD_idChkConfirmQuit = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_confirm_quit", "Confirm before quitting"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmQuit, _i18n("Settings.Behavior.tip_confirm_quit", "Show a confirmation dialog before exiting Desk Switcheroo"))
    __CD_RegBhvSub(1, $__g_CD_idChkConfirmQuit)
    $iY += 26
    $__g_CD_idChkConfirmRestart = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_confirm_restart", "Confirm before restarting"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfirmRestart, _i18n("Settings.Behavior.tip_confirm_restart", "Show confirmation dialog before restarting the application"))
    __CD_RegBhvSub(1, $__g_CD_idChkConfirmRestart)
    $iY += 26
    $__g_CD_idChkDebugMode = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_debug_mode", "Debug mode"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkDebugMode, _i18n("Settings.Behavior.tip_debug_mode", "Enables debug features: Trigger Crash in context menu, verbose logging"))
    __CD_RegBhvSub(1, $__g_CD_idChkDebugMode)
    $iY += 26
    $__g_CD_idChkDisableNativeOsd = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_disable_native_osd", "Disable native desktop-switch OSD"), $iX, $iY, 340, $t)
    _Theme_SetTooltip($__g_CD_idChkDisableNativeOsd, _i18n("Settings.Behavior.tip_disable_native_osd", "Suppress the Windows desktop-switch overlay when changing desktops"))
    __CD_RegBhvSub(1, $__g_CD_idChkDisableNativeOsd)
    $iY += 26
    $__g_CD_idChkPinningEnabled = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_pinning_enabled", "Enable window pinning"), $iX, $iY, 340, $t)
    _Theme_SetTooltip($__g_CD_idChkPinningEnabled, _i18n("Settings.Behavior.tip_pinning_enabled", "Allow pinning windows so they stay visible on all virtual desktops"))
    __CD_RegBhvSub(1, $__g_CD_idChkPinningEnabled)

    ; ========================================
    ; Sub-tab 2: Timers
    ; ========================================
    $iY = $iContentStartY

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_peek_delay", "Peek delay (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(2, $idLbl)
    $__g_CD_idInpPeekDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpPeekDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpPeekDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpPeekDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpPeekDelay)
    __CD_RegCtrl($t, $__g_CD_idInpPeekDelay)
    __CD_RegBhvSub(2, $__g_CD_idInpPeekDelay)
    _Theme_SetTooltip($__g_CD_idInpPeekDelay, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_auto_hide", "Auto-hide timeout (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(2, $idLbl)
    $__g_CD_idInpAutoHide = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHide, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHide, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHide, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHide)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHide)
    __CD_RegBhvSub(2, $__g_CD_idInpAutoHide)
    _Theme_SetTooltip($__g_CD_idInpAutoHide, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_topmost", "Topmost interval (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(2, $idLbl)
    $__g_CD_idInpTopmost = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTopmost, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTopmost, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTopmost, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpTopmost)
    __CD_RegCtrl($t, $__g_CD_idInpTopmost)
    __CD_RegBhvSub(2, $__g_CD_idInpTopmost)
    _Theme_SetTooltip($__g_CD_idInpTopmost, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_cm_delay", "Menu hide delay (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(2, $idLbl)
    $__g_CD_idInpCmDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCmDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCmDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCmDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpCmDelay)
    __CD_RegCtrl($t, $__g_CD_idInpCmDelay)
    __CD_RegBhvSub(2, $__g_CD_idInpCmDelay)
    _Theme_SetTooltip($__g_CD_idInpCmDelay, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 34

    $__g_CD_idChkConfigWatcher = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_config_watcher", "Config file watcher"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkConfigWatcher, _i18n("Settings.Behavior.tip_config_watcher", "Automatically reload settings when the INI file changes"))
    __CD_RegBhvSub(2, $__g_CD_idChkConfigWatcher)
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_watcher_interval", "Watcher interval (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(2, $idLbl)
    $__g_CD_idInpWatcherInterval = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWatcherInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWatcherInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWatcherInterval, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWatcherInterval)
    __CD_RegCtrl($t, $__g_CD_idInpWatcherInterval)
    __CD_RegBhvSub(2, $__g_CD_idInpWatcherInterval)
    _Theme_SetTooltip($__g_CD_idInpWatcherInterval, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_ctx_delay", "Context menu hide delay (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(2, $idLbl)
    $__g_CD_idInpCtxDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpCtxDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpCtxDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpCtxDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpCtxDelay)
    __CD_RegCtrl($t, $__g_CD_idInpCtxDelay)
    __CD_RegBhvSub(2, $__g_CD_idInpCtxDelay)
    _Theme_SetTooltip($__g_CD_idInpCtxDelay, _i18n("Settings.Behavior.tip_ms_hint", "Time in milliseconds (1000ms = 1 second)"))

    ; ========================================
    ; Sub-tab 3: Slideshow (supersedes Carousel)
    ; ========================================
    ; ~16 rows; tightened pitch (24px chk / 26px field) + 2x2 break grid keeps the pane
    ; within the single-column budget (ends ~y=528; button row starts at $iH-70).
    $iY = $iContentStartY

    $__g_CD_idChkSlideshowEnabled = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_enabled", "Enable slideshow"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowEnabled, _i18n("Settings.Behavior.tip_slideshow_enabled", "Automatically cycle through virtual desktops at a set interval"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowEnabled)
    $iY += 24

    ; Interval (ms)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_interval", "Slideshow interval (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowInterval = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpSlideshowInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpSlideshowInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowInterval, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowInterval)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowInterval)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowInterval)
    _Theme_SetTooltip($__g_CD_idInpSlideshowInterval, _i18n("Settings.Behavior.tip_slideshow_interval", "Default time between automatic desktop switches (1000-3600000ms)"))
    $iY += 26

    ; Selection mode (which desktops participate)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_selection_mode", "Desktops to include:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idCmbSlideshowSelMode = GUICtrlCreateCombo("", $iX + 180, $iY, 150, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idCmbSlideshowSelMode, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idCmbSlideshowSelMode, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idCmbSlideshowSelMode, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idCmbSlideshowSelMode, 0)
    __CD_RegCtrl($t, $__g_CD_idCmbSlideshowSelMode)
    __CD_RegBhvSub(3, $__g_CD_idCmbSlideshowSelMode)
    _Theme_SetTooltip($__g_CD_idCmbSlideshowSelMode, _i18n("Settings.Behavior.tip_slideshow_selection_mode", "Which desktops the slideshow visits: all, even-numbered, odd-numbered, those whose name matches a filter, or a custom sequence"))
    $iY += 26

    ; Direction
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_direction", "Direction:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idCmbSlideshowDirection = GUICtrlCreateCombo("", $iX + 180, $iY, 150, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idCmbSlideshowDirection, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idCmbSlideshowDirection, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idCmbSlideshowDirection, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idCmbSlideshowDirection, 0)
    __CD_RegCtrl($t, $__g_CD_idCmbSlideshowDirection)
    __CD_RegBhvSub(3, $__g_CD_idCmbSlideshowDirection)
    _Theme_SetTooltip($__g_CD_idCmbSlideshowDirection, _i18n("Settings.Behavior.tip_slideshow_direction", "Visit desktops ascending (forward) or descending (backward); reverses the custom sequence order"))
    $iY += 26

    ; Name filter (name_contains mode)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_name_filter", "Name filter:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowNameFilter = GUICtrlCreateInput("", $iX + 180, $iY, 200, 22)
    GUICtrlSetFont($__g_CD_idInpSlideshowNameFilter, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpSlideshowNameFilter, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowNameFilter, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowNameFilter)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowNameFilter)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowNameFilter)
    _Theme_SetTooltip($__g_CD_idInpSlideshowNameFilter, _i18n("Settings.Behavior.tip_slideshow_name_filter", "Case-insensitive text matched against desktop names; only used by the ""name contains"" selection mode"))
    $iY += 26

    ; Custom sequence (custom mode) — mono input like the hotkey fields
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_sequence", "Custom sequence:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowSequence = GUICtrlCreateInput("", $iX + 180, $iY, 200, 22)
    GUICtrlSetFont($__g_CD_idInpSlideshowSequence, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpSlideshowSequence, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowSequence, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowSequence)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowSequence)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowSequence)
    _Theme_SetTooltip($__g_CD_idInpSlideshowSequence, _i18n("Settings.Behavior.tip_slideshow_sequence", "Comma-separated 1-based desktop numbers to visit, e.g. 1,3,2,5; repeats allowed; only used by the ""custom"" selection mode"))
    $iY += 26

    ; Per-desktop intervals (all modes) — mono input
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_desktop_intervals", "Per-desktop intervals:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowDesktopIntervals = GUICtrlCreateInput("", $iX + 180, $iY, 200, 22)
    GUICtrlSetFont($__g_CD_idInpSlideshowDesktopIntervals, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpSlideshowDesktopIntervals, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowDesktopIntervals, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowDesktopIntervals)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowDesktopIntervals)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowDesktopIntervals)
    _Theme_SetTooltip($__g_CD_idInpSlideshowDesktopIntervals, _i18n("Settings.Behavior.tip_slideshow_desktop_intervals", "Per-desktop timing overrides as desktop:ms pairs, e.g. 1:5000,3:8000; applies in every selection mode; unlisted desktops use the default interval"))
    $iY += 26

    ; Loop mode
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_loop_mode", "Loop mode:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idCmbSlideshowLoopMode = GUICtrlCreateCombo("", $iX + 180, $iY, 150, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idCmbSlideshowLoopMode, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idCmbSlideshowLoopMode, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idCmbSlideshowLoopMode, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idCmbSlideshowLoopMode, 0)
    __CD_RegCtrl($t, $__g_CD_idCmbSlideshowLoopMode)
    __CD_RegBhvSub(3, $__g_CD_idCmbSlideshowLoopMode)
    _Theme_SetTooltip($__g_CD_idCmbSlideshowLoopMode, _i18n("Settings.Behavior.tip_slideshow_loop_mode", "Run forever (infinite), for a number of full passes (count), or for a total time (duration)"))
    $iY += 26

    ; Loop count
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_loop_count", "Loop count:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowLoopCount = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpSlideshowLoopCount, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpSlideshowLoopCount, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowLoopCount, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowLoopCount)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowLoopCount)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowLoopCount)
    _Theme_SetTooltip($__g_CD_idInpSlideshowLoopCount, _i18n("Settings.Behavior.tip_slideshow_loop_count", "Number of full passes through the selection before stopping (1-1000)"))
    $iY += 26

    ; Loop duration (s)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_loop_duration", "Loop duration (s):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowLoopDuration = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpSlideshowLoopDuration, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpSlideshowLoopDuration, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowLoopDuration, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowLoopDuration)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowLoopDuration)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowLoopDuration)
    _Theme_SetTooltip($__g_CD_idInpSlideshowLoopDuration, _i18n("Settings.Behavior.tip_slideshow_loop_duration", "Total run time in seconds before stopping (5-86400)"))
    $iY += 26

    ; Auto-start on launch
    $__g_CD_idChkSlideshowAutostart = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_autostart", "Auto-start on launch"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowAutostart, _i18n("Settings.Behavior.tip_slideshow_autostart", "Start the slideshow automatically after the app launches"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowAutostart)
    $iY += 24

    ; Auto-start delay (ms)
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_slideshow_autostart_delay", "Auto-start delay (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(3, $idLbl)
    $__g_CD_idInpSlideshowAutostartDelay = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpSlideshowAutostartDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpSlideshowAutostartDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpSlideshowAutostartDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpSlideshowAutostartDelay)
    __CD_RegCtrl($t, $__g_CD_idInpSlideshowAutostartDelay)
    __CD_RegBhvSub(3, $__g_CD_idInpSlideshowAutostartDelay)
    _Theme_SetTooltip($__g_CD_idInpSlideshowAutostartDelay, _i18n("Settings.Behavior.tip_slideshow_autostart_delay", "Wait this long after launch before auto-starting the slideshow (0-3600000ms)"))
    $iY += 26

    ; Show in context menu
    $__g_CD_idChkSlideshowMenu = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_menu", "Show in context menu"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowMenu, _i18n("Settings.Behavior.tip_slideshow_menu", "Show the slideshow start/stop entry in the right-click context menu"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowMenu)
    $iY += 24

    ; Toast on toggle
    $__g_CD_idChkNotifySlideshow = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_notify_slideshow", "Toast on slideshow toggle"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifySlideshow, _i18n("Settings.Behavior.tip_notify_slideshow", "Show a toast when the slideshow is started or stopped"))
    __CD_RegBhvSub(3, $__g_CD_idChkNotifySlideshow)
    $iY += 24

    ; Break conditions (2x2 grid to conserve vertical space)
    $__g_CD_idChkSlideshowBreakManual = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_break_manual", "Stop on manual switch"), $iX, $iY, 230, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowBreakManual, _i18n("Settings.Behavior.tip_slideshow_break_manual", "Stop the slideshow when you change desktops yourself"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowBreakManual)
    $__g_CD_idChkSlideshowBreakWidget = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_break_widget", "Stop on widget click"), $iX + 245, $iY, 230, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowBreakWidget, _i18n("Settings.Behavior.tip_slideshow_break_widget", "Stop the slideshow when you click the widget"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowBreakWidget)
    $iY += 24
    $__g_CD_idChkSlideshowBreakHotkey = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_break_hotkey", "Stop on hotkey"), $iX, $iY, 230, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowBreakHotkey, _i18n("Settings.Behavior.tip_slideshow_break_hotkey", "Stop the slideshow when you use an app navigation or action hotkey"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowBreakHotkey)
    $__g_CD_idChkSlideshowBreakInput = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_slideshow_break_input", "Stop on any input"), $iX + 245, $iY, 230, $t)
    _Theme_SetTooltip($__g_CD_idChkSlideshowBreakInput, _i18n("Settings.Behavior.tip_slideshow_break_input", "Stop the slideshow on any keyboard or mouse activity"))
    __CD_RegBhvSub(3, $__g_CD_idChkSlideshowBreakInput)

    ; ========================================
    ; Sub-tab 4: Rules
    ; ========================================
    $iY = $iContentStartY

    $__g_CD_idChkRulesEnabled = __CD_CreateCheckbox(_i18n("Settings.Behavior.chk_rules_enabled", "Enable window rules engine"), $iX, $iY, 400, $t)
    _Theme_SetTooltip($__g_CD_idChkRulesEnabled, _i18n("Settings.Behavior.tip_rules_enabled", "Automatically move windows to specific desktops based on process name or window class"))
    __CD_RegBhvSub(4, $__g_CD_idChkRulesEnabled)
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_rules_interval", "Poll interval (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(4, $idLbl)
    $__g_CD_idInpRulesPollInterval = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpRulesPollInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpRulesPollInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpRulesPollInterval, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpRulesPollInterval)
    __CD_RegCtrl($t, $__g_CD_idInpRulesPollInterval)
    __CD_RegBhvSub(4, $__g_CD_idInpRulesPollInterval)
    _Theme_SetTooltip($__g_CD_idInpRulesPollInterval, _i18n("Settings.Behavior.tip_rules_interval", "How often to check windows against rules (500-30000)"))
    $iY += 30

    ; Rules builder header row
    Local $iColType = $iX
    Local $iColPattern = $iX + 72
    Local $iColDesk = $iX + 310
    Local $iColW_Type = 68
    Local $iColW_Pattern = 232
    Local $iColW_Desk = 40

    ; Rules builder info label
    Local $idRulesInfo = GUICtrlCreateLabel("(?) " & _i18n("Settings.Behavior.lbl_rules_help", "How rules work"), $iX, $iY, 200, 16)
    GUICtrlSetFont($idRulesInfo, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idRulesInfo, $THEME_FG_LINK)
    GUICtrlSetBkColor($idRulesInfo, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idRulesInfo)
    __CD_RegBhvSub(4, $idRulesInfo)
    _Theme_SetTooltip($idRulesInfo, _i18n("Settings.Behavior.tip_rules_help", _
        "Rules automatically move new windows to a specific desktop." & @CRLF & @CRLF & _
        "Type: Click to toggle between Process and Class." & @CRLF & _
        "  Process — match by executable name (e.g. chrome.exe)" & @CRLF & _
        "  Class — match by window class (e.g. CabinetWClass)" & @CRLF & @CRLF & _
        "Pattern: The text to match against. Wildcards * and ? are supported." & @CRLF & _
        "  e.g. discord* matches discord.exe and discordptb.exe" & @CRLF & @CRLF & _
        "Desk: The desktop number to send matching windows to." & @CRLF & _
        "Leave a row empty to skip it."))
    $iY += 18

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_rule_col_type", "Type"), $iColType, $iY, $iColW_Type, 16)
    GUICtrlSetFont($idLbl, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(4, $idLbl)

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_rule_col_pattern", "Match Pattern"), $iColPattern, $iY, $iColW_Pattern, 16)
    GUICtrlSetFont($idLbl, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(4, $idLbl)

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Behavior.lbl_rule_col_desktop", "Desk"), $iColDesk, $iY, $iColW_Desk, 16, $SS_CENTER)
    GUICtrlSetFont($idLbl, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    __CD_RegBhvSub(4, $idLbl)
    $iY += 18

    ; Rule builder rows
    Local $r
    For $r = 1 To $__g_CD_iRuleRowCount
        ; Type cycle label (Process / Class)
        $__g_CD_aidRuleType[$r] = GUICtrlCreateLabel(_i18n("Settings.Behavior.rule_type_process", "Process"), $iColType, $iY, $iColW_Type, 20, _
            BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidRuleType[$r], 7, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidRuleType[$r], $THEME_FG_LINK)
        GUICtrlSetBkColor($__g_CD_aidRuleType[$r], $THEME_BG_INPUT)
        GUICtrlSetCursor($__g_CD_aidRuleType[$r], 0)
        __CD_RegCtrl($t, $__g_CD_aidRuleType[$r])
        __CD_RegBhvSub(4, $__g_CD_aidRuleType[$r])

        ; Pattern input (e.g. "chrome.exe" or "CabinetWClass")
        $__g_CD_aidRulePattern[$r] = GUICtrlCreateInput("", $iColPattern, $iY, $iColW_Pattern, 20)
        GUICtrlSetFont($__g_CD_aidRulePattern[$r], 8, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidRulePattern[$r], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidRulePattern[$r], $THEME_BG_INPUT)
        _Theme_FlattenInput($__g_CD_aidRulePattern[$r])
        __CD_RegCtrl($t, $__g_CD_aidRulePattern[$r])
        __CD_RegBhvSub(4, $__g_CD_aidRulePattern[$r])

        ; Desktop number input
        $__g_CD_aidRuleDesktop[$r] = GUICtrlCreateInput("", $iColDesk, $iY, $iColW_Desk, 20, BitOR($ES_NUMBER, $ES_CENTER))
        GUICtrlSetFont($__g_CD_aidRuleDesktop[$r], 8, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidRuleDesktop[$r], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidRuleDesktop[$r], $THEME_BG_INPUT)
        _Theme_FlattenInput($__g_CD_aidRuleDesktop[$r])
        __CD_RegCtrl($t, $__g_CD_aidRuleDesktop[$r])
        __CD_RegBhvSub(4, $__g_CD_aidRuleDesktop[$r])

        $iY += 24
    Next

    ; Apply initial sub-tab visibility
    __CD_SwitchBhvSub(1)
EndFunc


Func __CD_BuildTabLogging()
    Local $t = 5, $iX = 20, $iY = 94

    $__g_CD_idChkLogging = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_logging", "Enable logging"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogging, _i18n("Settings.Logging.tip_logging", "Write debug information to a log file for troubleshooting"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_folder", "Log folder:"), $iX, $iY + 2, 100, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogPath = GUICtrlCreateInput("", $iX + 105, $iY, 248, 22)
    GUICtrlSetFont($__g_CD_idInpLogPath, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogPath, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogPath, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpLogPath)
    __CD_RegCtrl($t, $__g_CD_idInpLogPath)
    _Theme_SetTooltip($__g_CD_idInpLogPath, _i18n("Settings.Logging.tip_log_folder", "Folder for log files (empty = script folder). Supports %APPDATA%, %TEMP%, %SCRIPTDIR%"))
    $__g_CD_idBtnLogBrowse = GUICtrlCreateLabel(_i18n("General.btn_browse", "Browse"), $iX + 105 + 252, $iY, 48, 22, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnLogBrowse, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnLogBrowse, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idBtnLogBrowse, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnLogBrowse, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnLogBrowse)
    $iY += 30

    Local $idLblLL = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_level", "Log level:"), $iX, $iY + 2, 100, 18)
    GUICtrlSetFont($idLblLL, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblLL, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblLL, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblLL)
    $__g_CD_idLblLogLevel = GUICtrlCreateCombo("", $iX + 100, $iY, 90, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblLogLevel, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblLogLevel, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblLogLevel, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblLogLevel, 0)
    __CD_RegCtrl($t, $__g_CD_idLblLogLevel)
    _Theme_SetTooltip($__g_CD_idLblLogLevel, _i18n("Settings.Logging.tip_log_level", "Select log verbosity level (debug is most verbose)"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_max_size", "Max log size (MB):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogMaxSize = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpLogMaxSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogMaxSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogMaxSize, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpLogMaxSize)
    __CD_RegCtrl($t, $__g_CD_idInpLogMaxSize)
    _Theme_SetTooltip($__g_CD_idInpLogMaxSize, _i18n("Settings.Logging.tip_log_max_size", "Rotate log file when it exceeds this size"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_rotate", "Rotate count (1-10):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpLogRotateCount = GUICtrlCreateInput("", $iX + 170, $iY, 50, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpLogRotateCount, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpLogRotateCount, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpLogRotateCount, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpLogRotateCount)
    __CD_RegCtrl($t, $__g_CD_idInpLogRotateCount)
    _Theme_SetTooltip($__g_CD_idInpLogRotateCount, _i18n("Settings.Logging.tip_log_rotate", "Number of rotated log files to keep (1-10)"))
    $iY += 30

    $__g_CD_idChkLogCompress = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_log_compress", "Compress old logs"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogCompress, _i18n("Settings.Logging.tip_log_compress", "Zip old log files when rotating (uses PowerShell)"))
    $iY += 34

    $__g_CD_idChkLogPID = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_log_pid", "Include PID in log"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogPID, _i18n("Settings.Logging.tip_log_pid", "Add process ID [PID:XXXX] to each log line after the timestamp"))
    $iY += 34

    Local $idLblDF = GUICtrlCreateLabel(_i18n("Settings.Logging.lbl_log_date", "Date format:"), $iX, $iY + 2, 100, 18)
    GUICtrlSetFont($idLblDF, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblDF, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblDF, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblDF)
    $__g_CD_idLblLogDateFormat = GUICtrlCreateCombo("", $iX + 100, $iY, 90, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblLogDateFormat, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblLogDateFormat, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblLogDateFormat, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblLogDateFormat, 0)
    __CD_RegCtrl($t, $__g_CD_idLblLogDateFormat)
    _Theme_SetTooltip($__g_CD_idLblLogDateFormat, _i18n("Settings.Logging.tip_log_date", "Select date format: iso (YYYY-MM-DD), us (MM/DD/YYYY), eu (DD/MM/YYYY)"))
    $iY += 30

    $__g_CD_idChkLogFlush = __CD_CreateCheckbox(_i18n("Settings.Logging.chk_log_flush", "Flush immediately"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkLogFlush, _i18n("Settings.Logging.tip_log_flush", "Flush log file after every write (vs buffered I/O)"))
EndFunc

Func __CD_BuildTabUpdates()
    Local $t = 6, $iX = 20, $iY = 94

    ; Current version display
    Local $idVerLbl = GUICtrlCreateLabel(_i18n_Format("Settings.Updates.lbl_current_version", "Current version: v{1}", $APP_VERSION), $iX, $iY, 300, 18)
    GUICtrlSetFont($idVerLbl, 9, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idVerLbl, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idVerLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idVerLbl)
    $iY += 26

    $__g_CD_idChkAutoUpdate = __CD_CreateCheckbox(_i18n("Settings.Updates.chk_auto_update", "Auto-check for updates"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoUpdate, _i18n("Settings.Updates.tip_auto_update", "Periodically check GitHub for new releases"))
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Updates.lbl_update_interval", "Check interval (hours):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpUpdateInterval = GUICtrlCreateInput("", $iX + 170, $iY, 100, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpUpdateInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpUpdateInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpUpdateInterval, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpUpdateInterval)
    __CD_RegCtrl($t, $__g_CD_idInpUpdateInterval)
    _Theme_SetTooltip($__g_CD_idInpUpdateInterval, _i18n("Settings.Updates.tip_update_interval", "How often to check for updates (in hours)"))
    $iY += 34

    $__g_CD_idChkUpdateOnStartup = __CD_CreateCheckbox(_i18n("Settings.Updates.chk_check_startup", "Check on startup"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkUpdateOnStartup, _i18n("Settings.Updates.tip_check_startup", "Check for updates when the application starts (respects day interval)"))
    $iY += 34

    Local $idLblDays = GUICtrlCreateLabel(_i18n("Settings.Updates.lbl_check_days", "Check every (days):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblDays, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblDays, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblDays, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblDays)
    $__g_CD_idInpUpdateCheckDays = GUICtrlCreateInput("", $iX + 170, $iY, 100, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpUpdateCheckDays, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpUpdateCheckDays, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpUpdateCheckDays, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpUpdateCheckDays)
    __CD_RegCtrl($t, $__g_CD_idInpUpdateCheckDays)
    _Theme_SetTooltip($__g_CD_idInpUpdateCheckDays, _i18n("Settings.Updates.tip_check_days", "Minimum days between startup update checks (1-90)"))
    $iY += 34

    $__g_CD_idBtnCheckNow = GUICtrlCreateLabel(ChrW(0x21BB) & " " & _i18n("Settings.Updates.btn_check_now", "Check Now"), $iX, $iY, 120, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnCheckNow, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnCheckNow, $THEME_FG_MENU)
    GUICtrlSetBkColor($__g_CD_idBtnCheckNow, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnCheckNow, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnCheckNow)
    _Theme_SetTooltip($__g_CD_idBtnCheckNow, _i18n("Settings.Updates.tip_check_now", "Check for updates right now"))

    $__g_CD_idBtnDownloadLatest = GUICtrlCreateLabel(ChrW(0x2B07) & " " & _i18n("Settings.Updates.btn_download", "Download Latest"), $iX + 130, $iY, 140, 26, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($__g_CD_idBtnDownloadLatest, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idBtnDownloadLatest, $THEME_FG_LINK)
    GUICtrlSetBkColor($__g_CD_idBtnDownloadLatest, $THEME_BG_HOVER)
    GUICtrlSetCursor($__g_CD_idBtnDownloadLatest, 0)
    __CD_RegCtrl($t, $__g_CD_idBtnDownloadLatest)
    _Theme_SetTooltip($__g_CD_idBtnDownloadLatest, _i18n("Settings.Updates.tip_download", "Download the latest portable version to your Downloads folder"))
    $iY += 38

    ; Last checked / Next check display labels
    $__g_CD_idLblLastChecked = GUICtrlCreateLabel("", $iX, $iY, 380, 16)
    GUICtrlSetFont($__g_CD_idLblLastChecked, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idLblLastChecked, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idLblLastChecked, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $__g_CD_idLblLastChecked)
    $iY += 20

    $__g_CD_idLblNextCheck = GUICtrlCreateLabel("", $iX, $iY, 380, 16)
    GUICtrlSetFont($__g_CD_idLblNextCheck, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idLblNextCheck, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idLblNextCheck, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $__g_CD_idLblNextCheck)
    _CD_RefreshUpdateStatusLabels()
EndFunc

Func _CD_RefreshUpdateStatusLabels()
    If $__g_CD_hGUI = 0 Or $__g_CD_idLblLastChecked = 0 Or $__g_CD_idLblNextCheck = 0 Then Return

    Local $sLastCheck = IniRead(_Cfg_GetPath(), "Updates", "_last_check_date", "")
    Local $bNeverChecked = ($sLastCheck = "" Or $sLastCheck = "0")
    Local $sLastCheckDisplay = $sLastCheck
    If $bNeverChecked Then $sLastCheckDisplay = _i18n("Extra.value_never", "Never")

    GUICtrlSetData($__g_CD_idLblLastChecked, _i18n("Settings.Updates.lbl_last_checked", "Last checked:") & " " & $sLastCheckDisplay)

    Local $sNextCheck = _i18n("Extra.value_na", "N/A")
    If Not $bNeverChecked Then
        Local $iCheckDays = _Cfg_GetUpdateCheckDays()
        $sNextCheck = _i18n_Format("Extra.update_next_estimate", "~{1} + {2}d", $sLastCheck, $iCheckDays)
    EndIf
    GUICtrlSetData($__g_CD_idLblNextCheck, _i18n("Settings.Updates.lbl_next_check", "Next check:") & " " & $sNextCheck)
EndFunc

Func __CD_BuildTabDesktops()
    Local $t = 7, $iX = 20, $iY = 94
    Local $idLbl

    ; Enable toggles side by side
    $__g_CD_idChkColorsEnabled = __CD_CreateCheckbox(_i18n("Settings.Desktops.chk_colors_enabled", "Enable desktop colors"), $iX, $iY, 220, $t)
    _Theme_SetTooltip($__g_CD_idChkColorsEnabled, _i18n("Settings.Desktops.tip_colors_enabled", "Show colored indicators next to desktop names in the list"))

    $__g_CD_idChkWallpaper = __CD_CreateCheckbox(_i18n("Settings.Wallpaper.chk_wallpaper_enabled", "Enable wallpaper"), $iX + 230, $iY, 200, $t)
    _Theme_SetTooltip($__g_CD_idChkWallpaper, _i18n("Settings.Wallpaper.tip_wallpaper_enabled", "Automatically change wallpaper when switching desktops"))
    $iY += 26

    ; Wallpaper delay
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Wallpaper.lbl_wallpaper_delay", "Change delay (ms):"), $iX, $iY + 2, 130, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWallpaperDelay = GUICtrlCreateInput("", $iX + 135, $iY, 55, 20, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWallpaperDelay, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWallpaperDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWallpaperDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWallpaperDelay)
    __CD_RegCtrl($t, $__g_CD_idInpWallpaperDelay)
    _Theme_SetTooltip($__g_CD_idInpWallpaperDelay, _i18n("Settings.Wallpaper.tip_wallpaper_delay", "Delay before applying wallpaper after switching (ms)"))
    $iY += 26

    ; Desktop count and pagination
    Local $iCount = _VD_GetCount()
    If $iCount > 50 Then $iCount = 50
    $__g_CD_iDeskCount = $iCount
    $__g_CD_iDeskPageCount = Ceiling($iCount / $__g_CD_DESK_PER_PAGE)
    If $__g_CD_iDeskPageCount < 1 Then $__g_CD_iDeskPageCount = 1
    $__g_CD_iDeskPage = 1

    ; Page sub-tab buttons (only if more than 10 desktops)
    If $__g_CD_iDeskPageCount > 1 Then
        Local $iPageBtnW = 55, $iPageGap = 4
        Local $p
        For $p = 1 To $__g_CD_iDeskPageCount
            Local $iFrom = ($p - 1) * $__g_CD_DESK_PER_PAGE + 1
            Local $iTo = $p * $__g_CD_DESK_PER_PAGE
            If $iTo > $iCount Then $iTo = $iCount
            Local $sBtnText = $iFrom & "-" & $iTo
            $__g_CD_aidDeskPageBtn[$p] = GUICtrlCreateLabel($sBtnText, $iX + ($iPageBtnW + $iPageGap) * ($p - 1), $iY, $iPageBtnW, 18, _
                BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
            GUICtrlSetFont($__g_CD_aidDeskPageBtn[$p], 7, ($p = 1) ? 700 : 400, 0, $THEME_FONT_MAIN)
            GUICtrlSetColor($__g_CD_aidDeskPageBtn[$p], ($p = 1) ? $THEME_FG_WHITE : $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_CD_aidDeskPageBtn[$p], ($p = 1) ? $THEME_BG_ACTIVE : $THEME_BG_MAIN)
            GUICtrlSetCursor($__g_CD_aidDeskPageBtn[$p], 0)
            __CD_RegCtrl($t, $__g_CD_aidDeskPageBtn[$p])
        Next
        $iY += 22
    EndIf

    ; Column headers
    ;   #(22) Label(130) Color(55) [■](16) Wallpaper(180) [...](24)
    Local $idHdr
    $idHdr = GUICtrlCreateLabel("#", $iX, $iY, 20, 14)
    GUICtrlSetFont($idHdr, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHdr, $THEME_FG_DIM)
    GUICtrlSetBkColor($idHdr, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idHdr)

    $idHdr = GUICtrlCreateLabel(_i18n("Settings.Desktops.col_label", "Label"), $iX + 24, $iY, 128, 14)
    GUICtrlSetFont($idHdr, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHdr, $THEME_FG_DIM)
    GUICtrlSetBkColor($idHdr, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idHdr)

    $idHdr = GUICtrlCreateLabel(_i18n("Settings.Desktops.col_color", "Color"), $iX + 158, $iY, 50, 14)
    GUICtrlSetFont($idHdr, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHdr, $THEME_FG_DIM)
    GUICtrlSetBkColor($idHdr, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idHdr)

    $idHdr = GUICtrlCreateLabel(_i18n("Settings.Desktops.col_wallpaper", "Wallpaper"), $iX + 230, $iY, 200, 14)
    GUICtrlSetFont($idHdr, 7, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHdr, $THEME_FG_DIM)
    GUICtrlSetBkColor($idHdr, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idHdr)
    $iY += 18

    ; Desktop rows — single line each, all pages created at same Y positions
    Local $iRowStartY = $iY
    Local $i
    For $i = 1 To $iCount
        ; Calculate row Y based on position within page (0-9)
        Local $iSlot = Mod($i - 1, $__g_CD_DESK_PER_PAGE)
        Local $iRowY = $iRowStartY + ($iSlot * 22)

        ; Number label
        $__g_CD_aidDeskNum[$i] = GUICtrlCreateLabel(StringRight("0" & $i, 2), $iX, $iRowY + 2, 20, 18)
        GUICtrlSetFont($__g_CD_aidDeskNum[$i], 8, 700, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidDeskNum[$i], $THEME_FG_PRIMARY)
        GUICtrlSetBkColor($__g_CD_aidDeskNum[$i], $GUI_BKCOLOR_TRANSPARENT)
        __CD_RegCtrl($t, $__g_CD_aidDeskNum[$i])

        ; Label input
        $__g_CD_aidDeskLabel[$i] = GUICtrlCreateInput("", $iX + 24, $iRowY, 128, 20)
        GUICtrlSetFont($__g_CD_aidDeskLabel[$i], 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidDeskLabel[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidDeskLabel[$i], $THEME_BG_INPUT)
        _Theme_FlattenInput($__g_CD_aidDeskLabel[$i])
        __CD_RegCtrl($t, $__g_CD_aidDeskLabel[$i])

        ; Color hex input
        $__g_CD_aidDeskColor[$i] = GUICtrlCreateInput("", $iX + 158, $iRowY, 50, 20)
        GUICtrlSetFont($__g_CD_aidDeskColor[$i], 7, 400, 0, $THEME_FONT_MONO)
        GUICtrlSetColor($__g_CD_aidDeskColor[$i], $THEME_FG_TEXT)
        GUICtrlSetBkColor($__g_CD_aidDeskColor[$i], $THEME_BG_INPUT)
        _Theme_FlattenInput($__g_CD_aidDeskColor[$i])
        __CD_RegCtrl($t, $__g_CD_aidDeskColor[$i])

        ; Color preview swatch
        $__g_CD_aidDeskPreview[$i] = GUICtrlCreateLabel("", $iX + 214, $iRowY + 2, 14, 16)
        __CD_RegCtrl($t, $__g_CD_aidDeskPreview[$i])

        ; Wallpaper path input
        $__g_CD_aidWallpaperPath[$i] = GUICtrlCreateInput("", $iX + 234, $iRowY, 220, 20)
        GUICtrlSetFont($__g_CD_aidWallpaperPath[$i], 7, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidWallpaperPath[$i], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidWallpaperPath[$i], $THEME_BG_INPUT)
        _Theme_FlattenInput($__g_CD_aidWallpaperPath[$i])
        __CD_RegCtrl($t, $__g_CD_aidWallpaperPath[$i])

        ; Wallpaper browse button
        $__g_CD_aidWallpaperBrowse[$i] = GUICtrlCreateLabel("...", $iX + 458, $iRowY, 24, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidWallpaperBrowse[$i], 8, 700, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidWallpaperBrowse[$i], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidWallpaperBrowse[$i], $THEME_BG_HOVER)
        GUICtrlSetCursor($__g_CD_aidWallpaperBrowse[$i], 0)
        __CD_RegCtrl($t, $__g_CD_aidWallpaperBrowse[$i])

        ; Hide rows not on page 1
        If $i > $__g_CD_DESK_PER_PAGE Then
            GUICtrlSetState($__g_CD_aidDeskNum[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidDeskLabel[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidDeskColor[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidDeskPreview[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidWallpaperPath[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidWallpaperBrowse[$i], $GUI_HIDE)
        EndIf
    Next
EndFunc

; Name:        __CD_SwitchDeskPage
; Description: Switches the visible page of desktop rows in the Desktops tab.
; Parameters:  $iPage - page number (1-based)
Func __CD_SwitchDeskPage($iPage)
    If $iPage < 1 Or $iPage > $__g_CD_iDeskPageCount Then Return
    $__g_CD_iDeskPage = $iPage
    $__g_CD_iSubTabHovered = 0 ; this switch fully restyles every page button; drop stale hover
    __CD_LockBegin()

    ; Show/hide rows per page
    Local $i
    For $i = 1 To $__g_CD_iDeskCount
        Local $iRowPage = Ceiling($i / $__g_CD_DESK_PER_PAGE)
        If $iRowPage = $iPage Then
            GUICtrlSetState($__g_CD_aidDeskNum[$i], $GUI_SHOW)
            GUICtrlSetState($__g_CD_aidDeskLabel[$i], $GUI_SHOW)
            GUICtrlSetState($__g_CD_aidDeskColor[$i], $GUI_SHOW)
            GUICtrlSetState($__g_CD_aidDeskPreview[$i], $GUI_SHOW)
            GUICtrlSetState($__g_CD_aidWallpaperPath[$i], $GUI_SHOW)
            GUICtrlSetState($__g_CD_aidWallpaperBrowse[$i], $GUI_SHOW)
        Else
            GUICtrlSetState($__g_CD_aidDeskNum[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidDeskLabel[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidDeskColor[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidDeskPreview[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidWallpaperPath[$i], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidWallpaperBrowse[$i], $GUI_HIDE)
        EndIf
    Next

    ; Update page button styles
    Local $p
    For $p = 1 To $__g_CD_iDeskPageCount
        If $p = $iPage Then
            GUICtrlSetFont($__g_CD_aidDeskPageBtn[$p], 7, 700, 0, $THEME_FONT_MAIN)
            GUICtrlSetColor($__g_CD_aidDeskPageBtn[$p], $THEME_FG_WHITE)
            GUICtrlSetBkColor($__g_CD_aidDeskPageBtn[$p], $THEME_BG_ACTIVE)
        Else
            GUICtrlSetFont($__g_CD_aidDeskPageBtn[$p], 7, 400, 0, $THEME_FONT_MAIN)
            GUICtrlSetColor($__g_CD_aidDeskPageBtn[$p], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_CD_aidDeskPageBtn[$p], $THEME_BG_MAIN)
        EndIf
    Next
    __CD_LockEnd()
EndFunc

Func __CD_BuildTabOSD()
    Local $t = 9, $iX = 20, $iY = 94

    $__g_CD_idChkOsdEnabled = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_osd_enabled", "Show notification on desktop switch"), $iX, $iY, 400, $t)
    _Theme_SetTooltip($__g_CD_idChkOsdEnabled, _i18n("Settings.Notifications.tip_osd_enabled", "Display an on-screen notification when switching desktops"))
    $iY += 26

    $__g_CD_idChkOsdShowName = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_osd_show_name", "Show desktop name"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkOsdShowName, _i18n("Settings.Notifications.tip_osd_show_name", "Include the desktop name in the OSD notification"))
    $iY += 26

    $__g_CD_idChkOsdShowNumber = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_osd_show_number", "Show desktop number"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkOsdShowNumber, _i18n("Settings.Notifications.tip_osd_show_number", "Include the desktop number in the OSD notification"))
    $iY += 30

    ; OSD Duration
    Local $idLblOsdDur = GUICtrlCreateLabel(_i18n("Settings.Notifications.lbl_osd_duration", "OSD duration (ms):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLblOsdDur, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblOsdDur, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblOsdDur, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblOsdDur)
    $__g_CD_idInpOsdDuration = GUICtrlCreateInput("1500", $iX + 210, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOsdDuration, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOsdDuration, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOsdDuration, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOsdDuration)
    __CD_RegCtrl($t, $__g_CD_idInpOsdDuration)
    _Theme_SetTooltip($__g_CD_idInpOsdDuration, _i18n("Settings.Notifications.tip_osd_duration", "How long the OSD notification stays visible (500-5000)"))
    $iY += 30

    ; OSD Position (combo dropdown)
    Local $idLblPos = GUICtrlCreateLabel(_i18n("Settings.Notifications.lbl_osd_position", "OSD position:"), $iX, $iY + 2, 120, 18)
    GUICtrlSetFont($idLblPos, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblPos, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblPos, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblPos)
    $__g_CD_idCycOsdPosition = GUICtrlCreateCombo("", $iX + 130, $iY, 200, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idCycOsdPosition, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idCycOsdPosition, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idCycOsdPosition, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idCycOsdPosition, 0)
    __CD_RegCtrl($t, $__g_CD_idCycOsdPosition)
    _Theme_SetTooltip($__g_CD_idCycOsdPosition, _i18n("Settings.Notifications.tip_osd_position", "Where to display the OSD notification on screen"))
    $iY += 30

    ; OSD Font Size
    Local $idLblOsdFont = GUICtrlCreateLabel(_i18n("Settings.Notifications.lbl_osd_font_size", "OSD font size:"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLblOsdFont, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblOsdFont, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblOsdFont, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblOsdFont)
    $__g_CD_idInpOsdFontSize = GUICtrlCreateInput("14", $iX + 210, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOsdFontSize, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOsdFontSize, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOsdFontSize, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOsdFontSize)
    __CD_RegCtrl($t, $__g_CD_idInpOsdFontSize)
    _Theme_SetTooltip($__g_CD_idInpOsdFontSize, _i18n("Settings.Notifications.tip_osd_font_size", "Font size for the OSD notification text (8-48)"))
    $iY += 30

    ; OSD Opacity
    Local $idLblOsdOpac = GUICtrlCreateLabel(_i18n("Settings.Notifications.lbl_osd_opacity", "OSD opacity (0-255):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLblOsdOpac, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblOsdOpac, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblOsdOpac, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblOsdOpac)
    $__g_CD_idInpOsdOpacity = GUICtrlCreateInput("220", $iX + 210, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOsdOpacity, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOsdOpacity, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOsdOpacity, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOsdOpacity)
    __CD_RegCtrl($t, $__g_CD_idInpOsdOpacity)
    _Theme_SetTooltip($__g_CD_idInpOsdOpacity, _i18n("Settings.Notifications.tip_osd_opacity", "Transparency of the OSD notification window (0=invisible, 255=opaque)"))
    $iY += 30

    ; OSD Format
    Local $idLblOsdFmt = GUICtrlCreateLabel(_i18n("Settings.Notifications.lbl_osd_format", "OSD format:"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLblOsdFmt, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblOsdFmt, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblOsdFmt, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblOsdFmt)
    $__g_CD_idInpOsdFormat = GUICtrlCreateInput("{number}: {name}", $iX + 210, $iY, 180, 22)
    GUICtrlSetFont($__g_CD_idInpOsdFormat, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idInpOsdFormat, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOsdFormat, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOsdFormat)
    __CD_RegCtrl($t, $__g_CD_idInpOsdFormat)
    _Theme_SetTooltip($__g_CD_idInpOsdFormat, _i18n("Settings.Notifications.tip_osd_format", "Template for the OSD text. Use {number} and {name} as placeholders"))
    $iY += 30

    ; OSD Width
    Local $idLblOsdW = GUICtrlCreateLabel(_i18n("Settings.OSD.lbl_osd_width", "OSD width (px):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLblOsdW, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblOsdW, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblOsdW, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblOsdW)
    $__g_CD_idInpOsdWidth = GUICtrlCreateInput("300", $iX + 210, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpOsdWidth, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpOsdWidth, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpOsdWidth, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpOsdWidth)
    __CD_RegCtrl($t, $__g_CD_idInpOsdWidth)
    _Theme_SetTooltip($__g_CD_idInpOsdWidth, _i18n("Settings.OSD.tip_osd_width", "Width of the OSD notification window in pixels (100-800)"))
EndFunc

Func __CD_BuildTabWindowList()
    Local $t = 10, $iX = 20, $iY = 94

    $__g_CD_idChkWLEnabled = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_enabled", "Enable window list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLEnabled, _i18n("Settings.WindowList.tip_wl_enabled", "Show a panel listing windows on the current desktop"))
    $iY += 34

    Local $idLblWS = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_scope", "Window scope:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblWS, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblWS, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblWS, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblWS)
    $__g_CD_idLblWLScope = GUICtrlCreateCombo("", $iX + 165, $iY, 110, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblWLScope, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblWLScope, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblWLScope, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblWLScope, 0)
    __CD_RegCtrl($t, $__g_CD_idLblWLScope)
    _Theme_SetTooltip($__g_CD_idLblWLScope, _i18n("Settings.WindowList.tip_wl_scope", "Show windows from current desktop only or all desktops"))
    $iY += 30

    Local $idLblWP = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_position", "Panel position:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblWP, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblWP, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblWP, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblWP)
    $__g_CD_idLblWLPosition = GUICtrlCreateCombo("", $iX + 165, $iY, 110, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblWLPosition, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblWLPosition, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblWLPosition, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblWLPosition, 0)
    __CD_RegCtrl($t, $__g_CD_idLblWLPosition)
    _Theme_SetTooltip($__g_CD_idLblWLPosition, _i18n("Settings.WindowList.tip_wl_position", "Select panel position on screen"))
    $iY += 30

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_width", "Panel width (150-600):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWLWidth = GUICtrlCreateInput("", $iX + 170, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWLWidth, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWLWidth, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWLWidth, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWLWidth)
    __CD_RegCtrl($t, $__g_CD_idInpWLWidth)
    _Theme_SetTooltip($__g_CD_idInpWLWidth, _i18n("Settings.WindowList.tip_wl_width", "Width of the window list panel in pixels"))
    $iY += 30

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_max_visible", "Max visible windows (5-50):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWLMaxVisible = GUICtrlCreateInput("", $iX + 170, $iY, 60, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWLMaxVisible, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWLMaxVisible, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWLMaxVisible, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWLMaxVisible)
    __CD_RegCtrl($t, $__g_CD_idInpWLMaxVisible)
    _Theme_SetTooltip($__g_CD_idInpWLMaxVisible, _i18n("Settings.WindowList.tip_wl_max_visible", "Maximum number of windows shown before scrolling"))
    $iY += 34

    $__g_CD_idChkWLSearch = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_search", "Show search bar"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLSearch, _i18n("Settings.WindowList.tip_wl_search", "Show a search/filter bar at the top of the window list"))
    $iY += 26
    $__g_CD_idChkWLAutoRefresh = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_auto_refresh", "Auto-refresh"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLAutoRefresh, _i18n("Settings.WindowList.tip_wl_auto_refresh", "Automatically update the window list at regular intervals"))
    $iY += 34

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.WindowList.lbl_wl_refresh_interval", "Refresh interval (ms, 500-10000):"), $iX, $iY + 2, 200, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpWLRefreshInterval = GUICtrlCreateInput("", $iX + 205, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpWLRefreshInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpWLRefreshInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpWLRefreshInterval, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpWLRefreshInterval)
    __CD_RegCtrl($t, $__g_CD_idInpWLRefreshInterval)
    _Theme_SetTooltip($__g_CD_idInpWLRefreshInterval, _i18n("Settings.WindowList.tip_wl_refresh_interval", "How often to refresh the window list (ms)"))
    $iY += 34

    $__g_CD_idChkWLDraggable = __CD_CreateCheckbox(_i18n("Settings.WindowList.chk_wl_draggable", "Draggable window list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkWLDraggable, _i18n("Settings.WindowList.tip_wl_draggable", "Hold and drag the window list title bar to reposition it"))
EndFunc

Func __CD_BuildTabExplorer()
    Local $t = 11, $iX = 20, $iY = 94

    $__g_CD_idChkExplorerMonitor = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_explorer_monitor", "Enable shell monitor"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkExplorerMonitor, _i18n("Settings.Explorer.tip_explorer_monitor", "Monitor the shell process and attempt recovery on crash"))
    $iY += 34

    ; Shell process name
    Local $idLblProc = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_shell_process", "Shell process:"), $iX, $iY + 2, 120, 18)
    GUICtrlSetFont($idLblProc, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblProc, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblProc, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblProc)
    $__g_CD_idInpShellProcess = GUICtrlCreateInput("", $iX + 125, $iY, 160, 22)
    GUICtrlSetFont($__g_CD_idInpShellProcess, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpShellProcess, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpShellProcess, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpShellProcess)
    __CD_RegCtrl($t, $__g_CD_idInpShellProcess)
    _Theme_SetTooltip($__g_CD_idInpShellProcess, _i18n("Settings.Explorer.tip_shell_process", "Process name to monitor (default: explorer.exe)"))
    $iY += 30

    ; Check interval
    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_explorer_interval", "Check interval (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpExplorerInterval = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpExplorerInterval, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpExplorerInterval, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpExplorerInterval, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpExplorerInterval)
    __CD_RegCtrl($t, $__g_CD_idInpExplorerInterval)
    _Theme_SetTooltip($__g_CD_idInpExplorerInterval, _i18n("Settings.Explorer.tip_explorer_interval", "How often to check if the shell is alive (ms)"))
    $iY += 30

    ; Auto-restart
    $__g_CD_idChkAutoRestart = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_auto_restart", "Auto-restart on crash"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoRestart, _i18n("Settings.Explorer.tip_auto_restart", "Attempt to restart the shell process automatically when a crash is detected"))
    $iY += 26

    ; Restart delay
    Local $idLblRD = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_restart_delay", "Restart delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblRD, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblRD, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblRD, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblRD)
    $__g_CD_idInpRestartDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpRestartDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpRestartDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpRestartDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpRestartDelay)
    __CD_RegCtrl($t, $__g_CD_idInpRestartDelay)
    _Theme_SetTooltip($__g_CD_idInpRestartDelay, _i18n("Settings.Explorer.tip_restart_delay", "Wait this long before attempting restart (ms)"))
    $iY += 34

    ; Max retries
    Local $idLblMR = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_max_retries", "Max retries (0=unlimited):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblMR, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblMR, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblMR, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblMR)
    $__g_CD_idInpMaxRetries = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMaxRetries, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMaxRetries, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMaxRetries, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpMaxRetries)
    __CD_RegCtrl($t, $__g_CD_idInpMaxRetries)
    _Theme_SetTooltip($__g_CD_idInpMaxRetries, _i18n("Settings.Explorer.tip_max_retries", "Maximum restart attempts (0 = unlimited)"))
    $iY += 30

    ; Retry delay
    Local $idLblRDl = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_retry_delay", "Retry delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblRDl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblRDl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblRDl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblRDl)
    $__g_CD_idInpRetryDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpRetryDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpRetryDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpRetryDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpRetryDelay)
    __CD_RegCtrl($t, $__g_CD_idInpRetryDelay)
    _Theme_SetTooltip($__g_CD_idInpRetryDelay, _i18n("Settings.Explorer.tip_retry_delay", "Initial delay between retry attempts (ms)"))
    $iY += 30

    ; Exponential backoff
    $__g_CD_idChkExpBackoff = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_exp_backoff", "Exponential backoff"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkExpBackoff, _i18n("Settings.Explorer.tip_exp_backoff", "Double the retry delay after each failed attempt"))
    $iY += 26

    ; Max retry delay
    Local $idLblMD = GUICtrlCreateLabel(_i18n("Settings.Explorer.lbl_max_retry_delay", "Max retry delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLblMD, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblMD, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblMD, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblMD)
    $__g_CD_idInpMaxRetryDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpMaxRetryDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpMaxRetryDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpMaxRetryDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpMaxRetryDelay)
    __CD_RegCtrl($t, $__g_CD_idInpMaxRetryDelay)
    _Theme_SetTooltip($__g_CD_idInpMaxRetryDelay, _i18n("Settings.Explorer.tip_max_retry_delay", "Maximum delay cap for exponential backoff (ms)"))
    $iY += 34

    ; Notify on recovery
    $__g_CD_idChkExplorerNotify = __CD_CreateCheckbox(_i18n("Settings.Explorer.chk_explorer_notify", "Notify on recovery"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkExplorerNotify, _i18n("Settings.Explorer.tip_explorer_notify", "Show a toast when the shell is recovered after a crash"))
EndFunc

Func __CD_BuildTabNotifications()
    Local $t = 12, $iX = 20, $iY = 94

    $__g_CD_idChkNotificationsEnabled = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notifications_enabled", "Enable notifications"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotificationsEnabled, _i18n("Settings.Notifications.tip_notifications_enabled", "Master toggle for all toast notifications"))
    $iY += 34  ; extra spacing to visually separate from individual toggles

    $__g_CD_idChkNotifyMoved = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_moved", "Window sent to desktop"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyMoved, _i18n("Settings.Notifications.tip_notify_moved", "Show a toast when a window is moved to another desktop"))
    $iY += 26
    $__g_CD_idChkNotifyCreated = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_created", "Desktop created"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyCreated, _i18n("Settings.Notifications.tip_notify_created", "Show a toast when a new desktop is created"))
    $iY += 26
    $__g_CD_idChkNotifyDeleted = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_deleted", "Desktop deleted"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyDeleted, _i18n("Settings.Notifications.tip_notify_deleted", "Show a toast when a desktop is deleted"))
    $iY += 26
    $__g_CD_idChkNotifyPinned = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_pinned", "Window pinned"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyPinned, _i18n("Settings.Notifications.tip_notify_pinned", "Show a toast when a window is pinned to all desktops"))
    $iY += 26
    $__g_CD_idChkNotifyUnpinned = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_unpinned", "Window unpinned"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyUnpinned, _i18n("Settings.Notifications.tip_notify_unpinned", "Show a toast when a window is unpinned"))
    $iY += 26
    $__g_CD_idChkNotifyExplorerRecov = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_explorer", "Shell monitor recovery"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyExplorerRecov, _i18n("Settings.Notifications.tip_notify_explorer", "Show a toast when the shell process recovers from a crash"))
    $iY += 26
    $__g_CD_idChkNotifyExplorerCrash = __CD_CreateCheckbox(_i18n("Settings.Notifications.chk_notify_crash", "Shell crash detected"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkNotifyExplorerCrash, _i18n("Settings.Notifications.tip_notify_crash", "Show a toast when the shell process crashes"))
EndFunc

Func __CD_BuildTabTaskbar()
    Local $t = 13, $iX = 20, $iY = 94

    $__g_CD_idChkAutoHideSync = __CD_CreateCheckbox(_i18n("Settings.Taskbar.chk_autohide_sync", "Sync widget with taskbar auto-hide"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoHideSync, _i18n("Settings.Taskbar.tip_autohide_sync", "Hide widget when taskbar auto-hides, show when taskbar appears"))
    $iY += 34

    ; Poll interval
    Local $idLbl1 = GUICtrlCreateLabel(_i18n("Settings.Taskbar.lbl_poll_interval", "Poll interval (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl1, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl1, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl1, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl1)
    $__g_CD_idInpAutoHidePoll = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHidePoll, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHidePoll, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHidePoll, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHidePoll)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHidePoll)
    _Theme_SetTooltip($__g_CD_idInpAutoHidePoll, _i18n("Settings.Taskbar.tip_poll_interval", "How often to check taskbar visibility state (50-2000)"))
    $iY += 30

    ; Hide delay
    Local $idLbl2 = GUICtrlCreateLabel(_i18n("Settings.Taskbar.lbl_hide_delay", "Hide delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl2, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl2, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl2, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl2)
    $__g_CD_idInpAutoHideHideDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHideHideDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHideHideDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHideHideDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHideHideDelay)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHideHideDelay)
    _Theme_SetTooltip($__g_CD_idInpAutoHideHideDelay, _i18n("Settings.Taskbar.tip_hide_delay", "Wait this long before hiding widget after taskbar hides (0-5000)"))
    $iY += 30

    ; Show delay
    Local $idLbl3 = GUICtrlCreateLabel(_i18n("Settings.Taskbar.lbl_show_delay", "Show delay (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl3, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl3, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl3, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl3)
    $__g_CD_idInpAutoHideShowDelay = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHideShowDelay, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHideShowDelay, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHideShowDelay, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHideShowDelay)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHideShowDelay)
    _Theme_SetTooltip($__g_CD_idInpAutoHideShowDelay, _i18n("Settings.Taskbar.tip_show_delay", "Wait this long before showing widget after taskbar shows (0-5000)"))
    $iY += 34

    ; Sync desktop list
    $__g_CD_idChkAutoHideSyncDL = __CD_CreateCheckbox(_i18n("Settings.Taskbar.chk_sync_desktop_list", "Also sync desktop list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoHideSyncDL, _i18n("Settings.Taskbar.tip_sync_desktop_list", "Hide/show the desktop list panel with the widget"))
    $iY += 26

    ; Sync window list
    $__g_CD_idChkAutoHideSyncWL = __CD_CreateCheckbox(_i18n("Settings.Taskbar.chk_sync_window_list", "Also sync window list"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoHideSyncWL, _i18n("Settings.Taskbar.tip_sync_window_list", "Hide/show the window list with the widget"))
    $iY += 34

    ; Hidden threshold
    Local $idLbl5 = GUICtrlCreateLabel(_i18n("Settings.Taskbar.lbl_threshold", "Hidden threshold (px):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl5, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl5, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl5, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl5)
    $__g_CD_idInpAutoHideThreshold = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHideThreshold, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHideThreshold, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHideThreshold, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHideThreshold)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHideThreshold)
    _Theme_SetTooltip($__g_CD_idInpAutoHideThreshold, _i18n("Settings.Taskbar.tip_threshold", "Pixels of visible taskbar edge to consider it hidden (1-20)"))
    $iY += 30

    ; Recheck count
    Local $idLbl6 = GUICtrlCreateLabel(_i18n("Settings.Taskbar.lbl_recheck", "Recheck interval:"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl6, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl6, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl6, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl6)
    $__g_CD_idInpAutoHideRecheck = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHideRecheck, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHideRecheck, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHideRecheck, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHideRecheck)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHideRecheck)
    _Theme_SetTooltip($__g_CD_idInpAutoHideRecheck, _i18n("Settings.Taskbar.tip_recheck", "Re-check auto-hide mode setting every N poll cycles (1-100)"))
    $iY += 34

    ; Skip when dialog open
    $__g_CD_idChkAutoHideSkipDialog = __CD_CreateCheckbox(_i18n("Settings.Taskbar.chk_skip_dialog", "Skip when dialog open"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoHideSkipDialog, _i18n("Settings.Taskbar.tip_skip_dialog", "Don't hide widget while Settings or About dialog is open"))
EndFunc

Func __CD_BuildTabTray()
    Local $t = 14, $iX = 20, $iY = 94
    Local $idLbl

    ; -- Click Actions section --
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Tray.section_clicks", "Click Actions"), $iX, $iY, 300, 18)
    GUICtrlSetFont($idLbl, 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $iY += 24

    $__g_CD_idLblTrayLeftClick = __CD_CreateCycleLabel(_i18n("Settings.Tray.lbl_left_click", "Left click:"), $iX, $iY, 145, 130, $t)
    _Theme_SetTooltip($__g_CD_idLblTrayLeftClick, _i18n("Settings.Tray.tip_left_click", "Action when left-clicking the tray icon"))
    $iY += 28

    $__g_CD_idLblTrayDoubleClick = __CD_CreateCycleLabel(_i18n("Settings.Tray.lbl_double_click", "Double click:"), $iX, $iY, 145, 130, $t)
    _Theme_SetTooltip($__g_CD_idLblTrayDoubleClick, _i18n("Settings.Tray.tip_double_click", "Action when double-clicking the tray icon"))
    $iY += 28

    $__g_CD_idLblTrayMiddleClick = __CD_CreateCycleLabel(_i18n("Settings.Tray.lbl_middle_click", "Middle click:"), $iX, $iY, 145, 130, $t)
    _Theme_SetTooltip($__g_CD_idLblTrayMiddleClick, _i18n("Settings.Tray.tip_middle_click", "Action when middle-clicking the tray icon"))
    $iY += 34

    ; -- Tooltip section --
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Tray.section_tooltip", "Tooltip"), $iX, $iY, 300, 18)
    GUICtrlSetFont($idLbl, 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $iY += 24

    $__g_CD_idChkTrayTooltipLabel = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_tooltip_label", "Show desktop label in tooltip"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayTooltipLabel, _i18n("Settings.Tray.tip_tooltip_label", "Append the desktop label name to the tray tooltip"))
    $iY += 26

    $__g_CD_idChkTrayTooltipCount = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_tooltip_count", "Show desktop count in tooltip"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayTooltipCount, _i18n("Settings.Tray.tip_tooltip_count", "Append current/total count (e.g. 3/5) to the tray tooltip"))
    $iY += 34

    ; -- Menu Visibility section --
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Tray.section_menu", "Menu Items"), $iX, $iY, 300, 18)
    GUICtrlSetFont($idLbl, 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $iY += 24

    $__g_CD_idChkTrayMenuList = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_menu_list", "Show Desktop List"), $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkTrayMenuEdit = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_menu_edit", "Rename Desktop"), $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkTrayMenuAdd = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_menu_add", "Add Desktop"), $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkTrayMenuDelete = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_menu_delete", "Delete Desktop"), $iX, $iY, 300, $t)
    $iY += 26
    $__g_CD_idChkTrayMenuDesktopSub = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_menu_desktop_sub", "Desktop quick-switch submenu"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayMenuDesktopSub, _i18n("Settings.Tray.tip_menu_desktop_sub", "Add a submenu listing all desktops for quick switching"))
    $iY += 26
    $__g_CD_idChkTrayMenuMoveWin = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_menu_move_win", "Move window to Desktop submenu"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayMenuMoveWin, _i18n("Settings.Tray.tip_menu_move_win", "Add a submenu to move the active window to another desktop"))
    $iY += 34

    ; -- Notifications section --
    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Tray.section_notify", "Balloon Notifications"), $iX, $iY, 300, 18)
    GUICtrlSetFont($idLbl, 8, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $iY += 24

    $__g_CD_idChkTrayNotifySwitch = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_notify_switch", "Balloon on desktop switch"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayNotifySwitch, _i18n("Settings.Tray.tip_notify_switch", "Show a balloon notification when switching desktops"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Tray.lbl_balloon_dur", "Balloon duration (ms):"), $iX, $iY + 2, 165, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpTrayBalloonDur = GUICtrlCreateInput("", $iX + 170, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpTrayBalloonDur, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpTrayBalloonDur, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpTrayBalloonDur, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpTrayBalloonDur)
    __CD_RegCtrl($t, $__g_CD_idInpTrayBalloonDur)
    _Theme_SetTooltip($__g_CD_idInpTrayBalloonDur, _i18n("Settings.Tray.tip_balloon_dur", "Balloon display time in milliseconds (500-10000)"))
    $iY += 34

    ; -- Close Behavior --
    $__g_CD_idChkTrayCloseToTray = __CD_CreateCheckbox(_i18n("Settings.Tray.chk_close_to_tray", "Close minimizes to tray"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkTrayCloseToTray, _i18n("Settings.Tray.tip_close_to_tray", "Closing the window minimizes to tray instead of quitting"))
EndFunc

; =============================================
; POPULATE FROM CONFIG
; =============================================

Func __CD_BuildTabAnimations()
    Local $t = 8, $iX = 20, $iY = 94

    $__g_CD_idChkAnimEnabled = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_enabled", "Enable animations"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAnimEnabled, _i18n("Settings.Animations.tip_enabled", "Master toggle for all fade-in/fade-out animations"))
    $iY += 28

    ; Per-location toggles
    $__g_CD_idChkAnimList = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_list", "Desktop list"), $iX + 20, $iY, 130, $t)
    $__g_CD_idChkAnimMenus = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_menus", "Menus"), $iX + 155, $iY, 100, $t)
    $__g_CD_idChkAnimDialogs = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_dialogs", "Dialogs"), $iX + 260, $iY, 100, $t)
    $iY += 24
    $__g_CD_idChkAnimToasts = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_toasts", "Toasts"), $iX + 20, $iY, 130, $t)
    $__g_CD_idChkAnimWidget = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_widget", "Widget"), $iX + 155, $iY, 100, $t)
    $iY += 34

    Local $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_in", "Fade-in duration (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeIn = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeIn, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeIn, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeIn, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpFadeIn)
    __CD_RegCtrl($t, $__g_CD_idInpFadeIn)
    _Theme_SetTooltip($__g_CD_idInpFadeIn, _i18n("Settings.Animations.tip_fade_in", "Total time for fade-in effect in milliseconds (0 = instant)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_out", "Fade-out duration (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeOut = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeOut, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeOut, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeOut, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpFadeOut)
    __CD_RegCtrl($t, $__g_CD_idInpFadeOut)
    _Theme_SetTooltip($__g_CD_idInpFadeOut, _i18n("Settings.Animations.tip_fade_out", "Total time for fade-out effect in milliseconds (0 = instant)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_step", "Fade step (alpha, 5-255):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeStep = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeStep, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeStep, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeStep, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpFadeStep)
    __CD_RegCtrl($t, $__g_CD_idInpFadeStep)
    _Theme_SetTooltip($__g_CD_idInpFadeStep, _i18n("Settings.Animations.tip_fade_step", "Alpha increment per frame (higher = faster, fewer frames)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_sleep", "Frame delay (ms, 1-50):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpFadeSleep = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpFadeSleep, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpFadeSleep, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpFadeSleep, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpFadeSleep)
    __CD_RegCtrl($t, $__g_CD_idInpFadeSleep)
    _Theme_SetTooltip($__g_CD_idInpFadeSleep, _i18n("Settings.Animations.tip_fade_sleep", "Sleep between fade frames (lower = smoother but more CPU)"))
    $iY += 28

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_toast_fade", "Toast fade-out (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpToastFadeOut = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpToastFadeOut, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpToastFadeOut, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpToastFadeOut, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpToastFadeOut)
    __CD_RegCtrl($t, $__g_CD_idInpToastFadeOut)
    _Theme_SetTooltip($__g_CD_idInpToastFadeOut, _i18n("Settings.Animations.tip_toast_fade", "Duration of toast notification fade-out in milliseconds"))
    $iY += 28

    Local $idLblTP = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_toast_position", "Toast position:"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLblTP, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLblTP, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLblTP, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLblTP)
    $__g_CD_idLblToastPosition = GUICtrlCreateCombo("", $iX + 180, $iY, 120, 22, 0x0003) ; CBS_DROPDOWNLIST
    GUICtrlSetFont($__g_CD_idLblToastPosition, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($__g_CD_idLblToastPosition, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idLblToastPosition, $THEME_BG_INPUT)
    GUICtrlSetCursor($__g_CD_idLblToastPosition, 0)
    __CD_RegCtrl($t, $__g_CD_idLblToastPosition)
    _Theme_SetTooltip($__g_CD_idLblToastPosition, _i18n("Settings.Animations.tip_toast_position", "Where toast notifications appear (widget = near widget)"))
    $iY += 34

    ; Taskbar auto-hide fade
    $__g_CD_idChkAutoHideFade = __CD_CreateCheckbox(_i18n("Settings.Animations.chk_use_fade", "Use fade animation (taskbar auto-hide)"), $iX, $iY, 300, $t)
    _Theme_SetTooltip($__g_CD_idChkAutoHideFade, _i18n("Settings.Animations.tip_use_fade", "Fade widget in/out instead of instant show/hide"))
    $iY += 26

    $idLbl = GUICtrlCreateLabel(_i18n("Settings.Animations.lbl_fade_duration", "Fade duration (ms):"), $iX, $iY + 2, 175, 18)
    GUICtrlSetFont($idLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idLbl, $GUI_BKCOLOR_TRANSPARENT)
    __CD_RegCtrl($t, $idLbl)
    $__g_CD_idInpAutoHideFadeDur = GUICtrlCreateInput("", $iX + 180, $iY, 80, 22, $ES_NUMBER)
    GUICtrlSetFont($__g_CD_idInpAutoHideFadeDur, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idInpAutoHideFadeDur, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idInpAutoHideFadeDur, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idInpAutoHideFadeDur)
    __CD_RegCtrl($t, $__g_CD_idInpAutoHideFadeDur)
    _Theme_SetTooltip($__g_CD_idInpAutoHideFadeDur, _i18n("Settings.Animations.tip_fade_duration", "How long the fade animation takes (10-1000)"))
EndFunc

Func __CD_PopulateControls()
    Local $i
    ; General
    __CD_SetCheckState($__g_CD_idChkStartWin, _Cfg_GetStartWithWindows())
    __CD_SetCheckState($__g_CD_idChkWrapNav, _Cfg_GetWrapNavigation())
    __CD_SetCheckState($__g_CD_idChkAutoCreate, _Cfg_GetAutoCreateDesktop())
    GUICtrlSetData($__g_CD_idInpPadding, _Cfg_GetNumberPadding())
    GUICtrlSetData($__g_CD_idLblPosition, __CD_LocalizeOptionValue("Options.widget_position", _Cfg_GetWidgetPosition()))
    ; Populate language dropdown with all available locales
    Local $sLangCode = _Cfg_GetLanguage()
    Local $sAllDisplay = _i18n_GetAvailableDisplay()
    Local $sCurrentDisplay = ""
    ; Build combo items (pipe-delimited) and find current
    Local $aLangs = StringSplit($sAllDisplay, "|")
    Local $sComboList = ""
    Local $iL
    For $iL = 1 To $aLangs[0]
        If $sComboList <> "" Then $sComboList &= "|"
        $sComboList &= $aLangs[$iL]
        If StringLeft($aLangs[$iL], StringLen($sLangCode)) = $sLangCode Then $sCurrentDisplay = $aLangs[$iL]
    Next
    GUICtrlSetData($__g_CD_idLblLanguage, $sComboList, $sCurrentDisplay)
    GUICtrlSetData($__g_CD_idComboOverlay, " " & $sCurrentDisplay & "  " & ChrW(0x25BE))
    GUICtrlSetData($__g_CD_idInpOffsetX, _Cfg_GetWidgetOffsetX())
    GUICtrlSetData($__g_CD_idInpOffsetY, _Cfg_GetWidgetOffsetY())
    GUICtrlSetData($__g_CD_idInpWidgetWidth, _Cfg_GetWidgetWidth())
    GUICtrlSetData($__g_CD_idInpWidgetHeight, _Cfg_GetWidgetHeight())
    __CD_SetCheckState($__g_CD_idChkWidgetDrag, _Cfg_GetWidgetDragEnabled())
    __CD_SetCheckState($__g_CD_idChkWidgetColorBar, _Cfg_GetWidgetColorBar())
    GUICtrlSetData($__g_CD_idInpColorBarH, _Cfg_GetWidgetColorBarHeight())
    __CD_SetLocalizedOptions($__g_CD_idCmbColorBarAnim, "Options.color_bar_anim", $CD_OPT_COLOR_BAR_ANIM, _Cfg_GetWidgetColorBarAnim())
    GUICtrlSetData($__g_CD_idInpColorBarAnimDur, _Cfg_GetWidgetColorBarAnimDuration())
    __CD_SetCheckState($__g_CD_idChkTrayMode, _Cfg_GetTrayIconMode())
    __CD_SetCheckState($__g_CD_idChkQuickAccess, _Cfg_GetQuickAccessEnabled())
    __CD_SetCheckState($__g_CD_idChkListKeyNav, _Cfg_GetListKeyboardNav())

    ; Display
    __CD_SetCheckState($__g_CD_idChkShowCount, _Cfg_GetShowCount())
    GUICtrlSetData($__g_CD_idInpCountFont, _Cfg_GetCountFontSize())
    GUICtrlSetData($__g_CD_idInpOpacity, _Cfg_GetThemeAlphaMain())
    __CD_SetLocalizedOptions($__g_CD_idLblTheme, "Options.theme", $CD_OPT_THEME, _Cfg_GetTheme())
    __CD_SetCheckState($__g_CD_idChkThumbnails, _Cfg_GetThumbnailsEnabled())
    GUICtrlSetData($__g_CD_idInpThumbW, _Cfg_GetThumbnailWidth())
    GUICtrlSetData($__g_CD_idInpThumbH, _Cfg_GetThumbnailHeight())
    __CD_SetCheckState($__g_CD_idChkThumbScreenshot, _Cfg_GetThumbnailUseScreenshot())
    GUICtrlSetData($__g_CD_idInpThumbCacheTTL, _Cfg_GetThumbnailCacheTTL())
    GUICtrlSetData($__g_CD_idInpListFont, _Cfg_GetListFontName())
    GUICtrlSetData($__g_CD_idInpListFontSize, _Cfg_GetListFontSize())
    GUICtrlSetData($__g_CD_idInpTooltipFontSize, _Cfg_GetTooltipFontSize())
    __CD_SetCheckState($__g_CD_idChkDLShowNumbers, _Cfg_GetDesktopListShowNumbers())
    __CD_SetCheckState($__g_CD_idChkListScrollable, _Cfg_GetListScrollable())
    GUICtrlSetData($__g_CD_idInpListMaxVisible, _Cfg_GetListMaxVisible())
    GUICtrlSetData($__g_CD_idInpListScrollSpeed, _Cfg_GetListScrollSpeed())

    ; Scroll
    __CD_SetCheckState($__g_CD_idChkScroll, _Cfg_GetScrollEnabled())
    GUICtrlSetData($__g_CD_idLblScrollDir, __CD_LocalizeOptionValue("Options.scroll_direction", _Cfg_GetScrollDirection()))
    __CD_SetCheckState($__g_CD_idChkScrollWrap, _Cfg_GetScrollWrap())
    __CD_SetCheckState($__g_CD_idChkListScroll, _Cfg_GetListScrollEnabled())
    __CD_SetLocalizedOptions($__g_CD_idLblListAction, "Options.list_action", $CD_OPT_LIST_ACTION, _Cfg_GetListScrollAction())

    ; Hotkeys
    __CD_SetCheckState($__g_CD_idChkHotkeysEnabled, _Cfg_GetHotkeysEnabled())
    GUICtrlSetData($__g_CD_idInpHkNext, _Cfg_GetHotkeyNext())
    GUICtrlSetData($__g_CD_idInpHkPrev, _Cfg_GetHotkeyPrev())
    For $i = 1 To 9
        GUICtrlSetData($__g_CD_aidInpHkDesktop[$i], _Cfg_GetHotkeyDesktop($i))
    Next
    GUICtrlSetData($__g_CD_idInpHkToggleList, _Cfg_GetHotkeyToggleList())
    GUICtrlSetData($__g_CD_idInpHkSlideshow, _Cfg_GetHotkeyToggleSlideshow())

    ; Behavior
    __CD_SetCheckState($__g_CD_idChkConfirmDel, _Cfg_GetConfirmDelete())
    __CD_SetCheckState($__g_CD_idChkMidClick, _Cfg_GetMiddleClickDelete())
    __CD_SetCheckState($__g_CD_idChkMoveWin, _Cfg_GetMoveWindowEnabled())
    __CD_SetCheckState($__g_CD_idChkMoveHereClick, _Cfg_GetMoveHereClickEnabled())
    GUICtrlSetData($__g_CD_idInpPeekDelay, _Cfg_GetPeekBounceDelay())
    GUICtrlSetData($__g_CD_idInpAutoHide, _Cfg_GetAutoHideTimeout())
    GUICtrlSetData($__g_CD_idInpTopmost, _Cfg_GetTopmostInterval())
    GUICtrlSetData($__g_CD_idInpCmDelay, _Cfg_GetCmAutoHideDelay())
    __CD_SetCheckState($__g_CD_idChkConfigWatcher, _Cfg_GetConfigWatcherEnabled())
    GUICtrlSetData($__g_CD_idInpWatcherInterval, _Cfg_GetConfigWatcherInterval())
    GUICtrlSetData($__g_CD_idInpCtxDelay, _Cfg_GetCtxAutoHideDelay())
    __CD_SetCheckState($__g_CD_idChkConfirmQuit, _Cfg_GetConfirmQuit())
    __CD_SetCheckState($__g_CD_idChkConfirmRestart, _Cfg_GetConfirmRestart())
    __CD_SetCheckState($__g_CD_idChkDebugMode, _Cfg_GetDebugMode())
    __CD_SetCheckState($__g_CD_idChkDisableNativeOsd, _Cfg_GetDisableNativeOsd())
    __CD_SetCheckState($__g_CD_idChkPinningEnabled, _Cfg_GetPinningEnabled())

    ; Slideshow
    __CD_SetCheckState($__g_CD_idChkSlideshowEnabled, _Cfg_GetSlideshowEnabled())
    GUICtrlSetData($__g_CD_idInpSlideshowInterval, _Cfg_GetSlideshowInterval())
    __CD_SetLocalizedOptions($__g_CD_idCmbSlideshowSelMode, "Options.slideshow_selection_mode", $CD_OPT_SLIDESHOW_SELMODE, _Cfg_GetSlideshowSelectionMode())
    __CD_SetLocalizedOptions($__g_CD_idCmbSlideshowDirection, "Options.slideshow_direction", $CD_OPT_SLIDESHOW_DIRECTION, _Cfg_GetSlideshowDirection())
    GUICtrlSetData($__g_CD_idInpSlideshowNameFilter, _Cfg_GetSlideshowNameFilter())
    GUICtrlSetData($__g_CD_idInpSlideshowSequence, _Cfg_GetSlideshowSequence())
    GUICtrlSetData($__g_CD_idInpSlideshowDesktopIntervals, _Cfg_GetSlideshowDesktopIntervals())
    __CD_SetLocalizedOptions($__g_CD_idCmbSlideshowLoopMode, "Options.slideshow_loop_mode", $CD_OPT_SLIDESHOW_LOOPMODE, _Cfg_GetSlideshowLoopMode())
    GUICtrlSetData($__g_CD_idInpSlideshowLoopCount, _Cfg_GetSlideshowLoopCount())
    GUICtrlSetData($__g_CD_idInpSlideshowLoopDuration, _Cfg_GetSlideshowLoopDuration())
    __CD_SetCheckState($__g_CD_idChkSlideshowAutostart, _Cfg_GetSlideshowAutostart())
    GUICtrlSetData($__g_CD_idInpSlideshowAutostartDelay, _Cfg_GetSlideshowAutostartDelay())
    __CD_SetCheckState($__g_CD_idChkSlideshowMenu, _Cfg_GetSlideshowShowInMenu())
    __CD_SetCheckState($__g_CD_idChkNotifySlideshow, _Cfg_GetNotifySlideshowToggle())
    __CD_SetCheckState($__g_CD_idChkSlideshowBreakManual, _Cfg_GetSlideshowBreakOnManualSwitch())
    __CD_SetCheckState($__g_CD_idChkSlideshowBreakWidget, _Cfg_GetSlideshowBreakOnWidgetClick())
    __CD_SetCheckState($__g_CD_idChkSlideshowBreakHotkey, _Cfg_GetSlideshowBreakOnHotkey())
    __CD_SetCheckState($__g_CD_idChkSlideshowBreakInput, _Cfg_GetSlideshowBreakOnAnyInput())

    ; Rules engine
    __CD_SetCheckState($__g_CD_idChkRulesEnabled, _Cfg_GetRulesEnabled())
    GUICtrlSetData($__g_CD_idInpRulesPollInterval, _Cfg_GetRulesPollInterval())
    Local $sIniPath = _Cfg_GetPath()
    Local $r
    For $r = 1 To $__g_CD_iRuleRowCount
        Local $sRule = IniRead($sIniPath, "Rules", "rule_" & $r, "")
        If $sRule <> "" Then
            ; Parse rule format: "process.exe|N" or "class:ClassName|N"
            Local $aParts = StringSplit($sRule, "|")
            If $aParts[0] >= 2 Then
                Local $sPattern = $aParts[1]
                Local $sDesk = $aParts[2]
                If StringLeft(StringLower($sPattern), 6) = "class:" Then
                    GUICtrlSetData($__g_CD_aidRuleType[$r], _i18n("Settings.Behavior.rule_type_class", "Class"))
                    GUICtrlSetData($__g_CD_aidRulePattern[$r], StringMid($sPattern, 7))
                Else
                    GUICtrlSetData($__g_CD_aidRuleType[$r], _i18n("Settings.Behavior.rule_type_process", "Process"))
                    GUICtrlSetData($__g_CD_aidRulePattern[$r], $sPattern)
                EndIf
                GUICtrlSetData($__g_CD_aidRuleDesktop[$r], $sDesk)
            EndIf
        Else
            GUICtrlSetData($__g_CD_aidRuleType[$r], _i18n("Settings.Behavior.rule_type_process", "Process"))
            GUICtrlSetData($__g_CD_aidRulePattern[$r], "")
            GUICtrlSetData($__g_CD_aidRuleDesktop[$r], "")
        EndIf
    Next

    ; Logging
    __CD_SetCheckState($__g_CD_idChkLogging, _Cfg_GetLoggingEnabled())
    GUICtrlSetData($__g_CD_idInpLogPath, _Cfg_GetLogFolder())
    __CD_SetLocalizedOptions($__g_CD_idLblLogLevel, "Options.log_level", $CD_OPT_LOG_LEVEL, _Cfg_GetLogLevel())
    GUICtrlSetData($__g_CD_idInpLogMaxSize, _Cfg_GetLogMaxSizeMB())
    GUICtrlSetData($__g_CD_idInpLogRotateCount, _Cfg_GetLogRotateCount())
    __CD_SetCheckState($__g_CD_idChkLogCompress, _Cfg_GetLogCompressOld())
    __CD_SetCheckState($__g_CD_idChkLogPID, _Cfg_GetLogIncludePID())
    __CD_SetLocalizedOptions($__g_CD_idLblLogDateFormat, "Options.log_date_format", $CD_OPT_LOG_DATE, _Cfg_GetLogDateFormat())
    __CD_SetCheckState($__g_CD_idChkLogFlush, _Cfg_GetLogFlushImmediate())

    ; Updates
    __CD_SetCheckState($__g_CD_idChkAutoUpdate, _Cfg_GetAutoUpdateEnabled())
    GUICtrlSetData($__g_CD_idInpUpdateInterval, _Cfg_GetAutoUpdateIntervalHours())
    __CD_SetCheckState($__g_CD_idChkUpdateOnStartup, _Cfg_GetUpdateCheckOnStartup())
    GUICtrlSetData($__g_CD_idInpUpdateCheckDays, _Cfg_GetUpdateCheckDays())
    _CD_RefreshUpdateStatusLabels()

    ; Desktops
    __CD_SetCheckState($__g_CD_idChkColorsEnabled, _Cfg_GetDesktopColorsEnabled())
    For $i = 1 To $__g_CD_iDeskCount
        GUICtrlSetData($__g_CD_aidDeskLabel[$i], _Labels_Load($i))
        Local $iClr = _Cfg_GetDesktopColor($i)
        If $iClr > 0 Then
            GUICtrlSetData($__g_CD_aidDeskColor[$i], Hex($iClr, 6))
            GUICtrlSetBkColor($__g_CD_aidDeskPreview[$i], $iClr)
        Else
            GUICtrlSetData($__g_CD_aidDeskColor[$i], "")
            GUICtrlSetBkColor($__g_CD_aidDeskPreview[$i], $THEME_BG_INPUT)
        EndIf
    Next

    ; Animations
    __CD_SetCheckState($__g_CD_idChkAnimEnabled, _Cfg_GetAnimationsEnabled())
    __CD_SetCheckState($__g_CD_idChkAnimList, _Cfg_GetAnimList())
    __CD_SetCheckState($__g_CD_idChkAnimMenus, _Cfg_GetAnimMenus())
    __CD_SetCheckState($__g_CD_idChkAnimDialogs, _Cfg_GetAnimDialogs())
    __CD_SetCheckState($__g_CD_idChkAnimToasts, _Cfg_GetAnimToasts())
    __CD_SetCheckState($__g_CD_idChkAnimWidget, _Cfg_GetAnimWidget())
    GUICtrlSetData($__g_CD_idInpFadeIn, _Cfg_GetFadeInDuration())
    GUICtrlSetData($__g_CD_idInpFadeOut, _Cfg_GetFadeOutDuration())
    GUICtrlSetData($__g_CD_idInpFadeStep, _Cfg_GetFadeStep())
    GUICtrlSetData($__g_CD_idInpFadeSleep, _Cfg_GetFadeSleepMs())
    GUICtrlSetData($__g_CD_idInpToastFadeOut, _Cfg_GetToastFadeOutDuration())

    ; General extras
    __CD_SetCheckState($__g_CD_idChkSingleton, _Cfg_GetSingletonEnabled())
    __CD_SetCheckState($__g_CD_idChkTaskbarFocus, _Cfg_GetTaskbarFocusTrick())
    __CD_SetCheckState($__g_CD_idChkAutoFocus, _Cfg_GetAutoFocusAfterSwitch())
    __CD_SetCheckState($__g_CD_idChkStartMinimized, _Cfg_GetStartMinimized())
    __CD_SetCheckState($__g_CD_idChkDisableWinWidgets, _Cfg_GetDisableWinWidgets())
    GUICtrlSetData($__g_CD_idInpMinDesktops, _Cfg_GetMinDesktops())
    GUICtrlSetData($__g_CD_idInpMaxDesktops, _Cfg_GetMaxDesktops())

    ; Hotkeys extras
    GUICtrlSetData($__g_CD_idInpHkLastDesktop, _Cfg_GetHotkeyToggleLast())
    GUICtrlSetData($__g_CD_idInpHkMoveFollowNext, _Cfg_GetHotkeyMoveFollowNext())
    GUICtrlSetData($__g_CD_idInpHkMoveFollowPrev, _Cfg_GetHotkeyMoveFollowPrev())
    GUICtrlSetData($__g_CD_idInpHkMoveToNext, _Cfg_GetHotkeyMoveNext())
    GUICtrlSetData($__g_CD_idInpHkMoveToPrev, _Cfg_GetHotkeyMovePrev())
    GUICtrlSetData($__g_CD_idInpHkSendToNew, _Cfg_GetHotkeySendNewDesktop())
    GUICtrlSetData($__g_CD_idInpHkPinWindow, _Cfg_GetHotkeyPinWindow())
    GUICtrlSetData($__g_CD_idInpHkToggleWL, _Cfg_GetHotkeyToggleWindowList())
    GUICtrlSetData($__g_CD_idInpHkOpenSettings, _Cfg_GetHotkeyOpenSettings())
    GUICtrlSetData($__g_CD_idInpHkAddDesktop, _Cfg_GetHotkeyAddDesktop())
    GUICtrlSetData($__g_CD_idInpHkDeleteDesktop, _Cfg_GetHotkeyDeleteDesktop())
    GUICtrlSetData($__g_CD_idInpHkRenameDesktop, _Cfg_GetHotkeyRenameDesktop())
    GUICtrlSetData($__g_CD_idInpHkCloseWindow, _Cfg_GetHotkeyCloseWindow())
    GUICtrlSetData($__g_CD_idInpHkMinimizeWindow, _Cfg_GetHotkeyMinimizeWindow())
    GUICtrlSetData($__g_CD_idInpHkTaskView, _Cfg_GetHotkeyTaskView())
    GUICtrlSetData($__g_CD_idInpHkMaximizeWindow, _Cfg_GetHotkeyMaximizeWindow())
    GUICtrlSetData($__g_CD_idInpHkRestoreWindow, _Cfg_GetHotkeyRestoreWindow())
    GUICtrlSetData($__g_CD_idInpHkGatherWindows, _Cfg_GetHotkeyGatherWindows())
    GUICtrlSetData($__g_CD_idInpHkToggleRules, _Cfg_GetHotkeyToggleRules())
    GUICtrlSetData($__g_CD_idInpHkToggleSession, _Cfg_GetHotkeyToggleSession())
    GUICtrlSetData($__g_CD_idInpHkToggleOsd, _Cfg_GetHotkeyToggleOsd())
    GUICtrlSetData($__g_CD_idInpHkToggleWidget, _Cfg_GetHotkeyToggleWidget())
    GUICtrlSetData($__g_CD_idInpHkLoadNextProfile, _Cfg_GetHotkeyLoadNextProfile())
    GUICtrlSetData($__g_CD_idInpHkLoadPrevProfile, _Cfg_GetHotkeyLoadPrevProfile())
    GUICtrlSetData($__g_CD_idInpHkSwapDesktops, _Cfg_GetHotkeySwapDesktops())
    For $i = 1 To 9
        GUICtrlSetData($__g_CD_aidInpHkMoveToDesktop[$i], _Cfg_GetHotkeyMoveToDesktop($i))
    Next

    ; Wallpaper (integrated into desktop rows)
    __CD_SetCheckState($__g_CD_idChkWallpaper, _Cfg_GetWallpaperEnabled())
    GUICtrlSetData($__g_CD_idInpWallpaperDelay, _Cfg_GetWallpaperChangeDelay())
    For $i = 1 To $__g_CD_iDeskCount
        GUICtrlSetData($__g_CD_aidWallpaperPath[$i], _Cfg_GetDesktopWallpaper($i))
    Next

    ; Window List
    __CD_SetCheckState($__g_CD_idChkWLEnabled, _Cfg_GetWindowListEnabled())
    __CD_SetLocalizedOptions($__g_CD_idLblWLPosition, "Options.panel_position", $CD_OPT_PANEL_POS, _Cfg_GetWindowListPosition())
    GUICtrlSetData($__g_CD_idInpWLWidth, _Cfg_GetWindowListWidth())
    GUICtrlSetData($__g_CD_idInpWLMaxVisible, _Cfg_GetWindowListMaxVisible())
    __CD_SetCheckState($__g_CD_idChkWLSearch, _Cfg_GetWindowListSearch())
    __CD_SetCheckState($__g_CD_idChkWLAutoRefresh, _Cfg_GetWindowListAutoRefresh())
    GUICtrlSetData($__g_CD_idInpWLRefreshInterval, _Cfg_GetWindowListRefreshInterval())
    __CD_SetCheckState($__g_CD_idChkWLDraggable, _Cfg_GetWindowListDraggable())

    ; Explorer
    __CD_SetCheckState($__g_CD_idChkExplorerMonitor, _Cfg_GetExplorerMonitorEnabled())
    GUICtrlSetData($__g_CD_idInpShellProcess, _Cfg_GetShellProcessName())
    GUICtrlSetData($__g_CD_idInpExplorerInterval, _Cfg_GetExplorerCheckInterval())
    __CD_SetCheckState($__g_CD_idChkAutoRestart, _Cfg_GetMonitorAutoRestart())
    GUICtrlSetData($__g_CD_idInpRestartDelay, _Cfg_GetMonitorRestartDelay())
    GUICtrlSetData($__g_CD_idInpMaxRetries, _Cfg_GetMonitorMaxRetries())
    GUICtrlSetData($__g_CD_idInpRetryDelay, _Cfg_GetMonitorRetryDelay())
    __CD_SetCheckState($__g_CD_idChkExpBackoff, _Cfg_GetMonitorExpBackoff())
    GUICtrlSetData($__g_CD_idInpMaxRetryDelay, _Cfg_GetMonitorMaxRetryDelay())
    __CD_SetCheckState($__g_CD_idChkExplorerNotify, _Cfg_GetExplorerNotifyRecovery())

    ; Notifications
    __CD_SetCheckState($__g_CD_idChkNotificationsEnabled, _Cfg_GetNotificationsEnabled())
    __CD_SetCheckState($__g_CD_idChkNotifyMoved, _Cfg_GetNotifyWindowMoved())
    __CD_SetCheckState($__g_CD_idChkNotifyCreated, _Cfg_GetNotifyDesktopCreated())
    __CD_SetCheckState($__g_CD_idChkNotifyDeleted, _Cfg_GetNotifyDesktopDeleted())
    __CD_SetCheckState($__g_CD_idChkNotifyPinned, _Cfg_GetNotifyWindowPinned())
    __CD_SetCheckState($__g_CD_idChkNotifyUnpinned, _Cfg_GetNotifyWindowUnpinned())
    __CD_SetCheckState($__g_CD_idChkNotifyExplorerRecov, _Cfg_GetNotifyExplorerRecovery())
    __CD_SetLocalizedOptions($__g_CD_idLblWLScope, "Options.window_scope", $CD_OPT_WINDOW_SCOPE, _Cfg_GetWindowListScope())

    ; Notifications extras
    __CD_SetCheckState($__g_CD_idChkNotifyExplorerCrash, _Cfg_GetNotifyExplorerCrash())

    ; OSD Toast
    __CD_SetCheckState($__g_CD_idChkOsdEnabled, _Cfg_GetOsdEnabled())
    __CD_SetCheckState($__g_CD_idChkOsdShowName, _Cfg_GetOsdShowName())
    __CD_SetCheckState($__g_CD_idChkOsdShowNumber, _Cfg_GetOsdShowNumber())
    GUICtrlSetData($__g_CD_idInpOsdDuration, _Cfg_GetOsdDuration())
    __CD_SetLocalizedOptions($__g_CD_idCycOsdPosition, "Options.osd_position", $CD_OPT_OSD_POS, _Cfg_GetOsdPosition())
    GUICtrlSetData($__g_CD_idInpOsdFontSize, _Cfg_GetOsdFontSize())
    GUICtrlSetData($__g_CD_idInpOsdOpacity, _Cfg_GetOsdOpacity())
    GUICtrlSetData($__g_CD_idInpOsdFormat, _Cfg_GetOsdFormat())
    GUICtrlSetData($__g_CD_idInpOsdWidth, _Cfg_GetOsdWidth())

    ; Animations extras
    __CD_SetLocalizedOptions($__g_CD_idLblToastPosition, "Options.toast_position", $CD_OPT_TOAST_POS, _Cfg_GetToastPosition())
    __CD_SetCheckState($__g_CD_idChkAutoHideFade, _Cfg_GetAutoHideUseFade())
    GUICtrlSetData($__g_CD_idInpAutoHideFadeDur, _Cfg_GetAutoHideFadeDuration())

    ; Taskbar Auto-Hide
    __CD_SetCheckState($__g_CD_idChkAutoHideSync, _Cfg_GetAutoHideSyncEnabled())
    GUICtrlSetData($__g_CD_idInpAutoHidePoll, _Cfg_GetAutoHidePollInterval())
    GUICtrlSetData($__g_CD_idInpAutoHideHideDelay, _Cfg_GetAutoHideHideDelay())
    GUICtrlSetData($__g_CD_idInpAutoHideShowDelay, _Cfg_GetAutoHideShowDelay())
    __CD_SetCheckState($__g_CD_idChkAutoHideSyncDL, _Cfg_GetAutoHideSyncDesktopList())
    __CD_SetCheckState($__g_CD_idChkAutoHideSyncWL, _Cfg_GetAutoHideSyncWindowList())
    GUICtrlSetData($__g_CD_idInpAutoHideThreshold, _Cfg_GetAutoHideHiddenThreshold())
    GUICtrlSetData($__g_CD_idInpAutoHideRecheck, _Cfg_GetAutoHideRecheckCount())
    __CD_SetCheckState($__g_CD_idChkAutoHideSkipDialog, _Cfg_GetAutoHideSkipIfDialog())

    ; Tray
    GUICtrlSetData($__g_CD_idLblTrayLeftClick, __CD_LocalizeOptionValue("Options.tray_left_click", _Cfg_GetTrayLeftClick()))
    GUICtrlSetData($__g_CD_idLblTrayDoubleClick, __CD_LocalizeOptionValue("Options.tray_double_click", _Cfg_GetTrayDoubleClick()))
    GUICtrlSetData($__g_CD_idLblTrayMiddleClick, __CD_LocalizeOptionValue("Options.tray_middle_click", _Cfg_GetTrayMiddleClick()))
    __CD_SetCheckState($__g_CD_idChkTrayTooltipLabel, _Cfg_GetTrayTooltipShowLabel())
    __CD_SetCheckState($__g_CD_idChkTrayTooltipCount, _Cfg_GetTrayTooltipShowCount())
    __CD_SetCheckState($__g_CD_idChkTrayMenuList, _Cfg_GetTrayMenuShowList())
    __CD_SetCheckState($__g_CD_idChkTrayMenuEdit, _Cfg_GetTrayMenuShowEdit())
    __CD_SetCheckState($__g_CD_idChkTrayMenuAdd, _Cfg_GetTrayMenuShowAdd())
    __CD_SetCheckState($__g_CD_idChkTrayMenuDelete, _Cfg_GetTrayMenuShowDelete())
    __CD_SetCheckState($__g_CD_idChkTrayMenuDesktopSub, _Cfg_GetTrayMenuShowDesktopSub())
    __CD_SetCheckState($__g_CD_idChkTrayMenuMoveWin, _Cfg_GetTrayMenuShowMoveWindow())
    __CD_SetCheckState($__g_CD_idChkTrayNotifySwitch, _Cfg_GetTrayNotifySwitch())
    GUICtrlSetData($__g_CD_idInpTrayBalloonDur, _Cfg_GetTrayBalloonDuration())
    __CD_SetCheckState($__g_CD_idChkTrayCloseToTray, _Cfg_GetTrayCloseToTray())
EndFunc

; =============================================
; BLOCKING MESSAGE LOOP
; =============================================

; =============================================
; SETTINGS SEARCH (t1-e11)
; =============================================
; Search box in the dialog chrome finds settings by keyword across all tabs and
; sub-tabs. Matching runs against a prebuilt registry (no i18n lookups or control
; reads per keystroke) so typing never stalls. Bulk show/hide reuses e8's
; nesting-safe __CD_LockBegin/End so results never flicker.

; -- Registry population ----------------------------------------------

Func __CD_SearchReset()
    $__g_CD_iSearchCount = 0
    $__g_CD_iSearchResultCount = 0
EndFunc

; Appends one searchable entry. Pure (array writes only) — unit-testable.
Func __CD_SearchAdd($idCtrl, $iTab, $iSub, $sRow, $sLabel, $sTip, $iRestoreBg)
    If $__g_CD_iSearchCount >= $__g_CD_SEARCH_MAX Then Return
    Local $i = $__g_CD_iSearchCount
    $__g_CD_aSearchCtrl[$i] = $idCtrl
    $__g_CD_aSearchTab[$i] = $iTab
    $__g_CD_aSearchSub[$i] = $iSub
    $__g_CD_aSearchRow[$i] = $sRow
    $__g_CD_aSearchTip[$i] = $sTip
    $__g_CD_aSearchBlob[$i] = StringLower($sLabel & " " & $sTip)
    $__g_CD_aSearchRestoreBg[$i] = $iRestoreBg
    $__g_CD_iSearchCount = $i + 1
EndFunc

; Collapses a tooltip into a single-line description for the dim second row line.
; Newlines/tabs/runs of whitespace become single spaces; over-long text is cut with an
; ellipsis so the label never spills. Returns "" when there is no tooltip (fallback:
; the row shows only its tab path). Pure — unit-testable.
Func __CD_SearchFormatDesc($sTip, $iMaxChars = 78)
    Local $s = StringStripWS($sTip, 3)
    If $s = "" Then Return ""
    $s = StringReplace($s, @CRLF, " ")
    $s = StringReplace($s, @LF, " ")
    $s = StringReplace($s, @CR, " ")
    $s = StringReplace($s, @TAB, " ")
    ; collapse any run of spaces to one
    While StringInStr($s, "  ")
        $s = StringReplace($s, "  ", " ")
    WEnd
    $s = StringStripWS($s, 3)
    If StringLen($s) > $iMaxChars Then $s = StringLeft($s, $iMaxChars - 1) & ChrW(0x2026)
    Return $s
EndFunc

; Flash phase for an elapsed time: floor(elapsed / step). Even phases show the highlight,
; odd phases restore, and phase >= $__g_CD_PULSE_PHASES means the flash is finished.
; Pure — unit-testable.
Func __CD_PulsePhaseAt($iElapsed, $iStep = $__g_CD_PULSE_STEP)
    If $iStep < 1 Then $iStep = 1
    Return Int($iElapsed / $iStep)
EndFunc

; True if a flash phase is a "highlight on" phase (even). Pure — unit-testable.
Func __CD_PulseIsOn($iPhase)
    Return (Mod($iPhase, 2) = 0)
EndFunc

; True if any registry entry belongs to $iTab (test/coverage helper).
Func __CD_SearchTabContributes($iTab)
    Local $i
    For $i = 0 To $__g_CD_iSearchCount - 1
        If $__g_CD_aSearchTab[$i] = $iTab Then Return True
    Next
    Return False
EndFunc

; Case-insensitive substring match over the prebuilt registry blobs. An empty or
; whitespace-only query yields zero results. Fills $__g_CD_aSearchResultIdx and
; returns the count. Pure over the registry globals — unit-testable.
Func __CD_SearchMatch($sQuery)
    $__g_CD_iSearchResultCount = 0
    Local $sQ = StringLower(StringStripWS($sQuery, 3))
    If $sQ = "" Then Return 0
    Local $i
    For $i = 0 To $__g_CD_iSearchCount - 1
        If StringInStr($__g_CD_aSearchBlob[$i], $sQ, 0) > 0 Then
            $__g_CD_aSearchResultIdx[$__g_CD_iSearchResultCount] = $i
            $__g_CD_iSearchResultCount += 1
            If $__g_CD_iSearchResultCount >= $__g_CD_SEARCH_MAX Then ExitLoop
        EndIf
    Next
    Return $__g_CD_iSearchResultCount
EndFunc

; Sets the active sub-tab/page global for $iTab so a following __CD_SwitchTab
; lands on $iSub. Pure (writes globals only) — unit-testable navigation mapping.
Func __CD_SetActiveSubForTab($iTab, $iSub)
    If $iSub < 1 Then Return
    Switch $iTab
        Case 1
            $__g_CD_iGenActiveSub = $iSub
        Case 2
            $__g_CD_iDispActiveSub = $iSub
        Case 3
            $__g_CD_iHkActiveSub = $iSub
        Case 4
            $__g_CD_iBhvActiveSub = $iSub
        Case 7
            $__g_CD_iDeskPage = $iSub
    EndSwitch
EndFunc

; -- Harvest helpers (GUI-side; run once after the dialog is built) ----

Func __CD_SearchFindTab($idCtrl, ByRef $iCtrlIdx)
    Local $t, $c
    For $t = 1 To 14
        For $c = 0 To $__g_CD_aiTabCtrlCount[$t] - 1
            If $__g_CD_aidTabCtrls[$t][$c] = $idCtrl Then
                $iCtrlIdx = $c
                Return $t
            EndIf
        Next
    Next
    $iCtrlIdx = -1
    Return 0
EndFunc

Func __CD_SearchInArray($idCtrl, ByRef $aArr, $iCount)
    Local $i
    For $i = 0 To $iCount - 1
        If $aArr[$i] = $idCtrl Then Return True
    Next
    Return False
EndFunc

Func __CD_SearchFindSub($idCtrl, $iTab)
    Switch $iTab
        Case 1
            If __CD_SearchInArray($idCtrl, $__g_CD_aGenWidgetCtrls, $__g_CD_iGenWidgetCount) Then Return 1
            If __CD_SearchInArray($idCtrl, $__g_CD_aGenDesktopCtrls, $__g_CD_iGenDesktopCount) Then Return 2
            If __CD_SearchInArray($idCtrl, $__g_CD_aGenSystemCtrls, $__g_CD_iGenSystemCount) Then Return 3
            If __CD_SearchInArray($idCtrl, $__g_CD_aGenScrollCtrls, $__g_CD_iGenScrollCount) Then Return 4
        Case 2
            If __CD_SearchInArray($idCtrl, $__g_CD_aDispAppearanceCtrls, $__g_CD_iDispAppearanceCount) Then Return 1
            If __CD_SearchInArray($idCtrl, $__g_CD_aDispThumbnailsCtrls, $__g_CD_iDispThumbnailsCount) Then Return 2
        Case 3
            If __CD_SearchInArray($idCtrl, $__g_CD_aHkNavCtrls, $__g_CD_iHkNavCount) Then Return 1
            If __CD_SearchInArray($idCtrl, $__g_CD_aHkWinCtrls, $__g_CD_iHkWinCount) Then Return 2
            If __CD_SearchInArray($idCtrl, $__g_CD_aHkDeskCtrls, $__g_CD_iHkDeskCount) Then Return 3
            If __CD_SearchInArray($idCtrl, $__g_CD_aHkSendCtrls, $__g_CD_iHkSendCount) Then Return 4
            If __CD_SearchInArray($idCtrl, $__g_CD_aHkActionsCtrls, $__g_CD_iHkActionsCount) Then Return 5
        Case 4
            If __CD_SearchInArray($idCtrl, $__g_CD_aBhvInteractCtrls, $__g_CD_iBhvInteractCount) Then Return 1
            If __CD_SearchInArray($idCtrl, $__g_CD_aBhvTimersCtrls, $__g_CD_iBhvTimersCount) Then Return 2
            If __CD_SearchInArray($idCtrl, $__g_CD_aBhvSlideshowCtrls, $__g_CD_iBhvSlideshowCount) Then Return 3
            If __CD_SearchInArray($idCtrl, $__g_CD_aBhvRulesCtrls, $__g_CD_iBhvRulesCount) Then Return 4
    EndSwitch
    Return 0
EndFunc

Func __CD_SearchChkText($idCtrl)
    Local $i
    For $i = 1 To $__g_CD_iChkCount
        If $__g_CD_aChkIDs[$i] = $idCtrl Then Return $__g_CD_aChkTexts[$i]
    Next
    Return ""
EndFunc

; Returns the localized sub-tab / page button caption for the display row, or "".
Func __CD_GetSubLabel($iTab, $iSub)
    If $iSub < 1 Then Return ""
    Local $id = 0
    Switch $iTab
        Case 1
            Local $a1[5] = [0, $__g_CD_idGenSubWidget, $__g_CD_idGenSubDesktop, $__g_CD_idGenSubSystem, $__g_CD_idGenSubScroll]
            If $iSub <= 4 Then $id = $a1[$iSub]
        Case 2
            Local $a2[3] = [0, $__g_CD_idDispSubAppearance, $__g_CD_idDispSubThumbnails]
            If $iSub <= 2 Then $id = $a2[$iSub]
        Case 3
            Local $a3[6] = [0, $__g_CD_idHkSubNav, $__g_CD_idHkSubWin, $__g_CD_idHkSubDesk, $__g_CD_idHkSubSend, $__g_CD_idHkSubActions]
            If $iSub <= 5 Then $id = $a3[$iSub]
        Case 4
            Local $a4[5] = [0, $__g_CD_idBhvSubInteract, $__g_CD_idBhvSubTimers, $__g_CD_idBhvSubSlideshow, $__g_CD_idBhvSubRules]
            If $iSub <= 4 Then $id = $a4[$iSub]
        Case 7
            If $iSub <= $__g_CD_iDeskPageCount Then $id = $__g_CD_aidDeskPageBtn[$iSub]
    EndSwitch
    If $id = 0 Then Return ""
    Return StringStripWS(GUICtrlRead($id), 3)
EndFunc

; Harvests {control, tab, sub-tab, label, tooltip} for every tooltip'd setting into
; the registry. Foreign tooltips (widget/menu) are skipped by tab-membership. Runs
; once per dialog open. Not headless — logic is exercised at runtime + build.
Func __CD_BuildSearchIndex()
    __CD_SearchReset()
    Local $i, $iCtrlIdx, $iTab, $iSub, $sLabel, $sTip, $idCtrl, $iRestoreBg, $sRow, $sSub
    For $i = 1 To $__g_Theme_iTipCount
        $idCtrl = $__g_Theme_aTipIDs[$i]
        If $idCtrl = 0 Then ContinueLoop
        $iCtrlIdx = -1
        $iTab = __CD_SearchFindTab($idCtrl, $iCtrlIdx)
        If $iTab = 0 Then ContinueLoop ; not a ConfigDialog setting control (foreign tooltip)
        $iSub = __CD_SearchFindSub($idCtrl, $iTab)
        $sTip = $__g_Theme_aTipTexts[$i]
        ; Label = checkbox text, else the descriptive label registered just before it.
        $sLabel = __CD_SearchChkText($idCtrl)
        $iRestoreBg = $THEME_BG_INPUT
        If $sLabel <> "" Then
            $iRestoreBg = $GUI_BKCOLOR_TRANSPARENT ; checkbox labels are transparent
        Else
            If $iCtrlIdx > 0 Then
                Local $sPrev = GUICtrlRead($__g_CD_aidTabCtrls[$iTab][$iCtrlIdx - 1])
                If $sPrev <> "" And Not StringInStr($sPrev, "[ ]") And Not StringInStr($sPrev, "[x]") Then _
                    $sLabel = StringStripWS($sPrev, 3)
            EndIf
            If $sLabel = "" Then $sLabel = $sTip ; last resort: tooltip doubles as label
        EndIf
        ; Display row: "Tab > Sub > Label"
        $sSub = __CD_GetSubLabel($iTab, $iSub)
        $sRow = __CD_GetMainTabLabel($iTab)
        If $sSub <> "" Then $sRow &= "  " & ChrW(0x203A) & "  " & $sSub
        $sRow &= "  " & ChrW(0x203A) & "  " & StringStripWS(StringReplace($sLabel, ":", ""), 3)
        __CD_SearchAdd($idCtrl, $iTab, $iSub, $sRow, $sLabel, $sTip, $iRestoreBg)
    Next
    _Log_Debug("Settings search: indexed " & $__g_CD_iSearchCount & " settings")
EndFunc

; -- Search UI (chrome input + overlay results panel) -----------------

Func __CD_SetCueBanner($idCtrl, $sText)
    Local $h = GUICtrlGetHandle($idCtrl)
    If $h = 0 Then Return
    Local $tText = DllStructCreate("wchar[" & (StringLen($sText) + 1) & "]")
    DllStructSetData($tText, 1, $sText)
    ; EM_SETCUEBANNER (0x1501), wParam=True keeps the cue visible while focused
    DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $h, "uint", 0x1501, "wparam", True, "struct*", $tText)
EndFunc

Func __CD_BuildSearchUI()
    Local $iW = 540
    ; Search input sits in the trailing gap of the 3rd tab row (tabs 11-14 end at x=424).
    $__g_CD_idSearchInput = GUICtrlCreateInput("", 428, 56, 104, 22)
    GUICtrlSetFont($__g_CD_idSearchInput, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idSearchInput, $THEME_FG_TEXT)
    GUICtrlSetBkColor($__g_CD_idSearchInput, $THEME_BG_INPUT)
    _Theme_FlattenInput($__g_CD_idSearchInput)
    __CD_SetCueBanner($__g_CD_idSearchInput, _i18n("Settings.Search.lbl_search", "Search settings..."))
    _Theme_SetTooltip($__g_CD_idSearchInput, _i18n("Settings.Search.tip_search", "Type to find settings by name across all tabs"))

    ; Results panel overlays the content area, hidden until the user types.
    Local $iPx = 8, $iPy = 84, $iPw = $iW - 16, $iPh = $__g_CD_iContentH
    $__g_CD_idSearchPanelBg = GUICtrlCreateLabel("", $iPx, $iPy, $iPw, $iPh)
    GUICtrlSetBkColor($__g_CD_idSearchPanelBg, $THEME_BG_POPUP)
    GUICtrlSetState($__g_CD_idSearchPanelBg, $GUI_HIDE)

    $__g_CD_idSearchCountLbl = GUICtrlCreateLabel("", $iPx + 8, $iPy + 6, $iPw - 16, 18)
    GUICtrlSetFont($__g_CD_idSearchCountLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($__g_CD_idSearchCountLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($__g_CD_idSearchCountLbl, $THEME_BG_POPUP)
    GUICtrlSetState($__g_CD_idSearchCountLbl, $GUI_HIDE)

    ; Two-line result rows: line 1 = "Tab > Sub > Label" (primary), line 2 = a dim
    ; single-line description harvested from the setting's tooltip. Both lines are
    ; clickable so the whole row navigates. The description label carries a themed
    ; tooltip (updated in place per filter) so hovering a truncated description shows
    ; the full text — the "elaborate" gesture, reusing the existing tooltip mechanism.
    Local $iRy = $iPy + 28, $r
    For $r = 0 To $__g_CD_SEARCH_ROWS - 1
        $__g_CD_aidSearchRowLbl[$r] = GUICtrlCreateLabel("", $iPx + 8, $iRy, $iPw - 16, 18, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidSearchRowLbl[$r], 9, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidSearchRowLbl[$r], $THEME_FG_MENU)
        GUICtrlSetBkColor($__g_CD_aidSearchRowLbl[$r], $THEME_BG_POPUP)
        GUICtrlSetCursor($__g_CD_aidSearchRowLbl[$r], 0)
        GUICtrlSetState($__g_CD_aidSearchRowLbl[$r], $GUI_HIDE)

        $__g_CD_aidSearchDescLbl[$r] = GUICtrlCreateLabel("", $iPx + 8, $iRy + 17, $iPw - 16, 15, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
        GUICtrlSetFont($__g_CD_aidSearchDescLbl[$r], 8, 400, 0, $THEME_FONT_MAIN)
        GUICtrlSetColor($__g_CD_aidSearchDescLbl[$r], $THEME_FG_DIM)
        GUICtrlSetBkColor($__g_CD_aidSearchDescLbl[$r], $THEME_BG_POPUP)
        GUICtrlSetCursor($__g_CD_aidSearchDescLbl[$r], 0)
        GUICtrlSetState($__g_CD_aidSearchDescLbl[$r], $GUI_HIDE)
        ; Reserve a themed-tooltip slot for this description row. Guard the 199-cap:
        ; only remember the slot if the registration actually took (else in-place text
        ; updates would clobber a foreign entry).
        Local $iBeforeTip = $__g_Theme_iTipCount
        _Theme_SetTooltip($__g_CD_aidSearchDescLbl[$r], "")
        If $__g_Theme_iTipCount > $iBeforeTip Then
            $__g_CD_aiSearchRowTipSlot[$r] = $__g_Theme_iTipCount
        Else
            $__g_CD_aiSearchRowTipSlot[$r] = 0
        EndIf

        $__g_CD_aSearchRowEntry[$r] = -1
        $iRy += 36
    Next
EndFunc

; -- Results panel show/hide/filter -----------------------------------

Func __CD_SearchHideResults()
    If Not $__g_CD_bSearchResultsVisible Then Return
    __CD_LockBegin()
    GUICtrlSetState($__g_CD_idSearchPanelBg, $GUI_HIDE)
    GUICtrlSetState($__g_CD_idSearchCountLbl, $GUI_HIDE)
    Local $r
    For $r = 0 To $__g_CD_SEARCH_ROWS - 1
        GUICtrlSetState($__g_CD_aidSearchRowLbl[$r], $GUI_HIDE)
        GUICtrlSetState($__g_CD_aidSearchDescLbl[$r], $GUI_HIDE)
    Next
    __CD_LockEnd()
    $__g_CD_bSearchResultsVisible = False
    $__g_CD_iSearchRowHovered = 0
EndFunc

Func __CD_SearchClear()
    GUICtrlSetData($__g_CD_idSearchInput, "")
    $__g_CD_sSearchLast = ""
    __CD_SearchHideResults()
EndFunc

; Reads the input, matches, and repaints the results panel in one locked span.
Func __CD_SearchApplyFilter()
    Local $sQuery = GUICtrlRead($__g_CD_idSearchInput)
    If StringStripWS($sQuery, 3) = "" Then
        __CD_SearchHideResults()
        Return
    EndIf
    __CD_SearchMatch($sQuery)

    __CD_LockBegin()
    GUICtrlSetState($__g_CD_idSearchPanelBg, $GUI_SHOW)
    If $__g_CD_iSearchResultCount = 0 Then
        GUICtrlSetData($__g_CD_idSearchCountLbl, _i18n("Settings.Search.lbl_no_results", "No settings match"))
    Else
        GUICtrlSetData($__g_CD_idSearchCountLbl, _i18n_Format("Settings.Search.lbl_results_count", "{1} matches", $__g_CD_iSearchResultCount))
    EndIf
    GUICtrlSetState($__g_CD_idSearchCountLbl, $GUI_SHOW)
    Local $r
    For $r = 0 To $__g_CD_SEARCH_ROWS - 1
        If $r < $__g_CD_iSearchResultCount Then
            Local $iEntry = $__g_CD_aSearchResultIdx[$r]
            $__g_CD_aSearchRowEntry[$r] = $iEntry
            GUICtrlSetData($__g_CD_aidSearchRowLbl[$r], "  " & $__g_CD_aSearchRow[$iEntry])
            GUICtrlSetColor($__g_CD_aidSearchRowLbl[$r], $THEME_FG_MENU)
            GUICtrlSetBkColor($__g_CD_aidSearchRowLbl[$r], $THEME_BG_POPUP)
            GUICtrlSetState($__g_CD_aidSearchRowLbl[$r], $GUI_SHOW)
            ; Description line (dim). Empty when the setting has no tooltip: the row then
            ; shows only its tab path (graceful fallback).
            Local $sTip = $__g_CD_aSearchTip[$iEntry]
            GUICtrlSetData($__g_CD_aidSearchDescLbl[$r], "  " & __CD_SearchFormatDesc($sTip))
            GUICtrlSetColor($__g_CD_aidSearchDescLbl[$r], $THEME_FG_DIM)
            GUICtrlSetBkColor($__g_CD_aidSearchDescLbl[$r], $THEME_BG_POPUP)
            GUICtrlSetState($__g_CD_aidSearchDescLbl[$r], $GUI_SHOW)
            ; Full (untruncated) tooltip on hover-to-elaborate, updated in place — no new
            ; registry entries per keystroke, so the 199-cap is never touched here.
            If $__g_CD_aiSearchRowTipSlot[$r] > 0 Then $__g_Theme_aTipTexts[$__g_CD_aiSearchRowTipSlot[$r]] = $sTip
        Else
            $__g_CD_aSearchRowEntry[$r] = -1
            GUICtrlSetState($__g_CD_aidSearchRowLbl[$r], $GUI_HIDE)
            GUICtrlSetState($__g_CD_aidSearchDescLbl[$r], $GUI_HIDE)
            If $__g_CD_aiSearchRowTipSlot[$r] > 0 Then $__g_Theme_aTipTexts[$__g_CD_aiSearchRowTipSlot[$r]] = ""
        EndIf
    Next
    __CD_LockEnd()
    $__g_CD_bSearchResultsVisible = True
    $__g_CD_iSearchRowHovered = 0
EndFunc

; -- Highlight flash on the navigated-to control ---------------------

; Begins a multi-cycle flash on the target control: its background toggles between
; $THEME_BG_HOVER and its normal colour a few times so the eye catches it. Time-driven
; (the message loop ticks it) — no Sleep, so the dialog stays responsive.
Func __CD_SearchStartPulse($idCtrl, $iRestoreBg)
    If $__g_CD_iPulseCtrl <> 0 Then GUICtrlSetBkColor($__g_CD_iPulseCtrl, $__g_CD_iPulseRestoreBg)
    $__g_CD_iPulseCtrl = $idCtrl
    $__g_CD_iPulseRestoreBg = $iRestoreBg
    $__g_CD_hPulseTimer = TimerInit()
    $__g_CD_iPulsePhase = 0
    GUICtrlSetBkColor($idCtrl, $THEME_BG_HOVER) ; phase 0 = highlight on
EndFunc

; Advances the flash. Called every message-loop pass (no Sleep). Recolours only when the
; phase actually changes, and restores + clears once all phases have elapsed.
Func __CD_SearchTickHighlight()
    If $__g_CD_iPulseCtrl = 0 Then Return
    Local $iPhase = __CD_PulsePhaseAt(TimerDiff($__g_CD_hPulseTimer))
    If $iPhase = $__g_CD_iPulsePhase Then Return
    $__g_CD_iPulsePhase = $iPhase
    If $iPhase >= $__g_CD_PULSE_PHASES Then
        GUICtrlSetBkColor($__g_CD_iPulseCtrl, $__g_CD_iPulseRestoreBg)
        $__g_CD_iPulseCtrl = 0
        $__g_CD_iPulsePhase = -1
        Return
    EndIf
    If __CD_PulseIsOn($iPhase) Then
        GUICtrlSetBkColor($__g_CD_iPulseCtrl, $THEME_BG_HOVER)
    Else
        GUICtrlSetBkColor($__g_CD_iPulseCtrl, $__g_CD_iPulseRestoreBg)
    EndIf
EndFunc

; Pure decision: given a GUIGetMsg event while the results panel is open, should the
; panel close? Only a genuine click qualifies -- a click on some other control
; (positive control id that is neither the search input nor a result row) or a click
; on the dialog background ($GUI_EVENT_PRIMARYDOWN/$GUI_EVENT_SECONDARYDOWN). Mouse
; movement ($GUI_EVENT_MOUSEMOVE), button-up events, the no-event idle (id 0), a click
; on a result row, or a click on the search input all keep the panel open. This is what
; lets results survive mere mouse motion over the dialog.
Func __CD_SearchShouldCloseOnClick($id, $bRowClicked, $idSearchInput)
    If $bRowClicked Then Return False           ; clicked a result row -> navigate handles it
    If $id = $idSearchInput Then Return False    ; clicked/focused the search input
    If $id > 0 Then Return True                  ; clicked some other control -> real click-away
    If $id = $GUI_EVENT_PRIMARYDOWN Or $id = $GUI_EVENT_SECONDARYDOWN Then Return True
    Return False                                 ; mouse-move / up-event / idle -> keep open
EndFunc

; Navigate to a result: switch to its tab/sub-tab, close the panel, pulse the target.
Func __CD_SearchNavigate($iEntry)
    If $iEntry < 0 Or $iEntry >= $__g_CD_iSearchCount Then Return
    Local $iTab = $__g_CD_aSearchTab[$iEntry]
    Local $iSub = $__g_CD_aSearchSub[$iEntry]
    __CD_SetActiveSubForTab($iTab, $iSub)
    __CD_SearchClear()
    __CD_SwitchTab($iTab)
    __CD_SearchStartPulse($__g_CD_aSearchCtrl[$iEntry], $__g_CD_aSearchRestoreBg[$iEntry])
EndFunc

Func __CD_MessageLoop()
    Local $iHovered = 0, $iTabHovered = 0, $t

    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $__g_CD_hGUI Then
            Local $id = $aMsg[0]
            Switch $id
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $__g_CD_idBtnApply
                    __CD_ApplyChanges()
                Case $__g_CD_idBtnReset
                    __CD_ResetDefaults()
                Case $__g_CD_idBtnImport
                    __CD_ImportSettings()
                Case $__g_CD_idBtnExport
                    __CD_ExportSettings()
                Case $__g_CD_idBtnRestart
                    __CD_RestartApp()
                    ExitLoop
                Case $__g_CD_idBtnClose
                    ExitLoop
                Case $__g_CD_idBtnCheckNow
                    ; _UC_CheckNow shows its own centered top-most popup with progress;
                    ; keep Settings in place (no @SW_HIDE/@SW_SHOW flash) and just restore
                    ; the current-GUI context afterwards. GUICtrlSetState disables the
                    ; button to block re-entry while the modal check runs.
                    GUICtrlSetState($__g_CD_idBtnCheckNow, $GUI_DISABLE)
                    _UC_CheckNow()
                    GUICtrlSetState($__g_CD_idBtnCheckNow, $GUI_ENABLE)
                    GUISwitch($__g_CD_hGUI)
                    _CD_RefreshUpdateStatusLabels()
                Case $__g_CD_idBtnDownloadLatest
                    GUICtrlSetState($__g_CD_idBtnDownloadLatest, $GUI_DISABLE)
                    _UC_DownloadPortable()
                    GUICtrlSetState($__g_CD_idBtnDownloadLatest, $GUI_ENABLE)
                    GUISwitch($__g_CD_hGUI)
                    _CD_RefreshUpdateStatusLabels()
                Case $__g_CD_idBtnLogBrowse
                    Local $sFolder = FileSelectFolder("Select log folder", "", 7, GUICtrlRead($__g_CD_idInpLogPath), $__g_CD_hGUI)
                    If $sFolder <> "" Then GUICtrlSetData($__g_CD_idInpLogPath, $sFolder)
            EndSwitch

            ; Wallpaper browse button clicks
            Local $iBrowseIdx
            For $iBrowseIdx = 1 To $__g_CD_iDeskCount
                If $id = $__g_CD_aidWallpaperBrowse[$iBrowseIdx] Then
                    Local $sWpFile = FileOpenDialog("Select wallpaper", "", "Images (*.jpg;*.jpeg;*.png;*.bmp)", 1, "", $__g_CD_hGUI)
                    If $sWpFile <> "" Then GUICtrlSetData($__g_CD_aidWallpaperPath[$iBrowseIdx], $sWpFile)
                    ExitLoop
                EndIf
            Next

            ; Sub-tab clicks
            If $id = $__g_CD_idGenSubWidget Then __CD_SwitchGenSub(1)
            If $id = $__g_CD_idGenSubDesktop Then __CD_SwitchGenSub(2)
            If $id = $__g_CD_idGenSubSystem Then __CD_SwitchGenSub(3)
            If $id = $__g_CD_idGenSubScroll Then __CD_SwitchGenSub(4)
            If $id = $__g_CD_idDispSubAppearance Then __CD_SwitchDispSub(1)
            If $id = $__g_CD_idDispSubThumbnails Then __CD_SwitchDispSub(2)
            If $id = $__g_CD_idBhvSubInteract Then __CD_SwitchBhvSub(1)
            If $id = $__g_CD_idBhvSubTimers Then __CD_SwitchBhvSub(2)
            If $id = $__g_CD_idBhvSubSlideshow Then __CD_SwitchBhvSub(3)
            If $id = $__g_CD_idBhvSubRules Then __CD_SwitchBhvSub(4)
            ; Desktop page buttons
            If $__g_CD_iDeskPageCount > 1 Then
                Local $dp
                For $dp = 1 To $__g_CD_iDeskPageCount
                    If $id = $__g_CD_aidDeskPageBtn[$dp] Then
                        __CD_SwitchDeskPage($dp)
                        ExitLoop
                    EndIf
                Next
            EndIf
            If $id = $__g_CD_idHkSubNav Then __CD_SwitchHkSub(1)
            If $id = $__g_CD_idHkSubWin Then __CD_SwitchHkSub(2)
            If $id = $__g_CD_idHkSubDesk Then __CD_SwitchHkSub(3)
            If $id = $__g_CD_idHkSubSend Then __CD_SwitchHkSub(4)
            If $id = $__g_CD_idHkSubActions Then __CD_SwitchHkSub(5)

            ; Tab button clicks
            For $t = 1 To 14
                If $id = $__g_CD_aidTabBtn[$t] Then
                    $iTabHovered = 0
                    __CD_SwitchTab($t)
                    ExitLoop
                EndIf
            Next

            ; Checkbox clicks (label-based, handle box + text clicks)
            __CD_HandleCheckboxClick($id)

            ; Hotkey builder "..." button clicks
            __CD_HandleHotkeyBuildClick($id)

            ; Cycle label clicks
            If $id = $__g_CD_idLblPosition Then __CD_CycleLocalizedValue($id, "Options.widget_position", $CD_OPT_WIDGET_POS)
            If $id = $__g_CD_idLblScrollDir Then __CD_CycleLocalizedValue($id, "Options.scroll_direction", $CD_OPT_SCROLL_DIR)
            If $id = $__g_CD_idLblTrayLeftClick Then __CD_CycleLocalizedValue($id, "Options.tray_left_click", $CD_OPT_TRAY_LEFT)
            If $id = $__g_CD_idLblTrayDoubleClick Then __CD_CycleLocalizedValue($id, "Options.tray_double_click", $CD_OPT_TRAY_DOUBLE)
            If $id = $__g_CD_idLblTrayMiddleClick Then __CD_CycleLocalizedValue($id, "Options.tray_middle_click", $CD_OPT_TRAY_MIDDLE)
            ; Rule type cycle labels (Process <-> Class)
            For $r = 1 To $__g_CD_iRuleRowCount
                If $id = $__g_CD_aidRuleType[$r] Then
                    Local $sCur = GUICtrlRead($__g_CD_aidRuleType[$r])
                    If $sCur = _i18n("Settings.Behavior.rule_type_process", "Process") Then
                        GUICtrlSetData($__g_CD_aidRuleType[$r], _i18n("Settings.Behavior.rule_type_class", "Class"))
                    Else
                        GUICtrlSetData($__g_CD_aidRuleType[$r], _i18n("Settings.Behavior.rule_type_process", "Process"))
                    EndIf
                    ExitLoop
                EndIf
            Next
            ; Language combo overlay click — toggle dropdown
            If $id = $__g_CD_idComboOverlay Then
                Local $hCombo = GUICtrlGetHandle($__g_CD_idLblLanguage)
                If $hCombo <> 0 Then
                    ; Save system highlight colors and override with dark theme
                    $__g_CD_iSavedHighlight = DllCall("user32.dll", "dword", "GetSysColor", "int", 13)[0] ; COLOR_HIGHLIGHT
                    $__g_CD_iSavedHighlightText = DllCall("user32.dll", "dword", "GetSysColor", "int", 14)[0] ; COLOR_HIGHLIGHTTEXT
                    Local $aElems = DllStructCreate("int[2]")
                    Local $aColors = DllStructCreate("dword[2]")
                    DllStructSetData($aElems, 1, 13, 1) ; COLOR_HIGHLIGHT
                    DllStructSetData($aElems, 1, 14, 2) ; COLOR_HIGHLIGHTTEXT
                    DllStructSetData($aColors, 1, $THEME_BG_HOVER, 1)
                    DllStructSetData($aColors, 1, $THEME_FG_WHITE, 2)
                    DllCall("user32.dll", "bool", "SetSysColors", "int", 2, "struct*", $aElems, "struct*", $aColors)
                    $__g_CD_bDropdownOpen = True
                    DllCall("user32.dll", "bool", "SendMessageW", "hwnd", $hCombo, "uint", 0x014F, "wparam", 1, "lparam", 0) ; CB_SHOWDROPDOWN
                EndIf
            EndIf
            ; Sync overlay on combo selection change
            If $id = $__g_CD_idLblLanguage Then
                GUICtrlSetData($__g_CD_idComboOverlay, " " & GUICtrlRead($__g_CD_idLblLanguage) & "  " & ChrW(0x25BE))
            EndIf

            ; Settings-search result row clicks -> navigate to that setting
            If $__g_CD_bSearchResultsVisible And $id <> 0 Then
                Local $srClicked = False, $sr
                For $sr = 0 To $__g_CD_SEARCH_ROWS - 1
                    ; either line (tab path or description) navigates the row
                    If $id = $__g_CD_aidSearchRowLbl[$sr] Or $id = $__g_CD_aidSearchDescLbl[$sr] Then
                        If $__g_CD_aSearchRowEntry[$sr] >= 0 Then __CD_SearchNavigate($__g_CD_aSearchRowEntry[$sr])
                        $srClicked = True
                        ExitLoop
                    EndIf
                Next
                ; Click-away: only a genuine click outside the input + result rows closes
                ; the panel. Mouse movement over the dialog no longer dismisses results.
                If $__g_CD_bSearchResultsVisible And __CD_SearchShouldCloseOnClick($id, $srClicked, $__g_CD_idSearchInput) Then _
                    __CD_SearchHideResults()
            EndIf
        EndIf

        ; Escape: close the results panel first (if open), otherwise close the dialog.
        ; Edge-detected so a single tap of a held key doesn't cascade both actions.
        ; Focus-gated on WinActive (guard 7): with async settings the widget's own
        ; Escape handling (drag-cancel) now runs concurrently, and pressing Escape in any
        ; other app must not close Settings — only act when the dialog is foreground.
        Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
        Local $bEscDown = (Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0)
        If $bEscDown And Not $__g_CD_bEscWasDown And WinActive($__g_CD_hGUI) Then
            If $__g_CD_bSearchResultsVisible Then
                __CD_SearchClear()
            Else
                $__g_CD_bEscWasDown = True
                ExitLoop
            EndIf
        EndIf
        $__g_CD_bEscWasDown = $bEscDown

        ; Async settings (t8-c): drive one main-loop frame so the widget/tray/DL/CM/WL,
        ; toasts/ticks, event flags, slideshow and relayed IPC stay live while Settings is
        ; open. Pass the event this loop just read and did NOT consume; pass 0/0 for
        ; CD-owned events (already handled above) and idle so widget handlers never
        ; double-process a CD control click (guard 12). Runs BEFORE GUISwitch (guard 3) so
        ; phase functions that create/switch GUIs don't clobber CD hover/cursor context.
        ; No-op string in headless tests (no callback registered).
        If $__g_CD_sCbMainTick <> "" Then
            If $aMsg[1] <> 0 And $aMsg[1] <> $__g_CD_hGUI Then
                Call($__g_CD_sCbMainTick, $aMsg[0], $aMsg[1])
            Else
                Call($__g_CD_sCbMainTick, 0, 0)
            EndIf
        EndIf

        ; Ensure ConfigDialog is the "current" GUI for GUIGetCursorInfo
        ; (tooltip creation via GUICreate switches it away, breaking $aCursor[4])
        GUISwitch($__g_CD_hGUI)

        ; Button hover
        Local $aCursor = GUIGetCursorInfo($__g_CD_hGUI)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $__g_CD_idBtnApply Then $iFound = $__g_CD_idBtnApply
            If $aCursor[4] = $__g_CD_idBtnReset Then $iFound = $__g_CD_idBtnReset
            If $aCursor[4] = $__g_CD_idBtnClose Then $iFound = $__g_CD_idBtnClose
            If $aCursor[4] = $__g_CD_idBtnImport Then $iFound = $__g_CD_idBtnImport
            If $aCursor[4] = $__g_CD_idBtnExport Then $iFound = $__g_CD_idBtnExport
            If $aCursor[4] = $__g_CD_idBtnRestart Then $iFound = $__g_CD_idBtnRestart
            If $aCursor[4] = $__g_CD_idBtnCheckNow Then $iFound = $__g_CD_idBtnCheckNow
            If $aCursor[4] = $__g_CD_idBtnDownloadLatest Then $iFound = $__g_CD_idBtnDownloadLatest
            If $aCursor[4] = $__g_CD_idBtnLogBrowse Then $iFound = $__g_CD_idBtnLogBrowse
            If $__g_CD_idComboOverlay <> 0 And $aCursor[4] = $__g_CD_idComboOverlay Then $iFound = $__g_CD_idComboOverlay
            ; Cycle labels (only remaining non-combo cycle labels)
            If $aCursor[4] = $__g_CD_idLblPosition Then $iFound = $__g_CD_idLblPosition
            If $aCursor[4] = $__g_CD_idLblScrollDir Then $iFound = $__g_CD_idLblScrollDir
            If $aCursor[4] = $__g_CD_idLblTrayLeftClick Then $iFound = $__g_CD_idLblTrayLeftClick
            If $aCursor[4] = $__g_CD_idLblTrayDoubleClick Then $iFound = $__g_CD_idLblTrayDoubleClick
            If $aCursor[4] = $__g_CD_idLblTrayMiddleClick Then $iFound = $__g_CD_idLblTrayMiddleClick
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    Local $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnReset Then $iFgRestore = 0xCC6666
                    If $iHovered = $__g_CD_idBtnImport Or $iHovered = $__g_CD_idBtnExport Then $iFgRestore = $THEME_FG_DIM
                    If $iHovered = $__g_CD_idBtnRestart Then $iFgRestore = $THEME_FG_LINK
                    If $iHovered = $__g_CD_idBtnCheckNow Then $iFgRestore = $THEME_FG_MENU
                    If $iHovered = $__g_CD_idBtnDownloadLatest Then $iFgRestore = $THEME_FG_LINK
                    If $iHovered = $__g_CD_idBtnLogBrowse Then $iFgRestore = $THEME_FG_DIM
                    If $iHovered = $__g_CD_idComboOverlay Then $iFgRestore = $THEME_FG_TEXT
                    If $iHovered = $__g_CD_idLblPosition Or $iHovered = $__g_CD_idLblScrollDir Or _
                       $iHovered = $__g_CD_idLblTrayLeftClick Or $iHovered = $__g_CD_idLblTrayDoubleClick Or _
                       $iHovered = $__g_CD_idLblTrayMiddleClick Then $iFgRestore = $THEME_FG_PRIMARY
                    Local $iBgRestore = $THEME_BG_HOVER
                    If $iHovered = $__g_CD_idComboOverlay Or $iHovered = $__g_CD_idLblPosition Or _
                       $iHovered = $__g_CD_idLblScrollDir Or $iHovered = $__g_CD_idLblTrayLeftClick Or _
                       $iHovered = $__g_CD_idLblTrayDoubleClick Or _
                       $iHovered = $__g_CD_idLblTrayMiddleClick Then $iBgRestore = $THEME_BG_INPUT
                    _Theme_RemoveHover($iHovered, $iFgRestore, $iBgRestore)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf

            ; Tab hover (inactive tabs highlight on mouseover)
            Local $iTabFound = 0
            For $t = 1 To 14
                If $aCursor[4] = $__g_CD_aidTabBtn[$t] And $t <> $__g_CD_iActiveTab Then
                    $iTabFound = $t
                    ExitLoop
                EndIf
            Next
            If $iTabFound <> $iTabHovered Then
                ; Remove old tab hover
                If $iTabHovered <> 0 And $iTabHovered <> $__g_CD_iActiveTab Then
                    GUICtrlSetColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_FG_DIM)
                    GUICtrlSetBkColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_BG_MAIN)
                EndIf
                $iTabHovered = $iTabFound
                ; Apply new tab hover
                If $iTabHovered <> 0 Then
                    GUICtrlSetColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_FG_NORMAL)
                    GUICtrlSetBkColor($__g_CD_aidTabBtn[$iTabHovered], $THEME_BG_HOVER)
                EndIf
            EndIf

            ; Sub-tab hover (mirrors main-tab hover for the active tab's sub-tab group;
            ; the active sub-tab is excluded, inactive restore = dim on main bg)
            Local $iSubHit = 0
            Switch $__g_CD_iActiveTab
                Case 1
                    Local $aGenSub[4] = [$__g_CD_idGenSubWidget, $__g_CD_idGenSubDesktop, $__g_CD_idGenSubSystem, $__g_CD_idGenSubScroll]
                    $iSubHit = __CD_SubTabHoverHit($aGenSub, 4, $__g_CD_iGenActiveSub - 1, $aCursor[4])
                Case 2
                    Local $aDispSub[2] = [$__g_CD_idDispSubAppearance, $__g_CD_idDispSubThumbnails]
                    $iSubHit = __CD_SubTabHoverHit($aDispSub, 2, $__g_CD_iDispActiveSub - 1, $aCursor[4])
                Case 3
                    Local $aHkSub[5] = [$__g_CD_idHkSubNav, $__g_CD_idHkSubWin, $__g_CD_idHkSubDesk, $__g_CD_idHkSubSend, $__g_CD_idHkSubActions]
                    $iSubHit = __CD_SubTabHoverHit($aHkSub, 5, $__g_CD_iHkActiveSub - 1, $aCursor[4])
                Case 4
                    Local $aBhvSub[4] = [$__g_CD_idBhvSubInteract, $__g_CD_idBhvSubTimers, $__g_CD_idBhvSubSlideshow, $__g_CD_idBhvSubRules]
                    $iSubHit = __CD_SubTabHoverHit($aBhvSub, 4, $__g_CD_iBhvActiveSub - 1, $aCursor[4])
                Case 7
                    If $__g_CD_iDeskPageCount > 1 Then
                        Local $aPgSub[$__g_CD_iDeskPageCount]
                        Local $pg
                        For $pg = 1 To $__g_CD_iDeskPageCount
                            $aPgSub[$pg - 1] = $__g_CD_aidDeskPageBtn[$pg]
                        Next
                        $iSubHit = __CD_SubTabHoverHit($aPgSub, $__g_CD_iDeskPageCount, $__g_CD_iDeskPage - 1, $aCursor[4])
                    EndIf
            EndSwitch
            If $iSubHit <> $__g_CD_iSubTabHovered Then
                If $__g_CD_iSubTabHovered <> 0 Then _Theme_RemoveHover($__g_CD_iSubTabHovered, $THEME_FG_DIM, $THEME_BG_MAIN)
                $__g_CD_iSubTabHovered = $iSubHit
                If $__g_CD_iSubTabHovered <> 0 Then _Theme_ApplyHover($__g_CD_iSubTabHovered, $THEME_FG_NORMAL, $THEME_BG_HOVER)
            EndIf

            ; Search result-row hover — highlight both lines of the row together.
            ; $__g_CD_iSearchRowHovered holds the 1-based row index (0 = none).
            If $__g_CD_bSearchResultsVisible Then
                Local $iRowHit = 0, $srh
                For $srh = 0 To $__g_CD_SEARCH_ROWS - 1
                    If $__g_CD_aSearchRowEntry[$srh] < 0 Then ContinueLoop
                    If $aCursor[4] = $__g_CD_aidSearchRowLbl[$srh] Or $aCursor[4] = $__g_CD_aidSearchDescLbl[$srh] Then
                        $iRowHit = $srh + 1
                        ExitLoop
                    EndIf
                Next
                If $iRowHit <> $__g_CD_iSearchRowHovered Then
                    If $__g_CD_iSearchRowHovered <> 0 Then
                        _Theme_RemoveHover($__g_CD_aidSearchRowLbl[$__g_CD_iSearchRowHovered - 1], $THEME_FG_MENU, $THEME_BG_POPUP)
                        _Theme_RemoveHover($__g_CD_aidSearchDescLbl[$__g_CD_iSearchRowHovered - 1], $THEME_FG_DIM, $THEME_BG_POPUP)
                    EndIf
                    $__g_CD_iSearchRowHovered = $iRowHit
                    If $__g_CD_iSearchRowHovered <> 0 Then
                        _Theme_ApplyHover($__g_CD_aidSearchRowLbl[$__g_CD_iSearchRowHovered - 1], $THEME_FG_WHITE, $THEME_BG_HOVER)
                        _Theme_ApplyHover($__g_CD_aidSearchDescLbl[$__g_CD_iSearchRowHovered - 1], $THEME_FG_NORMAL, $THEME_BG_HOVER)
                    EndIf
                EndIf
            EndIf
        EndIf

        ; Tick toast fade-out while dialog is open
        _Theme_ToastTick()

        ; Themed tooltip hover check
        _Theme_CheckTooltipHover($__g_CD_hGUI)

        ; Restore system highlight colors when combo dropdown closes
        If $__g_CD_bDropdownOpen Then
            Local $hCmb = GUICtrlGetHandle($__g_CD_idLblLanguage)
            If $hCmb <> 0 Then
                Local $aDropped = DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $hCmb, "uint", 0x0157, "wparam", 0, "lparam", 0) ; CB_GETDROPPEDSTATE
                If Not @error And IsArray($aDropped) And $aDropped[0] = 0 Then
                    $__g_CD_bDropdownOpen = False
                    Local $aElems2 = DllStructCreate("int[2]")
                    Local $aColors2 = DllStructCreate("dword[2]")
                    DllStructSetData($aElems2, 1, 13, 1)
                    DllStructSetData($aElems2, 1, 14, 2)
                    DllStructSetData($aColors2, 1, $__g_CD_iSavedHighlight, 1)
                    DllStructSetData($aColors2, 1, $__g_CD_iSavedHighlightText, 2)
                    DllCall("user32.dll", "bool", "SetSysColors", "int", 2, "struct*", $aElems2, "struct*", $aColors2)
                EndIf
            EndIf
        EndIf

        ; Live color preview update
        __CD_UpdateColorPreviews()

        ; Incremental settings-search filter — poll the input, refilter only on change
        ; (matches the prebuilt registry; no per-keystroke i18n or control reads).
        Local $sSearchNow = GUICtrlRead($__g_CD_idSearchInput)
        If $sSearchNow <> $__g_CD_sSearchLast Then
            $__g_CD_sSearchLast = $sSearchNow
            __CD_SearchApplyFilter()
        EndIf

        ; Restore the search-highlight pulse ~1s after navigation (no Sleep)
        __CD_SearchTickHighlight()

        ; Single sleep source: when the main tick is registered it sleeps via
        ; _ProcessTimersAndSleep (15 ms popup tier — imperceptibly above the old 10 ms),
        ; so a second Sleep here would double the loop's idle latency. Headless tests have
        ; no callback registered and keep the local 10 ms cadence.
        If $__g_CD_sCbMainTick = "" Then Sleep(10)
    WEnd

    _Theme_ClearTooltips()
    _Theme_ToastDestroy()
    _CD_Destroy()
EndFunc

; =============================================
; APPLY CHANGES
; =============================================

Func __CD_ApplyChanges()
    If $__g_CD_hGUI = 0 Then Return
    _Log_Info("Settings: applying changes")
    Local $i
    Local $bOldStartup = _Cfg_IsStartupEnabled()

    ; General
    _Cfg_SetStartWithWindows(__CD_GetCheckState($__g_CD_idChkStartWin))
    _Cfg_SetWrapNavigation(__CD_GetCheckState($__g_CD_idChkWrapNav))
    _Cfg_SetAutoCreateDesktop(__CD_GetCheckState($__g_CD_idChkAutoCreate))
    Local $s = GUICtrlRead($__g_CD_idInpPadding)
    If StringIsInt($s) Then _Cfg_SetNumberPadding(Int($s))
    _Cfg_SetWidgetPosition(__CD_DelocalizeOptionValue("Options.widget_position", $CD_OPT_WIDGET_POS, GUICtrlRead($__g_CD_idLblPosition)))
    Local $sOldLang = _Cfg_GetLanguage()
    _Cfg_SetLanguage(_i18n_DisplayToCode(GUICtrlRead($__g_CD_idLblLanguage)))
    $s = GUICtrlRead($__g_CD_idInpOffsetX)
    If $s <> "" And StringIsInt($s) Then _Cfg_SetWidgetOffsetX(Int($s))
    $s = GUICtrlRead($__g_CD_idInpOffsetY)
    If $s <> "" And StringIsInt($s) Then _Cfg_SetWidgetOffsetY(Int($s))
    $s = GUICtrlRead($__g_CD_idInpWidgetWidth)
    If StringIsInt($s) Then _Cfg_SetWidgetWidth(Int($s))
    $s = GUICtrlRead($__g_CD_idInpWidgetHeight)
    If StringIsInt($s) Then _Cfg_SetWidgetHeight(Int($s))
    _Cfg_SetWidgetDragEnabled(__CD_GetCheckState($__g_CD_idChkWidgetDrag))
    _Cfg_SetWidgetColorBar(__CD_GetCheckState($__g_CD_idChkWidgetColorBar))
    $s = GUICtrlRead($__g_CD_idInpColorBarH)
    If StringIsInt($s) Then _Cfg_SetWidgetColorBarHeight(Int($s))
    _Cfg_SetWidgetColorBarAnim(__CD_DelocalizeOptionValue("Options.color_bar_anim", $CD_OPT_COLOR_BAR_ANIM, GUICtrlRead($__g_CD_idCmbColorBarAnim)))
    $s = GUICtrlRead($__g_CD_idInpColorBarAnimDur)
    If StringIsInt($s) Then _Cfg_SetWidgetColorBarAnimDuration(Int($s))
    _Cfg_SetTrayIconMode(__CD_GetCheckState($__g_CD_idChkTrayMode))
    _Cfg_SetQuickAccessEnabled(__CD_GetCheckState($__g_CD_idChkQuickAccess))
    _Cfg_SetListKeyboardNav(__CD_GetCheckState($__g_CD_idChkListKeyNav))
    _Cfg_SetSingletonEnabled(__CD_GetCheckState($__g_CD_idChkSingleton))
    _Cfg_SetTaskbarFocusTrick(__CD_GetCheckState($__g_CD_idChkTaskbarFocus))
    _Cfg_SetAutoFocusAfterSwitch(__CD_GetCheckState($__g_CD_idChkAutoFocus))
    _Cfg_SetStartMinimized(__CD_GetCheckState($__g_CD_idChkStartMinimized))
    _Cfg_SetDisableWinWidgets(__CD_GetCheckState($__g_CD_idChkDisableWinWidgets))
    $s = GUICtrlRead($__g_CD_idInpMinDesktops)
    If StringIsInt($s) Then _Cfg_SetMinDesktops(Int($s))
    $s = GUICtrlRead($__g_CD_idInpMaxDesktops)
    If StringIsInt($s) Then _Cfg_SetMaxDesktops(Int($s))

    ; Display
    _Cfg_SetShowCount(__CD_GetCheckState($__g_CD_idChkShowCount))
    $s = GUICtrlRead($__g_CD_idInpCountFont)
    If StringIsInt($s) Then _Cfg_SetCountFontSize(Int($s))
    $s = GUICtrlRead($__g_CD_idInpOpacity)
    If StringIsInt($s) Then _Cfg_SetThemeAlphaMain(Int($s))
    Local $sOldTheme = _Cfg_GetTheme()
    _Cfg_SetTheme(__CD_DelocalizeOptionValue("Options.theme", $CD_OPT_THEME, GUICtrlRead($__g_CD_idLblTheme)))
    _Cfg_SetThumbnailsEnabled(__CD_GetCheckState($__g_CD_idChkThumbnails))
    $s = GUICtrlRead($__g_CD_idInpThumbW)
    If StringIsInt($s) Then _Cfg_SetThumbnailWidth(Int($s))
    $s = GUICtrlRead($__g_CD_idInpThumbH)
    If StringIsInt($s) Then _Cfg_SetThumbnailHeight(Int($s))
    _Cfg_SetThumbnailUseScreenshot(__CD_GetCheckState($__g_CD_idChkThumbScreenshot))
    $s = GUICtrlRead($__g_CD_idInpThumbCacheTTL)
    If StringIsInt($s) Then _Cfg_SetThumbnailCacheTTL(Int($s))
    _Cfg_SetListFontName(GUICtrlRead($__g_CD_idInpListFont))
    $s = GUICtrlRead($__g_CD_idInpListFontSize)
    If StringIsInt($s) Then _Cfg_SetListFontSize(Int($s))
    $s = GUICtrlRead($__g_CD_idInpTooltipFontSize)
    If StringIsInt($s) Then _Cfg_SetTooltipFontSize(Int($s))
    _Cfg_SetDesktopListShowNumbers(__CD_GetCheckState($__g_CD_idChkDLShowNumbers))
    _Cfg_SetListScrollable(__CD_GetCheckState($__g_CD_idChkListScrollable))
    $s = GUICtrlRead($__g_CD_idInpListMaxVisible)
    If StringIsInt($s) Then _Cfg_SetListMaxVisible(Int($s))
    $s = GUICtrlRead($__g_CD_idInpListScrollSpeed)
    If StringIsInt($s) Then _Cfg_SetListScrollSpeed(Int($s))

    ; Scroll
    _Cfg_SetScrollEnabled(__CD_GetCheckState($__g_CD_idChkScroll))
    _Cfg_SetScrollDirection(__CD_DelocalizeOptionValue("Options.scroll_direction", $CD_OPT_SCROLL_DIR, GUICtrlRead($__g_CD_idLblScrollDir)))
    _Cfg_SetScrollWrap(__CD_GetCheckState($__g_CD_idChkScrollWrap))
    _Cfg_SetListScrollEnabled(__CD_GetCheckState($__g_CD_idChkListScroll))
    _Cfg_SetListScrollAction(__CD_DelocalizeOptionValue("Options.list_action", $CD_OPT_LIST_ACTION, GUICtrlRead($__g_CD_idLblListAction)))

    ; Hotkeys
    _Cfg_SetHotkeysEnabled(__CD_GetCheckState($__g_CD_idChkHotkeysEnabled))
    _Cfg_SetHotkeyNext(GUICtrlRead($__g_CD_idInpHkNext))
    _Cfg_SetHotkeyPrev(GUICtrlRead($__g_CD_idInpHkPrev))
    For $i = 1 To 9
        _Cfg_SetHotkeyDesktop($i, GUICtrlRead($__g_CD_aidInpHkDesktop[$i]))
    Next
    _Cfg_SetHotkeyToggleList(GUICtrlRead($__g_CD_idInpHkToggleList))
    _Cfg_SetHotkeyToggleLast(GUICtrlRead($__g_CD_idInpHkLastDesktop))
    _Cfg_SetHotkeyMoveFollowNext(GUICtrlRead($__g_CD_idInpHkMoveFollowNext))
    _Cfg_SetHotkeyMoveFollowPrev(GUICtrlRead($__g_CD_idInpHkMoveFollowPrev))
    _Cfg_SetHotkeyMoveNext(GUICtrlRead($__g_CD_idInpHkMoveToNext))
    _Cfg_SetHotkeyMovePrev(GUICtrlRead($__g_CD_idInpHkMoveToPrev))
    _Cfg_SetHotkeySendNewDesktop(GUICtrlRead($__g_CD_idInpHkSendToNew))
    _Cfg_SetHotkeyPinWindow(GUICtrlRead($__g_CD_idInpHkPinWindow))
    _Cfg_SetHotkeyToggleWindowList(GUICtrlRead($__g_CD_idInpHkToggleWL))
    _Cfg_SetHotkeyOpenSettings(GUICtrlRead($__g_CD_idInpHkOpenSettings))
    _Cfg_SetHotkeyAddDesktop(GUICtrlRead($__g_CD_idInpHkAddDesktop))
    _Cfg_SetHotkeyDeleteDesktop(GUICtrlRead($__g_CD_idInpHkDeleteDesktop))
    _Cfg_SetHotkeyRenameDesktop(GUICtrlRead($__g_CD_idInpHkRenameDesktop))
    _Cfg_SetHotkeyCloseWindow(GUICtrlRead($__g_CD_idInpHkCloseWindow))
    _Cfg_SetHotkeyMinimizeWindow(GUICtrlRead($__g_CD_idInpHkMinimizeWindow))
    _Cfg_SetHotkeyToggleSlideshow(GUICtrlRead($__g_CD_idInpHkSlideshow))
    _Cfg_SetHotkeyTaskView(GUICtrlRead($__g_CD_idInpHkTaskView))
    _Cfg_SetHotkeyMaximizeWindow(GUICtrlRead($__g_CD_idInpHkMaximizeWindow))
    _Cfg_SetHotkeyRestoreWindow(GUICtrlRead($__g_CD_idInpHkRestoreWindow))
    _Cfg_SetHotkeyGatherWindows(GUICtrlRead($__g_CD_idInpHkGatherWindows))
    _Cfg_SetHotkeyToggleRules(GUICtrlRead($__g_CD_idInpHkToggleRules))
    _Cfg_SetHotkeyToggleSession(GUICtrlRead($__g_CD_idInpHkToggleSession))
    _Cfg_SetHotkeyToggleOsd(GUICtrlRead($__g_CD_idInpHkToggleOsd))
    _Cfg_SetHotkeyToggleWidget(GUICtrlRead($__g_CD_idInpHkToggleWidget))
    _Cfg_SetHotkeyLoadNextProfile(GUICtrlRead($__g_CD_idInpHkLoadNextProfile))
    _Cfg_SetHotkeyLoadPrevProfile(GUICtrlRead($__g_CD_idInpHkLoadPrevProfile))
    _Cfg_SetHotkeySwapDesktops(GUICtrlRead($__g_CD_idInpHkSwapDesktops))
    For $i = 1 To 9
        _Cfg_SetHotkeyMoveToDesktop($i, GUICtrlRead($__g_CD_aidInpHkMoveToDesktop[$i]))
    Next

    ; Behavior
    _Cfg_SetConfirmDelete(__CD_GetCheckState($__g_CD_idChkConfirmDel))
    _Cfg_SetMiddleClickDelete(__CD_GetCheckState($__g_CD_idChkMidClick))
    _Cfg_SetMoveWindowEnabled(__CD_GetCheckState($__g_CD_idChkMoveWin))
    _Cfg_SetMoveHereClickEnabled(__CD_GetCheckState($__g_CD_idChkMoveHereClick))
    $s = GUICtrlRead($__g_CD_idInpPeekDelay)
    If StringIsInt($s) Then _Cfg_SetPeekBounceDelay(Int($s))
    $s = GUICtrlRead($__g_CD_idInpAutoHide)
    If StringIsInt($s) Then _Cfg_SetAutoHideTimeout(Int($s))
    $s = GUICtrlRead($__g_CD_idInpTopmost)
    If StringIsInt($s) Then _Cfg_SetTopmostInterval(Int($s))
    $s = GUICtrlRead($__g_CD_idInpCmDelay)
    If StringIsInt($s) Then _Cfg_SetCmAutoHideDelay(Int($s))
    _Cfg_SetConfigWatcherEnabled(__CD_GetCheckState($__g_CD_idChkConfigWatcher))
    $s = GUICtrlRead($__g_CD_idInpWatcherInterval)
    If StringIsInt($s) Then _Cfg_SetConfigWatcherInterval(Int($s))
    $s = GUICtrlRead($__g_CD_idInpCtxDelay)
    If StringIsInt($s) Then _Cfg_SetCtxAutoHideDelay(Int($s))
    _Cfg_SetConfirmQuit(__CD_GetCheckState($__g_CD_idChkConfirmQuit))
    _Cfg_SetConfirmRestart(__CD_GetCheckState($__g_CD_idChkConfirmRestart))
    _Cfg_SetDebugMode(__CD_GetCheckState($__g_CD_idChkDebugMode))
    _Cfg_SetDisableNativeOsd(__CD_GetCheckState($__g_CD_idChkDisableNativeOsd))
    _Cfg_SetPinningEnabled(__CD_GetCheckState($__g_CD_idChkPinningEnabled))

    ; Slideshow. Sequence / per-desktop-intervals stored verbatim (setters clamp length);
    ; the engine parses + validates them at start time, matching the lenient input style.
    _Cfg_SetSlideshowEnabled(__CD_GetCheckState($__g_CD_idChkSlideshowEnabled))
    $s = GUICtrlRead($__g_CD_idInpSlideshowInterval)
    If StringIsInt($s) Then _Cfg_SetSlideshowInterval(Int($s))
    _Cfg_SetSlideshowSelectionMode(__CD_DelocalizeOptionValue("Options.slideshow_selection_mode", $CD_OPT_SLIDESHOW_SELMODE, GUICtrlRead($__g_CD_idCmbSlideshowSelMode)))
    _Cfg_SetSlideshowDirection(__CD_DelocalizeOptionValue("Options.slideshow_direction", $CD_OPT_SLIDESHOW_DIRECTION, GUICtrlRead($__g_CD_idCmbSlideshowDirection)))
    _Cfg_SetSlideshowNameFilter(GUICtrlRead($__g_CD_idInpSlideshowNameFilter))
    _Cfg_SetSlideshowSequence(GUICtrlRead($__g_CD_idInpSlideshowSequence))
    _Cfg_SetSlideshowDesktopIntervals(GUICtrlRead($__g_CD_idInpSlideshowDesktopIntervals))
    _Cfg_SetSlideshowLoopMode(__CD_DelocalizeOptionValue("Options.slideshow_loop_mode", $CD_OPT_SLIDESHOW_LOOPMODE, GUICtrlRead($__g_CD_idCmbSlideshowLoopMode)))
    $s = GUICtrlRead($__g_CD_idInpSlideshowLoopCount)
    If StringIsInt($s) Then _Cfg_SetSlideshowLoopCount(Int($s))
    $s = GUICtrlRead($__g_CD_idInpSlideshowLoopDuration)
    If StringIsInt($s) Then _Cfg_SetSlideshowLoopDuration(Int($s))
    _Cfg_SetSlideshowAutostart(__CD_GetCheckState($__g_CD_idChkSlideshowAutostart))
    $s = GUICtrlRead($__g_CD_idInpSlideshowAutostartDelay)
    If StringIsInt($s) Then _Cfg_SetSlideshowAutostartDelay(Int($s))
    _Cfg_SetSlideshowShowInMenu(__CD_GetCheckState($__g_CD_idChkSlideshowMenu))
    _Cfg_SetNotifySlideshowToggle(__CD_GetCheckState($__g_CD_idChkNotifySlideshow))
    _Cfg_SetSlideshowBreakOnManualSwitch(__CD_GetCheckState($__g_CD_idChkSlideshowBreakManual))
    _Cfg_SetSlideshowBreakOnWidgetClick(__CD_GetCheckState($__g_CD_idChkSlideshowBreakWidget))
    _Cfg_SetSlideshowBreakOnHotkey(__CD_GetCheckState($__g_CD_idChkSlideshowBreakHotkey))
    _Cfg_SetSlideshowBreakOnAnyInput(__CD_GetCheckState($__g_CD_idChkSlideshowBreakInput))

    ; Rules engine
    _Cfg_SetRulesEnabled(__CD_GetCheckState($__g_CD_idChkRulesEnabled))
    $s = GUICtrlRead($__g_CD_idInpRulesPollInterval)
    If StringIsInt($s) Then _Cfg_SetRulesPollInterval(Int($s))
    Local $sIniApply = _Cfg_GetPath()
    Local $r
    For $r = 1 To $__g_CD_iRuleRowCount
        Local $sPattern = StringStripWS(GUICtrlRead($__g_CD_aidRulePattern[$r]), 3)
        Local $sDesk = StringStripWS(GUICtrlRead($__g_CD_aidRuleDesktop[$r]), 3)
        If $sPattern <> "" And $sDesk <> "" Then
            Local $sType = GUICtrlRead($__g_CD_aidRuleType[$r])
            Local $sRuleVal
            If $sType = _i18n("Settings.Behavior.rule_type_class", "Class") Then
                $sRuleVal = "class:" & $sPattern & "|" & $sDesk
            Else
                $sRuleVal = $sPattern & "|" & $sDesk
            EndIf
            IniWrite($sIniApply, "Rules", "rule_" & $r, $sRuleVal)
        Else
            IniDelete($sIniApply, "Rules", "rule_" & $r)
        EndIf
    Next

    ; Logging
    _Cfg_SetLoggingEnabled(__CD_GetCheckState($__g_CD_idChkLogging))
    _Cfg_SetLogFolder(GUICtrlRead($__g_CD_idInpLogPath))
    _Cfg_SetLogLevel(__CD_DelocalizeOptionValue("Options.log_level", $CD_OPT_LOG_LEVEL, GUICtrlRead($__g_CD_idLblLogLevel)))
    $s = GUICtrlRead($__g_CD_idInpLogMaxSize)
    If StringIsInt($s) Then _Cfg_SetLogMaxSizeMB(Int($s))
    $s = GUICtrlRead($__g_CD_idInpLogRotateCount)
    If StringIsInt($s) Then _Cfg_SetLogRotateCount(Int($s))
    _Cfg_SetLogCompressOld(__CD_GetCheckState($__g_CD_idChkLogCompress))
    _Cfg_SetLogIncludePID(__CD_GetCheckState($__g_CD_idChkLogPID))
    _Cfg_SetLogDateFormat(__CD_DelocalizeOptionValue("Options.log_date_format", $CD_OPT_LOG_DATE, GUICtrlRead($__g_CD_idLblLogDateFormat)))
    _Cfg_SetLogFlushImmediate(__CD_GetCheckState($__g_CD_idChkLogFlush))

    ; Updates
    _Cfg_SetAutoUpdateEnabled(__CD_GetCheckState($__g_CD_idChkAutoUpdate))
    $s = GUICtrlRead($__g_CD_idInpUpdateInterval)
    If StringIsInt($s) Then _Cfg_SetAutoUpdateInterval(Int($s))
    _Cfg_SetUpdateCheckOnStartup(__CD_GetCheckState($__g_CD_idChkUpdateOnStartup))
    $s = GUICtrlRead($__g_CD_idInpUpdateCheckDays)
    If StringIsInt($s) Then _Cfg_SetUpdateCheckDays(Int($s))

    ; Desktops - save labels and colors
    ; Colors-enabled comes straight from its checkbox (was a one-way True latch that
    ; could never turn the feature off from the UI — audit F2).
    _Cfg_SetDesktopColorsEnabled(__CD_GetCheckState($__g_CD_idChkColorsEnabled))
    For $i = 1 To $__g_CD_iDeskCount
        Local $sLabel = GUICtrlRead($__g_CD_aidDeskLabel[$i])
        _Labels_Save($i, $sLabel)

        Local $sHex = GUICtrlRead($__g_CD_aidDeskColor[$i])
        Local $iClr = _Theme_ValidateHexColor($sHex)
        If $iClr >= 0 Then
            _Cfg_SetDesktopColor($i, $iClr)
        ElseIf $sHex = "" Then
            _Cfg_SetDesktopColor($i, 0) ; none
        EndIf
    Next

    ; Animations
    _Cfg_SetAnimationsEnabled(__CD_GetCheckState($__g_CD_idChkAnimEnabled))
    _Cfg_SetAnimList(__CD_GetCheckState($__g_CD_idChkAnimList))
    _Cfg_SetAnimMenus(__CD_GetCheckState($__g_CD_idChkAnimMenus))
    _Cfg_SetAnimDialogs(__CD_GetCheckState($__g_CD_idChkAnimDialogs))
    _Cfg_SetAnimToasts(__CD_GetCheckState($__g_CD_idChkAnimToasts))
    _Cfg_SetAnimWidget(__CD_GetCheckState($__g_CD_idChkAnimWidget))
    _Cfg_SetFadeInDuration(Int(GUICtrlRead($__g_CD_idInpFadeIn)))
    _Cfg_SetFadeOutDuration(Int(GUICtrlRead($__g_CD_idInpFadeOut)))
    _Cfg_SetFadeStep(Int(GUICtrlRead($__g_CD_idInpFadeStep)))
    _Cfg_SetFadeSleepMs(Int(GUICtrlRead($__g_CD_idInpFadeSleep)))
    _Cfg_SetToastFadeOutDuration(Int(GUICtrlRead($__g_CD_idInpToastFadeOut)))
    _Cfg_SetToastPosition(__CD_DelocalizeOptionValue("Options.toast_position", $CD_OPT_TOAST_POS, GUICtrlRead($__g_CD_idLblToastPosition)))
    _Cfg_SetAutoHideUseFade(__CD_GetCheckState($__g_CD_idChkAutoHideFade))
    _Cfg_SetAutoHideFadeDuration(Int(GUICtrlRead($__g_CD_idInpAutoHideFadeDur)))

    ; Wallpaper (integrated into desktop rows)
    _Cfg_SetWallpaperEnabled(__CD_GetCheckState($__g_CD_idChkWallpaper))
    $s = GUICtrlRead($__g_CD_idInpWallpaperDelay)
    If StringIsInt($s) Then _Cfg_SetWallpaperChangeDelay(Int($s))
    For $i = 1 To $__g_CD_iDeskCount
        _Cfg_SetDesktopWallpaper($i, GUICtrlRead($__g_CD_aidWallpaperPath[$i]))
    Next

    ; Window List
    _Cfg_SetWindowListEnabled(__CD_GetCheckState($__g_CD_idChkWLEnabled))
    _Cfg_SetWindowListPosition(__CD_DelocalizeOptionValue("Options.panel_position", $CD_OPT_PANEL_POS, GUICtrlRead($__g_CD_idLblWLPosition)))
    $s = GUICtrlRead($__g_CD_idInpWLWidth)
    If StringIsInt($s) Then _Cfg_SetWindowListWidth(Int($s))
    $s = GUICtrlRead($__g_CD_idInpWLMaxVisible)
    If StringIsInt($s) Then _Cfg_SetWindowListMaxVisible(Int($s))
    _Cfg_SetWindowListSearch(__CD_GetCheckState($__g_CD_idChkWLSearch))
    _Cfg_SetWindowListAutoRefresh(__CD_GetCheckState($__g_CD_idChkWLAutoRefresh))
    $s = GUICtrlRead($__g_CD_idInpWLRefreshInterval)
    If StringIsInt($s) Then _Cfg_SetWindowListRefreshInterval(Int($s))
    _Cfg_SetWindowListDraggable(__CD_GetCheckState($__g_CD_idChkWLDraggable))

    ; Explorer
    _Cfg_SetExplorerMonitorEnabled(__CD_GetCheckState($__g_CD_idChkExplorerMonitor))
    _Cfg_SetShellProcessName(GUICtrlRead($__g_CD_idInpShellProcess))
    $s = GUICtrlRead($__g_CD_idInpExplorerInterval)
    If StringIsInt($s) Then _Cfg_SetExplorerCheckInterval(Int($s))
    _Cfg_SetMonitorAutoRestart(__CD_GetCheckState($__g_CD_idChkAutoRestart))
    $s = GUICtrlRead($__g_CD_idInpRestartDelay)
    If StringIsInt($s) Then _Cfg_SetMonitorRestartDelay(Int($s))
    $s = GUICtrlRead($__g_CD_idInpMaxRetries)
    If StringIsInt($s) Then _Cfg_SetMonitorMaxRetries(Int($s))
    $s = GUICtrlRead($__g_CD_idInpRetryDelay)
    If StringIsInt($s) Then _Cfg_SetMonitorRetryDelay(Int($s))
    _Cfg_SetMonitorExpBackoff(__CD_GetCheckState($__g_CD_idChkExpBackoff))
    $s = GUICtrlRead($__g_CD_idInpMaxRetryDelay)
    If StringIsInt($s) Then _Cfg_SetMonitorMaxRetryDelay(Int($s))
    _Cfg_SetExplorerNotifyRecovery(__CD_GetCheckState($__g_CD_idChkExplorerNotify))

    ; Notifications
    _Cfg_SetNotificationsEnabled(__CD_GetCheckState($__g_CD_idChkNotificationsEnabled))
    _Cfg_SetNotifyWindowMoved(__CD_GetCheckState($__g_CD_idChkNotifyMoved))
    _Cfg_SetNotifyDesktopCreated(__CD_GetCheckState($__g_CD_idChkNotifyCreated))
    _Cfg_SetNotifyDesktopDeleted(__CD_GetCheckState($__g_CD_idChkNotifyDeleted))
    _Cfg_SetNotifyWindowPinned(__CD_GetCheckState($__g_CD_idChkNotifyPinned))
    _Cfg_SetNotifyWindowUnpinned(__CD_GetCheckState($__g_CD_idChkNotifyUnpinned))
    _Cfg_SetNotifyExplorerRecovery(__CD_GetCheckState($__g_CD_idChkNotifyExplorerRecov))
    _Cfg_SetNotifyExplorerCrash(__CD_GetCheckState($__g_CD_idChkNotifyExplorerCrash))
    _Cfg_SetWindowListScope(__CD_DelocalizeOptionValue("Options.window_scope", $CD_OPT_WINDOW_SCOPE, GUICtrlRead($__g_CD_idLblWLScope)))

    ; OSD Toast
    _Cfg_SetOsdEnabled(__CD_GetCheckState($__g_CD_idChkOsdEnabled))
    _Cfg_SetOsdShowName(__CD_GetCheckState($__g_CD_idChkOsdShowName))
    _Cfg_SetOsdShowNumber(__CD_GetCheckState($__g_CD_idChkOsdShowNumber))
    $s = GUICtrlRead($__g_CD_idInpOsdDuration)
    If StringIsInt($s) Then _Cfg_SetOsdDuration(Int($s))
    _Cfg_SetOsdPosition(__CD_DelocalizeOptionValue("Options.osd_position", $CD_OPT_OSD_POS, GUICtrlRead($__g_CD_idCycOsdPosition)))
    $s = GUICtrlRead($__g_CD_idInpOsdFontSize)
    If StringIsInt($s) Then _Cfg_SetOsdFontSize(Int($s))
    $s = GUICtrlRead($__g_CD_idInpOsdOpacity)
    If StringIsInt($s) Then _Cfg_SetOsdOpacity(Int($s))
    _Cfg_SetOsdFormat(GUICtrlRead($__g_CD_idInpOsdFormat))
    $s = GUICtrlRead($__g_CD_idInpOsdWidth)
    If StringIsInt($s) Then _Cfg_SetOsdWidth(Int($s))

    ; Taskbar Auto-Hide
    _Cfg_SetAutoHideSyncEnabled(__CD_GetCheckState($__g_CD_idChkAutoHideSync))
    _Cfg_SetAutoHidePollInterval(Int(GUICtrlRead($__g_CD_idInpAutoHidePoll)))
    _Cfg_SetAutoHideHideDelay(Int(GUICtrlRead($__g_CD_idInpAutoHideHideDelay)))
    _Cfg_SetAutoHideShowDelay(Int(GUICtrlRead($__g_CD_idInpAutoHideShowDelay)))
    _Cfg_SetAutoHideSyncDesktopList(__CD_GetCheckState($__g_CD_idChkAutoHideSyncDL))
    _Cfg_SetAutoHideSyncWindowList(__CD_GetCheckState($__g_CD_idChkAutoHideSyncWL))
    _Cfg_SetAutoHideHiddenThreshold(Int(GUICtrlRead($__g_CD_idInpAutoHideThreshold)))
    _Cfg_SetAutoHideRecheckCount(Int(GUICtrlRead($__g_CD_idInpAutoHideRecheck)))
    _Cfg_SetAutoHideSkipIfDialog(__CD_GetCheckState($__g_CD_idChkAutoHideSkipDialog))

    ; Tray
    _Cfg_SetTrayLeftClick(__CD_DelocalizeOptionValue("Options.tray_left_click", $CD_OPT_TRAY_LEFT, GUICtrlRead($__g_CD_idLblTrayLeftClick)))
    _Cfg_SetTrayDoubleClick(__CD_DelocalizeOptionValue("Options.tray_double_click", $CD_OPT_TRAY_DOUBLE, GUICtrlRead($__g_CD_idLblTrayDoubleClick)))
    _Cfg_SetTrayMiddleClick(__CD_DelocalizeOptionValue("Options.tray_middle_click", $CD_OPT_TRAY_MIDDLE, GUICtrlRead($__g_CD_idLblTrayMiddleClick)))
    _Cfg_SetTrayTooltipShowLabel(__CD_GetCheckState($__g_CD_idChkTrayTooltipLabel))
    _Cfg_SetTrayTooltipShowCount(__CD_GetCheckState($__g_CD_idChkTrayTooltipCount))
    _Cfg_SetTrayMenuShowList(__CD_GetCheckState($__g_CD_idChkTrayMenuList))
    _Cfg_SetTrayMenuShowEdit(__CD_GetCheckState($__g_CD_idChkTrayMenuEdit))
    _Cfg_SetTrayMenuShowAdd(__CD_GetCheckState($__g_CD_idChkTrayMenuAdd))
    _Cfg_SetTrayMenuShowDelete(__CD_GetCheckState($__g_CD_idChkTrayMenuDelete))
    _Cfg_SetTrayMenuShowDesktopSub(__CD_GetCheckState($__g_CD_idChkTrayMenuDesktopSub))
    _Cfg_SetTrayMenuShowMoveWindow(__CD_GetCheckState($__g_CD_idChkTrayMenuMoveWin))
    _Cfg_SetTrayNotifySwitch(__CD_GetCheckState($__g_CD_idChkTrayNotifySwitch))
    $s = GUICtrlRead($__g_CD_idInpTrayBalloonDur)
    If StringIsInt($s) Then _Cfg_SetTrayBalloonDuration(Int($s))
    _Cfg_SetTrayCloseToTray(__CD_GetCheckState($__g_CD_idChkTrayCloseToTray))

    ; Persist AFTER every section is set in memory. (Was mid-function, before the
    ; Animations/Wallpaper/WindowList/Explorer/Notifications/OSD/TAH/Tray setters, so
    ; those silently reverted on restart — audit F1.)
    If Not _Cfg_Save() Then
        _Log_Error("Settings: failed to save config file")
        Local $aErrPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_save_failed", "Failed to save settings"), $aErrPos[0], $aErrPos[1] + $aErrPos[3] + 4, 2000, $TOAST_ERROR)
        EndIf
        Return
    EndIf
    _Log_Info("Settings: saved successfully")

    ; Apply changes live to the running app
    _ApplySettingsLive()

    ; Rebuild desktop list to reflect font/color changes
    If _DL_IsVisible() Then
        _DL_Destroy()
        _DL_Show($iTaskbarY, $iDesktop)
    EndIf

    ; Startup toggle with verification
    Local $sToastMsg = _i18n("Toasts.toast_saved", "Settings saved")
    Local $iToastIcon = $TOAST_SUCCESS
    If _Cfg_GetStartWithWindows() <> $bOldStartup Then
        If _Cfg_GetStartWithWindows() Then
            If _Cfg_EnableStartup() Then
                $sToastMsg = _i18n("Toasts.toast_saved_startup_on", "Settings saved (startup enabled)")
            Else
                $sToastMsg = _i18n("Toasts.toast_saved_startup_fail", "Settings saved (startup failed)")
                $iToastIcon = $TOAST_ERROR
            EndIf
        Else
            If _Cfg_DisableStartup() Then
                $sToastMsg = _i18n("Toasts.toast_saved_startup_off", "Settings saved (startup disabled)")
            Else
                $sToastMsg = _i18n("Toasts.toast_saved_startup_remove_fail", "Settings saved (startup removal failed)")
                $iToastIcon = $TOAST_ERROR
            EndIf
        EndIf
    EndIf

    ; Theme change notification
    If _Cfg_GetTheme() <> $sOldTheme Then
        $sToastMsg = _i18n("Toasts.toast_theme_changed", "Theme changed (restart required)")
        $iToastIcon = $TOAST_WARNING
    EndIf

    ; Language change notification
    If _Cfg_GetLanguage() <> $sOldLang Then
        $sToastMsg = _i18n("Toasts.toast_language_changed", "Language changed (restart required)")
        $iToastIcon = $TOAST_WARNING
    EndIf

    _CD_RefreshUpdateStatusLabels()

    ; Toast notification
    Local $aPos = WinGetPos($__g_CD_hGUI)
    If Not @error Then
        _Theme_Toast($sToastMsg, $aPos[0], $aPos[1] + $aPos[3] + 4, 2000, $iToastIcon)
    EndIf
EndFunc

; Name:        __CD_UpdateColorPreviews
; Description: Updates color preview swatches only when values actually change (throttled)
Global $__g_CD_hColorUpdateTimer = 0
Global $__g_CD_aLastDeskColor[51] ; cached last-applied color per desktop (index 1-50)

Func __CD_UpdateColorPreviews()
    If $__g_CD_iActiveTab <> 7 Then Return ; colour inputs live on the Desktops tab (7), not Animations (8)
    ; Throttle: only check every 250ms to avoid flicker
    If TimerDiff($__g_CD_hColorUpdateTimer) < 250 Then Return
    $__g_CD_hColorUpdateTimer = TimerInit()

    Local $i
    For $i = 1 To $__g_CD_iDeskCount
        If $__g_CD_aidDeskColor[$i] = 0 Then ContinueLoop
        Local $sHex = GUICtrlRead($__g_CD_aidDeskColor[$i])
        Local $iClr = _Theme_ValidateHexColor($sHex)
        If $iClr >= 0 And $iClr <> $__g_CD_aLastDeskColor[$i] Then
            $__g_CD_aLastDeskColor[$i] = $iClr
            GUICtrlSetBkColor($__g_CD_aidDeskPreview[$i], $iClr)
        EndIf
    Next
EndFunc

Func __CD_ResetDefaults()
    _Log_Info("Settings: reset to defaults requested")
    If Not _Theme_Confirm(_i18n("Dialogs.confirm_reset_title", "Reset Settings"), _i18n("Dialogs.confirm_reset_msg", "Reset all settings to defaults?")) Then
        _Log_Info("Settings: reset cancelled by user")
        Return
    EndIf
    _Log_Info("Settings: resetting to defaults")

    Local $sPath = _Cfg_GetPath()
    FileDelete($sPath)
    _Cfg_Init($sPath)
    __CD_PopulateControls()

    Local $aPos = WinGetPos($__g_CD_hGUI)
    If Not @error Then
        _Theme_Toast(_i18n("Toasts.toast_reset", "Reset to defaults"), $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_WARNING)
    EndIf
EndFunc

; Name:        __CD_ImportSettings
; Description: Opens a file dialog to import settings from an external INI file
Func __CD_ImportSettings()
    Local $sPath = FileOpenDialog("Import Settings", @DesktopDir, "INI Files (*.ini)", 1, "", $__g_CD_hGUI)
    If $sPath = "" Or @error Then
        _Log_Debug("Settings: import cancelled")
        Return
    EndIf
    _Log_Info("Settings: importing from " & $sPath)
    If _Cfg_Import($sPath) Then
        _Log_Info("Settings: import successful")
        _ApplySettingsLive()
        __CD_PopulateControls()
        Local $aPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_imported", "Settings imported"), $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_SUCCESS)
        EndIf
    Else
        Local $aPos2 = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_import_failed", "Import failed"), $aPos2[0], $aPos2[1] + $aPos2[3] + 4, 1500, $TOAST_ERROR)
        EndIf
    EndIf
EndFunc

; Name:        __CD_ExportSettings
; Description: Opens a file dialog to export current settings to an INI file
Func __CD_ExportSettings()
    Local $sPath = FileSaveDialog("Export Settings", @DesktopDir, "INI Files (*.ini)", 16, "desk_switcheroo.ini", $__g_CD_hGUI)
    If $sPath = "" Or @error Then
        _Log_Debug("Settings: export cancelled")
        Return
    EndIf
    _Log_Info("Settings: exporting to " & $sPath)
    ; Ensure .ini extension
    If StringRight($sPath, 4) <> ".ini" Then $sPath &= ".ini"
    If _Cfg_Export($sPath) Then
        Local $aPos = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_exported", "Settings exported"), $aPos[0], $aPos[1] + $aPos[3] + 4, 1500, $TOAST_SUCCESS)
        EndIf
    Else
        Local $aPos2 = WinGetPos($__g_CD_hGUI)
        If Not @error Then
            _Theme_Toast(_i18n("Toasts.toast_export_failed", "Export failed"), $aPos2[0], $aPos2[1] + $aPos2[3] + 4, 1500, $TOAST_ERROR)
        EndIf
    EndIf
EndFunc

; =============================================
; HOTKEY BUILDER
; =============================================

; Name:        __CD_HandleHotkeyBuildClick
; Description: Checks if a hotkey build "..." button was clicked and opens the builder
; Parameters:  $id - control ID from GUIGetMsg
Func __CD_HandleHotkeyBuildClick($id)
    ; Registry lookup: find the input paired with this "..." button (uniform across all
    ; hotkey rows now — see __CD_RegHkBuilder).
    Local $idInput = 0, $i
    For $i = 0 To $__g_CD_iHkBuildCount - 1
        If $id = $__g_CD_aHkBuildBtn[$i] Then
            $idInput = $__g_CD_aHkBuildInp[$i]
            ExitLoop
        EndIf
    Next
    If $idInput = 0 Then Return

    Local $sResult = __CD_ShowHotkeyBuilder()
    ; Explicit confirm: only OK (non-empty result) writes to the row input.
    If $sResult <> "" Then GUICtrlSetData($idInput, $sResult)
EndFunc

; Name:        __CD_ShowHotkeyBuilder
; Description: Shows a dialog to visually build a hotkey string
; Return:      AutoIt hotkey string (e.g. "^!{RIGHT}") or "" if cancelled
Func __CD_ShowHotkeyBuilder()
    ; Suspend global hotkeys for the builder's WHOLE lifetime so recording a chord like
    ; Ctrl+Alt+Right doesn't also FIRE it. Resumed once, on the single exit path below.
    __CD_HkSuspend()

    Local $iDlgW = 280, $iDlgH = 220
    Local $iDlgX = (@DesktopWidth - $iDlgW) / 2
    Local $iDlgY = (@DesktopHeight - $iDlgH) / 2

    Local $hDlg = _Theme_CreatePopup("HotkeyBuilder", $iDlgW, $iDlgH, $iDlgX, $iDlgY, $THEME_BG_POPUP, $THEME_ALPHA_DIALOG)

    ; Title label
    Local $idTitle = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_title", "Hotkey Builder"), 10, 8, $iDlgW - 20, 18)
    GUICtrlSetFont($idTitle, 9, 700, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idTitle, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idTitle, $GUI_BKCOLOR_TRANSPARENT)

    ; Modifier checkboxes (label-based toggle)
    Local $iChkY = 34
    Local $idChkCtrl = GUICtrlCreateLabel(__CD_GetHotkeyModifierLabel("Extra.hkb_mod_ctrl", "Ctrl", False), 16, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkCtrl, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkCtrl, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkCtrl, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkCtrl, 0)

    Local $idChkAlt = GUICtrlCreateLabel(__CD_GetHotkeyModifierLabel("Extra.hkb_mod_alt", "Alt", False), 146, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkAlt, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkAlt, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkAlt, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkAlt, 0)

    $iChkY += 26
    Local $idChkShift = GUICtrlCreateLabel(__CD_GetHotkeyModifierLabel("Extra.hkb_mod_shift", "Shift", False), 16, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkShift, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkShift, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkShift, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkShift, 0)

    Local $idChkWin = GUICtrlCreateLabel(__CD_GetHotkeyModifierLabel("Extra.hkb_mod_win", "Win", False), 146, $iChkY, 110, 22, BitOR($SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idChkWin, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idChkWin, $THEME_FG_PRIMARY)
    GUICtrlSetBkColor($idChkWin, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetCursor($idChkWin, 0)

    ; Key input
    Local $iKeyY = $iChkY + 32
    Local $idKeyLbl = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_key", "Key:"), 16, $iKeyY + 2, 35, 18)
    GUICtrlSetFont($idKeyLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idKeyLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idKeyLbl, $GUI_BKCOLOR_TRANSPARENT)

    Local $idKeyInput = GUICtrlCreateInput("", 55, $iKeyY, 120, 22)
    GUICtrlSetFont($idKeyInput, 9, 400, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idKeyInput, $THEME_FG_TEXT)
    GUICtrlSetBkColor($idKeyInput, $THEME_BG_INPUT)
    _Theme_FlattenInput($idKeyInput)

    ; Capture button
    Local $iX = 16
    Local $idCapture = GUICtrlCreateLabel(ChrW(0x23CE) & " " & _i18n("HotkeyBuilder.hkb_capture", "Capture"), $iX + 165, $iKeyY, 80, 22, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCapture, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCapture, $THEME_FG_MENU)
    GUICtrlSetBkColor($idCapture, $THEME_BG_HOVER)
    GUICtrlSetCursor($idCapture, 0)
    _Theme_SetTooltip($idCapture, _i18n("HotkeyBuilder.hkb_tip_capture", "Press the full key combination; Esc cancels (times out after 10 seconds)"))

    ; Hint
    Local $idHint = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_hint", "e.g.: LEFT, RIGHT, F1-F12, 1-9, A-Z"), 16, $iKeyY + 26, 250, 14)
    GUICtrlSetFont($idHint, 7, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idHint, $THEME_FG_LABEL)
    GUICtrlSetBkColor($idHint, $GUI_BKCOLOR_TRANSPARENT)

    ; Preview
    Local $iPreviewY = $iKeyY + 48
    Local $idPreviewLbl = GUICtrlCreateLabel(_i18n("HotkeyBuilder.hkb_preview", "Preview:"), 16, $iPreviewY + 2, 50, 18)
    GUICtrlSetFont($idPreviewLbl, 8, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idPreviewLbl, $THEME_FG_DIM)
    GUICtrlSetBkColor($idPreviewLbl, $GUI_BKCOLOR_TRANSPARENT)

    Local $idPreview = GUICtrlCreateLabel("", 70, $iPreviewY, 190, 22, $SS_CENTERIMAGE)
    GUICtrlSetFont($idPreview, 10, 700, 0, $THEME_FONT_MONO)
    GUICtrlSetColor($idPreview, $THEME_FG_WHITE)
    GUICtrlSetBkColor($idPreview, $THEME_BG_INPUT)

    ; OK / Cancel buttons
    Local $iBtnW = 60, $iBtnH = 26
    Local $iBtnY = $iDlgH - 38
    Local $idOK = GUICtrlCreateLabel(_i18n("General.btn_ok", "OK"), ($iDlgW / 2) - $iBtnW - 8, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idOK, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idOK, $THEME_FG_MENU)
    GUICtrlSetBkColor($idOK, $THEME_BG_HOVER)
    GUICtrlSetCursor($idOK, 0)

    Local $idCancel = GUICtrlCreateLabel(_i18n("General.btn_cancel", "Cancel"), ($iDlgW / 2) + 8, $iBtnY, $iBtnW, $iBtnH, _
        BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOTIFY))
    GUICtrlSetFont($idCancel, 9, 400, 0, $THEME_FONT_MAIN)
    GUICtrlSetColor($idCancel, $THEME_FG_MENU)
    GUICtrlSetBkColor($idCancel, $THEME_BG_HOVER)
    GUICtrlSetCursor($idCancel, 0)

    _Theme_FadeIn($hDlg, $THEME_ALPHA_DIALOG, "dialog")

    ; Checkbox states
    Local $bCtrl = False, $bAlt = False, $bShift = False, $bWin = False
    Local $sLastKey = "", $sResult = ""
    Local $iHovered = 0
    ; Edge-detected + focus-gated Esc/Enter (a held key from clicking Capture must not
    ; instantly confirm/cancel, and keys pressed in OTHER apps must not reach this dialog).
    Local $bDlgEscWasDown = False, $bDlgEnterWasDown = False

    ; Blocking loop
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idOK
                    $sResult = __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, GUICtrlRead($idKeyInput))
                    ExitLoop
                Case $idCancel
                    ExitLoop
                Case $idChkCtrl
                    $bCtrl = Not $bCtrl
                    GUICtrlSetData($idChkCtrl, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_ctrl", "Ctrl", $bCtrl))
                    GUICtrlSetColor($idChkCtrl, $bCtrl ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idChkAlt
                    $bAlt = Not $bAlt
                    GUICtrlSetData($idChkAlt, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_alt", "Alt", $bAlt))
                    GUICtrlSetColor($idChkAlt, $bAlt ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idChkShift
                    $bShift = Not $bShift
                    GUICtrlSetData($idChkShift, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_shift", "Shift", $bShift))
                    GUICtrlSetColor($idChkShift, $bShift ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idChkWin
                    $bWin = Not $bWin
                    GUICtrlSetData($idChkWin, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_win", "Win", $bWin))
                    GUICtrlSetColor($idChkWin, $bWin ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                Case $idCapture
                    ; Prompt, then run the armed-chord capture state machine. It waits for
                    ; the full combination to be pressed and snapshots the modifiers held in
                    ; the SAME tick as the key (fixes lost/ghost modifiers), or returns "" on
                    ; Esc/timeout. Capture only fills the builder fields; OK commits.
                    GUICtrlSetData($idKeyInput, _i18n("HotkeyBuilder.hkb_press_key", "Press the key combination..."))
                    Local $iCapMod = 0
                    Local $sCaptured = __CD_CaptureKeyPress($iCapMod)
                    If $sCaptured <> "" Then
                        GUICtrlSetData($idKeyInput, $sCaptured)
                        ; Snapshot the chord's modifiers into the toggles (replaces prior state).
                        $bCtrl = (BitAND($iCapMod, 1) <> 0)
                        $bAlt = (BitAND($iCapMod, 2) <> 0)
                        $bShift = (BitAND($iCapMod, 4) <> 0)
                        $bWin = (BitAND($iCapMod, 8) <> 0)
                        GUICtrlSetData($idChkCtrl, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_ctrl", "Ctrl", $bCtrl))
                        GUICtrlSetColor($idChkCtrl, $bCtrl ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                        GUICtrlSetData($idChkAlt, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_alt", "Alt", $bAlt))
                        GUICtrlSetColor($idChkAlt, $bAlt ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                        GUICtrlSetData($idChkShift, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_shift", "Shift", $bShift))
                        GUICtrlSetColor($idChkShift, $bShift ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                        GUICtrlSetData($idChkWin, __CD_GetHotkeyModifierLabel("Extra.hkb_mod_win", "Win", $bWin))
                        GUICtrlSetColor($idChkWin, $bWin ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    Else
                        GUICtrlSetData($idKeyInput, "")
                    EndIf
            EndSwitch
        EndIf

        ; Update preview when key input changes
        Local $sCurKey = GUICtrlRead($idKeyInput)
        If $sCurKey <> $sLastKey Or $aMsg[0] = $idChkCtrl Or $aMsg[0] = $idChkAlt Or $aMsg[0] = $idChkShift Or $aMsg[0] = $idChkWin Then
            $sLastKey = $sCurKey
            GUICtrlSetData($idPreview, " " & __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, $sCurKey))
        EndIf

        ; Escape cancels, Enter confirms — only while THIS dialog is focused, and only on a
        ; fresh key-down edge (so a key still held from clicking Capture doesn't fire, and
        ; keys pressed in other apps are ignored).
        If WinActive($hDlg) Then
            Local $retEsc = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x1B)
            Local $bEscDown = (Not @error And IsArray($retEsc) And BitAND($retEsc[0], 0x8000) <> 0)
            If $bEscDown And Not $bDlgEscWasDown Then ExitLoop ; cancel: $sResult stays ""
            $bDlgEscWasDown = $bEscDown

            Local $retEnter = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x0D)
            Local $bEnterDown = (Not @error And IsArray($retEnter) And BitAND($retEnter[0], 0x8000) <> 0)
            If $bEnterDown And Not $bDlgEnterWasDown Then
                $sResult = __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, GUICtrlRead($idKeyInput))
                ExitLoop
            EndIf
            $bDlgEnterWasDown = $bEnterDown
        Else
            $bDlgEscWasDown = False
            $bDlgEnterWasDown = False
        EndIf

        ; Button hover
        GUISwitch($hDlg)
        Local $aCursor = GUIGetCursorInfo($hDlg)
        If Not @error Then
            Local $iFound = 0
            If $aCursor[4] = $idOK Then $iFound = $idOK
            If $aCursor[4] = $idCancel Then $iFound = $idCancel
            If $aCursor[4] = $idCapture Then $iFound = $idCapture
            If $aCursor[4] = $idChkCtrl Then $iFound = $idChkCtrl
            If $aCursor[4] = $idChkAlt Then $iFound = $idChkAlt
            If $aCursor[4] = $idChkShift Then $iFound = $idChkShift
            If $aCursor[4] = $idChkWin Then $iFound = $idChkWin
            If $iFound <> $iHovered Then
                If $iHovered <> 0 Then
                    Local $iFgR = $THEME_FG_MENU
                    ; Checkboxes restore to their toggle color
                    If $iHovered = $idChkCtrl Then $iFgR = ($bCtrl ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    If $iHovered = $idChkAlt Then $iFgR = ($bAlt ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    If $iHovered = $idChkShift Then $iFgR = ($bShift ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    If $iHovered = $idChkWin Then $iFgR = ($bWin ? $THEME_FG_WHITE : $THEME_FG_PRIMARY)
                    _Theme_RemoveHover($iHovered, $iFgR, $THEME_BG_HOVER)
                EndIf
                $iHovered = $iFound
                If $iHovered <> 0 Then _Theme_ApplyHover($iHovered, $THEME_FG_WHITE, $THEME_BG_BTN_HOV)
            EndIf
        EndIf

        Sleep(10)
    WEnd

    _Theme_FadeOut($hDlg, "dialog")
    ; Single resume path: every exit (OK / Cancel / Escape / window close) reaches here.
    __CD_HkResume()
    Return $sResult
EndFunc

; Armed-chord capture state machine states.
Global Const $CD_HKCAP_FLUSH = 0    ; wait for all keys physically released
Global Const $CD_HKCAP_ARMED = 1    ; wait for a non-modifier keydown
Global Const $CD_HKCAP_DONE = 2      ; chord captured
Global Const $CD_HKCAP_CANCEL = 3    ; cancelled (Esc)

; Name:        __CD_HkCap_Tick
; Description: Pure armed-chord capture state machine, one tick. Headless-testable.
; Parameters:  $iState      - current state ($CD_HKCAP_*)
;              $iVkDown     - the non-modifier VK currently held (0 if none)
;              $iModMask    - modifier bitmask held this tick (1=Ctrl 2=Alt 4=Shift 8=Win)
;              $bEscDown    - True if Escape is held
;              $bAnyKeyDown - True if ANY physical key (incl. modifiers) is held
; Return:      [newState, capturedVK, capturedModMask]
Func __CD_HkCap_Tick($iState, $iVkDown, $iModMask, $bEscDown, $bAnyKeyDown)
    Local $aOut[3] = [$iState, 0, 0]
    ; Terminal states are sticky.
    If $iState = $CD_HKCAP_DONE Or $iState = $CD_HKCAP_CANCEL Then Return $aOut
    ; Escape cancels from any state and is never itself capturable.
    If $bEscDown Then
        $aOut[0] = $CD_HKCAP_CANCEL
        Return $aOut
    EndIf
    Switch $iState
        Case $CD_HKCAP_FLUSH
            ; Arm only once every key (incl. stale modifiers) is released — replaces the old
            ; fake sleep-flush and kills the stale-transition-bit phantom capture.
            If Not $bAnyKeyDown Then $aOut[0] = $CD_HKCAP_ARMED
        Case $CD_HKCAP_ARMED
            ; Complete on a real (non-modifier) keydown; snapshot modifiers in the SAME tick.
            ; A modifier-only press never completes (stays ARMED).
            If $iVkDown <> 0 Then
                $aOut[0] = $CD_HKCAP_DONE
                $aOut[1] = $iVkDown
                $aOut[2] = $iModMask
            EndIf
    EndSwitch
    Return $aOut
EndFunc

; Name:        __CD_HkCap_IsExcludedVK
; Description: Pure. True for VKs that must not be captured as the chord's main key:
;              mouse buttons, Escape, and every modifier (generic + L/R variants).
Func __CD_HkCap_IsExcludedVK($iVK)
    If $iVK <= 0x07 Then Return True                      ; mouse buttons
    If $iVK = 0x1B Then Return True                       ; Esc (cancel, not capturable)
    If $iVK = 0x10 Or $iVK = 0x11 Or $iVK = 0x12 Then Return True ; Shift/Ctrl/Alt (generic)
    If $iVK = 0x5B Or $iVK = 0x5C Then Return True         ; Left/Right Win
    If $iVK >= 0xA0 And $iVK <= 0xA5 Then Return True      ; Left/Right Shift/Ctrl/Alt
    Return False
EndFunc

; Name:        __CD_KeyLevelDown
; Description: Impure. True if the VK's LEVEL bit (0x8000) is set — "is physically down
;              right now". Never reads the transition bit 0x0001 (that is the stale-state bug).
Func __CD_KeyLevelDown($iVK)
    Local $ret = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $iVK)
    Return (Not @error And IsArray($ret) And BitAND($ret[0], 0x8000) <> 0)
EndFunc

; Name:        __CD_HkCap_ScanKeys
; Description: Impure companion to __CD_HkCap_Tick: samples LEVEL key state for one tick.
Func __CD_HkCap_ScanKeys(ByRef $iVkDown, ByRef $iModMask, ByRef $bEscDown, ByRef $bAnyKeyDown)
    $iVkDown = 0
    $iModMask = 0
    $bAnyKeyDown = False
    $bEscDown = __CD_KeyLevelDown(0x1B)
    ; Modifier level state (generic VKs cover both L/R variants).
    If __CD_KeyLevelDown(0x11) Then $iModMask = BitOR($iModMask, 1) ; Ctrl
    If __CD_KeyLevelDown(0x12) Then $iModMask = BitOR($iModMask, 2) ; Alt
    If __CD_KeyLevelDown(0x10) Then $iModMask = BitOR($iModMask, 4) ; Shift
    If __CD_KeyLevelDown(0x5B) Or __CD_KeyLevelDown(0x5C) Then $iModMask = BitOR($iModMask, 8) ; Win
    Local $i
    For $i = 0x08 To 0xFE
        If Not __CD_KeyLevelDown($i) Then ContinueLoop
        $bAnyKeyDown = True
        If __CD_HkCap_IsExcludedVK($i) Then ContinueLoop
        If $iVkDown = 0 Then $iVkDown = $i ; first non-modifier key wins
    Next
EndFunc

; Name:        __CD_CaptureKeyPress
; Description: Drives __CD_HkCap_Tick from live key state until the chord completes, Escape
;              cancels, or ~10 s elapses. LEVEL bits only — no transition bits, no Send().
; Parameters:  $iModMask - ByRef out; captured modifier bitmask (1=Ctrl 2=Alt 4=Shift 8=Win)
; Return:      AutoIt key name string, or "" on cancel/timeout
Func __CD_CaptureKeyPress(ByRef $iModMask)
    $iModMask = 0
    Local $iState = $CD_HKCAP_FLUSH
    Local $hTimeout = TimerInit()
    While TimerDiff($hTimeout) < 10000
        Local $iVkDown = 0, $iMods = 0, $bEscDown = False, $bAnyKeyDown = False
        __CD_HkCap_ScanKeys($iVkDown, $iMods, $bEscDown, $bAnyKeyDown)
        Local $aTick = __CD_HkCap_Tick($iState, $iVkDown, $iMods, $bEscDown, $bAnyKeyDown)
        $iState = $aTick[0]
        If $iState = $CD_HKCAP_DONE Then
            $iModMask = $aTick[2]
            Return __CD_VKToAutoItKey($aTick[1])
        ElseIf $iState = $CD_HKCAP_CANCEL Then
            Return ""
        EndIf
        Sleep(10)
    WEnd
    Return "" ; timeout
EndFunc

; Name:        __CD_VKToAutoItKey
; Description: Converts a Windows virtual key code to an AutoIt key name
; Parameters:  $iVK - virtual key code (0x08-0xFE)
; Return:      AutoIt key name string
Func __CD_VKToAutoItKey($iVK)
    Switch $iVK
        Case 0x08
            Return "BS"
        Case 0x09
            Return "TAB"
        Case 0x0D
            Return "ENTER"
        Case 0x1B
            Return "ESC"
        Case 0x20
            Return "SPACE"
        Case 0x21
            Return "PGUP"
        Case 0x22
            Return "PGDN"
        Case 0x23
            Return "END"
        Case 0x24
            Return "HOME"
        Case 0x25
            Return "LEFT"
        Case 0x26
            Return "UP"
        Case 0x27
            Return "RIGHT"
        Case 0x28
            Return "DOWN"
        Case 0x2D
            Return "INSERT"
        Case 0x2E
            Return "DELETE"
        Case 0x30 To 0x39
            Return Chr($iVK)
        Case 0x41 To 0x5A
            Return StringLower(Chr($iVK))
        Case 0x60
            Return "NUMPAD0"
        Case 0x61
            Return "NUMPAD1"
        Case 0x62
            Return "NUMPAD2"
        Case 0x63
            Return "NUMPAD3"
        Case 0x64
            Return "NUMPAD4"
        Case 0x65
            Return "NUMPAD5"
        Case 0x66
            Return "NUMPAD6"
        Case 0x67
            Return "NUMPAD7"
        Case 0x68
            Return "NUMPAD8"
        Case 0x69
            Return "NUMPAD9"
        Case 0x6A
            Return "NUMPADMULT"
        Case 0x6B
            Return "NUMPADADD"
        Case 0x6D
            Return "NUMPADSUB"
        Case 0x6E
            Return "NUMPADDOT"
        Case 0x6F
            Return "NUMPADDIV"
        Case 0x70 To 0x7B
            Return "F" & ($iVK - 0x6F)
        Case 0xBA
            Return ";"
        Case 0xBB
            Return "="
        Case 0xBC
            Return ","
        Case 0xBD
            Return "-"
        Case 0xBE
            Return "."
        Case 0xBF
            Return "/"
        Case 0xC0
            Return "``"
        Case 0xDB
            Return "["
        Case 0xDC
            Return "\"
        Case 0xDD
            Return "]"
        Case 0xDE
            Return "'"
        Case Else
            Return "{" & Hex($iVK, 2) & "}"
    EndSwitch
EndFunc

; Name:        __CD_BuildHotkeyString
; Description: Constructs an AutoIt hotkey string from modifier flags and key name
; Parameters:  $bCtrl  - True if Ctrl modifier
;              $bAlt   - True if Alt modifier
;              $bShift - True if Shift modifier
;              $bWin   - True if Win modifier
;              $sKey   - key name (e.g. "RIGHT", "F1", "A")
; Return:      Hotkey string (e.g. "^!{RIGHT}")
Func __CD_BuildHotkeyString($bCtrl, $bAlt, $bShift, $bWin, $sKey)
    Local $s = ""
    If $bCtrl Then $s &= "^"
    If $bAlt Then $s &= "!"
    If $bShift Then $s &= "+"
    If $bWin Then $s &= "#"

    $sKey = StringStripWS($sKey, 3) ; trim leading+trailing
    If $sKey = "" Then Return $s

    ; Single character keys don't need braces
    If StringLen($sKey) = 1 Then
        $s &= $sKey
    Else
        ; Multi-char keys get wrapped in braces (e.g. LEFT -> {LEFT})
        $s &= "{" & StringUpper($sKey) & "}"
    EndIf

    Return $s
EndFunc

; Name:        __CD_RestartApp
; Description: Relaunches the application and exits the current instance
Func __CD_RestartApp()
    If _Cfg_GetConfirmRestart() Then
        If Not _Theme_Confirm(_i18n("Dialogs.confirm_restart_title", "Restart Desk Switcheroo?"), _
                _i18n("Dialogs.confirm_restart_msg", "The application will restart. Unsaved changes will be lost.")) Then
            Return
        EndIf
    EndIf
    _CD_Destroy()
    Run(_Cfg_GetLaunchCommand())
    _Shutdown()
EndFunc

; Name:        __CD_WM_CTLCOLORLISTBOX
; Description: WM handler to theme combo dropdown list with dark colors
Func __CD_WM_CTLCOLORLISTBOX($hWnd, $iMsg, $wParam, $lParam)
    If $__g_CD_hBrushCombo = 0 Then Return $GUI_RUNDEFMSG
    DllCall("gdi32.dll", "int", "SetTextColor", "handle", $wParam, "dword", $THEME_FG_TEXT)
    DllCall("gdi32.dll", "int", "SetBkColor", "handle", $wParam, "dword", $THEME_BG_INPUT)
    DllCall("gdi32.dll", "int", "SetBkMode", "handle", $wParam, "int", 1) ; OPAQUE
    Return $__g_CD_hBrushCombo
EndFunc

