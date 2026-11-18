# Horizontal Tile Selector Design

**Approved:** 2026-11-17

## Intent
Make the client selector feel more like a game launcher by showing clients as sideways-scrolling tiles with cover pictures.

## Goals
- Selector uses horizontal scrolling tile rows with a cover image on each tile.
- Bundled and Custom clients remain separate sections (each a horizontal row/section).
- Bundled clients have generated bundled cover images; custom clients use a bundled generic custom cover image.
- Preserve existing behaviors: launch on tap, Add Client import, remove custom client via context menu, missing/unavailable state, footer/quit behavior.

## Non-goals / Anti-goals
- No per-custom-client user-selected images.
- No downloaded third-party artwork; covers are generated in-repo.
- No behavior changes to game loading, import persistence logic, or quit/failure flows.

## Approach
- Generate PNG cover assets with PIL and add them to `Falcon/Assets.xcassets` (Eaglet, 1.8.8-wasm, 1.21.11-wasm, generic custom).
- Expose a cover image name/key on `GameClient` (or map by client identity) for UI rendering.
- Update `ContentView` selector: keep header/footer and section labels, replace vertical card stacks with horizontal `ScrollView(.horizontal)` tile rows; each tile shows cover image, name, custom badge/note, and availability affordance.
- Keep Add Client button and custom remove context menu.

## Builder calls
- Tile size, spacing, and typography tuned for landscape readability.
- Generated cover style: dark game-launcher gradients with simple icon/label treatment per client.