import Foundation

nonisolated enum HumanHealthObservationDelay: Int, CaseIterable, Identifiable, Sendable {
    case sameDay = 0, nextDay = 1, week = 7, twoWeeks = 14, month = 30, twoMonths = 60, threeMonths = 90
    var id: Int { rawValue }
}

nonisolated enum HumanHealthMedicationDayState: String, CaseIterable, Sendable {
    case taken, skipped, mixed, unknown
}

nonisolated struct HumanHealthPatternObservation: Equatable, Sendable {
    let id: UUID
    let date: Date
    let severity: Int
}

nonisolated struct HumanHealthPatternDose: Equatable, Sendable {
    let date: Date
    let statusRaw: String
}

nonisolated struct HumanHealthPatternDay: Equatable, Identifiable, Sendable {
    let date: Date
    let medicationDate: Date
    let severity: Double
    let observationCount: Int
    let medicationState: HumanHealthMedicationDayState
    var id: Date { date }
}

nonisolated struct HumanHealthPatternComparison: Equatable, Sendable {
    let takenDays: Int
    let skippedDays: Int
    let takenMean: Double
    let skippedMean: Double
}

nonisolated struct HumanHealthMedicationPatternSnapshot: Equatable, Sendable {
    let days: [HumanHealthPatternDay]
    let start: Date
    let end: Date
    let delay: HumanHealthObservationDelay
    let isComplete: Bool
    let comparison: HumanHealthPatternComparison?

    var pairedDayCount: Int {
        days.count { $0.medicationState == .taken || $0.medicationState == .skipped }
    }
}

/// Descriptive day-level alignment, never a medication-effect or causal estimator.
nonisolated enum HumanHealthMedicationPattern {
    static let observationDays = 90
    static let minimumComparisonDays = 5

    static func build(
        observations: [HumanHealthPatternObservation],
        doses: [HumanHealthPatternDose],
        delay: HumanHealthObservationDelay,
        isComplete: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HumanHealthMedicationPatternSnapshot {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: 1 - observationDays, to: end) ?? end
        let valid = observations.filter { $0.date >= start && $0.date <= now && (0 ... 10).contains($0.severity) }
        let observationsByDay = Dictionary(grouping: valid, by: { calendar.startOfDay(for: $0.date) })
        let dosesByDay = Dictionary(grouping: doses.filter { $0.date <= now }, by: { calendar.startOfDay(for: $0.date) })
        let days = observationsByDay.compactMap { day, entries -> HumanHealthPatternDay? in
            guard let medicationDay = calendar.date(byAdding: .day, value: -delay.rawValue, to: day) else { return nil }
            // Each recorded day carries equal weight, even when one day has many observations.
            let mean = Double(entries.reduce(0) { $0 + $1.severity }) / Double(entries.count)
            let status = dayState(dosesByDay[medicationDay] ?? [])
            return HumanHealthPatternDay(date: day, medicationDate: medicationDay, severity: mean, observationCount: entries.count, medicationState: status)
        }.sorted { $0.date < $1.date }
        return HumanHealthMedicationPatternSnapshot(
            days: days, start: start, end: end, delay: delay, isComplete: isComplete,
            comparison: isComplete ? comparison(days: days) : nil
        )
    }

    private static func dayState(_ doses: [HumanHealthPatternDose]) -> HumanHealthMedicationDayState {
        let states = Set(doses.map(\.statusRaw))
        if states == ["taken"] { return .taken }
        if states == ["skipped"] { return .skipped }
        if states == ["taken", "skipped"] { return .mixed }
        return .unknown
    }

    private static func comparison(days: [HumanHealthPatternDay]) -> HumanHealthPatternComparison? {
        let taken = days.filter { $0.medicationState == .taken }
        let skipped = days.filter { $0.medicationState == .skipped }
        guard taken.count >= minimumComparisonDays, skipped.count >= minimumComparisonDays else { return nil }
        return HumanHealthPatternComparison(
            takenDays: taken.count, skippedDays: skipped.count,
            takenMean: taken.reduce(0) { $0 + $1.severity } / Double(taken.count),
            skippedMean: skipped.reduce(0) { $0 + $1.severity } / Double(skipped.count)
        )
    }
}
