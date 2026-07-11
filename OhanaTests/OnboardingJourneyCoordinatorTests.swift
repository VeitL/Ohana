import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct OnboardingJourneyCoordinatorTests {
    @Test func freshInstallJourneyIsPetFirstAndCompletesWithinNinetySecondBudget() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preOnboarding = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: false,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(preOnboarding.phase == .preOnboarding)

        let startedAt = Date(timeIntervalSince1970: 1000)
        OnboardingJourneyCoordinator.beginFreshJourney(
            context: context,
            defaults: defaults,
            now: startedAt
        )
        let pending = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(pending.starterGiftResult == .pendingFirstPet)
        #expect(pending.phase == .needsFirstPet)

        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        context.safeSave()
        let needsFirstCare = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(needsFirstCare.starterGiftResult == .pendingFirstCare(recipient: .pet(pet.id)))
        #expect(needsFirstCare.phase == .firstCarePending)
        #expect(pet.coconutBalance == 0)

        context.insert(PetWeightLog(weight: 4.2, pet: pet))
        context.safeSave()

        let claimed = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(claimed.starterGiftResult == .claimed(recipient: .pet(pet.id), amount: StarterGiftService.giftAmount))
        #expect(claimed.phase == .starterGiftReadyForCeremony(amount: StarterGiftService.giftAmount))
        #expect(defaults.bool(forKey: OnboardingJourneyCoordinator.Key.firstCareCompleted))
        #expect(pet.coconutBalance == StarterGiftService.giftAmount)

        let completedAt = Date(timeIntervalSince1970: 1089)
        #expect(OnboardingJourneyCoordinator.journeyElapsedMilliseconds(
            defaults: defaults,
            now: completedAt
        ) == 89000)
        OnboardingJourneyCoordinator.markStarterCeremonySeen(
            defaults: defaults,
            now: completedAt
        )
        let complete = OnboardingJourneyCoordinator.currentPhase(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(complete == .complete)
    }

    @Test func interruptedOnboardingRecoversPersistedFirstPetWithoutHuman() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingJourneyCoordinator.beginFreshJourney(
            context: context,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 2000)
        )
        let first = Pet(name: "First", species: "cat")
        first.createdAt = Date(timeIntervalSince1970: 100)
        let second = Pet(name: "Second", species: "dog")
        second.createdAt = Date(timeIntervalSince1970: 200)
        context.insert(second)
        context.insert(first)
        context.safeSave()

        let recoveredID = OnboardingJourneyCoordinator.interruptedOnboardingFirstPetID(context: context)
        let evaluation = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(recoveredID == first.id.uuidString)
        #expect(evaluation.phase == .firstCarePending)
        #expect(evaluation.starterGiftResult == .pendingFirstCare(recipient: .pet(first.id)))
        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
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
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen))
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
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
