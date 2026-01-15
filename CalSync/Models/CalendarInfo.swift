import Foundation
import EventKit

/// Metadata about a calendar.
struct CalendarInfo: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let source: String?
    let isWritable: Bool
    let color: CGColor?

    /// Initialize from an EKCalendar.
    init(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.source = calendar.source?.title
        self.isWritable = calendar.allowsContentModifications
        self.color = calendar.cgColor
    }

    /// Manual initializer for testing.
    init(id: String, title: String, source: String? = nil, isWritable: Bool = true, color: CGColor? = nil) {
        self.id = id
        self.title = title
        self.source = source
        self.isWritable = isWritable
        self.color = color
    }
}
