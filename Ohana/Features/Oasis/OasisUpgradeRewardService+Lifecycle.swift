//
//  OasisUpgradeRewardService+Lifecycle.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    static func normalizeDecay(for critter: OasisElectronicPet) {
        normalizeLifecycle(for: critter)
    }

    static func normalizeLifecycle(for critter: OasisElectronicPet, context: ModelContext? = nil, now: Date = Date()) {
        let before = lifecycleFingerprint(for: critter)
        let needsCompatibilityMaintenance = critter.lifeState != .healthy && critter.lifeState != .sleeping ||
            !critter.deathReasonRaw.isEmpty ||
            critter.riskStartedAt != nil ||
            critter.criticalStartedAt != nil ||
            critter.diedAt != nil ||
            critter.lastGentlePromptAt != nil
        switch critter.lifeState {
        case .dead, .critical:
            // V94 compatibility maintenance: irreversible legacy states become
            // a gentle, free-to-wake sleep while preserving progression facts.
            critter.lifeState = .sleeping
            critter.isFeaturedOnOasis = false
        case .needsCare, .atRisk, .sick:
            critter.lifeState = .healthy
        case .healthy, .sleeping:
            break
        }
        critter.deathReason = nil
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.diedAt = nil
        critter.lastGentlePromptAt = nil
        if needsCompatibilityMaintenance {
            critter.lastStateRefreshAt = now
        }

        if lifecycleFingerprint(for: critter) != before, let context {
            _ = saveRewardChangesIfNeeded(context: context)
        }
    }

    static func lifecycleSnapshot(
        for critter: OasisElectronicPet,
        context: ModelContext? = nil,
        now: Date = Date()
    ) -> OasisCritterLifecycleSnapshot {
        _ = context
        let state: OasisCritterLifeState = switch critter.lifeState {
        case .dead, .critical:
            .sleeping
        case .needsCare, .atRisk, .sick:
            .healthy
        case .healthy, .sleeping:
            critter.lifeState
        }
        let urgency = switch state {
        case .healthy: 0
        case .sleeping: 1
        case .needsCare, .atRisk, .sick, .critical, .dead: 0
        }
        return OasisCritterLifecycleSnapshot(
            state: state,
            deathReason: nil,
            recommendedAction: state == .sleeping ? .rescue : recommendedCareAction(for: critter),
            isRescuable: state == .sleeping,
            hoursUntilDeath: nil,
            ageDays: ageDays(for: critter, now: now),
            urgencyScore: urgency
        )
    }

    static func gentlePrompt(for critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot, l: L10n) -> String {
        let name = critter.displayName(l)
        switch snapshot.state {
        case .healthy:
            return l.tr(
                zh: "\(name) 今天很安稳，像一团小小的云贴在你身边。",
                en: "\(name) feels settled today, soft and close by.",
                de: "\(name) fühlt sich heute ruhig an, weich und nah bei dir."
            )
        case .sleeping, .critical, .dead:
            return l.tr(
                zh: "\(name) 正在安心休眠，点一下免费唤醒就会回来。",
                en: "\(name) is resting safely. A free wake-up brings it right back.",
                de: "\(name) schläft sicher. Kostenloses Wecken bringt es zurück."
            )
        case .needsCare, .atRisk, .sick:
            return l.tr(
                zh: "\(name) 今天很安稳，等你陪它完成一个小心愿。",
                en: "\(name) is settled and waiting to share a tiny wish with you.",
                de: "\(name) ist ruhig und wartet auf einen kleinen Wunsch mit dir."
            )
        }
    }

    @discardableResult
    static func rescueIfNeeded(for critter: OasisElectronicPet, context: ModelContext, now: Date = Date()) throws -> OasisCritterInteractionOutcome {
        normalizeLifecycle(for: critter, context: context, now: now)
        let snapshot = lifecycleSnapshot(for: critter, context: context, now: now)
        let wish = dailyWish(for: .rescue)
        guard snapshot.isRescuable else {
            return OasisCritterInteractionOutcome(
                success: false,
                action: .rescue,
                completedDailyWish: false,
                wish: wish,
                messageZh: "现在不用急，它只是想被轻轻陪一下。",
                messageEn: "No rush right now. It only wants gentle company.",
                messageDe: "Kein Stress gerade. Es möchte nur sanfte Nähe.",
                rewardXP: 0,
                rewardBond: 0,
                rewardFragments: 0,
                rewardCoconuts: 0
            )
        }

        critter.hunger = max(critter.hunger, 80)
        critter.mood = max(critter.mood, 80)
        critter.health = 100
        critter.bond = min(999, critter.bond + 4)
        let xpDelta = addXP(3, to: critter)
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.lifeState = .healthy
        critter.deathReason = nil
        critter.diedAt = nil
        critter.lastInteractionAt = now
        critter.lastStateRefreshAt = now
        critter.lastGentlePromptAt = now
        context.insert(actionLog(for: critter, action: .rescue, xpDelta: xpDelta))
        try saveRewardChanges(context: context)
        return OasisCritterInteractionOutcome(
            success: true,
            action: .rescue,
            completedDailyWish: false,
            wish: wish,
            messageZh: "伙伴醒来了，带着你们过去的等级、羁绊和回忆回来。",
            messageEn: "Your companion wakes with every level, bond, and memory intact.",
            messageDe: "Dein Begleiter wacht mit allen Leveln, Bindungen und Erinnerungen auf.",
            rewardXP: xpDelta,
            rewardBond: 4,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }
}
