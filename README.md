# Falcon

Falcon is a native iOS (SwiftUI) launcher/wrapper for bundled Eaglercraft-style web clients. It loads client HTML/WASM builds in an immersive `WKWebView` and provides a simple selector for launching bundled or custom clients.

## Features

- **Bundled clients**
  - `Eaglet`
  - `1.8.8-wasm`
  - `1.21.11-wasm`
  - `reVCDOS` — offline HTML5 port of GTA: Vice City (assets bundled; no network needed)
- **Custom clients**: import a single `.html` client file from Files and launch it from the selector
- **Immersive web view**: browser-chrome-free `WKWebView` surface tuned for gameplay
- **Client covers**:
  - default per-client cover art
  - set a custom cover from Photos or Files (via context menu)
  - reset custom covers
  - on quit, Falcon captures a snapshot to use as the client cover
- **In-game quit gesture**: swipe down in the top-left corner to reveal a `Quit` button (auto-hides after a few seconds) and return to the client selector
- **Failure handling**: shows an in-app error screen for missing bundles, load failures, or web content termination (with retry/back options)

## Notes

- `1.8.8-wasm` may hang while starting the integrated server; if that happens, try running it in single-thread mode (if available in the client).
- A debug launch argument is supported: `--client=<name-or-id>` (DEBUG builds) to open a specific client on startup.
- `reVCDOS` is served from a small in-app loopback server on `localhost:8199` so the game's brotli-compressed assets and cross-origin-isolation headers work offline. If that port is occupied, the failure screen will say so.
- The reVCDOS HTML5 port is MIT licensed, copyright DOS Zone and Lolendor; it is not affiliated with Rockstar Games. This app is for personal use only.

## Project structure

- `Falcon/` — SwiftUI app source, web view wrapper, bundled client definitions, and bundled client HTML files
- `Falcon/reVCDOS/` — offline game assets, bundled as a folder reference so its directory structure is preserved. If you add files here, also add their paths to the `membership-exceptions` exclusions in `Falcon.xcodeproj/project.xcproj`.
- `Falcon.xcodeproj/` — Xcode project

## Getting started

1. Open `Falcon.xcodeproj` in Xcode.
2. Select an iOS simulator or device.
3. Build and run.

> Exact signing/team and deployment target settings depend on your local Xcode/project configuration.

## License

MIT — see [LICENSE](LICENSE).
