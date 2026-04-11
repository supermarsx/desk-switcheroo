# Development Guide

## Prerequisites

- [AutoIt v3.3.18+](https://www.autoitscript.com/) (64-bit)
- [NSIS](https://nsis.sourceforge.io/) (optional, for installer builds)
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) (for build scripts)

## Project Structure

```
desk-switcheroo/
├── desktop_switcher.au3          Main script (event loop, GUI)
├── includes/
│   ├── Config.au3                80+ config keys, INI persistence
│   ├── ConfigDialog.au3          9-tab Settings dialog (~1800 lines)
│   ├── ContextMenu.au3           Widget right-click menu
│   ├── DesktopList.au3           Desktop list with drag-reorder, scroll, peek
│   ├── Theme.au3                 5 themes, fade helpers, toast, tooltip, confirm
│   ├── VirtualDesktop.au3        DLL wrapper (EnumWindows, swap, move)
│   ├── Labels.au3                Desktop label persistence + OS sync
│   ├── Logger.au3                Logging with rotation/compression
│   ├── Peek.au3                  Desktop peek state machine
│   ├── RenameDialog.au3          Rename label dialog
│   ├── AboutDialog.au3           About dialog with credit links
│   ├── UpdateChecker.au3         Auto-update + download portable
│   └── i18n.au3                  Internationalization (Scripting.Dictionary)
├── locales/                      17 locale INI files
├── tests/                        9 test suites, 409+ assertions
├── scripts/                      12 PowerShell scripts
├── tools/                        Icon generator (GDI+)
├── installer/                    NSIS installer script
├── examples/                     Prod + debug INI configs
├── fonts/                        Fira Code (OFL)
├── assets/                       Generated icons
└── docs/                         Documentation
```

## Scripts

| Script | Usage |
|--------|-------|
| `scripts/run-dev.ps1` | Run from source |
| `scripts/test.ps1` | Run full test suite |
| `scripts/lint.ps1` | Run au3check on all files |
| `scripts/format.ps1` | Normalize line endings |
| `scripts/build.ps1` | Compile to .exe |
| `scripts/package.ps1` | Build + NSIS installer + portable zip |
| `scripts/release.ps1` | Bump version (YY.N), tag, push |
| `scripts/generate-icon.ps1` | Generate application icon |
| `scripts/locale-check.ps1` | Verify all translations are complete |
| `scripts/install.ps1` | Install build to local directory |
| `scripts/clean.ps1` | Remove build artifacts |
| `scripts/e2e.ps1` | Run E2E sandbox tests |

## Testing

```powershell
pwsh scripts/test.ps1
```

Or directly:
```
"C:\Program Files (x86)\AutoIt3\AutoIt3_x64.exe" tests\TestRunner.au3
```

Tests cover: Config (178 assertions), Theme, Labels, VirtualDesktop, Peek, DesktopList, ContextMenu, RenameDialog, Logger, i18n. Exit code 0 = pass, 1 = failures.

## Building

```powershell
pwsh scripts/build.ps1      # Compile to build/DeskSwitcheroo.exe
pwsh scripts/package.ps1     # Build + installer + portable zip
```

## Architecture

### Main Loop

`desktop_switcher.au3` runs a `While 1` loop with 6 extracted helper functions:
1. `_ProcessGUIEvents` — GUIGetMsg dispatch
2. `_ProcessMouseInput` — GetAsyncKeyState polling for LMB/RMB/MMB/drag
3. `_ProcessKeyboardInput` — keyboard nav, quick-access
4. `_ProcessEventFlags` — desktop change + name sync events
5. `_ProcessHoverAndVisuals` — single-pass hit-testing, hover effects
6. `_ProcessTimersAndSleep` — toast tick, update poll, adaptive sleep

### Window Enumeration

AutoIt's `WinList()` is virtual-desktop-scoped on Windows 10/11. We bypass it with `DllCallbackRegister` + Win32 `EnumWindows` to get ALL windows system-wide for desktop swap operations.

### Animation System

`_Theme_FadeIn`/`_Theme_FadeOut` use `_WinAPI_SetLayeredWindowAttributes` with stepped alpha. Per-location toggles (list, menus, dialogs, toasts, widget) via `__Theme_ShouldAnimate($sType)`.

### i18n

`Scripting.Dictionary`-based O(1) lookup. 278 `_i18n()` calls. Fallback chain: current locale → en-US.ini → hardcoded default. Locale files are standard INI with `[Section]` and `key=value`.

## Adding a Locale

1. Copy `locales/en-US.ini` to `locales/xx-XX.ini`
2. Edit `[Meta]`: set `name`, `code`, `author`, `contributors`
3. Translate all values (keep keys, `{1}` placeholders, `\n`, technical terms)
4. Run `pwsh scripts/locale-check.ps1` to verify 277/277 keys
5. It appears automatically in Settings > General > Language

## Adding a Config Key

1. `Config.au3`: add Global, load (`__Cfg_ReadInt`/`Bool`/`Enum`), save, defaults, getter, setter
2. `ConfigDialog.au3`: add control in the appropriate tab builder, populate, save in `__CD_ApplyChanges`
3. `locales/en-US.ini`: add label + tooltip keys
4. `tests/Test_Config.au3`: add default + set/get assertions
5. `examples/*.ini`: add the key with appropriate values

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`):
- **test**: `choco install autoit` → run TestRunner.au3
- **build**: compile with Aut2Exe (x64)
- **release** (on `v*` tag): build + NSIS + portable zip → GitHub Release
