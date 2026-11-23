import Foundation
import Compression

func brotliCompressForTest(_ data: Data) -> Data {
    let dstCapacity = max(data.count + 64, 128)
    var dst = Data(count: dstCapacity)
    let written: Int = dst.withUnsafeMutableBytes { dstBuf -> Int in
        data.withUnsafeBytes { srcBuf -> Int in
            guard let dstBase = dstBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                  let srcBase = srcBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_encode_buffer(dstBase, dstCapacity, srcBase, data.count, nil, COMPRESSION_BROTLI)
        }
    }
    if written > 0 {
        dst.count = written
        return dst
    }
    return data
}

func uleb(_ value: Int) -> [UInt8] {
    var v = value
    var out: [UInt8] = []
    while true {
        var byte = UInt8(v & 0x7F)
        v >>= 7
        if v != 0 { byte |= 0x80 }
        out.append(byte)
        if v == 0 { break }
    }
    return out
}

func makeArchive(folders: [(name: String, files: [(name: String, data: String)])]) -> Data {
    var d = Data()
    for folder in folders {
        d.append(0) // folder type normal
        d.append(contentsOf: uleb(folder.name.utf8.count))
        d.append(contentsOf: folder.name.utf8)
        d.append(contentsOf: uleb(folder.files.count))
        for file in folder.files {
            d.append(contentsOf: uleb(file.name.utf8.count))
            d.append(contentsOf: file.name.utf8)
            d.append(0) // file type content
            let raw = Data(file.data.utf8)
            let bytes: Data = file.name.lowercased().hasSuffix(".br") ? raw : brotliCompressForTest(raw)
            d.append(contentsOf: uleb(bytes.count))
            d.append(bytes)
        }
    }
    return d
}

func testArchiveExtractsVcbrFiles() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive.bin")
    let dest = root.appendingPathComponent("dest", isDirectory: true)
    let data = makeArchive(folders: [
        ("vcsky", [("sha256sums.txt", "skip")]),
        ("vcbr", [("vc-sky-en-v6.data.br", "DATA1"), ("vc-sky-en-v6.wasm.br", "DATA2")]),
    ])
    try data.write(to: archive)

    let urls = try ReVCDOSPackedArchive.extractVcbrBRFiles(from: archive, to: dest)
    assert(urls.count == 2)
    let names = Set(urls.map { $0.lastPathComponent })
    assert(names == ["vc-sky-en-v6.data.br", "vc-sky-en-v6.wasm.br"])
    for url in urls {
        let content = String(data: try Data(contentsOf: url), encoding: .utf8)
        assert(content == (url.lastPathComponent.contains("data") ? "DATA1" : "DATA2"))
    }
    let vcskySums = dest.appendingPathComponent("vcsky").appendingPathComponent("sha256sums.txt")
    assert(FileManager.default.fileExists(atPath: vcskySums.path))
    let sums = String(data: try Data(contentsOf: vcskySums), encoding: .utf8)
    assert(sums == "skip")
}

func testArchiveTruncatedThrows() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("bad.bin")
    var data = makeArchive(folders: [("vcbr", [("a.br", "x")])])
    data = data.subdata(in: 0..<(data.count - 1)) // cut last content byte
    try? data.write(to: archive)

    do {
        _ = try ReVCDOSPackedArchive.extractVcbrBRFiles(from: archive, to: root.appendingPathComponent("d"))
        fatalError("expected truncated error")
    } catch ReVCDOSPackedArchiveError.truncated {
        // expected
    } catch {
        fatalError("wrong error: \(error)")
    }
}
