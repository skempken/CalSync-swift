import SwiftUI

/// Main settings window with tabs.
struct SettingsWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Allgemein", systemImage: "gear")
                }

            CalendarsSettingsView()
                .tabItem {
                    Label("Kalender", systemImage: "calendar")
                }

            AboutView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
        }
        .environmentObject(appState.settingsStore)
        .frame(width: 480, height: 320)
    }
}

#Preview {
    SettingsWindow()
        .environmentObject(AppState())
}
