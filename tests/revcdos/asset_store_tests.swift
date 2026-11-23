import Foundation

func testAssetStoreReadiness() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    assert(!ReVCDOSAssetStore.isReady(at: root))

    for name in ReVCDOSAssetStore.assetNames {
        let file = root.appendingPathComponent("vcbr").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
    }
    for name in ["index.html", "index.js", "game.js"] {
        let file = root.appendingPathComponent("dist").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
    }
    assert(!ReVCDOSAssetStore.isReady(at: root), "marker not yet written")
    let vcsky = root.appendingPathComponent("vcsky", isDirectory: true)
    try? FileManager.default.createDirectory(at: vcsky, withIntermediateDirectories: true)
    try Data("sums".utf8).write(to: vcsky.appendingPathComponent("sha256sums.txt"))
    try ReVCDOSAssetStore.markReady(at: root)
    assert(ReVCDOSAssetStore.isReady(at: root))

    try ReVCDOSAssetStore.clear(at: root)
    assert(!ReVCDOSAssetStore.isReady(at: root))
}
