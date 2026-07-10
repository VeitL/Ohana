//
//  CloudSyncMutationRecorder+Helpers.swift
//  Ohana
//

import Foundation
import SwiftData

nonisolated extension CloudSyncMutationRecorder {
    static func supportsLocalMutationRecording(for entityName: String) -> Bool {
        AppCapabilityProfile.permitsCloudSyncDirtyWrites &&
            CloudSyncEntityRegistry.descriptor(for: entityName)?.uploadsToCloudKit == true
    }

    static func markPetScopedModified<T>(
        _: T.Type,
        id: UUID,
        petId: UUID?,
        context: ModelContext,
        modifiedAt: Date
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: T.self),
            localRecordId: id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: petId ?? id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    static func markPetScopedModified<T>(
        _: T.Type,
        logs: [(id: UUID, petId: UUID?)],
        context: ModelContext,
        modifiedAt: Date
    ) {
        guard !logs.isEmpty else { return }
        let householdId = sharedHouseholdId(context: context, now: modifiedAt)
        for log in logs {
            _ = markModified(
                entityName: String(describing: T.self),
                localRecordId: log.id,
                householdId: householdId,
                fallbackHouseholdId: log.petId ?? log.id,
                modifiedAt: modifiedAt,
                context: context
            )
        }
    }

    static func markPetScopedDeleted<T>(
        _: T.Type,
        id: UUID,
        petId: UUID?,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: T.self),
            localRecordId: id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: petId ?? id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    static func markHumanScopedModified<T>(
        _: T.Type,
        id: UUID,
        humanId: String,
        context: ModelContext,
        modifiedAt: Date
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: T.self),
            localRecordId: id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: uuid(from: humanId) ?? id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    static func markHumanScopedDeleted<T>(
        _: T.Type,
        id: UUID,
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: T.self),
            localRecordId: id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: uuid(from: humanId) ?? id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    static func sharedHouseholdId(context: ModelContext, now: Date) -> UUID? {
        guard AppCapabilityProfile.permitsCloudSyncDirtyWrites else {
            return nil
        }

        do {
            var descriptor = FetchDescriptor<Household>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                return existing.id
            }

            let household = Household()
            household.createdAt = now
            context.insert(household)
            try CloudSyncMetadataService.markModified(
                entityName: String(describing: Household.self),
                localRecordId: household.id,
                householdId: household.id,
                modifiedAt: now,
                context: context
            )
            return household.id
        } catch {
            OhanaLog.warning(
                "Cloud sync failed to resolve local household zone: \(error)",
                category: "CloudSync"
            )
            return nil
        }
    }

    static func uuid(from rawValue: String?) -> UUID? {
        guard let rawValue else { return nil }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
