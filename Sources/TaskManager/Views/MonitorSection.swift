import SwiftUI

enum MonitorSection: String, CaseIterable, Identifiable {
    case cpu, memory, gpu, disk, network, energy, processes, systemInfo

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .gpu: "GPU"
        case .disk: "Disk"
        case .network: "Network"
        case .energy: "Energy"
        case .processes: "Processes"
        case .systemInfo: "System Info"
        }
    }

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
        }
    }
}
