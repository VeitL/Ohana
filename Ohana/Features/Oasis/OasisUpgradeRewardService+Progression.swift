//
//  OasisUpgradeRewardService+Progression.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    static func dailyWish(for critter: OasisElectronicPet, context: ModelContext, now: Date = Date()) -> OasisCritterDailyWish {
        normalizeLifecycle(for: critter, context: context, now: now)
        let snapshot = lifecycleSnapshot(for: critter, context: context, now: now)
        return displayDailyWish(for: critter, snapshot: snapshot, now: now)
    }

    static func displayDailyWish(
        for critter: OasisElectronicPet,
        snapshot: OasisCritterLifecycleSnapshot,
        now: Date = Date()
    ) -> OasisCritterDailyWish {
        if snapshot.state == .dead {
            return dailyWish(for: .rest)
        }
        if snapshot.state == .atRisk || snapshot.state == .sick || snapshot.state == .critical {
            return dailyWish(for: .rescue)
        }

        let action: OasisCritterAction
        if critter.hunger < 45 {
            action = .feed
        } else if critter.health < 70 {
            action = .rest
        } else if critter.mood < 45 {
            action = .play
        } else {
            let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? Int(now.timeIntervalSince1970 / 86400)
            let catalogScore = critter.catalogId.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            let index = abs(day + catalogScore + critter.level * 17 + critter.starLevel * 31) % 3
            action = [.feed, .play, .rest][index]
        }
        return dailyWish(for: action)
    }

    static func isDailyWishCompleted(for critter: OasisElectronicPet, wish: OasisCritterDailyWish, context: ModelContext) -> Bool {
        actionLogs(for: critter, context: context).contains { $0.action == wish.action }
    }

    static func bondLevel(for critter: OasisElectronicPet) -> Int {
        min(10, max(1, critter.bond / 100 + 1))
    }

    static func bondProgress(for critter: OasisElectronicPet) -> Int {
        max(0, min(100, critter.bond % 100))
    }

    static func appearanceStage(forLevel level: Int) -> Int {
        switch max(1, min(maxCritterLevel, level)) {
        case 1 ... 2:
            1
        case 3 ... 5:
            2
        case 6 ... 8:
            3
        case 9 ... 11:
            4
        default:
            maxCritterAppearanceStage
        }
    }

    static func xpProgress(for critter: OasisElectronicPet) -> Int {
        critter.level >= maxCritterLevel ? critterXPPerLevel : max(0, min(critterXPPerLevel, critter.xp))
    }

    static func canUpgradeLevel(for critter: OasisElectronicPet) -> Bool {
        critter.lifeState != .dead &&
            critter.level < maxCritterLevel &&
            critter.xp >= critterXPPerLevel
    }

    @discardableResult
    static func upgradeLevel(for critter: OasisElectronicPet, context: ModelContext) throws -> Bool {
        normalizeLifecycle(for: critter, context: context)
        guard canUpgradeLevel(for: critter) else { return false }
        critter.xp = 0
        critter.level = min(maxCritterLevel, critter.level + 1)
        critter.appearanceStage = appearanceStage(forLevel: critter.level)
        critter.mood = min(100, critter.mood + 10)
        critter.bond = min(999, critter.bond + 8)
        critter.lastInteractionAt = Date()
        critter.lastStateRefreshAt = Date()
        context.insert(actionLog(for: critter, action: .levelUpgrade, xpDelta: 0))
        refreshLifecycleState(for: critter, now: Date())
        try context.save()
        return true
    }

    @discardableResult
    static func addXP(_ amount: Int, to critter: OasisElectronicPet) -> Int {
        guard amount > 0, critter.level < maxCritterLevel else {
            critter.xp = critter.level >= maxCritterLevel ? 0 : max(0, min(critterXPPerLevel, critter.xp))
            critter.appearanceStage = appearanceStage(forLevel: critter.level)
            return 0
        }
        let before = max(0, min(critterXPPerLevel, critter.xp))
        let after = min(critterXPPerLevel, before + amount)
        critter.xp = after
        critter.appearanceStage = appearanceStage(forLevel: critter.level)
        return after - before
    }
}
