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

    @Test func petFirstJourneyWaitsForCareThenClaimsIntoIslandReserve() throws {
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

        #expect(waitingForCare == .pendingFirstCare(recipient: .island))
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

        #expect(result == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(pet.coconutBalance == 0)
        #expect(CoconutWalletService.balance(
            accountKey: CoconutAccountKey.islandReserve,
            context: context
        ) == StarterGiftService.giftAmount)
        #expect(CoconutWalletService.totalBalance(context: context) == StarterGiftService.giftAmount)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.pending))

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.actionType == "starterGift")
        #expect(ledger.first?.subjectKind == CareLedgerSubjectKind.household.rawValue)
        #expect(ledger.first?.subjectId == nil)
        #expect(ledger.first?.coconutDelta == StarterGiftService.giftAmount)
        #expect(ledger.first?.metadataJSON.contains("\"growthXP\":0") == true)
    }

    @Test func existingHumanDoesNotOwnTheSystemStarterGift() throws {
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

        #expect(result == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(human.coconutBalance == 0)
        #expect(pet.coconutBalance == 0)
        #expect(CoconutWalletService.balance(
            accountKey: CoconutAccountKey.islandReserve,
            context: context
        ) == StarterGiftService.giftAmount)
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
        #expect(first == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))

        defaults.removeObject(forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.pending)
        let recovered = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(recovered == .alreadyHandled)
        #expect(pet.coconutBalance == 0)
        #expect(CoconutWalletService.balance(
            accountKey: CoconutAccountKey.islandReserve,
            context: context
        ) == StarterGiftService.giftAmount)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count == 1)
    }

    @Test func legacyMemberStarterGiftMovesAvailableGiftBalanceToIslandOnce() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        try CoconutWalletService.apply(
            deltas: [
                .pet(
                    pet,
                    delta: StarterGiftService.giftAmount,
                    entryKind: .reward,
                    source: .starterGift,
                    title: "Starter gift",
                    transactionKey: "starterGift:v2:\(CoconutAccountKey.pet(pet.id))"
                ),
                .pet(
                    pet,
                    delta: 9,
                    entryKind: .reward,
                    source: .careEvent,
                    title: "Care reward",
                    transactionKey: "test:starter-gift:migration:care-reward"
                )
            ],
            context: context,
            save: true,
            postsRewardFeedback: false,
            updatesProjection: false
        )
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)

        let first = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        let entryCountAfterFirst = try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>())
        let second = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(first == .alreadyHandled)
        #expect(second == .alreadyHandled)
        #expect(CoconutWalletService.balance(for: pet, context: context) == 9)
        #expect(CoconutWalletService.balance(
            accountKey: CoconutAccountKey.islandReserve,
            context: context
        ) == StarterGiftService.giftAmount)
        #expect(CoconutWalletService.totalBalance(context: context) == 59)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == entryCountAfterFirst)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains {
            $0.sourceModelName == "StarterGiftOwnershipMigration" && !$0.affectsBalance
        })
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
