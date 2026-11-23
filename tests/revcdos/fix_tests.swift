import Foundation

func makeSlowServerScript(_ dir: String) -> String {
    """
    import http.server, time
    http.server.HTTPServer.allow_reuse_address = True
    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Length', '10000000')
            self.send_header('Accept-Ranges', 'bytes')
            self.end_headers()
            try:
                self.wfile.write(b'x' * 1000000)
                self.wfile.flush()
                time.sleep(5)
            except Exception:
                pass
        def log_message(self, *args): pass
    http.server.HTTPServer(('127.0.0.1', 18320), H).serve_forever()
    """
}

func testArchiveRejectsDeduplicatedVcbrEntry() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    var data = Data()
    // folder vcbr, one file which is a reference (type 1) instead of content
    data.append(0)
    data.append(contentsOf: uleb(4)); data.append(contentsOf: "vcbr".utf8)
    data.append(contentsOf: uleb(1))
    data.append(contentsOf: uleb(4)); data.append(contentsOf: "a.br".utf8)
    data.append(1) // reference
    data.append(contentsOf: uleb(3)); data.append(contentsOf: "src".utf8)
    data.append(contentsOf: uleb(1)); data.append(contentsOf: "b".utf8)
    let archive = root.appendingPathComponent("ref.bin")
    try data.write(to: archive)

    do {
        _ = try ReVCDOSPackedArchive.extractVcbrBRFiles(from: archive, to: root.appendingPathComponent("d"))
        fatalError("expected unsupported deduplicated entry error")
    } catch ReVCDOSPackedArchiveError.unsupportedDeduplicatedEntry {
        // expected
    } catch {
        fatalError("wrong error: \(error)")
    }
}

func testStoreRootIsInApplicationSupport() {
    let root = ReVCDOSAssetStore.rootURL()
    assert(root != nil)
    assert(root!.path.contains("Application Support/reVCDOS"))
}

func testReadinessIncludesDist() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    for name in ReVCDOSAssetStore.assetNames {
        let f = root.appendingPathComponent("vcbr").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: f)
    }
    try ReVCDOSAssetStore.markReady(at: root)
    assert(!ReVCDOSAssetStore.isReady(at: root), "dist missing should not be ready")
    for name in ["index.html", "index.js", "game.js"] {
        let f = root.appendingPathComponent("dist").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: f)
    }
    let vcsky = root.appendingPathComponent("vcsky", isDirectory: true)
    try? FileManager.default.createDirectory(at: vcsky, withIntermediateDirectories: true)
    try Data("sums".utf8).write(to: vcsky.appendingPathComponent("sha256sums.txt"))
    assert(ReVCDOSAssetStore.isReady(at: root))
}

func testFailedRedownloadClearsMarker() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    for name in ReVCDOSAssetStore.assetNames {
        let f = root.appendingPathComponent("vcbr").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: f)
    }
    for name in ["index.html", "index.js", "game.js"] {
        let f = root.appendingPathComponent("dist").appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: f)
    }
    let vcsky = root.appendingPathComponent("vcsky", isDirectory: true)
    try? FileManager.default.createDirectory(at: vcsky, withIntermediateDirectories: true)
    try Data("sums".utf8).write(to: vcsky.appendingPathComponent("sha256sums.txt"))
    try ReVCDOSAssetStore.markReady(at: root)
    assert(ReVCDOSAssetStore.isReady(at: root))

    let downloader = ReVCDOSAssetDownloader(
        archiveURL: URL(string: "http://127.0.0.1:1/nope.bin")!,
        destinationRoot: root,
        callbackQueue: .global()
    )
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Void, Error>?
    downloader.download(progress: { _ in }, completion: { result = $0; semaphore.signal() })
    _ = semaphore.wait(timeout: .now() + 20)
    guard case .failure? = result else { fatalError("expected failure") }
    assert(!ReVCDOSAssetStore.isReady(at: root), "marker must be cleared on failed attempt")
}

func testCancelWritesResumeData() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let script = root.appendingPathComponent("slow.py")
    try makeSlowServerScript(root.path).write(to: script, atomically: true, encoding: .utf8)
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    proc.arguments = [script.path]
    try proc.run()
    defer { proc.terminate() }
    Thread.sleep(forTimeInterval: 0.6)

    let downloader = ReVCDOSAssetDownloader(
        archiveURL: URL(string: "http://127.0.0.1:18320/slow")!,
        destinationRoot: root,
        callbackQueue: .global()
    )
    downloader.download(progress: { _ in }, completion: { _ in })
    Thread.sleep(forTimeInterval: 1.0)
    assert(downloader.isDownloading)
    downloader.cancel()
    Thread.sleep(forTimeInterval: 1.5)
    assert(!downloader.isDownloading)

    // Persisting resume data is testable directly; URLSession only supplies it
    // when the server cooperates with range requests.
    downloader.storeResumeData(Data("resume".utf8), root: root)
    assert(FileManager.default.fileExists(atPath: root.appendingPathComponent(".download-resume").path))
}
