# Wikipedia Game Covers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-fetch game tile covers from Wikipedia by game name, cache them locally, and let users search/pick or replace covers manually.

**Architecture:** Extend `ClientCoverStore` into two layers (manual override, auto-fetched) with legacy root-cover compatibility. Add a small `WikipediaCoverService` for keyless Wikipedia search/thumbnail download and a `GameCoverSearchName` mapping for curated bundled names. Wire auto-fetch on library load and client addition in `ContentView`, and add a "Search Cover Online..." sheet from the tile menu.

**Tech Stack:** SwiftUI, Foundation/URLSession, XCTest-free standalone Swift test harnesses (`swiftc`), Xcode build for app verification.

**Spec:** `docs/superpowers/specs/2026-11-24-wikipedia-game-covers-design.md`

## Global Constraints

- No API keys or paid cover services; use keyless Wikipedia/Wikimedia APIs.
- Cover resolution order: manual override → auto-fetched cover → built-in `defaultCoverImageName` asset.
- "Reset Cover" removes only the manual layer; auto-fetched cover remains. Built-in art is fallback only when no manual or auto cover exists.
- Auto-fetch on library load for clients missing manual+auto cover, and on client add/import; never overwrite a manual cover.
- Existing `Application Support/Covers/<sanitized>.<ext>` legacy files must continue to work as manual covers.
- Network failures are non-fatal; keep built-in/default/current cover and do not block UI.
- Wikipedia requests must send a descriptive `User-Agent` and use small result limits.

## Review Focus

- **Legacy cover migration:** a cover file already at `Covers/<id>.jpg` (pre-feature layout) is treated as manual, shows as manual override, and Reset removes it revealing auto/built-in as specified.
- **Manual vs auto precedence:** auto-fetch never replaces a manual cover (including quit snapshot, Photos, Files, online pick); manual search pick overwrites previous manual but does not delete auto cache.
- **Remove vs reset semantics:** removing a custom client deletes both manual and auto covers; UI Reset removes only manual.
- **Duplicate fetches / UI churn:** library reloads do not spawn unbounded duplicate Wikipedia requests per client; cover updates refresh tiles after save.
- **Ambiguous/missing names:** empty/odd client names or Wikipedia no-result responses fall back cleanly to built-in art with no crash.

---

## File Structure

- Modify: `Falcon/ClientCoverStore.swift` — manual/auto cover layers, legacy root compatibility, explicit manual/auto/all removal APIs.
- Modify: `Falcon/BundledClient.swift` — expose curated internet cover search name.
- Create: `Falcon/WikipediaCoverService.swift` — Wikipedia search result model, response parsing, best-match selection, thumbnail download.
- Create: `Falcon/CoverSearchSheet.swift` — SwiftUI sheet for searching and picking an online cover.
- Modify: `Falcon/ContentView.swift` — auto-fetch triggers, search sheet state, cover menu wiring, refresh after auto save.
- Modify: `Falcon/LibraryView.swift` — add "Search Cover Online..." menu action callback.
- Modify: `Falcon/CustomClientStore.swift` — remove all covers (manual+auto) on client removal.
- Test: `tests/library/cover_store_tests.swift` — cover store layering/legacy/reset semantics.
- Test: `tests/library/wikipedia_cover_service_tests.swift` — search term mapping, response parsing, best-match selection.
- Modify: `tests/library/main.swift` — register new tests.
- Modify: `tests/library/stubs.swift` — only if needed by compile set; keep existing stub behavior intact.
- Modify: `tests/retropacker/stubs.swift`, `tests/revcdos/stubs.swift` — add any new `ClientCoverStore` methods used by compiled production code if those suites compile against stubs.

---

### Task 1: ClientCoverStore Manual/Auto Layers

**Files:**
- Modify: `Falcon/ClientCoverStore.swift`
- Modify: `Falcon/CustomClientStore.swift:171`
- Test: `tests/library/cover_store_tests.swift`
- Modify: `tests/library/main.swift`

**Interfaces:**
- Consumes: `clientID: String`, `UIImage`/`Data`/file URL; file system under Application Support `Covers/`.
- Produces:
  - `func manualCoverURL(for clientID: String) -> URL?`
  - `func autoCoverURL(for clientID: String) -> URL?`
  - `func coverURL(for clientID: String) -> URL?` // resolves manual ?? auto ?? legacy manual
  - `func hasManualCover(for clientID: String) -> Bool`
  - `func saveManual(data: Data, fileExtension: String, for clientID: String) throws`
  - `func saveManual(image: UIImage, for clientID: String) throws` (UIKit convenience wrapper)
  - `func importManualCover(from sourceURL: URL, for clientID: String) throws`
  - `func saveAuto(data: Data, fileExtension: String, for clientID: String) throws`
  - `func saveAuto(image: UIImage, for clientID: String) throws` (UIKit convenience wrapper)
  - `func resetManualCover(for clientID: String)`
  - `func removeAllCovers(for clientID: String)`
  - Keep `save(image:for:)`, `importCover(from:for:)`, `reset(for:)` as compatibility wrappers: save/import -> manual, reset -> removeAll.

- [ ] **Step 1: Write failing cover store tests**

Create `tests/library/cover_store_tests.swift` with tests using a temp base directory injected into `ClientCoverStore(fileManager:baseDirectoryURL:)` (add this initializer if missing; keep `shared`).

```swift
func testCoverStorePrefersManualOverAuto() throws
func testCoverStoreFallsBackToAutoWhenNoManual() throws
func testLegacyRootCoverIsTreatedAsManual() throws
func testResetManualCoverKeepsAuto() throws
func testRemoveAllCoversDeletesManualAndAuto() throws
```

Pin exact behavior:
- Save auto image/data for id -> `autoCoverURL != nil`, `coverURL == autoCoverURL`, `hasManualCover == false`.
- Save manual -> `coverURL == manualCoverURL`.
- Legacy file written at `base/<sanitized>.jpg` -> `hasManualCover == true`, `coverURL` resolves it.
- `resetManualCover` removes manual/legacy manual, keeps auto.
- `removeAllCovers` removes manual, auto, and legacy root file.

- [ ] **Step 2: Register tests and run to verify they fail**

Add the five functions to `tests/library/main.swift`. Create `tests/library/cover_store_tests.swift` using only Foundation/Data APIs (no UIKit) so tests run with macOS `swiftc`.

Run:
```bash
swiftc -swift-version 5 -g -o /tmp/falcon-library-tests \
  Falcon/BundledClient.swift \
  Falcon/RetroPacker/RetroSystemCatalog.swift \
  Falcon/ClientLibraryMetadataStore.swift \
  Falcon/LibraryShelf.swift \
  Falcon/ClientCoverStore.swift \
  tests/library/revcdos_manifest_stub.swift \
  tests/library/metadata_store_tests.swift \
  tests/library/shelf_tests.swift \
  tests/library/cover_store_tests.swift \
  tests/library/main.swift
/tmp/falcon-library-tests
```
Expected: FAIL (missing new APIs / wrong semantics). Note: this command compiles the real `ClientCoverStore.swift` instead of `tests/library/stubs.swift`; because `ClientCoverStore` currently imports UIKit, Step 3 must guard UIKit-only members with `#if canImport(UIKit)` and keep Data-based APIs available on macOS.

- [ ] **Step 3: Implement manual/auto layering in `ClientCoverStore`**

Implement:
- Add `init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil)`; `shared` uses default.
- Base layout: `<base>/manual/` and `<base>/auto/`; ensure directories on save.
- Guard UIKit-only imports/APIs (`import UIKit`, `UIImage` methods) with `#if canImport(UIKit)` so Data/path APIs compile in macOS `swiftc` tests.
- `manualCoverURL` checks `manual/` first, then legacy root `<base>/<sanitized>.<ext>` for compatibility.
- `autoCoverURL` checks `auto/`.
- `coverURL` returns `manualCoverURL ?? autoCoverURL`.
- `hasManualCover` true if manual or legacy root exists.
- `saveManual(data:fileExtension:for:)` / `importManualCover` write to `manual/`, removing previous manual+legacy files for that id. `saveManual(image:...)` wraps data API under UIKit guard.
- `saveAuto(data:fileExtension:for:)` writes to `auto/`, removing previous auto files for that id only. `saveAuto(image:...)` wraps data API under UIKit guard.
- `resetManualCover` removes manual+legacy only. `removeAllCovers` removes manual+legacy+auto.
- Keep old `save/importCover/reset` wrappers calling new methods for source compatibility (`reset` remains remove-all for deletion callers).

- [ ] **Step 4: Update CustomClientStore removal**

In `Falcon/CustomClientStore.swift`, change `ClientCoverStore.shared.reset(for: client.id)` to `ClientCoverStore.shared.removeAllCovers(for: client.id)`.

- [ ] **Step 5: Run tests to verify they pass**

Run the same `swiftc` command as Step 2.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add Falcon/ClientCoverStore.swift Falcon/CustomClientStore.swift tests/library/cover_store_tests.swift tests/library/main.swift
git commit -m "feat: add manual and auto cover layers"
```

---

### Task 2: Search Name Mapping and Wikipedia Parsing

**Files:**
- Modify: `Falcon/BundledClient.swift`
- Create: `Falcon/WikipediaCoverService.swift`
- Test: `tests/library/wikipedia_cover_service_tests.swift`
- Modify: `tests/library/main.swift`

**Interfaces:**
- Produces on `GameClient`:
  - `var coverSearchName: String { get }` — curated for bundled, trimmed `name` for custom.
- Produces in `WikipediaCoverService.swift`:
  - `struct WikipediaCoverCandidate: Equatable, Sendable { let title: String; let description: String?; let thumbnailURL: URL }`
  - `enum WikipediaCoverServiceError: Error, Equatable { case invalidResponse; case noResults }`
  - `protocol WikipediaCoverFetching: Sendable { func data(from url: URL) async throws -> (Data, URLResponse) }`
  - `struct WikipediaCoverService: Sendable { init(fetcher: any WikipediaCoverFetching = URLSession.shared); func search(term: String, limit: Int = 8) async throws -> [WikipediaCoverCandidate]; func bestCandidate(for term: String) async throws -> WikipediaCoverCandidate }`
  - Parsing/best-match helpers should be `static`/internal-visible-for-tests as needed (e.g. `static func parseSearchResults(data: Data) throws -> [WikipediaCoverCandidate]`, `static func bestCandidate(from candidates: [WikipediaCoverCandidate], term: String) -> WikipediaCoverCandidate?`).

- [ ] **Step 1: Write failing tests**

Create `tests/library/wikipedia_cover_service_tests.swift`:

```swift
func testBundledCoverSearchNamesAreCurated() throws
func testCustomCoverSearchNameFallsBackToTrimmedName() throws
func testWikipediaParseSearchResultsReturnsThumbnailCandidates() throws
func testWikipediaBestCandidatePrefersFirstThumbnailResult() throws
```

Pin values:
- `bundled:1.8.8-wasm` -> `"Minecraft Java Edition"` (or the exact curated string you implement; keep consistent in one place).
- `bundled:reVCDOS` -> `"Grand Theft Auto: Vice City"`.
- Custom client named `"  My Game  "` -> `"My Game"`.
- Fixture JSON with two pages, one missing thumbnail -> returns only page with thumbnail.
- Best candidate from non-empty candidates returns first reasonable candidate deterministically.

- [ ] **Step 2: Register tests and run to verify they fail**

Add four functions to `tests/library/main.swift`.

Run:
```bash
swiftc -swift-version 5 -g -o /tmp/falcon-library-tests \
  Falcon/BundledClient.swift \
  Falcon/RetroPacker/RetroSystemCatalog.swift \
  Falcon/ClientLibraryMetadataStore.swift \
  Falcon/LibraryShelf.swift \
  Falcon/ClientCoverStore.swift \
  Falcon/WikipediaCoverService.swift \
  tests/library/revcdos_manifest_stub.swift \
  tests/library/metadata_store_tests.swift \
  tests/library/shelf_tests.swift \
  tests/library/cover_store_tests.swift \
  tests/library/wikipedia_cover_service_tests.swift \
  tests/library/main.swift
/tmp/falcon-library-tests
```
Expected: FAIL (missing `coverSearchName` / service).

- [ ] **Step 3: Implement search name mapping**

In `Falcon/BundledClient.swift`, add:

```swift
var coverSearchName: String {
    switch id {
    case "bundled:1.8.8-wasm": return "Minecraft"
    case "bundled:reVCDOS": return "Grand Theft Auto: Vice City"
    default: return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

Use exact curated strings decided here and pin them in tests. (If you choose "Minecraft Java Edition", use it in both code and tests.)

- [ ] **Step 4: Implement `WikipediaCoverService`**

In `Falcon/WikipediaCoverService.swift`:
- Build search URL with `URLComponents`: `action=query`, `generator=search`, `gsrsearch=<term>`, `gsrlimit=<limit>`, `prop=pageimages|description`, `pithumbsize=600`, `format=json`, `origin=*`.
- Add `User-Agent` (e.g. `Falcon-iOS/1.0 (cover lookup)`) on requests.
- Parse JSON shape: `query.pages` dictionary values; map entries with `thumbnail.source` URL into `WikipediaCoverCandidate`.
- `bestCandidate(for:)` returns `bestCandidate(from:term:)` or throws `.noResults`.
- Keep parsing deterministic: sort by page index if present, else stable title order.
- Add `URLSession` conformance to `WikipediaCoverFetching` in same file or a small extension.

- [ ] **Step 5: Run tests to verify they pass**

Run the Step 2 command.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add Falcon/BundledClient.swift Falcon/WikipediaCoverService.swift tests/library/wikipedia_cover_service_tests.swift tests/library/main.swift
git commit -m "feat: add wikipedia cover search service"
```

---

### Task 3: Auto-Fetch Wiring in ContentView

**Files:**
- Modify: `Falcon/ContentView.swift`
- Modify: `Falcon/CustomClientStore.swift` (no behavior change expected; verify)
- Test: build verification (no UI test harness in repo)

**Interfaces:**
- Consumes: `GameClient.coverSearchName`, `WikipediaCoverService.bestCandidate(for:)`, `WikipediaCoverService` image download, `ClientCoverStore.hasManualCover`, `autoCoverURL`, `saveAuto`.
- Produces: background auto-fetch on library load and after import/add; `coverRevision` increment after successful auto save; no overwrite of manual covers.

- [ ] **Step 1: Add auto-fetch state/helpers in `ContentView`**

Add state:
```swift
@State private var autoCoverFetchIDs: Set<String> = []
private let coverService = WikipediaCoverService()
```

Add helpers:
- `func autoFetchMissingCovers(for clients: [GameClient])`
- `func autoFetchCoverIfNeeded(for client: GameClient)`
- `func fetchAutoCover(for client: GameClient) async` — guard not manual, not already auto, not in-flight; search best candidate; download thumbnail; `try? ClientCoverStore.shared.saveAuto(...)`; on main actor increment `coverRevision`.

- [ ] **Step 2: Trigger auto-fetch on load and add**

- In `.task` after `loadClients()`, call `autoFetchMissingCovers(for: GameClient.bundled + customClients)`.
- In `loadClients()`, after updating `customClients`, trigger auto-fetch for current clients.
- In `handleImport` success path, after `loadClients()`, fetch for the imported client if convenient (loadClients already covers it).
- In retro packer `onImported` callback, `loadClients()` already called; ensure it triggers auto-fetch.

- [ ] **Step 3: Add image download helper**

In `WikipediaCoverService`, add:
```swift
func downloadImageData(from url: URL) async throws -> Data
```
Use fetcher/data(from:) and validate HTTP 200 + non-empty data.

- [ ] **Step 4: Build verify**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Falcon/ContentView.swift Falcon/WikipediaCoverService.swift
git commit -m "feat: auto-fetch wikipedia covers for library clients"
```

---

### Task 4: Search Cover Online Sheet and Menu Wiring

**Files:**
- Create: `Falcon/CoverSearchSheet.swift`
- Modify: `Falcon/LibraryView.swift`
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- `LibraryView` gains `@ViewBuilder let coverMenuItems: (GameClient) -> AnyView` already exists; add a new callback for online search, e.g. `let onSearchCoverOnline: (GameClient) -> Void`, or include action via `coverMenuItems` closure from ContentView. Prefer adding explicit callback `let onSearchCoverOnline: (GameClient) -> Void` and render menu item in `LibraryView` near other cover actions for consistency.
- `CoverSearchSheet`:
  - `init(client: GameClient, service: WikipediaCoverService, onPick: @escaping (WikipediaCoverCandidate) -> Void)`
  - loads candidates by `client.coverSearchName`; allows editing query and searching again.
- `ContentView` presents sheet and, on pick, downloads image and saves via `ClientCoverStore.shared.saveManual(...)`, increments `coverRevision`.

- [ ] **Step 1: Add failing/compile-first UI wiring**

Add `onSearchCoverOnline` parameter to `LibraryView` and pass from `ContentView`. Add menu item:

```swift
Button {
    onSearchCoverOnline(client)
} label: {
    Label("Search Cover Online...", systemImage: "globe")
}
```

Show above Photos/Files/Reset or in a sensible order; keep existing actions.

- [ ] **Step 2: Implement `CoverSearchSheet`**

Create `Falcon/CoverSearchSheet.swift` with a simple searchable sheet:
- `@State query` initialized from `client.coverSearchName`.
- `@State results: [WikipediaCoverCandidate] = []`, loading/error states.
- `.task` performs initial search.
- Results list/grid: thumbnail `AsyncImage`, title, description.
- On tap: call `onPick(candidate)`.

Keep it plain SwiftUI and accessible. No cropping/editing.

- [ ] **Step 3: Wire sheet presentation and manual save in `ContentView`**

Add state:
```swift
@State private var coverSearchClient: GameClient?
```

Present sheet when non-nil. On pick:
- download image data via `WikipediaCoverService.downloadImageData`.
- save as manual: `try ClientCoverStore.shared.saveAuto/Manual`? Use `saveManual` path; if service gives data, add `ClientCoverStore.saveManual(data:fileExtension:for:)` or convert to UIImage. Prefer adding `saveManual(data:fileExtension:for:)` in `ClientCoverStore` for JPEG/PNG data.
- set `coverRevision += 1`; dismiss sheet.

Update Reset menu visibility to `ClientCoverStore.shared.hasManualCover(for: client.id)`.

- [ ] **Step 4: Build verify**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Falcon/CoverSearchSheet.swift Falcon/LibraryView.swift Falcon/ContentView.swift Falcon/ClientCoverStore.swift
git commit -m "feat: add online cover search and manual override flow"
```

---

### Task 5: Final Verification and Cleanup

**Files:**
- Modify: `tests/library/main.swift` (only if missed)
- Modify: any stubs required by compile (`tests/retropacker/stubs.swift`, `tests/revcdos/stubs.swift`) if API drift breaks their swiftc suites.

- [ ] **Step 1: Run library tests**

Run:
```bash
swiftc -swift-version 5 -g -o /tmp/falcon-library-tests \
  Falcon/BundledClient.swift \
  Falcon/RetroPacker/RetroSystemCatalog.swift \
  Falcon/ClientLibraryMetadataStore.swift \
  Falcon/LibraryShelf.swift \
  Falcon/ClientCoverStore.swift \
  Falcon/WikipediaCoverService.swift \
  tests/library/revcdos_manifest_stub.swift \
  tests/library/metadata_store_tests.swift \
  tests/library/shelf_tests.swift \
  tests/library/cover_store_tests.swift \
  tests/library/wikipedia_cover_service_tests.swift \
  tests/library/main.swift
/tmp/falcon-library-tests
```
Expected: `ALL TESTS PASSED`. (Uses real `ClientCoverStore.swift`; do not include `tests/library/stubs.swift` in this command.)

- [ ] **Step 2: Run retropacker tests (regression)**

Run:
```bash
swiftc -swift-version 5 -g -o /tmp/falcon-retropacker-tests \
  Falcon/BundledClient.swift \
  Falcon/CustomClientStore.swift \
  Falcon/ClientLibraryMetadataStore.swift \
  Falcon/RetroPacker/RetroSystemCatalog.swift \
  Falcon/RetroPacker/RetroPackRequest.swift \
  tests/retropacker/stubs.swift \
  tests/retropacker/catalog_tests.swift \
  tests/retropacker/bridge_message_tests.swift \
  tests/retropacker/store_tests.swift \
  tests/retropacker/main.swift
/tmp/falcon-retropacker-tests
```
Expected: `ALL TESTS PASSED`. If stub API mismatch occurs because `ClientCoverStore` gained methods referenced by compiled code, update `tests/retropacker/stubs.swift` minimally.

- [ ] **Step 3: Run app build**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke checklist (report results)**

- Launch app on simulator/device: bundled tiles fetch/show internet covers after load (or fall back gracefully).
- Add/import a custom client: auto-fetch triggers for it.
- Open tile menu → Search Cover Online: search, pick result, tile updates.
- Reset Cover: manual pick removed, auto-fetched cover returns.
- Photos/Files cover set still works and overrides auto.
- Remove custom client: no crash; re-add does not show stale cover unexpectedly.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add wikipedia cover lookup for game tiles"
```

(If work was committed in prior tasks, only commit remaining verification/stub fixes.)