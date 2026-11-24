import Foundation

enum ReVCDOSAssetManifest {
    static let launchURL = URL(string: "http://localhost:8199/?fullscreen=0&lang=en")!
}

final class ClientCoverStore {
    static let shared = ClientCoverStore()
    func coverURL(for clientID: String) -> URL? { nil }
    func reset(for clientID: String) {}
    func removeAllCovers(for clientID: String) {}
}
