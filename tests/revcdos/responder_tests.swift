import Foundation

func header(_ name: String, in response: ReVCDOSHTTPResponse) -> String? {
    response.headers.first(where: { $0.0.caseInsensitiveCompare(name) == .orderedSame })?.1
}

func testBrotliResponseHeaders() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vcbr = root.appendingPathComponent("vcbr", isDirectory: true)
    try? FileManager.default.createDirectory(at: vcbr, withIntermediateDirectories: true)
    let payload = Data("brotli-payload".utf8)
    try? payload.write(to: vcbr.appendingPathComponent("test.data.br"))

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

    let missing = ReVCDOSHTTPResponder.response(
        method: "GET", path: "/nope", rootURL: root
    )
    assert(missing.status == 404)
}
