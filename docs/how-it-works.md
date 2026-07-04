---
title: How It Works
nav_order: 3
---

# How It Works

This page explains what Desk Switcheroo is and what it does when you use it, in
plain language. It is the user-level companion to the developer-level
[Architecture & Patterns](reference/architecture.md) page, which covers how the
code itself is organized.

## The widget

Desk Switcheroo is a small, always-on-top overlay that docks against your
taskbar. It shows the current virtual desktop's number, its label, and an
optional accent color, plus arrows to move between desktops. It is a normal
top-level window painted by the application (see `desktop_switcher.au3`) — **not**
a shell extension, and it does not inject into Explorer. Nothing about your
Windows install is modified to make the widget appear; when the program is not
running, the widget is simply gone.

![The widget showing desktop 1 "Main" with navigation arrows and an accent color bar.](assets/screenshots/widget.png)

*The widget is an ordinary layered top-level window the app paints — not a shell extension.*

If you prefer to stay out of the way, the app can run as a **tray icon** instead
of an on-taskbar widget (tray mode). Either way it is a single, self-contained
process.

## How it controls desktops

Windows 10 and Windows 11 already have a built-in virtual-desktop engine — the
same one behind Task View and the `Ctrl+Win+Left/Right` shortcuts. Windows
exposes almost no public API for driving that engine from another program, so
Desk Switcheroo talks to it through a bundled helper library,
`VirtualDesktopAccessor.dll` (an open-source component by Ciantic; see
[Licensing](reference/licensing.md)). The app loads that DLL at startup and uses
it to switch desktops, create and remove them, move windows between them, and
read the current desktop number (see `includes/VirtualDesktop.au3`). Because the
DLL speaks to the OS engine directly, a switch triggered by Desk Switcheroo is
the same switch Windows would perform itself — which is why it is instant and
why other desktop features keep working normally.

One consequence of relying on this unofficial bridge: the DLL is tied to
Windows' internal desktop interfaces, which Microsoft can change between Windows
builds. See [Known Limitations](reference/limitations.md) and the
[Compatibility Matrix](reference/compatibility.md) for what that means in
practice.

## What happens when you switch

Whether you click an arrow, click a desktop number, press a hotkey, or scroll
the mouse wheel over the widget, the same end-to-end sequence runs (traced in
`desktop_switcher.au3` and `includes/VirtualDesktop.au3`):

1. **You act.** A click, hotkey, or wheel event is picked up by the main loop.
2. **The app asks the DLL to switch.** `_VD_GoTo` calls the DLL's
   `GoToDesktopNumber` export for the target desktop. Before the call it can
   optionally suppress Windows' own desktop-switch animation/overlay (so the
   app's own on-screen display can take over) and apply a "taskbar focus" trick
   that makes switching more reliable on some systems.
3. **Windows performs the switch.** The OS activates the target desktop exactly
   as if you had used Task View.
4. **The app is notified.** Desk Switcheroo registers for desktop-change
   notifications, so when the switch completes it runs `_RefreshIndex`, which
   reconciles the new current desktop and remembers the previous one.
5. **Everything updates.** On a confirmed change the app updates the widget's
   number, label, and accent color; applies that desktop's
   [per-desktop wallpaper](guides/coloring.md) if one is set; shows the optional
   on-screen display (the OSD "toast" with the desktop number and/or name);
   refreshes the window list if it is open; and fires the `on_desktop_change`
   [hook](guides/rules-engine.md) so any command you attached to that event
   runs.

![The on-screen display overlay reading "2: Code" centered near the top of the screen.](assets/screenshots/osd.png)

*Step 5 in action: the optional on-screen display announces the desktop you switched to.*

The OSD's text, position, size, and duration are all configurable on the OSD tab in Settings:

![The Settings dialog OSD tab, with controls for showing the desktop name/number, duration, position, font size, opacity, and format.](assets/screenshots/settings-osd.png)

*The OSD tab controls the on-screen display's format (`{number}: {name}` by default), position, and timing.*

All of this happens in a single pass of the app's event loop, so the widget
reflects the new desktop essentially the moment Windows finishes switching. The
mechanics of that loop are described in
[Architecture & Patterns](reference/architecture.md).

## Where your data lives

Desk Switcheroo is portable by design. It keeps its settings and state in plain
`.ini` files next to the executable (its script directory, `@ScriptDir` in the
code): `desk_switcheroo.ini` for configuration, `desktop_labels.ini` for your
desktop names, and `desk_switcheroo_state.ini` for saved runtime state such as
the desktop-list scroll position. Named profiles and, by default, the log file
live in the same folder. Nothing is written to a hidden system location unless
you deliberately redirect the log folder. That means you can copy the whole
folder to a USB stick or another machine and keep your setup. For a file-by-file
breakdown of what is saved and when, see
[Persistence & Profiles](guides/persistence.md); for where files land per
install channel, see [Deployment & Lifecycle](reference/lifecycle.md).

## What it helps with

Desk Switcheroo is built for people who actually live across several virtual
desktops. The scenarios below are the long-form version of the "Who is this for"
summary on the [Home](index.md) page.

- **Multi-desktop power users.** If you keep separate desktops for email,
  coding, communications, and research, the widget gives you a permanent,
  glanceable readout of which desktop you are on and one-click movement between
  them — without opening Task View every time. Add/remove desktops, reorder them
  by dragging, and jump straight to a numbered desktop from the keyboard.

- **Keyboard-driven users.** Every core action has a hotkey: next/previous
  desktop, jump to desktop 1–9, toggle the desktop list, move the active window
  to another desktop, and more. You can drive the whole tool without reaching for
  the mouse. See [Desktop Management](guides/desktop-management.md) and the
  [CLI reference](configuration/cli.md).

- **Minimal-footprint / portable-tool users.** It is one small process with no
  installer required, no background services, and no registry footprint unless
  you opt into "Start with Windows." Run it from a folder or a USB stick, and
  delete it by deleting the folder. See
  [Deployment & Lifecycle](reference/lifecycle.md).

- **Visual customizers.** Give each desktop its own accent color, wallpaper, and
  label, choose from five built-in themes, and tune fonts and opacity so the
  widget matches your setup. See [Coloring & Theming](guides/coloring.md).

- **Scripters & automators.** A command-line interface and a running-instance
  IPC channel let you script desktop actions (`goto`, `next`, `save-profile`,
  and more), while [rules](guides/rules-engine.md) auto-move matching windows to
  designated desktops and [hooks](guides/rules-engine.md) run your own commands
  on events like a desktop change. See the
  [CLI reference](configuration/cli.md).

For the full, grouped feature list see [Feature Set](features.md); for how Desk
Switcheroo stacks up against other tools per persona, see the
[Comparison](comparison.md).
