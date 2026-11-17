# In-Game Quit Button — Short Design (Approved)

- **Intent:** Let you leave a running client and return to the client selector without force-quitting Falcon.
- **Goals:** Add an in-game quit control that returns to the launch client list. **Non-goals:** Exiting the app, remembering last client, or adding other in-game menus. **Anti-goals:** Browser chrome; minimize gameplay obstruction (but a small control will overlay the game).
- **Constraints:** Game view is a full-screen immersive `WKWebView` (landscape-only) driven by `selectedClient` state in `ContentView`.
- **Approaches considered:**
  1. **Persistent corner button (chosen):** overlay a small, semi-transparent quit button in a safe corner above the web view; tapping clears selection to return to the selector. *Always available, simple and reliable; may cover a small area of gameplay.*
  2. **Reveal-on-demand control:** hidden by default, shown via gesture/handle. *Less intrusive but less discoverable and can conflict with game input.*
  3. **In-game menu overlay:** menu button opens minimal overlay. *More UI/steps than needed for a single action.*
  - **Picked:** **(1)** — directly satisfies the request with minimal complexity.
- **How (decided):** In the selected-client branch of `ContentView`, present `EaglerWebView` in a `ZStack` with a top-leading safe-area button (e.g. “Quit”/`xmark`) styled to be visible but unobtrusive; tapping sets `selectedClient = nil` to show the selector.
- **Left to the builder:** Exact placement, size/opacity, and label/icon so it’s easy to hit but minimally intrusive during landscape play.

*Approved by user in conversation (2026-11-16).*