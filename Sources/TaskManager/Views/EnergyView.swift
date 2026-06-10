import SwiftUI

struct EnergyView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        SectionScrollView(title: "Energy", subtitle: subtitle) {
            if let energy = store.latest?.energy {
                chargeIndicator(energy)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Power draw")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HistoryChart(
                        series: [.init(
                            label: "Power",
                            color: MonitorSection.energy.tint,
                            values: store.history.elements.map { $0.energy?.powerWatts ?? 0 }
                        )],
                        capacity: store.history.capacity,
                        yLabel: { String(format: "%.0f W", $0) }
                    )
                    .frame(height: 220)
                }

                StatGrid(items: items(for: energy))
            } else {
                ContentUnavailableView(
                    "No Battery",
                    systemImage: "bolt.slash",
                    description: Text("This Mac has no battery to report on.")
                )
                .padding(.top, 60)
            }
        }
    }

    private var subtitle: String {
        guard let energy = store.latest?.energy else { return "" }
        return "\(Int((energy.health * 100).rounded()))% health · \(energy.cycleCount) cycles"
    }

    private func chargeIndicator(_ energy: EnergySnapshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: batterySymbol(energy))
                .font(.system(size: 30))
                .foregroundStyle(chargeColor(energy))
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int((energy.charge * 100).rounded()))%")
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                Text(statusLabel(energy))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func items(for energy: EnergySnapshot) -> [StatGrid.Item] {
        [
            .init(label: "Charge", value: "\(Int((energy.charge * 100).rounded()))%"),
            .init(label: "Power source", value: energy.onAC ? "Power Adapter" : "Battery"),
            .init(label: "Status", value: statusLabel(energy)),
            .init(label: timeLabel(energy), value: timeValue(energy)),
            .init(label: "Power draw", value: String(format: "%.1f W", energy.powerWatts)),
            .init(label: "Power adapter", value: adapterValue(energy)),
            .init(label: "Battery health", value: "\(Int((energy.health * 100).rounded()))%"),
            .init(label: "Cycle count", value: "\(energy.cycleCount)"),
            .init(label: "Temperature", value: String(format: "%.1f °C", energy.temperature)),
            .init(label: "Voltage", value: String(format: "%.2f V", energy.voltage)),
            .init(label: "Capacity", value: "\(energy.currentCapacity) of \(energy.designCapacity) mAh"),
        ]
    }

    private func adapterValue(_ energy: EnergySnapshot) -> String {
        guard energy.onAC else { return "Not connected" }
        if let watts = energy.adapterWatts, watts > 0 { return "\(watts) W" }
        return "Connected"
    }

    private func statusLabel(_ energy: EnergySnapshot) -> String {
        switch energy.status {
        case .charging: "Charging"
        case .charged: "Fully charged"
        case .onBattery: "On battery"
        case .pluggedNotCharging: "Plugged in, not charging"
        }
    }

    private func timeLabel(_ energy: EnergySnapshot) -> String {
        energy.status == .charging ? "Time to full" : "Time remaining"
    }

    private func timeValue(_ energy: EnergySnapshot) -> String {
        let minutes = energy.status == .charging ? energy.timeToFull : energy.timeToEmpty
        switch minutes {
        case ..<0: return "Calculating…"
        case 0: return energy.status == .charged ? "—" : "Calculating…"
        default: return String(format: "%d:%02d", minutes / 60, minutes % 60)
        }
    }

    private func batterySymbol(_ energy: EnergySnapshot) -> String {
        if energy.isCharging { return "battery.100.bolt" }
        switch Int((energy.charge * 100).rounded()) {
        case ..<13: return "battery.0"
        case 13..<38: return "battery.25"
        case 38..<63: return "battery.50"
        case 63..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private func chargeColor(_ energy: EnergySnapshot) -> Color {
        if energy.isCharging || energy.onAC { return .green }
        return energy.charge < 0.2 ? .red : MonitorSection.energy.tint
    }
}
