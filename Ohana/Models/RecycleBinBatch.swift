//
//  RecycleBinBatch.swift
//  Ohana
//
//  Metadata row for grouped recycle-bin operations.
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
