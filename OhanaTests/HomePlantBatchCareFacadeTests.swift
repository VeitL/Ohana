import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HomePlantBatchCareFacadeTests {
    @Test func completePlantBatchCareWritesOneAtomicBatchForAllDueTargets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 9,
            hour: 9
        )))
        let previousCareDate = try #require(calendar.date(byAdding: .day, value: -2, to: now))
        let committedAt = now.addingTimeInterval(3600)
        let first = duePlant(name: "Fern", previousCareDate: previousCareDate)
        let second = duePlant(name: "Pothos", previousCareDate: previousCareDate)
        let restoreDefaults = isolateStandardPlantDefaults(for: [first.id, second.id])
        defer { restoreDefaults() }
        context.insert(first)
        context.insert(second)
        try context.save()

        let executor = makeExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let selections = [first, second].map {
            PlantBatchCareSelection(plantID: $0.id, careType: .watering)
        }

        let result = executor.completePlantBatchCare(
            selections: selections,
            executorId: "human-1",
            now: now,
            calendar: calendar,
            clock: { committedAt }
        )

        let token = try #require(result.undoToken)
        let mutation = try #require(revisionCenter.lastMutation)
        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let expectedPlantIDs = Set([first.id, second.id])
        #expect(result.didPersist)
        #expect(result.didWrite)
        #expect(result.completedCount == 2)
        #expect(result.skipped.isEmpty)
        #expect(token.batchID == result.batchID)
        #expect(token.items.count == 2)
        #expect(token.createdAt == committedAt)
        #expect(token.expiresAt == committedAt.addingTimeInterval(PlantBatchCareCommandService.undoWindowSeconds))
        #expect(token.items.allSatisfy { $0.occurredAt == now })
        #expect(Set(logs.compactMap { $0.plant?.id }) == expectedPlantIDs)
        #expect(logs.allSatisfy { $0.careTransactionId == result.batchID.uuidString })
        #expect(first.lastWateredDate == now)
        #expect(second.lastWateredDate == now)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .plantBatchCare(
            batchID: result.batchID,
            action: "batchCare",
            count: 2
        ))
        #expect(mutation.affectedEntityIDs.isSuperset(of: expectedPlantIDs))

        let undo = executor.undoPlantBatchCare(
            token,
            now: committedAt.addingTimeInterval(1),
            calendar: calendar
        )
        #expect(undo.didPersist)
        #expect(undo.didUndo)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
    }

    @Test func completePlantBatchCareWritesNothingWhenAnyTargetIsNoLongerDue() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 9,
            hour: 10
        )))
        let previousCareDate = try #require(calendar.date(byAdding: .day, value: -2, to: now))
        let due = duePlant(name: "Fern", previousCareDate: previousCareDate)
        let noLongerDue = Plant(name: "Pothos", wateringIntervalDays: 7)
        noLongerDue.createdAt = now
        noLongerDue.lastWateredDate = now
        let restoreDefaults = isolateStandardPlantDefaults(for: [due.id, noLongerDue.id])
        defer { restoreDefaults() }
        context.insert(due)
        context.insert(noLongerDue)
        try context.save()

        let executor = makeExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let result = executor.completePlantBatchCare(
            selections: [
                PlantBatchCareSelection(plantID: due.id, careType: .watering),
                PlantBatchCareSelection(plantID: noLongerDue.id, careType: .watering)
            ],
            executorId: "human-1",
            now: now,
            calendar: calendar
        )

        #expect(result.didPersist)
        #expect(!result.didWrite)
        #expect(result.items.isEmpty)
        #expect(result.undoToken == nil)
        #expect(result.skipped.contains {
            $0.selection.plantID == noLongerDue.id && $0.reason == .notDue
        })
        #expect(due.lastWateredDate == previousCareDate)
        #expect(noLongerDue.lastWateredDate == now)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(revisionCenter.lastMutation?.wroteBusinessFact == false)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeExecutor(
        context: ModelContext,
        revisionCenter: ReadModelRevisionCenter
    ) -> HomeCommandExecutor {
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        return HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: revisions,
            questManager: QuestManager(
                wallet: SwiftDataCoconutWalletManager(),
                revisions: revisions
            ),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager()
        )
    }

    private func duePlant(name: String, previousCareDate: Date) -> Plant {
        let plant = Plant(name: name, wateringIntervalDays: 1)
        plant.createdAt = previousCareDate
        plant.lastWateredDate = previousCareDate
        return plant
    }

    private func isolateStandardPlantDefaults(for plantIDs: [UUID]) -> () -> Void {
        let defaults = UserDefaults.standard
        let plantIDTokens = Set(plantIDs.map(\.uuidString))
        let isScopedKey: (String) -> Bool = { key in
            plantIDTokens.contains { key.contains($0) } &&
                (key.hasPrefix("ohana_plant_care_plan_event_v1_") ||
                    key.hasPrefix("plantReminder."))
        }
        let originalValues = defaults.dictionaryRepresentation().filter { key, _ in
            isScopedKey(key)
        }
        for key in originalValues.keys {
            defaults.removeObject(forKey: key)
        }

        return {
            for key in defaults.dictionaryRepresentation().keys where isScopedKey(key) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in originalValues {
                defaults.set(value, forKey: key)
            }
        }
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
