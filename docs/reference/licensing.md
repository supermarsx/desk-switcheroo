---
title: Licensing
nav_order: 7
parent: Reference
---

# Licensing

Desk Switcheroo is released under the **MIT License**. This page reproduces the
license, summarizes it in plain language, and lists the third-party components
bundled with releases.

## The license

The authoritative text is the [`license.md`](https://github.com/supermarsx/desk-switcheroo/blob/main/license.md)
file in the repository root. It reads, in full:

```
MIT License

Copyright (c) 2026 Mariana

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## What this means in plain language

> This is an informal summary to help you understand the license quickly. It is
> **not legal advice** and it does **not** replace the license text above. Where
> the summary and the license disagree, the license text controls.

Under the MIT License you may:

- **Use** Desk Switcheroo for anything, including commercially, with no fee.
- **Modify** the source and build your own version.
- **Redistribute** it — original or modified — and even **sublicense or sell**
  copies.

The one obligation is:

- **Keep the copyright notice and the license text** in copies or substantial
  portions of the software when you redistribute it.

And the key disclaimer:

- The software is provided **"as is," with no warranty**, and the author is
  **not liable** for damages arising from its use.

## Third-party components

Releases bundle a small number of third-party components. The CI `release` job
(`.github/workflows/ci.yml`) packages `VirtualDesktopAccessor.dll` and the Fira
Code font files into the Portable and Source archives, and the NSIS installer
installs the DLL (always) and the Fira Code fonts (as a selectable component).
Each component keeps its own license, distinct from Desk Switcheroo's MIT
license.

| Component | Author | License | Bundled as |
|---|---|---|---|
| VirtualDesktopAccessor.dll | Jari Pennanen (Ciantic) | MIT | `VirtualDesktopAccessor.dll` — installed by the setup's Core section and included in the Portable and Source archives |
| Fira Code | Nikita Prokopov and contributors | SIL Open Font License 1.1 | `FiraCode-Regular.ttf`, `FiraCode-Bold.ttf` in `fonts/` — installed by the setup's "Fira Code Fonts" component and included in the release archives |

Sources for the third-party licenses:

- VirtualDesktopAccessor — <https://github.com/Ciantic/VirtualDesktopAccessor>
  (MIT), the open-source bridge Desk Switcheroo uses to drive the Windows
  virtual-desktop engine (see [How It Works](../how-it-works.md)).
- Fira Code — <https://github.com/tonsky/FiraCode> (SIL Open Font License 1.1),
  the monospaced font used for the widget/overlay text.

The SIL Open Font License permits bundling and redistributing the fonts,
including with commercial software; its main conditions are that the fonts keep
their license and not be sold on their own. The MIT-licensed DLL carries the
same keep-the-notice obligation as Desk Switcheroo itself.

## Packaging channels

The package manifests under `packaging/` declare Desk Switcheroo's MIT license:

- Chocolatey (`packaging/chocolatey/desk-switcheroo.nuspec`) points its
  `licenseUrl` at `license.md` on GitHub and sets
  `requireLicenseAcceptance` to false.
- Scoop (`packaging/scoop/desk-switcheroo.json`) declares `"license": "MIT"`.
- WinGet (`packaging/winget/supermarsx.DeskSwitcheroo.yaml`) declares
  `License: MIT` with a `LicenseUrl` pointing at `license.md`.

See [Deployment & Lifecycle](lifecycle.md) for how these channels package the
release.
