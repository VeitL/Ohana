import Foundation
import SwiftData
import Testing
@testable import Ohana

@Suite("Delayed medication and symptom records")
struct HumanHealthMedicationPatternTests {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return result
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    private func observation(_ offset: Int, severity: Int) -> HumanHealthPatternObservation {
        .init(id: UUID(), date: day(offset), severity: severity)
    }

    @Test func sixtyDayAlignmentUsesCalendarDaysAcrossDaylightSaving() throws {
        let snapshot = HumanHealthMedicationPattern.build(
            observations: [observation(0, severity: 8)],
            doses: [.init(date: day(-60), statusRaw: "taken")],
            delay: .twoMonths, isComplete: true, now: now, calendar: calendar
        )
        let point = try #require(snapshot.days.first)
        #expect(point.medicationState == .taken)
        #expect(point.medicationDate == calendar.startOfDay(for: day(-60)))
        #expect(point.date == calendar.startOfDay(for: now))
        #expect(snapshot.comparison == nil)
        #expect(now.timeIntervalSince(day(-60)) != 60 * 86400)
    }

    @Test func missingPendingAndMixedAreNotSkippedOrZeroSeverity() {
        let result = HumanHealthMedicationPattern.build(
            observations: [observation(0, severity: 0), observation(-1, severity: 7), observation(-3, severity: 9)],
            doses: [.init(date: day(-1), statusRaw: "pending"), .init(date: day(-3), statusRaw: "taken"), .init(date: day(-3), statusRaw: "skipped")],
            delay: .sameDay, isComplete: true, now: now, calendar: calendar
        )
        #expect(result.days.count == 3)
        #expect(result.days.map(\.medicationState) == [.mixed, .unknown, .unknown])
        #expect(result.days.last?.severity == 0)
        #expect(result.pairedDayCount == 0)
        #expect(result.comparison == nil)
    }

    @Test func dailyMeansDoNotOverweightFrequentlyRecordedDaysAndIncompleteLoadsHideComparison() throws {
        var observations: [HumanHealthPatternObservation] = []
        var doses: [HumanHealthPatternDose] = []
        for offset in -9 ... 0 {
            observations.append(observation(offset, severity: offset < -4 ? 2 : 8))
            doses.append(.init(date: day(offset - 7), statusRaw: offset < -4 ? "taken" : "skipped"))
        }
        observations += (0 ..< 9).map { _ in observation(-9, severity: 2) }
        let result = HumanHealthMedicationPattern.build(observations: observations, doses: doses, delay: .week, isComplete: true, now: now, calendar: calendar)
        let comparison = try #require(result.comparison)
        #expect(comparison.takenDays == 5)
        #expect(comparison.skippedDays == 5)
        #expect(comparison.takenMean == 2)
        #expect(comparison.skippedMean == 8)
        let incomplete = HumanHealthMedicationPattern.build(observations: observations, doses: doses, delay: .week, isComplete: false, now: now, calendar: calendar)
        #expect(incomplete.comparison == nil)
        #expect(!incomplete.isComplete)
    }

    @Test func changingDelayDoesNotSearchForOrInventAnAssociation() {
        let observations = [observation(0, severity: 6)]
        let doses = [HumanHealthPatternDose(date: day(-60), statusRaw: "taken")]
        let sameDay = HumanHealthMedicationPattern.build(observations: observations, doses: doses, delay: .sameDay, isComplete: true, now: now, calendar: calendar)
        #expect(sameDay.days.first?.medicationState == .unknown)
        #expect(sameDay.comparison == nil)
        let empty = HumanHealthMedicationPattern.build(observations: [], doses: doses, delay: .twoMonths, isComplete: true, now: now, calendar: calendar)
        #expect(empty.days.isEmpty)
    }

    @Test func futureAndOutOfWindowObservationsAreExcluded() {
        let snapshot = HumanHealthMedicationPattern.build(
            observations: [observation(1, severity: 10), observation(-100, severity: 1), observation(0, severity: 4)],
            doses: [], delay: .sameDay, isComplete: true, now: now, calendar: calendar
        )
        #expect(snapshot.days.count == 1)
        #expect(snapshot.days.first?.severity == 4)
    }

    @MainActor
    @Test func boundedReadSeparatesMembersAndConditionsAndUsesLatestDoseCorrection() throws {
        let container = try ModelContainer(for: Schema(ArkSchemaV99.models), configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = container.mainContext
        let first = Human(name: "First"), second = Human(name: "Second")
        context.insert(first)
        context.insert(second)
        let condition = HumanHealthCondition(humanId: first.id.uuidString, name: "Hair", category: .hairAndScalp)
        let otherCondition = HumanHealthCondition(humanId: second.id.uuidString, name: "Allergy", category: .allergy)
        context.insert(condition)
        context.insert(otherCondition)
        let medication = HumanMedication(humanId: " \(first.id.uuidString.lowercased()) ", name: "First medicine")
        let otherMedication = HumanMedication(humanId: second.id.uuidString, name: "Other medicine")
        context.insert(medication)
        context.insert(otherMedication)
        context.insert(HumanHealthObservation(humanId: first.id.uuidString, conditionId: condition.id.uuidString, recordedAt: now, severity: 6))
        context.insert(HumanHealthObservation(humanId: second.id.uuidString, conditionId: condition.id.uuidString, recordedAt: now, severity: 10))
        context.insert(HumanHealthObservation(humanId: first.id.uuidString, conditionId: otherCondition.id.uuidString, recordedAt: now, severity: 10))
        let older = HumanMedicationLog(humanId: first.id.uuidString, medicationId: medication.id.uuidString, scheduledTime: day(-60), status: .taken, recordedTime: day(-60))
        let correction = HumanMedicationLog(humanId: first.id.uuidString, medicationId: medication.id.uuidString, scheduledTime: day(-60), status: .skipped, recordedTime: day(-59))
        context.insert(older)
        context.insert(correction)
        try context.save()
        let choices = try HumanHealthMedicationPatternReadModel.medications(humanID: first.id, conditionID: condition.id, viewerID: first.id, context: context)
        #expect(choices.medications.map(\.id) == [medication.id])
        let snapshot = try HumanHealthMedicationPatternReadModel.load(humanID: first.id, conditionID: condition.id, medicationID: medication.id, viewerID: first.id, delay: .twoMonths, context: context, now: now, calendar: calendar)
        #expect(snapshot.days.count == 1)
        #expect(snapshot.days.first?.severity == 6)
        #expect(snapshot.days.first?.medicationState == .skipped)
        #expect(throws: HumanHealthMedicationPatternReadModel.ReadError.self) {
            try HumanHealthMedicationPatternReadModel.load(humanID: first.id, conditionID: condition.id, medicationID: otherMedication.id, viewerID: first.id, delay: .twoMonths, context: context, now: now, calendar: calendar)
        }
        #expect(throws: HumanHealthMedicationPatternReadModel.ReadError.self) {
            try HumanHealthMedicationPatternReadModel.medications(humanID: first.id, conditionID: otherCondition.id, viewerID: first.id, context: context)
        }
    }
}
