---
title: Stability & Mitigations
nav_order: 2
parent: Reference
---

# Stability & Mitigations

Desk Switcheroo runs as a single long-lived process that has to survive Explorer
restarts, a fragile third-party virtual-desktop DLL, external edits to its own config,
and other windows fighting it for the top of the z-order. This page documents the
mechanisms that keep it alive and responsive, and the specific defenses it employs
against known failure modes. Each mechanism names its source module. For the honest list
of things it still cannot do, see [Known Limitations](../reference/limitations.md); for
the code structure behind these mechanisms, see
[Architecture & Patterns](../reference/architecture.md).

## Crash recovery

An unhandled AutoIt error is caught by `_OnAutoItError` (in `desktop_switcher.au3`),
which routes through `__WriteCrashLog`. The crash handler is written to work even when
the rest of the app is broken:

- It writes a `crash_<YYYYMMDD>_<HHMMSS>.log` **immediately** to disk with `FileFlush`,
  next to the executable (`@ScriptDir`), falling back to the temp directory if the
  install folder is not writable (it probes with a throwaway test file first).
- The report bypasses the normal [logger](../guides/logging.md) entirely — the logger
  might itself be the crash source. It captures the crash reason and error details, an
  app-state snapshot (version, current desktop, script line number, and which
  popups/dialogs were visible), and system info (AutoIt version and bitness, OS build,
  user, PID, script path).
- It then shows a standalone dark crash dialog (`__ShowCrashDialog`) built with a raw
  `GUICreate` rather than the themed popup helpers, so it does not depend on Theme module
  state that may be corrupt. The dialog offers four actions: **Copy Report** (to
  clipboard), **Open Log** (opens the `crash_*.log`), **Restart** (relaunches the app),
  and **Close**.

The logger also records a best-effort `ERROR` line for the crash, but the `crash_*.log`
is the authoritative artifact to attach when reporting a problem.

## Singleton enforcement

Only one instance runs at a time when `singleton_enabled` is `true` (the default). This
is read straight from the INI at startup, before the full config loads, so it takes
effect as early as possible (`desktop_switcher.au3`). Enforcement uses a named mutex
(`DesktopSwitcherMutex_7F3A`); if the mutex is already held (`GetLastError` = 183, "already
exists") the newly launched instance **kills the previous one and takes over**, rather
than the new launch aborting. It kills only its own kind: a compiled build enumerates
`@AutoItExe`; running from source, it inspects each AutoIt process's WMI command line and
closes only those running `desktop_switcher.au3`, so it never touches unrelated AutoIt
programs. The net effect is that re-launching the app cleanly replaces a running copy.

## Virtual-desktop DLL health check

All desktop control goes through `VirtualDesktopAccessor.dll`. A periodic health check,
`_CheckDLLHealth` (Adlib, interval `dll_check_interval`, default 30000 ms), calls
`_VD_IsReady()`; if the DLL handle has been lost it logs an error and attempts a reload
via `_VD_Init()`. This recovers from transient handle loss. It cannot recover from a
Windows update that changes the underlying desktop internals such that the pinned DLL is
incompatible — that is a genuine limitation documented on the
[Known Limitations](../reference/limitations.md) page.

## Config-save debounce and the config watcher

Settings changes are applied to in-memory config immediately, but the disk write is
**debounced by 500 ms** (`$__g_Cfg_SAVE_DEBOUNCE` in `includes/Config.au3`): a burst of
edits coalesces into a single write instead of hammering the INI. Separately, a config
watcher Adlib (`_AdlibConfigWatcher`, default 60000 ms) notices when the INI's
modification time changes underneath the app — for example if you edit it by hand — and
performs an **atomic reload**: it unregisters hotkeys, reloads config, re-registers
hotkeys, re-applies the desktop change, and re-arms the topmost Adlib with any new
interval. Doing the reload in one pass avoids the main loop observing half-updated config.

## Watchdog: staying on top

The widget must stay visible above the taskbar without strobing against other topmost
windows. `_ForceTopMost` (Adlib, `topmost_interval`, default 300 ms) re-asserts the
widget's position and z-order, but is **change-gated**: it only issues a
`SetWindowPos` when geometry actually changed, so an idle app does no work. When a peer
topmost window covers the widget, an occlusion check walks the z-order to re-raise the
widget above the cover — but only when cheaper "did anything move / did we lose the
topmost bit" gates fail first, so the expensive walk almost never runs. Performance
verification measured this re-assert holding the widget above an aggressive competitor
with **zero z-order strobing over 25 seconds** and about **+1% of one CPU core**
worst-case. In tray mode there is no widget and topmost enforcement is skipped entirely.

## Logging as a diagnostic

The optional file logger is the first tool for diagnosing intermittent problems: enable
it, set the level to `debug`, reproduce, and read the file. Its full behavior — levels,
file location, rotation, the non-blocking detached compression, and a
step-by-step diagnosis workflow — lives on the dedicated
[Logging & Diagnostics](../guides/logging.md) page. Crash reports (`crash_*.log`) are a
separate mechanism, described above.

## Update-check failure behavior

The background update check (`_UC_AdlibCheck` + `_UC_CheckResult`) uses a non-blocking
`InetGet` handle polled from the main loop. If the check fails — no network, GitHub
unreachable — the failure is simply logged as a warning and the temp file cleaned up;
there is no error popup and nothing stalls (`includes/UpdateChecker.au3`). A
user-initiated "Check for updates" or portable download runs a modal dialog that
**pumps its own message loop and is cancellable**, with the transfer running on a
background `InetGet` handle rather than a blocking spin-wait, so the app stays alive and
the dialog stays responsive throughout.

![A small themed dialog reading "Checking for updates..." centered on screen.](../assets/screenshots/update-checking.png)

*A manual update check shows a cancellable progress dialog while it contacts GitHub.*

When the check completes, the dialog reports the result. If you are on the latest build it
simply confirms so:

![An update-result dialog reading "You're up to date!" showing matching current and latest versions and a Close button.](../assets/screenshots/update-uptodate.png)

*When you are already current, the result dialog confirms it and offers nothing to download.*

If a newer release exists it shows the version and release date and offers a download:

![An update-result dialog reading "Update available!" with current v26.17, latest v27.02, a release date, and a "Download Latest" button.](../assets/screenshots/update-available.png)

*When a newer version exists, the dialog offers a one-click portable download. The download itself is only started if you click it.*

## Mitigations against specific failure modes

### Taskbar auto-hide oscillation

When the Windows taskbar is set to auto-hide, the widget must follow it in and out
without flickering. `includes/TaskbarAutoHide.au3` debounces the hide/show transitions
(separate hide and show timers) and runs the fade as a **non-blocking tick**
(`_TAH_FadeTick`, advanced from the main loop) rather than a blocking animation loop, so
rapid taskbar toggling neither strobes the widget nor stalls input.

### Explorer restarts

If `explorer.exe` crashes or is restarted, the widget must not die with it.
`includes/ExplorerMonitor.au3` polls the shell process (`__EM_Poll`, default 5000 ms);
on detecting the shell's death it logs a warning, tracks recovery with exponential
backoff, and can optionally auto-restart the shell (`monitor_auto_restart`). Because the
monitor runs in-process via an Adlib, the widget itself survives an Explorer crash and
re-asserts its position when the shell returns.

### Rapid desktop-switch handling

Fast relative navigation (holding next/prev, or frantic arrow clicks) used to lose
inputs. The chain of fixes is worth stating honestly:

- The original code did `_VD_GoTo` then a **blocking** `Sleep(50)` + `_RefreshIndex()`
  after every switch, which froze input during the settle.
- That was replaced with a **deferred** refresh (`_RequestDeferredRefresh` /
  `_ProcessPendingRefresh`, settle `$NAV_SETTLE_MS` = 50 ms) so input keeps flowing —
  but relative-nav handlers then read a stale `$iDesktop` during the 50 ms window and
  two quick inputs could collapse onto the same target. Performance testing flagged this
  as a regression and produced the "keep switches ≥ 300 ms apart" guidance.
- That guidance is now **obsolete**. `_NavigateTo` (in `desktop_switcher.au3`)
  optimistically advances the tracked index to the target immediately
  (`$iDesktop = $iNew`), so back-to-back relative navigation chains off a fresh index
  instead of the stale one. Reconciliation via the deferred `_RefreshIndex` and the
  event-driven `_WM_DESKTOPCHANGE` notification corrects `$iDesktop` to OS ground truth,
  so a denied, failed, or externally-driven switch can never leave the index permanently
  drifted (the pure reconciler is `_Nav_Reconcile` in `includes/VirtualDesktop.au3`).

What remains is the inherent Windows compositor switch cost (measured around a 55 ms
floor per switch), which no application can remove; at any human-plausible cadence every
input now lands and the widget converges to the correct desktop.

### Native switch-OSD suppression

To suppress the Windows native desktop-switch OSD during app-driven switches, `_VD_GoTo`
temporarily disables the client-area animation that gates it, then switches. Because the
shell reads that flag **asynchronously** after the switch, an immediate restore can let
the OSD slip through; instead the restore is **deferred** via a one-shot Adlib
(`__VD_ScheduleAnimRestore`) that is re-armed on every switch, so a burst of rapid
switches keeps the OSD suppressed and the flag is restored exactly once after switching
settles. A shutdown/error-safe flush (`__VD_FlushAnimRestore`) guarantees the system
setting is never left altered. This mechanism is **asymmetric by design**: it only does
anything when desktop animations are ON. When animations are already OFF the native OSD
never appears, so the guard is a no-op and suppression is satisfied by construction
(`includes/VirtualDesktop.au3`).

### Responsive Settings dialog

The Settings dialog used to be a hard modal: while it was open its own message loop ran and the
main loop did not, so the widget, tray, panels, toasts, ticks, and slideshow all froze until you
closed it. It is now **asynchronous**. The dialog's loop calls back once per iteration into
`_MainTick_FromDialog` (registered at startup by `_CD_RegisterMainCallbacks`), which runs the same
main-loop phase functions — GUI events, input, event flags, relayed IPC actions, hover/visuals, and
the timer/tick phase. So with Settings open the widget still switches desktops, the tray and panels
still respond, toasts and the taskbar-auto-hide fade still tick, the slideshow keeps stepping, and a
relayed CLI action still executes. Events are not double-processed (the dialog owns the single
`GUIGetMsg` read and only forwards events it did not consume, and `GUISwitch` is restored to the
dialog after each tick), and the dialog drops to the 15 ms popup sleep tier so the extra work stays
cheap. Nested sub-loops the dialog itself opens — the hotkey builder, folder/file pickers, and the
update check — deliberately do not run the tick.

### Locale fallback chain

A missing or incomplete translation must never leave a blank label. String lookups
(`_i18n` in `includes/i18n.au3`) resolve through a three-step fallback: **current locale
→ `en-US` → the hardcoded English default** passed at the call site. `en-US.ini` is
always loaded as the fallback dictionary regardless of the selected language, and if a
requested locale file is missing the app silently uses English. The result is that a
partially-translated or absent locale degrades gracefully rather than showing empty UI.

### Remaining blocking fades

Most animations are non-blocking ticks (toast, OSD, taskbar auto-hide, and the window
list all advance one step per main-loop pass). For honesty: the **generic menu and
modal-dialog fade-in/out** (`_Theme_FadeIn` / `_Theme_FadeOut` in `includes/Theme.au3`)
are still short blocking loops — roughly 64–72 ms at default fade settings — and are a
known, deferred conversion. They are brief and only occur on menu/dialog open/close, but
they are documented here rather than marketed around. See
[Known Limitations](../reference/limitations.md).
