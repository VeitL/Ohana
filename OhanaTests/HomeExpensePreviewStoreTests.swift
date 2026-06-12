import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HomeExpensePreviewStoreTests {
    @Test func expandedFeedQuickActionUsesLedgerEntriesForManualStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        pet.dailyPortionGrams = 45
        FeedOperatingMode.set(pet.id, mode: .manual)
        let item = QuickActionItem(
            label: "喂食",
            icon: "fork.knife",
            colorHex: "FFDD44",
            petId: pet.id,
            actionType: "feed",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomeFeedQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            date: now,
            amountGrams: 45,
            source: .manualMain
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [entry],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [entry],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(countText == "手动 1餐")
        #expect(isCompleted == true)
    }

    @Test func expandedPlayQuickActionUsesCareLedgerEntriesForStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 10)))
        let pet = Pet(name: "Milo", species: "猫")
        let item = QuickActionItem(
            label: "逗玩",
            icon: "tennisball",
            colorHex: "77CCFF",
            petId: pet.id,
            actionType: "play",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomeCareQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            actionType: CareType.play.rawValue,
            date: now,
            amountValue: 0
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [entry],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [entry],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(countText == "今日陪玩 1次")
        #expect(isCompleted == true)
    }

    @Test func expandedWalkQuickActionUsesLedgerDistanceForStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 11)))
        let pet = Pet(name: "Milo", species: "狗")
        let item = QuickActionItem(
            label: "出行",
            icon: "figure.walk",
            colorHex: "22CC88",
            petId: pet.id,
            actionType: "walk",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomeWalkQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            startDate: now,
            distanceMeters: 1200
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [entry],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [entry],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(countText == "今日 1次 · 1.2km")
        #expect(isCompleted == true)
    }

    @Test func expandedPottyQuickActionUsesLedgerEntriesForRecentAbnormalStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 12)))
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 18)))
        let pet = Pet(name: "Milo", species: "猫")
        let item = QuickActionItem(
            label: "便便",
            icon: "seal.fill",
            colorHex: "AA7744",
            petId: pet.id,
            actionType: "potty",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomePottyQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            date: yesterday,
            pottyType: .softPoop
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [entry],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [entry],
            now: now,
            calendar: calendar
        )

        #expect(countText == "最近异常")
        #expect(isCompleted == false)
    }

    @Test func expandedPetExpenseQuickActionUsesLedgerEntriesForMonthlyTotal() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 13)))
        let currentMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9)))
        let currentMonthLater = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 18)))
        let previousMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 18)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let item = QuickActionItem(
            label: "支出",
            icon: "creditcard",
            colorHex: "66CCAA",
            petId: pet.id,
            actionType: "expense",
            entityId: pet.id,
            entityKind: .pet
        )
        let entries = [
            HomePetExpenseQuickActionEntry(id: UUID(), petId: pet.id, date: currentMonth, amount: 12),
            HomePetExpenseQuickActionEntry(id: UUID(), petId: pet.id, date: currentMonthLater, amount: 30),
            HomePetExpenseQuickActionEntry(id: UUID(), petId: pet.id, date: previousMonth, amount: 80),
            HomePetExpenseQuickActionEntry(id: UUID(), petId: otherPet.id, date: currentMonth, amount: 99)
        ]

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petExpenseLedgerEntries: entries,
            now: now,
            calendar: calendar
        )

        #expect(countText == "本月 \(AppCurrency.format(42, fractionDigits: 0))")
    }

    @Test func expandedPetWeightQuickActionUsesLedgerEntriesForLatestAndCompletion() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 14)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let previous = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let item = QuickActionItem(
            label: "体重",
            icon: "scalemass.fill",
            colorHex: "66AADD",
            petId: pet.id,
            actionType: "weight",
            entityId: pet.id,
            entityKind: .pet
        )
        let entries = [
            HomePetWeightQuickActionEntry(id: UUID(), petId: pet.id, date: previous, weightKg: 4.2),
            HomePetWeightQuickActionEntry(id: UUID(), petId: pet.id, date: today, weightKg: 4.8),
            HomePetWeightQuickActionEntry(id: UUID(), petId: otherPet.id, date: today, weightKg: 8.1)
        ]

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petWeightLedgerEntries: entries,
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petWeightLedgerEntries: entries,
            now: now,
            calendar: calendar
        )

        #expect(countText == "4.8kg")
        #expect(isCompleted == true)
    }

    @Test func expandedGroomQuickActionUsesHygieneLedgerEntriesForCompletion() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 15)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let item = QuickActionItem(
            label: "护理",
            icon: "scissors",
            colorHex: "FF9966",
            petId: pet.id,
            actionType: "groom",
            entityId: pet.id,
            entityKind: .pet
        )
        let entries = [
            HomeHygieneQuickActionEntry(id: UUID(), petId: pet.id, hygieneType: .brushing, date: yesterday),
            HomeHygieneQuickActionEntry(id: UUID(), petId: pet.id, hygieneType: .bath, date: today),
            HomeHygieneQuickActionEntry(id: UUID(), petId: otherPet.id, hygieneType: .bath, date: today)
        ]

        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            hygieneLedgerEntries: entries,
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(isCompleted == true)
    }

    @Test func fetchExpenseEntriesFiltersToCurrentMonthAndActor() throws {
        let container = try makeContainer()
        let human = Human(name: "Owner")
        let otherHuman = Human(name: "Other")
        container.mainContext.insert(human)
        container.mainContext.insert(otherHuman)

        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let current = try expenseLedger(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))),
            amount: 12,
            actorId: human.id.uuidString
        )
        let older = try expenseLedger(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))),
            amount: 20,
            actorId: human.id.uuidString
        )
        let otherActor = try expenseLedger(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))),
            amount: 30,
            actorId: otherHuman.id.uuidString
        )
        let unrelatedKind = try CareLedgerEvent(
            occurredAt: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 6))),
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        )
        container.mainContext.insert(current)
        container.mainContext.insert(older)
        container.mainContext.insert(otherActor)
        container.mainContext.insert(unrelatedKind)
        try container.mainContext.save()

        let entries = HomeExpensePreviewStore.fetchExpenseEntries(
            context: container.mainContext,
            humanID: human.id,
            now: now
        )

        #expect(entries == [
            HomeExpensePreviewEntry(
                id: current.id,
                date: current.occurredAt,
                actorId: human.id.uuidString,
                amount: current.amountValue
            )
        ])
    }

    private func expenseLedger(date: Date, amount: Double, actorId: String) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: date,
            actorKind: .human,
            actorId: actorId,
            subjectKind: .human,
            subjectId: actorId,
            eventKind: .expense,
            actionType: ExpenseCategory.other.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            source: .service,
            legacyModelName: "PetExpenseLog"
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
