import SwiftUI

/// Window appearance: follow the system, or force light / dark.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: String { "settings.theme\(rawValue.capitalized)" }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit

    var id: Self { self }

    var titleKey: String { "settings.\(rawValue)" }

    func format(celsius value: Double) -> String {
        switch self {
        case .celsius: String(format: "%.1f °C", value)
        case .fahrenheit: String(format: "%.1f °F", value * 9 / 5 + 32)
        }
    }
}
