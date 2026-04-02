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

    var systemIconName: String {
        switch self {
        case .feeding:           return "fork.knife"
        case .watering:          return "drop.fill"
        case .litter:            return "trash.fill"
        case .waterChange:       return "arrow.2.circlepath"
        case .filterClean:       return "sparkles"
        case .cageCleaning:      return "house.fill"
        case .freeFlight:        return "bird.fill"
        case .misting:           return "humidity.fill"
        case .substrateChange:   return "leaf.fill"
        case .play:              return "gamecontroller.fill"
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

    // MARK: - 喂食来源（手动 vs 按计划，互斥展示用）
    /// 首页/详情「按计划」打卡写入 `ohana_plan_feed:` + eventId
    static let plannedFeedNotePrefix = "ohana_plan_feed:"
    /// 首页/详情「手动记录」打卡写入
    static let manualFeedNoteMarker = "ohana_manual_feed"

    /// 是否为「按计划」产生的喂食记录
    var isPlannedFeedLogEntry: Bool {
        careType == .feeding && note.hasPrefix(Self.plannedFeedNotePrefix)
    }

    /// 是否为「手动记录」喂食（含旧数据 note 为空）
    var isManualFeedLogEntry: Bool {
        careType == .feeding && !isPlannedFeedLogEntry
    }
}

// MARK: - 首页喂食模式（与 QuickFeedDetailSheet 分段控件同步）
enum HomeFeedRecordMode: String {
    case manual
    case planned

    private static func storageKey(petId: UUID) -> String {
        "feedRecordMode_\(petId.uuidString)"
    }

    static func storedRaw(for petId: UUID) -> String {
        UserDefaults.standard.string(forKey: storageKey(petId: petId)) ?? Self.manual.rawValue
    }

    static func isPlanned(for petId: UUID) -> Bool {
        storedRaw(for: petId) == Self.planned.rawValue
    }

    static func set(_ petId: UUID, mode: HomeFeedRecordMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: storageKey(petId: petId))
    }
}
