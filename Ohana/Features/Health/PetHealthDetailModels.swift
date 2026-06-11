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
    case symptom // 新增
    case heatCycle // 新增

    var id: String {
        switch self {
        case let .guided(m):
            m == .preventive ? "guide_p" : "guide_v"
        case let .direct(t):
            "dir_\(t.rawValue)"
        case .medications:
            "meds"
        case .symptom:
            "symptom"
        case .heatCycle:
            "heat"
        }
    }

    var usesInlineRecordPopup: Bool {
        switch self {
        case .guided, .direct:
            true
        case .medications, .symptom, .heatCycle:
            false
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
        case .preventiveOverview: "preventiveOverview"
        case .medicationOverview: "medicationOverview"
        case .symptomVisitOverview: "symptomVisitOverview"
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
        case .preventive: "shield.checkered"
        case .visit: "cross.case.fill"
        case .medication: "pill.fill"
        case .vaccinePassport: "syringe.fill"
        case .archive: "folder.fill"
        case .pdf: "doc.richtext"
        case .symptom: "exclamationmark.triangle.fill"
        case .heatCycle: "heart.text.square.fill"
        }
    }

    func label(_ l: L10n, isRenderingPDF: Bool = false) -> String {
        switch self {
        case .preventive:
            l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge")
        case .visit:
            l.tr(zh: "就诊记录", en: "Visit record", de: "Besuchseintrag")
        case .medication:
            l.tr(zh: "添加药物", en: "Add medication", de: "Medikament")
        case .vaccinePassport:
            l.tr(zh: "疫苗本", en: "Vaccine passport", de: "Impfpass")
        case .archive:
            l.tr(zh: "完整档案", en: "Full archive", de: "Vollständige Akte")
        case .pdf:
            isRenderingPDF
                ? l.tr(zh: "PDF 生成中", en: "Rendering PDF", de: "PDF wird erstellt")
                : l.tr(zh: "导出 PDF", en: "Export PDF", de: "PDF exportieren")
        case .symptom:
            l.tr(zh: "记录异常", en: "Log symptom", de: "Symptom")
        case .heatCycle:
            l.tr(zh: "生理期", en: "Heat cycle", de: "Läufigkeit")
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
