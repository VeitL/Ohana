//
//  PhysicalDeletionService.swift
//  Ohana
//
//  Irreversible local deletes with CloudSync tombstones.
//

import Foundation
import SwiftData

@MainActor
enum PhysicalDeletionService {
    @discardableResult
    static func deleteEvent(
        _ event: Event,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil,
        cancelNotifications: Bool = true
    ) -> Int {
        for reminder in event.reminders {
            if cancelNotifications {
                OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            }
            CloudSyncMutationRecorder.markDeleted(
                reminder,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(reminder)
        }

        CloudSyncMutationRecorder.markDeleted(
            event,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(event)
        return 1
    }

    static func deletePet(
        _ pet: Pet,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) {
        let petId = pet.id.uuidString
        let legacyModelIds = petScopedLegacyModelIds(for: pet)
        deletePetDerivedRows(
            petId: petId,
            legacyModelIds: legacyModelIds,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        markPetCascadeDeletedForSync(pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        CloudSyncMutationRecorder.markDeleted(
            pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(pet)
        scrubSharedCareSessionsReferencingPet(
            petId: petId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
    }

    @discardableResult
    static func deleteHuman(
        _ human: Human,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> Int {
        let childCount = deleteHumanScopedRows(for: human, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        CloudSyncMutationRecorder.markDeleted(
            human,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(human)
        return childCount
    }

    static func deletePlant(
        _ plant: Plant,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) {
        CloudSyncMutationRecorder.markDeleted(
            plant,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(plant)
    }

    @discardableResult
    static func deletePetScopedRecord(
        _ record: any PersistentModel,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> Bool {
        switch record {
        case let log as PetCareLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as PetPottyLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as PetHygieneLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as PetHealthLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as PetWalkLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as PetExpenseLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as PetWeightLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let record as PetFoodRecord:
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(record)
        case let medication as PetMedication:
            CloudSyncMutationRecorder.markDeleted(medication, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(medication)
        case let photo as PetPhotoLog:
            CloudSyncMutationRecorder.markDeleted(photo, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(photo)
        case let milestone as PetMilestone:
            CloudSyncMutationRecorder.markDeleted(milestone, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(milestone)
        case let document as PetDocument:
            deleteDocument(document, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        case let insurance as PetInsurance:
            deleteInsurance(insurance, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        case let log as SymptomLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        case let log as HeatCycleLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        default:
            return false
        }
        return true
    }

    static func deleteDocument(
        _ document: PetDocument,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) {
        for attachment in document.attachments {
            CloudSyncMutationRecorder.markDeleted(
                attachment,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(attachment)
        }
        CloudSyncMutationRecorder.markDeleted(
            document,
            pet: pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(document)
    }

    static func deleteInsurance(
        _ insurance: PetInsurance,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) {
        for claim in insurance.claims {
            CloudSyncMutationRecorder.markDeleted(
                claim,
                pet: pet,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(claim)
        }
        CloudSyncMutationRecorder.markDeleted(
            insurance,
            pet: pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(insurance)
    }

    private static func markPetCascadeDeletedForSync(
        _ pet: Pet,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        for record in pet.careLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.pottyLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.hygieneLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.healthLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.walkLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.expenseLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.weightLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.foodRecords {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for medication in pet.medications {
            CloudSyncMutationRecorder.markDeleted(medication, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for photo in pet.photoLogs {
            CloudSyncMutationRecorder.markDeleted(photo, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for milestone in pet.milestones {
            CloudSyncMutationRecorder.markDeleted(milestone, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for document in pet.documents {
            for attachment in document.attachments {
                CloudSyncMutationRecorder.markDeleted(attachment, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            }
            CloudSyncMutationRecorder.markDeleted(document, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for insurance in pet.insurances {
            for claim in insurance.claims {
                CloudSyncMutationRecorder.markDeleted(claim, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            }
            CloudSyncMutationRecorder.markDeleted(insurance, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.symptomLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for record in pet.heatCycleLogs {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
    }

    private static func deleteHumanScopedRows(
        for human: Human,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        let humanId = human.id.uuidString
        var deletedCount = 0

        deletedCount += deleteRows(fetchAll(HumanMedication.self, context: context).filter { $0.humanId == humanId }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanMedicationLog.self, context: context).filter { $0.humanId == humanId }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanHealthReport.self, context: context).filter { $0.humanId == humanId }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(WishlistItem.self, context: context).filter { $0.creatorId == humanId }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(PetExpenseLog.self, context: context).filter { $0.executorId == humanId && $0.pet == nil }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, pet: $0.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanWeightLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanWorkoutLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanHealthMetricLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(CoconutAccount.self, context: context).filter { account in
            account.ownerKind == .human && idsMatch(account.ownerId, humanId)
        }, context: context) { _ in }
        deletedCount += deleteRows(fetchAll(CoconutLedgerEntry.self, context: context).filter { entry in
            referencesHuman(entry, humanId: humanId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(CareLedgerEvent.self, context: context).filter { event in
            referencesHuman(event, humanId: humanId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += scrubSharedCareSessionsReferencingHuman(
            humanId: humanId,
            context: context,
            deletedAt: deletedAt
        )

        return deletedCount
    }

    private static func petScopedLegacyModelIds(for pet: Pet) -> Set<String> {
        Set(
            pet.careLogs.map(\.id.uuidString) +
                pet.pottyLogs.map(\.id.uuidString) +
                pet.hygieneLogs.map(\.id.uuidString) +
                pet.healthLogs.map(\.id.uuidString) +
                pet.walkLogs.map(\.id.uuidString) +
                pet.expenseLogs.map(\.id.uuidString) +
                pet.weightLogs.map(\.id.uuidString) +
                pet.foodRecords.map(\.id.uuidString) +
                pet.medications.map(\.id.uuidString) +
                pet.photoLogs.map(\.id.uuidString) +
                pet.milestones.map(\.id.uuidString) +
                pet.documents.map(\.id.uuidString) +
                pet.insurances.map(\.id.uuidString) +
                pet.symptomLogs.map(\.id.uuidString) +
                pet.heatCycleLogs.map(\.id.uuidString)
        )
    }

    private static func deletePetDerivedRows(
        petId: String,
        legacyModelIds: Set<String>,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        _ = deleteRows(fetchAll(CoconutAccount.self, context: context).filter { account in
            account.ownerKind == .pet && idsMatch(account.ownerId, petId)
        }, context: context) { _ in }

        _ = deleteRows(fetchAll(CoconutLedgerEntry.self, context: context).filter { entry in
            referencesPet(entry, petId: petId) || legacyModelIds.containsNormalized(entry.sourceModelId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }

        _ = deleteRows(fetchAll(CareLedgerEvent.self, context: context).filter { event in
            referencesPet(event, petId: petId) || legacyModelIds.containsNormalized(event.legacyModelId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
    }

    @discardableResult
    private static func scrubSharedCareSessionsReferencingPet(
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
    private static func scrubSharedCareSessionsReferencingHuman(
        humanId: String,
        context: ModelContext,
        deletedAt: Date
    ) -> Int {
        var changedCount = 0
        for session in fetchAll(SharedCareSession.self, context: context) {
            let originalExecutors = session.executorIds
            let filteredExecutors = originalExecutors.filter { !idsMatch($0, humanId) }
            guard filteredExecutors.count != originalExecutors.count else { continue }
            session.setExecutorIds(filteredExecutors, primaryExecutorId: filteredExecutors.first)
            if filteredExecutors.isEmpty {
                session.executorId = nil
                session.executorIdsRaw = ""
            }
            CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: deletedAt)
            changedCount += 1
        }
        return changedCount
    }

    private static func referencesPet(_ entry: CoconutLedgerEntry, petId: String) -> Bool {
        (entry.ownerKind == .pet && idsMatch(entry.ownerId, petId)) ||
            idsMatch(entry.actorId, petId) ||
            idsMatch(entry.subjectId, petId)
    }

    private static func referencesPet(_ event: CareLedgerEvent, petId: String) -> Bool {
        idsMatch(event.actorId, petId) || idsMatch(event.subjectId, petId)
    }

    private static func referencesHuman(_ entry: CoconutLedgerEntry, humanId: String) -> Bool {
        (entry.ownerKind == .human && idsMatch(entry.ownerId, humanId)) ||
            idsMatch(entry.actorId, humanId) ||
            idsMatch(entry.subjectId, humanId)
    }

    private static func referencesHuman(_ event: CareLedgerEvent, humanId: String) -> Bool {
        idsMatch(event.actorId, humanId) || idsMatch(event.subjectId, humanId)
    }

    private static func idsMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        let left = CloudSyncRecordState.normalizedRecordId(lhs)
        let right = CloudSyncRecordState.normalizedRecordId(rhs)
        return !left.isEmpty && left == right
    }

    private static func deleteRows<T: PersistentModel>(
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

    private static func fetchAll<T: PersistentModel>(_: T.Type, context: ModelContext) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            OhanaLog.warning("PhysicalDeletionService failed to fetch \(T.self): \(error.localizedDescription)", category: "Care")
            return []
        }
    }
}

private extension Set<String> {
    func containsNormalized(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalizedValue = CloudSyncRecordState.normalizedRecordId(value)
        return contains { CloudSyncRecordState.normalizedRecordId($0) == normalizedValue }
    }
}
