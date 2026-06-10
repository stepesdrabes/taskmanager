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
            ContentView()
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
        .commands {
            CommandMenu("View") {
                ForEach(Array(MonitorSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.title) {
                        store.selectedSection = section
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
