import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CalSync", category: "BackgroundSync")

/// Manages automatic background synchronization.
@MainActor
final class BackgroundSyncService: ObservableObject {
    private var timer: Timer?
    private let syncEngine: SyncEngine
    private let settingsStore: SettingsStore

    @Published private(set) var isRunning = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var nextSyncTime: Date?
    @Published private(set) var lastSyncResult: SyncSummary?
    @Published private(set) var isSyncing = false

    /// Callback for sync completion
    var onSyncComplete: ((SyncSummary) -> Void)?

    init(syncEngine: SyncEngine, settingsStore: SettingsStore) {
        self.syncEngine = syncEngine
        self.settingsStore = settingsStore
    }

    /// Start the background sync timer.
    func start() {
        stop() // Ensure no duplicate timers

        let intervalMinutes = settingsStore.syncIntervalMinutes
        guard intervalMinutes > 0 else {
            logger.info("Auto-sync disabled (interval = 0)")
            return
        }

        let interval = TimeInterval(intervalMinutes * 60)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSync()
            }
        }

        isRunning = true
        updateNextSyncTime()
        logger.info("Background sync started with interval: \(intervalMinutes) minutes")

        // Run immediately on start
        Task {
            await performSync()
        }
    }

    /// Stop the background sync timer.
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        nextSyncTime = nil
        logger.info("Background sync stopped")
    }

    /// Reschedule the timer with current settings.
    func reschedule() {
        if isRunning || settingsStore.syncIntervalMinutes > 0 {
            start()
        }
    }

    /// Perform a sync operation.
    func performSync() async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }

        guard settingsStore.selectedCalendarIDs.count >= 2 else {
            logger.warning("Not enough calendars configured for sync")
            return
        }

        isSyncing = true
        logger.info("Starting sync...")

        // Update placeholder title from settings
        syncEngine.placeholderTitle = settingsStore.placeholderTitle

        // Calculate date range
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(
            byAdding: .day,
            value: settingsStore.syncDaysAhead,
            to: startDate
        )

        let result = await syncEngine.sync(
            calendarIDs: settingsStore.selectedCalendarIDs,
            startDate: startDate,
            endDate: endDate,
            dryRun: false
        )

        lastSyncTime = Date()
        lastSyncResult = result
        isSyncing = false
        updateNextSyncTime()

        logger.info("Sync completed: \(result.totalCreated) created, \(result.totalUpdated) updated, \(result.totalDeleted) deleted")

        if result.hasErrors {
            for error in result.allErrors {
                logger.error("Sync error: \(error)")
            }
        }

        onSyncComplete?(result)
    }

    /// Trigger a manual sync.
    func triggerManualSync() async {
        await performSync()
    }

    /// Update the next sync time based on current settings.
    private func updateNextSyncTime() {
        guard isRunning, settingsStore.syncIntervalMinutes > 0 else {
            nextSyncTime = nil
            return
        }

        nextSyncTime = Date().addingTimeInterval(TimeInterval(settingsStore.syncIntervalMinutes * 60))
    }
}
