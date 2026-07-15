import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct OnboardingJourneyCoordinatorTests {
    @Test func freshJourneyMovesFromHumanNameThroughDeferredPetChoice() throws {
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

        OnboardingJourneyCoordinator.beginFreshJourney(
            context: context,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 1000)
        )
        let needsHuman = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: false,
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(needsHuman.phase == .needsHumanName)
        #expect(needsHuman.starterGiftResult == .pendingFirstPet)
        #expect(!StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))

        let human = Human(name: "Ava")
        context.insert(human)
        context.safeSave()
        OnboardingJourneyCoordinator.markFirstHumanCreated(human.id, defaults: defaults)

        let choice = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: false,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )
        #expect(choice.phase == .petChoice)
        #expect(defaults.string(forKey: OnboardingJourneyCoordinator.Key.firstHumanID) == human.id.uuidString)

        OnboardingJourneyCoordinator.markPetCreationStarted(defaults: defaults)
        #expect(OnboardingJourneyCoordinator.currentPhase(
            hasOnboarded: false,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        ) == .petCreation)

        OnboardingJourneyCoordinator.markPetDeferred(defaults: defaults)
        #expect(OnboardingJourneyCoordinator.currentPhase(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        ) == .awaitingPet)
        #expect(!StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))
    }

    @Test func completedOnboardingWithHumanAndNoPetDefaultsToAwaitingPet() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingJourneyCoordinator.beginFreshJourney(context: context, defaults: defaults)
        let human = Human(name: "Ava")
        context.insert(human)
        context.safeSave()

        let evaluation = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )

        #expect(evaluation.phase == .awaitingPet)
        #expect(evaluation.starterGiftResult == .pendingFirstPet)
    }

    @Test func petMakesGiftReadyBeforeCareAndClaimUnlocksOnlyAfterAcknowledgement() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let startedAt = Date(timeIntervalSince1970: 1000)
        OnboardingJourneyCoordinator.beginFreshJourney(
            context: context,
            defaults: defaults,
            now: startedAt
        )
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        context.safeSave()

        let ready = OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )
        #expect(ready.phase == .starterGiftReady(amount: StarterGiftService.giftAmount))
        #expect(ready.starterGiftResult == .readyToClaim(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(try context.fetch(FetchDescriptor<PetWeightLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(!StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))

        // Merely dismissing/finishing the visual ceremony cannot unlock before
        // the economic transaction has committed.
        OnboardingJourneyCoordinator.markStarterCeremonySeen(defaults: defaults)
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen))

        let claim = OnboardingJourneyCoordinator.claimStarterGift(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )
        #expect(claim == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(!StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))
        #expect(OnboardingJourneyCoordinator.currentPhase(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        ) == .starterGiftReady(amount: StarterGiftService.giftAmount))

        let completedAt = Date(timeIntervalSince1970: 1089)
        #expect(OnboardingJourneyCoordinator.journeyElapsedMilliseconds(
            defaults: defaults,
            now: completedAt
        ) == 89000)
        OnboardingJourneyCoordinator.markStarterCeremonySeen(defaults: defaults, now: completedAt)
        #expect(StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))
        #expect(OnboardingJourneyCoordinator.currentPhase(
            hasOnboarded: true,
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        ) == .complete)
    }

    @Test func unfinishedLegacyJourneyWithPetBecomesReadyWithoutHumanOrCare() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: StarterGiftStorageKey.pending)
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
        #expect(evaluation.phase == .starterGiftReady(amount: StarterGiftService.giftAmount))
        #expect(evaluation.starterGiftResult == .readyToClaim(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
    }

    @Test func existingUserIsMarkedCompleteWithoutStarterPrompt() throws {
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
        #expect(defaults.bool(forKey: OnboardingJourneyCoordinator.Key.roadmapPromptSeen))
        #expect(StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))
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
