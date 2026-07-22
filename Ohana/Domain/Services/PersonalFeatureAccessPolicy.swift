//
//  PersonalFeatureAccessPolicy.swift
//  Ohana
//
//  Semantic capability mapping for paid local features.
//

import Foundation

nonisolated enum PersonalFeature: String, CaseIterable, Hashable, Sendable {
    case extendedTrends
    case vetSummaryPDF
    case supporterAppearance
    case presenceLongRangeAnalytics
    case presenceCrossSubjectComparison
    case presenceDataExport
    case presenceAdvancedReminders
    case presenceEditableMessageTemplate
    case systemWidgets
}

nonisolated enum PersonalFeatureAccessPolicy {
    static func allows(
        _ feature: PersonalFeature,
        level: PersonalAccessLevel
    ) -> Bool {
        switch (level, feature) {
        case (.personal, _):
            true
        case (.free, _):
            false
        }
    }
}
