//
//  ContentView.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    private enum AppTab: Hashable {
        case library
        case packer
    }

    @State private var selectedClient: GameClient?
    @State private var quitRevealed = false
    @State private var quitHideTask: Task<Void, Never>?
    @State private var clientFailure: String?
    @State private var customClients: [GameClient] = []
    @State private var selectedTab: AppTab = .library
    @State private var showingFileImporter = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false
    @State private var snapshotter = WebViewSnapshotter()
    @State private var coverTargetClient: GameClient?
    @State private var showingPhotoPicker = false
    @State private var showingCoverFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverRevision = 0
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
            } else if let selectedClient, !showingAssetDownload {
                if let clientURL = selectedClient.url {
                    let webContent: FalconWebContent = {
                        if case .localServer = selectedClient.source {
                            return .localServer(baseURL: clientURL)
                        }
                        return .file(clientURL)
                    }()
                    EaglerWebView(content: webContent, snapshotter: snapshotter) { message in
                        clientFailure = message
                    }
                    .id(webViewIdentity)
                    .ignoresSafeArea()
                    .background(.black)
                    .overlay(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .frame(width: 140, height: 90)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 20)
                                        .onEnded { _ in
                                            toggleQuitReveal()
                                        }
                                )

                            if quitRevealed {
                                quitButton
                            }
                        }
                    }
                } else {
                    failureView(
                        title: selectedClient.name,
                        message: "The bundled file for \(selectedClient.name) is missing."
                    )
                }
            } else {
                TabView(selection: $selectedTab) {
                    clientSelector
                        .tag(AppTab.library)
                        .tabItem {
                            Label("Library", systemImage: "gamecontroller")
                        }

                    RetroPackerView(
                        onImported: { _ in
                            loadClients()
                            selectedTab = .library
                        },
                        onCancel: nil
                    )
                    .tag(AppTab.packer)
                    .tabItem {
                        Label("Packer", systemImage: "shippingbox")
                    }
                }
            }
        }
        .onChange(of: selectedClient) { _, _ in
            hideQuit()
            if selectedClient == nil {
                reVCDOSServer?.stop()
                reVCDOSServer = nil
            }
            OrientationLock.shared.portraitOnly = (selectedClient == nil)
        }
        .task {
            loadClients()
            openDebugClientIfRequested()
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
    }

    private var quitButton: some View {
        Button {
            quitCurrentClient()
        } label: {
            Text("Quit")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.25))
        .clipShape(Capsule())
        .foregroundStyle(.white.opacity(0.9))
        .padding(.leading, 24)
        .padding(.top, 8)
    }

    private func toggleQuitReveal() {
        withAnimation(.easeInOut(duration: 0.15)) {
            quitRevealed.toggle()
        }
        if quitRevealed {
            scheduleQuitAutoHide()
        } else {
            quitHideTask?.cancel()
        }
    }

    private func scheduleQuitAutoHide() {
        quitHideTask?.cancel()
        quitHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                quitRevealed = false
            }
        }
    }

    private func hideQuit() {
        quitHideTask?.cancel()
        quitHideTask = nil
        quitRevealed = false
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
                    clientFailure = nil
                    selectedClient = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }

    private var clientSelector: some View {
        NavigationStack {
            List {
                Section("BUNDLED") {
                    ForEach(GameClient.bundled) { client in
                        Button {
                            selectClient(client)
                        } label: {
                            SelectorRow(client: client, cover: coverImage(for: client))
                        }
                        .buttonStyle(.plain)
                        .disabled(client.url == nil)
                        .id("\(client.id)-\(coverRevision)")
                        .contextMenu {
                            coverMenuItems(for: client)
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
                    }
                }

                Section {
                    if customClients.isEmpty {
                        Text("No custom clients yet. Add a single .html client file from Files.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customClients) { client in
                            Button {
                                selectClient(client)
                            } label: {
                                SelectorRow(client: client, cover: coverImage(for: client))
                            }
                            .buttonStyle(.plain)
                            .disabled(client.url == nil)
                            .id("\(client.id)-\(coverRevision)")
                            .contextMenu {
                                coverMenuItems(for: client)
                                Button(role: .destructive) {
                                    removeCustomClient(client)
                                } label: {
                                    Label("Remove Client", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("CUSTOM")
                } footer: {
                    Text("Swipe down in the top-left corner to reveal Quit. 1.8.8-wasm may need single-thread if it hangs starting the integrated server.")
                        .font(.footnote)
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Add Client from Files", systemImage: "plus")
                    }
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

    private func selectClient(_ client: GameClient) {
        clientFailure = nil
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
        selectClient(client)
    }

    private func loadClients() {
        customClients = CustomClientStore.shared.load()
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
            reVCDOSServer?.stop()
            reVCDOSServer = nil
            selectedClient = nil
            clientFailure = nil
        }
        CustomClientStore.shared.remove(client)
        loadClients()
    }

    private func quitCurrentClient() {
        hideQuit()
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
        if ClientCoverStore.shared.coverURL(for: client.id) != nil {
            Button(role: .destructive) {
                ClientCoverStore.shared.reset(for: client.id)
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
}

#Preview {
    ContentView()
}
