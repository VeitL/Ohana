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

    func recentFeedingWarning() -> (executorName: String, minutesAgo: Int)? {
        AntiRepeatCareManager.checkRecentCareLog(
            for: pet,
            type: .feeding,
            thresholdMinutes: 120,
            currentUserId: currentUserId,
            in: humans
        )
    }
}
