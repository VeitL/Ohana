//
//  CloudSyncEngineBatchBuilder.swift
//  Ohana
//
//  Converts local sync payloads into CKSyncEngine send batches.
//

import CloudKit
import Foundation

nonisolated enum CloudSyncEngineBatchBuilder {
    static func recordID(
        for payload: CloudSyncRecordPayload,
        ownerName: String = CKCurrentUserDefaultName
    ) -> CKRecord.ID {
        let zoneID = CKRecordZone.ID(zoneName: payload.zoneName, ownerName: ownerName)
        return CKRecord.ID(recordName: payload.recordName, zoneID: zoneID)
    }

    static func pendingSaveChanges(
        for payloads: [CloudSyncRecordPayload],
        ownerName: String = CKCurrentUserDefaultName
    ) -> [CKSyncEngine.PendingRecordZoneChange] {
        payloads.map { .saveRecord(recordID(for: $0, ownerName: ownerName)) }
    }

    static func recordZoneChangeBatch(
        for payloads: [CloudSyncRecordPayload],
        ownerName: String = CKCurrentUserDefaultName,
        sendScope: CKSyncEngine.SendChangesOptions.Scope? = nil,
        atomicByZone: Bool = false,
        assetFileURLProvider: CloudSyncRecordPayload.AssetFileURLProvider? = nil
    ) throws -> CKSyncEngine.RecordZoneChangeBatch? {
        let scopedPayloads = payloads.filter { payload in
            guard let sendScope else { return true }
            return sendScope.contains(.saveRecord(recordID(for: payload, ownerName: ownerName)))
        }
        guard !scopedPayloads.isEmpty else { return nil }

        let records = try scopedPayloads.map {
            try $0.makeCKRecord(
                ownerName: ownerName,
                assetFileURLProvider: assetFileURLProvider
            )
        }
        return CKSyncEngine.RecordZoneChangeBatch(
            recordsToSave: records,
            recordIDsToDelete: [],
            atomicByZone: atomicByZone
        )
    }
}
