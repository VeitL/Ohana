//
//  HumanHealthReport.swift
//  Ohana
//
//  身体检测报告模型 — 记录人类成员的体检 / 检测结果

import SwiftUI
import SwiftData
import Foundation

/// 报告类型
enum HealthReportType: String, Codable, CaseIterable, Identifiable {
    case bloodTest      = "血液检测"
    case urineTest      = "尿液检测"
    case physical       = "全身体检"
    case vision         = "视力检查"
    case dental         = "口腔检查"
    case cardiac        = "心脏检查"
    case imaging        = "影像检查"
    case allergy        = "过敏检测"
    case other          = "其他"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .bloodTest:  return "🩸"
        case .urineTest:  return "🧪"
        case .physical:   return "🏥"
        case .vision:     return "👁️"
        case .dental:     return "🦷"
        case .cardiac:    return "❤️"
        case .imaging:    return "📷"
        case .allergy:    return "🤧"
        case .other:      return "📋"
        }
    }

    var systemImage: String {
        switch self {
        case .bloodTest:  return "drop.fill"
        case .urineTest:  return "flask.fill"
        case .physical:   return "stethoscope"
        case .vision:     return "eye.fill"
        case .dental:     return "mouth.fill"
        case .cardiac:    return "heart.fill"
        case .imaging:    return "camera.metering.spot"
        case .allergy:    return "allergens.fill"
        case .other:      return "doc.text.fill"
        }
    }
}

/// 报告结论等级
enum ReportConclusion: String, Codable, CaseIterable, Identifiable {
    case normal     = "正常"
    case attention  = "注意"
    case abnormal   = "异常"
    case critical   = "危急"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .normal:    return .goLime
        case .attention: return .goYellow
        case .abnormal:  return .goOrange
        case .critical:  return .goRed
        }
    }

    var emoji: String {
        switch self {
        case .normal:    return "✅"
        case .attention: return "⚠️"
        case .abnormal:  return "🔶"
        case .critical:  return "🔴"
        }
    }
}

/// 身体检测报告
@Model
final class HumanHealthReport {
    var id: UUID
    var humanId: String
    var reportTypeRaw: String
    var conclusionRaw: String
    var hospitalName: String
    var doctorName: String
    var reportDate: Date
    var nextCheckDate: Date?
    var summary: String
    var notes: String
    var colorHex: String
    var createdAt: Date

    init(
        humanId: String,
        reportType: HealthReportType = .physical,
        conclusion: ReportConclusion = .normal,
        hospitalName: String = "",
        doctorName: String = "",
        reportDate: Date = Date(),
        nextCheckDate: Date? = nil,
        summary: String = "",
        notes: String = "",
        colorHex: String = "00D4AA"
    ) {
        self.id = UUID()
        self.humanId = humanId
        self.reportTypeRaw = reportType.rawValue
        self.conclusionRaw = conclusion.rawValue
        self.hospitalName = hospitalName
        self.doctorName = doctorName
        self.reportDate = reportDate
        self.nextCheckDate = nextCheckDate
        self.summary = summary
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    var reportType: HealthReportType {
        get { HealthReportType(rawValue: reportTypeRaw) ?? .other }
        set { reportTypeRaw = newValue.rawValue }
    }

    var conclusion: ReportConclusion {
        get { ReportConclusion(rawValue: conclusionRaw) ?? .normal }
        set { conclusionRaw = newValue.rawValue }
    }

    var daysUntilNextCheck: Int? {
        guard let next = nextCheckDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: next).day
    }
}
