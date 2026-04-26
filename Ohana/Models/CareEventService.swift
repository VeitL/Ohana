//
//  CareEventService.swift
//  Ohana
//
//  Centralized care/reminder/economy write paths.
//

import Foundation
import SwiftData

enum CareEventService {
    @discardableResult
    @MainActor
    static func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: PetCareLog.manualFeedNoteMarker,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()

        QuestManager.shared.recordFirstMeal()
        let reward = CoconutEconomyService.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: context
        )
        return reward
    }

    @discardableResult
    @MainActor
    static func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .precise,
        executorId: String? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        guard let event = reminder.event else { return nil }

        let log = PetCareLog(
            date: Date(),
            type: .feeding,
            amountGrams: feedAmount(from: event, fallback: pet.dailyPortionGrams),
            note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
            pet: pet,
            executorId: executorId
        )
        context.insert(log)

        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        if let executorId {
            reminder.completedBy = executorId
        }
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: executorId,
            source: .reminder,
            context: context
        )

        QuestManager.shared.recordFirstMeal()
        let reward = CoconutEconomyService.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: context
        )
        return reward
    }

    @discardableResult
    @MainActor
    static func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetCareLog(
            date: date,
            type: type,
            amountMl: amountMl,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()

        let award = CoconutEconomyService.awardCareAction(type: reward, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(award),
            context: context
        )
        return award
    }

    @discardableResult
    @MainActor
    static func recordPotty(
        pet: Pet,
        type: PottyType = .perfectPoop,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetPottyLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = CoconutEconomyService.awardCareAction(type: .potty(isLitter: false), pet: pet, context: context)
        CareLedgerService.recordPetPotty(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: context
        )
        return reward
    }

    static func feedAmount(from event: Event, fallback: Double) -> Double {
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }
}

enum ReminderCompletionService {
    @MainActor
    static func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        reminder.completedBy = humanId ?? ""
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "complete", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        reminder.statusEnum = .skipped
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "skip", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        if reschedule {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "reopen", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.scheduledAt = Calendar.current.date(byAdding: .day, value: 1, to: reminder.scheduledAt)
            ?? Date().addingTimeInterval(86_400)
        if reschedule {
            Task { @MainActor in
                await ReminderSchedulingService.cancelAndReschedule(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "snoozeOneDay", actorId: humanId, source: .service, context: context)
    }
}

enum CoconutEconomyService {
    @discardableResult
    @MainActor
    static func awardCareAction(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none
    ) -> (humanGot: Int, petGot: Int) {
        QuestManager.shared.awardAction(type: type, pet: pet, context: context, quality: quality)
    }
}
