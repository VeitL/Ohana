//
//  CloudSyncRecordApplier+Deletion.swift
//  Ohana
//
//  Split helpers for applying CloudKit records into SwiftData.
//

import CloudKit
import Foundation
import SwiftData

extension CloudSyncRecordApplier {
    nonisolated static func deleteLocalModel(metadata: RemoteMetadata, context: ModelContext) throws {
        try deleteLocalModel(
            entityName: metadata.entityName,
            localRecordUUID: metadata.localRecordUUID,
            deletedAt: metadata.deletedAt ?? metadata.lastModifiedAt,
            deletedByHumanId: normalizedDeletionActorId(metadata.deletedByHumanId),
            context: context
        )
    }

    nonisolated static func deleteLocalModel(
        entityName: String,
        localRecordUUID: UUID,
        deletedAt: Date,
        deletedByHumanId: String?,
        context: ModelContext
    ) throws {
        switch entityName {
        case String(describing: Household.self):
            try deleteHousehold(id: localRecordUUID, context: context)
        case String(describing: Pet.self):
            if let model = try fetchPet(id: localRecordUUID, context: context) {
                PhysicalDeletionService.deletePet(
                    model,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: Human.self):
            if let model = try fetchHuman(id: localRecordUUID, context: context) {
                PhysicalDeletionService.deleteHuman(
                    model,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: Event.self):
            if let model = try fetchEvent(id: localRecordUUID, context: context) {
                PhysicalDeletionService.deleteEvent(
                    model,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetCareLog.self):
            if let model = try fetchPetCareLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetPottyLog.self):
            if let model = try fetchPetPottyLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetHygieneLog.self):
            if let model = try fetchPetHygieneLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetHealthLog.self):
            if let model = try fetchPetHealthLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetWalkLog.self):
            if let model = try fetchPetWalkLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetExpenseLog.self):
            if let model = try fetchPetExpenseLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetFoodRecord.self):
            if let model = try fetchPetFoodRecord(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetWeightLog.self),
             String(describing: SymptomLog.self),
             String(describing: HeatCycleLog.self):
            try deletePetObservationRecord(
                entityName, id: localRecordUUID, deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId, context: context
            )
        case String(describing: SharedCareSession.self):
            if let model = try fetchSharedCareSession(id: localRecordUUID, context: context) {
                try SharedCareSessionMaintenance.deleteCascade(
                    model,
                    context: context,
                    deletedByHumanId: deletedByHumanId,
                    deletedAt: deletedAt
                )
            }
        case String(describing: CareLedgerEvent.self):
            try deleteCareLedgerEvent(id: localRecordUUID, context: context)
        case String(describing: CoconutLedgerEntry.self):
            // CoconutLedgerEntry is append-only. A remote tombstone should mark
            // sync state only; removing local history would corrupt replay and
            // make balances jump without an explicit reversal entry.
            break
        case String(describing: GachaOwnedItem.self):
            try deleteGachaOwnedItem(id: localRecordUUID, context: context)
        case String(describing: GachaDrawLog.self):
            try deleteGachaDrawLog(id: localRecordUUID, context: context)
        case String(describing: ShopPurchaseRecord.self):
            try deleteShopPurchaseRecord(id: localRecordUUID, context: context)
        default:
            break
        }
    }

    private nonisolated static func deletePetObservationRecord(
        _ entityName: String,
        id: UUID,
        deletedAt: Date,
        deletedByHumanId: String?,
        context: ModelContext
    ) throws {
        let model: (record: any PersistentModel, pet: Pet?)? = switch entityName {
        case String(describing: PetWeightLog.self):
            try fetchPetWeightLog(id: id, context: context).map { ($0, $0.pet) }
        case String(describing: SymptomLog.self):
            try fetchSymptomLog(id: id, context: context).map { ($0, $0.pet) }
        case String(describing: HeatCycleLog.self):
            try fetchHeatCycleLog(id: id, context: context).map { ($0, $0.pet) }
        default:
            nil
        }
        guard let model else { return }
        deletePetScopedRecord(
            model.record,
            pet: model.pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    private nonisolated static func deleteHousehold(id: UUID, context: ModelContext) throws {
        if let model = try fetchHousehold(id: id, context: context) {
            context.delete(model)
        }
    }

    private nonisolated static func deleteCareLedgerEvent(id: UUID, context: ModelContext) throws {
        if let model = try fetchCareLedgerEvent(id: id, context: context) {
            context.delete(model)
        }
    }

    private nonisolated static func deleteGachaOwnedItem(id: UUID, context: ModelContext) throws {
        if let model = try fetchGachaOwnedItem(id: id, context: context) {
            context.delete(model)
        }
    }

    private nonisolated static func deleteGachaDrawLog(id: UUID, context: ModelContext) throws {
        if let model = try fetchGachaDrawLog(id: id, context: context) {
            context.delete(model)
        }
    }

    private nonisolated static func deleteShopPurchaseRecord(id: UUID, context: ModelContext) throws {
        if let model = try fetchShopPurchaseRecord(id: id, context: context) {
            context.delete(model)
        }
    }

    private nonisolated static func deletePetScopedRecord(
        _ model: any PersistentModel,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        let stockReminderPets = stockReminderPetsAffectedByDeleting(model, fallbackPet: pet)
        let didDelete = PhysicalDeletionService.deletePetScopedRecord(
            model,
            pet: pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        guard didDelete, !stockReminderPets.isEmpty else { return }
        guard saveCloudSyncDeletionChanges(context: context) else { return }
        FeedingPlanWriter.rebuildFoodStockReminders(
            pets: stockReminderPets,
            context: context,
            now: deletedAt
        )
    }

    private nonisolated static func stockReminderPetsAffectedByDeleting(_ model: any PersistentModel, fallbackPet: Pet?) -> [Pet] {
        switch model {
        case let log as PetCareLog where log.careType == .feeding:
            (log.pet ?? fallbackPet).map { [$0] } ?? []
        case let record as PetFoodRecord:
            (record.pet ?? fallbackPet).map { [$0] } ?? []
        default:
            []
        }
    }

    nonisolated static func normalizedDeletionActorId(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
