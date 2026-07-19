//
//  PhysicalDeletionService.swift
//  Ohana
//
//  Irreversible local deletes with CloudSync tombstones.
//

import Foundation
import SwiftData

nonisolated enum PhysicalDeletionService {
    static let pendingShopPurchaseDeletionBlockCode = -1

    private static let petDeletionCascadeCoverageEntityNames: Set<String> = [
        String(describing: Event.self),
        String(describing: Reminder.self),
        String(describing: PetRelationship.self),
        String(describing: FamilyCollaborationTask.self),
        String(describing: SharedCareSession.self),
        String(describing: PetCareLog.self),
        String(describing: PetPottyLog.self),
        String(describing: PetHygieneLog.self),
        String(describing: PetHealthLog.self),
        String(describing: PetWalkLog.self),
        String(describing: PetExpenseLog.self),
        String(describing: PetWeightLog.self),
        String(describing: PetFoodRecord.self),
        String(describing: PetMedication.self),
        String(describing: PetPhotoLog.self),
        String(describing: PetMilestone.self),
        String(describing: PetDocument.self),
        String(describing: PetDocumentAttachment.self),
        String(describing: PetInsurance.self),
        String(describing: InsuranceClaim.self),
        String(describing: SymptomLog.self),
        String(describing: HeatCycleLog.self),
        String(describing: CareLedgerEvent.self),
        String(describing: EconomyBudgetUsageEvent.self)
    ]

    private static let humanDeletionCascadeCoverageEntityNames: Set<String> = [
        String(describing: Event.self),
        String(describing: Reminder.self),
        String(describing: HumanMedication.self),
        String(describing: HumanMedicationLog.self),
        String(describing: HumanHealthReport.self),
        String(describing: HumanNoteRecord.self),
        String(describing: WishlistItem.self),
        String(describing: GachaOwnedItem.self),
        String(describing: GachaDrawLog.self),
        String(describing: ShopPurchaseRecord.self),
        String(describing: PetExpenseLog.self),
        String(describing: HumanWeightLog.self),
        String(describing: HumanWorkoutLog.self),
        String(describing: HumanHealthMetricLog.self),
        String(describing: CareLedgerEvent.self),
        String(describing: EconomyBudgetUsageEvent.self),
        String(describing: SharedCareSession.self),
        String(describing: CoconutExchangeRequest.self),
        String(describing: FamilyCollaborationTask.self)
    ]

    static func localPhysicalDeletionCascadeCoverage(parent: CloudSyncPhysicalDeletionParent) -> Set<String> {
        switch parent {
        case .pet:
            petDeletionCascadeCoverageEntityNames
        case .human:
            humanDeletionCascadeCoverageEntityNames
        case .plant:
            plantDeletionCascadeCoverageEntityNames
        }
    }

    @discardableResult
    static func deleteEvent(
        _ event: Event,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil,
        cancelNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> Int {
        for reminder in event.reminders {
            if cancelNotifications {
                notifications.cancel(notificationId: reminder.notificationId)
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
        deletedByHumanId: String? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) {
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
        let petId = pet.id.uuidString
        let legacyModelIds = petScopedLegacyModelIds(for: pet)
        _ = deletePetRelatedEvents(
            pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        deletePetRelationships(
            petId: pet.id,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        deleteFamilyTasksReferencingPet(
            petId: petId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        deletePetDerivedRows(
            petId: petId,
            legacyModelIds: legacyModelIds,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        _ = deleteAchievementFacts(
            scopeKind: .pet,
            scopeID: petId,
            context: context
        )
        deleteSharedCareUndoReceiptsReferencingPet(petId: petId, context: context)
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
        deleteOrphanedSharedCareUndoReceipts(context: context)
        reconcileWalletAfterEconomyDeletion(context: context)
    }

    @discardableResult
    static func deleteHuman(
        _ human: Human,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> Int {
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
        let humanId = human.id.uuidString
        guard !hasUnsettledShopPurchaseReference(
            humanID: human.id,
            context: context
        ) else {
            OhanaLog.warning(
                "PhysicalDeletionService blocked Human deletion while a shop purchase still references its wallet.",
                category: "Economy"
            )
            return pendingShopPurchaseDeletionBlockCode
        }
        let humanMedications = fetchAll(HumanMedication.self, context: context).filter { $0.humanId == humanId }
        let relatedEventCount = deleteHumanRelatedEvents(
            humanId: humanId,
            humanMedications: humanMedications,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        let childCount = relatedEventCount + deleteHumanScopedRows(
            for: human,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        CloudSyncMutationRecorder.markDeleted(
            human,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(human)
        reconcileWalletAfterEconomyDeletion(context: context)
        return childCount
    }

    static func hasUnsettledShopPurchaseReference(
        humanID: UUID,
        context: ModelContext
    ) -> Bool {
        let fulfilled = ShopPurchaseAttemptState.fulfilled.rawValue
        let refunded = ShopPurchaseAttemptState.refunded.rawValue
        let descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.stateRaw != fulfilled && attempt.stateRaw != refunded
            }
        )
        do {
            let attempts = try context.fetch(descriptor)
            return attempts.contains { attempt in
                if attempt.buyerHumanId == humanID.uuidString { return true }
                guard let data = attempt.fundingContributionsJSON.data(using: .utf8),
                      let contributions = try? JSONDecoder().decode(
                          [ShopPurchaseFundingContribution].self,
                          from: data
                      ) else {
                    // A corrupt immutable funding snapshot is not evidence that
                    // this member is safe to delete. Fail closed until the
                    // purchase is manually repaired.
                    return true
                }
                return contributions.contains { $0.humanID == humanID }
            }
        } catch {
            OhanaLog.warning(
                "PhysicalDeletionService could not verify pending shop wallet references: \(error.localizedDescription)",
                category: "Economy"
            )
            return true
        }
    }

    @discardableResult
    static func deletePetScopedRecord(
        _ record: any PersistentModel,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> Bool {
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
        let sharedSessionIds = sharedSessionIds(for: record)
        if let healthLog = record as? PetHealthLog {
            deletePetHealthDerivedRows(
                for: healthLog,
                pet: pet,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId,
                notifications: notifications
            )
        }
        if let legacy = petScopedLegacyReference(for: record) {
            deleteCareLedgerEvents(
                legacyModelName: legacy.modelName,
                legacyModelId: legacy.modelId,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
        if let linkedPotty = linkedPottyLog(for: record, pet: pet, context: context) {
            deleteCareLedgerEvents(
                legacyModelName: String(describing: PetPottyLog.self),
                legacyModelId: linkedPotty.id.uuidString,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            CloudSyncMutationRecorder.markDeleted(
                linkedPotty,
                pet: linkedPotty.pet ?? pet,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(linkedPotty)
        }

        let didDelete: Bool
        switch record {
        case let log as PetCareLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as PetPottyLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as PetHygieneLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as PetHealthLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as PetWalkLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as PetExpenseLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as PetWeightLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let record as PetFoodRecord:
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(record)
            didDelete = true
        case let medication as PetMedication:
            CloudSyncMutationRecorder.markDeleted(medication, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(medication)
            didDelete = true
        case let photo as PetPhotoLog:
            CloudSyncMutationRecorder.markDeleted(photo, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(photo)
            didDelete = true
        case let milestone as PetMilestone:
            CloudSyncMutationRecorder.markDeleted(milestone, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(milestone)
            didDelete = true
        case let document as PetDocument:
            deleteDocument(document, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            didDelete = true
        case let insurance as PetInsurance:
            deleteInsurance(insurance, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            didDelete = true
        case let log as SymptomLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        case let log as HeatCycleLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
            didDelete = true
        default:
            return false
        }

        for sharedSessionId in sharedSessionIds {
            SharedCareSessionMaintenance.reconcileAfterDeletingChild(
                sharedSessionId: sharedSessionId,
                context: context,
                reconciledAt: deletedAt
            )
        }
        deleteOrphanedSharedCareUndoReceipts(context: context)
        return didDelete
    }

    static func deleteDocument(
        _ document: PetDocument,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) {
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
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
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
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
        deletedCount += deleteRows(fetchAll(WishlistItem.self, context: context).filter {
            idsMatch($0.creatorId, humanId) || idsMatch($0.redeemedById, humanId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(GachaOwnedItem.self, context: context).filter { idsMatch($0.ownerHumanId, humanId) }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(GachaDrawLog.self, context: context).filter { idsMatch($0.ownerHumanId, humanId) }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(ShopPurchaseRecord.self, context: context).filter { idsMatch($0.buyerHumanId, humanId) }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteAchievementFacts(
            scopeKind: .human,
            scopeID: humanId,
            context: context
        )
        for receipt in fetchAll(AchievementRewardReceipt.self, context: context)
            where receipt.scopeKindRaw == AchievementScopeKind.island.rawValue
                && idsMatch(receipt.recipientHumanIDRaw, humanId) {
            receipt.recipientHumanIDRaw = ""
        }
        deletedCount += scrubHumanAttribution(for: human, in: context, at: deletedAt, by: deletedByHumanId)
        deletedCount += deleteRows(fetchAll(HumanWeightLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanWorkoutLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanHealthMetricLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteSharedCareUndoReceiptsReferencingHuman(humanId: humanId, context: context)
        deletedCount += scrubSharedCareSessionsReferencingHuman(
            humanId: humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        deletedCount += deleteOrphanedSharedCareUndoReceipts(context: context)
        deletedCount += scrubRetainedPetFactsReferencingHuman(humanId: humanId, context: context, modifiedAt: deletedAt)
        deletedCount += retireWalletAccounts(ownerKind: .human, ownerId: humanId, context: context, deletedAt: deletedAt)
        deletedCount += scrubCoconutLedgerEntriesReferencingDeletedOwner(
            ownerKind: .human,
            ownerId: humanId,
            subjectKind: .human,
            reason: "humanPhysicalDeletion",
            context: context,
            modifiedAt: deletedAt
        )
        deletedCount += deleteOrRetainCareLedgerEvents(fetchAll(CareLedgerEvent.self, context: context).filter { event in
            referencesHuman(event, humanId: humanId)
        }, context: context) { _ in
            CareLedgerDeletionContext(
                deletedOwnerKind: .human,
                deletedOwnerId: humanId,
                deletedLegacyModelName: nil,
                deletedLegacyModelId: nil,
                reason: "humanPhysicalDeletion",
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
        deletedCount += deleteRows(fetchAll(EconomyBudgetUsageEvent.self, context: context).filter { event in
            referencesHuman(event, humanId: humanId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(CoconutExchangeRequest.self, context: context).filter { request in
            idsMatch(request.senderId, humanId) || idsMatch(request.receiverId, humanId)
        }, context: context) {
            markGenericDeleted(entityName: String(describing: CoconutExchangeRequest.self), localRecordId: $0.id, parentId: humanId, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(FamilyCollaborationTask.self, context: context).filter { task in
            referencesHuman(task, humanId: humanId)
        }, context: context) {
            markGenericDeleted(entityName: String(describing: FamilyCollaborationTask.self), localRecordId: $0.id, parentId: humanId, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }

        return deletedCount
    }

    private static func deleteAchievementFacts(
        scopeKind: AchievementScopeKind,
        scopeID: String,
        context: ModelContext
    ) -> Int {
        let kind = scopeKind.rawValue
        let unlocks = fetchAll(AchievementUnlock.self, context: context).filter {
            $0.scopeKindRaw == kind && idsMatch($0.scopeIDRaw, scopeID)
        }
        let receipts = fetchAll(AchievementRewardReceipt.self, context: context).filter {
            $0.scopeKindRaw == kind && idsMatch($0.scopeIDRaw, scopeID)
        }
        for unlock in unlocks {
            context.delete(unlock)
        }
        for receipt in receipts {
            context.delete(receipt)
        }
        return unlocks.count + receipts.count
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

    private static func petScopedLegacyReference(for record: any PersistentModel) -> (modelName: String, modelId: String)? {
        switch record {
        case let log as PetCareLog:
            (String(describing: PetCareLog.self), log.id.uuidString)
        case let log as PetPottyLog:
            (String(describing: PetPottyLog.self), log.id.uuidString)
        case let log as PetHygieneLog:
            (String(describing: PetHygieneLog.self), log.id.uuidString)
        case let log as PetHealthLog:
            (String(describing: PetHealthLog.self), log.id.uuidString)
        case let log as PetWalkLog:
            (String(describing: PetWalkLog.self), log.id.uuidString)
        case let log as PetExpenseLog:
            (String(describing: PetExpenseLog.self), log.id.uuidString)
        case let log as PetWeightLog:
            (String(describing: PetWeightLog.self), log.id.uuidString)
        case let record as PetFoodRecord:
            (String(describing: PetFoodRecord.self), record.id.uuidString)
        case let medication as PetMedication:
            (String(describing: PetMedication.self), medication.id.uuidString)
        case let photo as PetPhotoLog:
            (String(describing: PetPhotoLog.self), photo.id.uuidString)
        case let milestone as PetMilestone:
            (String(describing: PetMilestone.self), milestone.id.uuidString)
        case let document as PetDocument:
            (String(describing: PetDocument.self), document.id.uuidString)
        case let insurance as PetInsurance:
            (String(describing: PetInsurance.self), insurance.id.uuidString)
        case let log as SymptomLog:
            (String(describing: SymptomLog.self), log.id.uuidString)
        case let log as HeatCycleLog:
            (String(describing: HeatCycleLog.self), log.id.uuidString)
        default:
            nil
        }
    }

    private static func sharedSessionIds(for record: any PersistentModel) -> [String] {
        switch record {
        case let log as PetCareLog:
            [log.sharedSessionId].filter { !$0.isEmpty }
        case let log as PetPottyLog:
            [log.sharedSessionId].filter { !$0.isEmpty }
        case let log as PetHygieneLog:
            [log.sharedSessionId].filter { !$0.isEmpty }
        case let log as PetWalkLog:
            [log.sharedSessionId].filter { !$0.isEmpty }
        case let log as PetExpenseLog:
            [log.sharedSessionId].filter { !$0.isEmpty }
        default:
            []
        }
    }

    private static func linkedPottyLog(
        for record: any PersistentModel,
        pet: Pet?,
        context: ModelContext
    ) -> PetPottyLog? {
        guard let careLog = record as? PetCareLog,
              careLog.careType == .litter else {
            return nil
        }
        return fetchAll(PetPottyLog.self, context: context)
            .filter { candidate in
                (pet == nil || candidate.pet?.id == pet?.id)
                    && candidate.executorId == careLog.executorId
                    && abs(candidate.date.timeIntervalSince(careLog.date)) < 2
            }
            .min { lhs, rhs in
                abs(lhs.date.timeIntervalSince(careLog.date)) < abs(rhs.date.timeIntervalSince(careLog.date))
            }
    }
}

extension PhysicalDeletionService {
    static func deleteCareLedgerEvents(
        legacyModelName: String,
        legacyModelId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        _ = deleteOrRetainCareLedgerEvents(fetchAll(CareLedgerEvent.self, context: context).filter { event in
            event.legacyModelName == legacyModelName && idsMatch(event.legacyModelId, legacyModelId)
        }, context: context) { _ in
            CareLedgerDeletionContext(
                deletedOwnerKind: nil,
                deletedOwnerId: nil,
                deletedLegacyModelName: legacyModelName,
                deletedLegacyModelId: legacyModelId,
                reason: "legacyFactPhysicalDeletion",
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    private static func deletePetHealthDerivedRows(
        for log: PetHealthLog,
        pet providedPet: Pet?,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) {
        guard let pet = providedPet ?? log.pet else { return }
        let allLedger = fetchAll(CareLedgerEvent.self, context: context)
        let healthLogId = log.id.uuidString
        let directHealthLedger = allLedger.filter { ledger in
            ledger.legacyModelName == String(describing: PetHealthLog.self) &&
                idsMatch(ledger.legacyModelId, healthLogId)
        }

        let events = petHealthEventsLinkedTo(
            log,
            pet: pet,
            healthLedger: directHealthLedger,
            context: context
        )
        let eventIds = Set(events.map { CloudSyncRecordState.normalizedRecordId($0.id.uuidString) })

        let reminders = unique(
            events.flatMap(\.reminders) + fetchAll(Reminder.self, context: context).filter { reminder in
                guard let eventId = reminder.event?.id.uuidString else { return false }
                return eventIds.contains(CloudSyncRecordState.normalizedRecordId(eventId))
            },
            by: \.id
        )
        let reminderIds = Set(reminders.map { CloudSyncRecordState.normalizedRecordId($0.id.uuidString) })

        let expenses = petHealthExpensesLinkedTo(log, pet: pet, context: context)
        let expenseIds = Set(expenses.map { CloudSyncRecordState.normalizedRecordId($0.id.uuidString) })

        let derivedLedgerEvents = unique(allLedger.filter { ledger in
            if ledger.legacyModelName == String(describing: PetHealthLog.self) &&
                idsMatch(ledger.legacyModelId, healthLogId) {
                return false
            }
            if ledger.legacyModelName == String(describing: PetExpenseLog.self),
               let legacyModelId = ledger.legacyModelId,
               expenseIds.contains(CloudSyncRecordState.normalizedRecordId(legacyModelId)) {
                return false
            }
            if let sourceEventId = ledger.sourceEventId,
               eventIds.contains(CloudSyncRecordState.normalizedRecordId(sourceEventId)) {
                return true
            }
            if let sourceReminderId = ledger.sourceReminderId,
               reminderIds.contains(CloudSyncRecordState.normalizedRecordId(sourceReminderId)) {
                return true
            }
            return false
        }, by: \.id)

        for reminder in reminders {
            notifications.cancel(notificationId: reminder.notificationId)
            CloudSyncMutationRecorder.markDeleted(
                reminder,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(reminder)
        }
        for event in events {
            CloudSyncMutationRecorder.markDeleted(
                event,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(event)
        }
        for expense in expenses {
            _ = deletePetScopedRecord(
                expense,
                pet: pet,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
        _ = deleteOrRetainCareLedgerEvents(derivedLedgerEvents, context: context) { _ in
            CareLedgerDeletionContext(
                deletedOwnerKind: .pet,
                deletedOwnerId: pet.id.uuidString,
                deletedLegacyModelName: nil,
                deletedLegacyModelId: nil,
                reason: "petHealthDerivedPhysicalDeletion",
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    private static func petHealthEventsLinkedTo(
        _ log: PetHealthLog,
        pet: Pet,
        healthLedger: [CareLedgerEvent],
        context: ModelContext
    ) -> [Event] {
        let allEvents = fetchAll(Event.self, context: context)
        let sourceEventIds = Set(healthLedger.compactMap { ledger in
            ledger.sourceEventId.map(CloudSyncRecordState.normalizedRecordId)
        })
        var linked = allEvents.filter { event in
            sourceEventIds.contains(CloudSyncRecordState.normalizedRecordId(event.id.uuidString))
        }

        if let expirationDate = log.expirationDate,
           let eventType = petHealthExpirationEventType(for: log.healthLogType) {
            linked += allEvents.filter { event in
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: pet.id.uuidString) &&
                    event.eventType == eventType.rawValue &&
                    abs(event.startDate.timeIntervalSince(expirationDate)) < 1
            }
        }
        return unique(linked, by: \.id)
    }

    private static func petHealthExpensesLinkedTo(
        _ log: PetHealthLog,
        pet: Pet,
        context: ModelContext
    ) -> [PetExpenseLog] {
        guard log.cost > 0 else { return [] }
        return fetchAll(PetExpenseLog.self, context: context).filter { expense in
            guard expense.pet?.id == pet.id,
                  expense.category == ExpenseCategory.medical.rawValue,
                  abs(expense.amount - log.cost) < 0.001,
                  abs(expense.date.timeIntervalSince(log.date)) < 1
            else { return false }
            return expense.note.isEmpty ||
                log.note.isEmpty ||
                log.note.localizedCaseInsensitiveContains(expense.note) ||
                expense.note.localizedCaseInsensitiveContains(log.note) ||
                expense.note == log.healthLogType.rawValue
        }
    }

    private static func petHealthExpirationEventType(for type: HealthLogType) -> EventType? {
        switch type {
        case .vaccine:
            .vaccine
        case .dewormingInternal:
            .internalDeworming
        case .dewormingExternal:
            .externalDeworming
        default:
            nil
        }
    }

    private static func deletePetDerivedRows(
        petId: String,
        legacyModelIds: Set<String>,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        _ = retireWalletAccounts(ownerKind: .pet, ownerId: petId, context: context, deletedAt: deletedAt)
        _ = scrubCoconutLedgerEntriesReferencingDeletedOwner(
            ownerKind: .pet,
            ownerId: petId,
            subjectKind: .pet,
            legacyModelIds: legacyModelIds,
            reason: "petPhysicalDeletion",
            context: context,
            modifiedAt: deletedAt
        )

        _ = deleteOrRetainCareLedgerEvents(fetchAll(CareLedgerEvent.self, context: context).filter { event in
            referencesPet(event, petId: petId) || legacyModelIds.containsNormalized(event.legacyModelId)
        }, context: context) {
            let deletesLegacyReference = legacyModelIds.containsNormalized($0.legacyModelId)
            return CareLedgerDeletionContext(
                deletedOwnerKind: .pet,
                deletedOwnerId: petId,
                deletedLegacyModelName: deletesLegacyReference ? $0.legacyModelName : nil,
                deletedLegacyModelId: deletesLegacyReference ? $0.legacyModelId : nil,
                reason: "petPhysicalDeletion",
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }

        _ = deleteRows(fetchAll(EconomyBudgetUsageEvent.self, context: context).filter { event in
            referencesPet(event, petId: petId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
    }

    private static func deletePetRelatedEvents(
        _ pet: Pet,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let events = fetchAll(Event.self, context: context).filter { event in
            MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: pet.medications,
                insurances: pet.insurances
            )
        }
        return deleteEvents(
            events,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
    }

    @discardableResult
    private static func deleteHumanRelatedEvents(
        humanId: String,
        humanMedications: [HumanMedication],
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let pets = fetchAll(Pet.self, context: context)
        let petMedications = pets.flatMap(\.medications)
        let insurances = pets.flatMap(\.insurances)
        var eventsToDelete: [Event] = []
        var retainedAssignedEvents: [Event] = []

        for event in fetchAll(Event.self, context: context) {
            if MemberLifecycleActiveScheduleResolver.eventOwnedByHuman(
                event,
                humanId: humanId,
                humanMedications: humanMedications
            ) {
                eventsToDelete.append(event)
                continue
            }

            guard MemberLifecycleActiveScheduleResolver.eventAssignedToHuman(event, humanId: humanId) else { continue }
            if MemberLifecycleActiveScheduleResolver.petTarget(
                for: event,
                pets: pets,
                petMedications: petMedications,
                insurances: insurances
            ) != nil {
                retainedAssignedEvents.append(event)
            } else {
                eventsToDelete.append(event)
            }
        }

        let deletedCount = deleteEvents(
            eventsToDelete,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        let uniqueRetainedAssignedEvents = unique(retainedAssignedEvents, by: \.id)
        var retainedUpdateCount = 0
        for event in uniqueRetainedAssignedEvents {
            if clearDeletedAssignee(from: event, context: context, modifiedAt: deletedAt) {
                retainedUpdateCount += 1
            }
        }
        return deletedCount + retainedUpdateCount
    }

    private static func clearDeletedAssignee(
        from event: Event,
        context: ModelContext,
        modifiedAt: Date
    ) -> Bool {
        let updateIntent = DomainScheduleCreateIntent(
            event: event,
            assigneeOverride: .set(nil),
            writeKind: .care,
            source: .domainService
        )
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
            event: event,
            intent: updateIntent,
            writeKind: .care,
            context: context
        ) else { return false }
        guard DomainScheduleWriter.updateEvent(event, intent: updateIntent, mutation: mutation) else { return false }
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: modifiedAt)
        return true
    }
}
