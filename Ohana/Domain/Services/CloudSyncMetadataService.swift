//
//  CloudSyncMetadataService.swift
//  Ohana
//
//  Phase 0 sync-readiness helpers for local SwiftData + CKSyncEngine.
//

import Foundation
import SwiftData

nonisolated enum CloudSyncMergePolicy {
    static func defaultConflictPolicy(for entityName: String) -> CloudSyncConflictPolicy {
        CloudSyncEntityRegistry.defaultConflictPolicy(for: entityName)
    }

    static func conflictPolicy(entityName: String, fieldName: String) -> CloudSyncConflictPolicy {
        CloudSyncEntityRegistry.conflictPolicy(entityName: entityName, fieldName: fieldName)
    }
}

nonisolated enum CloudSyncMetadataService {
    static func state(
        entityName: String,
        localRecordId: UUID,
        context: ModelContext
    ) throws -> CloudSyncRecordState? {
        try state(
            recordKey: CloudSyncRecordState.recordKey(entityName: entityName, localRecordId: localRecordId),
            context: context
        )
    }

    @discardableResult
    static func markModified(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID? = nil,
        modifiedAt: Date = Date(),
        conflictPolicy: CloudSyncConflictPolicy? = nil,
        metadataJSON: String = "",
        context: ModelContext
    ) throws -> CloudSyncRecordState {
        let normalizedEntityName = CloudSyncRecordState.normalizedEntityName(entityName)
        let policy = conflictPolicy ?? CloudSyncMergePolicy.defaultConflictPolicy(for: normalizedEntityName)
        let recordKey = CloudSyncRecordState.recordKey(entityName: normalizedEntityName, localRecordId: localRecordId)

        let existingStates = try states(recordKey: recordKey, context: context)
        if let existing = existingStates.first {
            deleteDuplicateStates(existingStates, keeping: existing, context: context)
            existing.householdId = normalizedHouseholdId(householdId) ?? existing.householdId
            existing.conflictPolicy = policy
            existing.isDeleted = false
            existing.isDeletionTombstone = false
            existing.deletedAt = nil
            existing.deletedByHumanId = ""
            existing.hasPendingLocalChanges = true
            existing.lastModifiedAt = modifiedAt
            existing.updatedAt = modifiedAt
            if !metadataJSON.isEmpty {
                existing.metadataJSON = metadataJSON
            }
            return existing
        }

        let state = CloudSyncRecordState(
            entityName: normalizedEntityName,
            localRecordId: localRecordId,
            householdId: householdId,
            conflictPolicy: policy,
            hasPendingLocalChanges: true,
            lastModifiedAt: modifiedAt,
            createdAt: modifiedAt,
            updatedAt: modifiedAt,
            metadataJSON: metadataJSON
        )
        context.insert(state)
        return state
    }

    @discardableResult
    static func markDeleted(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID? = nil,
        deletedAt: Date = Date(),
        deletedByHumanId: UUID? = nil,
        conflictPolicy: CloudSyncConflictPolicy? = nil,
        metadataJSON: String = "",
        context: ModelContext
    ) throws -> CloudSyncRecordState {
        let normalizedEntityName = CloudSyncRecordState.normalizedEntityName(entityName)
        let policy = conflictPolicy ?? CloudSyncMergePolicy.defaultConflictPolicy(for: normalizedEntityName)
        let recordKey = CloudSyncRecordState.recordKey(entityName: normalizedEntityName, localRecordId: localRecordId)

        let existingStates = try states(recordKey: recordKey, context: context)
        if let existing = existingStates.first {
            deleteDuplicateStates(existingStates, keeping: existing, context: context)
            existing.householdId = normalizedHouseholdId(householdId) ?? existing.householdId
            existing.conflictPolicy = policy
            existing.isDeleted = true
            existing.isDeletionTombstone = true
            existing.deletedAt = deletedAt
            existing.deletedByHumanId = deletedByHumanId.map(CloudSyncRecordState.normalizedRecordId) ?? ""
            existing.hasPendingLocalChanges = true
            existing.lastModifiedAt = deletedAt
            existing.updatedAt = deletedAt
            if !metadataJSON.isEmpty {
                existing.metadataJSON = metadataJSON
            }
            return existing
        }

        let state = CloudSyncRecordState(
            entityName: normalizedEntityName,
            localRecordId: localRecordId,
            householdId: householdId,
            conflictPolicy: policy,
            isDeleted: true,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            hasPendingLocalChanges: true,
            lastModifiedAt: deletedAt,
            createdAt: deletedAt,
            updatedAt: deletedAt,
            metadataJSON: metadataJSON
        )
        context.insert(state)
        return state
    }

    static func markSynced(
        _ state: CloudSyncRecordState,
        ckRecordName: String,
        ckChangeTag: String,
        ckZoneName: String,
        syncedAt: Date = Date()
    ) {
        state.ckRecordName = ckRecordName
        state.ckChangeTag = ckChangeTag
        state.ckZoneName = ckZoneName
        state.hasPendingLocalChanges = false
        state.lastSyncedAt = syncedAt
        state.updatedAt = syncedAt
    }

    static func dirtyStates(context: ModelContext) throws -> [CloudSyncRecordState] {
        let descriptor = FetchDescriptor<CloudSyncRecordState>(
            predicate: #Predicate<CloudSyncRecordState> { $0.hasPendingLocalChanges },
            sortBy: [SortDescriptor(\.lastModifiedAt)]
        )
        return try context.fetch(descriptor)
    }

    static func state(
        recordKey: String,
        context: ModelContext
    ) throws -> CloudSyncRecordState? {
        let matchedStates = try states(recordKey: recordKey, context: context)
        guard let canonical = matchedStates.first else { return nil }
        deleteDuplicateStates(matchedStates, keeping: canonical, context: context)
        return canonical
    }

    static func state(
        entityName: String,
        ckRecordName: String,
        ckZoneName: String,
        context: ModelContext
    ) throws -> CloudSyncRecordState? {
        let normalizedEntityName = CloudSyncRecordState.normalizedEntityName(entityName)
        let trimmedRecordName = ckRecordName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedZoneName = ckZoneName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecordName.isEmpty, !trimmedZoneName.isEmpty else {
            return nil
        }
        let matchedStates = try states(
            entityName: normalizedEntityName,
            ckRecordName: trimmedRecordName,
            ckZoneName: trimmedZoneName,
            context: context
        )
        guard let canonical = matchedStates.first else { return nil }
        deleteDuplicateStates(matchedStates, keeping: canonical, context: context)
        return canonical
    }

    private static func normalizedHouseholdId(_ householdId: UUID?) -> String? {
        householdId.map(CloudSyncRecordState.normalizedRecordId)
    }

    private static func states(
        recordKey: String,
        context: ModelContext
    ) throws -> [CloudSyncRecordState] {
        let descriptor = FetchDescriptor<CloudSyncRecordState>(
            predicate: #Predicate<CloudSyncRecordState> { $0.recordKey == recordKey },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.lastModifiedAt, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }

    private static func states(
        entityName: String,
        ckRecordName: String,
        ckZoneName: String,
        context: ModelContext
    ) throws -> [CloudSyncRecordState] {
        let descriptor = FetchDescriptor<CloudSyncRecordState>(
            predicate: #Predicate<CloudSyncRecordState> {
                $0.entityName == entityName &&
                    $0.ckRecordName == ckRecordName &&
                    $0.ckZoneName == ckZoneName
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.lastModifiedAt, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }

    private static func deleteDuplicateStates(
        _ states: [CloudSyncRecordState],
        keeping canonical: CloudSyncRecordState,
        context: ModelContext
    ) {
        for state in states where state.id != canonical.id {
            context.delete(state)
        }
    }
}
