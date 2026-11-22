# reVCDOS Downloadable Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship reVCDOS without bundled game data and let the user download the four `.br` files from the packed archive into app storage for offline play.

**Architecture:** A small Swift parser reads the upstream packed-archive format and copies the four `vcbr/*.br` entries (stored raw) into Application Support. The existing local server's root switches between the bundle and that downloaded directory. The app always launches the local v6 client; no external URLs are loaded.

**Tech Stack:** Swift, Foundation, URLSession, Network.framework, SwiftUI; Xcode 27.2.

**Spec:** `docs/superpowers/specs/2026-11-21-revcdos-download-assets-design.md`

## Global Constraints

- Archive URL: `https://folder.morgen.qzz.io/revcdos.bin` (~1.08 GB, byte-range capable).
- Four asset filenames: `vc-sky-en-v6.data.br`, `vc-sky-en-v6.wasm.br`, `vc-sky-ru-v6.data.br`, `vc-sky-ru-v6.wasm.br`.
- Downloaded asset root: `Application Support/reVCDOS/vcbr/`.
- Success marker: `Application Support/reVCDOS/.assets-ready` written only after all four files exist.
- No CDN streaming; no v16; no `vcsky` extraction.
- Personal/sideload only; no game assets committed.
- Keep v6 client, quit gesture, covers, failure view, and other clients unchanged.

## Review Focus

- **Interrupted download** — expect retry without re-downloading from zero: Task 3 tests resume-data handling and tests that the success marker appears only on complete success.
- **Malformed/truncated archive** — expect a clear failure, not a crash: Task 2 tests ULEB128/format errors.
- **Switching between bundled and downloaded roots** — expect the server to serve from the right place: Task 4 test `testServerRootSelection`.
- **Downloaded assets survive app updates** — expect them in Application Support, not the bundle: Task 1 test.
- **Missing assets on first launch** — expect a download prompt, not a broken game: Task 5 test.

---

## File Structure

- `Falcon/ReVCDOSPackedArchive.swift` (new) — ULEB128 reader + extraction of `vcbr/*.br` entries.
- `Falcon/ReVCDOSAssetStore.swift` (new) — storage paths, completeness check, copy of extracted files, marker.
- `Falcon/ReVCDOSAssetDownloader.swift` (new) — URLSession download with progress, cancel, resume.
- `Falcon/ReVCDOSAssetManifest.swift` (modify) — root URL selection (bundle vs Application Support).
- `Falcon/ReVCDOSHTTPResponder.swift` (modify) — uses selected root (no logic change needed beyond root injection).
- `Falcon/ContentView.swift` (modify) — download sheet, progress, promote downloaded assets.
- `Falcon/BundledClient.swift` (modify) — note about one-time download.
- Delete `Falcon/reVCDOS/vcbr/*.br` and remove them from `project.xcproj` exclusions.
- `tests/revcdos/` (modify) — host tests.
- `README.md` (modify).

---

### Task 1: Asset store paths and completeness

**Files:**
- Create `Falcon/ReVCDOSAssetStore.swift`
- Test `tests/revcdos/asset_store_tests.swift`, modify `main.swift`

**Interfaces:**
- Produces:
  - `enum ReVCDOSAssetStore`
  - `static func rootURL(fileManager: FileManager = .default) -> URL?` — Application Support/reVCDOS
  - `static let assetNames: [String]` — the four filenames
  - `static func isReady(at root: URL, fileManager: FileManager = .default) -> Bool` — marker + four files
  - `static func markReady(at root: URL, fileManager: FileManager = .default) throws`
  - `static func clear(at root: URL, fileManager: FileManager = .default) throws`

- [ ] **Step 1: Write failing tests**

Tests: `isReady` false on empty temp root; `markReady` + four files makes it true; `clear` removes files and marker.

- [ ] **Step 2: Run to verify failure** — compile error, type not found.

- [ ] **Step 3: Implement** with the exact signatures; marker file `.assets-ready`.

- [ ] **Step 4: Run to verify pass** — full host suite `ALL TESTS PASSED`.

- [ ] **Step 5: Commit** — `git commit -m "feat: add reVCDOS downloaded asset store"`

---

### Task 2: Packed archive parser

**Files:**
- Create `Falcon/ReVCDOSPackedArchive.swift`
- Test `tests/revcdos/archive_tests.swift`, modify `main.swift`

**Interfaces:**
- Produces:
  - `enum ReVCDOSPackedArchiveError: Error` (e.g. `truncated`, `unexpectedFolderType`, `unexpectedFileType`)
  - `static func extractVcbrBRFiles(from archiveURL: URL, to destURL: URL, fileManager: FileManager = .default) throws -> [URL]`

- [ ] **Step 1: Write failing tests**

Build a tiny synthetic archive in a temp file with one normal folder `vcbr` containing two `.br` files (raw bytes `DATA1`, `DATA2`) and one `vcsky` file that must be skipped. Assert `extractVcbrBRFiles` returns the two URLs and the files contain the raw bytes. Add a truncated-data test expecting `ReVCDOSPackedArchiveError.truncated`.

Format for the fixture: folder = type byte 0, ULEB128 name length, name bytes, ULEB128 file count; file = ULEB128 name length, name bytes, type byte 0, ULEB128 content length, content bytes.

- [ ] **Step 2: Run to verify failure** — compile error.

- [ ] **Step 3: Implement** a streaming ULEB128 parser reading from `FileHandle`, copying only `vcbr/*.br` entries; skip other folders/files. Throw on truncation or unknown types.

- [ ] **Step 4: Run to verify pass** — full host suite.

- [ ] **Step 5: Commit** — `git commit -m "feat: parse packed archive for vcbr assets"`

---

### Task 3: Downloader with progress and resume

**Files:**
- Create `Falcon/ReVCDOSAssetDownloader.swift`
- Test `tests/revcdos/downloader_tests.swift`, modify `main.swift`

**Interfaces:**
- Consumes: `ReVCDOSPackedArchive.extractVcbrBRFiles`, `ReVCDOSAssetStore`.
- Produces:
  - `final class ReVCDOSAssetDownloader`
  - `init(session: URLSession = .shared, fileManager: FileManager = .default)`
  - `func download(progress: @escaping (Double) -> Void, completion: @escaping (Result<Void, Error>) -> Void)`
  - `func cancel()`
  - `var isDownloading: Bool { get }`

- [ ] **Step 1: Write failing tests**

Use a local HTTP server serving a synthetic archive with the four required `.br` files. Test: successful download leads to `ReVCDOSAssetStore.isReady == true`; cancel leaves `isReady == false`; a second successful call after a failed/cancelled one works. (Resume-data behavior can be asserted via a session stub if practical; otherwise verify via a fresh task that reuses the partial file.)

- [ ] **Step 2: Run to verify failure** — compile error.

- [ ] **Step 3: Implement**: download to a temp file with `URLSessionDownloadTask`, report `totalBytesWritten/totalBytesExpectedToWrite`, on success call the archive parser, copy results into the asset store, write the marker, delete the temp archive. On failure keep resume data for the next attempt and do not write the marker.

- [ ] **Step 4: Run to verify pass** — full host suite.

- [ ] **Step 5: Commit** — `git commit -m "feat: download and extract reVCDOS assets"`

---

### Task 4: Server root selection and bundle slimming

**Files:**
- Modify `Falcon/ReVCDOSAssetManifest.swift`, `Falcon/ReVCDOSLocalServer.swift`, `Falcon/ContentView.swift`, `Falcon.xcodeproj/project.xcproj`
- Delete `Falcon/reVCDOS/vcbr/*.br`, remove their exclusions.

**Interfaces:**
- Consumes: `ReVCDOSAssetStore.isReady`.
- Produces: local server serves downloaded root when ready, bundle root otherwise.

- [ ] **Step 1: Write failing test**

`testServerRootSelection`: `ReVCDOSAssetManifest.serveRoot()` returns the Application Support root when `isReady`, else the bundle root.

- [ ] **Step 2: Run to verify failure** — compile error.

- [ ] **Step 3: Implement**: add `serveRoot()`; `ContentView` starts `ReVCDOSLocalServer(rootURL: manifestServeRoot)`. Remove the four `.br` files from the app bundle and from `project.xcproj` exclusions.

- [ ] **Step 4: Verify** — full host suite + Xcode build; confirm bundle has no `vcbr/`.

- [ ] **Step 5: Commit** — `git commit -m "feat: serve reVCDOS from downloaded assets when available"`

---

### Task 5: Download UI

**Files:**
- Modify `Falcon/ContentView.swift`, `Falcon/BundledClient.swift`

**Interfaces:**
- Consumes: `ReVCDOSAssetDownloader`, `ReVCDOSAssetStore`.

- [ ] **Step 1: Write failing check**

`testDownloadPromptWhenMissing`: selecting reVCDOS with no ready assets shows the download sheet.

- [ ] **Step 2: Run to verify failure**.

- [ ] **Step 3: Implement**: context-menu item "Download full assets…" opens a sheet with a progress bar, Cancel, and explanatory text about the ~1.08 GB archive / WiFi. On success, dismiss and launch. If the user launches reVCDOS before assets are ready, show the same sheet instead of a broken game.

- [ ] **Step 4: Verify** — full suite + build + simulator screenshot.

- [ ] **Step 5: Commit** — `git commit -m "feat: add reVCDOS asset download UI"`

---

### Task 6: Docs and final verification

**Files:**
- Modify `README.md`

- [ ] **Step 1: Document** the small app, one-time download, WiFi recommendation, and personal-use caveat.
- [ ] **Step 2: Run full host suite + build + simulator offline check.**
- [ ] **Step 3: Confirm no game assets tracked by git.**
- [ ] **Step 4: Commit** — `git commit -m "docs: document reVCDOS asset download"`

## Self-Review

- Spec coverage: small bundle (Task 4), download action (Task 3/5), on-device extraction (Task 2), storage (Task 1), offline play (Task 4/6), no CDN/v16/vcsky (global constraints), personal use (Task 6).
- Step scan: every step has one checkable result; synthetic fixtures keep tests small.
- Type consistency: `ReVCDOSAssetStore`, `ReVCDOSPackedArchive.extractVcbrBRFiles`, `ReVCDOSAssetDownloader`, `serveRoot()` used consistently.
- Review Focus: all five items pinned to tests or verification in their tasks.
- Proportion: plan is concise; code blocks only for exact signatures and fixture format.
