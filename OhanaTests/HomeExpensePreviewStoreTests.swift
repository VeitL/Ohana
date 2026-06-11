import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HomeExpensePreviewStoreTests {
    @Test func fetchExpenseLogsFiltersToCurrentMonthAndExecutor() throws {
        let container = try makeContainer()
        let human = Human(name: "Owner")
        let otherHuman = Human(name: "Other")
        let pet = Pet(name: "Milo", species: "猫")
        container.mainContext.insert(human)
        container.mainContext.insert(otherHuman)
        container.mainContext.insert(pet)

        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let current = try PetExpenseLog(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))),
            amount: 12,
            pet: pet,
            executorId: human.id.uuidString
        )
        let older = try PetExpenseLog(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))),
            amount: 20,
            pet: pet,
            executorId: human.id.uuidString
        )
        let otherExecutor = try PetExpenseLog(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))),
            amount: 30,
            pet: pet,
            executorId: otherHuman.id.uuidString
        )
        container.mainContext.insert(current)
        container.mainContext.insert(older)
        container.mainContext.insert(otherExecutor)
        try container.mainContext.save()

        let logs = HomeExpensePreviewStore.fetchExpenseLogs(
            context: container.mainContext,
            humanID: human.id,
            now: now
        )

        #expect(logs.map(\.id) == [current.id])
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
