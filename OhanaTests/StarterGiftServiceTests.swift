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
        let result = StarterGiftService.evaluateEligibility(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(result == .pendingFirstPet)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.ceremonyRequested))
    }

    @Test func firstActivePetMakesGiftReadyWithoutCareAndConfirmationClaimsIntoIslandReserve() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        context.safeSave()
        let ready = StarterGiftService.evaluateEligibility(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(ready == .readyToClaim(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(pet.coconutBalance == 0)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)

        let result = StarterGiftService.claimStarterGift(
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

        defaults.set(true, forKey: StarterGiftStorageKey.ceremonyRequested)
        StarterGiftService.markCeremonySeen(defaults: defaults)
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.ceremonyRequested))

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
        context.safeSave()

        let eligibility = StarterGiftService.evaluateEligibility(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )
        #expect(eligibility == .readyToClaim(recipient: .island, amount: StarterGiftService.giftAmount))

        let result = StarterGiftService.claimStarterGift(
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

    @Test func memorialPetDoesNotMakeStarterGiftEligible() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date()
        context.insert(pet)
        context.safeSave()

        let result = StarterGiftService.evaluateEligibility(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(result == .pendingFirstPet)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.claimed))
    }

    @Test func zenFirstPlantUsesTheSameHouseholdGiftAndCannotDoubleClaimThroughStandard() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        context.insert(Plant(name: "Monstera", species: "Monstera deliciosa"))
        context.safeSave()

        #expect(StarterGiftService.evaluateZenEligibility(
            context: context,
            defaults: defaults
        ) == .readyToClaim(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(StarterGiftService.claimZenStarterGift(
            context: context,
            defaults: defaults
        ) == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))

        context.insert(Pet(name: "Momo", species: "cat"))
        context.safeSave()
        #expect(StarterGiftService.claimStarterGift(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        ) == .alreadyHandled)
        #expect(CoconutWalletService.balance(
            accountKey: CoconutAccountKey.islandReserve,
            context: context
        ) == StarterGiftService.giftAmount)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 1)
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
        context.safeSave()

        let first = StarterGiftService.claimStarterGift(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(first == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))

        defaults.removeObject(forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.pending)
        let recovered = StarterGiftService.claimStarterGift(
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
        #expect(StarterGiftService.shouldShowCeremony(defaults: defaults))
        #expect(!StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))
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

        let first = StarterGiftService.evaluateEligibility(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        let entryCountAfterFirst = try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>())
        let second = StarterGiftService.evaluateEligibility(
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

        let result = StarterGiftService.evaluateEligibility(
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

    @Test func completedLegacyOnboardingWithNoLocalMembersDoesNotStartANewGiftJourney() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let result = StarterGiftService.evaluateEligibility(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(result == .markedExistingUser)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func repeatedConfirmationMintsStarterGiftOnlyOnce() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        context.insert(Pet(name: "Momo", species: "cat"))
        context.safeSave()

        let first = StarterGiftService.claimStarterGift(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        let second = StarterGiftService.claimStarterGift(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(first == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(second == .alreadyHandled)
        #expect(first.completesClaimRequest)
        #expect(second.completesClaimRequest)
        #expect(try context.fetchCount(FetchDescriptor<CareLedgerEvent>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 1)
    }

    @Test func homeProjectionGateUsesTheVisibleBalanceInsteadOfTheWholeWallet() {
        let claimed = StarterGiftHomeProjectionPolicy.expectedVisibleBalance(
            after: .claimed(recipient: .island, amount: StarterGiftService.giftAmount),
            visibleBalanceBeforeRequest: 12,
            existingExpectation: nil
        )
        let retry = StarterGiftHomeProjectionPolicy.expectedVisibleBalance(
            after: .alreadyHandled,
            visibleBalanceBeforeRequest: 12,
            existingExpectation: claimed
        )
        let crashRecovery = StarterGiftHomeProjectionPolicy.expectedVisibleBalance(
            after: .alreadyHandled,
            visibleBalanceBeforeRequest: 62,
            existingExpectation: nil
        )

        #expect(claimed == 62)
        #expect(retry == 62)
        #expect(crashRecovery == 62)
    }

    @Test func failedConfirmationLeavesGiftReadyAndDoesNotUnlockOasis() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(StarterGiftService.beginFreshJourney(context: context, defaults: defaults))
        context.insert(Pet(name: "Momo", species: "cat"))
        context.safeSave()

        let result = StarterGiftService.claimStarterGift(
            activeHumanID: nil,
            context: context,
            defaults: defaults,
            wallet: FailingCoconutWalletManager()
        )

        #expect(result == .persistenceFailed)
        #expect(!result.completesClaimRequest)
        #expect(defaults.bool(forKey: StarterGiftStorageKey.pending))
        #expect(!defaults.bool(forKey: StarterGiftStorageKey.claimed))
        #expect(!StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults))
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)

        let retry = StarterGiftService.claimStarterGift(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )
        #expect(retry == .claimed(recipient: .island, amount: StarterGiftService.giftAmount))
        #expect(try context.fetchCount(FetchDescriptor<CareLedgerEvent>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 1)
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
        let schema = Schema(ArkSchemaV94.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private final class FailingCoconutWalletManager: CoconutWalletManaging {
        enum Failure: Error { case forced }

        func apply(
            deltas _: [CoconutWalletDelta],
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            updatesProjection _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            throw Failure.forced
        }

        func applyActorDelta(
            amount _: Int,
            emoji _: String,
            title _: String,
            actorId _: String?,
            actorName _: String?,
            entryKind _: CoconutWalletEntryKind,
            source _: CoconutWalletSource,
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            throw Failure.forced
        }

        func totalBalance(context _: ModelContext) -> Int { 0 }
        func balance(accountKey _: String, context _: ModelContext, fallback: Int) -> Int { fallback }
        func balance(for human: Human, context _: ModelContext) -> Int { human.coconutBalance }
        func balance(for pet: Pet, context _: ModelContext) -> Int { pet.coconutBalance }
        func legacySystemBalance(context _: ModelContext, fallback: Int) -> Int { fallback }
        func setDeveloperOverrideBalance(amount _: Int, for _: Human?, displayName _: String, context _: ModelContext) {}
        func refreshQuestProjection(context _: ModelContext, manager _: CoconutProjectionManaging?) {}
        func bootstrapIfNeeded(context _: ModelContext, projectionManager _: CoconutProjectionManaging?) throws {}
    }
}
