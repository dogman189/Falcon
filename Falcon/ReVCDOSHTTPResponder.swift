import Foundation

struct ReVCDOSHTTPResponse {
    let status: Int
    let reason: String
    let headers: [(String, String)]
    let body: Data
}

enum ReVCDOSHTTPResponder {
    static func parseRequestLine(_ line: String) -> (method: String, path: String)? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 3,
              parts[0] == "GET" || parts[0] == "HEAD",
              parts[2].hasPrefix("HTTP/1.") else { return nil }
        return (parts[0], parts[1])
    }

    static func response(
        method: String,
        path: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> ReVCDOSHTTPResponse {
        let pathOnly = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        let effectivePath: String
        if pathOnly == "/" {
            effectivePath = "/dist/index.html"
        } else if pathOnly.hasPrefix("/vcbr/") || pathOnly.hasPrefix("/vcsky/") {
            effectivePath = pathOnly
        } else {
            effectivePath = "/dist" + pathOnly
        }
        guard let fileURL = ReVCDOSAssetManifest.resolvedFileURL(for: effectivePath, in: rootURL),
              let data = fileManager.contents(atPath: fileURL.path) else {
            return ReVCDOSHTTPResponse(
                status: 404,
                reason: "Not Found",
                headers: [
                    ("Content-Type", "text/plain"),
                    ("Content-Length", "9"),
                    ("Cache-Control", "no-store"),
                    ("Cross-Origin-Opener-Policy", "same-origin"),
                    ("Cross-Origin-Embedder-Policy", "require-corp"),
                ],
                body: Data("Not Found".utf8)
            )
        }

        var headers: [(String, String)] = [
            ("Content-Type", ReVCDOSAssetManifest.contentType(for: effectivePath)),
            ("Content-Length", String(data.count)),
            ("Cache-Control", "no-store"),
            ("Cross-Origin-Opener-Policy", "same-origin"),
            ("Cross-Origin-Embedder-Policy", "require-corp"),
        ]
        if ReVCDOSAssetManifest.usesBrotli(effectivePath) {
            headers.append(("Content-Encoding", "br"))
        }

        return ReVCDOSHTTPResponse(
            status: 200,
            reason: "OK",
            headers: headers,
            body: method == "HEAD" ? Data() : data
        )
    }
}
