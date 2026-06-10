import SwiftUI

struct EnergyView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc
    @AppStorage("temperatureUnit") private var temperatureUnit = TemperatureUnit.celsius

    var body: some View {
        SectionScrollView(title: loc("section.energy"), subtitle: subtitle) {
            if let energy = store.latest?.energy {
                chargeIndicator(energy)

                VStack(alignment: .leading, spacing: 14) {
                    Text(loc("energy.powerDraw"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HistoryChart(
                        series: [.init(
                            label: loc("energy.power"),
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
                    loc("energy.noBattery"),
                    systemImage: "bolt.slash",
                    description: Text(loc("energy.noBatteryDesc"))
                )
                .padding(.top, 60)
            }
        }
    }

    private var subtitle: String {
        guard let energy = store.latest?.energy else { return "" }
        return loc("energy.subtitle", [
            "health": "\(Int((energy.health * 100).rounded()))",
            "cycles": "\(energy.cycleCount)",
        ])
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
            .init(label: loc("energy.charge"), value: "\(Int((energy.charge * 100).rounded()))%"),
            .init(label: loc("energy.powerSource"), value: energy.onAC ? loc("energy.powerAdapter") : loc("energy.battery")),
            .init(label: loc("energy.status"), value: statusLabel(energy)),
            .init(label: timeLabel(energy), value: timeValue(energy)),
            .init(label: loc("energy.powerDraw"), value: String(format: "%.1f W", energy.powerWatts)),
            .init(label: loc("energy.powerAdapterLabel"), value: adapterValue(energy)),
            .init(label: loc("energy.batteryHealth"), value: "\(Int((energy.health * 100).rounded()))%"),
            .init(label: loc("energy.cycleCount"), value: "\(energy.cycleCount)"),
            .init(label: loc("energy.temperature"), value: temperatureUnit.format(celsius: energy.temperature)),
            .init(label: loc("energy.voltage"), value: String(format: "%.2f V", energy.voltage)),
            .init(label: loc("energy.capacity"), value: loc("energy.capacityValue", ["current": "\(energy.currentCapacity)", "design": "\(energy.designCapacity)"])),
        ]
    }

    private func adapterValue(_ energy: EnergySnapshot) -> String {
        guard energy.onAC else { return loc("energy.notConnected") }
        if let watts = energy.adapterWatts, watts > 0 { return loc("energy.adapterWatts", ["watts": "\(watts)"]) }
        return loc("energy.connected")
    }

    private func statusLabel(_ energy: EnergySnapshot) -> String {
        switch energy.status {
        case .charging: loc("energy.charging")
        case .charged: loc("energy.fullyCharged")
        case .onBattery: loc("energy.onBattery")
        case .pluggedNotCharging: loc("energy.pluggedNotCharging")
        }
    }

    private func timeLabel(_ energy: EnergySnapshot) -> String {
        energy.status == .charging ? loc("energy.timeToFull") : loc("energy.timeRemaining")
    }

    private func timeValue(_ energy: EnergySnapshot) -> String {
        let minutes = energy.status == .charging ? energy.timeToFull : energy.timeToEmpty
        switch minutes {
        case ..<0: return loc("energy.calculating")
        case 0: return energy.status == .charged ? loc("common.unavailable") : loc("energy.calculating")
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
