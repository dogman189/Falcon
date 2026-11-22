# reVCDOS downloadable assets — design

Date: 2026-11-21

## Intent

Keep the working, fully offline v6 reVCDOS client, but let the app ship small:
the user taps "Download full assets" once to fetch the game data onto the
device, then plays offline. No CDN streaming.

## Findings

- The v6 client works reliably in Falcon and needs four files:
  `vc-sky-{en,ru}-v6.data.br` and `vc-sky-{en,ru}-v6.wasm.br` (~122 MB total).
- The upstream CDN no longer serves these files (all 404), so the only known
  source is the packed archive `https://folder.morgen.qzz.io/revcdos.bin`
  (~1.08 GB, HTTP byte-range capable).
- In that archive, `.br` files are stored **raw** (not brotli-compressed again).
  Extracting the four game files needs only ULEB128 parsing and byte copying —
  no decompression library. The `vcsky` entries are brotli-compressed and are
  not needed by the game.
- v16 was tested and rejected: it fails in WKWebView with ENOENT before
  fetching any assets.

## Goals

- App bundle drops the four `.br` files (~122 MB saved).
- A clear in-app action: "Download full assets" with progress and cancel.
- Downloaded files stored in Application Support, served by the existing local
  server on `localhost:8199`.
- The game works offline after download; retry after interruption.
- Existing quit gesture, covers, failure view, and other clients unchanged.

## Non-goals

- CDN streaming, v16, in-game source switching.
- Extracting or serving `vcsky` (game does not request it; brotli decoding in
  Swift is out of scope).
- App Store distribution; personal sideload only.
- Committing any game assets.

## Approaches

1. **Download the packed archive, extract the four `.br` files (chosen).**
   Self-contained, no hosting needed. Cost: a ~1.08 GB download to obtain
   ~122 MB of usable files. Range requests can resume an interrupted download.
2. **Host the four `.br` files directly.** Small 122 MB download and trivial
   code, but requires the user to upload the files somewhere and provide a
   URL. Rejected unless the user prefers it.
3. **Keep the files bundled.** No download feature at all. Rejected — the user
   explicitly wants a download option.

## Constraints

- Archive format (pinned upstream `packer_brotli.py`):
  - folder entry: 1-byte type (0 normal, 1 copy), ULEB128 name length, name,
    then for normal folders a ULEB128 file count;
  - file entry: ULEB128 name length, name, 1-byte type (0 content, 1 reference),
    then for content a ULEB128 length followed by the bytes.
  - Only `vcbr/*.br` entries are copied; everything else is skipped.
- Use `URLSession` download task with progress, resume data for retry, and a
  success marker written only when all four files exist.
- Keep downloaded assets outside the app bundle so app updates don't delete them.

## Decisions left to the builder

- Exact progress UI (propose a sheet on the reVCDOS tile with progress bar and
  cancel).
- Whether to delete stale partial files before a retry (propose yes).
- README wording about the one-time download size and WiFi recommendation.
