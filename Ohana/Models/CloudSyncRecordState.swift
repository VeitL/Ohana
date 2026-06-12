//
//  CloudSyncRecordState.swift
//  Ohana
//
//  Local sync envelope for future CKSyncEngine/CKShare integration.
//

import Foundation
import SwiftData

nonisolated enum CloudSyncConflictPolicy: String, Codable, CaseIterable {
    case lastWriterWins
    case maxValue
    case appendOnly
    case ledgerProjection
}

@Model
final class CloudSyncRecordState {
    #Index<CloudSyncRecordState>(
        [\.recordKey],
        [\.entityName, \.localRecordId],
        [\.householdId, \.hasPendingLocalChanges],
        [\.lastModifiedAt]
    )

    var id: UUID
    var recordKey: String
    var entityName: String
    var localRecordId: String
    var householdId: String
    var ckZoneName: String
    var ckRecordName: String
    var ckChangeTag: String
    var conflictPolicyRaw: String
    // Legacy column: SwiftData does not reliably persist this name as sync tombstone state.
    var isDeleted: Bool
    var isDeletionTombstone: Bool = false
    var deletedAt: Date?
    var deletedByHumanId: String
    var hasPendingLocalChanges: Bool
    var lastModifiedAt: Date
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var metadataJSON: String

    init(
        id: UUID = UUID(),
        entityName: String,
        localRecordId: UUID,
        householdId: UUID? = nil,
        ckZoneName: String = "",
        ckRecordName: String = "",
        ckChangeTag: String = "",
        conflictPolicy: CloudSyncConflictPolicy = .lastWriterWins,
        isDeleted: Bool = false,
        isDeletionTombstone: Bool? = nil,
        deletedAt: Date? = nil,
        deletedByHumanId: UUID? = nil,
        hasPendingLocalChanges: Bool = true,
        lastModifiedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadataJSON: String = ""
    ) {
        let normalizedEntityName = Self.normalizedEntityName(entityName)
        let normalizedRecordId = Self.normalizedRecordId(localRecordId)

        self.id = id
        self.recordKey = Self.recordKey(entityName: normalizedEntityName, localRecordId: normalizedRecordId)
        self.entityName = normalizedEntityName
        self.localRecordId = normalizedRecordId
        self.householdId = householdId.map(Self.normalizedRecordId) ?? ""
        self.ckZoneName = ckZoneName
        self.ckRecordName = ckRecordName
        self.ckChangeTag = ckChangeTag
        self.conflictPolicyRaw = conflictPolicy.rawValue
        self.isDeleted = isDeleted
        self.isDeletionTombstone = isDeletionTombstone ?? isDeleted
        self.deletedAt = deletedAt
        self.deletedByHumanId = deletedByHumanId.map(Self.normalizedRecordId) ?? ""
        self.hasPendingLocalChanges = hasPendingLocalChanges
        self.lastModifiedAt = lastModifiedAt
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataJSON = metadataJSON
    }

    var conflictPolicy: CloudSyncConflictPolicy {
        get { CloudSyncConflictPolicy(rawValue: conflictPolicyRaw) ?? .lastWriterWins }
        set { conflictPolicyRaw = newValue.rawValue }
    }

    static func recordKey(entityName: String, localRecordId: UUID) -> String {
        recordKey(entityName: normalizedEntityName(entityName), localRecordId: normalizedRecordId(localRecordId))
    }

    static func recordKey(entityName: String, localRecordId: String) -> String {
        "\(normalizedEntityName(entityName)):\(normalizedRecordId(localRecordId))"
    }

    static func normalizedEntityName(_ entityName: String) -> String {
        entityName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedRecordId(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    static func normalizedRecordId(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uuid = UUID(uuidString: trimmed) {
            return normalizedRecordId(uuid)
        }
        return trimmed.lowercased()
    }
}
