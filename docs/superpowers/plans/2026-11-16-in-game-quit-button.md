# In-Game Quit Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-game quit control that returns from the running client to the launch client selector.

**Architecture:** In `ContentView`, render the selected-client immersive `EaglerWebView` inside a `ZStack` with a small top-leading overlay button. Tapping the button sets `selectedClient = nil`, returning to the existing selector (no persistence, no app exit).

**Tech Stack:** SwiftUI, existing `EaglerWebView` wrapper.

**Spec:** `docs/superpowers/specs/2026-11-16-in-game-quit-button-design.md`

## Global Constraints

- **Quit means return to selector:** clear selection to show client list; do not exit/terminate the app.
- **Minimal intrusion:** control overlays gameplay but must remain small/semi-transparent and not introduce browser chrome or menus.
- **Preserve immersion:** keep full-screen, landscape, no-scroll/bounce web view behavior unchanged.

## Review Focus

- **State transition:** tapping quit reliably returns to selector from any bundled client and allows picking another client.
- **Hit area/visibility:** button is reachable in landscape without being overly obstructive.
- **No regressions:** selector and web view loading/immersion behavior remain intact.

---

### Task 1: Add quit overlay and verify

**Files:**
- Modify: `Falcon/ContentView.swift`

**Interfaces:**
- Consumes: existing `@State private var selectedClient: BundledClient?` and `EaglerWebView(fileURL:)`.
- Produces: selected-client view as `ZStack(alignment: .topLeading)` containing `EaglerWebView(...).ignoresSafeArea().background(.black)` and an overlay `Button` that sets `selectedClient = nil`.

- [ ] **Step 1: Implement quit button overlay in `ContentView` selected-client branch**

Wrap the game view in a `ZStack` and add a top-leading safe-area button (e.g. “Quit” or `xmark` label) with semi-transparent styling so it is visible but minimally intrusive in landscape.

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Falcon/ContentView.swift
git commit -m "feat: add in-game quit button to return to selector"
```

### Task 2: Runtime verification

**Files:**
- Modify (only if needed): `Falcon/ContentView.swift`

- [ ] **Step 1: Verify behavior manually**

Manual checks (device/simulator): while a client is running, quit button is visible/tappable in landscape; tapping returns to client selector; selecting a client again works; web view remains immersive.
Expected: quit returns to selector without app exit or regressions.

- [ ] **Step 2: Apply minimal fixes only if needed, rebuild, and commit**

Run build and commit only if changes were required.
```bash
git add Falcon/ContentView.swift
git commit -m "fix: adjust in-game quit button placement"
```