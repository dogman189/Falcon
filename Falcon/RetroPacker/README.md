# Vendored universal retro game packer

This directory holds the upstream **portable-retro-games** universal web packer, used as the packing engine for Falcon's "Pack Retro Game" flow. It is vendored verbatim so the upstream packing logic is reused rather than reimplemented.

## Provenance

| Field | Value |
| --- | --- |
| Upstream repository | https://github.com/aciderix/portable-retro-games |
| Source file path | `docs/pack_game_en.html` |
| Raw source URL | https://raw.githubusercontent.com/aciderix/portable-retro-games/main/docs/pack_game_en.html |
| Upstream commit | `66d4c40af8d85834adc725c2044cae835747b696` (2026-03-06, "feat: add MSX Packer link to navigation in all web packers") |
| Upstream blob SHA-1 (git) | `5c0834054ccbe9bb01beb8f3d1911e3a30023dfa` |
| SHA-256 of vendored bytes | `f1490bb84fca61814fe573a78e941066d6d59126eedb09c18b656f19cffaae5c` |
| Size | 71182 bytes |
| Vendored on | 2026-11-23 |
| Vendored path | `Falcon/RetroPacker/pack_game_en.html` |

The upstream commit above is the most recent commit touching `docs/pack_game_en.html` on `main`, and its blob SHA-1 matches the vendored file exactly.

## License

Upstream is MIT licensed. The full notice is vendored verbatim in [`LICENSE`](LICENSE) (upstream: https://github.com/aciderix/portable-retro-games/blob/main/LICENSE; Copyright (c) 2026 Aciiderixx; upstream blob SHA-1 `40b931024b4a04fd9b641251cf7eb131ccd4bbb4`). The MIT copyright and permission notice must accompany copies or substantial portions of the vendored source — include `LICENSE` in the app's third-party notices/About screen when this resource is bundled.

## Integration rules

- **Keep upstream logic intact.** Do not modify the packer's system table, core selection, download/generation code, or embedded HTML template. Falcon reuses this engine as-is.
- **Falcon-specific bridge behavior belongs in `RetroPackerBridge.js`**, a separate resource loaded by the page. If a tiny hook inside the vendored HTML is unavoidable, wrap it in a clearly marked block:
  ```html
  <!-- FalconBridge:begin -->
  ...
  <!-- FalconBridge:end -->
  ```
  Keep such hooks minimal and greppable by `FalconBridge` so upstream updates stay easy to rebase.
- **No ROMs and no emulator cores are bundled.** The user supplies a ROM they own; cores are downloaded on demand during packing (network required when uncached).

## Verifying / updating the vendored bytes

```bash
curl -sSL "https://raw.githubusercontent.com/aciderix/portable-retro-games/main/docs/pack_game_en.html" \
  -o /tmp/pack_game_en.html
shasum -a 256 /tmp/pack_game_en.html
git hash-object /tmp/pack_game_en.html   # should match the upstream blob SHA-1 above
wc -c /tmp/pack_game_en.html
```

If the upstream bytes change, replace `Falcon/RetroPacker/pack_game_en.html`, re-apply only the marked `FalconBridge` hooks, and update the commit/SHA/size/date fields in this README.
