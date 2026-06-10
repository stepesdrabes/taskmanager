import SwiftUI

struct GPUView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc

    var body: some View {
        SectionScrollView(title: loc("section.gpu"), subtitle: store.system.gpuName ?? store.system.chipName) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("gpu.utilizationPercent"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HistoryChart(
                    series: [.init(
                        label: loc("gpu.device"),
                        color: MonitorSection.gpu.tint,
                        values: store.history.elements.map { ($0.gpu?.device ?? 0) * 100 }
                    )],
                    capacity: store.history.capacity,
                    yDomain: 0...100,
                    yLabel: { "\(Int($0))%" }
                )
                .frame(height: 240)
            }

            HStack(spacing: 16) {
                auxSparkline(label: loc("gpu.renderer"), value: store.latest?.gpu?.renderer) {
                    $0.gpu?.renderer
                }
                auxSparkline(label: loc("gpu.tiler"), value: store.latest?.gpu?.tiler) {
                    $0.gpu?.tiler
                }
            }

            StatGrid(items: items)
        }
    }

    private func auxSparkline(
        label: String,
        value: Double?,
        series: @escaping (Snapshot) -> Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value.map(Format.percent) ?? loc("common.unavailable"))
                    .font(.caption)
                    .monospacedDigit()
            }
            Sparkline(
                values: store.history.elements.map { series($0) ?? 0 },
                capacity: store.history.capacity,
                tint: MonitorSection.gpu.tint
            )
            .frame(height: 56)
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var items: [StatGrid.Item] {
        let gpu = store.latest?.gpu
        let dash = loc("common.unavailable")
        return [
            .init(label: loc("gpu.utilization"), value: gpu?.device.map(Format.percent) ?? dash),
            .init(label: loc("gpu.sharedInUse"), value: gpu?.usedMemory.map(Format.bytes) ?? dash),
            .init(label: loc("gpu.sharedAllocated"), value: gpu?.allocatedMemory.map(Format.bytes) ?? dash),
            .init(label: loc("gpu.cores"), value: store.system.gpuCoreCount.map(String.init) ?? dash),
            .init(label: loc("gpu.type"), value: loc("gpu.integrated")),
        ]
    }
}
