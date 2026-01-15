import Foundation
import SwiftUI

/// Current sync state for UI display.
enum SyncState {
    case idle           // Normal state, no recent sync
    case synced         // Successfully synced recently
    case syncing        // Currently syncing
    case error          // Last sync had errors

    var iconName: String {
        switch self {
        case .idle: return "calendar.badge.clock"
        case .synced: return "calendar.badge.checkmark"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "calendar.badge.exclamationmark"
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Bereit"
        case .synced: return "Synchronisiert"
        case .syncing: return "Synchronisiere..."
        case .error: return "Fehler"
        }
    }
}

/// Global application state.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Services
    let eventKitService: EventKitService
    let settingsStore: SettingsStore
    let syncEngine: SyncEngine
    let backgroundSyncService: BackgroundSyncService

    // MARK: - Published State
    @Published var syncState: SyncState = .idle
    @Published var lastSyncTime: Date?
    @Published var lastSyncResult: SyncSummary?
    @Published var lastError: String?

    init() {
        // Initialize services
        self.eventKitService = EventKitService()
        self.settingsStore = SettingsStore()
        self.syncEngine = SyncEngine(eventKitService: eventKitService)
        self.backgroundSyncService = BackgroundSyncService(
            syncEngine: syncEngine,
            settingsStore: settingsStore
        )

        // Set up sync completion callback
        backgroundSyncService.onSyncComplete = { [weak self] result in
            Task { @MainActor in
                self?.handleSyncComplete(result)
            }
        }
    }

    /// Request calendar access.
    func requestCalendarAccess() async -> Bool {
        do {
            return try await eventKitService.requestAccess()
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Start automatic sync if configured.
    func startAutoSync() {
        guard settingsStore.isConfigured else { return }
        backgroundSyncService.start()
    }

    /// Stop automatic sync.
    func stopAutoSync() {
        backgroundSyncService.stop()
    }

    /// Trigger a manual sync.
    func syncNow() async {
        guard settingsStore.isConfigured else {
            lastError = "Mindestens 2 Kalender müssen konfiguriert sein."
            syncState = .error
            return
        }

        syncState = .syncing
        await backgroundSyncService.performSync()
    }

    /// Handle sync completion.
    private func handleSyncComplete(_ result: SyncSummary) {
        lastSyncTime = Date()
        lastSyncResult = result

        if result.hasErrors {
            syncState = .error
            lastError = result.allErrors.first
        } else {
            syncState = .synced
            lastError = nil

            // Reset to idle after 30 seconds
            Task {
                try? await Task.sleep(for: .seconds(30))
                if syncState == .synced {
                    syncState = .idle
                }
            }
        }
    }

    /// Get available calendars.
    var availableCalendars: [CalendarInfo] {
        eventKitService.getCalendars()
    }

    /// Get writable calendars.
    var writableCalendars: [CalendarInfo] {
        eventKitService.getWritableCalendars()
    }

    /// Check if calendar access is authorized.
    var isAuthorized: Bool {
        eventKitService.isAuthorized
    }
}
