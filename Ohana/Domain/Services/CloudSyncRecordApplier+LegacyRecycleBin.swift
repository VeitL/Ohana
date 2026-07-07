//
//  CloudSyncRecordApplier+LegacyRecycleBin.swift
//  Ohana
//
//  Split helpers for applying CloudKit records into SwiftData.
//

import CloudKit
import Foundation
import SwiftData

extension CloudSyncRecordApplier {
    nonisolated static func applyLegacyRecycleBinFieldsIfSupported(
        from record: CKRecord,
        entityName: String,
        localRecordUUID: UUID,
        context: ModelContext
    ) throws {
        let values = legacyRecycleBinFieldValues(from: record)
        switch entityName {
        case String(describing: Pet.self):
            if let model = try fetchPet(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: Human.self):
            if let model = try fetchHuman(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: Event.self):
            if let model = try fetchEvent(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetCareLog.self):
            if let model = try fetchPetCareLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetPottyLog.self):
            if let model = try fetchPetPottyLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetHygieneLog.self):
            if let model = try fetchPetHygieneLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetHealthLog.self):
            if let model = try fetchPetHealthLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetWalkLog.self):
            if let model = try fetchPetWalkLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetExpenseLog.self):
            if let model = try fetchPetExpenseLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetFoodRecord.self):
            if let model = try fetchPetFoodRecord(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        case String(describing: PetWeightLog.self):
            if let model = try fetchPetWeightLog(id: localRecordUUID, context: context) {
                applyLegacyRecycleBinFields(values, to: model)
            }
        default:
            break
        }
    }

    private nonisolated static func legacyRecycleBinFieldValues(from record: CKRecord) -> LegacyRecycleBinFieldValues {
        LegacyRecycleBinFieldValues(
            trashedAt: record.date(for: CloudSyncLegacyRecycleBinFieldKey.trashedAt),
            trashExpiresAt: record.date(for: CloudSyncLegacyRecycleBinFieldKey.trashExpiresAt),
            trashBatchId: record.string(for: CloudSyncLegacyRecycleBinFieldKey.trashBatchId) ?? "",
            trashedByHumanId: record.string(for: CloudSyncLegacyRecycleBinFieldKey.trashedByHumanId) ?? ""
        )
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: Pet) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: Human) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: Event) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetCareLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetPottyLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetHygieneLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetHealthLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetWalkLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetExpenseLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetFoodRecord) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }

    private nonisolated static func applyLegacyRecycleBinFields(_ values: LegacyRecycleBinFieldValues, to model: PetWeightLog) {
        model.trashedAt = values.trashedAt
        model.trashExpiresAt = values.trashExpiresAt
        model.trashBatchId = values.trashBatchId
        model.trashedByHumanId = values.trashedByHumanId
    }
}
