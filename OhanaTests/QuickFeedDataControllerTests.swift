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
        let fallbackEntry = feedEntry(pet: pet, amount: 20)
        let loadedEntry = feedEntry(pet: pet, amount: 30)
        let controller = QuickFeedDataController()

        #expect(controller.observedCareLogs(fallback: [fallbackLog]).map(\.id) == [fallbackLog.id])
        #expect(controller.observedFeedingLedgerEntries(fallback: [fallbackEntry]).map(\.id) == [fallbackEntry.id])
        #expect(controller.observedFoodRecords(fallback: [fallbackRecord]).map(\.id) == [fallbackRecord.id])

        controller.loadedCareLogs = [loadedLog]
        controller.loadedFeedingLedgerEntries = [loadedEntry]
        controller.loadedFoodRecords = [loadedRecord]
        controller.hasLoadedFullCareLogs = true
        controller.hasLoadedFullFeedingLedgerEntries = true
        controller.hasLoadedFullFoodRecords = true

        #expect(controller.observedCareLogs(fallback: [fallbackLog]).map(\.id) == [loadedLog.id])
        #expect(controller.observedFeedingLedgerEntries(fallback: [fallbackEntry]).map(\.id) == [loadedEntry.id])
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
        let fallbackEntry = feedEntry(pet: pet, amount: 20)
        let loadedEntry = feedEntry(pet: pet, amount: 30)
        let controller = QuickFeedDataController()
        var careFetchCount = 0
        var ledgerEntryFetchCount = 0
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
        controller.loadFullFeedingLedgerEntries(
            petID: pet.id,
            fallback: [fallbackEntry],
            fetcher: { _, _ in
                ledgerEntryFetchCount += 1
                return [loadedEntry]
            }
        )
        controller.loadFullFeedingLedgerEntries(
            petID: pet.id,
            fallback: [fallbackEntry],
            fetcher: { _, _ in
                ledgerEntryFetchCount += 1
                return [fallbackEntry]
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
        #expect(ledgerEntryFetchCount == 1)
        #expect(foodFetchCount == 2)
        #expect(controller.loadedCareLogs.map(\.id) == [loadedLog.id])
        #expect(controller.loadedFeedingLedgerEntries.map(\.id) == [loadedEntry.id])
        #expect(controller.loadedFoodRecords.map(\.id) == [forcedRecord.id])
    }

    @Test func quickFeedRenderRowsDoNotAcceptLegacyCareLogModels() throws {
        let rootURL = repositoryRootURL()
        let rowSource = try source(
            "Ohana/Features/Feeding/Views/QuickFeedDetailContent+FeedRows.swift",
            rootURL: rootURL
        )
        let helpers = try source(
            "Ohana/Features/Feeding/Views/QuickFeedDetailContent+Helpers.swift",
            rootURL: rootURL
        )
        let routeSource = try source("Ohana/Features/Feeding/QuickFeedPresentationRoutes.swift", rootURL: rootURL)
        let draftSource = try source("Ohana/Features/Feeding/QuickFeedDraftStore.swift", rootURL: rootURL)
        let alertHostSource = try source("Ohana/Features/Feeding/Views/QuickFeedAlertHost.swift", rootURL: rootURL)

        #expect(!rowSource.contains("func feedLogRow(_ log: PetCareLog"))
        #expect(rowSource.contains("func feedLogRow(_ entry: QuickFeedLedgerEntry"))
        #expect(!rowSource.contains("observedCareLogs.first"))
        #expect(!rowSource.contains("legacyFeedLog(for"))
        #expect(!helpers.contains("func feedLogBadge(for log: PetCareLog"))
        #expect(!routeSource.contains("case deleteFeedLog(PetCareLog)"))
        #expect(routeSource.contains("case deleteFeedLog(id: UUID)"))
        #expect(!draftSource.contains("editingFeedLog: PetCareLog?"))
        #expect(draftSource.contains("editingFeedLogId: UUID?"))
        #expect(alertHostSource.contains("let onDeleteFeedLog: (UUID) -> Void"))
    }

    @Test func feedTodayStateDoesNotFallbackToPetCareLogRelationship() throws {
        let rootURL = repositoryRootURL()
        let todayStateSource = try source("Ohana/Features/Feeding/FeedTodayState.swift", rootURL: rootURL)
        let dashboardStateSource = try source("Ohana/Features/Feeding/FeedingDashboardState.swift", rootURL: rootURL)
        let stockSupportSource = try source("Ohana/Features/Feeding/FeedStockSupport.swift", rootURL: rootURL)
        let planWriterSource = try source("Ohana/Features/Feeding/FeedingPlanWriter.swift", rootURL: rootURL)
        let petSource = try source("Ohana/Models/Pet.swift", rootURL: rootURL)

        #expect(!todayStateSource.contains("pet.careLogs"))
        #expect(!todayStateSource.contains("careLogs ??"))
        #expect(!todayStateSource.contains("let careLogs: [PetCareLog]?"))
        #expect(!dashboardStateSource.contains("let careLogs: [PetCareLog]?"))
        #expect(dashboardStateSource.contains("careLogs: [PetCareLog] = []"))
        #expect(!stockSupportSource.contains("pet.careLogs"))
        #expect(!stockSupportSource.contains("careLogs ??"))
        #expect(!stockSupportSource.contains("careLogs: [PetCareLog]?"))
        #expect(planWriterSource.contains("stockCareLogs(petID: pet.id, context: context)"))
        #expect(!petSource.contains("careLogs.compactMap { log -> UUID?"))
        #expect(!petSource.contains("FeedStockCalculator.snapshot(for: self, sharedCareSessions:"))
    }

    private func feedEntry(pet: Pet, amount: Double) -> QuickFeedLedgerEntry {
        QuickFeedLedgerEntry(
            id: UUID(),
            petId: pet.id,
            date: Date(),
            amountGrams: amount,
            note: "",
            source: .manualMain,
            foodKind: .dry,
            treatKind: nil,
            legacyModelId: nil,
            sharedSessionId: "",
            actorId: nil,
            sourceEventId: nil,
            sourceReminderId: nil,
            metadataJSON: ""
        )
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
