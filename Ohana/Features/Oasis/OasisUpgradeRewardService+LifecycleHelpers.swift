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
        var lastGentlePromptAt: Date?
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
            lastGentlePromptAt: critter.lastGentlePromptAt,
            lastStateRefreshAt: critter.lastStateRefreshAt,
            isFeaturedOnOasis: critter.isFeaturedOnOasis
        )
    }

    static func settleElapsedNeeds(for critter: OasisElectronicPet, now: Date) {
        // Compatibility hook only. V94 companions never lose condition while
        // the app is closed and no elapsed-time lifecycle task is scheduled.
        critter.lastStateRefreshAt = now
    }

    static func refreshLifecycleState(for critter: OasisElectronicPet, now: Date) {
        if critter.lifeState == .dead || critter.lifeState == .critical {
            critter.lifeState = .sleeping
            critter.isFeaturedOnOasis = false
        } else if critter.lifeState != .sleeping {
            critter.lifeState = .healthy
        }
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.deathReason = nil
        critter.diedAt = nil
        critter.lastStateRefreshAt = now
    }

    static func isLowCondition(_ critter: OasisElectronicPet) -> Bool {
        _ = critter
        return false
    }

    static func recommendedCareAction(for critter: OasisElectronicPet) -> OasisCritterAction? {
        guard critter.lifeState != .dead,
              critter.lifeState != .critical,
              critter.lifeState != .sleeping else { return nil }
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
        // Retained for old call sites and restored backups. New behavior is
        // always reversible sleep and never emits a death fact.
        _ = reason
        critter.lifeState = .sleeping
        critter.deathReason = nil
        critter.diedAt = nil
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.isFeaturedOnOasis = false
        critter.lastStateRefreshAt = now
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
        let critterId = critter.id
        let descriptor = FetchDescriptor<OasisCritterActionLog>(
            predicate: #Predicate<OasisCritterActionLog> { log in
                log.critterId == critterId && log.createdAt >= startOfDay
            }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch daily action logs for critterId=\(critterId.uuidString): \(error.localizedDescription)",
                category: "Oasis"
            )
            return []
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
