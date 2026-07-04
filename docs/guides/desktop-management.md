---
title: Desktop Management
nav_order: 2
parent: Guides
---

# Desktop Management

This guide covers everything Desk Switcheroo does with virtual desktops themselves: switching
between them, opening the desktop list, adding, deleting, reordering, renaming, and peeking at
desktops, moving windows between them, and the window list panel. For the appearance of
desktops (colors, wallpapers) see [Coloring & Theming](coloring.md); for what gets saved
across restarts see [Persistence & Profiles](persistence.md).

Almost everything here is optional and configurable — the exact keys, defaults, and ranges
live in the [Advanced INI Reference](../configuration/ini-reference.md), and this guide names
the INI key for each behavior so you can find it there.

## The widget

The widget is the small always-on-top overlay docked to your taskbar. It has three
interactive parts (`desktop_switcher.au3`):

- **Left / right arrows** — switch to the previous or next desktop. The next arrow respects
  the auto-create and wrap options described below.
- **Desktop number** — a single click opens (or closes) the desktop list panel. If the panel
  is pinned, the number does nothing because the panel stays open. If quick access is enabled,
  a double click on the number opens the quick-access input instead (see
  [Quick access](#quick-access)).

![The widget showing desktop 1 "Main" with left and right navigation arrows and an accent color bar.](../assets/screenshots/widget.png)

*The three interactive parts of the widget: left arrow, desktop number/label, and right arrow.*

## The desktop list panel

The desktop list is the popup panel that shows all your desktops (`includes/DesktopList.au3`).
Open it by clicking the widget number or with the toggle-list hotkey (`hotkey_toggle_list`,
default `Ctrl+Alt+Down`).

![The desktop list panel listing desktops 1–10, the first six labeled Main, Code, Chat, Media, Notes, Test with colored accent bars at the right edge.](../assets/screenshots/desktop-list.png)

*The desktop list panel: each row shows the number, label, and (when enabled) the desktop's accent color.*

- **Click to switch** — click any row to switch to that desktop.
- **Scrolling** — when you have more desktops than fit, enable a scrollable list with
  `list_scrollable` in `[Display]`; `list_max_visible` (range 3–30, default 10) caps how many
  rows show at once, and scroll arrows appear at the top and bottom.
- **Auto-hide** — by default the panel closes shortly after the cursor leaves it
  (`_DL_CheckAutoHide`).
- **Pinning** — pin the panel open so it stays visible (`desktop_list_pinned` in `[General]`,
  or the "Keep list open" action on the widget's context menu). While pinned, clicking the
  widget number no longer toggles it.
- **Keyboard navigation** — with `list_keyboard_nav` enabled in `[General]`, you can move
  through the list and switch with the keyboard while it is open.

Right-clicking a desktop row opens a context menu (`_DL_CtxShow`) anchored at the cursor with
these items: **Switch**, **Rename**, **Peek**, **Set Color** (when per-desktop colors are
enabled), **Move Here** (when move-window is enabled), **Pin to All Desktops** (when pinning
is enabled), **Add Desktop**, and — below a separator — **Delete** (shown in red as a
destructive action).

![The desktop right-click context menu with items Rename Desktop, Set Color, Pin Desktop List, Pull All Windows Here, Window List, Add Desktop, Delete Desktop (red), About, Settings, and Quit.](../assets/screenshots/desktop-context-menu.png)

*The context menu anchored at the cursor. Destructive actions like Delete Desktop are drawn in red.*

## Adding and deleting desktops

- **Add** — from the list context menu's "Add Desktop", the widget context menu, the
  add-desktop hotkey (`hotkey_add_desktop`, default `Ctrl+Alt+Insert`), or the CLI
  (`add-desktop`).
- **Delete** — from the list context menu's "Delete", the delete-desktop hotkey
  (`hotkey_delete_desktop`, unbound by default), or, if enabled, a **middle-click** on a
  desktop row (`middle_click_delete` in `[Behavior]`, off by default). By default a
  confirmation dialog appears first; set `confirm_delete` to `false` in `[Behavior]` to delete
  without confirmation.
- **Count limits** — `min_desktops` and `max_desktops` in `[General]` (each 0–50, 0 means no
  limit) bound how few or how many desktops the app will let you have.

When a desktop is deleted, the labels of the desktops after it shift down to stay aligned with
their desktops (`_Labels_RemoveAndShift` in `includes/Labels.au3`), using a snapshot taken
before the removal so the labels do not double-shift.

## Reordering desktops (drag)

You can drag a desktop to a new position in the list to reorder it. Because Windows has no API
to move a desktop directly, Desk Switcheroo reorders by an **adjacent-swap chain**: to move a
desktop from position A to position B, it repeatedly swaps neighboring desktops until it
arrives (`_DL_DragPerformReorder` in `DesktopList.au3`). Each swap (`_VD_SwapDesktops` in
`includes/VirtualDesktop.au3`) moves the windows of the two desktops, and swaps their OS names
and accent colors; the app keeps its own stored labels in lockstep with `_Labels_Swap`.

Swapping the windows of a desktop requires enumerating windows that live on *other* desktops,
which AutoIt's built-in `WinList()` cannot do — it only sees windows on the current desktop.
Desk Switcheroo therefore calls the Win32 `EnumWindows` API directly
(`_VD_EnumWindowsAllDesktops`) to get every top-level window system-wide, then tags each with
its desktop number. This bypass is why reorder (and the window list, session restore, and
gather) can see and move windows across desktops.

## Renaming desktops and labels

Rename a desktop through the list context menu's **Rename**, the widget context menu, or the
rename hotkey (`hotkey_rename_desktop`, default `Ctrl+Alt+R`), which opens the rename dialog
(`includes/RenameDialog.au3`). Labels are stored in `desktop_labels.ini`, and on Windows 11
they are kept in sync with the OS desktop names (so a rename shows up in Task View, and a
Task View rename flows back). The sync poll interval is `name_sync_interval` in `[Behavior]`
(range 500–60000 ms, default 2000). Where labels are stored and how the sync behaves is
covered in [Persistence & Profiles](persistence.md#desktop-labels).

![The rename dialog titled "Label for Desktop 2" with an input field containing "Code" and OK / Cancel buttons.](../assets/screenshots/rename-dialog.png)

*The rename dialog, pre-filled with the desktop's current label.*

## Peeking at a desktop

Peek lets you glance at another desktop and automatically bounce back
(`includes/Peek.au3`). Starting a peek (for example from the list context menu's "Peek")
switches to the target desktop and remembers where you came from; when you leave the peek
zone, a short debounce timer fires and snaps you back to the original desktop
(`_Peek_StartBounceBack` / `_Peek_CheckBounce`). If you decide to stay, the peek can be
committed so the peeked desktop becomes the new active one (`_Peek_Commit`).

## Moving windows between desktops

When `move_window_enabled` is on in `[Behavior]` (the default), Desk Switcheroo can move the
active or a chosen window to another desktop:

- **Move hotkeys** — `hotkey_move_next` / `hotkey_move_prev` move the active window to the
  adjacent desktop and stay put; `hotkey_move_follow_next` / `hotkey_move_follow_prev`
  (defaults `Ctrl+Alt+Shift+Right` / `Left`) move it *and* follow it there.
  `hotkey_send_new_desktop` (default `Ctrl+Alt+N`) creates a new desktop and sends the active
  window to it.
- **Move Here** — from a desktop row's context menu, when move-window is enabled.
- **CLI** — `move-window N` (see [CLI Parameters](../configuration/cli.md)).

All window moves go through `_VD_MoveWindowToDesktop` in `VirtualDesktop.au3`.

![A small toast notification with a green status dot reading "Moved window to Desktop 3 - Chat".](../assets/screenshots/toast.png)

*Optional toast notifications confirm actions like moving a window (toggle them on the Notifications tab).*

![The Settings dialog Notifications tab, with per-event toggles and on-screen display options.](../assets/screenshots/settings-notifications.png)

*The Notifications tab controls which events raise a toast, plus the on-screen display settings.*

## The window list panel

The window list is a separate panel that shows the windows on the current desktop
(`includes/WindowList.au3`). Toggle it with `hotkey_toggle_window_list` (default
`Ctrl+Alt+W`). It supports drag-to-reposition, a configurable position that persists, and its
own scroll and search.

![The window list panel titled "Windows on Desktop 2" listing five windows: Roadmap.md, team-standup, localhost:3000, build.log, and Inbox.](../assets/screenshots/window-list.png)

*The window list shows the windows on the current desktop, with an optional search box.*

### Per-window actions

Right-click a window row for a cursor-anchored menu (`_WL_CtxShow`) whose items adapt to the
window's state:

- **Send to Desktop** — a submenu that moves the window to a chosen desktop (or to a new one).
- **Go to / Pull here** — when the window is on a different desktop, jump to it or pull it to
  the current desktop.
- **Minimize / Maximize / Restore** — whichever apply to the window's current state.
- **Always on Top** — toggles the window's topmost state via `SetWindowPos`
  (`_WL_ToggleAlwaysOnTop`). This is best-effort and does **not** require administrator
  rights: from a normal-privilege process, Windows silently ignores the change on elevated
  (higher-integrity) windows, so the app verifies the style actually changed before reporting
  success (`__WL_ClassifyTopmostResult`).
- **Pin window / Pin app** — when pinning is enabled, pin the window (or all of the app's
  windows) to all desktops.
- **Close** — closes the window gracefully.

![The per-window right-click menu with items Send to Desktop, Minimize, Maximize, Always on Top, and Close (red).](../assets/screenshots/window-list-row-menu.png)

*Right-clicking a window row opens actions that adapt to that window's current state.*

### Title-bar menu (whole-desktop actions)

Right-clicking the window list's title bar opens a second menu (`_WL_TitleCtxShow`) with
actions that apply to every window on the panel's desktop:

- **Pin / Unpin** the window list panel, **Refresh** it, and **Close** the panel.
- **Send All** to the next, previous, or a new desktop (`_WL_SendAllToDesktop`).
- **Minimize All**, **Maximize All**, and **Close All** (`_WL_MinimizeAll`,
  `_WL_MaximizeAll`, `_WL_CloseAll`). Close All is shown in red and asks for confirmation
  first; it closes windows gracefully (`WinClose`, never a forced process kill) so apps can
  still prompt to save unsaved work.

![The window list title-bar menu with Pin, Refresh, Send All to Desktop, Minimize All, Maximize All, Close All (red), and Close.](../assets/screenshots/window-list-title-menu.png)

*The title-bar menu applies whole-desktop actions. Close All is red and confirms before closing anything.*

## Keyboard shortcuts and mouse-wheel navigation

- **Switch hotkeys** — `hotkey_next` (default `Ctrl+Alt+Right`) and `hotkey_prev` (default
  `Ctrl+Alt+Left`) move between desktops; `hotkey_toggle_last` (default `Ctrl+Alt+Tab`) jumps
  back to the previously active desktop.
- **Jump-to hotkeys** — `hotkey_desktop_1` through `hotkey_desktop_9` (unbound by default) go
  straight to a numbered desktop.

![The Settings dialog Hotkeys tab, listing rebindable hotkey rows grouped into sub-tabs.](../assets/screenshots/settings-hotkeys.png)

*Every hotkey is rebindable on the Hotkeys tab in Settings; unbound actions are still available via the CLI and menus.*
- **Mouse wheel** — with `scroll_enabled` in the `[Scroll]` section, scrolling the wheel over
  the widget switches desktops. `scroll_direction` (`normal` or `inverted`) flips the
  direction, and `scroll_wrap` (default on) controls whether scrolling past the last desktop
  wraps to the first. A separate `list_scroll_action` (`switch` or `scroll`) sets what the
  wheel does over the desktop list panel.

Desk Switcheroo exposes many more optional hotkeys (rename, add/delete desktop, open settings,
task view, toggle carousel, load profiles, and more); the full list with defaults is in the
[Advanced INI Reference](../configuration/ini-reference.md).

## Quick access

With `quick_access_enabled` in `[General]`, double-clicking the widget number opens a
quick-access input (`_QuickAccess_Show` in `desktop_switcher.au3`) where you type a desktop
number to jump straight to it — useful when you have many desktops and do not want to open the
full list.

## Carousel mode

Carousel mode cycles automatically through your desktops on a timer (`[Carousel]` section).
Enable it with `carousel_enabled` and set the dwell time with `carousel_interval` (range
3000–300000 ms, default 20000). It can be toggled from the tray/context menu (when
`carousel_show_in_menu` is on) or a hotkey (`hotkey_toggle_carousel`), and shows a toast when
toggled unless `notify_carousel_toggle` is off.

## Navigation options

Two `[General]` options change how switching behaves at the ends of your desktop range:

- **`wrap_navigation`** (default on) — moving past the last desktop wraps to the first, and
  vice versa (`_Nav_NextTarget` / `_Nav_PrevTarget`).
- **`auto_create_desktop`** (default off) — pressing "next" while on the last desktop creates
  a new desktop and switches to it instead of wrapping or stopping.

## Related pages

- [Coloring & Theming](coloring.md) — per-desktop accent colors and wallpapers.
- [Persistence & Profiles](persistence.md) — how labels, session, and profiles are saved.
- [Rules Engine & Hooks](rules-engine.md) — automatically moving windows to desktops by rule.
- [CLI Parameters](../configuration/cli.md) — driving desktop management from scripts.
- [Advanced INI Reference](../configuration/ini-reference.md) — every key named on this page.
