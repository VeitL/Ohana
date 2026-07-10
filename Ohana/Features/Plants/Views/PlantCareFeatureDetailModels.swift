//
//  PlantCareFeatureDetailModels.swift
//  Ohana
//
//  Small value models used by the plant care feature detail route.
//

import Foundation
import SwiftUI

struct PlantCareFeatureLogDraft: Identifiable {
    let id = UUID()
    let plantID: UUID
    let careType: PlantCareType
}

struct PlantWateringChartPoint: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let intervalDays: Int
}

struct PlantWateringSignal: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let tint: Color
}

struct PlantCareAggregateInsight: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
}

enum PlantWaterGuidedMode: String, CaseIterable, Identifiable {
    case overview
    case plan
    case history

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview:
            "drop.circle.fill"
        case .plan:
            "calendar.badge.clock"
        case .history:
            "clock.arrow.circlepath"
        }
    }

    func title(l: L10n) -> String {
        switch self {
        case .overview:
            l.tr(zh: "概览", en: "Overview", de: "Übersicht")
        case .plan:
            l.tr(zh: "计划", en: "Plan", de: "Plan")
        case .history:
            l.tr(zh: "历史", en: "History", de: "Verlauf")
        }
    }
}

enum WaterReminderLeadOption: Int, CaseIterable, Identifiable {
    case sameDay = 0
    case oneDay = 1
    case twoDays = 2
    case oneWeek = 7

    var id: Int { rawValue }

    func title(l: L10n) -> String {
        switch self {
        case .sameDay:
            l.tr(zh: "当天", en: "Same day", de: "Am selben Tag")
        case .oneDay:
            l.tr(zh: "提前 1 天", en: "1 day before", de: "1 Tag vorher")
        case .twoDays:
            l.tr(zh: "提前 2 天", en: "2 days before", de: "2 Tage vorher")
        case .oneWeek:
            l.tr(zh: "提前 7 天", en: "7 days before", de: "7 Tage vorher")
        }
    }
}
