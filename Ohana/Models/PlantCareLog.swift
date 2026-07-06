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

enum PlantCareCategory: String, CaseIterable, Identifiable, Sendable {
    case hydration
    case nutrition
    case maintenance
    case health
    case growth

    nonisolated var id: String { rawValue }

    nonisolated func title(l: L10n) -> String {
        switch self {
        case .hydration:
            l.tr(zh: "水分与湿度", en: "Water & Humidity", de: "Wasser & Feuchte")
        case .nutrition:
            l.tr(zh: "营养与盆土", en: "Nutrition & Soil", de: "Nährstoffe & Erde")
        case .maintenance:
            l.tr(zh: "整理与养护", en: "Care & Grooming", de: "Pflege & Ordnung")
        case .health:
            l.tr(zh: "健康复查", en: "Health Review", de: "Gesundheitscheck")
        case .growth:
            l.tr(zh: "成长记录", en: "Growth Notes", de: "Wachstum")
        }
    }

    nonisolated func shortTitle(l: L10n) -> String {
        switch self {
        case .hydration:
            l.tr(zh: "水分", en: "Water", de: "Wasser")
        case .nutrition:
            l.tr(zh: "营养", en: "Feed", de: "Nährstoff")
        case .maintenance:
            l.tr(zh: "养护", en: "Care", de: "Pflege")
        case .health:
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .growth:
            l.tr(zh: "成长", en: "Growth", de: "Wachstum")
        }
    }

    nonisolated var icon: String {
        switch self {
        case .hydration:
            "drop.fill"
        case .nutrition:
            "leaf.fill"
        case .maintenance:
            "sparkles"
        case .health:
            "stethoscope"
        case .growth:
            "camera.macro"
        }
    }

    nonisolated var careTypes: [PlantCareType] {
        switch self {
        case .hydration:
            [.watering, .misting]
        case .nutrition:
            [.fertilizing, .repotting]
        case .maintenance:
            [.pruning, .leafCleaning, .rotating]
        case .health:
            [.pestCheck, .yellowLeaf, .pestFound]
        case .growth:
            [.photo, .newLeaf, .customNote]
        }
    }

    nonisolated var schedulableCareTypes: [PlantCareType] {
        switch self {
        case .hydration:
            [.watering, .misting]
        case .nutrition:
            [.fertilizing, .repotting]
        case .maintenance:
            [.pruning, .leafCleaning, .rotating]
        case .health:
            [.pestCheck]
        case .growth:
            []
        }
    }

    nonisolated var isSchedulable: Bool {
        !schedulableCareTypes.isEmpty
    }

    nonisolated var defaultCareType: PlantCareType {
        switch self {
        case .hydration:
            .watering
        case .nutrition:
            .fertilizing
        case .maintenance:
            .pruning
        case .health:
            .pestCheck
        case .growth:
            .photo
        }
    }

    nonisolated func contains(_ careType: PlantCareType) -> Bool {
        careTypes.contains(careType)
    }

    nonisolated static func category(for careType: PlantCareType) -> PlantCareCategory {
        allCases.first { $0.contains(careType) } ?? .growth
    }

    nonisolated static var schedulableCareTypes: [PlantCareType] {
        allCases.flatMap(\.schedulableCareTypes)
    }
}

extension PlantCareType {
    nonisolated var careCategory: PlantCareCategory {
        PlantCareCategory.category(for: self)
    }

    nonisolated var isSchedulablePlantCare: Bool {
        careCategory.schedulableCareTypes.contains(self)
    }
}

enum PlantCarePhotoAttachmentState: String, Codable, Sendable {
    case unknown
    case absent
    case present
}

@Model
final class PlantCareLog {
    var id: UUID
    var date: Date
    var careTypeRaw: String
    var note: String
    var executorId: String?
    @Attribute(.externalStorage) var photoData: Data?
    var photoAttachmentStateRaw: String = PlantCarePhotoAttachmentState.unknown.rawValue
    var photoImageSignature: String = ""
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
        self.photoAttachmentStateRaw = photoData == nil ? PlantCarePhotoAttachmentState.absent.rawValue : PlantCarePhotoAttachmentState.present.rawValue
        self.photoImageSignature = photoData.map(MediaPayloadSignature.signature(for:)) ?? ""
        self.healthStatusRaw = healthStatus?.rawValue ?? ""
    }

    var careType: PlantCareType {
        PlantCareType(rawValue: careTypeRaw) ?? .watering
    }

    var healthStatus: PlantHealthStatus? {
        get { PlantHealthStatus(rawValue: healthStatusRaw) }
        set { healthStatusRaw = newValue?.rawValue ?? "" }
    }

    var photoAttachmentState: PlantCarePhotoAttachmentState {
        get { PlantCarePhotoAttachmentState(rawValue: photoAttachmentStateRaw) ?? .unknown }
        set { photoAttachmentStateRaw = newValue.rawValue }
    }

    var hasPhotoAttachment: Bool {
        canAttemptPhotoAttachmentLoad
    }

    var canAttemptPhotoAttachmentLoad: Bool {
        photoAttachmentState != .absent
    }

    var photoThumbnailSignature: String {
        if !photoImageSignature.isEmpty {
            return photoImageSignature
        }
        guard canAttemptPhotoAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):photo:\(date.timeIntervalSince1970)"
    }

    var needsPhotoAttachmentIndexRepair: Bool {
        photoAttachmentState == .unknown || (hasPhotoAttachment && photoImageSignature.isEmpty)
    }

    func updatePhotoData(_ data: Data?) {
        photoData = data
        updatePhotoAttachmentIndex(for: data)
    }

    @discardableResult
    func repairPhotoAttachmentIndexIfNeeded() -> Bool {
        guard needsPhotoAttachmentIndexRepair else { return false }
        updatePhotoAttachmentIndex(for: photoData)
        return true
    }

    @discardableResult
    func backfillPhotoAttachmentPresence(hasData: Bool) -> Bool {
        if hasData {
            guard photoAttachmentState != .present else { return false }
            photoAttachmentState = .present
            return true
        }

        guard photoAttachmentState != .absent || !photoImageSignature.isEmpty else { return false }
        photoAttachmentState = .absent
        photoImageSignature = ""
        return true
    }

    private func updatePhotoAttachmentIndex(for data: Data?) {
        photoAttachmentState = data == nil ? .absent : .present
        photoImageSignature = data.map(MediaPayloadSignature.signature(for:)) ?? ""
    }
}
