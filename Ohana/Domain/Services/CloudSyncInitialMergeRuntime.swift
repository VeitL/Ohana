//
//  CloudSyncInitialMergeRuntime.swift
//  Ohana
//
//  One-shot staging for local data when a household becomes shared.
//

import Foundation
import SwiftData

nonisolated struct CloudSyncInitialHouseholdMergeSummary: Equatable, Sendable {
    let householdId: UUID
    let snapshotRecordCount: Int
    var stagedRecordCount: Int
    var mergedHouseholdCount: Int
    var stagedByEntityName: [String: Int]

    mutating func recordStage(entityName: String) {
        stagedRecordCount += 1
        stagedByEntityName[CloudSyncRecordState.normalizedEntityName(entityName), default: 0] += 1
    }
}

@MainActor
enum CloudSyncInitialHouseholdMergeRuntime {
    private static let stagingMetadataJSON = #"{"source":"initialHouseholdShareMerge"}"#
    private static let privateRestageMetadataJSON = #"{"source":"shareStoppedPrivateRestage"}"#

    static func stageLocalSnapshotForHouseholdShare(
        householdId: UUID,
        context: ModelContext,
        backupManager: DataBackupManager = DataBackupManager(),
        modifiedAt: Date = Date()
    ) throws -> CloudSyncInitialHouseholdMergeSummary {
        try stageLocalSnapshot(
            householdId: householdId,
            context: context,
            backupManager: backupManager,
            modifiedAt: modifiedAt,
            metadataJSON: stagingMetadataJSON,
            shouldMergeLocalHouseholds: true
        )
    }

    static func stageLocalSnapshotForPrivateHouseholdSync(
        householdId: UUID,
        context: ModelContext,
        backupManager: DataBackupManager = DataBackupManager(),
        modifiedAt: Date = Date()
    ) throws -> CloudSyncInitialHouseholdMergeSummary {
        try stageLocalSnapshot(
            householdId: householdId,
            context: context,
            backupManager: backupManager,
            modifiedAt: modifiedAt,
            metadataJSON: privateRestageMetadataJSON,
            shouldMergeLocalHouseholds: false
        )
    }

    private static func stageLocalSnapshot(
        householdId: UUID,
        context: ModelContext,
        backupManager: DataBackupManager,
        modifiedAt: Date,
        metadataJSON: String,
        shouldMergeLocalHouseholds: Bool
    ) throws -> CloudSyncInitialHouseholdMergeSummary {
        let household = try sharedHousehold(householdId: householdId, context: context, createdAt: modifiedAt)
        let backup = try backupManager.buildBackup(context: context)
        var summary = CloudSyncInitialHouseholdMergeSummary(
            householdId: householdId,
            snapshotRecordCount: snapshotRecordCount(in: backup),
            stagedRecordCount: 0,
            mergedHouseholdCount: 0,
            stagedByEntityName: [:]
        )

        if shouldMergeLocalHouseholds {
            mergeLocalHouseholds(
                from: backup,
                into: household,
                acceptedHouseholdId: householdId,
                summary: &summary
            )
        }

        try stageEntity(
            String(describing: Household.self),
            ids: [householdId.uuidString],
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: Pet.self),
            ids: backup.pets.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: Human.self),
            ids: backup.humans.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetCareLog.self),
            ids: backup.petCareLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetPottyLog.self),
            ids: backup.petPottyLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetHygieneLog.self),
            ids: backup.petHygieneLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetHealthLog.self),
            ids: backup.petHealthLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetWalkLog.self),
            ids: backup.petWalkLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetExpenseLog.self),
            ids: backup.petExpenseLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: PetWeightLog.self),
            ids: backup.petWeightLogs.map(\.id),
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )
        try stageEntity(
            String(describing: CoconutLedgerEntry.self),
            ids: backup.coconutLedgerEntries?.map(\.id) ?? [],
            householdId: householdId,
            modifiedAt: modifiedAt,
            metadataJSON: metadataJSON,
            context: context,
            summary: &summary
        )

        return summary
    }

    private static func sharedHousehold(
        householdId: UUID,
        context: ModelContext,
        createdAt: Date
    ) throws -> Household {
        if let household = try fetchHousehold(id: householdId, context: context) {
            return household
        }
        let household = Household()
        household.id = householdId
        household.createdAt = createdAt
        context.insert(household)
        return household
    }

    private static func mergeLocalHouseholds(
        from backup: OhanaBackup,
        into household: Household,
        acceptedHouseholdId: UUID,
        summary: inout CloudSyncInitialHouseholdMergeSummary
    ) {
        let acceptedId = CloudSyncRecordState.normalizedRecordId(acceptedHouseholdId)
        for dto in backup.households where CloudSyncRecordState.normalizedRecordId(dto.id) != acceptedId {
            let name = dto.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if household.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !name.isEmpty {
                household.name = name
            }
            household.totalProsperity = max(household.totalProsperity, dto.totalProsperity)
            if let createdAt = DataBackupManager().iso.date(from: dto.createdAt), createdAt < household.createdAt {
                household.createdAt = createdAt
            }
            summary.mergedHouseholdCount += 1
        }
    }

    private static func stageEntity(
        _ entityName: String,
        ids: [String],
        householdId: UUID,
        modifiedAt: Date,
        metadataJSON: String,
        context: ModelContext,
        summary: inout CloudSyncInitialHouseholdMergeSummary
    ) throws {
        let normalizedEntityName = CloudSyncRecordState.normalizedEntityName(entityName)
        guard CloudSyncEntityRegistry.descriptor(for: normalizedEntityName)?.uploadsToCloudKit == true,
              CloudSyncEntityRegistry.supportsUploadPipeline(for: normalizedEntityName) else {
            return
        }

        for id in ids {
            guard let localRecordId = UUID(uuidString: id.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }
            let state = try CloudSyncMetadataService.markModified(
                entityName: normalizedEntityName,
                localRecordId: localRecordId,
                householdId: householdId,
                modifiedAt: modifiedAt,
                metadataJSON: metadataJSON,
                context: context
            )
            rehome(state, to: householdId)
            summary.recordStage(entityName: normalizedEntityName)
        }
    }

    private static func rehome(_ state: CloudSyncRecordState, to householdId: UUID) {
        let normalizedHouseholdId = CloudSyncRecordState.normalizedRecordId(householdId)
        state.householdId = normalizedHouseholdId
        state.ckZoneName = CloudSyncZoneNaming.zoneName(forHouseholdId: normalizedHouseholdId)
        state.ckChangeTag = ""
        state.hasPendingLocalChanges = true
    }

    private static func fetchHousehold(id: UUID, context: ModelContext) throws -> Household? {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func snapshotRecordCount(in backup: OhanaBackup) -> Int {
        backup.pets.count
            + backup.humans.count
            + backup.events.count
            + backup.reminders.count
            + backup.households.count
            + backup.plants.count
            + backup.petCareLogs.count
            + backup.petPottyLogs.count
            + backup.petWalkLogs.count
            + backup.petWeightLogs.count
            + backup.petExpenseLogs.count
            + backup.petHealthLogs.count
            + backup.petHygieneLogs.count
            + backup.petFoodRecords.count
            + backup.petDocuments.count
            + (backup.petDocumentAttachments?.count ?? 0)
            + backup.petMilestones.count
            + (backup.petPhotoLogs?.count ?? 0)
            + (backup.petInsurances?.count ?? 0)
            + (backup.insuranceClaims?.count ?? 0)
            + (backup.petMedications?.count ?? 0)
            + (backup.symptomLogs?.count ?? 0)
            + (backup.heatCycleLogs?.count ?? 0)
            + backup.humanWeightLogs.count
            + backup.humanWorkoutLogs.count
            + (backup.humanMedications?.count ?? 0)
            + (backup.humanMedicationLogs?.count ?? 0)
            + (backup.humanHealthMetricLogs?.count ?? 0)
            + backup.waterLogs.count
            + backup.wishlistItems.count
            + (backup.careLedgerEvents?.count ?? 0)
            + (backup.coconutAccounts?.count ?? 0)
            + (backup.coconutLedgerEntries?.count ?? 0)
            + (backup.familyCollaborationTasks?.count ?? 0)
            + (backup.sharedCareSessions?.count ?? 0)
            + (backup.coconutExchangeRequests?.count ?? 0)
            + (backup.oasisUpgradeCoconuts?.count ?? 0)
            + (backup.oasisElectronicPets?.count ?? 0)
            + (backup.oasisCritterFragments?.count ?? 0)
            + (backup.oasisUnlocks?.count ?? 0)
            + (backup.oasisCritterActionLogs?.count ?? 0)
            + (backup.gachaOwnedItems?.count ?? 0)
            + (backup.gachaDrawLogs?.count ?? 0)
    }
}
