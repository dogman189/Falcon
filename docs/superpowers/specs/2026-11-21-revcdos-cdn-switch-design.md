# reVCDOS asset source switch — design

Date: 2026-11-21

## Intent

Give the user an in-app switch for how reVCDOS gets game data: stream from the
live DOS Zone CDN (small app, needs internet), or download the full asset set
to the device once (large download, then offline). The app should ship without
the ~122 MB bundled `.br` files.

## Findings that shape this

- The pinned v6 client's CDN URLs are all 404 today. DOS Zone now serves a v16
  client at `https://dos.zone/vcsky/release/v16/` with
  `?wasm=https://br.cdn.dos.zone/vcsky/v16.wasm.br` (wasm returns HTTP 200).
- v16 has no original-game ownership gate — "Click to play" is always enabled.
- v16 fetches ~2008 data files into OPFS at runtime based on
  `preload_files.list`. The data-file URL pattern is not visible in the page
  source; it must be discovered by observing a real page load.
- The old packed archive (`folder.morgen.qzz.io/revcdos.bin`, ~1.08 GB) supports
  HTTP byte-range requests, but it contains the v6 asset set.

## Goals

- An in-app control on the reVCDOS tile to choose "Stream (CDN)" or
  "Downloaded (Offline)".
- Default: Stream — WKWebView loads the official v16 URL directly.
- Downloaded mode: the app fetches the full v16 asset set into app storage,
  the existing local server serves it, and the game runs offline.
- Remove the bundled `vcbr/*.br` files so a fresh app is small.
- Keep the existing swipe-to-quit gesture, cover snapshot, and failure screen.

## Non-goals

- A build-time toggle (the previously built vcsky option is superseded by this).
- Changing the other clients.
- App Store distribution; personal sideload only.
- Committing game assets.

## Approaches

1. **Load official URL for CDN; local server for downloaded (chosen).** CDN
   mode needs no asset URL knowledge and no proxy. Downloaded mode reuses the
   existing local server and responder. Cost: offline mode needs the v16 asset
   URLs discovered, and a sizeable one-time download.
2. **Proxy everything through the local server.** Both modes go through
   `localhost:8199`, which proxies to the CDN in stream mode. Gives control
   over headers, but requires knowing every CDN URL and re-implementing
   v16's OPFS fetch behavior. Rejected as riskier.
3. **Keep v6 and host the assets ourselves.** Requires user-provided hosting
   and abandoned per earlier choice. Rejected.

## Constraints

- v16's data URLs are unknown → Task 1 is a throwaway discovery spike that
  loads the official page in WKWebView with a `URLProtocol` request logger and
  records the URL pattern. Nothing from the spike ships.
- Downloaded assets live in Application Support (`reVCDOS/vcsky/`), never in
  the bundle, so the app stays small and assets survive app updates.
- The local server's document root must be switching-aware: local files in
  downloaded mode; unused in stream mode.
- `crypto.subtle`/COOP/COEP matter only for downloaded mode (local server);
  the official page handles its own headers in stream mode.

## Decisions left to the builder

- Exact download mechanism (one file per asset vs a packed archive) based on
  what Task 1 discovers.
- UI placement: propose a context-menu item on the reVCDOS tile that opens a
  small sheet with the two modes, a download button, progress, and storage size.
- Whether to delete previously downloaded assets when switching back to CDN.
