import Foundation
import Testing
@testable import Ohana

@MainActor
struct QuickFeedDataControllerTests {
    @Test func observedCollectionsUseFallbackUntilFullDataLoads() {
        let pet = Pet(name: "Momo", species: "猫")
        let fallbackLog = PetCareLog(date: Date(), type: .feeding, pet: pet)
        let loadedLog = PetCareLog(date: Date().addingTimeInterval(-60), type: .feeding, pet: pet)
        let fallbackRecord = PetFoodRecord(brand: "A", totalGrams: 100, startDate: Date(), pet: pet)
        let loadedRecord = PetFoodRecord(brand: "B", totalGrams: 200, startDate: Date().addingTimeInterval(-60), pet: pet)
        let controller = QuickFeedDataController()

        #expect(controller.observedCareLogs(fallback: [fallbackLog]).map(\.id) == [fallbackLog.id])
        #expect(controller.observedFoodRecords(fallback: [fallbackRecord]).map(\.id) == [fallbackRecord.id])

        controller.loadedCareLogs = [loadedLog]
        controller.loadedFoodRecords = [loadedRecord]
        controller.hasLoadedFullCareLogs = true
        controller.hasLoadedFullFoodRecords = true

        #expect(controller.observedCareLogs(fallback: [fallbackLog]).map(\.id) == [loadedLog.id])
        #expect(controller.observedFoodRecords(fallback: [fallbackRecord]).map(\.id) == [loadedRecord.id])
    }

    @Test func loadFullCollectionsUsesInjectedFetchersOnceUntilForced() {
        let pet = Pet(name: "Momo", species: "猫")
        let fallbackLog = PetCareLog(date: Date(), type: .feeding, pet: pet)
        let loadedLog = PetCareLog(date: Date().addingTimeInterval(-60), type: .feeding, pet: pet)
        let forcedLog = PetCareLog(date: Date().addingTimeInterval(-120), type: .feeding, pet: pet)
        let fallbackRecord = PetFoodRecord(brand: "A", totalGrams: 100, startDate: Date(), pet: pet)
        let loadedRecord = PetFoodRecord(brand: "B", totalGrams: 200, startDate: Date().addingTimeInterval(-60), pet: pet)
        let forcedRecord = PetFoodRecord(brand: "C", totalGrams: 300, startDate: Date().addingTimeInterval(-120), pet: pet)
        let controller = QuickFeedDataController()
        var careFetchCount = 0
        var foodFetchCount = 0

        controller.loadFullCareLogs(
            petID: pet.id,
            feedingType: CareType.feeding.rawValue,
            fallback: [fallbackLog],
            fetcher: { _, _, _ in
                careFetchCount += 1
                return [loadedLog]
            }
        )
        controller.loadFullCareLogs(
            petID: pet.id,
            feedingType: CareType.feeding.rawValue,
            fallback: [fallbackLog],
            fetcher: { _, _, _ in
                careFetchCount += 1
                return [forcedLog]
            }
        )

        controller.loadFullFoodRecords(
            petID: pet.id,
            fallback: [fallbackRecord],
            fetcher: { _, _ in
                foodFetchCount += 1
                return [loadedRecord]
            }
        )
        controller.loadFullFoodRecords(
            petID: pet.id,
            fallback: [fallbackRecord],
            force: true,
            fetcher: { _, _ in
                foodFetchCount += 1
                return [forcedRecord]
            }
        )

        #expect(careFetchCount == 1)
        #expect(foodFetchCount == 2)
        #expect(controller.loadedCareLogs.map(\.id) == [loadedLog.id])
        #expect(controller.loadedFoodRecords.map(\.id) == [forcedRecord.id])
    }
}
