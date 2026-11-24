import Foundation

struct WikipediaCoverCandidate: Equatable, Sendable {
    let title: String
    let description: String?
    let thumbnailURL: URL
}

enum WikipediaCoverServiceError: Error, Equatable {
    case invalidResponse
    case noResults
}

protocol WikipediaCoverFetching: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: WikipediaCoverFetching {}

struct WikipediaCoverService: Sendable {
    private let fetcher: any WikipediaCoverFetching
    private let userAgent = "Falcon-iOS/1.0 (cover lookup)"

    init(fetcher: any WikipediaCoverFetching = URLSession.shared) {
        self.fetcher = fetcher
    }

    func search(term: String, limit: Int = 8) async throws -> [WikipediaCoverCandidate] {
        guard var components = URLComponents(string: "https://en.wikipedia.org/w/api.php") else {
            throw WikipediaCoverServiceError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: term),
            URLQueryItem(name: "gsrlimit", value: String(limit)),
            URLQueryItem(name: "prop", value: "pageimages|description"),
            URLQueryItem(name: "pithumbsize", value: "600"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*"),
        ]
        guard let url = components.url else {
            throw WikipediaCoverServiceError.invalidResponse
        }

        let data: Data
        let response: URLResponse
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let session = fetcher as? URLSession {
            (data, response) = try await session.data(for: request)
        } else {
            (data, response) = try await fetcher.data(from: url)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw WikipediaCoverServiceError.invalidResponse
        }

        return try Self.parseSearchResults(data: data)
    }

    func bestCandidate(for term: String) async throws -> WikipediaCoverCandidate {
        let candidates = try await search(term: term)
        guard let best = Self.bestCandidate(from: candidates, term: term) else {
            throw WikipediaCoverServiceError.noResults
        }
        return best
    }

    static func parseSearchResults(data: Data) throws -> [WikipediaCoverCandidate] {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw WikipediaCoverServiceError.invalidResponse
        }

        guard let object = root as? [String: Any] else {
            throw WikipediaCoverServiceError.invalidResponse
        }

        guard let query = object["query"] as? [String: Any] else {
            return []
        }
        guard let pages = query["pages"] as? [String: Any] else {
            return []
        }

        let parsed: [(index: Int?, title: String, candidate: WikipediaCoverCandidate)] = pages.values.compactMap { value in
            guard let page = value as? [String: Any] else { return nil }
            guard let title = page["title"] as? String else { return nil }
            guard let thumbnail = page["thumbnail"] as? [String: Any] else { return nil }
            guard let source = thumbnail["source"] as? String else { return nil }
            guard let thumbnailURL = URL(string: source) else { return nil }
            let description = page["description"] as? String
            let index = page["index"] as? Int
            return (index, title, WikipediaCoverCandidate(title: title, description: description, thumbnailURL: thumbnailURL))
        }

        let sorted = parsed.sorted { lhs, rhs in
            switch (lhs.index, rhs.index) {
            case let (l?, r?):
                if l != r { return l < r }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }

        return sorted.map(\.candidate)
    }

    static func bestCandidate(from candidates: [WikipediaCoverCandidate], term: String) -> WikipediaCoverCandidate? {
        guard !candidates.isEmpty else { return nil }
        let normalizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedTerm.isEmpty,
           let exact = candidates.first(where: { $0.title.lowercased() == normalizedTerm }) {
            return exact
        }
        if !normalizedTerm.isEmpty,
           let prefix = candidates.first(where: { $0.title.lowercased().hasPrefix(normalizedTerm) }) {
            return prefix
        }
        return candidates.first
    }
}
