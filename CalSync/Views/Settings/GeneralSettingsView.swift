import SwiftUI
import ServiceManagement

/// General settings view.
struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section {
                TextField("Platzhalter-Titel:", text: $settingsStore.placeholderTitle)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Platzhalter")
            }

            Section {
                Picker("Intervall:", selection: $settingsStore.syncIntervalMinutes) {
                    ForEach(SyncInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                }
                .onChange(of: settingsStore.syncIntervalMinutes) { _, _ in
                    appState.backgroundSyncService.reschedule()
                }

                Stepper("Tage voraus: \(settingsStore.syncDaysAhead)",
                        value: $settingsStore.syncDaysAhead,
                        in: 7...90)
            } header: {
                Text("Synchronisierung")
            }

            Section {
                Toggle("Bei Anmeldung starten", isOn: $settingsStore.launchAtLogin)
                    .onChange(of: settingsStore.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            } header: {
                Text("Autostart")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Set launch at login using ServiceManagement.
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

#Preview {
    GeneralSettingsView()
        .environmentObject(AppState())
        .environmentObject(SettingsStore())
}
