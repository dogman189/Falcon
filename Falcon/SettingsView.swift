import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                themeSection
                uiScaleSection
                webScaleSection
            }
            .scrollContentBackground(.hidden)
            .background(settings.backgroundColor)
            .navigationTitle("Settings")
            .toolbarBackground(settings.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            Text("App Theme")
        } footer: {
            Text("Applies to Falcon chrome only. Game and web content keep their own appearance.")
        }
        .listRowBackground(rowBackground)
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
                .tint(.white)

                notchLabels(for: AppSettings.uiScaleNotches, selected: settings.uiScale)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Scales Falcon's library, packer, and settings chrome.")
        }
        .listRowBackground(rowBackground)
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
                .tint(.white)

                notchLabels(for: AppSettings.webScaleNotches, selected: settings.webScale)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Applies globally to all game/client web content.")
        }
        .listRowBackground(rowBackground)
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

    private var rowBackground: some View {
        Color.white.opacity(0.06)
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
                    .foregroundStyle(abs(notch - selected) < 0.001 ? .white : .white.opacity(0.45))
                if notch != notches.last {
                    Spacer()
                }
            }
        }
    }

    private static func index(for value: Double, in notches: [Double]) -> Int {
        notches.enumerated().min(by: { abs($0.element - value) < abs($1.element - value) })?.offset ?? 0
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
