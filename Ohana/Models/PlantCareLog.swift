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
        displayName(l: L10n.current)
    }

    nonisolated func displayName(l: L10n) -> String {
        switch self {
        case .watering: l.tr(zh: "浇水", en: "Watering", de: "Gießen")
        case .fertilizing: l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen")
        case .repotting: l.tr(zh: "换盆", en: "Repotting", de: "Umtopfen")
        case .pruning: l.tr(zh: "修剪", en: "Pruning", de: "Schneiden")
        case .misting: l.tr(zh: "喷雾", en: "Misting", de: "Besprühen")
        case .rotating: l.tr(zh: "转盆", en: "Rotate pot", de: "Topf drehen")
        case .leafCleaning: l.tr(zh: "清洁叶片", en: "Clean leaves", de: "Blätter reinigen")
        case .pestCheck: l.tr(zh: "检查病虫害", en: "Pest check", de: "Schädlingscheck")
        case .photo: l.tr(zh: "拍照", en: "Photo", de: "Foto")
        case .newLeaf: l.tr(zh: "新叶", en: "New leaf", de: "Neues Blatt")
        case .yellowLeaf: l.tr(zh: "黄叶", en: "Yellow leaf", de: "Gelbes Blatt")
        case .pestFound: l.tr(zh: "发现虫害", en: "Pests found", de: "Schädlinge entdeckt")
        case .customNote: l.tr(zh: "备注", en: "Note", de: "Notiz")
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
