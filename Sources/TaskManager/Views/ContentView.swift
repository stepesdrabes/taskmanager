import SwiftUI

struct ContentView: View {
    @State private var selection: MonitorSection? = .cpu

    var body: some View {
        NavigationSplitView {
            List(MonitorSection.allCases, selection: $selection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    SidebarIcon(section: section)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } detail: {
            PlaceholderView(section: selection ?? .cpu)
                .navigationTitle((selection ?? .cpu).title)
        }
    }
}
