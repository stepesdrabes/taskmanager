import SwiftUI

struct CPUView: View {
    @Environment(MetricsStore.self) private var store
    @State private var display: CoreDisplay = .overall

    private enum CoreDisplay: String, CaseIterable, Identifiable {
        case overall = "Overall"
        case cores = "Logical cores"
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "CPU", subtitle: store.system.chipName)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(display == .overall ? "% Utilization" : "% Utilization per logical processor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Display", selection: $display) {
                            ForEach(CoreDisplay.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    if display == .overall {
                        overallChart
                    } else {
                        coreGrid
                    }
                }

                StatGrid(items: liveItems)

                Divider()

                StatGrid(items: staticItems, valueFont: .body)
            }
            .padding(24)
        }
    }

    private var overallChart: some View {
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

    private var coreGrid: some View {
        let snapshots = store.history.elements
        let coreCount = store.latest?.cpu.coreBusy.count ?? 0
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(0..<coreCount, id: \.self) { core in
                let isEfficiency = store.system.isEfficiencyCore(core)
                let tint: Color = isEfficiency ? .teal : .blue
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Core \(core)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Format.percent(store.latest?.cpu.coreBusy[core] ?? 0))
                            .font(.caption)
                            .monospacedDigit()
                        Text(isEfficiency ? "E" : "P")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    Sparkline(
                        values: snapshots.map { $0.cpu.coreBusy.indices.contains(core) ? $0.cpu.coreBusy[core] : 0 },
                        capacity: store.history.capacity,
                        tint: tint
                    )
                    .frame(height: 56)
                }
                .padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
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
