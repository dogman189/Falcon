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
                    let client = try CustomClientStore.shared.importGeneratedClient(
                        named: name,
                        htmlData: htmlData,
                        systemID: self.selectedSystem?.id
                    )
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
/// Fully supports gamepad/controller navigation, field toggling, and system selection.
struct RetroPackerView: View {
    @Bindable var model: RetroPackerModel
    var isActiveTab: Bool = true
    let onImported: (GameClient) -> Void
    var onReturnToLibrary: (() -> Void)? = nil
    let onCancel: (() -> Void)?

    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var controllerManager = GameControllerManager.shared
    /// 0: ROM File, 1: System Picker, 2: Game Title TextField, 3: Pack / Cancel Button
    @State private var focusedField: Int = 0
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // ROM file section (Field 0)
                Section {
                    Button {
                        focusedField = 0
                        model.showingFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.body.weight(focusedField == 0 ? .bold : .regular))
                            if model.romFileName.isEmpty {
                                Text("Choose ROM File")
                                    .fontWeight(focusedField == 0 ? .semibold : .regular)
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.romFileName)
                                        .foregroundStyle(.primary)
                                        .fontWeight(focusedField == 0 ? .semibold : .regular)
                                    Text(byteCountLabel(model.romByteCount))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if focusedField == 0 && controllerManager.isConnected {
                                Image(systemName: "button.programmable")
                                    .foregroundStyle(settings.appTheme.secondaryText)
                            }
                        }
                    }
                    .disabled(model.isPacking)
                    .listRowBackground(rowBackground(for: 0))
                } header: {
                    HStack {
                        Text("ROM File")
                        if focusedField == 0 && controllerManager.isConnected {
                            Text("• SELECTED").font(.caption2.bold()).foregroundStyle(.green)
                        }
                    }
                } footer: {
                    Text("Select a ROM file you own. Nothing is uploaded; packing happens on your device.")
                }

                // System section (Field 1)
                Section {
                    HStack {
                        Picker("System", selection: $model.selectedSystem) {
                            Text(model.romFileName.isEmpty ? "Choose a ROM first" : "Select a system")
                                .tag(nil as RetroSystem?)
                            ForEach(RetroSystemCatalog.systems) { system in
                                Text(system.label).tag(system as RetroSystem?)
                            }
                        }
                        .disabled(model.isPacking)

                        if focusedField == 1 && controllerManager.isConnected {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                Text("D-Pad")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(settings.appTheme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(settings.appTheme.subtleFill)
                            .clipShape(Capsule())
                        }
                    }
                    .listRowBackground(rowBackground(for: 1))

                    if let note = model.systemDetectionNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("System")
                        if focusedField == 1 && controllerManager.isConnected {
                            Text("• SELECTED").font(.caption2.bold()).foregroundStyle(.green)
                        }
                    }
                }

                // Details section (Field 2)
                Section {
                    TextField("Game title", text: $model.title)
                        .focused($isTitleFieldFocused)
                        .disabled(model.isPacking)
                        .listRowBackground(rowBackground(for: 2))
                } header: {
                    HStack {
                        Text("Details")
                        if focusedField == 2 && controllerManager.isConnected {
                            Text("• SELECTED").font(.caption2.bold()).foregroundStyle(.green)
                        }
                    }
                } footer: {
                    Text("This name is used for the imported client in your library.")
                }

                // Pack section (Field 3)
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
                        .listRowBackground(rowBackground(for: 3))
                    } else {
                        Button {
                            focusedField = 3
                            model.startPacking()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Pack and Add to Library", systemImage: "shippingbox.and.arrow.backward")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .disabled(!canPack)
                        .listRowBackground(rowBackground(for: 3, isPrimaryButton: true))
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

                // Controller Legend (when connected)
                if controllerManager.isConnected {
                    Section {
                        VStack(spacing: 8) {
                            HStack(spacing: 14) {
                                buttonLegendItem(button: "A", label: actionLabel)
                                buttonLegendItem(button: "B", label: "Library")
                                buttonLegendItem(button: "LB", label: "Library Tab")
                            }
                            if focusedField == 1 {
                                HStack(spacing: 6) {
                                    buttonLegendItem(button: "◀ ▶", label: "Change System")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(settings.backgroundColor)
            .navigationTitle("Pack a Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(settings.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

                if let onCancel {
                    ToolbarItem(placement: .topBarTrailing) {
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
                if isActiveTab {
                    setupControllerCallbacks()
                }
            }
            .onChange(of: isActiveTab) { _, active in
                if active {
                    setupControllerCallbacks()
                }
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

    private var actionLabel: String {
        switch focusedField {
        case 0: return "Choose ROM"
        case 1: return "Next System"
        case 2: return "Edit Title"
        case 3: return model.isPacking ? "Cancel" : "Pack Game"
        default: return "Select"
        }
    }

    @ViewBuilder
    private func rowBackground(for fieldIndex: Int, isPrimaryButton: Bool = false) -> some View {
        let isFocused = (focusedField == fieldIndex && controllerManager.isConnected)
        let base = settings.appTheme.primaryText
        ZStack {
            if isPrimaryButton {
                isFocused ? base.opacity(0.25) : base.opacity(0.1)
            } else {
                isFocused ? base.opacity(0.12) : settings.appTheme.subtleFill
            }

            if isFocused {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(base, lineWidth: 2)
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
        controllerManager.onNavigateUp = {
            navigateVertically(step: -1)
        }

        controllerManager.onNavigateDown = {
            navigateVertically(step: 1)
        }

        controllerManager.onNavigateLeft = {
            navigateHorizontally(step: -1)
        }

        controllerManager.onNavigateRight = {
            navigateHorizontally(step: 1)
        }

        controllerManager.onActionA = {
            handleActionA()
        }

        controllerManager.onActionB = {
            handleActionB()
        }
    }

    private func navigateVertically(step: Int) {
        let newField = max(0, min(3, focusedField + step))
        if newField != focusedField {
            focusedField = newField
            isTitleFieldFocused = (newField == 2)
        }
    }

    private func navigateHorizontally(step: Int) {
        if focusedField == 1 {
            // Cycle system in catalog
            cycleSystem(step: step)
        }
    }

    private func cycleSystem(step: Int) {
        let all = RetroSystemCatalog.systems
        guard !all.isEmpty else { return }

        if let current = model.selectedSystem, let idx = all.firstIndex(of: current) {
            let nextIdx = (idx + step + all.count) % all.count
            model.selectedSystem = all[nextIdx]
        } else {
            model.selectedSystem = all.first
        }
    }

    private func handleActionA() {
        switch focusedField {
        case 0:
            model.showingFileImporter = true
        case 1:
            cycleSystem(step: 1)
        case 2:
            isTitleFieldFocused = true
        case 3:
            if model.isPacking {
                model.cancelPacking()
            } else if canPack {
                model.startPacking()
            }
        default:
            break
        }
    }

    private func handleActionB() {
        if model.isPacking {
            model.cancelPacking()
        } else {
            onReturnToLibrary?()
        }
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
