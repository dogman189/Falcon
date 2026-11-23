# Bottom Tab Navigation Design

**Date:** 2026-11-23  
**Status:** Approved in chat

## Goal

Add a bottom bar so users can navigate between the game library and the retro packer.

## Scope

Small UI change in `ContentView` and minor adjustments to `RetroPackerView` integration.

## Design

- Add a `TabView` with two tabs:
  - **Library**: existing client selector/list, cover actions, file import, and game launch flow.
  - **Packer**: `RetroPackerView` as a tab (no sheet presentation).
- The Library toolbar Add menu keeps **Add Client from Files**; remove **Pack Retro Game** menu action because Packer is now a tab.
- On successful pack import, refresh custom clients and switch to the Library tab so the new client is visible.
- Hide the tab bar while a game is running/full-screen; quitting returns to the tabbed selector.
- Keep existing game launch, quit gesture, asset download, cover, and custom import behavior unchanged.

## Non-goals

- No new visual redesign of the library or packer screens.
- No changes to packing engine or storage behavior.
