# Desk Switcheroo

<img width="881" height="256" alt="Desk Switcheroo" src="https://github.com/user-attachments/assets/f6b2545a-554d-4e8a-8d93-0fd0e0430662" />

[![CI](https://img.shields.io/github/actions/workflow/status/supermarsx/desk-switcheroo/ci.yml?style=flat-square&label=CI)](https://github.com/supermarsx/desk-switcheroo/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/supermarsx/desk-switcheroo?style=flat-square&label=latest)](https://github.com/supermarsx/desk-switcheroo/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/supermarsx/desk-switcheroo/total?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/releases)
[![Stars](https://img.shields.io/github/stars/supermarsx/desk-switcheroo?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/stargazers)
[![Forks](https://img.shields.io/github/forks/supermarsx/desk-switcheroo?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/network/members)
[![Watchers](https://img.shields.io/github/watchers/supermarsx/desk-switcheroo?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/watchers)
[![Built with AutoIt](https://img.shields.io/badge/built%20with-AutoIt-blue?style=flat-square)](https://www.autoitscript.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

A lightweight Windows virtual desktop switcher widget for your taskbar. Navigate, rename, peek, and manage desktops from a compact dark-themed overlay.

## Requirements

- **Windows 10 or 11** (64-bit only)
- [VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor) (bundled)

> To run from source, you also need [AutoIt v3](https://www.autoitscript.com/) (64-bit). The compiled `.exe` works standalone.

## Installation

### Portable (recommended)

1. Download the latest `DeskSwitcheroo_Portable.zip` from [Releases](https://github.com/supermarsx/desk-switcheroo/releases/latest)
2. Extract anywhere
3. Run `DeskSwitcheroo.exe`

### Installer

Download `DeskSwitcheroo_Setup.exe` from [Releases](https://github.com/supermarsx/desk-switcheroo/releases/latest). Includes optional Start Menu shortcut, desktop shortcut, and start-with-Windows.

### From source

```
git clone https://github.com/supermarsx/desk-switcheroo.git
cd desk-switcheroo
AutoIt3_x64.exe desktop_switcher.au3
```

## Quick Start

1. The widget appears at the bottom-left of your taskbar
2. **Click arrows** to switch between desktops
3. **Click the number** to open the full desktop list
4. **Right-click** the widget for options (edit label, settings, quit)
5. **Right-click a desktop** in the list for per-desktop actions (rename, peek, delete, set color, move window)

## Features

- **Compact taskbar widget** with desktop number and custom label
- **Desktop list panel** with click-to-switch, drag-to-reorder, and auto-hide
- **Desktop peek** — hover the eye icon to temporarily preview a desktop
- **Custom labels** with Windows 11 OS name sync (falls back to INI on Win10)
- **5 dark themes** — dark, darker, midnight, midday, sunset
- **Per-desktop colors** — assign accent colors visible in the list and widget
- **9-position screen anchoring** — place the widget anywhere on screen
- **Global hotkeys** — configurable keyboard shortcuts (Ctrl+Alt+S opens Settings)
- **Scroll wheel navigation** — scroll on widget or list to cycle desktops
- **Move window to desktop** — right-click context menu option
- **Start with Windows** — configurable auto-start
- **System tray mode** — run as a tray icon instead of taskbar widget
- **Fade animations** — configurable fade-in/out on all popups, menus, and dialogs
- **Auto-update checker** — periodic or manual check for new releases
- **Logging** — configurable debug logging with rotation and compression
- **80+ settings** across 9 tabs in the Settings dialog

## Localization

Desk Switcheroo supports 17 languages out of the box:

| Language | Code | Language | Code |
|----------|------|----------|------|
| English (US) | en-US | Hungarian | hu-HU |
| English (GB) | en-GB | Icelandic | is-IS |
| Arabic | ar-SA | Italian | it-IT |
| Chinese (Simplified) | zh-CN | Dutch | nl-NL |
| Chinese (Traditional) | zh-TW | Portuguese (BR) | pt-BR |
| French | fr-FR | Portuguese (PT) | pt-PT |
| German | de-DE | Russian | ru-RU |
| Hindi | hi-IN | Ukrainian | uk-UA |
| Spanish | es-ES | | |

Change language in **Settings > General > Language**. To add your own translation, copy `locales/en-US.ini`, rename it (e.g. `ja-JP.ini`), translate the values, and it will appear automatically in the language picker.

## Configuration

All settings are accessible via **right-click > Settings** or the hotkey **Ctrl+Alt+S**. Settings are stored in `desk_switcheroo.ini` (auto-created on first run).

Example configurations are provided in the `examples/` folder:
- `desk_switcheroo.prod.ini` — conservative defaults for daily use
- `desk_switcheroo.debug.ini` — all features enabled for testing

See [Power User Guide](docs/POWER_USER.md) for advanced configuration details.

## Third-Party

- **[VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor)** by Jari Pennanen (Ciantic) — MIT License
- **[Fira Code](https://github.com/tonsky/FiraCode)** by Nikita Prokopov — SIL Open Font License

## Documentation

- [Power User Guide](docs/POWER_USER.md) — advanced configuration, INI reference, scripting
- [Development Guide](docs/DEVELOPMENT.md) — building, testing, architecture, contributing

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
