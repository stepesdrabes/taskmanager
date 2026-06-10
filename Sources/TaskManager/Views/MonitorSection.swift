import SwiftUI

enum MonitorSection: String, CaseIterable, Identifiable {
    case cpu, memory, gpu, disk, network, energy, processes, systemInfo, settings

    var id: Self { self }

    /// The metric sections shown in the main sidebar list (Settings is pinned
    /// separately at the bottom).
    static let metrics: [MonitorSection] = allCases.filter { $0 != .settings }

    /// Localization key for the section's display name.
    var titleKey: String { "section.\(rawValue)" }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .gpu: "cpu.fill"   // SF Symbols has no gpu glyph; tint differentiates
        case .disk: "internaldrive"
        case .network: "network"
        case .energy: "bolt.fill"
        case .processes: "list.bullet.rectangle"
        case .systemInfo: "desktopcomputer"
        case .settings: "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: .blue
        case .memory: .green
        case .gpu: .purple
        case .disk: .orange
        case .network: .teal
        case .energy: .yellow
        case .processes: .gray
        case .systemInfo: .indigo
        case .settings: .gray
        }
    }
}
