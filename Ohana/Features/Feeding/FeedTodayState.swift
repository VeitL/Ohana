//
//  FeedTodayState.swift
//  Ohana
//
//  Derived state for today's feeding progress.
//

import Foundation

struct FeedTodayState {
    let pet: Pet
    let allEvents: [Event]
    let manualGoalCount: Int
    let careLogs: [PetCareLog]
    let now: Date
    let calendar: Calendar

    init(
        pet: Pet,
        allEvents: [Event],
        manualGoalCount: Int,
        careLogs: [PetCareLog] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.pet = pet
        self.allEvents = allEvents
        self.manualGoalCount = max(manualGoalCount, 1)
        self.careLogs = careLogs
        self.now = now
        self.calendar = calendar
    }

    func isPlanReminderSatisfied(_ reminder: Reminder) -> Bool {
        reminder.isCompleted
    }

    var feedScheduleEvents: [Event] {
        FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).manualReminderEvents
    }

    var autoFeederEvents: [Event] {
        FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).autoFeederEvents
    }

    var todayPlanReminders: [Reminder] {
        allPlanReminders
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var allPlanReminders: [Reminder] {
        feedScheduleEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { ($0.isPending || $0.isFailed) && !isPlanReminderSatisfied($0) }
    }

    var missedTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { !isPlanReminderSatisfied($0) && ($0.isFailed || ($0.isPending && $0.scheduledAt < now)) }
    }

    var missedPlanReminders: [Reminder] {
        allPlanReminders.filter { !isPlanReminderSatisfied($0) && ($0.isPending || $0.isFailed) && $0.scheduledAt <= now }
    }

    var catchUpPlanReminders: [Reminder] {
        allPlanReminders.filter { FeedPlanCatchUpPolicy.isCatchUpEligible($0, now: now) }
    }

    var expiredMissedPlanReminders: [Reminder] {
        allPlanReminders.filter { FeedPlanCatchUpPolicy.isExpiredMiss($0, now: now) }
    }

    var lastExpiredPlanReminderDate: Date? {
        expiredMissedPlanReminders.map(\.scheduledAt).max()
    }

    var completedTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { isPlanReminderSatisfied($0) }
    }

    var nextPendingReminder: Reminder? {
        guard expiredMissedPlanReminders.isEmpty else { return nil }
        return catchUpPlanReminders.first ?? pendingTodayPlanReminders.first
    }

    var hasTodayPlan: Bool {
        !todayPlanReminders.isEmpty
    }

    var manualTodayLogs: [PetCareLog] {
        careLogs
            .filter {
                $0.pet?.id == pet.id &&
                    $0.careType == .feeding &&
                    $0.isManualFeedLogEntry &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
    }

    var plannedTodayLogs: [PetCareLog] {
        careLogs
            .filter {
                $0.pet?.id == pet.id &&
                    $0.careType == .feeding &&
                    $0.isPlannedFeedLogEntry &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
    }

    var allTodayLogs: [PetCareLog] {
        careLogs
            .filter {
                $0.pet?.id == pet.id &&
                    $0.careType == .feeding &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
    }

    var mainFoodTodayLogs: [PetCareLog] {
        allTodayLogs.filter { FeedLogMetadata.isMainFoodLog($0) }
    }

    var treatTodayLogs: [PetCareLog] {
        allTodayLogs.filter { FeedLogMetadata.isTreatLog($0) }
    }

    var completedCount: Int {
        hasTodayPlan ? completedTodayPlanReminders.count : mainFoodTodayLogs.count
    }

    var targetCount: Int {
        hasTodayPlan ? max(todayPlanReminders.count, 1) : manualGoalCount
    }

    var progress: Double {
        min(1, Double(completedCount) / Double(targetCount))
    }

    var isComplete: Bool {
        completedCount >= targetCount
    }

    var hasOverduePlan: Bool {
        !missedPlanReminders.isEmpty
    }

    var todayFeedGrams: Double {
        allTodayLogs.reduce(0) { total, log in
            total + (log.amountGrams > 0 ? log.amountGrams : pet.dailyPortionGrams)
        }
    }

    var todayMainFoodGrams: Double {
        mainFoodTodayLogs.reduce(0) { total, log in
            total + FeedStockCalculator.effectiveMainFoodAmount(for: log, pet: pet)
        }
    }

    var todayTreatGrams: Double {
        treatTodayLogs.reduce(0) { total, log in
            total + max(0, log.amountGrams)
        }
    }
}
