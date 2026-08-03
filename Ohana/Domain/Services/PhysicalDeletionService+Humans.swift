//
//  PhysicalDeletionService+Humans.swift
//  Ohana
//
//  Human-owned row cleanup for the irreversible member deletion boundary.
//

import Foundation
import SwiftData

extension PhysicalDeletionService {
    nonisolated struct HumanDeletionRequiredHealthRows {
        let reports: [HumanHealthReport]
        let metrics: [HumanHealthMetricLog]
        let conditions: [HumanHealthCondition]
        let observations: [HumanHealthObservation]
    }

    typealias HumanDeletionRequiredHealthRowsLoader = (
        _ context: ModelContext
    ) throws -> HumanDeletionRequiredHealthRows

    nonisolated static func loadRequiredHumanHealthRows(
        context: ModelContext
    ) throws -> HumanDeletionRequiredHealthRows {
        try HumanDeletionRequiredHealthRows(
            reports: context.fetch(FetchDescriptor<HumanHealthReport>()),
            metrics: context.fetch(FetchDescriptor<HumanHealthMetricLog>()),
            conditions: context.fetch(FetchDescriptor<HumanHealthCondition>()),
            observations: context.fetch(FetchDescriptor<HumanHealthObservation>())
        )
    }

    nonisolated static func deleteHumanScopedRows(
        for human: Human,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling,
        requiredHealthRows: HumanDeletionRequiredHealthRows? = nil
    ) -> Int {
        let humanId = human.id.uuidString
        var deletedCount = deleteHumanMedicationAndHealthRows(
            for: human,
            humanId: humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            requiredHealthRows: requiredHealthRows
        )
        deletedCount += deleteHumanCollectionsAndAchievements(
            humanId: humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        deletedCount += scrubHumanAttribution(
            for: human,
            in: context,
            at: deletedAt,
            by: deletedByHumanId,
            requiredHealthRows: requiredHealthRows
        )
        deletedCount += deleteHumanOwnedHistoryRows(
            for: human,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            requiredHealthRows: requiredHealthRows
        )
        deletedCount += deleteHumanSharedAndEconomyRows(
            human: human,
            humanId: humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        return deletedCount
    }

    private nonisolated static func deleteHumanMedicationAndHealthRows(
        for human: Human,
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        requiredHealthRows: HumanDeletionRequiredHealthRows?
    ) -> Int {
        var deletedCount = 0
        let ownedMedications = fetchAll(HumanMedication.self, context: context).filter {
            idsMatch($0.humanId, humanId)
        }
        let ownedMedicationIDs = Set(ownedMedications.map(\.id))
        deletedCount += deleteRows(ownedMedications, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanMedicationLog.self, context: context).filter { log in
            idsMatch(log.humanId, humanId)
                || UUID(
                    uuidString: log.medicationId.trimmingCharacters(in: .whitespacesAndNewlines)
                ).map(ownedMedicationIDs.contains) == true
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }

        let allHealthReports = requiredHealthRows?.reports
            ?? fetchAll(HumanHealthReport.self, context: context)
        let allHealthMetrics = requiredHealthRows?.metrics
            ?? fetchAll(HumanHealthMetricLog.self, context: context)
        let allHealthConditions = requiredHealthRows?.conditions
            ?? fetchAll(HumanHealthCondition.self, context: context)
        let allHealthObservations = requiredHealthRows?.observations
            ?? fetchAll(HumanHealthObservation.self, context: context)

        let ownedHealthReports = allHealthReports.filter {
            idsMatch($0.humanId, humanId)
        }
        let ownedHealthReportIDs = Set(ownedHealthReports.map(\.id))
        let metricsLinkedToOwnedReports = allHealthMetrics.filter {
            $0.sourceReportID.map(ownedHealthReportIDs.contains) == true
        }
        let unownedMetrics = metricsLinkedToOwnedReports.filter { $0.human == nil }
        let retainedMetrics = metricsLinkedToOwnedReports.filter {
            $0.human.map { $0.id != human.id } == true
        }
        deletedCount += deleteRows(unownedMetrics, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        for retainedMetric in retainedMetrics {
            retainedMetric.sourceReportID = nil
            CloudSyncMutationRecorder.markModified(
                retainedMetric,
                context: context,
                modifiedAt: deletedAt
            )
        }
        deletedCount += deleteRows(ownedHealthReports, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }

        let ownedHealthConditions = allHealthConditions.filter {
            idsMatch($0.humanId, humanId)
        }
        let ownedHealthConditionIDs = Set(ownedHealthConditions.map(\.id))
        deletedCount += deleteRows(allHealthObservations.filter { observation in
            idsMatch(observation.humanId, humanId)
                || UUID(
                    uuidString: observation.conditionId.trimmingCharacters(in: .whitespacesAndNewlines)
                ).map(ownedHealthConditionIDs.contains) == true
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(ownedHealthConditions, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        return deletedCount
    }

    private nonisolated static func deleteHumanCollectionsAndAchievements(
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        var deletedCount = deleteRows(fetchAll(WishlistItem.self, context: context).filter {
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
        return deletedCount
    }

    private nonisolated static func deleteHumanOwnedHistoryRows(
        for human: Human,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        requiredHealthRows: HumanDeletionRequiredHealthRows?
    ) -> Int {
        var deletedCount = deleteRows(fetchAll(HumanWeightLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        deletedCount += deleteRows(fetchAll(HumanWorkoutLog.self, context: context).filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        let allHealthMetrics = requiredHealthRows?.metrics
            ?? fetchAll(HumanHealthMetricLog.self, context: context)
        deletedCount += deleteRows(allHealthMetrics.filter { $0.human?.id == human.id }, context: context) {
            CloudSyncMutationRecorder.markDeleted($0, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        }
        return deletedCount
    }

    private nonisolated static func deleteHumanSharedAndEconomyRows(
        human: Human,
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        var deletedCount = deleteSharedCareUndoReceiptsReferencingHuman(humanId: humanId, context: context)
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
        deletedCount += deleteFamilyTaskPlansAndActivitiesReferencingHuman(
            humanId: humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        deletedCount += deleteGuardianSafetyProjections(
            ownerHumanID: human.id,
            context: context
        )
        return deletedCount
    }
}
