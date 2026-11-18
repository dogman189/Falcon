# Game Launcher Selector Design

**Approved:** 2026-11-17

## Intent
Replace the stock list-based client selector with a game-launcher feel so Falcon feels like a launcher rather than a settings menu.

## Goals
- Full-screen dark launcher screen with prominent “Falcon” header/subtitle.
- Each bundled client (`Eaglet`, `1.8.8-wasm`, `1.21.11-wasm`) presented as a large tappable card showing name, optional note/badge, and a clear play/chevron affordance.
- Preserve footer hint: swipe down in top-left to reveal Quit and the 1.8.8 single-thread guidance.
- Keep existing behavior: tap launches client, missing-bundle clients disabled/warned, debug `--client=` auto-open unchanged.

## Non-goals / Anti-goals
- No new image assets or per-client artwork.
- No behavior changes to web/game loading, quit gesture, or failure handling.
- Do not reduce readability or tap-target size, especially in landscape.

## Approach
- SwiftUI-only changes in `Falcon/ContentView.swift` (`clientSelector` and small helper views/styles).
- Dark gradient/black background, header, scrollable stack of rounded accent cards, styled note captions, and footer.
- Existing selection/failure state logic remains unchanged.

## Builder calls
- Exact colors, spacing, typography, and accent treatment tuned for contrast and landscape fit (simple consistent accent across cards).