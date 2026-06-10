import SwiftUI

struct CPUView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "CPU", subtitle: store.system.chipName)

                VStack(alignment: .leading, spacing: 4) {
                    Text("% Utilization")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HistoryChart(
                        series: [.init(
                            label: "Utilization",
                            color: MonitorSection.cpu.tint,
                            values: store.history.elements.map { $0.cpu.totalBusy * 100 }
                        )],
                        capacity: store.history.capacity,
                        yDomain: 0...100,
                        yLabel: { "\(Int($0))%" }
                    )
                    .frame(height: 240)
                }

                StatGrid(items: liveItems)

                Divider()

                StatGrid(items: staticItems, valueFont: .body)
            }
            .padding(24)
        }
    }

    private var liveItems: [StatGrid.Item] {
        guard let cpu = store.latest?.cpu else { return [] }
        return [
            .init(label: "Utilization", value: Format.percent(cpu.totalBusy)),
            .init(label: "Processes", value: "\(cpu.processCount)"),
            .init(label: "Threads", value: "\(cpu.threadCount)"),
            .init(label: "Up time", value: Format.uptime(since: store.system.bootTime)),
            .init(label: "Load average", value: String(format: "%.2f / %.2f / %.2f", cpu.load1, cpu.load5, cpu.load15)),
        ]
    }

    private var staticItems: [StatGrid.Item] {
        let system = store.system
        return [
            .init(label: "\(system.pCoreName) cores", value: "\(system.pCoreCount)"),
            .init(label: "\(system.eCoreName) cores", value: "\(system.eCoreCount)"),
            .init(label: "Logical processors", value: "\(system.logicalCPUs)"),
            .init(label: "L1 cache (P)", value: "\(Format.bytes(system.pCoreL1i)) + \(Format.bytes(system.pCoreL1d))"),
            .init(label: "L1 cache (E)", value: "\(Format.bytes(system.eCoreL1i)) + \(Format.bytes(system.eCoreL1d))"),
            .init(label: "L2 cache (P)", value: Format.bytes(system.pCoreL2)),
            .init(label: "L2 cache (E)", value: Format.bytes(system.eCoreL2)),
        ]
    }
}
