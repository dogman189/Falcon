import Foundation

private func makeTemporaryStoreRoot() throws -> URL {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

func testImportGeneratedClientWritesFileAndRecord() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = CustomClientStore(baseDirectoryURL: root)
    let html = Data("<html><body>Super Mario</body></html>".utf8)

    let client = try store.importGeneratedClient(named: "Super Mario", htmlData: html)

    assert(client.name == "Super Mario")
    assert(client.isCustom)
    guard case let .custom(fileURL) = client.source else {
        assertionFailure("expected a custom source")
        return
    }
    assert(fileURL.pathExtension == "html")
    assert(fileURL.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
    let savedHTML = try Data(contentsOf: fileURL)
    assert(savedHTML == html)
    let loaded = store.load()
    assert(loaded.contains(where: { $0.id == client.id }))
}

func testImportGeneratedClientKeepsDuplicateNamesDistinct() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = CustomClientStore(baseDirectoryURL: root)

    let first = try store.importGeneratedClient(named: "Sonic", htmlData: Data("first".utf8))
    let second = try store.importGeneratedClient(named: "Sonic", htmlData: Data("second".utf8))

    assert(first.id != second.id)
    guard case let .custom(firstURL) = first.source,
          case let .custom(secondURL) = second.source else {
        assertionFailure("expected custom sources")
        return
    }
    assert(firstURL != secondURL)
    assert(firstURL.lastPathComponent == "Sonic.html")
    assert(secondURL.lastPathComponent == "Sonic-2.html")
    let savedSecond = try Data(contentsOf: secondURL)
    assert(savedSecond == Data("second".utf8))
    assert(store.load().count == 2)
}

func testImportGeneratedClientSanitizesNameForFileName() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = CustomClientStore(baseDirectoryURL: root)

    let client = try store.importGeneratedClient(named: "  Zelda: A/Link  ", htmlData: Data("<html></html>".utf8))

    assert(client.name == "Zelda: A/Link")
    guard case let .custom(fileURL) = client.source else {
        assertionFailure("expected a custom source")
        return
    }
    assert(fileURL.lastPathComponent == "Zelda- A-Link.html")
    assert(fileManager.fileExists(atPath: fileURL.path))
}

func testImportGeneratedClientAvoidsDoubleHtmlExtension() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = CustomClientStore(baseDirectoryURL: root)

    let client = try store.importGeneratedClient(named: "Metroid.html", htmlData: Data("<html></html>".utf8))

    guard case let .custom(fileURL) = client.source else {
        assertionFailure("expected a custom source")
        return
    }
    assert(fileURL.lastPathComponent == "Metroid.html")
}

func testFileImportStillWorksWithInjectedDirectory() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let sourceURL = root.appendingPathComponent("Tetris.htm")
    try Data("<html>Tetris</html>".utf8).write(to: sourceURL)
    let store = CustomClientStore(baseDirectoryURL: root.appendingPathComponent("Clients", isDirectory: true))

    let client = try store.importClient(from: sourceURL)

    assert(client.name == "Tetris")
    assert(client.isCustom)
    guard case let .custom(fileURL) = client.source else {
        assertionFailure("expected a custom source")
        return
    }
    assert(fileURL.lastPathComponent == "Tetris.htm")
    let savedHTML = try Data(contentsOf: fileURL)
    assert(savedHTML == Data("<html>Tetris</html>".utf8))
    assert(store.load().contains(where: { $0.id == client.id }))
}

func testImportGeneratedClientPersistsSystemIDMetadata() throws {
    let fileManager = FileManager.default
    let root = try makeTemporaryStoreRoot()
    defer { try? fileManager.removeItem(at: root) }
    let store = CustomClientStore(baseDirectoryURL: root.appendingPathComponent("Clients", isDirectory: true))
    let metadataStore = ClientLibraryMetadataStore(baseDirectoryURL: root.appendingPathComponent("Metadata", isDirectory: true))

    let client = try store.importGeneratedClient(
        named: "Pokemon",
        htmlData: Data("<html></html>".utf8),
        systemID: "gba",
        metadataStore: metadataStore
    )

    assert(metadataStore.metadata(for: client.id).systemID == "gba")
}
