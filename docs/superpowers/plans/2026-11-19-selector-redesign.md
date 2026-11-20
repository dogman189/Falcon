# Selector Redesign + Portrait-Until-Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the vibe-coded selector (heavy black gradient wall, giant ALL-CAPS "FALCON" wordmark, 260×150 cyan-outlined tiles) with a quiet utility list of clean rows, and lock the app to portrait while the selector is up — freeing orientation when a client launches.

**Architecture:** A new `SelectorRow` view renders one client as a 56pt cover thumbnail + name + note on a soft card. `ContentView` renders a vertical `ScrollView` of these rows. A shared `OrientationLock` observable holds `portraitOnly`; an `AppDelegate` adaptor returns the mask from it, and a window-scene geometry update applies changes at runtime.

**Tech Stack:** SwiftUI, WebKit, UIKit (orientation); no new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-19-selector-redesign-design.md`

## Global Constraints
- iOS app, SwiftUI + WebKit + UIKit; deployment target iOS 27.2; no third-party libraries.
- Palette: default system background; row card = `Color.white.opacity(0.08)` with `RoundedRectangle(cornerRadius: 12, style: .continuous)` and `.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)`; cyan accent only for the CUSTOM badge and the Add Client button.
- No giant wordmark, no heavy gradient, no cyan-outlined wide tiles.
- Launch, failure, quit, cover-store, and custom-client-store behavior stays unchanged.

## Review Focus
1. **Launch tap:** a row must still select and launch its client (same behavior as the old tile tap).
2. **Rotate while selector is up:** app stays portrait on device rotation.
3. **Rotate after launch:** orientation is free; returning to the selector re-locks to portrait.
4. **Cover + context menus:** custom rows still show the cover and their context menu (cover actions + Remove Client); bundled rows keep cover actions.
5. **Add Client + empty CUSTOM state:** unchanged behavior and copy.

Verification is `xcodebuild build` plus manual simulator/device checks — this project has no test target.

---

### Task 1: Create `Falcon/SelectorRow.swift`

**Files:**
- Create: `Falcon/SelectorRow.swift`

**Interfaces:**
- Consumes: `GameClient` (from `Falcon/BundledClient.swift`) and an `Image` cover passed in by the caller.
- Produces: `SelectorRow(client: GameClient, cover: Image)` — a presentational view with no state or store access.

- [ ] **Step 1: Implement** — Create `struct SelectorRow: View { let client: GameClient; let cover: Image; var body: some View { ... } }`. Layout: `HStack(spacing: 12)` with `cover.resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))`, then a `VStack(alignment: .leading, spacing: 4)` containing `Text(client.name).font(.body.weight(.semibold))`, an inline CUSTOM badge (`Text("CUSTOM").font(.caption2.weight(.bold)).foregroundStyle(.cyan)`) when `client.isCustom`, and `Text(client.note ?? (client.url == nil ? "Bundle missing" : "Tap to launch")).font(.footnote).foregroundStyle(.secondary)`. Add `Spacer(minLength: 0)` to push content left. Apply `.padding(12)`, `.frame(height: 68)`, and the exact card background + shadow from Global Constraints. No context menu here — the caller attaches it.

- [ ] **Step 2: Verify** — Run `xcodebuild -project Falcon.xcodeproj -scheme Falcon -sdk iphonesimulator build` (use `xcodebuild -list` first if the scheme name differs). Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit** — `git add Falcon/SelectorRow.swift && git commit -m "ui: add quiet selector row view"`.

### Task 2: Rework `Falcon/ContentView.swift` selector

**Files:**
- Modify: `Falcon/ContentView.swift` — `clientSelector` (lines ~181–297) and `clientTile(for:)` (lines ~299–380).

**Interfaces:**
- Consumes: `SelectorRow(client:cover:)` from Task 1; existing `coverImage(for:)`, `coverMenuItems(for:)`, `removeCustomClient(_:)`, `loadClients()`, etc.
- Produces: same public behavior; orientation wiring added in Task 3.

- [ ] **Step 1: Implement** — Replace `clientSelector` with a `ZStack` over the default system background (no linear gradient). Inside: `ScrollView { VStack(alignment: .leading, spacing: 12) { ... } }` with a header `Text("Select a client to launch").font(.title3.weight(.medium))` (no "FALCON" wordmark) and the existing Add Client button styled as a cyan capsule (`Color.cyan.opacity(0.18)` fill, `Capsule().stroke(Color.cyan.opacity(0.45))`); a "BUNDLED" caption label; `ForEach(GameClient.bundled)` rendering `SelectorRow(client:cover: coverImage(for: client))` with `.id("\(client.id)-\(coverRevision)")` and `.contextMenu { coverMenuItems(for: client) }`; a "CUSTOM" caption label; the existing empty-state text when `customClients.isEmpty`, else `ForEach(customClients)` with the same row/id/context menu plus the destructive `Remove Client` button calling `removeCustomClient(client)`. Keep the existing footer hint text and `.padding(.horizontal, 24)` / `.frame(maxWidth: 900, alignment: .leading)` structure. Delete `clientTile(for:)` entirely. Do not add orientation code in this task.

- [ ] **Step 2: Verify** — `xcodebuild -project Falcon.xcodeproj -scheme Falcon -sdk iphonesimulator build`. Expected: BUILD SUCCEEDED. Manual: selector is a vertical list of quiet rows; tapping a row launches its client; context menus still open.

- [ ] **Step 3: Commit** — `git add Falcon/ContentView.swift && git commit -m "ui: redesign selector as quiet utility list"`.

### Task 3: Create `Falcon/OrientationLock.swift` and wire it

**Files:**
- Create: `Falcon/OrientationLock.swift`
- Modify: `Falcon/FalconApp.swift`
- Modify: `Falcon/ContentView.swift` (the existing `.onChange(of: selectedClient)` at lines ~66–68)

**Interfaces:**
- Produces: `OrientationLock` (observable) with `static let shared`, `@Published var portraitOnly: Bool` (default `true`), and `func apply()`. Used by `FalconApp`'s `AppDelegate` and by `ContentView`.

- [ ] **Step 1: Implement `OrientationLock`** — `final class OrientationLock: ObservableObject { static let shared = OrientationLock(); @Published var portraitOnly = true { didSet { apply() } }; func apply() { ... } }`. In `apply()`, find the foreground-active `UIWindowScene` from `UIApplication.shared.connectedScenes` (fall back to any window scene), and on iOS 16+ call `scene.requestGeometryUpdate(.iOS(interfaceOrientations: portraitOnly ? .portrait : .allButUpsideDown))` and `scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()`.

- [ ] **Step 2: Wire the AppDelegate** — In `Falcon/FalconApp.swift`, add `@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate` to `FalconApp`, and define `final class AppDelegate: NSObject, UIApplicationDelegate { func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { OrientationLock.shared.portraitOnly ? .portrait : .allButUpsideDown } }`.

- [ ] **Step 3: Wire ContentView** — Change the existing `.onChange(of: selectedClient) { _, _ in hideQuit() }` to also set `OrientationLock.shared.portraitOnly = (selectedClient == nil)`. This covers launch (free), quit, failure-back (re-lock), and the DEBUG `--client=` launch path. No other state wiring is needed.

- [ ] **Step 4: Verify** — `xcodebuild -project Falcon.xcodeproj -scheme Falcon -sdk iphonesimulator build`. Expected: BUILD SUCCEEDED. Manual: with selector up, rotating the device/Simulator keeps portrait; launch a client, rotation is free; quit back to selector, portrait re-locks.

- [ ] **Step 5: Commit** — `git add Falcon/OrientationLock.swift Falcon/FalconApp.swift Falcon/ContentView.swift && git commit -m "feat: lock portrait while selector is up"`.
