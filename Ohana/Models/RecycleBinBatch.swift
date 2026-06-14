//
//  RecycleBinBatch.swift
//  Ohana
//
//  Legacy V69 schema row retained only so stores that already migrated through
//  the cancelled recycle-bin model continue to open. No product flow creates,
//  restores, or syncs this row.
//

import Foundation
import SwiftData

@Model
final class RecycleBinBatch {
    var id: UUID
    var kindRaw: String
    var title: String
    var subtitle: String
    var sourceEntityName: String
    var sourceEntityId: String
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date
    var trashExpiresAt: Date
    var trashedByHumanId: String
    var metadataJSON: String

    init(
        id: UUID = UUID(),
        kindRaw: String,
        title: String,
        subtitle: String = "",
        sourceEntityName: String,
        sourceEntityId: String,
        trashedAt: Date,
        trashExpiresAt: Date,
        trashedByHumanId: String = "",
        metadataJSON: String = ""
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.title = title
        self.subtitle = subtitle
        self.sourceEntityName = sourceEntityName
        self.sourceEntityId = sourceEntityId
        self.trashedAt = trashedAt
        self.trashExpiresAt = trashExpiresAt
        self.trashedByHumanId = trashedByHumanId
        self.metadataJSON = metadataJSON
    }
}
