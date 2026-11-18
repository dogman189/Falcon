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
    @State private var selectedClient: GameClient?
    @State private var quitRevealed = false
    @State private var quitHideTask: Task<Void, Never>?
    @State private var clientFailure: String?
    @State private var customClients: [GameClient] = []
    @State private var showingFileImporter = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false
    @State private var snapshotter = WebViewSnapshotter()
    @State private var coverTargetClient: GameClient?
    @State private var showingPhotoPicker = false
    @State private var showingCoverFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverRevision = 0

    var body: some View {
        Group {
            if let selectedClient {
                if let clientFailure {
                    failureView(for: selectedClient, message: clientFailure)
                } else if let fileURL = selectedClient.url {
                    EaglerWebView(fileURL: fileURL, snapshotter: snapshotter) { message in
                        clientFailure = message
                    }
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
                        for: selectedClient,
                        message: "The bundled file for \(selectedClient.name) is missing."
                    )
                }
            } else {
                clientSelector
            }
        }
        .onChange(of: selectedClient) { _, _ in
            hideQuit()
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

    private func failureView(for client: GameClient, message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)

            Text("\(client.name) stopped")
                .font(.title2.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560)

            HStack(spacing: 12) {
                Button("Try again") {
                    clientFailure = nil
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.14),
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FALCON")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .kerning(2)
                                    .foregroundStyle(.white)
                                Text("Select a client to launch")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            Spacer()
                            Button {
                                showingFileImporter = true
                            } label: {
                                Label("Add Client", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.cyan.opacity(0.18))
                                    .overlay(
                                        Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("BUNDLED")
                            .font(.caption.weight(.bold))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(GameClient.bundled) { client in
                                    clientTile(for: client)
                                        .id("\(client.id)-\(coverRevision)")
                                        .contextMenu {
                                            coverMenuItems(for: client)
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 24)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CUSTOM")
                            .font(.caption.weight(.bold))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 24)

                        if customClients.isEmpty {
                            Text("No custom clients yet. Add a single .html client file from Files.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 6)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(customClients) { client in
                                        clientTile(for: client)
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
                                .padding(.vertical, 4)
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    Text("Swipe down in the top-left corner to reveal Quit. 1.8.8-wasm may need single-thread if it hangs starting the integrated server.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func clientTile(for client: GameClient) -> some View {
        let isAvailable = client.url != nil
        Button {
            clientFailure = nil
            selectedClient = client
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    coverImage(for: client)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 260, height: 150)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 260, height: 150)

                    if client.isCustom {
                        Text("CUSTOM")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .foregroundStyle(.cyan)
                            .padding(10)
                    }

                    if !isAvailable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let note = client.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if !isAvailable {
                        Text("Bundle missing")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.9))
                    } else {
                        Text("Tap to launch")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(14)
                .frame(width: 260, alignment: .leading)
                .background(Color.white.opacity(isAvailable ? 0.08 : 0.04))
            }
            .frame(width: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isAvailable ? Color.cyan.opacity(0.35) : Color.orange.opacity(0.25),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.6)
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
        selectedClient = client
        #endif
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
