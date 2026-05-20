# Minimal Ice Agent Guide

This repository uses Xcode file-system-synchronized groups. The filesystem under
`MinimalIce/` is the source map for both Xcode and coding agents.

## Source Map

- `MinimalIce/App`: app entry point, delegate, lifecycle coordination, and
  app-wide state composition.
- `MinimalIce/Features/MenuBar`: menu bar sections, control items, item
  discovery, reveal behavior, and menu bar hit testing.
- `MinimalIce/Features/Settings`: single-page settings UI plus `State/` for
  settings persistence and behavior policy.
- `MinimalIce/Features/Permissions`: Accessibility permission model and window.
- `MinimalIce/Infrastructure/Events`: AppKit and CGEvent monitoring.
- `MinimalIce/Infrastructure/Platform`: WindowServer, Accessibility, and
  CoreGraphics bridging.
- `MinimalIce/Infrastructure/Persistence`: defaults, migrations, and status-item
  storage.
- `MinimalIce/Infrastructure/Runtime`: logging, Objective-C storage, extensions,
  and runtime shims.
- `MinimalIce/Shared`: small reusable helpers with no feature ownership.
- `MinimalIce/Supporting`: assets, plist, and entitlements.

## Working Rules

- Keep feature-specific policies inside the owning feature unless another
  feature already has a concrete caller.
- Preserve `com.personal.Ice` unless the user explicitly asks for a bundle
  identity migration.
- Keep the Xcode project and scheme named `Ice`; the user-facing app name is
  `Minimal Ice`.
- Keep the app lightweight, native, fast, minimal, and personal-use focused.
- Avoid public distribution surfaces, update flows, telemetry, analytics,
  donation/support links, release infrastructure, funding metadata, and
  issue-template ceremony.
- Keep the GPL-3 license file because this remains a derivative fork.
- Accessibility is required for core menu bar management. Normal operation
  should not require Screen & System Audio Recording permission.
- Local builds are ad-hoc signed on this machine.
- SwiftLint is not part of this fork's current toolchain.
- Build with `xcodebuild -project Ice.xcodeproj -scheme Ice -configuration Debug build`.

## Domain Language

- Menu bar item: a status item window owned by an app or by macOS that can
  appear in the system menu bar.
- Control item: a Minimal Ice-owned menu bar item used to control or delimit a
  section.
- Visible section: the normal menu bar area to the right of the hidden section
  control item.
- Hidden section: the revealable area between the always-hidden section control
  item and the hidden section control item.
- Always-hidden section: the more restricted section to the left of the
  always-hidden control item.
- Reveal: a user action that temporarily shows a hidden section.
- Temporary reveal: moving one hidden menu bar item into visible space long
  enough to optionally click it, then returning it to its original section.
- Permission check: the startup flow that blocks normal app setup until
  Accessibility permission is granted.
- Settings window: the single-page macOS 26 settings interface.

## Removed Surface Area

Do not reintroduce Ice Bar, Show on Scroll, hotkeys, multi-pane settings, public
update flows, Menu Bar Appearance, Menu Bar Layout, visual LayoutBar previews,
custom control-item icon importing, old Dot/Ellipsis/Ice Cube assets, or public
support flows.

## Current Product Decisions

- The Minimal Ice icon is always the built-in Chevron.
- Settings are intentionally minimal, dark, content-height fitting, and
  single-page.
- The About section stays one line: app name and version.
- Do not expose permissions as a settings section; open the permissions window
  automatically when required Accessibility permission is missing.
- Accessibility permission detection should rely on
  `AXIsProcessTrustedWithOptions`.
- Hidden items reveal on hover by default. Hover reveal activates instantly only
  when the pointer is over the chevron and hides immediately when the pointer
  leaves the menu bar.
- Showing all sections while command-dragging menu bar items is always enabled.

## Local Workflow

- Do not push to GitHub unless explicitly asked.
- Keep changes local until the user asks to commit or push.
- Install test builds into `/Applications/Minimal Ice.app` when asked.
- Release builds:

```sh
xcodebuild -project Ice.xcodeproj -scheme Ice -configuration Release build
```

- Reinstall the Release build:

```sh
osascript -e 'tell application "Minimal Ice" to quit' || true
pkill -x "Minimal Ice" || true
rm -rf "/Applications/Minimal Ice.app"
ditto "$HOME/Library/Developer/Xcode/DerivedData/Ice-fgzxyubmlykwgvdiswwvjjyewtrp/Build/Products/Release/Minimal Ice.app" "/Applications/Minimal Ice.app"
open "/Applications/Minimal Ice.app"
```
