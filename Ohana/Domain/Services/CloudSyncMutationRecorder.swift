//
//  CloudSyncMutationRecorder.swift
//  Ohana
//
//  Local write hooks that enqueue supported SwiftData facts for CKSyncEngine.
//

import Foundation
import SwiftData

nonisolated enum CloudSyncMutationRecorder {
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
        _ plant: Plant,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: Plant.self),
            localRecordId: plant.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: plant.id,
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markDeleted(
        _ log: PlantCareLog,
        plant: Plant?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> CloudSyncRecordState? {
        markDeleted(
            entityName: String(describing: PlantCareLog.self),
            localRecordId: log.id,
            householdId: sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: plant?.id ?? log.plant?.id ?? log.id,
            deletedAt: deletedAt,
            deletedByHumanId: uuid(from: deletedByHumanId),
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
            fallbackHouseholdId: fallbackHouseholdId(for: event, context: context),
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ reminder: Reminder,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: Reminder.self),
            localRecordId: reminder.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: fallbackHouseholdId(for: reminder, context: context),
            modifiedAt: modifiedAt,
            context: context
        )
    }

    @discardableResult
    static func markModified(
        _ medication: HumanMedication,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(HumanMedication.self, id: medication.id, humanId: medication.humanId, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ report: HumanHealthReport,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(HumanHealthReport.self, id: report.id, humanId: report.humanId, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: HumanMedicationLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(HumanMedicationLog.self, id: log.id, humanId: log.humanId, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ item: WishlistItem,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(WishlistItem.self, id: item.id, humanId: item.creatorId, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ task: FamilyCollaborationTask,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markModified(
            entityName: String(describing: FamilyCollaborationTask.self),
            localRecordId: task.id,
            householdId: sharedHouseholdId(context: context, now: modifiedAt),
            fallbackHouseholdId: uuid(from: task.createdById)
                ?? uuid(from: task.assignedToId)
                ?? uuid(from: task.claimedById)
                ?? task.id,
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
        _ milestone: PetMilestone,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetMilestone.self, id: milestone.id, petId: milestone.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ photo: PetPhotoLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetPhotoLog.self, id: photo.id, petId: photo.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: SymptomLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(SymptomLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: HeatCycleLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(HeatCycleLog.self, id: log.id, petId: log.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ document: PetDocument,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetDocument.self, id: document.id, petId: document.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ insurance: PetInsurance,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetInsurance.self, id: insurance.id, petId: insurance.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ claim: InsuranceClaim,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(InsuranceClaim.self, id: claim.id, petId: claim.insurance?.pet?.id, context: context, modifiedAt: modifiedAt)
    }

    @discardableResult
    static func markModified(
        _ log: HumanWeightLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(
            HumanWeightLog.self,
            id: log.id,
            humanId: log.human?.id.uuidString ?? log.executorId ?? "",
            context: context,
            modifiedAt: modifiedAt
        )
    }

    @discardableResult
    static func markModified(
        _ log: HumanWorkoutLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(
            HumanWorkoutLog.self,
            id: log.id,
            humanId: log.human?.id.uuidString ?? "",
            context: context,
            modifiedAt: modifiedAt
        )
    }

    @discardableResult
    static func markModified(
        _ log: HumanHealthMetricLog,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markHumanScopedModified(
            HumanHealthMetricLog.self,
            id: log.id,
            humanId: log.human?.id.uuidString ?? "",
            context: context,
            modifiedAt: modifiedAt
        )
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
        _ medication: PetMedication,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> CloudSyncRecordState? {
        markPetScopedModified(PetMedication.self, id: medication.id, petId: medication.pet?.id, context: context, modifiedAt: modifiedAt)
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

    static func markModified(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID?,
        fallbackHouseholdId: UUID? = nil,
        modifiedAt: Date,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        guard supportsLocalMutationRecording(for: entityName) else {
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

    static func fallbackHouseholdId(for reminder: Reminder, context: ModelContext) -> UUID {
        reminder.event.map { fallbackHouseholdId(for: $0, context: context) } ?? reminder.id
    }

    static func fallbackHouseholdId(for event: Event, context: ModelContext) -> UUID {
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        )
        if let owner = resolution.owner {
            return owner.id
        }
        if let displayTarget = resolution.displayTarget {
            return displayTarget.id
        }
        if let plantId = DomainEntityLinkRegistry.plantId(for: event) {
            return plantId
        }
        let link = DomainEntityLink(event: event)
        return DomainEntityLinkRegistry.affectedEntityId(for: link, role: resolution.role)
            ?? uuid(from: link.trimmedId)
            ?? event.id
    }

    static func markDeleted(
        entityName: String,
        localRecordId: UUID,
        householdId: UUID?,
        fallbackHouseholdId: UUID? = nil,
        deletedAt: Date,
        deletedByHumanId: UUID?,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        guard supportsLocalMutationRecording(for: entityName) else {
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
}
