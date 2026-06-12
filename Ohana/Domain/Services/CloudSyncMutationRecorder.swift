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
        _ event: Event,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: Event.self),
            localRecordId: event.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: uuid(from: event.relatedEntityId) ?? event.id,
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
        markPetScopedModified(PetCareLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
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

    @discardableResult
    static func markModified(
        _ log: PetPottyLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetPottyLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    static func markModified(
        _ logs: [PetPottyLog],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        markPetScopedModified(PetPottyLog.self, logs: logs.map { ($0.id, $0.pet?.id) }, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: PetHygieneLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetHygieneLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    static func markModified(
        _ logs: [PetHygieneLog],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        markPetScopedModified(PetHygieneLog.self, logs: logs.map { ($0.id, $0.pet?.id) }, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: PetHealthLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetHealthLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: PetWalkLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetWalkLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    static func markModified(
        _ logs: [PetWalkLog],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        markPetScopedModified(PetWalkLog.self, logs: logs.map { ($0.id, $0.pet?.id) }, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: PetExpenseLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetExpenseLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: PetWeightLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetWeightLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ record: PetFoodRecord,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetFoodRecord.self, id: record.id, petId: record.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ session: SharedCareSession,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: SharedCareSession.self),
            localRecordId: session.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: session.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ event: CareLedgerEvent,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: CareLedgerEvent.self),
            localRecordId: event.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: event.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    static func markModified(
        _ events: [CareLedgerEvent],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        guard !events.isEmpty else { return }
        let householdId = sharedHouseholdId(context: context, now: modifiedAt)
        for event in events {
            _ = markModified(
                entityName: String(describing: CareLedgerEvent.self),
                localRecordId: event.id,
                householdId: householdId,
                fallbackHouseholdId: event.id,
                modifiedAt: modifiedAt,
                context: context
            )
        }
    }

    static func markModified(
        _ logs: [PetExpenseLog],
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        markPetScopedModified(PetExpenseLog.self, logs: logs.map { ($0.id, $0.pet?.id) }, context: context, modifiedAt: modifiedAt)
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
        _ event: CareLedgerEvent,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: CareLedgerEvent.self),
            localRecordId: event.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: event.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
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
        _ event: Event,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: Event.self),
            localRecordId: event.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: uuid(from: event.relatedEntityId) ?? event.id,
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
        markPetScopedDeleted(
            PetCareLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetPottyLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetPottyLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetHygieneLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetHygieneLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetHealthLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetHealthLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetWalkLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetWalkLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetExpenseLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetExpenseLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PetWeightLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetWeightLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ record: PetFoodRecord,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetFoodRecord.self,
            id: record.id,
            petId: pet?.id ?? record.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ session: SharedCareSession,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        let entityName = String(describing: SharedCareSession.self)
        guard supportsSyncPipeline(for: entityName) else {
            return nil
        }

        let householdId = sharedHouseholdId(context: context, now: deletedAt)
        if let state = markDeleted(
            entityName: entityName,
            localRecordId: session.id,
            householdId: householdId,
            fallbackHouseholdId: session.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        ) {
            state.isDeleted = true
            state.isDeletionTombstone = true
            state.deletedAt = deletedAt
            state.deletedByHumanId = uuid(from: deletedByHumanId).map(CloudSyncRecordState.normalizedRecordId) ?? ""
            state.hasPendingLocalChanges = true
            return state
        }

        do {
            return try CloudSyncMetadataService.markDeleted(
                entityName: entityName,
                localRecordId: session.id,
                householdId: householdId ?? session.id,
                deletedAt: deletedAt,
                deletedByHumanId: uuid(from: deletedByHumanId),
                context: context
            )
        } catch {
            OhanaLog.warning(
                "Cloud sync failed to force mark deleted SharedCareSession:\(session.id): \(error)",
                category: "CloudSync"
            )
            return nil
        }
    }

    private static func markModified(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID?,
        fallbackHouseholdId: UUID? = nil,
        modifiedAt: Date,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        guard supportsSyncPipeline(for: entityName) else {
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
        guard supportsSyncPipeline(for: entityName) else {
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

    private static func supportsSyncPipeline(for entityName: String) -> Bool {
        CloudSyncEntityRegistry.descriptor(for: entityName)?.uploadsToCloudKit == true
            && CloudSyncEntityRegistry.supportsUploadPipeline(for: entityName)
    }

    private static func markPetScopedModified<T>(
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

    private static func markPetScopedModified<T>(
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

    private static func markPetScopedDeleted<T>(
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
