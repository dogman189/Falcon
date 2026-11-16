# Launch Client Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a client selector on every launch listing the three bundled Eaglercraft builds and open the chosen build in the existing immersive `WKWebView` wrapper.

**Architecture:** Bundle `Eaglet.html`, `1.8.8-wasm.html`, and `26.3-wasm.html` as app resources and define a small in-code catalog of bundled clients (display name + bundle file URL). `ContentView` presents a launch list first; selecting a client sets state and renders `EaglerWebView(fileURL:)` full-screen/immersive. No persisted selection (relaunch to switch).

**Tech Stack:** SwiftUI, WebKit (`WKWebView`), Xcode app bundle resources (Falcon, iOS/iPadOS).

**Spec:** `docs/superpowers/specs/2026-11-16-launch-client-selector-design.md`

## Global Constraints

- **Always show client list at launch:** no remembered/auto-opened last client; switching means quit and reopen.
- **Bundled clients only:** package builds from `/Volumes/SSD/Falcon Builds` into the app (`Eaglet.html`, `1.8.8-wasm.html`, `26.3-wasm.html`); no on-device import and no remote URLs.
- **Immersive gameplay surface:** selected client opens in a full-screen, browser-chrome-free `WKWebView` (reuse/tune existing wrapper); no in-game back/overlay UI.
- **WebKit ceiling:** do not claim or attempt to bypass WebKit engine/performance limits.

## Review Focus

- **Large/missing bundled resources:** all three HTML files (including ~65 MB `26.3-wasm.html`) must be present in the app bundle with correct names and load without blank/missing-resource failures.
- **`file://` load access:** `WKWebView` must load each selected file with appropriate read access (e.g. `allowingReadAccessTo` the file’s directory) so the self-contained builds run as intended.
- **Selector → game transition:** tapping a client reliably opens that exact build full-screen; launch always starts at the selector (no unintended persistence).
- **Immersion regressions:** list is fine at launch, but gameplay view must remain free of browser-like scroll/bounce/zoom/selection chrome and safe-area distractions.
- **Name/file mapping:** display names map to the correct bundled filenames (`Eaglet`→`Eaglet.html`, `1.8.8-wasm`→`1.8.8-wasm.html`, `26.3-wasm`→`26.3-wasm.html`) with no swaps.

---

### Task 1: Bundle additional clients and define the client catalog

**Files:**
- Create/Copy: `Falcon/1.8.8-wasm.html` (from `/Volumes/SSD/Falcon Builds/1.8.8-wasm.html`)
- Create/Copy: `Falcon/26.3-wasm.html` (from `/Volumes/SSD/Falcon Builds/26.3-wasm.html`)
- Create: `Falcon/BundledClient.swift`

**Interfaces:**
- Produces: `BundledClient` (identifiable model with `name: String`, `resource: String`, `fileExtension: String` and a computed/resolved bundle `url: URL?`) and `BundledClient.all: [BundledClient]` containing exactly:
  1. `Eaglet` / `Eaglet` / `html`
  2. `1.8.8-wasm` / `1.8.8-wasm` / `html`
  3. `26.3-wasm` / `26.3-wasm` / `html`

- [ ] **Step 1: Copy the additional builds into the app folder**

Run:
```bash
cp "/Volumes/SSD/Falcon Builds/1.8.8-wasm.html" "Falcon/1.8.8-wasm.html"
cp "/Volumes/SSD/Falcon Builds/26.3-wasm.html" "Falcon/26.3-wasm.html"
ls -lh Falcon/Eaglet.html Falcon/1.8.8-wasm.html Falcon/26.3-wasm.html
```
Expected: all three files exist (~2.6M, ~12M, ~65M).

- [ ] **Step 2: Verify copied files are intact (byte sizes)**

Run:
```bash
python3 - <<'PY'
import os
for n in ['Eaglet.html','1.8.8-wasm.html','26.3-wasm.html']:
    p=os.path.join('Falcon',n)
    print(n, os.path.getsize(p))
PY
```
Expected: sizes match sources (2777084, 12907738, 68028922 bytes).

- [ ] **Step 3: Implement `BundledClient` catalog in `Falcon/BundledClient.swift`**

Create `struct BundledClient: Identifiable` with stable `id` (e.g. resource name), `name`, `resource`, `fileExtension = "html"`, `var url: URL? { Bundle.main.url(forResource: resource, withExtension: fileExtension) }`, and static `let all` in the spec order above. Keep it minimal and deterministic.

- [ ] **Step 4: Build to verify catalog compiles**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Falcon/1.8.8-wasm.html Falcon/26.3-wasm.html Falcon/BundledClient.swift
git commit -m "feat: bundle additional clients and add catalog"
```

### Task 2: Generalize the immersive web view to load a selected file

**Files:**
- Modify: `Falcon/EaglerWebView.swift`

**Interfaces:**
- Consumes: a bundle file `URL` for the selected client.
- Produces: `struct EaglerWebView: UIViewRepresentable { let fileURL: URL }` that loads `fileURL` with `loadFileURL(_:allowingReadAccessTo: fileURL.deletingLastPathComponent())` and applies the existing immersive configuration (no scroll/bounce/zoom-bounce/indicators, edge-to-edge insets behavior, opaque black background).

- [ ] **Step 1: Refactor `EaglerWebView` to accept `fileURL: URL`**

Replace hardcoded `Bundle.main.url(forResource: "Eaglet", withExtension: "html")` lookup with the provided `fileURL`. Preserve defensive handling (do not crash if load fails; show/log a clear message in debug) and existing immersive settings.

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED` (or a compile error only until Task 3 updates the call site; if so, complete Task 3’s call-site change in the same working state before re-running build and committing together as specified in Task 3).

- [ ] **Step 3: Commit**

```bash
git add Falcon/EaglerWebView.swift
git commit -m "refactor: load selected bundled client in web view"
```

### Task 3: Add the launch client selector

**Files:**
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: `BundledClient.all` and `BundledClient.url`, and `EaglerWebView(fileURL:)` from Tasks 1–2.
- Produces: launch UI that always shows the client list on open; tapping a client renders `EaglerWebView(fileURL: selectedURL).ignoresSafeArea().background(.black)` full-screen for that session (no persisted selection). Display names: `Eaglet`, `1.8.8-wasm`, `26.3-wasm`.

- [ ] **Step 1: Implement selector state and view in `ContentView`**

Use simple `@State` to hold the selected client/URL. When none selected, show a list of `BundledClient.all` with tappable rows labeled by `client.name`; when selected, show the immersive web view for that client. No navigation chrome/back control over gameplay.

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Falcon/ContentView.swift Falcon/EaglerWebView.swift
git commit -m "feat: add launch client selector"
```
(Include only files actually changed in this commit; if Task 2 was committed separately, add only `ContentView.swift`.)

### Task 4: Runtime verification

**Files:**
- Modify (only if needed): `Falcon/ContentView.swift`, `Falcon/EaglerWebView.swift`, `Falcon/BundledClient.swift`

**Interfaces:**
- Consumes: Tasks 1–3 outputs.
- Produces: verified launch selector and correct per-client immersive loading.

- [ ] **Step 1: Verify launch and selection flow**

Manual checks (simulator/device): app launches to a list showing exactly `Eaglet`, `1.8.8-wasm`, `26.3-wasm`; tapping each opens that corresponding bundled build full-screen with no browser chrome; relaunch returns to the selector (no remembered choice).
Expected: correct mapping and always-show-list behavior.

- [ ] **Step 2: Verify immersion and large-build loading**

Manual checks: no scroll/bounce/zoom/selection distractions during play; large builds (especially `26.3-wasm.html`) load from bundle without missing-resource failure. Note WebKit-bounded performance honestly.
Expected: immersive surface preserved; all bundled clients load.

- [ ] **Step 3: Apply minimal fixes only if verification reveals issues, rebuild, and commit**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
```bash
git add Falcon/ContentView.swift Falcon/EaglerWebView.swift Falcon/BundledClient.swift
git commit -m "fix: adjust client selector runtime behavior"
```
(Only if changes were required.)

## Notes for the implementer
- `1.8.8-wasm.html` and `26.3-wasm.html` are large/obfuscated; copy without reformatting or re-encoding.
- Folder-referenced `Falcon` group in `project.xcproj` should include new files automatically; confirm resource membership if a client fails to load.
- If a specific wasm build misbehaves under `file://`, record the finding; switching to a localhost-serving approach is a separate explicit decision.
