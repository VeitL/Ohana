import Foundation
import Testing
@testable import Ohana

@MainActor
struct IslandFoodDashboardSnapshotStoreTests {
    @Test func dashboardSnapshotAggregatesSelectedPetsAndStockOnce() {
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let momo = Pet(name: "Momo", species: "猫")
        momo.dailyPortionGrams = 50
        let nori = Pet(name: "Nori", species: "猫")
        nori.dailyPortionGrams = 60
        let momoLog = PetCareLog(date: today.addingTimeInterval(3600), amountGrams: 40, foodKind: .dry, pet: momo)
        let noriLog = PetCareLog(date: today.addingTimeInterval(7200), amountGrams: 60, foodKind: .dry, pet: nori)
        let momoLedger = feedingLedgerEvent(pet: momo, date: momoLog.date, grams: 40)
        let noriLedger = feedingLedgerEvent(pet: nori, date: noriLog.date, grams: 60)
        let ledgerEntries = FoodLedgerEntry.entries(from: [momoLedger, noriLedger])
        let momoStock = PetFoodRecord(
            brand: "Dry",
            totalGrams: 1000,
            foodKind: .dry,
            startDate: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            pet: momo
        )

        let allSnapshot = IslandFoodDashboardSnapshot.build(
            pets: [nori, momo],
            selectedPetId: nil,
            allEvents: [],
            allFeedingLedgerEntries: ledgerEntries,
            legacyStockCareLogs: [momoLog, noriLog],
            allFoodRecords: [momoStock],
            now: now,
            calendar: calendar
        )

        #expect(allSnapshot.activePets.map(\.id) == [momo.id, nori.id])
        #expect(allSnapshot.todayFeedCount == 2)
        #expect(allSnapshot.todayGrams == 100)
        #expect(allSnapshot.dailyPoints.last?.count == 2)
        #expect(allSnapshot.petSummaries.count == 2)
        #expect(allSnapshot.stock(for: momo)?.hasStock == true)
        #expect(allSnapshot.lowestFoodDaysPet?.id == momo.id)

        let selectedSnapshot = IslandFoodDashboardSnapshot.build(
            pets: [nori, momo],
            selectedPetId: momo.id,
            allEvents: [],
            allFeedingLedgerEntries: ledgerEntries,
            legacyStockCareLogs: [momoLog, noriLog],
            allFoodRecords: [momoStock],
            now: now,
            calendar: calendar
        )

        #expect(selectedSnapshot.selectedPets.map(\.id) == [momo.id])
        #expect(selectedSnapshot.todayFeedCount == 1)
        #expect(selectedSnapshot.todayGrams == 40)
        #expect(selectedSnapshot.petSummaries.map(\.id) == [momo.id])
    }

    @Test func dashboardInputRevisionChangesWhenContentChangesWithoutCountChanges() {
        let now = fixedDate()
        let pet = Pet(name: "Momo", species: "猫")
        let ledger = feedingLedgerEvent(pet: pet, date: now, grams: 40)
        let originalEntries = FoodLedgerEntry.entries(from: [ledger])
        let foodRecord = PetFoodRecord(
            brand: "Dry",
            totalGrams: 1000,
            foodKind: .dry,
            startDate: now,
            pet: pet
        )
        let original = IslandFoodDashboardInputRevision.make(
            pets: [pet],
            selectedPetId: nil,
            allEvents: [],
            allFeedingLedgerEntries: originalEntries,
            legacyStockCareLogs: [],
            allFoodRecords: [foodRecord],
            allSharedCareSessions: []
        )

        ledger.amountValue = 55
        let changedEntries = FoodLedgerEntry.entries(from: [ledger])
        let changedLedger = IslandFoodDashboardInputRevision.make(
            pets: [pet],
            selectedPetId: nil,
            allEvents: [],
            allFeedingLedgerEntries: changedEntries,
            legacyStockCareLogs: [],
            allFoodRecords: [foodRecord],
            allSharedCareSessions: []
        )
        foodRecord.remainingCorrectionGrams = 700
        let changedStock = IslandFoodDashboardInputRevision.make(
            pets: [pet],
            selectedPetId: nil,
            allEvents: [],
            allFeedingLedgerEntries: changedEntries,
            legacyStockCareLogs: [],
            allFoodRecords: [foodRecord],
            allSharedCareSessions: []
        )

        #expect(changedLedger != original)
        #expect(changedStock != changedLedger)
        #expect(changedLedger.shouldReplayChart(comparedTo: original))
        #expect(!changedStock.shouldReplayChart(comparedTo: changedLedger))
    }

    @Test func foodLedgerEntriesFilterSortAndClampInvalidRows() {
        let now = fixedDate()
        let pet = Pet(name: "Momo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let older = feedingLedgerEvent(pet: pet, date: now.addingTimeInterval(-3600), grams: -12)
        let newer = feedingLedgerEvent(pet: otherPet, date: now, grams: 30)
        let wrongKind = CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: CareType.feeding.rawValue
        )
        let wrongAction = CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.watering.rawValue
        )

        let entries = FoodLedgerEntry.entries(from: [older, wrongKind, wrongAction, newer])

        #expect(entries.map(\.id) == [newer.id, older.id])
        #expect(entries.map(\.petId) == [otherPet.id, pet.id])
        #expect(entries[1].amountGrams == 0)
    }

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func feedingLedgerEvent(pet: Pet, date: Date, grams: Double) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: grams,
            amountUnit: "g",
            legacyModelName: "PetCareLog"
        )
    }
}
