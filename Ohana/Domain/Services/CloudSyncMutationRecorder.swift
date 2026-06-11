//
//  CloudSyncMutationRecorder.swift
//  Ohana
//
//  Local write hooks that enqueue supported SwiftData facts for CKSyncEngine.
//

import Foundation
import SwiftData

@MainActor
enum CloudSyncMutationRecorder {
    @discardableResult
    static func markModified(
        _ household: Household,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            householdId: household.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ pet: Pet,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: pet.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ human: Human,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: Human.self),
            localRecordId: human.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: human.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ log: PetCareLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: PetCareLog.self),
            localRecordId: log.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: log.pet?.id ?? log.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    static func markModified(
        _ logs: [PetCareLog],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        guard !logs.isEmpty else { return }
        let householdId = sharedHouseholdId(context: context, now: modifiedAt)
        for log in logs {
            _ = markModified(
                entityName: String(describing: PetCareLog.self),
                localRecordId: log.id,
                householdId: householdId,
                fallbackHouseholdId: log.pet?.id ?? log.id,
                modifiedAt: modifiedAt,
                context: context
            )
        }
    }

    static func markModified(
        _ entries: [CoconutLedgerEntry],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        guard !entries.isEmpty else { return }
        let householdId = sharedHouseholdId(context: context, now: modifiedAt)
        for entry in entries {
            _ = markModified(
                entityName: String(describing: CoconutLedgerEntry.self),
                localRecordId: entry.id,
                householdId: householdId,
                fallbackHouseholdId: entry.id,
                modifiedAt: entry.occurredAt,
                context: context
            )
        }
    }

    @discardableResult
    static func markDeleted(
        _ pet: Pet,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: pet.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ human: Human,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: Human.self),
            localRecordId: human.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: human.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetCareLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: PetCareLog.self),
            localRecordId: log.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: pet?.id ?? log.pet?.id ?? log.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    private static func markModified(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID?,
        fallbackHouseholdId: UUID? = nil,
        modifiedAt: Date,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        guard CloudSyncEntityRegistry.descriptor(for: entityName)?.uploadsToCloudKit == true else {
            return nil
        }
        do {
            return try CloudSyncMetadataService.markModified(
                entityName: entityName,
                localRecordId: localRecordId,
                householdId: householdId ?? fallbackHouseholdId ?? localRecordId,
                modifiedAt: modifiedAt,
                context: context
            )
        } catch {
            OhanaLog.warning(
                "Cloud sync failed to mark modified \(entityName):\(localRecordId): \(error)",
                category: "CloudSync"
            )
            return nil
        }
    }

    private static func markDeleted(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID?,
        fallbackHouseholdId: UUID? = nil,
        deletedAt: Date,
        deletedByHumanId: UUID?,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        guard CloudSyncEntityRegistry.descriptor(for: entityName)?.uploadsToCloudKit == true else {
            return nil
        }
        do {
            return try CloudSyncMetadataService.markDeleted(
                entityName: entityName,
                localRecordId: localRecordId,
                householdId: householdId ?? fallbackHouseholdId ?? localRecordId,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId,
                context: context
            )
        } catch {
            OhanaLog.warning(
                "Cloud sync failed to mark deleted \(entityName):\(localRecordId): \(error)",
                category: "CloudSync"
            )
            return nil
        }
    }

    private static func sharedHouseholdId(context: ModelContext, now: Date) -> UUID? {
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

    private static func uuid(from rawValue: String?) -> UUID? {
        guard let rawValue else { return nil }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
