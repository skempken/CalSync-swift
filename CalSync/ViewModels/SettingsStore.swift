import Foundation
import SwiftUI

/// Persisted settings using UserDefaults.
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedCalendarIDs = "selectedCalendarIDs"
        static let placeholderTitle = "placeholderTitle"
        static let syncIntervalMinutes = "syncIntervalMinutes"
        static let syncDaysAhead = "syncDaysAhead"
        static let launchAtLogin = "launchAtLogin"
    }

    /// Selected calendar IDs for sync.
    @Published var selectedCalendarIDs: [String] {
        didSet {
            defaults.set(selectedCalendarIDs, forKey: Keys.selectedCalendarIDs)
        }
    }

    /// Placeholder event title.
    @Published var placeholderTitle: String {
        didSet {
            defaults.set(placeholderTitle, forKey: Keys.placeholderTitle)
        }
    }

    /// Sync interval in minutes (0 = manual only).
    @Published var syncIntervalMinutes: Int {
        didSet {
            defaults.set(syncIntervalMinutes, forKey: Keys.syncIntervalMinutes)
        }
    }

    /// Days to sync ahead.
    @Published var syncDaysAhead: Int {
        didSet {
            defaults.set(syncDaysAhead, forKey: Keys.syncDaysAhead)
        }
    }

    /// Launch at login preference.
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    /// Check if app is properly configured (at least 2 calendars).
    var isConfigured: Bool {
        selectedCalendarIDs.count >= 2
    }

    init() {
        self.selectedCalendarIDs = defaults.stringArray(forKey: Keys.selectedCalendarIDs) ?? []
        self.placeholderTitle = defaults.string(forKey: Keys.placeholderTitle) ?? "Nicht verfügbar"
        self.syncIntervalMinutes = defaults.object(forKey: Keys.syncIntervalMinutes) as? Int ?? 15
        self.syncDaysAhead = defaults.object(forKey: Keys.syncDaysAhead) as? Int ?? 30
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    /// Toggle a calendar selection.
    func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.removeAll { $0 == id }
        } else {
            selectedCalendarIDs.append(id)
        }
    }

    /// Check if a calendar is selected.
    func isCalendarSelected(_ id: String) -> Bool {
        selectedCalendarIDs.contains(id)
    }

    /// Remove calendar IDs that no longer exist in EventKit.
    func cleanupOrphanedCalendars(availableIDs: Set<String>) {
        let orphaned = selectedCalendarIDs.filter { !availableIDs.contains($0) }
        if !orphaned.isEmpty {
            selectedCalendarIDs.removeAll { !availableIDs.contains($0) }
        }
    }
}

/// Available sync interval options.
enum SyncInterval: Int, CaseIterable, Identifiable {
    case minutes5 = 5
    case minutes15 = 15
    case minutes30 = 30
    case hour1 = 60
    case hours2 = 120
    case manual = 0

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .minutes5: return "Alle 5 Minuten"
        case .minutes15: return "Alle 15 Minuten"
        case .minutes30: return "Alle 30 Minuten"
        case .hour1: return "Jede Stunde"
        case .hours2: return "Alle 2 Stunden"
        case .manual: return "Nur manuell"
        }
    }
}
