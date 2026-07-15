import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct JourneyCompatibilityTests {
    @Test func legacyWelcomeMilestonesPersistFlagsWithoutMintingRewards() throws {
        let defaults = UserDefaults.standard
        let originalFirstMeal = defaults.object(forKey: QuestManager.Keys.firstMeal)
        let originalThemeColor = defaults.object(forKey: QuestManager.Keys.themeColor)
        defer {
            restore(originalFirstMeal, forKey: QuestManager.Keys.firstMeal, in: defaults)
            restore(originalThemeColor, forKey: QuestManager.Keys.themeColor, in: defaults)
        }
        defaults.set(false, forKey: QuestManager.Keys.firstMeal)
        defaults.set(false, forKey: QuestManager.Keys.themeColor)

        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let historicalEntry = CoconutLedgerEntry(
            transactionKey: "historical:welcome:firstMeal",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            delta: 15,
            balanceBefore: 0,
            balanceAfter: 15,
            entryKind: .reward,
            source: .service,
            title: "Historical reward",
            emoji: "🥥"
        )
        context.insert(human)
        context.insert(historicalEntry)
        try context.save()

        let wallet = RecordingWallet()
        let manager = QuestManager(wallet: wallet, revisions: SharedDomainRevisionPublisher())

        manager.recordFirstMeal(
            actorId: human.id.uuidString,
            actorName: human.name,
            context: context
        )
        manager.recordThemeColorSet(
            actorId: human.id.uuidString,
            actorName: human.name,
            context: context
        )

        #expect(manager.isFirstMealRecorded)
        #expect(manager.isThemeColorSet)
        #expect(defaults.bool(forKey: QuestManager.Keys.firstMeal))
        #expect(defaults.bool(forKey: QuestManager.Keys.themeColor))
        #expect(wallet.applyCallCount == 0)
        #expect(wallet.applyActorDeltaCallCount == 0)

        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(entries.map(\.id) == [historicalEntry.id])
    }

    @Test func vaccineAchievementRecognizesCanonicalHealthLogRawValue() {
        let pet = Pet(name: "Momo", species: "cat")
        let vaccineEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: HealthLogType.vaccine.rawValue
        )

        let achievements = AchievementManager.compute(
            for: pet,
            context: AchievementComputationContext(careLedgerEvents: [vaccineEvent])
        )

        #expect(achievements.first { $0.id == "vaccine_keeper" }?.isUnlocked == true)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV91.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func restore(_ value: Any?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private final class RecordingWallet: CoconutWalletManaging {
        var applyCallCount = 0
        var applyActorDeltaCallCount = 0

        func apply(
            deltas _: [CoconutWalletDelta],
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            updatesProjection _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            applyCallCount += 1
            return []
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
            applyActorDeltaCallCount += 1
            return []
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
