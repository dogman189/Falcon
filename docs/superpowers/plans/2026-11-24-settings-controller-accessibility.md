# Settings Controller Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Settings page reachable and fully operable with a game controller, matching the existing Retro Packer controller UX.

**Architecture:** Extend the existing `GameControllerManager` callback pattern used by `RetroPackerView`/`LibraryView`. `ContentView` owns tab cycling and passes `isActiveTab` to tab views; each active tab registers controller callbacks. `SettingsView` gets focused-row state and adjusts `AppSettings` values directly from controller inputs.

**Tech Stack:** SwiftUI, Observation/Combine as used in-project, GameController via `GameControllerManager`, Xcode project `Falcon.xcodeproj`, scheme `Falcon`.

**Spec:** `docs/superpowers/specs/2026-11-24-settings-controller-accessibility-design.md`

## Global Constraints

- Match existing controller UX patterns in `Falcon/RetroPacker/RetroPackerView.swift` (focused field, active-tab callback registration, visual focus, controller legend).
- Do not change in-game controller behavior; `GameControllerManager.isEnabled` must still be `false` only when a client is open, as currently handled in `Falcon/ContentView.swift`.
- Touch/mouse behavior in Settings must remain unchanged.
- Theme changes cycle through `AppTheme.allCases` in order: `darkBlue`, `black`, `light`.
- Scale changes move through existing notches only: `AppSettings.uiScaleNotches = [0.90, 1.00, 1.10, 1.20]`, `AppSettings.webScaleNotches = [0.75, 0.85, 1.00, 1.25]`.
- No test target exists in this repo; verification uses `xcodebuild` compile checks.

## Review Focus

- **Tab callback ownership:** when switching among Library/Packer/Settings, the inactive tab must not leave stale `GameControllerManager` navigation/action callbacks that hijack the active tab.
- **Settings tab reachability:** with a controller connected, L1/R1 can reach Settings from any tab and never traps the user in a two-tab cycle.
- **Scale bounds:** left/right/A adjustments at min/max scale notches clamp; they do not index out of bounds or wrap unexpectedly.
- **Touch regression:** existing touch controls (segmented theme picker, sliders) still work when no controller is connected.
- **Client-open isolation:** opening a game still disables menu controller interception and returning to tabs restores it.

---

### Task 1: Extend Controller Tab Cycling to Include Settings

**Files:**
- Modify: `Falcon/ContentView.swift:330-341` (shoulder tab switching)

**Interfaces:**
- Consumes: existing `GameControllerManager.shared.onShoulderLeft/onShoulderRight` and `@State private var selectedTab: AppTab`.
- Produces: shoulder buttons cycle across all three tabs in order `library, packer, settings`.

- [ ] **Step 1: Add tab ordering helper in `ContentView`**

Add a private helper on `ContentView`:

```swift
private var orderedTabs: [AppTab] { [.library, .packer, .settings] }
```

- [ ] **Step 2: Replace hardcoded shoulder handlers with cycling**

Update `setupControllerTabSwitching()` to move by index with wraparound:

```swift
private func setupControllerTabSwitching() {
    GameControllerManager.shared.onShoulderLeft = {
        cycleTab(step: -1)
    }
    GameControllerManager.shared.onShoulderRight = {
        cycleTab(step: 1)
    }
}

private func cycleTab(step: Int) {
    let tabs = orderedTabs
    guard let index = tabs.firstIndex(of: selectedTab) else { return }
    let next = (index + step + tabs.count) % tabs.count
    withAnimation(.easeInOut(duration: 0.2)) {
        selectedTab = tabs[next]
    }
}
```

- [ ] **Step 3: Build verify**

Run:

```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Falcon/ContentView.swift
git commit -m "feat: cycle controller tabs through settings"
```

---

### Task 2: Add Controller Support to SettingsView

**Files:**
- Modify: `Falcon/SettingsView.swift`
- Modify: `Falcon/ContentView.swift:120-125` (Settings tab wiring)

**Interfaces:**
- Consumes: `AppSettings` (`appTheme`, `uiScale`, `webScale`, notch arrays), `GameControllerManager.shared` callbacks, `ContentView.selectedTab`.
- Produces: controller-operable Settings UI with focused rows, d-pad navigation, left/right/A adjustments, B to Library, and visual controller feedback; ContentView passes `isActiveTab` and `onReturnToLibrary`.

- [ ] **Step 1: Add controller state and inputs to `SettingsView`**

Add properties/state near the top of `SettingsView`:

```swift
var isActiveTab: Bool = true
var onReturnToLibrary: (() -> Void)? = nil

@ObservedObject private var controllerManager = GameControllerManager.shared
@State private var focusedField: Int = 0
```

Keep existing `@EnvironmentObject private var settings: AppSettings`.

- [ ] **Step 2: Wire `SettingsView` from `ContentView`**

Update the Settings tab in `ContentView`:

```swift
SettingsView(
    isActiveTab: selectedTab == .settings,
    onReturnToLibrary: {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = .library
        }
    }
)
.tag(AppTab.settings)
.tabItem {
    Label("Settings", systemImage: "gearshape")
}
```

- [ ] **Step 3: Register callbacks on appear and active-tab changes**

Add lifecycle hooks to the Settings root view:

```swift
.onAppear {
    if isActiveTab {
        setupControllerCallbacks()
    }
}
.onChange(of: isActiveTab) { _, active in
    if active {
        setupControllerCallbacks()
    }
}
```

Implement `setupControllerCallbacks()` to assign `onNavigateUp/Down/Left/Right`, `onActionA`, `onActionB`. Do not overwrite `onShoulderLeft/Right`; `ContentView` owns tab switching.

- [ ] **Step 4: Implement focus movement and value adjustment**

Add helpers:

```swift
private func navigateVertically(step: Int) {
    focusedField = max(0, min(2, focusedField + step))
}

private func adjustFocusedField(step: Int) {
    switch focusedField {
    case 0:
        cycleTheme(step: step)
    case 1:
        adjustScale(\.uiScale, notches: AppSettings.uiScaleNotches, step: step)
    case 2:
        adjustScale(\.webScale, notches: AppSettings.webScaleNotches, step: step)
    default:
        break
    }
}
```

Implement `cycleTheme(step:)` wrapping over `AppTheme.allCases`. Implement scale adjustment clamping at notch ends (no wrap). `onActionA` performs the forward action: `cycleTheme(step: 1)` for theme, `+1` for scales. `onActionB` calls `onReturnToLibrary?()`.

- [ ] **Step 5: Add visual focus and controller legend**

Add a row background helper mirroring `RetroPackerView`:

```swift
private func rowBackground(for field: Int) -> some View {
    let isFocused = focusedField == field && controllerManager.isConnected
    let base = settings.appTheme.primaryText
    return Rectangle()
        .fill(isFocused ? base.opacity(0.12) : settings.appTheme.subtleFill)
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(base, lineWidth: 2)
            }
        }
}
```

Apply focus background to theme, UI scale, and web scale sections/rows. Add a controller legend section when `controllerManager.isConnected` showing Up/Down move, Left/Right adjust, A activate, B Library, LB/RB tab cycle.

- [ ] **Step 6: Build verify**

Run:

```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED. If no simulator destination is available, use an available iOS Simulator destination reported by `xcodebuild -showdestinations -project Falcon.xcodeproj -scheme Falcon`.

- [ ] **Step 7: Commit**

```bash
git add Falcon/ContentView.swift Falcon/SettingsView.swift
git commit -m "feat: add controller navigation to settings"
```

---

### Task 3: Re-register Library Controller Callbacks on Active Tab

**Files:**
- Modify: `Falcon/LibraryView.swift:8-35` (view properties)
- Modify: `Falcon/LibraryView.swift:210-230` (onAppear/lifecycle)
- Modify: `Falcon/ContentView.swift:307-328` (LibraryView wiring)

**Interfaces:**
- Consumes: existing `setupControllerCallbacks()` in `LibraryView`; `ContentView.selectedTab`.
- Produces: Library reclaims controller callbacks whenever it becomes the active tab, preventing stale callbacks from Packer/Settings.

- [ ] **Step 1: Add `isActiveTab` to `LibraryView`**

Add property:

```swift
var isActiveTab: Bool = true
```

Place it with other input properties.

- [ ] **Step 2: Re-register callbacks on active tab change**

Update lifecycle:

```swift
.onAppear {
    if isActiveTab {
        setupControllerCallbacks()
    }
}
.onChange(of: isActiveTab) { _, active in
    if active {
        setupControllerCallbacks()
    }
}
```

- [ ] **Step 3: Pass `isActiveTab` from `ContentView`**

In `libraryTab`, pass:

```swift
isActiveTab: selectedTab == .library,
```

- [ ] **Step 4: Build verify**

Run:

```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Falcon/ContentView.swift Falcon/LibraryView.swift
git commit -m "fix: restore library controller callbacks on tab activation"
```

---

### Task 4: Manual Controller Verification

**Files:**
- No code changes expected unless verification finds a defect.

**Interfaces:**
- Consumes: built app on device/simulator with paired controller or keyboard/controller mapping available in development environment.
- Produces: confidence that the approved behavior works end-to-end.

- [ ] **Step 1: Verify tab reachability**

Run the app and confirm: from Library, R1 goes to Packer, R1 goes to Settings, R1 wraps to Library; L1 cycles in reverse.

- [ ] **Step 2: Verify Settings controls**

In Settings with controller connected: Up/Down moves focus across Theme/UI Scale/Web Content Scale; Left/Right changes values; A performs forward action; B returns to Library. Theme wraps; scales clamp at ends.

- [ ] **Step 3: Verify regressions**

Confirm touch changes still work in Settings. Open a client and confirm controller menu interception remains disabled in-game (`GameControllerManager.isEnabled == false` path unchanged). Return to tabs and confirm controller navigation works.

- [ ] **Step 4: Record verification notes**

If issues are found, fix them and add a follow-up commit. If verification is manual-only in this environment, record what was and was not verified in the final handoff.
