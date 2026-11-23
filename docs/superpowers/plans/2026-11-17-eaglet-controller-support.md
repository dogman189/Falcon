# Eaglet Controller Support (First Pass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable basic physical gamepad play in the bundled **Eaglet** web client (movement + a few actions) by bridging `GCController` input to synthetic DOM events in the `WKWebView`.

**Architecture:** Add a small native controller bridge owned by `EaglerWebView` that listens for `GCController` connect/disconnect, reads `extendedGamepad` state, translates it to a fixed Eaglet mapping, and calls `evaluateJavaScript` to dispatch `KeyboardEvent`/mouse or pointer events into the page. Keep it Eaglet-only for this pass, with no launcher/UI navigation and no right-stick look.

**Tech Stack:** Swift, SwiftUI, UIKit (`WKWebView`), GameController (`GCController`, `GCExtendedGamepad`), JavaScript DOM event dispatch via `WKWebView.evaluateJavaScript`.

**Spec:** Approved in-chat design (2026-11-17): Eaglet first; left stick/D-pad → `W/A/S/D`; A → jump (`Space`); X → attack/mine; B → use/place; no look; approach 1 (native `GameController` → synthetic DOM events), no bundled HTML changes.

## Global Constraints

- **Scope:** in-game only, **Eaglet** bundled client only; do not add controller handling to Falcon launcher/UI.
- **Mapping (v1):** left thumbstick or D-pad → `W/A/S/D`; button A → `Space` (jump); button X → attack/mine; button B → use/place; right stick/look out of scope.
- **Approach:** Apple `GameController` + `evaluateJavaScript` DOM event injection; do **not** modify `Falcon/Eaglet.html` or other bundled client assets.
- **Behavior:** send press/release transitions (no stuck keys, avoid unnecessary repeat spam); handle controller connect/disconnect; keep JS work lightweight.
- **No regressions:** existing client loading, quit overlay/snapshot flow, and non-Eaglet clients must continue to work unchanged.

## Review Focus

- **No controller connected:** Eaglet must behave exactly as today (touch/keyboard), with no crashes/log spam from the bridge.
- **Disconnect mid-session / reconnect:** pressed inputs must be released on disconnect; reconnect should resume control without requiring app relaunch.
- **Diagonal/overlapping inputs:** stick and D-pad combinations must produce a consistent `W/A/S/D` pressed set (e.g. up+left → `W`+`A`) without stuck keys when returning to neutral.
- **Attack/use event mismatch:** if Eaglet expects mouse/pointer events on the canvas (not keys), X/B must still trigger the intended actions; verify and pin the working event form for Eaglet.
- **Non-Eaglet clients:** `1.8.8-wasm`, `1.21.11-wasm`, and custom clients must not receive Eaglet controller injection.

---

## File Structure

- **Create:** `Falcon/EagletControllerBridge.swift` — owns `GCController` observation for the active Eaglet webview, maintains current input state, maps gamepad → actions, and emits JS to dispatch DOM events. Single responsibility: controller-to-web input translation for Eaglet.
- **Modify:** `Falcon/EaglerWebView.swift` — detect Eaglet loads, create/start/stop the bridge for the associated `WKWebView` lifecycle, and provide a narrow hook to evaluate JS on the game webview. Keep existing navigation/failure/snapshot behavior intact.
- **Modify (only if needed):** `Falcon/ContentView.swift` — no functional changes expected; only touch if a small API/threading adjustment is required by the bridge lifecycle (prefer not).
- **Modify:** `Falcon.xcodeproj/project.pbxproj` — add `EagletControllerBridge.swift` to the Falcon target and link `GameController.framework` if not already linked by SDK defaults in this project format.

**Decomposition:** Task 1 adds the bridge + Eaglet mapping/JS emission in isolation; Task 2 wires lifecycle into the webview; Task 3 verifies behavior on device/simulator-with-controller and hardens event details for Eaglet.

## Task 1: Implement Eaglet controller bridge and mapping

**Files:**
- Create: `Falcon/EagletControllerBridge.swift`
- Modify: `Falcon.xcodeproj/project.pbxproj` (register new file / framework if required)

**Interfaces:**
- Consumes: a `WKWebView` instance used by `EaglerWebView` to load the selected client.
- Produces: `final class EagletControllerBridge` with an API usable from `EaglerWebView`, e.g. `init(webView: WKWebView)`, `start()`, `stop()` (exact names/signatures may be finalized, but must clearly separate attach/start, detach/stop, and "release all inputs"). Internally: `GCController` connect/disconnect handling; mapping from `GCExtendedGamepad` (`leftThumbstick`, `dpad`, `buttonA`, `buttonX`, `buttonB`) to logical actions; JS generation/dispatch for key down/up and action press/release.

- [ ] **Step 1: Define mapping and state model (Eaglet v1)**
- [ ] **Step 2: Implement `GCController` observation**
- [ ] **Step 3: Implement JS event dispatch helpers**
- [ ] **Step 4: Wire Xcode project membership**
- [ ] **Step 5: Build-check**
- [ ] **Step 6: Commit**

## Task 2: Wire bridge lifecycle into `EaglerWebView` (Eaglet only)

**Files:**
- Modify: `Falcon/EaglerWebView.swift`

**Interfaces:**
- Consumes: `EagletControllerBridge` from Task 1.
- Produces: `EaglerWebView` starts the bridge only when the loaded client is Eaglet and stops/releases inputs when the webview is torn down or replaced. Non-Eaglet loads must not start the bridge.

- [ ] **Step 1: Add Eaglet detection and bridge ownership**
- [ ] **Step 2: Ensure cleanup/releases on teardown**
- [ ] **Step 3: Keep navigation/failure behavior unchanged**
- [ ] **Step 4: Build-check**
- [ ] **Step 5: Commit**

## Task 3: Manual verification and Eaglet-specific event tuning

**Files:**
- Modify (as needed): `Falcon/EagletControllerBridge.swift` (and rarely `Falcon/EaglerWebView.swift`)

**Interfaces:**
- Consumes: implemented bridge + wiring from Tasks 1–2.
- Produces: confirmed-working v1 mapping on Eaglet with clean connect/disconnect behavior.

- [ ] **Step 1: Verify core mapping on device with a paired controller**
- [ ] **Step 2: Verify connect/disconnect and non-Eaglet isolation**
- [ ] **Step 3: Tune attack/use events if needed**
- [ ] **Step 4: Final build-check and commit** (if tuning changes required)
