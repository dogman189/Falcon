import SwiftUI

struct CoverSearchSheet: View {
    let client: GameClient
    let service: WikipediaCoverService
    let onPick: (WikipediaCoverCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [WikipediaCoverCandidate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(client: GameClient, service: WikipediaCoverService, onPick: @escaping (WikipediaCoverCandidate) -> Void) {
        self.client = client
        self.service = service
        self.onPick = onPick
        _query = State(initialValue: client.coverSearchName)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && results.isEmpty {
                    ProgressView("Searching Wikipedia…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, results.isEmpty {
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await performSearch() }
                        }
                    }
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "No Covers Found",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Try a different search term.")
                    )
                } else {
                    List(results, id: \.thumbnailURL) { candidate in
                        Button {
                            onPick(candidate)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: candidate.thumbnailURL) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 56, height: 56)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    @unknown default:
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    if let description = candidate.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Cover Online")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Game name")
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading && !results.isEmpty {
                        ProgressView()
                    }
                }
            }
            .task {
                await performSearch()
            }
        }
    }

    @MainActor
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await service.search(term: trimmed)
            results = fetched
        } catch {
            if results.isEmpty {
                errorMessage = "Could not load results. Check your connection and try again."
            }
        }
        isLoading = false
    }
}
