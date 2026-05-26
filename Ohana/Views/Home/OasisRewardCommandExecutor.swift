import Foundation
import SwiftData

@MainActor
struct OasisRewardCommandExecutor {
    let context: ModelContext

    func currentHumanCoconutBalance(humans: [Human], currentActiveHumanId: String) -> Int {
        humans.first { $0.id.uuidString == currentActiveHumanId }?.coconutBalance
            ?? QuestManager.shared.coconutCount
    }

    func makeActionSnapshot(
        humans: [Human],
        currentActiveHumanId: String,
        critterFragments: [OasisCritterFragmentBalance]
    ) -> OasisRewardActionSnapshot {
        OasisRewardActionSnapshot(
            canInjectCoconuts: OasisCritterEconomyService.canSpendCurrentHumanCoconuts(10, context: context),
            activeCoconutBalance: currentHumanCoconutBalance(
                humans: humans,
                currentActiveHumanId: currentActiveHumanId
            ),
            critterFragmentTotal: critterFragments.reduce(0) { $0 + $1.amount }
        )
    }

    func makeBentoSnapshot(
        pets: [Pet],
        electronicPets: [OasisElectronicPet],
        activeCoconutBalance: Int
    ) -> OasisBentoSnapshot {
        let allAchievements = pets.flatMap { AchievementManager.compute(for: $0) }
        let unlockedCount = allAchievements.filter(\.isUnlocked).count
        let totalCount = allAchievements.count
        let activeCritterCount = electronicPets.filter { !$0.isArchived }.count

        return OasisBentoSnapshot(
            shopMetric: "\(activeCoconutBalance)",
            achievementMetric: pets.isEmpty ? "—" : "\(unlockedCount)/\(totalCount)",
            achievementsLocked: pets.isEmpty,
            critterMetric: electronicPets.isEmpty
                ? "Lv.10"
                : "\(activeCritterCount)/\(OasisUpgradeRewardCatalog.critters.count)"
        )
    }

    func makeCritterSnapshots(
        electronicPets: [OasisElectronicPet],
        fragments: [OasisCritterFragmentBalance] = []
    ) -> [UUID: OasisCritterRenderSnapshot] {
        var snapshots: [UUID: OasisCritterRenderSnapshot] = [:]
        for critter in electronicPets where !critter.isArchived {
            let lifecycle = OasisUpgradeRewardService.lifecycleSnapshot(for: critter, context: context)
            let wish = OasisUpgradeRewardService.displayDailyWish(for: critter, snapshot: lifecycle)
            let starCost = OasisUpgradeRewardService.starUpgradeCost(for: critter)
            let feedCost = OasisUpgradeRewardService.interactionCost(for: critter, action: .feed, context: context)
            let playCost = OasisUpgradeRewardService.interactionCost(for: critter, action: .play, context: context)
            let restCost = OasisUpgradeRewardService.interactionCost(for: critter, action: .rest, context: context)
            let activeBalance = OasisCritterEconomyService.currentHumanBalance(context: context)
            let fragmentCount = fragments.first(where: { $0.catalogId == critter.catalogId })?.amount ?? 0
            let xpProgress = OasisUpgradeRewardService.xpProgress(for: critter)
            let canUseActions = lifecycle.state != .dead
            snapshots[critter.id] = OasisCritterRenderSnapshot(
                lifecycle: lifecycle,
                dailyWish: wish,
                isDailyWishCompleted: OasisUpgradeRewardService.isDailyWishCompleted(
                    for: critter,
                    wish: wish,
                    context: context
                ),
                prompt: OasisCritterRenderSnapshot.prompt(for: critter, lifecycle: lifecycle),
                displayLevel: min(OasisUpgradeRewardService.maxCritterLevel, max(1, critter.level)),
                appearanceStage: OasisUpgradeRewardService.appearanceStage(forLevel: critter.level),
                maxLevel: OasisUpgradeRewardService.maxCritterLevel,
                bondLevel: OasisUpgradeRewardService.bondLevel(for: critter),
                bondProgress: OasisUpgradeRewardService.bondProgress(for: critter),
                xpProgress: xpProgress,
                xpPercent: Int(Double(xpProgress) / Double(OasisUpgradeRewardService.critterXPPerLevel) * 100),
                xpTarget: OasisUpgradeRewardService.critterXPPerLevel,
                todayInteractionCount: OasisUpgradeRewardService.todayInteractionCount(for: critter, context: context),
                canUpgradeLevel: OasisUpgradeRewardService.canUpgradeLevel(for: critter),
                xpNeededForNextLevel: max(0, OasisUpgradeRewardService.critterXPPerLevel - xpProgress),
                canFeed: canUseActions && activeBalance >= feedCost,
                canPlay: canUseActions && activeBalance >= playCost,
                canRest: canUseActions && activeBalance >= restCost,
                feedCost: feedCost,
                playCost: playCost,
                restCost: restCost,
                starFragmentsCost: starCost.fragments,
                starCoconutsCost: starCost.coconuts,
                canUpgradeStar: canUseActions && fragmentCount >= starCost.fragments && activeBalance >= starCost.coconuts
            )
        }
        return snapshots
    }

    func refreshPreviewEnergy(
        treeManager: OasisTreeManager,
        pets: [Pet],
        humans: [Human],
        plants: [Plant]
    ) {
        treeManager.refreshPreviewEnergy(modelContext: context, pets: pets, humans: humans, plants: plants)
    }

    func refreshEnergy(
        treeManager: OasisTreeManager,
        pets: [Pet],
        humans: [Human],
        plants: [Plant]
    ) {
        treeManager.refreshEnergy(modelContext: context, pets: pets, humans: humans, plants: plants)
    }

    func awardHarvestedTreeCoconuts(_ amount: Int) {
        guard amount > 0 else { return }
        OasisCritterEconomyService.awardCurrentHumanCoconuts(
            amount,
            emoji: "🥥",
            title: "摘下椰子 +\(amount)🥥",
            context: context
        )
        context.safeSave()
    }

    func harvestDailyTreeCoconuts(treeManager: OasisTreeManager) -> Bool {
        guard treeManager.canHarvestToday else { return false }
        let amount = treeManager.passiveIncomeAmount
        guard amount > 0 else { return false }
        UserDefaults.standard.set(Date(), forKey: OasisTreeManager.passiveIncomeKey)
        OasisCritterEconomyService.awardCurrentHumanCoconuts(
            amount,
            emoji: "🌳",
            title: "生命之树的馈赠 +\(amount)🥥",
            context: context
        )
        context.safeSave()
        return true
    }

    func injectTreeEnergy(treeManager: OasisTreeManager, cost: Int = 10) -> Bool {
        treeManager.injectEnergy(cost: cost, modelContext: context)
    }

    func openUpgradeCoconut(_ coconut: OasisUpgradeCoconut) throws -> OasisOpenedUpgradeReward {
        try OasisUpgradeRewardService.open(coconut, context: context)
    }

    func interact(
        with critter: OasisElectronicPet,
        action: OasisCritterAction
    ) throws -> OasisCritterInteractionOutcome {
        try OasisUpgradeRewardService.interactWithOutcome(with: critter, action: action, context: context)
    }

    func rescue(_ critter: OasisElectronicPet) throws -> OasisCritterInteractionOutcome {
        try OasisUpgradeRewardService.rescueIfNeeded(for: critter, context: context)
    }

    func upgradeStar(_ critter: OasisElectronicPet) throws -> Bool {
        try OasisUpgradeRewardService.upgradeStar(for: critter, context: context)
    }

    func upgradeLevel(_ critter: OasisElectronicPet) throws -> Bool {
        try OasisUpgradeRewardService.upgradeLevel(for: critter, context: context)
    }

    func awakenWithFragments(catalogId: String) throws -> OasisElectronicPet? {
        try OasisUpgradeRewardService.awakenWithFragments(catalogId: catalogId, context: context)
    }

    func setFeatured(_ critter: OasisElectronicPet, desired: Bool) throws {
        if desired {
            try OasisUpgradeRewardService.setFeatured(critter, context: context)
        } else {
            try OasisUpgradeRewardService.clearFeatured(critter, context: context)
        }
    }

    func refreshFeaturedCritterLifecycle(_ electronicPets: [OasisElectronicPet]) {
        for critter in electronicPets where !critter.isArchived {
            OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context)
        }
    }

    func loadCheckInData(currentActiveHumanId: String) -> OasisCheckInSnapshot {
        OasisCheckInSnapshot(
            checkedInDates: CheckInStreakStore.checkedInDates(for: currentActiveHumanId),
            makeupDates: CheckInStreakStore.makeupDates(for: currentActiveHumanId),
            makeupPackCount: UserDefaults.standard.integer(forKey: CheckInStreakStore.makeupPackKey),
            lastClaimedMilestone: CheckInStreakStore.lastClaimedMilestone(for: currentActiveHumanId)
        )
    }

    func triggerTodayCheckIn(
        currentActiveHumanId: String,
        checkedInDates: Set<String>
    ) -> Set<String>? {
        let today = CheckInStreakStore.dateString()
        guard !checkedInDates.contains(today) else { return nil }
        var updatedDates = checkedInDates
        updatedDates.insert(today)
        CheckInStreakStore.setCheckedInDates(updatedDates, for: currentActiveHumanId)
        OasisCritterEconomyService.awardCurrentHumanCoconuts(
            1,
            emoji: "📅",
            title: "每日打卡奖励",
            context: context
        )
        context.safeSave()
        return updatedDates
    }

    func applyMakeup(
        date: String,
        currentActiveHumanId: String,
        snapshot: OasisCheckInSnapshot
    ) -> OasisCheckInSnapshot? {
        guard snapshot.makeupPackCount > 0, !snapshot.checkedInDates.contains(date) else { return nil }
        var updated = snapshot
        updated.makeupPackCount -= 1
        updated.checkedInDates.insert(date)
        updated.makeupDates.insert(date)
        UserDefaults.standard.set(updated.makeupPackCount, forKey: CheckInStreakStore.makeupPackKey)
        CheckInStreakStore.setCheckedInDates(updated.checkedInDates, for: currentActiveHumanId)
        CheckInStreakStore.setMakeupDates(updated.makeupDates, for: currentActiveHumanId)
        return updated
    }

    func claimMilestone(days: Int, reward: Int, emoji: String, currentActiveHumanId: String) {
        OasisCritterEconomyService.awardCurrentHumanCoconuts(
            reward,
            emoji: emoji,
            title: "\(days)天连胜奖励",
            context: context
        )
        context.safeSave()
        CheckInStreakStore.setLastClaimedMilestone(days, for: currentActiveHumanId)
    }
}
