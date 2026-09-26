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

    @Test func everyCompanionUsesDeterministicFiveStageAssetNames() {
        for entry in OasisUpgradeRewardCatalog.critters {
            for stage in 1 ... 5 {
                let candidates = OasisCritterAssetResolver.assetCandidates(
                    catalogID: entry.id,
                    stage: stage
                )
                #expect(candidates.first == "\(entry.assetName)\(OasisCritterAssetResolver.stageSuffixes[stage - 1])")
                #expect(candidates.last == "CritterLumoBaby")
            }
        }
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
        let human = Human(name: "Ava")
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }
        context.insert(human)
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
    @Test func lifecycleNeverDecaysWhileAppIsClosed() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        let critter = makeCritter(lastInteractionAt: twoDaysAgo, lastStateRefreshAt: twoDaysAgo)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)
        #expect(critter.lifeState == .healthy)
        #expect(critter.hunger == 80)
        #expect(critter.mood == 82)

        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
        let neglected = makeCritter(lastInteractionAt: sixDaysAgo, lastStateRefreshAt: sixDaysAgo)
        context.insert(neglected)

        OasisUpgradeRewardService.normalizeLifecycle(for: neglected, context: context, now: now)
        #expect(neglected.lifeState == .healthy)
        #expect(neglected.hunger == 80)
        #expect(neglected.mood == 82)
        #expect(neglected.riskStartedAt == nil)
    }

    @MainActor
    @Test func lifecycleRefreshDoesNotApplyElapsedTimeTicks() throws {
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
        #expect(settled.hunger == 80)
        #expect(settled.mood == 82)
        #expect(settled.health == 100)
    }

    @MainActor
    @Test func legacyCriticalStateBecomesSleepingImmediately() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 80, health: 50, lastStateRefreshAt: now)
        critter.lifeState = .critical
        critter.riskStartedAt = Calendar.current.date(byAdding: .hour, value: -96, to: now)
        critter.criticalStartedAt = Calendar.current.date(byAdding: .hour, value: -48, to: now)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)

        #expect(critter.lifeState == .sleeping)
        #expect(critter.diedAt == nil)
        #expect(critter.riskStartedAt == nil)
        #expect(critter.criticalStartedAt == nil)
    }

    @MainActor
    @Test func legacyCriticalStateNeverCreatesDeathFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 80, health: 40, lastStateRefreshAt: now)
        critter.lifeState = .critical
        critter.riskStartedAt = Calendar.current.date(byAdding: .hour, value: -168, to: now)
        critter.criticalStartedAt = Calendar.current.date(byAdding: .hour, value: -96, to: now)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)

        #expect(critter.lifeState == .sleeping)
        #expect(critter.deathReason == nil)
        #expect(critter.diedAt == nil)
        let logs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        #expect(!logs.contains { $0.action == .death })
    }

    @MainActor
    @Test func legacyDeadStateKeepsProgressWhenConvertedToSleeping() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let obtainedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let critter = makeCritter(obtainedAt: obtainedAt)
        critter.level = 9
        critter.starLevel = 4
        critter.xp = 211
        critter.bond = 573
        critter.lifeState = .dead
        critter.deathReason = .oldAge
        critter.riskStartedAt = Date(timeIntervalSince1970: 1_800_000_000)
        critter.criticalStartedAt = Date(timeIntervalSince1970: 1_800_003_600)
        critter.diedAt = Date(timeIntervalSince1970: 1_800_007_200)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context)

        #expect(critter.lifeState == .sleeping)
        #expect(critter.level == 9)
        #expect(critter.starLevel == 4)
        #expect(critter.xp == 211)
        #expect(critter.bond == 573)
        #expect(critter.obtainedAt == obtainedAt)
        #expect(critter.deathReason == nil)
        #expect(critter.riskStartedAt == nil)
        #expect(critter.criticalStartedAt == nil)
        #expect(critter.diedAt == nil)
    }

    @MainActor
    @Test func backupRehydrateNormalizesLegacyDeathStateInsideRestoreTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let id = UUID()
        let obtainedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let result = try DomainGeneralRehydrateWriter.insertOasisElectronicPetIfNeeded(
            snapshot: DomainOasisElectronicPetRehydrateSnapshot(
                id: id,
                catalogId: "critter_moss_bun",
                nameZh: "苔团",
                nameEn: "Moss Bun",
                nameDe: "Moosknäuel",
                emoji: "🌿",
                rarityRaw: OasisElectronicPetRarity.rare.rawValue,
                nickname: "Bun",
                level: 9,
                starLevel: 4,
                xp: 211,
                hunger: 12,
                mood: 18,
                health: 4,
                bond: 573,
                appearanceStage: 5,
                isFeaturedOnOasis: true,
                habitatSlot: 2,
                equippedDecorId: "fern",
                favoriteItemId: "berry",
                personalityRaw: "gentle",
                featuredPoseRaw: "resting",
                sourceLevel: 10,
                obtainedAt: obtainedAt,
                lastInteractionAt: obtainedAt,
                lastStateRefreshAt: obtainedAt,
                lifeStateRaw: OasisCritterLifeState.dead.rawValue,
                deathReasonRaw: OasisCritterDeathReason.oldAge.rawValue,
                riskStartedAt: obtainedAt,
                criticalStartedAt: obtainedAt,
                diedAt: obtainedAt,
                lastGentlePromptAt: obtainedAt,
                isArchived: false
            ),
            source: .backupRestore,
            context: context
        )

        let critter = try #require(result.model)
        #expect(result.inserted)
        #expect(critter.id == id)
        #expect(critter.lifeState == .sleeping)
        #expect(!critter.isFeaturedOnOasis)
        #expect(critter.level == 9)
        #expect(critter.starLevel == 4)
        #expect(critter.xp == 211)
        #expect(critter.bond == 573)
        #expect(critter.obtainedAt == obtainedAt)
        #expect(critter.deathReason == nil)
        #expect(critter.riskStartedAt == nil)
        #expect(critter.criticalStartedAt == nil)
        #expect(critter.diedAt == nil)
        #expect(critter.lastGentlePromptAt == nil)
    }

    @MainActor
    @Test func lifecycleCompatibilityMaintenanceIsBoundedAndIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = makeCritter(obtainedAt: Date(timeIntervalSince1970: 1_700_000_000))
        first.lifeState = .dead
        first.deathReason = .oldAge
        let second = makeCritter(obtainedAt: Date(timeIntervalSince1970: 1_700_000_100))
        second.lifeState = .atRisk
        second.riskStartedAt = Date(timeIntervalSince1970: 1_700_000_200)
        context.insert(first)
        context.insert(second)
        try context.save()

        let firstBatch = try OasisCompanionLifecycleCompatibilityService.reconcile(
            context: context,
            maximumCount: 1
        )
        #expect(firstBatch.inspectedCount == 1)
        #expect(firstBatch.repairedCount == 1)
        #expect(firstBatch.hasMoreWork)
        #expect(first.lifeState == .sleeping)
        #expect(second.lifeState == .atRisk)

        let secondBatch = try OasisCompanionLifecycleCompatibilityService.reconcile(
            context: context,
            maximumCount: 1
        )
        #expect(secondBatch.inspectedCount == 1)
        #expect(secondBatch.repairedCount == 1)
        #expect(!secondBatch.hasMoreWork)
        #expect(second.lifeState == .healthy)
        #expect(second.riskStartedAt == nil)

        let idempotentPass = try OasisCompanionLifecycleCompatibilityService.reconcile(
            context: context,
            maximumCount: 1
        )
        #expect(idempotentPass.inspectedCount == 0)
        #expect(idempotentPass.repairedCount == 0)
        #expect(!idempotentPass.hasMoreWork)
    }

    @MainActor
    @Test func companionAgeNeverChangesLifecycleOrHomeSelection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let obtainedAt = Calendar.current.date(byAdding: .day, value: -211, to: now) ?? now
        let critter = makeCritter(obtainedAt: obtainedAt, lastStateRefreshAt: now)
        critter.isFeaturedOnOasis = true
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)

        #expect(critter.lifeState == .healthy)
        #expect(critter.deathReason == nil)
        #expect(critter.isFeaturedOnOasis)
    }

    @MainActor
    @Test func rememberedRestingCritterCanBeRescued() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let critter = makeCritter(hunger: 0, mood: 0, health: 0, lastStateRefreshAt: now)
        critter.lifeState = .dead
        critter.deathReason = .hungry
        critter.diedAt = Calendar.current.date(byAdding: .day, value: -1, to: now)
        context.insert(critter)

        let outcome = try OasisUpgradeRewardService.rescueIfNeeded(for: critter, context: context, now: now)

        #expect(outcome.success)
        #expect(critter.lifeState == .healthy)
        #expect(critter.deathReason == nil)
        #expect(critter.diedAt == nil)
        #expect(critter.hunger == 80)
        #expect(critter.mood == 80)
        #expect(critter.health == 100)
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
        #expect(critter.hunger == 80)
        #expect(critter.mood == 80)
        #expect(critter.health == 100)
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
    @Test func companionGrowthCostsMatchFiveStarEconomy() {
        #expect(OasisUpgradeRewardService.awakeningCost(for: .common) == (120, 80))
        #expect(OasisUpgradeRewardService.awakeningCost(for: .rare) == (160, 120))
        #expect(OasisUpgradeRewardService.awakeningCost(for: .epic) == (240, 180))
        #expect(OasisUpgradeRewardService.awakeningCost(for: .legendary) == (360, 300))

        let critter = makeCritter()
        critter.starLevel = 1
        #expect(OasisUpgradeRewardService.starUpgradeCost(for: critter) == (40, 40))
        critter.starLevel = 2
        #expect(OasisUpgradeRewardService.starUpgradeCost(for: critter) == (60, 80))
        critter.starLevel = 3
        #expect(OasisUpgradeRewardService.starUpgradeCost(for: critter) == (80, 120))
        critter.starLevel = 4
        #expect(OasisUpgradeRewardService.starUpgradeCost(for: critter) == (120, 160))
        critter.starLevel = 5
        #expect(OasisUpgradeRewardService.starUpgradeCost(for: critter) == (0, 0))
    }

    @MainActor
    @Test func starUpgradeUsesSpecificFragmentsBeforeUniversalStardust() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        let specific = OasisCritterFragmentBalance(catalogId: critter.catalogId, amount: 10)
        let stardust = OasisCritterFragmentBalance(
            catalogId: OasisCompanionCurrency.stardustCatalogID,
            amount: 30
        )
        let human = Human(name: "Ava")
        human.coconutBalance = 40
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
        context.insert(specific)
        context.insert(stardust)
        context.insert(human)
        try context.save()
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            legacyIslandCount: human.coconutBalance,
            legacyLogsJSON: "[]"
        )

        let availability = OasisUpgradeRewardService.starUpgradeAvailability(
            for: critter,
            context: context
        )
        #expect(availability.isAvailable)
        #expect(availability.fundingPlan.specificFragmentsUsed == 10)
        #expect(availability.fundingPlan.stardustUsed == 30)

        #expect(try OasisUpgradeRewardService.upgradeStar(for: critter, context: context))
        #expect(critter.starLevel == 2)
        #expect(specific.amount == 0)
        #expect(stardust.amount == 0)
        #expect(CoconutWalletService.balance(for: human, context: context) == 0)

        let log = try #require(
            context.fetch(FetchDescriptor<OasisCritterActionLog>())
                .first(where: { $0.action == .starUpgrade })
        )
        #expect(log.noteZh.contains("10◇ + 30✦"))
    }

    @MainActor
    @Test func fiveStarCompanionCannotBeChargedAgain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        critter.starLevel = OasisCompanionCurrency.maxStarLevel
        let fragments = OasisCritterFragmentBalance(catalogId: critter.catalogId, amount: 999)
        let human = Human(name: "Ava")
        human.coconutBalance = 999
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }
        context.insert(critter)
        context.insert(fragments)
        context.insert(human)
        try context.save()

        let availability = OasisUpgradeRewardService.starUpgradeAvailability(
            for: critter,
            context: context
        )
        #expect(availability.reason == .maxStars)
        #expect(!(try OasisUpgradeRewardService.upgradeStar(for: critter, context: context)))
        #expect(critter.starLevel == OasisCompanionCurrency.maxStarLevel)
        #expect(fragments.amount == 999)
    }

    @MainActor
    @Test func insufficientGrowthCurrencyLeavesAllBalancesUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let critter = makeCritter()
        let specific = OasisCritterFragmentBalance(catalogId: critter.catalogId, amount: 9)
        let stardust = OasisCritterFragmentBalance(
            catalogId: OasisCompanionCurrency.stardustCatalogID,
            amount: 29
        )
        let human = Human(name: "Ava")
        human.coconutBalance = 40
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }
        context.insert(critter)
        context.insert(specific)
        context.insert(stardust)
        context.insert(human)
        try context.save()

        let availability = OasisUpgradeRewardService.starUpgradeAvailability(
            for: critter,
            context: context
        )
        #expect(availability.reason == .insufficientGrowthCurrency)
        #expect(!(try OasisUpgradeRewardService.upgradeStar(for: critter, context: context)))
        #expect(critter.starLevel == 1)
        #expect(specific.amount == 9)
        #expect(stardust.amount == 29)
        #expect(human.coconutBalance == 40)
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
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            legacyIslandCount: human.coconutBalance,
            legacyLogsJSON: "[]"
        )
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
        #expect(CoconutWalletService.balance(for: human, context: context) == 80)
    }

    @MainActor
    @Test func fragmentAwakenStagesSpendAndRefreshesProjectionAfterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let entry = try #require(OasisUpgradeRewardCatalog.critter(id: OasisUpgradeRewardCatalog.mossBunId))
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
        treeManager.setEnergyForTesting(injectedEnergy: 3600)
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
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            legacyIslandCount: human.coconutBalance,
            legacyLogsJSON: "[]"
        )
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
        #expect(dead.lifeState == .sleeping)
        #expect(dead.health == 0)
    }

    @MainActor
    @Test func oasisEconomyDoesNotFallBackToLegacySystemWalletWithoutActiveHuman() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let legacy = CoconutAccount(
            accountKey: CoconutAccountKey.legacySystem,
            ownerKind: .system,
            ownerId: "legacy",
            displayName: "Legacy",
            balance: 99
        )
        context.insert(legacy)
        try context.save()

        let selection = StubActiveHumanSelection(currentHumanId: nil)
        let questManager = QuestManager()

        #expect(OasisCritterEconomyService.currentHumanBalance(
            context: context,
            activeHumanSelection: selection,
            questManager: questManager
        ) == 0)
        #expect(!OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
            1,
            context: context,
            activeHumanSelection: selection,
            questManager: questManager
        ))
        #expect(!OasisCritterEconomyService.spendCurrentHumanCoconuts(
            1,
            emoji: "✨",
            title: "No active human",
            context: context,
            activeHumanSelection: selection,
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        ))
        #expect(OasisCritterEconomyService.awardBudgetedCurrentHumanCoconuts(
            1,
            emoji: "🥥",
            title: "No active human reward",
            context: context,
            postsRewardFeedback: false,
            activeHumanSelection: selection,
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager,
            date: Date(timeIntervalSince1970: 1_802_000_000)
        ) == nil)
        #expect(OasisCritterEconomyService.awardSpecialCurrentHumanCoconuts(
            1,
            emoji: "🥥",
            title: "No active special reward",
            sourceModelName: "Test",
            sourceModelId: "no-active-human",
            transactionKey: "test:no-active-human",
            context: context,
            postsRewardFeedback: false,
            activeHumanSelection: selection,
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        ) == nil)
        #expect(legacy.balance == 99)
    }

    @MainActor
    @Test func repeatedOasisRewardsUseBudgetAndCooldown() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let selection = StubActiveHumanSelection(currentHumanId: human.id.uuidString)
        let date = Date(timeIntervalSince1970: 1_802_000_000)
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let oldCooldown = UserDefaults.standard.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let oldCooldown {
                UserDefaults.standard.set(oldCooldown, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            EconomyDailyBudgetStore.reset(
                householdKey: householdKey,
                memberKey: human.id.uuidString,
                date: date
            )
        }
        UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        context.insert(human)
        try context.save()
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: human.id.uuidString,
            date: date
        )

        let questManager = QuestManager()
        let first = OasisCritterEconomyService.awardBudgetedCurrentHumanCoconuts(
            1,
            emoji: "📅",
            title: "Oasis daily check-in",
            context: context,
            postsRewardFeedback: false,
            activeHumanSelection: selection,
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager,
            date: date
        )
        let second = OasisCritterEconomyService.awardBudgetedCurrentHumanCoconuts(
            1,
            emoji: "📅",
            title: "Oasis daily check-in",
            context: context,
            postsRewardFeedback: false,
            activeHumanSelection: selection,
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager,
            date: date.addingTimeInterval(60)
        )

        #expect(first == 1)
        #expect(second == 0)
        #expect(CoconutWalletService.balance(for: human, context: context) == 1)

        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        #expect(budgetEvents.contains { $0.actionKey.contains("Oasis daily") && $0.coconutUsed == 1 })
        #expect(budgetEvents.contains { $0.actionKey.contains("Oasis daily") && $0.coconutUsed == 0 })
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
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
    private struct StubActiveHumanSelection: ActiveHumanSelecting {
        let currentHumanId: String?

        var currentHumanIdRaw: String {
            currentHumanId ?? ""
        }
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
            projectionManager: CoconutProjectionManaging?
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
            projectionManager: CoconutProjectionManaging?
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

        func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging?) {
            refreshCount += 1
            wrapped.refreshQuestProjection(context: context, manager: manager)
        }

        func bootstrapIfNeeded(context: ModelContext, projectionManager: CoconutProjectionManaging?) throws {
            try wrapped.bootstrapIfNeeded(context: context, projectionManager: projectionManager)
        }
    }
}
