import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// Native SwiftUI screen for turning a user-owned ROM into a portable HTML game
/// client using the hidden `RetroPackerEngine`.
struct RetroPackerView: View {
    let onImported: (GameClient) -> Void
    let onCancel: () -> Void

    @State private var engine = RetroPackerEngine()

    // ROM selection
    @State private var showingFileImporter = false
    @State private var romData: Data?
    @State private var romFileName: String = ""
    @State private var romByteCount: Int = 0

    // Detection / details
    @State private var selectedSystem: RetroSystem?
    @State private var systemDetectionNote: String?
    @State private var title: String = ""

    // Packing state
    @State private var isPacking = false
    @State private var progress: Double = 0
    @State private var statusMessage: String = ""
    @State private var errorMessage: String?

    // File import errors
    @State private var showingImportError = false
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingFileImporter = true
                    } label: {
                        HStack {
                            Label("Choose ROM", systemImage: "doc")
                            Spacer()
                            if !romFileName.isEmpty {
                                Text(romFileName)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if !romFileName.isEmpty {
                        LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(romByteCount), countStyle: .file))
                    }

                    Text("Import a ROM you own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("ROM")
                }

                Section {
                    Picker("System", selection: $selectedSystem) {
                        Text("Select a system").tag(nil as RetroSystem?)
                        ForEach(RetroSystemCatalog.systems) { system in
                            Text(system.label).tag(system as RetroSystem?)
                        }
                    }

                    if let systemDetectionNote {
                        Text(systemDetectionNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Title", text: $title)
                } header: {
                    Text("Details")
                }

                Section {
                    Button {
                        startPacking()
                    } label: {
                        if isPacking {
                            HStack {
                                ProgressView()
                                Text("Packing…")
                            }
                        } else {
                            Text("Pack Game")
                        }
                    }
                    .disabled(romData == nil || selectedSystem == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPacking)

                    if isPacking {
                        ProgressView(value: max(0, min(progress, 1)))
                            .progressViewStyle(.linear)

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Button("Cancel Packing", role: .cancel) {
                            cancelPacking()
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Pack")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pack a Game")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if isPacking {
                            cancelPacking()
                        }
                        onCancel()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: Self.allowedROMTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Couldn't Open ROM", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "Unknown error.")
            }
            .onAppear {
                engine.loadIfNeeded()
                wireCallbacks()
            }
            .onDisappear {
                // Break the engine -> callback -> view retain cycle and stop any
                // in-flight pack when the screen goes away (cancel button, swipe
                // dismiss, or parent removal).
                engine.onProgress = nil
                engine.onComplete = nil
                engine.onError = nil
                if isPacking {
                    engine.cancel()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Host the engine's WKWebView invisibly so iOS does not throttle it.
                RetroPackerEngineHost(engine: engine)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Callbacks

    private func wireCallbacks() {
        engine.onProgress = { percent, message in
            Task { @MainActor in
                self.progress = percent
                self.statusMessage = message
            }
        }
        engine.onComplete = { fileName, htmlData in
            Task { @MainActor in
                let name = self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fileName : self.title
                do {
                    let client = try CustomClientStore.shared.importGeneratedClient(named: name, htmlData: htmlData)
                    self.isPacking = false
                    self.progress = 0
                    self.statusMessage = ""
                    self.errorMessage = nil
                    self.onImported(client)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isPacking = false
                    self.progress = 0
                    self.statusMessage = ""
                }
            }
        }
        engine.onError = { message in
            Task { @MainActor in
                self.errorMessage = message
                self.isPacking = false
                self.progress = 0
                self.statusMessage = ""
            }
        }
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
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

    private func startPacking() {
        guard let romData, let system = selectedSystem else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        errorMessage = nil
        progress = 0
        statusMessage = "Starting…"
        isPacking = true

        engine.pack(romData: romData, romName: romFileName, system: system.id, title: trimmedTitle)
    }

    private func cancelPacking() {
        engine.cancel()
        isPacking = false
        progress = 0
        statusMessage = ""
    }

    // MARK: - Helpers

    private static var allowedROMTypes: [UTType] {
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
