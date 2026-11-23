# Bottom Tab Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bottom tab bar so users can navigate between the game library and the retro packer.

**Architecture:** Replace the single selector view in `ContentView` with a `TabView` containing Library and Packer tabs. Keep the existing full-screen game/failure overlay above the tabs, and hide the tab bar while a client is running. Reuse `RetroPackerView` as the Packer tab by making its sheet-cancel action optional.

**Tech Stack:** SwiftUI, iOS, Xcode project.

**Spec:** `docs/superpowers/specs/2026-11-23-bottom-tab-navigation-design.md`

## Global Constraints

- **Native UI:** SwiftUI, matching existing Falcon patterns.
- **No behavior regressions:** game launch, quit gesture, covers, custom file import, reVCDOS download flow, and packer import must still work.
- **No new dependencies.**

## Review Focus

- **Game running hides tabs** — launching a client should present the full-screen game/failure view without a visible tab bar; quitting should return to tabs.
- **Pack import lands in Library** — successful pack should refresh custom clients and switch to Library so the user sees the new client.
- **Packer tab vs sheet** — Packer tab should not show a sheet-style Cancel action that dismisses nothing; sheet-style cancel remains available only where appropriate.
- **Add menu clarity** — Library Add menu should keep "Add Client from Files" and no longer include "Pack Retro Game".
- **reVCDOS download/failure overlays** — existing overlays still work when library tab is active.

---

### Task 1: Tabbed navigation

**Files:**
- Modify: `Falcon/ContentView.swift`
- Modify: `Falcon/RetroPacker/RetroPackerView.swift`

**Interfaces:**
- Consumes: existing `clientSelector`, `RetroPackerView(onImported:onCancel:)`, `loadClients()`.
- Produces: `ContentView` bottom tab navigation with Library and Packer tabs; `RetroPackerView` usable both as sheet and tab.

- [ ] **Step 1: Update `RetroPackerView` cancel API**

In `Falcon/RetroPacker/RetroPackerView.swift`, change `let onCancel: () -> Void` to `let onCancel: (() -> Void)?` (or equivalent). Only show the toolbar "Cancel" button when `onCancel` is non-nil. "Cancel Packing" remains and still cancels the active pack.

- [ ] **Step 2: Add tab state and TabView in `ContentView`**

Add a private tab enum/state, e.g. `private enum AppTab { case library, packer }` and `@State private var selectedTab: AppTab = .library`. Replace the selector branch with a `TabView(selection: $selectedTab)` containing:
- Library tab: existing `clientSelector` as its root content, tagged `.library`, `Label("Library", systemImage: "gamecontroller")` or similar native symbol.
- Packer tab: `RetroPackerView(onImported: { _ in loadClients(); selectedTab = .library }, onCancel: nil)`, tagged `.packer`, `Label("Packer", systemImage: "shippingbox")`.

Keep the full-screen selected-client/failure overlay above the TabView so the tab bar is not visible during gameplay/failure. Use `.toolbar(.hidden, for: .tabBar)` when `selectedClient != nil` if needed.

- [ ] **Step 3: Remove packer sheet/menu entry from Library**

Remove `@State private var showingRetroPacker` and the `.sheet(isPresented: $showingRetroPacker) { ... }` packer sheet. Change the toolbar Add menu to a single "Add Client from Files" button/action (or a menu with only that action) keeping existing file importer behavior.

- [ ] **Step 4: Build verify**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Falcon/ContentView.swift Falcon/RetroPacker/RetroPackerView.swift docs/superpowers/specs/2026-11-23-bottom-tab-navigation-design.md docs/superpowers/plans/2026-11-23-bottom-tab-navigation.md
git commit -m "feat: add bottom tab navigation for library and packer"
```
