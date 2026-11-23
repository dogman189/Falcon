import Foundation

func testCleanTitleFromFilename() {
    assert(RetroSystemCatalog.cleanTitle(from: "super_mario_bros.nes") == "Super Mario Bros")
    assert(RetroSystemCatalog.cleanTitle(from: "sonic-genesis.md") == "Sonic Genesis")
}

func testCleanTitleKeepsMixedCaseAndHandlesMultipleDots() {
    assert(RetroSystemCatalog.cleanTitle(from: "SuperMario.nes") == "SuperMario")
    assert(RetroSystemCatalog.cleanTitle(from: "game.v1.nes") == "Game.V1")
    assert(RetroSystemCatalog.cleanTitle(from: "no-extension") == "No Extension")
}

func testDetectsUniqueExtension() {
    let systems = RetroSystemCatalog.systems(forExtension: ".nes")
    assert(systems.map(\.id) == ["nes"])
    assert(RetroSystemCatalog.suggestedSystem(forFilename: "game.nes")?.id == "nes")
}

func testExtensionNormalizationIgnoresCaseAndLeadingDot() {
    assert(RetroSystemCatalog.systems(forExtension: "nes").map(\.id) == ["nes"])
    assert(RetroSystemCatalog.systems(forExtension: "NES").map(\.id) == ["nes"])
    assert(RetroSystemCatalog.systems(forExtension: " .NeS ").map(\.id) == ["nes"])
    assert(RetroSystemCatalog.suggestedSystem(forFilename: "GAME.NES")?.id == "nes")
}

func testUnknownOrMissingExtensionReturnsNoSystems() {
    assert(RetroSystemCatalog.systems(forExtension: "").isEmpty)
    assert(RetroSystemCatalog.systems(forExtension: ".").isEmpty)
    assert(RetroSystemCatalog.systems(forExtension: ".xyz").isEmpty)
    assert(RetroSystemCatalog.suggestedSystem(forFilename: "game") == nil)
    assert(RetroSystemCatalog.suggestedSystem(forFilename: "game.xyz") == nil)
    assert(!RetroSystemCatalog.isAmbiguousExtension(".xyz"))
}

func testAmbiguousExtensionReturnsMultipleSystems() {
    let binSystems = RetroSystemCatalog.systems(forExtension: ".bin")
    assert(binSystems.count > 1)
    assert(RetroSystemCatalog.isAmbiguousExtension(".bin"))
    assert(RetroSystemCatalog.suggestedSystem(forFilename: "game.bin") == nil)
}

func testAmbiguousExtensionsCoverEverySharedExtension() {
    let zipIDs = RetroSystemCatalog.systems(forExtension: ".zip").map(\.id)
    assert(zipIDs == ["cps1", "cps2", "fbneo", "mame"])
    assert(RetroSystemCatalog.isAmbiguousExtension(".zip"))
    assert(RetroSystemCatalog.suggestedSystem(forFilename: "arcade.zip") == nil)

    let binIDs = RetroSystemCatalog.systems(forExtension: ".bin").map(\.id)
    assert(binIDs.first == "genesis")
    assert(binIDs.count == 8)
}

func testCatalogContainsUniversalSystems() {
    let ids = Set(RetroSystemCatalog.systems.map(\.id))
    for required in ["nes", "snes", "gb", "gba", "n64", "nds", "psx", "genesis", "doom", "mame"] {
        assert(ids.contains(required), "missing \(required)")
    }
}

func testCatalogEntriesAreWellFormed() {
    let systems = RetroSystemCatalog.systems
    assert(systems.count == 41)
    assert(Set(systems.map(\.id)).count == systems.count, "duplicate system id")
    for system in systems {
        assert(!system.label.isEmpty, "missing label for \(system.id)")
        assert(!system.category.isEmpty, "missing category for \(system.id)")
        assert(!system.extensions.isEmpty, "missing extensions for \(system.id)")
        for ext in system.extensions {
            assert(ext.hasPrefix("."), "extension \(ext) for \(system.id) is not dot-prefixed")
            assert(ext == ext.lowercased(), "extension \(ext) for \(system.id) is not lowercase")
        }
    }
    let categories = Set(systems.map(\.category))
    assert(categories == ["Console", "Computer", "Arcade", "Other"])
}

func testCatalogRoundTripsThroughCodable() throws {
    let encoded = try JSONEncoder().encode(RetroSystemCatalog.systems)
    let decoded = try JSONDecoder().decode([RetroSystem].self, from: encoded)
    assert(decoded == RetroSystemCatalog.systems)
}
