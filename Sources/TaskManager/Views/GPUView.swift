import SwiftUI

struct GPUView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        SectionScrollView(title: "GPU", subtitle: store.system.gpuName ?? store.system.chipName) {
            VStack(alignment: .leading, spacing: 4) {
                Text("% Utilization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HistoryChart(
                    series: [.init(
                        label: "Device",
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
                auxSparkline(label: "Renderer", value: store.latest?.gpu?.renderer) {
                    $0.gpu?.renderer
                }
                auxSparkline(label: "Tiler", value: store.latest?.gpu?.tiler) {
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
                Text(value.map(Format.percent) ?? "—")
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
        return [
            .init(label: "Utilization", value: gpu?.device.map(Format.percent) ?? "—"),
            .init(label: "Shared memory in use", value: gpu?.usedMemory.map(Format.bytes) ?? "—"),
            .init(label: "Shared memory allocated", value: gpu?.allocatedMemory.map(Format.bytes) ?? "—"),
            .init(label: "Cores", value: store.system.gpuCoreCount.map(String.init) ?? "—"),
            .init(label: "Type", value: "Integrated (shared memory)"),
        ]
    }
}
