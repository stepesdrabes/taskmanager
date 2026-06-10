import SwiftUI

struct NetworkView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc
    @State private var selectedID: String?

    var body: some View {
        SectionScrollView(
            title: loc("section.network"),
            subtitle: selected.map { loc("network.adapterName", ["name": $0.displayName, "id": $0.id]) } ?? ""
        ) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    legendDot(color: .blue, label: loc("network.receive"))
                    legendDot(color: .orange, label: loc("network.send"))
                    Spacer()
                    if activeInterfaces.count > 1 {
                        Picker(loc("network.interface"), selection: pickerBinding) {
                            ForEach(activeInterfaces) { interface in
                                Text(loc("network.adapterName", ["name": interface.displayName, "id": interface.id])).tag(interface.id)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                HistoryChart(
                    series: [
                        .init(label: loc("network.receive"), color: .blue, values: series(\.rxPerSec)),
                        .init(label: loc("network.send"), color: .orange, values: series(\.txPerSec)),
                    ],
                    capacity: store.history.capacity,
                    yLabel: { Format.storageBytesPerSecond($0) }
                )
                .frame(height: 240)
            }

            if let interface = selected {
                StatGrid(items: items(for: interface))
            }
        }
    }

    /// Adapters worth listing: the primary one, anything with an address, or
    /// anything that has moved bytes since sampling started.
    private var activeInterfaces: [InterfaceSnapshot] {
        let all = store.latest?.interfaces ?? []
        let active = all.filter {
            $0.isPrimary || !$0.ipv4.isEmpty || !$0.ipv6.isEmpty || $0.totalRx + $0.totalTx > 0
        }
        return active.isEmpty ? all : active
    }

    private var selected: InterfaceSnapshot? {
        activeInterfaces.first { $0.id == selectedID } ?? activeInterfaces.first
    }

    private var pickerBinding: Binding<String> {
        Binding(
            get: { selected?.id ?? "" },
            set: { selectedID = $0 }
        )
    }

    private func series(_ keyPath: KeyPath<InterfaceSnapshot, Double>) -> [Double] {
        guard let id = selected?.id else { return [] }
        return store.history.elements.map { snapshot in
            snapshot.interfaces.first { $0.id == id }.map { $0[keyPath: keyPath] } ?? 0
        }
    }

    private func items(for interface: InterfaceSnapshot) -> [StatGrid.Item] {
        [
            .init(label: loc("network.receive"), value: Format.storageBytesPerSecond(interface.rxPerSec)),
            .init(label: loc("network.send"), value: Format.storageBytesPerSecond(interface.txPerSec)),
            .init(label: loc("network.receivedSession"), value: Format.storageBytes(interface.totalRx)),
            .init(label: loc("network.sentSession"), value: Format.storageBytes(interface.totalTx)),
            .init(label: loc("network.adapter"), value: loc("network.adapterName", ["name": interface.displayName, "id": interface.id])),
            .init(label: loc("network.ipv4"), value: interface.ipv4.isEmpty ? loc("common.unavailable") : interface.ipv4.joined(separator: ", ")),
            .init(label: loc("network.ipv6"), value: interface.ipv6.first ?? loc("common.unavailable")),
        ]
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
}
