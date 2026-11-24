import Foundation

private func makeCustomClient(id: String, name: String) -> GameClient {
    GameClient(
        id: id,
        name: name,
        source: .custom(fileURL: URL(fileURLWithPath: "/tmp/\(id).html"))
    )
}

func testResolveTypeUsesBundledDefaults() throws {
    let wasm = GameClient.bundled.first { $0.id == "bundled:1.8.8-wasm" }!
    let revcdos = GameClient.bundled.first { $0.id == "bundled:reVCDOS" }!

    assert(LibraryShelfBuilder.resolveType(for: wasm, metadata: nil) == .web)
    assert(LibraryShelfBuilder.resolveType(for: revcdos, metadata: nil) == .port)
}

func testResolveTypeUsesKnownRetroSystemID() throws {
    let client = makeCustomClient(id: "custom:gba", name: "My GBA Game")
    let metadata = ClientLibraryMetadata(systemID: "gba")

    let resolved = LibraryShelfBuilder.resolveType(for: client, metadata: metadata)
    assert(resolved == .retroSystem("gba"))

    let shelves = LibraryShelfBuilder.shelves(
        for: [client],
        metadataByID: [client.id: metadata]
    )
    let systemShelf = shelves.first { $0.kind == .type(.retroSystem("gba")) }
    assert(systemShelf?.title == "Game Boy Advance")
}

func testResolveTypeFallsBackToWebForUnknownCustom() throws {
    let unknown = makeCustomClient(id: "custom:unknown", name: "Unknown")
    let noMetadata = makeCustomClient(id: "custom:none", name: "No Metadata")
    let unknownSystem = makeCustomClient(id: "custom:bad-system", name: "Bad System")
    let badMetadata = ClientLibraryMetadata(systemID: "not-a-real-system")

    assert(LibraryShelfBuilder.resolveType(for: unknown, metadata: nil) == .web)
    assert(LibraryShelfBuilder.resolveType(for: noMetadata, metadata: ClientLibraryMetadata()) == .web)
    assert(LibraryShelfBuilder.resolveType(for: unknownSystem, metadata: badMetadata) == .web)
}

func testShelvesBuildRecentlyPlayedAndTypeShelves() throws {
    let recentDate = Date(timeIntervalSince1970: 300)
    let olderDate = Date(timeIntervalSince1970: 100)
    let webClient = GameClient.bundled.first { $0.id == "bundled:1.8.8-wasm" }!
    let portClient = GameClient.bundled.first { $0.id == "bundled:reVCDOS" }!
    let gbaClient = makeCustomClient(id: "custom:gba", name: "Pokemon")
    let unknownClient = makeCustomClient(id: "custom:unknown", name: "Homebrew")

    let metadataByID: [String: ClientLibraryMetadata] = [
        webClient.id: ClientLibraryMetadata(lastPlayedAt: olderDate),
        gbaClient.id: ClientLibraryMetadata(systemID: "gba", lastPlayedAt: recentDate),
        unknownClient.id: ClientLibraryMetadata()
    ]

    let shelves = LibraryShelfBuilder.shelves(
        for: [webClient, portClient, gbaClient, unknownClient],
        metadataByID: metadataByID
    )

    assert(shelves.first?.kind == .recentlyPlayed)
    assert(shelves.first?.id == "recently-played")
    assert(shelves.first?.clients.map(\.id) == [gbaClient.id, webClient.id])

    let typeKinds = shelves.dropFirst().map(\.kind)
    assert(typeKinds.contains(.type(.web)))
    assert(typeKinds.contains(.type(.port)))
    assert(typeKinds.contains(.type(.retroSystem("gba"))))
}

func testRecentlyPlayedIsCappedAndStillAppearsInTypeShelf() throws {
    let clients = (0..<10).map { index in
        makeCustomClient(id: "custom:\(index)", name: "Game \(index)")
    }
    let metadataByID = Dictionary(uniqueKeysWithValues: clients.enumerated().map { index, client in
        (
            client.id,
            ClientLibraryMetadata(lastPlayedAt: Date(timeIntervalSince1970: Double(100 + index)))
        )
    })

    let shelves = LibraryShelfBuilder.shelves(
        for: clients,
        metadataByID: metadataByID,
        recentlyPlayedLimit: 8
    )

    let recentShelf = shelves.first { $0.kind == .recentlyPlayed }
    assert(recentShelf != nil)
    assert(recentShelf?.clients.count == 8)
    assert(recentShelf?.clients.first?.id == "custom:9")
    assert(recentShelf?.clients.last?.id == "custom:2")

    let webShelf = shelves.first { $0.kind == .type(.web) }
    assert(webShelf != nil)
    let webIDs = Set(webShelf?.clients.map(\.id) ?? [])
    for client in clients {
        assert(webIDs.contains(client.id))
    }
}

func testTypeShelvesAreOrderedAndSortedByRecentThenName() throws {
    let recent = Date(timeIntervalSince1970: 500)
    let older = Date(timeIntervalSince1970: 100)

    let webB = makeCustomClient(id: "custom:web-b", name: "Bravo")
    let webARecent = makeCustomClient(id: "custom:web-a", name: "Alpha")
    let webCNil = makeCustomClient(id: "custom:web-c", name: "Charlie")
    let port = GameClient.bundled.first { $0.id == "bundled:reVCDOS" }!
    let nes = makeCustomClient(id: "custom:nes", name: "NES Game")
    let gbaZ = makeCustomClient(id: "custom:gba-z", name: "Zelda")
    let gbaA = makeCustomClient(id: "custom:gba-a", name: "Astro")

    let metadataByID: [String: ClientLibraryMetadata] = [
        webB.id: ClientLibraryMetadata(lastPlayedAt: older),
        webARecent.id: ClientLibraryMetadata(lastPlayedAt: recent),
        webCNil.id: ClientLibraryMetadata(),
        nes.id: ClientLibraryMetadata(systemID: "nes", lastPlayedAt: older),
        gbaZ.id: ClientLibraryMetadata(systemID: "gba", lastPlayedAt: older),
        gbaA.id: ClientLibraryMetadata(systemID: "gba", lastPlayedAt: older),
    ]

    let shelves = LibraryShelfBuilder.shelves(
        for: [gbaZ, port, webCNil, nes, webB, gbaA, webARecent],
        metadataByID: metadataByID
    )

    let typeShelves = shelves.filter {
        if case .type = $0.kind { return true }
        return false
    }
    assert(typeShelves.map(\.id) == ["type:web", "type:port", "type:system:nes", "type:system:gba"])

    let webShelf = typeShelves.first { $0.id == "type:web" }
    assert(webShelf?.clients.map(\.id) == [webARecent.id, webB.id, webCNil.id])

    let gbaShelf = typeShelves.first { $0.id == "type:system:gba" }
    assert(gbaShelf?.clients.map(\.id) == [gbaA.id, gbaZ.id])
}

func testLibraryNavigationModelMapsDynamicSectionsWithPackerLast() throws {
    let empty = LibraryNavigationModel(shelfCount: 0)
    assert(empty.heroSection == 0)
    assert(empty.packerSection == 1)
    assert(empty.maxSection == 1)
    assert(empty.isShelfSection(0) == false)
    assert(empty.isShelfSection(1) == false)
    assert(empty.shelfIndex(forSection: 1) == nil)

    let threeShelves = LibraryNavigationModel(shelfCount: 3)
    assert(threeShelves.heroSection == 0)
    assert(threeShelves.packerSection == 4)
    assert(threeShelves.maxSection == 4)
    assert(threeShelves.isShelfSection(1))
    assert(threeShelves.isShelfSection(3))
    assert(threeShelves.isShelfSection(4) == false)
    assert(threeShelves.shelfIndex(forSection: 1) == 0)
    assert(threeShelves.shelfIndex(forSection: 3) == 2)
    assert(threeShelves.section(forShelfIndex: 0) == 1)
    assert(threeShelves.section(forShelfIndex: 2) == 3)
    assert(threeShelves.section(forShelfIndex: 3) == nil)
    assert(threeShelves.clampedSection(-1) == 0)
    assert(threeShelves.clampedSection(9) == 4)
}
