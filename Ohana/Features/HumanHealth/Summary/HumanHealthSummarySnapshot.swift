//
//  HumanHealthSummarySnapshot.swift
//  Ohana
//
//  Bounded, value-only presentation state for the Human health overview.
//

import Foundation

nonisolated enum HumanHealthSummaryDestination: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case medication
    case metrics
    case conditions
    case reports
    case weight
    case workouts

    var id: String { rawValue }
}

nonisolated enum HumanHealthSummaryRoute: Hashable, Sendable {
    case feature(HumanHealthSummaryDestination)
    case metric(String)
}

nonisolated enum HumanHealthSummaryDoseState: Equatable, Sendable {
    case pending
    case taken
    case skipped
}

nonisolated enum HumanHealthSummaryMetricStatus: Equatable, Sendable {
    case low
    case normal
    case high
    case unknown

    var needsReview: Bool {
        self == .low || self == .high
    }
}

nonisolated enum HumanHealthSummarySourceState: Equatable, Sendable {
    case hidden
    case unavailable
    case localOnly
    case appleHealthBound
}

nonisolated struct HumanHealthSummaryDoseInput: Equatable, Sendable {
    let medicationID: UUID
    let name: String
    let dosage: String
    let scheduledTime: Date
    let state: HumanHealthSummaryDoseState
}

nonisolated struct HumanHealthSummaryMetricInput: Equatable, Sendable {
    let id: UUID
    let metricKey: String
    let unitCode: String
    let value: Double
    let date: Date
    let createdAt: Date
    let status: HumanHealthSummaryMetricStatus
}

nonisolated struct HumanHealthSummaryReportInput: Equatable, Sendable {
    let id: UUID
    let reportTypeRaw: String
    let reportDate: Date
    let nextCheckDate: Date?
    let createdAt: Date
}

nonisolated struct HumanHealthSummaryConditionInput: Equatable, Sendable {
    let id: UUID
    let name: String
    let isActive: Bool
    let updatedAt: Date
}

nonisolated struct HumanHealthSummaryObservationInput: Equatable, Sendable {
    let id: UUID
    let conditionID: UUID?
    let recordedAt: Date
    let severity: Int
    let moodScore: Int?
}

nonisolated struct HumanHealthSummaryInput: Equatable, Sendable {
    var bodyIsVisible = true
    var medicationIsVisible = true
    var workoutIsVisible = true
    var activeMedicationPlanCount = 0
    var medicationPlansAreTruncated = false
    var medicationLogsAreTruncated = false
    var metricLogsAreTruncated = false
    var reportsAreTruncated = false
    var conditionsAreTruncated = false
    var observationsAreTruncated = false
    var doses: [HumanHealthSummaryDoseInput] = []
    var metrics: [HumanHealthSummaryMetricInput] = []
    var reports: [HumanHealthSummaryReportInput] = []
    var conditions: [HumanHealthSummaryConditionInput] = []
    var observations: [HumanHealthSummaryObservationInput] = []
    var sourceState: HumanHealthSummarySourceState = .localOnly
}

nonisolated struct HumanHealthSummaryDose: Equatable, Sendable {
    let medicationID: UUID
    let name: String
    let dosage: String
    let scheduledTime: Date
}

nonisolated struct HumanHealthSummaryMetric: Equatable, Sendable, Identifiable {
    let metricKey: String
    let unitCode: String
    let value: Double
    let date: Date
    let status: HumanHealthSummaryMetricStatus

    var id: String { metricKey }
}

nonisolated struct HumanHealthSummaryFollowUp: Equatable, Sendable {
    let reportID: UUID
    let reportTypeRaw: String
    let date: Date
    let timing: HumanHealthSummaryFollowUpTiming
}

nonisolated enum HumanHealthSummaryFollowUpTiming: Equatable, Sendable {
    case overdue(days: Int)
    case upcoming(days: Int)

    var isOverdue: Bool {
        if case .overdue = self { return true }
        return false
    }
}

nonisolated struct HumanHealthSummaryObservation: Equatable, Sendable {
    let observationID: UUID
    let conditionName: String
    let recordedAt: Date
    let severity: Int
    let moodScore: Int?
}

nonisolated enum HumanHealthSummaryTrendDirection: Equatable, Sendable {
    case rising
    case steady
    case falling
}

nonisolated struct HumanHealthSummaryTrend: Equatable, Sendable, Identifiable {
    let metricKey: String
    let unitCode: String
    let currentValue: Double
    let previousValue: Double
    let currentDate: Date
    let status: HumanHealthSummaryMetricStatus

    var id: String { "\(metricKey):\(unitCode)" }

    var direction: HumanHealthSummaryTrendDirection {
        let scale = max(abs(currentValue), abs(previousValue), 1)
        let tolerance = scale * 0.001
        if currentValue > previousValue + tolerance { return .rising }
        if currentValue < previousValue - tolerance { return .falling }
        return .steady
    }
}

nonisolated enum HumanHealthSummaryHighlight: Equatable, Sendable, Identifiable {
    case dosesRemaining(Int)
    case dosesHandled(Int)
    case latestMetricsWithoutReviewFlag(Int)
    case latestMetricsNeedReview(Int)
    case metricReviewIncomplete(Int)
    case recentObservation(HumanHealthSummaryObservation)
    case followUp(HumanHealthSummaryFollowUp)

    var id: String {
        switch self {
        case .dosesRemaining: "doses-remaining"
        case .dosesHandled: "doses-handled"
        case .latestMetricsWithoutReviewFlag: "metrics-without-review-flag"
        case .latestMetricsNeedReview: "metrics-need-review"
        case .metricReviewIncomplete: "metrics-review-incomplete"
        case .recentObservation: "recent-observation"
        case .followUp: "follow-up"
        }
    }
}

nonisolated enum HumanHealthSummaryFollowUpStatus: Equatable, Sendable {
    case attention(HumanHealthSummaryFollowUp)
    case incomplete
    case none
}

nonisolated enum HumanHealthSummaryFocusKind: String, Equatable, Sendable, Identifiable {
    case medication
    case metrics
    case followUp
    case observation
    case conditions

    var id: String { rawValue }

    var destination: HumanHealthSummaryDestination {
        switch self {
        case .medication: .medication
        case .metrics: .metrics
        case .followUp: .reports
        case .observation, .conditions: .conditions
        }
    }
}

nonisolated struct HumanHealthSummaryBoundedCount: Equatable, Sendable {
    let loaded: Int
    let isTruncated: Bool
}

nonisolated struct HumanHealthSummaryRecordCounts: Equatable, Sendable {
    let activeMedicationPlans: HumanHealthSummaryBoundedCount
    let trackedMetrics: HumanHealthSummaryBoundedCount
    let reports: HumanHealthSummaryBoundedCount
    let activeConditions: HumanHealthSummaryBoundedCount
}

nonisolated struct HumanHealthSummarySnapshot: Equatable, Sendable {
    let bodyIsVisible: Bool
    let medicationIsVisible: Bool
    let workoutIsVisible: Bool
    let scheduledDoseCount: Int
    let pendingDoseCount: Int
    let nextPendingDose: HumanHealthSummaryDose?
    let latestMetricCount: Int
    let abnormalMetrics: [HumanHealthSummaryMetric]
    let followUpAttention: HumanHealthSummaryFollowUp?
    let recentObservation: HumanHealthSummaryObservation?
    let activeConditionCount: Int
    let medicationLogsAreTruncated: Bool
    let medicationScheduleIsIncomplete: Bool
    let metricLogsAreTruncated: Bool
    let observationsAreTruncated: Bool
    let focusItems: [HumanHealthSummaryFocusKind]
    let highlights: [HumanHealthSummaryHighlight]
    let trends: [HumanHealthSummaryTrend]
    let recordCounts: HumanHealthSummaryRecordCounts
    let sourceState: HumanHealthSummarySourceState

    var followUpStatus: HumanHealthSummaryFollowUpStatus {
        if let followUpAttention {
            return .attention(followUpAttention)
        }
        return recordCounts.reports.isTruncated ? .incomplete : .none
    }
}

nonisolated enum HumanHealthSummaryBuilder {
    static let maximumFocusItemCount = 4
    static let maximumHighlightCount = 3
    static let maximumTrendCount = 3

    static func build(
        input: HumanHealthSummaryInput,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HumanHealthSummarySnapshot {
        let sortedDoses = input.doses.sorted { lhs, rhs in
            if lhs.scheduledTime != rhs.scheduledTime {
                return lhs.scheduledTime < rhs.scheduledTime
            }
            return lhs.medicationID.uuidString < rhs.medicationID.uuidString
        }
        let pendingDoses = sortedDoses.filter { $0.state == .pending }
        let latestMetrics = latestMetricsByKey(input.metrics)
        let abnormalMetrics = latestMetrics
            .filter(\.status.needsReview)
            .map {
                HumanHealthSummaryMetric(
                    metricKey: $0.metricKey,
                    unitCode: $0.unitCode,
                    value: $0.value,
                    date: $0.date,
                    status: $0.status
                )
            }
        let followUpAttention = followUpAttention(
            reports: input.reports,
            now: now,
            calendar: calendar
        )
        let recentObservation = recentObservation(
            observations: input.observations,
            conditions: input.conditions,
            now: now,
            calendar: calendar
        )
        let activeConditionCount = input.conditions.count(where: \.isActive)
        let trends = metricTrends(input.metrics)
        let focusItems = focusItems(
            pendingDoseCount: pendingDoses.count,
            abnormalMetricCount: abnormalMetrics.count,
            followUp: followUpAttention,
            recentObservation: recentObservation,
            activeConditionCount: activeConditionCount
        )
        let medicationScheduleIsIncomplete = input.medicationPlansAreTruncated || input.medicationLogsAreTruncated
        let highlights = highlights(
            scheduledDoseCount: sortedDoses.count,
            pendingDoseCount: pendingDoses.count,
            medicationScheduleIsIncomplete: medicationScheduleIsIncomplete,
            latestMetricCount: latestMetrics.count,
            abnormalMetricCount: abnormalMetrics.count,
            metricReviewIsIncomplete: input.metricLogsAreTruncated,
            recentObservation: recentObservation,
            followUp: followUpAttention
        )

        return HumanHealthSummarySnapshot(
            bodyIsVisible: input.bodyIsVisible,
            medicationIsVisible: input.medicationIsVisible,
            workoutIsVisible: input.workoutIsVisible,
            scheduledDoseCount: sortedDoses.count,
            pendingDoseCount: pendingDoses.count,
            nextPendingDose: pendingDoses.first.map {
                HumanHealthSummaryDose(
                    medicationID: $0.medicationID,
                    name: $0.name,
                    dosage: $0.dosage,
                    scheduledTime: $0.scheduledTime
                )
            },
            latestMetricCount: latestMetrics.count,
            abnormalMetrics: abnormalMetrics,
            followUpAttention: followUpAttention,
            recentObservation: recentObservation,
            activeConditionCount: activeConditionCount,
            medicationLogsAreTruncated: input.medicationLogsAreTruncated,
            medicationScheduleIsIncomplete: medicationScheduleIsIncomplete,
            metricLogsAreTruncated: input.metricLogsAreTruncated,
            observationsAreTruncated: input.observationsAreTruncated,
            focusItems: Array(focusItems.prefix(maximumFocusItemCount)),
            highlights: Array(highlights.prefix(maximumHighlightCount)),
            trends: Array(trends.prefix(maximumTrendCount)),
            recordCounts: HumanHealthSummaryRecordCounts(
                activeMedicationPlans: HumanHealthSummaryBoundedCount(
                    loaded: max(0, input.activeMedicationPlanCount),
                    isTruncated: input.medicationPlansAreTruncated
                ),
                trackedMetrics: HumanHealthSummaryBoundedCount(
                    loaded: Set(latestMetrics.map(\.metricKey)).count,
                    isTruncated: input.metricLogsAreTruncated
                ),
                reports: HumanHealthSummaryBoundedCount(
                    loaded: input.reports.count,
                    isTruncated: input.reportsAreTruncated
                ),
                activeConditions: HumanHealthSummaryBoundedCount(
                    loaded: activeConditionCount,
                    isTruncated: input.conditionsAreTruncated
                )
            ),
            sourceState: input.sourceState
        )
    }

    private static func latestMetricsByKey(
        _ metrics: [HumanHealthSummaryMetricInput]
    ) -> [HumanHealthSummaryMetricInput] {
        var latestByKey: [String: HumanHealthSummaryMetricInput] = [:]
        for metric in metrics where metric.value.isFinite {
            if let existing = latestByKey[metric.metricKey],
               !isNewer(metric, than: existing) {
                continue
            }
            latestByKey[metric.metricKey] = metric
        }
        return latestByKey.values.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.metricKey < $1.metricKey
        }
    }

    private static func followUpAttention(
        reports: [HumanHealthSummaryReportInput],
        now: Date,
        calendar: Calendar
    ) -> HumanHealthSummaryFollowUp? {
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: 30, to: today) ?? now
        let datedReports = latestReportsByType(reports).compactMap { report -> (HumanHealthSummaryReportInput, Date)? in
            guard let nextCheckDate = report.nextCheckDate else { return nil }
            return (report, calendar.startOfDay(for: nextCheckDate))
        }
        if let overdue = datedReports
            .filter({ $0.1 < today })
            .max(by: { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.id.uuidString < rhs.0.id.uuidString
            }) {
            let days = max(1, calendar.dateComponents([.day], from: overdue.1, to: today).day ?? 1)
            return HumanHealthSummaryFollowUp(
                reportID: overdue.0.id,
                reportTypeRaw: overdue.0.reportTypeRaw,
                date: overdue.0.nextCheckDate ?? overdue.1,
                timing: .overdue(days: days)
            )
        }
        guard let upcoming = datedReports
            .filter({ $0.1 >= today && $0.1 <= horizon })
            .min(by: { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.id.uuidString < rhs.0.id.uuidString
            })
        else { return nil }
        let days = max(0, calendar.dateComponents([.day], from: today, to: upcoming.1).day ?? 0)
        return HumanHealthSummaryFollowUp(
            reportID: upcoming.0.id,
            reportTypeRaw: upcoming.0.reportTypeRaw,
            date: upcoming.0.nextCheckDate ?? upcoming.1,
            timing: .upcoming(days: days)
        )
    }

    private static func latestReportsByType(
        _ reports: [HumanHealthSummaryReportInput]
    ) -> [HumanHealthSummaryReportInput] {
        var latestByType: [String: HumanHealthSummaryReportInput] = [:]
        for report in reports {
            let trimmedType = report.reportTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let typeKey = trimmedType.isEmpty ? "__other__" : trimmedType
            if let existing = latestByType[typeKey],
               !isNewer(report, than: existing) {
                continue
            }
            latestByType[typeKey] = report
        }
        return latestByType.values.sorted {
            if $0.reportDate != $1.reportDate { return $0.reportDate > $1.reportDate }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString > $1.id.uuidString
        }
    }

    private static func recentObservation(
        observations: [HumanHealthSummaryObservationInput],
        conditions: [HumanHealthSummaryConditionInput],
        now: Date,
        calendar: Calendar
    ) -> HumanHealthSummaryObservation? {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        guard let latest = observations
            .filter({ $0.recordedAt >= start && $0.recordedAt <= now })
            .max(by: { lhs, rhs in
                if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt < rhs.recordedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            })
        else { return nil }

        let conditionName = latest.conditionID
            .flatMap { id in conditions.first(where: { $0.id == id })?.name }
            ?? ""
        return HumanHealthSummaryObservation(
            observationID: latest.id,
            conditionName: conditionName,
            recordedAt: latest.recordedAt,
            severity: max(0, min(10, latest.severity)),
            moodScore: latest.moodScore.map { max(1, min(10, $0)) }
        )
    }

    private static func metricTrends(
        _ metrics: [HumanHealthSummaryMetricInput]
    ) -> [HumanHealthSummaryTrend] {
        let grouped = Dictionary(grouping: metrics.filter(\.value.isFinite), by: \.metricKey)
        return grouped.compactMap { metricKey, values -> HumanHealthSummaryTrend? in
            let sorted = values.sorted { lhs, rhs in isNewer(lhs, than: rhs) }
            guard let current = sorted.first,
                  let previous = sorted.dropFirst().first(where: { $0.unitCode == current.unitCode })
            else { return nil }
            return HumanHealthSummaryTrend(
                metricKey: metricKey,
                unitCode: current.unitCode,
                currentValue: current.value,
                previousValue: previous.value,
                currentDate: current.date,
                status: current.status
            )
        }
        .sorted {
            if $0.currentDate != $1.currentDate { return $0.currentDate > $1.currentDate }
            return $0.metricKey < $1.metricKey
        }
    }

    private static func focusItems(
        pendingDoseCount: Int,
        abnormalMetricCount: Int,
        followUp: HumanHealthSummaryFollowUp?,
        recentObservation: HumanHealthSummaryObservation?,
        activeConditionCount: Int
    ) -> [HumanHealthSummaryFocusKind] {
        var result: [HumanHealthSummaryFocusKind] = []
        if pendingDoseCount > 0 { result.append(.medication) }
        if abnormalMetricCount > 0 { result.append(.metrics) }
        if followUp != nil { result.append(.followUp) }
        if recentObservation != nil { result.append(.observation) }
        if activeConditionCount > 0 { result.append(.conditions) }
        return result
    }

    private static func highlights(
        scheduledDoseCount: Int,
        pendingDoseCount: Int,
        medicationScheduleIsIncomplete: Bool,
        latestMetricCount: Int,
        abnormalMetricCount: Int,
        metricReviewIsIncomplete: Bool,
        recentObservation: HumanHealthSummaryObservation?,
        followUp: HumanHealthSummaryFollowUp?
    ) -> [HumanHealthSummaryHighlight] {
        var result: [HumanHealthSummaryHighlight] = []
        if scheduledDoseCount > 0, !medicationScheduleIsIncomplete {
            result.append(pendingDoseCount > 0
                ? .dosesRemaining(pendingDoseCount)
                : .dosesHandled(scheduledDoseCount))
        }
        if abnormalMetricCount > 0 {
            result.append(.latestMetricsNeedReview(abnormalMetricCount))
        } else if metricReviewIsIncomplete {
            result.append(.metricReviewIncomplete(latestMetricCount))
        } else if latestMetricCount > 0 {
            result.append(.latestMetricsWithoutReviewFlag(latestMetricCount))
        }
        if let recentObservation {
            result.append(.recentObservation(recentObservation))
        }
        if let followUp {
            result.append(.followUp(followUp))
        }
        return result
    }

    private static func isNewer(
        _ lhs: HumanHealthSummaryMetricInput,
        than rhs: HumanHealthSummaryMetricInput
    ) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func isNewer(
        _ lhs: HumanHealthSummaryReportInput,
        than rhs: HumanHealthSummaryReportInput
    ) -> Bool {
        if lhs.reportDate != rhs.reportDate { return lhs.reportDate > rhs.reportDate }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}

nonisolated enum HumanHealthSummaryOwnerIdentity {
    static func matches(_ rawOwnerID: String, humanID: UUID) -> Bool {
        let trimmed = rawOwnerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = UUID(uuidString: trimmed) else { return false }
        return parsed == humanID
    }
}

nonisolated enum HumanHealthSummaryMedicationWindow {
    static func includes(
        isActive: Bool,
        startDate: Date,
        endDate: Date?,
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isActive else { return false }
        let day = calendar.startOfDay(for: date)
        guard calendar.startOfDay(for: startDate) <= day else { return false }
        if let endDate,
           calendar.startOfDay(for: endDate) < day {
            return false
        }
        return true
    }
}

nonisolated enum HumanHealthSummaryDayIdentity {
    static func key(for date: Date, calendar: Calendar = .current) -> Int64 {
        Int64(calendar.startOfDay(for: date).timeIntervalSinceReferenceDate)
    }
}

nonisolated enum HumanHealthSummaryPinPreference {
    static let defaultItems: [HumanHealthSummaryDestination] = [
        .medication,
        .metrics,
        .conditions,
        .reports
    ]

    static let availableItems: [HumanHealthSummaryDestination] = [
        .medication,
        .metrics,
        .conditions,
        .reports,
        .weight,
        .workouts
    ]

    static func storageKey(humanID: UUID) -> String {
        "humanHealthSummary.pinned.v1.\(humanID.uuidString)"
    }

    static func decode(_ rawValue: String?) -> [HumanHealthSummaryDestination] {
        guard let rawValue,
              !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([HumanHealthSummaryDestination].self, from: data)
        else { return defaultItems }
        return normalized(decoded)
    }

    static func encode(_ values: [HumanHealthSummaryDestination]) -> String {
        let values = normalized(values)
        guard let data = try? JSONEncoder().encode(values),
              let encoded = String(data: data, encoding: .utf8)
        else { return "[]" }
        return encoded
    }

    static func normalized(
        _ values: [HumanHealthSummaryDestination]
    ) -> [HumanHealthSummaryDestination] {
        var seen: Set<HumanHealthSummaryDestination> = []
        return values.filter { value in
            availableItems.contains(value) && seen.insert(value).inserted
        }
    }
}
