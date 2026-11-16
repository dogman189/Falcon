# Launch Client Selector (Bundled Builds) — Short Design (Approved)

- **Intent / why:** Let you choose which Eaglercraft build to run when opening Falcon, now that multiple builds are available, without going through Safari.
- **Goals:** On every launch show a client list; bundling the three builds from `/Volumes/SSD/Falcon Builds` (`Eaglet.html`, `1.8.8-wasm.html`, `26.3-wasm.html`); tapping a client opens it in the same immersive, browser-chrome-free `WKWebView` wrapper. **Non-goals:** Remembering last choice, importing files on-device, loading remote URLs, or promising better-than-WebKit engine performance. **Anti-goals:** Browser UI/controls during play.
- **Constraints:** iOS app can’t read the Mac/SSD folder at runtime, so clients must be packaged in the app bundle (app size increases, notably ~65 MB for `26.3-wasm.html`). Existing immersive wrapper and WebKit limits remain.
- **Approaches considered:**
  1. **Pick-then-launch (chosen):** show a simple SwiftUI list at launch; selecting a client replaces the view with the full-screen immersive `EaglerWebView` for that bundled file. To switch clients, quit and reopen (list shows every launch, as requested). *Simplest, no in-game overlay/back chrome to interfere with play.*
  2. **Navigation/detail with back control:** `NavigationStack` pushes the webview and keeps a way back to the list. *Easy switching but risks visible navigation UI/gestures conflicting with an immersive full-screen game unless carefully hidden.*
  3. **Overlay/sheet-based picker:** in-game control to reopen selector. *Most flexible but adds UI over gameplay (anti-goal) and more state complexity.*
  - **Picked:** **1** — matches “always show list at launch” with minimal, non-intrusive behavior.

- **How (decided):** Copy the three HTML builds into the app bundle; define a small list of bundled clients (name derived from filename, e.g. “Eaglet”, “1.8.8-wasm”, “26.3-wasm” → their resource files). `ContentView` shows a launch list first; tapping one sets the selected bundled file URL and presents `EaglerWebView` full-screen/immersive (reusing current wrapper, generalized to load a given file URL). No persisted selection.
- **Left to the builder:** Exact SwiftUI structure/state for list→game transition, display-name formatting, bundle/resource verification for all three large files, and build/runtime checks (including that large wasm HTMLs load correctly from the bundle).

*Approved by user in conversation (2026-11-16).*