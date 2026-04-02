//
//  PlantCareLog.swift
//  Ohana
//
//  植物养护日志：记录每次浇水/施肥的历史
//

import SwiftUI
import SwiftData
import Foundation

enum PlantCareType: String, Codable, CaseIterable, Identifiable {
    case watering = "watering"
    case fertilizing = "fertilizing"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .watering: return "💧"
        case .fertilizing: return "🌿"
        }
    }

    var displayName: String {
        switch self {
        case .watering: return "浇水"
        case .fertilizing: return "施肥"
        }
    }
}

@Model
final class PlantCareLog {
    var id: UUID
    var date: Date
    var careTypeRaw: String
    var note: String
    var executorId: String?

    @Relationship(inverse: \Plant.careLogs) var plant: Plant?

    init(
        date: Date = Date(),
        careType: PlantCareType,
        note: String = "",
        executorId: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.careTypeRaw = careType.rawValue
        self.note = note
        self.executorId = executorId
    }

    var careType: PlantCareType {
        PlantCareType(rawValue: careTypeRaw) ?? .watering
    }
}
