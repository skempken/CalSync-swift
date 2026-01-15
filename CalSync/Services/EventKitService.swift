import Foundation
import EventKit

/// Errors that can occur during EventKit operations.
enum EventKitError: LocalizedError {
    case accessDenied
    case accessRestricted
    case calendarNotFound(id: String)
    case calendarReadOnly(name: String)
    case eventNotFound(id: String)
    case saveFailed(underlying: Error?)
    case deleteFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Kalenderzugriff verweigert. Bitte in Systemeinstellungen aktivieren."
        case .accessRestricted:
            return "Kalenderzugriff eingeschränkt."
        case .calendarNotFound(let id):
            return "Kalender nicht gefunden: \(id)"
        case .calendarReadOnly(let name):
            return "Kalender ist schreibgeschützt: \(name)"
        case .eventNotFound(let id):
            return "Termin nicht gefunden: \(id)"
        case .saveFailed(let error):
            return "Speichern fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")"
        case .deleteFailed(let error):
            return "Löschen fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")"
        }
    }
}

/// Calendar permission state.
enum CalendarPermissionState {
    case notDetermined
    case authorized
    case denied
    case restricted

    init(from status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .fullAccess, .writeOnly:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .denied
        }
    }
}

/// Service for interacting with EventKit (Apple Calendar).
@MainActor
final class EventKitService: ObservableObject {
    private let store = EKEventStore()

    @Published private(set) var permissionState: CalendarPermissionState = .notDetermined
    @Published private(set) var isAuthorized = false

    init() {
        updatePermissionState()
    }

    /// Update the current permission state.
    private func updatePermissionState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        permissionState = CalendarPermissionState(from: status)
        isAuthorized = permissionState == .authorized
    }

    /// Request calendar access.
    func requestAccess() async throws -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            updatePermissionState()
            return granted
        } catch {
            updatePermissionState()
            throw EventKitError.accessDenied
        }
    }

    /// Get all calendars.
    func getCalendars() -> [CalendarInfo] {
        let calendars = store.calendars(for: .event)
        return calendars.map { CalendarInfo(from: $0) }
    }

    /// Get all writable calendars.
    func getWritableCalendars() -> [CalendarInfo] {
        getCalendars().filter { $0.isWritable }
    }

    /// Get events from a calendar within a time range.
    func getEvents(calendarID: String, from startDate: Date, to endDate: Date) throws -> [CalendarEvent] {
        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            throw EventKitError.calendarNotFound(id: calendarID)
        }

        let predicate = store.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        let ekEvents = store.events(matching: predicate)
        return ekEvents.map { CalendarEvent(from: $0) }
    }

    /// Create a new event.
    func createEvent(
        calendarID: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        notes: String? = nil,
        availability: Int? = nil
    ) throws -> CalendarEvent {
        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            throw EventKitError.calendarNotFound(id: calendarID)
        }

        guard calendar.allowsContentModifications else {
            throw EventKitError.calendarReadOnly(name: calendar.title)
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = calendar
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay

        if let notes = notes {
            event.notes = notes
        }

        if let availability = availability {
            event.availability = EKEventAvailability(rawValue: availability) ?? .busy
        }

        do {
            try store.save(event, span: .thisEvent)
            return CalendarEvent(from: event)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }
    }

    /// Update an existing event.
    func updateEvent(
        eventID: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        availability: Int? = nil
    ) throws -> CalendarEvent {
        guard let event = store.event(withIdentifier: eventID) else {
            throw EventKitError.eventNotFound(id: eventID)
        }

        if let title = title {
            event.title = title
        }
        if let startDate = startDate {
            event.startDate = startDate
        }
        if let endDate = endDate {
            event.endDate = endDate
        }
        if let notes = notes {
            event.notes = notes
        }
        if let availability = availability {
            event.availability = EKEventAvailability(rawValue: availability) ?? .busy
        }

        do {
            try store.save(event, span: .thisEvent)
            return CalendarEvent(from: event)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }
    }

    /// Delete an event.
    func deleteEvent(eventID: String) throws -> Bool {
        guard let event = store.event(withIdentifier: eventID) else {
            return false
        }

        do {
            try store.remove(event, span: .thisEvent)
            return true
        } catch {
            throw EventKitError.deleteFailed(underlying: error)
        }
    }
}
