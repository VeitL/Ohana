import Foundation
import SwiftData
import Testing
@testable import Ohana

struct OasisCritterDailyWishTests {
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
            sourceLevel: 5
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
        #expect(critter.xp == 24)
        #expect(critter.bond == 9)

        let fragments = try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())
        #expect(fragments.first { $0.catalogId == critter.catalogId }?.amount == 1)

        let logs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        #expect(logs.contains { $0.action == .feed })
        #expect(logs.contains { $0.action == .careEcho && $0.fragmentDelta == 1 && $0.xpDelta == 14 })
    }

    @MainActor
    @Test func lifecycleDecayIsGentleAndOnlyLaterBecomesAtRisk() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        let critter = makeCritter(lastStateRefreshAt: twoDaysAgo)
        context.insert(critter)

        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context, now: now)
        #expect(critter.lifeState != .dead)
        #expect(critter.hunger == 52)
        #expect(critter.mood == 62)

        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
        let neglected = makeCritter(lastStateRefreshAt: sixDaysAgo)
        context.insert(neglected)

        OasisUpgradeRewardService.normalizeLifecycle(for: neglected, context: context, now: now)
        #expect(neglected.lifeState == .atRisk)
        #expect(neglected.lifeState != .dead)
        #expect(neglected.riskStartedAt != nil)
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
        #expect(logs.contains { $0.action == .rescue && $0.xpDelta == 8 })
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
        let schema = Schema(ArkSchemaV55.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeCritter(
        hunger: Int = 80,
        mood: Int = 82,
        health: Int = 100,
        obtainedAt: Date = Date(),
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
            sourceLevel: 5,
            obtainedAt: obtainedAt,
            lastStateRefreshAt: lastStateRefreshAt
        )
    }
}
