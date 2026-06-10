import SwiftUI

struct DiskView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc
    @State private var usage: StorageUsage?

    var body: some View {
        SectionScrollView(
            title: loc("section.disk"),
            subtitle: activeDisks.map(\.id).joined(separator: " · ")
        ) {
            if let volumes = store.latest?.volumes, !volumes.isEmpty {
                ForEach(volumes) { volume in
                    StorageMeter(
                        title: volume.name,
                        caption: loc("disk.volumeUsage", ["used": Format.storageBytes(volume.used), "total": Format.storageBytes(volume.total)]),
                        used: slices(for: volume),
                        free: volume.available,
                        total: volume.total,
                        freeLabel: loc("disk.free")
                    )
                    .padding(.bottom, 8)
                }
            }

            if !activeDisks.isEmpty {
                Divider()
                ForEach(activeDisks) { disk in
                    diskBlock(disk)
                }
            }
        }
        .task { usage = await StorageAnalyzer.analyze() }
    }

    /// The breakdown only covers the boot volume (Spotlight's scope); other
    /// volumes fall back to a single Used segment.
    private func slices(for volume: VolumeSnapshot) -> [StorageMeter.Slice] {
        guard volume.id == "/", let usage, volume.used > 0 else {
            return [.init(label: loc("disk.used"), bytes: volume.used, color: .accentColor)]
        }
        // Logical sizes (clones, compression) can exceed physical use — scale the
        // categories down so they never overflow the used portion.
        let categorized = usage.categorized
        let scale = categorized > volume.used ? Double(volume.used) / Double(categorized) : 1
        func scaled(_ bytes: UInt64) -> UInt64 { UInt64(Double(bytes) * scale) }

        let apps = scaled(usage.applications)
        let photos = scaled(usage.photos)
        let movies = scaled(usage.movies)
        let audio = scaled(usage.audio)
        let systemData = volume.used - min(apps + photos + movies + audio, volume.used)

        return [
            .init(label: loc("disk.applications"), bytes: apps, color: .orange),
            .init(label: loc("disk.photos"), bytes: photos, color: .yellow),
            .init(label: loc("disk.movies"), bytes: movies, color: .pink),
            .init(label: loc("disk.audio"), bytes: audio, color: .blue),
            .init(label: loc("disk.systemData"), bytes: systemData, color: .gray),
        ].filter { $0.bytes > 0 }
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
