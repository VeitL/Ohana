//
//  HumanHealthMetricReferenceEvaluator.swift
//  Ohana
//
//  Resolves a recorded metric against the source laboratory's own flag/range
//  before falling back to the app catalog's general reference range.
//

import Foundation

@MainActor
enum HumanHealthMetricReferenceEvaluator {
    static func hasSourceReference(_ log: HumanHealthMetricLog) -> Bool {
        !log.referenceRangeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || log.referenceLow != nil
            || log.referenceHigh != nil
    }

    static func status(
        for log: HumanHealthMetricLog,
        fallbackUnit: HealthMetricUnit
    ) -> HealthMetricStatus {
        switch log.reportedFlagRaw {
        case "low":
            return .low
        case "high", "critical":
            return .high
        case "normal":
            return .normal
        default:
            break
        }

        if let low = log.referenceLow, log.value < low {
            return .low
        }
        if let high = log.referenceHigh, log.value > high {
            return .high
        }
        if log.referenceLow != nil || log.referenceHigh != nil {
            return .normal
        }
        return fallbackUnit.status(for: log.value)
    }

    static func referenceLabel(
        for log: HumanHealthMetricLog,
        fallbackUnit: HealthMetricUnit,
        includeUnit: Bool = true
    ) -> String {
        let sourceText = log.referenceRangeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceText.isEmpty {
            return sourceText
        }

        let suffix = includeUnit ? " \(fallbackUnit.label)" : ""
        switch (log.referenceLow, log.referenceHigh) {
        case let (.some(low), .some(high)):
            return "\(fallbackUnit.formatted(low))–\(fallbackUnit.formatted(high))\(suffix)"
        case let (.some(low), .none):
            return "≥ \(fallbackUnit.formatted(low))\(suffix)"
        case let (.none, .some(high)):
            return "≤ \(fallbackUnit.formatted(high))\(suffix)"
        default:
            return fallbackUnit.normalRangeLabel(includeUnit: includeUnit)
        }
    }
}
