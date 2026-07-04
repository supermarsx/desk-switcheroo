---
title: Deployment & Lifecycle
nav_order: 6
parent: Reference
---

# Deployment & Lifecycle

This page covers how Desk Switcheroo is delivered, what happens across the life
of an install (from first run to full uninstall), and how the running
application starts up and shuts down. For the quick "just get me running" path,
see [Getting Started](../getting-started.md); this page is the in-depth
reference it links to.

## Deployment channels

Desk Switcheroo ships as three release artifacts, produced by the CI `release`
job on every push to `main` (see `.github/workflows/ci.yml`):
`DeskSwitcheroo_Portable.zip`, `DeskSwitcheroo_Setup.exe`, and
`DeskSwitcheroo_Source.zip`. Package-manager manifests wrap the first two.

### Portable ZIP (recommended)

The portable build is fully self-contained: unzip it anywhere (a normal user
folder, a USB stick) and run `DeskSwitcheroo.exe`. It requires no elevation, no
installer, and touches the registry only if you enable "Start with Windows" from
Settings. All configuration and state files are created next to the executable,
so the whole tool is contained in its folder. To remove it, delete the folder
(see the cleanup note under [Uninstall](#uninstall) about the autostart entry).

### NSIS installer (`DeskSwitcheroo_Setup.exe`)

The Windows installer is built from `installer/desk_switcheroo.nsi` (NSIS 3.x
with MUI2). It requests administrator elevation
(`RequestExecutionLevel admin`) and installs to
`$PROGRAMFILES64\DeskSwitcheroo` by default. Its selectable components are:

| Section | Default | What it does |
|---|---|---|
| Core Files (required) | Always on (read-only) | Installs `DeskSwitcheroo.exe` and `VirtualDesktopAccessor.dll`; writes `HKLM\Software\DeskSwitcheroo` `InstallDir`; writes `Uninstall.exe` and the standard uninstall registry key; creates Start Menu shortcuts. |
| Fira Code Fonts | On | Installs the bundled Fira Code fonts used by the overlay into `$INSTDIR\fonts`. |
| Desktop Shortcut | On | Creates a desktop shortcut. |
| Start with Windows | On | Writes `HKCU\...\CurrentVersion\Run` `DeskSwitcheroo` = the installed executable path. |

**Registry keys written by the installer** (see `installer/desk_switcheroo.nsi`):

- `HKLM\Software\DeskSwitcheroo` → `InstallDir`
- `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\DeskSwitcheroo` →
  `DisplayName`, `UninstallString`, `DisplayIcon`, `Publisher`, `URLInfoAbout`,
  `EstimatedSize`
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `DeskSwitcheroo` (only
  if the "Start with Windows" component is selected)

**Silent install.** The script sets no `SilentInstall` directive, so the NSIS
default applies: `DeskSwitcheroo_Setup.exe /S` performs a silent install with
all selectable sections applied at their defaults (Core, Fira Code Fonts,
Desktop Shortcut, and Start with Windows all install). Add `/D=` to override the
install directory — it must be the **last** argument, unquoted, e.g.
`DeskSwitcheroo_Setup.exe /S /D=C:\Tools\DeskSwitcheroo`. The uninstaller
likewise accepts `/S` for a silent uninstall.

### Chocolatey / Scoop / WinGet

The repository carries package manifests under `packaging/`. Each is present in
the repo as a manifest; treat these as manifest definitions rather than a
confirmation that the package is live in the corresponding public feed. All three
are pinned to version 26.6 and declare the MIT license.

| Manifest | File | Wraps | License field |
|---|---|---|---|
| Chocolatey | `packaging/chocolatey/desk-switcheroo.nuspec` (+ `tools/chocolateyinstall.ps1`) | `DeskSwitcheroo_Setup.exe`, installed with `/S` | `licenseUrl` → `license.md` on GitHub; `requireLicenseAcceptance` = false |
| Scoop | `packaging/scoop/desk-switcheroo.json` | `DeskSwitcheroo_Portable.zip` | `"license": "MIT"` |
| WinGet | `packaging/winget/supermarsx.DeskSwitcheroo.yaml` | `DeskSwitcheroo_Setup.exe` (`nullsoft`) | `License: MIT`, `LicenseUrl` → `license.md` |

The Scoop manifest supports auto-update (`checkver`/`autoupdate` against GitHub
releases). The Chocolatey and WinGet manifests carry empty checksum fields in the
repo (filled at publish time).

### Run from source

You can run `desktop_switcher.au3` directly with AutoIt (x64). This is the path
for development and for platforms where you would rather not run a compiled
binary; see [Building from Source](building.md) for prerequisites.

### Channel comparison

| Channel | Elevation | Auto-update path | Leaves behind on uninstall |
|---|---|---|---|
| Portable ZIP | None | In-app update check downloads a new portable ZIP | Nothing, if you never enabled autostart; otherwise the `Run` registry value stays (see below) |
| NSIS installer | Admin (install & uninstall) | Re-run a newer Setup, or in-app update check | Only files/logs you redirected outside `$INSTDIR`; see [Uninstall](#uninstall) |
| Chocolatey | Admin (wraps Setup) | `choco upgrade` | Same as installer |
| Scoop | None | `scoop update` | Scoop manages the folder |
| WinGet | Admin (wraps Setup) | `winget upgrade` | Same as installer |
| From source | None | `git pull` | Nothing (your working copy) |

## User lifecycle

### Install and first run

On first launch (see `includes/Config.au3`), the app creates its configuration
next to the executable. If `desk_switcheroo.ini` does not exist, it seeds one
from `examples/desk_switcheroo.prod.ini` when that file is present, then writes
any missing defaults. The following files appear in the executable's folder over
the first run and normal use:

- `desk_switcheroo.ini` — all settings.
- `desktop_labels.ini` — your desktop names/labels.
- `desk_switcheroo_state.ini` — saved runtime state (last desktop, desktop-list
  scroll offset), written on shutdown.
- `desk_switcheroo.log` — the log file, when logging is enabled (default
  location; can be redirected — see below).
- `crash_*.log` — a crash report, only if the app hits a fatal error.
- Named profile `.ini` files, if you save profiles.

A singleton guard means launching the app again does not stack a second copy;
the new instance takes over and terminates the previous one (see
[App runtime lifecycle](#app-runtime-lifecycle)).

### Configure

Change settings either through the in-app **Settings** dialog or by editing
`desk_switcheroo.ini` directly (the app watches the file and hot-reloads it). See
the [Configuration](../configuration/index.md) section for the Settings dialog
and the [Advanced INI Reference](../configuration/ini-reference.md) for every
key. Two example configs ship in `examples/` (`prod` and `debug`) as
starting points.

### Daily use

Ordinary operation is the [event loop](#app-runtime-lifecycle) described below —
you switch desktops, rename them, and so on. See
[How It Works](../how-it-works.md) for the user-level mechanism and the
[guides](../guides/coloring.md) for individual features.

### Update

When update checking is enabled, the app checks for a newer release in the
background (see [Stability & Mitigations](stability.md) for how a failed check is
handled). Portable users receive a new portable ZIP; installer users re-run a
newer `DeskSwitcheroo_Setup.exe` (or `choco upgrade` / `winget upgrade` /
`scoop update`). Because settings live in the INI files, updating in place keeps
your configuration.

### Back up and migrate your config

Everything that makes up "your setup" is in a handful of plain files next to the
executable. To back up or move to another machine, copy:

- `desk_switcheroo.ini` — settings
- `desktop_labels.ini` — desktop names
- `desk_switcheroo_state.ini` — saved state (optional; regenerated if absent)
- any named profile `.ini` files you created

Drop those into the new install's folder and the app picks them up on launch.
Because paths are relative to the executable, the config is portable between
machines running the same Desk Switcheroo version. See
[Persistence & Profiles](../guides/persistence.md) for details on each file.

### Uninstall

**Installer (or Chocolatey/WinGet, which wrap it).** The NSIS uninstall section
(`installer/desk_switcheroo.nsi`) does the following, in order:

1. Terminates a running `DeskSwitcheroo.exe` (`taskkill /F`).
2. Deletes `DeskSwitcheroo.exe`, `VirtualDesktopAccessor.dll`, and
   `Uninstall.exe`.
3. Removes the `fonts` subfolder.
4. **Recursively removes the entire install directory** (`RMDir /r "$INSTDIR"`).
   This also deletes any config, state, label, log, and crash files the app
   wrote into its install folder.
5. Removes the Start Menu and desktop shortcuts.
6. Deletes the `HKCU\...\Run` `DeskSwitcheroo` autostart value.
7. Deletes `HKLM\Software\DeskSwitcheroo` and the uninstall registry key.

Because step 4 wipes the whole install directory, an installer uninstall is
close to complete. The one thing it can miss is a **log file you redirected
outside the install directory**: the `log_folder` setting can expand
`%APPDATA%`, `%TEMP%`, or `%SCRIPTDIR%` (see `includes/Config.au3` and
[Logging & Diagnostics](../guides/logging.md)). If you pointed `log_folder` at
`%APPDATA%` or `%TEMP%`, those logs survive the uninstall — delete them by hand.

**Portable.** There is no uninstaller. Delete the folder to remove the program
and all of its config/state/log/crash files. One manual step remains **if you
enabled "Start with Windows"**: the app wrote an autostart value
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `DeskSwitcheroo` (via
`_Cfg_EnableStartup` in `includes/Config.au3`), and deleting the folder does not
remove it. Turn off "Start with Windows" in Settings before deleting the folder,
or delete that `Run` value manually afterward.

**Full-cleanup checklist (either channel):**

- Install directory / portable folder — removed automatically by the installer;
  delete manually for portable.
- `HKCU\...\Run` → `DeskSwitcheroo` — removed by the installer; **remove manually
  for portable** if autostart was enabled.
- `HKLM\Software\DeskSwitcheroo` and the `...\Uninstall\DeskSwitcheroo` key —
  installer only; portable never creates them.
- Redirected logs under `%APPDATA%` / `%TEMP%` — delete by hand if you set a
  custom `log_folder`.

## App runtime lifecycle

This section traces the running application in `desktop_switcher.au3`.

### Startup sequence

On launch the script runs, in order (see `desktop_switcher.au3`):

1. Installs the error handler and registers the exit handler (`_OnExit`).
2. **Singleton check.** If `singleton_enabled` is on (read directly from the INI
   before full config load), it creates a named mutex; if a prior instance is
   detected it terminates that instance and continues. The new instance always
   takes over — it does not refuse to start.
3. Loads fonts, then **configuration** (`_Cfg_Init`), then the **locale**
   (`_i18n_Init`), then the theme.
4. Initializes wallpaper handling and **logging** (`_Log_Init`).
5. Starts the Explorer monitor, taskbar auto-hide monitor, **rules engine**
   (`_WR_Start`), **hooks** (`_Hooks_Init`), profiles, and the **CLI/IPC**
   handler.
6. Runs startup checks (which also perform **session restore** and fire the
   `on_startup` hook).
7. Parses CLI arguments; a query command (for example `status`) executes and
   exits here without creating the widget.
8. **Loads the DLL and runs its health check** (`_VD_Init`); if the DLL cannot
   load, the app shows an error and exits.
9. Initializes labels, ensures the minimum number of desktops exists, and
   **creates the widget GUI** (or tray icon in tray mode).
10. Registers window-message hooks and the **desktop-change notification**
    (`_VD_RegisterNotify`), then starts the periodic timers (topmost re-assert,
    name sync, DLL health check), hotkeys, the config watcher, and the
    background update check.
11. Restores persisted state (desktop-list scroll offset) and enters the main
    loop.

### Normal run (event loop)

The main `While 1` loop runs one cooperative pass at a time, calling its phase
functions each iteration: `_ProcessGUIEvents`, `_ProcessMouseInput`,
`_ProcessKeyboardInput`, `_ProcessEventFlags`, `_ProcessHoverAndVisuals`, and
`_ProcessTimersAndSleep`. A three-tier adaptive sleep (roughly 5 ms while
interactive or animating, 15 ms while a popup is open, 100 ms when idle) keeps
the widget responsive without spinning the CPU. What happens on an actual desktop
switch is described in [How It Works](../how-it-works.md); the concurrency model
is detailed in [Architecture & Patterns](architecture.md).

### Crash path

On a fatal error the app writes a crash report and offers recovery. The report
(`crash_YYYYMMDD_HHMMSS.log`) is written to the executable's folder, or to the
system temp folder if that folder is not writable, and it is written with a raw
file handle so it works even when the logger itself is the problem. A recovery
dialog then appears with four actions: **Copy Report**, **Open Log**,
**Restart**, and **Close**. See [Stability & Mitigations](stability.md) for the
broader recovery story and [Persistence & Profiles](../guides/persistence.md)
for the crash-log format.

### Shutdown sequence

A normal exit runs `_Shutdown` (also reached from the crash/exit handler), which
tears down in this order:

1. Guards against re-entry; honors "close to tray" and the optional quit
   confirmation.
2. Sets the shutting-down flag, then **fires `on_shutdown` hooks
   synchronously** — before services are stopped, so shutdown hooks are not
   killed mid-run. These run under a capped wait: a hook that overruns its
   timeout is terminated so it cannot hang the exit (see
   `includes/Hooks.au3` and [Rules Engine & Hooks](../guides/rules-engine.md)).
3. **Saves the session** (if session restore is enabled).
4. Stops the rules engine, hooks, CLI/IPC, Explorer monitor, and taskbar
   monitor; unregisters hotkeys; and unregisters all periodic timers.
5. Destroys popups and fades out the widget.
6. **Writes `desk_switcheroo_state.ini`** (last desktop, scroll offset).
7. Unregisters the desktop-change notification, shuts down the DLL, unloads
   fonts, flushes the log, and exits.

Configuration itself is written eagerly during normal operation (with a debounce;
see [Configuration](../configuration/index.md)), so there is no separate config
flush at shutdown — the only file the shutdown path writes is the state INI.
