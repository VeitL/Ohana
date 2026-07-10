//
//  DomainCareFactWriteKernel.swift
//  Ohana
//
//  Typed authorization and persistence writer for active member care/economy facts.
//

import Foundation
import SwiftData

nonisolated enum DomainCareFactKind: Equatable {
    case care(
        type: CareType,
        amountGrams: Double,
        amountMl: Double,
        note: String,
        foodKind: FeedFoodKind,
        treatKind: FeedTreatKind?,
        autoFeedDedupKey: String,
        sharedSessionId: String
    )
    case potty(type: PottyType, sharedSessionId: String)
    case unknownPotty(type: PottyType, sharedSessionId: String)
    case hygiene(type: HygieneType, sharedSessionId: String)
    case health(type: HealthLogType, note: String)
    case expense(amount: Double, category: ExpenseCategory, note: String, sharedSessionId: String)
    case walk(
        distanceMeters: Double,
        endDate: Date?,
        coconutsEarned: Int,
        behaviorNotes: String?,
        moodRating: Int,
        executorIds: [String],
        sharedSessionId: String
    )
}

nonisolated struct DomainCareFactCreateIntent: Equatable {
    let kind: DomainCareFactKind
    let occurredAt: Date
    let modifiedAt: Date
    let executorId: String?
    let source: DomainMutationSourceKind
    let writeKind: MemberWriteKind

    init(
        kind: DomainCareFactKind,
        occurredAt: Date,
        modifiedAt: Date? = nil,
        executorId: String? = nil,
        source: DomainMutationSourceKind = .domainService,
        writeKind: MemberWriteKind = .care
    ) {
        self.kind = kind
        self.occurredAt = occurredAt
        self.modifiedAt = modifiedAt ?? occurredAt
        self.executorId = executorId
        self.source = source
        self.writeKind = writeKind
    }
}

nonisolated struct DomainCareFactWriteToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainCareFactWrite {
    fileprivate let token: DomainCareFactWriteToken
    let mutationPlan: AuthorizedMutationPlan
    let intent: DomainCareFactCreateIntent
    let pet: Pet
    let actor: EconomyRewardOwnerResolution
    let disposition: CareFactWriteDisposition

    fileprivate init(
        mutationPlan: AuthorizedMutationPlan,
        intent: DomainCareFactCreateIntent,
        pet: Pet,
        actor: EconomyRewardOwnerResolution,
        disposition: CareFactWriteDisposition
    ) {
        self.token = DomainCareFactWriteToken()
        self.mutationPlan = mutationPlan
        self.intent = intent
        self.pet = pet
        self.actor = actor
        self.disposition = disposition
    }

    var writesFact: Bool {
        disposition.writesFact
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }
}

nonisolated struct AuthorizedDomainHumanExpenseWrite {
    fileprivate let token: DomainCareFactWriteToken
    let mutationPlan: AuthorizedMutationPlan
    let intent: DomainCareFactCreateIntent
    let human: Human
    let actor: EconomyRewardOwnerResolution
    let disposition: CareFactWriteDisposition

    fileprivate init(
        mutationPlan: AuthorizedMutationPlan,
        intent: DomainCareFactCreateIntent,
        human: Human,
        actor: EconomyRewardOwnerResolution,
        disposition: CareFactWriteDisposition
    ) {
        self.token = DomainCareFactWriteToken()
        self.mutationPlan = mutationPlan
        self.intent = intent
        self.human = human
        self.actor = actor
        self.disposition = disposition
    }

    var writesFact: Bool {
        disposition.writesFact
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }
}

nonisolated struct DomainCareLogWriteResult {
    let log: PetCareLog
    let linkedPottyLog: PetPottyLog?
}

@MainActor
enum DomainCareFactWriteAuthorizer {
    static func authorizePetFact(
        pet: Pet,
        intent: DomainCareFactCreateIntent,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainCareFactWrite? {
        guard let mutationPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .careFact,
                source: intent.source,
                subjectRequest: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: pet.id.uuidString
                ),
                writeKind: intent.writeKind
            ),
            context: context
        ),
            mutationPlan.allowsCareFactWrite
        else {
            return nil
        }

        let actor = actorOverride ?? CareFactWritePolicy.executorResolution(
            requestedExecutorId: intent.executorId,
            context: context,
            logPrefix: logPrefix
        )

        return AuthorizedDomainCareFactWrite(
            mutationPlan: mutationPlan,
            intent: intent,
            pet: pet,
            actor: actor,
            disposition: .active
        )
    }

    /// Startup auto-feeder materialization has no human executor and must be
    /// allowed to run inside a background SwiftData actor. Keep the existing
    /// interactive authorizer on the main actor; this narrow variant only
    /// issues the same policy-backed token for a system-owned care fact.
    nonisolated static func authorizeSystemPetFact(
        pet: Pet,
        intent: DomainCareFactCreateIntent,
        context: ModelContext
    ) -> AuthorizedDomainCareFactWrite? {
        guard let mutationPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .careFact,
                source: intent.source,
                subjectRequest: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: pet.id.uuidString
                ),
                writeKind: intent.writeKind
            ),
            context: context
        ),
            mutationPlan.allowsCareFactWrite
        else {
            return nil
        }

        return AuthorizedDomainCareFactWrite(
            mutationPlan: mutationPlan,
            intent: intent,
            pet: pet,
            actor: EconomyRewardOwnerResolution(
                requestedExecutorId: nil,
                effectiveExecutorId: nil,
                rewardExecutorId: nil,
                usedFallback: false
            ),
            disposition: .active
        )
    }

    static func authorizeHumanExpense(
        human: Human,
        intent: DomainCareFactCreateIntent,
        context: ModelContext,
        logPrefix _: String
    ) -> AuthorizedDomainHumanExpenseWrite? {
        guard case .expense = intent.kind,
              let mutationPlan = DomainPolicyAuthorizer.authorize(
                  DomainMutationAuthorizationRequest(
                      scope: .careFact,
                      source: intent.source,
                      subjectRequest: DomainSubjectResolutionRequest(
                          relatedEntityType: EntityKind.human.rawValue,
                          relatedEntityId: human.id.uuidString
                      ),
                      writeKind: intent.writeKind
                  ),
                  context: context
              ),
              mutationPlan.allowsCareFactWrite
        else {
            return nil
        }

        let humanId = human.id.uuidString
        return AuthorizedDomainHumanExpenseWrite(
            mutationPlan: mutationPlan,
            intent: intent,
            human: human,
            actor: EconomyRewardOwnerResolution(
                requestedExecutorId: humanId,
                effectiveExecutorId: humanId,
                rewardExecutorId: humanId,
                usedFallback: false
            ),
            disposition: .active
        )
    }
}

nonisolated enum DomainCareFactWriter {
    @discardableResult
    static func createCareLog(
        plan: AuthorizedDomainCareFactWrite,
        linkedPottyType: PottyType? = nil,
        context: ModelContext
    ) -> DomainCareLogWriteResult {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard case let .care(type, amountGrams, amountMl, note, foodKind, treatKind, autoFeedDedupKey, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .care")
        }

        let log = PetCareLog(
            date: plan.intent.occurredAt,
            type: type,
            amountGrams: amountGrams,
            amountMl: amountMl,
            note: note,
            foodKind: foodKind,
            treatKind: treatKind,
            autoFeedDedupKey: autoFeedDedupKey,
            sharedSessionId: sharedSessionId,
            pet: plan.pet,
            executorId: plan.actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.intent.modifiedAt)

        let linkedPottyLog: PetPottyLog? = if plan.allowsDerivedEffects, let linkedPottyType {
            createPottyLog(
                plan: plan,
                type: linkedPottyType,
                pet: plan.pet,
                sharedSessionId: sharedSessionId,
                context: context
            )
        } else {
            nil
        }

        return DomainCareLogWriteResult(log: log, linkedPottyLog: linkedPottyLog)
    }

    @discardableResult
    static func createPottyLog(
        plan: AuthorizedDomainCareFactWrite,
        context: ModelContext
    ) -> PetPottyLog {
        guard case let .potty(type, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .potty")
        }
        return createPottyLog(plan: plan, type: type, pet: plan.pet, sharedSessionId: sharedSessionId, context: context)
    }

    @discardableResult
    static func createUnknownPottyLog(
        plan: AuthorizedDomainCareFactWrite,
        context: ModelContext
    ) -> PetPottyLog {
        guard case let .unknownPotty(type, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .unknownPotty")
        }
        return createPottyLog(plan: plan, type: type, pet: nil, sharedSessionId: sharedSessionId, context: context)
    }

    @discardableResult
    static func createHygieneLog(
        plan: AuthorizedDomainCareFactWrite,
        context: ModelContext
    ) -> PetHygieneLog {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard case let .hygiene(type, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .hygiene")
        }

        let log = PetHygieneLog(
            date: plan.intent.occurredAt,
            type: type,
            pet: plan.pet,
            executorId: plan.actor.effectiveExecutorId,
            sharedSessionId: sharedSessionId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.intent.modifiedAt)
        return log
    }

    @discardableResult
    static func createHealthLog(
        plan: AuthorizedDomainCareFactWrite,
        context: ModelContext
    ) -> PetHealthLog {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard case let .health(type, note) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .health")
        }

        let log = PetHealthLog(
            date: plan.intent.occurredAt,
            type: type,
            note: note,
            pet: plan.pet,
            executorId: plan.actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.intent.modifiedAt)
        return log
    }

    @discardableResult
    static func createExpenseLog(
        plan: AuthorizedDomainCareFactWrite,
        context: ModelContext
    ) -> PetExpenseLog {
        upsertExpenseLog(plan: plan, existing: nil, context: context)
    }

    @discardableResult
    static func upsertExpenseLog(
        plan: AuthorizedDomainCareFactWrite,
        existing log: PetExpenseLog?,
        context: ModelContext
    ) -> PetExpenseLog {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard case let .expense(amount, category, note, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .expense")
        }

        // economy-boundary: allow authorized care-fact writer; callers emit ledger/economy effects through DomainCareFactEffectsDispatcher.
        let didCreate = log == nil
        let expenseLog = log ?? PetExpenseLog(
            date: plan.intent.occurredAt,
            amount: amount,
            category: category,
            note: note,
            pet: plan.pet,
            executorId: plan.actor.effectiveExecutorId,
            sharedSessionId: sharedSessionId
        )
        if didCreate {
            context.insert(expenseLog)
        }
        expenseLog.date = plan.intent.occurredAt
        expenseLog.amount = amount
        expenseLog.category = category.rawValue
        expenseLog.note = note
        expenseLog.pet = plan.pet
        expenseLog.executorId = plan.actor.effectiveExecutorId
        expenseLog.sharedSessionId = sharedSessionId
        CloudSyncMutationRecorder.markModified(expenseLog, context: context, modifiedAt: plan.intent.modifiedAt)
        return expenseLog
    }

    @discardableResult
    static func createHumanExpenseLog(
        plan: AuthorizedDomainHumanExpenseWrite,
        context: ModelContext
    ) -> PetExpenseLog {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard case let .expense(amount, category, note, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainHumanExpenseWrite kind must be .expense")
        }

        // economy-boundary: allow authorized human expense writer; effects are dispatched through the same capability plan.
        let log = PetExpenseLog(
            date: plan.intent.occurredAt,
            amount: amount,
            category: category,
            note: note,
            pet: nil,
            executorId: plan.actor.effectiveExecutorId,
            sharedSessionId: sharedSessionId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.intent.modifiedAt)
        return log
    }

    @discardableResult
    static func createWalkLog(
        plan: AuthorizedDomainCareFactWrite,
        context: ModelContext
    ) -> PetWalkLog {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard case let .walk(distanceMeters, endDate, coconutsEarned, behaviorNotes, moodRating, executorIds, sharedSessionId) = plan.intent.kind else {
            preconditionFailure("AuthorizedDomainCareFactWrite kind must be .walk")
        }

        let log = PetWalkLog(
            startDate: plan.intent.occurredAt,
            pet: plan.pet,
            executorId: plan.actor.effectiveExecutorId,
            executorIds: executorIds,
            sharedSessionId: sharedSessionId
        )
        log.endDate = endDate
        log.distanceMeters = max(0, distanceMeters)
        log.coconutsEarned = max(0, coconutsEarned)
        log.behaviorNotes = behaviorNotes
        log.moodRating = moodRating
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.intent.modifiedAt)
        return log
    }

    private static func createPottyLog(
        plan: AuthorizedDomainCareFactWrite,
        type: PottyType,
        pet: Pet?,
        sharedSessionId: String,
        context: ModelContext
    ) -> PetPottyLog {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        let log = PetPottyLog(
            date: plan.intent.occurredAt,
            type: type,
            pet: pet,
            executorId: plan.actor.effectiveExecutorId,
            sharedSessionId: sharedSessionId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.intent.modifiedAt)
        return log
    }
}

@MainActor
enum DomainCareFactEffectsDispatcher {
    @discardableResult
    static func run(
        plan: AuthorizedDomainCareFactWrite,
        _ effects: (EconomyRewardOwnerResolution) -> Void
    ) -> Bool {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard plan.allowsDerivedEffects else { return false }
        effects(plan.actor)
        return true
    }

    @discardableResult
    static func run(
        plan: AuthorizedDomainHumanExpenseWrite,
        _ effects: (EconomyRewardOwnerResolution) -> Void
    ) -> Bool {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard plan.allowsDerivedEffects else { return false }
        effects(plan.actor)
        return true
    }

    static func map<Result>(
        plan: AuthorizedDomainCareFactWrite,
        default defaultValue: Result,
        _ effects: (EconomyRewardOwnerResolution) -> Result
    ) -> Result {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard plan.allowsDerivedEffects else { return defaultValue }
        return effects(plan.actor)
    }

    static func map<Result>(
        plan: AuthorizedDomainHumanExpenseWrite,
        default defaultValue: Result,
        _ effects: (EconomyRewardOwnerResolution) -> Result
    ) -> Result {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        guard plan.allowsDerivedEffects else { return defaultValue }
        return effects(plan.actor)
    }

    @discardableResult
    static func run(
        plans: [AuthorizedDomainCareFactWrite],
        _ effects: (EconomyRewardOwnerResolution) -> Void
    ) -> Bool {
        for plan in plans {
            _ = plan.token
            plan.mutationPlan.consumeAuthorization()
        }
        guard let plan = plans.first(where: \.allowsDerivedEffects) else { return false }
        effects(plan.actor)
        return true
    }

    static func map<Result>(
        plans: [AuthorizedDomainCareFactWrite],
        default defaultValue: Result,
        _ effects: (EconomyRewardOwnerResolution) -> Result
    ) -> Result {
        for plan in plans {
            _ = plan.token
            plan.mutationPlan.consumeAuthorization()
        }
        guard let plan = plans.first(where: \.allowsDerivedEffects) else { return defaultValue }
        return effects(plan.actor)
    }
}
