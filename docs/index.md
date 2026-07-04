---
title: Home
nav_order: 1
---

# Desk Switcheroo

<img width="881" height="256" alt="Desk Switcheroo" src="https://github.com/user-attachments/assets/f6b2545a-554d-4e8a-8d93-0fd0e0430662" />

Desk Switcheroo is a lightweight Windows virtual desktop switcher widget for your
taskbar. Navigate, rename, peek, and manage desktops from a compact dark-themed
overlay — without opening Task View or reaching for the mouse. It sits quietly on the
taskbar (or in the system tray), drives the built-in Windows virtual-desktop engine
through a bundled helper DLL, and stays out of your way until you need it.

![The Desk Switcheroo widget docked at the taskbar corner, showing desktop 1 labeled "Main" with navigation arrows and a blue accent bar.](assets/screenshots/widget.png)

*The taskbar widget: current desktop number, its label, navigation arrows, and a per-desktop accent bar.*

The whole application is portable by design: it keeps its configuration in plain INI
files next to the executable, so you can carry it on a USB stick or drop it in any
folder and run it with no installer and no registry footprint.

## Requirements

- **Windows 10 or 11** (64-bit only)
- [VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor) — bundled with every release

> To run from source you also need [AutoIt v3](https://www.autoitscript.com/) (64-bit).
> The compiled `.exe` works standalone.

## Who is this for

Desk Switcheroo is built around a handful of people who live on Windows virtual desktops:

- **Multi-desktop power users** — if you keep separate desktops for work, comms, and
  play, the widget gives you an always-visible count and one-click switching so you
  never lose track of where you are.
- **Keyboard-driven users** — global hotkeys, direct desktop jumps (1–9), and
  wheel navigation let you move between desktops without touching Task View.
- **Minimal-footprint / portable-tool users** — a single portable folder, INI-file
  config, and no background services suit anyone who wants a tool they can carry and
  remove without a trace.
- **Visual customizers** — per-desktop wallpaper, accent colors, and custom labels let
  you make each desktop instantly recognizable.
- **Scripters & automators** — a full CLI, `WM_COPYDATA` IPC, event hooks, and a window
  rules engine let you drive and extend the app from scripts and other tools.

The [How It Works](how-it-works.md) page expands each of these into concrete use cases.

## Explore the documentation

- **[Getting Started](getting-started.md)** — install, first run, and basic use.
- **[How It Works](how-it-works.md)** — what the widget is and what happens when you switch.
- **[Feature Set](features.md)** — the full list of what Desk Switcheroo can do.
- **[Configuration](configuration/index.md)** — the Settings dialog, CLI parameters, and the advanced INI reference.
- **[Guides](guides/index.md)** — coloring, desktop management, persistence, rules & hooks, and logging.
- **[Reference](reference/index.md)** — compatibility, stability, limitations, architecture, building, lifecycle, and licensing.
- **[Comparison with Other Tools](comparison.md)** — how Desk Switcheroo stacks up, with per-persona recommendations.

## License & credits

Desk Switcheroo is released under the **MIT License** (Copyright &copy; 2026 Mariana).
See the [Licensing](reference/licensing.md) page for the full text, a plain-language
summary, and the third-party component list.

It bundles two third-party components:

- **[VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor)**
  by Jari Pennanen (Ciantic) — MIT License.
- **[Fira Code](https://github.com/tonsky/FiraCode)** by Nikita Prokopov — SIL Open Font License.
