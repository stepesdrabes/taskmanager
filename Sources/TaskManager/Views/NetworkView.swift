import SwiftUI

struct NetworkView: View {
    @Environment(MetricsStore.self) private var store
    @State private var selectedID: String?

    var body: some View {
        SectionScrollView(
            title: "Network",
            subtitle: selected.map { "\($0.displayName) (\($0.id))" } ?? ""
        ) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    legendDot(color: .blue, label: "Receive")
                    legendDot(color: .orange, label: "Send")
                    Spacer()
                    if activeInterfaces.count > 1 {
                        Picker("Interface", selection: pickerBinding) {
                            ForEach(activeInterfaces) { interface in
                                Text("\(interface.displayName) (\(interface.id))").tag(interface.id)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                HistoryChart(
                    series: [
                        .init(label: "Receive", color: .blue, values: series(\.rxPerSec)),
                        .init(label: "Send", color: .orange, values: series(\.txPerSec)),
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
            .init(label: "Receive", value: Format.storageBytesPerSecond(interface.rxPerSec)),
            .init(label: "Send", value: Format.storageBytesPerSecond(interface.txPerSec)),
            .init(label: "Received (session)", value: Format.storageBytes(interface.totalRx)),
            .init(label: "Sent (session)", value: Format.storageBytes(interface.totalTx)),
            .init(label: "Adapter", value: "\(interface.displayName) (\(interface.id))"),
            .init(label: "IPv4", value: interface.ipv4.isEmpty ? "—" : interface.ipv4.joined(separator: ", ")),
            .init(label: "IPv6", value: interface.ipv6.first ?? "—"),
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
