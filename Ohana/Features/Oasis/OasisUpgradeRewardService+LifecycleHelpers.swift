//
//  OasisUpgradeRewardService+LifecycleHelpers.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    struct LifecycleFingerprint: Equatable {
        var hunger: Int
        var mood: Int
        var health: Int
        var lifeState: String
        var deathReason: String
        var riskStartedAt: Date?
        var criticalStartedAt: Date?
        var diedAt: Date?
        var lastStateRefreshAt: Date
        var isFeaturedOnOasis: Bool
    }

    static func lifecycleFingerprint(for critter: OasisElectronicPet) -> LifecycleFingerprint {
        LifecycleFingerprint(
            hunger: critter.hunger,
            mood: critter.mood,
            health: critter.health,
            lifeState: critter.lifeStateRaw,
            deathReason: critter.deathReasonRaw,
            riskStartedAt: critter.riskStartedAt,
            criticalStartedAt: critter.criticalStartedAt,
            diedAt: critter.diedAt,
            lastStateRefreshAt: critter.lastStateRefreshAt,
            isFeaturedOnOasis: critter.isFeaturedOnOasis
        )
    }

    static func settleElapsedNeeds(for critter: OasisElectronicPet, now: Date) {
        let elapsed = max(0, now.timeIntervalSince(critter.lastStateRefreshAt))
        let ticks = Int(elapsed / lifecycleCareTick)
        guard ticks > 0 else { return }

        let start = critter.lastStateRefreshAt
        var hunger = critter.hunger
        var mood = critter.mood
        var health = critter.health

        for index in 0 ..< ticks {
            let tickDate = start.addingTimeInterval(Double(index + 1) * lifecycleCareTick)
            let idleHours = hoursBetween(critter.lastInteractionAt, tickDate)

            hunger = max(0, hunger - 3)

            if idleHours >= 24 || hunger < needsCareThreshold {
                mood = max(0, mood - (hunger < atRiskThreshold ? 3 : 2))
            }

            if hunger < atRiskThreshold || mood < atRiskThreshold {
                health = max(0, health - 2)
            } else if hunger < needsCareThreshold || mood < needsCareThreshold {
                health = max(0, health - 1)
            } else if health < 100, (index + 1).isMultiple(of: 4) {
                health = min(100, health + 1)
            }
        }

        critter.hunger = hunger
        critter.mood = mood
        critter.health = health
        critter.lastStateRefreshAt = start.addingTimeInterval(Double(ticks) * lifecycleCareTick)
    }

    static func refreshLifecycleState(for critter: OasisElectronicPet, now: Date) {
        guard critter.lifeState != .dead else { return }
        let age = ageDays(for: critter, now: now)
        if age >= oldAgeDeathDays {
            markDead(critter, reason: .oldAge, now: now)
            return
        }

        if isLowCondition(critter) {
            if critter.riskStartedAt == nil {
                critter.riskStartedAt = now
            }
            let riskHours = hoursBetween(critter.riskStartedAt ?? now, now)
            if riskHours >= riskToCriticalHours {
                if critter.criticalStartedAt == nil {
                    critter.criticalStartedAt = now
                }
                if hoursBetween(critter.criticalStartedAt ?? now, now) >= criticalToDeathHours {
                    markDead(critter, reason: deathReason(for: critter), now: now)
                    return
                }
                critter.lifeState = .critical
            } else if critter.health < sickHealthThreshold || riskHours >= 48 {
                critter.lifeState = .sick
            } else {
                critter.lifeState = .atRisk
            }
            return
        }

        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        if critter.hunger < needsCareThreshold ||
            critter.mood < needsCareThreshold ||
            critter.health < 70 ||
            age >= elderWarningDays {
            critter.lifeState = .needsCare
        } else {
            critter.lifeState = .healthy
        }
        critter.deathReason = nil
        critter.diedAt = nil
    }

    static func isLowCondition(_ critter: OasisElectronicPet) -> Bool {
        critter.hunger < atRiskThreshold ||
            critter.mood < atRiskThreshold ||
            critter.health < sickHealthThreshold
    }

    static func recommendedCareAction(for critter: OasisElectronicPet) -> OasisCritterAction? {
        guard critter.lifeState != .dead else { return nil }
        if critter.health < 70 { return .rest }
        if critter.hunger < needsCareThreshold, critter.hunger <= critter.mood { return .feed }
        if critter.mood < needsCareThreshold { return .play }
        if critter.hunger < needsCareThreshold { return .feed }
        return nil
    }

    static func deathReason(for critter: OasisElectronicPet) -> OasisCritterDeathReason {
        if critter.health <= 0 || (critter.health < sickHealthThreshold && critter.hunger < atRiskThreshold && critter.mood < atRiskThreshold) {
            return .sick
        }
        if critter.hunger < atRiskThreshold, critter.hunger <= critter.mood {
            return .hungry
        }
        if critter.mood < atRiskThreshold {
            return .bored
        }
        return .sick
    }

    static func markDead(_ critter: OasisElectronicPet, reason: OasisCritterDeathReason, now: Date) {
        critter.lifeState = .dead
        critter.deathReason = reason
        critter.diedAt = critter.diedAt ?? now
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.isFeaturedOnOasis = false
    }

    static func ageDays(for critter: OasisElectronicPet, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(critter.obtainedAt) / lifecycleDay))
    }

    static func hoursBetween(_ start: Date, _ end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 3600))
    }

    static func clampedPercent(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    static func dailyActionCount(for action: OasisCritterAction, critter: OasisElectronicPet, context: ModelContext) -> Int {
        actionLogs(for: critter, context: context).count(where: { $0.action == action })
    }

    static func actionLogs(for critter: OasisElectronicPet, context: ModelContext) -> [OasisCritterActionLog] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let logs = (try? context.fetch(FetchDescriptor<OasisCritterActionLog>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        return logs.filter {
            $0.critterId == critter.id &&
                $0.createdAt >= startOfDay
        }
    }

    struct FeedInteractionEffect {
        let hungerDelta: Int
        let moodDelta: Int
        let healthDelta: Int
        let bondDelta: Int
        let xp: Int
        let messageZh: String
        let messageEn: String
        let messageDe: String
    }

    static func feedEffect(for critter: OasisElectronicPet, dailyFeedCount: Int) -> FeedInteractionEffect {
        if critter.hunger >= 95 {
            return FeedInteractionEffect(
                hungerDelta: 0,
                moodDelta: -6,
                healthDelta: -5,
                bondDelta: 0,
                xp: 0,
                messageZh: "它已经饱饱的，继续喂有点吃撑，心情和身体都不太舒服。",
                messageEn: "It is already full. Another bite makes it uncomfortably stuffed.",
                messageDe: "Es ist schon satt. Noch ein Bissen fühlt sich unangenehm voll an."
            )
        }

        if dailyFeedCount >= 2 {
            return FeedInteractionEffect(
                hungerDelta: 8,
                moodDelta: 1,
                healthDelta: 0,
                bondDelta: 1,
                xp: 1,
                messageZh: "它有点吃撑，只小小咬了一口。",
                messageEn: "It is getting full and only takes a tiny bite.",
                messageDe: "Es wird langsam satt und nimmt nur einen kleinen Bissen."
            )
        }

        if critter.hunger >= 80 {
            return FeedInteractionEffect(
                hungerDelta: 10,
                moodDelta: 3,
                healthDelta: 2,
                bondDelta: 2,
                xp: 2,
                messageZh: "它还不太饿，慢慢把小碗推近一点。",
                messageEn: "It is not very hungry, but nudges the bowl closer.",
                messageDe: "Es ist nicht sehr hungrig, schiebt die Schale aber näher."
            )
        }

        return FeedInteractionEffect(
            hungerDelta: 24,
            moodDelta: 6,
            healthDelta: 8,
            bondDelta: 3,
            xp: 4,
            messageZh: "它抱着小碗眯起眼，精神多了一点。",
            messageEn: "It hugs the little bowl and perks up.",
            messageDe: "Es umarmt die kleine Schale und wirkt munterer."
        )
    }
}
