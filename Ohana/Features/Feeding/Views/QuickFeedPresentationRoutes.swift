//
//  QuickFeedPresentationRoutes.swift
//  Ohana
//
//  Typed presentation routes for the feeding detail flow.
//

import SwiftUI

enum QuickFeedAlertRoute: Identifiable {
    case antiRepeat(id: UUID = UUID(), title: String, message: String)
    case deleteFeedLog(PetCareLog)
    case deleteFoodRecord(PetFoodRecord)

    var id: String {
        switch self {
        case let .antiRepeat(id, _, _):
            return "anti-repeat-\(id.uuidString)"
        case let .deleteFeedLog(log):
            return "delete-feed-log-\(log.id.uuidString)"
        case let .deleteFoodRecord(record):
            return "delete-food-record-\(record.id.uuidString)"
        }
    }

    var isAntiRepeat: Bool {
        if case .antiRepeat = self { return true }
        return false
    }

    var antiRepeatText: (title: String, message: String)? {
        guard case let .antiRepeat(_, title, message) = self else { return nil }
        return (title, message)
    }

    var feedLogPendingDelete: PetCareLog? {
        guard case let .deleteFeedLog(log) = self else { return nil }
        return log
    }

    var foodRecordPendingDelete: PetFoodRecord? {
        guard case let .deleteFoodRecord(record) = self else { return nil }
        return record
    }
}

enum QuickFeedOverlayRoute: Identifiable {
    case toast(id: UUID = UUID(), message: String, tint: Color)
    case treatCelebration(id: UUID = UUID(), tint: Color)

    var id: UUID {
        switch self {
        case let .toast(id, _, _):
            return id
        case let .treatCelebration(id, _):
            return id
        }
    }
}
