---
title: Architecture & Patterns
nav_order: 4
parent: Reference
---

# Architecture & Patterns

This page describes how Desk Switcheroo is built — the programming paradigms, the
concurrency model, and the recurring patterns a contributor will meet across the
codebase. It is the developer-level companion to the user-level
[How It Works](../how-it-works.md) page, and it explains the code behind the mechanisms
on [Stability & Mitigations](../reference/stability.md). Every structural claim here was
spot-checked against current source.

## Language and module layout

The app is **procedural AutoIt**. There are no classes; state lives in module-scoped
globals and behavior in functions. Code is organized **one module per file** under
`includes/` (`Config.au3`, `Theme.au3`, `VirtualDesktop.au3`, `WindowRules.au3`,
`Hooks.au3`, `Logger.au3`, `i18n.au3`, and so on), with the top-level
`desktop_switcher.au3` owning the widget, the main loop, and the glue between modules.

Naming follows a consistent public/private convention: a single leading underscore
(`_Module_Function`) marks a module's public API, and a double leading underscore
(`__Module_Function`) marks an internal helper not meant to be called from outside the
module. The same applies to globals (`$__g_Module_...` for private module state). This
convention is the primary signal of what is safe to call across module boundaries.

## Single-threaded cooperative concurrency

AutoIt is single-threaded, so the entire app is a cooperative system built around one
`While 1` main loop in `desktop_switcher.au3`. Each iteration calls **seven phase
functions** in order:

1. `_ProcessGUIEvents` — dispatch GUI messages (clicks, control notifications).
2. `_ProcessMouseInput` — mouse position, hover, scroll, drag.
3. `_ProcessKeyboardInput` — polled keyboard state.
4. `_ProcessEventFlags` — consume flags set by hooks/Adlibs (including the deferred
   nav refresh).
5. `_ProcessIPCPending` — execute a relayed, instance-bound CLI action queued over IPC
   (`toggle-list`, `toggle-slideshow`, `load-`/`save-profile`).
6. `_ProcessHoverAndVisuals` — hover-driven visuals; returns whether the cursor is active.
7. `_ProcessTimersAndSleep` — advance all ticked animations/timers, then sleep.

Because everything shares this one thread, the golden rule is **never block the loop**.
The supporting patterns all exist to honor that rule:

**Three-tier adaptive sleep.** The loop's idle cost is tuned by choosing one of three
sleep durations at the end of `_ProcessTimersAndSleep`: **5 ms** when interactive (cursor
active, a fade running, or a nav settle armed), **15 ms** when a popup/menu is visible,
and **100 ms** when fully idle. This keeps the app responsive under interaction and cheap
at rest.

**Adlib timers for periodic work.** Recurring background tasks are registered with
`AdlibRegister`, which interrupts the script between statements. Because an Adlib cannot
be interrupted by another Adlib, each handler is kept tiny — set a flag or do a cheap
probe, never a `Sleep` or heavy loop. The registered handlers include `_ForceTopMost`
(topmost re-assert), `_AdlibSyncNames` (OS desktop-name sync), `_CheckDLLHealth`,
`_AdlibConfigWatcher`, `__TAH_Poll` (taskbar auto-hide), `__EM_Poll` (Explorer monitor),
`__WR_Poll` (rules engine), `_UC_AdlibCheck` (background update check), and one-shot
handlers such as `__VD_AnimRestoreTick`.

**Event-driven desktop-change notifications.** Rather than poll for the active desktop,
the app registers for a native push notification via `RegisterPostMessageHook` (in
`includes/VirtualDesktop.au3`); the DLL posts a message when the desktop changes and the
widget updates from the handler. This is how a switch triggered outside the app (Task
View, another tool) still updates the widget.

**Tick / state-machine animations instead of blocking sleeps.** Fades that would
otherwise be `For … Sleep` loops are driven one step per main-loop pass: the toast fade
(`_Theme_ToastTick`), OSD fade (`_Theme_OsdTick`), taskbar auto-hide fade
(`_TAH_FadeTick`), and the widget color-bar animation (`_Theme_ColorBarTick`) all advance
from `_ProcessTimersAndSleep`. The desktop slideshow steps the same way, from its own
main-loop tick (`_SlideshowTick`) rather than an Adlib, because its per-step intervals vary
and the idle sleep granularity is fine for second-scale steps. (The generic menu/dialog
fade is a documented exception that still blocks briefly — see
[Known Limitations](../reference/limitations.md).)

**Deferred nav settle with an optimistic index.** A desktop switch does not block for the
OS to settle. `_NavigateTo` issues the switch, optimistically advances the tracked index
(`$iDesktop = $iNew`) so rapid relative navigation chains off a fresh value, and arms a
deferred refresh (`_RequestDeferredRefresh`) that reconciles to OS ground truth ~50 ms
later from the main loop (`_ProcessPendingRefresh`). The pure reconciliation helper is
`_Nav_Reconcile`. This is the pattern behind the fixed rapid-switch behavior described on
the [Stability](../reference/stability.md) page.

**Debounced writes.** Config saves are debounced 500 ms (`$__g_Cfg_SAVE_DEBOUNCE`) so a
burst of setting changes coalesces into one disk write; wallpaper application and taskbar
auto-hide transitions are similarly debounced.

**Async modal dialog via a re-entrant tick.** The Settings dialog runs its own blocking message
loop, but rather than freezing the app it calls back once per iteration into
`_MainTick_FromDialog` (registered by `_CD_RegisterMainCallbacks`), which runs the same phase
functions listed above — minus the single `GUIGetMsg` read, which the dialog owns. So the widget,
tray, panels, ticks, slideshow, and relayed IPC actions all stay live while Settings is open. The
dialog forwards only the events it does not consume (no double-processing), and `GUISwitch` is
restored to the dialog after the tick so phase functions that create or switch GUIs don't disturb
its hover state. Nested sub-loops the dialog opens itself (hotkey builder, file pickers, update
check) deliberately skip the tick.

## The multi-site config-key pattern

Adding a configuration key touches a fixed set of sites, and following the pattern is
what keeps config coherent. For a given key you add:

1. A **module global with its default** in `includes/Config.au3`.
2. A **read** in `_Cfg_Load` using the typed helpers `__Cfg_ReadBool` / `__Cfg_ReadInt`
   / `__Cfg_ReadEnum` (which clamp and validate), or a raw `IniRead` for free-form values.
3. A **write** in `_Cfg_Save`.
4. A **default entry** in the ensure-defaults routine that materializes a fresh INI.
5. A **getter** (`_Cfg_Get...`) and, where the setting is set from the UI, a **setter**
   (`_Cfg_Set...`).
6. A **control in `includes/ConfigDialog.au3`** plus its apply path, if the key is
   user-exposed.

Keys that are deliberately INI-only simply omit step 6. The step-by-step recipe for
contributors lives on the [Building from Source](../reference/building.md) page.

## Custom GUI toolkit

The widget, popups, menus, and dialogs are **custom borderless `WS_POPUP` windows** drawn
by the app, not native Win32 menus or common controls. This is what gives every surface
the same dark theme and lets the app control fades and layout precisely. `includes/Theme.au3`
holds the drawing and theming; even the crash dialog is a hand-built `GUICreate` so it can
render without depending on possibly-corrupt Theme state. The trade-off is that the app
reimplements behavior a native menu would give for free, which is where the residual
menu-fade blocking (see limitations) comes from.

## Internationalization

Localization is designed for O(1) lookups. On startup `_i18n_Init` loads the selected
locale's INI into a `Scripting.Dictionary` and **always** loads `en-US.ini` into a second
dictionary as the fallback (`includes/i18n.au3`). A lookup (`_i18n`) resolves through a
three-step chain — **current locale → `en-US` → the hardcoded English default** passed at
the call site — so a missing key can never render blank. There are **34 locale files**,
each with roughly 760 keys (`en-US.ini` has 759), and a CI guard, `scripts/locale-check.ps1`,
verifies key parity across locales so a translation cannot silently drift out of sync.

## Window enumeration bypass

AutoIt's built-in `WinList()` only sees windows on the current virtual desktop, which is
useless for a tool whose whole job is moving windows between desktops. The app therefore
bypasses it and enumerates **all** top-level windows directly via the Win32 `EnumWindows`
API (`__VD_EnumAllWindows` in `includes/VirtualDesktop.au3`), then asks the DLL for each
window's desktop number. This is the foundation of the window list, "move all windows",
and "gather" features.

## Testability and the regression-guard style

Logic that can be pure is kept pure so it can be unit-tested without a running GUI. There
are **23 `Test_*.au3` suites** under `tests/`, run headless by `tests/TestRunner.au3`. The
distinctive convention is a **regression-guard test**: when a specific bug is fixed, a
test is added that reproduces the exact failing scenario and is tagged in a comment with
the date so its purpose survives. A concrete example is the desktop-label
**double-shift** regression in `tests/Test_Labels.au3`: deleting a middle desktop on
Windows 11 used to duplicate the last label and suppress two names, because the code
re-read already-reindexed state; the test simulates that reindexing and asserts the
pre-remove snapshot prevents the double-shift. Several tests carry a `Regression 2026-...`
tag marking the bug they lock down. See [Building from Source](../reference/building.md)
for how to run them.

## Inter-process communication

CLI action commands are relayed to the already-running instance rather than acting
directly. The running instance registers a `WM_COPYDATA` handler (`_CLI_RegisterIPC` in
`includes/CLI.au3`); a second launch that parses an action command packages it and sends
it via `WM_COPYDATA`, guarded by a magic number (`0x44534B`, ASCII "DSK") so the handler
ignores foreign messages. Commands that need the running GUI — `toggle-list`,
`toggle-slideshow`, and profile load/save — cannot complete inside the message handler, so they
are queued and drained each pass by `_ProcessIPCPending` (phase 5 above), which also runs from the
Settings dialog's tick. Query commands (`list-desktops`, `get-current`, `status`, …) run
standalone without a running instance. The command set is documented on the
[CLI Parameters](../configuration/cli.md) page.

## Background update checker

The updater illustrates the non-blocking I/O pattern. The scheduled check
(`_UC_AdlibCheck`) starts a **background** `InetGet` and returns; `_UC_CheckResult`,
called from the main loop each pass, polls the handle and processes the result when it
completes — the loop never waits on the network. A user-initiated check or portable
download uses the same background-handle approach wrapped in a modal dialog that pumps its
own message loop and can be cancelled, so even a foreground update stays responsive
(`includes/UpdateChecker.au3`).
