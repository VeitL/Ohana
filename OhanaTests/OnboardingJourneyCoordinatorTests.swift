import Foundation
import SwiftData
@testable import Ohana
import Testing

@MainActor
struct OnboardingJourneyCoordinatorTests {
    @Test func freshInstallJourneyCompletesAfterHumanAndStarterGift() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        let oldCount = QuestManager.shared.coconutCount
        let oldLogs = QuestManager.shared.coconutLogs
        defer {
            QuestManager.shared.coconutCount = oldCount
            QuestManager.shared.coconutLogs = oldLogs
            QuestManager.shared.flushToDefaults()
            defaults.removePersistentDomain(forName: suiteName)
        }

        let preOnboarding = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: false,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(preOnboarding.phase == .preOnboarding)

        let pending = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(pending.phase == .starterGiftPending)

        let human = Human(name: "Guan")
        context.insert(human)
        context.safeSave()
        QuestManager.shared.coconutCount = 0
        QuestManager.shared.coconutLogs = []

        let claimed = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )
        #expect(claimed.starterGiftResult == .claimed(humanID: human.id, amount: StarterGiftService.giftAmount))
        #expect(claimed.phase == .starterGiftReadyForCeremony(amount: StarterGiftService.giftAmount))

        OnboardingJourneyCoordinator.markStarterCeremonySeen(defaults: defaults)
        let complete = OnboardingJourneyCoordinator.currentPhase(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )
        #expect(complete == .complete)
    }

    @Test func existingUserIsMarkedCompleteWithoutStarterCeremony() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let human = Human(name: "Existing")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        context.safeSave()

        let evaluation = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )

        #expect(evaluation.phase == .existingUser)
        #expect(defaults.bool(forKey: StarterGiftService.Key.claimed))
        #expect(defaults.bool(forKey: StarterGiftService.Key.ceremonySeen))
        #expect(defaults.bool(forKey: OnboardingJourneyCoordinator.Key.firstCareCompleted))
        #expect(defaults.bool(forKey: OnboardingJourneyCoordinator.Key.roadmapPromptSeen))
    }

    private func makeDefaultsSuiteName() -> String {
        "OnboardingJourneyCoordinatorTests.\(UUID().uuidString)"
    }

    private func makeDefaults(suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV56.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
