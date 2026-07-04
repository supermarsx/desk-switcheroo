---
title: Logging & Diagnostics
nav_order: 5
parent: Guides
---

# Logging & Diagnostics

Desk Switcheroo has an optional file logger for diagnosing problems. It is off by
default, writes plain-text lines to a single rotating file, and is designed so that
logging never blocks the widget — even when a log write triggers rotation and
compression. This page describes the logger, its configuration, and a workflow for
using it to diagnose issues. The implementation lives in `includes/Logger.au3`, driven
by the `[Logging]` section read in `includes/Config.au3`. For crash reports — a separate
mechanism — see [Stability & Mitigations](../reference/stability.md). The full key table
is on the [Advanced INI Reference](../configuration/ini-reference.md) page.

## Enabling logging

Logging is controlled by `logging_enabled` in the `[Logging]` INI section (default
`false`). Set it to `true` to turn the logger on. The setting is also exposed in the
Settings dialog. Changes apply live: `_ApplySettingsLive` (in `desktop_switcher.au3`)
tears the logger down and re-initializes it (`_Log_Shutdown` then `_Log_Init`) when you
save, so you can enable logging, change the level, or move the log folder without
restarting the app. When logging is disabled, `_Log_Init` is a no-op and every
`_Log_*` call returns immediately, so a disabled logger costs essentially nothing.

## Levels and what each captures

The logger has four severity levels, selected by `log_level` (enum
`error | warn | info | debug`, default `info`). Each level includes everything more
severe than itself:

| `log_level` | Captures | Typical use |
|---|---|---|
| `error` | Errors only (DLL handle lost, crash reports, failed operations) | Quietest; catch only failures |
| `warn` | Errors + warnings (rejected config paths, shell crash detected, update-check failures) | Light monitoring |
| `info` | The above + lifecycle messages (logger init, config reload, monitor start/stop) | Default; normal operation trace |
| `debug` | The above + per-operation detail on hot paths (desktop changes, etc.) | Reproducing a bug |

Internally the levels map to integers 1–4 (`error`=1 … `debug`=4), and a message is
written only when its severity is at or below the configured level
(`_Log_Error`/`_Log_Warn`/`_Log_Info`/`_Log_Debug` in `includes/Logger.au3`).

## Log file location

The log is always named `desk_switcheroo.log`. Where it lives is set by `log_folder`
(default empty). When `log_folder` is empty the file is written next to the executable
(`@ScriptDir`), keeping the app portable. When you set a folder, `_Cfg_GetLogFilePath`
expands these environment placeholders:

| Placeholder | Expands to |
|---|---|
| `%APPDATA%` | The current user's roaming AppData directory |
| `%TEMP%` | The user's temp directory |
| `%SCRIPTDIR%` | The folder containing the executable |

For example, `log_folder = %APPDATA%\DeskSwitcheroo` writes
`...\AppData\Roaming\DeskSwitcheroo\desk_switcheroo.log`. For safety the expanded path
is rejected if it contains `..` (directory traversal) or begins with `\\` (a UNC path);
in that case the logger logs a warning and falls back to writing next to the executable
(`_Cfg_GetLogFilePath` in `includes/Config.au3`).

## Line format

Each line is built by `__Log_Write` as:

```
[<timestamp>] [PID:<n>] [<LEVEL>] <message>
```

- **Timestamp** — a date part plus `HH:MM:SS`. The date part follows `log_date_format`
  (enum `iso | us | eu`, default `iso`): `iso` = `YYYY-MM-DD`, `us` = `MM/DD/YYYY`,
  `eu` = `DD/MM/YYYY`.
- **`[PID:<n>]`** — included only when `log_include_pid` is `true` (default `false`).
  Useful when more than one instance may write, or when correlating with Task Manager.
- **`[<LEVEL>]`** — `ERROR`, `WARN`, `INFO`, or `DEBUG`.
- **message** — the log text. There is no separate automatic per-function column; where
  a message needs to name the module or function it came from, the calling code includes
  that in the message text itself.

## Rotation

To bound disk use, the logger rotates the file by size. After every write,
`__Log_CheckRotation` compares the file against `log_max_size_mb` (default `5` MB,
range 1–50). When the file exceeds that size it is rotated:

1. The current file is closed.
2. The oldest kept file (`desk_switcheroo.log.<N>`, where `N` = `log_rotate_count`,
   default `3`, range 1–10) and its `.zip`, if any, are deleted.
3. Each numbered backup shifts up one (`.log.2` → `.log.3`, `.log.1` → `.log.2`, …).
4. The current log becomes `.log.1`.
5. A fresh empty `desk_switcheroo.log` is opened.

So `log_rotate_count = 3` keeps the live log plus three historical files. If an external
program is holding one of the files open (for example a tail viewer) and the rename
fails, the logger falls back to truncating the current file in place so logging can
continue rather than stalling.

## Detached compression (never blocks the UI)

When `log_compress_old` is `true` (default `false`), each rotated `.log.1` is
compressed to `.log.1.zip`. This is the one place logging could historically freeze the
app: earlier the compression ran as a synchronous `RunWait` that spun up `powershell.exe`
and waited 0.5–2 seconds — on the very write that tripped rotation, which can happen on
the hot desktop-change path. That stall has been removed.

Compression is now launched **detached**: `__Log_CheckRotation` starts
`powershell.exe … Compress-Archive` with a fire-and-forget `Run` and returns
immediately, so the log write never waits for the archiver. The rotated source path is
recorded in a small pending-cleanup queue (`__Log_EnqueuePendingCompress`). A later pass
(`__Log_ProcessPendingCompress`, called opportunistically on the next rotation check and
again at shutdown) deletes the source `.log.1` once its `.zip` exists. If the compressor
is still running the source is still locked, so the delete simply retries on the next
pass. A stuck compression is abandoned after a 30-second give-up timer
(`$__g_Log_iCompressTimeout`), leaving the uncompressed source in place — no data is
lost. The trade-off of enabling compression is that a rotated `.log.1` may briefly
coexist with its in-progress `.zip`; the queue reconciles that automatically.

## Immediate flush

`log_flush_immediate` (default `true`) calls `FileFlush` after every line, so the last
lines survive a hard crash — valuable precisely when you are logging to catch a crash.
Turning it off lets the OS buffer writes, which is marginally cheaper on disk I/O but
risks losing the final buffered lines if the process is killed abruptly. Leave it on
unless you are logging at `debug` on a very hot path and see disk contention.

## Performance cost of logging

At `info` level (the default when enabled) a healthy idle app produces no lines after
startup, so steady-state overhead is negligible — the performance verification measured
the app silent at idle once startup completed. Raising the level to `debug` adds lines
on frequent operations (every desktop change, hover transitions, etc.), and
`log_flush_immediate` adds a disk flush per line. For day-to-day monitoring keep `info`;
switch to `debug` only while actively reproducing a problem, then switch back.

## Diagnosing a problem with logs

A practical workflow:

1. In the `[Logging]` section (or the Settings dialog) set `logging_enabled = true` and
   `log_level = debug`, then save — the change applies live, no restart needed.
2. Reproduce the problem as directly as you can.
3. Open `desk_switcheroo.log` (next to the executable, or in your configured
   `log_folder`). Read from the bottom up.
4. Look for `ERROR` and `WARN` lines around the time of the failure. Some load-bearing
   ones: `VirtualDesktopAccessor DLL handle lost — attempting reload` (the virtual-desktop
   helper stopped responding), `explorer.exe crash detected` (the shell restarted under
   the app), `Config file changed externally, reloading` (a config hot-reload fired), and
   `rejected log folder path` (your `log_folder` was unsafe and fell back).
5. When reporting an issue, attach the log. If the app crashed, also attach the separate
   `crash_*.log` (see below).
6. Set `log_level` back to `info` (or disable logging) when done.

## Relationship to crash logs

Crash reports are a **separate** mechanism from this logger. When the app hits an
unhandled AutoIt error it writes a standalone `crash_<date>_<time>.log` directly to disk
— deliberately bypassing this logger, in case the logger itself is the crash source —
and shows a recovery dialog. Those files, their contents, and the recovery dialog are
documented on the [Stability & Mitigations](../reference/stability.md) page. The logger
still records a best-effort `ERROR` line for the crash as well, but the `crash_*.log`
is the authoritative artifact.
