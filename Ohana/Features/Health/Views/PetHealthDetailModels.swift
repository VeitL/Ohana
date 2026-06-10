//
//  PetHealthDetailModels.swift
//  Ohana
//
//  Route and render support values for PetHealthDetailContentView.
//

import Foundation
import SwiftUI

// MARK: - 健康添加 Sheet 路由
enum HealthPlusDestination: Identifiable {
    case guided(HealthRecordEntryMode)
    case direct(HealthLogType)
    case medications
    case symptom     // 新增
    case heatCycle   // 新增

    var id: String {
        switch self {
        case .guided(let m):
            return m == .preventive ? "guide_p" : "guide_v"
        case .direct(let t):
            return "dir_\(t.rawValue)"
        case .medications:
            return "meds"
        case .symptom:
            return "symptom"
        case .heatCycle:
            return "heat"
        }
    }

    var usesInlineRecordPopup: Bool {
        switch self {
        case .guided, .direct:
            return true
        case .medications, .symptom, .heatCycle:
            return false
        }
    }
}

// MARK: - Health Scatter Point (散点时间轴)
struct HealthScatterPoint: Identifiable {
    let id = UUID()
    let date: Date
    let typeName: String
    let typeEnum: HealthLogType
}

struct HealthActivityItem: Identifiable {
    let id: String
    let date: Date
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

enum ActiveHealthSheet: Identifiable {
    case preventiveOverview
    case medicationOverview
    case symptomVisitOverview

    var id: String {
        switch self {
        case .preventiveOverview: return "preventiveOverview"
        case .medicationOverview: return "medicationOverview"
        case .symptomVisitOverview: return "symptomVisitOverview"
        }
    }
}

enum HealthFabActionKind: String, Identifiable {
    case preventive
    case visit
    case medication
    case vaccinePassport
    case archive
    case pdf
    case symptom
    case heatCycle

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .preventive: return "shield.checkered"
        case .visit: return "cross.case.fill"
        case .medication: return "pill.fill"
        case .vaccinePassport: return "syringe.fill"
        case .archive: return "folder.fill"
        case .pdf: return "doc.richtext"
        case .symptom: return "exclamationmark.triangle.fill"
        case .heatCycle: return "heart.text.square.fill"
        }
    }

    func label(_ l: L10n, isRenderingPDF: Bool = false) -> String {
        switch self {
        case .preventive:
            return l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge")
        case .visit:
            return l.tr(zh: "就诊记录", en: "Visit record", de: "Besuchseintrag")
        case .medication:
            return l.tr(zh: "添加药物", en: "Add medication", de: "Medikament")
        case .vaccinePassport:
            return l.tr(zh: "疫苗本", en: "Vaccine passport", de: "Impfpass")
        case .archive:
            return l.tr(zh: "完整档案", en: "Full archive", de: "Vollständige Akte")
        case .pdf:
            return isRenderingPDF
                ? l.tr(zh: "PDF 生成中", en: "Rendering PDF", de: "PDF wird erstellt")
                : l.tr(zh: "导出 PDF", en: "Export PDF", de: "PDF exportieren")
        case .symptom:
            return l.tr(zh: "记录异常", en: "Log symptom", de: "Symptom")
        case .heatCycle:
            return l.tr(zh: "生理期", en: "Heat cycle", de: "Läufigkeit")
        }
    }
}

enum PetHealthInitialSection: Hashable {
    case preventive
    case medication
    case symptomVisit
}

struct PetHealthPreventionItem: Identifiable {
    let type: HealthLogType
    let icon: String
    let title: String
    let cycleDays: Int
    let latestLog: PetHealthLog?
    let dueDate: Date?
    let daysRemaining: Int?

    var id: String { type.rawValue }
}

struct PetHealthMedicationDoseItem: Identifiable {
    let medication: PetMedication
    let scheduledAt: Date
    let doseIndex: Int
    let isCompleted: Bool

    var id: String {
        "\(medication.id.uuidString)-\(Int(scheduledAt.timeIntervalSince1970 / 60))-\(doseIndex)"
    }
}
