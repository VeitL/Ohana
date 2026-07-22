import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HouseholdInsightSnapshotTests {
    @Test func longTermReviewBuildsBoundedMonthlySnapshotFromExistingFacts() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let now = date(2026, 7, 20, calendar: calendar)
        let recent = date(2026, 7, 10, calendar: calendar)
        let previousMonth = date(2026, 6, 8, calendar: calendar)
        let olderThanYear = date(2025, 5, 4, calendar: calendar)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Mochi", species: "cat")

        context.insert(human)
        context.insert(pet)
        context.insert(CareLedgerEvent(
            occurredAt: recent,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2,
            amountUnit: "kg"
        ))
        context.insert(CareLedgerEvent(
            occurredAt: previousMonth,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: "feed"
        ))
        context.insert(CareLedgerEvent(
            occurredAt: olderThanYear,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: "expense",
            amountValue: 48
        ))
        context.insert(PetPhotoLog(
            imageData: Data(),
            date: olderThanYear,
            note: "First day",
            pet: pet
        ))
        try context.save()

        let actor = FamilyLongTermReviewDataActor(modelContainer: container)
        let all = try await actor.load(range: .all, now: now, calendar: calendar)
        let year = try await actor.load(range: .year, now: now, calendar: calendar)

        #expect(all.hasLoaded)
        #expect(all.operationCount == 3)
        #expect(all.weightRecordCount == 1)
        #expect(all.expenseTotal == 48)
        #expect(all.memoryCount == 1)
        #expect(all.months.count == 3)
        #expect(all.subjects.first?.name == "Mochi")
        #expect(!all.isTruncated)

        #expect(year.operationCount == 2)
        #expect(year.expenseTotal == 0)
        #expect(year.memoryCount == 0)
        #expect(year.months.count == 2)
    }

    @Test func reminderSafetySnapshotExposesFailuresAndOverdueItemsWithoutTrendFetches() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let overdue = Reminder(scheduledAt: now.addingTimeInterval(-3600))
        let upcoming = Reminder(scheduledAt: now.addingTimeInterval(3600))
        let failed = Reminder(scheduledAt: now.addingTimeInterval(-7200))
        failed.statusEnum = .failed
        context.insert(overdue)
        context.insert(upcoming)
        context.insert(failed)
        try context.save()

        let snapshot = try await ReminderObservabilityDataActor(modelContainer: container)
            .loadSafety(now: now)

        #expect(snapshot.hasLoaded)
        #expect(snapshot.overdueCount == 1)
        #expect(snapshot.failedCount == 1)
    }

    @Test func careAnalysisActorScopesEventsByRangeAndSelectedSubject() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let now = date(2026, 7, 20, calendar: calendar)
        let petA = Pet(name: "Mochi", species: "cat")
        let petB = Pet(name: "Nori", species: "cat")
        context.insert(petA)
        context.insert(petB)
        context.insert(CareLedgerEvent(
            occurredAt: date(2026, 7, 19, calendar: calendar),
            subjectKind: .pet,
            subjectId: petA.id.uuidString,
            eventKind: .care,
            actionType: "feed"
        ))
        context.insert(CareLedgerEvent(
            occurredAt: date(2026, 7, 18, calendar: calendar),
            subjectKind: .pet,
            subjectId: petB.id.uuidString,
            eventKind: .care,
            actionType: "feed"
        ))
        context.insert(CareLedgerEvent(
            occurredAt: date(2026, 5, 1, calendar: calendar),
            subjectKind: .pet,
            subjectId: petA.id.uuidString,
            eventKind: .health,
            actionType: "checkup"
        ))
        try context.save()

        let actor = CareLedgerAnalysisDataActor(modelContainer: container)
        let scoped = try await actor.load(
            range: .week,
            subjectKey: "pet:\(petA.id.uuidString)",
            now: now,
            calendar: calendar
        )
        let all = try await actor.load(
            range: .all,
            subjectKey: nil,
            now: now,
            calendar: calendar
        )

        #expect(scoped.events.count == 1)
        #expect(scoped.events.first?.subjectId == petA.id.uuidString)
        #expect(scoped.subjects.map(\.name) == ["Mochi", "Nori"])
        #expect(all.events.count == 3)
    }

    @Test func weightAndExpenseActorsOnlyLoadTheRequestedRangeAndObject() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let now = date(2026, 7, 20, calendar: calendar)
        let recent = date(2026, 7, 19, calendar: calendar)
        let old = date(2026, 6, 1, calendar: calendar)
        let human = Human(name: "Ava")
        let petA = Pet(name: "Mochi", species: "cat")
        let petB = Pet(name: "Nori", species: "cat")
        context.insert(human)
        context.insert(petA)
        context.insert(petB)
        context.insert(CareLedgerEvent(
            occurredAt: recent,
            subjectKind: .pet,
            subjectId: petA.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2
        ))
        context.insert(CareLedgerEvent(
            occurredAt: recent,
            subjectKind: .pet,
            subjectId: petB.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 5.1
        ))
        context.insert(CareLedgerEvent(
            occurredAt: old,
            subjectKind: .pet,
            subjectId: petA.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.0
        ))
        context.insert(HumanWeightLog(date: recent, weight: 63, human: human))
        context.insert(PetExpenseLog(date: recent, amount: 20, category: .food, pet: petA, executorId: human.id.uuidString))
        context.insert(PetExpenseLog(date: recent, amount: 30, category: .toys, pet: petB, executorId: human.id.uuidString))
        context.insert(PetExpenseLog(date: old, amount: 80, category: .medical, pet: petA, executorId: human.id.uuidString))
        try context.save()

        let petDescriptors = [
            WeightInsightSubjectDescriptor(id: petA.id, name: petA.name, isHuman: false),
            WeightInsightSubjectDescriptor(id: petB.id, name: petB.name, isHuman: false)
        ]
        let humanDescriptors = [
            WeightInsightSubjectDescriptor(id: human.id, name: human.name, isHuman: true)
        ]
        let weight = try await WeightInsightDataActor(modelContainer: container).load(
            dayCount: 7,
            subjectKey: "pet:\(petA.id.uuidString)",
            pets: petDescriptors,
            humans: humanDescriptors,
            now: now,
            calendar: calendar
        )
        let expense = try await ExpenseInsightDataActor(modelContainer: container).load(
            range: .week,
            subjectKey: "pet:\(petA.id.uuidString)",
            activePetIDs: [petA.id, petB.id],
            activeHumanIDs: [human.id.uuidString],
            now: now,
            calendar: calendar
        )

        #expect(weight.points.count == 1)
        #expect(weight.points.first?.seriesID == "pet:\(petA.id.uuidString)")
        #expect(expense.logs.count == 1)
        #expect(expense.logs.first?.expensePetID == petA.id)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(ArkSchemaV94.models),
            migrationPlan: ArkMigrationPlan.self,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        )) ?? .distantPast
    }
}
