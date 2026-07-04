---
title: Configuration
nav_order: 5
has_children: true
---

# Configuration

Desk Switcheroo keeps all of its settings in a single INI file next to the executable. You
can change settings two ways: through the **Settings** dialog (the config window) or by editing
the INI directly. Both routes write the same keys, so anything you can do in one you can do in
the other — the Settings dialog just covers the common subset with validated controls.

This section has two companion pages:

- [CLI Parameters](cli.md) — driving the app from the command line.
- [Advanced INI Reference](ini-reference.md) — every INI key, its type, default, valid range,
  and whether it appears in the Settings dialog.

## The Settings dialog

Open Settings from the widget's right-click menu, the tray menu, or the default hotkey
**Ctrl+Alt+S** (`hotkey_open_settings`, rebindable on the Hotkeys tab). The dialog is a custom
borderless window built by `includes/ConfigDialog.au3` and is organized into 14 tabs:

General, Display, Hotkeys, Behavior, Logging, Updates, Desktops, Animations, OSD, Window List,
Explorer, Notifications, Taskbar, and Tray.

![The Settings dialog on the General tab, showing the three-row tab bar and the Widget sub-tab of controls.](../assets/screenshots/settings-general.png)

*The Settings dialog is a custom borderless window; the three-row tab bar at the top switches between its 14 tabs.*

Any tab with more options than fit is split into sub-tabs (for example the General tab's
Widget / Desktop / System / Scroll rows). A **search box** in the top-right corner finds
settings by name across every tab and jumps you straight to the matching control:

![The Settings dialog with "color" typed in the search box and a results panel listing four matching settings with descriptions.](../assets/screenshots/settings-search.png)

*Typing in the search box lists matching settings from any tab, each with a short description; click one to jump to it.*

Not every INI key has a control on these tabs. Keys that are only meaningful to power users, or
that are set at runtime by dragging/menu toggles, are edited in the INI directly. The
[Advanced INI Reference](ini-reference.md) marks each key's exposure as `Yes (Tab)`, `INI-only`,
or runtime-managed.

### Applying changes

Clicking **Apply** or **OK** writes the whole configuration to disk and then re-applies it to
the running app in one pass (`__CD_ApplyChanges` → `_ApplySettingsLive` in
`includes/ConfigDialog.au3` and `desktop_switcher.au3`). The write happens once, after every
tab's values are collected, so all sections persist together.

Most settings take effect **immediately** — hotkey rebindings, widget opacity/position, scroll
handling, the desktop list, tray mode, the taskbar auto-hide monitor, the rules engine, logging,
and the explorer-crash monitor are all re-initialized live. Two changes require a **restart** to
take effect and say so in the dialog:

- **Theme** (`[Display] theme`) — the color scheme is applied at startup.
- **Language** (`[General] language`) — locale strings are loaded once at startup.

![The Settings dialog Behavior tab, with toggles for confirmation prompts and interaction options.](../assets/screenshots/settings-behavior.png)

*The Behavior tab gathers interaction and confirmation options; most take effect the moment you click Apply.*

## Where the INI file lives

The config file is `desk_switcheroo.ini` in the same folder as the executable (`@ScriptDir`).
Desk Switcheroo is portable by design: it does not write to `%APPDATA%` or the registry for its
settings (the only registry touch is the optional "start with Windows" entry). See
[Persistence & Profiles](../guides/persistence.md) for the full list of files the app reads and
writes.

### First-run creation

On first launch, if `desk_switcheroo.ini` does not exist, the app seeds it from
`examples/desk_switcheroo.prod.ini` when that file is present, then fills in any missing keys
with their built-in defaults (`_Cfg_Init` → `_Cfg_WriteDefaults` in `includes/Config.au3`). This
means a fresh INI always contains every key, even ones the example omits. If the INI is present
but unreadable, the app falls back to defaults for the session and shows a tray warning.

## Hot-reloading external edits

By default, edits you make to the INI by hand are picked up the next time the app starts. If you
turn on the **config watcher** (`[Behavior] config_watcher_enabled`, default off), the app polls
the file's modification time every `config_watcher_interval` milliseconds (default 60000) and
reloads + re-applies the configuration live when it changes — so you can edit the INI in a text
editor and see the result without restarting.

## Save debounce

Saves are debounced: `_Cfg_Save` skips a write if the previous save was less than 500 ms ago
(`includes/Config.au3`). This keeps rapid changes (for example dragging the widget, which
persists its position) from thrashing the disk. Writes are atomic — the app writes a temporary
file, verifies it, then renames it over the original — so an interrupted save cannot corrupt your
config.

## Example configurations

The `examples/` folder ships two ready-made INIs you can copy to `desk_switcheroo.ini`:

- **`desk_switcheroo.prod.ini`** — conservative defaults: logging and updates off, no hotkeys
  bound, colors cleared. This is the file the app seeds a fresh install from.
- **`desk_switcheroo.debug.ini`** — a development profile with debug mode and verbose logging
  enabled and more features switched on, useful for testing and for seeing a populated file.

Both examples are partial: they omit some sections entirely. That is fine — missing keys are
filled with defaults on load, so a copied example still runs with the full feature set available.
