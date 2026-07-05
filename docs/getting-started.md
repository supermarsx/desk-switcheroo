---
title: Getting Started
nav_order: 2
---

# Getting Started

This is the quick path: check the requirements, install one way, run it, and learn the
handful of interactions you need for daily use. For channel-by-channel deployment, silent
installation, and full uninstall/cleanup, see [Deployment & Lifecycle](reference/lifecycle.md).

## Requirements

- **Windows 10 or Windows 11, 64-bit.** 32-bit Windows is not supported.
- Nothing else to install — the compiled `DeskSwitcheroo.exe` is standalone and ships with
  its one native dependency, `VirtualDesktopAccessor.dll`, alongside it.

You only need [AutoIt](https://www.autoitscript.com/) (v3.3.18+, x64) if you want to run
from source; see [Building from Source](reference/building.md). Full per-feature OS deltas
are on the [Compatibility Matrix](reference/compatibility.md) — the main one to know up
front is that syncing labels with Windows' own desktop names works only on Windows 11.

## Install

There are two common routes. Both leave you with the same app; pick whichever you prefer.
Package-manager channels (Chocolatey, Scoop, winget) and run-from-source are covered in
[Deployment & Lifecycle](reference/lifecycle.md).

### Portable ZIP (recommended)

1. Download `DeskSwitcheroo_Portable.zip` from the
   [latest release](https://github.com/supermarsx/desk-switcheroo/releases/latest).
2. Extract it anywhere you can write to — a folder in your user profile, a USB stick,
   wherever. The app is portable by design and keeps its settings next to the executable.
3. Run `DeskSwitcheroo.exe`.

The ZIP contains `DeskSwitcheroo.exe`, `VirtualDesktopAccessor.dll`, and the bundled
`fonts/` folder (see `scripts/package.ps1`). No installation, no registry writes, no
elevation.

### Installer (`DeskSwitcheroo_Setup.exe`)

Download `DeskSwitcheroo_Setup.exe` from the
[latest release](https://github.com/supermarsx/desk-switcheroo/releases/latest) and run it.
The NSIS installer (`installer/desk_switcheroo.nsi`) requests administrator rights and
installs to `%ProgramFiles%\DeskSwitcheroo`. It offers four component sections: **Core Files**
(required), **Fira Code Fonts**, **Desktop Shortcut**, and **Start with Windows**. The last
two are optional and unchecking them is fine.

> **Which should I pick?** Choose the portable ZIP if you want zero footprint, no admin
> prompt, or you move the app between machines. Choose the installer if you want Start Menu
> and desktop shortcuts and an entry in *Add or remove programs*. For silent install (`/S`),
> a custom directory (`/D=`), and exactly what each channel leaves behind on uninstall, see
> [Deployment & Lifecycle](reference/lifecycle.md).

## First run

When you launch Desk Switcheroo, a small **widget** docks to your taskbar (bottom-left by
default). It shows the current desktop number, its label, a color bar, and navigation arrows.

![The widget on first run, showing desktop 1 "Main" with left/right arrows and an accent color bar.](assets/screenshots/widget.png)

*On first launch the widget appears in the taskbar corner — this is your whole control surface.*

Everything you need is reachable from there:

- **Click the arrows** to move to the previous/next desktop.
- **Click the number** to open the **desktop list** — the popup panel showing every desktop.
- **Right-click the widget** for the menu: edit the current label, open **Settings**, and
  quit, among other actions.
- **Right-click a desktop in the list** for per-desktop actions: rename, peek, delete, set
  color, and move the active window to it.

That is enough to switch, rename, and organize desktops. The full set of gestures — scroll-
wheel navigation, drag-to-reorder, quick-access number entry, hotkeys, slideshow mode — is
covered in [Desktop Management](guides/desktop-management.md). For a plain-language account
of what actually happens when you switch, see [How It Works](how-it-works.md).

### Where your settings live

Desk Switcheroo is configured through the **Settings** dialog (right-click the widget →
Settings, or press **Ctrl+Alt+S**) and stores everything in plain INI files created
automatically on first run, in the same folder as the executable:

![The Settings dialog open on the General tab, with a three-row tab bar and validated controls for the widget.](assets/screenshots/settings-general.png)

*The Settings dialog covers the common options across 14 tabs; everything it writes also lives in the INI file.*

- `desk_switcheroo.ini` — all your settings.
- `desktop_labels.ini` — your custom desktop labels (on Windows 11 these also sync with the
  OS desktop names).
- `desk_switcheroo_state.ini` — small runtime state such as the desktop-list scroll position.

Because these sit next to the app, backing up or moving your configuration is just a matter
of copying them. See [Persistence & Profiles](guides/persistence.md) for what each file holds
and [Configuration](configuration/index.md) for how settings are applied. Two ready-made
example configs ship in `examples/` (`desk_switcheroo.prod.ini` for conservative daily use,
`desk_switcheroo.debug.ini` with everything turned on).

> **Note:** if you used the installer and let it install under `%ProgramFiles%`, that folder
> is not user-writable, so Windows may redirect the INI files into your per-user *VirtualStore*.
> Running the portable build from a writable folder avoids this entirely. Deployment depth,
> including this caveat, lives in [Deployment & Lifecycle](reference/lifecycle.md).

## Updating

Desk Switcheroo includes a built-in update checker (`includes/UpdateChecker.au3`) that can
look for newer releases on GitHub and, for portable users, download the latest
`DeskSwitcheroo_Portable.zip` for you. Installer users update by re-running a newer
`DeskSwitcheroo_Setup.exe`. Update-check behavior and its settings are described in
[Configuration](configuration/index.md); the failure handling is covered under
[Stability & Mitigations](reference/stability.md).

## Where to go next

- [How It Works](how-it-works.md) — what the widget is and what a switch actually does.
- [Configuration](configuration/index.md) — the Settings dialog and INI files.
- [Guides](guides/index.md) — coloring, desktop management, persistence, rules, and logging.
- [Reference](reference/index.md) — compatibility, building, deployment, and licensing.
- [Comparison with Other Tools](comparison.md) — how it stacks up and which tool suits you.
