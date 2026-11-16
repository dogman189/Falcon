import Foundation

struct BundledClient: Identifiable, Hashable {
    let name: String
    let resource: String
    let fileExtension: String

    var id: String { resource }

    var url: URL? {
        Bundle.main.url(forResource: resource, withExtension: fileExtension)
    }

    static let all: [BundledClient] = [
        BundledClient(name: "Eaglet", resource: "Eaglet", fileExtension: "html"),
        BundledClient(name: "1.8.8-wasm", resource: "1.8.8-wasm", fileExtension: "html"),
        BundledClient(name: "26.3-wasm", resource: "26.3-wasm", fileExtension: "html"),
    ]
}
