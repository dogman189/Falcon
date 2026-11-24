import SwiftUI

struct SettingsView: View {
    var isActiveTab: Bool = true
    var onReturnToLibrary: (() -> Void)? = nil

    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var controllerManager = GameControllerManager.shared
    @State private var focusedField: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                themeSection
                uiScaleSection
                webScaleSection

                if controllerManager.isConnected {
                    controllerLegendSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(settings.backgroundColor)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(settings.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
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
    }

    private var themeSection: some View {
        Section {
            Picker("Theme", selection: $settings.appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            sectionHeader("App Theme", field: 0)
        } footer: {
            Text("Applies to Falcon chrome only. Game and web content keep their own appearance.")
        }
        .listRowBackground(rowBackground(for: 0))
    }

    private var uiScaleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("App UI Scale")
                    Spacer()
                    Text(percentLabel(settings.uiScale))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: uiScaleIndex,
                    in: 0...Double(AppSettings.uiScaleNotches.count - 1),
                    step: 1
                )
                .tint(settings.appTheme.primaryText)

                notchLabels(for: AppSettings.uiScaleNotches, selected: settings.uiScale)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader("Interface", field: 1)
        } footer: {
            Text("Scales Falcon's library, packer, and settings chrome.")
        }
        .listRowBackground(rowBackground(for: 1))
    }

    private var webScaleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Web Content Scale")
                    Spacer()
                    Text(percentLabel(settings.webScale))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: webScaleIndex,
                    in: 0...Double(AppSettings.webScaleNotches.count - 1),
                    step: 1
                )
                .tint(settings.appTheme.primaryText)

                notchLabels(for: AppSettings.webScaleNotches, selected: settings.webScale)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader("Web Content", field: 2)
        } footer: {
            Text("Applies globally to all game/client web content.")
        }
        .listRowBackground(rowBackground(for: 2))
    }

    private var controllerLegendSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack(spacing: 14) {
                    buttonLegendItem(button: "▲▼", label: "Move")
                    buttonLegendItem(button: "◀▶", label: "Adjust")
                    buttonLegendItem(button: "A", label: "Activate")
                }
                HStack(spacing: 14) {
                    buttonLegendItem(button: "B", label: "Library")
                    buttonLegendItem(button: "LB/RB", label: "Tabs")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private var uiScaleIndex: Binding<Double> {
        Binding(
            get: { Double(Self.index(for: settings.uiScale, in: AppSettings.uiScaleNotches)) },
            set: { settings.uiScale = AppSettings.uiScaleNotches[Int($0.rounded())] }
        )
    }

    private var webScaleIndex: Binding<Double> {
        Binding(
            get: { Double(Self.index(for: settings.webScale, in: AppSettings.webScaleNotches)) },
            set: { settings.webScale = AppSettings.webScaleNotches[Int($0.rounded())] }
        )
    }

    private func rowBackground(for field: Int) -> some View {
        let isFocused = focusedField == field && controllerManager.isConnected
        let base = settings.appTheme.primaryText
        return Rectangle()
            .fill(isFocused ? base.opacity(0.12) : settings.appTheme.subtleFill)
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(base, lineWidth: 2)
                }
            }
    }

    private func sectionHeader(_ title: String, field: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
            if controllerManager.isConnected && focusedField == field {
                Text("• SELECTED")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
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

    private func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    @ViewBuilder
    private func notchLabels(for notches: [Double], selected: Double) -> some View {
        HStack {
            ForEach(notches, id: \.self) { notch in
                Text(percentLabel(notch))
                    .font(.caption2.weight(abs(notch - selected) < 0.001 ? .bold : .regular))
                    .foregroundStyle(abs(notch - selected) < 0.001 ? settings.appTheme.primaryText : settings.appTheme.secondaryText)
                if notch != notches.last {
                    Spacer()
                }
            }
        }
    }

    private static func index(for value: Double, in notches: [Double]) -> Int {
        notches.enumerated().min(by: { abs($0.element - value) < abs($1.element - value) })?.offset ?? 0
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
            adjustFocusedField(step: -1)
        }

        controllerManager.onNavigateRight = {
            adjustFocusedField(step: 1)
        }

        controllerManager.onActionA = {
            handleActionA()
        }

        controllerManager.onActionB = {
            handleActionB()
        }
        controllerManager.onActionX = nil
    }

    private func navigateVertically(step: Int) {
        focusedField = max(0, min(2, focusedField + step))
    }

    private func adjustFocusedField(step: Int) {
        switch focusedField {
        case 0:
            cycleTheme(step: step)
        case 1:
            adjustScale(current: settings.uiScale, notches: AppSettings.uiScaleNotches, step: step) { settings.uiScale = $0 }
        case 2:
            adjustScale(current: settings.webScale, notches: AppSettings.webScaleNotches, step: step) { settings.webScale = $0 }
        default:
            break
        }
    }

    private func handleActionA() {
        switch focusedField {
        case 0:
            cycleTheme(step: 1)
        case 1:
            adjustScale(current: settings.uiScale, notches: AppSettings.uiScaleNotches, step: 1) { settings.uiScale = $0 }
        case 2:
            adjustScale(current: settings.webScale, notches: AppSettings.webScaleNotches, step: 1) { settings.webScale = $0 }
        default:
            break
        }
    }

    private func handleActionB() {
        onReturnToLibrary?()
    }

    private func cycleTheme(step: Int) {
        let all = AppTheme.allCases
        guard let index = all.firstIndex(of: settings.appTheme) else { return }
        let next = (index + step + all.count) % all.count
        settings.appTheme = all[next]
    }

    private func adjustScale(current: Double, notches: [Double], step: Int, set: (Double) -> Void) {
        let index = Self.index(for: current, in: notches)
        let next = max(0, min(notches.count - 1, index + step))
        set(notches[next])
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}