# Wikipedia Game Covers Design

**Approved:** 2026-11-24

## Intent

Give every game tile a cover image pulled from the internet by searching the game’s name, while keeping covers easy to change.

## Goals

- Auto-fetch an internet cover for each client by searching its game name.
- Auto-pick the best match and apply it without blocking the library UI.
- Fetch when the library loads for clients missing an auto cover, and when a client is added/imported to the library.
- Let the user change a cover later via an online search/pick UI, while keeping existing Photos/Files cover options.
- “Reset Cover” returns to the auto-found internet cover; built-in Falcon art is only the fallback when no internet cover exists.

## Non-goals / Anti-goals

- No API keys or paid cover services.
- No background sync beyond simple on-demand fetches; no cloud storage.
- No guarantee of perfect matches for ambiguous custom client names (Wikipedia is best-effort).
- No cropping/editing UI.

## Current State

- `Falcon/GameCard.swift` renders tile covers; `Falcon/HeroHeaderView.swift` renders the featured hero cover.
- `Falcon/ContentView.swift` resolves covers via `coverImage(for:)`: stored `ClientCoverStore` cover if present, else `client.defaultCoverImageName`.
- `Falcon/ClientCoverStore.swift` stores one cover per client id in `Application Support/Covers/<sanitized>.<ext>`.
- `Falcon/BundledClient.swift` provides `defaultCoverImageName` and bundled client ids/names.
- Tile context menu already supports Set Cover from Photos, Set Cover from Files, and Reset Cover. Quit captures a WebView snapshot as the cover.

## Approaches

### 1. SteamGridDB covers (not chosen)

Use SteamGridDB’s API to search and download game grid art. Best quality and purpose-built for game covers. Tradeoff: requires a free API key and key management.

### 2. Keyless Wikipedia/Wikimedia lookup (chosen)

Use Wikipedia/Wikimedia public APIs to search game pages and fetch page thumbnail images. No API key. Tradeoff: match quality/coverage is inconsistent, especially for ambiguous names; thumbnails may not always be ideal box art.

**Picked:** Approach 2, per user choice, accepting best-effort match quality for a keyless solution.

## Design

### Cover resolution model

Resolution order for a displayed tile cover:

1. **Manual cover** - explicitly set by user (Photos, Files, online search pick, or existing quit-snapshot/manual saves).
2. **Auto cover** - internet cover fetched automatically by name.
3. **Built-in default** - `client.defaultCoverImageName` asset.

`ClientCoverStore` gains two logical layers:

- `Covers/manual/<sanitized>.<ext>` - manual overrides.
- `Covers/auto/<sanitized>.<ext>` - auto-fetched internet covers.

Compatibility: existing files currently stored directly in `Covers/<sanitized>.<ext>` are treated as **manual** covers. The store should read legacy root files as manual and, when convenient, write new manual covers into `Covers/manual/`. Reset removes only the manual layer for that client.

### Search name mapping

Provide a search term for each client:

- `bundled:1.8.8-wasm` → `Minecraft Java Edition`
- `bundled:reVCDOS` → `Grand Theft Auto: Vice City`
- Custom/packed clients → `client.name` (trimmed). Future: if library metadata contains a better game title, prefer it.

The mapping lives in a small dedicated helper/type so bundled mappings are explicit and testable.

### Wikipedia cover service

Add a small service, e.g. `WikipediaCoverService`, responsible for:

- **Search:** query Wikimedia API for candidate pages with thumbnails.
  - Endpoint shape: `https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=<term>&gsrlimit=8&prop=pageimages|description&pithumbsize=600&format=json&origin=*`
  - Parse pages with `thumbnail.source`.
- **Auto-pick:** choose the first reasonable result with a thumbnail. Prefer results whose title/description look game-related when possible; otherwise first thumbnail result.
- **Download:** fetch image data via URLSession and store through `ClientCoverStore` as an auto cover.
- **Manual search:** return candidate results (title, description, thumbnail URL/full image URL) for the search sheet.

Requests include a descriptive `User-Agent` header. Network failures are non-fatal; UI falls back to built-in art.

### Auto-fetch behavior

- On library load / client list change, identify clients missing a manual cover and missing an auto cover, then fetch in background.
- On custom client import/add, trigger auto-fetch for the newly added client.
- Auto-fetch never overwrites a manual cover. It may overwrite/refresh an existing auto cover only when explicitly refreshed (not required in v1).
- Fetches should be deduplicated per client id to avoid concurrent duplicate requests.
- UI updates via a revision/token change after save so tiles/hero refresh.

### Manual change UI

Add `Search Cover Online…` to the existing tile context menu in `LibraryView` (and keep Photos/Files/Reset).

The action opens a sheet with:

- Text field pre-filled with the client’s search term.
- Search action / submit.
- Grid/list of up to ~8 results showing thumbnail, title, and optional description.
- Tap result → download image, save as **manual** cover, dismiss/update.
- Cancel to dismiss.

Existing actions remain:

- **Set Cover from Photos** - saves manual cover.
- **Set Cover from Files** - saves manual cover.
- **Reset Cover** - removes manual cover, revealing auto cover or built-in default. Only shown when a manual cover exists.

### Files likely affected

- `Falcon/ClientCoverStore.swift` - manual/auto layers, legacy manual compatibility, lookup helpers.
- `Falcon/BundledClient.swift` or new helper - curated search names.
- New `Falcon/WikipediaCoverService.swift` (or similarly named service) - search/download.
- `Falcon/ContentView.swift` - auto-fetch triggers on load/import, search sheet state/actions, cover resolution wiring.
- `Falcon/LibraryView.swift` / `Falcon/GameCard.swift` / `Falcon/HeroHeaderView.swift` - menu item / display refresh as needed.
- Tests under `tests/` for cover store layering and search-name mapping; service parsing tests where practical.

## Risks / Notes

- Wikipedia thumbnails can be low quality, wrong aspect, or not box art. This is accepted for the keyless approach.
- Some names will be ambiguous; manual Search Cover Online provides correction.
- Wikimedia requests should be polite (User-Agent, small result count, no aggressive refetch loops).
- Legacy covers in `Covers/` must continue to work as manual covers.

## Verification

- Unit tests for `ClientCoverStore` manual/auto/legacy resolution and reset behavior.
- Unit tests for bundled/custom search term mapping.
- Unit tests for Wikipedia response parsing / best-match selection with fixture JSON.
- Manual smoke: launch app, confirm bundled tiles get covers after fetch; add custom client and confirm auto-fetch; use Search Cover Online to replace; Reset returns to auto cover; Photos/Files still work.