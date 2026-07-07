//
//  PhysicalDeletionService+Utilities.swift
//  Ohana
//
//  Shared helpers for irreversible local deletion boundaries.
//

import Foundation
import SwiftData

extension PhysicalDeletionService {
    @discardableResult
    nonisolated static func deleteEvents(
        _ events: [Event],
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let uniqueEvents = unique(events, by: \.id)
        for event in uniqueEvents {
            _ = deleteEvent(
                event,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId,
                notifications: notifications
            )
        }
        return uniqueEvents.count
    }

    @discardableResult
    nonisolated static func deletePetRelationships(
        petId: UUID,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        let petIdString = petId.uuidString
        return deleteRows(fetchAll(PetRelationship.self, context: context).filter { relationship in
            relationship.fromPetId == petId || relationship.toPetId == petId
        }, context: context) {
            markGenericDeleted(
                entityName: String(describing: PetRelationship.self),
                localRecordId: $0.id,
                parentId: petIdString,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    @discardableResult
    nonisolated static func deleteFamilyTasksReferencingPet(
        petId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        deleteRows(fetchAll(FamilyCollaborationTask.self, context: context).filter { task in
            idsMatch(task.relatedPetId, petId)
        }, context: context) {
            markGenericDeleted(
                entityName: String(describing: FamilyCollaborationTask.self),
                localRecordId: $0.id,
                parentId: petId,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    @discardableResult
    nonisolated static func scrubSharedCareSessionsReferencingPet(
        petId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        var changedCount = 0
        for session in fetchAll(SharedCareSession.self, context: context) {
            guard idsMatch(session.sourcePetId, petId) ||
                idsMatch(session.stockOwnerPetId, petId) ||
                session.targetPetIds.contains(where: { idsMatch($0, petId) }) else {
                continue
            }

            let hadDeletedStockOwner = idsMatch(session.stockOwnerPetId, petId)
            let sessionID = session.id
            SharedCareSessionMaintenance.reconcile(session, context: context, reconciledAt: deletedAt)
            guard fetchAll(SharedCareSession.self, context: context).contains(where: { $0.id == sessionID }) else {
                changedCount += 1
                continue
            }

            let originalTargets = session.targetPetIds
            let filteredTargets = originalTargets.filter { !idsMatch($0, petId) }
            var changed = filteredTargets.count != originalTargets.count

            if idsMatch(session.sourcePetId, petId) {
                session.sourcePetId = ""
                changed = true
            }
            if hadDeletedStockOwner || idsMatch(session.stockOwnerPetId, petId) {
                session.stockOwnerPetId = ""
                changed = true
            }
            if filteredTargets.isEmpty && changed {
                CloudSyncMutationRecorder.markDeleted(
                    session,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
                context.delete(session)
                changedCount += 1
                continue
            }
            guard changed else { continue }
            session.targetPetIdsRaw = filteredTargets.joined(separator: "|")
            CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: deletedAt)
            changedCount += 1
        }
        return changedCount
    }

    @discardableResult
    nonisolated static func scrubSharedCareSessionsReferencingHuman(
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        var changedCount = 0
        for session in fetchAll(SharedCareSession.self, context: context) {
            let originalExecutors = session.executorIds
            let filteredExecutors = originalExecutors.filter { !idsMatch($0, humanId) }
            guard filteredExecutors.count != originalExecutors.count else { continue }
            if filteredExecutors.isEmpty {
                changedCount += scrubSharedCareChildrenReferencingSession(
                    session,
                    deletedHumanId: humanId,
                    remainingExecutorIds: [],
                    clearsSessionLink: true,
                    context: context,
                    modifiedAt: deletedAt
                )
                CloudSyncMutationRecorder.markDeleted(
                    session,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
                context.delete(session)
                changedCount += 1
                continue
            }
            session.setExecutorIds(filteredExecutors, primaryExecutorId: filteredExecutors.first)
            changedCount += scrubSharedCareChildrenReferencingSession(
                session,
                deletedHumanId: humanId,
                remainingExecutorIds: filteredExecutors,
                clearsSessionLink: false,
                context: context,
                modifiedAt: deletedAt
            )
            CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: deletedAt)
            changedCount += 1
        }
        return changedCount
    }

    nonisolated static func referencesPet(_ event: CareLedgerEvent, petId: String) -> Bool {
        idsMatch(event.actorId, petId) || idsMatch(event.subjectId, petId)
    }

    nonisolated static func referencesHuman(_ event: CareLedgerEvent, humanId: String) -> Bool {
        idsMatch(event.actorId, humanId) || idsMatch(event.subjectId, humanId)
    }

    nonisolated static func referencesPet(_ event: EconomyBudgetUsageEvent, petId: String) -> Bool {
        idsMatch(event.careObjectKey, petId) || idsMatch(event.scopeKey, petId)
    }

    nonisolated static func referencesHuman(_ event: EconomyBudgetUsageEvent, humanId: String) -> Bool {
        idsMatch(event.memberKey, humanId) || idsMatch(event.scopeKey, humanId)
    }

    nonisolated static func referencesHuman(_ task: FamilyCollaborationTask, humanId: String) -> Bool {
        idsMatch(task.createdById, humanId) ||
            idsMatch(task.assignedToId, humanId) ||
            idsMatch(task.claimedById, humanId) ||
            idsMatch(task.completedById, humanId)
    }

    nonisolated static func idsMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        let left = CloudSyncRecordState.normalizedRecordId(lhs)
        let right = CloudSyncRecordState.normalizedRecordId(rhs)
        return !left.isEmpty && left == right
    }

    nonisolated static func deleteRows<T: PersistentModel>(
        _ rows: [T],
        context: ModelContext,
        markDeleted: (T) -> Void
    ) -> Int {
        for row in rows {
            markDeleted(row)
            context.delete(row)
        }
        return rows.count
    }

    struct CareLedgerDeletionContext {
        let deletedOwnerKind: CareLedgerSubjectKind?
        let deletedOwnerId: String?
        let deletedLegacyModelName: String?
        let deletedLegacyModelId: String?
        let reason: String
        let deletedAt: Date
        let deletedByHumanId: String?
    }

    @discardableResult
    nonisolated static func deleteOrRetainCareLedgerEvents(
        _ events: [CareLedgerEvent],
        context: ModelContext,
        deletionContext: (CareLedgerEvent) -> CareLedgerDeletionContext
    ) -> Int {
        let uniqueEvents = unique(events, by: \.id)
        for event in uniqueEvents {
            let contextForEvent = deletionContext(event)
            if shouldRetainEconomicCareLedger(event) {
                retainEconomicCareLedger(
                    event,
                    context: context,
                    deletionContext: contextForEvent
                )
            } else {
                CloudSyncMutationRecorder.markDeleted(
                    event,
                    context: context,
                    deletedAt: contextForEvent.deletedAt,
                    deletedByHumanId: contextForEvent.deletedByHumanId
                )
                context.delete(event)
            }
        }
        return uniqueEvents.count
    }

    private nonisolated static func shouldRetainEconomicCareLedger(_ event: CareLedgerEvent) -> Bool {
        event.coconutDelta != 0 || event.rewardLogId?.isEmpty == false
    }

    private nonisolated static func retainEconomicCareLedger(
        _ event: CareLedgerEvent,
        context: ModelContext,
        deletionContext: CareLedgerDeletionContext
    ) {
        let originalActorKind = event.actorKind
        let originalSubjectKind = event.subjectKind
        let originalLegacyModelName = event.legacyModelName
        event.note = ""

        if let deletedOwnerId = deletionContext.deletedOwnerId {
            if idsMatch(event.actorId, deletedOwnerId) {
                event.actorKind = CareLedgerActorKind.unknown.rawValue
                event.actorId = nil
            }
            if idsMatch(event.subjectId, deletedOwnerId) {
                event.subjectKind = CareLedgerSubjectKind.unknown.rawValue
                event.subjectId = nil
            }
        }

        if let deletedLegacyModelName = deletionContext.deletedLegacyModelName,
           let deletedLegacyModelId = deletionContext.deletedLegacyModelId,
           event.legacyModelName == deletedLegacyModelName,
           idsMatch(event.legacyModelId, deletedLegacyModelId) {
            event.legacyModelName = nil
            event.legacyModelId = nil
        }

        event.metadataJSON = retainedEconomicCareLedgerMetadata(
            existingMetadataJSON: event.metadataJSON,
            reason: deletionContext.reason,
            deletedOwnerKind: deletionContext.deletedOwnerKind?.rawValue,
            deletedAt: deletionContext.deletedAt,
            originalActorKind: originalActorKind,
            originalSubjectKind: originalSubjectKind,
            originalLegacyModelName: originalLegacyModelName
        )
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: deletionContext.deletedAt)
    }

    @discardableResult
    nonisolated static func scrubCoconutLedgerEntriesReferencingDeletedOwner(
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        subjectKind: CareLedgerSubjectKind,
        legacyModelIds: Set<String> = [],
        reason: String,
        context: ModelContext,
        modifiedAt: Date
    ) -> Int {
        let entries = fetchAll(CoconutLedgerEntry.self, context: context).filter { entry in
            idsMatch(entry.ownerId, ownerId) ||
                idsMatch(entry.actorId, ownerId) ||
                idsMatch(entry.subjectId, ownerId) ||
                legacyModelIds.containsNormalized(entry.sourceModelId)
        }
        guard !entries.isEmpty else { return 0 }

        for entry in entries {
            let originalOwnerKind = entry.ownerKindRaw
            let originalSubjectKind = entry.subjectKindRaw
            let originalSourceModelName = entry.sourceModelName

            if idsMatch(entry.ownerId, ownerId) && entry.ownerKind == ownerKind {
                entry.ownerKindRaw = CoconutWalletOwnerKind.system.rawValue
                entry.ownerId = ""
                entry.ownerName = ""
            }
            if idsMatch(entry.actorId, ownerId) {
                entry.actorId = nil
                entry.actorName = nil
            }
            if idsMatch(entry.subjectId, ownerId) {
                entry.subjectKindRaw = CareLedgerSubjectKind.unknown.rawValue
                entry.subjectId = nil
            }
            if legacyModelIds.containsNormalized(entry.sourceModelId) {
                entry.sourceModelName = ""
                entry.sourceModelId = ""
            }

            entry.metadataJSON = retainedCoconutLedgerMetadata(
                existingMetadataJSON: entry.metadataJSON,
                reason: reason,
                deletedOwnerKind: subjectKind.rawValue,
                deletedAt: modifiedAt,
                originalOwnerKind: originalOwnerKind,
                originalSubjectKind: originalSubjectKind,
                originalSourceModelName: originalSourceModelName
            )
        }

        CloudSyncMutationRecorder.markModified(entries, context: context, modifiedAt: modifiedAt)
        return entries.count
    }

    private nonisolated static func retainedEconomicCareLedgerMetadata(
        existingMetadataJSON: String,
        reason: String,
        deletedOwnerKind: String?,
        deletedAt: Date,
        originalActorKind: String,
        originalSubjectKind: String,
        originalLegacyModelName: String?
    ) -> String {
        var payload: [String: Any] = [
            "deletedOwnerRetention": true,
            "retentionReason": reason,
            "retainedAt": deletedAt.timeIntervalSince1970,
            "originalActorKind": originalActorKind,
            "originalSubjectKind": originalSubjectKind
        ]
        if let deletedOwnerKind {
            payload["deletedOwnerKind"] = deletedOwnerKind
        }
        if let originalLegacyModelName {
            payload["originalLegacyModelName"] = originalLegacyModelName
        }
        if !existingMetadataJSON.isEmpty,
           let data = existingMetadataJSON.data(using: .utf8),
           let existingPayload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["previousMetadata"] = existingPayload
        } else if !existingMetadataJSON.isEmpty {
            payload["previousMetadataRaw"] = existingMetadataJSON
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"deletedOwnerRetention\":true,\"retentionReason\":\"\(reason)\"}"
        }
        return json
    }

    private nonisolated static func retainedCoconutLedgerMetadata(
        existingMetadataJSON: String,
        reason: String,
        deletedOwnerKind: String,
        deletedAt: Date,
        originalOwnerKind: String,
        originalSubjectKind: String,
        originalSourceModelName: String
    ) -> String {
        var payload: [String: Any] = [
            "deletedOwnerRetention": true,
            "retentionReason": reason,
            "retainedAt": deletedAt.timeIntervalSince1970,
            "deletedOwnerKind": deletedOwnerKind,
            "originalOwnerKind": originalOwnerKind,
            "originalSubjectKind": originalSubjectKind,
            "originalSourceModelName": originalSourceModelName
        ]
        if !existingMetadataJSON.isEmpty,
           let data = existingMetadataJSON.data(using: .utf8),
           let existingPayload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["previousMetadata"] = existingPayload
        } else if !existingMetadataJSON.isEmpty {
            payload["previousMetadataRaw"] = existingMetadataJSON
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"deletedOwnerRetention\":true,\"retentionReason\":\"\(reason)\"}"
        }
        return json
    }

    @discardableResult
    nonisolated static func retireWalletAccounts(
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        context: ModelContext,
        deletedAt: Date
    ) -> Int {
        let accounts = fetchAll(CoconutAccount.self, context: context).filter { account in
            account.ownerKind == ownerKind && idsMatch(account.ownerId, ownerId)
        }
        for account in accounts {
            account.balance = 0
            account.updatedAt = deletedAt
            CoconutWalletAccountLifecycleMetadata.markDeletedOwner(account, deletedAt: deletedAt)
            CloudSyncMutationRecorder.markModified(account, context: context, modifiedAt: deletedAt)
        }
        return accounts.count
    }

    nonisolated static func markGenericDeleted(
        entityName: String,
        localRecordId: UUID,
        parentId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        _ = CloudSyncMutationRecorder.markDeleted(
            entityName: entityName,
            localRecordId: localRecordId,
            householdId: CloudSyncMutationRecorder.sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: CloudSyncMutationRecorder.uuid(from: parentId),
            deletedAt: deletedAt,
            deletedByHumanId: CloudSyncMutationRecorder.uuid(from: deletedByHumanId),
            context: context
        )
    }

    nonisolated static func fetchAll<T: PersistentModel>(_: T.Type, context: ModelContext) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            OhanaLog.warning("PhysicalDeletionService failed to fetch \(T.self): \(error.localizedDescription)", category: "Care")
            return []
        }
    }

    nonisolated static func unique<T, ID: Hashable>(_ values: [T], by keyPath: KeyPath<T, ID>) -> [T] {
        var seen: Set<ID> = []
        return values.filter { seen.insert($0[keyPath: keyPath]).inserted }
    }

    nonisolated static func reconcileWalletAfterEconomyDeletion(context: ModelContext) {
        _ = CoconutWalletService.reconcileFormalAccountBalancesWithLedger(context: context, saveChanges: false)
    }
}

extension Set<String> {
    nonisolated func containsNormalized(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalizedValue = CloudSyncRecordState.normalizedRecordId(value)
        return contains { CloudSyncRecordState.normalizedRecordId($0) == normalizedValue }
    }
}
