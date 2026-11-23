# Falcon

Falcon is a native iOS (SwiftUI) launcher/wrapper for bundled Eaglercraft-style web clients. It loads client HTML/WASM builds in an immersive `WKWebView` and provides a simple selector for launching bundled or custom clients.

## Features

- **Bundled clients**
  - `1.8.8-wasm`
  - `reVCDOS` — HTML5 port of GTA: Vice City; game data is downloaded once, then played offline
- **Custom clients**: import a single `.html` client file from Files and launch it from the selector
- **Pack Retro Game**: turn a user-owned ROM into a portable HTML game client (universal systems only; ROM supplied by user; emulator cores downloaded on demand; generated HTML imported as a custom client)
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

## reVCDOS game data

The app ships without the game data. On first launch, reVCDOS shows a download sheet:

- The download is about **1.08 GB** (the upstream packed archive) and needs roughly **1.5 GB** of free space. Use WiFi.
- Falcon extracts the four game files into Application Support, where they survive app updates.
- An interrupted download resumes on the next attempt; the assets are only marked ready when all four files are present.
- You can also start it from the reVCDOS tile's context menu: **Download full assets…**.

Once downloaded, the game runs fully offline through the local server on `localhost:8199`.

## Pack Retro Game

Falcon can pack a user-owned ROM into a portable HTML game client:

- **Universal systems only** (no platform-specific cores are bundled).
- The **user supplies the ROM**; Falcon does not ship or download any game data.
- Emulator cores are **downloaded on demand** by the generated client.
- The result is **generated HTML imported as a custom client**, launchable from the selector like any other custom client.

> Legal note: only use ROMs you own the rights to. Falcon does not provide or distribute ROMs or copyrighted game data.

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
