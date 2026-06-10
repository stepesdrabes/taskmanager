import AppKit
import Combine
import SwiftUI

@main
struct TaskManagerApp: App {
    @State private var store = MetricsStore()

    init() {
        // Unbundled binaries (swift run) can't take focus or own the menu bar
        // without this; harmless inside the .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate()
    }

    var body: some Scene {
        WindowGroup("Task Manager") {
            LiveDebugView()
                .environment(store)
                .frame(minWidth: 760, minHeight: 480)
                .task { store.start() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeOcclusionStateNotification)) { _ in
                    // Occlusion is the reliable window-visibility signal on macOS
                    // (scenePhase is not); sampling while hidden is wasted work.
                    if NSApp.occlusionState.contains(.visible) {
                        store.start()
                    } else {
                        store.stop()
                    }
                }
        }
    }
}

// Temporary proof of live sampling until the section views land.
private struct LiveDebugView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cpu = store.latest?.cpu {
                Text("CPU \(Format.percent(cpu.totalBusy))")
                    .font(.title2)
                Text(cpu.coreBusy.map(Format.percent).joined(separator: "  "))
                Text("\(cpu.processCount) processes · \(cpu.threadCount) threads")
                Text(String(format: "load %.2f / %.2f / %.2f", cpu.load1, cpu.load5, cpu.load15))
                Text("up \(Format.uptime(since: store.system.bootTime)) · \(store.system.chipName)")
            } else {
                Text("Sampling…")
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
