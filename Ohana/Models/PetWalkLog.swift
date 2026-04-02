//
//  PetWalkLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

@Model
final class PetWalkLog {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distanceMeters: Double
    var coconutsEarned: Int
    var executorId: String?  // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    @Attribute(.externalStorage) var mapSnapshotData: Data?
    @Attribute(.externalStorage) var routeLocationsData: Data?
    var pet: Pet?
    
    init(startDate: Date = Date(), pet: Pet? = nil, executorId: String? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.distanceMeters = 0
        self.coconutsEarned = 0
        self.executorId = executorId
        self.mapSnapshotData = nil
        self.routeLocationsData = nil
        self.pet = pet
    }

    /// 每 500m 奖励 1 椰子，最少 1 个
    static func coconuts(for distanceMeters: Double) -> Int {
        max(1, Int(distanceMeters / 500))
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
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        }
        return String(format: "%.0f m", distanceMeters)
    }
}
