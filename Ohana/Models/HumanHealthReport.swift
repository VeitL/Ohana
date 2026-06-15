//
//  HumanHealthReport.swift
//  Ohana
//
//  身体检测报告模型 — 记录人类成员的体检 / 检测结果

import Foundation
import SwiftData

/// 报告类型
enum HealthReportType: String, Codable, CaseIterable, Identifiable {
    case bloodTest = "血液检测"
    case urineTest = "尿液检测"
    case physical = "全身体检"
    case vision = "视力检查"
    case dental = "口腔检查"
    case cardiac = "心脏检查"
    case imaging = "影像检查"
    case allergy = "过敏检测"
    case other = "其他"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .bloodTest: "🩸"
        case .urineTest: "🧪"
        case .physical: "🏥"
        case .vision: "👁️"
        case .dental: "🦷"
        case .cardiac: "❤️"
        case .imaging: "📷"
        case .allergy: "🤧"
        case .other: "📋"
        }
    }

    var systemImage: String {
        switch self {
        case .bloodTest: "drop.fill"
        case .urineTest: "flask.fill"
        case .physical: "stethoscope"
        case .vision: "eye.fill"
        case .dental: "mouth.fill"
        case .cardiac: "heart.fill"
        case .imaging: "camera.metering.spot"
        case .allergy: "allergens.fill"
        case .other: "doc.text.fill"
        }
    }
}

/// 报告结论等级
enum ReportConclusion: String, Codable, CaseIterable, Identifiable {
    case normal = "正常"
    case attention = "注意"
    case abnormal = "异常"
    case critical = "危急"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .normal: "✅"
        case .attention: "⚠️"
        case .abnormal: "🔶"
        case .critical: "🔴"
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
