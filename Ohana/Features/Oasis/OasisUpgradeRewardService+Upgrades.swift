//
//  OasisUpgradeRewardService+Upgrades.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    @discardableResult
    static func upgradeStar(
        for critter: OasisElectronicPet,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> Bool {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        let commandKey = "star:\(critter.id.uuidString)"
        guard beginGrowthCommand(commandKey) else { return false }
        defer { endGrowthCommand(commandKey) }

        return try PersistenceWriteFence.withExclusiveAccess(
            context: context,
            unavailable: { false }
        ) {
            normalizeLifecycle(for: critter, context: context)
            let availability = starUpgradeAvailability(
                for: critter,
                context: context,
                isProcessing: false,
                activeHumanSelection: activeHumanSelection,
                questManager: questManager,
                ignoresCommandKey: commandKey
            )
            guard availability.isAvailable else { return false }
            let plan = availability.fundingPlan
            guard consumeCompanionFunding(
                plan,
                catalogId: critter.catalogId,
                emoji: "⭐️",
                title: DomainCareRewardGeneralTitle.oasisCritterStarUpgrade,
                context: context,
                activeHumanSelection: activeHumanSelection,
                wallet: wallet,
                questManager: questManager
            ) else { return false }

            do {
                critter.starLevel = min(maxCritterStarLevel, critter.starLevel + 1)
                critter.bond = min(999, critter.bond + 20)
                critter.mood = min(100, critter.mood + 16)
                critter.appearanceStage = min(
                    maxCritterAppearanceStage,
                    max(appearanceStage(forLevel: critter.level), critter.starLevel)
                )
                critter.lastInteractionAt = Date()
                critter.lastStateRefreshAt = Date()
                context.insert(fundingActionLog(
                    for: critter,
                    action: .starUpgrade,
                    plan: plan
                ))
                try saveRewardChanges(context: context)
                wallet.refreshQuestProjection(context: context, manager: questManager)
                return true
            } catch {
                context.rollback()
                wallet.refreshQuestProjection(context: context, manager: questManager)
                throw error
            }
        }
    }

    @discardableResult
    static func awakenWithFragments(
        catalogId: String,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> OasisElectronicPet? {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        let commandKey = "awaken:\(catalogId)"
        guard beginGrowthCommand(commandKey) else { return nil }
        defer { endGrowthCommand(commandKey) }

        return try PersistenceWriteFence.withExclusiveAccess(
            context: context,
            unavailable: { nil }
        ) {
            guard let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) else { return nil }
            let availability = awakenAvailability(
                catalogId: catalogId,
                context: context,
                isProcessing: false,
                activeHumanSelection: activeHumanSelection,
                questManager: questManager,
                ignoresCommandKey: commandKey
            )
            guard availability.isAvailable else { return nil }
            let plan = availability.fundingPlan
            guard consumeCompanionFunding(
                plan,
                catalogId: catalogId,
                emoji: "🐾",
                title: DomainCareRewardGeneralTitle.oasisCritterAwaken,
                context: context,
                activeHumanSelection: activeHumanSelection,
                wallet: wallet,
                questManager: questManager
            ) else { return nil }

            do {
                let hasFeatured = hasFeaturedCritter(context: context)
                let critter = OasisElectronicPet(
                    catalogId: entry.id,
                    nameZh: entry.nameZh,
                    nameEn: entry.nameEn,
                    nameDe: entry.nameDe,
                    emoji: entry.emoji,
                    rarity: entry.rarity,
                    isFeaturedOnOasis: !hasFeatured,
                    habitatSlot: hasFeatured ? 1 : 0,
                    favoriteItemId: entry.preferredItemId,
                    personalityRaw: entry.personalityRaw,
                    sourceLevel: entry.sourceLevel
                )
                context.insert(critter)
                context.insert(fundingActionLog(
                    for: critter,
                    action: .fragmentAwaken,
                    plan: plan
                ))
                try saveRewardChanges(context: context)
                wallet.refreshQuestProjection(context: context, manager: questManager)
                return critter
            } catch {
                context.rollback()
                wallet.refreshQuestProjection(context: context, manager: questManager)
                throw error
            }
        }
    }

    static func setFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws {
        normalizeLifecycle(for: critter, context: context)
        guard critter.lifeState != .dead,
              critter.lifeState != .critical,
              critter.lifeState != .sleeping else { return }
        let all = allElectronicPets(context: context)
        for item in all {
            item.isFeaturedOnOasis = item.id == critter.id
            if item.id == critter.id {
                item.habitatSlot = 0
            } else if item.habitatSlot == 0 {
                item.habitatSlot = 1
            }
        }
        context.insert(actionLog(for: critter, action: .feature))
        try saveRewardChanges(context: context)
    }

    static func clearFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws {
        normalizeLifecycle(for: critter, context: context)
        guard critter.lifeState != .dead,
              critter.lifeState != .critical,
              critter.lifeState != .sleeping else { return }
        critter.isFeaturedOnOasis = false
        context.insert(actionLog(for: critter, action: .feature))
        try saveRewardChanges(context: context)
    }

    static func rewardFeaturedCritterFromCare(
        type: QuestManager.OhanaActionType,
        context: ModelContext,
        idempotencyID: UUID? = nil
    ) -> Bool {
        if let idempotencyID {
            var descriptor = FetchDescriptor<OasisCritterActionLog>(
                predicate: #Predicate<OasisCritterActionLog> { $0.id == idempotencyID }
            )
            descriptor.fetchLimit = 1
            if (try? context.fetch(descriptor).first) != nil { return true }
        }
        let candidates = activeCritters(context: context)
            .sorted(by: {
                if $0.isFeaturedOnOasis != $1.isFeaturedOnOasis { return $0.isFeaturedOnOasis && !$1.isFeaturedOnOasis }
                if $0.habitatSlot != $1.habitatSlot { return $0.habitatSlot < $1.habitatSlot }
                return $0.obtainedAt < $1.obtainedAt
            })
        guard let critter = candidates.first(where: {
            normalizeLifecycle(for: $0, context: context)
            return $0.lifeState != .dead && $0.lifeState != .critical && $0.lifeState != .sleeping
        }) else { return true }

        let gain = careEchoGain(for: type)
        let xpDelta = addXP(gain.xp, to: critter)
        critter.bond = min(999, critter.bond + gain.bond)
        critter.mood = min(100, critter.mood + gain.mood)
        critter.health = min(100, critter.health + gain.health)
        switch type {
        case .feed, .water:
            critter.hunger = min(100, critter.hunger + 6)
        default:
            break
        }
        critter.xp = critter.level >= maxCritterLevel ? 0 : max(0, min(critterXPPerLevel, critter.xp))
        critter.appearanceStage = appearanceStage(forLevel: critter.level)
        critter.lastStateRefreshAt = Date()
        refreshLifecycleState(for: critter, now: Date())
        let log = actionLog(
            for: critter,
            action: .careEcho,
            xpDelta: xpDelta
        )
        if let idempotencyID { log.id = idempotencyID }
        context.insert(log)
        return saveRewardChangesIfNeeded(context: context)
    }

    static func careEchoGain(for type: QuestManager.OhanaActionType) -> (xp: Int, bond: Int, mood: Int, health: Int) {
        switch type {
        case .walk:
            (2, 3, 3, 4)
        case .health, .care:
            (2, 3, 2, 8)
        case .feed, .water:
            (1, 2, 2, 4)
        case .potty, .weight:
            (1, 1, 1, 3)
        case .expense:
            (0, 1, 0, 1)
        case .milestone:
            (3, 5, 4, 6)
        case .dailyFocusCompletion, .general:
            (1, 2, 1, 2)
        case .plantWatering:
            (1, 2, 1, 3)
        case .plantFertilizing:
            (2, 3, 1, 3)
        }
    }

    static func interactionCost(for critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) -> Int {
        switch action {
        case .feed:
            dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 5
        case .play:
            dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 3
        case .rest:
            dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 2
        case .rescue, .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            0
        }
    }

    static func awakeningCost(for rarity: OasisElectronicPetRarity) -> (fragments: Int, coconuts: Int) {
        switch rarity {
        case .common: (120, 80)
        case .rare: (160, 120)
        case .epic: (240, 180)
        case .legendary: (360, 300)
        }
    }

    static func starUpgradeCost(for critter: OasisElectronicPet) -> (fragments: Int, coconuts: Int) {
        switch critter.starLevel {
        case ...1: (40, 40)
        case 2: (60, 80)
        case 3: (80, 120)
        case 4: (120, 160)
        default: (0, 0)
        }
    }

    static func starUpgradeAvailability(
        for critter: OasisElectronicPet,
        context: ModelContext,
        isProcessing: Bool = false,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        questManager providedQuestManager: QuestManager? = nil,
        ignoresCommandKey: String? = nil
    ) -> CompanionActionAvailability {
        let questManager = providedQuestManager ?? QuestManager()
        let cost = starUpgradeCost(for: critter)
        let plan = companionFundingPlan(
            catalogId: critter.catalogId,
            requiredGrowthCurrency: cost.fragments,
            coconutCost: cost.coconuts,
            context: context,
            activeHumanSelection: activeHumanSelection,
            questManager: questManager
        )
        let commandKey = "star:\(critter.id.uuidString)"
        let commandIsActive = activeGrowthCommandKeys.contains(commandKey) && commandKey != ignoresCommandKey
        let reason: CompanionActionUnavailableReason? = if isProcessing || commandIsActive {
            .processing
        } else if critter.starLevel >= maxCritterStarLevel {
            .maxStars
        } else if critter.lifeState == .sleeping || critter.lifeState == .critical || critter.lifeState == .dead {
            .sleeping
        } else if OasisCritterEconomyService.currentHuman(
            context: context,
            activeHumanSelection: activeHumanSelection
        ) == nil {
            .noActiveHuman
        } else if plan.missingGrowthCurrency > 0 {
            .insufficientGrowthCurrency
        } else if plan.missingCoconuts > 0 {
            .insufficientCoconuts
        } else {
            nil
        }
        return CompanionActionAvailability(
            action: .starUpgrade,
            isAvailable: reason == nil,
            reason: reason,
            fundingPlan: plan
        )
    }

    static func awakenAvailability(
        catalogId: String,
        context: ModelContext,
        isProcessing: Bool = false,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        questManager providedQuestManager: QuestManager? = nil,
        ignoresCommandKey: String? = nil
    ) -> CompanionActionAvailability {
        let questManager = providedQuestManager ?? QuestManager()
        guard let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) else {
            let plan = CompanionFundingPlan.make(
                requiredGrowthCurrency: 0,
                coconutCost: 0,
                specificFragmentBalance: 0,
                stardustBalance: stardustBalance(context: context),
                coconutBalance: OasisCritterEconomyService.currentHumanBalance(
                    context: context,
                    activeHumanSelection: activeHumanSelection,
                    questManager: questManager
                )
            )
            return CompanionActionAvailability(
                action: .awaken,
                isAvailable: false,
                reason: .unknownCompanion,
                fundingPlan: plan
            )
        }
        let cost = awakeningFundingCost(for: entry)
        let plan = companionFundingPlan(
            catalogId: catalogId,
            requiredGrowthCurrency: cost.fragments,
            coconutCost: cost.coconuts,
            context: context,
            activeHumanSelection: activeHumanSelection,
            questManager: questManager
        )
        let commandKey = "awaken:\(catalogId)"
        let commandIsActive = activeGrowthCommandKeys.contains(commandKey) && commandKey != ignoresCommandKey
        let reason: CompanionActionUnavailableReason? = if isProcessing || commandIsActive {
            .processing
        } else if ownsCritter(catalogId, context: context) {
            .alreadyOwned
        } else if OasisTreeManagerRegistry.current.treeLevel.rawValue < entry.sourceLevel {
            .treeLevelLocked
        } else if OasisCritterEconomyService.currentHuman(
            context: context,
            activeHumanSelection: activeHumanSelection
        ) == nil {
            .noActiveHuman
        } else if plan.missingGrowthCurrency > 0 {
            .insufficientGrowthCurrency
        } else if plan.missingCoconuts > 0 {
            .insufficientCoconuts
        } else {
            nil
        }
        return CompanionActionAvailability(
            action: .awaken,
            isAvailable: reason == nil,
            reason: reason,
            fundingPlan: plan
        )
    }

    static func companionSnapshot(
        for critter: OasisElectronicPet,
        context: ModelContext,
        isProcessing: Bool = false,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        questManager providedQuestManager: QuestManager? = nil
    ) -> OasisCompanionSnapshot {
        let questManager = providedQuestManager ?? QuestManager()
        let availability = starUpgradeAvailability(
            for: critter,
            context: context,
            isProcessing: isProcessing,
            activeHumanSelection: activeHumanSelection,
            questManager: questManager
        )
        return OasisCompanionSnapshot(
            id: critter.id,
            catalogID: critter.catalogId,
            level: min(maxCritterLevel, max(1, critter.level)),
            starLevel: min(maxCritterStarLevel, max(1, critter.starLevel)),
            appearanceStage: min(maxCritterAppearanceStage, max(1, critter.appearanceStage)),
            bond: max(0, critter.bond),
            lifeState: lifecycleSnapshot(for: critter).state,
            specificFragments: availability.fundingPlan.specificFragmentBalance,
            stardust: availability.fundingPlan.stardustBalance,
            starAvailability: availability
        )
    }

    private static func awakeningFundingCost(
        for entry: OasisElectronicPetCatalogEntry
    ) -> (fragments: Int, coconuts: Int) {
        if entry.id == OasisUpgradeRewardCatalog.firstCritterId {
            return (0, 0)
        }
        return awakeningCost(for: entry.rarity)
    }

    private static func companionFundingPlan(
        catalogId: String,
        requiredGrowthCurrency: Int,
        coconutCost: Int,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting,
        questManager: QuestManager
    ) -> CompanionFundingPlan {
        CompanionFundingPlan.make(
            requiredGrowthCurrency: requiredGrowthCurrency,
            coconutCost: coconutCost,
            specificFragmentBalance: fragmentBalance(
                critterId: catalogId,
                context: context
            )?.amount ?? 0,
            stardustBalance: stardustBalance(context: context),
            coconutBalance: OasisCritterEconomyService.currentHumanBalance(
                context: context,
                activeHumanSelection: activeHumanSelection,
                questManager: questManager
            )
        )
    }

    private static func consumeCompanionFunding(
        _ plan: CompanionFundingPlan,
        catalogId: String,
        emoji: String,
        title: String,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager
    ) -> Bool {
        guard plan.isFullyFunded else { return false }
        let now = Date()
        if plan.specificFragmentsUsed > 0 {
            guard let balance = fragmentBalance(critterId: catalogId, context: context),
                  balance.amount >= plan.specificFragmentsUsed else { return false }
            balance.amount -= plan.specificFragmentsUsed
            balance.updatedAt = now
        }
        if plan.stardustUsed > 0 {
            guard let balance = fragmentBalance(
                critterId: OasisCompanionCurrency.stardustCatalogID,
                context: context
            ), balance.amount >= plan.stardustUsed else {
                context.rollback()
                return false
            }
            balance.amount -= plan.stardustUsed
            balance.updatedAt = now
        }
        guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
            plan.coconutCost,
            emoji: emoji,
            title: title,
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager,
            updatesProjection: false
        ) else {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            return false
        }
        return true
    }

    private static func fundingActionLog(
        for critter: OasisElectronicPet,
        action: OasisCritterAction,
        plan: CompanionFundingPlan
    ) -> OasisCritterActionLog {
        let actionZh = action == .starUpgrade ? "伙伴升星" : "唤醒伙伴"
        let actionEn = action == .starUpgrade ? "Companion star upgrade" : "Companion awakening"
        let actionDe = action == .starUpgrade ? "Begleiter-Sternupgrade" : "Begleiter-Erweckung"
        let fundingZh = "\(plan.specificFragmentsUsed)◇ + \(plan.stardustUsed)✦ + \(plan.coconutCost)🥥"
        return OasisCritterActionLog(
            critterId: critter.id,
            critterCatalogId: critter.catalogId,
            action: action,
            coconutDelta: -plan.coconutCost,
            fragmentDelta: -(plan.specificFragmentsUsed + plan.stardustUsed),
            sourceLevel: critter.sourceLevel,
            noteZh: "\(actionZh)：\(fundingZh)",
            noteEn: "\(actionEn): \(fundingZh)",
            noteDe: "\(actionDe): \(fundingZh)"
        )
    }

    private static func beginGrowthCommand(_ key: String) -> Bool {
        activeGrowthCommandKeys.insert(key).inserted
    }

    private static func endGrowthCommand(_ key: String) {
        activeGrowthCommandKeys.remove(key)
    }
}
