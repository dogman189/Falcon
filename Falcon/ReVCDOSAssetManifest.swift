import Foundation

enum ReVCDOSAssetManifest {
    static let rootDirectoryName = "reVCDOS"
    static let port: UInt16 = 8199
    static let launchURL = URL(string: "http://localhost:8199/?fullscreen=0&lang=en")!

    static let requiredRelativePaths: [String] = [
        "dist/index.html",
        "dist/index.js",
        "dist/game.js",
        "vcbr/vc-sky-en-v6.data.br",
        "vcbr/vc-sky-en-v6.wasm.br",
        "vcbr/vc-sky-ru-v6.data.br",
        "vcbr/vc-sky-ru-v6.wasm.br",
    ]

    static func bundleRootURL(fileManager: FileManager = .default) -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent(rootDirectoryName, isDirectory: true)
    }

    static func missingAssets(in rootURL: URL, fileManager: FileManager = .default) -> [String] {
        requiredRelativePaths.filter { path in
            !fileManager.fileExists(atPath: rootURL.appendingPathComponent(path).path)
        }
    }

    static func resolvedFileURL(for path: String, in rootURL: URL) -> URL? {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let root = rootURL.standardizedFileURL
        let candidate = root.appendingPathComponent(relative).standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else { return nil }
        return candidate
    }

    static func contentType(for path: String) -> String {
        let lowered = path.lowercased()
        if lowered.hasSuffix(".wasm.br") { return "application/wasm" }
        if lowered.hasSuffix(".br") { return "application/octet-stream" }
        if lowered.hasSuffix(".html") { return "text/html" }
        if lowered.hasSuffix(".js") { return "text/javascript" }
        if lowered.hasSuffix(".css") { return "text/css" }
        if lowered.hasSuffix(".json") { return "application/json" }
        if lowered.hasSuffix(".mp4") { return "video/mp4" }
        if lowered.hasSuffix(".jpg") || lowered.hasSuffix(".jpeg") { return "image/jpeg" }
        if lowered.hasSuffix(".png") { return "image/png" }
        if lowered.hasSuffix(".svg") { return "image/svg+xml" }
        if lowered.hasSuffix(".txt") { return "text/plain" }
        return "application/octet-stream"
    }

    static func usesBrotli(_ path: String) -> Bool {
        path.lowercased().hasSuffix(".br")
    }
}
