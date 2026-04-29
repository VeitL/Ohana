//
//  PetHealthLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum HealthLogType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case general = "常规"
    case vaccine = "疫苗"
    case medication = "用药"          // 保留旧值，向下兼容
    case dewormingInternal = "体内驱虫"  // Bug8: 新增
    case dewormingExternal = "体外驱虫"  // Bug8: 新增
    case surgery = "手术"
    case dental = "牙科"
    case checkup = "体检"
    case emergency = "急诊"
    case other = "其他"
    
    var emoji: String {
        switch self {
        case .general:           return "📋"
        case .vaccine:           return "💉"
        case .medication:        return "💊"
        case .dewormingInternal: return "🪱"
        case .dewormingExternal: return "🐛"
        case .surgery:           return "🏥"
        case .dental:            return "🦷"
        case .checkup:           return "🩺"
        case .emergency:         return "🚨"
        case .other:             return "📝"
        }
    }

    /// Bug8: 是否需要设置有效期（疫苗 + 驱虫类型）
    var needsExpiration: Bool {
        switch self {
        case .vaccine, .dewormingInternal, .dewormingExternal, .medication: return true
        default: return false
        }
    }
}

@Model
final class PetHealthLog {
    var id: UUID
    var date: Date
    var type: String
    var note: String
    var vetName: String
    var cost: Double
    var expirationDate: Date?
    var nextCheckupDate: Date?  // 下次体检提醒日期（仅体检记录使用）
    var executorId: String?     // ArkSchemaV38: 执行该记录的 Human.id.uuidString
    var pet: Pet?
    
    init(date: Date = Date(), type: HealthLogType = .general, note: String = "", pet: Pet? = nil, executorId: String? = nil) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.note = note
        self.vetName = ""
        self.cost = 0
        self.expirationDate = nil
        self.nextCheckupDate = nil
        self.executorId = executorId
        self.pet = pet
    }
    
    var healthLogType: HealthLogType {
        HealthLogType(rawValue: type) ?? .general
    }
}
