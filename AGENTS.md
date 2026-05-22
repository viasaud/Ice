# Minimal Ice Agent Guide

This is a personal, minimal macOS menu bar utility. Keep it native, fast,
private, and small.

## Non-Negotiables

- Preserve bundle identifier `com.personal.Ice`.
- Keep the Xcode project and scheme named `MinimalIce`; the app name is
  `Minimal Ice`.
- Accessibility is the only required permission. Do not add Screen & System
  Audio Recording, telemetry, analytics, donation links, support flows, or
  issue-template ceremony.
- Keep GPL-3.0.
- Do not push unless the user explicitly asks.
- Use `xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Debug build`
  for normal verification.
- SwiftLint is not part of this fork.

## Product Shape

- User-facing layout:
  `always hidden < hidden < always visible`
- The right chevron is the interactive Minimal Ice icon.
- The optional left chevron is the always-hidden divider and uses the same large
  chevron artwork.
- Do not show a middle visible-section chevron. The old visible section is an
  internal compatibility detail only.
- Hidden items reveal on hover by default. Hover reveal starts only over the
  interactive chevron and should not collapse while a revealed item's menu or
  popover is open.
- Show all relevant sections while Command-dragging menu bar items.
- Settings stay single-page, minimal, dark, and content-height fitting.
- The About row stays one line: app name and version.

## Code Map

- `MinimalIce/App`: app entry, delegate, and app-wide state.
- `MinimalIce/MenuBar`: section orchestration, control items, menu bar item
  identity, caching, movement, reveal, clicking, and rehide behavior.
- `MinimalIce/Settings/State`: the single `SettingsManager`.
- `MinimalIce/Permissions`: Accessibility-only permission checks.
- `MinimalIce/Platform`: event monitoring, WindowServer adapters, private
  CoreGraphics bridges, and platform shims.
- `MinimalIce/Persistence`: defaults and migrations.
- `MinimalIce/Runtime`: logging, constants, extensions, runtime helpers.
- `MinimalIce/Supporting`: assets, plist, entitlements.

## Architecture Rules

- Prefer fewer files. If a type has one caller and no independent lifecycle,
  keep it with that caller.
- Keep settings in `SettingsManager` unless a real second owner appears.
- Keep permissions Accessibility-only; no generic permission model or settings
  permissions UI.
- Keep event monitoring unified unless a monitor has a genuinely different
  mechanism.
- Keep right-click/control-item menu construction owned by `MenuBarManager`.
- Preserve `@MainActor` isolation for app state, settings, permissions, menu bar
  orchestration, control items, and event handling.
- Do not recreate deleted wrapper/helper files such as
  `AppLifecycleCoordinator`, generic `Permission`, `GeneralSettingsManager`,
  `AdvancedSettingsManager`, `MenuBarRevealPolicy`, `MenuBarHitTest`,
  `MenuBarSectionLayout`, `MenuItemIcon`, `ControlItemImage`,
  `StatusItemDefaults`, `BindingExposable`, `IceSlider`, `SettingsCard`,
  `ObjectStorage`, or similar shallow indirection.

## Removed Features

Do not reintroduce Ice Bar, Show on Scroll, hotkeys, multi-pane settings, public
update UI, auto-updaters, Menu Bar Appearance, Menu Bar Layout, LayoutBar
previews, custom control-item icon importing, old Dot/Ellipsis/Ice Cube assets,
or public support flows.

## App Icon

- Source of truth:
  `MinimalIce/Supporting/Assets.xcassets/AppIcon.appiconset/`
- The icon is cube artwork on an opaque black square background.
- Do not use transparent-corner variants, cube-only small slots, or
  `MinimalIce/Supporting/AppIcon.icon`.
- If icon work is requested, verify with a Debug build, install to
  `/Applications/Minimal Ice.app`, inspect the extracted `.icns`, and confirm
  edge/corner pixels are opaque black.

## Version And Release

- User-facing version format is `year.month`, for example `26.5`. Do not add
  the build number to `MARKETING_VERSION`.
- `CURRENT_PROJECT_VERSION` is the numeric build number, for example `260523`.
- Distribution is source-only unless the user explicitly decides to use
  Developer ID signing and notarization. Do not publish ad-hoc signed app zips.
- GitHub Release notes, when used, should ask users to build from source and
  explain that prebuilt app zips are not provided because this fork is not
  Developer ID signed or notarized.
- Verify before calling a push/release done that the Release build succeeds.

## Local Commands

Debug build:

```sh
xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Debug build
```

Release build:

```sh
xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release build
```

Install current Release build:

```sh
osascript -e 'tell application "Minimal Ice" to quit' || true
pkill -x "Minimal Ice" || true
rm -rf "/Applications/Minimal Ice.app"
release_products_dir="$(xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ { print $2; exit }')"
ditto "$release_products_dir/Minimal Ice.app" "/Applications/Minimal Ice.app"
open "/Applications/Minimal Ice.app"
```
