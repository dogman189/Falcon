# Falcon Eaglercraft Wrapper — Short Design (Approved)

- **Intent / why:** Make Eaglercraft usable in Falcon instead of Safari because Safari’s browser UI gets in the way and performance felt poor on a flagship phone. The wrapper should provide a dedicated, distraction-free game surface.
- **Goals:** Remove browser chrome/interruptions; run true fullscreen with a stable edge-to-edge viewport; load the provided bundled client for consistent local startup. **Non-goals:** Replacing WebKit or guaranteeing higher raw engine FPS than Safari can achieve. **Anti-goals:** Adding browser-like navigation/UI, or behavior that introduces extra overlays/gestures during play.
- **Constraints:** iOS uses WebKit (same engine family as Safari), so embedding tunes experience more than raw JS/WebGL throughput. Source is a single bundled file: `/Volumes/SSD/Falcon Builds/Eaglet.html` (~2.7 MB, self-contained, UTF‑16 HTML). Must fit the existing SwiftUI app (`FalconApp.swift` → `ContentView`).
- **Approaches considered:**
  1. **Immersive local-file wrapper (chosen):** bundle `Eaglet.html`, load in full-screen `WKWebView` via local file URL, disable browser-like UI/scroll/zoom/selection behaviors. *Best fit for a single self-contained build; directly fixes UI and avoids remote overhead; limited by WebKit perf ceiling.*
  2. **Local web server:** serve bundled files over `localhost` to `WKWebView`. *Helps only if `file://` origin/URL semantics misbehave; adds complexity with similar engine limits.*
  3. **Game-mode tuning:** approach 1 plus deeper orientation/idle/input/WKWebView tuning. *May improve playability feel but more device-specific and still WebKit-bounded; can be a follow-up if needed.*
  - **Picked:** **1** — simplest path that addresses the stated UI problem and establishes a clean local-play baseline.
- **How (decided):** Import `Eaglet.html` into the app bundle; replace `ContentView` with a SwiftUI `UIViewRepresentable` hosting a configured `WKWebView` that loads the bundled file with appropriate file-read access; apply immersive configuration (edge-to-edge/ignores safe area as appropriate, no bounce/scrolling/zoom/text interaction chrome) so the game owns the screen.
- **Left to the builder:** Exact `WKConfiguration`/preferences and any minimal viewport/script injection needed for this specific build, asset import/copy details in Xcode, and on-device verification (UI immersion, load success, input/perf feel).

*Approved by user in conversation (2026-11-15).*
