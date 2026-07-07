//
//  PetHealthLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

nonisolated enum HealthLogType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case general = "常规"
    case vaccine = "疫苗"
    case medication = "用药" // 保留旧值，向下兼容
    case dewormingInternal = "体内驱虫" // Bug8: 新增
    case dewormingExternal = "体外驱虫" // Bug8: 新增
    case surgery = "手术"
    case dental = "牙科"
    case checkup = "体检"
    case emergency = "急诊"
    case other = "其他"

    var emoji: String {
        switch self {
        case .general: "📋"
        case .vaccine: "💉"
        case .medication: "💊"
        case .dewormingInternal: "🪱"
        case .dewormingExternal: "🐛"
        case .surgery: "🏥"
        case .dental: "🦷"
        case .checkup: "🩺"
        case .emergency: "🚨"
        case .other: "📝"
        }
    }

    /// Bug8: 是否需要设置有效期（疫苗 + 驱虫类型）
    var needsExpiration: Bool {
        switch self {
        case .vaccine, .dewormingInternal, .dewormingExternal, .medication: true
        default: false
        }
    }

    func localizedLabel(_ l: L10n) -> String {
        switch self {
        case .general:
            l.tr(zh: "常规", en: "General", de: "Allgemein")
        case .vaccine:
            l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .medication:
            l.tr(zh: "用药", en: "Medication", de: "Medikation")
        case .dewormingInternal:
            l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal:
            l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .surgery:
            l.tr(zh: "手术", en: "Surgery", de: "Operation")
        case .dental:
            l.tr(zh: "牙科", en: "Dental", de: "Zähne")
        case .checkup:
            l.tr(zh: "体检", en: "Checkup", de: "Check-up")
        case .emergency:
            l.tr(zh: "急诊", en: "Emergency", de: "Notfall")
        case .other:
            l.tr(zh: "其他", en: "Other", de: "Sonstiges")
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
    var nextCheckupDate: Date? // 下次体检提醒日期（仅体检记录使用）
    var executorId: String? // ArkSchemaV38: 执行该记录的 Human.id.uuidString
    var pet: Pet?
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

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
