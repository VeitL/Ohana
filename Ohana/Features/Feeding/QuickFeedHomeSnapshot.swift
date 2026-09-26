//
//  QuickFeedHomeSnapshot.swift
//  Ohana
//
//  Lightweight render snapshot for the feeding home surface.
//

import Foundation

nonisolated struct QuickFeedPlanRenderEvent: Equatable, Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let foodKindRaw: String
    let amountGrams: Double

    @MainActor
    init(event: Event) {
        id = event.id
        startDate = event.startDate
        recurrenceDays = event.recurrenceDays
        recurrenceEndDate = event.recurrenceEndDate
        foodKindRaw = event.foodKind.rawValue
        amountGrams = FeedRuleMetadata.amountGrams(from: event)
    }

    var foodKind: FeedFoodKind {
        FeedFoodKind(rawValue: foodKindRaw) ?? .dry
    }
}

struct QuickFeedHomeSnapshot {
    let manualPlanEvents: [QuickFeedPlanRenderEvent]
    let autoFeederEvents: [QuickFeedPlanRenderEvent]
    let todayMainFoodGrams: Double
    let todayDryFoodGrams: Double
    let todayWetFoodGrams: Double
    let todayTreatGrams: Double
    let todayTreatCount: Int
    let todayAutoFeedCount: Int
    let hasNextManualReminder: Bool
    let hasMissedManualPlan: Bool
    let todayManualPlanMissedCount: Int
    let lastExpiredManualPlanDate: Date?
    let todayManualPlanCompletionText: String
    let autoDailyTotalGrams: Double
    let latestAutoFeedDate: Date?
    let nextAutoFeedDate: Date?
    let stockCardRemainingDays: Int?
    let dryStockRemainingGrams: Double?
    let dryStockRemainingDays: Int?
    let wetStockRemainingGrams: Double?
    let wetStockRemainingDays: Int?
    let guidedSevenDayMainFoodPoints: [OhanaMinimalChartPoint]

    static func make(
        pet: Pet,
        allEvents: [Event],
        careLogs: [PetCareLog],
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession] = [],
        now: Date,
        todayLabel: String,
        calendar: Calendar = .current
    ) -> QuickFeedHomeSnapshot {
        FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: allEvents,
            careLogs: careLogs,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now,
            todayLabel: todayLabel,
            calendar: calendar
        ))
    }
}
