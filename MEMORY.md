# Memory

This file is the standing working memory for this personal Ice fork. Read it at
the start of future work in this repository and update it when decisions,
constraints, or user preferences change.

## User Preferences

- Do not push to GitHub unless explicitly asked.
- Keep changes local until the user asks to commit or push.
- Install the app into `/Applications/Ice.app` when the user asks to test the
  current build.
- Prefer practical personal-use behavior over public distribution workflows.

## Product Direction

- This is a private macOS 26 Tahoe personal-use fork.
- Keep the app lightweight, native, fast, and minimal.
- Preserve required license and copyright notices.
- Avoid telemetry, analytics, update checkers, donation/support flows, and
  public release infrastructure.
- The app should not require Screen & System Audio Recording permission for
  normal operation.
- Accessibility permission is still required for core menu bar management.

## Current Technical Notes

- Bundle identifier: `com.personal.Ice`.
- Build target: macOS 26.
- Swift version: 6.
- App marketing versions use the `year.month` pattern, with patch updates as
  `year.month.update` such as `26.5.3`. The current marketing version is
  `26.5`.
- Local builds are ad-hoc signed because this machine currently has no valid
  code-signing identities.
- Ad-hoc signing can make macOS privacy/TCC registration unreliable, especially
  for screen-recording permissions.
- Screen-capture-dependent features should use native fallbacks instead of
  requesting Screen & System Audio Recording permission.
- The Ice Bar feature has been removed from this fork. Keep settings, menu-bar
  behavior, and image-cache logic on the standard menu bar path.
- The Show on Scroll feature has been removed. Do not add a global scroll-wheel
  monitor just to show or hide hidden menu bar items.
- The Hotkeys settings page and global hotkey subsystem have been removed. Keep
  only local keyboard handling needed by focused UI such as Escape/arrow keys.
- The Menu Bar Appearance page and custom tint/shape overlay subsystem have
  been removed. Keep menu bar visuals native and avoid reintroducing overlay
  panels or appearance editors.
- The Menu Bar Layout page and visual LayoutBar drag UI have been removed.
  Keep core menu bar section behavior, but do not reintroduce the settings
  layout editor or its preview assets.
- The Ice icon is always the built-in Chevron in this fork. Do not reintroduce
  icon picker settings, custom icon importing, or old Dot/Ellipsis/Ice Cube
  control item assets.
- Accessibility permission detection should rely on the canonical
  `AXIsProcessTrustedWithOptions` result. Do not use sticky grant state or AX
  read fallbacks because they can show "granted" when permission is actually
  revoked.

## Workflow Notes

- Update this file proactively without waiting for the user to ask when there is
  a durable decision, a standing user preference, an important repo fact, or a
  workflow constraint that future work should remember.
- Keep app metadata and About/version notes current as part of related changes;
  do not wait for a separate user reminder when the versioning rule or visible
  app identity changes.
- Use `rg` for searches.
- Use `apply_patch` for manual edits.
- Build with:

```sh
xcodebuild -project Ice.xcodeproj -scheme Ice -configuration Release build
```

- Reinstall the Release build with:

```sh
osascript -e 'tell application "Ice" to quit' || true
pkill -x Ice || true
rm -rf /Applications/Ice.app
ditto "$HOME/Library/Developer/Xcode/DerivedData/Ice-fgzxyubmlykwgvdiswwvjjyewtrp/Build/Products/Release/Ice.app" /Applications/Ice.app
open /Applications/Ice.app
```
