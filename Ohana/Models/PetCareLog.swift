//
//  PetCareLog.swift
//  Ohana
//
//  喂食 / 喂水 / 铲屎 追踪记录（V7 新增）
//

import SwiftData
import Foundation

// MARK: - Care Type
enum CareType: String, CaseIterable, Codable {
    // 基础
    case feeding      = "喂食"
    case watering     = "喂水"
    case litter       = "铲屎"
    // 鱼类
    case waterChange  = "换水"
    case filterClean  = "清理滤材"
    // 鸟类
    case cageCleaning = "清理鸟笼"
    case freeFlight   = "放飞互动"
    // 爬宠/其他
    case misting      = "喷水保湿"
    case substrateChange = "换垫材"
    // 通用互动
    case play         = "逗玩"

    var emoji: String {
        switch self {
        case .feeding:        return "🍽️"
        case .watering:       return "💧"
        case .litter:         return "🧹"
        case .waterChange:    return "🪣"
        case .filterClean:    return "🔧"
        case .cageCleaning:   return "🧺"
        case .freeFlight:     return "🕊️"
        case .misting:        return "💦"
        case .substrateChange: return "🪵"
        case .play:           return "🎾"
        }
    }

    var accentColorHex: String {
        switch self {
        case .feeding:        return "FF8C00"
        case .watering:       return "00D4AA"
        case .litter:         return "FFF44F"
        case .waterChange:    return "4ECDC4"
        case .filterClean:    return "A78BFA"
        case .cageCleaning:   return "80FFEA"
        case .freeFlight:     return "C8FF00"
        case .misting:        return "00D4FF"
        case .substrateChange: return "D4A574"
        case .play:           return "FF6B6B"
        }
    }

    var label: String { rawValue }
}

// MARK: - Model
@Model
final class PetCareLog {
    #Index<PetCareLog>([\.date])
    var id: UUID
    var date: Date
    var type: String       // CareType.rawValue
    var amountGrams: Double  // 仅 feeding 用（喂食克数）
    var amountMl: Double     // 仅 watering 用（喂水毫升）
    var note: String
    var executorId: String?  // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var pet: Pet?

    init(
        date: Date = Date(),
        type: CareType = .feeding,
        amountGrams: Double = 0,
        amountMl: Double = 0,
        note: String = "",
        pet: Pet? = nil,
        executorId: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.amountGrams = amountGrams
        self.amountMl = amountMl
        self.note = note
        self.executorId = executorId
        self.pet = pet
    }

    var careType: CareType { CareType(rawValue: type) ?? .feeding }
}
