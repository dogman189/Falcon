import Foundation

/// A retro system supported by the vendored portable-retro-games universal packer.
struct RetroSystem: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let category: String
    let extensions: [String]
}

/// Static catalog mirroring the `SYSTEMS` table in the vendored universal packer
/// (`Falcon/RetroPacker/pack_game_en.html`). Keep ids, labels, categories and
/// extensions in sync with that table.
enum RetroSystemCatalog {
    static let systems: [RetroSystem] = [
        RetroSystem(id: "nes", label: "NES / Famicom", category: "Console", extensions: [".nes"]),
        RetroSystem(id: "snes", label: "Super Nintendo", category: "Console", extensions: [".smc", ".sfc", ".snes"]),
        RetroSystem(id: "gb", label: "Game Boy", category: "Console", extensions: [".gb"]),
        RetroSystem(id: "gbc", label: "Game Boy Color", category: "Console", extensions: [".gbc"]),
        RetroSystem(id: "genesis", label: "Sega Genesis / Mega Drive", category: "Console", extensions: [".md", ".bin", ".gen"]),
        RetroSystem(id: "sms", label: "Sega Master System", category: "Console", extensions: [".sms"]),
        RetroSystem(id: "gg", label: "Sega Game Gear", category: "Console", extensions: [".gg"]),
        RetroSystem(id: "atari2600", label: "Atari 2600", category: "Console", extensions: [".a26", ".bin"]),
        RetroSystem(id: "atari7800", label: "Atari 7800", category: "Console", extensions: [".a78"]),
        RetroSystem(id: "atari5200", label: "Atari 5200", category: "Console", extensions: [".a52"]),
        RetroSystem(id: "lynx", label: "Atari Lynx", category: "Console", extensions: [".lnx"]),
        RetroSystem(id: "coleco", label: "ColecoVision", category: "Console", extensions: [".col"]),
        RetroSystem(id: "ngp", label: "Neo Geo Pocket / Color", category: "Console", extensions: [".ngp", ".ngc"]),
        RetroSystem(id: "ws", label: "WonderSwan / Color", category: "Console", extensions: [".ws", ".wsc"]),
        RetroSystem(id: "vb", label: "Virtual Boy", category: "Console", extensions: [".vb"]),
        RetroSystem(id: "pce", label: "PC Engine / TurboGrafx-16", category: "Console", extensions: [".pce"]),
        RetroSystem(id: "32x", label: "Sega 32X", category: "Console", extensions: [".32x"]),
        RetroSystem(id: "gba", label: "Game Boy Advance", category: "Console", extensions: [".gba"]),
        RetroSystem(id: "n64", label: "Nintendo 64", category: "Console", extensions: [".n64", ".z64", ".v64"]),
        RetroSystem(id: "nds", label: "Nintendo DS", category: "Console", extensions: [".nds"]),
        RetroSystem(id: "psx", label: "PlayStation", category: "Console", extensions: [".bin", ".cue", ".iso", ".pbp"]),
        RetroSystem(id: "segacd", label: "Sega CD / Mega CD", category: "Console", extensions: [".cue", ".bin", ".chd"]),
        RetroSystem(id: "pcfx", label: "PC-FX", category: "Console", extensions: [".cue", ".ccd", ".toc"]),
        RetroSystem(id: "jaguar", label: "Atari Jaguar", category: "Console", extensions: [".j64", ".jag", ".rom", ".abs", ".cof", ".bin"]),
        RetroSystem(id: "c64", label: "Commodore 64", category: "Computer", extensions: [".d64", ".t64", ".prg", ".crt"]),
        RetroSystem(id: "c128", label: "Commodore 128", category: "Computer", extensions: [".d64", ".d71", ".d81", ".prg", ".t64", ".tap"]),
        RetroSystem(id: "vic20", label: "Commodore VIC-20", category: "Computer", extensions: [".d64", ".prg", ".crt", ".t64", ".tap", ".20", ".60", ".a0"]),
        RetroSystem(id: "pet", label: "Commodore PET", category: "Computer", extensions: [".d64", ".prg", ".t64", ".tap"]),
        RetroSystem(id: "plus4", label: "Commodore Plus/4", category: "Computer", extensions: [".d64", ".prg", ".t64", ".tap", ".bin", ".crt"]),
        RetroSystem(id: "amiga", label: "Commodore Amiga", category: "Computer", extensions: [".adf", ".adz", ".dms", ".ipf"]),
        RetroSystem(id: "cpc", label: "Amstrad CPC", category: "Computer", extensions: [".dsk", ".sna", ".cdt", ".voc"]),
        RetroSystem(id: "zxspectrum", label: "ZX Spectrum", category: "Computer", extensions: [".z80", ".tap", ".sna", ".tzx"]),
        RetroSystem(id: "zx81", label: "Sinclair ZX81", category: "Computer", extensions: [".p", ".81", ".tzx"]),
        RetroSystem(id: "cps1", label: "Arcade (CPS1)", category: "Arcade", extensions: [".zip"]),
        RetroSystem(id: "cps2", label: "Arcade (CPS2)", category: "Arcade", extensions: [".zip"]),
        RetroSystem(id: "fbneo", label: "Arcade (FBNeo)", category: "Arcade", extensions: [".zip"]),
        RetroSystem(id: "mame", label: "Arcade (MAME 2003+)", category: "Arcade", extensions: [".zip"]),
        RetroSystem(id: "doom", label: "DOOM (PrBoom)", category: "Other", extensions: [".wad"]),
        RetroSystem(id: "3do", label: "3DO Interactive", category: "Console", extensions: [".iso", ".bin", ".chd", ".cue"]),
        RetroSystem(id: "saturn", label: "Sega Saturn", category: "Console", extensions: [".bin", ".cue", ".iso", ".chd", ".mds"]),
        RetroSystem(id: "cdi", label: "Philips CD-i", category: "Console", extensions: [".chd", ".iso"]),
    ]

    /// Returns every system whose extension list contains `ext`.
    /// Matching ignores case, surrounding whitespace and a missing leading dot.
    static func systems(forExtension ext: String) -> [RetroSystem] {
        let normalized = normalize(extension: ext)
        guard !normalized.isEmpty else { return [] }
        return systems.filter { $0.extensions.contains(normalized) }
    }

    /// Returns the system for `filename` unless detection is ambiguous or unknown.
    static func suggestedSystem(forFilename filename: String) -> RetroSystem? {
        guard let ext = normalizedExtension(of: filename) else { return nil }
        let candidates = systems(forExtension: ext)
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// True when more than one system claims `ext`.
    static func isAmbiguousExtension(_ ext: String) -> Bool {
        systems(forExtension: ext).count > 1
    }

    /// Mirrors the packer's `cleanTitle`: drop the final extension, turn `_`/`-`
    /// into spaces, then title-case the name when it is entirely lowercase.
    static func cleanTitle(from filename: String) -> String {
        var name = filename
        if let dotIndex = filename.lastIndex(of: ".") {
            name = String(filename[filename.startIndex..<dotIndex])
        }
        name = name.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        guard name == name.lowercased() else { return name }

        var result = ""
        result.reserveCapacity(name.count)
        var previousWasWordCharacter = false
        for character in name {
            let isWordCharacter = character.isLetter || character.isNumber
            if isWordCharacter && !previousWasWordCharacter {
                result.append(contentsOf: character.uppercased())
            } else {
                result.append(character)
            }
            previousWasWordCharacter = isWordCharacter
        }
        return result
    }

    private static func normalizedExtension(of filename: String) -> String? {
        guard let dotIndex = filename.lastIndex(of: ".") else { return nil }
        let ext = String(filename[filename.index(after: dotIndex)...])
        let normalized = normalize(extension: ext)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalize(extension ext: String) -> String {
        var normalized = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalized.isEmpty && !normalized.hasPrefix(".") {
            normalized = "." + normalized
        }
        return normalized
    }
}
