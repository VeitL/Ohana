//
//  PlantCareLog.swift
//  Ohana
//
//  植物养护日志：记录每次浇水/施肥的历史
//

import Foundation
import SwiftData

enum PlantCareType: String, Codable, CaseIterable, Identifiable, Sendable {
    case watering
    case fertilizing
    case repotting
    case pruning
    case misting
    case rotating
    case leafCleaning
    case pestCheck
    case photo
    case newLeaf
    case yellowLeaf
    case pestFound
    case customNote

    var id: String { rawValue }

    nonisolated var emoji: String {
        switch self {
        case .watering: "💧"
        case .fertilizing: "🌿"
        case .repotting: "🪴"
        case .pruning: "✂️"
        case .misting: "💦"
        case .rotating: "🔄"
        case .leafCleaning: "🍃"
        case .pestCheck: "🔎"
        case .photo: "📷"
        case .newLeaf: "🌱"
        case .yellowLeaf: "🍂"
        case .pestFound: "🐛"
        case .customNote: "📝"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .watering: "浇水"
        case .fertilizing: "施肥"
        case .repotting: "换盆"
        case .pruning: "修剪"
        case .misting: "喷雾"
        case .rotating: "转盆"
        case .leafCleaning: "清洁叶片"
        case .pestCheck: "检查病虫害"
        case .photo: "拍照"
        case .newLeaf: "新叶"
        case .yellowLeaf: "黄叶"
        case .pestFound: "发现虫害"
        case .customNote: "备注"
        }
    }

    nonisolated var eventType: EventType {
        switch self {
        case .watering:
            .watering
        case .fertilizing:
            .fertilizing
        case .repotting:
            .plantRepotting
        case .pruning:
            .plantPruning
        case .misting:
            .plantMisting
        case .rotating:
            .plantRotation
        case .leafCleaning:
            .plantLeafCleaning
        case .pestCheck, .pestFound:
            .plantPestCheck
        case .photo, .newLeaf, .yellowLeaf, .customNote:
            .plantHealthCheck
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
    @Attribute(.externalStorage) var photoData: Data?
    var healthStatusRaw: String = ""

    @Relationship(inverse: \Plant.careLogs) var plant: Plant?

    init(
        date: Date = Date(),
        careType: PlantCareType,
        note: String = "",
        executorId: String? = nil,
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.careTypeRaw = careType.rawValue
        self.note = note
        self.executorId = executorId
        self.photoData = photoData
        self.healthStatusRaw = healthStatus?.rawValue ?? ""
    }

    var careType: PlantCareType {
        PlantCareType(rawValue: careTypeRaw) ?? .watering
    }

    var healthStatus: PlantHealthStatus? {
        get { PlantHealthStatus(rawValue: healthStatusRaw) }
        set { healthStatusRaw = newValue?.rawValue ?? "" }
    }
}
