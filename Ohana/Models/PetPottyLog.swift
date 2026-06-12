//
//  PetPottyLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

nonisolated enum PottyType: String, Codable, CaseIterable {
    case perfectPoop = "完美便便"
    case softPoop = "软便"
    case liquidPoop = "水便"
    case pee = "尿尿"

    var emoji: String {
        switch self {
        case .perfectPoop: "💩"
        case .softPoop: "💦"
        case .liquidPoop: "🌊"
        case .pee: "💧"
        }
    }

    var systemIconName: String {
        switch self {
        case .perfectPoop: "seal.fill"
        case .softPoop: "circle.dashed"
        case .liquidPoop: "exclamationmark.triangle.fill"
        case .pee: "drop.fill"
        }
    }

    func localizedLabel(_ l: L10n) -> String {
        switch self {
        case .perfectPoop:
            l.tr(zh: "完美噗噗", en: "Great poop", de: "Top-Häufchen")
        case .softPoop:
            l.tr(zh: "软软噗噗", en: "Soft poop", de: "Weiches Häufchen")
        case .liquidPoop:
            l.tr(zh: "水水噗噗", en: "Watery poop", de: "Wässriges Häufchen")
        case .pee:
            l.tr(zh: "尿尿", en: "Pee", de: "Pipi")
        }
    }
}

@Model
final class PetPottyLog {
    #Index<PetPottyLog>([\.date])
    var id: UUID
    var date: Date
    var type: String
    var executorId: String? // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var latitude: Double?
    var longitude: Double?
    var locationAccuracyMeters: Double?
    var walkLogId: String?
    var sharedSessionId: String = ""
    var pet: Pet?
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    init(
        date: Date = Date(),
        type: PottyType = .perfectPoop,
        pet: Pet? = nil,
        executorId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationAccuracyMeters: Double? = nil,
        walkLogId: String? = nil,
        sharedSessionId: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.executorId = executorId
        self.latitude = latitude
        self.longitude = longitude
        self.locationAccuracyMeters = locationAccuracyMeters
        self.walkLogId = walkLogId
        self.sharedSessionId = sharedSessionId
        self.pet = pet
    }

    var pottyType: PottyType {
        PottyType(rawValue: type) ?? .perfectPoop
    }
}
