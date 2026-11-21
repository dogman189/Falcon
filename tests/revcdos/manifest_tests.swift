import Foundation

func makeTempRoot() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func testManifestConstants() {
    assert(ReVCDOSAssetManifest.port == 8199)
    assert(ReVCDOSAssetManifest.launchURL.absoluteString == "http://localhost:8199/?fullscreen=0&lang=en")
    assert(ReVCDOSAssetManifest.requiredRelativePaths.count == 7)
}

func testMissingAssetsReportsBinaries() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let missing = ReVCDOSAssetManifest.missingAssets(in: root)
    assert(missing.contains("vcbr/vc-sky-en-v6.wasm.br"))
    assert(missing.contains("vcbr/vc-sky-ru-v6.wasm.br"))
}

func testResolvedFileURLRejectsTraversal() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    assert(ReVCDOSAssetManifest.resolvedFileURL(for: "../secrets", in: root) == nil)
    assert(ReVCDOSAssetManifest.resolvedFileURL(for: "/dist/index.html", in: root)?.lastPathComponent == "index.html")
}

func testContentTypeAndBrotliRules() {
    assert(ReVCDOSAssetManifest.contentType(for: "a.wasm.br") == "application/wasm")
    assert(ReVCDOSAssetManifest.contentType(for: "a.js") == "text/javascript")
    assert(ReVCDOSAssetManifest.usesBrotli("a.data.br") == true)
    assert(ReVCDOSAssetManifest.usesBrotli("a.js") == false)
}
