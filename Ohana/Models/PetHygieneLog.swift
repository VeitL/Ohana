//
//  PetHygieneLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

enum HygieneType: String, Codable, CaseIterable {
    case teeth = "刷牙"
    case nails = "剪甲"
    case ears = "清耳"
    case brushing = "梳毛"
    case bath = "洗澡"

    var emoji: String {
        switch self {
        case .teeth: "🦷"
        case .nails: "✂️"
        case .ears: "👂"
        case .brushing: "🪮"
        case .bath: "🛁"
        }
    }

    var systemIconName: String {
        switch self {
        case .teeth: "mouth.fill"
        case .nails: "scissors"
        case .ears: "ear.fill"
        case .brushing: "comb.fill"
        case .bath: "drop.fill"
        }
    }

    func localizedLabel(_ l: L10n) -> String {
        switch self {
        case .teeth:
            l.tr(zh: "刷牙", en: "Teeth", de: "Zähne")
        case .nails:
            l.tr(zh: "剪甲", en: "Nails", de: "Krallen")
        case .ears:
            l.tr(zh: "清耳", en: "Ears", de: "Ohren")
        case .brushing:
            l.tr(zh: "梳毛", en: "Brushing", de: "Bürsten")
        case .bath:
            l.tr(zh: "洗澡", en: "Bath", de: "Bad")
        }
    }

    /// 系统默认周期天数
    var defaultCycleDays: Int {
        switch self {
        case .teeth: 1
        case .nails: 14
        case .ears: 7
        case .brushing: 3
        case .bath: 14
        }
    }

    /// 实际周期天数（优先使用用户自定义，fallback 到默认值）
    var cycleDays: Int { defaultCycleDays }
}

extension HygieneType: Identifiable {
    var id: String { rawValue }
}

@Model
final class PetHygieneLog {
    #Index<PetHygieneLog>([\.date])
    var id: UUID
    var date: Date
    var type: String
    var executorId: String? // ArkSchemaV38: 执行该记录的 Human.id.uuidString
    var pet: Pet?
    var sharedSessionId: String = ""
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    init(date: Date = Date(), type: HygieneType = .bath, pet: Pet? = nil, executorId: String? = nil, sharedSessionId: String = "") {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.executorId = executorId
        self.pet = pet
        self.sharedSessionId = sharedSessionId
    }

    var hygieneType: HygieneType {
        HygieneType(rawValue: type) ?? .bath
    }
}
