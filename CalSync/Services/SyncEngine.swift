import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CalSync", category: "SyncEngine")

/// Main sync logic for multi-calendar sync.
@MainActor
final class SyncEngine: ObservableObject {
    private let eventKitService: EventKitService
    private let tracker = EventTracker()
    private let differ: ChangeDiffer

    /// Configurable placeholder title
    var placeholderTitle: String = "Nicht verfügbar"

    init(eventKitService: EventKitService) {
        self.eventKitService = eventKitService
        self.differ = ChangeDiffer(tracker: tracker)
    }

    /// Determine placeholder availability based on source event status.
    ///
    /// Priority:
    /// 1. Source Unavailable (OOO) → Placeholder Unavailable (3)
    /// 2. Source Tentative (4) → Placeholder Tentative (2)
    /// 3. Otherwise → Placeholder Busy (0)
    private func getPlaceholderAvailability(_ sourceEvent: CalendarEvent) -> Int {
        // Out of Office / Außer Haus has highest priority
        if sourceEvent.availability == EventAvailability.unavailable.rawValue {
            return EventAvailability.unavailable.rawValue
        }
        // Tentative participant status
        if sourceEvent.selfParticipantStatus == ParticipantStatus.tentative.rawValue {
            return EventAvailability.tentative.rawValue
        }
        return EventAvailability.busy.rawValue
    }

    /// Perform sync between all calendar pairs.
    ///
    /// For n calendars, syncs each calendar to all others.
    ///
    /// - Parameters:
    ///   - calendarIDs: IDs of calendars to sync
    ///   - startDate: Start of sync period (default: today)
    ///   - endDate: End of sync period (default: +30 days)
    ///   - dryRun: If true, only simulate changes
    /// - Returns: SyncSummary with results for each direction
    func sync(
        calendarIDs: [String],
        startDate: Date? = nil,
        endDate: Date? = nil,
        dryRun: Bool = false
    ) async -> SyncSummary {
        var summary = SyncSummary()
        summary.startTime = Date()

        let effectiveStartDate = startDate ?? Calendar.current.startOfDay(for: Date())
        let effectiveEndDate = endDate ?? Calendar.current.date(byAdding: .day, value: 30, to: effectiveStartDate) ?? effectiveStartDate

        logger.info("Sync period: \(effectiveStartDate) to \(effectiveEndDate)")
        logger.info("Calendars: \(calendarIDs.count)")

        // Load events from all calendars
        var eventsByCalendar: [String: [CalendarEvent]] = [:]

        for calID in calendarIDs {
            do {
                let events = try eventKitService.getEvents(
                    calendarID: calID,
                    from: effectiveStartDate,
                    to: effectiveEndDate
                )
                eventsByCalendar[calID] = events
                logger.info("Calendar \(calID.prefix(8))...: \(events.count) events")
            } catch {
                logger.error("Failed to load events from \(calID): \(error.localizedDescription)")
                var result = SyncResult()
                result.sourceID = calID
                result.errors.append("Failed to load events: \(error.localizedDescription)")
                summary.results.append(result)
            }
        }

        // Clean up placeholders from calendars no longer in the sync list
        let calendarIDSet = Set(calendarIDs)
        let orphanedResult = cleanupOrphanedPlaceholders(
            eventsByCalendar: eventsByCalendar,
            activeCalendarIDs: calendarIDSet,
            dryRun: dryRun
        )
        if orphanedResult.totalActions > 0 {
            summary.results.append(orphanedResult)

            // Refresh events after cleanup
            if !dryRun {
                for calID in calendarIDs {
                    do {
                        eventsByCalendar[calID] = try eventKitService.getEvents(
                            calendarID: calID,
                            from: effectiveStartDate,
                            to: effectiveEndDate
                        )
                    } catch {
                        logger.error("Failed to refresh events after orphan cleanup: \(error.localizedDescription)")
                    }
                }
            }
        }

        // Sync each pair (source -> target) using permutations
        let pairs = generatePermutations(calendarIDs)

        for (sourceID, targetID) in pairs {
            guard let sourceEvents = eventsByCalendar[sourceID],
                  let targetEvents = eventsByCalendar[targetID] else {
                continue
            }

            var result = syncDirection(
                sourceEvents: sourceEvents,
                targetEvents: targetEvents,
                sourceCalendarID: sourceID,
                targetCalendarID: targetID,
                dryRun: dryRun
            )
            result.sourceID = sourceID
            result.targetID = targetID
            summary.results.append(result)

            // Refresh target events if changes were made
            if !dryRun && result.totalActions > 0 {
                do {
                    eventsByCalendar[targetID] = try eventKitService.getEvents(
                        calendarID: targetID,
                        from: effectiveStartDate,
                        to: effectiveEndDate
                    )
                } catch {
                    logger.error("Failed to refresh events: \(error.localizedDescription)")
                }
            }
        }

        summary.endTime = Date()
        return summary
    }

    /// Generate all permutations of calendar pairs.
    private func generatePermutations(_ ids: [String]) -> [(String, String)] {
        var pairs: [(String, String)] = []
        for source in ids {
            for target in ids where source != target {
                pairs.append((source, target))
            }
        }
        return pairs
    }

    /// Sync in one direction.
    private func syncDirection(
        sourceEvents: [CalendarEvent],
        targetEvents: [CalendarEvent],
        sourceCalendarID: String,
        targetCalendarID: String,
        dryRun: Bool
    ) -> SyncResult {
        var result = SyncResult()

        let actions = differ.computeSyncActions(
            sourceEvents: sourceEvents,
            targetEvents: targetEvents,
            sourceCalendarID: sourceCalendarID
        )

        logger.debug("Direction \(sourceCalendarID.prefix(8))... -> \(targetCalendarID.prefix(8))...: \(actions.count) actions")

        for action in actions {
            do {
                switch action.actionType {
                case .create:
                    if !dryRun, let sourceEvent = action.sourceEvent {
                        try createPlaceholder(
                            sourceEvent: sourceEvent,
                            sourceCalendarID: sourceCalendarID,
                            targetCalendarID: targetCalendarID
                        )
                    }
                    result.created += 1
                    logger.debug("CREATE: \(action.reason)")

                case .update:
                    if !dryRun, let sourceEvent = action.sourceEvent, let placeholderEvent = action.targetEvent {
                        try updatePlaceholder(
                            sourceEvent: sourceEvent,
                            placeholderEvent: placeholderEvent,
                            sourceCalendarID: sourceCalendarID
                        )
                    }
                    result.updated += 1
                    logger.debug("UPDATE: \(action.reason)")

                case .delete:
                    if !dryRun, let targetEvent = action.targetEvent {
                        _ = try eventKitService.deleteEvent(eventID: targetEvent.id)
                    }
                    result.deleted += 1
                    logger.debug("DELETE: \(action.reason)")

                case .noop:
                    break
                }
            } catch {
                let errorMsg = "Error in \(action.actionType.rawValue): \(error.localizedDescription)"
                logger.error("\(errorMsg)")
                result.errors.append(errorMsg)
            }
        }

        return result
    }

    /// Remove placeholders whose source calendar is no longer in the active sync list.
    private func cleanupOrphanedPlaceholders(
        eventsByCalendar: [String: [CalendarEvent]],
        activeCalendarIDs: Set<String>,
        dryRun: Bool
    ) -> SyncResult {
        var result = SyncResult()
        result.sourceID = "orphan-cleanup"

        for (calID, events) in eventsByCalendar {
            result.targetID = calID
            for event in events {
                guard tracker.isPlaceholder(event),
                      let info = tracker.extractTrackingInfo(event),
                      !activeCalendarIDs.contains(info.sourceCalendarID) else {
                    continue
                }

                logger.info("Removing orphaned placeholder in \(calID.prefix(8))... (source calendar \(info.sourceCalendarID.prefix(8))... no longer active)")

                if !dryRun {
                    do {
                        _ = try eventKitService.deleteEvent(eventID: event.id)
                    } catch {
                        result.errors.append("Failed to delete orphaned placeholder: \(error.localizedDescription)")
                    }
                }
                result.deleted += 1
            }
        }

        return result
    }

    /// Create a placeholder for a source event.
    private func createPlaceholder(
        sourceEvent: CalendarEvent,
        sourceCalendarID: String,
        targetCalendarID: String
    ) throws {
        let trackingID = PlaceholderInfo.generateTrackingID()
        let sourceHash = tracker.computeEventHash(sourceEvent)
        let isoFormatter = ISO8601DateFormatter()

        let notes = tracker.createPlaceholderNotes(
            trackingID: trackingID,
            sourceEventID: sourceEvent.id,
            sourceCalendarID: sourceCalendarID,
            sourceHash: sourceHash,
            sourceStart: isoFormatter.string(from: sourceEvent.startDate)
        )

        let availability = getPlaceholderAvailability(sourceEvent)

        _ = try eventKitService.createEvent(
            calendarID: targetCalendarID,
            title: placeholderTitle,
            startDate: sourceEvent.startDate,
            endDate: sourceEvent.endDate,
            isAllDay: sourceEvent.isAllDay,
            notes: notes,
            availability: availability
        )
    }

    /// Update an existing placeholder.
    private func updatePlaceholder(
        sourceEvent: CalendarEvent,
        placeholderEvent: CalendarEvent,
        sourceCalendarID: String
    ) throws {
        guard let info = tracker.extractTrackingInfo(placeholderEvent) else {
            return
        }

        let sourceHash = tracker.computeEventHash(sourceEvent)
        let isoFormatter = ISO8601DateFormatter()

        let notes = tracker.createPlaceholderNotes(
            trackingID: info.trackingID,
            sourceEventID: sourceEvent.id,
            sourceCalendarID: sourceCalendarID,
            sourceHash: sourceHash,
            sourceStart: isoFormatter.string(from: sourceEvent.startDate)
        )

        let availability = getPlaceholderAvailability(sourceEvent)

        _ = try eventKitService.updateEvent(
            eventID: placeholderEvent.id,
            startDate: sourceEvent.startDate,
            endDate: sourceEvent.endDate,
            notes: notes,
            availability: availability
        )
    }
}
