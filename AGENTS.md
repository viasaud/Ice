# Minimal Ice Agent Guide

This repository uses Xcode file-system-synchronized groups. The filesystem under
`MinimalIce/` is the source map for both Xcode and coding agents.

## Source Map

- `MinimalIce/App/Bootstrap`: SwiftUI app entry point plus the app delegate and
  permission-gated launch flow. Keep bootstrap in `MinimalIceApp.swift` unless
  it becomes substantially more complex.
- `MinimalIce/App/State`: app-wide state composition.
- `MinimalIce/MenuBar`: core menu bar orchestration.
- `MinimalIce/MenuBar/Sections`: visible, hidden, and always-hidden section
  models.
- `MinimalIce/MenuBar/ControlItems`: Minimal Ice-owned status items used to
  control or delimit sections. Built-in chevron drawing stays local to
  `ControlItem`.
- `MinimalIce/MenuBar/Items`: menu bar item identity, window snapshots, image
  caching, and item discovery.
- `MinimalIce/MenuBar/Items/ItemManagement`: item cache refresh, CGEvent
  routing, movement, clicking, temporary reveal, rehide behavior, and section
  classification.
- `MinimalIce/Settings/State`: the single settings manager plus reveal policy
  value types. There is no separate settings UI in this fork.
- `MinimalIce/Permissions`: Accessibility-only permission checking.
- `MinimalIce/Platform`: AppKit event monitoring, WindowServer adapters,
  private CoreGraphics bridging, and platform shims.
- `MinimalIce/Persistence`: defaults, status-item defaults, and migrations.
- `MinimalIce/Runtime`: logging, bundle constants, extensions, and runtime
  shims.
- `MinimalIce/Shared`: small reusable helpers with no feature ownership.
- `MinimalIce/Supporting`: assets, plist, and entitlements.

## Working Rules

- Keep feature-specific policies inside the owning feature unless another
  feature already has a concrete caller.
- Preserve `com.personal.Ice` unless the user explicitly asks for a bundle
  identity migration.
- Keep the Xcode project bundle and scheme named `MinimalIce`; the user-facing
  app name is `Minimal Ice`.
- Keep the app lightweight, native, fast, minimal, and personal-use focused.
- Avoid public distribution surfaces, update flows, telemetry, analytics,
  donation/support links, release infrastructure, funding metadata, and
  issue-template ceremony.
- Keep the GPL-3 license file because this remains a derivative fork.
- Accessibility is required for core menu bar management. Normal operation
  should not require Screen & System Audio Recording permission.
- Local builds are ad-hoc signed on this machine.
- SwiftLint is not part of this fork's current toolchain.
- Build with `xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Debug build`.

## Simplified Architecture

- Prefer fewer files and fewer shallow modules. If a type has one concrete
  caller and no independent lifecycle, keep it beside that caller.
- Do not recreate deleted wrapper files such as `AppLifecycleCoordinator`,
  generic `Permission`, `GeneralSettingsManager`, `AdvancedSettingsManager`,
  `MenuBarRevealPolicy`, `MenuBarHitTest`, `MenuBarSectionLayout`,
  `MenuItemIcon`, `ControlItemImage`, `StatusItemDefaults`,
  `BindingExposable`, `IceSlider`, `SettingsCard`, or `ObjectStorage`.
- Keep settings as one `SettingsManager`. If a new setting is needed, add the
  stored value, defaults persistence, and behavior projection there unless a
  real second owner appears.
- Keep permissions Accessibility-only. Do not add a generic permission model or
  permissions settings UI unless the product truly needs another required
  permission.
- Keep event monitoring in the unified monitor file unless a monitor has a
  genuinely different mechanism, such as the run-loop local event observer.
- Keep right-click/control-item menu construction owned by `MenuBarManager`.
  Control items should ask the menu bar manager for menus instead of building
  duplicate menus.
- Do not weaken Swift concurrency to simplify code: preserve `@MainActor`
  isolation for app state, settings, permissions, menu bar orchestration,
  control items, and event handling; avoid new `nonisolated(unsafe)` unless it
  is replacing an existing necessary bridge.

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

## App Icon Notes

- The correct app icon artwork is cube artwork on an opaque black square
  background, with the generated rounded-square/card rim removed from the PNG
  artwork.
- Do not use the previous transparent-corner version or cube-only small icon
  slots. Those made the System Settings icon look worse.
- Do not add `MinimalIce/Supporting/AppIcon.icon` from Icon Composer for this
  icon. Icon Composer/macOS 26 adds its own glossy rounded enclosure and made
  the border more obvious in previews.
- The source of truth remains
  `MinimalIce/Supporting/Assets.xcassets/AppIcon.appiconset/`.
- The final generation approach was:
  - Start from the good generated image under
    `$HOME/.codex/generated_images/.../ig_0b75acd7c94bb234016a0e0d386b0881918c986a01641fff6d.png`.
  - Extract/preserve the cube and its glow.
  - Explicitly remove the generated outer app-card/rim from the image.
  - Composite the cube over an opaque black 1024x1024 background.
  - Export all native macOS app icon slots from 16px through 1024px.
- Verification used:
  - `xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Debug build`
  - Install to `/Applications/Minimal Ice.app`.
  - Extract `/Applications/Minimal Ice.app/Contents/Resources/AppIcon.icns`
    with `iconutil -c iconset`.
  - Check extracted icon edge/corner pixels are opaque black, not gray and not
    transparent.
  - Render `/Applications/Minimal Ice.app` via
    `NSWorkspace.shared.icon(forFile:)` to see what System Settings/Finder-style
    APIs receive.
- Important finding: after the artwork rim is removed, any remaining
  rounded/glossy border visible in System Settings is macOS 26's
  system-rendered app icon enclosure, not a border baked into the icon assets.

## Local Workflow

- Do not push to GitHub unless explicitly asked.
- Keep changes local until the user asks to commit or push.
- Install test builds into `/Applications/Minimal Ice.app` when asked.
- Release builds:

```sh
xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release build
```

- Reinstall the Release build:

```sh
osascript -e 'tell application "Minimal Ice" to quit' || true
pkill -x "Minimal Ice" || true
rm -rf "/Applications/Minimal Ice.app"
release_products_dir="$(xcodebuild -project MinimalIce.xcodeproj -scheme MinimalIce -configuration Release -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ { print $2; exit }')"
ditto "$release_products_dir/Minimal Ice.app" "/Applications/Minimal Ice.app"
open "/Applications/Minimal Ice.app"
```
