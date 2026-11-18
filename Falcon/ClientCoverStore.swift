import Foundation
import UIKit

final class ClientCoverStore {
    static let shared = ClientCoverStore()

    private let fileManager = FileManager.default

    private var baseDirectoryURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("Covers", isDirectory: true)
    }

    func coverURL(for clientID: String) -> URL? {
        guard let baseDirectoryURL else { return nil }
        guard let files = try? fileManager.contentsOfDirectory(at: baseDirectoryURL, includingPropertiesForKeys: nil) else {
            return nil
        }
        let prefix = sanitizedFileName(for: clientID) + "."
        return files.first(where: { $0.lastPathComponent.hasPrefix(prefix) && fileManager.fileExists(atPath: $0.path) })
    }

    func save(image: UIImage, for clientID: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try save(data: data, for: clientID, fileExtension: "jpg")
    }

    func importCover(from sourceURL: URL, for clientID: String) throws {
        try ensureBaseDirectory()
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: sourceURL)
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let ext = sourceURL.pathExtension.lowercased()
        if ext == "png", let png = image.pngData() {
            try save(data: png, for: clientID, fileExtension: "png")
        } else {
            try save(image: image, for: clientID)
        }
    }

    func reset(for clientID: String) {
        guard let baseDirectoryURL,
              let files = try? fileManager.contentsOfDirectory(at: baseDirectoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        let prefix = sanitizedFileName(for: clientID) + "."
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: file)
        }
    }

    private func save(data: Data, for clientID: String, fileExtension: String) throws {
        try ensureBaseDirectory()
        guard let baseDirectoryURL else { throw CocoaError(.fileNoSuchFile) }
        reset(for: clientID)
        let url = baseDirectoryURL.appendingPathComponent("\(sanitizedFileName(for: clientID)).\(fileExtension)")
        try data.write(to: url, options: .atomic)
    }

    private func ensureBaseDirectory() throws {
        guard let baseDirectoryURL else { throw CocoaError(.fileNoSuchFile) }
        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func sanitizedFileName(for clientID: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = clientID.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let name = String(scalars)
        return name.isEmpty ? UUID().uuidString : name
    }
}
