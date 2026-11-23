import Foundation

enum ReVCDOSAssetStore {
    static let assetNames: [String] = [
        "vc-sky-en-v6.data.br",
        "vc-sky-en-v6.wasm.br",
        "vc-sky-ru-v6.data.br",
        "vc-sky-ru-v6.wasm.br",
    ]

    private static let markerName = ".assets-ready"
    private static let distNames = ["index.html", "index.js", "game.js"]

    static func rootURL(fileManager: FileManager = .default) -> URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("reVCDOS", isDirectory: true)
    }

    static func isReady(at root: URL, fileManager: FileManager = .default) -> Bool {
        guard fileManager.fileExists(atPath: root.appendingPathComponent(markerName).path) else {
            return false
        }
        let vcbrReady = assetNames.allSatisfy { name in
            fileManager.fileExists(atPath: root.appendingPathComponent("vcbr").appendingPathComponent(name).path)
        }
        let distReady = distNames.allSatisfy { name in
            fileManager.fileExists(atPath: root.appendingPathComponent("dist").appendingPathComponent(name).path)
        }
        let vcskyReady = fileManager.fileExists(
            atPath: root.appendingPathComponent("vcsky").appendingPathComponent("sha256sums.txt").path
        )
        return vcbrReady && distReady && vcskyReady
    }

    static func clearMarker(at root: URL, fileManager: FileManager = .default) {
        let marker = root.appendingPathComponent(markerName)
        if fileManager.fileExists(atPath: marker.path) {
            try? fileManager.removeItem(at: marker)
        }
    }

    static func shouldPromptForDownload(at root: URL, fileManager: FileManager = .default) -> Bool {
        !isReady(at: root, fileManager: fileManager)
    }

    static func markReady(at root: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let marker = root.appendingPathComponent(markerName)
        if fileManager.fileExists(atPath: marker.path) {
            try fileManager.removeItem(at: marker)
        }
        try Data("ready".utf8).write(to: marker)
    }

    static func clear(at root: URL, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
    }
}
