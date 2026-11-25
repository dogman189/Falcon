# In-Game Quick Menu — Short Design (Approved)

- **Intent:** Expand the existing top-left quit gesture into a small in-game quick menu so players can take common actions without leaving the game unexpectedly.
- **Goals:** Swipe in the top-leading hotspot reveals a quick menu with Resume, Reload, Screenshot, and Quit. Pressing the controller **Guide/Home button** (the big center Xbox button, `GCExtendedGamepad.buttonHome`, where exposed) also toggles the menu while in-game. **Non-goals:** True game pause, audio mixing, aspect-ratio/display-mode changes, fast-forward/turbo, or full in-game controller navigation. **Anti-goals:** Browser chrome; accidental quits; interfering with normal gameplay/controller input.

- **Constraints:** Full-screen immersive `WKWebView` client in `ContentView`; selection/session lifecycle owned by `ContentView`. `GameControllerManager` is currently disabled while a client is active (`isEnabled = newClient == nil`) so WebKit can receive raw gamepad input. `buttonHome` is optional, not exposed by every controller/OS configuration, and may have system-level behavior; it must be treated as a best-effort shortcut. WKWebView has no reliable global audio mute; emulator/client features vary.

- **Approaches considered:**
  1. **Extend existing quit overlay in place (chosen):** Replace quit-only reveal state with a small quick-menu overlay state in `ContentView`, extracting overlay UI/state helpers as needed. Add reload/screenshot hooks to `EaglerWebView` and a dedicated in-game Home-button callback to `GameControllerManager`. *Builds on the current gesture, keeps session actions in `ContentView`, low risk.*
  2. **New modal HUD screen:** Separate full-screen/modal pause screen. *Clearer focus but heavier and more disruptive.*
  3. **Pluggable action system:** Generic per-client action registry. *Flexible but over-designed for v1.*

  - **Picked:** **(1)** — smallest change that delivers the requested actions.

- **How (decided):**
  - **Trigger:** Keep the existing top-leading 140x90 swipe hotspot and drag gesture. Swipe toggles the quick menu. While a client is active, wire a dedicated in-game menu-toggle callback so the controller **Guide/Home button** toggles the same menu where available. This must work without enabling full menu navigation; D-pad/sticks/face buttons/shoulders remain normal game input. The swipe gesture remains the primary, always-available trigger.
  - **Menu UI:** Replace the Quit-only capsule with a small top-leading menu card containing **Resume**, **Reload**, **Screenshot**, and **Quit**. Resume or tapping outside closes it. Auto-hide after ~5 seconds of inactivity; interactions reset the timer.
  - **Quit:** Reuse `quitCurrentClient()` behavior: hide menu, finalize launch session, take snapshot for cover, stop reVCDOS server, clear selection/failure.
  - **Reload:** Add a narrow reload hook to `EaglerWebView`/coordinator so `ContentView` can request reload; clear transient failure state as appropriate.
  - **Screenshot:** Reuse `WebViewSnapshotter` to capture the current web view. Save to Photos with permission handling and lightweight success/failure feedback.
  - **Controller Home:** Add a `GameControllerManager` callback (e.g. `onInGameMenuToggle`) invoked on Guide/Home button press even when `isEnabled == false`. Configure `buttonHome?.pressedChangedHandler` where available. `ContentView` sets the callback when a client is active and clears it on exit. Do not enable D-pad/thumbstick/A/B/shoulder menu callbacks in-game.

- **Left to the builder:** Exact menu styling/animation, reload confirmation default (propose none in v1), Photos permission/error UI copy, handling controllers/OSes where `buttonHome` is unavailable or system-reserved, and tests/manual verification for bundled, custom, and reVCDOS clients.

*Approved by user in conversation (2026-11-24), including correction: use the controller Guide/Home center button, not the X face button.*