# SDD ledger — plan: docs/superpowers/plans/2026-11-16-launch-client-selector.md

Pre-flight: no shared interfaces (sequential tasks; Task 2 consumes bundled clients/catalog from Task 1, Task 3 consumes Task 2 interface).
Ruling: Copied current builds from /Volumes/SSD/Falcon Builds; byte sizes observed as Eaglet 2777084, 1.8.8-wasm 12972767, 26.3-wasm 68220124 (differ from earlier noted values) — used source files as-is. Cost if wrong: none if files are valid builds.
Task 1: complete (commits 6b66d9f..4fe7866, tests: ls/cp, python3 byte-size check, xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO → BUILD SUCCEEDED)
Task 2: complete (commits 9d421e3..115aef6, tests: xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO → BUILD SUCCEEDED)
Task 3: complete (commits 115aef6..a594e58, tests: xcodebuild -project Falcon.xcodeproj -scheme Falcon -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO → BUILD SUCCEEDED)
Task 4: manual runtime verification not executable in this environment (no interactive device/simulator UI). Code review: selector lists BundledClient.all (Eaglet, 1.8.8-wasm, 26.3-wasm) on launch, tap sets selection and renders immersive EaglerWebView(fileURL:) full-screen, no persisted selection. User should verify on device/simulator that each bundled client loads (especially 26.3-wasm.html) and immersion is preserved.
Final review: self-review (no subagent tool). Rulings: source byte sizes differed from plan's noted values; used current /Volumes/SSD/Falcon Builds files as-is.
