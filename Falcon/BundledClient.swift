import Foundation

struct BundledClient: Identifiable, Hashable {
    let name: String
    let resource: String
    let fileExtension: String
    var query: String?
    var fragment: String?
    var note: String?

    var id: String { resource }

    var url: URL? {
        guard let baseURL = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
            return nil
        }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }
        if let query, !query.isEmpty {
            components.percentEncodedQuery = query
        }
        if let fragment, !fragment.isEmpty {
            components.percentEncodedFragment = fragment
        }
        return components.url ?? baseURL
    }

    static let all: [BundledClient] = [
        BundledClient(name: "Eaglet", resource: "Eaglet", fileExtension: "html"),
        BundledClient(
            name: "1.8.8-wasm",
            resource: "1.8.8-wasm",
            fileExtension: "html",
            note: "If stuck on integrated server, cancel and run single-thread"
        ),
        BundledClient(name: "1.12.2-wasm", resource: "1.12.2-wasm", fileExtension: "html"),
        BundledClient(name: "1.21.11-wasm", resource: "1.21.11-wasm", fileExtension: "html"),
    ]
}
