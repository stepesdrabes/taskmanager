import SwiftUI

struct ContentView: View {
    @Environment(MetricsStore.self) private var store

    private var selection: MonitorSection? { store.selectedSection }

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            List(MonitorSection.allCases, selection: $store.selectedSection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    SidebarIcon(section: section)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } detail: {
            detailView
                .navigationTitle((selection ?? .cpu).title)
        }
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
        case .processes:
            ProcessesView()
        }
    }
}
