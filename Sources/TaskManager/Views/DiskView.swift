import SwiftUI

struct DiskView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    title: "Disk",
                    subtitle: activeDisks.map(\.id).joined(separator: " · ")
                )

                ForEach(activeDisks) { disk in
                    diskBlock(disk)
                }

                if let volumes = store.latest?.volumes, !volumes.isEmpty {
                    Text("Volumes")
                        .font(.title3.weight(.semibold))
                    ForEach(volumes) { volume in
                        volumeRow(volume)
                    }
                }
            }
            .padding(24)
        }
    }

    /// Disks with no traffic since boot are cryptexes/idle disk images — noise.
    private var activeDisks: [DiskSnapshot] {
        (store.latest?.disks ?? []).filter { $0.totalRead + $0.totalWritten > 0 }
    }

    private func diskBlock(_ disk: DiskSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                Text(disk.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                legendDot(color: .green, label: "Read")
                legendDot(color: .red, label: "Write")
                Spacer()
            }
            HistoryChart(
                series: [
                    .init(label: "Read", color: .green, values: series(for: disk.id, \.readPerSec)),
                    .init(label: "Write", color: .red, values: series(for: disk.id, \.writePerSec)),
                ],
                capacity: store.history.capacity,
                yLabel: { Format.storageBytesPerSecond($0) }
            )
            .frame(height: 180)

            StatGrid(items: [
                .init(label: "Read speed", value: Format.storageBytesPerSecond(disk.readPerSec)),
                .init(label: "Write speed", value: Format.storageBytesPerSecond(disk.writePerSec)),
                .init(label: "Total read since boot", value: Format.storageBytes(disk.totalRead)),
                .init(label: "Total written since boot", value: Format.storageBytes(disk.totalWritten)),
            ])
            .padding(.top, 12)
        }
    }

    private func volumeRow(_ volume: VolumeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(volume.name)
                    .font(.callout)
                Spacer()
                Text("\(Format.storageBytes(volume.used)) of \(Format.storageBytes(volume.total)) used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(volume.used), total: Double(max(volume.total, 1)))
                .tint(MonitorSection.disk.tint)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func series(for diskID: String, _ keyPath: KeyPath<DiskSnapshot, Double>) -> [Double] {
        store.history.elements.map { snapshot in
            snapshot.disks.first { $0.id == diskID }.map { $0[keyPath: keyPath] } ?? 0
        }
    }
}
