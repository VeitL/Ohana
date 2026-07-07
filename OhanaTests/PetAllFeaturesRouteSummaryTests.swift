import Foundation
import SwiftData
import Testing
@testable import Ohana

struct PetAllFeaturesRouteSummaryTests {
    @MainActor
    @Test func petAllFeaturesSummaryUsesLedgerAndRouteScopedCounts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let now = date(year: 2026, month: 7, day: 7, hour: 12)
        let todayStart = calendar.startOfDay(for: now)
        let pet = Pet(name: "Momo", species: "狗")
        let otherPet = Pet(name: "Nori", species: "猫")
        context.insert(pet)
        context.insert(otherPet)

        context.insert(PetCareLog(date: now, type: .feeding, amountGrams: 999, pet: pet))
        context.insert(PetPottyLog(date: now, type: .pee, pet: pet))
        context.insert(PetWalkLog(startDate: now, pet: pet))

        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(3600),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: 42
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(4200),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(-86400),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.watering.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(5000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.pee.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(6000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .walk,
            actionType: "walk",
            amountValue: 1200
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(-2 * 86400),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .walk,
            actionType: "walk",
            amountValue: 800
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(7000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: HealthLogType.checkup.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(-7000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(8000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.8
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(9000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.food.rawValue,
            amountValue: 20
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(10000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.treats.rawValue,
            amountValue: 30
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(11000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        ))

        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), pet: pet))
        context.insert(PetMilestone(title: "First hike", pet: pet))
        context.insert(PetDocument(title: "Vaccine", category: .vaccine, pet: pet))
        context.insert(PetDocument(title: "Passport", category: .other, pet: pet))
        context.insert(PetInsurance(companyName: "Ohana Care", pet: pet))
        context.insert(PetMedication(name: "Active", startDate: todayStart, pet: pet))
        let inactiveMedication = PetMedication(name: "Inactive", startDate: todayStart, pet: pet)
        inactiveMedication.isActive = false
        context.insert(inactiveMedication)
        try context.save()

        let summary = PetAllFeaturesActivitySummary.load(petID: pet.id, context: context, now: now)

        #expect(summary.todayFeedCount == 1)
        #expect(summary.todayNonFeedingCareCount == 1)
        #expect(summary.totalNonFeedingCareCount == 2)
        #expect(summary.todayPottyCount == 1)
        #expect(summary.todayWalkCount == 1)
        #expect(summary.totalWalkCount == 2)
        #expect(summary.weekWalkDistanceMeters == 2000)
        #expect(summary.healthCount == 1)
        #expect(summary.weightCount == 2)
        #expect(summary.latestWeightKg == 4.8)
        #expect(summary.expenseCount == 2)
        #expect(summary.expenseTotal == 50)
        #expect(summary.photoCount == 1)
        #expect(summary.milestoneCount == 1)
        #expect(summary.documentCount == 2)
        #expect(summary.protectionDocumentCount == 1)
        #expect(summary.insuranceCount == 1)
        #expect(summary.medicationCount == 2)
        #expect(summary.activeMedicationCount == 1)
    }

    @Test func petAllFeaturesRouteLoadsSummaryThroughModelActor() throws {
        let rootURL = repositoryRootURL()
        let routeSource = try source("Ohana/Features/Members/PetDetailSheetRouteContainer.swift", rootURL: rootURL)
        let actorSource = try source("Ohana/Features/Members/PetAllFeaturesActivitySummaryActor.swift", rootURL: rootURL)
        let chartSource = try source("Ohana/Shared/Components/OhanaChartStyle.swift", rootURL: rootURL)
        let featureHubSource = try source("Ohana/Shared/Components/FeatureHubComponents.swift", rootURL: rootURL)

        #expect(routeSource.contains("PetAllFeaturesActivitySummaryActor(modelContainer: container)"))
        #expect(!routeSource.contains("PetAllFeaturesActivitySummary.load(petID: petID, context: modelContext)"))
        #expect(routeSource.contains("OhanaFrameScheduler.waitAfterNextFrame"))
        #expect(actorSource.contains("@ModelActor"))
        #expect(actorSource.contains("PetAllFeaturesActivitySummary.load("))
        #expect(chartSource.contains("OhanaMinimalChartPoint: Identifiable, Hashable, Sendable"))
        #expect(featureHubSource.contains("nonisolated enum FeatureHubChartPointFactory"))
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}
