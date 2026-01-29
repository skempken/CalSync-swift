import SwiftUI

/// Calendar selection settings view.
struct CalendarsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var isRequestingAccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wähle die zu synchronisierenden Kalender:")
                .font(.headline)

            if !appState.isAuthorized {
                // Permission not granted
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Kalenderzugriff erforderlich")
                        .font(.headline)

                    Text("CalSync benötigt Zugriff auf deine Kalender, um Platzhalter-Termine zu synchronisieren.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Zugriff erlauben") {
                        isRequestingAccess = true
                        Task {
                            _ = await appState.requestCalendarAccess()
                            isRequestingAccess = false
                        }
                    }
                    .disabled(isRequestingAccess)

                    if appState.eventKitService.permissionState == .denied {
                        Text("Bitte aktiviere den Zugriff in Systemeinstellungen > Datenschutz & Sicherheit > Kalender")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Systemeinstellungen öffnen") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Calendar list
                let calendars = appState.writableCalendars

                if calendars.isEmpty {
                    Text("Keine beschreibbaren Kalender gefunden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(calendars) { calendar in
                            CalendarRow(
                                calendar: calendar,
                                isSelected: settingsStore.isCalendarSelected(calendar.id)
                            ) {
                                settingsStore.toggleCalendar(calendar.id)
                            }
                        }
                    }
                    .listStyle(.inset)

                    // Validation message
                    if settingsStore.selectedCalendarIDs.count < 2 {
                        Label("Mindestens 2 Kalender auswählen", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Label("\(settingsStore.selectedCalendarIDs.count) Kalender ausgewählt", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .task {
            // Request access on appear if not determined
            if appState.eventKitService.permissionState == .notDetermined {
                _ = await appState.requestCalendarAccess()
            }
        }
        .onAppear {
            // Remove calendar IDs that no longer exist in EventKit
            let availableIDs = Set(appState.writableCalendars.map(\.id))
            settingsStore.cleanupOrphanedCalendars(availableIDs: availableIDs)
        }
    }
}

/// Row for a single calendar in the list.
struct CalendarRow: View {
    let calendar: CalendarInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            )) {
                HStack {
                    // Color indicator
                    if let color = calendar.color {
                        Circle()
                            .fill(Color(cgColor: color))
                            .frame(width: 12, height: 12)
                    }

                    VStack(alignment: .leading) {
                        Text(calendar.title)
                            .fontWeight(.medium)

                        if let source = calendar.source {
                            Text(source)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toggleStyle(.checkbox)
        }
    }
}

#Preview {
    CalendarsSettingsView()
        .environmentObject(AppState())
        .environmentObject(SettingsStore())
}
