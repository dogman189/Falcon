import Foundation

struct GameClient: Identifiable, Hashable {
    enum Source: Hashable {
        case bundled(resource: String, fileExtension: String, query: String?, fragment: String?)
        case localServer(root: String)
        case custom(fileURL: URL)
    }

    let id: String
    let name: String
    let source: Source
    var note: String?

    var isCustom: Bool {
        if case .custom = source { return true }
        return false
    }

    var coverSearchName: String {
        switch id {
        case "bundled:1.8.8-wasm": return "Minecraft Java Edition"
        case "bundled:reVCDOS": return "Grand Theft Auto: Vice City"
        default: return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var defaultCoverImageName: String {
        switch source {
        case let .bundled(resource, _, _, _):
            switch resource {
            case "1.8.8-wasm":
                return "ClientCover-188"
            default:
                return "ClientCover-Custom"
            }
        case .localServer:
            return "ClientCover-ReVCDOS"
        case .custom:
            return "ClientCover-Custom"
        }
    }

    var storedCoverURL: URL? {
        ClientCoverStore.shared.coverURL(for: id)
    }

    var coverImageName: String { defaultCoverImageName }

    var url: URL? {
        switch source {
        case let .bundled(resource, fileExtension, query, fragment):
            guard let baseURL = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
                return nil
            }
            guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                return baseURL
            }
            if let query, !query.isEmpty {
                components.percentEncodedQuery = query
            }
            if let fragment, !fragment.isEmpty {
                components.percentEncodedFragment = fragment
            }
            return components.url ?? baseURL
        case .localServer:
            return ReVCDOSAssetManifest.launchURL
        case let .custom(fileURL):
            return fileURL
        }
    }

    static let bundled: [GameClient] = [
        GameClient(
            id: "bundled:1.8.8-wasm",
            name: "1.8.8-wasm",
            source: .bundled(resource: "1.8.8-wasm", fileExtension: "html", query: nil, fragment: nil),
            note: "If stuck on integrated server, cancel and run single-thread"
        ),
        GameClient(
            id: "bundled:reVCDOS",
            name: "reVCDOS",
            source: .localServer(root: "reVCDOS"),
            note: "GTA: Vice City — download assets once, then play offline"
        ),
    ]

    static var all: [GameClient] { bundled }
}

typealias BundledClient = GameClient
