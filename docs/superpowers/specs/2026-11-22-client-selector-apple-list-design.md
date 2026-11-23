# Client Selector Redesign (Apple/system-native list) — Short Design

Date: 2026-11-22  
Scope: Client selector/home screen (ContentView selector UI) only.

## Intent / why
The current selector feels “vibe-coded”. Goal: a cleaner, more **Apple/system-native** visual style.

## Goals
- Use a system-style grouped/list presentation (e.g. inset grouped feel) with system typography and colors.
- Reduce heavy custom chrome: remove prominent custom card fills/shadows and bright cyan accents where they conflict with a native look (use system tint/secondary appropriately).
- Keep all existing behavior.

## Non-goals
- No changes to launch/select flow, `GameClient` models, cover storage/import/reset logic, custom client import/remove logic.
- No changes to reVCDOS asset download/delete actions or their availability rules.
- No changes to quit overlay behavior or orientation lock behavior.

## Constraints
- Existing iOS SwiftUI app. Keep row data/identifiers and disabled states (`client.url == nil`) intact. Keep `.contextMenu` actions intact.

## Approaches considered
1. **Native list (chosen):** system list/grouped styling, cell-like rows, “Add Client” in a standard control position, subtle “Custom” treatment.
2. Refined flatter cards (keep stacked layout) — rejected (still custom).
3. Grid launcher — rejected (layout change, not requested).

## Chosen approach (1)
- Replace the selector’s `ScrollView` + custom stacked cards presentation with a **system list/grouped style** (builder may choose `.insetGrouped` vs similar system style).
- **BUNDLED** and **CUSTOM** are list sections with system section headers.
- Rows are cell-like: cover thumbnail + title + subtitle/note. “Custom” is shown subtly (system secondary styling), not a bright cyan pill/fill. Remove custom card background/shadow styling.
- **“Add Client”** moves to a standard control (e.g. toolbar trailing button) using system styling, preserving the same action.
- Preserve: `.contextMenu` on rows (cover actions for all; reVCDOS extras on bundled reVCDOS row; “Remove Client” destructive on custom rows), footer hint text (placement may move to list footer), empty CUSTOM state copy/behavior, and `id`/disabled behavior.

## Builder’s calls
- Exact list style (`.insetGrouped` vs alternatives).
- Precise “Add Client” placement and styling details.
- Exact “Custom” label styling.
- Footer placement (list footer vs adjacent text).
