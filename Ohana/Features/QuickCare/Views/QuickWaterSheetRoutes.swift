//
//  QuickWaterSheetRoutes.swift
//  Ohana
//
//  Sheet route metadata for QuickWaterDetailSheet.
//

import SwiftUI

enum QuickWaterActiveSheet: String, Identifiable {
    case waterSettings
    case waterAmount
    case waterPlan
    case filterSettings
    case history
    case waterOverview
    case waterChangeOverview
    case filterOverview

    var id: String { rawValue }

    var usesInlineOverlay: Bool {
        switch self {
        case .waterSettings, .waterAmount, .waterPlan, .filterSettings:
            return true
        case .history, .waterOverview, .waterChangeOverview, .filterOverview:
            return false
        }
    }

    var inlineHeight: CGFloat {
        switch self {
        case .waterAmount:
            return 430
        case .waterPlan:
            return 486
        case .waterSettings:
            return 420
        case .filterSettings:
            return 460
        case .history, .waterOverview, .waterChangeOverview, .filterOverview:
            return 720
        }
    }
}
