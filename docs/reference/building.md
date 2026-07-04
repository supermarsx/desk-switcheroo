---
title: Building from Source
nav_order: 5
parent: Reference
---

# Building from Source

Desk Switcheroo is written in [AutoIt](https://www.autoitscript.com/) and compiled to a
standalone x64 executable. This page covers everything you need to run it from source, build
and package a release, run the test suite, and extend the app with a new locale or config key.
The developer-level structure of the code is described in
[Architecture & Patterns](architecture.md).

## Prerequisites

- **[AutoIt](https://www.autoitscript.com/) v3.3.18+, x64.** Required to run from source and to
  compile. The x64 toolchain matters: `VirtualDesktopAccessor.dll` is 64-bit, so the app is
  built and tested with `AutoIt3_x64.exe` / the x64 `Aut2Exe`.
- **[PowerShell 7+](https://github.com/PowerShell/PowerShell).** All build scripts under
  `scripts/` are PowerShell (`pwsh`).
- **[NSIS](https://nsis.sourceforge.io/) 3.x with MUI2** — *optional*, only needed to build the
  installer (`scripts/package.ps1` skips the installer step if `makensis.exe` is not found).

The scripts locate AutoIt automatically: they honor an `AUTOIT_PATH` environment variable if
set, otherwise they probe the standard install locations. If you do not have AutoIt installed,
`scripts/install-autoit.ps1` downloads the official portable bundle and exports `AUTOIT_PATH`
for the current session — this is exactly what CI uses.

## Running from source

```powershell
git clone https://github.com/supermarsx/desk-switcheroo.git
cd desk-switcheroo
pwsh scripts/run-dev.ps1
```

`run-dev.ps1` finds `AutoIt3_x64.exe` and runs `desktop_switcher.au3` directly — no compile
step. You can also invoke AutoIt yourself: `AutoIt3_x64.exe desktop_switcher.au3`.

## Build scripts

Everything lives in `scripts/` (13 PowerShell scripts). Run any of them with
`pwsh scripts/<name>.ps1`.

| Script | What it does |
|---|---|
| `run-dev.ps1` | Runs `desktop_switcher.au3` from source with the x64 AutoIt interpreter (no compile). |
| `build.ps1` | Compiles `desktop_switcher.au3` to `build/DeskSwitcheroo.exe` with `Aut2Exe /x64` (embedding `assets/desk_switcheroo.ico` if present), then copies `VirtualDesktopAccessor.dll`, `fonts/`, the `VERSION` file, and `examples/` into `build/`. |
| `package.ps1` | Runs `build.ps1`, zips `build/DeskSwitcheroo_Portable.zip` (exe + DLL + fonts), then builds `build/DeskSwitcheroo_Setup.exe` via NSIS. Skips the installer with a warning if `makensis.exe` is not found. |
| `generate-icon.ps1` | Runs `tools/generate_icon.au3` (GDI+) to produce `assets/desk_switcheroo.ico`. Run this before `build.ps1` if the icon is missing. |
| `test.ps1` | Runs `tests/TestRunner.au3` with `AutoIt3_x64.exe /ErrorStdOut` and exits with the runner's exit code (0 = all pass, 1 = failures). |
| `lint.ps1` | Runs `Au3Check.exe` against the two aggregate roots, mirroring CI (see [Lint & format](#lint--format)). Skips with exit 0 if `Au3Check.exe` is absent. |
| `format.ps1` | Normalizes every `*.au3` (outside `build/`) to CRLF line endings, trims trailing whitespace, and ensures a final newline. This is the fixer for the CI `format` check. |
| `locale-check.ps1` | Verifies every `locales/*.ini` has the same key set as `en-US.ini` (ignoring the `[Meta]` section); exits 1 on any missing or extra key. |
| `install-autoit.ps1` | Downloads the official portable AutoIt zip and exports `AUTOIT_PATH` (used by CI; handy locally if you lack a system AutoIt). |
| `install.ps1` | Copies a build to a target directory (default `%LOCALAPPDATA%\DeskSwitcheroo`), building first if `build/` is empty. Copies the exe, DLL, `VERSION`, `fonts/`, `locales/`, and `examples/`. |
| `clean.ps1` | Removes `build/`, `desk_switcheroo_state.ini`, `test_output.txt`, and any `crash_*.log` / `desk_switcheroo*.log` in the repo root. |
| `release.ps1` | Local release helper: computes the next `vYY.N` tag for the current year from existing tags, creates an annotated tag, and pushes it. See the [note on releases](#a-note-on-releases-and-versioning) below. |

### Typical workflows

```powershell
pwsh scripts/build.ps1      # compile only -> build/DeskSwitcheroo.exe
pwsh scripts/package.ps1    # build + portable zip + installer
pwsh scripts/test.ps1       # run the full test suite
pwsh scripts/lint.ps1       # static analysis (as CI runs it)
pwsh scripts/format.ps1     # auto-fix formatting before pushing
```

## The test suite

Tests live in `tests/` as 23 `Test_*.au3` files, aggregated by `tests/TestRunner.au3`. The
runner `#include`s each module under test plus each test file, then calls one `_RunTest_*`
entry point per suite. It uses a tiny assertion framework (`_Test_AssertEqual`,
`_Test_AssertTrue`/`False`, `_Test_AssertNotEqual`, `_Test_AssertGreaterEqual`/`LessEqual`,
`_Test_Skip`) and prints a `Results: N passed, M failed` summary. **Exit code 0 means every
assertion passed; exit code 1 means at least one failed** (`_Test_Summary` in `TestRunner.au3`).

Run tests with x64 AutoIt so the DLL-backed suites load correctly:

```powershell
pwsh scripts/test.ps1
# or directly:
AutoIt3_x64.exe /ErrorStdOut tests\TestRunner.au3
```

The 23 suites cover: `Config`, `Theme`, `Labels`, `VirtualDesktop`, `Peek`, `DesktopList`,
`ContextMenu`, `RenameDialog`, `Logger`, `i18n`, `ConfigDialog`, `UpdateChecker`,
`AboutDialog`, `WindowList`, `Wallpaper`, `ExplorerMonitor`, `TaskbarAutoHide`, `WindowRules`,
`SessionRestore`, `Hooks`, `CLI`, `Profiles`, and `Performance`. Because the code favors pure,
side-effect-free helpers, most logic is unit-testable without a live desktop; several suites
are regression guards for specific past bugs — see [Architecture & Patterns](architecture.md).

### End-to-end sandbox

`scripts/e2e.ps1` launches `tests/sandbox.wsb`, a [Windows Sandbox](https://learn.microsoft.com/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview)
configuration that mounts the repo read-only at `C:\project`, mounts `tests/results/` as a
writable output folder, and runs `tests/sandbox_setup.ps1` on logon. This exercises the app in
a clean, disposable Windows image; results land in `tests/results/`. Windows Sandbox must be
enabled on your machine for this to work.

## Lint & format

Two CI gates keep the source consistent, and each has a matching script:

- **Lint** (`scripts/lint.ps1`) runs `Au3Check.exe`. Because the sources use relative
  `#include` paths that only resolve from their own directory, individual files do not lint
  standalone. CI and this script instead check the two *aggregate roots* that transitively
  include everything: `desktop_switcher.au3` (from the repo root) and `tests/TestRunner.au3`
  (from inside `tests/`). The exit codes are aggregated; any failure fails the job.
- **Format** is enforced by the CI `format` job, which requires every `*.au3` (outside
  `build/`) to use **CRLF line endings**, have **no trailing whitespace**, and **end with a
  final newline**. `scripts/format.ps1` applies exactly these rules, so run it before pushing.

Documentation pages under `docs/` follow the conventions in this repo's docs plan (UTF-8
without BOM, no trailing whitespace); they are not part of the AutoIt lint/format gates.

## CI pipeline

The workflow is `.github/workflows/ci.yml`. It runs on every push and pull request to `main`,
on `windows-2025-vs2026` runners, with five jobs:

1. **lint** — installs AutoIt via `install-autoit.ps1`, runs `Au3Check.exe` on the two
   aggregate roots.
2. **format** — the CRLF / trailing-whitespace / final-newline check described above.
3. **test** — installs AutoIt, runs `TestRunner.au3` with the x64 interpreter, uploads
   `test_output.txt` as an artifact.
4. **build** (needs lint, format, test) — installs AutoIt, generates the icon, runs
   `build.ps1`, installs NSIS via Chocolatey, runs `package.ps1`, and uploads the `build/`
   folder as an artifact.
5. **release** (needs build; runs only on a push to `main`) — see below.

### A note on releases and versioning

The **release** job runs on every push to `main`. It computes the next version in `YY.N`
form (current two-digit year, incrementing `N` from the latest existing `vYY.*` tag), writes
that into the `VERSION` file, commits `Bump version to <version>`, creates an annotated
`vYY.N` tag, pushes both back to `main`, assembles a source zip (the `.au3` scripts, the DLL,
fonts, assets, license, and README), and publishes a GitHub Release with three assets:
`DeskSwitcheroo_Setup.exe`, `DeskSwitcheroo_Portable.zip`, and `DeskSwitcheroo_Source.zip`.

> **Consequence to be aware of:** because the release job triggers on any push to `main`, a
> merge to `main` cuts a new release and tag — including a docs-only change. This is
> pre-existing repository behavior, not something specific to any one change. The local
> `scripts/release.ps1` uses the same `vYY.N` scheme if you need to tag manually.

## Extending the app

### Adding a locale

Locales are plain INI files in `locales/`; there are **34** as of this writing (run
`ls locales` to confirm). To add one:

1. Copy `locales/en-US.ini` to `locales/xx-XX.ini` (BCP-47 code).
2. Edit the `[Meta]` section: set `name`, `code`, `author`, and `contributors`.
3. Translate every value. **Keep the keys, `{1}`-style placeholders, `\n` escapes, and
   technical terms intact** — only the human-readable text changes.
4. Run `pwsh scripts/locale-check.ps1`. It must report your file with the same key count as
   `en-US.ini` (roughly 700 keys) and no missing/extra keys.
5. The new locale appears automatically in **Settings → General → Language** — the app
   discovers locale files at runtime; there is no list to register it in.

The i18n design (O(1) `Scripting.Dictionary` lookups, the current-locale → `en-US` →
hardcoded fallback chain) is described in [Architecture & Patterns](architecture.md).

### Adding a config key

Config is centralized in `includes/Config.au3`. Each key touches six sites within that file,
plus the UI, translations, tests, and examples. Using the existing `widget_width` key as a
template:

**In `includes/Config.au3` (six sites):**

1. **Global** — declare the backing variable, e.g. `Global $__g_Cfg_iWidgetWidth = 0`.
2. **Load** — read it in `__Cfg_Load` with the right helper and clamp/enum, e.g.
   `__Cfg_ReadInt($f, "General", "widget_width", 0, 0, 500)`.
3. **Save** — write it in `__Cfg_Save` with `IniWrite`.
4. **Default** — register it in the defaults writer (`__Cfg_DefaultVal`) so a fresh INI and
   the "reset to defaults" path both know it.
5. **Getter** — add `_Cfg_GetWidgetWidth()`.
6. **Setter** — add `_Cfg_SetWidgetWidth($i)`.

**Then, outside `Config.au3`:**

7. `includes/ConfigDialog.au3` — add the control to the appropriate tab builder, populate it
   when the dialog opens, and save it in `__CD_ApplyChanges`.
8. `locales/en-US.ini` — add the label and tooltip keys (then translate, or let
   `locale-check.ps1` flag the other locales as needing them).
9. `tests/Test_Config.au3` — add default and set/get assertions.
10. `examples/desk_switcheroo.prod.ini` and `examples/desk_switcheroo.debug.ini` — add the key
    with appropriate values.

The full catalogue of existing keys, their types, defaults, and UI exposure is in the
[Advanced INI Reference](../configuration/ini-reference.md).
