# Desk Switcheroo

<img width="881" height="256" alt="Desk Switcheroo" src="https://github.com/user-attachments/assets/f6b2545a-554d-4e8a-8d93-0fd0e0430662" />

[![CI](https://img.shields.io/github/actions/workflow/status/supermarsx/desk-switcheroo/ci.yml?style=flat-square&label=CI)](https://github.com/supermarsx/desk-switcheroo/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/supermarsx/desk-switcheroo?style=flat-square&label=latest)](https://github.com/supermarsx/desk-switcheroo/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/supermarsx/desk-switcheroo/total?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/releases)
[![Stars](https://img.shields.io/github/stars/supermarsx/desk-switcheroo?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/stargazers)
[![Forks](https://img.shields.io/github/forks/supermarsx/desk-switcheroo?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/network/members)
[![Watchers](https://img.shields.io/github/watchers/supermarsx/desk-switcheroo?style=flat-square)](https://github.com/supermarsx/desk-switcheroo/watchers)
[![Built with AutoIt](https://img.shields.io/badge/built%20with-AutoIt-blue?style=flat-square)](https://www.autoitscript.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](license.md)

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

**Widget**
- Compact taskbar overlay with desktop number, custom label, and arrow navigation
- 9-position screen anchoring with pixel offset fine-tuning
- Draggable widget repositioning (optional)
- Custom widget dimensions (width/height override)
- Color bar accent matching the current desktop color
- Desktop count display (e.g. "2/5") with configurable font
- Always-on-top enforcement with configurable interval

**Desktop Management**
- Desktop list panel with click-to-switch, drag-to-reorder, pin/unpin, and auto-hide
- Window list panel — send any window to another desktop, pin, minimize/maximize/close, toggle always-on-top, plus bulk Minimize/Maximize/Close All
- Desktop peek — hover the eye icon to temporarily preview a desktop
- Thumbnail previews on hover with optional screenshot capture
- Custom labels with Windows 11 OS name sync (falls back to INI on Win10)
- Per-desktop accent colors with 7 presets + custom hex color picker
- Per-desktop wallpaper applied automatically on switch
- Add, delete, and reorder desktops from the list context menu
- Move active window to any desktop via right-click menu
- Wrap navigation at desktop ends, auto-create desktop past last

**Input & Shortcuts**
- Global hotkeys for next/prev/toggle list + direct desktop jump (1-9)
- Scroll wheel navigation on widget and list (normal/inverted, wrap)
- Quick-access number input — double-click to type a desktop number
- Triple-click to edit desktop label
- Middle-click to delete a desktop from the list
- Keyboard navigation (Up/Down) in the desktop list

**Appearance**
- 5 dark themes — dark, darker, midnight, midday, sunset
- On-screen desktop-change indicator (OSD) and toast notifications for actions
- Configurable fade animations per location (list, menus, dialogs, toasts, widget)
- Customizable list font, tooltip font, and widget opacity
- Scrollable list with configurable max visible items

**System**
- Start with Windows + start minimized options
- System tray mode — run as tray icon instead of taskbar widget
- Session restore — remembers which windows were on which desktop
- Named settings profiles — save and load complete configurations
- Window rules engine + event hooks — auto-place windows and run commands on desktop events
- Explorer crash monitor — auto-recovers the widget if Explorer restarts
- Taskbar auto-hide synchronization
- Singleton enforcement — relaunch kills previous instance
- Config file watcher — auto-reload settings on external INI changes
- Searchable settings dialog
- Auto-update checker with portable download from GitHub Releases
- Debug logging with level filtering, rotation, compression, and PID/function tagging
- Confirm-before-quit and confirm-before-delete safeguards
- 34 locales with automatic language detection and in-app picker
- 90+ settings across 14 tabs in the Settings dialog

## How Desk Switcheroo Compares

| Feature | Desk Switcheroo | [SylphyHorn](https://github.com/grabacr07/SylphyHorn) | [Dexpot](https://dexpot.de) | [VirtuaWin](https://virtuawin.sourceforge.io) | [VD Enhancer](https://github.com/sdias/win-10-virtual-desktop-enhancer) | [PowerToys](https://github.com/microsoft/PowerToys) | [VD.ahk](https://github.com/FuPeiJiang/VD.ahk) | [Desktop Switcher](https://github.com/pmb6tz/windows-desktop-switcher) |
|---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Per-desktop wallpaper | Yes | Yes | Yes | No | Yes | No | No | No |
| Per-desktop colors | Yes | No | No | No | No | No | No | No |
| Custom desktop labels | Yes | No | Partial | No | No | No | Yes | No |
| Desktop peek/preview | Yes | No | Yes | No | No | No | No | No |
| Window rules engine | Yes | No | No | No | No | No | No | No |
| Session persistence | Yes | No | No | No | No | No | No | No |
| Desktop profiles | Yes | No | Partial | No | No | No | No | No |
| Global hotkeys | Yes | Yes | Yes | Yes | Yes | Limited | Yes | Yes |
| Window management | Yes | Limited | Yes | Yes | Limited | Yes | Yes | Yes |
| Drag-to-reorder desktops | Yes | No | Yes | No | No | No | No | No |
| Carousel mode | Yes | No | No | No | No | No | No | No |
| Taskbar widget | Yes | No | No | No | No | No | No | No |
| System tray mode | Yes | Yes | Yes | Yes | No | No | No | No |
| CLI / IPC control | Yes | No | No | No | No | No | No | No |
| Event hooks | Yes | No | No | No | No | No | Yes | No |
| Locales | 34 | 2 | 5 | 3 | 1 | 20+ | 1 | 1 |
| Themes | 5 | 1 | 3 | 1 | 1 | 1 | 0 | 0 |
| Open source | Yes | Yes | No | Yes | Yes | Yes | Yes | Yes |
| Price | Free | Free | Free/Paid | Free | Free | Free | Free | Free |
| Actively maintained | Yes | Fragmented | Aging | Active | Archived | Yes | Yes | Infrequent |

> **Notes (as of July 2026).** PowerToys is a utility suite that does not itself switch virtual desktops — its Workspaces (app-launch layouts) and FancyZones (window tiling) cover adjacent needs, so its cells reflect window management rather than desktop switching. VirtuaWin last shipped v4.5 (April 2025); `win-10-virtual-desktop-enhancer` was archived in December 2018.

For a fuller, source-cited comparison with per-use-case recommendations, see [Comparison with Other Tools](docs/comparison.md).

## Localization

Desk Switcheroo supports 34 locales out of the box:

| Language | Code | Language | Code |
|----------|------|----------|------|
| Arabic (Egypt) | ar-EG | Indonesian | id-ID |
| Arabic (Saudi Arabia) | ar-SA | Icelandic | is-IS |
| Bengali (India) | bn-IN | Italian | it-IT |
| Chinese (Simplified) | zh-CN | Korean | ko-KR |
| Chinese (Traditional) | zh-TW | Dutch | nl-NL |
| Danish | da-DK | Polish | pl-PL |
| English (Canada) | en-CA | Portuguese (Brazil) | pt-BR |
| English (India) | en-IN | Portuguese (Portugal) | pt-PT |
| English (UK) | en-GB | Romanian | ro-RO |
| English (US) | en-US | Russian | ru-RU |
| French (Canada) | fr-CA | Swedish | sv-SE |
| French (France) | fr-FR | Thai | th-TH |
| German | de-DE | Turkish | tr-TR |
| Hindi (India) | hi-IN | Ukrainian | uk-UA |
| Hungarian | hu-HU | Vietnamese | vi-VN |
| Japanese | ja-JP | | |
| Spanish (Argentina) | es-AR | | |
| Spanish (Mexico) | es-MX | | |
| Spanish (Spain) | es-ES | | |

Change language in **Settings > General > Language**. To add your own translation, copy `locales/en-US.ini`, rename it (e.g. `el-GR.ini`), translate the values, and it will appear automatically in the language picker.

## Configuration

All settings are accessible via **right-click > Settings** or the hotkey **Ctrl+Alt+S**. Settings are stored in `desk_switcheroo.ini` (auto-created on first run).

Example configurations are provided in the `examples/` folder:
- `desk_switcheroo.prod.ini` — conservative defaults for daily use
- `desk_switcheroo.debug.ini` — all features enabled for testing

See the [Advanced INI Reference](docs/configuration/ini-reference.md) for every setting, and the [CLI Parameters](docs/configuration/cli.md) page for scripting.

## Third-Party

- **[VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor)** by Jari Pennanen (Ciantic) — MIT License
- **[Fira Code](https://github.com/tonsky/FiraCode)** by Nikita Prokopov — SIL Open Font License

## Documentation

Full documentation is published as a browsable site at **<https://supermarsx.github.io/desk-switcheroo/>** (goes live once GitHub Pages is enabled for this repo). The same pages live under [`docs/`](docs/) and render directly on GitHub:

- [Getting Started](docs/getting-started.md) — install routes and first run
- [How It Works](docs/how-it-works.md) — what the widget does under the hood
- [Interface Tour](docs/interface-tour.md) — an annotated, screenshot-by-screenshot walkthrough
- [Feature Set](docs/features.md) — the full, grouped feature list
- **Configuration** — [overview](docs/configuration/index.md), [CLI Parameters](docs/configuration/cli.md), [Advanced INI Reference](docs/configuration/ini-reference.md)
- **Guides** — [Everyday Usage](docs/guides/usage.md), [Coloring & Theming](docs/guides/coloring.md), [Desktop Management](docs/guides/desktop-management.md), [Persistence & Profiles](docs/guides/persistence.md), [Rules Engine & Hooks](docs/guides/rules-engine.md), [Logging & Diagnostics](docs/guides/logging.md)
- **Reference** — [Compatibility](docs/reference/compatibility.md), [Stability & Mitigations](docs/reference/stability.md), [Known Limitations](docs/reference/limitations.md), [Architecture & Patterns](docs/reference/architecture.md), [Building from Source](docs/reference/building.md), [Deployment & Lifecycle](docs/reference/lifecycle.md), [Licensing](docs/reference/licensing.md)
- [Comparison with Other Tools](docs/comparison.md) — researched, source-cited, with per-use-case recommendations

## License

This project is licensed under the **MIT License** — see the [license.md](license.md) file for details.
