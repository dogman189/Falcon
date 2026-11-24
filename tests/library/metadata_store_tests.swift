import Foundation

private func makeTemporaryStoreRoot() throws -> URL {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

func testMetadataStoreDefaultsAreEmpty() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)

    let metadata = store.metadata(for: "game-1")

    assert(metadata.systemID == nil)
    assert(metadata.lastPlayedAt == nil)
    assert(metadata.launchCount == 0)
    assert(metadata.totalPlaySeconds == 0)
    assert(store.allMetadata().isEmpty)
}

func testRecordLaunchSetsLastPlayedAndIncrementsCount() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)
    let launchDate = Date(timeIntervalSince1970: 100)
    let sessionEndDate = Date(timeIntervalSince1970: 160)

    store.recordLaunch(clientID: "game-1", at: launchDate)
    store.recordSessionEnd(clientID: "game-1", startedAt: launchDate, endedAt: sessionEndDate)

    let metadata = store.metadata(for: "game-1")
    assert(metadata.launchCount == 1)
    assert(metadata.lastPlayedAt == Date(timeIntervalSince1970: 100))
    assert(metadata.totalPlaySeconds == 60)
}

func testRecordSessionEndAccumulatesPlaytime() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)
    let firstStart = Date(timeIntervalSince1970: 100)
    let firstEnd = Date(timeIntervalSince1970: 160)
    let secondStart = Date(timeIntervalSince1970: 200)
    let secondEnd = Date(timeIntervalSince1970: 230)

    store.recordSessionEnd(clientID: "game-1", startedAt: firstStart, endedAt: firstEnd)
    store.recordSessionEnd(clientID: "game-1", startedAt: secondStart, endedAt: secondEnd)
    store.recordSessionEnd(clientID: "game-1", startedAt: secondEnd, endedAt: secondStart)

    let metadata = store.metadata(for: "game-1")
    assert(metadata.totalPlaySeconds == 90)
    assert(metadata.launchCount == 0)
    assert(metadata.lastPlayedAt == nil)
}

func testSetSystemIDPersistsAcrossReload() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }

    let store = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)
    store.setSystemID("com.rileytestut.delta.game.snes", for: "game-1")

    let reloaded = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)
    let metadata = reloaded.metadata(for: "game-1")

    assert(metadata.systemID == "com.rileytestut.delta.game.snes")
    assert(metadata.launchCount == 0)
    assert(metadata.totalPlaySeconds == 0)
}

func testRemoveDeletesClientMetadata() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)

    store.recordLaunch(clientID: "game-1", at: Date(timeIntervalSince1970: 100))
    store.setSystemID("com.rileytestut.delta.game.gba", for: "game-1")
    store.remove(clientID: "game-1")

    let metadata = store.metadata(for: "game-1")
    assert(metadata.systemID == nil)
    assert(metadata.lastPlayedAt == nil)
    assert(metadata.launchCount == 0)
    assert(metadata.totalPlaySeconds == 0)
    assert(store.allMetadata()["game-1"] == nil)
}

func testFinalizeSessionRecordsDurationOnce() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = ClientLibraryMetadataStore(fileManager: fileManager, baseDirectoryURL: root)
    let start = Date(timeIntervalSince1970: 100)
    let end = Date(timeIntervalSince1970: 160)

    var session: ActiveLaunchSession? = ActiveLaunchSession(clientID: "game-1", startedAt: start)
    LaunchSessionTracker.finalize(&session, at: end, store: store)
    LaunchSessionTracker.finalize(&session, at: Date(timeIntervalSince1970: 200), store: store)

    let metadata = store.metadata(for: "game-1")
    assert(metadata.totalPlaySeconds == 60)
    assert(session == nil)
}
