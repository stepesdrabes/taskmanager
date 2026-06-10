import AppKit
import Combine
import SwiftUI

@main
struct TaskManagerApp: App {
    @State private var store = MetricsStore()
    @State private var localizer = Localizer()
    @AppStorage("appearance") private var appearance = AppAppearance.system
    @AppStorage("floatWindow") private var floatWindow = false
    @AppStorage("defaultSection") private var defaultSection = MonitorSection.cpu.rawValue

    init() {
        // Unbundled binaries (swift run) can't take focus or own the menu bar
        // without this; harmless inside the .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate()
    }

    private func applyWindowLevel() {
        let level: NSWindow.Level = floatWindow ? .floating : .normal
        for window in NSApp.windows { window.level = level }
    }

    var body: some Scene {
        WindowGroup("Task Manager") {
            ContentView()
                .environment(store)
                .environment(localizer)
                .frame(minWidth: 760, minHeight: 480)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    if let section = MonitorSection(rawValue: defaultSection) {
                        store.selectedSection = section
                    }
                    applyWindowLevel()
                    store.start()
                }
                .onChange(of: floatWindow) { applyWindowLevel() }
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
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(localizer("section.settings")) {
                    store.selectedSection = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(localizer("menu.view")) {
                ForEach(Array(MonitorSection.metrics.enumerated()), id: \.element) { index, section in
                    Button(localizer(section.titleKey)) {
                        store.selectedSection = section
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
    }
}
