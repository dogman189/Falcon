# Falcon Feature Roadmap & Ideas

A curated catalog of potential features, gameplay enhancements, and technical expansions for the Falcon iOS game launcher.

---

## 1. In-Game Controls & Gameplay QoL

### Virtual Touch Gamepad Overlay
- **Customizable On-Screen Controls:**
  - Virtual D-pad, dual analog thumbsticks, and configurable action buttons (A, B, X, Y, L/R bumpers).
  - Designed for web/WASM clients and retro emulators that lack built-in touch input.
  - Injects standard HTML5 Gamepad API events or synthetic keyboard keycodes into the `WKWebView`.
- **Haptic Touch Feedback:**
  - Tactile ticks on button presses using `UIImpactFeedbackGenerator`.
- **Opacity & Layout Editor:**
  - Adjust transparency, scale, and reposition controls per game client.
  - Option to auto-hide overlay when a physical Bluetooth/MFi controller is connected.

### In-Game Quick Menu / Pause HUD
- **Enhanced In-Game Gesture Drawer:**
  - Expand the top-left quit button into a slide-out game overlay.
- **Controls & Actions:**
  - **Volume & Audio Toggle:** Mute or boost client audio independently.
  - **Quick Screenshot:** Save full-resolution gameplay captures directly to the Photos library.
  - **Aspect Ratio & Display Modes:** Switch between 4:3 (retro), 16:9, Stretch, or Pixel-Perfect Integer scaling.
  - **Quick Reset / Reload:** Soft-restart the web runtime without returning to the library.
  - **Fast-Forward / Turbo Mode:** Trigger emulation speedup for supported cores.

---

## 2. Save State & Data Management

### Save Data Export & Import (Backup & Restore)
- **Universal Save Manager:**
  - Extract and restore game save data from `WKWebView` storage:
    - `localStorage`
    - `IndexedDB`
    - Emscripten / WebAssembly Virtual Filesystem (`/root`, `FS.syncfs`).
- **Files App & iCloud Drive Integration:**
  - Export saves as `.json` or `.zip` archives directly to the iOS Files app or automatic iCloud Drive sync for seamless cross-device play.
- **Per-Game Save Slot Snapshots:**
  - Create multiple labeled save backups per game with timestamp and playtime tags.

---

## 3. Library Management & Organization

### Categorization & Filtering
- **Smart Collections:**
  - Default collections: *Favorites*, *Recently Played*, *Universal Retro*, *Ports & Engines*.
  - User-defined tags and custom playlists.
- **Search & Sort:**
  - Live search bar in Library view.
  - Sort by: Last Played, Date Added, Name, and Total Playtime.

### Playtime Tracking & Statistics
- **Activity Metrics:**
  - Track total time in-game per client.
  - "Last played" timestamps and launch counts.
  - Display stats card in the game details sheet or context menu.

### Metadata & Cover Scraping
- **Automated Box Art & Game Info:**
  - Search open databases (such as OpenVGDB or ScreenScraper) to fetch high-res cover art, descriptions, and release years for imported ROMs and custom web clients.

---

## 4. RetroPacker & Emulation Expansions

### Additional Retro System Cores
- **Expand System Catalog:**
  - Add universal core profiles for additional systems:
    - **Sega:** Genesis / Mega Drive, Master System, Game Gear
    - **Arcade:** MAME / FinalBurn Neo cores
    - **SNK:** Neo Geo Pocket / Color
    - **Atari:** 2600, 7800, Lynx
    - **Classic Computers:** Commodore 64, Amiga (WASM DOSBox / PUAE ports)
- **Multi-File & Disc-Based ROM Support:**
  - Support packaging multi-file games (e.g. `.cue` + `.bin` tracks) into compressed, single-file HTML bundles.

### Cheats & Save State Injection
- **Game Genie / Action Replay Support:**
  - Enable cheat code input fields when packing ROMs or in the in-game overlay.

---

## 5. Hardware & Performance Enhancements

### External Display & AirPlay Support
- **Dual-Screen / Handheld Mode:**
  - When connected to a TV/monitor via USB-C HDMI or AirPlay:
    - External screen shows clean, borderless fullscreen gameplay.
    - iPhone/iPad screen acts as a dedicated virtual touchscreen controller with macro buttons and status displays.

### Low Latency & High Refresh Rate
- **ProMotion Support:**
  - Optimize `CADisplayLink` and WebKit rendering pipeline to support 120Hz refresh rates where supported by the client.
- **Low-Latency Gamepad Polling:**
  - Reduce input lag by tuning `GCController` polling rates and direct web event dispatching.
