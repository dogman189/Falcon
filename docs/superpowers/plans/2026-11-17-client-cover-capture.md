# Client Cover Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let every client (bundled and custom) use an auto-captured in-game screenshot or a manually selected Photos/Files image as its tile cover, persisted per client.

**Architecture:** Add a `ClientCoverStore` that saves/resolves per-client cover image files in Application Support. `EaglerWebView` exposes a way to take a snapshot of the underlying `WKWebView` so `ContentView` can capture on Quit before returning to the selector. `ContentView` resolves tile images from stored covers with fallback to generated assets, and adds context-menu actions for Photos picker, Files image picker, and reset.

**Tech Stack:** SwiftUI, PhotosUI (`PhotosPicker`), UniformTypeIdentifiers, UIKit/WebKit (`WKWebView.takeSnapshot`, `UIImage`), Foundation/FileManager, Xcode/xcodebuild.

**Spec:** `docs/superpowers/specs/2026-11-17-client-cover-capture-design.md`

## Global Constraints

- Applies to any client (bundled or custom), keyed by stable client id.
- Auto-capture: on Quit tap, snapshot active WebView and save as that client’s cover before returning to selector; if snapshot fails, quit still proceeds and existing cover/default remains.
- Manual: context menu offers “Set Cover from Photos”, “Set Cover from Files” (image), and “Reset Cover” when an override exists.
- Covers persist per client and override default generated art; do not modify bundled client files.
- No galleries/history, cropping/editing UI, sharing, or cloud sync.

## Review Focus

- **Quit capture:** Quit still works even if snapshot fails or returns nil; saved snapshot appears as that client’s tile on next selector render/relaunch.
- **Manual set/reset:** Photos and Files picks save and immediately update the tile; reset removes override and falls back to generated cover.
- **Per-client isolation:** bundled and custom clients each keep their own cover by id; removing a custom client also removes its cover override.
- **UI behavior:** context menu and pickers work from horizontal tiles; existing add/remove/launch/footer/quit behaviors remain intact.

---

### Task 1: Cover storage and resolution

**Files:**
- Create: `Falcon/ClientCoverStore.swift`
- Modify: `Falcon/BundledClient.swift`
- Modify: `Falcon/CustomClientStore.swift`

**Interfaces:**
- Consumes: `GameClient.id`, `GameClient.coverImageName` (default generated asset), image data/`UIImage` from snapshot or pickers.
- Produces: `ClientCoverStore` with APIs to resolve a client’s cover (`stored file URL`/image or default asset name), save image data for a client id, remove cover for a client id, and import from a picked file URL. `CustomClientStore.remove(_:)` also removes the client’s cover.

- [ ] **Step 1: Implement `ClientCoverStore`**
  - Store covers under `Application Support/Covers/` (create directory as needed), one file per client id (sanitized filename), e.g. JPEG.
  - Methods to: `coverURL(for clientID: String) -> URL?`, `save(image: UIImage, for clientID: String) throws`, `import(from url: URL, for clientID: String) throws`, `reset(for clientID: String)`.
  - Replacing overwrites existing cover for that id.

- [ ] **Step 2: Expose cover resolution on `GameClient`**
  - Provide a way for UI to prefer stored cover (file URL/image) over `coverImageName` default (e.g. computed property/method using `ClientCoverStore`).

- [ ] **Step 3: Remove cover when custom client removed**
  - Call `ClientCoverStore.reset(for:)` from `CustomClientStore.remove(_:)`.

- [ ] **Step 4: Build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Falcon/ClientCoverStore.swift Falcon/BundledClient.swift Falcon/CustomClientStore.swift
git commit -m "feat: add per-client cover storage"
```

### Task 2: Auto-capture on Quit

**Files:**
- Modify: `Falcon/EaglerWebView.swift`
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: underlying `WKWebView` snapshot capability, selected `GameClient`.
- Produces: Quit action captures and saves cover for selected client before clearing selection; quit proceeds even on capture failure.

- [ ] **Step 1: Add snapshot support to web view**
  - Allow `ContentView` to request a snapshot of the active `WKWebView` (e.g. binding/coordinator callback/reference) using `takeSnapshot(with:completionHandler:)`.

- [ ] **Step 2: Capture on Quit**
  - Change quit flow to: request snapshot for selected client, save via `ClientCoverStore` when image available, then hide quit/reset state/clear `selectedClient` and `clientFailure` (regardless of snapshot success).

- [ ] **Step 3: Build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Falcon/EaglerWebView.swift Falcon/ContentView.swift
git commit -m "feat: capture client cover on quit"
```

### Task 3: Manual cover set/reset UI

**Files:**
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: `ClientCoverStore` save/import/reset, tile context menus, SwiftUI `PhotosPicker` and file importer for images.
- Produces: each client tile menu offers set-from-Photos, set-from-Files, and reset (when override exists); UI refreshes to show stored cover.

- [ ] **Step 1: Render stored covers in tiles**
  - Load/display stored cover image file when present, else default asset image.

- [ ] **Step 2: Add Photos and Files pickers + reset actions**
  - Track target client for cover editing; present `PhotosPicker` (images) and `.fileImporter` for image types; on selection save via store and refresh state; reset removes override.
  - Keep existing remove-custom action in custom client menus.

- [ ] **Step 3: Build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Falcon/ContentView.swift docs/superpowers/specs/2026-11-17-client-cover-capture-design.md docs/superpowers/plans/2026-11-17-client-cover-capture.md
git commit -m "feat: allow setting and resetting client covers"
```