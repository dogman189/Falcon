import Foundation

func testPreflightReportsMissingBinary() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let result = ReVCDOSLaunchPreflight.check(rootURL: root)
    assert(!result.canLaunch)
    assert(result.errorMessage?.contains("vc-sky-en-v6.wasm.br") == true)
}

func testPreflightAllowsCompleteBundle() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    for path in ReVCDOSAssetManifest.requiredRelativePaths {
        let file = root.appendingPathComponent(path)
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? Data("x".utf8).write(to: file)
    }
    let result = ReVCDOSLaunchPreflight.check(rootURL: root)
    assert(result.canLaunch)
    assert(result.errorMessage == nil)
    assert(result.rootURL == root.standardizedFileURL)
}
