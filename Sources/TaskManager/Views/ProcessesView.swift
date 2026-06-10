import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProcessesView: View {
    @Environment(MetricsStore.self) private var store
    @State private var sortOrder = [KeyPathComparator(\ProcessRow.cpu, order: .reverse)]
    @State private var selection: ProcessRow.ID?
    @State private var searchText = ""
    @State private var signalFailed = false

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { row in
                HStack(spacing: 6) {
                    Image(nsImage: ProcessIconCache.shared.icon(for: row))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(row.name)
                }
            }
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
            TableColumn("Disk", value: \.diskPerSec) { row in
                Text(row.diskPerSec > 0 ? Format.storageBytesPerSecond(row.diskPerSec) : "—")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 100, max: 130)
        }
        .searchable(text: $searchText, prompt: "Search processes")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Processes")
                    .font(.headline)
            }

            ToolbarItem(placement: .primaryAction) {
                Button("End Task", systemImage: "xmark.circle") {
                    signalSelected(SIGTERM)
                }
                .disabled(selection == nil)
                .help("Ask the process to quit (SIGTERM)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Force Kill", systemImage: "bolt.circle") {
                    signalSelected(SIGKILL)
                }
                .disabled(selection == nil)
                .help("Kill the process immediately (SIGKILL)")
            }
        }
        .alert("Not permitted", isPresented: $signalFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This process can't be terminated by the current user.")
        }
        .onAppear { store.startProcessSampling() }
        .onDisappear { store.stopProcessSampling() }
    }

    private var rows: [ProcessRow] {
        let filtered = searchText.isEmpty
            ? store.processes
            : store.processes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) || "\($0.id)" == searchText
            }
        return filtered.sorted(using: sortOrder)
    }

    private func signalSelected(_ signal: Int32) {
        guard let pid = selection else { return }
        if kill(pid, signal) != 0 {
            signalFailed = true
        }
    }
}

/// Row icons: running applications report their own icon; everything else
/// falls back to the executable's file icon, cached by path.
@MainActor
private final class ProcessIconCache {
    static let shared = ProcessIconCache()
    private var byPath: [String: NSImage] = [:]
    private lazy var generic = NSWorkspace.shared.icon(for: .unixExecutable)

    func icon(for row: ProcessRow) -> NSImage {
        if let app = NSRunningApplication(processIdentifier: row.id), let icon = app.icon {
            return icon
        }
        guard let path = row.path else { return generic }
        if let cached = byPath[path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        byPath[path] = icon
        return icon
    }
}
