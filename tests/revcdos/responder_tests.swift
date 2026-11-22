import Foundation

func header(_ name: String, in response: ReVCDOSHTTPResponse) -> String? {
    response.headers.first(where: { $0.0.caseInsensitiveCompare(name) == .orderedSame })?.1
}

func testVCSKYPathServedFromBundleRoot() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vcsky = root.appendingPathComponent("vcsky", isDirectory: true)
    try? FileManager.default.createDirectory(at: vcsky, withIntermediateDirectories: true)
    try? Data("fixture".utf8).write(to: vcsky.appendingPathComponent("sha256sums.txt"))

    let response = ReVCDOSHTTPResponder.response(
        method: "GET", path: "/vcsky/sha256sums.txt", rootURL: root
    )
    assert(response.status == 200)
    assert(response.body == Data("fixture".utf8))
    assert(header("Content-Type", in: response) == "text/plain")
}

func testServerRootSelection() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let bundle = root.appendingPathComponent("bundle", isDirectory: true)
    let downloaded = root.appendingPathComponent("downloaded", isDirectory: true)
    try? FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: downloaded, withIntermediateDirectories: true)
    assert(ReVCDOSAssetManifest.serveRoot(bundleRoot: bundle, downloadedRoot: downloaded) == bundle)
    for name in ReVCDOSAssetStore.assetNames {
        let file = downloaded.appendingPathComponent("vcbr").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
    }
    for name in ["index.html", "index.js", "game.js"] {
        let file = downloaded.appendingPathComponent("dist").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
    }
    try ReVCDOSAssetStore.markReady(at: downloaded)
    assert(ReVCDOSAssetManifest.serveRoot(bundleRoot: bundle, downloadedRoot: downloaded) == downloaded)
}

func testBrotliResponseHeaders() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vcbr = root.appendingPathComponent("vcbr", isDirectory: true)
    try? FileManager.default.createDirectory(at: vcbr, withIntermediateDirectories: true)
    let payload = Data("brotli-payload".utf8)
    try? payload.write(to: vcbr.appendingPathComponent("test.data.br"))
    let dist = root.appendingPathComponent("dist", isDirectory: true)
    try? FileManager.default.createDirectory(at: dist, withIntermediateDirectories: true)
    try? Data("index".utf8).write(to: dist.appendingPathComponent("index.html"))
    try? Data("game".utf8).write(to: dist.appendingPathComponent("game.js"))

    let parsed = ReVCDOSHTTPResponder.parseRequestLine("GET /vcbr/test.data.br HTTP/1.1")
    assert(parsed?.method == "GET")
    assert(parsed?.path == "/vcbr/test.data.br")
    assert(ReVCDOSHTTPResponder.parseRequestLine("BAD") == nil)

    let response = ReVCDOSHTTPResponder.response(
        method: "GET", path: "/vcbr/test.data.br", rootURL: root
    )
    assert(response.status == 200)
    assert(response.body == payload)
    assert(header("Content-Encoding", in: response) == "br")
    assert(header("Content-Type", in: response) == "application/octet-stream")
    assert(header("Cross-Origin-Opener-Policy", in: response) == "same-origin")
    assert(header("Cross-Origin-Embedder-Policy", in: response) == "require-corp")

    let rootResponse = ReVCDOSHTTPResponder.response(
        method: "GET", path: "/?fullscreen=0&lang=en", rootURL: root
    )
    assert(rootResponse.status == 200)
    assert(rootResponse.body == Data("index".utf8))

    let clientFile = ReVCDOSHTTPResponder.response(
        method: "GET", path: "/game.js", rootURL: root
    )
    assert(clientFile.status == 200)
    assert(clientFile.body == Data("game".utf8))
    assert(header("Content-Type", in: clientFile) == "text/javascript")

    let missing = ReVCDOSHTTPResponder.response(
        method: "GET", path: "/nope", rootURL: root
    )
    assert(missing.status == 404)
}
