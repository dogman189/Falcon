# Optional vcsky bundling for reVCDOS — design

## Intent

Let the offline reVCDOS client optionally include the upstream `vcsky` game assets (~1.5 GB) in the app bundle. The game currently renders without them, but the upstream server exposes `/vcsky/...`, so including them makes the bundle complete for any future feature that reads those paths.

## Goals

- An Xcode build setting, `FALCON_BUNDLE_VCSKY`, default `NO`.
- When set to `YES`, a build phase copies the pre-extracted `vcsky/` folder from the repo root into the app bundle at `reVCDOS/vcsky/`.
- A one-time helper script downloads `revcdos.bin` and extracts only `vcsky/` to the repo root (gitignored).
- No runtime behavior change when the toggle is off; the app remains ~122 MB.
- README documents how to prepare assets and flip the toggle.

## Non-goals

- An in-app toggle or runtime download (that is not "bundling").
- Committing any game assets to git.
- Changing the other clients or the existing local server routing.
- Public distribution; this remains a personal sideload app.

## Approaches

1. **Build setting + copy script phase (chosen).** Clean on/off in Xcode, assets kept outside the synchronized `Falcon/` folder so the folder-flattening workaround does not need thousands of exclusions. The existing responder already maps `/vcsky/...` to `<bundle>/reVCDOS/vcsky/...`, so no routing code changes are needed. Cost: a script phase in the JSON project file and a one-time ~1 GB download.
2. **Permanent folder reference, always bundled.** Simpler project structure but makes every build ~1.6 GB with no way to opt out. Rejected.
3. **Download on demand in the app.** Keeps the bundle small but is not bundling, and would need UI plus network code. Rejected.

## Constraints

- Upstream `vcsky` data is ~1.5 GB expanded; the archive is ~1.08 GB downloaded once.
- `project.xcproj` is JSON5 and supports `{ "kind": "script", "shell": ..., "script": [...] }` build phases.
- User script sandboxing is currently on; the copy phase needs either declared inputs/outputs or an override.
- The assets must live outside `Falcon/` (synchronized folder) to avoid polluting the exclusion list.

## Decisions left to the builder

- Exact shell script text and whether to disable user-script sandboxing for the target or declare file inputs/outputs.
- Exact shape of the one-time extraction script (reuse `utils/packer_brotli.py` from the pinned upstream commit).
- A focused test asserting that `/vcsky/...` requests resolve against the bundle when the folder is present.
