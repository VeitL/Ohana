import Combine
import Foundation
import SwiftData

struct OasisRewardLiveDataSnapshot {
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var upgradeCoconuts: [OasisUpgradeCoconut] = []
    var electronicPets: [OasisElectronicPet] = []
    var critterFragments: [OasisCritterFragmentBalance] = []
}

@MainActor
final class OasisRewardLiveDataStore: ObservableObject {
    @Published private(set) var snapshot = OasisRewardLiveDataSnapshot()

    func refresh(context: ModelContext) {
        snapshot = Self.fetchSnapshot(context: context)
    }

    func reset() {
        snapshot = OasisRewardLiveDataSnapshot()
    }

    private static func fetchSnapshot(context: ModelContext) -> OasisRewardLiveDataSnapshot {
        OasisRewardLiveDataSnapshot(
            pets: fetchPets(context: context),
            humans: fetchHumans(context: context),
            plants: AppFeatureRouteGuard.shouldLoadPlantData ? fetchPlants(context: context) : [],
            upgradeCoconuts: fetchUpgradeCoconuts(context: context),
            electronicPets: fetchElectronicPets(context: context),
            critterFragments: fetchCritterFragments(context: context)
        )
    }

    private static func fetchPets(context: ModelContext) -> [Pet] {
        var descriptor = FetchDescriptor<Pet>(
            sortBy: [SortDescriptor(\Pet.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchHumans(context: ModelContext) -> [Human] {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 40
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchPlants(context: ModelContext) -> [Plant] {
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\Plant.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 60
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchUpgradeCoconuts(context: ModelContext) -> [OasisUpgradeCoconut] {
        var descriptor = FetchDescriptor<OasisUpgradeCoconut>(
            sortBy: [SortDescriptor(\OasisUpgradeCoconut.level, order: .forward)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchElectronicPets(context: ModelContext) -> [OasisElectronicPet] {
        var descriptor = FetchDescriptor<OasisElectronicPet>(
            sortBy: [SortDescriptor(\OasisElectronicPet.obtainedAt, order: .forward)]
        )
        descriptor.fetchLimit = 48
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchCritterFragments(context: ModelContext) -> [OasisCritterFragmentBalance] {
        var descriptor = FetchDescriptor<OasisCritterFragmentBalance>(
            sortBy: [SortDescriptor(\OasisCritterFragmentBalance.updatedAt, order: .forward)]
        )
        descriptor.fetchLimit = 120
        return (try? context.fetch(descriptor)) ?? []
    }
}

struct OasisBentoSnapshot: Equatable {
    var shopMetric: String = "—"
    var achievementMetric: String = "—"
    var achievementsLocked: Bool = true
    var critterMetric: String = "—"
}

struct OasisRewardActionSnapshot: Equatable {
    var canInjectCoconuts: Bool?
    var activeCoconutBalance: Int = 0
    var critterFragmentTotal: Int = 0
}

struct OasisCheckInSnapshot: Equatable {
    var checkedInDates: Set<String>
    var makeupDates: Set<String>
    var makeupPackCount: Int
    var lastClaimedMilestone: Int
}

struct OasisCritterRenderSnapshot: Equatable {
    var lifecycle: OasisCritterLifecycleSnapshot
    var dailyWish: OasisCritterDailyWish?
    var isDailyWishCompleted: Bool
    var prompt: AppLocalizedText
    var displayLevel: Int
    var appearanceStage: Int
    var maxLevel: Int
    var bondLevel: Int
    var bondProgress: Int
    var xpProgress: Int
    var xpPercent: Int
    var xpTarget: Int
    var todayInteractionCount: Int
    var canUpgradeLevel: Bool
    var xpNeededForNextLevel: Int
    var canFeed: Bool
    var canPlay: Bool
    var canRest: Bool
    var feedCost: Int
    var playCost: Int
    var restCost: Int
    var starFragmentsCost: Int
    var starCoconutsCost: Int
    var canUpgradeStar: Bool

    @MainActor
    static func lightweight(
        for critter: OasisElectronicPet,
        rewards: OasisRewardManaging
    ) -> OasisCritterRenderSnapshot {
        let lifecycle = OasisCritterLifecycleSnapshot(
            state: critter.lifeState,
            deathReason: critter.deathReason,
            recommendedAction: nil,
            isRescuable: critter.lifeState == .critical || critter.lifeState == .sick,
            hoursUntilDeath: nil,
            ageDays: max(0, Calendar.current.dateComponents([.day], from: critter.obtainedAt, to: Date()).day ?? 0),
            urgencyScore: 0
        )
        let xpProgress = rewards.xpProgress(for: critter)
        let starCost = rewards.starUpgradeCost(for: critter)
        return OasisCritterRenderSnapshot(
            lifecycle: lifecycle,
            dailyWish: nil,
            isDailyWishCompleted: false,
            prompt: Self.prompt(for: critter, lifecycle: lifecycle, rewards: rewards),
            displayLevel: min(rewards.maxCritterLevel, max(1, critter.level)),
            appearanceStage: rewards.appearanceStage(forLevel: critter.level),
            maxLevel: rewards.maxCritterLevel,
            bondLevel: rewards.bondLevel(for: critter),
            bondProgress: rewards.bondProgress(for: critter),
            xpProgress: xpProgress,
            xpPercent: Int(Double(xpProgress) / Double(rewards.critterXPPerLevel) * 100),
            xpTarget: rewards.critterXPPerLevel,
            todayInteractionCount: 0,
            canUpgradeLevel: rewards.canUpgradeLevel(for: critter),
            xpNeededForNextLevel: max(0, rewards.critterXPPerLevel - xpProgress),
            canFeed: false,
            canPlay: false,
            canRest: false,
            feedCost: 0,
            playCost: 0,
            restCost: 0,
            starFragmentsCost: starCost.fragments,
            starCoconutsCost: starCost.coconuts,
            canUpgradeStar: false
        )
    }

    @MainActor
    static func prompt(
        for critter: OasisElectronicPet,
        lifecycle: OasisCritterLifecycleSnapshot,
        rewards: OasisRewardManaging
    ) -> AppLocalizedText {
        AppLocalizedText(
            zh: rewards.gentlePrompt(for: critter, snapshot: lifecycle, l: L10n("zh")),
            en: rewards.gentlePrompt(for: critter, snapshot: lifecycle, l: L10n("en")),
            de: rewards.gentlePrompt(for: critter, snapshot: lifecycle, l: L10n("de"))
        )
    }
}
