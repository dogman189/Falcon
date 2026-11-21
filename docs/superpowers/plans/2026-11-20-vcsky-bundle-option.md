# Optional vcsky Bundling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an off-by-default Xcode build option that copies pre-extracted `vcsky` game assets into the reVCDOS bundle so the existing `/vcsky/` route can serve them.

**Architecture:** Keep the ~1.5 GB assets outside the synchronized `Falcon/` folder at repo-root `vcsky/` (gitignored). A `FALCON_BUNDLE_VCSKY` build setting gates a script build phase that copies that folder into `reVCDOS/vcsky/` in the app bundle. The existing `ReVCDOSHTTPResponder` already maps `/vcsky/...` to `<bundle>/reVCDOS/vcsky/...`, so no routing change is needed.

**Tech Stack:** Xcode 27.2 JSON project (`.xcproj` JSON5), shell build phase, Foundation Swift host tests, `packer_brotli.py` from upstream commit `95f14ef3c1d0a872ecd0881544cc7e1f55cb1946`.

**Spec:** `docs/superpowers/specs/2026-11-20-vcsky-bundle-option-design.md`

## Global Constraints

- Build setting name: `FALCON_BUNDLE_VCSKY`; default `NO`; only the exact value `YES` enables bundling.
- Bundled destination inside the app: `reVCDOS/vcsky/`.
- Source assets location: repository root `vcsky/`, gitignored, never committed.
- Toggle off must leave the app ~122 MB and the game behavior unchanged.
- Toggle on with missing source assets must fail the build with a clear message.
- Personal/sideload use only; no App Store distribution.
- Do not add thousands of entries to the `membership-exceptions` exclusion list in `project.xcproj`.

## Review Focus

- **Toggle off by default** — a reasonable person expects a normal small build: Task 2 verifies `vcsky/` is absent from the app bundle with the default setting.
- **Toggle on with no prepared assets** — expect a clear build error, not a silently empty folder: Task 2 builds with `FALCON_BUNDLE_VCSKY=YES` and no `vcsky/` source, expecting the error message.
- **Toggle on with assets present** — expect the assets in the bundle at the path the server uses: Task 2 builds with `YES` and a small fixture, checking `reVCDOS/vcsky/sha256sums.txt` exists.
- **`/vcsky/` requests resolve against the bundle root** — expect the right file and MIME type: Task 3 adds `testVCSKYPathServedFromBundleRoot`.
- **Re-running asset preparation is idempotent** — expect no re-download when `vcsky/` already exists: Task 1 test.

---

## File Structure

- `Scripts/prepare-vcsky.sh` (new) — one-time download/extract helper, idempotent.
- `.gitignore` (modify) — ignore `/vcsky/`.
- `Falcon.xcodeproj/project.xcproj` (modify) — add `FALCON_BUNDLE_VCSKY = NO` target setting, `ENABLE_USER_SCRIPT_SANDBOXING = NO`, and a script build phase after `resources`.
- `tests/revcdos/responder_tests.swift` (modify) — add the `/vcsky/` routing test.
- `README.md` (modify) — document the toggle and preparation script.

---

### Task 1: Asset preparation script

**Files:**
- Create: `Scripts/prepare-vcsky.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `vcsky/` at repo root containing the upstream `fetched/`, `fetched-ru/`, and `sha256sums.txt` entries; script is idempotent when that folder exists.

- [ ] **Step 1: Write the failing check**

Create a temporary directory with a `vcsky/` subfolder and a file `vcsky/sha256sums.txt`. Run the script with `REPO_ROOT` pointing at that directory (the script accepts an optional first argument for the repo root). Expected behavior: exit 0, leave the file untouched, and print no download activity.

- [ ] **Step 2: Run the check to verify it fails**

Run: `bash -n Scripts/prepare-vcsky.sh`
Expected: fails because the file does not exist yet.

- [ ] **Step 3: Implement the script**

`Scripts/prepare-vcsky.sh`:
- Accept optional `$1` as `REPO_ROOT`, defaulting to the script's parent directory.
- If `$REPO_ROOT/vcsky` exists and is a directory, print `vcsky already prepared` and exit 0.
- Otherwise download `https://folder.morgen.qzz.io/revcdos.bin` to a `mktemp -d` directory, shallow-clone `https://github.com/Lolendor/reVCDOS` at commit `95f14ef3c1d0a872ecd0881544cc7e1f55cb1946`, run `python3 -c '... from packer_brotli import unpack_file; unpack_file(...)'` into that temp dir, move `<tmp>/unpacked/vcsky` to `$REPO_ROOT/vcsky`, and delete the temp dir.
- Use `set -euo pipefail` and `curl -L --fail`.

Add `/vcsky/` to `.gitignore`.

- [ ] **Step 4: Run the check to verify it passes**

Run the same idempotence check from Step 1 and `bash -n Scripts/prepare-vcsky.sh`.
Expected: exit 0, fixture file intact, message `vcsky already prepared`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/prepare-vcsky.sh .gitignore
git commit -m "build: add vcsky asset preparation script"
```

---

### Task 2: Build toggle and copy phase

**Files:**
- Modify: `Falcon.xcodeproj/project.xcproj`

**Interfaces:**
- Consumes: repo-root `vcsky/` from Task 1.
- Produces: build setting `FALCON_BUNDLE_VCSKY`; when `YES`, `reVCDOS/vcsky/` in the app bundle.

- [ ] **Step 1: Verify current default state**

Build and confirm the bundle has no `vcsky` directory:

```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
APP="$(xcodebuild -project Falcon.xcodeproj -scheme Falcon -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -showBuildSettings | awk -F'= ' '/^ *TARGET_BUILD_DIR/{print $2}')/Falcon.app"
test ! -d "$APP/reVCDOS/vcsky"
```

Expected: passes.

- [ ] **Step 2: Add the toggle**

In the `Falcon` target's `build-settings`, add `"FALCON_BUNDLE_VCSKY": "NO"` and `"ENABLE_USER_SCRIPT_SANDBOXING": "NO"`. In the target's `build-phases`, insert after `"resources"`:

```
{
  "kind": "script",
  "name": "Bundle vcsky (optional)",
  "shell": "/bin/sh",
  "script": [
    ... lines implementing the gated copy ...
  ],
},
```

The script must: exit 0 unless `$FALCON_BUNDLE_VCSKY` equals `YES`; fail with `error: FALCON_BUNDLE_VCSKY=YES but vcsky/ is missing. Run Scripts/prepare-vcsky.sh` when `$SRCROOT/vcsky` is absent; otherwise `mkdir -p` and `cp -R "$SRCROOT/vcsky/." "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/reVCDOS/vcsky/"`.

- [ ] **Step 3: Verify the failure mode**

With no repo-root `vcsky/`, run:

```bash
xcodebuild -project Falcon.xcodeproj -scheme Falcon -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO FALCON_BUNDLE_VCSKY=YES build
```

Expected: build fails and output contains the exact error message from Step 2.

- [ ] **Step 4: Verify the enabled mode with a fixture**

Create a temporary repo-root `vcsky/sha256sums.txt` fixture, then run the same build with `FALCON_BUNDLE_VCSKY=YES` and check:

```bash
test -s "$APP/reVCDOS/vcsky/sha256sums.txt"
```

Expected: passes. Remove the fixture afterwards.

- [ ] **Step 5: Commit**

```bash
git add Falcon.xcodeproj/project.xcproj
git commit -m "build: add optional vcsky bundle phase"
```

---

### Task 3: Server route test

**Files:**
- Modify: `tests/revcdos/responder_tests.swift`
- Modify: `tests/revcdos/main.swift`

**Interfaces:**
- Consumes: `ReVCDOSHTTPResponder.response(method:path:rootURL:)` from the existing implementation.

- [ ] **Step 1: Write the failing test**

Add `testVCSKYPathServedFromBundleRoot()` to `responder_tests.swift`. Create a temp root with `vcsky/sha256sums.txt` containing `fixture`. Assert that `ReVCDOSHTTPResponder.response(method: "GET", path: "/vcsky/sha256sums.txt", rootURL: root)` has `status == 200`, `body == Data("fixture".utf8)`, and `Content-Type: text/plain`. Register the test in `main.swift`.

- [ ] **Step 2: Run the test to verify it fails**

Use the full host-suite compile command (all Swift sources and test files).
Expected: FAIL because the responder currently routes `/vcsky/...` correctly but the test fixture/assertion is newly added; if it already passes, add the missing `Content-Type` assertion so the failure is about text/plain.

- [ ] **Step 3: Implement any missing behavior**

If needed, extend `ReVCDOSAssetManifest.contentType(for:)` so `.txt` maps to `text/plain` (it already does) and leave the `/vcsky/` routing branch in `ReVCDOSHTTPResponder.response` unchanged.

- [ ] **Step 4: Run the test to verify it passes**

Run the full host suite.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add tests/revcdos/responder_tests.swift tests/revcdos/main.swift
git commit -m "test: cover vcsky asset routing"
```

---

### Task 4: Documentation and final verification

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: all prior tasks.

- [ ] **Step 1: Document the option**

In `README.md`, add a short "Optional vcsky assets" section: run `Scripts/prepare-vcsky.sh` once, set `FALCON_BUNDLE_VCSKY = YES` in the Falcon target build settings, rebuild; note the ~1.5 GB size and that it is off by default.

- [ ] **Step 2: Run the full host suite and default build**

```bash
swiftc -swift-version 5 -o /tmp/falcon-tests ...   # all Swift sources and test files
/tmp/falcon-tests
xcodebuild ... build
```

Expected: `ALL TESTS PASSED` and `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify the default build has no vcsky and the game still launches**

Check `$APP/reVCDOS/vcsky` is absent, install the app on the booted simulator, launch with `--client=bundled:reVCDOS`, and confirm the start page renders.

- [ ] **Step 4: Verify no large files are tracked**

```bash
git status --short
git ls-files | grep '^vcsky/' || true
```

Expected: no `vcsky/` files tracked and no fixture left behind.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document optional vcsky bundling"
```

## Self-Review

- Spec coverage: build setting (Task 2), copy phase (Task 2), preparation script (Task 1), default small app (Tasks 2 and 4), clear failure when assets missing (Task 2), README (Task 4), routing (Task 3), personal-use/no committed assets (Tasks 1 and 4).
- Step scan: each step has one checkable result; the script body and build-phase script are fixed by the spec.
- Type consistency: `FALCON_BUNDLE_VCSKY`, `Scripts/prepare-vcsky.sh`, and `reVCDOS/vcsky/` are used identically in every task.
- Review Focus: all five items are pinned to a verification or test in their owning task.
- Proportion: plan is shorter than the implementation it describes; no full code transcripts.
