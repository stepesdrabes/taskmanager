import SwiftUI

enum MonitorSection: String, CaseIterable, Identifiable {
    case cpu, memory, gpu, disk, network, processes

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .gpu: "GPU"
        case .disk: "Disk"
        case .network: "Network"
        case .processes: "Processes"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .gpu: "cpu.fill"   // SF Symbols has no gpu glyph; tint differentiates
        case .disk: "internaldrive"
        case .network: "network"
        case .processes: "list.bullet.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: .blue
        case .memory: .green
        case .gpu: .purple
        case .disk: .orange
        case .network: .teal
        case .processes: .gray
        }
    }
}
