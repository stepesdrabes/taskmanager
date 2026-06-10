import SwiftUI

struct CPUView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc
    @State private var display: CoreDisplay = .overall

    private enum CoreDisplay: Hashable {
        case overall, cores
    }

    var body: some View {
        SectionScrollView(title: loc("section.cpu"), subtitle: store.system.chipName) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(display == .overall ? loc("cpu.utilizationPercent") : loc("cpu.utilizationPerCore"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker(loc("cpu.display"), selection: $display) {
                        Text(loc("cpu.overall")).tag(CoreDisplay.overall)
                        Text(loc("cpu.logicalCores")).tag(CoreDisplay.cores)
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
    }

    private var overallChart: some View {
        HistoryChart(
            series: [.init(
                label: loc("cpu.utilization"),
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
                let badge = isEfficiency ? loc("common.efficiency") : loc("common.performance")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(loc("cpu.core", ["n": "\(core)"]))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Format.percent(store.latest?.cpu.coreBusy[core] ?? 0))
                            .font(.caption)
                            .monospacedDigit()
                        Text(badge.prefix(1))
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
            .init(label: loc("cpu.utilization"), value: Format.percent(cpu.totalBusy)),
            .init(label: loc("cpu.processes"), value: "\(cpu.processCount)"),
            .init(label: loc("cpu.threads"), value: "\(cpu.threadCount)"),
            .init(label: loc("cpu.upTime"), value: Format.uptime(since: store.system.bootTime)),
            .init(label: loc("cpu.loadAverage"), value: String(format: "%.2f / %.2f / %.2f", cpu.load1, cpu.load5, cpu.load15)),
        ]
    }

    private var staticItems: [StatGrid.Item] {
        let system = store.system
        let performance = loc("common.performance")
        let efficiency = loc("common.efficiency")
        return [
            .init(label: loc("cpu.coresLabel", ["type": performance]), value: "\(system.pCoreCount)"),
            .init(label: loc("cpu.coresLabel", ["type": efficiency]), value: "\(system.eCoreCount)"),
            .init(label: loc("cpu.logicalProcessors"), value: "\(system.logicalCPUs)"),
            .init(label: loc("cpu.l1Cache", ["type": performance]), value: "\(Format.bytes(system.pCoreL1i)) + \(Format.bytes(system.pCoreL1d))"),
            .init(label: loc("cpu.l1Cache", ["type": efficiency]), value: "\(Format.bytes(system.eCoreL1i)) + \(Format.bytes(system.eCoreL1d))"),
            .init(label: loc("cpu.l2Cache", ["type": performance]), value: Format.bytes(system.pCoreL2)),
            .init(label: loc("cpu.l2Cache", ["type": efficiency]), value: Format.bytes(system.eCoreL2)),
        ]
    }
}
