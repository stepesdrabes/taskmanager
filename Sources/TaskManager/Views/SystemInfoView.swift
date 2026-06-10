import SwiftUI

struct SystemInfoView: View {
    @Environment(MetricsStore.self) private var store
    @State private var report: SystemReport?
    @State private var search = ""

    var body: some View {
        Group {
            if let report {
                let sections = report.filtered(by: search)
                if sections.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.rows) { row in
                                    LabeledContent(row.label) {
                                        Text(row.value)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("System Info")
        .searchable(text: $search, prompt: "Search")
        .task { report = SystemReport.gather(system: store.system) }
    }
}
