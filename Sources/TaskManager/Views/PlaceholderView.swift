import SwiftUI

/// Stand-in detail view until each section's real view lands.
struct PlaceholderView: View {
    @Environment(MetricsStore.self) private var store
    let section: MonitorSection

    var body: some View {
        VStack(spacing: 12) {
            ContentUnavailableView {
                Label(section.title, systemImage: section.symbol)
            } description: {
                Text("This section arrives in a later build step.")
            }
            if section == .cpu, let cpu = store.latest?.cpu {
                Text("Live: \(Format.percent(cpu.totalBusy)) CPU · \(cpu.processCount) processes · \(cpu.threadCount) threads")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.bottom)
            }
        }
    }
}
