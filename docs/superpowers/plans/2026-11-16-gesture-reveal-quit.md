# Gesture-Reveal Quit Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the always-visible in-game Quit button with a top-leading swipe gesture that reveals a Quit button; tapping it returns to the client selector.

**Architecture:** In `ContentView`’s selected-client branch, track `quitRevealed` state (reset per session). Overlay a transparent top-leading hotspot that recognizes a swipe/drag to set `quitRevealed = true`, and conditionally show the existing-styled Quit button; tapping Quit sets `selectedClient = nil`.

**Tech Stack:** SwiftUI gestures/overlay, existing `EaglerWebView`.

**Spec:** `docs/superpowers/specs/2026-11-16-gesture-reveal-quit-design.md`

## Global Constraints

- **Reveal then confirm:** swipe in top-leading area reveals Quit; button tap (not swipe) returns to selector.
- **No immediate/accidental quit:** do not quit directly on swipe; no app exit.
- **Scoped interaction:** keep gesture area limited to top-leading hotspot to reduce conflict with gameplay; preserve immersive web view.

## Review Focus

- **Gesture reliability:** swipe in the intended top-leading area reveals the button; ordinary gameplay touches elsewhere are unaffected.
- **State reset:** revealed state does not leak across sessions/clients (returning to selector and re-entering starts hidden).
- **Quit works:** revealed button tap returns to selector and allows selecting another client.

---

### Task 1: Implement swipe-to-reveal quit control

**Files:**
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: `@State selectedClient` and `EaglerWebView(fileURL:)`.
- Produces: hidden-by-default quit control revealed by swipe/drag in top-leading hotspot; `quitRevealed` reset on session changes; button tap sets `selectedClient = nil`.

- [ ] **Step 1: Add `quitRevealed` state and reset behavior for selected-client sessions**

Add `@State private var quitRevealed = false` and reset it when selection/session changes (e.g. via `.onChange(of: selectedClient)` or equivalent) so new sessions start hidden.

- [ ] **Step 2: Replace persistent quit button with hotspot + conditional revealed button**

Overlay a transparent top-leading area with a `DragGesture` (reasonable minimum distance) that sets `quitRevealed = true`; show `quitButton` only when `quitRevealed` is true, positioned in the same top-leading region.

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Falcon/ContentView.swift
git commit -m "feat: reveal in-game quit button via swipe gesture"
```

### Task 2: Runtime verification

**Files:**
- Modify (only if needed): `Falcon/ContentView.swift`

- [ ] **Step 1: Verify manually**

Manual checks (device/simulator, landscape): quit hidden on client start; swiping in top-leading area reveals Quit; tapping Quit returns to selector; re-entering a client starts hidden again; gameplay elsewhere not obviously blocked.
Expected: gesture-reveal-then-confirm behavior works as specified.

- [ ] **Step 2: Apply minimal fixes only if needed, rebuild, and commit**

```bash
git add Falcon/ContentView.swift
git commit -m "fix: adjust quit reveal gesture hotspot"
```
(Only if changes were required.)