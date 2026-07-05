---
title: Feature Set
nav_order: 4
---

# Feature Set

This page is the complete tour of what Desk Switcheroo does. It expands the short list in
the project README into a paragraph per capability, grouped by area, and names the module in
the source that implements each one so the descriptions can be checked against the code. Each
group links to the guide or reference page that covers it in depth.

For a side-by-side against other virtual-desktop tools, see
[Comparison with Other Tools](comparison.md). For the underlying mechanism, see
[How It Works](how-it-works.md).

## Widget

The core of Desk Switcheroo is a compact, always-on-top overlay that sits on your taskbar
(built in `desktop_switcher.au3`). It shows the current desktop number, the desktop's custom
label, and left/right arrows for switching. It is a plain layered window — not a shell
extension and not an Explorer injection.

![The widget showing desktop 1 "Main" with navigation arrows and a blue accent bar.](assets/screenshots/widget.png)

*The widget: desktop number, label, arrows, and an optional per-desktop accent bar.*

- **Screen anchoring with pixel offsets.** The widget can be pinned to any of nine screen
  positions (corners, edge-centers, and center) with additional X/Y pixel offsets for
  fine-tuning (`widget_position`, `widget_offset_x`, `widget_offset_y`).
- **Draggable repositioning.** When enabled (`widget_drag_enabled`, off by default), you can
  drag the widget freely and its position is remembered.
- **Custom dimensions.** The widget width and height can be overridden from their computed
  defaults (`_Cfg_GetWidgetWidth`/`_Cfg_GetWidgetHeight`).
- **Color bar accent.** An accent bar matches the current desktop's color
  (`widget_color_bar`, `widget_color_bar_height`) — see [Coloring &
  Theming](guides/coloring.md). Its transition on a desktop change is configurable
  (`widget_color_bar_anim`: `none`/`grow`/`fade`, `widget_color_bar_anim_duration`).
- **Desktop count display.** An optional "2/5"-style counter shows the current desktop and the
  total, with a configurable font size.
- **Always-on-top enforcement.** A periodic re-assert keeps the widget above other windows
  even when another topmost window tries to bury it, at a configurable interval
  (`_Cfg_GetTopmostInterval`).

## Desktop management

Clicking the widget number opens the desktop list panel (`includes/DesktopList.au3`), the
primary surface for managing desktops. The full walkthrough is in [Desktop
Management](guides/desktop-management.md).

![The desktop list panel listing desktops 1–10, the first six labeled Main, Code, Chat, Media, Notes, Test with colored accent bars.](assets/screenshots/desktop-list.png)

*The desktop list: click a row to switch, right-click for per-desktop actions, drag to reorder.*

- **Desktop list panel** with click-to-switch, drag-to-reorder (adjacent-swap of windows,
  names, labels, and colors), pin/unpin the panel open, and auto-hide on mouse-away
  (`_DL_HandleClick`, `_DL_DragPerformReorder`, `_DL_CheckAutoHide`).
- **Desktop peek** — hover the eye icon to temporarily preview another desktop; it bounces
  back when you leave (`includes/Peek.au3`).
- **Thumbnail previews** on hover, with an optional live screenshot capture
  (`_DL_ThumbShow`, `thumbnails_enabled`, `thumbnail_use_screenshot`).
- **Custom desktop labels** with Windows 11 OS desktop-name sync; on Windows 10 it falls back
  to the INI-stored labels (`includes/Labels.au3`).
- **Per-desktop accent colors** — seven presets plus a custom hex picker; `0x000000` means "no
  color" (`_DL_ColorPickerShow`). See [Coloring & Theming](guides/coloring.md).
- **Add, delete, and reorder desktops** from the list context menu (`_DL_CtxShow`), including
  confirm-before-delete.
- **Move the active window** to any desktop from the widget or list menus
  (`_DL_MoveMenuShow`), including an optional single-click **Move Here** that sends it straight to
  a desktop from the list's context menu (`move_here_click_enabled`, off by default).
- **Wrap navigation and auto-create.** Navigation can wrap around at the ends, and moving past
  the last desktop can auto-create a new one (`wrap_navigation`, `auto_create_desktop`).

### Window list

The window list is a separate panel (`includes/WindowList.au3`) that shows the windows on the
current desktop — or across all desktops when scope is set to `all` — and lets you act on them
individually or in bulk.

- **Per-window actions**: send to another desktop, pull to the current desktop, go to the
  window's desktop, pin/unpin the window (or its whole app), minimize/maximize/restore, and
  close (`_WL_SendToShow`, `_WL_CtxShow`).
- **Per-window Always on Top** toggle — flips `WS_EX_TOPMOST` and honestly
  reports failure on elevated windows a non-elevated process cannot touch
  (`_WL_ToggleAlwaysOnTop`).
- **Bulk title-bar actions**: **Minimize All**, **Maximize All**, and
  **Close All** windows on the panel's desktop; Close All is graceful (`WM_CLOSE`, never a
  process kill) so apps can still prompt to save (`_WL_MinimizeAll`, `_WL_MaximizeAll`,
  `_WL_CloseAll`).
- **Search box** to filter the list by window title as you type (`_WL_SearchFilter`).
- **All-desktops scope** that lists every window with a `[Dn]` desktop tag
  (`window_list_scope = all`).

## Input & shortcuts

Desk Switcheroo is designed to be driven from the keyboard and mouse wheel as much as from the
widget. Hotkey defaults and bindings are covered in [Desktop
Management](guides/desktop-management.md) and the [Advanced INI
Reference](configuration/ini-reference.md).

- **Global hotkeys** for next / previous / toggle-list / toggle-last plus direct jump to
  desktops 1–9 (`hotkey_next`, `hotkey_prev`, `hotkey_desktop_1..9`, and more).
- **Hotkey chord builder** — every row on the Hotkeys tab has a `…` capture button that records a
  full key combination (**Esc** cancels, 10-second timeout), with global hotkeys suspended while it
  is open so recording a chord never fires the action bound to it.
- **Scroll-wheel navigation** on the widget and list, in normal or inverted direction, with
  optional wrap (`scroll_direction`).
- **Quick-access number input** — double-click the widget to type a desktop number and jump
  to it (`quick_access_enabled`).
- **Triple-click to rename** a desktop label inline (`includes/RenameDialog.au3`).
- **Middle-click to delete** a desktop from the list (`middle_click_delete`).
- **Keyboard navigation** (Up/Down) within the desktop list.

## Appearance

The look is fully themeable; the details and palette values are in [Coloring &
Theming](guides/coloring.md).

- **Five dark themes** — `dark`, `darker`, `midnight`, `midday`, and `sunset`
  (`includes/Theme.au3`).
- **Configurable fade animations** per surface — list, menus, dialogs, toasts, and the widget
  can each fade in/out at their own duration (`_Theme_FadeIn`/`_Theme_FadeOut`).
- **Custom fonts and opacity** — separate list font, tooltip font, and widget opacity.
- **Per-desktop wallpaper** — a background image that changes with the active desktop
  (`includes/Wallpaper.au3`, `wallpaper_enabled`).
- **On-screen display (OSD)** — a large transient overlay announcing the desktop on switch,
  with configurable name/number, position, duration, opacity, and format
  (`osd_enabled` and related keys).
- **Toast notifications** for events such as window moved, desktop created/deleted, window
  pinned, and Explorer recovery, with configurable position and fade (`notifications_enabled`).
- **Scrollable lists** with a configurable maximum number of visible items.

## Persistence & profiles

State survives restarts and can be moved between machines. The file-by-file breakdown is in
[Persistence & Profiles](guides/persistence.md).

- **Session restore** — captures the window-to-desktop layout and restores it on next launch,
  matching windows by process/class and excluding system processes
  (`includes/SessionRestore.au3`, `session_restore_enabled`).
- **Settings profiles** — save, load, and delete named configuration profiles, with sanitized
  profile names (`includes/Profiles.au3`); also driveable from the CLI.
- **Persisted labels, colors, and state** across `desk_switcheroo.ini`,
  `desktop_labels.ini`, and `desk_switcheroo_state.ini`.

## Rules & hooks

Automation lives in two engines, both covered in [Rules Engine &
Hooks](guides/rules-engine.md).

- **Window rules engine** — INI rules of the form `rule_N = pattern|target_desktop` that
  auto-move matching windows to a designated desktop; matching is by process name (or window
  class with a `class:` prefix), driven by a polling engine with stale-window cleanup
  (`includes/WindowRules.au3`).
- **Event hooks** — run external commands on desktop events (change, create, delete, and
  more), with variable substitution, asynchronous execution, PID tracking, and timeout kill
  (`includes/Hooks.au3`). Hooks run arbitrary commands with your privileges.

## CLI & IPC

Desk Switcheroo can be scripted from the command line; the full command list is in [CLI
Parameters](configuration/cli.md).

- **Query commands** that work without a running instance — `help`, `version`,
  `list-desktops`, `get-current`, `status` (`includes/CLI.au3`).
- **Action commands** relayed to a running instance over a `WM_COPYDATA` IPC channel — `goto`,
  `next`, `prev`, `add-desktop`, `remove-desktop`, `rename`, `move-window`, `toggle-list`,
  `toggle-slideshow`, `load-profile`, `save-profile`.
- **Flexible prefixes** — `--`, `-`, and `/` are all accepted, with a legacy `-autostart`
  passthrough.

## System

Everything that keeps the app running cleanly and out of your way. Reliability details are in
[Stability & Mitigations](reference/stability.md); logging has its own page,
[Logging & Diagnostics](guides/logging.md).

- **Start with Windows** and **start minimized** options.
- **System tray mode** — run as a tray icon instead of the taskbar widget, with configurable
  double-click and middle-click actions.
- **Slideshow mode** — auto-advance through desktops on a timer, for dashboards or a rotating
  display (`_SlideshowTick`, `includes/Slideshow.au3`, `slideshow_enabled`, `slideshow_interval`).
  Choose which desktops participate (all/even/odd/name-filter/custom sequence), the direction,
  per-desktop dwell times, loop mode (infinite/count/duration), autostart, and the conditions
  that break it. Supersedes the former carousel.
- **Singleton enforcement** — relaunching kills the previous instance so only one runs
  (`singleton_enabled`).
- **Config file watcher** — reloads settings automatically when the INI changes on disk
  (`config_watcher_enabled`).
- **Explorer crash monitor** — detects an Explorer/shell crash and recovers the widget
  (`includes/ExplorerMonitor.au3`).
- **Taskbar auto-hide sync** — hides and shows the widget in step with an auto-hiding taskbar
  (`includes/TaskbarAutoHide.au3`).
- **Auto-update checker** — checks GitHub Releases and can download the portable build
  (`includes/UpdateChecker.au3`).
- **Debug logging** — level filtering, size-based rotation, detached compression of rotated
  logs, and optional PID/function tagging (`includes/Logger.au3`); see [Logging &
  Diagnostics](guides/logging.md).
- **Confirmation safeguards** — confirm-before-quit and confirm-before-delete.
- **Localization** — 34 bundled locales with automatic language detection and an in-app
  picker.
- **Settings dialog** — a searchable settings window (Ctrl+Alt+S) organized into tabs; see
  [Configuration](configuration/index.md) and the [Advanced INI
  Reference](configuration/ini-reference.md).

## Capability summary

| Area | Capability | Notes |
|---|---|---|
| Widget | Taskbar overlay: number, label, arrows | `desktop_switcher.au3` |
| Widget | 9-position anchoring + pixel offsets | `widget_position`, `widget_offset_x/y` |
| Widget | Draggable repositioning | `widget_drag_enabled` (off by default) |
| Widget | Custom width/height | Overrides computed size |
| Widget | Color bar accent | Matches current desktop color |
| Widget | Desktop count "2/5" | Configurable font |
| Widget | Always-on-top enforcement | Periodic re-assert, configurable interval |
| Desktop mgmt | Desktop list panel | Click-switch, drag-reorder, pin, auto-hide |
| Desktop mgmt | Desktop peek | `Peek.au3`, bounce-back |
| Desktop mgmt | Thumbnail previews | Optional screenshot capture |
| Desktop mgmt | Custom labels + Win11 name sync | INI fallback on Windows 10 |
| Desktop mgmt | Per-desktop accent colors | 7 presets + custom hex picker |
| Desktop mgmt | Add / delete / reorder desktops | From list context menu |
| Desktop mgmt | Move active window to any desktop | Widget/list menus |
| Desktop mgmt | Optional click-to-move (Move Here) | `move_here_click_enabled`, off by default |
| Desktop mgmt | Wrap navigation + auto-create | `wrap_navigation`, `auto_create_desktop` |
| Window list | Send-to-desktop / pull / go-to | `WindowList.au3` |
| Window list | Per-window minimize/maximize/restore/close/pin | Per-window context menu |
| Window list | Per-window Always on Top | `_WL_ToggleAlwaysOnTop` |
| Window list | Minimize All / Maximize All / Close All | Title-bar menu, graceful close |
| Window list | Title search + all-desktops scope | `_WL_SearchFilter`, `window_list_scope` |
| Input | Global hotkeys (next/prev/toggle + 1–9) | `hotkey_*` keys |
| Input | Hotkey chord builder on every row | `…` capture, Esc / 10 s timeout |
| Input | Scroll-wheel navigation | Normal/inverted, wrap |
| Input | Quick-access number input | Double-click widget |
| Input | Triple-click rename, middle-click delete | `RenameDialog.au3`, `middle_click_delete` |
| Input | Keyboard nav in list | Up/Down |
| Appearance | 5 dark themes | dark, darker, midnight, midday, sunset |
| Appearance | Per-surface fade animations | List, menus, dialogs, toasts, widget |
| Appearance | Custom fonts + opacity | List, tooltip, widget |
| Appearance | Per-desktop wallpaper | `Wallpaper.au3` |
| Appearance | OSD overlay on switch | `osd_*` keys |
| Appearance | Toast notifications | Per-event toggles |
| Persistence | Session restore | Window→desktop layout, process/class match |
| Persistence | Settings profiles | Save/load/delete, CLI-driveable |
| Rules & hooks | Window rules engine | `rule_N = pattern\|target`, polling |
| Rules & hooks | Event hooks | Async, PID tracking, timeout kill |
| CLI & IPC | Query + action commands | `WM_COPYDATA` IPC to running instance |
| System | Start with Windows / start minimized | Autostart options |
| System | System tray mode | Configurable click actions |
| System | Slideshow mode | Timed auto-advance with selection modes, loops, and break conditions |
| System | Singleton enforcement | Relaunch kills previous |
| System | Config file watcher | Hot-reload on external INI change |
| System | Explorer crash recovery | `ExplorerMonitor.au3` |
| System | Taskbar auto-hide sync | `TaskbarAutoHide.au3` |
| System | Auto-update checker | Portable download from GitHub Releases |
| System | Debug logging | Levels, rotation, compression, PID/function tags |
| System | Confirmation safeguards | Confirm-before-quit / -delete |
| System | Localization | 34 locales, auto-detect + picker |
