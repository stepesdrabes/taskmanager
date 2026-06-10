import SwiftUI

struct SettingsView: View {
    @AppStorage("updateInterval") private var updateInterval = 1.0

    var body: some View {
        Form {
            Picker("Update interval", selection: $updateInterval) {
                Text("0.5 seconds").tag(0.5)
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
            }
            Text("History window: 120 samples")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 320)
    }
}
