//
//  ContentView.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct ContentView: View {
    private enum AppTab: Hashable {
        case library
        case packer
        case settings
    }

    @EnvironmentObject private var settings: AppSettings
    @State private var selectedClient: GameClient?
    @State private var activeLaunchSession: ActiveLaunchSession?
    @State private var countedLaunchClientID: String?
    @State private var quickMenuVisible = false
    @State private var quickMenuHideTask: Task<Void, Never>?
    @State private var webReloadToken = UUID()
    @State private var screenshotFeedback: String?
    @State private var screenshotFeedbackTask: Task<Void, Never>?
    @State private var clientFailure: String?
    @State private var customClients: [GameClient] = []
    @State private var libraryRevision = 0
    @State private var selectedTab: AppTab = .library
    @State private var retroPackerModel = RetroPackerModel()
    @State private var showingFileImporter = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false
    @State private var snapshotter = WebViewSnapshotter()
    @State private var coverTargetClient: GameClient?
    @State private var showingPhotoPicker = false
    @State private var showingCoverFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverRevision = 0
    @State private var coverSearchClient: GameClient?
    @State private var autoCoverFetchIDs: Set<String> = []
    private let coverService = WikipediaCoverService()
    @State private var reVCDOSServer: ReVCDOSLocalServer?
    @State private var webViewIdentity = 0
    @State private var showingAssetDownload = false
    @State private var downloadProgress = 0.0
    @State private var downloadStatus = "Ready to download"
    @State private var downloadErrorMessage: String?
    @State private var assetDownloadInFlight = false
    @State private var downloader = ReVCDOSAssetDownloader()
    @State private var showingDeleteAssetsConfirmation = false

    var body: some View {
        Group {
            if let clientFailure {
                failureView(title: selectedClient?.name ?? "Client", message: clientFailure)
                    .appChromeScale(settings.uiScale)
            } else if let selectedClient, !showingAssetDownload {
                if let clientURL = selectedClient.url {
                    let webContent: FalconWebContent = {
                        if case .localServer = selectedClient.source {
                            return .localServer(baseURL: clientURL)
                        }
                        return .file(clientURL)
                    }()
                    EaglerWebView(
                        content: webContent,
                        snapshotter: snapshotter,
                        reloadToken: webReloadToken,
                        webScale: settings.webScale,
                        backgroundUIColor: settings.backgroundUIColor
                    ) { message in
                        if clientFailure == nil {
                            pauseLaunchSession()
                        }
                        hideQuickMenu()
                        clientFailure = message
                    }
                    .id(webViewIdentity)
                    .ignoresSafeArea()
                    .background(settings.backgroundColor)
                    .overlay(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            if quickMenuVisible {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        hideQuickMenu()
                                    }
                            }

                            Color.clear
                                .frame(width: 140, height: 90)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 20)
                                        .onEnded { _ in
                                            toggleQuickMenu()
                                        }
                                )

                            if quickMenuVisible {
                                quickMenuCard
                            }

                            if let screenshotFeedback {
                                Text(screenshotFeedback)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.55), in: Capsule())
                                    .padding(.leading, 24)
                                    .padding(.top, quickMenuVisible ? 190 : 8)
                                    .transition(.opacity)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    failureView(
                        title: selectedClient.name,
                        message: "The bundled file for \(selectedClient.name) is missing."
                    )
                }
            } else {
                TabView(selection: $selectedTab) {
                    libraryTab
                        .tag(AppTab.library)
                        .tabItem {
                            Label("Library", systemImage: "gamecontroller")
                        }

                    RetroPackerView(
                        model: retroPackerModel,
                        isActiveTab: selectedTab == .packer,
                        onImported: { _ in
                            loadClients()
                            selectedTab = .library
                        },
                        onReturnToLibrary: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = .library
                            }
                        },
                        onCancel: nil
                    )
                    .tag(AppTab.packer)
                    .tabItem {
                        Label("Packer", systemImage: "shippingbox")
                    }

                    SettingsView(
                        isActiveTab: selectedTab == .settings,
                        onReturnToLibrary: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = .library
                            }
                        }
                    )
                    .tag(AppTab.settings)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                .tint(settings.appTheme.primaryText)
                .toolbarBackground(settings.backgroundColor, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .appChromeScale(settings.uiScale)
            }
        }
        .preferredColorScheme(settings.appTheme.preferredColorScheme)
        .onChange(of: selectedClient) { _, newClient in
            hideQuickMenu()
            GameControllerManager.shared.isEnabled = (newClient == nil)
            GameControllerManager.shared.onInGameMenuToggle = newClient == nil ? nil : {
                toggleQuickMenu()
            }
            if newClient == nil {
                finalizeLaunchSession()
                countedLaunchClientID = nil
                reVCDOSServer?.stop()
                reVCDOSServer = nil
            }
            OrientationLock.shared.mode = (newClient == nil) ? .auto : .landscapeOnly
        }
        .task {
            loadClients()
            autoFetchMissingCovers(for: GameClient.bundled + customClients)
            openDebugClientIfRequested()
            setupControllerTabSwitching()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.html, UTType(filenameExtension: "htm")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileImporter(
            isPresented: $showingCoverFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleCoverFileImport(result)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleSelectedPhotoItem(newItem) }
        }
        .alert("Couldn't Add Client", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Unknown error.")
        }
        .confirmationDialog("Delete downloaded reVCDOS assets?", isPresented: $showingDeleteAssetsConfirmation, titleVisibility: .visible) {
            Button("Delete Assets", role: .destructive) {
                deleteDownloadedAssets()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the downloaded game data from this device. You can download it again later.")
        }
        .sheet(isPresented: $showingAssetDownload, onDismiss: {
            // Never leave a selected client with no server behind the sheet.
            if ReVCDOSAssetStore.rootURL().map({ ReVCDOSAssetStore.shouldPromptForDownload(at: $0) }) ?? false {
                selectedClient = nil
            }
        }) {
            VStack(spacing: 18) {
                Text("Download reVCDOS assets")
                    .font(.title2.bold())
                Text("The game data is about 1.08 GB to download and needs around 3 GB free during install. Use WiFi, then you can play offline.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: max(0, min(downloadProgress, 1)))
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)
                    Text(downloadStatus)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let downloadErrorMessage {
                    Text(downloadErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                HStack(spacing: 12) {
                    Button("Cancel") {
                        downloader.cancel()
                        assetDownloadInFlight = false
                        downloadStatus = "Cancelled"
                        showingAssetDownload = false
                    }
                    .buttonStyle(.bordered)
                    Button(assetDownloadInFlight ? "Downloading…" : "Download") {
                        startAssetDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(assetDownloadInFlight)
                }
            }
            .padding(32)
            .frame(minWidth: 420)
            .interactiveDismissDisabled(true)
        }
        .sheet(item: $coverSearchClient) { client in
            CoverSearchSheet(client: client, service: coverService) { candidate in
                Task {
                    await applyOnlineCover(candidate, for: client)
                }
            }
        }
    }

    private var quickMenuCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            quickMenuButton("Resume") {
                hideQuickMenu()
            }
            quickMenuButton("Reload") {
                reloadCurrentClient()
            }
            quickMenuButton("Screenshot") {
                captureScreenshot()
            }
            quickMenuButton("Quit", role: .destructive) {
                quitCurrentClient()
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .foregroundStyle(.white.opacity(0.95))
        .padding(.leading, 24)
        .padding(.top, 8)
    }

    private func quickMenuButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toggleQuickMenu() {
        if quickMenuVisible {
            hideQuickMenu()
        } else {
            showQuickMenu()
        }
    }

    private func showQuickMenu(autoHide: Bool = true) {
        screenshotFeedbackTask?.cancel()
        screenshotFeedbackTask = nil
        screenshotFeedback = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            quickMenuVisible = true
        }
        if autoHide {
            scheduleQuickMenuAutoHide()
        } else {
            quickMenuHideTask?.cancel()
            quickMenuHideTask = nil
        }
    }

    private func hideQuickMenu() {
        quickMenuHideTask?.cancel()
        quickMenuHideTask = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            quickMenuVisible = false
        }
    }

    private func scheduleQuickMenuAutoHide() {
        quickMenuHideTask?.cancel()
        quickMenuHideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            // Ignore sleep cancellation; only skip hide if this task was replaced/cancelled.
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.15)) {
                    quickMenuVisible = false
                }
            }
        }
    }

    private func reloadCurrentClient() {
        clientFailure = nil
        webReloadToken = UUID()
        hideQuickMenu()
    }

    private func captureScreenshot() {
        quickMenuHideTask?.cancel()
        quickMenuHideTask = nil
        snapshotter.takeSnapshot { image in
            Task { @MainActor in
                guard let image else {
                    showScreenshotFeedback("Screenshot failed")
                    if quickMenuVisible {
                        scheduleQuickMenuAutoHide()
                    }
                    return
                }
                await saveScreenshotToPhotos(image)
                if quickMenuVisible {
                    scheduleQuickMenuAutoHide()
                }
            }
        }
    }

    @MainActor
    private func saveScreenshotToPhotos(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            showScreenshotFeedback("Photos access denied")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            showScreenshotFeedback("Saved to Photos")
        } catch {
            showScreenshotFeedback("Save failed")
        }
    }

    @MainActor
    private func showScreenshotFeedback(_ message: String) {
        screenshotFeedbackTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            screenshotFeedback = message
        }
        screenshotFeedbackTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.15)) {
                    screenshotFeedback = nil
                }
            }
        }
    }

    private func beginLaunchSession(for clientID: String) {
        LaunchSessionTracker.begin(
            &activeLaunchSession,
            clientID: clientID,
            at: Date(),
            store: .shared
        )
        countedLaunchClientID = clientID
        libraryRevision += 1
    }

    private func resumeLaunchSession(for clientID: String) {
        LaunchSessionTracker.resume(
            &activeLaunchSession,
            clientID: clientID,
            at: Date(),
            store: .shared
        )
        libraryRevision += 1
    }

    private func pauseLaunchSession() {
        LaunchSessionTracker.pause(
            &activeLaunchSession,
            at: Date(),
            store: .shared
        )
        libraryRevision += 1
    }

    private func finalizeLaunchSession() {
        LaunchSessionTracker.finalize(
            &activeLaunchSession,
            at: Date(),
            store: .shared
        )
        libraryRevision += 1
    }

    private func failureView(title: String, message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)

            Text("\(title) stopped")
                .font(.title2.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560)

            HStack(spacing: 12) {
                Button("Try again") {
                    retryCurrentClient()
                }
                .buttonStyle(.borderedProminent)

                Button("Back to clients") {
                    finalizeLaunchSession()
                    countedLaunchClientID = nil
                    clientFailure = nil
                    selectedClient = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.backgroundColor)
        .foregroundStyle(settings.appTheme.primaryText)
        .ignoresSafeArea()
    }

    private var libraryTab: some View {
        let _ = libraryRevision
        let shelves = LibraryShelfBuilder.shelves(
            for: GameClient.bundled + customClients,
            metadataByID: ClientLibraryMetadataStore.shared.allMetadata()
        )
        return LibraryView(
            shelves: shelves,
            coverImage: { coverImage(for: $0) },
            coverRevision: coverRevision,
            onSelect: { selectClient($0) },
            onAddClient: { showingFileImporter = true },
            onRemoveClient: { removeCustomClient($0) },
            onOpenPacker: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .packer
                }
            },
            onSearchCoverOnline: { client in
                coverSearchClient = client
            },
            coverMenuItems: { client in
                AnyView(coverMenuItems(for: client))
            },
            reVCDOSMenuItems: { client in
                AnyView(reVCDOSContextItems(for: client))
            },
            isActiveTab: selectedTab == .library
        )
    }

    private var orderedTabs: [AppTab] { [.library, .packer, .settings] }

    private func setupControllerTabSwitching() {
        GameControllerManager.shared.onShoulderLeft = {
            cycleTab(step: -1)
        }
        GameControllerManager.shared.onShoulderRight = {
            cycleTab(step: 1)
        }
    }

    private func cycleTab(step: Int) {
        let tabs = orderedTabs
        guard let index = tabs.firstIndex(of: selectedTab) else { return }
        let next = (index + step + tabs.count) % tabs.count
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tabs[next]
        }
    }

    @ViewBuilder
    private func reVCDOSContextItems(for client: GameClient) -> some View {
        if client.id == "bundled:reVCDOS" {
            Button {
                downloadErrorMessage = nil
                downloadProgress = 0
                downloadStatus = "Ready to download"
                showingAssetDownload = true
            } label: {
                Label("Download full assets…", systemImage: "arrow.down.circle")
            }
            if let root = ReVCDOSAssetStore.rootURL(),
               ReVCDOSAssetStore.isReady(at: root) {
                Button(role: .destructive) {
                    showingDeleteAssetsConfirmation = true
                } label: {
                    Label("Delete downloaded assets", systemImage: "trash")
                }
            }
        }
    }

    private func openDebugClientIfRequested() {
        #if DEBUG
        guard selectedClient == nil else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard let argument = arguments.first(where: { $0.hasPrefix("--client=") }) else {
            return
        }
        let requested = String(argument.dropFirst("--client=".count))
        let allClients = GameClient.bundled + customClients
        guard let client = allClients.first(where: {
            $0.name == requested || $0.id == requested
        }) else {
            return
        }
        selectClient(client)
        #endif
    }

    private func selectClient(_ client: GameClient, recordLaunch: Bool = true) {
        clientFailure = nil
        let isNewLogicalLaunch = recordLaunch && countedLaunchClientID != client.id
        if activeLaunchSession?.clientID != client.id {
            finalizeLaunchSession()
        }
        if isNewLogicalLaunch {
            countedLaunchClientID = nil
        }
        reVCDOSServer?.stop()
        reVCDOSServer = nil
        // Set the client first so a pre-flight failure still has context for
        // the failure view and for "Try again".
        selectedClient = client

        if case .localServer = client.source {
            if let assetRoot = ReVCDOSAssetStore.rootURL(),
               ReVCDOSAssetStore.shouldPromptForDownload(at: assetRoot) {
                downloadErrorMessage = nil
                downloadProgress = 0
                downloadStatus = "Ready to download"
                showingAssetDownload = true
                return
            }
            let rootURL = ReVCDOSAssetManifest.serveRoot()
            let preflight = ReVCDOSLaunchPreflight.check(rootURL: rootURL)
            guard preflight.canLaunch, let rootURL = preflight.rootURL else {
                clientFailure = preflight.errorMessage
                return
            }
            let server = ReVCDOSLocalServer(rootURL: rootURL)
            do {
                try server.start()
            } catch {
                clientFailure = "Could not start the local game server: \(error.localizedDescription)"
                return
            }
            reVCDOSServer = server
        }
        if isNewLogicalLaunch {
            beginLaunchSession(for: client.id)
        } else {
            resumeLaunchSession(for: client.id)
        }
    }

    private func deleteDownloadedAssets() {
        reVCDOSServer?.stop()
        reVCDOSServer = nil
        if let root = ReVCDOSAssetStore.rootURL() {
            try? ReVCDOSAssetStore.clear(at: root)
        }
        downloadProgress = 0
        downloadStatus = "Ready to download"
        downloadErrorMessage = nil
        assetDownloadInFlight = false
    }

    private func startAssetDownload() {
        downloadErrorMessage = nil
        downloadProgress = 0
        downloadStatus = "Starting download…"
        assetDownloadInFlight = true
        downloader.download(
            progress: { value in
                downloadProgress = max(0, min(value, 1))
                if value < 1 {
                    downloadStatus = "Downloading… \(Int((max(0, min(value, 1)) * 100).rounded()))%"
                } else {
                    downloadStatus = "Installing…"
                }
            },
            completion: { result in
                assetDownloadInFlight = false
                switch result {
                case .success:
                    downloadStatus = "Done"
                    showingAssetDownload = false
                    if let client = selectedClient {
                        selectClient(client)
                    }
                case .failure(let error):
                    if (error as NSError).code == NSURLErrorCancelled {
                        downloadStatus = "Cancelled"
                    } else {
                        downloadErrorMessage = error.localizedDescription
                        downloadStatus = "Download failed"
                    }
                }
            }
        )
    }

    private func retryCurrentClient() {
        guard let client = selectedClient else { return }
        webViewIdentity += 1
        let shouldRecordLaunch = countedLaunchClientID != client.id
        selectClient(client, recordLaunch: shouldRecordLaunch)
    }

    private func loadClients() {
        customClients = CustomClientStore.shared.load()
        libraryRevision += 1
        autoFetchMissingCovers(for: GameClient.bundled + customClients)
    }

    @MainActor
    private func autoFetchMissingCovers(for clients: [GameClient]) {
        for client in clients {
            autoFetchCoverIfNeeded(for: client)
        }
    }

    @MainActor
    private func autoFetchCoverIfNeeded(for client: GameClient) {
        guard !client.coverSearchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !ClientCoverStore.shared.hasManualCover(for: client.id) else { return }
        guard ClientCoverStore.shared.autoCoverURL(for: client.id) == nil else { return }
        guard !autoCoverFetchIDs.contains(client.id) else { return }
        autoCoverFetchIDs.insert(client.id)
        Task {
            await fetchAutoCover(for: client)
        }
    }

    private func fetchAutoCover(for client: GameClient) async {
        defer {
            Task { @MainActor in
                autoCoverFetchIDs.remove(client.id)
            }
        }
        let searchName = client.coverSearchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchName.isEmpty else { return }
        guard !ClientCoverStore.shared.hasManualCover(for: client.id) else { return }
        guard ClientCoverStore.shared.autoCoverURL(for: client.id) == nil else { return }

        do {
            let candidate = try await coverService.bestCandidate(for: searchName)
            let data = try await coverService.downloadImageData(from: candidate.thumbnailURL)
            let ext = candidate.thumbnailURL.pathExtension.isEmpty ? "jpg" : candidate.thumbnailURL.pathExtension
            try ClientCoverStore.shared.saveAuto(data: data, fileExtension: ext, for: client.id)
            await MainActor.run {
                coverRevision += 1
            }
        } catch {
            // Failures are non-fatal; keep built-in/default/current cover.
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                _ = try CustomClientStore.shared.importClient(from: url)
                loadClients()
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    private func removeCustomClient(_ client: GameClient) {
        guard client.isCustom else { return }
        if selectedClient?.id == client.id {
            finalizeLaunchSession()
            countedLaunchClientID = nil
            reVCDOSServer?.stop()
            reVCDOSServer = nil
            selectedClient = nil
            clientFailure = nil
        }
        CustomClientStore.shared.remove(client)
        loadClients()
    }

    private func quitCurrentClient() {
        hideQuickMenu()
        finalizeLaunchSession()
        countedLaunchClientID = nil
        let client = selectedClient
        snapshotter.takeSnapshot { image in
            DispatchQueue.main.async {
                if let client, let image {
                    try? ClientCoverStore.shared.save(image: image, for: client.id)
                    coverRevision += 1
                }
                clientFailure = nil
                reVCDOSServer?.stop()
                reVCDOSServer = nil
                selectedClient = nil
            }
        }
    }

    private func coverImage(for client: GameClient) -> Image {
        if let url = ClientCoverStore.shared.coverURL(for: client.id),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        return Image(client.defaultCoverImageName)
    }

    @ViewBuilder
    private func coverMenuItems(for client: GameClient) -> some View {
        Button {
            coverTargetClient = client
            showingPhotoPicker = true
        } label: {
            Label("Set Cover from Photos", systemImage: "photo")
        }
        Button {
            coverTargetClient = client
            showingCoverFileImporter = true
        } label: {
            Label("Set Cover from Files", systemImage: "folder")
        }
        if ClientCoverStore.shared.hasManualCover(for: client.id) {
            Button(role: .destructive) {
                ClientCoverStore.shared.resetManualCover(for: client.id)
                coverRevision += 1
            } label: {
                Label("Reset Cover", systemImage: "arrow.uturn.backward")
            }
        }
    }

    private func handleCoverFileImport(_ result: Result<[URL], Error>) {
        defer { coverTargetClient = nil }
        switch result {
        case .success(let urls):
            guard let url = urls.first, let client = coverTargetClient else { return }
            do {
                try ClientCoverStore.shared.importCover(from: url, for: client.id)
                coverRevision += 1
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    private func handleSelectedPhotoItem(_ item: PhotosPickerItem) async {
        let target = coverTargetClient
        defer {
            Task { @MainActor in
                coverTargetClient = nil
                selectedPhotoItem = nil
            }
        }
        guard let target,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        await MainActor.run {
            try? ClientCoverStore.shared.save(image: image, for: target.id)
            coverRevision += 1
        }
    }

    @MainActor
    private func applyOnlineCover(_ candidate: WikipediaCoverCandidate, for client: GameClient) async {
        coverSearchClient = nil
        do {
            let data = try await coverService.downloadImageData(from: candidate.thumbnailURL)
            let ext = candidate.thumbnailURL.pathExtension.isEmpty ? "jpg" : candidate.thumbnailURL.pathExtension
            try ClientCoverStore.shared.saveManual(data: data, fileExtension: ext, for: client.id)
            coverRevision += 1
        } catch {
            // Network failures are non-fatal; keep built-in/default/current cover.
        }
    }
}

#Preview {
    ContentView()
}
