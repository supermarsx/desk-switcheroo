---
title: CLI Parameters
nav_order: 1
parent: Configuration
---

# CLI Parameters

Desk Switcheroo accepts command-line arguments for querying virtual-desktop state and for
controlling a running instance. The command-line interface is implemented in `includes/CLI.au3`
and dispatched from `desktop_switcher.au3` at startup. For editing settings instead, see
[Configuration](index.md) and the [Advanced INI Reference](ini-reference.md).

## Command forms

A command is a single token with one of three interchangeable prefixes — `--`, `-`, or `/`:

```
desk_switcheroo.exe --get-current
desk_switcheroo.exe -get-current
desk_switcheroo.exe /get-current
```

The parser (`_CLI_ParseArgs`) strips the prefix, lowercases the command, and reads up to two
following tokens as arguments (a token starting with `-` or `/` is treated as the next flag, not an
argument). A quoted argument that contains spaces is passed through as one value, which is how
`--rename` takes a label:

```
desk_switcheroo.exe --rename 2 "Work"
```

The legacy `-autostart` flag is ignored by the CLI parser (it is handled separately by the app's
start-with-Windows path), so it never counts as a command.

## Query commands

Query commands read state and print to standard output. They run **standalone** — the process
starts, executes the query locally (`_CLI_ExecuteLocal`), prints the result, and exits immediately,
whether or not a widget is already running. These are the commands that produce output on standard
output for scripting (see the caveat under [dispatch behavior](#how-the-executable-dispatches-its-own-command-line) about queries and the running widget).

| Command | Output |
|---|---|
| `--help` | Full usage text. |
| `--version` | The application version string, one line. |
| `--list-desktops` | One line per desktop: `N: label`. |
| `--get-current` | The current desktop number, one line. |
| `--status` | A JSON object: `{"current":N,"count":M,"desktops":[{"id":1,"name":"…"},…]}`. |

The `--status` JSON is built by hand in `__CLI_PrintStatus` and escapes `\` and `"` in labels, so
it is safe to pipe into a JSON parser.

## Action commands

Action commands change desktop state. They are recognized by the parser and defined for delivery to
a **running instance** over the app's `WM_COPYDATA` IPC channel (see below).

| Command | Args | Effect |
|---|---|---|
| `--goto N` | desktop number (1-based) | Switch to desktop *N*. |
| `--next` | — | Switch to the next desktop (honors `wrap_navigation`). |
| `--prev` | — | Switch to the previous desktop (honors `wrap_navigation`). |
| `--add-desktop` | — | Create a new virtual desktop. |
| `--remove-desktop N` | desktop number | Remove desktop *N* (and shift labels). |
| `--rename N "label"` | number + label | Rename desktop *N*. |
| `--move-window N` | desktop number | Move the currently active window to desktop *N*. |
| `--toggle-list` | — | Show/hide the desktop list panel. |
| `--toggle-carousel` | — | Toggle carousel (auto-rotate) mode. |
| `--load-profile "name"` | profile name | Load a saved profile. |
| `--save-profile "name"` | profile name | Save the current state as a profile. |

`--goto`, `--remove-desktop`, `--rename`, and `--move-window` validate their arguments and print an
error (and, for an unknown command, the help text) if the number is missing or out of range.

## The IPC channel

A running instance creates a hidden window titled `DeskSwitcheroo_IPC` and registers a
`WM_COPYDATA` handler (`_CLI_RegisterIPC` → `_CLI_HandleIPC`). Messages are accepted only when the
`COPYDATASTRUCT.dwData` field equals the magic value `0x44534B` (ASCII "DSK"); the payload is the
command string (for example `goto 3` or `rename 2 Work`). On receipt, navigation and
desktop-management commands are executed directly, while the GUI-level commands (`toggle-list`,
`toggle-carousel`, `load-profile`, `save-profile`) are queued for the main loop to pick up
(`_CLI_CheckIPCPending`). This is a stable contract an external tool can target to drive a running
widget.

### How the executable dispatches its own command line

When you run `desk_switcheroo.exe` with a command, the startup path in `desktop_switcher.au3`
handles it as follows:

- **Action commands** are relayed to a running instance. Before the singleton block (which would
  otherwise kill the running widget) and before the new process registers its own IPC window, the
  startup path calls `_CLI_SendToRunning`, which locates the running instance's `DeskSwitcheroo_IPC`
  window and sends the command over `WM_COPYDATA`. If a running instance is found, the command is
  delivered and the launching process exits `0` without starting a second widget. So
  `desk_switcheroo.exe --goto 3` now switches the already-running widget to desktop 3.
- **Action commands with no running instance to relay to** fall through and execute locally against
  the OS (`_CLI_ExecuteLocal`), then exit. Because virtual desktops are global to the session, the
  desktop operations — `goto`, `next`, `prev`, `add-desktop`, `remove-desktop`, `rename`, and
  `move-window` — work standalone and exit `0` on success. The GUI-only actions — `toggle-list`,
  `toggle-carousel`, `load-profile`, and `save-profile` — need a widget to drive, so with no
  instance running they print a "requires a running instance" error and exit `1` rather than
  spawning a persistent widget as a side effect.
- **Query commands** execute locally and the process exits (`_CLI_ExecuteLocal` then `Exit`).

> **Known caveat (open follow-up):** query commands do *not* go through the early relay, so with
> `singleton_enabled` on (the default) launching the executable for a query — for example
> `desk_switcheroo.exe --get-current` — triggers the singleton block and **kills the running
> widget** as a side effect before printing its answer and exiting. Action commands are exempt
> (the relay path suppresses the singleton kill). Until a lightweight query relay lands, script
> query calls against a session where you want to keep the widget running by talking to the IPC
> channel directly (below) instead of shelling out to the executable.

## Scripting examples

Query commands, which are the standalone-safe ones, compose cleanly in PowerShell:

```powershell
# Current desktop number
$current = & .\desk_switcheroo.exe --get-current

# Parse the JSON status
$status = & .\desk_switcheroo.exe --status | ConvertFrom-Json
Write-Host "On desktop $($status.current) of $($status.count)"

# List desktops
& .\desk_switcheroo.exe --list-desktops
```

## Exit behavior

For a query command, the process runs the query and exits (exit code `0` on success; the query
helpers return `False` and print an error for bad input). If `VirtualDesktopAccessor.dll` cannot be
loaded, the app exits with code `1` before any command runs. When no recognized command is present,
the app starts normally as the widget.
