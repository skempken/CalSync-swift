import Foundation
import CryptoKit

/// Manages tracking IDs and event hashing for sync detection.
struct EventTracker {

    /// Compute a hash based on sync-relevant attributes.
    /// Used to detect changes in source events.
    /// Must match Python implementation exactly for compatibility!
    func computeEventHash(_ event: CalendarEvent) -> String {
        // Create data structure matching Python implementation
        let data: [String: Any] = [
            "start": ISO8601DateFormatter().string(from: event.startDate),
            "end": ISO8601DateFormatter().string(from: event.endDate),
            "all_day": event.isAllDay,
            "participant_status": event.selfParticipantStatus as Any,
            "availability": event.availability as Any
        ]

        // Sort keys and create JSON string (matching Python's sort_keys=True)
        let sortedKeys = ["all_day", "availability", "end", "participant_status", "start"]
        var jsonParts: [String] = []

        for key in sortedKeys {
            let value = data[key]
            let valueString: String

            switch value {
            case let bool as Bool:
                valueString = bool ? "true" : "false"
            case let int as Int:
                valueString = "\(int)"
            case let string as String:
                valueString = "\"\(string)\""
            case is NSNull, nil:
                valueString = "null"
            default:
                if let optionalValue = value as Any? {
                    if case Optional<Any>.none = optionalValue {
                        valueString = "null"
                    } else {
                        valueString = "null"
                    }
                } else {
                    valueString = "null"
                }
            }

            jsonParts.append("\"\(key)\": \(valueString)")
        }

        let jsonString = "{\(jsonParts.joined(separator: ", "))}"

        // Compute SHA256 hash and take first 16 characters
        let inputData = Data(jsonString.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.map { String(format: "%02x", $0) }.joined()

        return String(hashString.prefix(16))
    }

    /// Check if an event is a sync placeholder.
    func isPlaceholder(_ event: CalendarEvent) -> Bool {
        PlaceholderInfo.containsMarker(in: event.notes)
    }

    /// Extract tracking info from a placeholder event.
    func extractTrackingInfo(_ event: CalendarEvent) -> PlaceholderInfo? {
        PlaceholderInfo.fromNotes(event.notes)
    }

    /// Get unique key for an event occurrence (handles recurring events).
    func getOccurrenceKey(_ event: CalendarEvent) -> String {
        let isoFormatter = ISO8601DateFormatter()
        return "\(event.id)_\(isoFormatter.string(from: event.startDate))"
    }

    /// Create notes content for a placeholder.
    func createPlaceholderNotes(
        trackingID: String,
        sourceEventID: String,
        sourceCalendarID: String,
        sourceHash: String,
        sourceStart: String
    ) -> String {
        let info = PlaceholderInfo(
            trackingID: trackingID,
            sourceEventID: sourceEventID,
            sourceCalendarID: sourceCalendarID,
            sourceHash: sourceHash,
            sourceStart: sourceStart
        )
        return info.toNotesMarker()
    }
}
