import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct UITestPlantBaselineSeederTests {
    @Test func animationDisablingRequiresExplicitUITestLaunchMarker() {
        #expect(!OhanaUITestLaunchOptions.shouldDisableAnimations(arguments: []))
        #expect(!OhanaUITestLaunchOptions.shouldDisableAnimations(arguments: ["-OHANA_UI_TEST_ENABLE_ANIMATIONS"]))
        #expect(OhanaUITestLaunchOptions.shouldDisableAnimations(arguments: ["-OHANA_UI_TESTS"]))
        #expect(!OhanaUITestLaunchOptions.shouldDisableAnimations(arguments: [
            "-OHANA_UI_TESTS",
            "-OHANA_UI_TEST_ENABLE_ANIMATIONS"
        ]))
    }

    @Test func reduceMotionOverrideRequiresUITestSessionAndExplicitFlag() {
        let arguments = ["-OHANA_UI_TEST_REDUCE_MOTION"]

        #expect(!OhanaUITestLaunchOptions.shouldForceReduceMotion(
            arguments: [],
            isRunningUITests: true
        ))
        #expect(!OhanaUITestLaunchOptions.shouldForceReduceMotion(
            arguments: arguments,
            isRunningUITests: false
        ))
        #expect(OhanaUITestLaunchOptions.shouldForceReduceMotion(
            arguments: arguments,
            isRunningUITests: true
        ))
    }

    @Test func seedAddsMissingPlantsWithoutDuplicatingExistingBaseline() throws {
        let container = try makeInMemoryContainer()
        let services = AppServices(modelContainer: container)
        let context = container.mainContext

        UITestPlantBaselineSeeder.seed(
            modelContext: context,
            services: services,
            desiredCount: 4,
            revisionNote: "test.ui.plantSeed"
        )
        let firstPass = try seededPlants(in: context)

        #expect(firstPass.map(\.name) == [
            "Codex Pothos Seed-1",
            "Codex Pothos Seed-2",
            "Codex Pothos Seed-3",
            "Codex Pothos Seed-4"
        ])
        #expect(firstPass.map(\.roomNameRaw) == [
            "Living room",
            "Balcony",
            "Living room",
            "Balcony"
        ])

        UITestPlantBaselineSeeder.seed(
            modelContext: context,
            services: services,
            desiredCount: 2,
            revisionNote: "test.ui.plantSeed"
        )
        #expect(try seededPlants(in: context).count == 4)

        UITestPlantBaselineSeeder.seed(
            modelContext: context,
            services: services,
            desiredCount: 6,
            revisionNote: "test.ui.plantSeed"
        )
        let expanded = try seededPlants(in: context)
        #expect(expanded.count == 6)
        #expect(expanded.suffix(2).map(\.name) == [
            "Codex Pothos Seed-5",
            "Codex Pothos Seed-6"
        ])
    }

    private func seededPlants(in context: ModelContext) throws -> [Plant] {
        try context.fetch(
            FetchDescriptor<Plant>(
                predicate: #Predicate<Plant> { plant in
                    plant.notes == "Seeded by UI tests"
                },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, configurations: [config])
    }
}
