//
//  HomePetQuickActionCommand.swift
//  Ohana
//
//  Typed command input and UI handoff actions for Home pet quick care.
//

import Foundation

nonisolated enum HomePetQuickActionKind: String, Sendable {
    case feed
    case water
    case walk
    case litter
    case play
    case medication
    case waterChange
    case filterClean
    case cageCleaning
    case freeFlight
    case misting
    case substrateChange

    var needsEvents: Bool {
        switch self {
        case .feed, .water, .medication:
            true
        default:
            false
        }
    }

    var needsFoodRecords: Bool {
        self == .feed
    }

    var needsHumans: Bool {
        self == .feed
    }
}

struct HomePetQuickActionRequest {
    let action: HomePetQuickActionKind
    let petID: UUID
    let executorID: String?
    let now: Date
}

struct HomePetQuickActionActions {
    let antiRepeatTitle: String
    let antiRepeatMessage: ((executorName: String, minutesAgo: Int)) -> String
    let openFeedDetail: (_ petID: UUID, _ opensManualSheet: Bool) -> Void
    let showAntiRepeat: (_ title: String, _ message: String, _ pendingAction: @escaping () -> Void) -> Void
    let startWalk: (UUID) -> Void
    let openWaterManagement: (UUID) -> Void
    let openMedication: (UUID) -> Void
    let feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
}
