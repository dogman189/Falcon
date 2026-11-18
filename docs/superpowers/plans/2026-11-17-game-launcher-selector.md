# Game Launcher Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle Falcon's client selector as a dark game-launcher screen with large tappable client cards while preserving existing launch behavior.

**Architecture:** Replace the plain `NavigationStack`+`List` selector in `ContentView` with a SwiftUI full-screen dark view (gradient/black background, header, scrollable card stack, footer). Reuse existing state/actions (`selectedClient`, `clientFailure`, debug auto-open, missing-URL disabling) and keep game/failure/quit behavior unchanged.

**Tech Stack:** SwiftUI, iOS app target (`Falcon`), Xcode/xcodebuild.

**Spec:** `docs/superpowers/specs/2026-11-17-game-launcher-selector-design.md`

## Global Constraints

- No new image assets or per-client artwork.
- No behavior changes to web/game loading, quit gesture, or failure handling.
- Keep tap targets and text readable in landscape.
- Preserve clients list and notes: `Eaglet`, `1.8.8-wasm` (single-thread hint), `1.21.11-wasm`; footer keeps swipe-to-quit and 1.8.8 guidance.

## Review Focus

- **Small/landscape screens:** header/cards/footer remain visible and tappable without clipping; scroll works if content exceeds height.
- **Client notes/missing state:** 1.8.8 note is clearly readable on the card; a client with `url == nil` remains visibly disabled and non-launching.
- **Behavior parity:** tapping a valid card still sets `selectedClient` and clears `clientFailure`; debug `--client=` auto-open and quit/failure flows are unaffected.

---

### Task 1: Restyle the selector as a game launcher

**Files:**
- Modify: `Falcon/ContentView.swift` (`clientSelector` and helper view(s) as needed)

**Interfaces:**
- Consumes: `BundledClient.all`, `BundledClient.name`, `BundledClient.note`, `BundledClient.url`, `@State selectedClient`, `@State clientFailure`.
- Produces: `clientSelector` renders the approved launcher UI and preserves launch/disabled behavior (valid tap sets `clientFailure = nil` and `selectedClient = client`; `client.url == nil` is disabled).

- [ ] **Step 1: Replace selector layout**
  - Implement a full-screen dark background (e.g. black/subtle gradient) with a header area (“Falcon”, short subtitle like “Select a client”).
  - Render clients as large rounded tappable cards in a scrollable vertical stack, each showing client name, optional note text when present, and a trailing chevron/play indicator.
  - Show the footer hint text: `Swipe down in the top-left corner to reveal Quit. 1.8.8-wasm may need single-thread if it hangs starting the integrated server.`
  - Apply a consistent accent style and spacing that read well in landscape.

- [ ] **Step 2: Preserve behavior and states**
  - Valid card tap: `clientFailure = nil; selectedClient = client`.
  - Missing bundle (`client.url == nil`): visually indicate unavailability and disable interaction.
  - Keep `openDebugClientIfRequested`, quit overlay, and `failureView` logic unchanged.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Falcon/ContentView.swift docs/superpowers/specs/2026-11-17-game-launcher-selector-design.md docs/superpowers/plans/2026-11-17-game-launcher-selector.md
git commit -m "feat: restyle selector as game launcher"
```
