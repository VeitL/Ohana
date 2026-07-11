import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct StarterGiftServiceTests {
    @Test func freshInstallMarksGiftPendingUntilFirstPetExists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(result == .pendingFirstPet)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.claimed))
    }

    @Test func petFirstJourneyWaitsForCareThenClaimsIntoPetWallet() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        context.safeSave()
        let waitingForCare = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(waitingForCare == .pendingFirstCare(recipient: .pet(pet.id)))
        #expect(pet.coconutBalance == 0)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.claimed))

        context.insert(PetWeightLog(weight: 4.2, pet: pet))
        context.safeSave()

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(result == .claimed(recipient: .pet(pet.id), amount: StarterGiftService.giftAmount))
        #expect(pet.coconutBalance == StarterGiftService.giftAmount)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.pending))

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.actionType == "starterGift")
        #expect(ledger.first?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(ledger.first?.subjectId == pet.id.uuidString)
        #expect(ledger.first?.coconutDelta == StarterGiftService.giftAmount)
        #expect(ledger.first?.metadataJSON.contains("\"growthXP\":0") == true)
    }

    @Test func existingHumanRemainsTheRecipientWhenOneIsAvailable() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        let human = Human(name: "Fresh")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        context.insert(PetWeightLog(weight: 4.2, pet: pet))
        context.safeSave()

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )

        #expect(result == .claimed(recipient: .human(human.id), amount: StarterGiftService.giftAmount))
        #expect(human.coconutBalance == StarterGiftService.giftAmount)
        #expect(pet.coconutBalance == 0)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen))
        #expect(StarterGiftService.shouldShowCeremony(defaults: defaults))
    }

    @Test func persistedGiftRecoversDefaultsWithoutMintingTwice() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        context.insert(PetWeightLog(weight: 4.2, pet: pet))
        context.safeSave()

        let first = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(first == .claimed(recipient: .pet(pet.id), amount: StarterGiftService.giftAmount))

        defaults.removeObject(forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.pending)
        let recovered = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(recovered == .alreadyHandled)
        #expect(pet.coconutBalance == StarterGiftService.giftAmount)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count == 1)
    }

    @Test func existingUserIsMarkedHandledWithoutGift() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        let human = Human(name: "Existing")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        context.safeSave()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )

        #expect(result == .markedExistingUser)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen))
        #expect(human.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    private func makeDefaultsSuiteName() -> String {
        "StarterGiftServiceTests.\(UUID().uuidString)"
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
