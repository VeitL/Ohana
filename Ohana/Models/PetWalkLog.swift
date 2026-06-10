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
    var sharedSessionId: String = ""
    @Attribute(.externalStorage) var mapSnapshotData: Data?
    @Attribute(.externalStorage) var routeLocationsData: Data?
    var pet: Pet?
    // P1: 遛狗行为备注
    var behaviorNotes: String? // 如"今天很兴奋，追了一只猫"
    var moodRating: Int = 0 // 1-5颗星，0 = 未评价

    init(startDate: Date = Date(), pet: Pet? = nil, executorId: String? = nil, sharedSessionId: String = "") {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.distanceMeters = 0
        self.coconutsEarned = 0
        self.executorId = executorId
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
