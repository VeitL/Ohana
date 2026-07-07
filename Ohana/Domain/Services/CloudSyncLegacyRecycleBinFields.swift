//
//  CloudSyncLegacyRecycleBinFields.swift
//  Ohana
//
//  CloudSync-only compatibility for stores that migrated through the retired
//  recoverable-delete model. This preserves legacy columns across future sync
//  peers without reviving user-visible recycle-bin behavior.
//

nonisolated enum CloudSyncLegacyRecycleBinFieldKey {
    static let trashedAt = "trashedAt"
    static let trashExpiresAt = "trashExpiresAt"
    static let trashBatchId = "trashBatchId"
    static let trashedByHumanId = "trashedByHumanId"
}
