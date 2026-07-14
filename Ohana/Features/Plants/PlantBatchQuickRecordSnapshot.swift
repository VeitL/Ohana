//
//  PlantBatchQuickRecordSnapshot.swift
//  Ohana
//
//  Value-only candidates for multi-select plant quick care.
//

import Foundation
import SwiftData

nonisolated struct PlantBatchQuickRecordTargetSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let plantModelID: PersistentIdentifier
    let name: String
    let roomName: String
    let avatarSignature: String
    let tintHex: String
}

extension PlantBatchQuickRecordTargetSnapshot {
    static func activeTargets(from plants: [Plant]) -> [PlantBatchQuickRecordTargetSnapshot] {
        plants
            .filter { !$0.isArchived }
            .map {
                PlantBatchQuickRecordTargetSnapshot(
                    id: $0.id,
                    plantModelID: $0.persistentModelID,
                    name: $0.name,
                    roomName: $0.roomName,
                    avatarSignature: $0.avatarThumbnailSignature,
                    tintHex: $0.themeColorHex
                )
            }
    }
}
