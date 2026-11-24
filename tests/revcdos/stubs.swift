import Foundation

final class ClientCoverStore {
    static let shared = ClientCoverStore()
    func coverURL(for clientID: String) -> URL? { nil }
    func reset(for clientID: String) {}
    func removeAllCovers(for clientID: String) {}
}
