import Observation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@Observable
@MainActor
final class RetroPackerModel {
    let engine = RetroPackerEngine()

    var showingFileImporter = false
    var romData: Data?
    var romFileName: String = ""
    var romByteCount: Int = 0

    var selectedSystem: RetroSystem?
    var systemDetectionNote: String?
    var title: String = ""

    var isPacking = false
    var progress: Double = 0
    var statusMessage: String = ""
    var errorMessage: String?

    var showingImportError = false
    var importErrorMessage: String?

    init() {
        wireCallbacks()
    }

    func loadIfNeeded() {
        engine.loadIfNeeded()
    }

    func wireCallbacks() {
        engine.onProgress = { [weak self] percent, message in
            Task { @MainActor in
                guard let self else { return }
                self.progress = percent
                self.statusMessage = message
            }
        }
        engine.onComplete = { [weak self] fileName, htmlData in
            Task { @MainActor in
                guard let self else { return }
                let name = self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fileName : self.title
                do {
                    let client = try CustomClientStore.shared.importGeneratedClient(named: name, htmlData: htmlData)
                    self.isPacking = false
                    self.progress = 0
                    self.statusMessage = ""
                    self.errorMessage = nil
                    self.onImported?(client)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isPacking = false
                    self.progress = 0
                    self.statusMessage = ""
                }
            }
        }
        engine.onError = { [weak self] message in
            Task { @MainActor in
                guard let self else { return }
                self.errorMessage = message
                self.isPacking = false
                self.progress = 0
                self.statusMessage = ""
            }
        }
    }

    var onImported: ((GameClient) -> Void)?

    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                romData = data
                romFileName = url.lastPathComponent
                romByteCount = data.count
                title = RetroSystemCatalog.cleanTitle(from: url.lastPathComponent)

                let ext = "." + url.pathExtension.lowercased()
                let candidates = RetroSystemCatalog.systems(forExtension: ext)
                if let suggested = RetroSystemCatalog.suggestedSystem(forFilename: url.lastPathComponent) {
                    selectedSystem = suggested
                    systemDetectionNote = nil
                } else if candidates.count > 1 {
                    selectedSystem = nil
                    systemDetectionNote = "This extension is used by multiple systems. Choose the correct one."
                } else if candidates.isEmpty {
                    selectedSystem = nil
                    systemDetectionNote = "This extension isn't recognized. Choose a system manually."
                } else {
                    selectedSystem = candidates.first
                    systemDetectionNote = nil
                }
                errorMessage = nil
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    func startPacking() {
        guard let romData, let system = selectedSystem else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        errorMessage = nil
        progress = 0
        statusMessage = "Starting…"
        isPacking = true

        engine.pack(romData: romData, romName: romFileName, system: system.id, title: trimmedTitle)
    }

    func cancelPacking() {
        engine.cancel()
        isPacking = false
        progress = 0
        statusMessage = ""
    }

    static var allowedROMTypes: [UTType] {
        var types: Set<UTType> = [.data]
        for system in RetroSystemCatalog.systems {
            for ext in system.extensions {
                let clean = ext.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                if !clean.isEmpty, let type = UTType(filenameExtension: clean) {
                    types.insert(type)
                }
            }
        }
        return Array(types)
    }
}

/// Native SwiftUI screen for turning a user-owned ROM into a portable HTML game
/// client using the hidden `RetroPackerEngine`.
struct RetroPackerView: View {
    @Bindable var model: RetroPackerModel
    let onImported: (GameClient) -> Void
    let onCancel: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                // ROM file section
                Section {
                    Button {
                        model.showingFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            if model.romFileName.isEmpty {
                                Text("Choose ROM File")
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.romFileName)
                                        .foregroundStyle(.primary)
                                    Text(byteCountLabel(model.romByteCount))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .disabled(model.isPacking)
                } header: {
                    Text("ROM File")
                } footer: {
                    Text("Select a ROM file you own. Nothing is uploaded; packing happens on your device.")
                }

                // System section
                Section {
                    Picker("System", selection: $model.selectedSystem) {
                        Text(model.romFileName.isEmpty ? "Choose a ROM first" : "Select a system")
                            .tag(nil as RetroSystem?)
                        ForEach(RetroSystemCatalog.systems) { system in
                            Text(system.label).tag(system as RetroSystem?)
                        }
                    }
                    .disabled(model.isPacking)

                    if let note = model.systemDetectionNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("System")
                }

                // Details section
                Section {
                    TextField("Game title", text: $model.title)
                        .disabled(model.isPacking)
                } header: {
                    Text("Details")
                } footer: {
                    Text("This name is used for the imported client in your library.")
                }

                // Pack section
                Section {
                    if model.isPacking {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: model.progress)
                                .progressViewStyle(.linear)
                            Text(model.statusMessage.isEmpty ? "Packing…" : model.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)

                        Button("Cancel Packing", role: .cancel) {
                            model.cancelPacking()
                        }
                    } else {
                        Button {
                            model.startPacking()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Pack and Add to Library", systemImage: "shippingbox.and.arrow.backward")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(!canPack)
                    }

                    if let error = model.errorMessage, !model.isPacking {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    if !model.isPacking {
                        Text("The emulator core is downloaded on demand during packing. You need an internet connection the first time you pack a system.")
                    }
                }
            }
            .navigationTitle("Pack a Game")
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            if model.isPacking {
                                model.cancelPacking()
                            }
                            onCancel()
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $model.showingFileImporter,
                allowedContentTypes: RetroPackerModel.allowedROMTypes,
                allowsMultipleSelection: false
            ) { result in
                model.handleFileSelection(result)
            }
            .alert("Couldn't Open ROM", isPresented: $model.showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.importErrorMessage ?? "Unknown error.")
            }
            .onAppear {
                model.onImported = onImported
                model.loadIfNeeded()
            }
            .overlay(alignment: .bottomTrailing) {
                // Host the engine's WKWebView invisibly so iOS does not throttle it.
                RetroPackerEngineHost(engine: model.engine)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var canPack: Bool {
        model.romData != nil
            && model.selectedSystem != nil
            && !model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.isPacking
    }

    private func byteCountLabel(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}

// MARK: - Hidden engine host

private struct RetroPackerEngineHost: UIViewRepresentable {
    let engine: RetroPackerEngine

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        engine.loadIfNeeded()
        if let webView = engine.webView {
            webView.frame = container.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(webView)
            context.coordinator.hostedWebView = webView
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        engine.loadIfNeeded()
        let current = engine.webView
        guard context.coordinator.hostedWebView !== current else { return }
        context.coordinator.hostedWebView?.removeFromSuperview()
        if let current {
            current.frame = uiView.bounds
            current.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            uiView.addSubview(current)
        }
        context.coordinator.hostedWebView = current
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hostedWebView: WKWebView?
    }
}
