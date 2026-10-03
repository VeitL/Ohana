//
//  PlantProfileEditorModels.swift
//  Ohana
//
//  Shared editor scope and focus taxonomy for the plant profile flow.
//

import Foundation

enum PlantProfileEditorScope: String, Identifiable, Sendable {
    case profile
    case fullCare

    var id: String { rawValue }
}

enum PlantEditFocusSection: String, CaseIterable, Identifiable {
    case all
    case identity
    case care
    case environment
    case potting
    case growth
    case safety
    case notes

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:
            "square.grid.2x2.fill"
        case .identity:
            "person.text.rectangle.fill"
        case .care:
            "calendar.badge.clock"
        case .environment:
            "sun.max.fill"
        case .potting:
            "shippingbox.fill"
        case .growth:
            "ruler.fill"
        case .safety:
            "shield.checkered"
        case .notes:
            "note.text"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .all:
            l.tr(zh: "全部", en: "All", de: "Alles")
        case .identity:
            l.tr(zh: "身份", en: "Identity", de: "Identität")
        case .care:
            l.tr(zh: "护理", en: "Care", de: "Pflege")
        case .environment:
            l.tr(zh: "环境", en: "Environment", de: "Umgebung")
        case .potting:
            l.tr(zh: "盆土", en: "Potting", de: "Topf")
        case .growth:
            l.tr(zh: "成长", en: "Growth", de: "Wachstum")
        case .safety:
            l.tr(zh: "安全", en: "Safety", de: "Sicherheit")
        case .notes:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }
}
