import Foundation

func fetch(_ url: URL) -> (Data?, HTTPURLResponse?, Error?) {
    let semaphore = DispatchSemaphore(value: 0)
    var result: (Data?, HTTPURLResponse?, Error?)
    URLSession.shared.dataTask(with: url) { data, response, error in
        result = (data, response as? HTTPURLResponse, error)
        semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .now() + 10)
    return result
}

func testServerAppliesHeadersOverHTTP() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vcbr = root.appendingPathComponent("vcbr", isDirectory: true)
    try FileManager.default.createDirectory(at: vcbr, withIntermediateDirectories: true)
    let payload = Data("brotli-over-http".utf8)
    // Valid brotli stream for `payload`, so URLSession decodes it like WKWebView will.
    let encoded = Data([139, 7, 128, 98, 114, 111, 116, 108, 105, 45, 111, 118, 101, 114, 45, 104, 116, 116, 112, 3])
    try encoded.write(to: vcbr.appendingPathComponent("test.data.br"))

    let server = ReVCDOSLocalServer(rootURL: root, port: 18191)
    try server.start()
    defer { server.stop() }

    let result = fetch(URL(string: "http://localhost:18191/vcbr/test.data.br")!)
    assert(result.2 == nil)
    assert(result.1?.statusCode == 200)
    assert(result.0 == payload)
    assert(result.1?.value(forHTTPHeaderField: "Content-Encoding") == "br")
    assert(result.1?.value(forHTTPHeaderField: "Cross-Origin-Opener-Policy") == "same-origin")
    assert(result.1?.value(forHTTPHeaderField: "Cross-Origin-Embedder-Policy") == "require-corp")
}

func testServerErrorDescribesItself() {
    assert(ReVCDOSLocalServerError.startFailed("port busy").localizedDescription == "port busy")
}

func testStartThrowsWhenPortUnavailable() throws {
    let first = ReVCDOSLocalServer(rootURL: makeTempRoot(), port: 18192)
    try first.start()
    defer { first.stop() }

    let second = ReVCDOSLocalServer(rootURL: makeTempRoot(), port: 18192)
    var threw = false
    do {
        try second.start()
    } catch {
        threw = true
    }
    assert(threw)
    second.stop()
}
