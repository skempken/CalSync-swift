import Foundation

/// Tracking marker constants - must match Python implementation exactly!
private let trackingPrefix = "[CALSYNC:"
private let trackingSuffix = "]"

/// Information stored in placeholder notes field for tracking.
struct PlaceholderInfo: Codable, Equatable {
    /// Unique tracking ID for this placeholder
    let trackingID: String
    /// ID of the source event
    let sourceEventID: String
    /// ID of the source calendar
    let sourceCalendarID: String
    /// Hash of sync-relevant source event attributes
    let sourceHash: String
    /// ISO format start date, for recurring events
    let sourceStart: String?

    private enum CodingKeys: String, CodingKey {
        case trackingID = "tid"
        case sourceEventID = "src"
        case sourceCalendarID = "scal"
        case sourceHash = "hash"
        case sourceStart = "sstart"
    }

    /// Generate a new tracking ID (8 characters from UUID).
    static func generateTrackingID() -> String {
        String(UUID().uuidString.prefix(8))
    }

    /// Get unique key for this occurrence (handles recurring events).
    func getOccurrenceKey() -> String {
        if let start = sourceStart {
            return "\(sourceEventID)_\(start)"
        }
        return sourceEventID
    }

    /// Create the tracking marker for the notes field.
    /// Format: [CALSYNC:{"tid":"...","src":"...","scal":"...","hash":"...","sstart":"..."}]
    func toNotesMarker() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        guard let jsonData = try? encoder.encode(self),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }

        return "\(trackingPrefix)\(jsonString)\(trackingSuffix)"
    }

    /// Extract tracking info from notes field.
    static func fromNotes(_ notes: String?) -> PlaceholderInfo? {
        guard let notes = notes,
              let startIndex = notes.range(of: trackingPrefix)?.upperBound,
              let endIndex = notes.range(of: trackingSuffix, range: startIndex..<notes.endIndex)?.lowerBound else {
            return nil
        }

        let jsonString = String(notes[startIndex..<endIndex])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(PlaceholderInfo.self, from: jsonData)
    }

    /// Check if a notes field contains a CalSync tracking marker.
    static func containsMarker(in notes: String?) -> Bool {
        guard let notes = notes else { return false }
        return notes.contains(trackingPrefix)
    }
}
