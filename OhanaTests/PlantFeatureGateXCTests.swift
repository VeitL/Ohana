import XCTest
@testable import Ohana

@MainActor
final class PlantFeatureGateXCTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PlantUnlockPolicy.clearExistingPlantData()
        PlantLockedPreviewPolicy.clearOnboardingPlantInterest()
        PlantCatalogFavoriteStore.clearFavorites()
    }

    override func tearDown() {
        PlantUnlockPolicy.clearExistingPlantData()
        PlantLockedPreviewPolicy.clearOnboardingPlantInterest()
        PlantCatalogFavoriteStore.clearFavorites()
        super.tearDown()
    }

    func testPlantBuildGateIsOpenButEntrySurfacesUnlockAtLevelFour() {
        XCTAssertTrue(PlantFeatureGate.allows(.plants))
        XCTAssertFalse(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
        XCTAssertTrue(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 4))
        XCTAssertFalse(AppFeatureRouteGuard.allowsAppRoute(.plantProfile(id: UUID()), currentLevel: 3))
        XCTAssertTrue(AppFeatureRouteGuard.allowsAppRoute(.plantProfile(id: UUID()), currentLevel: 4))
        XCTAssertFalse(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 3).contains(.plants))
        XCTAssertTrue(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 4).contains(.plants))
        XCTAssertTrue(AppFeatureRouteGuard.shouldLoadPlantData)
    }

    func testExistingPlantDataGrandfathersEntrySurfacesBeforeLevelFour() {
        PlantUnlockPolicy.noteExistingPlantData()

        XCTAssertTrue(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
        XCTAssertTrue(AppFeatureRouteGuard.allowsAppRoute(.plantProfile(id: UUID()), currentLevel: 3))
        XCTAssertTrue(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 3).contains(.plants))
    }

    func testLockedPreviewDoesNotUnlockPlantEntrySurfaces() {
        PlantLockedPreviewPolicy.noteOnboardingPlantInterest()

        XCTAssertTrue(PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: 3))
        XCTAssertFalse(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
        XCTAssertFalse(AppFeatureRouteGuard.allowsAppRoute(.plantProfile(id: UUID()), currentLevel: 3))
        XCTAssertFalse(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 3).contains(.plants))
        XCTAssertEqual(PlantLockedPreviewPolicy.energyRemainingForUnlock(currentEnergy: 300), 200)
    }

    func testPlantCatalogFavoritesPersistWithoutCreatingPlantAccess() {
        XCTAssertFalse(PlantCatalogFavoriteStore.isFavorite(id: "epipremnum-aureum"))

        XCTAssertTrue(PlantCatalogFavoriteStore.toggleFavorite(id: "epipremnum-aureum"))

        XCTAssertTrue(PlantCatalogFavoriteStore.isFavorite(id: "epipremnum-aureum"))
        XCTAssertEqual(PlantCatalogFavoriteStore.favoriteIDs(), ["epipremnum-aureum"])
        XCTAssertFalse(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
    }

    func testQuestEngineOnlyGeneratesPlantQuestsWhenPlantCareIsIncluded() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plant = Plant(name: "Fern", wateringIntervalDays: 1, fertilizingIntervalDays: 1)
        plant.lastWateredDate = now.addingTimeInterval(-3 * 86400)
        plant.lastFertilizedDate = now.addingTimeInterval(-40 * 86400)

        let hiddenQuests = IslandQuestEngine.todayQuests(
            pets: [],
            reminders: [],
            plants: [plant],
            humans: [Human(name: "Owner")],
            includesPlants: false,
            now: now,
            questProgress: TodayFocusQuestProgress(
                isPetWizardCompleted: true,
                isFirstMealRecorded: true,
                isThemeColorSet: true
            )
        )
        XCTAssertFalse(hiddenQuests.contains { $0.targetPlantId == plant.id })

        let quests = IslandQuestEngine.todayQuests(
            pets: [],
            reminders: [],
            plants: [plant],
            humans: [Human(name: "Owner")],
            includesPlants: true,
            now: now,
            questProgress: TodayFocusQuestProgress(
                isPetWizardCompleted: true,
                isFirstMealRecorded: true,
                isThemeColorSet: true
            )
        )

        let plantQuests = quests.filter { IslandQuestEngine.isPlantCareQuest($0.id) }
        XCTAssertEqual(plantQuests.count, 1)
        XCTAssertEqual(plantQuests.first?.targetPlantIds, [plant.id])
        XCTAssertTrue(plantQuests.first?.targetPlantId == plant.id)
    }

    func testMoodSignalsReadPlantCareStateWhenPlantCareIsUnlocked() {
        PlantUnlockPolicy.noteExistingPlantData()
        let plant = Plant(name: "Fern")
        plant.lastWateredDate = Date(timeIntervalSinceNow: -9 * 86400)

        let signals = IslandNegativeFeedback.signals(pets: [], plants: [plant], clinicalAlerts: [])

        XCTAssertTrue(signals.contains { $0.plantId == plant.id })
        XCTAssertTrue(signals.contains { $0.routeHint == .plant })
    }

    func testLegacyPlantClosuresWereMovedBehindPlantUnlockPolicy() throws {
        let rootURL = repositoryRootURL()
        let routeGuard = try source("Ohana/App/AppFeatureRouteGuard.swift", rootURL: rootURL)
        let addEntity = try source("Ohana/Features/Members/Views/AddEntityRoute.swift", rootURL: rootURL)
        let growthUnlock = try source("Ohana/Features/GrowthUnlock/GrowthUnlockPolicy.swift", rootURL: rootURL)

        XCTAssertTrue(routeGuard.contains("PlantFeatureGate.allows(.plants)"))
        XCTAssertTrue(routeGuard.contains("PlantUnlockPolicy.isUnlocked"))
        XCTAssertTrue(addEntity.contains("PlantUnlockPolicy.isUnlocked"))
        XCTAssertTrue(growthUnlock.contains("case .plants: .household"))
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
