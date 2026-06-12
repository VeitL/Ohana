//
//  QuickFeedAntiRepeatScreenModel.swift
//  Ohana
//
//  Read helper for quick-feed duplicate-care warnings.
//

import Foundation

struct QuickFeedAntiRepeatScreenModel {
    let pet: Pet
    let currentUserId: String?
    let humans: [Human]
    let feedingLedgerEvents: [CareLedgerEvent]
    let now: Date

    func recentFeedingWarning() -> (executorName: String, minutesAgo: Int)? {
        AntiRepeatCareManager.checkRecentCareLedger(
            for: pet,
            type: .feeding,
            ledgerEvents: feedingLedgerEvents,
            thresholdMinutes: 120,
            currentUserId: currentUserId,
            in: humans,
            now: now
        )
    }
}
