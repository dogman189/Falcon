import Combine
import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case darkBlue
    case black
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .darkBlue: return "Dark Blue"
        case .black: return "Black"
        case .light: return "Light"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .darkBlue: return Color(red: 11 / 255, green: 20 / 255, blue: 38 / 255)
        case .black: return .black
        case .light: return Color(red: 0.95, green: 0.96, blue: 0.98)
        }
    }

    var uiColor: UIColor {
        switch self {
        case .darkBlue: return UIColor(red: 11 / 255, green: 20 / 255, blue: 38 / 255, alpha: 1)
        case .black: return .black
        case .light: return UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1)
        }
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .darkBlue, .black: return .dark
        case .light: return .light
        }
    }

    var primaryText: Color {
        switch self {
        case .darkBlue, .black: return .white
        case .light: return .black
        }
    }

    var secondaryText: Color {
        switch self {
        case .darkBlue, .black: return .white.opacity(0.7)
        case .light: return .black.opacity(0.65)
        }
    }

    var subtleFill: Color {
        switch self {
        case .darkBlue, .black: return .white.opacity(0.08)
        case .light: return .black.opacity(0.06)
        }
    }

    var border: Color {
        switch self {
        case .darkBlue, .black: return .white.opacity(0.12)
        case .light: return .black.opacity(0.12)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let appTheme = "appTheme"
        static let uiScale = "uiScale"
        static let webScale = "webScale"
    }

    static let uiScaleNotches: [Double] = [0.90, 1.00, 1.10, 1.20]
    static let webScaleNotches: [Double] = [0.75, 0.85, 1.00, 1.15, 1.25]

    @Published var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: Keys.appTheme) }
    }

    @Published var uiScale: Double {
        didSet { UserDefaults.standard.set(uiScale, forKey: Keys.uiScale) }
    }

    @Published var webScale: Double {
        didSet { UserDefaults.standard.set(webScale, forKey: Keys.webScale) }
    }

    init(defaults: UserDefaults = .standard) {
        let themeRaw = defaults.string(forKey: Keys.appTheme) ?? AppTheme.darkBlue.rawValue
        self.appTheme = AppTheme(rawValue: themeRaw) ?? .darkBlue

        let storedUIScale = defaults.object(forKey: Keys.uiScale) as? Double ?? 1.0
        self.uiScale = Self.nearestNotch(to: storedUIScale, in: Self.uiScaleNotches)

        let storedWebScale = defaults.object(forKey: Keys.webScale) as? Double ?? 1.0
        self.webScale = Self.nearestNotch(to: storedWebScale, in: Self.webScaleNotches)
    }

    var backgroundColor: Color { appTheme.backgroundColor }
    var backgroundUIColor: UIColor { appTheme.uiColor }

    static func nearestNotch(to value: Double, in notches: [Double]) -> Double {
        notches.min(by: { abs($0 - value) < abs($1 - value) }) ?? 1.0
    }
}

struct AppChromeScaleModifier: ViewModifier {
    let scale: Double

    func body(content: Content) -> some View {
        if abs(scale - 1.0) < 0.001 {
            content
        } else {
            GeometryReader { geo in
                content
                    .frame(
                        width: geo.size.width / scale,
                        height: geo.size.height / scale
                    )
                    .scaleEffect(scale, anchor: .topLeading)
            }
        }
    }
}

extension View {
    func appChromeScale(_ scale: Double) -> some View {
        modifier(AppChromeScaleModifier(scale: scale))
    }
}
