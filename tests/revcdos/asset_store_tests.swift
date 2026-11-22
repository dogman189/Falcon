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
    assert(!ReVCDOSAssetStore.isReady(at: root), "marker not yet written")
    try ReVCDOSAssetStore.markReady(at: root)
    assert(ReVCDOSAssetStore.isReady(at: root))

    try ReVCDOSAssetStore.clear(at: root)
    assert(!ReVCDOSAssetStore.isReady(at: root))
}
