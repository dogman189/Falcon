# Settings Controller Accessibility

## Goal

Make the Settings page reachable and fully operable with a game controller, matching the existing Retro Packer controller UX.

## Approved approach

Approach 1: match the packer’s controller pattern and extend tab switching to include Settings.

## Scope

### `Falcon/ContentView.swift`

- Change shoulder tab switching from hardcoded `L1 -> Library, R1 -> Packer` to cycling left/right across `[.library, .packer, .settings]`.
- Pass `isActiveTab: selectedTab == .settings` and `onReturnToLibrary` into `SettingsView`.

### `Falcon/SettingsView.swift`

- Add controller state: `isActiveTab` (default `true`), `@ObservedObject private var controllerManager = GameControllerManager.shared`, and `focusedField` with three rows: `0 = Theme`, `1 = App UI Scale`, `2 = Web Content Scale`.
- Add optional `onReturnToLibrary: (() -> Void)? = nil`.
- Register controller callbacks on appear and when `isActiveTab` becomes active. Only register when active so other tabs keep their callbacks.
- Controller mapping:
  - **Up/Down:** move focus between the 3 rows.
  - **Left/Right:** Theme cycles through `AppTheme.allCases`; scales step through `AppSettings.uiScaleNotches` / `AppSettings.webScaleNotches` (clamped at ends).
  - **A:** forward/activate action — cycle theme forward, increase scale by one notch, clamped at max.
  - **B:** return to Library via `onReturnToLibrary`.
- Visual feedback when a controller is connected: focused row gets a visible border/fill treatment like `RetroPackerView`; show a small controller legend/hint. Touch/mouse behavior remains unchanged.

### `Falcon/LibraryView.swift` (recommended integration fix)

- Add `isActiveTab` and re-register controller callbacks when the Library tab becomes active, following the `RetroPackerView` pattern. This prevents stale callbacks after visiting Settings/Packer.

## Non-goals

- No redesign of Settings layout or new settings.
- No changes to in-game controller behavior; `GameControllerManager.isEnabled` already disables menu interception when a client is open.

## Risks / notes

- Shoulder-button muscle memory changes: R1 now reaches Settings. This is intended.
- Theme cycling wraps through `AppTheme.allCases`; scale adjustments clamp at min/max notch values.
- Verify controller callback ownership when switching tabs so only the active tab handles navigation/action inputs.
