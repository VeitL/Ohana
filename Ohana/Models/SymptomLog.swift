//
//  SymptomLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

// MARK: - Symptom Severity
enum SymptomSeverity: Int, Codable, CaseIterable {
    case mild = 1
    case moderate = 2
    case severe = 3
    case critical = 4

    nonisolated var label: String {
        switch self {
        case .mild: "轻微"
        case .moderate: "中度"
        case .severe: "严重"
        case .critical: "紧急"
        }
    }

    var icon: String {
        switch self {
        case .mild: "exclamationmark.circle"
        case .moderate: "exclamationmark.triangle"
        case .severe: "exclamationmark.octagon.fill"
        case .critical: "bolt.horizontal.circle.fill"
        }
    }
}

// MARK: - Symptom Category
enum SymptomCategory: String, Codable, CaseIterable {
    case digestive = "消化系统" // 呕吐、软便、腹泻
    case respiratory = "呼吸系统" // 咳嗽、打喷嚏、气喘
    case mobility = "运动与骨骼" // 跛行、不愿走动
    case appetite = "饮食异常" // 食欲不振、饮水激增
    case skin = "皮肤与毛发" // 瘙痒、脱毛、红肿
    case behavior = "精神与行为" // 嗜睡、躲藏、异常叫唤
    case other = "其他"

    var emoji: String {
        switch self {
        case .digestive: "💩"
        case .respiratory: "😮‍💨"
        case .mobility: "🦴"
        case .appetite: "🥣"
        case .skin: "🩹"
        case .behavior: "💤"
        case .other: "🔍"
        }
    }
}

@Model
final class SymptomLog {
    var id: UUID
    var date: Date
    var categoryRaw: String
    var symptomName: String
    var severityRaw: Int
    var note: String
    var photoData: Data?
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    var pet: Pet?

    init(date: Date = Date(), category: SymptomCategory, symptomName: String, severity: SymptomSeverity, note: String = "", photoData: Data? = nil, pet: Pet? = nil) {
        self.id = UUID()
        self.date = date
        self.categoryRaw = category.rawValue
        self.symptomName = symptomName
        self.severityRaw = severity.rawValue
        self.note = note
        self.photoData = photoData
        self.pet = pet
    }

    var category: SymptomCategory {
        SymptomCategory(rawValue: categoryRaw) ?? .other
    }

    var severity: SymptomSeverity {
        SymptomSeverity(rawValue: severityRaw) ?? .mild
    }
}
