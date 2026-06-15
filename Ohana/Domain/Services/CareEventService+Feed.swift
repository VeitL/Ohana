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
        let intent = DomainCareFactCreateIntent(
            kind: .care(
                type: .feeding,
                amountGrams: amountGrams,
                amountMl: 0,
                note: PetCareLog.manualFeedNoteMarker,
                foodKind: foodKind,
                treatKind: nil,
                autoFeedDedupKey: "",
                sharedSessionId: ""
            ),
            occurredAt: date,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService recordManualFeedFact"
        ) else {
            return noOpManualFeedResult(
                pet: pet,
                amountGrams: amountGrams,
                executorId: executorId,
                date: date,
                foodKind: foodKind
            )
        }
        let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log
        context.safeSave()

        let reward = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
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
            return reward
        }
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
        let intent = DomainCareFactCreateIntent(
            kind: .care(
                type: .feeding,
                amountGrams: amountGrams,
                amountMl: 0,
                note: FeedLogMetadata.treatFeedNoteMarker,
                foodKind: .dry,
                treatKind: treatKind,
                autoFeedDedupKey: "",
                sharedSessionId: ""
            ),
            occurredAt: date,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService recordTreatFeedFact"
        ) else {
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
                    disposition: .noOp
                ),
                log: log
            )
        }
        let disposition = write.disposition
        let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log
        context.safeSave()
        DomainCareFactEffectsDispatcher.run(plan: write) { _ in
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
        }
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
        let intent = DomainCareFactCreateIntent(
            kind: .care(
                type: .feeding,
                amountGrams: feedAmount(from: event, fallback: pet.dailyPortionGrams),
                amountMl: 0,
                note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
                foodKind: event.foodKind,
                treatKind: nil,
                autoFeedDedupKey: "",
                sharedSessionId: ""
            ),
            occurredAt: occurredAt,
            modifiedAt: operationDate,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService completePlannedFeedResult"
        ) else {
            return .noOp(operationDate: operationDate)
        }
        let disposition = write.disposition
        let isCatchUp = reminder.scheduledAt < operationDate
        guard !disposition.allowsDerivedEffects || !isCatchUp || FeedPlanCatchUpPolicy.isCatchUpEligible(reminder, now: operationDate) else {
            return .noOp(operationDate: operationDate)
        }

        let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log

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

        let reward = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
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
            return reward
        }
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
        let intent = DomainCareFactCreateIntent(
            kind: .care(
                type: .watering,
                amountGrams: 0,
                amountMl: max(0, amountMl),
                note: "\(PetCareLog.plannedWaterNotePrefix)\(event.id.uuidString)",
                foodKind: .dry,
                treatKind: nil,
                autoFeedDedupKey: "",
                sharedSessionId: ""
            ),
            occurredAt: occurredAt,
            modifiedAt: operationDate,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService completePlannedWaterResult"
        ) else {
            return .noOp(operationDate: operationDate)
        }
        let disposition = write.disposition
        let isCatchUp = reminder.scheduledAt < operationDate
        guard !disposition.allowsDerivedEffects || !isCatchUp || WaterPlanCatchUpPolicy.isCatchUpEligible(reminder, now: operationDate) else {
            return .noOp(operationDate: operationDate)
        }

        let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log

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

        let reward = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
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
            return reward
        }
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
