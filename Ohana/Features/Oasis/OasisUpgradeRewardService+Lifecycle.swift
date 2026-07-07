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
        let wasDead = critter.lifeState == .dead
        guard !wasDead else { return }

        settleElapsedNeeds(for: critter, now: now)
        refreshLifecycleState(for: critter, now: now)

        if critter.lifeState == .dead, before.lifeState != OasisCritterLifeState.dead.rawValue {
            critter.isFeaturedOnOasis = false
            if let context {
                context.insert(deathLog(for: critter, now: now))
            }
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
        let state = critter.lifeState
        let remainingHours: Int? = if state == .critical, let criticalStartedAt = critter.criticalStartedAt {
            max(0, criticalToDeathHours - hoursBetween(criticalStartedAt, now))
        } else {
            nil
        }
        let urgency = switch state {
        case .healthy: 0
        case .needsCare: 1
        case .atRisk: 2
        case .sick: 3
        case .critical: 4
        case .dead: 5
        }
        return OasisCritterLifecycleSnapshot(
            state: state,
            deathReason: critter.deathReason,
            recommendedAction: state == .dead ? .rescue : recommendedCareAction(for: critter),
            isRescuable: state == .atRisk || state == .sick || state == .critical || state == .dead,
            hoursUntilDeath: remainingHours,
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
        case .needsCare:
            if snapshot.ageDays >= elderWarningDays {
                return l.tr(
                    zh: "\(name) 最近动作慢了一点，想被轻轻陪一会儿。",
                    en: "\(name) moves a little slower lately and wants gentle company.",
                    de: "\(name) bewegt sich langsam und möchte sanfte Nähe."
                )
            }
            return l.tr(
                zh: "\(name) 轻轻碰了碰椰壳，像是在说想你了。",
                en: "\(name) taps the coconut shell softly, as if missing you.",
                de: "\(name) stupst die Kokosschale leise an, als würde es dich vermissen."
            )
        case .atRisk:
            return l.tr(
                zh: "\(name) 缩进椰壳里等一会儿，照顾一下就会缓过来。",
                en: "\(name) is curled in the coconut shell. A little care will help.",
                de: "\(name) kuschelt in der Kokosschale. Ein wenig Pflege hilft."
            )
        case .sick:
            return l.tr(
                zh: "\(name) 有点没精神，还来得及温柔地救回来。",
                en: "\(name) is low on energy, but you can still gently bring it back.",
                de: "\(name) hat wenig Energie, aber du kannst es sanft zurückholen."
            )
        case .critical:
            let hours = snapshot.hoursUntilDeath ?? criticalToDeathHours
            return l.tr(
                zh: "\(name) 真的需要你一下，约 \(hours) 小时内照顾都能救回来。",
                en: "\(name) really needs you. Care within about \(hours)h can still rescue it.",
                de: "\(name) braucht dich wirklich. Pflege innerhalb von etwa \(hours) Std. kann es retten."
            )
        case .dead:
            return l.tr(
                zh: "\(name) 正在纪念册里安静休息，轻轻照顾一下就能回来打招呼。",
                en: "\(name) is quietly resting in the memorial album. Gentle care can bring it back to say hello.",
                de: "\(name) ruht leise im Erinnerungsalbum. Sanfte Pflege kann es zurückbringen."
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

        critter.hunger = max(critter.hunger, 58)
        critter.mood = max(critter.mood, 58)
        critter.health = max(critter.health, 74)
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
            messageZh: "你轻轻照顾了一下，它慢慢从椰壳里探出头。",
            messageEn: "You gave gentle care, and it slowly peeks out of the coconut shell.",
            messageDe: "Du hast sanft geholfen, und es schaut langsam aus der Kokosschale.",
            rewardXP: xpDelta,
            rewardBond: 4,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }
}
