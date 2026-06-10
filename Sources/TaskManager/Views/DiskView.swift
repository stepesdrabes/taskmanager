import SwiftUI

struct DiskView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc

    var body: some View {
        SectionScrollView(
            title: loc("section.disk"),
            subtitle: activeDisks.map(\.id).joined(separator: " · ")
        ) {
            ForEach(activeDisks) { disk in
                diskBlock(disk)
            }

            if let volumes = store.latest?.volumes, !volumes.isEmpty {
                Text(loc("disk.volumes"))
                    .font(.title3.weight(.semibold))
                ForEach(volumes) { volume in
                    volumeRow(volume)
                }
            }
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
                legendDot(color: .green, label: loc("disk.read"))
                legendDot(color: .red, label: loc("disk.write"))
                Spacer()
            }
            HistoryChart(
                series: [
                    .init(label: loc("disk.read"), color: .green, values: series(for: disk.id, \.readPerSec)),
                    .init(label: loc("disk.write"), color: .red, values: series(for: disk.id, \.writePerSec)),
                ],
                capacity: store.history.capacity,
                yLabel: { Format.storageBytesPerSecond($0) }
            )
            .frame(height: 180)

            StatGrid(items: [
                .init(label: loc("disk.readSpeed"), value: Format.storageBytesPerSecond(disk.readPerSec)),
                .init(label: loc("disk.writeSpeed"), value: Format.storageBytesPerSecond(disk.writePerSec)),
                .init(label: loc("disk.totalRead"), value: Format.storageBytes(disk.totalRead)),
                .init(label: loc("disk.totalWritten"), value: Format.storageBytes(disk.totalWritten)),
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
                Text(loc("disk.volumeUsage", ["used": Format.storageBytes(volume.used), "total": Format.storageBytes(volume.total)]))
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
