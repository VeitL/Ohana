//
//  QuickFeedRefreshRequest.swift
//  Ohana
//
//  Coalesced refresh flags for the feeding sheet's route-scoped read models.
//

import Foundation

struct QuickFeedRefreshRequest: OptionSet {
    let rawValue: Int

    static let reloadFullCareLogsIfLoaded = QuickFeedRefreshRequest(rawValue: 1 << 0)
    static let reloadFullFoodRecordsIfLoaded = QuickFeedRefreshRequest(rawValue: 1 << 1)
    static let reloadSnapshots = QuickFeedRefreshRequest(rawValue: 1 << 2)
    static let refreshFeedHomeSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 3)
    static let forceFeedHomeSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 4)
    static let refreshOverviewSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 5)
    static let forceOverviewSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 6)
    static let syncDisplayedMode = QuickFeedRefreshRequest(rawValue: 1 << 7)
    static let forceDisplayedMode = QuickFeedRefreshRequest(rawValue: 1 << 8)
    static let ensurePlanReminders = QuickFeedRefreshRequest(rawValue: 1 << 9)
    static let refreshPlanCalendarSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 10)
    static let forcePlanCalendarSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 11)
    static let refreshTreatSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 12)
    static let forceTreatSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 13)
}
