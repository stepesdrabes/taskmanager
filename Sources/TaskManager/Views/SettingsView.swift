import SwiftUI

struct SettingsView: View {
    @Environment(Localizer.self) private var loc
    @AppStorage("updateInterval") private var updateInterval = 1.0

    var body: some View {
        @Bindable var loc = loc
        SectionScrollView(title: loc("section.settings"), subtitle: "") {
            VStack(alignment: .leading, spacing: 20) {
                Picker(loc("settings.language"), selection: $loc.preference) {
                    Text(loc("settings.systemLanguage")).tag(Localizer.systemCode)
                    Divider()
                    ForEach(loc.available) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker(loc("settings.updateInterval"), selection: $updateInterval) {
                    Text(loc("settings.interval05")).tag(0.5)
                    Text(loc("settings.interval1")).tag(1.0)
                    Text(loc("settings.interval2")).tag(2.0)
                    Text(loc("settings.interval5")).tag(5.0)
                }
                .pickerStyle(.menu)
                .fixedSize()

                Text(loc("settings.historyNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
