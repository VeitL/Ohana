import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HumanRequirementCoordinatorTests {
    @Test func notOnboardedDoesNotRequireHuman() throws {
        let container = try makeContainer()

        let resolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: false,
            currentActiveHumanId: "",
            isAccountSwitchPresented: false,
            context: container.mainContext
        )

        #expect(resolution == .notOnboarded)
    }

    @Test func onboardedWithoutHumansRequiresProfile() throws {
        let container = try makeContainer()

        let resolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: true,
            currentActiveHumanId: "",
            isAccountSwitchPresented: false,
            context: container.mainContext
        )

        #expect(resolution == .needsRequiredProfile)
    }

    @Test func accountSwitchPresentationIsPreserved() throws {
        let container = try makeContainer()
        let human = Human(name: "Owner")
        container.mainContext.insert(human)
        try container.mainContext.save()

        let resolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: true,
            currentActiveHumanId: "",
            isAccountSwitchPresented: true,
            context: container.mainContext
        )

        #expect(resolution == .preserveAccountSwitch)
    }

    @Test func emptyOrMissingActiveHumanActivatesFirstHuman() throws {
        let container = try makeContainer()
        let first = Human(name: "First")
        first.createdAt = Date(timeIntervalSince1970: 100)
        let second = Human(name: "Second")
        second.createdAt = Date(timeIntervalSince1970: 200)
        container.mainContext.insert(second)
        container.mainContext.insert(first)
        try container.mainContext.save()

        let emptyResolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: true,
            currentActiveHumanId: "",
            isAccountSwitchPresented: false,
            context: container.mainContext
        )
        let missingResolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: true,
            currentActiveHumanId: UUID().uuidString,
            isAccountSwitchPresented: false,
            context: container.mainContext
        )

        #expect(emptyResolution == .activateHuman(first.id.uuidString))
        #expect(missingResolution == .activateHuman(first.id.uuidString))
    }

    @Test func existingActiveHumanIsReady() throws {
        let container = try makeContainer()
        let human = Human(name: "Owner")
        container.mainContext.insert(human)
        try container.mainContext.save()

        let resolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: true,
            currentActiveHumanId: human.id.uuidString,
            isAccountSwitchPresented: false,
            context: container.mainContext
        )

        #expect(resolution == .ready)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
