//
//  SymptomLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

// MARK: - Symptom Severity
enum SymptomSeverity: Int, Codable, CaseIterable {
    case mild = 1
    case moderate = 2
    case severe = 3
    case critical = 4

    var label: String {
        switch self {
        case .mild: return "轻微"
        case .moderate: return "中度"
        case .severe: return "严重"
        case .critical: return "紧急"
        }
    }
    
    var icon: String {
        switch self {
        case .mild: return "exclamationmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .severe: return "exclamationmark.octagon.fill"
        case .critical: return "bolt.horizontal.circle.fill"
        }
    }
}

// MARK: - Symptom Category
enum SymptomCategory: String, Codable, CaseIterable {
    case digestive = "消化系统"     // 呕吐、软便、腹泻
    case respiratory = "呼吸系统"   // 咳嗽、打喷嚏、气喘
    case mobility = "运动与骨骼"     // 跛行、不愿走动
    case appetite = "饮食异常"       // 食欲不振、饮水激增
    case skin = "皮肤与毛发"         // 瘙痒、脱毛、红肿
    case behavior = "精神与行为"     // 嗜睡、躲藏、异常叫唤
    case other = "其他"

    var emoji: String {
        switch self {
        case .digestive: return "💩"
        case .respiratory: return "😮‍💨"
        case .mobility: return "🦴"
        case .appetite: return "🥣"
        case .skin: return "🩹"
        case .behavior: return "💤"
        case .other: return "🔍"
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
