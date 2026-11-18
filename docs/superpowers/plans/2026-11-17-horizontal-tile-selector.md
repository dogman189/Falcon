# Horizontal Tile Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the vertical selector cards with horizontal-scrolling client tiles that display bundled cover images.

**Architecture:** Generate and add cover image assets to the asset catalog, expose cover image names from the client model, and refactor `ContentView` selector layout to horizontal tile rows per section while preserving existing selection/import/remove behavior.

**Tech Stack:** SwiftUI, Xcode asset catalog, Python/Pillow (one-time asset generation), xcodebuild.

**Spec:** `docs/superpowers/specs/2026-11-17-horizontal-tile-selector-design.md`

## Global Constraints

- Bundled and Custom remain separate sections; each scrolls horizontally.
- Each tile shows a picture (bundled-specific or generic custom cover).
- No per-custom-client user-selected images; no downloaded third-party artwork.
- Preserve launch, Add Client, remove custom, missing/unavailable, footer, and quit behavior.

## Review Focus

- **Layout/usability:** horizontal rows scroll smoothly in landscape, tiles are tappable, text/badges readable over images.
- **Images:** correct cover shown for each bundled client and generic cover for custom clients in simulator build.
- **Behavior parity:** add/remove/select still work; unavailable clients remain disabled; custom empty state still clear.

---

### Task 1: Add cover assets and model mapping

**Files:**
- Create: image assets in `Falcon/Assets.xcassets/*`
- Modify: `Falcon/BundledClient.swift`

**Interfaces:**
- Produces: each `GameClient` provides a cover image name for UI (bundled clients mapped to specific assets, custom clients mapped to generic custom asset).

- [ ] **Step 1: Generate and add cover images**
  - Create PNG covers for `Eaglet`, `1.8.8-wasm`, `1.21.11-wasm`, and `Custom` and add as named imagesets/assets.
- [ ] **Step 2: Expose cover image name on `GameClient`**
  - Add property (e.g. `coverImageName: String`) with correct mapping for bundled/custom clients.
- [ ] **Step 3: Build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Falcon/Assets.xcassets Falcon/BundledClient.swift docs/superpowers/specs/2026-11-17-horizontal-tile-selector-design.md docs/superpowers/plans/2026-11-17-horizontal-tile-selector.md
git commit -m "feat: add client cover art assets"
```

### Task 2: Horizontal tile selector UI

**Files:**
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: `GameClient` cover image names and existing client/store/actions.
- Produces: horizontal scrolling tile rows for Bundled and Custom sections with image tiles and preserved behaviors.

- [ ] **Step 1: Implement tile view and horizontal sections**
  - Render cover image, name, custom badge/note, and availability state in fixed-size tiles.
  - Use `ScrollView(.horizontal)` per section; keep header, Add Client button, section labels, footer, empty custom state, and remove context menu.
- [ ] **Step 2: Build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Falcon/ContentView.swift
git commit -m "feat: show selector clients as horizontal image tiles"
```