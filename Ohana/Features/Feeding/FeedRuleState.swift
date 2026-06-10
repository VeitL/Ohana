//
//  FeedRuleState.swift
//  Ohana
//

import Foundation
import SwiftData

struct FeedRuleState {
    let pet: Pet
    let allEvents: [Event]
    let now: Date
    let calendar: Calendar

    init(pet: Pet, allEvents: [Event], now: Date = Date(), calendar: Calendar = .current) {
        self.pet = pet
        self.allEvents = allEvents
        self.now = now
        self.calendar = calendar
    }

    var manualReminderEvents: [Event] {
        allEvents
            .filter { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    var autoFeederEvents: [Event] {
        allEvents
            .filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    var todayManualReminders: [Reminder] {
        allManualReminders
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var allManualReminders: [Reminder] {
        manualReminderEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isPending || $0.isFailed }
    }

    var missedTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isFailed || ($0.isPending && $0.scheduledAt < now) }
    }

    var missedManualReminders: [Reminder] {
        allManualReminders.filter { !$0.isCompleted && ($0.isPending || $0.isFailed) && $0.scheduledAt <= now }
    }

    var catchUpManualReminders: [Reminder] {
        allManualReminders.filter { FeedPlanCatchUpPolicy.isCatchUpEligible($0, now: now) }
    }

    var expiredMissedManualReminders: [Reminder] {
        allManualReminders.filter { FeedPlanCatchUpPolicy.isExpiredMiss($0, now: now) }
    }

    var completedTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isCompleted }
    }

    var nextPendingManualReminder: Reminder? {
        guard expiredMissedManualReminders.isEmpty else { return nil }
        return catchUpManualReminders.first ?? pendingTodayManualReminders.first
    }

    var autoDailyTotalGrams: Double {
        FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents)
    }

    var operatingMode: FeedOperatingMode {
        FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
    }
}
