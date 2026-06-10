import SwiftUI

struct ContentView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc

    private var selection: MonitorSection? { store.selectedSection }

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            List(MonitorSection.metrics, selection: $store.selectedSection) { section in
                Label {
                    Text(loc(section.titleKey))
                } icon: {
                    SidebarIcon(section: section)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                settingsRow
            }
        } detail: {
            detailView
        }
    }

    /// Settings pinned at the bottom of the sidebar, styled like a row.
    private var settingsRow: some View {
        Button {
            store.selectedSection = .settings
        } label: {
            Label {
                Text(loc(MonitorSection.settings.titleKey))
            } icon: {
                SidebarIcon(section: .settings)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selection == .settings ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .cpu {
        case .cpu:
            CPUView()
        case .memory:
            MemoryView()
        case .gpu:
            GPUView()
        case .disk:
            DiskView()
        case .network:
            NetworkView()
        case .energy:
            EnergyView()
        case .processes:
            ProcessesView()
        case .systemInfo:
            SystemInfoView()
        case .settings:
            SettingsView()
        }
    }
}
