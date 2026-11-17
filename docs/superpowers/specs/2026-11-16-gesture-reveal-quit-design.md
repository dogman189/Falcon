# Gesture-Reveal Quit Button — Short Design (Approved)

- **Intent:** Hide the always-visible Quit control and let you reveal it intentionally, then confirm to return to the client selector.
- **Goals:** In-game swipe in the top-leading (current Quit) area reveals a Quit button; tapping that button returns to the launch client list. **Non-goals:** Immediate quit without confirmation, quitting the app, remembering client choice. **Anti-goals:** Browser chrome; avoid accidental quits and minimize interference with gameplay.
- **Constraints:** Full-screen immersive `WKWebView` (landscape) with touch input used by the game; selection state in `ContentView`.
- **Approaches considered:**
  1. **Top-leading swipe hotspot overlay (chosen):** transparent gesture region in the top-leading area detects a swipe to show the Quit button; tapping Quit clears selection to return to selector; revealed state resets when leaving/starting a session. *Matches requested location, reliable without broad interference.*
  2. **Global screen-edge gesture:** edge swipe along leading/top edge over web view. *Harder to make reliable without interfering with in-game touch input.*
  - **Picked:** **(1)**.
- **How (decided):** Replace the persistent button with a hidden-by-default Quit button plus a top-leading overlay area that listens for a swipe (drag) gesture to reveal it; tapping Quit returns to selector. Swipe toggles the button (swipe again hides it), the revealed button auto-hides after ~3 seconds, and reveal state resets when the selected client changes.
- **Post-approval revision (2026-11-16):** Originally specified "no auto-hide"; user reported the revealed button never went away until app restart. Revised to toggle on swipe + auto-hide after 3 seconds + reliable reset on client change.
- **Left to the builder:** Exact hotspot size and swipe direction/distance threshold; auto-hide duration.

*Approved by user in conversation (2026-11-16).*