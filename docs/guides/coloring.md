---
title: Coloring & Theming
nav_order: 1
parent: Guides
---

# Coloring & Theming

Desk Switcheroo's appearance is controlled by three independent systems: a global
**theme** that recolors every window the app draws, optional **per-desktop accent colors**
that tag individual desktops, and optional **per-desktop wallpapers** that Windows swaps
when you switch. This guide explains what each does and where its settings live. For the
exact key names, types, and defaults, see the
[Advanced INI Reference](../configuration/ini-reference.md).

## Themes

The overall color scheme is set by the `theme` key in the `[Display]` section. Five schemes
ship with the app (defined in `includes/Theme.au3`):

| Theme | Character | Window background |
|---|---|---|
| `dark` | The default. Neutral near-black grays. | `0x191919` |
| `darker` | A deeper, higher-contrast variant of dark. | `0x0F0F0F` |
| `midnight` | Dark with a cool blue tint. | `0x141824` |
| `midday` | A light theme — dark text on light gray. | `0xD8D8D8` |
| `sunset` | Dark with a warm purple tint. | `0x2D1B2E` |

Each scheme is a full ten-color palette (four background tones and six foreground/text
tones), so switching the theme recolors the widget, the desktop list, context menus, and the
Settings dialog together. The values above are the base window background of each scheme;
the rest of the palette is listed in `Theme.au3` (`$__g_Theme_aSchemeDark` and its siblings).

![The Settings dialog Display tab, with controls for theme, opacity, and list appearance.](../assets/screenshots/settings-display.png)

*The Display tab sets the theme, opacity, and list appearance. A theme change takes effect on the next launch.*

Set the theme in **Settings** on the Display tab, or write `theme = midnight` under
`[Display]` in `desk_switcheroo.ini`. The scheme is applied once at startup, before any
window is created (`_Theme_ApplyScheme`), so a theme change takes effect on the next launch
rather than live.

## Window opacity

The widget and popups are drawn as translucent windows. The main opacity is set by
`theme_alpha_main` in `[Display]` (range 50–255, default 235, where 255 is fully opaque).
Popups, menus, and dialogs use their own fixed alpha values defined in `Theme.au3`
(`$THEME_ALPHA_POPUP`, `$THEME_ALPHA_MENU`, `$THEME_ALPHA_DIALOG`). The on-screen desktop
notification has a separate `osd_opacity` key in `[Notifications]` (range 0–255,
default 220).

## Per-desktop accent colors

You can assign each desktop its own accent color. This is off by default; enable it with
`desktop_colors_enabled` in the `[DesktopColors]` section (or the corresponding checkbox in
Settings). Colors are stored per desktop as `desktop_N_color` keys:

```ini
[DesktopColors]
desktop_colors_enabled=true
desktop_1_color=0x4A9EFF
desktop_2_color=0x4AFF7E
```

Each value is a `0xRRGGBB` color. A value of `0x000000` (or a missing key) means **no
color** for that desktop. Accent colors are tracked for desktops 1–9.

### Setting a color

Right-click a desktop in the desktop list and choose **Set Color** to open the color picker
(`_DL_ColorPickerShow` in `includes/DesktopList.au3`). The picker offers:

- **None** — clears the accent color.
- **Seven named presets** — Blue, Green, Orange, Yellow, Purple, Pink, and Teal (the preset
  values live in `$THEME_PRESET_COLORS` in `Theme.au3`).
- **Custom...** — enter any hex color of your own.

![The color picker popup listing None, seven named color presets (Blue, Green, Orange, Yellow, Purple, Pink, Teal) with colored dots, and Custom.](../assets/screenshots/color-picker.png)

*The color picker: choose None, one of seven presets, or a custom hex color.*

### Where accent colors appear

When accent colors are enabled, a desktop's color shows up in two places:

- **Desktop list rows** — a small color bar is drawn at the right edge of each colored
  desktop's row in the list panel (`_DL_Render` in `DesktopList.au3`).
- **Widget color bar** — an optional strip along the bottom edge of the widget that reflects
  the *current* desktop's color. This is a separate opt-in: set `widget_color_bar` to `true`
  in `[General]`, and size it with `widget_color_bar_height` (range 1–10 pixels, default 2).
  The bar is repainted on every desktop change by `_UpdateWidgetColorBar` in
  `desktop_switcher.au3`; if the current desktop has no color, or either the color bar or
  accent colors are disabled, the strip falls back to the theme background.
  The transition is set by `widget_color_bar_anim`: `grow` (the default) animates both
  entry and exit — it compresses the outgoing color out (width shrinks to zero) and then
  grows the incoming color in, so leaving a colored desktop is animated as well as arriving
  at one; `fade` crossfades the background color in a single step; and `none` snaps
  instantly. The total motion time is set by `widget_color_bar_anim_duration`, split evenly
  between the compress and grow phases.

![The Settings dialog Desktops tab showing a table of desktop labels and their hex accent colors with color swatches.](../assets/screenshots/settings-desktops.png)

*The Desktops tab in Settings: per-desktop labels, accent colors, and optional wallpapers in one table.*

## Per-desktop wallpapers

Independently of accent colors, Desk Switcheroo can change the Windows desktop wallpaper when
you switch desktops. This is handled by `includes/Wallpaper.au3` and is off by default.
Enable it with `wallpaper_enabled` in the `[Wallpaper]` section, then set a per-desktop image
path with `desktop_N_wallpaper`:

```ini
[Wallpaper]
wallpaper_enabled=true
wallpaper_change_delay=200
desktop_1_wallpaper=C:\Users\You\Pictures\desk1.jpg
desktop_2_wallpaper=C:\Users\You\Pictures\desk2.jpg
```

When the active desktop changes, the app starts a short debounce timer
(`wallpaper_change_delay`, range 50–2000 ms, default 200) and then applies that desktop's
wallpaper via `SystemParametersInfoW` (`_WP_Apply`). The debounce means that flicking quickly
through several desktops only applies the wallpaper of the one you land on, rather than every
desktop you pass through. A desktop with no configured path keeps whatever wallpaper is
already showing.

Wallpaper paths are validated for safety: the app rejects paths containing `..` and UNC
paths (`\\...`), and silently skips any file that does not exist, logging a warning instead
(`Config.au3` `__Cfg_ValidateWallpaperPath` and `Wallpaper.au3` `_WP_Apply`).

## Fonts

The app draws with a small set of fonts, defined in `Theme.au3`:

- The **desktop number** on the widget uses the monospace **Fira Code** font
  (`$THEME_FONT_MONO`), falling back to **Consolas** if Fira Code is not installed. Fira Code
  ships with the installer and portable builds. Its size is `count_font_size` in `[Display]`
  (range 4–20, default 7).
- **General UI text** uses **Segoe UI** (`$THEME_FONT_MAIN`).
- The **desktop list** can use a custom font: set `list_font_name` in `[Display]` (empty means
  the default UI font) and `list_font_size` (range 6–14, default 8).
- **Tooltips** use `tooltip_font_size` in `[Display]` (range 6–12, default 8).
- The **on-screen desktop notification** uses `osd_font_size` in `[Notifications]`
  (range 8–48, default 14).

## Related pages

- [Advanced INI Reference](../configuration/ini-reference.md) — the full `[Display]`,
  `[DesktopColors]`, `[Wallpaper]`, and `[General]` key tables.
- [Desktop Management](desktop-management.md) — the desktop list panel where accent colors
  are set and shown.
- [Configuration overview](../configuration/index.md) — how the Settings dialog and INI file
  relate.
