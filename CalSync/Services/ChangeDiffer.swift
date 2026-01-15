import Foundation

/// EventKit participant status constants
enum ParticipantStatus: Int {
    case pending = 1
    case accepted = 2
    case declined = 3
    case tentative = 4
}

/// EventKit availability constants
enum EventAvailability: Int {
    case busy = 0
    case free = 1
    case tentative = 2
    case unavailable = 3  // Out of Office
}

/// Determines necessary sync actions between two calendars.
final class ChangeDiffer {
    private let tracker: EventTracker

    init(tracker: EventTracker = EventTracker()) {
        self.tracker = tracker
    }

    /// Check if an event should be synced.
    ///
    /// Excludes:
    /// - Placeholders (already synced)
    /// - Pending events (not yet responded)
    /// - Declined events
    /// - Free events (no time blocking)
    private func shouldSyncEvent(_ event: CalendarEvent) -> Bool {
        // Skip placeholders
        if tracker.isPlaceholder(event) {
            return false
        }

        // Skip free events (availability = 1)
        if event.availability == EventAvailability.free.rawValue {
            return false
        }

        // Skip pending (1) and declined (3) events
        if let status = event.selfParticipantStatus {
            if status == ParticipantStatus.pending.rawValue {
                return false
            }
            if status == ParticipantStatus.declined.rawValue {
                return false
            }
        }

        return true
    }

    /// Compute all necessary sync actions.
    ///
    /// - Parameters:
    ///   - sourceEvents: Events from source calendar
    ///   - targetEvents: Events from target calendar (including placeholders)
    ///   - sourceCalendarID: ID of the source calendar
    /// - Returns: List of SyncActions to perform
    func computeSyncActions(
        sourceEvents: [CalendarEvent],
        targetEvents: [CalendarEvent],
        sourceCalendarID: String
    ) -> [SyncAction] {
        var actions: [SyncAction] = []

        // Filter: Only syncable events (not placeholders, not pending/declined)
        let realSourceEvents = sourceEvents.filter { shouldSyncEvent($0) }

        // Find placeholders in target calendar that originated from source
        // Use occurrence key (event_id + start_date) to handle recurring events
        var placeholders: [String: CalendarEvent] = [:]

        for event in targetEvents {
            if tracker.isPlaceholder(event) {
                if let info = tracker.extractTrackingInfo(event),
                   info.sourceCalendarID == sourceCalendarID {
                    placeholders[info.getOccurrenceKey()] = event
                }
            }
        }

        // 1. CREATE/UPDATE: Check each source event
        for source in realSourceEvents {
            let occurrenceKey = tracker.getOccurrenceKey(source)

            if let placeholder = placeholders[occurrenceKey] {
                // Placeholder exists - check if update needed
                if let info = tracker.extractTrackingInfo(placeholder) {
                    let currentHash = tracker.computeEventHash(source)

                    if info.sourceHash != currentHash {
                        actions.append(SyncAction(
                            actionType: .update,
                            sourceEvent: source,
                            targetEvent: placeholder,
                            reason: "Event changed (hash: \(info.sourceHash.prefix(8)) -> \(currentHash.prefix(8)))"
                        ))
                    }
                }
            } else {
                // New placeholder needed
                actions.append(SyncAction(
                    actionType: .create,
                    sourceEvent: source,
                    targetEvent: nil,
                    reason: "New event, creating placeholder"
                ))
            }
        }

        // 2. DELETE: Remove placeholders without source event
        let sourceKeys = Set(realSourceEvents.map { tracker.getOccurrenceKey($0) })

        for (occurrenceKey, placeholder) in placeholders {
            if !sourceKeys.contains(occurrenceKey) {
                actions.append(SyncAction(
                    actionType: .delete,
                    sourceEvent: nil,
                    targetEvent: placeholder,
                    reason: "Source event deleted, removing placeholder"
                ))
            }
        }

        return actions
    }
}
