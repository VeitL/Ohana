//
//  DomainGeneralRehydrateWriter+Authorization.swift
//  Ohana
//
//  Subject authorization helpers for general restore/cloud rehydrate writes.
//

import Foundation
import SwiftData

extension DomainGeneralRehydrateWriter {
    nonisolated static func authorizePet(_ id: UUID, source: DomainRehydrateSourceKind, context: ModelContext) -> AuthorizedDomainRehydratePlan {
        DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: id.uuidString
            ),
            source: source,
            context: context
        )
    }

    nonisolated static func authorizeHuman(_ id: UUID, source: DomainRehydrateSourceKind, context: ModelContext) -> AuthorizedDomainRehydratePlan {
        authorizeHumanString(id.uuidString, source: source, context: context)
    }

    nonisolated static func authorizeHumanString(
        _ id: String,
        assigneeId: String? = nil,
        source: DomainRehydrateSourceKind,
        context: ModelContext,
        requirement: DomainRehydrateSubjectRequirement = .historyCompatible
    ) -> AuthorizedDomainRehydratePlan {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = trimmed.isEmpty
            ? DomainSubjectResolutionRequest(assigneeId: assigneeId)
            : DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: trimmed,
                assigneeId: assigneeId
            )
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: request,
            source: source,
            context: context,
            requirement: requirement
        )
    }

    nonisolated static func authorizePetRelationship(
        snapshot: DomainPetRelationshipRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> AuthorizedDomainRehydratePlan {
        guard try fetchPet(id: snapshot.toPetId, context: context) != nil else {
            return DomainRehydrateAuthorizer.rejectSubject(source: source, reason: "unresolvedRelationshipTargetPet")
        }
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: snapshot.fromPetId.uuidString
            ),
            source: source,
            context: context,
            requirement: .requiredPet
        )
    }

    nonisolated static func authorizeEconomyBudgetUsageEvent(
        snapshot: DomainEconomyBudgetUsageEventRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> AuthorizedDomainRehydratePlan {
        if let petId = try firstResolvablePetId(
            rawIds: [snapshot.careObjectKey, snapshot.scopeKey],
            context: context
        ) {
            return DomainRehydrateAuthorizer.authorizeSubject(
                request: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: petId.uuidString
                ),
                source: source,
                context: context,
                requirement: .requiredPet
            )
        }
        if let humanId = try firstResolvableHumanId(
            rawIds: [snapshot.memberKey, snapshot.scopeKey],
            context: context
        ) {
            return authorizeHumanString(
                humanId.uuidString,
                source: source,
                context: context,
                requirement: .requiredHuman
            )
        }
        return authorizeHousehold(source: source, context: context)
    }

    nonisolated static func authorizeWallet(
        ownerKindRaw: String,
        ownerId: String,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        guard let ownerKind = CoconutWalletOwnerKind(rawValue: ownerKindRaw) else {
            return DomainRehydrateAuthorizer.rejectSubject(source: source, reason: "invalidWalletOwnerKind")
        }
        switch ownerKind {
        case .pet:
            return DomainRehydrateAuthorizer.authorizeSubject(
                request: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: ownerId
                ),
                source: source,
                context: context,
                requirement: .requiredPet
            )
        case .human:
            return authorizeHumanString(ownerId, source: source, context: context, requirement: .requiredHuman)
        case .system:
            return authorizeHousehold(source: source, context: context)
        }
    }

    nonisolated static func authorizeLedger(
        snapshot: DomainCoconutLedgerEntryRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        authorizeWallet(ownerKindRaw: snapshot.ownerKindRaw, ownerId: snapshot.ownerId, source: source, context: context)
    }

    nonisolated static func authorizeFamilyTask(
        snapshot: DomainFamilyCollaborationTaskRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        if let relatedPetId = snapshot.relatedPetId, !relatedPetId.isEmpty {
            return DomainRehydrateAuthorizer.authorizeSubject(
                request: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: relatedPetId,
                    assigneeId: snapshot.assignedToId
                ),
                source: source,
                context: context,
                requirement: .requiredPet
            )
        }
        return authorizeHumanString(
            snapshot.createdById,
            assigneeId: snapshot.assignedToId,
            source: source,
            context: context,
            requirement: .requiredHuman
        )
    }

    nonisolated static func authorizeHousehold(
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(),
            source: source,
            context: context,
            requirement: .household
        )
    }

    nonisolated static func firstResolvablePetId(rawIds: [String], context: ModelContext) throws -> UUID? {
        let candidateIds = rawIds.compactMap { UUID(uuidString: $0) }
        for candidateId in candidateIds where try fetchPet(id: candidateId, context: context) != nil {
            return candidateId
        }
        return nil
    }

    nonisolated static func firstResolvableHumanId(rawIds: [String], context: ModelContext) throws -> UUID? {
        let candidateIds = rawIds.compactMap { UUID(uuidString: $0) }
        for candidateId in candidateIds where try fetchHuman(id: candidateId, context: context) != nil {
            return candidateId
        }
        return nil
    }
}
