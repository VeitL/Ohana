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
    var pet: Pet?
    
    init(
        date: Date = Date(),
        type: PottyType = .perfectPoop,
        pet: Pet? = nil,
        executorId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationAccuracyMeters: Double? = nil,
        walkLogId: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.executorId = executorId
        self.latitude = latitude
        self.longitude = longitude
        self.locationAccuracyMeters = locationAccuracyMeters
        self.walkLogId = walkLogId
        self.pet = pet
    }
    
    var pottyType: PottyType {
        PottyType(rawValue: type) ?? .perfectPoop
    }
}
