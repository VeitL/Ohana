//
//  QuickFeedPresentationRoutes.swift
//  Ohana
//
//  Typed presentation routes for the feeding detail flow.
//

import Combine
import SwiftUI

enum QuickFeedAlertRoute: Identifiable {
    case antiRepeat(id: UUID = UUID(), title: String, message: String)
    case deleteFeedLog(PetCareLog)
    case deleteFoodRecord(PetFoodRecord)

    var id: String {
        switch self {
        case let .antiRepeat(id, _, _):
            "anti-repeat-\(id.uuidString)"
        case let .deleteFeedLog(log):
            "delete-feed-log-\(log.id.uuidString)"
        case let .deleteFoodRecord(record):
            "delete-food-record-\(record.id.uuidString)"
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
            id
        case let .treatCelebration(id, _):
            id
        }
    }
}

@MainActor
final class QuickFeedPresentationState: ObservableObject {
    @Published var activeAlert: QuickFeedAlertRoute?
    @Published var activeOverlay: QuickFeedOverlayRoute?
    @Published var feedFeedbackToken: CheckInFeedbackToken?
    @Published var feedFeedbackMetricId: String?
    @Published var stockFeedbackToken: CheckInFeedbackToken?
    @Published var stockFeedbackKind: FeedFoodKind?
    @Published var treatFeedbackToken: CheckInFeedbackToken?
    @Published var activeEmbeddedPanel: ActiveFeedEmbeddedPanel?

    var pendingRepeatAction: (() -> Void)?
    var toastTask: Task<Void, Never>?
    var feedbackClearTask: Task<Void, Never>?

    func clearFeedback() {
        feedFeedbackToken = nil
        feedFeedbackMetricId = nil
        stockFeedbackToken = nil
        stockFeedbackKind = nil
        treatFeedbackToken = nil
    }

    func cancelTransientTasks() {
        toastTask?.cancel()
        feedbackClearTask?.cancel()
        toastTask = nil
        feedbackClearTask = nil
        pendingRepeatAction = nil
    }
}
