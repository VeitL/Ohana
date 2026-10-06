import Foundation
import SwiftData

nonisolated struct HumanHealthPatternMedication: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let dosage: String
}

nonisolated struct HumanHealthPatternMedicationChoices: Sendable {
    let medications: [HumanHealthPatternMedication]
    let isComplete: Bool
}

@MainActor
enum HumanHealthMedicationPatternReadModel {
    static let medicationLimit = 128
    static let observationLimit = 1024
    static let doseLimit = 2048
    enum ReadError: Error { case unavailable }

    static func medications(humanID: UUID, conditionID: UUID, viewerID: UUID?, context: ModelContext) throws -> HumanHealthPatternMedicationChoices {
        try validateAccess(humanID: humanID, conditionID: conditionID, viewerID: viewerID, context: context)
        let owner = humanID.uuidString
        let lower = owner.lowercased()
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate { $0.humanId.contains(owner) || $0.humanId.contains(lower) },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = medicationLimit + 1
        let candidates = try context.fetch(descriptor)
        let values = candidates.prefix(medicationLimit).filter { matches($0.humanId, humanID) }.map {
            HumanHealthPatternMedication(id: $0.id, name: $0.name, dosage: $0.dosage)
        }
        return HumanHealthPatternMedicationChoices(medications: values, isComplete: candidates.count <= medicationLimit)
    }

    static func load(humanID: UUID, conditionID: UUID, medicationID: UUID, viewerID: UUID?, delay: HumanHealthObservationDelay, context: ModelContext, now: Date = Date(), calendar: Calendar = .current) throws -> HumanHealthMedicationPatternSnapshot {
        try validateAccess(humanID: humanID, conditionID: conditionID, viewerID: viewerID, context: context)
        var medicationDescriptor = FetchDescriptor<HumanMedication>(predicate: #Predicate { $0.id == medicationID })
        medicationDescriptor.fetchLimit = 1
        guard let medication = try context.fetch(medicationDescriptor).first,
              matches(medication.humanId, humanID) else { throw ReadError.unavailable }
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: 1 - HumanHealthMedicationPattern.observationDays, to: today) ?? today
        let doseStart = calendar.date(byAdding: .day, value: -delay.rawValue, to: start) ?? start
        let doseEndDay = calendar.date(byAdding: .day, value: 1 - delay.rawValue, to: today) ?? now
        let observations = try observations(humanID: humanID, conditionID: conditionID, start: start, end: now, context: context)
        let doses = try doses(humanID: humanID, medicationID: medicationID, start: doseStart, end: min(doseEndDay, now), context: context, calendar: calendar)
        return HumanHealthMedicationPattern.build(
            observations: observations.values, doses: doses.values, delay: delay,
            isComplete: observations.complete && doses.complete, now: now, calendar: calendar
        )
    }

    private static func validateAccess(humanID: UUID, conditionID: UUID, viewerID: UUID?, context: ModelContext) throws {
        var humans = FetchDescriptor<Human>(predicate: #Predicate { $0.id == humanID })
        humans.fetchLimit = 1
        var conditions = FetchDescriptor<HumanHealthCondition>(predicate: #Predicate { $0.id == conditionID })
        conditions.fetchLimit = 1
        guard let human = try context.fetch(humans).first,
              !human.isPrivate(.weight, viewedBy: viewerID), !human.isPrivate(.medication, viewedBy: viewerID),
              let condition = try context.fetch(conditions).first,
              matches(condition.humanId, humanID) else { throw ReadError.unavailable }
    }

    private static func observations(humanID: UUID, conditionID: UUID, start: Date, end: Date, context: ModelContext) throws -> (values: [HumanHealthPatternObservation], complete: Bool) {
        let owner = humanID.uuidString, lowerOwner = owner.lowercased()
        let condition = conditionID.uuidString, lowerCondition = condition.lowercased()
        var descriptor = FetchDescriptor<HumanHealthObservation>(
            predicate: #Predicate {
                ($0.humanId.contains(owner) || $0.humanId.contains(lowerOwner)) &&
                    ($0.conditionId.contains(condition) || $0.conditionId.contains(lowerCondition)) &&
                    $0.recordedAt >= start && $0.recordedAt <= end
            },
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = observationLimit + 1
        let candidates = try context.fetch(descriptor)
        let values = candidates.prefix(observationLimit).filter { matches($0.humanId, humanID) && matches($0.conditionId, conditionID) }.map {
            HumanHealthPatternObservation(id: $0.id, date: $0.recordedAt, severity: $0.severity)
        }
        return (values, candidates.count <= observationLimit)
    }

    private static func doses(humanID: UUID, medicationID: UUID, start: Date, end: Date, context: ModelContext, calendar: Calendar) throws -> (values: [HumanHealthPatternDose], complete: Bool) {
        let owner = humanID.uuidString, lowerOwner = owner.lowercased()
        let medication = medicationID.uuidString, lowerMedication = medication.lowercased()
        var descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate {
                ($0.humanId.contains(owner) || $0.humanId.contains(lowerOwner)) &&
                    ($0.medicationId.contains(medication) || $0.medicationId.contains(lowerMedication)) &&
                    $0.scheduledTime >= start && $0.scheduledTime <= end
            },
            sortBy: [SortDescriptor(\.scheduledTime, order: .reverse), SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = doseLimit + 1
        let candidates = try context.fetch(descriptor)
        let canonical = candidates.prefix(doseLimit).filter { matches($0.humanId, humanID) && matches($0.medicationId, medicationID) }
        let byMinute = Dictionary(grouping: canonical) { calendar.dateInterval(of: .minute, for: $0.scheduledTime)?.start ?? $0.scheduledTime }
        let values = byMinute.values.compactMap { entries -> HumanHealthPatternDose? in
            guard let winner = entries.max(by: HumanMedicationLogStore.actionPrecedes) else { return nil }
            return HumanHealthPatternDose(date: winner.scheduledTime, statusRaw: winner.statusRaw)
        }
        return (values, candidates.count <= doseLimit)
    }

    private static func matches(_ raw: String, _ id: UUID) -> Bool {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)) == id
    }
}
