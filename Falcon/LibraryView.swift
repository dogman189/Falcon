import SwiftUI

/// Clean console-style game launcher.
/// Features full controller menu navigation, top navigation bar, a prominent hero banner,
/// and horizontal browsing shelves with full context menu support.
struct LibraryView: View {
    let bundledClients: [GameClient]
    let customClients: [GameClient]
    let coverImage: (GameClient) -> Image
    let coverRevision: Int
    let onSelect: (GameClient) -> Void
    let onAddClient: () -> Void
    let onRemoveClient: (GameClient) -> Void
    @ViewBuilder let coverMenuItems: (GameClient) -> AnyView
    @ViewBuilder let reVCDOSMenuItems: (GameClient) -> AnyView

    @ObservedObject private var controllerManager = GameControllerManager.shared
    @State private var focusedClient: GameClient?
    @State private var focusedSection: Int = 0 // 0: Bundled, 1: Custom
    @State private var focusedIndex: Int = 0

    private var activeHeroClient: GameClient {
        focusedClient ?? bundledClients.first ?? customClients.first ?? GameClient.bundled[0]
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // Featured Hero Banner
                        HeroHeaderView(
                            client: activeHeroClient,
                            coverImage: coverImage(activeHeroClient),
                            onPlay: { onSelect(activeHeroClient) }
                        )
                        .id("hero-\(activeHeroClient.id)-\(coverRevision)")
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .contextMenu {
                            coverMenuItems(activeHeroClient)
                            reVCDOSMenuItems(activeHeroClient)
                        }

                        // Bundled Games Shelf
                        shelfView(
                            title: "Bundled Games",
                            count: bundledClients.count,
                            clients: bundledClients,
                            sectionIndex: 0,
                            scrollProxy: scrollProxy
                        )

                        // Custom Games Shelf
                        shelfView(
                            title: "Custom Games",
                            count: customClients.count,
                            clients: customClients,
                            sectionIndex: 1,
                            showAddCard: true,
                            scrollProxy: scrollProxy
                        )

                        // Controller Button Legend & Guidance
                        VStack(spacing: 8) {
                            if controllerManager.isConnected {
                                HStack(spacing: 16) {
                                    buttonLegendItem(button: "A", label: "Launch")
                                    buttonLegendItem(button: "X", label: "Add Game")
                                    buttonLegendItem(button: "✛", label: "Navigate")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw")
                                    .font(.subheadline)
                                Text("Swipe down in the top-left corner to reveal Quit while in-game.")
                                    .font(.footnote)
                            }
                            .foregroundStyle(.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                    }
                }
                .background(Color.black.ignoresSafeArea())
                .onAppear {
                    setupControllerCallbacks(scrollProxy: scrollProxy)
                }
            }
            .navigationTitle("Falcon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if controllerManager.isConnected {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                            Image(systemName: "gamecontroller.fill")
                                .font(.caption2)
                            Text(controllerManager.controllerName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAddClient()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Add Client from Files")
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func shelfView(
        title: String,
        count: Int,
        clients: [GameClient],
        sectionIndex: Int,
        showAddCard: Bool = false,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Shelf Header
            HStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                if showAddCard && !clients.isEmpty {
                    Button(action: onAddClient) {
                        Image(systemName: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 18)

            // Horizontal Shelf
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                        GameCard(
                            client: client,
                            cover: coverImage(client),
                            isFocused: activeHeroClient.id == client.id,
                            action: {
                                focusedSection = sectionIndex
                                focusedIndex = index
                                focusedClient = client
                                onSelect(client)
                            }
                        )
                        .disabled(client.url == nil)
                        .id(client.id)
                        .contextMenu {
                            Button {
                                focusedSection = sectionIndex
                                focusedIndex = index
                                focusedClient = client
                            } label: {
                                Label("Set as Featured", systemImage: "star")
                            }

                            coverMenuItems(client)
                            reVCDOSMenuItems(client)

                            if client.isCustom {
                                Button(role: .destructive) {
                                    onRemoveClient(client)
                                } label: {
                                    Label("Remove Client", systemImage: "trash")
                                }
                            }
                        }
                    }

                    if showAddCard {
                        AddClientCard(action: onAddClient)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
            }
        }
    }

    private func buttonLegendItem(button: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(button)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
            Text(label)
                .font(.caption2.weight(.medium))
        }
    }

    // MARK: - Controller Navigation Handlers

    private func setupControllerCallbacks(scrollProxy: ScrollViewProxy) {
        controllerManager.onNavigateLeft = {
            navigateHorizontally(step: -1, scrollProxy: scrollProxy)
        }

        controllerManager.onNavigateRight = {
            navigateHorizontally(step: 1, scrollProxy: scrollProxy)
        }

        controllerManager.onNavigateUp = {
            navigateVertically(step: -1, scrollProxy: scrollProxy)
        }

        controllerManager.onNavigateDown = {
            navigateVertically(step: 1, scrollProxy: scrollProxy)
        }

        controllerManager.onActionA = {
            if activeHeroClient.url != nil {
                onSelect(activeHeroClient)
            }
        }

        controllerManager.onActionX = {
            onAddClient()
        }
    }

    private func navigateHorizontally(step: Int, scrollProxy: ScrollViewProxy) {
        let currentList = (focusedSection == 0) ? bundledClients : customClients
        guard !currentList.isEmpty else { return }

        let newIndex = max(0, min(currentList.count - 1, focusedIndex + step))
        if newIndex != focusedIndex || focusedClient?.id != currentList[newIndex].id {
            focusedIndex = newIndex
            let target = currentList[newIndex]
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                focusedClient = target
                scrollProxy.scrollTo(target.id, anchor: .center)
            }
        }
    }

    private func navigateVertically(step: Int, scrollProxy: ScrollViewProxy) {
        let maxSection = customClients.isEmpty ? 0 : 1
        let newSection = max(0, min(maxSection, focusedSection + step))

        if newSection != focusedSection {
            focusedSection = newSection
            let currentList = (focusedSection == 0) ? bundledClients : customClients
            if !currentList.isEmpty {
                focusedIndex = min(focusedIndex, currentList.count - 1)
                let target = currentList[focusedIndex]
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    focusedClient = target
                    scrollProxy.scrollTo(target.id, anchor: .center)
                }
            }
        }
    }
}
