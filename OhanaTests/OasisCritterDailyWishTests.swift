import Foundation
import SwiftData
import Testing
@testable import Ohana

struct OasisCritterDailyWishTests {
    @Test func critterMilestonesStayReachableWithinCurrentTreeLevels() {
        let levelFive = OasisUpgradeRewardCatalog.rule(for: 5)
        #expect(levelFive.rewardKind != .electronicPet)

        let levelTwo = OasisUpgradeRewardCatalog.rule(for: 2)
        let levelThree = OasisUpgradeRewardCatalog.rule(for: 3)
        #expect(levelThree.coconutAmount > levelTwo.coconutAmount)

        let levelTen = OasisUpgradeRewardCatalog.rule(for: 10)
        #expect(levelTen.rewardKind == .electronicPet)
        #expect(levelTen.guaranteedCritterId == OasisUpgradeRewardCatalog.firstCritterId)
        #expect(OasisUpgradeRewardCatalog.critter(id: OasisUpgradeRewardCatalog.firstCritterId)?.sourceLevel == 10)

        #expect(OasisUpgradeRewardCatalog.critters.allSatisfy { $0.sourceLevel <= TreeLevel.maxSupportedLevel })
    }

    @MainActor
    @Test func completingDailyWishAddsBonusAndMarksWishComplete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = OasisElectronicPet(
            catalogId: OasisUpgradeRewardCatalog.firstCritterId,
            nameZh: "nana",
            nameEn: "nana",
            nameDe: "nana",
            emoji: "🥥",
            rarity: .rare,
            hunger: 30,
            mood: 80,
            sourceLevel: 10
        )
        context.insert(critter)
        try context.save()

        let wish = OasisUpgradeRewardService.dailyWish(for: critter, context: context)
        #expect(wish.action == .feed)
        #expect(!OasisUpgradeRewardService.isDailyWishCompleted(for: critter, wish: wish, context: context))

        let outcome = try OasisUpgradeRewardService.interactWithOutcome(with: critter, action: .feed, context: context)

        #expect(outcome.success)
        #expect(outcome.completedDailyWish)
        #expect(OasisUpgradeRewardService.isDailyWishCompleted(for: critter, wish: wish, context: context))
        #expect(critter.xp == 10)
        #expect(critter.bond == 9)

        let fragments = try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())
        #expect(fragments.first { $0.catalogId == critter.catalogId }?.amount == 1)

        let logs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        #expect(logs.contains { $0.action == .feed })
        #expect(logs.contains { $0.action == .careEcho && $0.fragmentDelta == 1 && $0.xpDelta == 6 })
    }

    @MainActor
    @Test func feedingWhenFullMakesCritterUncomfortableAndSpendsAfterAllowance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter(hunger: 98, mood: 80, health: 80)
        let human = Human(name: "Ava")
        human.coconutBalance = 20
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }
        context.insert(human)
        context.insert(critter)
        context.insert(OasisCritterActionLog(critterId: critter.id, critterCatalogId: critter.catalogId, action: .feed, noteZh: "早饭", noteEn: "Breakfast", noteDe: "Frühstück"))
        try context.save()

        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .feed, context: context) == 5)

        let outcome = try OasisUpgradeRewardService.interactWithOutcome(with: critter, action: .feed, context: context)

        #expect(outcome.success)
        #expect(!outcome.completedDailyWish)
        #expect(outcome.messageZh.contains("吃撑"))
        #expect(critter.hunger == 98)
        #expect(critter.mood == 74)
        #expect(critter.health == 75)
        #expect(critter.bond == 0)
        #expect(critter.xp == 0)
        #expect(human.coconutBalance == 15)

        let logs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        #expect(logs.contains { $0.action == .feed && $0.coconutDelta == -5 && $0.xpDelta == 0 })
    }

    @MainActor
    @Test func careActionsAreFreeOnceThenRequireCoconuts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        let human = Human(name: "Ava")
        human.coconutBalance = 1
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }
        context.insert(human)
        context.insert(critter)
        try context.save()

        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .feed, context: context) == 0)
        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .play, context: context) == 0)
        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .rest, context: context) == 0)

        context.insert(OasisCritterActionLog(critterId: critter.id, critterCatalogId: critter.catalogId, action: .feed, noteZh: "喂过", noteEn: "Fed", noteDe: "Gefüttert"))
        context.insert(OasisCritterActionLog(critterId: critter.id, critterCatalogId: critter.catalogId, action: .play, noteZh: "玩过", noteEn: "Played", noteDe: "Gespielt"))
        context.insert(OasisCritterActionLog(critterId: critter.id, critterCatalogId: critter.catalogId, action: .rest, noteZh: "睡过", noteEn: "Rested", noteDe: "Geruht"))
        try context.save()

        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .feed, context: context) == 5)
        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .play, context: context) == 3)
        #expect(OasisUpgradeRewardService.interactionCost(for: critter, action: .rest, context: context) == 2)
        #expect(!OasisUpgradeRewardService.canInteract(with: critter, action: .feed, context: context))
        #expect(!OasisUpgradeRewardService.canInteract(with: critter, action: .play, context: context))
        #expect(!OasisUpgradeRewardService.canInteract(with: critter, action: .rest, context: context))
    }

    @MainActor
    @Test func repeatedFeedingHasDiminishingReturnsWithoutHarmingCritter() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter(hunger: 40, mood: 80, health: 80)
        let human = Human(name: "Ava")
        human.coconutBalance = 100
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }
        context.insert(human)
        context.insert(critter)
        context.insert(OasisCritterActionLog(critterId: critter.id, critterCatalogId: critter.catalogId, action: .feed, noteZh: "早饭", noteEn: "Breakfast", noteDe: "Frühstück"))
        context.insert(OasisCritterActionLog(critterId: critter.id, critterCatalogId: critter.catalogId, action: .feed, noteZh: "午饭", noteEn: "Lunch", noteDe: "Mittag"))
        try context.save()

        let outcome = try OasisUpgradeRewardService.interactWithOutcome(with: critter, action: .feed, context: context)

        #expect(outcome.success)
        #expect(!outcome.completedDailyWish)
        #expect(outcome.messageZh.contains("小小咬了一口"))
        #expect(critter.hunger == 48)
        #expect(critter.mood == 81)
        #expect(critter.health == 80)
        #expect(critter.bond == 1)
        #expect(critter.xp == 1)
        #expect(human.coconutBalance == 95)
    }

    @MainActor
    @Test func lifecycleDecayIsGentleAndOnlyLaterBecomesAtRisk() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        let critter = makeCritter(lastInteractionAt: twoDaysAgo, lastStateRefreshAt: twoDaysAgo)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)
        #expect(critter.lifeState != .dead)
        #expect(critter.hunger == 56)
        #expect(critter.mood == 72)

        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
        let neglected = makeCritter(lastInteractionAt: sixDaysAgo, lastStateRefreshAt: sixDaysAgo)
        context.insert(neglected)

        OasisUpgradeRewardService.normalizeLifecycle(for: neglected, context: context, now: now)
        #expect(neglected.lifeState == .atRisk)
        #expect(neglected.lifeState != .dead)
        #expect(neglected.riskStartedAt != nil)
    }

    @MainActor
    @Test func lifecycleSettlesInSixHourBlocksWithoutBackgroundTimers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let fiveHoursAgo = Calendar.current.date(byAdding: .hour, value: -5, to: now) ?? now
        let twelveHoursAgo = Calendar.current.date(byAdding: .hour, value: -12, to: now) ?? now

        let unchanged = makeCritter(lastInteractionAt: fiveHoursAgo, lastStateRefreshAt: fiveHoursAgo)
        context.insert(unchanged)
        OasisUpgradeRewardService.normalizeLifecycle(for: unchanged, context: context, now: now)
        #expect(unchanged.hunger == 80)
        #expect(unchanged.mood == 82)

        let settled = makeCritter(lastInteractionAt: twelveHoursAgo, lastStateRefreshAt: twelveHoursAgo)
        context.insert(settled)
        OasisUpgradeRewardService.normalizeLifecycle(for: settled, context: context, now: now)
        #expect(settled.hunger == 74)
        #expect(settled.mood == 82)
        #expect(settled.health == 100)
    }

    @MainActor
    @Test func criticalWindowDoesNotKillBeforeGracePeriod() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 80, health: 50, lastStateRefreshAt: now)
        critter.lifeState = .critical
        critter.riskStartedAt = Calendar.current.date(byAdding: .hour, value: -96, to: now)
        critter.criticalStartedAt = Calendar.current.date(byAdding: .hour, value: -48, to: now)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)

        #expect(critter.lifeState == .critical)
        #expect(critter.diedAt == nil)
    }

    @MainActor
    @Test func criticalWindowKillsWithReasonAfterGracePeriod() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 80, health: 40, lastStateRefreshAt: now)
        critter.lifeState = .critical
        critter.riskStartedAt = Calendar.current.date(byAdding: .hour, value: -168, to: now)
        critter.criticalStartedAt = Calendar.current.date(byAdding: .hour, value: -96, to: now)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)

        #expect(critter.lifeState == .dead)
        #expect(critter.deathReason == .hungry)
        #expect(critter.diedAt != nil)
    }

    @MainActor
    @Test func oldAgeDeathIsArchivedAsMemorialState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let obtainedAt = Calendar.current.date(byAdding: .day, value: -211, to: now) ?? now
        let critter = makeCritter(obtainedAt: obtainedAt, lastStateRefreshAt: now)
        critter.isFeaturedOnOasis = true
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)

        #expect(critter.lifeState == .dead)
        #expect(critter.deathReason == .oldAge)
        #expect(!critter.isFeaturedOnOasis)
    }

    @MainActor
    @Test func rescueClearsRiskAndRecordsLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 12, health: 32, lastStateRefreshAt: now)
        critter.lifeState = .critical
        critter.riskStartedAt = Calendar.current.date(byAdding: .hour, value: -96, to: now)
        critter.criticalStartedAt = Calendar.current.date(byAdding: .hour, value: -24, to: now)
        context.insert(critter)

        let outcome = try OasisUpgradeRewardService.rescueIfNeeded(for: critter, context: context, now: now)

        #expect(outcome.success)
        #expect(critter.lifeState == .healthy)
        #expect(critter.hunger >= 58)
        #expect(critter.mood >= 58)
        #expect(critter.health >= 74)
        let logs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        #expect(logs.contains { $0.action == .rescue && $0.xpDelta == 3 })
    }

    @MainActor
    @Test func critterLevelRequiresThreeHundredXPAndCapsAtFinalForm() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        critter.xp = OasisUpgradeRewardService.critterXPPerLevel - 1
        context.insert(critter)

        #expect(!OasisUpgradeRewardService.canUpgradeLevel(for: critter))

        critter.xp = OasisUpgradeRewardService.critterXPPerLevel
        #expect(try OasisUpgradeRewardService.upgradeLevel(for: critter, context: context))
        #expect(critter.level == 2)
        #expect(critter.xp == 0)
        #expect(critter.appearanceStage == 1)

        critter.level = OasisUpgradeRewardService.maxCritterLevel
        critter.xp = OasisUpgradeRewardService.critterXPPerLevel
        #expect(!OasisUpgradeRewardService.canUpgradeLevel(for: critter))
        #expect(!((try? OasisUpgradeRewardService.upgradeLevel(for: critter, context: context)) ?? true))
        #expect(critter.level == OasisUpgradeRewardService.maxCritterLevel)
    }

    @MainActor
    @Test func critterEvolutionStagesFollowLevelThresholds() {
        #expect(OasisUpgradeRewardService.appearanceStage(forLevel: 1) == 1)
        #expect(OasisUpgradeRewardService.appearanceStage(forLevel: 3) == 2)
        #expect(OasisUpgradeRewardService.appearanceStage(forLevel: 6) == 3)
        #expect(OasisUpgradeRewardService.appearanceStage(forLevel: 9) == 4)
        #expect(OasisUpgradeRewardService.appearanceStage(forLevel: 12) == 5)
    }

    @MainActor
    @Test func starUpgradeCanStillReachAppearanceStageFive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        critter.level = OasisUpgradeRewardService.maxCritterLevel
        critter.starLevel = 4
        critter.appearanceStage = 4
        context.insert(critter)
        context.insert(OasisCritterFragmentBalance(catalogId: critter.catalogId, amount: 400))
        let human = Human(name: "Ava")
        human.coconutBalance = 1000
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        context.insert(human)

        #expect(try OasisUpgradeRewardService.upgradeStar(for: critter, context: context))
        #expect(critter.appearanceStage == 5)
    }

    @MainActor
    @Test func starUpgradeStagesSpendAndRefreshesProjectionAfterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        let balance = OasisCritterFragmentBalance(catalogId: critter.catalogId, amount: 40)
        let human = Human(name: "Ava")
        human.coconutBalance = 120
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        context.insert(critter)
        context.insert(balance)
        context.insert(human)
        try context.save()
        let wallet = ProjectionSpyWallet()
        let questManager = QuestManager(wallet: wallet)

        #expect(try OasisUpgradeRewardService.upgradeStar(
            for: critter,
            context: context,
            wallet: wallet,
            questManager: questManager
        ))

        #expect(wallet.applyUpdatesProjection == [false])
        #expect(wallet.refreshCount == 1)
        #expect(critter.starLevel == 2)
        #expect(balance.amount == 0)
        #expect(CoconutWalletService.balance(for: human, context: context) == 40)
    }

    @MainActor
    @Test func fragmentAwakenStagesSpendAndRefreshesProjectionAfterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let entry = try #require(OasisUpgradeRewardCatalog.critter(id: OasisUpgradeRewardCatalog.firstCritterId))
        let cost = OasisUpgradeRewardService.awakeningCost(for: entry.rarity)
        let balance = OasisCritterFragmentBalance(catalogId: entry.id, amount: cost.fragments)
        let human = Human(name: "Ava")
        human.coconutBalance = cost.coconuts + 15
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldInjectedEnergy = defaults.object(forKey: "oasis_injectedEnergy")
        let oldLastRewardedLevel = defaults.object(forKey: "oasis_lastRewardedLevel")
        let oldTreeManager = OasisTreeManagerRegistry.current
        let treeManager = OasisTreeManager()
        OasisTreeManagerRegistry.current = treeManager
        treeManager.injectedEnergy = 3600
        defer {
            OasisTreeManagerRegistry.current = oldTreeManager
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldInjectedEnergy {
                defaults.set(oldInjectedEnergy, forKey: "oasis_injectedEnergy")
            } else {
                defaults.removeObject(forKey: "oasis_injectedEnergy")
            }
            if let oldLastRewardedLevel {
                defaults.set(oldLastRewardedLevel, forKey: "oasis_lastRewardedLevel")
            } else {
                defaults.removeObject(forKey: "oasis_lastRewardedLevel")
            }
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        context.insert(balance)
        context.insert(human)
        try context.save()
        let wallet = ProjectionSpyWallet()
        let questManager = QuestManager(wallet: wallet)

        let awakened = try OasisUpgradeRewardService.awakenWithFragments(
            catalogId: entry.id,
            context: context,
            wallet: wallet,
            questManager: questManager
        )
        let critter = try #require(awakened)

        #expect(wallet.applyUpdatesProjection == [false])
        #expect(wallet.refreshCount == 1)
        #expect(critter.catalogId == entry.id)
        #expect(balance.amount == 0)
        #expect(CoconutWalletService.balance(for: human, context: context) == 15)
    }

    @MainActor
    @Test func displayDailyWishDoesNotMutateLifecycleDuringRendering() throws {
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 12, health: 32, lastStateRefreshAt: now)
        critter.lifeState = .critical
        critter.riskStartedAt = Calendar.current.date(byAdding: .hour, value: -96, to: now)
        critter.criticalStartedAt = Calendar.current.date(byAdding: .hour, value: -24, to: now)

        let beforeRefresh = critter.lastStateRefreshAt
        let snapshot = OasisUpgradeRewardService.lifecycleSnapshot(for: critter, now: now)
        let wish = OasisUpgradeRewardService.displayDailyWish(for: critter, snapshot: snapshot, now: now)

        #expect(wish.action == .rescue)
        #expect(critter.lifeState == .critical)
        #expect(critter.lastStateRefreshAt == beforeRefresh)
        #expect(critter.hunger == 0)
        #expect(critter.mood == 12)
        #expect(critter.health == 32)
    }

    @MainActor
    @Test func careEchoImprovesHealthAndDoesNotReviveDeadCritter() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let live = makeCritter(health: 50)
        live.isFeaturedOnOasis = true
        context.insert(live)

        OasisUpgradeRewardService.rewardFeaturedCritterFromCare(type: .health, context: context)
        #expect(live.health > 50)
        #expect(live.lifeState != .dead)

        live.isFeaturedOnOasis = false
        let dead = makeCritter(health: 0)
        dead.isFeaturedOnOasis = true
        dead.lifeState = .dead
        dead.deathReason = .sick
        context.insert(dead)
        try context.save()

        OasisUpgradeRewardService.rewardFeaturedCritterFromCare(type: .health, context: context)
        #expect(dead.lifeState == .dead)
        #expect(dead.health == 0)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeCritter(
        hunger: Int = 80,
        mood: Int = 82,
        health: Int = 100,
        obtainedAt: Date = Date(),
        lastInteractionAt: Date = Date(),
        lastStateRefreshAt: Date = Date()
    ) -> OasisElectronicPet {
        OasisElectronicPet(
            catalogId: OasisUpgradeRewardCatalog.firstCritterId,
            nameZh: "nana",
            nameEn: "nana",
            nameDe: "nana",
            emoji: "🥥",
            rarity: .rare,
            hunger: hunger,
            mood: mood,
            health: health,
            sourceLevel: 10,
            obtainedAt: obtainedAt,
            lastInteractionAt: lastInteractionAt,
            lastStateRefreshAt: lastStateRefreshAt
        )
    }

    @MainActor
    private final class ProjectionSpyWallet: CoconutWalletManaging {
        private let wrapped = SwiftDataCoconutWalletManager()
        var applyUpdatesProjection: [Bool] = []
        var refreshCount = 0

        func apply(
            deltas: [CoconutWalletDelta],
            context: ModelContext,
            save: Bool,
            postsRewardFeedback: Bool,
            updatesProjection: Bool,
            projectionManager: QuestManager?
        ) throws -> [CoconutLedgerEntry] {
            applyUpdatesProjection.append(updatesProjection)
            return try wrapped.apply(
                deltas: deltas,
                context: context,
                save: save,
                postsRewardFeedback: postsRewardFeedback,
                updatesProjection: updatesProjection,
                projectionManager: projectionManager
            )
        }

        func applyActorDelta(
            amount: Int,
            emoji: String,
            title: String,
            actorId: String?,
            actorName: String?,
            entryKind: CoconutWalletEntryKind,
            source: CoconutWalletSource,
            context: ModelContext,
            save: Bool,
            postsRewardFeedback: Bool,
            projectionManager: QuestManager?
        ) throws -> [CoconutLedgerEntry] {
            try wrapped.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
                entryKind: entryKind,
                source: source,
                context: context,
                save: save,
                postsRewardFeedback: postsRewardFeedback,
                projectionManager: projectionManager
            )
        }

        func totalBalance(context: ModelContext) -> Int {
            wrapped.totalBalance(context: context)
        }

        func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int {
            wrapped.balance(accountKey: accountKey, context: context, fallback: fallback)
        }

        func balance(for human: Human, context: ModelContext) -> Int {
            wrapped.balance(for: human, context: context)
        }

        func balance(for pet: Pet, context: ModelContext) -> Int {
            wrapped.balance(for: pet, context: context)
        }

        func legacySystemBalance(context: ModelContext, fallback: Int) -> Int {
            wrapped.legacySystemBalance(context: context, fallback: fallback)
        }

        func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext) {
            wrapped.setDeveloperOverrideBalance(
                amount: amount,
                for: human,
                displayName: displayName,
                context: context
            )
        }

        func refreshQuestProjection(context: ModelContext, manager: QuestManager?) {
            refreshCount += 1
            wrapped.refreshQuestProjection(context: context, manager: manager)
        }

        func bootstrapIfNeeded(context: ModelContext, projectionManager: QuestManager?) throws {
            try wrapped.bootstrapIfNeeded(context: context, projectionManager: projectionManager)
        }
    }
}
