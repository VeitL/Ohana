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

nonisolated enum ExpenseAmountValidationError: LocalizedError, Equatable, Sendable {
    case invalidUserExpense
    case invalidInsuranceReimbursement
    case invalidPersistedExpense

    var errorDescription: String? {
        let l = L10n.current
        return switch self {
        case .invalidUserExpense:
            l.tr(
                zh: "费用金额必须是大于 0 的有效数字。请修改金额后重试。",
                en: "Expense amount must be a finite number greater than zero. Update the amount and try again.",
                de: "Der Ausgabenbetrag muss eine endliche Zahl größer als null sein. Ändere den Betrag und versuche es erneut."
            )
        case .invalidInsuranceReimbursement:
            l.tr(
                zh: "保险报销金额必须是大于 0 的有效数字。请修改金额后重试。",
                en: "Insurance reimbursement must be a finite number greater than zero. Update the amount and try again.",
                de: "Die Versicherungserstattung muss eine endliche Zahl größer als null sein. Ändere den Betrag und versuche es erneut."
            )
        case .invalidPersistedExpense:
            l.tr(
                zh: "费用记录包含无效金额，未写入数据。请检查来源后重试。",
                en: "The expense record contains an invalid amount and was not saved. Check the source and try again.",
                de: "Der Ausgabeneintrag enthält einen ungültigen Betrag und wurde nicht gespeichert. Prüfe die Quelle und versuche es erneut."
            )
        }
    }
}

nonisolated enum ExpenseAmountPolicy {
    static let insuranceReimbursementNotePrefix = "保险报销到账："

    static func isValidUserExpense(_ amount: Double) -> Bool {
        amount.isFinite && amount > 0
    }

    static func validateUserExpense(_ amount: Double) throws {
        guard isValidUserExpense(amount) else {
            throw ExpenseAmountValidationError.invalidUserExpense
        }
    }

    static func storedInsuranceReimbursementAmount(from amount: Double) throws -> Double {
        guard isValidUserExpense(amount) else {
            throw ExpenseAmountValidationError.invalidInsuranceReimbursement
        }
        return -amount
    }

    static func isValidPersistedExpense(
        amount: Double,
        categoryRaw: String,
        note: String
    ) -> Bool {
        if isValidUserExpense(amount) {
            return true
        }
        return isRecognizedInsuranceReimbursement(
            amount: amount,
            categoryRaw: categoryRaw,
            note: note
        )
    }

    static func validatePersistedExpense(
        amount: Double,
        categoryRaw: String,
        note: String
    ) throws {
        guard isValidPersistedExpense(amount: amount, categoryRaw: categoryRaw, note: note) else {
            throw ExpenseAmountValidationError.invalidPersistedExpense
        }
    }

    static func isValid(intent: DomainCareFactCreateIntent) -> Bool {
        guard case let .expense(amount, category, note, _) = intent.kind else { return true }
        if intent.source == .domainService {
            return isValidPersistedExpense(
                amount: amount,
                categoryRaw: category.rawValue,
                note: note
            )
        }
        return isValidUserExpense(amount)
    }

    private static func isRecognizedInsuranceReimbursement(
        amount: Double,
        categoryRaw: String,
        note: String
    ) -> Bool {
        amount.isFinite &&
            amount < 0 &&
            categoryRaw == ExpenseCategory.insurancePremium.rawValue &&
            note.hasPrefix(insuranceReimbursementNotePrefix)
    }
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
        guard ExpenseAmountPolicy.isValid(intent: intent),
              let mutationPlan = DomainPolicyAuthorizer.authorize(
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
        guard ExpenseAmountPolicy.isValid(intent: intent),
              let mutationPlan = DomainPolicyAuthorizer.authorize(
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
              ExpenseAmountPolicy.isValid(intent: intent),
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

    /// Creates the ledger projection for a previously authorized care fact.
    /// Keeping this writer beside the fact writer lets background model actors
    /// persist one atomic batch without reaching through a static service
    /// facade or crossing live models onto the main actor.
    @discardableResult
    static func createCareLedgerEvent(
        plan: AuthorizedDomainCareFactWrite,
        log: PetCareLog,
        sourceEventID: UUID?,
        metadataJSON: String,
        context: ModelContext
    ) -> CareLedgerEvent? {
        _ = plan.token
        guard plan.allowsDerivedEffects else { return nil }

        let event = CareLedgerEvent(
            occurredAt: log.date,
            actorKind: log.executorId == nil ? .unknown : .human,
            actorId: log.executorId,
            subjectKind: .pet,
            subjectId: plan.pet.id.uuidString,
            eventKind: .care,
            actionType: log.careType.rawValue,
            amountValue: log.amountGrams,
            amountUnit: "g",
            note: log.note,
            source: .service,
            sourceEventId: sourceEventID?.uuidString,
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString,
            metadataJSON: metadataJSON
        )
        context.insert(event)
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: log.date)
        return event
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
        recordedByHumanId: String? = nil,
        context: ModelContext
    ) -> PetExpenseLog {
        upsertExpenseLog(
            plan: plan,
            recordedByHumanId: recordedByHumanId,
            existing: nil,
            context: context
        )
    }

    @discardableResult
    static func upsertExpenseLog(
        plan: AuthorizedDomainCareFactWrite,
        recordedByHumanId: String? = nil,
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
        expenseLog.recordedByHumanId = recordedByHumanId
        expenseLog.sharedSessionId = sharedSessionId
        CloudSyncMutationRecorder.markModified(expenseLog, context: context, modifiedAt: plan.intent.modifiedAt)
        return expenseLog
    }

    @discardableResult
    static func createHumanExpenseLog(
        plan: AuthorizedDomainHumanExpenseWrite,
        recordedByHumanId: String? = nil,
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
        log.recordedByHumanId = recordedByHumanId
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
