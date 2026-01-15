import SwiftUI

/// Main menu bar menu content.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsStore: SettingsStore

    private var lastSyncText: String {
        if let lastSync = appState.backgroundSyncService.lastSyncTime {
            return "Letzte Sync: \(lastSync.formatted(date: .omitted, time: .shortened))"
        }
        return "Noch nicht synchronisiert"
    }

    private var nextSyncText: String? {
        guard settingsStore.syncIntervalMinutes > 0,
              let nextSync = appState.backgroundSyncService.nextSyncTime else {
            return nil
        }
        return "Nächste Sync: \(nextSync.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        Group {
            // Sync Now Button
            Button {
                Task {
                    await appState.syncNow()
                }
            } label: {
                Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(appState.syncState == .syncing || !settingsStore.isConfigured)

            Divider()

            // Status Info
            Text(lastSyncText)
                .foregroundStyle(.secondary)

            if let nextSync = nextSyncText {
                Text(nextSync)
                    .foregroundStyle(.secondary)
            }

            // Last Sync Result
            if let result = appState.lastSyncResult {
                if result.totalActions > 0 {
                    Text("\(result.totalCreated) erstellt, \(result.totalUpdated) aktualisiert, \(result.totalDeleted) gelöscht")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            // Error Display
            if let error = appState.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            // Auto-Sync Toggle
            Toggle(isOn: Binding(
                get: { appState.backgroundSyncService.isRunning },
                set: { newValue in
                    if newValue {
                        appState.startAutoSync()
                    } else {
                        appState.stopAutoSync()
                    }
                }
            )) {
                if settingsStore.syncIntervalMinutes > 0 {
                    let interval = SyncInterval(rawValue: settingsStore.syncIntervalMinutes)
                    Text("Auto-Sync (\(interval?.displayName ?? ""))")
                } else {
                    Text("Auto-Sync")
                }
            }
            .disabled(!settingsStore.isConfigured)

            Divider()

            // Calendar Info
            if settingsStore.isConfigured {
                Text("\(settingsStore.selectedCalendarIDs.count) Kalender konfiguriert")
                    .foregroundStyle(.secondary)
            } else {
                Text("Keine Kalender konfiguriert")
                    .foregroundStyle(.orange)
            }

            Divider()

            // Settings
            SettingsLink {
                Label("Einstellungen...", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button("Beenden") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
