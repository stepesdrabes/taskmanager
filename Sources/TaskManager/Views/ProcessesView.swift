import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProcessesView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc
    @State private var sortOrder = [KeyPathComparator(\ProcessRow.cpu, order: .reverse)]
    @State private var selection: ProcessRow.ID?
    @State private var searchText = ""
    @State private var signalFailed = false

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(loc("processes.name"), value: \.name) { row in
                HStack(spacing: 6) {
                    Image(nsImage: ProcessIconCache.shared.icon(for: row))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(row.name)
                }
            }
            TableColumn(loc("processes.pid"), value: \.id) { row in
                Text(verbatim: "\(row.id)")
                    .monospacedDigit()
            }
            .width(min: 50, ideal: 60, max: 80)
            TableColumn(loc("processes.cpu"), value: \.cpu) { row in
                Text(String(format: "%.1f", row.cpu * 100))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 70, max: 90)
            TableColumn(loc("processes.memory"), value: \.memory) { row in
                Text(Format.bytes(row.memory))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
            TableColumn(loc("processes.disk"), value: \.diskPerSec) { row in
                Text(row.diskPerSec > 0 ? Format.storageBytesPerSecond(row.diskPerSec) : loc("common.unavailable"))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 100, max: 130)
        }
        .searchable(text: $searchText, prompt: Text(loc("processes.search")))
        .navigationTitle(loc("section.processes"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(loc("processes.endTask"), systemImage: "xmark.circle") {
                    signalSelected(SIGTERM)
                }
                .disabled(selection == nil)
                .help(loc("processes.endTaskHelp"))
            }

            ToolbarItem(placement: .primaryAction) {
                Button(loc("processes.forceKill"), systemImage: "bolt.circle") {
                    signalSelected(SIGKILL)
                }
                .disabled(selection == nil)
                .help(loc("processes.forceKillHelp"))
            }
        }
        .alert(loc("processes.notPermitted"), isPresented: $signalFailed) {
            Button(loc("processes.ok"), role: .cancel) {}
        } message: {
            Text(loc("processes.cantTerminate"))
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

/// Row icons resolved once per pid and cached — the lookups (NSRunningApplication,
/// NSWorkspace.icon) are far too expensive to run for every visible row on each
/// 2 s refresh. Running apps report their own icon; everything else falls back to
/// the executable's file icon (shared across pids of the same binary).
@MainActor
private final class ProcessIconCache {
    static let shared = ProcessIconCache()
    private var byPID: [pid_t: NSImage] = [:]
    private var byPath: [String: NSImage] = [:]
    private lazy var generic = NSWorkspace.shared.icon(for: .unixExecutable)

    func icon(for row: ProcessRow) -> NSImage {
        if let cached = byPID[row.id] { return cached }
        if byPID.count > 4096 { byPID.removeAll(keepingCapacity: true) }
        let resolved = resolve(row)
        byPID[row.id] = resolved
        return resolved
    }

    private func resolve(_ row: ProcessRow) -> NSImage {
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
