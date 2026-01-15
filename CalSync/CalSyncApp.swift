import SwiftUI

@main
struct CalSyncApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(appState.settingsStore)
        } label: {
            Label("CalSync", systemImage: appState.syncState.iconName)
        }
        .menuBarExtraStyle(.menu)

        // Settings Window
        Settings {
            SettingsWindow()
                .environmentObject(appState)
                .environmentObject(appState.settingsStore)
        }
    }

    init() {
        // Note: Auto-sync will be started after calendar access is granted
        // This happens in the CalendarsSettingsView when access is first requested
    }
}
