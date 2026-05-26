import Foundation

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
    var canFeed: Bool
    var canPlay: Bool
    var canRest: Bool
    var feedCost: Int
    var playCost: Int
    var restCost: Int
    var starFragmentsCost: Int
    var canUpgradeStar: Bool

    static func lightweight(for critter: OasisElectronicPet) -> OasisCritterRenderSnapshot {
        OasisCritterRenderSnapshot(
            lifecycle: OasisCritterLifecycleSnapshot(
                state: critter.lifeState,
                deathReason: critter.deathReason,
                recommendedAction: nil,
                isRescuable: critter.lifeState == .critical || critter.lifeState == .sick,
                hoursUntilDeath: nil,
                ageDays: max(0, Calendar.current.dateComponents([.day], from: critter.obtainedAt, to: Date()).day ?? 0),
                urgencyScore: 0
            ),
            dailyWish: nil,
            isDailyWishCompleted: false,
            canFeed: false,
            canPlay: false,
            canRest: false,
            feedCost: 0,
            playCost: 0,
            restCost: 0,
            starFragmentsCost: OasisUpgradeRewardService.starUpgradeCost(for: critter).fragments,
            canUpgradeStar: false
        )
    }
}
