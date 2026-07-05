---
title: Rules Engine & Hooks
nav_order: 4
parent: Guides
---

# Rules Engine & Hooks

Desk Switcheroo ships two related automation subsystems. The **window rules engine**
(`includes/WindowRules.au3`) watches for windows and moves them to a designated desktop
automatically. The **hook system** (`includes/Hooks.au3`) runs an external command of your
choosing whenever a specific application event fires. Both are configured entirely through the
INI file, both are disabled by default, and both are independent of each other — you can use
either alone.

This page documents current behavior verified against the two modules. For the flat key/type/
default tables, see the [Advanced INI Reference](../configuration/ini-reference.md).

## Window rules

### What it does

When enabled, the rules engine polls all top-level windows on a timer and moves any window that
matches a rule to the desktop that rule names — for example, "always send Chrome to desktop 3."
It runs in the background and applies each matching window once (it will not keep re-shuffling a
window you subsequently move by hand). All logic lives in `includes/WindowRules.au3`.

### Configuration

Rules live in the `[Rules]` section of `desk_switcheroo.ini`:

```ini
[Rules]
rules_enabled       = true
rules_poll_interval = 2000
rule_1              = chrome.exe|3
rule_2              = class:CabinetWClass|1
```

| Key | Default | Meaning |
|---|---|---|
| `rules_enabled` | `false` | Master on/off switch for the engine. |
| `rules_poll_interval` | `2000` | Milliseconds between polls, clamped to **500–30000** (`_Cfg_GetRulesPollInterval` plus a second clamp in `_WR_Start`). |
| `rule_1` … `rule_50` | — | Individual rules. Up to **50** rules are read (`$__g_WR_MAX_RULES` in `WindowRules.au3`). |

`rules_enabled` and `rules_poll_interval` are exposed in **Settings → Behavior → Rules**
sub-tab (`includes/ConfigDialog.au3`). The individual `rule_N` rows are **INI-only** — there is
no UI to edit them, so you add them by editing the file directly.

### Rule syntax

Each rule has the form:

```
rule_N = pattern|target_desktop
```

The value is split on a single `|` into a **pattern** and a **target desktop number**
(`_WR_LoadRules`). A rule is discarded (with a warning to the log) if it does not split into
exactly two parts, if the target is less than `1`, or if the pattern is empty.

- **`target_desktop`** is a 1-based desktop number. At apply time the engine also checks the
  target against the live desktop count (`_VD_GetCount`); if the target desktop does not exist
  yet, the move is skipped and logged rather than creating a desktop.
- **`pattern`** is matched one of two ways, decided by a `class:` prefix (`__WR_MatchWindow`):

| Pattern form | Example | Matches on | Case sensitivity |
|---|---|---|---|
| Process name (default) | `chrome.exe` | The window's executable file name | **Case-insensitive** (both sides lowercased) |
| `class:` prefix | `class:CabinetWClass` | The window's Win32 class name | **Case-sensitive** (exact string compare) |

The process form compares against the executable's file name (derived from
`_WinAPI_GetProcessFileName`), so use the full name including the extension, e.g. `chrome.exe`,
not `chrome`. The class form strips the `class:` prefix and compares the remainder exactly, so
class names must match the OS casing precisely (`CabinetWClass`, not `cabinetwclass`).

### How polling works

`_WR_Start` loads the rules and registers `__WR_Poll` on an AdlibRegister timer at the
configured interval. Each poll (`__WR_Poll`):

1. Enumerates all top-level windows with `WinList()`.
2. Skips windows with no title, and skips any window already recorded as moved.
3. For each remaining window, checks it against every rule in order and applies the **first**
   match (`__WR_MatchWindow` returns the first matching rule index).
4. Moves the window via `_VD_MoveWindowToDesktop` (`__WR_ApplyRule`) and records the window
   handle so it is not touched again.

The moved-window record is a `Scripting.Dictionary` keyed by window handle. A window is recorded
as handled **whether or not the move actually succeeded**, which prevents the engine from
retrying a failing move on every poll. It is also recorded (without moving) when it is already on
the target desktop. Because matching happens only at poll time, the maximum latency between a
window appearing and being moved is one poll interval — this is a deliberate, honest limitation
of a polling design (see [Known Limitations](../reference/limitations.md)).

Every `$__g_WR_CLEANUP_INTERVAL` polls (currently **10**), `__WR_CleanupStaleHwnds` prunes the
moved-window record of handles whose windows have closed (checked with the `IsWindow` API), so
the record does not grow without bound and a reused handle is re-evaluated cleanly.

### Enabling and toggling rules

There are three ways to turn the engine on, all landing on the same in-memory
`rules_enabled` flag:

1. **INI:** set `rules_enabled = true` and restart (or re-save Settings to trigger a live
   re-apply).
2. **Settings dialog:** the "Enable window rules engine" checkbox on the **Behavior → Rules**
   sub-tab.
3. **Global hotkey:** bind `hotkey_toggle_rules` (empty by default) in `[Hotkeys]`. Pressing it
   runs `_HK_ToggleRules`, which flips the flag, **persists the change with `_Cfg_Save()`
   first**, then calls `_WR_Start`/`_WR_Stop` and shows a toast. Persisting before restarting is
   deliberate: `_WR_LoadRules` re-reads the `rule_N` rows from disk, while `_WR_Start` reads the
   just-toggled state from the in-memory getters, so the hotkey takes effect immediately. (An
   earlier version read stale state here; the current code is correct.)

`_WR_Start` is defensive: it no-ops if `rules_enabled` is false, and it does not start if no
valid rules were loaded. When you re-apply settings live, the app calls `_WR_Stop` then
`_WR_Start`, so edits to the interval or rule list take effect without a full restart.

### Worked examples

Send your browser to desktop 3 and your file-manager windows to desktop 1, checking twice a
second:

```ini
[Rules]
rules_enabled       = true
rules_poll_interval = 500
rule_1              = firefox.exe|3
rule_2              = class:CabinetWClass|1
```

Route a specific IDE by process name and a chat app to a "comms" desktop:

```ini
[Rules]
rules_enabled = true
rule_1        = Code.exe|2
rule_2        = slack.exe|4
```

Note that `Code.exe` (Visual Studio Code) is matched case-insensitively, so `code.exe` would
work equally well; the `class:` example above must match the OS class casing exactly.

## Hooks

### What it does

The hook system runs an external command whenever a named application event occurs — for
instance, launching a notification script every time you change desktops, or appending a line to
your own log on shutdown. Hooks are defined in the `[Hooks]` INI section, are disabled by
default, and are executed by `includes/Hooks.au3`.

> **Security note:** a hook is an **arbitrary command line run with your user privileges**, in the
> app's script directory, with a hidden window (`Run(..., @ScriptDir, @SW_HIDE)`). Anyone who can
> edit your `desk_switcheroo.ini` can make the app run any program as you. Only enable hooks with
> commands you trust, and treat the INI file as security-sensitive if hooks are on.

### Configuration

```ini
[Hooks]
hooks_enabled = true
hooks_timeout = 10000
on_desktop_change = powershell -Command "New-BurntToastNotification -Text 'Desktop {desktop}'"
on_shutdown       = cmd /c echo shutdown at desktop {desktop} >> C:\logs\ds.log
```

| Key | Default | Meaning |
|---|---|---|
| `hooks_enabled` | `false` | Master on/off switch (`_Hooks_Init`). Must be exactly `true` (case-insensitive) to enable. |
| `hooks_timeout` | `10000` | Per-hook timeout in milliseconds, clamped to **1000–300000**. A hook still running past this is killed. |

Both keys are **INI-only** — there is no hooks UI anywhere in `includes/ConfigDialog.au3`. Every
other key in the `[Hooks]` section is treated as a hook definition (`hooks_enabled` and
`hooks_timeout` are explicitly skipped when loading, in `_Hooks_LoadHooks`).

### Events

A hook key is an **event name**. The valid events are defined by the `$__HOOKS_EVENTS` constant
in `Hooks.au3`, and all **eight** are actually fired by the running application (verified against
`desktop_switcher.au3` and `includes/Profiles.au3`):

| Event | Fires when | Variables provided |
|---|---|---|
| `on_startup` | The app finishes starting | `desktop`, `desktop_count` |
| `on_shutdown` | The app is exiting | `desktop`, `desktop_count` |
| `on_desktop_change` | You switch to another desktop | `desktop`, `desktop_name`, `desktop_count`, `prev_desktop` |
| `on_desktop_create` | A desktop is added | `desktop`, `desktop_count` |
| `on_desktop_delete` | A desktop is removed | `desktop`, `desktop_count` |
| `on_window_move` | A window is sent to a desktop | `desktop`, `window_title`, `window_process` |
| `on_profile_load` | A named profile is loaded | `profile`, `desktop_count` |
| `on_slideshow_start` | The desktop slideshow starts | `mode`, `direction`, `steps`, `loop` |
| `on_slideshow_step` | The slideshow advances one step | `desktop`, `step`, `desktop_count` |
| `on_slideshow_stop` | The slideshow stops | `reason` |
| `on_carousel_tick` | *(Deprecated)* Fires on every slideshow step, alongside `on_slideshow_step` | `desktop`, `desktop_count` |

`on_carousel_tick` is retained only for backward compatibility with hook scripts written for
the former carousel; it still fires on every slideshow step. New hooks should use
`on_slideshow_step`.

An unknown event name is ignored with a warning (`__Hooks_IsValidEvent`).
`window_process` on `on_window_move` is currently sent empty, so `{window_process}` will
substitute to nothing.

### Multiple hooks per event

To attach more than one command to the same event, add a numeric suffix to the key. A trailing
`_<number>` is stripped to find the base event name, as long as that base is a known event
(`__Hooks_ParseHookLine`):

```ini
[Hooks]
hooks_enabled       = true
on_desktop_change   = notify.exe {desktop}
on_desktop_change_2 = log.exe {desktop} {prev_desktop}
```

Both fire on every desktop change. The line is **not** split on commas — this is intentional so a
command can contain commas (such as PowerShell argument lists) without being broken apart. Up to
**100** hooks total are loaded (`$__HOOKS_MAX_HOOKS`); beyond that, extra definitions are ignored
with a warning.

### Variable substitution

Placeholders of the form `{name}` in a hook command are replaced with the event's values before
the command runs (`__Hooks_SubstituteVars`). The variable names available per event are listed in
the table above. For example, with `on_desktop_change`:

```ini
on_desktop_change = cmd /c echo Now on {desktop} ({desktop_name}), came from {prev_desktop} >> log.txt
```

An unrecognized `{name}` is left in the command literally (only known variables are substituted).

### Execution model

Regular hooks run **asynchronously and fire-and-forget** (`__Hooks_Execute` with `Run`), so a
slow hook never blocks the widget's event loop. Each launched hook's PID is tracked (up to
**20** at a time, `$__HOOKS_MAX_PIDS`) alongside a start timer. On the next time any event fires,
`__Hooks_CheckTimeouts` runs first: it reaps hooks that have finished on their own and
force-kills (`ProcessClose`) any still running past `hooks_timeout`. So the timeout is a safety
cap on runaway hook processes, enforced lazily at the next fire and again at shutdown.

`on_shutdown` is the one exception. Because the app is about to exit — and `_Hooks_Shutdown`
kills any tracked PIDs during teardown — shutdown hooks are fired **synchronously with a bounded
wait** (`_Hooks_Fire(..., True)` → `__Hooks_ExecuteSyncCapped`). That variant launches the hook
and blocks until it exits or `hooks_timeout` elapses, whichever comes first, killing it if it
overruns. This lets a shutdown hook actually run to completion (within the timeout) instead of
being terminated the instant it starts. The blocking wait is only safe here precisely because the
UI loop is already ending.

`_Hooks_TestHook` runs a single command synchronously with `RunWait` and returns its exit code —
used for testing a command in isolation, not on the live event path.

### Worked examples

Toast on every desktop change, and log shutdown to a file:

```ini
[Hooks]
hooks_enabled     = true
hooks_timeout     = 5000
on_desktop_change = powershell -NoProfile -Command "New-BurntToastNotification -Text 'Switched to desktop {desktop}: {desktop_name}'"
on_shutdown       = cmd /c echo %DATE% %TIME% shutdown on desktop {desktop} >> "%USERPROFILE%\ds-sessions.log"
```

Run a per-desktop setup script when a profile is loaded, and mirror desktop changes into your own
audit log with two hooks:

```ini
[Hooks]
hooks_enabled       = true
on_profile_load     = cmd /c "C:\scripts\on-profile.bat" {profile}
on_desktop_change   = cmd /c echo enter {desktop} >> C:\logs\audit.log
on_desktop_change_2 = cmd /c echo left {prev_desktop} >> C:\logs\audit.log
```

For appending to the app's own diagnostic logs instead of a hook, see
[Logging & Diagnostics](logging.md). Profiles that trigger `on_profile_load` are covered in
[Persistence & Profiles](persistence.md), and the end-to-end switch flow that fires
`on_desktop_change` is described in [How It Works](../how-it-works.md).
