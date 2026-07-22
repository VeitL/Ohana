//
//  CloudSyncMutationRecorder+EconomyAndDeletion.swift
//  Ohana
//
//  Economy mutations and deletion tombstones recorded for Cloud sync.
//

import Foundation
import SwiftData

nonisolated extension CloudSyncMutationRecorder {
    @discardableResult
    static func markModified(
        _ account: CoconutAccount,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: CoconutAccount.self),
            localRecordId: account.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: account.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ entry: CoconutLedgerEntry,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: CoconutLedgerEntry.self),
            localRecordId: entry.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: entry.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ event: EconomyBudgetUsageEvent,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: EconomyBudgetUsageEvent.self),
            localRecordId: event.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: event.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ item: GachaOwnedItem,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: GachaOwnedItem.self),
            localRecordId: item.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: uuid(from: item.ownerHumanId) ?? item.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ log: GachaDrawLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: GachaDrawLog.self),
            localRecordId: log.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: uuid(from: log.ownerHumanId) ?? log.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ item: GachaOwnedItem,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: GachaOwnedItem.self),
            localRecordId: item.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: uuid(from: item.ownerHumanId) ?? item.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: GachaDrawLog,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: GachaDrawLog.self),
            localRecordId: log.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: uuid(from: log.ownerHumanId) ?? log.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ record: ShopPurchaseRecord,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: ShopPurchaseRecord.self),
            localRecordId: record.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: uuid(from: record.buyerHumanId) ?? record.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ record: ShopPurchaseRecord,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: ShopPurchaseRecord.self),
            localRecordId: record.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: uuid(from: record.buyerHumanId) ?? record.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
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
        _ plant: Plant,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: Plant.self),
            localRecordId: plant.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: plant.id,
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
            fallbackHouseholdId: fallbackHouseholdId(for: event, context: context),
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ reminder: Reminder,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: Reminder.self),
            localRecordId: reminder.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: fallbackHouseholdId(for: reminder, context: context),
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ medication: HumanMedication,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            HumanMedication.self,
            id: medication.id,
            humanId: medication.humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: HumanMedicationLog,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            HumanMedicationLog.self,
            id: log.id,
            humanId: log.humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ report: HumanHealthReport,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            HumanHealthReport.self,
            id: report.id,
            humanId: report.humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ item: WishlistItem,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            WishlistItem.self,
            id: item.id,
            humanId: item.creatorId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: HumanWeightLog,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            HumanWeightLog.self,
            id: log.id,
            humanId: log.human?.id.uuidString ?? log.executorId ?? "",
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: HumanWorkoutLog,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            HumanWorkoutLog.self,
            id: log.id,
            humanId: log.human?.id.uuidString ?? "",
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: HumanHealthMetricLog,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markHumanScopedDeleted(
            HumanHealthMetricLog.self,
            id: log.id,
            humanId: log.human?.id.uuidString ?? "",
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
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
        _ medication: PetMedication,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetMedication.self,
            id: medication.id,
            petId: pet?.id ?? medication.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ photo: PetPhotoLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetPhotoLog.self,
            id: photo.id,
            petId: pet?.id ?? photo.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ milestone: PetMilestone,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetMilestone.self,
            id: milestone.id,
            petId: pet?.id ?? milestone.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ attachment: PetDocumentAttachment,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: PetDocumentAttachment.self),
            localRecordId: attachment.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: attachment.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ document: PetDocument,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetDocument.self,
            id: document.id,
            petId: pet?.id ?? document.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ insurance: PetInsurance,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            PetInsurance.self,
            id: insurance.id,
            petId: pet?.id ?? insurance.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ claim: InsuranceClaim,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            InsuranceClaim.self,
            id: claim.id,
            petId: pet?.id ?? claim.insurance?.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: SymptomLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            SymptomLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: HeatCycleLog,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markPetScopedDeleted(
            HeatCycleLog.self,
            id: log.id,
            petId: pet?.id ?? log.pet?.id,
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
        guard supportsLocalMutationRecording(for: entityName) else {
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
}
