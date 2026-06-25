import Foundation
import Testing
@testable import Ohana

@MainActor
struct QuickFeedStockSnapshotStoreTests {
    @Test func stockSnapshotSortsAndPartitionsRecords() {
        let pet = Pet(name: "Momo", species: "猫")
        let now = fixedDate()
        let calendar = Calendar(identifier: .gregorian)
        let activeDry = PetFoodRecord(
            brand: "Active dry",
            totalGrams: 1200,
            foodKind: .dry,
            startDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            pet: pet
        )
        let historyDry = PetFoodRecord(
            brand: "History dry",
            totalGrams: 900,
            foodKind: .dry,
            startDate: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
            pet: pet
        )
        let pendingDry = PetFoodRecord(
            brand: "Pending dry",
            totalGrams: 800,
            foodKind: .dry,
            startDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
            pet: pet
        )
        let activeWet = PetFoodRecord(
            brand: "Active wet",
            totalGrams: 300,
            foodKind: .wet,
            startDate: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            pet: pet
        )

        let snapshot = QuickFeedStockSnapshot.build(
            pet: pet,
            allEvents: [],
            careLogs: [],
            foodRecords: [historyDry, activeWet, pendingDry, activeDry],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.records.map(\.id) == [pendingDry.id, activeDry.id, activeWet.id, historyDry.id])
        #expect(snapshot.activeRecord(for: .dry)?.id == activeDry.id)
        #expect(snapshot.activeRecord(for: .wet)?.id == activeWet.id)
        #expect(snapshot.pendingRecords(for: .dry).map(\.id) == [pendingDry.id])
        #expect(snapshot.openedHistoryRecords(for: .dry).map(\.id) == [historyDry.id])
        #expect(snapshot.activeCount == 2)
        #expect(snapshot.pendingCount == 1)
    }

    @Test func stockSnapshotUsesCachedTotalsForLegacyDryFallback() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.restockWeight = 1.5
        let record = PetFoodRecord(
            brand: "Legacy",
            totalGrams: 0,
            foodKind: .dry,
            startDate: fixedDate(),
            pet: pet
        )

        let snapshot = QuickFeedStockSnapshot.build(
            pet: pet,
            allEvents: [],
            careLogs: [],
            foodRecords: [record],
            now: fixedDate()
        )

        #expect(snapshot.totalGrams(for: record) == 1500)
    }

    @Test func stockSnapshotUsesFeedingLedgerEntriesForConsumptionWhenProvided() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 60
        let now = fixedDate()
        let record = stockRecord(pet: pet, totalGrams: 1000, foodKind: .dry, now: now)
        let legacyLog = PetCareLog(
            date: now.addingTimeInterval(-600),
            type: .feeding,
            amountGrams: 300,
            foodKind: .dry,
            pet: pet
        )
        let ledgerEntry = feedEntry(
            pet: pet,
            date: now.addingTimeInterval(-300),
            amount: 120,
            source: .manualMain,
            foodKind: .dry
        )

        let snapshot = QuickFeedStockSnapshot.build(
            pet: pet,
            allEvents: [],
            careLogs: [legacyLog],
            feedingLedgerEntries: [ledgerEntry],
            foodRecords: [record],
            now: now
        )

        #expect(snapshot.dryStock.consumedGrams == 120)
        #expect(snapshot.dryStock.remainingGrams == 880)
    }

    @Test func stockSnapshotTreatsSuppliedEmptyFeedingLedgerEntriesAsAuthoritative() {
        let pet = Pet(name: "Momo", species: "猫")
        let now = fixedDate()
        let record = stockRecord(pet: pet, totalGrams: 1000, foodKind: .dry, now: now)
        let legacyLog = PetCareLog(
            date: now.addingTimeInterval(-600),
            type: .feeding,
            amountGrams: 300,
            foodKind: .dry,
            pet: pet
        )

        let snapshot = QuickFeedStockSnapshot.build(
            pet: pet,
            allEvents: [],
            careLogs: [legacyLog],
            feedingLedgerEntries: [],
            foodRecords: [record],
            now: now
        )

        #expect(snapshot.dryStock.consumedGrams == 0)
        #expect(snapshot.dryStock.remainingGrams == 1000)
    }

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func stockRecord(
        pet: Pet,
        totalGrams: Double,
        foodKind: FeedFoodKind,
        now: Date
    ) -> PetFoodRecord {
        PetFoodRecord(
            brand: "Stock",
            totalGrams: totalGrams,
            foodKind: foodKind,
            startDate: now.addingTimeInterval(-86400),
            pet: pet
        )
    }

    private func feedEntry(
        pet: Pet,
        date: Date,
        amount: Double,
        source: FeedLogSource,
        foodKind: FeedFoodKind,
        sharedSessionId: String = "",
        note: String = ""
    ) -> QuickFeedLedgerEntry {
        QuickFeedLedgerEntry(
            id: UUID(),
            petId: pet.id,
            date: date,
            amountGrams: amount,
            note: note,
            source: source,
            foodKind: foodKind,
            treatKind: nil,
            legacyModelId: nil,
            sharedSessionId: sharedSessionId,
            actorId: nil,
            sourceEventId: nil,
            sourceReminderId: nil,
            metadataJSON: ""
        )
    }
}
