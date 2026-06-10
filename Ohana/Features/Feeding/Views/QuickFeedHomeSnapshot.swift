//
//  QuickFeedHomeSnapshot.swift
//  Ohana
//
//  Lightweight render snapshot for the feeding home surface.
//

import Foundation

struct QuickFeedHomeSnapshot {
    let manualPlanEvents: [Event]
    let autoFeederEvents: [Event]
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
        now: Date,
        todayLabel: String,
        calendar: Calendar = .current
    ) -> QuickFeedHomeSnapshot {
        FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: allEvents,
            careLogs: careLogs,
            foodRecords: foodRecords,
            now: now,
            todayLabel: todayLabel,
            calendar: calendar
        ))
    }
}
