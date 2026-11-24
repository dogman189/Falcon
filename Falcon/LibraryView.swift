import SwiftUI

/// Clean console-style game launcher.
/// Features full controller menu navigation, top navigation bar, a prominent hero banner,
/// horizontal browsing shelves, and a dedicated controller shortcut to the Retro Packer.
struct LibraryView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var settings: AppSettings

    let shelves: [LibraryShelf]
    let coverImage: (GameClient) -> Image
    let coverRevision: Int
    let onSelect: (GameClient) -> Void
    let onAddClient: () -> Void
    let onRemoveClient: (GameClient) -> Void
    let onOpenPacker: () -> Void
    @ViewBuilder let coverMenuItems: (GameClient) -> AnyView
    @ViewBuilder let reVCDOSMenuItems: (GameClient) -> AnyView
    var isActiveTab: Bool = true

    @ObservedObject private var controllerManager = GameControllerManager.shared
    @State private var focusedClient: GameClient?
    /// 0: Featured Hero Banner, 1...shelves.count: Shelf sections, shelves.count + 1: Pack Retro Game
    @State private var focusedSection: Int = 0
    @State private var focusedIndex: Int = 0
    @State private var focusedID: String = "hero-banner"

    private var effectiveShelfCount: Int {
        shelves.isEmpty ? 1 : shelves.count
    }

    private var navigation: LibraryNavigationModel {
        LibraryNavigationModel(shelfCount: effectiveShelfCount)
    }

    private var allClients: [GameClient] {
        var seen: Set<String> = []
        return shelves.flatMap(\.clients).filter { seen.insert($0.id).inserted }
    }

    private var activeHeroClient: GameClient {
        if let focusedClient, allClients.contains(where: { $0.id == focusedClient.id }) {
            return focusedClient
        }
        return allClients.first ?? GameClient.bundled[0]
    }

    private var addClientShelfID: String? {
        if shelves.contains(where: { $0.kind == .type(.web) }) {
            return shelves.first(where: { $0.kind == .type(.web) })?.id
        }
        return shelves.first?.id
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { verticalProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? 14 : 22) {
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

                        ForEach(Array(shelves.enumerated()), id: \.element.id) { index, shelf in
                            let sectionIndex = navigation.section(forShelfIndex: index) ?? (index + 1)
                            shelfView(
                                shelf: shelf,
                                sectionIndex: sectionIndex,
                                showAddCard: shelf.id == addClientShelfID
                            )
                            .id(verticalScrollID(for: sectionIndex, shelf: shelf))
                        }

                        if shelves.isEmpty {
                            shelfView(
                                shelf: LibraryShelf(kind: .type(.web), title: "Library", clients: [], id: "empty-library"),
                                sectionIndex: 1,
                                showAddCard: true
                            )
                            .id("shelf-empty-library")
                        }

                        packerBanner
                            .id("shelf-packer")

                        VStack(spacing: 6) {
                            if controllerManager.isConnected {
                                HStack(spacing: 14) {
                                    buttonLegendItem(button: "A", label: "Select")
                                    buttonLegendItem(button: "X", label: "Add File")
                                    buttonLegendItem(button: "RB", label: "Packer")
                                    buttonLegendItem(button: "✛", label: "Navigate")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(settings.appTheme.secondaryText)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(settings.appTheme.subtleFill)
                                .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw")
                                    .font(.subheadline)
                                Text("Swipe down in the top-left corner to reveal Quit while in-game.")
                                    .font(.footnote)
                            }
                            .foregroundStyle(settings.appTheme.secondaryText.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                }
                .background(settings.backgroundColor.ignoresSafeArea())
                .onChange(of: focusedSection) { _, newSection in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if newSection == 0 {
                            verticalProxy.scrollTo("hero-banner-container", anchor: .top)
                        } else if newSection == navigation.packerSection {
                            verticalProxy.scrollTo("shelf-packer", anchor: .center)
                        } else if let shelfIndex = navigation.shelfIndex(forSection: newSection),
                                  shelves.indices.contains(shelfIndex) {
                            verticalProxy.scrollTo(verticalScrollID(for: newSection, shelf: shelves[shelfIndex]), anchor: .center)
                        } else if shelves.isEmpty && newSection == 1 {
                            verticalProxy.scrollTo("shelf-empty-library", anchor: .center)
                        }
                    }
                }
                .onChange(of: shelves.map(\.id)) { _, _ in
                    clampFocusToAvailableContent()
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
                        .foregroundStyle(settings.appTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(settings.appTheme.subtleFill)
                        .clipShape(Capsule())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAddClient()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(settings.appTheme.primaryText)
                    }
                    .accessibilityLabel("Add Client from Files")
                }
            }
            .toolbarBackground(settings.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            clampFocusToAvailableContent()
            if isActiveTab {
                setupControllerCallbacks()
            }
        }
        .onChange(of: isActiveTab) { _, active in
            if active {
                setupControllerCallbacks()
            }
        }
    }

    private var packerBanner: some View {
        Button(action: onOpenPacker) {
            HStack(spacing: 14) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundStyle(settings.appTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(settings.appTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Pack a Retro Game")
                            .font(.subheadline.bold())
                            .foregroundStyle(settings.appTheme.primaryText)
                        Spacer()
                        if controllerManager.isConnected {
                            Text("RB")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(settings.appTheme.subtleFill)
                                .clipShape(Capsule())
                                .foregroundStyle(settings.appTheme.primaryText)
                        }
                    }
                    Text("Convert a ROM you own into a portable web game")
                        .font(.caption)
                        .foregroundStyle(settings.appTheme.secondaryText)
                }
            }
            .padding(14)
            .background(settings.appTheme.primaryText.opacity(focusedSection == navigation.packerSection ? 0.12 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        focusedSection == navigation.packerSection ? settings.appTheme.primaryText : settings.appTheme.border,
                        lineWidth: focusedSection == navigation.packerSection ? 2.5 : 1
                    )
            )
            .scaleEffect(focusedSection == navigation.packerSection ? 1.02 : 1.0)
            .shadow(
                color: focusedSection == navigation.packerSection ? settings.appTheme.primaryText.opacity(0.18) : Color.clear,
                radius: 8,
                y: 3
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedSection == navigation.packerSection)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func shelfView(
        shelf: LibraryShelf,
        sectionIndex: Int,
        showAddCard: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(shelf.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(settings.appTheme.primaryText)

                Text("\(shelf.clients.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(settings.appTheme.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(settings.appTheme.subtleFill)
                    .clipShape(Capsule())

                Spacer()

                if showAddCard && !shelf.clients.isEmpty {
                    Button(action: onAddClient) {
                        Image(systemName: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(settings.appTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 18)

            ScrollViewReader { shelfProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(shelf.clients.enumerated()), id: \.element.id) { index, client in
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
                                isFocused: (focusedSection == sectionIndex && focusedID == addClientFocusID),
                                action: onAddClient
                            )
                            .id(addClientFocusID)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                }
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
                .background(settings.appTheme.subtleFill)
                .clipShape(Capsule())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(settings.appTheme.secondaryText)
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

    private var addClientFocusID: String { "add-custom-client" }

    private func verticalScrollID(for sectionIndex: Int, shelf: LibraryShelf) -> String {
        "shelf-\(shelf.id)"
    }

    private func shelf(forSection section: Int) -> LibraryShelf? {
        guard !shelves.isEmpty,
              let shelfIndex = navigation.shelfIndex(forSection: section),
              shelves.indices.contains(shelfIndex) else { return nil }
        return shelves[shelfIndex]
    }

    private func showsAddCard(for section: Int) -> Bool {
        if shelves.isEmpty { return section == 1 }
        guard let shelf = shelf(forSection: section) else { return false }
        return shelf.id == addClientShelfID
    }

    private func totalItems(in section: Int) -> Int {
        if section == 0 {
            return allClients.count
        }
        if section == navigation.packerSection {
            return 1
        }
        if shelves.isEmpty {
            return section == 1 ? 1 : 0
        }
        guard let shelf = shelf(forSection: section) else { return 0 }
        return shelf.clients.count + (showsAddCard(for: section) ? 1 : 0)
    }

    private func navigateHorizontally(step: Int) {
        if focusedSection == 0 {
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
        } else if navigation.isShelfSection(focusedSection) || (shelves.isEmpty && focusedSection == 1) {
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
        let newSection = navigation.clampedSection(focusedSection + step)
        if newSection != focusedSection {
            focusedSection = newSection
            let count = totalItems(in: focusedSection)
            focusedIndex = max(0, min(focusedIndex, count - 1))
            updateFocusedItem()
        }
    }

    private func clampFocusToAvailableContent() {
        let maxSection = shelves.isEmpty ? 2 : navigation.maxSection
        if focusedSection > maxSection {
            focusedSection = maxSection
        }
        let count = totalItems(in: focusedSection)
        if count == 0 {
            if focusedSection != 0 && focusedSection != navigation.packerSection {
                focusedSection = navigation.packerSection
                focusedIndex = 0
                updateFocusedItem()
                return
            }
            return
        }
        focusedIndex = max(0, min(focusedIndex, count - 1))
        if focusedSection == 0, let focusedClient, !allClients.contains(where: { $0.id == focusedClient.id }) {
            self.focusedClient = allClients.first
        }
        updateFocusedItem()
    }

    private func updateFocusedItem() {
        if focusedSection == 0 {
            focusedID = "hero-banner"
            if focusedClient == nil || !allClients.contains(where: { $0.id == focusedClient!.id }) {
                focusedClient = allClients.first
            }
            return
        }

        if focusedSection == navigation.packerSection {
            focusedID = "packer-button"
            return
        }

        if shelves.isEmpty {
            if focusedSection == 1 {
                focusedID = addClientFocusID
            }
            return
        }

        guard let shelf = shelf(forSection: focusedSection) else { return }
        let addCardVisible = showsAddCard(for: focusedSection)
        if focusedIndex < shelf.clients.count {
            let client = shelf.clients[focusedIndex]
            focusedClient = client
            focusedID = client.id
        } else if addCardVisible {
            focusedID = addClientFocusID
        } else if let last = shelf.clients.last {
            focusedIndex = shelf.clients.count - 1
            focusedClient = last
            focusedID = last.id
        } else {
            focusedID = addClientFocusID
        }
    }

    private func handleActionA() {
        if focusedSection == 0 {
            if activeHeroClient.url != nil {
                onSelect(activeHeroClient)
            }
            return
        }

        if focusedSection == navigation.packerSection {
            onOpenPacker()
            return
        }

        if focusedID == addClientFocusID {
            onAddClient()
            return
        }

        if let focusedClient, focusedClient.url != nil, allClients.contains(where: { $0.id == focusedClient.id }) || shelf(forSection: focusedSection)?.clients.contains(where: { $0.id == focusedClient.id }) == true {
            onSelect(focusedClient)
        }
    }
}
