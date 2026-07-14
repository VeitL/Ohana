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
        false
    }

    var inlineHeight: CGFloat {
        switch self {
        case .waterAmount:
            430
        case .waterPlan:
            486
        case .waterSettings:
            420
        case .filterSettings:
            460
        case .history, .waterOverview, .waterChangeOverview, .filterOverview:
            720
        }
    }
}
