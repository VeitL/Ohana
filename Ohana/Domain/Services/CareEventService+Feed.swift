//
//  CareEventService+Feed.swift
//  Ohana
//

import Foundation
import SwiftData

extension CareEventService {
    private static func noOpManualFeedResult(
        pet: Pet,
        amountGrams: Double,
        executorId: String?,
        date: Date,
        foodKind: FeedFoodKind
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog) {
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: PetCareLog.manualFeedNoteMarker,
            foodKind: foodKind,
            pet: nil,
            executorId: executorId
        )
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: .feeding,
                linkedPottyLogID: nil,
                coconutDelta: 0,
                disposition: .noOp
            ),
            (0, 0),
            log
        )
    }

    @MainActor
    static func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        foodKind: FeedFoodKind = .dry,
        dependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordManualFeedFact(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            foodKind: foodKind,
            dependencies: dependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordManualFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        foodKind: FeedFoodKind = .dry,
        source: CareLedgerSource = .quickAction,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog) {
        let dependencies = providedDependencies ?? .live()
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            return noOpManualFeedResult(
                pet: pet,
                amountGrams: amountGrams,
                executorId: executorId,
                date: date,
                foodKind: foodKind
            )
        }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "CareEventService recordManualFeedFact"
        )
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: PetCareLog.manualFeedNoteMarker,
            foodKind: foodKind,
            pet: pet,
            executorId: actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()

        guard disposition.allowsDerivedEffects else {
            return (
                CareRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    careType: .feeding,
                    linkedPottyLogID: nil,
                    coconutDelta: 0,
                    disposition: disposition
                ),
                (0, 0),
                log
            )
        }

        dependencies.questManager.recordFirstMeal(actorId: actor.rewardExecutorId, context: context)
        let reward = dependencies.economy.awardCareAction(
            type: .feed,
            pet: pet,
            context: context,
            quality: quality,
            date: Date(),
            executorId: actor.rewardExecutorId
        )
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: source,
            sourceEventId: nil,
            sourceReminderId: nil,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        dependencies.quickActionReminderCompletion.completeNearestPetCareReminder(
            pet: pet,
            type: .feeding,
            context: context,
            executorId: actor.effectiveExecutorId,
            now: date
        )
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: .feeding,
                linkedPottyLogID: nil,
                coconutDelta: dependencies.careLedger.rewardDelta(reward)
            ),
            reward,
            log
        )
    }

    @discardableResult
    @MainActor
    static func recordTreatFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        treatKind: FeedTreatKind = .other,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> PetCareLog {
        recordTreatFeedFact(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            date: date,
            treatKind: treatKind,
            dependencies: providedDependencies
        ).log
    }

    @discardableResult
    @MainActor
    static func recordTreatFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        treatKind: FeedTreatKind = .other,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: TreatFeedRecordResult, log: PetCareLog) {
        let dependencies = providedDependencies ?? .live()
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            let log = PetCareLog(
                date: date,
                type: .feeding,
                amountGrams: amountGrams,
                note: FeedLogMetadata.treatFeedNoteMarker,
                treatKind: treatKind,
                pet: nil,
                executorId: executorId
            )
            return (
                result: TreatFeedRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    grams: amountGrams,
                    disposition: disposition
                ),
                log: log
            )
        }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "CareEventService recordTreatFeedFact"
        )
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: FeedLogMetadata.treatFeedNoteMarker,
            treatKind: treatKind,
            pet: pet,
            executorId: actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()
        guard disposition.allowsDerivedEffects else {
            return (
                result: TreatFeedRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    grams: amountGrams,
                    disposition: disposition
                ),
                log: log
            )
        }
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            sourceEventId: nil,
            sourceReminderId: nil,
            coconutDelta: 0,
            metadataJSON: "",
            context: context,
            save: true
        )
        return (
            result: TreatFeedRecordResult(
                logID: log.id,
                subjectID: pet.id,
                grams: amountGrams,
                disposition: disposition
            ),
            log: log
        )
    }

    @discardableResult
    @MainActor
    static func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .precise,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        let result = completePlannedFeedResult(
            pet: pet,
            reminder: reminder,
            context: context,
            quality: quality,
            executorId: executorId,
            operationDate: date,
            dependencies: providedDependencies
        )
        return result.didRecord ? result.reward : nil
    }

    @discardableResult
    @MainActor
    static func completePlannedFeedResult(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .precise,
        executorId: String? = nil,
        occurredAt providedOccurredAt: Date? = nil,
        operationDate: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> PlannedCareCompletionResult {
        let dependencies = providedDependencies ?? .live()
        guard let event = reminder.event else { return .noOp(operationDate: operationDate) }
        let occurredAt = providedOccurredAt ?? CareFactWritePolicy.plannedFactDate(
            scheduledAt: reminder.scheduledAt,
            operationDate: operationDate
        )
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: occurredAt,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else { return .noOp(operationDate: operationDate) }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "CareEventService completePlannedFeedResult"
        )
        let isCatchUp = reminder.scheduledAt < operationDate
        guard !disposition.allowsDerivedEffects || !isCatchUp || FeedPlanCatchUpPolicy.isCatchUpEligible(reminder, now: operationDate) else {
            return .noOp(operationDate: operationDate)
        }

        let log = PetCareLog(
            date: occurredAt,
            type: .feeding,
            amountGrams: feedAmount(from: event, fallback: pet.dailyPortionGrams),
            note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
            foodKind: event.foodKind,
            pet: pet,
            executorId: actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: operationDate)

        guard disposition.allowsDerivedEffects else {
            context.safeSave()
            return PlannedCareCompletionResult(
                logID: log.id,
                subjectID: pet.id,
                factDate: occurredAt,
                operationDate: operationDate,
                reward: (0, 0),
                disposition: disposition
            )
        }

        reminder.statusEnum = .completed
        reminder.completedAt = operationDate
        if let effectiveExecutorId = actor.effectiveExecutorId {
            reminder.completedBy = effectiveExecutorId
        }
        event.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        dependencies.careLedger.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: actor.effectiveExecutorId,
            source: .reminder,
            context: context,
            save: true
        )
        dependencies.familyTasks.syncCompletedReminder(reminder, completedBy: actor.effectiveExecutorId, context: context)

        dependencies.questManager.recordFirstMeal(actorId: actor.rewardExecutorId, context: context)
        let reward = dependencies.economy.awardCareAction(
            type: .feed,
            pet: pet,
            context: context,
            quality: quality,
            date: operationDate,
            executorId: actor.rewardExecutorId
        )
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        return PlannedCareCompletionResult(
            logID: log.id,
            subjectID: pet.id,
            factDate: occurredAt,
            operationDate: operationDate,
            reward: reward,
            disposition: disposition
        )
    }

    @discardableResult
    @MainActor
    static func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        let result = completePlannedWaterResult(
            pet: pet,
            reminder: reminder,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            operationDate: date,
            dependencies: providedDependencies
        )
        return result.didRecord ? result.reward : nil
    }

    @discardableResult
    @MainActor
    static func completePlannedWaterResult(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String? = nil,
        occurredAt providedOccurredAt: Date? = nil,
        operationDate: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> PlannedCareCompletionResult {
        let dependencies = providedDependencies ?? .live()
        guard let event = reminder.event else { return .noOp(operationDate: operationDate) }
        let occurredAt = providedOccurredAt ?? CareFactWritePolicy.plannedFactDate(
            scheduledAt: reminder.scheduledAt,
            operationDate: operationDate
        )
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: occurredAt,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else { return .noOp(operationDate: operationDate) }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "CareEventService completePlannedWaterResult"
        )
        let isCatchUp = reminder.scheduledAt < operationDate
        guard !disposition.allowsDerivedEffects || !isCatchUp || WaterPlanCatchUpPolicy.isCatchUpEligible(reminder, now: operationDate) else {
            return .noOp(operationDate: operationDate)
        }

        let log = PetCareLog(
            date: occurredAt,
            type: .watering,
            amountMl: max(0, amountMl),
            note: "\(PetCareLog.plannedWaterNotePrefix)\(event.id.uuidString)",
            pet: pet,
            executorId: actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: operationDate)

        guard disposition.allowsDerivedEffects else {
            context.safeSave()
            return PlannedCareCompletionResult(
                logID: log.id,
                subjectID: pet.id,
                factDate: occurredAt,
                operationDate: operationDate,
                reward: (0, 0),
                disposition: disposition
            )
        }

        reminder.statusEnum = .completed
        reminder.completedAt = operationDate
        if let effectiveExecutorId = actor.effectiveExecutorId {
            reminder.completedBy = effectiveExecutorId
        }
        event.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        dependencies.careLedger.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: actor.effectiveExecutorId,
            source: .reminder,
            context: context,
            save: true
        )
        dependencies.familyTasks.syncCompletedReminder(reminder, completedBy: actor.effectiveExecutorId, context: context)

        let reward = dependencies.economy.awardCareAction(
            type: .water,
            pet: pet,
            context: context,
            quality: .none,
            date: operationDate,
            executorId: actor.rewardExecutorId
        )
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        return PlannedCareCompletionResult(
            logID: log.id,
            subjectID: pet.id,
            factDate: occurredAt,
            operationDate: operationDate,
            reward: reward,
            disposition: disposition
        )
    }

    static func feedAmount(from event: Event, fallback: Double) -> Double {
        if event.feedAmountGrams > 0 {
            return event.feedAmountGrams
        }
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }
}
