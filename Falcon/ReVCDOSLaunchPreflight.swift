import Foundation

enum ReVCDOSLaunchPreflight {
    struct Result {
        let errorMessage: String?
        let rootURL: URL?

        var canLaunch: Bool { errorMessage == nil }
    }

    static func check(
        rootURL: URL?,
        requiredPaths: [String] = ReVCDOSAssetManifest.requiredRelativePaths,
        fileManager: FileManager = .default
    ) -> Result {
        guard let rootURL else {
            return Result(
                errorMessage: "The offline game bundle could not be located.",
                rootURL: nil
            )
        }
        let missing = requiredPaths.filter { path in
            !fileManager.fileExists(atPath: rootURL.appendingPathComponent(path).path)
        }
        guard missing.isEmpty else {
            return Result(
                errorMessage: "Missing game files: \(missing.joined(separator: ", "))",
                rootURL: rootURL
            )
        }
        return Result(errorMessage: nil, rootURL: rootURL)
    }
}
