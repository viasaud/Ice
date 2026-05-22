<p align="center">
  <img src="MinimalIce/Supporting/app-icon.png" width="132" alt="Minimal Ice app icon">
</p>

<h1 align="center">Minimal Ice</h1>

<p align="center">
  A quiet macOS menu bar utility for keeping extra menu bar items out of sight
  until you need them.
</p>

## What It Does

Minimal Ice keeps your menu bar clean by tucking selected menu bar items into a
hidden section. Move your pointer to the chevron to reveal them, use the menu
when you want more control, and let the app stay out of the way the rest of the
time.

It is designed to feel native, lightweight, and private: no account, no
telemetry, no update feed, no background cloud service.

## How To Use

- Launch **Minimal Ice**.
- Grant **Accessibility** permission when macOS asks. Minimal Ice needs this to
  read and rearrange menu bar items.
- Use the chevron in the menu bar to reveal hidden items.
- Right-click or Control-click the chevron for reveal mode, dividers,
  always-hidden items, launch at startup, and quit.
- Command-drag menu bar items to rearrange them. Minimal Ice temporarily shows
  all sections while you are arranging items.

## Privacy

Minimal Ice works locally on your Mac. It does not collect analytics, phone
home, show ads, or require a network connection for normal use.

## Permission

Minimal Ice requires **Accessibility** permission because managing menu bar items
uses macOS accessibility APIs. Normal use should not require Screen & System
Audio Recording permission.

## Download

Minimal Ice is ad-hoc signed for local use. If macOS blocks the first launch,
right-click **Minimal Ice.app** and choose **Open**.

## Local Release Build

```sh
xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release build
```

## License

Minimal Ice is available under the [GPL-3.0 license](LICENSE).
