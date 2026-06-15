//
//  CareEventService+Care.swift
//  Ohana
//

import Foundation
import SwiftData

extension CareEventService {
    private static func noOpCareFactResult(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        executorId: String?,
        reward _: DomainCareRewardAction,
        date: Date
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?) {
        let log = PetCareLog(date: date, type: type, amountMl: amountMl, pet: nil, executorId: executorId)
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: type,
                linkedPottyLogID: nil,
                coconutDelta: 0,
                disposition: .noOp
            ),
            (0, 0),
            log,
            nil
        )
    }

    @discardableResult
    @MainActor
    static func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        reward: DomainCareRewardAction,
        quality: DomainCareRewardQuality = .none,
        date: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordCareFact(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: quality,
            date: date,
            dependencies: dependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordCareFact(
        pet: Pet,
        type: CareType,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        reward: DomainCareRewardAction,
        quality: DomainCareRewardQuality = .none,
        date: Date = Date(),
        source: CareLedgerSource = .quickAction,
        createsLinkedPottyLog: Bool = false,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?) {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let intent = DomainCareFactCreateIntent(
            kind: .care(
                type: type,
                amountGrams: 0,
                amountMl: amountMl,
                note: "",
                foodKind: .dry,
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
            logPrefix: "CareEventService recordCareFact"
        ) else {
            return noOpCareFactResult(
                pet: pet,
                type: type,
                amountMl: amountMl,
                executorId: executorId,
                reward: reward,
                date: date
            )
        }
        let careWrite = DomainCareFactWriter.createCareLog(
            plan: write,
            linkedPottyType: createsLinkedPottyLog && type == .litter ? .perfectPoop : nil,
            context: context
        )
        let log = careWrite.log
        let pottyLog = careWrite.linkedPottyLog
        context.safeSave()

        let award = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
            let award = dependencies.economy.awardCareAction(
                type: reward,
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
                coconutDelta: dependencies.careLedger.rewardDelta(award),
                metadataJSON: dependencies.economy.rewardMetadata(for: award),
                context: context,
                save: true
            )
            if let pottyLog {
                dependencies.careLedger.recordPetPotty(
                    log: pottyLog,
                    pet: pet,
                    source: source,
                    coconutDelta: 0,
                    metadataJSON: "",
                    context: context,
                    save: true
                )
            }
            dependencies.quickActionReminderCompletion.completeNearestPetCareReminder(
                pet: pet,
                type: type,
                context: context,
                executorId: actor.effectiveExecutorId,
                now: date
            )
            return award
        }
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: type,
                linkedPottyLogID: pottyLog?.id,
                coconutDelta: dependencies.careLedger.rewardDelta(award)
            ),
            award,
            log,
            pottyLog
        )
    }

    @discardableResult
    @MainActor
    static func recordPotty(
        pet: Pet,
        type: PottyType = .perfectPoop,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordPottyFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordPottyFact(
        pet: Pet,
        type: PottyType = .perfectPoop,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: PottyRecordResult, reward: (humanGot: Int, petGot: Int), log: PetPottyLog?) {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let intent = DomainCareFactCreateIntent(
            kind: .potty(type: type, sharedSessionId: ""),
            occurredAt: date,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService recordPottyFact"
        ) else {
            return (
                PottyRecordResult(
                    logID: nil,
                    subjectID: pet.id,
                    pottyType: type,
                    coconutDelta: 0,
                    disposition: .noOp
                ),
                (0, 0),
                nil
            )
        }
        let disposition = write.disposition
        let log = DomainCareFactWriter.createPottyLog(plan: write, context: context)
        context.safeSave()

        let reward = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
            let reward = dependencies.economy.awardCareAction(
                type: .potty(isLitter: false),
                pet: pet,
                context: context,
                quality: .none,
                date: Date(),
                executorId: actor.rewardExecutorId
            )
            dependencies.careLedger.recordPetPotty(
                log: log,
                pet: pet,
                source: .quickAction,
                coconutDelta: dependencies.careLedger.rewardDelta(reward),
                metadataJSON: dependencies.economy.rewardMetadata(for: reward),
                context: context,
                save: true
            )
            dependencies.quickActionReminderCompletion.completeNearestPetPottyReminder(
                pet: pet,
                context: context,
                executorId: actor.effectiveExecutorId,
                now: date
            )
            return reward
        }
        let result = PottyRecordResult(
            logID: log.id,
            subjectID: pet.id,
            pottyType: type,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            disposition: disposition
        )
        return (result, reward, log)
    }

    struct HygieneRecordResult: Equatable {
        let logID: UUID
        let subjectID: UUID
        let hygieneType: HygieneType
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        init(
            logID: UUID,
            subjectID: UUID,
            hygieneType: HygieneType,
            coconutDelta: Int,
            disposition: CareFactWriteDisposition = .active
        ) {
            self.logID = logID
            self.subjectID = subjectID
            self.hygieneType = hygieneType
            self.coconutDelta = coconutDelta
            self.disposition = disposition
        }

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    @discardableResult
    @MainActor
    static func recordHygiene(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordHygieneFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordHygieneFact(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: HygieneRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHygieneLog) {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let intent = DomainCareFactCreateIntent(
            kind: .hygiene(type: type, sharedSessionId: ""),
            occurredAt: date,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService recordHygieneFact"
        ) else {
            let log = PetHygieneLog(date: date, type: type, pet: nil, executorId: executorId)
            return (
                HygieneRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    hygieneType: type,
                    coconutDelta: 0,
                    disposition: .noOp
                ),
                (0, 0),
                log
            )
        }
        let log = DomainCareFactWriter.createHygieneLog(plan: write, context: context)
        context.safeSave()

        let reward = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
            let reward = dependencies.economy.awardCareAction(
                type: .care(type: type),
                pet: pet,
                context: context,
                quality: .none,
                date: Date(),
                executorId: actor.rewardExecutorId
            )
            let metadataJSON = dependencies.economy.rewardMetadata(for: reward)
            dependencies.careLedger.record(
                occurredAt: log.date,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .hygiene,
                actionType: type.rawValue,
                amountValue: 0,
                amountUnit: "",
                note: "",
                source: .quickAction,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetHygieneLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: dependencies.careLedger.rewardDelta(reward),
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: metadataJSON,
                context: context,
                save: true
            )
            dependencies.careLedger.syncLedgerEnergyIfNeeded(metadataJSON: metadataJSON, context: context)
            dependencies.quickActionReminderCompletion.completeNearestPetHygieneReminder(
                pet: pet,
                type: type,
                context: context,
                executorId: actor.effectiveExecutorId,
                now: date
            )
            return reward
        }
        let result = HygieneRecordResult(
            logID: log.id,
            subjectID: pet.id,
            hygieneType: type,
            coconutDelta: dependencies.careLedger.rewardDelta(reward)
        )
        return (result, reward, log)
    }

    @discardableResult
    @MainActor
    static func recordHealth(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordHealthFact(
            pet: pet,
            type: type,
            note: note,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordHealthFact(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: HealthRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHealthLog?) {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let intent = DomainCareFactCreateIntent(
            kind: .health(type: type, note: note),
            occurredAt: date,
            executorId: executorId
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CareEventService recordHealthFact"
        ) else {
            return (
                HealthRecordResult(
                    logID: nil,
                    subjectID: pet.id,
                    healthType: type,
                    coconutDelta: 0,
                    disposition: .noOp
                ),
                (0, 0),
                nil
            )
        }
        let disposition = write.disposition
        let log = DomainCareFactWriter.createHealthLog(plan: write, context: context)
        context.safeSave()

        let reward = DomainCareFactEffectsDispatcher.map(plan: write, default: (0, 0)) { actor in
            let reward = dependencies.economy.awardCareAction(
                type: .health,
                pet: pet,
                context: context,
                quality: .none,
                date: Date(),
                executorId: actor.rewardExecutorId
            )
            let metadataJSON = dependencies.economy.rewardMetadata(for: reward)
            dependencies.careLedger.record(
                occurredAt: log.date,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .health,
                actionType: type.rawValue,
                amountValue: 0,
                amountUnit: "",
                note: note,
                source: .quickAction,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetHealthLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: dependencies.careLedger.rewardDelta(reward),
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: metadataJSON,
                context: context,
                save: true
            )
            dependencies.careLedger.syncLedgerEnergyIfNeeded(metadataJSON: metadataJSON, context: context)
            return reward
        }
        let result = HealthRecordResult(
            logID: log.id,
            subjectID: pet.id,
            healthType: type,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            disposition: disposition
        )
        return (result, reward, log)
    }
}
