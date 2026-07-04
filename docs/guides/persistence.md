---
title: Persistence & Profiles
nav_order: 3
parent: Guides
---

# Persistence & Profiles

Desk Switcheroo is **portable by design**: everything it remembers lives in plain INI files
and a `profiles` folder next to the executable (`@ScriptDir`), not in a scattered set of
system locations. This guide walks through each file, what it stores, and when it is written
or read, then covers named profiles, session restore, crash logs, the config watcher, and the
start-with-Windows entry.

## Files at a glance

| File / folder | Written by | Holds |
|---|---|---|
| `desk_switcheroo.ini` | `includes/Config.au3` | All settings — the main configuration. |
| `desk_switcheroo_state.ini` | `desktop_switcher.au3`, `includes/SessionRestore.au3` | Runtime state: last desktop, list scroll offset, and the saved session. |
| `desktop_labels.ini` | `includes/Labels.au3` | Per-desktop labels (also mirrored to Windows 11 desktop names). |
| `profiles\*.ini` | `includes/Profiles.au3` | Named snapshots of desktop count, labels, colors, and wallpapers. |
| `crash_YYYYMMDD_HHMMSS.log` | `desktop_switcher.au3` | Crash reports, one file per crash. |

All of these are created on demand — a fresh, unconfigured install writes them the first time
it needs to.

## The main configuration file

`desk_switcheroo.ini` holds every setting the app reads, organized into INI sections. It is
loaded once at startup by `_Cfg_Load` (`includes/Config.au3`) and re-written when you change
settings. You rarely edit it by hand — the Settings dialog is the usual path — but it is a
plain text file you can back up, copy between machines, or edit directly. The complete key
list is in the [Advanced INI Reference](../configuration/ini-reference.md); how the Settings
dialog and this file relate is covered in the
[Configuration overview](../configuration/index.md).

## Runtime state file

`desk_switcheroo_state.ini` is separate from your configuration; it stores transient runtime
state so the app can pick up where it left off. On shutdown (`_OnExit` in
`desktop_switcher.au3`) it writes a `[State]` section:

- `last_desktop` — the desktop that was active when the app closed.
- `list_visible` — whether the desktop list panel was open.
- `scroll_offset` — the scroll position of the desktop list.

On the next launch the app reads `scroll_offset` back and restores the list's scroll position
(`desktop_switcher.au3`, near the startup sequence). The same file also holds the `[Session]`
section used by session restore, described below.

## Desktop labels

Desktop names you assign are stored in `desktop_labels.ini` under a `[Labels]` section, keyed
`desktop_1`, `desktop_2`, and so on (`includes/Labels.au3`). On **Windows 11**, labels are
also kept in sync with the operating system's own virtual-desktop names: when you rename a
desktop in Desk Switcheroo the new name is pushed to Windows (so it shows in Task View), and
names you change in Task View are pulled back into the INI. This two-way sync is polled on a
timer set by `name_sync_interval` in the `[Behavior]` section (range 500–60000 ms, default
2000). On **Windows 10**, where the OS exposes no desktop-name API, the app falls back to INI
storage only (`_Labels_Init` checks `_VD_HasNameSupport`).

The sync logic is deliberately careful during desktop reorders and deletions: after a
swap or removal it defers a few sync polls (`_Labels_DeferSync`) so that transient,
mid-operation names Windows reports are not written back into the INI. Renaming, reordering,
and deleting desktops from the UI are covered in
[Desktop Management](desktop-management.md).

## Named profiles

Profiles let you save and restore whole desktop layouts by name — the desktop count plus every
desktop's label, accent color, and wallpaper. The feature is handled by
`includes/Profiles.au3` and must be enabled first (`profiles_enabled` in the `[Profiles]`
section). Profiles are stored one-per-file in a `profiles` folder next to the executable,
created on first save.

### Saving and loading

A saved profile (`_Prof_SaveProfile`) snapshots the current state into a profile INI with a
`[Meta]` section (name, created/modified timestamps, desktop count) plus `[Labels]`,
`[Colors]`, and `[Wallpapers]` sections. Loading a profile (`_Prof_LoadProfile`):

1. Adjusts the desktop count up or down to match the profile — creating or removing desktops
   from the end as needed.
2. Applies each desktop's saved label, color, and wallpaper (writing colors and wallpapers
   back into `desk_switcheroo.ini`).
3. Reloads the configuration so the running app reflects the changes.
4. Fires the `on_profile_load` hook (see the [Rules Engine & Hooks](rules-engine.md) guide).

Profiles can also be driven from the command line with `load-profile <name>` and
`save-profile <name>` (see [CLI Parameters](../configuration/cli.md)); both the hotkey and CLI
paths run through the same functions, so the hook fires either way.

### Name sanitization

Profile names are sanitized for filesystem safety before they become filenames
(`__Prof_SanitizeName`): only letters, digits, underscores, and dashes are kept, everything is
lowercased, an empty result becomes `default`, and names are capped at 64 characters. So a
profile you save as `Work — Main!` is stored as `workmain.ini`.

## Session restore

Session restore remembers which windows were on which desktop and puts them back on the next
launch. It is handled by `includes/SessionRestore.au3` and is off by default; enable it with
`session_restore_enabled` in the `[Session]` section.

- **On shutdown**, `_SR_SaveSession` enumerates every visible top-level window across all
  desktops and writes a `[Session]` entry per window into `desk_switcheroo_state.ini`, in the
  form `process|class|desktop` (for example `firefox.exe|MozillaWindowClass|2`).
- **On the next launch**, `_SR_RestoreSession` reads those entries, finds the matching running
  windows, and moves each back to its saved desktop.

Matching is by **process name first, with the window class as a tiebreaker**
(`__SR_MatchWindow`): if several windows share a process name, the one whose class also
matches wins, and each running window is only matched once. Because matching is by process and
class rather than by a specific window, session restore reconnects windows the same app has
reopened, but it cannot tell two identical windows of the same app apart.

Session restore deliberately ignores system and shell processes — `dwm.exe`, `explorer.exe`'s
desktop window (the `Progman`/`WorkerW` classes), `svchost.exe`, `RuntimeBroker.exe`, and a
number of others listed in `$__g_SR_aSkipProcs` — so it never tries to shuffle Windows' own
windows around. Windows on desktops beyond the saved count, and pinned windows (which report
no specific desktop), are skipped.

## Crash logs

If the app hits a fatal error it writes a standalone crash report before anything else, named
`crash_YYYYMMDD_HHMMSS.log` (`__WriteCrashLog` in `desktop_switcher.au3`). The writer
deliberately bypasses the normal logger — in case the logger itself is what failed — and
writes directly to a file. It first tests whether the executable's own folder
(`@ScriptDir`) is writable and, if not (for example an installed copy under
`Program Files`), falls back to the system temp folder (`@TempDir`).

Each report captures a timestamp, the crash reason and error details, an app-state snapshot
(app version, current desktop, whether each popup was visible, tray mode, drag state) and
system info. Crash logs are a **separate mechanism** from the ordinary log file — see the
[Logging & Diagnostics](logging.md) guide for the everyday log and
[Stability & Mitigations](../reference/stability.md) for the crash-recovery dialog that offers
to copy, open, restart, or close after a crash.

## Config watcher

Desk Switcheroo can watch its own configuration file and hot-reload it when it changes on disk
— useful if you edit the INI by hand or a profile/CLI action rewrites it. This is controlled
by `config_watcher_enabled` in the `[Behavior]` section (off by default) and
`config_watcher_interval` (range 5000–300000 ms, default 60000). When enabled, an Adlib timer
(`_AdlibConfigWatcher`) polls the file's modification time and, on a change, re-reads the
config, re-registers hotkeys, and re-applies the current desktop's appearance without a
restart.

## Start with Windows

The start-with-Windows option adds Desk Switcheroo to the current user's login startup. It is
controlled by `start_with_windows` in the `[General]` section and applied by writing a value
named `DeskSwitcheroo` under the registry key
`HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` (`_Cfg_EnableStartup` /
`_Cfg_DisableStartup` in `includes/Config.au3`). The value is the app's launch command with
the `-autostart` flag appended. Because it is written under `HKCU` (the current user) rather
than a machine-wide key, it requires no administrator rights and only affects the user who set
it.

## Backing up and moving your setup

Since everything lives next to the executable, migrating to another machine or taking a backup
is just a file copy. Copy `desk_switcheroo.ini`, `desktop_labels.ini`,
`desk_switcheroo_state.ini`, and the `profiles` folder. The
[Deployment & Lifecycle](../reference/lifecycle.md) reference covers backup, migration, and
per-channel uninstall cleanup in more detail.

## Related pages

- [Desktop Management](desktop-management.md) — creating, renaming, reordering, and deleting
  the desktops whose labels and colors these files persist.
- [Coloring & Theming](coloring.md) — the accent colors and wallpapers profiles capture.
- [Rules Engine & Hooks](rules-engine.md) — the `on_profile_load` and `on_shutdown` hooks.
- [Advanced INI Reference](../configuration/ini-reference.md) — the `[Session]`, `[Profiles]`,
  `[Behavior]`, and `[General]` keys named here.
