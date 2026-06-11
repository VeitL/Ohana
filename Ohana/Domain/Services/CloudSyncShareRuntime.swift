//
//  CloudSyncShareRuntime.swift
//  Ohana
//
//  Zone-wide CKShare helpers for shared households.
//

import CloudKit
import Foundation
import SwiftData

nonisolated enum CloudSyncShareRuntime {
    static let shareType = "com.guanchen.li.ohana.household"
    static let fallbackTitle = "Ohana Household"

    static func zoneID(
        householdId: UUID,
        ownerName: String = CKCurrentUserDefaultName
    ) -> CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: CloudSyncZoneNaming.zoneName(forHouseholdId: CloudSyncRecordState.normalizedRecordId(householdId)),
            ownerName: ownerName
        )
    }

    static func zoneWideShareRecordID(zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
    }

    static func isHouseholdShare(_ share: CKShare) -> Bool {
        let rawShareType = share[CKShare.SystemFieldKey.shareType] as? String
        return rawShareType == shareType
    }
}

nonisolated enum CloudSyncAccountUnavailableReason: Equatable, Sendable {
    case couldNotDetermine
    case noAccount
    case restricted
    case temporarilyUnavailable
}

nonisolated enum CloudSyncAccountAvailability: Equatable, Sendable {
    case available
    case unavailable(CloudSyncAccountUnavailableReason)
}

nonisolated protocol CloudSyncAccountStatusProviding {
    nonisolated func accountStatus() async throws -> CKAccountStatus
}

nonisolated struct CloudKitAccountStatusProvider: CloudSyncAccountStatusProviding {
    private let container: CKContainer

    init(containerIdentifier: String = CloudSyncEngineRuntime.containerIdentifier) {
        container = CKContainer(identifier: containerIdentifier)
    }

    nonisolated func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}

nonisolated enum CloudSyncAccountPreflight {
    static func availability(for status: CKAccountStatus) -> CloudSyncAccountAvailability {
        switch status {
        case .available:
            .available
        case .noAccount:
            .unavailable(.noAccount)
        case .restricted:
            .unavailable(.restricted)
        case .temporarilyUnavailable:
            .unavailable(.temporarilyUnavailable)
        case .couldNotDetermine:
            .unavailable(.couldNotDetermine)
        @unknown default:
            .unavailable(.couldNotDetermine)
        }
    }

    static func availability(
        provider: any CloudSyncAccountStatusProviding = CloudKitAccountStatusProvider()
    ) async -> CloudSyncAccountAvailability {
        do {
            let status = try await provider.accountStatus()
            return availability(for: status)
        } catch {
            return .unavailable(.couldNotDetermine)
        }
    }
}

nonisolated struct CloudSyncHouseholdSharePreparation: Sendable {
    let householdId: UUID
    let householdName: String
    let zoneID: CKRecordZone.ID
    let shareRecordID: CKRecord.ID
    let title: String
    let shareType: String
}

nonisolated enum CloudSyncHouseholdShareError: LocalizedError, Equatable {
    case shareRecordMissing(recordName: String)
    case recordWasNotShare(recordName: String)
    case shareMetadataMissing(url: URL)
    case acceptedShareMissing(url: URL)

    var errorDescription: String? {
        switch self {
        case let .shareRecordMissing(recordName):
            "CloudKit did not return the expected household share record: \(recordName)."
        case let .recordWasNotShare(recordName):
            "CloudKit returned \(recordName), but it was not a CKShare."
        case let .shareMetadataMissing(url):
            "CloudKit did not return share metadata for \(url.absoluteString)."
        case let .acceptedShareMissing(url):
            "CloudKit accepted the share URL but did not return a CKShare: \(url.absoluteString)."
        }
    }
}

final nonisolated class CloudSyncHouseholdShareService: @unchecked Sendable {
    private let containerProvider: () -> CKContainer

    var cloudKitContainer: CKContainer {
        containerProvider()
    }

    init(containerIdentifier: String = CloudSyncEngineRuntime.containerIdentifier) {
        containerProvider = {
            CKContainer(identifier: containerIdentifier)
        }
    }

    init(container: CKContainer) {
        containerProvider = {
            container
        }
    }

    func prepareZoneWideShare(
        householdId: UUID,
        householdName: String,
        ownerName: String = CKCurrentUserDefaultName
    ) -> CloudSyncHouseholdSharePreparation {
        let zoneID = CloudSyncShareRuntime.zoneID(householdId: householdId, ownerName: ownerName)

        return CloudSyncHouseholdSharePreparation(
            householdId: householdId,
            householdName: householdName,
            zoneID: zoneID,
            shareRecordID: CloudSyncShareRuntime.zoneWideShareRecordID(zoneID: zoneID),
            title: shareTitle(householdName),
            shareType: CloudSyncShareRuntime.shareType
        )
    }

    func existingShare(
        householdId: UUID,
        ownerName: String = CKCurrentUserDefaultName
    ) async throws -> CKShare? {
        let container = cloudKitContainer
        let zoneID = CloudSyncShareRuntime.zoneID(householdId: householdId, ownerName: ownerName)
        let recordID = CloudSyncShareRuntime.zoneWideShareRecordID(zoneID: zoneID)
        let results = try await container.privateCloudDatabase.records(for: [recordID])
        guard let result = results[recordID] else {
            throw CloudSyncHouseholdShareError.shareRecordMissing(recordName: recordID.recordName)
        }

        switch result {
        case let .success(record):
            guard let share = record as? CKShare else {
                throw CloudSyncHouseholdShareError.recordWasNotShare(recordName: recordID.recordName)
            }
            return share
        case let .failure(error):
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }

    func ensureShare(
        householdId: UUID,
        householdName: String,
        ownerName: String = CKCurrentUserDefaultName
    ) async throws -> CKShare {
        if let existing = try await existingShare(householdId: householdId, ownerName: ownerName) {
            return existing
        }

        let preparation = prepareZoneWideShare(
            householdId: householdId,
            householdName: householdName,
            ownerName: ownerName
        )
        try await ensureZoneExists(preparation.zoneID)
        let container = cloudKitContainer
        let share = makeZoneWideShare(from: preparation)
        let savedRecords = try await container.privateCloudDatabase.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        ).saveResults
        guard let result = savedRecords[share.recordID] else {
            throw CloudSyncHouseholdShareError.shareRecordMissing(recordName: share.recordID.recordName)
        }
        let record = try result.get()
        guard let share = record as? CKShare else {
            throw CloudSyncHouseholdShareError.recordWasNotShare(recordName: record.recordID.recordName)
        }
        return share
    }

    private func makeZoneWideShare(from preparation: CloudSyncHouseholdSharePreparation) -> CKShare {
        let share = CKShare(recordZoneID: preparation.zoneID)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = preparation.title as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = preparation.shareType as CKRecordValue
        return share
    }

    func shareMetadata(for url: URL) async throws -> CKShare.Metadata {
        let container = cloudKitContainer
        let results = try await container.shareMetadatas(for: [url])
        guard let result = results[url] else {
            throw CloudSyncHouseholdShareError.shareMetadataMissing(url: url)
        }
        return try result.get()
    }

    func acceptShare(url: URL) async throws -> CKShare {
        let metadata = try await shareMetadata(for: url)
        return try await acceptShare(metadata: metadata)
    }

    func acceptShare(metadata: CKShare.Metadata) async throws -> CKShare {
        let container = cloudKitContainer
        let results = try await container.accept([metadata])
        guard let result = results[metadata] else {
            throw CloudSyncHouseholdShareError.acceptedShareMissing(url: URL(fileURLWithPath: "/accepted-cloudkit-share"))
        }
        return try result.get()
    }

    private func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws {
        let container = cloudKitContainer
        let results = try await container.privateCloudDatabase.recordZones(for: [zoneID])
        if case .success = results[zoneID] {
            return
        }
        _ = try await container.privateCloudDatabase.modifyRecordZones(
            saving: [CKRecordZone(zoneID: zoneID)],
            deleting: []
        )
    }

    private func shareTitle(_ householdName: String) -> String {
        let trimmed = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? CloudSyncShareRuntime.fallbackTitle : trimmed
    }
}

nonisolated enum CloudSyncHouseholdShareStateUpdater {
    @discardableResult
    static func markSharePrepared(
        householdId: UUID,
        share: CKShare,
        context: ModelContext
    ) throws -> Bool {
        try markSharePrepared(
            householdId: householdId,
            shareRecordName: share.recordID.recordName,
            context: context
        )
    }

    @discardableResult
    static func markSharePrepared(
        householdId: UUID,
        shareRecordName: String,
        context: ModelContext
    ) throws -> Bool {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == householdId }
        )
        descriptor.fetchLimit = 1
        guard let household = try context.fetch(descriptor).first else {
            return false
        }
        household.ckShareRecordName = shareRecordName
        return true
    }

    @discardableResult
    static func markShareStopped(
        householdId: UUID,
        context: ModelContext
    ) throws -> Bool {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == householdId }
        )
        descriptor.fetchLimit = 1
        guard let household = try context.fetch(descriptor).first else {
            return false
        }
        household.ckShareRecordName = ""
        return true
    }
}

nonisolated struct CloudSyncHouseholdShareStopSummary: Equatable, Sendable {
    let householdId: UUID
    let shareRecordWasCleared: Bool
    let restagedSnapshot: CloudSyncInitialHouseholdMergeSummary

    var stagedRecordCount: Int {
        restagedSnapshot.stagedRecordCount
    }
}

@MainActor
enum CloudSyncHouseholdShareStopRuntime {
    static func stopSharingLocally(
        householdId: UUID,
        context: ModelContext,
        cloudSync: any CloudSyncManaging,
        backupManager: DataBackupManager = DataBackupManager(),
        modifiedAt: Date = Date()
    ) throws -> CloudSyncHouseholdShareStopSummary {
        let didClearShare = try CloudSyncHouseholdShareStateUpdater.markShareStopped(
            householdId: householdId,
            context: context
        )
        let restagedSnapshot = try CloudSyncInitialHouseholdMergeRuntime.stageLocalSnapshotForPrivateHouseholdSync(
            householdId: householdId,
            context: context,
            backupManager: backupManager,
            modifiedAt: modifiedAt
        )
        cloudSync.setDatabaseScope(.privateCloudDatabase, zoneOwnerName: nil)
        cloudSync.clearSharedZoneAccessRevokedNotice()

        return CloudSyncHouseholdShareStopSummary(
            householdId: householdId,
            shareRecordWasCleared: didClearShare,
            restagedSnapshot: restagedSnapshot
        )
    }
}

nonisolated enum CloudSyncAcceptedShareStateUpdater {
    @discardableResult
    @MainActor
    static func markAcceptedShare(
        _ share: CKShare,
        context: ModelContext
    ) throws -> UUID? {
        guard CloudSyncShareRuntime.isHouseholdShare(share),
              let householdId = householdId(from: share.recordID.zoneID) else {
            return nil
        }
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == householdId }
        )
        descriptor.fetchLimit = 1
        let household: Household
        if let existing = try context.fetch(descriptor).first {
            household = existing
        } else {
            household = Household(name: shareTitle(from: share))
            household.id = householdId
            household.createdAt = Date()
            context.insert(household)
        }
        household.ckShareRecordName = share.recordID.recordName
        if household.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            household.name = shareTitle(from: share)
        }
        return householdId
    }

    static func householdId(from zoneID: CKRecordZone.ID) -> UUID? {
        let prefix = "household-"
        guard zoneID.zoneName.hasPrefix(prefix) else { return nil }
        let rawId = String(zoneID.zoneName.dropFirst(prefix.count))
        return UUID(uuidString: CloudSyncRecordState.normalizedRecordId(rawId))
    }

    private static func shareTitle(from share: CKShare) -> String {
        let title = share[CKShare.SystemFieldKey.title] as? String
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? CloudSyncShareRuntime.fallbackTitle : trimmed
    }
}

protocol CloudSyncCurrentUserRecordIdentifying {
    func currentUserRecordName() async throws -> String
}

struct CloudKitCurrentUserRecordIdentifier: CloudSyncCurrentUserRecordIdentifying {
    private let container: CKContainer

    init(containerIdentifier: String = CloudSyncEngineRuntime.containerIdentifier) {
        container = CKContainer(identifier: containerIdentifier)
    }

    func currentUserRecordName() async throws -> String {
        try await container.userRecordID().recordName
    }
}

nonisolated enum CloudSyncHumanIdentityBinder {
    @discardableResult
    @MainActor
    static func bind(
        currentUserRecordName: String,
        toHumanId humanId: UUID,
        context: ModelContext
    ) throws -> Bool {
        let trimmed = currentUserRecordName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == humanId }
        )
        descriptor.fetchLimit = 1
        guard let human = try context.fetch(descriptor).first else {
            return false
        }
        human.appleUserIdentifier = trimmed
        return true
    }

    @discardableResult
    @MainActor
    static func bindCurrentCloudKitUser(
        toHumanId humanId: UUID,
        context: ModelContext,
        identifier: (any CloudSyncCurrentUserRecordIdentifying)? = nil
    ) async throws -> Bool {
        let identifier = identifier ?? CloudKitCurrentUserRecordIdentifier()
        let currentUserRecordName = try await identifier.currentUserRecordName()
        return try bind(
            currentUserRecordName: currentUserRecordName,
            toHumanId: humanId,
            context: context
        )
    }
}
