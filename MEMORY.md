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
- Settings are intentionally minimal and single-page in this fork. Do not
  reintroduce settings for search menu bar items, menu bar item spacing,
  rehide strategy/interval, acknowledgements, quit, permissions, hiding app
  menus, or showing all sections while dragging.
- Hidden items reveal on hover by default. Hover reveal activates instantly
  only when the pointer is over the chevron and hides immediately
  when the pointer leaves the menu bar. Click reveal is off by default; when
  enabled, click-revealed items hide again using the `tempShowInterval` delay.
- The always-hidden section can be revealed only when both "Use an
  always-hidden section" and "Allow the always-hidden section to be revealed"
  are enabled. If the allow setting is off, block all user reveal paths,
  including Option-click, direct control item clicks, and context menu entries.
- Showing all sections while command-dragging menu bar items is always enabled.
  Keep this behavior unconditional instead of exposing it as a setting.
- The app should open the permissions window automatically whenever required
  Accessibility permission is missing. Do not expose permissions as a settings
  section.
- The permissions window should avoid a tall empty top area; keep the titlebar
  hidden/full-content and use compact top padding.
- Keep the permission purpose text combined into the bottom lock note, along
  with the local/privacy wording. Do not show a separate details note inside
  the permission card. Keep this note concise and align the lock icon cleanly
  with the top of the note text.
- The active About section should stay one line only: app name and version.
- The active settings window should stay content-height fitting, dark,
  single-page, and use a hidden titlebar while keeping the standard macOS
  traffic-light controls.
- Accessibility permission detection should rely on the canonical
  `AXIsProcessTrustedWithOptions` result. Do not use sticky grant state or AX
  read fallbacks because they can show "granted" when permission is actually
  revoked.
- SwiftLint is not part of this fork's current toolchain. Do not keep orphan
  `.swiftlint.yml` config or inline SwiftLint disable comments unless linting is
  intentionally reintroduced through a real local/CI workflow.

## Workflow Notes

- Update this file proactively without waiting for the user to ask when there is
  a durable decision, a standing user preference, an important repo fact, or a
  workflow constraint that future work should remember.
- Keep app metadata and About/version notes current as part of related changes;
  do not wait for a separate user reminder when the versioning rule or visible
  app identity changes.
- When the user asks for wording or layout changes, preserve the existing UI
  structure and meaning unless they explicitly ask to remove or simplify it.
  If wording is ambiguous, check the nearby UI before making destructive
  simplifications.
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
