//
//  HumanHealthConditionAnalysis.swift
//  Ohana
//
//  Descriptive, non-diagnostic summaries for locally recorded Human health
//  observations. Lower severity values represent lighter self-reported impact.
//

import Foundation

nonisolated enum HumanHealthSeverityTrend: String, Equatable, Sendable {
    case insufficientData
    case improving
    case stable
    case worsening
}

nonisolated struct HumanHealthConditionTrendSnapshot: Equatable, Sendable {
    let totalCount: Int
    let sevenDayCount: Int
    let thirtyDayCount: Int
    let latestRecordedAt: Date?
    let latestSeverity: Int?
    let averageSeverity: Double?
    let averageMood: Double?
    let averageSleepHours: Double?
    let severityTrend: HumanHealthSeverityTrend
    let topSymptomTags: [String]
    let medicationResponseCounts: [HumanMedicationResponse: Int]
    let sideEffectNoteCount: Int
    let severityChartPoints: [OhanaMinimalChartPoint]
    let frequencyChartPoints: [OhanaMinimalChartPoint]

    static let empty = HumanHealthConditionTrendSnapshot(
        totalCount: 0,
        sevenDayCount: 0,
        thirtyDayCount: 0,
        latestRecordedAt: nil,
        latestSeverity: nil,
        averageSeverity: nil,
        averageMood: nil,
        averageSleepHours: nil,
        severityTrend: .insufficientData,
        topSymptomTags: [],
        medicationResponseCounts: [:],
        sideEffectNoteCount: 0,
        severityChartPoints: [],
        frequencyChartPoints: []
    )
}

nonisolated struct HumanHealthMedicationTrackingSnapshot: Equatable, Sendable {
    let linkedPlanCount: Int
    let activePlanCount: Int
    let plannedDoseCount: Int
    let takenDoseCount: Int

    var completionRate: Int? {
        guard plannedDoseCount > 0 else { return nil }
        return Int((Double(takenDoseCount) / Double(plannedDoseCount) * 100).rounded())
    }

    static let empty = HumanHealthMedicationTrackingSnapshot(
        linkedPlanCount: 0,
        activePlanCount: 0,
        plannedDoseCount: 0,
        takenDoseCount: 0
    )
}

@MainActor
enum HumanHealthConditionAnalysis {
    static func trendSnapshot(
        observations: [HumanHealthObservation],
        includeMedicationDetails: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HumanHealthConditionTrendSnapshot {
        let eligibleObservations = observations.filter { $0.recordedAt <= now }
        guard !eligibleObservations.isEmpty else { return .empty }

        let sorted = eligibleObservations.sorted {
            if $0.recordedAt == $1.recordedAt {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
            return $0.recordedAt < $1.recordedAt
        }
        let today = calendar.startOfDay(for: now)
        let sevenDayStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let thirtyDayStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let recentThirty = sorted.filter { $0.recordedAt >= thirtyDayStart && $0.recordedAt <= now }
        let recentSeven = sorted.filter { $0.recordedAt >= sevenDayStart && $0.recordedAt <= now }

        let severityValues = recentThirty.map { Double(max(0, min(10, $0.severity))) }
        let moodValues = recentThirty.compactMap(\.moodScore).map(Double.init)
        let sleepValues = recentThirty.compactMap(\.sleepHours).filter { $0.isFinite && $0 >= 0 }

        var tagCounts: [String: (label: String, count: Int)] = [:]
        for tag in recentThirty.flatMap(\.symptomTags) {
            let label = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let key = label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let current = tagCounts[key]
            tagCounts[key] = (current?.label ?? label, (current?.count ?? 0) + 1)
        }
        let topTags = tagCounts.values
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending }
                return lhs.count > rhs.count
            }
            .prefix(3)
            .map(\.label)

        var responseCounts: [HumanMedicationResponse: Int] = [:]
        if includeMedicationDetails {
            for observation in recentThirty where observation.medicationResponse != .unknown {
                responseCounts[observation.medicationResponse, default: 0] += 1
            }
        }

        return HumanHealthConditionTrendSnapshot(
            totalCount: sorted.count,
            sevenDayCount: recentSeven.count,
            thirtyDayCount: recentThirty.count,
            latestRecordedAt: sorted.last?.recordedAt,
            latestSeverity: sorted.last.map { max(0, min(10, $0.severity)) },
            averageSeverity: average(severityValues),
            averageMood: average(moodValues),
            averageSleepHours: average(sleepValues),
            severityTrend: severityTrend(
                observations: recentThirty,
                start: thirtyDayStart,
                end: now,
                calendar: calendar
            ),
            topSymptomTags: topTags,
            medicationResponseCounts: responseCounts,
            sideEffectNoteCount: includeMedicationDetails
                ? recentThirty.count {
                    !$0.sideEffects.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                : 0,
            severityChartPoints: sorted.suffix(14).map {
                OhanaMinimalChartPoint(
                    date: $0.recordedAt,
                    value: Double(max(0, min(10, $0.severity))),
                    id: "human-health-severity-\($0.id.uuidString)"
                )
            },
            frequencyChartPoints: frequencyPoints(
                observations: sorted,
                endingOn: today,
                days: 7,
                calendar: calendar
            )
        )
    }

    static func medicationSnapshot(
        condition: HumanHealthCondition,
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HumanHealthMedicationTrackingSnapshot {
        let linkedIDs = Set(condition.linkedMedicationIDs)
        guard !linkedIDs.isEmpty else { return .empty }

        let linked = medications.filter { linkedIDs.contains($0.id) }
        let today = calendar.startOfDay(for: now)
        let active = linked.filter { medication in
            guard medication.isActive,
                  today >= calendar.startOfDay(for: medication.startDate) else { return false }
            guard let endDate = medication.endDate else { return true }
            return today <= calendar.startOfDay(for: endDate)
        }
        let adherence = HumanMedicationAdherenceAnalysis.snapshot(
            medications: linked,
            logs: logs,
            now: now,
            calendar: calendar
        )

        return HumanHealthMedicationTrackingSnapshot(
            linkedPlanCount: linked.count,
            activePlanCount: active.count,
            plannedDoseCount: adherence.plannedDoseCount,
            takenDoseCount: adherence.takenDoseCount
        )
    }

    private static func severityTrend(
        observations: [HumanHealthObservation],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> HumanHealthSeverityTrend {
        guard observations.count >= 2 else { return .insufficientData }
        let daySpan = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 29)
        let midpoint = calendar.date(byAdding: .day, value: daySpan / 2, to: start) ?? end
        let earlier = observations.filter { $0.recordedAt < midpoint }.map { Double($0.severity) }
        let later = observations.filter { $0.recordedAt >= midpoint }.map { Double($0.severity) }
        guard let earlierAverage = average(earlier), let laterAverage = average(later) else {
            return .insufficientData
        }
        let change = laterAverage - earlierAverage
        if change <= -0.5 { return .improving }
        if change >= 0.5 { return .worsening }
        return .stable
    }

    private static func frequencyPoints(
        observations: [HumanHealthObservation],
        endingOn today: Date,
        days: Int,
        calendar: Calendar
    ) -> [OhanaMinimalChartPoint] {
        (0 ..< days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - (days - 1), to: today) else {
                return nil
            }
            let count = observations.count { calendar.isDate($0.recordedAt, inSameDayAs: day) }
            return OhanaMinimalChartPoint(
                date: day,
                value: Double(count),
                id: "human-health-frequency-\(Int(day.timeIntervalSinceReferenceDate))"
            )
        }
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
