//
//  CloudSyncRecordApplier+State.swift
//  Ohana
//
//  Split helpers for applying CloudKit records into SwiftData.
//

import CloudKit
import Foundation
import SwiftData

extension CloudSyncRecordApplier {
    nonisolated static func upsertState(
        metadata: RemoteMetadata,
        record: CKRecord,
        context: ModelContext,
        localRecordUUID: UUID? = nil
    ) throws -> CloudSyncRecordState {
        let stateLocalRecordUUID = localRecordUUID ?? metadata.localRecordUUID
        let stateRecordKey = stateLocalRecordUUID == metadata.localRecordUUID
            ? metadata.recordKey
            : CloudSyncRecordState.recordKey(
                entityName: metadata.entityName,
                localRecordId: stateLocalRecordUUID
            )
        return try CloudSyncMetadataService.upsertAppliedRemoteState(
            snapshot: CloudSyncAppliedRecordStateSnapshot(
                recordKey: stateRecordKey,
                entityName: metadata.entityName,
                localRecordId: stateLocalRecordUUID,
                householdId: metadata.householdUUID,
                ckZoneName: record.recordID.zoneID.zoneName,
                ckRecordName: record.recordID.recordName,
                ckChangeTag: record.recordChangeTag ?? "",
                conflictPolicy: metadata.conflictPolicy,
                isDeleted: metadata.isDeleted,
                isDeletionTombstone: metadata.isDeleted,
                deletedAt: metadata.deletedAt,
                deletedByHumanId: metadata.deletedByHumanId,
                lastModifiedAt: metadata.lastModifiedAt,
                lastSyncedAt: nil,
                createdAt: metadata.lastModifiedAt,
                updatedAt: Date()
            ),
            context: context
        )
    }

    nonisolated static func existingAppliedState(
        metadata: RemoteMetadata,
        record: CKRecord,
        context: ModelContext
    ) throws -> CloudSyncRecordState? {
        if let state = try CloudSyncMetadataService.state(recordKey: metadata.recordKey, context: context) {
            return state
        }
        return try CloudSyncMetadataService.state(
            entityName: metadata.entityName,
            ckRecordName: record.recordID.recordName,
            ckZoneName: record.recordID.zoneID.zoneName,
            context: context
        )
    }

    nonisolated static func localRecordUUID(from state: CloudSyncRecordState?) -> UUID? {
        guard let state else { return nil }
        return UUID(uuidString: state.localRecordId)
    }
}
