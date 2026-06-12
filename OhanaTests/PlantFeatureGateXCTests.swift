import XCTest
@testable import Ohana

@MainActor
final class PlantFeatureGateXCTests: XCTestCase {
    func testLaunchPlantGateIsClosedAndOwnsEntrySurfaces() {
        XCTAssertFalse(PlantFeatureGate.allows(.plants))
        XCTAssertFalse(AppFeatureRouteGuard.allowsAddEntity(.plant))
        XCTAssertFalse(AppFeatureRouteGuard.allowsAppRoute(.plantProfile(id: UUID())))
        XCTAssertFalse(AppFeatureRouteGuard.visibleHomeTabs.contains(.plants))
        XCTAssertFalse(AppFeatureRouteGuard.shouldLoadPlantData)
    }

    func testLaunchQuestEngineDoesNotGeneratePlantQuestsWhenPlantsExist() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plant = Plant(name: "Fern", wateringIntervalDays: 1, fertilizingIntervalDays: 1)
        plant.lastWateredDate = now.addingTimeInterval(-3 * 86400)
        plant.lastFertilizedDate = now.addingTimeInterval(-40 * 86400)

        let quests = IslandQuestEngine.todayQuests(
            pets: [],
            reminders: [],
            plants: [plant],
            humans: [Human(name: "Owner")],
            now: now,
            questProgress: TodayFocusQuestProgress(
                isPetWizardCompleted: true,
                isFirstMealRecorded: true,
                isThemeColorSet: true
            )
        )

        XCTAssertFalse(quests.contains { $0.id.hasPrefix("q_water_plant") })
        XCTAssertFalse(quests.contains { $0.id.hasPrefix("q_fertilize_plant") })
        XCTAssertFalse(quests.contains { $0.targetPlantId == plant.id })
    }

    func testLaunchMoodSignalsDoNotReadPlantCareStateWhenPlantsExist() {
        let plant = Plant(name: "Fern")
        plant.lastWateredDate = Date(timeIntervalSinceNow: -9 * 86400)

        let signals = IslandNegativeFeedback.signals(pets: [], plants: [plant], clinicalAlerts: [])

        XCTAssertFalse(signals.contains { $0.plantId == plant.id })
        XCTAssertFalse(signals.contains { $0.routeHint == .plant })
    }

    func testLegacyPlantClosuresWereMovedBehindPlantFeatureGate() throws {
        let rootURL = repositoryRootURL()
        let routeGuard = try source("Ohana/App/AppFeatureRouteGuard.swift", rootURL: rootURL)
        let addEntity = try source("Ohana/Features/Members/Views/AddEntityRoute.swift", rootURL: rootURL)
        let growthUnlock = try source("Ohana/Features/GrowthUnlock/GrowthUnlockPolicy.swift", rootURL: rootURL)

        XCTAssertTrue(routeGuard.contains("PlantFeatureGate.allows(.plants)"))
        XCTAssertTrue(addEntity.contains("PlantFeatureGate.allows(.plants)"))
        XCTAssertFalse(growthUnlock.contains("plantsAreOutOfScope"))
        XCTAssertFalse(growthUnlock.contains("group == .plants { return .outOfScope }"))
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
