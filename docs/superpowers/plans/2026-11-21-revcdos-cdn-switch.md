# reVCDOS Asset Source Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fully bundled reVCDOS client with an in-app choice between streaming DOS Zone's live v16 build and downloading its assets to the device for offline play.

**Architecture:** Stream mode points WKWebView at the official v16 page directly. Downloaded mode fetches v16's assets into Application Support and serves them through the existing `localhost:8199` responder. An `AssetSource` enum in UserDefaults drives which URL the web view loads; the local server only starts in downloaded mode.

**Tech Stack:** SwiftUI, WebKit, Network.framework, Foundation, URLSession; Xcode 27.2 JSON project.

**Spec:** `docs/superpowers/specs/2026-11-21-revcdos-cdn-switch-design.md`

## Global Constraints

- Stream URL: `https://dos.zone/vcsky/release/v16/?wasm=https://br.cdn.dos.zone/vcsky/v16.wasm.br`
- Downloaded assets root: `Application Support/reVCDOS/vcsky/` (never in the app bundle).
- Default source: `.stream`.
- The app must ship without `Falcon/reVCDOS/vcbr/*.br` (~122 MB removal).
- Personal/sideload only; no asset files committed.
- Keep swipe-to-quit, cover snapshot, failure view, and other clients unchanged.

## Review Focus

- **Stream mode with no internet** — expect the existing failure screen, not a blank page: Task 3 tests the navigation-failure path.
- **Switching from downloaded to stream with assets still on disk** — expect stream mode to ignore them: Task 2 test `testAssetSourceDrivesURL`.
- **Interrupted download** — expect resumable/restartable download and no half-complete "downloaded" state: Task 5 test `testDownloadMarkerOnlyOnSuccess`.
- **Switching to downloaded before assets exist** — expect the UI to show download progress, not a broken game: Task 4 test `testDownloadedModeRequiresAssets`.
- **Removing the bundled `.br` files** — expect the app still builds and the old pre-flight no longer requires them: Task 3 build + test.

---

## File Structure

- `Falcon/ReVCDOSAssetSource.swift` (new) — enum, UserDefaults persistence, URLs, asset-root path, completeness check.
- `Falcon/ReVCDOSAssetDownloader.swift` (new) — URLSession download of v16 assets into Application Support with progress and a success marker.
- `Falcon/ReVCDOSLocalServer.swift` (modify) — root URL supplied by asset source.
- `Falcon/BundledClient.swift` (modify) — stream URL, note, no bundled `.br` requirement.
- `Falcon/EaglerWebView.swift` (modify) — `.remote(URL)` content case.
- `Falcon/ContentView.swift` (modify) — source selection sheet, download progress, server lifecycle.
- `Falcon.xcodeproj/project.xcproj` (modify) — remove vcsky copy phase and setting from prior feature.
- `tests/revcdos/` (modify) — host tests.
- `README.md`, design/plan docs.

---

### Task 1: Discovery spike (throwaway, nothing ships)

**Files:**
- Scratch only, under the plan workspace.

**Interfaces:**
- Produces: a written findings note with the exact v16 asset URL pattern, total asset count/size, and whether WKWebView boots the official page and reaches the game.

- [ ] **Step 1: Build a temporary WebKit harness**

Write a throwaway macOS Swift script using WKWebView, registering a `URLProtocol` subclass that logs every `https` request. Load the stream URL from Global Constraints. After `didFinish`, call `evaluateJavaScript("document.getElementById('click-to-play-button').click()")`.

- [ ] **Step 2: Run and capture**

Run the script for up to 120 seconds; save all logged request URLs to the workspace. Expected: the log contains the v16 asset URL pattern (the ~2008 files from `preload_files.list`), and a screenshot/console confirms the game starts.

- [ ] **Step 3: Write findings and decision**

Record: base URL pattern, whether assets are individual files or a packed/range-requested file, total size, and any headers the CDN requires. If the page cannot boot or URLs cannot be discovered, STOP and report to the human partner — do not proceed to Task 5.

- [ ] **Step 4: No commit**

This task produces no repository changes.

---

### Task 2: Asset source model

**Files:**
- Create `Falcon/ReVCDOSAssetSource.swift`
- Test `tests/revcdos/asset_source_tests.swift`, modify `tests/revcdos/main.swift`

**Interfaces:**
- Produces:
  - `enum ReVCDOSAssetSource: String` with cases `.stream`, `.downloaded`
  - `static var current: ReVCDOSAssetSource` (UserDefaults backed, default `.stream`)
  - `static func setCurrent(_:)`
  - `var launchURL: URL` — stream URL for `.stream`; local server URL for `.downloaded`
  - `static var downloadedRootURL: URL?` — Application Support/reVCDOS/vcsky
  - `static func downloadedAssetsReady() -> Bool` — marker file present

- [ ] **Step 1: Write failing tests**

Tests: default is `.stream`; `setCurrent(.downloaded)` persists; `.stream.launchURL` equals the exact stream URL; `.downloaded.launchURL` equals `ReVCDOSAssetManifest.launchURL`; `downloadedAssetsReady()` is false with no marker.

- [ ] **Step 2: Run to verify failure**

Full host suite compile with the new file. Expected: compile error, type not found.

- [ ] **Step 3: Implement the model**

Use `UserDefaults.standard.string(forKey: "revcdos.assetSource")`. Apply task 1 findings only to the downloader, not this model.

- [ ] **Step 4: Run to verify pass**

Full host suite. Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

`git commit -m "feat: add reVCDOS asset source model"`

---

### Task 3: Stream mode and bundle slimming

**Files:**
- Modify `Falcon/BundledClient.swift`, `Falcon/EaglerWebView.swift`, `Falcon/ReVCDOSAssetManifest.swift`, `Falcon/ReVCDOSLaunchPreflight.swift`, `Falcon.xcodeproj/project.xcproj`
- Delete `Falcon/reVCDOS/vcbr/*.br` and the vcsky build phase from the prior feature.

**Interfaces:**
- Consumes: `ReVCDOSAssetSource.current.launchURL`.
- Produces: `FalconWebContent.remote(URL)`; reVCDOS tile launches without requiring local `.br` files.

- [ ] **Step 1: Write failing test**

`testStreamModeNeedsNoLocalAssets`: pre-flight for `.stream` succeeds with an empty bundle root; pre-flight for `.downloaded` fails.

- [ ] **Step 2: Run to verify failure** — expected compile/assertion failure.

- [ ] **Step 3: Implement**

Add `.remote(URL)` to `FalconWebContent` and load it with `URLRequest`. Remove the `.br` paths from `requiredRelativePaths`; in `ContentView`, only start the local server when source is `.downloaded`. Delete the four `.br` files and the vcsky build setting/phase from `project.xcproj`.

- [ ] **Step 4: Verify** — full host suite + Xcode build; confirm app bundle has no `vcbr/` or bundled `vcsky/`.

- [ ] **Step 5: Commit** — `git commit -m "feat: stream reVCDOS from CDN by default"`

---

### Task 4: In-app switch UI

**Files:**
- Modify `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: `ReVCDOSAssetSource`, downloader progress.

- [ ] **Step 1: Write failing check**

A host-side test `testDownloadedModeRequiresAssets`: selecting `.downloaded` when assets are not ready presents the download UI, not the game.

- [ ] **Step 2: Run to verify failure**.

- [ ] **Step 3: Implement**

Add a context-menu item on the reVCDOS tile, "Asset Source…", opening a sheet with two options and a "Download full assets" button. Show progress from the downloader. On success, set source `.downloaded`; allow switching back to `.stream` at any time.

- [ ] **Step 4: Verify** — full suite + build + simulator screenshot of the sheet.

- [ ] **Step 5: Commit** — `git commit -m "feat: add reVCDOS asset source switch"`

---

### Task 5: Asset downloader

**Files:**
- Create `Falcon/ReVCDOSAssetDownloader.swift`
- Test `tests/revcdos/download_tests.swift`

**Interfaces:**
- Consumes: Task 1 findings (URL pattern) and `ReVCDOSAssetSource.downloadedRootURL`.
- Produces: `final class ReVCDOSAssetDownloader` with `func download(progress: @escaping (Double) -> Void, completion: @escaping (Result<Void, Error>) -> Void)`, `func cancel()`, and a static success-marker filename.

- [ ] **Step 1: Write failing test**

`testDownloadMarkerOnlyOnSuccess`: simulate a failing download and assert no marker is created; simulate success and assert marker exists.

- [ ] **Step 2: Run to verify failure** — expected compile error.

- [ ] **Step 3: Implement**

Use URLSession download tasks against the URLs discovered in Task 1, writing into Application Support/reVCDOS/vcsky. Write the success marker only after all files finish. Use `FileManager` helpers so the test can point at a temp root.

- [ ] **Step 4: Run to verify pass** — full host suite.

- [ ] **Step 5: Commit** — `git commit -m "feat: download reVCDOS assets for offline play"`

---

### Task 6: Docs and final verification

**Files:**
- Modify `README.md`

- [ ] **Step 1: Document both modes** and the personal-use caveat.
- [ ] **Step 2: Run full host suite + build + simulator checks for both modes.**
- [ ] **Step 3: Confirm no large assets are tracked by git.**
- [ ] **Step 4: Commit** — `git commit -m "docs: document reVCDOS asset source switch"`

## Self-Review

- Spec coverage: switch (Task 4), stream via official v16 URL (Task 3), downloaded mode (Tasks 2 and 5), small app (Task 3), reused local server (Task 3), personal use (Task 6), superseded build toggle removed (Task 3).
- Step scan: each step has one checkable result; Task 1's spike is a deliberate discovery gate.
- Type consistency: `ReVCDOSAssetSource`, `FalconWebContent.remote`, `ReVCDOSAssetDownloader` used consistently.
- Review Focus: all five items pinned to tests or verification in their tasks.
- Proportion: code blocks appear only for exact URLs and test names.
