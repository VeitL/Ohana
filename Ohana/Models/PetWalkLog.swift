//
//  PetWalkLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

@Model
final class PetWalkLog {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distanceMeters: Double
    var coconutsEarned: Int
    var executorId: String? // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var executorIdsRaw: String = ""
    var sharedSessionId: String = ""
    @Attribute(.externalStorage) var mapSnapshotData: Data?
    @Attribute(.externalStorage) var routeLocationsData: Data?
    var pet: Pet?
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""
    // P1: 遛狗行为备注
    var behaviorNotes: String? // 如"今天很兴奋，追了一只猫"
    var moodRating: Int = 0 // 1-5颗星，0 = 未评价

    init(
        startDate: Date = Date(),
        pet: Pet? = nil,
        executorId: String? = nil,
        executorIds: [String] = [],
        sharedSessionId: String = ""
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.distanceMeters = 0
        self.coconutsEarned = 0
        let normalizedExecutorIds = SharedCareParticipantIDs.normalized(executorIds, preferredFirst: executorId)
        self.executorId = normalizedExecutorIds.first ?? executorId
        self.executorIdsRaw = SharedCareParticipantIDs.encode(normalizedExecutorIds)
        self.sharedSessionId = sharedSessionId
        self.mapSnapshotData = nil
        self.routeLocationsData = nil
        self.pet = pet
        self.behaviorNotes = nil
        self.moodRating = 0
    }

    /// Mirrors CoconutEconomyPolicyV2 walk reward display storage.
    static func coconuts(for distanceMeters: Double) -> Int {
        CoconutWalkRewardPolicy.earnedCoconuts(for: distanceMeters)
    }

    var executorIds: [String] {
        SharedCareParticipantIDs.decode(executorIdsRaw, fallback: executorId)
    }

    func setExecutorIds(_ ids: [String], primaryExecutorId: String? = nil) {
        let normalized = SharedCareParticipantIDs.normalized(ids, preferredFirst: primaryExecutorId ?? executorId)
        executorId = normalized.first
        executorIdsRaw = SharedCareParticipantIDs.encode(normalized)
    }

    var durationSeconds: TimeInterval {
        guard let endDate else { return 0 }
        return endDate.timeIntervalSince(startDate)
    }

    var durationText: String {
        let total = Int(durationSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }

    var distanceText: String {
        AppMeasurementSystem.formatDistanceMeters(distanceMeters)
    }
}
