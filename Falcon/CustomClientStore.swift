import Foundation

struct CustomClientRecord: Codable, Hashable {
    let id: String
    let name: String
    let storedFileName: String
}

enum CustomClientStoreError: LocalizedError {
    case applicationSupportUnavailable
    case invalidFile
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Could not access app storage."
        case .invalidFile:
            return "Please choose an HTML client file."
        case .copyFailed:
            return "Could not copy the selected file."
        }
    }
}

final class CustomClientStore {
    static let shared = CustomClientStore()

    private let fileManager = FileManager.default
    private let metadataFileName = "custom-clients.json"

    private var baseDirectoryURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("CustomClients", isDirectory: true)
    }

    private var metadataURL: URL? {
        baseDirectoryURL?.appendingPathComponent(metadataFileName, isDirectory: false)
    }

    func load() -> [GameClient] {
        let records = loadRecords()
        let valid = records.compactMap { record -> (CustomClientRecord, GameClient)? in
            guard let fileURL = fileURL(for: record.storedFileName),
                  fileManager.fileExists(atPath: fileURL.path) else {
                return nil
            }
            let client = GameClient(
                id: record.id,
                name: record.name,
                source: .custom(fileURL: fileURL),
                note: "Custom"
            )
            return (record, client)
        }
        if valid.count != records.count {
            saveRecords(valid.map(\.0))
        }
        return valid.map(\.1)
    }

    func importClient(from sourceURL: URL) throws -> GameClient {
        try ensureBaseDirectory()
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let ext = sourceURL.pathExtension.lowercased()
        guard ext == "html" || ext == "htm" else {
            throw CustomClientStoreError.invalidFile
        }

        let originalBaseName = sourceURL.deletingPathExtension().lastPathComponent
        let displayName = originalBaseName.isEmpty ? "Custom Client" : originalBaseName
        let id = "custom:\(UUID().uuidString)"
        let storedFileName = uniqueFileName(for: sourceURL.lastPathComponent)

        guard let destinationURL = fileURL(for: storedFileName) else {
            throw CustomClientStoreError.applicationSupportUnavailable
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw CustomClientStoreError.copyFailed
        }

        var records = loadRecords()
        let record = CustomClientRecord(id: id, name: displayName, storedFileName: storedFileName)
        records.append(record)
        saveRecords(records)

        return GameClient(
            id: id,
            name: displayName,
            source: .custom(fileURL: destinationURL),
            note: "Custom"
        )
    }

    func remove(_ client: GameClient) {
        guard client.isCustom else { return }
        var records = loadRecords()
        if let record = records.first(where: { $0.id == client.id }),
           let fileURL = fileURL(for: record.storedFileName),
           fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
        records.removeAll { $0.id == client.id }
        saveRecords(records)
    }

    private func ensureBaseDirectory() throws {
        guard let baseDirectoryURL else { throw CustomClientStoreError.applicationSupportUnavailable }
        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func loadRecords() -> [CustomClientRecord] {
        guard let metadataURL,
              let data = try? Data(contentsOf: metadataURL),
              let records = try? JSONDecoder().decode([CustomClientRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func saveRecords(_ records: [CustomClientRecord]) {
        guard let metadataURL else { return }
        try? ensureBaseDirectory()
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    private func fileURL(for storedFileName: String) -> URL? {
        baseDirectoryURL?.appendingPathComponent(storedFileName, isDirectory: false)
    }

    private func uniqueFileName(for originalFileName: String) -> String {
        let base = (originalFileName as NSString).deletingPathExtension
        let ext = (originalFileName as NSString).pathExtension
        let safeBase = base.isEmpty ? "client" : base
        var candidate = ext.isEmpty ? safeBase : "\(safeBase).\(ext)"
        var counter = 2
        while let url = fileURL(for: candidate), fileManager.fileExists(atPath: url.path) {
            candidate = ext.isEmpty ? "\(safeBase)-\(counter)" : "\(safeBase)-\(counter).\(ext)"
            counter += 1
        }
        return candidate
    }
}
