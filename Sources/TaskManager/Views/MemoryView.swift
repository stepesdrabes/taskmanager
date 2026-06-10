import SwiftUI

struct MemoryView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Memory", subtitle: Format.bytes(store.system.memoryTotal))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HistoryChart(
                        series: [.init(
                            label: "Used",
                            color: MonitorSection.memory.tint,
                            values: store.history.elements.map { Double($0.memory.used) }
                        )],
                        capacity: store.history.capacity,
                        yDomain: 0...Double(store.system.memoryTotal),
                        yLabel: { Format.bytes(UInt64($0)) }
                    )
                    .frame(height: 240)
                }

                if let memory = store.latest?.memory {
                    CompositionBar(
                        segments: [
                            .init(label: "App", value: memory.app, color: .green),
                            .init(label: "Wired", value: memory.wired, color: .indigo),
                            .init(label: "Compressed", value: memory.compressed, color: .orange),
                            .init(label: "Cached", value: memory.cached, color: .gray),
                        ],
                        total: store.system.memoryTotal
                    )

                    StatGrid(items: items(for: memory))

                    HStack(spacing: 6) {
                        Circle()
                            .fill(pressureColor(memory.pressure))
                            .frame(width: 8, height: 8)
                        Text("Memory pressure: \(pressureLabel(memory.pressure))")
                            .font(.callout)
                    }
                }
            }
            .padding(24)
        }
    }

    private func items(for memory: MemorySnapshot) -> [StatGrid.Item] {
        [
            .init(label: "Memory used", value: Format.bytes(memory.used)),
            .init(label: "App memory", value: Format.bytes(memory.app)),
            .init(label: "Wired", value: Format.bytes(memory.wired)),
            .init(label: "Compressed", value: Format.bytes(memory.compressed)),
            .init(label: "Cached files", value: Format.bytes(memory.cached)),
            .init(label: "Swap used", value: "\(Format.bytes(memory.swapUsed)) of \(Format.bytes(memory.swapTotal)) allocated"),
        ]
    }

    private func pressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }

    private func pressureLabel(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}
