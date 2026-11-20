# Falcon Selector Redesign + Portrait-Until-Launch — Design

## Intent
The selector is where the user spends most time, launching the same 2–3 clients repeatedly. It should feel like a calm, quiet utility that scans fast, not a game launcher page. Current state reads as "vibe-coded": heavy near-black gradient wall, giant ALL-CAPS "FALCON" wordmark, caption-tiny labels, 260×150 cards with thin cyan outlines.

## Decisions (from conversation, approved)
- **Direction A — clean utility list.** Vertical rows instead of horizontal card tiles. Each row: small cover thumbnail (56×56) on the left, then client name and short note. Soft card (white at 8%, subtle shadow) instead of the gradient/cyan outline.
- **Portrait until launch.** App locked to portrait while the selector is up; on launch (client selected), orientation is free again. Re-lock when returning to the selector.
- Add Client button, context menus, cover handling, launch/quit mechanics all keep their behavior.

## Goals
- Quiet, scannable selector list with restrained palette.
- Portrait lock while selector is visible; free orientation once a client has launched.

## Non-goals
- No change to launch, failure, or quit mechanics.
- No new settings screen.
- No change to cover/custom-client stores or their data.
- No change to bundled client definitions.

## Constraints
- iOS app, SwiftUI + WebKit + UIKit; no third-party dependencies.
- Deployment target iOS 27.2.
- Palette: default system background; row card = white at 8% opacity with 10pt shadow (`black` at 8%); cyan accent only for the CUSTOM badge and the Add Client button.
- No giant wordmark, no heavy gradient, no wide cyan-outlined tiles.

## Approaches considered
- **A (chosen):** vertical utility rows — fastest to scan, quietest, keeps repeated-launch friction low.
- **B:** smaller card grid — more visual, less compact; rejected as still playful.
- **C:** toned-down version of the current tiles — too close to current design; rejected.
