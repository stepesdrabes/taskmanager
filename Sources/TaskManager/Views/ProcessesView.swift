import SwiftUI

struct ProcessesView: View {
    @Environment(MetricsStore.self) private var store
    @State private var sortOrder = [KeyPathComparator(\ProcessRow.cpu, order: .reverse)]
    @State private var selection: ProcessRow.ID?
    @State private var endTaskFailed = false

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("PID", value: \.id) { row in
                Text(verbatim: "\(row.id)")
                    .monospacedDigit()
            }
            .width(min: 50, ideal: 60, max: 80)
            TableColumn("CPU %", value: \.cpu) { row in
                Text(String(format: "%.1f", row.cpu * 100))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 70, max: 90)
            TableColumn("Memory", value: \.memory) { row in
                Text(Format.bytes(row.memory))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
        }
        .toolbar {
            Button("End Task", systemImage: "xmark.circle") {
                endSelectedTask()
            }
            .disabled(selection == nil)
        }
        .alert("Not permitted", isPresented: $endTaskFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This process can't be terminated by the current user.")
        }
        .onAppear { store.startProcessSampling() }
        .onDisappear { store.stopProcessSampling() }
    }

    private var rows: [ProcessRow] {
        store.processes.sorted(using: sortOrder)
    }

    private func endSelectedTask() {
        guard let pid = selection else { return }
        if kill(pid, SIGTERM) != 0 {
            endTaskFailed = true
        }
    }
}
