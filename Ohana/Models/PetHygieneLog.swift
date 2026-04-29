//
//  PetHygieneLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum HygieneType: String, Codable, CaseIterable {
    case teeth = "刷牙"
    case nails = "剪甲"
    case ears = "清耳"
    case brushing = "梳毛"
    case bath = "洗澡"
    
    var emoji: String {
        switch self {
        case .teeth: return "🦷"
        case .nails: return "✂️"
        case .ears: return "👂"
        case .brushing: return "🪮"
        case .bath: return "🛁"
        }
    }

    var systemIconName: String {
        switch self {
        case .teeth:    return "mouth.fill"
        case .nails:    return "scissors"
        case .ears:     return "ear.fill"
        case .brushing: return "comb.fill"
        case .bath:     return "drop.fill"
        }
    }
    
    /// 系统默认周期天数
    var defaultCycleDays: Int {
        switch self {
        case .teeth: return 1
        case .nails: return 14
        case .ears: return 7
        case .brushing: return 3
        case .bath: return 14
        }
    }

    /// 实际周期天数（优先使用用户自定义，fallback 到默认值）
    var cycleDays: Int { defaultCycleDays }

    /// UserDefaults key for custom cycle
    static func customCycleDaysKey(petId: UUID, type: HygieneType) -> String {
        "hygiene_cycle_\(petId.uuidString)_\(type.rawValue)"
    }

    /// 读取某只宠物某类型的自定义周期天数（nil 表示使用默认值）
    static func customCycleDays(for type: HygieneType, petId: UUID) -> Int? {
        let key = customCycleDaysKey(petId: petId, type: type)
        let v = UserDefaults.standard.integer(forKey: key)
        return v > 0 ? v : nil
    }

    /// 设定自定义周期天数（≤0 表示恢复默认）
    static func setCustomCycleDays(_ days: Int, for type: HygieneType, petId: UUID) {
        let key = customCycleDaysKey(petId: petId, type: type)
        if days > 0 {
            UserDefaults.standard.set(days, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// 获取针对特定宠物的实际周期天数（自定义优先）
    func effectiveCycleDays(for petId: UUID) -> Int {
        HygieneType.customCycleDays(for: self, petId: petId) ?? defaultCycleDays
    }
}

@Model
final class PetHygieneLog {
    #Index<PetHygieneLog>([\.date])
    var id: UUID
    var date: Date
    var type: String
    var executorId: String? // ArkSchemaV38: 执行该记录的 Human.id.uuidString
    var pet: Pet?
    
    init(date: Date = Date(), type: HygieneType = .bath, pet: Pet? = nil, executorId: String? = nil) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.executorId = executorId
        self.pet = pet
    }
    
    var hygieneType: HygieneType {
        HygieneType(rawValue: type) ?? .bath
    }
}
