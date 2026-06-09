import SwiftUI

@main
struct TaskManagerApp: App {
    init() {
        // Unbundled binaries (swift run) can't take focus or own the menu bar
        // without this; harmless inside the .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate()
    }

    var body: some Scene {
        WindowGroup("Task Manager") {
            Text("TaskManager")
                .foregroundStyle(.secondary)
                .frame(minWidth: 760, minHeight: 480)
        }
    }
}
