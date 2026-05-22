<p align="center">
  <img src="MinimalIce/Supporting/app-icon.png" width="128" alt="Minimal Ice app icon">
</p>

<h1 align="center">Minimal Ice</h1>

<p align="center">
  A refined macOS menu bar utility for hiding what you do not need, until the
  moment you do.
</p>

<p align="center">
  <a href="#build-from-source">Build from source</a>
  ·
  <a href="LICENSE">License</a>
</p>

## Overview

Minimal Ice keeps your menu bar calm. Place extra menu bar items behind a small
chevron, reveal them instantly on hover or click, and keep the items you always
need visible.

It is native, lightweight, and private by design.

## Highlights

- Hide selected menu bar items behind a single chevron.
- Keep an always-visible area for essentials.
- Use an optional always-hidden area for items you rarely touch.
- Reveal hidden items on hover or click.
- Rearrange items with the familiar Command-drag gesture.
- Run locally with no accounts, analytics, ads, or cloud service.

## Build From Source

Minimal Ice is source-distributed. Clone the repository, build it locally, and
install the app you built:

```sh
git clone https://github.com/viasaud/Minimal-Ice.git
cd Minimal-Ice
xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release build
release_products_dir="$(xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ { print $2; exit }')"
ditto "$release_products_dir/Minimal Ice.app" "/Applications/Minimal Ice.app"
open "/Applications/Minimal Ice.app"
```

Grant Accessibility permission when macOS asks. Minimal Ice needs Accessibility
access to read and rearrange menu bar items.

Prebuilt release zips are not provided because this fork is not Developer ID
signed or notarized. Building from source avoids asking users to bypass
Gatekeeper for a downloaded app.

## Privacy

Minimal Ice works on your Mac. It does not collect analytics, track usage, show
ads, auto-update, or require a network connection for normal menu bar
management.

## License

Minimal Ice is available under the [GPL-3.0 license](LICENSE).
