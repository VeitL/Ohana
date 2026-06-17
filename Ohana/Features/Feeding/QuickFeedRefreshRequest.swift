//
//  QuickFeedRefreshRequest.swift
//  Ohana
//
//  Coalesced refresh flags for the feeding sheet's route-scoped read models.
//

import Combine
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

@MainActor
final class QuickFeedRuntimeState: ObservableObject {
    @Published var clockTick = Date()
    @Published var overviewChartProgress: Double = 1

    var feedDetailDataTask: Task<Void, Never>?
    var didApplyInitialSheet = false
    var didScheduleBootstrapMaintenance = false
    var feedModeTransitionTask: Task<Void, Never>?
    var feedModeMaintenanceTask: Task<Void, Never>?
    var feedRefreshTask: Task<Void, Never>?
    var feedPlanSaveTask: Task<Void, Never>?
    var feedPlanReminderSchedulingTask: Task<Void, Never>?
    var feedStockReminderSchedulingTask: Task<Void, Never>?
    var pendingFeedRefreshRequest = QuickFeedRefreshRequest()
    var latestAllEventsOverride: [Event]?
    var lastFeedClockMinute = -1

    func cancelTasks() {
        feedModeTransitionTask?.cancel()
        feedModeMaintenanceTask?.cancel()
        feedDetailDataTask?.cancel()
        feedRefreshTask?.cancel()
        feedPlanSaveTask?.cancel()
        feedPlanReminderSchedulingTask?.cancel()
        feedStockReminderSchedulingTask?.cancel()

        feedModeTransitionTask = nil
        feedModeMaintenanceTask = nil
        feedDetailDataTask = nil
        feedRefreshTask = nil
        feedPlanSaveTask = nil
        feedPlanReminderSchedulingTask = nil
        feedStockReminderSchedulingTask = nil
        pendingFeedRefreshRequest = QuickFeedRefreshRequest()
        latestAllEventsOverride = nil
    }
}
