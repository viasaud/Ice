# Context

This file records the domain language for this private Ice fork. Keep these
terms aligned with `MEMORY.md` when architecture changes land.

## Product

Ice is a private macOS menu bar utility fork. It manages menu bar items locally
and keeps settings minimal, native, and personal-use focused. The repository is
kept as app source plus local build/project context, not as a public project
surface.

## Domain Terms

- **Menu bar item**: A status item window owned by an app or by macOS that can
  appear in the system menu bar.
- **Control item**: An Ice-owned menu bar item used to control or delimit a
  section.
- **Visible section**: The normal menu bar area to the right of the hidden
  section control item.
- **Hidden section**: The revealable area between the always-hidden section
  control item and the hidden section control item.
- **Always-hidden section**: The more restricted section to the left of the
  always-hidden control item.
- **Reveal**: A user action that temporarily shows a hidden section.
- **Temporary reveal**: Moving one hidden menu bar item into visible space long
  enough to optionally click it, then returning it to its original section.
- **Permission check**: The startup flow that blocks normal app setup until the
  required Accessibility permission is granted.
- **Settings window**: The single-page macOS 26 settings interface for this
  fork.

## Code Shape

- Xcode file-system-synchronized groups make the `Ice/` folder layout the
  source of truth for app source membership.
- `AppState` owns app-wide window/navigation booleans directly; there is no
  separate navigation state model.
- Permission readiness is computed directly by `PermissionsManager`; there is
  no standalone permission gate type.
- Small one-off policies should stay near their owning feature unless they earn
  reuse across modules.
- The remaining `Ice/UI` helpers are only the controls still used by the
  current settings and permissions screens.

## Standing Constraints

- Do not reintroduce Ice Bar, Show on Scroll, hotkeys, multi-pane settings,
  public update flows, telemetry, donation/support links, or release
  infrastructure.
- Do not reintroduce `.github` issue templates, funding links, public support
  flows, or other upstream public-repository ceremony.
- Do not require Screen & System Audio Recording for normal operation.
- Accessibility remains required for core menu bar management.
- Keep the GPL-3 license file because this remains a derivative fork.
