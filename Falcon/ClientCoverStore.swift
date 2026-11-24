import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class ClientCoverStore {
    static let shared = ClientCoverStore()

    private let fileManager: FileManager
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
        return appSupport.appendingPathComponent("Covers", isDirectory: true)
    }

    private var manualDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent("manual", isDirectory: true)
    }

    private var autoDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent("auto", isDirectory: true)
    }

    func manualCoverURL(for clientID: String) -> URL? {
        if let url = fileURL(for: clientID, in: manualDirectoryURL) {
            return url
        }
        return legacyCoverURL(for: clientID)
    }

    func autoCoverURL(for clientID: String) -> URL? {
        fileURL(for: clientID, in: autoDirectoryURL)
    }

    func coverURL(for clientID: String) -> URL? {
        manualCoverURL(for: clientID) ?? autoCoverURL(for: clientID)
    }

    func hasManualCover(for clientID: String) -> Bool {
        manualCoverURL(for: clientID) != nil
    }

    func saveManual(data: Data, fileExtension: String, for clientID: String) throws {
        try ensureDirectory(manualDirectoryURL)
        removeManualFiles(for: clientID)
        try write(data: data, fileExtension: fileExtension, for: clientID, in: manualDirectoryURL)
    }

    func importManualCover(from sourceURL: URL, for clientID: String) throws {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: sourceURL)
        let ext = normalizedFileExtension(sourceURL.pathExtension)
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if ext == "png", let png = image.pngData() {
            try saveManual(data: png, fileExtension: "png", for: clientID)
        } else if let jpg = image.jpegData(compressionQuality: 0.85) {
            try saveManual(data: jpg, fileExtension: "jpg", for: clientID)
        } else {
            throw CocoaError(.fileWriteUnknown)
        }
        #else
        guard !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let fileExtension = ext.isEmpty ? "jpg" : ext
        try saveManual(data: data, fileExtension: fileExtension, for: clientID)
        #endif
    }

    func saveAuto(data: Data, fileExtension: String, for clientID: String) throws {
        try ensureDirectory(autoDirectoryURL)
        removeFiles(for: clientID, in: autoDirectoryURL)
        try write(data: data, fileExtension: fileExtension, for: clientID, in: autoDirectoryURL)
    }

    func resetManualCover(for clientID: String) {
        removeManualFiles(for: clientID)
    }

    func removeAllCovers(for clientID: String) {
        removeManualFiles(for: clientID)
        removeFiles(for: clientID, in: autoDirectoryURL)
    }

    #if canImport(UIKit)
    func saveManual(image: UIImage, for clientID: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try saveManual(data: data, fileExtension: "jpg", for: clientID)
    }

    func saveAuto(image: UIImage, for clientID: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try saveAuto(data: data, fileExtension: "jpg", for: clientID)
    }

    func save(image: UIImage, for clientID: String) throws {
        try saveManual(image: image, for: clientID)
    }
    #endif

    func importCover(from sourceURL: URL, for clientID: String) throws {
        try importManualCover(from: sourceURL, for: clientID)
    }

    func reset(for clientID: String) {
        removeAllCovers(for: clientID)
    }

    private func write(data: Data, fileExtension: String, for clientID: String, in directoryURL: URL?) throws {
        guard let directoryURL else { throw CocoaError(.fileNoSuchFile) }
        let ext = normalizedFileExtension(fileExtension)
        let safeExt = ext.isEmpty ? "jpg" : ext
        let url = directoryURL.appendingPathComponent("\(sanitizedFileName(for: clientID)).\(safeExt)")
        try data.write(to: url, options: .atomic)
    }

    private func ensureDirectory(_ directoryURL: URL?) throws {
        guard let directoryURL else { throw CocoaError(.fileNoSuchFile) }
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for clientID: String, in directoryURL: URL?) -> URL? {
        guard let directoryURL,
              let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return nil
        }
        let prefix = sanitizedFileName(for: clientID) + "."
        return files.first(where: { $0.lastPathComponent.hasPrefix(prefix) && fileManager.fileExists(atPath: $0.path) })
    }

    private func legacyCoverURL(for clientID: String) -> URL? {
        fileURL(for: clientID, in: baseDirectoryURL)
    }

    private func removeManualFiles(for clientID: String) {
        removeFiles(for: clientID, in: manualDirectoryURL)
        removeFiles(for: clientID, in: baseDirectoryURL)
    }

    private func removeFiles(for clientID: String, in directoryURL: URL?) {
        guard let directoryURL,
              let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        let prefix = sanitizedFileName(for: clientID) + "."
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: file)
        }
    }

    private func normalizedFileExtension(_ ext: String) -> String {
        let trimmed = ext.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix(".") { return String(lower.dropFirst()) }
        return lower
    }

    private func sanitizedFileName(for clientID: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = clientID.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let name = String(scalars)
        return name.isEmpty ? UUID().uuidString : name
    }
}
