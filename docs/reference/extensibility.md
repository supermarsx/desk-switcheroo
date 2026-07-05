---
title: Extensibility & Integration
nav_order: 8
parent: Reference
---

# Extensibility & Integration

Desk Switcheroo has no plugin system and no embedded scripting runtime — you cannot load code
into the process. What it does offer is a set of **integration surfaces** designed to be
driven from the outside: event **hooks** that run your commands, a **CLI** plus a
`WM_COPYDATA` **IPC** channel that external tools can send to, declarative **window rules**,
and named **profiles** for context switching. This page is about what you can *build* with
those surfaces; the syntax details live on the pages it links to.

If you just want to configure the app, see [Configuration](../configuration/index.md). If you
want to change the source, see the [Development Guide](development.md) and
[Building from Source](building.md).

## The extension surfaces at a glance

| Surface | What it is | Best for | Reference |
|---|---|---|---|
| Hooks | Run a command when an app event fires | Notifications, logging, automation chains | [Rules Engine & Hooks](../guides/rules-engine.md#hooks) |
| CLI | Command-line queries and actions | Scripting desktop state, status readouts | [CLI Parameters](../configuration/cli.md) |
| `WM_COPYDATA` IPC | Send a command to a running instance | Driving the live widget from another tool | [below](#driving-a-running-instance-the-ipc-contract) |
| Window rules | Declarative "app → desktop" placement | Auto-organizing windows without code | [Rules Engine & Hooks](../guides/rules-engine.md#window-rules) |
| Profiles | Named, saved configuration sets | Switching whole contexts on demand | [Persistence & Profiles](../guides/persistence.md) |
| Locales | Add a language | Translating the UI | [Building from Source](building.md#adding-a-locale) |

## Hooks: the primary extension point

Hooks are the main way to make the app *do something of yours* when something happens. The
hook system (`includes/Hooks.au3`) fires on application events and runs a command template you
define in the `[Hooks]` INI section. The full event list, syntax, and execution model are in
[Rules Engine & Hooks](../guides/rules-engine.md#hooks); the events you can hang behavior off
are, from `$__HOOKS_EVENTS` in the code:

`on_desktop_change`, `on_desktop_create`, `on_desktop_delete`, `on_window_move`,
`on_profile_load`, `on_startup`, `on_shutdown`, `on_slideshow_start`, `on_slideshow_step`,
`on_slideshow_stop`, and `on_carousel_tick`.

The three `on_slideshow_*` events cover the desktop slideshow: `on_slideshow_start`
(`mode`, `direction`, `steps`, `loop`), `on_slideshow_step` (`desktop`, `step`,
`desktop_count`) on every advance, and `on_slideshow_stop` (`reason`). For backward
compatibility, the legacy `on_carousel_tick` (`desktop`, `desktop_count`) still fires on
every slideshow step alongside `on_slideshow_step`, so existing hook scripts keep working;
new hooks should prefer `on_slideshow_step`.

Because a hook is just a command line — run asynchronously with per-process timeout tracking
(`__Hooks_Execute`, `__Hooks_CheckTimeouts`) and `{1}`-style variable substitution
(`__Hooks_SubstituteVars`) — you can build quite a lot on top of them:

- **Notifications** — pop a toast, send a Slack/Discord webhook, or ping a phone when you
  switch to (or away from) a particular desktop.
- **Logging and telemetry** — append a line to your own log or a time-tracking tool on
  `on_desktop_change` or `on_window_move`, so you can see where your day actually went.
- **Automation chains** — on `on_startup` launch the apps a desktop needs; on
  `on_profile_load` reconfigure external tools to match the profile you just loaded; on
  `on_shutdown` snapshot or sync something before the app exits.

A worked example, wiring a PowerShell notification to desktop changes via the `[Hooks]`
section:

```ini
[Hooks]
hooks_enabled=true
hooks_timeout=10000
on_desktop_change=powershell -NoProfile -Command "[console]::beep(800,120)"
```

> **Security note.** Hooks run arbitrary commands with your user privileges, no sandbox. Only
> put commands you trust in the `[Hooks]` section, and treat a shared or synced
> `desk_switcheroo.ini` as executable content, not just settings.

## Driving a running instance: the IPC contract

For tools that need to *control the live widget* — switch it, rename a desktop, toggle a
panel — Desk Switcheroo exposes a `WM_COPYDATA` inter-process channel
(`includes/CLI.au3`). This is the contract to target when a hook or an external script needs
to talk to the running app. The command vocabulary is the same as the CLI, documented in
[CLI Parameters](../configuration/cli.md); what follows is the wire-level format an
integrator needs.

**The message format.** A running instance creates a hidden receiver window and registers a
`WM_COPYDATA` handler (`_CLI_RegisterIPC` → `_CLI_HandleIPC`). To send it a command:

| Field | Value |
|---|---|
| Target window | Title `DeskSwitcheroo_IPC`, class `AutoIt v3 GUI` (find it by title) |
| Message | `WM_COPYDATA` (`0x004A`) |
| `COPYDATASTRUCT.dwData` | The magic number `0x44534B` (ASCII `"DSK"`) — messages with any other value are ignored |
| `COPYDATASTRUCT.cbData` | Byte length of the payload including its terminating NUL (must be 1–4096) |
| `COPYDATASTRUCT.lpData` | The command string, e.g. `goto 3`, `next`, `rename 2 Work`, `toggle-list` |

On receipt the app validates the magic number and length, then dispatches
(`__CLI_ProcessIPCCommand`): navigation and desktop-management commands run immediately, while
GUI-only commands (`toggle-list`, `toggle-slideshow`, `load-profile`, `save-profile`) are queued
and consumed on the next main-loop pass by `_ProcessIPCPending` — which also runs from the Settings
dialog's tick, so a relayed GUI command is acted on even with Settings open. The shipped executable
itself uses exactly this channel —
running `desk_switcheroo.exe --next` while an instance is up relays the command over IPC to
that instance (`_CLI_SendToRunning` in the startup path) rather than starting a second widget.

**Worked example — drive the widget from PowerShell.** This sends a raw `WM_COPYDATA`
message, so it works even from a script that is not the app's own executable:

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DeskIpc {
  [StructLayout(LayoutKind.Sequential)]
  public struct COPYDATASTRUCT { public IntPtr dwData; public int cbData; public IntPtr lpData; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, ref COPYDATASTRUCT lParam);
}
"@

function Send-Desk([string]$cmd) {
  $h = [DeskIpc]::FindWindow("AutoIt v3 GUI", "DeskSwitcheroo_IPC")
  if ($h -eq [IntPtr]::Zero) { throw "Desk Switcheroo is not running" }
  $bytes = [Text.Encoding]::ASCII.GetBytes($cmd + "`0")
  $p = [Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length)
  [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $p, $bytes.Length)
  $cds = New-Object DeskIpc+COPYDATASTRUCT
  $cds.dwData = [IntPtr]0x44534B      # "DSK" magic
  $cds.cbData = $bytes.Length
  $cds.lpData = $p
  [void][DeskIpc]::SendMessage($h, 0x004A, [IntPtr]::Zero, [ref]$cds)  # 0x004A = WM_COPYDATA
  [Runtime.InteropServices.Marshal]::FreeHGlobal($p)
}

Send-Desk "goto 3"          # switch the running widget to desktop 3
Send-Desk "rename 3 Build"  # rename desktop 3
```

The same pattern works from AutoHotkey or C — anything that can call `FindWindow` and
`SendMessage` with a `COPYDATASTRUCT`. For *reading* state instead (current desktop, count,
labels) prefer the standalone query commands, which print to stdout and exit without needing a
running instance; `--status` emits JSON that pipes cleanly into a parser. See
[CLI Parameters](../configuration/cli.md#query-commands).

## Window rules: declarative window placement

Window rules are the no-code way to keep windows organized: you declare `pattern → target
desktop` lines in the `[Rules]` INI section and a polling engine moves matching windows onto
their desktop automatically (`includes/WindowRules.au3`). Because rules match on process name
(or window class with a `class:` prefix), you can express things like "the browser always
lives on desktop 2" or "my IDE belongs on desktop 3" without writing any code. Full syntax,
matching semantics, the rule cap, and the polling interval are in
[Rules Engine & Hooks](../guides/rules-engine.md#window-rules). Rules are declarative and
polling-based, so placement latency is bounded by the poll interval — see
[Known Limitations](limitations.md).

## Profiles: context switching

A **profile** is a named, saved snapshot of configuration you can reload on demand
(`includes/Profiles.au3`), stored as its own INI with a sanitized filename. Profiles are an
integration surface because they can be driven: load or save one from the CLI/IPC
(`load-profile "name"` / `save-profile "name"`) or from a hook on `on_profile_load`, which
lets an external trigger flip the app between whole contexts — a "focus" profile versus a
"presentation" profile, say. What a profile captures and how names are sanitized is covered in
[Persistence & Profiles](../guides/persistence.md).

## Adding a locale

Translations are data, not code: each language is an INI under `locales/` keyed exactly like
`en-US.ini`, and adding one is a documented, PR-friendly contribution. The step-by-step —
copying `en-US.ini`, translating values, and validating parity with `scripts/locale-check.ps1`
— is in [Building from Source](building.md#adding-a-locale). There are **34** locales today,
and missing or extra keys are caught by the locale check.

## What is *not* extensible

Being honest about the boundaries so you do not go looking for something that is not there:

- **No plugin API.** You cannot load a DLL, module, or add-in into the process to add features.
- **No embedded scripting.** There is no Lua/JS/Python runtime inside the app; "scripting" here
  means *your* external scripts driving it through the CLI, IPC, and hooks.
- **Hooks run external commands only.** A hook launches a separate process
  (`Run`/`RunWait`); it cannot call into the app's internals or return data back into it.
- **The IPC vocabulary is fixed.** You can send the documented commands; there is no
  general-purpose "set any setting" or "call any function" message. To change settings
  programmatically, edit the INI (the config watcher hot-reloads it) rather than sending IPC.
- **Rules and hooks are the extent of built-in automation.** Anything more bespoke is built
  *around* the app with those surfaces, not *inside* it.

For the internal design that these surfaces sit on — the event loop, the IPC handler, the
config system — see [Architecture & Patterns](architecture.md).

## Related pages

- [Rules Engine & Hooks](../guides/rules-engine.md) — full hook and rule syntax.
- [CLI Parameters](../configuration/cli.md) — the command vocabulary and query output.
- [Persistence & Profiles](../guides/persistence.md) — what profiles capture.
- [Building from Source](building.md) — adding a locale and building the app.
- [Architecture & Patterns](architecture.md) — the internal design of these surfaces.
- [Known Limitations](limitations.md) — including the polling-latency and no-plugin notes.
