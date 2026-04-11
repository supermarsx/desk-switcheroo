# Power User Guide

Advanced configuration and hidden features for experienced users.

## INI File Reference

The main config file `desk_switcheroo.ini` is auto-created on first run. Edit it directly or use Settings (Ctrl+Alt+S). Changes via the config watcher are hot-reloaded if enabled.

### [General]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `language` | string | `en-US` | ISO locale code (e.g. `pt-PT`, `de-DE`) |
| `start_with_windows` | bool | `false` | Add to Windows startup registry |
| `start_minimized` | bool | `false` | Start with widget hidden |
| `wrap_navigation` | bool | `true` | Arrow past last desktop wraps to first |
| `auto_create_desktop` | bool | `false` | Right arrow on last desktop creates new |
| `number_padding` | int | `2` | Zero-pad desktop numbers (1-4) |
| `widget_position` | string | `bottom-left` | Screen anchor (9 positions) |
| `widget_offset_x` | int | `0` | Fine-tune X position (px) |
| `widget_offset_y` | int | `0` | Fine-tune Y position (px) |
| `widget_width` | int | `0` | Override width (0=auto, 130px) |
| `widget_height` | int | `0` | Override height (0=auto, taskbar) |
| `widget_drag_enabled` | bool | `false` | Allow dragging the widget |
| `widget_color_bar` | bool | `false` | Show color accent bar on widget |
| `widget_color_bar_height` | int | `2` | Color bar height in pixels (1-10) |
| `tray_icon_mode` | bool | `false` | Run as system tray icon |
| `quick_access_enabled` | bool | `false` | Double-click number to type desktop (1-9) |
| `list_keyboard_nav` | bool | `false` | Up/Down arrow keys in desktop list |
| `auto_update_enabled` | bool | `false` | Periodic GitHub release check |
| `auto_update_interval` | int | `168` | Hours between auto-checks |

### Widget Anchoring

The `widget_position` key supports 9 positions:

```
top-left      top-center      top-right
middle-left                   middle-right
bottom-left   bottom-center   bottom-right
```

Bottom positions track the taskbar Y. Others use absolute screen coordinates. Legacy values `left`/`center`/`right` auto-map to `bottom-*`.

### [Animations]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `animations_enabled` | bool | `true` | Master animation toggle |
| `fade_in_duration` | int | `80` | Fade-in total time (ms, 0-500) |
| `fade_out_duration` | int | `80` | Fade-out total time (ms, 0-500) |
| `fade_step` | int | `30` | Alpha increment per frame (5-255) |
| `fade_sleep_ms` | int | `8` | Sleep per frame (1-50ms) |
| `toast_fade_out_duration` | int | `300` | Toast fade-out (ms, 0-1000) |
| `anim_list` | bool | `true` | Animate desktop list |
| `anim_menus` | bool | `true` | Animate context menus |
| `anim_dialogs` | bool | `true` | Animate dialogs (settings, about, confirm) |
| `anim_toasts` | bool | `true` | Animate toast notifications |
| `anim_widget` | bool | `true` | Animate widget show/hide |

Set `animations_enabled=false` to disable all fades globally. Set `fade_step=255` for near-instant single-frame transitions.

### [Behavior]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `confirm_delete` | bool | `true` | Confirm before deleting a desktop |
| `middle_click_delete` | bool | `false` | Middle-click to delete from list |
| `move_window_enabled` | bool | `true` | Show "Move Window Here" in context menu |
| `peek_bounce_delay` | int | `500` | Ms before peek bounces back |
| `auto_hide_timeout` | int | `3000` | Ms before list auto-hides |
| `topmost_interval` | int | `300` | Ms between topmost enforcement |
| `cm_auto_hide_delay` | int | `500` | Ms before context menu hides |
| `config_watcher_enabled` | bool | `false` | Hot-reload INI on external changes |
| `config_watcher_interval` | int | `60000` | Ms between file change checks |
| `count_cache_ttl` | int | `1000` | Desktop count cache (ms) |
| `name_sync_interval` | int | `2000` | OS name sync polling (ms) |
| `dll_check_interval` | int | `30000` | DLL health check (ms) |
| `update_poll_interval` | int | `500` | Background download poll (ms) |
| `confirm_quit` | bool | `false` | Confirm before exiting |
| `debug_mode` | bool | `false` | Enable "Trigger Crash" in context menu |

### [DesktopColors]

Colors use `0xRRGGBB` format. `0x000000` means "no color" (transparent).

```ini
desktop_colors_enabled=true
desktop_1_color=0x4A9EFF
desktop_2_color=0x4AFF7E
desktop_3_color=0xFF7E4A
```

### [Logging]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `logging_enabled` | bool | `false` | Enable file logging |
| `log_folder` | string | `` | Folder for logs (empty=script dir). Supports `%APPDATA%`, `%TEMP%`, `%SCRIPTDIR%` |
| `log_level` | enum | `info` | `error`, `warn`, `info`, `debug` |
| `log_max_size_mb` | int | `5` | Max file size before rotation |
| `log_rotate_count` | int | `3` | Number of rotated files to keep |
| `log_compress_old` | bool | `false` | Zip rotated files (uses PowerShell) |
| `log_include_pid` | bool | `false` | Add `[PID:XXXX]` to each line |
| `log_date_format` | enum | `iso` | `iso` (YYYY-MM-DD), `us` (MM/DD), `eu` (DD/MM) |
| `log_flush_immediate` | bool | `true` | Flush after every write |

## Hidden Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+Alt+S | Open Settings |
| Ctrl+Alt+Left/Right | Switch desktop (if configured) |
| Triple-click on list item | Open rename dialog |
| Double-click widget number | Quick-access mode (type 1-9) |
| Escape | Cancel drag, close dialogs, cancel quick-access |
| Mouse wheel on widget | Cycle desktops (if enabled) |
| Mouse wheel on list | Scroll list or switch desktops |
| Mouse wheel on Settings | Scroll tab content |

## Desktop Reorder (Drag and Drop)

Drag a desktop in the list to reorder. This performs an adjacent-swap chain:
- Windows are moved between desktops via `MoveWindowToDesktopNumber`
- OS desktop names are swapped (Win11)
- INI labels are swapped
- Desktop colors are swapped

Uses Win32 `EnumWindows` directly (not AutoIt's `WinList` which is desktop-scoped on Win10/11).

## Crash Recovery

If the app crashes, a detailed crash log is written to `crash_YYYYMMDD_HHMMSS.log` in the script directory (falls back to `%TEMP%` if unwritable). The crash dialog offers Copy Report, Open Log, Restart, and Close.

## State Persistence

`desk_switcheroo_state.ini` saves scroll offset on shutdown and restores it on next launch.

## Adding Translations

See [Development Guide](DEVELOPMENT.md#adding-a-locale) for the full process. Quick version:

1. Copy `locales/en-US.ini` → `locales/xx-XX.ini`
2. Edit `[Meta]` section
3. Translate all values
4. Run `pwsh scripts/locale-check.ps1`
5. Restart the app — new language appears in Settings

## Example Configs

The `examples/` folder contains ready-to-use configurations:

- **`desk_switcheroo.prod.ini`** — Conservative defaults. Logging off, updates off, no hotkeys. Copy to your script directory and rename to `desk_switcheroo.ini`.

- **`desk_switcheroo.debug.ini`** — Everything enabled. Debug mode, verbose logging, all hotkeys configured, colors on all desktops. Useful for development and testing.
