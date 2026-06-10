import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(Localizer.self) private var loc
    @AppStorage("updateInterval") private var updateInterval = 1.0
    @AppStorage("appearance") private var appearance = AppAppearance.system
    @AppStorage("temperatureUnit") private var temperatureUnit = TemperatureUnit.celsius
    @AppStorage("floatWindow") private var floatWindow = false
    @AppStorage("defaultSection") private var defaultSection = MonitorSection.cpu.rawValue

    var body: some View {
        @Bindable var loc = loc
        Form {
            Section(loc("settings.general")) {
                Picker(loc("settings.language"), selection: $loc.preference) {
                    Text(loc("settings.systemLanguage")).tag(Localizer.systemCode)
                    Divider()
                    ForEach(loc.available) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                Picker(loc("settings.updateInterval"), selection: $updateInterval) {
                    Text(loc("settings.interval05")).tag(0.5)
                    Text(loc("settings.interval1")).tag(1.0)
                    Text(loc("settings.interval2")).tag(2.0)
                    Text(loc("settings.interval5")).tag(5.0)
                }
            }

            Section(loc("settings.appearanceSection")) {
                Picker(loc("settings.theme"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(loc(option.titleKey)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(loc("settings.behavior")) {
                Toggle(loc("settings.launchAtLogin"), isOn: launchAtLogin)
                Toggle(loc("settings.floatWindow"), isOn: $floatWindow)
                Picker(loc("settings.defaultSection"), selection: $defaultSection) {
                    ForEach(MonitorSection.metrics) { section in
                        Text(loc(section.titleKey)).tag(section.rawValue)
                    }
                }
            }

            Section(loc("settings.units")) {
                Picker(loc("settings.temperatureUnit"), selection: $temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(loc(unit.titleKey)).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Text(loc("settings.historyNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(loc("section.settings"))
    }

    /// Reflects and drives the real login-item registration.
    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            }
        )
    }
}
