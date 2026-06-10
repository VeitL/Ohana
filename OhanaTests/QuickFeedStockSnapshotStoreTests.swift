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

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}
