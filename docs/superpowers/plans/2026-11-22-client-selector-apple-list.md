# Client Selector Apple List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the client selector/home screen to an Apple/system-native grouped list style (Approach 1) with cleaner visual treatment, preserving all existing behavior.

**Architecture:** Replace the custom `ScrollView` + card stack in `ContentView.clientSelector` with a SwiftUI `List` using grouped styling, system section headers, and a toolbar “Add Client” control. Refactor `SelectorRow` into a cell-like row (no heavy card fill/shadow), keeping cover thumbnail, title/subtitle, subtle “Custom” indication, and the same context menu/actions attached by the caller.

**Tech Stack:** SwiftUI (iOS), existing stores/actions in `ContentView`/`SelectorRow`/`GameClient`.

**Spec:** `docs/superpowers/specs/2026-11-22-client-selector-apple-list-design.md`

## Global Constraints

- iOS SwiftUI app; no new third-party dependencies.
- Preserve behavior: client launch via row tap/select action, cover set/reset via context menu, custom client add/remove, reVCDOS download/delete actions in context menu when applicable, footer hint meaning, empty CUSTOM state behavior.
- Keep `client.url == nil` rows disabled (non-launchable) as today.
- Keep `.contextMenu` attachments and their contents/conditions unchanged in effect (only presentation container changes).
- Keep `SelectorRow(client:cover:)` call sites working conceptually; adjust styling/structure as specified.

## Review Focus

- Empty CUSTOM list: still communicates “No custom clients…” (via section footer or equivalent) and does not show broken/extra rows.
- Disabled bundled/client rows (`url == nil`) remain visually/behaviorally disabled (tap does nothing / disabled state).
- Context menus still appear on rows and include: cover actions for all; reVCDOS “Download full assets…” and conditional “Delete downloaded assets…” only for `client.id == "bundled:reVCDOS"`; “Remove Client” (destructive) only on custom rows.
- “Add Client” still presents the file importer and handles success/error flows unchanged.
- Footer hint text remains visible and readable.

---

### Task 1: Refactor `SelectorRow` to a cell-like row (no card chrome)

**Files:**
- Modify: `Falcon/SelectorRow.swift`

**Interfaces:**
- Consumes: `GameClient` (from `BundledClient.swift`), `cover: Image` passed by caller.
- Produces: `SelectorRow(client:cover:) -> some View` (presentational). Visual style becomes list/cell-like: no rounded card background fill and no shadow; keep cover thumbnail, name, subtitle/note, and a subtle “Custom” indicator (system secondary styling). No context menu inside the view.

- [ ] **Step 1: Update `SelectorRow` layout/styling**

In `Falcon/SelectorRow.swift`, replace the current card styling with a cell-like row:
- Keep `HStack(spacing: 12) { cover …; VStack(alignment: .leading, spacing: 4) { … }; Spacer(minLength: 0) }`.
- Cover: `.resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))` (unchanged).
- Title: `Text(client.name).font(.body.weight(.semibold))`.
- “Custom” indicator: when `client.isCustom`, show `Text("Custom")` (or keep text `CUSTOM` but styled subtly) using `.font(.caption.weight(.semibold)).foregroundStyle(.secondary)` (no bright cyan fill/badge). Do not use cyan accent for this label.
- Subtitle: `Text(client.note ?? (client.url == nil ? "Bundle missing" : "Tap to launch")).font(.footnote).foregroundStyle(.secondary)` (unchanged logic).
- Remove the `.padding(12)`, the rounded rectangle background fill `Color.white.opacity(0.08)`, and the shadow. Use default list row padding/appearance (no custom background modifier that adds a card). Keep a reasonable vertical padding if needed via `.padding(.vertical, 8)` or rely on list defaults; prefer minimal custom padding.

Resulting structure (example intent):
```swift
HStack(spacing: 12) {
    cover ...
    VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
            Text(client.name).font(.body.weight(.semibold))
            if client.isCustom {
                Text("Custom")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        Text(client.note ?? (client.url == nil ? "Bundle missing" : "Tap to launch"))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    Spacer(minLength: 0)
}
.padding(.vertical, 8)
```

- [ ] **Step 2: Build to verify**

Run: `cd "/Volumes/SSD/iOS apps/Falcon" && xcodebuild -project Falcon.xcodeproj -scheme Falcon -sdk iphonesimulator build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Falcon/SelectorRow.swift
git commit -m "ui: make selector row cell-style for native list"
```

---

### Task 2: Convert selector screen to a grouped system List with toolbar “Add Client”

**Files:**
- Modify: `Falcon/ContentView.swift` (replace `clientSelector` body and adjust placement of “Add Client”; keep all helpers/actions unchanged: `selectClient`, `coverMenuItems`, `removeCustomClient`, `coverImage`, `coverRevision`, `showingFileImporter`, etc.)

**Interfaces:**
- Consumes: `SelectorRow(client:cover:)` from Task 1, existing state/actions in `ContentView`.
- Produces: `clientSelector` rendered as a `List` (grouped/inset grouped style) with sections “BUNDLED” and “CUSTOM”, toolbar trailing “Add Client” button, preserved context menus and behaviors.

- [ ] **Step 1: Replace `clientSelector` with a List-based layout**

In `Falcon/ContentView.swift`, replace the current `clientSelector` implementation:
- Use `NavigationStack`? Or just `List` with `.listStyle(.insetGrouped)` (preferred for Apple-like grouped look). If not embedded in a navigation stack, adding `.toolbar` is still possible on iOS; prefer wrapping the selector content in `NavigationStack { ... }` inside `clientSelector` so toolbar/title behave well, or apply `.toolbar` directly to `List`. Keep changes minimal and consistent with existing UI (no big nav title required). A simple approach: `NavigationStack { List { ... } .listStyle(.insetGrouped) .toolbar { ... } }`.
- Sections:
  - `Section("BUNDLED") { ForEach(GameClient.bundled) { client in ... } }`
  - `Section { ... } header: { Text("CUSTOM") } footer: { if customClients.isEmpty { Text("No custom clients yet. Add a single .html client file from Files.") } else { Text("Swipe down in the top-left corner to reveal Quit…") /* keep existing footer hint meaning; can be placed once */ } }` — but be careful not to duplicate the long footer. Better: put the long hint as a global footer outside the list or as a footer in the CUSTOM section only if empty? Or keep it as a `Section(footer: Text(...))` at the end. Preserve the existing hint text: “Swipe down in the top-left corner to reveal Quit. 1.8.8-wasm may need single-thread if it hangs starting the integrated server.” (from current code).
- For each bundled client row:
  - `Button { selectClient(client) } label: { SelectorRow(client: client, cover: coverImage(for: client)) }`
  - `.buttonStyle(.plain)` (or default) to keep tap behavior; keep `.disabled(client.url == nil)`.
  - `.id("\(client.id)-\(coverRevision)")`
  - `.contextMenu { coverMenuItems(for: client); ... reVCDOS actions same as before ... }` (unchanged logic).
- For CUSTOM section:
  - If `customClients.isEmpty`: show the empty-state text. In a List, you can put `Text("No custom clients yet...") .foregroundStyle(.secondary)` as a row or in section footer. Prefer section footer for cleanliness: `Section("CUSTOM") { } footer: { if customClients.isEmpty { Text("No custom clients yet. Add a single .html client file from Files.") } ; Text(long hint...) }` — or split: CUSTOM section has content rows when non-empty else an empty placeholder row; and put the long hint in a final section footer. Keep it readable and preserve the exact strings where practical.
  - If not empty: `ForEach(customClients) { client in ... same row + .contextMenu { coverMenuItems(for: client); Button(role: .destructive) { removeCustomClient(client) } label: { Label("Remove Client", systemImage: "trash") } } }`
- Toolbar: add trailing button “Add Client” (system style). Example:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showingFileImporter = true
        } label: {
            Label("Add Client", systemImage: "plus")
        }
    }
}
```
Remove the old header HStack that contained the big cyan “Add Client” capsule button.

- [ ] **Step 2: Verify layout strings and behavior wiring**

Ensure these remain unchanged in behavior:
- `showingFileImporter` still toggles from the toolbar button.
- `selectClient(_:)`, `removeCustomClient(_:)`, `coverMenuItems(for:)`, `coverImage(for:)`, reVCDOS context menu branches (download/delete) unchanged.
- Disabled state uses `.disabled(client.url == nil)`.
- Footer hint text is still present somewhere in the selector UI (list footer or bottom section footer).

- [ ] **Step 3: Build to verify**

Run: `cd "/Volumes/SSD/iOS apps/Falcon" && xcodebuild -project Falcon.xcodeproj -scheme Falcon -sdk iphonesimulator build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verification checklist (no automated UI tests)**

Verify in Simulator/device:
- Selector shows as grouped list with “BUNDLED” and “CUSTOM” sections (Apple-like inset grouped appearance).
- “Add Client” is in the toolbar and opens the file importer; successful import adds a custom client row.
- Tapping a bundled/custom row with valid URL launches it; rows with missing URL are disabled.
- Long-press/context menu works on rows: cover actions appear; reVCDOS row shows “Download full assets…” and “Delete downloaded assets…” when assets present; custom rows show “Remove Client” and it works.
- Empty CUSTOM shows the empty-state message.
- Footer hint text is visible.
- Quit overlay/orientation behavior unchanged (quick sanity: launch a client, back out).

- [ ] **Step 5: Commit**

```bash
git add Falcon/ContentView.swift
git commit -m "ui: use grouped list layout for client selector"
```
