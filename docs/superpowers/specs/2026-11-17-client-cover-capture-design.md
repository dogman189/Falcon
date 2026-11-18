# Client Cover Capture Design

**Approved:** 2026-11-17

## Intent
Replace generated tile graphics with user-specific covers by auto-capturing in-game screenshots and allowing manual image selection, for both bundled and custom clients.

## Goals
- For any client (bundled or custom): auto-capture the WebView on Quit tap and save it as that client’s tile cover for next time.
- For any client: manually set a cover from Photos or Files via tile context menu, and reset to the default generated cover.
- Covers persist per client id and override default generated art.

## Non-goals / Anti-goals
- No galleries/history, cropping/editing UI, sharing, or cloud sync.
- Do not lose covers on relaunch; do not modify bundled client files.

## Approach
- Store cover images per client id in app storage (e.g. `Application Support/Covers/<client-id>.<ext>`), managed by a cover store.
- UI resolves tile image to stored cover file when present, else default generated asset (`ClientCover-*` including custom default).
- Auto: on Quit tap, snapshot the active `WKWebView` (`takeSnapshot`) for the selected client and save before returning to selector. If snapshot fails, quit still proceeds and existing cover/default remains.
- Manual: tile context menu provides “Set Cover from Photos” (PhotosPicker), “Set Cover from Files” (image file importer), and “Reset Cover” when an override exists.
- Bundled client overrides keyed by stable bundled id; custom clients keyed by custom id.

## Builder calls
- Auto-capture moment is Quit tap.
- Stored images saved/normalized as JPEG or PNG; replacing a cover overwrites the prior stored file for that client.