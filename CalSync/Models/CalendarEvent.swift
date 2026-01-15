import Foundation
import EventKit

/// Represents a calendar event with all sync-relevant attributes.
struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let calendarID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let notes: String?
    let location: String?
    /// EventKit availability: 0=Busy, 1=Free, 2=Tentative, 3=Unavailable
    let availability: Int?
    /// EventKit self participant status: 1=Pending, 2=Accepted, 3=Declined, 4=Tentative
    let selfParticipantStatus: Int?

    /// Calculate event duration in minutes.
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Initialize from an EKEvent.
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.calendarID = ekEvent.calendar?.calendarIdentifier ?? ""
        self.title = ekEvent.title ?? ""
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.notes = ekEvent.notes
        self.location = ekEvent.location
        self.availability = Int(ekEvent.availability.rawValue)

        // Get self participant status from attendees if available
        if let attendees = ekEvent.attendees {
            if let selfAttendee = attendees.first(where: { $0.isCurrentUser }) {
                self.selfParticipantStatus = Int(selfAttendee.participantStatus.rawValue)
            } else {
                self.selfParticipantStatus = nil
            }
        } else {
            self.selfParticipantStatus = nil
        }
    }

    /// Manual initializer for testing or manual creation.
    init(
        id: String,
        calendarID: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        notes: String? = nil,
        location: String? = nil,
        availability: Int? = nil,
        selfParticipantStatus: Int? = nil
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.location = location
        self.availability = availability
        self.selfParticipantStatus = selfParticipantStatus
    }
}
