import Foundation

enum ReVCDOSPackedArchiveError: Error {
    case truncated
    case unexpectedFolderType(UInt8)
    case unexpectedFileType(UInt8)
}

enum ReVCDOSPackedArchive {
    static func extractVcbrBRFiles(
        from archiveURL: URL,
        to destURL: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let size = (try fileManager.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber)?.intValue ?? 0
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: archiveURL)
        } catch {
            throw ReVCDOSPackedArchiveError.truncated
        }
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

        var extracted: [URL] = []
        try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true)

        while let folderType = try readByte() {
            guard let folderNameLen = try readULEB(),
                  let folderNameData = try? readBytes(folderNameLen),
                  let folderName = String(data: folderNameData, encoding: .utf8) else {
                throw ReVCDOSPackedArchiveError.truncated
            }

            if folderType == 1 { // copy folder: source name string, no files
                guard let sourceLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                try skip(sourceLen)
                continue
            }
            guard folderType == 0 else { throw ReVCDOSPackedArchiveError.unexpectedFolderType(folderType) }

            guard let fileCount = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
            for _ in 0..<fileCount {
                guard let nameLen = try readULEB(),
                      let nameData = try? readBytes(nameLen),
                      let name = String(data: nameData, encoding: .utf8),
                      let fileType = try readByte() else {
                    throw ReVCDOSPackedArchiveError.truncated
                }

                guard fileType == 0 else {
                    if fileType == 1 { // reference: source folder + source name
                        guard let fLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                        try skip(fLen)
                        guard let nLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                        try skip(nLen)
                        continue
                    }
                    throw ReVCDOSPackedArchiveError.unexpectedFileType(fileType)
                }

                guard let contentLen = try readULEB() else { throw ReVCDOSPackedArchiveError.truncated }
                let wantsFile = folderName == "vcbr" && name.hasSuffix(".br")
                if wantsFile {
                    let bytes = try readBytes(contentLen)
                    let fileURL = destURL.appendingPathComponent(name)
                    try bytes.write(to: fileURL)
                    extracted.append(fileURL)
                } else {
                    try skip(contentLen)
                }
            }
        }
        return extracted
    }
}
