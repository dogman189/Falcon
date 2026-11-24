import Foundation

struct ClientLibraryMetadata: Codable, Equatable {
    var systemID: String?
    var lastPlayedAt: Date?
    var launchCount: Int
    var totalPlaySeconds: Double

    init(
        systemID: String? = nil,
        lastPlayedAt: Date? = nil,
        launchCount: Int = 0,
        totalPlaySeconds: Double = 0
    ) {
        self.systemID = systemID
        self.lastPlayedAt = lastPlayedAt
        self.launchCount = launchCount
        self.totalPlaySeconds = totalPlaySeconds
    }
}

final class ClientLibraryMetadataStore {
    static let shared = ClientLibraryMetadataStore()

    private let fileManager: FileManager
    private let metadataFileName = "library-metadata.json"
    private let configuredBaseDirectoryURL: URL?

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.configuredBaseDirectoryURL = baseDirectoryURL
    }

    private var baseDirectoryURL: URL? {
        if let configuredBaseDirectoryURL { return configuredBaseDirectoryURL }
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("LibraryMetadata", isDirectory: true)
    }

    private var metadataURL: URL? {
        baseDirectoryURL?.appendingPathComponent(metadataFileName, isDirectory: false)
    }

    func metadata(for clientID: String) -> ClientLibraryMetadata {
        load()[clientID] ?? ClientLibraryMetadata()
    }

    func allMetadata() -> [String: ClientLibraryMetadata] {
        load()
    }

    func recordLaunch(clientID: String, at date: Date) {
        var records = load()
        var metadata = records[clientID] ?? ClientLibraryMetadata()
        metadata.lastPlayedAt = date
        metadata.launchCount += 1
        records[clientID] = metadata
        save(records)
    }

    func recordSessionEnd(clientID: String, startedAt: Date, endedAt: Date) {
        guard endedAt > startedAt else { return }
        var records = load()
        var metadata = records[clientID] ?? ClientLibraryMetadata()
        metadata.totalPlaySeconds += endedAt.timeIntervalSince(startedAt)
        records[clientID] = metadata
        save(records)
    }

    func setSystemID(_ systemID: String?, for clientID: String) {
        var records = load()
        var metadata = records[clientID] ?? ClientLibraryMetadata()
        metadata.systemID = systemID
        records[clientID] = metadata
        save(records)
    }

    func remove(clientID: String) {
        var records = load()
        records.removeValue(forKey: clientID)
        save(records)
    }

    private func ensureBaseDirectory() throws {
        guard let baseDirectoryURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func load() -> [String: ClientLibraryMetadata] {
        guard let metadataURL,
              let data = try? Data(contentsOf: metadataURL),
              let records = try? JSONDecoder().decode([String: ClientLibraryMetadata].self, from: data) else {
            return [:]
        }
        return records
    }

    private func save(_ records: [String: ClientLibraryMetadata]) {
        do {
            try ensureBaseDirectory()
            guard let metadataURL else { return }
            let data = try JSONEncoder().encode(records)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            return
        }
    }
}
