//
//  ExpandedQuickActionFeedState.swift
//  Ohana
//
//  Feed quick-action derived state for expanded Home cards.
//

import Foundation

nonisolated struct HomeFeedQuickActionState {
    let rules: FeedRuleState
    let todayEntries: [HomeFeedQuickActionEntry]
    let todayPlanReminders: [Reminder]
    let catchUpPlanReminders: [Reminder]
    let expiredMissedPlanReminders: [Reminder]

    init(
        pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) {
        rules = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
        todayEntries = feedingLedgerEntries
            .filter { entry in
                entry.petId == pet.id &&
                    entry.source != .treat &&
                    calendar.isDate(entry.date, inSameDayAs: now)
            }
        todayPlanReminders = rules.todayManualReminders
        catchUpPlanReminders = rules.catchUpManualReminders
        expiredMissedPlanReminders = rules.expiredMissedManualReminders
    }

    var operatingMode: FeedOperatingMode { rules.operatingMode }
    var manualMainCount: Int { todayEntries.count { $0.source == .manualMain } }
    var autoMainCount: Int { todayEntries.count { $0.source == .autoMain } }
    var completedTodayPlanCount: Int { todayPlanReminders.count(where: \.isCompleted) }
    var todayManualPlanTotalCount: Int { max(todayPlanReminders.count, rules.manualReminderEvents.count, 1) }
    var todayManualPlanMissedCount: Int { expiredMissedPlanReminders.isEmpty ? catchUpPlanReminders.count : 0 }
    var hasMissedManualPlan: Bool { expiredMissedPlanReminders.isEmpty && !catchUpPlanReminders.isEmpty }
    var lastExpiredManualPlanDate: Date? { expiredMissedPlanReminders.map(\.scheduledAt).max() }
    var nextManualReminder: Reminder? { rules.nextPendingManualReminder }
}
