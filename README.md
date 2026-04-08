# Desk Switcheroo

[![CI](https://img.shields.io/github/actions/workflow/status/supermarsx/desk-switcheroo/ci.yml?style=flat-square&label=CI)](https://github.com/supermarsx/desk-switcheroo/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/supermarsx/desk-switcheroo?style=flat-square&label=latest)](https://github.com/supermarsx/desk-switcheroo/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/supermarsx/desk-switcheroo/total?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/releases)

A lightweight Windows virtual desktop switcher that sits in your taskbar. Built with AutoIt.

## Features

- **Taskbar widget** — compact overlay docked to the taskbar showing your current desktop number and custom label
- **Arrow navigation** — click left/right arrows to move between desktops
- **Desktop list panel** — click the desktop number to pop open a list of all desktops; auto-hides after 3 seconds of inactivity
- **Per-desktop context menu** — right-click any desktop in the list to switch, rename, peek, or delete it (delete requires confirmation)
- **Persistent list toggle** — right-click menu option to keep the desktop list pinned open
- **Desktop peek** — hover over the eye icon next to any desktop in the list to temporarily preview it; move away and it snaps back after 500ms
- **Custom labels with OS sync** — name your desktops (e.g. "Work", "Music", "Chat") via the right-click > Edit Label dialog. On Windows 11, names sync with the OS — renaming in Desk Switcheroo updates Task View, and Task View changes are detected within a few seconds. Falls back to local `desktop_labels.ini` storage on Windows 10
- **Dark themed UI** — all popups, menus, dialogs, and hover states use a consistent dark color scheme
- **Always on top** — the widget aggressively stays above other windows, including fullscreen apps
- **Singleton enforcement** — relaunching the script kills the previous instance automatically
- **External desktop changes detected** — polls every 400ms so keyboard shortcuts (Win+Ctrl+arrows) and Task View switches are reflected in the widget
- **Fully configurable** — all behaviors configurable via Settings dialog or INI file
- **Scroll wheel navigation** — scroll on widget to cycle desktops (configurable, off by default)
- **Global hotkeys** — configurable keyboard shortcuts for desktop switching (off by default)
- **Desktop count display** — optionally show "2/5" format (off by default)
- **Move window to desktop** — right-click context menu option to move the active window
- **Start with Windows** — configurable auto-start via Settings
- **Desktop indicator colors** — assign accent colors per desktop (off by default)
- **Middle-click to delete** — quick delete from the list (off by default)
- **Widget positioning** — place widget left/center/right on taskbar

## Requirements

- Windows 10/11 with virtual desktops enabled
- [AutoIt v3](https://www.autoitscript.com/)

## Third-Party

- **[VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor)** by **Jari Pennanen (Ciantic)** — Rust library that exposes Windows' undocumented virtual desktop COM interfaces. Licensed under the MIT License. Make sure the DLL version matches your Windows build.
- **[Fira Code](https://github.com/tonsky/FiraCode)** by **Nikita Prokopov** — Monospaced font with programming ligatures, used for the desktop list. Licensed under the SIL Open Font License (OFL). Bundled in `fonts/`.

## Usage

1. Place `VirtualDesktopAccessor.dll` in the same directory as the script
2. Run `desktop_switcher.au3` with AutoIt, or compile it to an `.exe`
3. The widget appears at the left edge of your taskbar
4. Left-click arrows to switch desktops, click the number to see the full list
5. Right-click the widget for options (edit label, toggle list, quit)

## Configuration

Settings are accessible via right-click on the widget and selecting **Settings**. All settings are stored in `desk_switcheroo.ini`, which is auto-created with sensible defaults on first run.

The INI file is organized into the following sections:

| Section | Description |
|---------|-------------|
| `[General]` | Core behavior: polling interval, startup options, singleton mode |
| `[Display]` | Widget appearance: position, desktop count format, label visibility |
| `[Scroll]` | Scroll wheel navigation: enable/disable, direction, wrap-around |
| `[Hotkeys]` | Global keyboard shortcuts for switching desktops |
| `[Behavior]` | Interaction options: middle-click delete, move window, confirmations |
| `[DesktopColors]` | Per-desktop accent colors (mapped by desktop index) |

You can edit the INI file directly or use the Settings dialog for a guided experience. Changes made in the dialog are written to the INI immediately.

## Project Structure

```
desk-switcheroo/
├── desktop_switcher.au3          Main script (singleton, GUI, event loop)
├── includes/
│   ├── Theme.au3                 Dark theme constants and UI helpers
│   ├── Labels.au3                Desktop label persistence (INI)
│   ├── VirtualDesktop.au3        VirtualDesktopAccessor.dll wrapper
│   ├── Peek.au3                  Desktop peek state machine
│   ├── DesktopList.au3           Desktop list panel
│   ├── ContextMenu.au3           Right-click context menu
│   ├── RenameDialog.au3          Rename label dialog
│   ├── Config.au3                Configuration management (INI-backed)
│   └── ConfigDialog.au3          Settings dialog GUI
├── tests/
│   ├── TestRunner.au3            Test harness and runner
│   ├── Test_Theme.au3            Theme constant validation
│   ├── Test_Labels.au3           Label persistence tests
│   ├── Test_VirtualDesktop.au3   DLL wrapper integration tests
│   ├── Test_Peek.au3             Peek state machine tests
│   ├── Test_DesktopList.au3      Desktop list GUI tests
│   ├── Test_ContextMenu.au3      Context menu GUI tests
│   ├── Test_RenameDialog.au3     Rename dialog GUI tests
│   ├── Test_Config.au3           Configuration tests
│   ├── E2E_Sandbox.au3           End-to-end sandbox tests
│   ├── sandbox.wsb               Windows Sandbox config
│   └── sandbox_setup.ps1         Sandbox test runner script
├── fonts/
│   ├── FiraCode-Regular.ttf      Bundled monospace font (OFL)
│   └── FiraCode-Bold.ttf         Bundled monospace font (OFL)
├── VirtualDesktopAccessor.dll    Third-party DLL
├── desktop_labels.ini            Auto-generated label storage (git-ignored)
├── desk_switcheroo.ini           Auto-generated settings (git-ignored)
├── README.md
└── LICENSE
```

## Testing

Run the full test suite from the project root (use the 64-bit runner since the DLL is x64):

```
AutoIt3_x64.exe tests\TestRunner.au3
```

Or if compiled (as x64):

```
tests\TestRunner.exe
```

The runner outputs results to the console and exits with code 0 (all pass) or 1 (failures).

**Test categories:**
- **Unit tests** (Theme, Labels, Peek, Config) — pure logic, no GUI windows needed
- **Integration tests** (VirtualDesktop) — requires the DLL and a desktop session
- **GUI tests** (DesktopList, ContextMenu, RenameDialog, ConfigDialog) — create actual windows, require a desktop session
- **E2E sandbox tests** — run the full application in an isolated Windows Sandbox. Double-click `tests\sandbox.wsb` to launch (requires the Windows Sandbox feature to be enabled). Results are written to `tests\results\`
