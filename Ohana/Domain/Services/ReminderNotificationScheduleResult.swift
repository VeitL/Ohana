import Foundation

enum ReminderNotificationScheduleResult: Equatable {
    case scheduled
    case deferred(String)
    case skippedDuplicate
    case skippedPastDue
    case missingEvent
    case skippedBudget(String)
    case skippedMerged(String)
    case skippedUserDisabled(String)
    case failed(String)

    var ledgerActionType: String {
        switch self {
        case .scheduled: "scheduleSuccess"
        case .deferred: "scheduleDeferred"
        case .skippedDuplicate: "scheduleDuplicate"
        case .skippedPastDue: "scheduleSkippedPastDue"
        case .missingEvent: "scheduleMissingEvent"
        case .skippedBudget: "scheduleSkippedBudget"
        case .skippedMerged: "scheduleMerged"
        case .skippedUserDisabled: "scheduleUserDisabled"
        case .failed: "scheduleFailed"
        }
    }

    var metadataJSON: String {
        switch self {
        case let .deferred(metadata),
             let .skippedBudget(metadata),
             let .skippedMerged(metadata),
             let .skippedUserDisabled(metadata):
            metadata
        case let .failed(message):
            "{\"error\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        default:
            ""
        }
    }

    var didRegisterNotification: Bool {
        switch self {
        case .scheduled, .deferred:
            true
        default:
            false
        }
    }
}
