//
//  PetPottyLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum PottyType: String, Codable, CaseIterable {
    case perfectPoop = "完美便便"
    case softPoop = "软便"
    case liquidPoop = "水便"
    case pee = "尿尿"
    
    var emoji: String {
        switch self {
        case .perfectPoop: return "💩"
        case .softPoop: return "💦"
        case .liquidPoop: return "🌊"
        case .pee: return "💧"
        }
    }

    var systemIconName: String {
        switch self {
        case .perfectPoop: return "seal.fill"
        case .softPoop:    return "circle.dashed"
        case .liquidPoop:  return "exclamationmark.triangle.fill"
        case .pee:         return "drop.fill"
        }
    }

    func localizedLabel(_ l: L10n) -> String {
        switch self {
        case .perfectPoop:
            return l.tr(zh: "完美噗噗", en: "Great poop", de: "Top-Häufchen")
        case .softPoop:
            return l.tr(zh: "软软噗噗", en: "Soft poop", de: "Weiches Häufchen")
        case .liquidPoop:
            return l.tr(zh: "水水噗噗", en: "Watery poop", de: "Wässriges Häufchen")
        case .pee:
            return l.tr(zh: "尿尿", en: "Pee", de: "Pipi")
        }
    }
}

@Model
final class PetPottyLog {
    #Index<PetPottyLog>([\.date])
    var id: UUID
    var date: Date
    var type: String
    var executorId: String?  // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var latitude: Double?
    var longitude: Double?
    var locationAccuracyMeters: Double?
    var walkLogId: String?
    var sharedSessionId: String = ""
    var pet: Pet?
    
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
