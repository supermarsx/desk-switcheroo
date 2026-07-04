---
title: Development Guide
nav_order: 9
parent: Reference
---

# Development Guide

This is the contributor's guide to the codebase: how it is laid out, the conventions to
follow, how to write and run tests, and what CI expects of a pull request. It goes deeper than
[Building from Source](building.md), which covers the mechanics of building, packaging, and the
`scripts/*.ps1` tooling — this page assumes you can already build and focuses on *changing the
code well*. For the design ideas behind the structure, read
[Architecture & Patterns](architecture.md).

## Repository layout

Desk Switcheroo is procedural AutoIt. The entry point `desktop_switcher.au3` at the repo root
holds the startup sequence and the main event loop; everything else is a single-purpose module
under `includes/`. The modules, with their one-line purpose:

| Module | Purpose |
|---|---|
| `desktop_switcher.au3` (root) | Entry point: startup sequence, the widget, and the main event loop. |
| `includes/Config.au3` | Reads, clamps, and writes every setting; the INI schema lives here. |
| `includes/ConfigDialog.au3` | The 14-tab Settings dialog, including its live search. |
| `includes/VirtualDesktop.au3` | Wrapper around `VirtualDesktopAccessor.dll` plus the `EnumWindows` bypass. |
| `includes/DesktopList.au3` | The desktop list popup panel and drag-to-reorder. |
| `includes/WindowList.au3` | The window list panel, its context menus, and all-window actions. |
| `includes/Labels.au3` | Desktop labels: storage, shift-on-delete, OS-name sync. |
| `includes/RenameDialog.au3` | The rename-desktop dialog. |
| `includes/Peek.au3` | Peek-and-bounce-back navigation. |
| `includes/Theme.au3` | Themes, the custom popup toolkit, fonts, fades, tooltips. |
| `includes/Wallpaper.au3` | Per-desktop wallpaper application. |
| `includes/ContextMenu.au3` | The widget's right-click menu. |
| `includes/TaskbarAutoHide.au3` | Coexistence with the auto-hiding taskbar. |
| `includes/ExplorerMonitor.au3` | Detects and recovers from Explorer restarts. |
| `includes/WindowRules.au3` | The `pattern → desktop` rules engine (polling). |
| `includes/Hooks.au3` | The event-hook system. |
| `includes/Profiles.au3` | Named configuration profiles. |
| `includes/SessionRestore.au3` | Restoring windows to desktops across restarts. |
| `includes/CLI.au3` | Command-line parsing and the `WM_COPYDATA` IPC channel. |
| `includes/Logger.au3` | Levelled logging, rotation, and detached compression. |
| `includes/UpdateChecker.au3` | Background update check and portable download. |
| `includes/i18n.au3` | Localization lookups and the fallback chain. |
| `includes/AboutDialog.au3` | The About dialog. |

Tests live in `tests/` (one `Test_*.au3` per module plus `TestRunner.au3` and the sandbox
harness), build and packaging scripts in `scripts/`, the installer in `installer/`,
package-manager manifests in `packaging/`, translations in `locales/`, and example configs in
`examples/`.

## Coding conventions

- **Module prefix pattern.** Public functions of a module are named `_Module_Name`
  (one leading underscore); internal helpers are `__Module_Name` (two). For example
  `WindowList.au3` exposes `_WL_Show` and keeps `__WL_EnumFilteredWindows` private. Follow the
  existing prefix of the file you are editing (`_WL_`, `_Cfg_`, `_VD_`, `_CD_`, …).
- **The multi-site config-key pattern.** Adding a setting touches several coordinated sites
  (the read/clamp accessor in `Config.au3`, the write accessor, the Settings control, the
  apply path, defaults, and tests). This is deliberate and mechanical — the full checklist is
  in [Building from Source](building.md#adding-a-config-key), and the rationale is in
  [Architecture & Patterns](architecture.md#the-multi-site-config-key-pattern). Do not
  shortcut it; a key that is read but never clamped, or set but never applied, is the usual
  source of config bugs.
- **Line endings and formatting.** Source is CRLF with a trailing newline and no trailing
  whitespace; the CI `format` job enforces this on `*.au3`. Run `scripts/format.ps1` before
  committing. Note `format.ps1` only processes `.au3` files — `.ini` files stay LF in the
  working tree.
- **Internationalization.** Every user-visible string goes through `_i18n` (or `_i18n_Format`)
  with an English fallback baked in at the call site, e.g.
  `_i18n("WindowList.wl_close", "Close")`. Never hardcode a bare display string. When you add
  a key you must add it to **all 34 locale files** — `en-US.ini` is the source of truth and
  `scripts/locale-check.ps1` fails on any locale that is missing or has extra keys. See
  [Adding a locale](building.md#adding-a-locale) and
  [the i18n design](architecture.md#internationalization).

## Writing a test

The test framework is a single runner, `tests/TestRunner.au3`, that `#include`s every module
and every `Test_*.au3`, then calls each suite's entry function. To add tests for a module:

1. Create `tests/Test_YourModule.au3` with `#include-once` and a function
   `Func _RunTest_YourModule()` that opens with `_Test_Suite("YourModule")`.
2. Write assertions with the framework helpers (defined in `TestRunner.au3`):
   `_Test_AssertEqual`, `_Test_AssertNotEqual`, `_Test_AssertTrue`, `_Test_AssertFalse`,
   `_Test_AssertGreaterEqual`, and `_Test_AssertLessEqual`. Each takes a descriptive name
   first, e.g. `_Test_AssertEqual("WL default width", _Cfg_GetWindowListWidth(), 280)`.
3. Wire the suite into `TestRunner.au3`: add the `#include "Test_YourModule.au3"` alongside the
   others and a `_RunTest_YourModule()` call in the run list. (Modules under test are already
   included at the top of the runner; add yours there too if it is new.)

The runner exits `0` when every assertion passes and `1` if any fail, which is what CI checks.

**Prefer pure, headless-testable logic.** Most suites test pure functions — decision helpers,
parsers, geometry math — that need no live GUI or virtual-desktop COM, so they run headless in
CI. The codebase deliberately factors such logic out for this reason (for example
`__WL_IsPointInTitleBar` and `__WL_ClassifyTopmostResult` in `WindowList.au3`, or the
`_Nav_*Target` navigation math). When you fix a bug, add a pure regression assertion that
would have caught it.

### Regression-test tagging

When a test guards against a specific bug, tag it in the assertion name with the date it was
fixed: `Regression YYYY-MM-DD: <what must hold>`. For example:

```autoit
_Test_AssertEqual("Regression 2026-07-03: 10 rapid next() advance 10 steps (not collapse)", _
    $iSteps, 10)
```

This convention (used throughout `Test_VirtualDesktop.au3`, `Test_Theme.au3`, and
`Test_ConfigDialog.au3`) makes it obvious in test output that a named past bug is still fixed.

### The window-mutation safety rule (project law)

Some features **enumerate real windows and then change them** — move them between desktops,
minimize/maximize/close them, toggle always-on-top. Tests that exercise the *mutating* path of
such a feature must run **only inside the Windows Sandbox** (`tests/E2E_Sandbox.au3`, launched
via `tests/sandbox.wsb` and `scripts/e2e.ps1`), never against your live session. Running an
"enumerate-and-mutate" test on the host can move, minimize, or close your own real windows.
Keep host-side `Test_*.au3` suites to pure logic and read-only state; put anything that
actually mutates windows in the sandbox E2E harness. This is a hard project rule.

## Verification quick reference

The real commands, including the quirks that will otherwise waste your time:

- **Run the tests.** Launch `TestRunner.au3` with the x64 AutoIt from the `tests/` directory.
  On Windows, run it via PowerShell `Start-Process AutoIt3_x64.exe -RedirectStandardOutput` —
  running it through Git Bash reports a spurious exit 1 because the GUI binary's `ConsoleWrite`
  output is not captured there.
- **Lint.** The CI-equivalent lint is Au3Check on the **two aggregate roots only** —
  `desktop_switcher.au3` from the repo root and `tests/TestRunner.au3` from `tests/`.
  `scripts/lint.ps1` does exactly this. Linting an individual `includes/*.au3` in isolation is
  meaningless because its cross-includes cannot resolve.
- **Format.** `scripts/format.ps1` (checks CRLF, trailing newline, trailing whitespace on
  `.au3`).
- **Locale parity.** `scripts/locale-check.ps1` — hard-fails on any locale with missing or
  extra keys versus `en-US.ini`. It is **not** part of CI, so run it explicitly after any i18n
  change.
- **Build.** `scripts/build.ps1`, but treat its exit `0` with suspicion: its `Test-Path` check
  can pass against a **stale** binary. Verify the output `.exe`'s `LastWriteTime` actually
  advanced. Never launch the repo/build `.exe` directly — the singleton would kill the user's
  live instance; smoke-test an isolated copy with `singleton_enabled=false` in a scratch INI.

Some suites have **environment-dependent flakes that are not regressions**: `Test_Theme`
cursor-X asserts can fail when the OS returns a garbage negative resting cursor X;
`Test_VirtualDesktop` skips a block of asserts when `_VD_Init` COM init fails in the run
context (which shifts the suite's assert count); and `Test_Performance` micro-benchmarks flake
under CPU load. A wobble in exactly those places is expected, not a break you caused.

## Pull request expectations

- **CI must pass.** The `ci.yml` pipeline runs lint, format, test, and build jobs; all must be
  green. The pipeline walkthrough is in [Building from Source](building.md#ci-pipeline).
- **Keep locales in parity.** If your change adds or renames a user-visible string, update all
  34 locales and run `locale-check.ps1` locally (CI does not).
- **Add a regression test** for any bug fix, tagged with the date convention above.
- **Auto-release warning.** The `release` job computes a `vYY.N` version and tags a release on
  **every push to `main`** — merging a PR cuts a release. This is existing repo behavior, not
  something your PR opts into, but it means `main` should always be releasable. See
  [the note on releases and versioning](building.md#a-note-on-releases-and-versioning).

## Related pages

- [Building from Source](building.md) — prerequisites, scripts, CI, packaging.
- [Architecture & Patterns](architecture.md) — the design behind the module layout.
- [Extensibility & Integration](extensibility.md) — the external integration surfaces.
- [Stability & Mitigations](stability.md) — the runtime-safety behaviors you must not regress.
