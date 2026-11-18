# Custom Client Import Design

**Approved:** 2026-11-17

## Intent
Allow adding a user-chosen offline Eaglercraft client so Falcon is not limited to built-in bundled builds.

## Goals
- Add Client action on launcher opens Files picker for a single `.html` file.
- Falcon copies the selected file into private app storage and persists metadata across launches.
- Custom clients appear in the launcher and launch like bundled clients.
- Custom clients can be removed (deletes copied file and metadata record).

## Non-goals / Anti-goals
- No multi-file/folder clients, URLs/remote clients, or rename/edit UI.
- No import sources beyond the Files picker.
- Do not depend on the original file remaining in place; do not modify bundled clients.

## Constraints
- iOS sandboxed app using `WKWebView.loadFileURL(_:allowingReadAccessTo:)` for local files.
- Bundled clients remain in app bundle; custom clients stored in app container.

## Approach (chosen)
- Refactor client representation to support bundled and custom sources (bundled: bundle resource; custom: stored file URL/id/display name with “Custom” badge).
- Store imported copies in `Application Support/CustomClients` with persisted metadata (JSON). Load on launch; delete file and record on remove.
- Launcher: Add Client button; custom clients shown in a separate “Custom” section below bundled clients; remove via swipe/context menu.
- Web view loads custom file URLs with read access to their parent directory.

## Builder calls
- Display name derived from imported filename (without extension where appropriate).
- Duplicate imports receive unique stored filename/id.
- Remove is immediate (no confirmation dialog) unless changed during implementation review.