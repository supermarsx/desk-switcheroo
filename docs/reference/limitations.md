---
title: Known Limitations
nav_order: 3
parent: Reference
---

# Known Limitations

This page lists Desk Switcheroo's real constraints, documented plainly rather than
marketed around. Some are hard platform limits, some follow from the runtime it is built
on, and some are known-but-open issues. Where a limitation has a mitigation, it links to
the relevant mechanism on the [Stability & Mitigations](../reference/stability.md) or
[Architecture & Patterns](../reference/architecture.md) pages. Every item here was
re-verified against the current code, not carried over from older notes.

## Platform

- **Windows 10 and 11, 64-bit only.** There is no 32-bit build and no support for older
  Windows. The app depends on the Windows virtual-desktop engine, which does not exist on
  Windows 8.1 or earlier. See the [Compatibility Matrix](../reference/compatibility.md).
- **OS desktop-name sync is Windows 11 only.** Reading and writing the real OS
  desktop names requires DLL support present on Windows 11
  (`_VD_HasNameSupport` in `includes/VirtualDesktop.au3`). On Windows 10 the app falls
  back to its own INI-stored labels (`desktop_labels.ini`) — you still get labels, but
  they are not synced to the names Windows itself shows in Task View.
- **No per-monitor virtual desktops.** Windows virtual desktops span all monitors; the
  app cannot give each monitor its own independent desktop set because Windows does not
  offer that. This is a Windows limitation, not an app one.

## The virtual-desktop DLL dependency

Desk Switcheroo drives Windows' virtual desktops through the unofficial, open-source
`VirtualDesktopAccessor.dll`. Windows exposes almost no public API for this, so the DLL
reaches into undocumented internals.

- **Windows feature updates can break it.** A Windows update that changes those internals
  can make the pinned DLL stop working until an updated DLL is shipped. This is the single
  most likely thing to break the app after a major Windows update.
- The app **detects and retries** a lost DLL handle (`_CheckDLLHealth`, every
  `dll_check_interval` ms; see [Stability](../reference/stability.md)), which recovers
  from transient handle loss — but it cannot paper over a genuine API break; that requires
  a DLL update.

## Single-threaded cooperative runtime

The app is written in AutoIt, which is single-threaded. All work — input, repaint,
timers, animations — shares one cooperative main loop
(see [Architecture](../reference/architecture.md)). A long synchronous operation stalls
the whole UI for its duration. Most hot-path stalls have been eliminated:

- Fades for the toast, OSD, taskbar auto-hide, and window list are non-blocking ticks.
- The 50 ms post-switch settle is deferred, not a blocking sleep.
- Log-rotation compression is launched detached, not waited on.
- Manual update check and download run a pumped, cancellable modal instead of freezing
  the app.
- The Settings dialog no longer freezes the widget while open: its message loop drives the
  main-loop phases, so the widget, panels, ticks, slideshow, and relayed IPC stay live
  (see [Stability](../reference/stability.md)).

What remains, honestly:

- **Heavy batch operations still run synchronously** and can briefly freeze the widget:
  drag-reordering a desktop across many positions, "gather / pull all windows here" across
  many desktops, and applying a profile whose desktop count differs a lot from the current
  one. These are user-initiated and infrequent, but during the operation the widget does
  not respond.
- **Generic menu and modal-dialog fade-in/out still block** for roughly 64–72 ms at
  default settings (`_Theme_FadeIn` / `_Theme_FadeOut`). Brief, and only on menu/dialog
  open and close, but real. This is a known deferred conversion.

## Rapid switching

The app-level input-collapse on rapid relative next/prev navigation has been **fixed**
via an optimistically-advanced index (`_NavigateTo`; see
[Stability](../reference/stability.md)), so back-to-back switches at any human cadence
all land. The remaining limit is the **Windows compositor's own switch cost** — measured
around a 55 ms floor per switch — which is inherent to Windows and cannot be removed by
any switcher.

## Rules engine is polling-based

The window-rules engine scans windows on a timer (`__WR_Poll` in
`includes/WindowRules.au3`) rather than reacting to window-creation events. A newly
opened window is therefore moved to its target desktop with a latency of up to one poll
interval, not instantly. There is also a cap on the number of rules
(`$__g_WR_MAX_RULES`). See the [Rules Engine & Hooks](../guides/rules-engine.md) guide.

## Hooks are fire-and-forget

User hooks (`includes/Hooks.au3`) run external commands asynchronously with PID tracking
and a timeout kill. They are **not** transactional: the app does not wait for a hook to
succeed before continuing, and a hook that exceeds its timeout is killed. Hooks also run
arbitrary commands **with your user privileges** — that is a capability, but also a
security consideration, covered in the [Rules Engine & Hooks](../guides/rules-engine.md)
guide.

## Idle CPU

Performance verification measured the current build using about **4% of one CPU core at
idle**, versus roughly 2.8% before the responsiveness rework — a modest but real,
reproducible increase attributed to diffuse per-iteration work across the main-loop
helpers (no single dominant cause was isolated). Memory is flat with no leak. On a
desktop this is immaterial; on a laptop running on battery it is worth being aware of.
This is a known-open item.

## Native switch-OSD suppression is conditional

The suppression of the Windows native desktop-switch OSD only takes effect when Windows
desktop animations are turned **on** — it works by momentarily toggling the animation
setting that gates the OSD (see [Stability](../reference/stability.md)). When animations
are already off the native OSD never appears anyway, so there is nothing to suppress and
the mechanism is a no-op. It is not a general-purpose OSD blocker.
