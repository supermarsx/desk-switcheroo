---
title: Compatibility Matrix
nav_order: 1
parent: Reference
---

# Compatibility Matrix

Desk Switcheroo targets **64-bit Windows 10 and Windows 11**. This page lays out what runs
where: operating-system support and per-feature deltas, the AutoIt requirement for running
from source, the version-sensitive native dependency, locale coverage, and how the app is
distributed.

## Operating system

| Platform | Supported | Notes |
|---|:-:|---|
| Windows 11, 64-bit | Yes | Full feature set, including OS desktop-name sync. |
| Windows 10, 64-bit | Yes | Full feature set except OS desktop-name sync (labels are stored locally instead). |
| Windows 10/11, 32-bit | No | The app and its `VirtualDesktopAccessor.dll` dependency are x64 only. |
| Windows 8.1 and earlier | No | No virtual-desktop support in the OS. |

Both compiled builds and the from-source path are x64: the app is built with `Aut2Exe /x64`
and tested with `AutoIt3_x64.exe` because the bundled DLL is 64-bit (see
[Building from Source](building.md)).

### Per-feature deltas between Windows 10 and Windows 11

Nearly everything behaves identically on both. The one real behavioral difference is how
desktop **labels** relate to the names Windows itself keeps:

| Feature | Windows 11 | Windows 10 |
|---|---|---|
| Custom desktop labels | Yes | Yes |
| **OS desktop-name sync** | Yes — labels round-trip with the names Windows shows in Task View | No — labels live only in `desktop_labels.ini` / `desk_switcheroo.ini` |
| Switch / add / remove / reorder desktops | Yes | Yes |
| Move window to desktop | Yes | Yes |
| Per-desktop colors, wallpaper, peek, rules, hooks, CLI/IPC | Yes | Yes |

This split is not a hardcoded version check. At startup `_VD_Init` (in
`includes/VirtualDesktop.au3`) probes the DLL by test-calling `GetDesktopName`; if that export
works, name support is enabled (`$__g_VD_bNameSupport`). Windows 11 exposes named desktops and
Windows 10 does not, so in practice sync is a Windows 11 capability. `_Labels_Init` (in
`includes/Labels.au3`) gates OS sync on that probe (`_VD_HasNameSupport`) and auto-falls back
to INI-only labels when it is unavailable — so the same build works unmodified on both
Windows versions. What a desktop switch does end-to-end is described in
[How It Works](../how-it-works.md).

## AutoIt (running from source only)

You do **not** need AutoIt to run a compiled release — `DeskSwitcheroo.exe` is standalone. To
run or build from source you need **AutoIt v3.3.18 or newer, x64**. Details and the full
toolchain are in [Building from Source](building.md).

## Native dependency: VirtualDesktopAccessor.dll

Windows 10/11 have a built-in virtual-desktop engine but expose almost no public API for it.
Desk Switcheroo drives it through
[`VirtualDesktopAccessor.dll`](https://github.com/Ciantic/VirtualDesktopAccessor) by
Jari Pennanen (Ciantic), MIT-licensed and **bundled with every release** — you never install
it separately.

This DLL is the app's **Windows-build-sensitive** dependency. It wraps undocumented Windows
COM interfaces that Microsoft changes between Windows feature updates, so a given DLL build is
tied to a range of Windows builds. As of July 2026 the upstream project states it targets
Windows 11 24H2 (build 26100.2605) and newer (per its
[README](https://github.com/Ciantic/VirtualDesktopAccessor)); the version vendored in this
repository is pinned to match the app's supported OS range. The practical consequences:

- A major Windows update can, in principle, break desktop control until a matching DLL build
  is bundled. This is inherent to relying on an unofficial accessor, not a bug in the app.
- The app defends against a mismatch at load time: `_VD_Init` validates core exports
  (`GetDesktopCount`, `GetCurrentDesktopNumber`) by test-calling them and logs
  `incompatible DLL version?` and refuses to proceed if they fail, rather than misbehaving
  silently.

This trade-off is listed among the honest [Known Limitations](limitations.md).

## Locales

Desk Switcheroo ships **34 locales** in `locales/` (run `ls locales` to confirm the current
count). Each is a plain INI file carrying the same set of roughly 700 keys as the reference
`en-US.ini`, enforced by `scripts/locale-check.ps1`. The active language is chosen in
**Settings → General → Language**, and any locale file dropped into `locales/` is picked up
automatically — see [Building from Source](building.md) for how to add one. Missing keys in a
locale fall back to `en-US` and then to a hardcoded default, so a partial translation never
leaves the UI blank.

## Distribution channels

| Channel | Artifact | Elevation | Where it comes from |
|---|---|:-:|---|
| Portable ZIP | `DeskSwitcheroo_Portable.zip` | No | Release asset — extract and run. |
| Installer | `DeskSwitcheroo_Setup.exe` | Yes (admin) | Release asset — NSIS installer to `%ProgramFiles%\DeskSwitcheroo`. |
| Chocolatey | `packaging/chocolatey/` | Yes (admin) | Wraps the Setup.exe with silent `/S`. |
| Scoop | `packaging/scoop/desk-switcheroo.json` | No | References the portable ZIP. |
| winget | `packaging/winget/supermarsx.DeskSwitcheroo.yaml` | Yes (admin) | References the Setup.exe (nullsoft). |
| From source | git clone | No | Run/compile with AutoIt (see [Building from Source](building.md)). |

The portable ZIP and installer are the two channels published as GitHub release assets. The
Chocolatey, Scoop, and winget manifests are maintained in `packaging/` and currently pin an
earlier version with empty checksums, which indicates they are packaging templates rather than
confirmed-published entries in the public Chocolatey / Scoop / winget repositories. For the
authoritative, per-channel status — plus silent-install flags, auto-update paths, and exactly
what each channel leaves behind on uninstall — see [Deployment & Lifecycle](lifecycle.md).
