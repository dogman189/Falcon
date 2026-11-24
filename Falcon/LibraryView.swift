import SwiftUI

/// Clean console-style game launcher.
/// Features full controller menu navigation, top navigation bar, a prominent hero banner,
/// horizontal browsing shelves, and a dedicated controller shortcut to the Retro Packer.
struct LibraryView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var settings: AppSettings

    let bundledClients: [GameClient]
    let customClients: [GameClient]
    let coverImage: (GameClient) -> Image
    let coverRevision: Int
    let onSelect: (GameClient) -> Void
    let onAddClient: () -> Void
    let onRemoveClient: (GameClient) -> Void
    let onOpenPacker: () -> Void
    @ViewBuilder let coverMenuItems: (GameClient) -> AnyView
    @ViewBuilder let reVCDOSMenuItems: (GameClient) -> AnyView

    @ObservedObject private var controllerManager = GameControllerManager.shared
    @State private var focusedClient: GameClient?
    /// 0: Featured Hero Banner, 1: Bundled Games, 2: Custom Games, 3: Pack Retro Game
    @State private var focusedSection: Int = 0
    @State private var focusedIndex: Int = 0
    @State private var focusedID: String = "hero-banner"

    private var allClients: [GameClient] {
        bundledClients + customClients
    }

    private var activeHeroClient: GameClient {
        focusedClient ?? bundledClients.first ?? customClients.first ?? GameClient.bundled[0]
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { verticalProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? 14 : 22) {
                        // Featured Hero Banner (Section 0)
                        HeroHeaderView(
                            client: activeHeroClient,
                            coverImage: coverImage(activeHeroClient),
                            isFocused: (focusedSection == 0),
                            onPlay: { onSelect(activeHeroClient) }
                        )
                        .id("hero-banner-container")
                        .padding(.horizontal, 18)
                        .padding(.top, verticalSizeClass == .compact ? 6 : 10)
                        .onTapGesture {
                            focusedSection = 0
                            focusedID = "hero-banner"
                            onSelect(activeHeroClient)
                        }
                        .contextMenu {
                            coverMenuItems(activeHeroClient)
                            reVCDOSMenuItems(activeHeroClient)
                        }

                        // Bundled Games Shelf (Section 1)
                        shelfView(
                            title: "Bundled Games",
                            count: bundledClients.count,
                            clients: bundledClients,
                            sectionIndex: 1
                        )
                        .id("shelf-bundled")

                        // Custom Games Shelf (Section 2)
                        shelfView(
                            title: "Custom Games",
                            count: customClients.count,
                            clients: customClients,
                            sectionIndex: 2,
                            showAddCard: true
                        )
                        .id("shelf-custom")

                        // Retro Game Packer Banner (Section 3)
                        Button(action: onOpenPacker) {
                            HStack(spacing: 14) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Pack a Retro Game")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if controllerManager.isConnected {
                                            Text("RB")
                                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.2))
                                                .clipShape(Capsule())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text("Convert a ROM you own into a portable web game")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(focusedSection == 3 ? 0.12 : 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        focusedSection == 3 ? Color.white : Color.white.opacity(0.12),
                                        lineWidth: focusedSection == 3 ? 2.5 : 1
                                    )
                            )
                            .scaleEffect(focusedSection == 3 ? 1.02 : 1.0)
                            .shadow(
                                color: focusedSection == 3 ? Color.white.opacity(0.25) : Color.clear,
                                radius: 8,
                                y: 3
                            )
                            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedSection == 3)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal, 18)
                        .id("shelf-packer")

                        // Controller Button Legend & Guidance
                        VStack(spacing: 6) {
                            if controllerManager.isConnected {
                                HStack(spacing: 14) {
                                    buttonLegendItem(button: "A", label: "Select")
                                    buttonLegendItem(button: "X", label: "Add File")
                                    buttonLegendItem(button: "RB", label: "Packer")
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
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                }
                .background(settings.backgroundColor.ignoresSafeArea())
                // Smoothly center the active section vertically when focus moves
                .onChange(of: focusedSection) { _, newSection in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        switch newSection {
                        case 0:
                            verticalProxy.scrollTo("hero-banner-container", anchor: .top)
                        case 1:
                            verticalProxy.scrollTo("shelf-bundled", anchor: .center)
                        case 2:
                            verticalProxy.scrollTo("shelf-custom", anchor: .center)
                        case 3:
                            verticalProxy.scrollTo("shelf-packer", anchor: .center)
                        default:
                            break
                        }
                    }
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
            .toolbarBackground(settings.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            setupControllerCallbacks()
        }
    }

    @ViewBuilder
    private func shelfView(
        title: String,
        count: Int,
        clients: [GameClient],
        sectionIndex: Int,
        showAddCard: Bool = false
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

            // Horizontal Shelf with its own ScrollViewReader to follow the cursor horizontally
            ScrollViewReader { shelfProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                            let isCardFocused = (focusedSection == sectionIndex && focusedID == client.id)
                            GameCard(
                                client: client,
                                cover: coverImage(client),
                                isFocused: isCardFocused,
                                action: {
                                    focusedSection = sectionIndex
                                    focusedIndex = index
                                    focusedClient = client
                                    focusedID = client.id
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
                                    focusedID = client.id
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
                            AddClientCard(
                                isFocused: (focusedSection == 2 && focusedID == "add-custom-client"),
                                action: onAddClient
                            )
                            .id("add-custom-client")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                }
                // Automatically scroll horizontal shelf to center the selected card
                .onChange(of: focusedID) { _, newID in
                    if sectionIndex == focusedSection && !newID.isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            shelfProxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
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
                .clipShape(Capsule())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Controller Navigation

    private func setupControllerCallbacks() {
        controllerManager.onNavigateLeft = {
            navigateHorizontally(step: -1)
        }

        controllerManager.onNavigateRight = {
            navigateHorizontally(step: 1)
        }

        controllerManager.onNavigateUp = {
            navigateVertically(step: -1)
        }

        controllerManager.onNavigateDown = {
            navigateVertically(step: 1)
        }

        controllerManager.onActionA = {
            handleActionA()
        }

        controllerManager.onActionX = {
            onAddClient()
        }
    }

    private func totalItems(in section: Int) -> Int {
        switch section {
        case 0:
            return allClients.count
        case 1:
            return bundledClients.count
        case 2:
            return customClients.count + 1
        case 3:
            return 1
        default:
            return 0
        }
    }

    private func navigateHorizontally(step: Int) {
        if focusedSection == 0 {
            // Cycling through featured games on the Top Banner
            guard !allClients.isEmpty else { return }
            let count = allClients.count
            let newIndex = max(0, min(count - 1, focusedIndex + step))
            if newIndex != focusedIndex {
                focusedIndex = newIndex
                let target = allClients[newIndex]
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    focusedClient = target
                }
            }
        } else if focusedSection == 1 || focusedSection == 2 {
            let count = totalItems(in: focusedSection)
            guard count > 0 else { return }

            let newIndex = max(0, min(count - 1, focusedIndex + step))
            if newIndex != focusedIndex {
                focusedIndex = newIndex
                updateFocusedItem()
            }
        }
    }

    private func navigateVertically(step: Int) {
        let newSection = max(0, min(3, focusedSection + step))
        if newSection != focusedSection {
            focusedSection = newSection
            let count = totalItems(in: focusedSection)
            focusedIndex = max(0, min(focusedIndex, count - 1))
            updateFocusedItem()
        }
    }

    private func updateFocusedItem() {
        switch focusedSection {
        case 0:
            focusedID = "hero-banner"
            if focusedClient == nil {
                focusedClient = allClients.first
            }

        case 1:
            guard !bundledClients.isEmpty else { return }
            let client = bundledClients[min(focusedIndex, bundledClients.count - 1)]
            focusedClient = client
            focusedID = client.id

        case 2:
            if focusedIndex < customClients.count {
                let client = customClients[focusedIndex]
                focusedClient = client
                focusedID = client.id
            } else {
                focusedID = "add-custom-client"
            }

        case 3:
            focusedID = "packer-button"

        default:
            break
        }
    }

    private func handleActionA() {
        switch focusedSection {
        case 0:
            if activeHeroClient.url != nil {
                onSelect(activeHeroClient)
            }
        case 1:
            if let focusedClient, focusedClient.url != nil {
                onSelect(focusedClient)
            }
        case 2:
            if focusedID == "add-custom-client" {
                onAddClient()
            } else if let focusedClient, focusedClient.url != nil {
                onSelect(focusedClient)
            }
        case 3:
            onOpenPacker()
        default:
            break
        }
    }
}
