# Custom Client Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users import a single `.html` client file, persist it in Falcon, show it in the launcher, and remove it.

**Architecture:** Introduce a unified client model that can represent bundled and custom clients, plus a store that copies imported HTML files into `Application Support/CustomClients` and persists metadata as JSON. `ContentView` loads bundled + custom clients, presents an Add Client Files-picker flow, renders custom clients in a separate section below bundled ones, and supports removing custom clients. `EaglerWebView` continues to load the selected file URL.

**Tech Stack:** SwiftUI, UniformTypeIdentifiers, Foundation/FileManager, JSON persistence, WKWebView, Xcode/xcodebuild.

**Spec:** `docs/superpowers/specs/2026-11-17-custom-client-import-design.md`

## Global Constraints

- Single `.html` file import only via Files picker; copy into private app storage and persist across launches.
- Custom clients are removable (delete copied file and metadata record).
- Do not depend on the original file remaining in place; do not modify bundled clients.
- Custom clients appear in a separate “Custom” section below bundled clients.
- No multi-file/folder clients, URLs/remote clients, or rename/edit UI.

## Review Focus

- **Import/copy reliability:** picking a file copies it into app storage and it remains launchable after the original Files location is unavailable; duplicate names do not overwrite existing custom clients.
- **Persistence/removal:** imported clients reappear after relaunch; removing a custom client deletes its stored file/record and it no longer appears or launches.
- **Bundled behavior preserved:** bundled clients (`Eaglet`, `1.8.8-wasm`, `1.21.11-wasm`) still load as before; custom file URLs load with correct read access; launcher/readability/quit behavior unchanged.

---

### Task 1: Client model and custom client store

**Files:**
- Modify: `Falcon/BundledClient.swift` (or replace with unified client model/types as appropriate)
- Create: `Falcon/CustomClientStore.swift`

**Interfaces:**
- Consumes: existing bundled client definitions (`Eaglet`, `1.8.8-wasm.html`, `1.21.11-wasm.html` resources).
- Produces: a unified client type usable by `ContentView`/`EaglerWebView` with at least `id`, display `name`, launch `url`, optional `note`, and a way to distinguish bundled vs custom (for “Custom” badge/section and removability). `CustomClientStore` provides loading/persisting custom clients and methods to `import(from:)` and `remove(_:)`.

- [ ] **Step 1: Define unified client and metadata**
  - Represent bundled clients and custom clients in a model that exposes `id: String`, `name: String`, `url: URL?`, `note: String?`, and custom/bundled identity (e.g. enum source or flag).
  - Define a Codable metadata record for custom clients (stable id, display name, stored filename).

- [ ] **Step 2: Implement `CustomClientStore`**
  - Store files under Application Support `CustomClients/` and metadata JSON in Application Support (create directories as needed).
  - `load()` returns persisted custom clients whose files exist (ignore/prune missing records as a safe choice).
  - `import(from sourceURL: URL)` security-scopes the picked URL if needed, copies it to a unique destination filename, derives display name from the original filename, persists metadata, and returns the new client.
  - `remove(client)` deletes the stored file and metadata entry.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Falcon/BundledClient.swift Falcon/CustomClientStore.swift
git commit -m "feat: add custom client model and store"
```

### Task 2: Launcher import/remove UI

**Files:**
- Modify: `Falcon/ContentView.swift`
- Modify: `Falcon/EaglerWebView.swift` (only if needed for custom file URL loading; keep behavior otherwise unchanged)

**Interfaces:**
- Consumes: unified client model and `CustomClientStore` from Task 1.
- Produces: launcher shows bundled section and “Custom” section below it, an “Add Client” button that imports a single `.html` via fileImporter, custom cards show a “Custom” label/badge and can be removed, selecting any valid client launches it in `EaglerWebView`.

- [ ] **Step 1: Wire store and client lists into view state**
  - Load bundled clients and persisted custom clients on appear/initialization as appropriate.
  - Keep `selectedClient`/`clientFailure` behavior intact.

- [ ] **Step 2: Update launcher UI**
  - Add an “Add Client” button in the selector (e.g. header/toolbar/section action) that presents `.fileImporter` for HTML files.
  - On successful import, append/save via store and refresh the custom list; on failure, show a simple inline/user-visible error state or log-safe handling without crashing.
  - Render custom clients in a separate section below bundled clients with a visible “Custom” badge/label and a remove action (swipe/context menu) that calls store remove and updates UI.
  - Preserve card styling, notes, disabled-missing behavior, and footer.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Falcon/ContentView.swift Falcon/EaglerWebView.swift docs/superpowers/specs/2026-11-17-custom-client-import-design.md docs/superpowers/plans/2026-11-17-custom-client-import.md
git commit -m "feat: support importing and removing custom clients"
```
