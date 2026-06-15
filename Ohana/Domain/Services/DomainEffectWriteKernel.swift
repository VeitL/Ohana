//
//  DomainEffectWriteKernel.swift
//  Ohana
//
//  Thin capability wrapper for domain side effects that do not create a new
//  care/member fact themselves but still write ledger, wallet, reminder, or
//  reward state.
//

import Foundation
import SwiftData

nonisolated struct DomainEffectWriteToken: Sendable {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainEffectWrite: @unchecked Sendable {
    fileprivate let token: DomainEffectWriteToken
    let mutationPlan: AuthorizedMutationPlan
    let occurredAt: Date
    let actor: EconomyRewardOwnerResolution

    fileprivate init(
        mutationPlan: AuthorizedMutationPlan,
        occurredAt: Date,
        actor: EconomyRewardOwnerResolution
    ) {
        self.token = DomainEffectWriteToken()
        self.mutationPlan = mutationPlan
        self.occurredAt = occurredAt
        self.actor = actor
    }

    var writesContent: Bool {
        mutationPlan.writesContent
    }

    var allowsDerivedEffects: Bool {
        mutationPlan.allowsDerivedEffects
    }

    var allowsEconomyDerivation: Bool {
        mutationPlan.allowsEconomyDerivation
    }
}

@MainActor
enum DomainEffectWriteAuthorizer {
    static func authorizePetEffect(
        pet: Pet,
        occurredAt: Date = Date(),
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .domainService,
        executorId: String? = nil,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainEffectWrite? {
        authorize(
            subjectRequest: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            ),
            occurredAt: occurredAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actorOverride
        )
    }

    static func authorizeHumanEffect(
        human: Human,
        occurredAt: Date = Date(),
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .domainService,
        executorId: String? = nil,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainEffectWrite? {
        let humanId = human.id.uuidString
        let actor = actorOverride ?? EconomyRewardOwnerResolution(
            requestedExecutorId: executorId ?? humanId,
            effectiveExecutorId: executorId ?? humanId,
            rewardExecutorId: executorId ?? humanId,
            usedFallback: false
        )
        return authorize(
            subjectRequest: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: humanId
            ),
            occurredAt: occurredAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId ?? humanId,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actor
        )
    }

    static func authorizeSubjectEffect(
        subjectRequest: DomainSubjectResolutionRequest,
        occurredAt: Date = Date(),
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .domainService,
        executorId: String? = nil,
        unresolvedAssigneePolicy: DomainUnresolvedAssigneePolicy = .deny,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainEffectWrite? {
        authorize(
            subjectRequest: subjectRequest,
            occurredAt: occurredAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId,
            unresolvedAssigneePolicy: unresolvedAssigneePolicy,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actorOverride
        )
    }

    private static func authorize(
        subjectRequest: DomainSubjectResolutionRequest,
        occurredAt: Date,
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind,
        executorId: String?,
        unresolvedAssigneePolicy: DomainUnresolvedAssigneePolicy = .deny,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainEffectWrite? {
        guard let mutationPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .effect,
                source: source,
                subjectRequest: subjectRequest,
                writeKind: writeKind,
                unresolvedAssigneePolicy: unresolvedAssigneePolicy,
                assigneeWriteKind: writeKind
            ),
            context: context
        ),
            mutationPlan.allowsDerivedEffects
        else {
            return nil
        }

        let actor = actorOverride ?? CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: logPrefix
        )
        return AuthorizedDomainEffectWrite(
            mutationPlan: mutationPlan,
            occurredAt: occurredAt,
            actor: actor
        )
    }
}

@MainActor
enum DomainEffectDispatcher {
    @discardableResult
    static func run(
        plan: AuthorizedDomainEffectWrite,
        _ effects: (EconomyRewardOwnerResolution) -> Void
    ) -> Bool {
        plan.consume()
        guard plan.allowsDerivedEffects else { return false }
        effects(plan.actor)
        return true
    }

    @discardableResult
    static func runEconomy(
        plan: AuthorizedDomainEffectWrite,
        _ effects: (EconomyRewardOwnerResolution) -> Void
    ) -> Bool {
        plan.consume()
        guard plan.allowsEconomyDerivation else { return false }
        effects(plan.actor)
        return true
    }

    static func map<Result>(
        plan: AuthorizedDomainEffectWrite,
        default defaultValue: Result,
        _ effects: (EconomyRewardOwnerResolution) -> Result
    ) -> Result {
        plan.consume()
        guard plan.allowsDerivedEffects else { return defaultValue }
        return effects(plan.actor)
    }

    static func mapEconomy<Result>(
        plan: AuthorizedDomainEffectWrite,
        default defaultValue: Result,
        _ effects: (EconomyRewardOwnerResolution) -> Result
    ) -> Result {
        plan.consume()
        guard plan.allowsEconomyDerivation else { return defaultValue }
        return effects(plan.actor)
    }
}

private nonisolated extension AuthorizedDomainEffectWrite {
    func consume() {
        _ = token
        mutationPlan.consumeAuthorization()
    }
}
