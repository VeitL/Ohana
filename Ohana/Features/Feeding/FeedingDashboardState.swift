//
//  FeedingDashboardState.swift
//  Ohana
//

import Foundation
import SwiftData

struct FeedingDashboardState {
    let pet: Pet
    let allEvents: [Event]
    let manualGoalCount: Int
    let careLogs: [PetCareLog]
    let foodRecords: [PetFoodRecord]?
    let sharedCareSessions: [SharedCareSession]?
    let now: Date
    let calendar: Calendar

    init(
        pet: Pet,
        allEvents: [Event],
        manualGoalCount: Int = 1,
        careLogs: [PetCareLog] = [],
        foodRecords: [PetFoodRecord]? = nil,
        sharedCareSessions: [SharedCareSession]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.pet = pet
        self.allEvents = allEvents
        self.manualGoalCount = max(1, manualGoalCount)
        self.careLogs = careLogs
        self.foodRecords = foodRecords
        self.sharedCareSessions = sharedCareSessions
        self.now = now
        self.calendar = calendar
    }

    var today: FeedTodayState {
        FeedTodayState(pet: pet, allEvents: allEvents, manualGoalCount: manualGoalCount, careLogs: careLogs, now: now, calendar: calendar)
    }

    var rules: FeedRuleState {
        FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
    }

    var stock: FeedStockSnapshot {
        FeedStockCalculator.snapshot(for: pet, events: allEvents, careLogs: careLogs, foodRecords: foodRecords, sharedCareSessions: sharedCareSessions, now: now, calendar: calendar)
    }

    func stock(foodKind: FeedFoodKind) -> FeedStockSnapshot {
        FeedStockCalculator.snapshot(for: pet, foodKind: foodKind, events: allEvents, careLogs: careLogs, foodRecords: foodRecords, sharedCareSessions: sharedCareSessions, now: now, calendar: calendar)
    }

    var manualPlanEvents: [Event] { rules.manualReminderEvents }
    var autoFeederEvents: [Event] { rules.autoFeederEvents }
    var operatingMode: FeedOperatingMode { rules.operatingMode }
    var nextManualReminder: Reminder? { today.nextPendingReminder }
    var todayMainFoodGrams: Double { today.todayMainFoodGrams }
    var todayDryFoodGrams: Double { today.mainFoodTodayLogs.filter { $0.foodKind == .dry }.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) } }
    var todayWetFoodGrams: Double { today.mainFoodTodayLogs.filter { $0.foodKind == .wet }.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) } }
    var todayTreatGrams: Double { today.todayTreatGrams }
    var recentFeedLogs: [PetCareLog] { today.allTodayLogs }
    var todayAutoFeedLogs: [PetCareLog] {
        today.mainFoodTodayLogs.filter { FeedLogMetadata.source(for: $0) == .autoMain }
    }

    var todayAutoFeedCount: Int { todayAutoFeedLogs.count }
    var todayManualPlanTotalCount: Int {
        max(today.todayPlanReminders.count, manualPlanEvents.count, 1)
    }

    var todayManualPlanCompletedCount: Int {
        min(today.completedTodayPlanReminders.count, todayManualPlanTotalCount)
    }

    var todayManualPlanMissedCount: Int {
        today.expiredMissedPlanReminders.isEmpty ? today.catchUpPlanReminders.count : 0
    }

    var hasMissedManualPlan: Bool {
        today.expiredMissedPlanReminders.isEmpty && !today.catchUpPlanReminders.isEmpty
    }

    var lastExpiredManualPlanDate: Date? {
        today.lastExpiredPlanReminderDate
    }

    var todayManualPlanCompletionText: String {
        "\(todayManualPlanCompletedCount)/\(todayManualPlanTotalCount)"
    }

    var autoDailyTotalGrams: Double {
        FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents)
    }
}
