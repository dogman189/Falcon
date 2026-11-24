import Foundation

private func makeTemporaryCoverRoot() throws -> URL {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeTestImageData() -> Data {
    Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02, 0x03])
}

func testCoverStorePrefersManualOverAuto() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryCoverRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientCoverStore(fileManager: fileManager, baseDirectoryURL: root)
    let id = "game-1"

    try store.saveAuto(data: makeTestImageData(), fileExtension: "jpg", for: id)
    let autoURL = store.autoCoverURL(for: id)
    assert(autoURL != nil)
    assert(store.coverURL(for: id) == autoURL)
    assert(store.hasManualCover(for: id) == false)

    try store.saveManual(data: makeTestImageData(), fileExtension: "png", for: id)
    let manualURL = store.manualCoverURL(for: id)
    assert(manualURL != nil)
    assert(store.coverURL(for: id) == manualURL)
    assert(store.coverURL(for: id) != autoURL)
    assert(store.hasManualCover(for: id) == true)
}

func testCoverStoreFallsBackToAutoWhenNoManual() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryCoverRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientCoverStore(fileManager: fileManager, baseDirectoryURL: root)
    let id = "game-2"

    try store.saveAuto(data: makeTestImageData(), fileExtension: "jpg", for: id)

    let autoURL = store.autoCoverURL(for: id)
    assert(autoURL != nil)
    assert(store.manualCoverURL(for: id) == nil)
    assert(store.coverURL(for: id) == autoURL)
    assert(store.hasManualCover(for: id) == false)
}

func testLegacyRootCoverIsTreatedAsManual() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryCoverRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientCoverStore(fileManager: fileManager, baseDirectoryURL: root)
    let id = "custom:legacy"

    let legacyURL = root.appendingPathComponent("custom_legacy.jpg")
    try makeTestImageData().write(to: legacyURL, options: .atomic)

    assert(store.hasManualCover(for: id) == true)
    assert(store.coverURL(for: id)?.standardizedFileURL.path == legacyURL.standardizedFileURL.path)
    let resolvedManual = store.manualCoverURL(for: id)
    assert(resolvedManual?.standardizedFileURL.path == legacyURL.standardizedFileURL.path)
}

func testResetManualCoverKeepsAuto() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryCoverRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientCoverStore(fileManager: fileManager, baseDirectoryURL: root)
    let id = "game-3"

    try store.saveAuto(data: makeTestImageData(), fileExtension: "jpg", for: id)
    try store.saveManual(data: makeTestImageData(), fileExtension: "png", for: id)

    let autoURL = store.autoCoverURL(for: id)
    assert(autoURL != nil)
    assert(store.hasManualCover(for: id) == true)

    store.resetManualCover(for: id)

    assert(store.hasManualCover(for: id) == false)
    assert(store.manualCoverURL(for: id) == nil)
    assert(store.autoCoverURL(for: id) == autoURL)
    assert(store.coverURL(for: id) == autoURL)
}

func testRemoveAllCoversDeletesManualAndAuto() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryCoverRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientCoverStore(fileManager: fileManager, baseDirectoryURL: root)
    let id = "game-4"

    let legacyURL = root.appendingPathComponent("game-4.jpg")
    try makeTestImageData().write(to: legacyURL, options: .atomic)

    try store.saveManual(data: makeTestImageData(), fileExtension: "png", for: id)
    try store.saveAuto(data: makeTestImageData(), fileExtension: "jpg", for: id)

    assert(store.manualCoverURL(for: id) != nil)
    assert(store.autoCoverURL(for: id) != nil)

    store.removeAllCovers(for: id)

    assert(store.manualCoverURL(for: id) == nil)
    assert(store.autoCoverURL(for: id) == nil)
    assert(store.coverURL(for: id) == nil)
    assert(store.hasManualCover(for: id) == false)
    assert(fileManager.fileExists(atPath: legacyURL.path) == false)
}
