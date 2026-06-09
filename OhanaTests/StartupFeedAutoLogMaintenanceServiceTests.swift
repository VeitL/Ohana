import Foundation
@testable import Ohana
import SwiftData
import Testing

@MainActor
struct StartupFeedAutoLogMaintenanceServiceTests {
    @Test func materializesOnlyPetsWithAutoFeederEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(year: 2026, month: 5, day: 8, hour: 21)

        let targetPet = Pet(name: "Momo", species: "猫")
        let unrelatedPet = Pet(name: "Nori", species: "狗")
        let auto = Event(
            title: "自动喂食器",
            startDate: date(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: targetPet.id.uuidString
        )
        auto.recurrenceDays = 1
        auto.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        auto.feedAmountGrams = 35

        let manual = Event(
            title: "手动计划",
            startDate: date(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: unrelatedPet.id.uuidString
        )
        manual.recurrenceDays = 1
        manual.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        manual.feedAmountGrams = 50

        context.insert(targetPet)
        context.insert(unrelatedPet)
        context.insert(auto)
        context.insert(manual)
        try context.save()

        let inserted = StartupFeedAutoLogMaintenanceService.materializeDueAutoFeederLogs(
            context: context,
            now: now,
            calendar: calendar
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(inserted == 2)
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.pet?.id == targetPet.id })
        #expect(logs.allSatisfy { $0.amountGrams == 35 })
    }

    @Test func ignoresAutoFeederEventsWithoutMatchingPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let missingPetEvent = Event(
            title: "自动喂食器",
            startDate: date(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: UUID().uuidString
        )
        missingPetEvent.recurrenceDays = 1
        missingPetEvent.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        missingPetEvent.feedAmountGrams = 35
        context.insert(missingPetEvent)
        try context.save()

        let inserted = StartupFeedAutoLogMaintenanceService.materializeDueAutoFeederLogs(
            context: context,
            now: date(year: 2026, month: 5, day: 8, hour: 21)
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(inserted == 0)
        #expect(logs.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV58.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
