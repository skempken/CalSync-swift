import Foundation

/// Type of sync action.
enum ChangeType: String {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case noop = "noop"
}

/// Describes a sync action to perform.
struct SyncAction {
    let actionType: ChangeType
    let sourceEvent: CalendarEvent?
    let targetEvent: CalendarEvent?
    let reason: String
}

/// Result of a sync operation for one direction.
struct SyncResult {
    var sourceID: String = ""
    var targetID: String = ""
    var created: Int = 0
    var updated: Int = 0
    var deleted: Int = 0
    var errors: [String] = []

    var totalActions: Int {
        created + updated + deleted
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }
}

/// Summary of all sync operations.
struct SyncSummary {
    var results: [SyncResult] = []
    var startTime: Date = Date()
    var endTime: Date = Date()

    var totalCreated: Int {
        results.reduce(0) { $0 + $1.created }
    }

    var totalUpdated: Int {
        results.reduce(0) { $0 + $1.updated }
    }

    var totalDeleted: Int {
        results.reduce(0) { $0 + $1.deleted }
    }

    var totalActions: Int {
        totalCreated + totalUpdated + totalDeleted
    }

    var allErrors: [String] {
        results.flatMap { $0.errors }
    }

    var hasErrors: Bool {
        !allErrors.isEmpty
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
