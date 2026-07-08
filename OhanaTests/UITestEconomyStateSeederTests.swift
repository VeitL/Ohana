import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct UITestEconomyStateSeederTests {
    @Test func seedCoconutBalancesAppliesToExistingAndNewlyCreatedMembersOnce() throws {
        UITestEconomyStateSeeder.resetSessionTrackingForTests()
        defer { UITestEconomyStateSeeder.resetSessionTrackingForTests() }

        let container = try makeInMemoryContainer()
        let services = AppServices(modelContainer: container)
        let context = container.mainContext
        let human = Human(name: "Ava")
        let pet = Pet(name: "Miso", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let activeHumanID = UITestEconomyStateSeeder.seedCoconutBalances(
            modelContext: context,
            services: services,
            amount: 750,
            currentActiveHumanId: human.id.uuidString,
            revisionNote: "test.ui.economySeed"
        )
        #expect(activeHumanID == human.id)
        #expect(human.coconutBalance == 750)
        #expect(pet.coconutBalance == 750)
        #expect(services.coconutWallet.balance(for: human, context: context) == 750)
        #expect(services.coconutWallet.balance(for: pet, context: context) == 750)

        human.coconutBalance = 120
        pet.coconutBalance = 80
        try context.save()
        _ = UITestEconomyStateSeeder.seedCoconutBalances(
            modelContext: context,
            services: services,
            amount: 750,
            currentActiveHumanId: human.id.uuidString,
            revisionNote: "test.ui.economySeed"
        )
        #expect(human.coconutBalance == 120)
        #expect(pet.coconutBalance == 80)

        let secondPet = Pet(name: "Nori", species: "dog")
        context.insert(secondPet)
        try context.save()
        _ = UITestEconomyStateSeeder.seedCoconutBalances(
            modelContext: context,
            services: services,
            amount: 750,
            currentActiveHumanId: human.id.uuidString,
            revisionNote: "test.ui.economySeed"
        )
        #expect(secondPet.coconutBalance == 750)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, configurations: [config])
    }
}
