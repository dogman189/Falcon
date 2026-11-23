import Foundation
import Compression

enum ReVCDOSPackedArchiveError: Error {
    case truncated
    case unexpectedFolderType(UInt8)
    case unexpectedFileType(UInt8)
    case unsupportedDeduplicatedEntry
    case decompressionFailed
}

struct ReVCDOSExtractedAssets {
    let vcbr: [URL]
    let vcsky: [URL]
}

enum ReVCDOSPackedArchive {
    static func extractVcbrBRFiles(
        from archiveURL: URL,
        to destURL: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        try extract(from: archiveURL, to: destURL, fileManager: fileManager).vcbr
    }

    static func extract(
        from archiveURL: URL,
        to destURL: URL,
        fileManager: FileManager = .default
    ) throws -> ReVCDOSExtractedAssets {
        let size = (try fileManager.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber)?.intValue ?? 0
        let handle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? handle.close() }

        var offset = 0
        func readByte() throws -> UInt8? {
            guard offset < size else { return nil }
            try handle.seek(toOffset: UInt64(offset))
            guard let data = try handle.read(upToCount: 1), data.count == 1 else {
                throw ReVCDOSPackedArchiveError.truncated
            }
            offset += 1
            return data[0]
        }
        func readULEB() throws -> Int? {
            var result = 0
            var shift = 0
            while true {
                guard let byte = try readByte() else { return nil }
                result |= Int(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return result }
                shift += 7
                if shift > 63 { throw ReVCDOSPackedArchiveError.truncated }
            }
        }
        func readBytes(_ count: Int) throws -> Data {
            guard count >= 0, offset + count <= size else {
                throw ReVCDOSPackedArchiveError.truncated
            }
            try handle.seek(toOffset: UInt64(offset))
            guard let data = try handle.read(upToCount: count), data.count == count else {
                throw ReVCDOSPackedArchiveError.truncated
            }
            offset += count
            return data
        }
        func skip(_ count: Int) throws {
            guard count >= 0, offset + count <= size else {
                throw ReVCDOSPackedArchiveError.truncated
            }
            offset += count
        }

        var vcbr: [URL] = []
        var vcsky: [URL] = []
        var extractedFiles: [String: URL] = [:] // "folder/name" -> fileURL
        var extractedFolders: Set<String> = []

        try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true)

        while let folderType = try readByte() {
            guard let folderNameLen = try readULEB(),
                  let folderNameData = try? readBytes(folderNameLen),
                  let folderName = String(data: folderNameData, encoding: .utf8) else {
                throw ReVCDOSPackedArchiveError.truncated
            }

            let wantsFolder = folderName == "vcbr" || folderName == "vcsky" || folderName.hasPrefix("vcsky/")

            if folderType == 1 {
                guard let sourceLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                let sourceData = try readBytes(sourceLen)
                guard let sourceName = String(data: sourceData, encoding: .utf8) else {
                    throw ReVCDOSPackedArchiveError.truncated
                }
                if wantsFolder {
                    // Copy previously extracted files from source folder.
                    let prefix = sourceName.hasSuffix("/") ? sourceName : sourceName + "/"
                    let exact = sourceName
                    let matches = extractedFiles.filter { $0.key == exact || $0.key.hasPrefix(prefix) || $0.key.hasPrefix(exact + "/") }
                    if matches.isEmpty {
                        throw ReVCDOSPackedArchiveError.unsupportedDeduplicatedEntry
                    }
                    for (key, srcURL) in matches {
                        let rel = key.hasPrefix(prefix) ? String(key.dropFirst(prefix.count)) : URL(fileURLWithPath: key).lastPathComponent
                        let dstDir = destURL.appendingPathComponent(folderName, isDirectory: true)
                        let dstURL = dstDir.appendingPathComponent(rel)
                        try fileManager.createDirectory(at: dstURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        if fileManager.fileExists(atPath: dstURL.path) { try fileManager.removeItem(at: dstURL) }
                        try fileManager.copyItem(at: srcURL, to: dstURL)
                        let outKey = folderName + "/" + rel
                        extractedFiles[outKey] = dstURL
                        if folderName == "vcbr" && rel.hasSuffix(".br") { vcbr.append(dstURL) }
                        else if folderName == "vcsky" || folderName.hasPrefix("vcsky/") { vcsky.append(dstURL) }
                    }
                }
                extractedFolders.insert(folderName)
                continue
            }
            guard folderType == 0 else { throw ReVCDOSPackedArchiveError.unexpectedFolderType(folderType) }

            if wantsFolder {
                try fileManager.createDirectory(at: destURL.appendingPathComponent(folderName, isDirectory: true), withIntermediateDirectories: true)
            }
            extractedFolders.insert(folderName)

            guard let fileCount = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
            for _ in 0..<fileCount {
                guard let nameLen = try readULEB(),
                      let nameData = try? readBytes(nameLen),
                      let name = String(data: nameData, encoding: .utf8),
                      let fileType = try readByte() else {
                    throw ReVCDOSPackedArchiveError.truncated
                }

                if fileType == 1 {
                    guard let fLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                    let fData = try readBytes(fLen)
                    guard let nLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                    let nData = try readBytes(nLen)
                    if wantsFolder {
                        guard let srcFolder = String(data: fData, encoding: .utf8),
                              let srcName = String(data: nData, encoding: .utf8) else {
                            throw ReVCDOSPackedArchiveError.truncated
                        }
                        let key = srcFolder + "/" + srcName
                        guard let srcURL = extractedFiles[key] else {
                            throw ReVCDOSPackedArchiveError.unsupportedDeduplicatedEntry
                        }
                        let dstDir = destURL.appendingPathComponent(folderName, isDirectory: true)
                        let dstURL = dstDir.appendingPathComponent(name)
                        try fileManager.createDirectory(at: dstURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        if fileManager.fileExists(atPath: dstURL.path) { try fileManager.removeItem(at: dstURL) }
                        try fileManager.copyItem(at: srcURL, to: dstURL)
                        let outKey = folderName + "/" + name
                        extractedFiles[outKey] = dstURL
                        if folderName == "vcbr" && name.hasSuffix(".br") { vcbr.append(dstURL) }
                        else if folderName == "vcsky" || folderName.hasPrefix("vcsky/") { vcsky.append(dstURL) }
                    }
                    continue
                }
                guard fileType == 0 else { throw ReVCDOSPackedArchiveError.unexpectedFileType(fileType) }

                guard let contentLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                if wantsFolder {
                    let bytes = try readBytes(contentLen)
                    let outData: Data
                    if name.lowercased().hasSuffix(".br") {
                        outData = bytes
                    } else {
                        outData = try decompressBrotli(bytes)
                    }
                    let dstDir = destURL.appendingPathComponent(folderName, isDirectory: true)
                    let dstURL = dstDir.appendingPathComponent(name)
                    try fileManager.createDirectory(at: dstURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try outData.write(to: dstURL, options: .atomic)
                    let outKey = folderName + "/" + name
                    extractedFiles[outKey] = dstURL
                    if folderName == "vcbr" && name.hasSuffix(".br") { vcbr.append(dstURL) }
                    else if folderName == "vcsky" || folderName.hasPrefix("vcsky/") { vcsky.append(dstURL) }
                } else {
                    try skip(contentLen)
                }
            }
        }
        return ReVCDOSExtractedAssets(vcbr: vcbr, vcsky: vcsky)
    }

    private static func decompressBrotli(_ data: Data) throws -> Data {
        if data.isEmpty { return data }
        let dstCapacity = max(data.count * 4, 64 * 1024)
        let dstSize = dstCapacity
        var dst = Data(count: dstSize)
        var decoded: Int = 0
        let ok = dst.withUnsafeMutableBytes { dstBuf -> Bool in
            data.withUnsafeBytes { srcBuf -> Bool in
                guard let dstBase = dstBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let srcBase = srcBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
                decoded = compression_decode_buffer(dstBase, dstSize, srcBase, data.count, nil, COMPRESSION_BROTLI)
                return decoded > 0
            }
        }
        if ok {
            dst.count = decoded
            return dst
        }
        // Grow buffer until it fits or we give up.
        var cap = dstCapacity
        for _ in 0..<12 {
            cap *= 2
            var grown = Data(count: cap)
            let grew: Int = grown.withUnsafeMutableBytes { dstBuf -> Int in
                data.withUnsafeBytes { srcBuf -> Int in
                    guard let dstBase = dstBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let srcBase = srcBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return compression_decode_buffer(dstBase, cap, srcBase, data.count, nil, COMPRESSION_BROTLI)
                }
            }
            if grew > 0 {
                grown.count = grew
                return grown
            }
        }
        throw ReVCDOSPackedArchiveError.decompressionFailed
    }
}
