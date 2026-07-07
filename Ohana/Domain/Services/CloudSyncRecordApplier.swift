//
//  CloudSyncRecordApplier.swift
//  Ohana
//
//  Applies fetched CloudKit records into the local SwiftData store.
//

import CloudKit
import Foundation
import SwiftData

nonisolated enum CloudSyncRecordApplyResult: Equatable, Sendable {
    case inserted(entityName: String, localRecordId: String)
    case updated(entityName: String, localRecordId: String)
    case deleted(entityName: String, localRecordId: String)
    case skippedStale(entityName: String, localRecordId: String)
    case skippedUnsupported(entityName: String)
}

nonisolated struct CloudSyncRecordApplySummary: Equatable, Sendable {
    static let empty = CloudSyncRecordApplySummary()

    var inserted = 0
    var updated = 0
    var deleted = 0
    var skippedStale = 0
    var skippedUnsupported = 0
    var failed = 0

    var hasMutations: Bool {
        inserted > 0 || updated > 0 || deleted > 0
    }

    mutating func record(_ result: CloudSyncRecordApplyResult) {
        switch result {
        case .inserted:
            inserted += 1
        case .updated:
            updated += 1
        case .deleted:
            deleted += 1
        case .skippedStale:
            skippedStale += 1
        case .skippedUnsupported:
            skippedUnsupported += 1
        }
    }
}

nonisolated struct CloudSyncRecordApplyOutcome {
    let result: CloudSyncRecordApplyResult
    let stateLocalRecordUUID: UUID?
    let notificationIdsToCancel: [String]

    init(
        result: CloudSyncRecordApplyResult,
        stateLocalRecordUUID: UUID? = nil,
        notificationIdsToCancel: [String] = []
    ) {
        self.result = result
        self.stateLocalRecordUUID = stateLocalRecordUUID
        self.notificationIdsToCancel = notificationIdsToCancel
    }
}

nonisolated struct LegacyRecycleBinFieldValues {
    let trashedAt: Date?
    let trashExpiresAt: Date?
    let trashBatchId: String
    let trashedByHumanId: String
}

nonisolated enum CloudSyncRecordApplyError: LocalizedError, Equatable {
    case missingLocalRecordId(recordName: String)
    case invalidLocalRecordId(entityName: String, localRecordId: String)

    var errorDescription: String? {
        switch self {
        case let .missingLocalRecordId(recordName):
            "Cloud sync record \(recordName) is missing a local record id."
        case let .invalidLocalRecordId(entityName, localRecordId):
            "Cloud sync \(entityName) record has an invalid local record id: \(localRecordId)."
        }
    }
}

nonisolated enum CloudSyncRecordApplier {
    @discardableResult
    static func apply(_ record: CKRecord, context: ModelContext) throws -> CloudSyncRecordApplyResult {
        let metadata = try RemoteMetadata(record: record)
        guard let descriptor = CloudSyncEntityRegistry.descriptor(for: metadata.entityName),
              descriptor.uploadsToCloudKit else {
            return .skippedUnsupported(entityName: metadata.entityName)
        }
        guard supportsApply(for: descriptor.entityName) else {
            return .skippedUnsupported(entityName: descriptor.entityName)
        }
        let existingState = try existingAppliedState(metadata: metadata, record: record, context: context)
        let existingStateRecordUUID = localRecordUUID(from: existingState)
        if let existingState,
           existingState.lastModifiedAt > metadata.lastModifiedAt {
            return .skippedStale(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        if metadata.isDeleted {
            let deletedRecordUUID = existingStateRecordUUID ?? metadata.localRecordUUID
            try deleteLocalModel(
                entityName: metadata.entityName,
                localRecordUUID: deletedRecordUUID,
                deletedAt: metadata.deletedAt ?? metadata.lastModifiedAt,
                deletedByHumanId: normalizedDeletionActorId(metadata.deletedByHumanId),
                context: context
            )
            let state = try upsertState(
                metadata: metadata,
                record: record,
                context: context,
                localRecordUUID: deletedRecordUUID
            )
            state.isDeleted = true
            state.isDeletionTombstone = true
            state.deletedAt = metadata.deletedAt ?? metadata.lastModifiedAt
            state.deletedByHumanId = metadata.deletedByHumanId
            CloudSyncMetadataService.markSynced(
                state,
                ckRecordName: record.recordID.recordName,
                ckChangeTag: record.recordChangeTag ?? "",
                ckZoneName: record.recordID.zoneID.zoneName,
                syncedAt: Date()
            )
            return .deleted(
                entityName: metadata.entityName,
                localRecordId: CloudSyncRecordState.normalizedRecordId(deletedRecordUUID)
            )
        }

        if let existingState,
           existingState.isDeletionTombstone || existingState.isDeleted {
            return .skippedStale(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let outcome = try applyLiveRecord(record, metadata: metadata, descriptor: descriptor, context: context)
        let result = outcome.result
        if case .skippedUnsupported = result {
            return result
        }
        let appliedLocalRecordUUID = outcome.stateLocalRecordUUID ?? existingStateRecordUUID ?? metadata.localRecordUUID
        try applyLegacyRecycleBinFieldsIfSupported(
            from: record,
            entityName: metadata.entityName,
            localRecordUUID: appliedLocalRecordUUID,
            context: context
        )
        let state = try upsertState(
            metadata: metadata,
            record: record,
            context: context,
            localRecordUUID: appliedLocalRecordUUID
        )
        state.isDeleted = false
        state.isDeletionTombstone = false
        state.deletedAt = nil
        state.deletedByHumanId = ""
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag ?? "",
            ckZoneName: record.recordID.zoneID.zoneName,
            syncedAt: Date()
        )
        if !outcome.notificationIdsToCancel.isEmpty {
            try saveCloudSyncApplyChanges(context: context)
            DomainRehydrateEffectsDispatcher.cancelNotifications(outcome.notificationIdsToCancel)
        }
        return result
    }

    @discardableResult
    static func applyHardDeletedRecord(
        recordID: CKRecord.ID,
        recordType: CKRecord.RecordType,
        deletedAt: Date = Date(),
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let entityName = CloudSyncRecordState.normalizedEntityName(recordType)
        guard let descriptor = CloudSyncEntityRegistry.descriptor(for: entityName),
              descriptor.uploadsToCloudKit else {
            return .skippedUnsupported(entityName: entityName)
        }
        guard supportsApply(for: descriptor.entityName) else {
            return .skippedUnsupported(entityName: descriptor.entityName)
        }
        let matchedState = try CloudSyncMetadataService.state(
            entityName: descriptor.entityName,
            ckRecordName: recordID.recordName,
            ckZoneName: recordID.zoneID.zoneName,
            context: context
        )
        let parsedLocalRecordId = CloudSyncRecordIdentityParser.localRecordIdFromRecordName(
            recordID.recordName,
            entityName: descriptor.entityName
        )
        guard let rawLocalRecordId = parsedLocalRecordId ?? matchedState?.localRecordId else {
            throw CloudSyncRecordApplyError.missingLocalRecordId(recordName: recordID.recordName)
        }
        let localRecordId = CloudSyncRecordState.normalizedRecordId(rawLocalRecordId)
        guard let localRecordUUID = UUID(uuidString: localRecordId) else {
            throw CloudSyncRecordApplyError.invalidLocalRecordId(
                entityName: descriptor.entityName,
                localRecordId: localRecordId
            )
        }

        let matchedHouseholdId = matchedState?.householdId.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawHouseholdId = CloudSyncRecordIdentityParser.householdIdFromZoneName(recordID.zoneID.zoneName)
            ?? (matchedHouseholdId?.isEmpty == false ? matchedHouseholdId : nil)
            ?? (descriptor.entityName == String(describing: Household.self) ? localRecordId : "")
        let householdId = CloudSyncRecordState.normalizedRecordId(rawHouseholdId)
        let householdUUID = UUID(uuidString: householdId)
        let recordKey = CloudSyncRecordState.recordKey(
            entityName: descriptor.entityName,
            localRecordId: localRecordId
        )

        try deleteLocalModel(
            entityName: descriptor.entityName,
            localRecordUUID: localRecordUUID,
            deletedAt: deletedAt,
            deletedByHumanId: nil,
            context: context
        )
        let state = try CloudSyncMetadataService.upsertAppliedRemoteState(
            snapshot: CloudSyncAppliedRecordStateSnapshot(
                recordKey: recordKey,
                entityName: descriptor.entityName,
                localRecordId: localRecordUUID,
                householdId: householdUUID,
                ckZoneName: recordID.zoneID.zoneName,
                ckRecordName: recordID.recordName,
                ckChangeTag: "",
                conflictPolicy: matchedState?.conflictPolicy ?? descriptor.defaultConflictPolicy,
                isDeleted: true,
                isDeletionTombstone: true,
                deletedAt: deletedAt,
                deletedByHumanId: "",
                lastModifiedAt: deletedAt,
                lastSyncedAt: Date(),
                createdAt: matchedState?.createdAt ?? deletedAt,
                updatedAt: Date()
            ),
            context: context
        )
        _ = state
        return .deleted(entityName: descriptor.entityName, localRecordId: localRecordId)
    }

    private static func supportsApply(for entityName: String) -> Bool {
        CloudSyncEntityRegistry.supportsUploadPipeline(for: entityName)
    }
}

enum CloudSyncRecordApplyPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "cloud.sync.apply.persistence.failed",
                defaultValue: "Unable to save cloud sync changes.",
                comment: "Shown when applying a cloud sync record cannot be saved."
            )
        }
    }
}

nonisolated struct RemoteMetadata {
    let entityName: String
    let recordKey: String
    let localRecordId: String
    let localRecordUUID: UUID
    let householdId: String
    let householdUUID: UUID?
    let isDeleted: Bool
    let deletedAt: Date?
    let deletedByHumanId: String
    let deletedByHumanUUID: UUID?
    let lastModifiedAt: Date
    let conflictPolicy: CloudSyncConflictPolicy

    init(record: CKRecord) throws {
        entityName = CloudSyncRecordState.normalizedEntityName(
            record.string(for: CloudSyncRecordFieldKey.entityName) ?? record.recordType
        )
        let rawLocalRecordId = record.string(for: CloudSyncRecordFieldKey.localRecordId)
            ?? CloudSyncRecordIdentityParser.localRecordIdFromRecordName(
                record.recordID.recordName,
                entityName: entityName
            )
        guard let rawLocalRecordId else {
            throw CloudSyncRecordApplyError.missingLocalRecordId(recordName: record.recordID.recordName)
        }
        let normalizedLocalRecordId = CloudSyncRecordState.normalizedRecordId(rawLocalRecordId)
        guard let localRecordUUID = UUID(uuidString: normalizedLocalRecordId) else {
            throw CloudSyncRecordApplyError.invalidLocalRecordId(
                entityName: entityName,
                localRecordId: normalizedLocalRecordId
            )
        }

        localRecordId = normalizedLocalRecordId
        self.localRecordUUID = localRecordUUID
        recordKey = record.string(for: CloudSyncRecordFieldKey.recordKey)
            ?? CloudSyncRecordState.recordKey(entityName: entityName, localRecordId: normalizedLocalRecordId)

        let rawHouseholdId = record.string(for: CloudSyncRecordFieldKey.householdId)
            ?? CloudSyncRecordIdentityParser.householdIdFromZoneName(record.recordID.zoneID.zoneName)
            ?? (entityName == String(describing: Household.self) ? normalizedLocalRecordId : "")
        householdId = CloudSyncRecordState.normalizedRecordId(rawHouseholdId)
        householdUUID = UUID(uuidString: householdId)
        isDeleted = record.bool(for: CloudSyncRecordFieldKey.isDeleted) ?? false
        deletedAt = record.date(for: CloudSyncRecordFieldKey.deletedAt)
        deletedByHumanId = record.string(for: CloudSyncRecordFieldKey.deletedByHumanId) ?? ""
        deletedByHumanUUID = UUID(uuidString: deletedByHumanId)
        lastModifiedAt = record.date(for: CloudSyncRecordFieldKey.lastModifiedAt)
            ?? record.modificationDate
            ?? Date(timeIntervalSinceReferenceDate: 0)
        conflictPolicy = record.string(for: CloudSyncRecordFieldKey.conflictPolicy)
            .flatMap(CloudSyncConflictPolicy.init(rawValue:))
            ?? CloudSyncMergePolicy.defaultConflictPolicy(for: entityName)
    }
}

private nonisolated enum CloudSyncRecordIdentityParser {
    static func localRecordIdFromRecordName(_ recordName: String, entityName: String) -> String? {
        let prefix = "\(entityName)_"
        guard recordName.hasPrefix(prefix) else { return nil }
        return String(recordName.dropFirst(prefix.count))
    }

    static func householdIdFromZoneName(_ zoneName: String) -> String? {
        let prefix = "household-"
        guard zoneName.hasPrefix(prefix) else { return nil }
        return String(zoneName.dropFirst(prefix.count))
    }
}
extension CKRecord {
    nonisolated func string(for key: String) -> String? {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] as? NSString {
            return value as String
        }
        return nil
    }

    nonisolated func int(for key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        return nil
    }

    nonisolated func double(for key: String) -> Double? {
        if let value = self[key] as? Double {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    nonisolated func bool(for key: String) -> Bool? {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.boolValue
        }
        return nil
    }

    nonisolated func date(for key: String) -> Date? {
        if let value = self[key] as? Date {
            return value
        }
        if let value = self[key] as? NSDate {
            return value as Date
        }
        return nil
    }

    nonisolated func stringList(for key: String) -> [String]? {
        if let value = self[key] as? [String] {
            return value
        }
        if let value = self[key] as? NSArray {
            return value.compactMap { $0 as? String }
        }
        return nil
    }

    nonisolated func assetData(for key: String) -> Data? {
        guard let asset = self[key] as? CKAsset,
              let fileURL = asset.fileURL else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }
}
