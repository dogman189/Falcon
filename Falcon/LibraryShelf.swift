import Foundation

enum LibraryType: Hashable {
    case web
    case port
    case retroSystem(String)
}

struct LibraryShelf: Identifiable, Hashable {
    enum Kind: Hashable {
        case recentlyPlayed
        case type(LibraryType)
    }

    let kind: Kind
    let title: String
    let clients: [GameClient]
    var id: String
}

enum LibraryShelfBuilder {
    static func resolveType(for client: GameClient, metadata: ClientLibraryMetadata?) -> LibraryType {
        switch client.id {
        case "bundled:1.8.8-wasm":
            return .web
        case "bundled:reVCDOS":
            return .port
        default:
            break
        }

        guard let systemID = metadata?.systemID,
              RetroSystemCatalog.systems.contains(where: { $0.id == systemID }) else {
            return .web
        }
        return .retroSystem(systemID)
    }

    static func shelves(
        for clients: [GameClient],
        metadataByID: [String: ClientLibraryMetadata],
        recentlyPlayedLimit: Int = 8
    ) -> [LibraryShelf] {
        var result: [LibraryShelf] = []

        let recentlyPlayedClients = clients
            .compactMap { client -> (GameClient, Date)? in
                guard let lastPlayedAt = metadataByID[client.id]?.lastPlayedAt else { return nil }
                return (client, lastPlayedAt)
            }
            .sorted { lhs, rhs in
                lhs.1 > rhs.1
            }
            .prefix(recentlyPlayedLimit)
            .map(\.0)

        if !recentlyPlayedClients.isEmpty {
            result.append(
                LibraryShelf(
                    kind: .recentlyPlayed,
                    title: "Recently Played",
                    clients: Array(recentlyPlayedClients),
                    id: "recently-played"
                )
            )
        }

        var grouped: [LibraryType: [GameClient]] = [:]
        for client in clients {
            let type = resolveType(for: client, metadata: metadataByID[client.id])
            grouped[type, default: []].append(client)
        }

        let typeShelves = grouped.map { type, shelfClients -> LibraryShelf in
            let sortedClients = shelfClients.sorted { lhs, rhs in
                let lhsDate = metadataByID[lhs.id]?.lastPlayedAt
                let rhsDate = metadataByID[rhs.id]?.lastPlayedAt
                switch (lhsDate, rhsDate) {
                case let (l?, r?):
                    if l != r { return l > r }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return LibraryShelf(
                kind: .type(type),
                title: title(for: type),
                clients: sortedClients,
                id: shelfID(for: type)
            )
        }
        .sorted { lhs, rhs in
            shelfOrder(for: lhs.kind) < shelfOrder(for: rhs.kind)
        }

        result.append(contentsOf: typeShelves)
        return result
    }

    private static func title(for type: LibraryType) -> String {
        switch type {
        case .web:
            return "Web"
        case .port:
            return "Port"
        case let .retroSystem(systemID):
            return RetroSystemCatalog.systems.first(where: { $0.id == systemID })?.label ?? systemID
        }
    }

    private static func shelfID(for type: LibraryType) -> String {
        switch type {
        case .web:
            return "type:web"
        case .port:
            return "type:port"
        case let .retroSystem(systemID):
            return "type:system:\(systemID)"
        }
    }

    private static func shelfOrder(for kind: LibraryShelf.Kind) -> Int {
        switch kind {
        case .recentlyPlayed:
            return -1
        case let .type(type):
            switch type {
            case .web:
                return 0
            case .port:
                return 1
            case let .retroSystem(systemID):
                if let index = RetroSystemCatalog.systems.firstIndex(where: { $0.id == systemID }) {
                    return 2 + index
                }
                return Int.max
            }
        }
    }
}

struct LibraryNavigationModel {
    let shelfCount: Int

    var heroSection: Int { 0 }
    var packerSection: Int { shelfCount + 1 }
    var maxSection: Int { packerSection }

    func isShelfSection(_ section: Int) -> Bool {
        section >= 1 && section <= shelfCount
    }

    func shelfIndex(forSection section: Int) -> Int? {
        guard isShelfSection(section) else { return nil }
        return section - 1
    }

    func section(forShelfIndex index: Int) -> Int? {
        guard index >= 0 && index < shelfCount else { return nil }
        return index + 1
    }

    func clampedSection(_ section: Int) -> Int {
        max(0, min(maxSection, section))
    }
}
