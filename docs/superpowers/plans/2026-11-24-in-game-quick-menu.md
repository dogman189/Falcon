# In-Game Quick Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the in-game quit-only reveal with a small quick menu (Resume, Reload, Screenshot, Quit) that can be toggled by the existing top-left swipe or the controller Guide/Home button.

**Architecture:** Keep session lifecycle actions in `ContentView` and extend its existing top-left overlay state into a quick-menu overlay. Add a narrow reload hook to `EaglerWebView`, a best-effort in-game `buttonHome` callback to `GameControllerManager`, and Photos save handling for web-view snapshots. Verify with `xcodebuild`; this repo has no XCTest target.

**Tech Stack:** SwiftUI, UIKit/WebKit (`WKWebView`), GameController (`GCExtendedGamepad.buttonHome`), Photos (`PHPhotoLibrary` add-only), Xcode project `Falcon.xcodeproj`, scheme `Falcon`.

**Spec:** `docs/superpowers/specs/2026-11-24-in-game-quick-menu-design.md`

## Global Constraints

- **Swipe trigger remains primary:** keep the existing top-leading 140x90 swipe hotspot/drag gesture in `ContentView.swift`; swipe toggles the menu.
- **Guide/Home is best-effort:** controller Guide/Home button toggles the menu only where `GCExtendedGamepad.buttonHome` is exposed and delivers events; do not rely on it being present. Do not use the X face button.
- **No in-game menu navigation:** while a client is active, D-pad/thumbstick/A/B/X face button/shoulders must not trigger menu navigation callbacks. Only the Guide/Home toggle callback may fire in-game.
- **No true pause:** opening the menu does not pause the web game. Auto-hide after ~5 seconds of inactivity; Resume or tap outside closes it.
- **Reuse existing quit behavior:** Quit must still hide overlay, finalize launch session, snapshot cover, stop reVCDOS server, clear selection/failure.
- **No XCTest target:** verification uses `xcodebuild` build. Do not invent a test target.

## Review Focus

- **Controller isolation:** with a client active, Guide/Home toggles menu but D-pad/sticks/face buttons/shoulders do not invoke `GameControllerManager` menu callbacks or interfere with normal game input.
- **buttonHome availability:** controllers/OSes without `buttonHome` do not crash; swipe still works; callback is cleared on client exit.
- **Reload semantics:** Reload clears transient client failure and reloads the active web content without breaking reVCDOS local-server launches or custom/bundled file clients.
- **Screenshot permission:** saving to Photos handles denied/restricted/not-determined add-only authorization with lightweight feedback; no crash on failure.
- **Overlay lifecycle:** menu auto-hide timer resets on interaction, is cancelled on hide/quit/client change, and does not reappear after leaving a session.

---

### Task 1: Add In-Game Guide/Home Menu Toggle to GameControllerManager

**Files:**
- Modify: `Falcon/GameControllerManager.swift`
- Test: none (no XCTest target; verify with build)

**Interfaces:**
- Consumes: existing `GCController`/`GCExtendedGamepad` configuration in `configureExtendedGamepad(_:)`.
- Produces: `var onInGameMenuToggle: (() -> Void)?` on `GameControllerManager`. When `isEnabled == false`, a pressed `gamepad.buttonHome` event invokes `onInGameMenuToggle?()` on the main actor; when `isEnabled == true`, existing menu behavior is unaffected. No other callbacks fire while disabled.

- [ ] **Step 1: Add the callback property**

In `Falcon/GameControllerManager.swift`, add near the other callbacks:

```swift
var onInGameMenuToggle: (() -> Void)? // Guide/Home button while in-game
```

- [ ] **Step 2: Add a private handler**

Add:

```swift
private func handleInGameMenuToggle() {
    guard !isEnabled else { return }
    onInGameMenuToggle?()
}
```

- [ ] **Step 3: Wire `buttonHome` in `configureExtendedGamepad`**

In `configureExtendedGamepad(_:)`, after existing button configuration, add:

```swift
gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
    if pressed {
        Task { @MainActor in self?.handleInGameMenuToggle() }
    }
}
```

Do not gate this behind `isEnabled`; the handler itself checks `!isEnabled`. Do not add D-pad/stick/face button/shoulder handlers that bypass `isEnabled`.

- [ ] **Step 4: Build verify**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Falcon/GameControllerManager.swift
git commit -m "feat: add in-game controller home menu toggle callback"
```

---

### Task 2: Add Reload Hook to EaglerWebView

**Files:**
- Modify: `Falcon/EaglerWebView.swift`
- Test: none (build verification)

**Interfaces:**
- Consumes: existing `EaglerWebView` UIViewRepresentable and `Coordinator`.
- Produces: `var reloadToken: UUID = UUID()` (or equivalent stable token) on `EaglerWebView`; when `updateUIView` sees a changed token, it reloads the web view. `Coordinator` stores `lastReloadToken`.

- [ ] **Step 1: Add reload token state to Coordinator**

In `Coordinator`, add:

```swift
var lastReloadToken: UUID?
```

- [ ] **Step 2: Add reloadToken property to EaglerWebView**

Add a property with default value so existing call sites remain source-compatible:

```swift
var reloadToken: UUID = UUID()
```

- [ ] **Step 3: Trigger reload in updateUIView**

In `updateUIView(_:context:)`, after existing updates, add:

```swift
if context.coordinator.lastReloadToken != reloadToken {
    context.coordinator.lastReloadToken = reloadToken
    uiView.reload()
}
```

Keep initial load behavior in `makeUIView` unchanged.

- [ ] **Step 4: Build verify**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Falcon/EaglerWebView.swift
git commit -m "feat: add reload hook to web view"
```

---

### Task 3: Add Photos Permission Key for Screenshot Save

**Files:**
- Modify: `Falcon.xcodeproj/project.xcproj`
- Test: none (build verification)

**Interfaces:**
- Produces: `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` build setting with a clear user-facing string.

- [ ] **Step 1: Add the Info.plist key**

In `Falcon.xcodeproj/project.xcproj` build settings (near other `INFOPLIST_KEY_*` entries), add:

```json
"INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription": "Save gameplay screenshots to your photo library.",
```

- [ ] **Step 2: Build verify**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Falcon.xcodeproj/project.xcproj
git commit -m "chore: add photo library add usage description"
```

---

### Task 4: Replace Quit Overlay State with Quick Menu State in ContentView

**Files:**
- Modify: `Falcon/ContentView.swift`
- Test: none (build verification; manual verification required)

**Interfaces:**
- Consumes: existing `snapshotter`, `webViewIdentity`, `clientFailure`, `selectedClient`, `quitCurrentClient()`, `GameControllerManager.shared`.
- Produces: quick menu overlay state and UI with Resume/Reload/Screenshot/Quit; swipe and Guide/Home toggle it; tap outside closes it; 5s inactivity auto-hide.

- [ ] **Step 1: Replace quit-only state with menu state**

In `ContentView`, replace `quitRevealed`/`quitHideTask` with menu-focused state:

```swift
@State private var quickMenuVisible = false
@State private var quickMenuHideTask: Task<Void, Never>?
@State private var webReloadToken = UUID()
@State private var screenshotFeedback: String?
@State private var screenshotFeedbackTask: Task<Void, Never>?
```

Remove or adapt old quit helper names so there is one overlay path.

- [ ] **Step 2: Add menu visibility/timer helpers**

Implement helpers with these semantics:

```swift
private func toggleQuickMenu() { ... }
private func showQuickMenu(autoHide: Bool = true) { ... }
private func hideQuickMenu() { ... }
private func scheduleQuickMenuAutoHide() { ... }
```

- `toggleQuickMenu()` animates visibility; showing schedules 5s auto-hide; hiding cancels hide task.
- `scheduleQuickMenuAutoHide()` cancels previous task, sleeps 5_000_000_000 ns, ignores cancellation, then hides on main actor/animation.
- Any menu action that keeps menu open should reschedule auto-hide; Resume/Quit hide immediately.

- [ ] **Step 3: Wire Guide/Home callback on client activation**

Update the existing `selectedClient` `onChange` block:

```swift
.onChange(of: selectedClient) { _, newClient in
    hideQuickMenu()
    GameControllerManager.shared.isEnabled = (newClient == nil)
    GameControllerManager.shared.onInGameMenuToggle = newClient == nil ? nil : {
        toggleQuickMenu()
    }
    // existing session/failure/server cleanup...
}
```

Also clear `onInGameMenuToggle` in any path that fully exits a client if needed (quit already clears selectedClient, so onChange covers it).

- [ ] **Step 4: Replace Quit-only overlay with Quick Menu overlay**

In the selected-client overlay ZStack:

- Keep the top-leading clear hotspot `frame(width: 140, height: 90)` with the same drag gesture; change handler to `toggleQuickMenu()`.
- Add a full-screen clear tap target *behind* the menu card when menu is visible to close on tap outside.
- Replace `quitButton` with a `quickMenuCard` view containing Resume, Reload, Screenshot, Quit buttons.
- Style as a small unobtrusive top-leading card/capsule stack consistent with existing dark overlay styling.

- [ ] **Step 5: Implement menu actions**

Add handlers:

```swift
private func reloadCurrentClient() { ... }
private func captureScreenshot() { ... }
```

- **Resume:** `hideQuickMenu()`.
- **Reload:** `clientFailure = nil`; `webReloadToken = UUID()`; if using identity-recreate fallback, set `webViewIdentity += 1`; hide menu or reschedule per UX (prefer hide). Do not stop reVCDOS server.
- **Screenshot:** take `snapshotter.takeSnapshot`; on image, request Photos add-only auth and save; show lightweight feedback text/toast near menu or as overlay; reschedule auto-hide.
- **Quit:** call existing `quitCurrentClient()`; ensure it hides quick menu.

- [ ] **Step 6: Pass reloadToken to EaglerWebView**

Update EaglerWebView construction:

```swift
EaglerWebView(
    content: webContent,
    snapshotter: snapshotter,
    reloadToken: webReloadToken,
    webScale: settings.webScale,
    backgroundUIColor: settings.backgroundUIColor
) { message in ... }
```

- [ ] **Step 7: Add Photos save helper**

In `ContentView.swift` (or a small private helper), add Photos save with add-only authorization:

```swift
import Photos
```

Use `PHPhotoLibrary.requestAuthorization(for: .addOnly)` on iOS 14+ path appropriate to project target; on success perform `PHAssetChangeRequest.creationRequestForAsset(from: image)`. Report success/failure through `screenshotFeedback`.

Keep feedback lightweight and auto-dismiss after ~2s.

- [ ] **Step 8: Build verify**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 9: Commit**

```bash
git add Falcon/ContentView.swift
git commit -m "feat: add in-game quick menu overlay"
```

---

### Task 5: Manual Verification and Spec/Plan Hygiene

**Files:**
- Modify: `docs/ROADMAP.md` (optional, only if user wants status update)
- Test: manual smoke checks

**Interfaces:**
- Produces: verified behavior across bundled/custom/reVCDOS clients; no stale callbacks/timers.

- [ ] **Step 1: Build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Manual smoke checklist**

Run app on simulator/device and verify:

- Swipe top-left reveals quick menu; swipe/tap Resume/tap outside closes it; auto-hides after ~5s.
- Quit returns to library and still updates cover/session as before.
- Reload recovers a client without leaving library; reVCDOS still works.
- Screenshot requests Photos permission appropriately and saves image when authorized; shows feedback on deny/failure.
- With controller connected, Guide/Home toggles menu in-game where supported; D-pad/face buttons/shoulders still go to game, not menu nav.
- Leaving game clears in-game Home callback and restores normal tab controller navigation.

- [ ] **Step 3: Commit verification note if needed**

If code changes were required during smoke fixes, commit them with focused messages. Do not commit unrelated files.

## Notes for Implementers

- `ContentView.swift` is already large; keep new overlay logic small and well-named. Extracting a small `QuickMenuOverlayView` is acceptable if it keeps `ContentView` readable.
- `buttonHome` can be system-reserved on some configurations. Treat it as opportunistic; never make it the only way to open the menu.
- Screenshot saving uses Photos add-only access; the project currently has no photo-library usage description key.
- Prefer reusing `webViewIdentity += 1` for reload only if `WKWebView.reload()` is insufficient; start with `reload()` via `reloadToken`.
