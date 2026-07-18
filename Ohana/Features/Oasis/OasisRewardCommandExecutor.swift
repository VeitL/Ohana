import Foundation
import SwiftData

@MainActor
struct OasisRewardCommandExecutor {
    let context: ModelContext
    let rewards: OasisRewardManaging
    let shopInventory: ShopInventoryManaging

    init(
        context: ModelContext,
        rewards: OasisRewardManaging,
        shopInventory: ShopInventoryManaging
    ) {
        self.context = context
        self.rewards = rewards
        self.shopInventory = shopInventory
    }

    private func activeWritableHuman(humans: [Human], currentActiveHumanId: String) -> Human? {
        guard !currentActiveHumanId.isEmpty else { return nil }
        return humans.first(where: {
            $0.id.uuidString == currentActiveHumanId &&
                MemberLifecycleGate.disposition(human: $0, writeKind: .care).allowsEconomyDerivation
        })
    }

    func currentHumanCoconutBalance(humans: [Human], currentActiveHumanId: String) -> Int {
        guard let human = activeWritableHuman(humans: humans, currentActiveHumanId: currentActiveHumanId) else { return 0 }
        return CoconutWalletService.balance(for: human, context: context)
    }

    func makeActionSnapshot(
        humans: [Human],
        currentActiveHumanId: String,
        critterFragments: [OasisCritterFragmentBalance]
    ) -> OasisRewardActionSnapshot {
        let activeBalance = currentHumanCoconutBalance(
            humans: humans,
            currentActiveHumanId: currentActiveHumanId
        )
        let injectionBalance = OasisCritterEconomyService.availableCoconutBalance(context: context)
        return OasisRewardActionSnapshot(
            canInjectCoconuts: injectionBalance >= OasisTreeEnergyInjectionPolicy.starterPackageCost,
            injectionCoconutBalance: injectionBalance,
            activeCoconutBalance: activeBalance,
            critterFragmentTotal: critterFragments
                .filter { $0.catalogId != OasisCompanionCurrency.stardustCatalogID }
                .reduce(0) { $0 + $1.amount },
            stardustBalance: critterFragments
                .first(where: { $0.catalogId == OasisCompanionCurrency.stardustCatalogID })?
                .amount ?? 0
        )
    }

    func makeBentoSnapshot(
        pets: [Pet],
        electronicPets: [OasisElectronicPet],
        activeCoconutBalance: Int,
        careLedgerEvents: [CareLedgerEvent],
        petActivitySummaries: [UUID: AchievementPetActivitySummary]
    ) -> OasisBentoSnapshot {
        let context = AchievementComputationContext(
            careLedgerEvents: careLedgerEvents,
            petActivitySummaries: petActivitySummaries
        )
        let allAchievements = pets.flatMap { AchievementManager.compute(for: $0, context: context) }
        let unlockedCount = allAchievements.filter(\.isUnlocked).count
        let totalCount = allAchievements.count
        let activeCritterCount = electronicPets.count(where: { !$0.isArchived })

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
        fragments: [OasisCritterFragmentBalance] = [],
        activeCoconutBalance: Int
    ) -> [UUID: OasisCritterRenderSnapshot] {
        var snapshots: [UUID: OasisCritterRenderSnapshot] = [:]
        for critter in electronicPets where !critter.isArchived {
            let lifecycle = rewards.lifecycleSnapshot(for: critter, context: context)
            let wish = rewards.displayDailyWish(for: critter, snapshot: lifecycle)
            let starCost = rewards.starUpgradeCost(for: critter)
            let starAvailability = rewards.starUpgradeAvailability(
                for: critter,
                context: context,
                isProcessing: false
            )
            let feedCost = rewards.interactionCost(for: critter, action: .feed, context: context)
            let playCost = rewards.interactionCost(for: critter, action: .play, context: context)
            let restCost = rewards.interactionCost(for: critter, action: .rest, context: context)
            let fragmentCount = fragments.first(where: { $0.catalogId == critter.catalogId })?.amount ?? 0
            let xpProgress = rewards.xpProgress(for: critter)
            let canUseActions = lifecycle.state != .dead && lifecycle.state != .critical && lifecycle.state != .sleeping
            snapshots[critter.id] = OasisCritterRenderSnapshot(
                lifecycle: lifecycle,
                dailyWish: wish,
                isDailyWishCompleted: rewards.isDailyWishCompleted(
                    for: critter,
                    wish: wish,
                    context: context
                ),
                prompt: OasisCritterRenderSnapshot.prompt(for: critter, lifecycle: lifecycle, rewards: rewards),
                displayLevel: min(rewards.maxCritterLevel, max(1, critter.level)),
                appearanceStage: rewards.appearanceStage(forLevel: critter.level),
                maxLevel: rewards.maxCritterLevel,
                bondLevel: rewards.bondLevel(for: critter),
                bondProgress: rewards.bondProgress(for: critter),
                xpProgress: xpProgress,
                xpPercent: Int(Double(xpProgress) / Double(rewards.critterXPPerLevel) * 100),
                xpTarget: rewards.critterXPPerLevel,
                todayInteractionCount: rewards.todayInteractionCount(for: critter, context: context),
                canUpgradeLevel: rewards.canUpgradeLevel(for: critter),
                xpNeededForNextLevel: max(0, rewards.critterXPPerLevel - xpProgress),
                canFeed: canUseActions && activeCoconutBalance >= feedCost,
                canPlay: canUseActions && activeCoconutBalance >= playCost,
                canRest: canUseActions && activeCoconutBalance >= restCost,
                feedCost: feedCost,
                playCost: playCost,
                restCost: restCost,
                starFragmentsCost: starCost.fragments,
                starCoconutsCost: starCost.coconuts,
                canUpgradeStar: canUseActions && starAvailability.isAvailable,
                specificFragmentBalance: fragmentCount,
                stardustBalance: starAvailability.fundingPlan.stardustBalance,
                starAvailability: starAvailability
            )
        }
        return snapshots
    }

    func refreshPreviewEnergy(
        treeManager: OasisTreeManaging,
        pets: [Pet],
        humans: [Human],
        plants: [Plant]
    ) {
        treeManager.refreshPreviewEnergy(modelContext: context, pets: pets, humans: humans, plants: plants)
    }

    func refreshEnergy(
        treeManager: OasisTreeManaging,
        pets: [Pet],
        humans: [Human],
        plants: [Plant]
    ) {
        treeManager.refreshEnergy(modelContext: context, pets: pets, humans: humans, plants: plants)
    }

    func awardHarvestedTreeCoconuts(_ amount: Int) {
        guard amount > 0 else { return }
        guard rewards.awardBudgetedCurrentHumanCoconuts(
            amount,
            emoji: "🥥",
            title: DomainCareRewardGeneralTitle.counted(DomainCareRewardGeneralTitle.oasisHarvestedCoconut, count: amount),
            context: context,
            postsRewardFeedback: false,
            date: Date()
        ) != nil else {
            context.rollback()
            rewards.refreshCoconutProjection(context: context)
            return
        }
    }

    func harvestDailyTreeCoconuts(treeManager: OasisTreeManaging) -> Bool {
        guard treeManager.canHarvestToday else { return false }
        let amount = treeManager.passiveIncomeAmount
        guard amount > 0 else { return false }
        let harvestDate = Date()
        guard rewards.awardBudgetedCurrentHumanCoconuts(
            amount,
            emoji: "🌳",
            title: DomainCareRewardGeneralTitle.counted(DomainCareRewardGeneralTitle.oasisTreeGift, count: amount),
            context: context,
            postsRewardFeedback: false,
            date: harvestDate
        ) != nil else {
            context.rollback()
            rewards.refreshCoconutProjection(context: context)
            return false
        }
        treeManager.markDailyPassiveIncomeHarvested(date: harvestDate)
        return true
    }

    func injectTreeEnergy(
        treeManager: OasisTreeManaging,
        cost: Int = OasisTreeEnergyInjectionPolicy.starterPackageCost
    ) -> Bool {
        treeManager.injectEnergy(cost: cost, modelContext: context)
    }

    func openUpgradeCoconut(_ coconut: OasisUpgradeCoconut) throws -> OasisOpenedUpgradeReward {
        try rewards.open(coconut, context: context)
    }

    func interact(
        with critter: OasisElectronicPet,
        action: OasisCritterAction
    ) throws -> OasisCritterInteractionOutcome {
        try rewards.interactWithOutcome(with: critter, action: action, context: context)
    }

    func rescue(_ critter: OasisElectronicPet) throws -> OasisCritterInteractionOutcome {
        try rewards.rescueIfNeeded(for: critter, context: context)
    }

    func upgradeStar(_ critter: OasisElectronicPet) throws -> Bool {
        try rewards.upgradeStar(for: critter, context: context)
    }

    func starUpgradeAvailability(
        for critter: OasisElectronicPet,
        isProcessing: Bool = false
    ) -> CompanionActionAvailability {
        rewards.starUpgradeAvailability(
            for: critter,
            context: context,
            isProcessing: isProcessing
        )
    }

    func upgradeLevel(_ critter: OasisElectronicPet) throws -> Bool {
        try rewards.upgradeLevel(for: critter, context: context)
    }

    func levelUpgradeAvailability(
        for critter: OasisElectronicPet,
        isProcessing: Bool = false
    ) -> CompanionActionAvailability {
        rewards.levelUpgradeAvailability(
            for: critter,
            isProcessing: isProcessing
        )
    }

    func awakenWithFragments(catalogId: String) throws -> OasisElectronicPet? {
        try rewards.awakenWithFragments(catalogId: catalogId, context: context)
    }

    func awakenAvailability(
        catalogId: String,
        isProcessing: Bool = false
    ) -> CompanionActionAvailability {
        rewards.awakenAvailability(
            catalogId: catalogId,
            context: context,
            isProcessing: isProcessing
        )
    }

    func companionSnapshot(
        for critter: OasisElectronicPet,
        isProcessing: Bool = false
    ) -> OasisCompanionSnapshot {
        rewards.companionSnapshot(
            for: critter,
            context: context,
            isProcessing: isProcessing
        )
    }

    func setFeatured(_ critter: OasisElectronicPet, desired: Bool) throws {
        if desired {
            try rewards.setFeatured(critter, context: context)
        } else {
            try rewards.clearFeatured(critter, context: context)
        }
    }

    func refreshFeaturedCritterLifecycle(_ electronicPets: [OasisElectronicPet]) {
        for critter in electronicPets where !critter.isArchived {
            rewards.normalizeLifecycle(for: critter, context: context)
        }
    }

    func loadCheckInData(currentActiveHumanId: String) -> OasisCheckInSnapshot {
        // The UserDefaults streak store is retired. Keep this compatibility
        // shape empty until the unmounted legacy Oasis calendar is removed;
        // Zen Streak reads V93 Presence facts through its dedicated read model.
        OasisCheckInSnapshot(
            checkedInDates: [],
            makeupDates: [],
            makeupPackCount: shopInventory.consumableSnapshot().backdatePassCount,
            lastClaimedMilestone: 0
        )
    }

    func triggerTodayCheckIn(
        currentActiveHumanId: String,
        checkedInDates: Set<String>,
        postsRewardFeedback: Bool = true
    ) -> Set<String>? {
        // Retired with the V93 Presence command boundary. Ordinary Oasis must
        // not mint a second daily reward or write the legacy defaults store.
        nil
    }

    func applyMakeup(
        date: String,
        currentActiveHumanId: String,
        snapshot: OasisCheckInSnapshot
    ) -> OasisCheckInSnapshot? {
        // Backdate packs are historical inventory only; V93 does not support
        // makeup writes and this path must not consume one.
        nil
    }

    func claimMilestone(days: Int, reward: Int, emoji: String, currentActiveHumanId: String) {
        // V93 milestones are automatic and receipt-backed. The retired manual
        // claim callback remains source-compatible but intentionally does no work.
    }
}
