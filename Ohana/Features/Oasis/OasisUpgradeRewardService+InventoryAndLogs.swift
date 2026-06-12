//
//  OasisUpgradeRewardService+InventoryAndLogs.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    static func ownsCritter(_ catalogId: String, context: ModelContext) -> Bool {
        activeCritter(catalogId: catalogId, context: context) != nil
    }

    static func addFragments(critterId: String, amount: Int, context: ModelContext) {
        guard amount > 0 else { return }
        if let balance = fragmentBalance(critterId: critterId, context: context) {
            balance.amount += amount
            balance.updatedAt = Date()
        } else {
            context.insert(OasisCritterFragmentBalance(catalogId: critterId, amount: amount))
        }
    }

    static func fragmentBalance(critterId: String, context: ModelContext) -> OasisCritterFragmentBalance? {
        let catalogId = critterId
        var descriptor = FetchDescriptor<OasisCritterFragmentBalance>(
            predicate: #Predicate<OasisCritterFragmentBalance> { balance in
                balance.catalogId == catalogId
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch fragment balance for critterId=\(catalogId): \(error.localizedDescription)",
                category: "Oasis"
            )
            return nil
        }
    }

    static func unlock(id: String, kind: OasisUpgradeRewardKind, sourceLevel: Int, context: ModelContext) {
        let unlockId = id
        let kindRaw = kind.rawValue
        var descriptor = FetchDescriptor<OasisUnlock>(
            predicate: #Predicate<OasisUnlock> { unlock in
                unlock.unlockId == unlockId && unlock.unlockKindRaw == kindRaw
            }
        )
        descriptor.fetchLimit = 1
        do {
            guard try context.fetch(descriptor).isEmpty else { return }
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch unlock id=\(unlockId) kind=\(kindRaw): \(error.localizedDescription)",
                category: "Oasis"
            )
            return
        }
        context.insert(OasisUnlock(unlockId: id, unlockKind: kind, sourceLevel: sourceLevel))
    }

    static func activeCritter(catalogId: String, context: ModelContext) -> OasisElectronicPet? {
        let id = catalogId
        var descriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { critter in
                critter.catalogId == id && !critter.isArchived
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch active critter catalogId=\(id): \(error.localizedDescription)",
                category: "Oasis"
            )
            return nil
        }
    }

    static func hasFeaturedCritter(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { critter in
                critter.isFeaturedOnOasis && !critter.isArchived
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try !(context.fetch(descriptor)).isEmpty
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch featured critter: \(error.localizedDescription)",
                category: "Oasis"
            )
            return false
        }
    }

    static func allElectronicPets(context: ModelContext) -> [OasisElectronicPet] {
        do {
            return try context.fetch(FetchDescriptor<OasisElectronicPet>())
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch electronic pets: \(error.localizedDescription)",
                category: "Oasis"
            )
            return []
        }
    }

    static func activeCritters(context: ModelContext) -> [OasisElectronicPet] {
        let descriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { critter in
                !critter.isArchived
            }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch active critters: \(error.localizedDescription)",
                category: "Oasis"
            )
            return []
        }
    }

    static func dailyWish(for action: OasisCritterAction) -> OasisCritterDailyWish {
        switch action {
        case .feed:
            OasisCritterDailyWish(
                id: "daily_feed",
                action: .feed,
                icon: "fork.knife",
                titleZh: "想喝一点椰奶",
                titleEn: "Wants coconut milk",
                titleDe: "Möchte Kokosmilch",
                detailZh: "喂养一次，把今天的小肚子填得软软的。",
                detailEn: "Feed once and fill today's tiny belly.",
                detailDe: "Einmal füttern und den kleinen Bauch füllen.",
                rewardXP: 6,
                rewardBond: 6,
                rewardFragments: 1,
                rewardCoconuts: 3
            )
        case .play:
            OasisCritterDailyWish(
                id: "daily_play",
                action: .play,
                icon: "sparkles",
                titleZh: "想玩星星捉迷藏",
                titleEn: "Wants star hide-and-seek",
                titleDe: "Möchte Stern-Verstecken",
                detailZh: "陪它玩一次，心情会亮起来。",
                detailEn: "Play once and brighten its mood.",
                detailDe: "Einmal spielen und die Stimmung aufhellen.",
                rewardXP: 6,
                rewardBond: 6,
                rewardFragments: 1,
                rewardCoconuts: 3
            )
        case .rest:
            OasisCritterDailyWish(
                id: "daily_rest",
                action: .rest,
                icon: "moon.fill",
                titleZh: "想窝进椰壳午睡",
                titleEn: "Wants a coconut-shell nap",
                titleDe: "Möchte Kokosschalen-Schlaf",
                detailZh: "让它休息一次，醒来会更黏人。",
                detailEn: "Let it rest once and wake up closer.",
                detailDe: "Einmal ruhen lassen, danach ist es anhänglicher.",
                rewardXP: 6,
                rewardBond: 6,
                rewardFragments: 1,
                rewardCoconuts: 3
            )
        case .rescue:
            OasisCritterDailyWish(
                id: "daily_rescue",
                action: .rescue,
                icon: "cross.case.fill",
                titleZh: "想被轻轻照顾一下",
                titleEn: "Wants gentle care",
                titleDe: "Möchte sanfte Pflege",
                detailZh: "点一键照顾，把它从椰壳里温柔地带回来。",
                detailEn: "Use one-tap care and gently bring it back from the coconut shell.",
                detailDe: "Nutze Ein-Klick-Pflege und hol es sanft aus der Kokosschale.",
                rewardXP: 3,
                rewardBond: 4,
                rewardFragments: 0,
                rewardCoconuts: 0
            )
        case .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            dailyWish(for: .play)
        }
    }

    static func failedInteraction(action: OasisCritterAction, wish: OasisCritterDailyWish) -> OasisCritterInteractionOutcome {
        OasisCritterInteractionOutcome(
            success: false,
            action: action,
            completedDailyWish: false,
            wish: wish,
            messageZh: "现在还不能这样互动。",
            messageEn: "This interaction is not available right now.",
            messageDe: "Diese Interaktion ist gerade nicht verfügbar.",
            rewardXP: 0,
            rewardBond: 0,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    static func deadInteractionOutcome(for critter: OasisElectronicPet, action: OasisCritterAction) -> OasisCritterInteractionOutcome {
        let reason = critter.deathReasonRaw
        let reasonZh: String
        let reasonEn: String
        let reasonDe: String
        switch OasisCritterDeathReason(rawValue: reason) {
        case .hungry:
            reasonZh = "太久没有吃东西"
            reasonEn = "too long without food"
            reasonDe = "zu lange ohne Futter"
        case .sick:
            reasonZh = "久病没有恢复"
            reasonEn = "illness that was not healed"
            reasonDe = "Krankheit ohne Erholung"
        case .bored:
            reasonZh = "太久没有陪伴"
            reasonEn = "too long without company"
            reasonDe = "zu lange ohne Gesellschaft"
        case .oldAge:
            reasonZh = "自然老去"
            reasonEn = "old age"
            reasonDe = "Alter"
        case .none:
            reasonZh = "生命已经结束"
            reasonEn = "life has ended"
            reasonDe = "das Leben ist zu Ende"
        }
        return OasisCritterInteractionOutcome(
            success: false,
            action: action,
            completedDailyWish: false,
            wish: nil,
            messageZh: "它已经进入纪念册，原因是\(reasonZh)。",
            messageEn: "It is now in the memorial album because of \(reasonEn).",
            messageDe: "Es ist jetzt im Erinnerungsalbum wegen \(reasonDe).",
            rewardXP: 0,
            rewardBond: 0,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    static func interactionOutcome(action: OasisCritterAction, wish: OasisCritterDailyWish, completedWish: Bool) -> OasisCritterInteractionOutcome {
        if completedWish {
            return OasisCritterInteractionOutcome(
                success: true,
                action: action,
                completedDailyWish: true,
                wish: wish,
                messageZh: "完成今日小愿望，它更信任你了。",
                messageEn: "Tiny wish complete. It trusts you a little more.",
                messageDe: "Kleiner Wunsch erfüllt. Es vertraut dir etwas mehr.",
                rewardXP: wish.rewardXP,
                rewardBond: wish.rewardBond,
                rewardFragments: wish.rewardFragments,
                rewardCoconuts: wish.rewardCoconuts
            )
        }

        let message: (zh: String, en: String, de: String) = switch action {
        case .feed:
            ("它抱着小碗眯起眼，精神多了一点。", "It hugs the little bowl and perks up.", "Es umarmt die kleine Schale und wirkt munterer.")
        case .play:
            ("它追着小星星转了一圈，心情亮起来。", "It chases a tiny star and brightens up.", "Es jagt einen kleinen Stern und strahlt mehr.")
        case .rest:
            ("它缩进小窝，睡出一朵软软的梦。", "It curls into the nest and dreams softly.", "Es rollt sich im Nest ein und träumt sanft.")
        case .rescue:
            ("你轻轻照顾了一下，它从椰壳里探出头。", "You gave gentle care, and it peeks out.", "Du hast sanft geholfen, und es schaut heraus.")
        case .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            ("互动完成。", "Interaction complete.", "Interaktion abgeschlossen.")
        }
        return OasisCritterInteractionOutcome(
            success: true,
            action: action,
            completedDailyWish: false,
            wish: wish,
            messageZh: message.zh,
            messageEn: message.en,
            messageDe: message.de,
            rewardXP: 0,
            rewardBond: 0,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    static func openedResult(for coconut: OasisUpgradeCoconut, duplicate: Bool) -> OasisOpenedUpgradeReward {
        if duplicate, let critterId = coconut.guaranteedCritterId,
           let entry = OasisUpgradeRewardCatalog.critter(id: critterId) {
            return OasisOpenedUpgradeReward(
                level: coconut.level,
                kind: .fragments,
                critterCatalogId: nil,
                titleZh: "重复伙伴转为碎片",
                titleEn: "Duplicate Became Fragments",
                titleDe: "Duplikat wurde Fragmente",
                detailZh: "\(entry.nameZh) 已拥有，已转为碎片与纪念装饰。",
                detailEn: "\(entry.nameEn) is owned, so you received fragments and decor.",
                detailDe: "\(entry.nameDe) ist schon da, daher gab es Fragmente und Deko.",
                emoji: "✨",
                isMilestoneCritter: false
            )
        }

        let emoji: String = switch coconut.rewardKind {
        case .electronicPet: OasisUpgradeRewardCatalog.critter(id: coconut.guaranteedCritterId ?? "")?.emoji ?? "✨"
        case .decoration: "🪴"
        case .fragments: "◇"
        case .storyStyle: "📖"
        case .treeEnergy: "⚡"
        case .temporaryEffect: "✦"
        case .coconuts: "🥥"
        }
        return OasisOpenedUpgradeReward(
            level: coconut.level,
            kind: coconut.rewardKind,
            critterCatalogId: coconut.rewardKind == .electronicPet ? coconut.guaranteedCritterId : nil,
            titleZh: coconut.titleZh,
            titleEn: coconut.titleEn,
            titleDe: coconut.titleDe,
            detailZh: coconut.descriptionZh,
            detailEn: coconut.descriptionEn,
            detailDe: coconut.descriptionDe,
            emoji: emoji,
            isMilestoneCritter: coconut.rewardKind == .electronicPet
        )
    }

    static func actionLog(
        for critter: OasisElectronicPet,
        action: OasisCritterAction,
        coconutDelta: Int = 0,
        fragmentDelta: Int = 0,
        xpDelta: Int = 0
    ) -> OasisCritterActionLog {
        let note: (zh: String, en: String, de: String) = switch action {
        case .feed:
            ("喂养伙伴", "Fed companion", "Begleiter gefüttert")
        case .play:
            ("陪伙伴玩耍", "Played with companion", "Mit Begleiter gespielt")
        case .rest:
            ("伙伴休息", "Companion rested", "Begleiter hat geruht")
        case .rescue:
            ("温柔救回伙伴", "Gently rescued companion", "Begleiter sanft gerettet")
        case .levelUpgrade:
            ("伙伴升级", "Companion level up", "Begleiter-Levelaufstieg")
        case .starUpgrade:
            ("伙伴升星", "Companion star upgrade", "Begleiter-Sternupgrade")
        case .unlock:
            ("伙伴解锁", "Companion unlocked", "Begleiter freigeschaltet")
        case .fragmentAwaken:
            ("碎片唤醒", "Fragment awakening", "Fragment-Weckung")
        case .feature:
            ("设为主页展示", "Featured on home", "Auf Start gezeigt")
        case .careEcho:
            ("照护共鸣", "Care echo", "Pflege-Echo")
        case .death:
            ("伙伴进入纪念册", "Companion entered the memorial album", "Begleiter kam ins Erinnerungsalbum")
        }
        return OasisCritterActionLog(
            critterId: critter.id,
            critterCatalogId: critter.catalogId,
            action: action,
            coconutDelta: coconutDelta,
            fragmentDelta: fragmentDelta,
            xpDelta: xpDelta,
            sourceLevel: critter.sourceLevel,
            noteZh: note.zh,
            noteEn: note.en,
            noteDe: note.de
        )
    }

    static func deathLog(for critter: OasisElectronicPet, now: Date) -> OasisCritterActionLog {
        let reason = critter.deathReason
        let reasonZh: String
        let reasonEn: String
        let reasonDe: String
        switch reason {
        case .hungry:
            reasonZh = "太久没有吃东西"
            reasonEn = "too long without food"
            reasonDe = "zu lange ohne Futter"
        case .sick:
            reasonZh = "久病没有恢复"
            reasonEn = "illness that was not healed"
            reasonDe = "Krankheit ohne Erholung"
        case .bored:
            reasonZh = "太久没有陪伴"
            reasonEn = "too long without company"
            reasonDe = "zu lange ohne Gesellschaft"
        case .oldAge:
            reasonZh = "自然老去"
            reasonEn = "old age"
            reasonDe = "Alter"
        case .none:
            reasonZh = "生命结束"
            reasonEn = "life ended"
            reasonDe = "das Leben endete"
        }
        return OasisCritterActionLog(
            critterId: critter.id,
            critterCatalogId: critter.catalogId,
            action: .death,
            createdAt: now,
            sourceLevel: critter.sourceLevel,
            noteZh: "伙伴进入纪念册：\(reasonZh)",
            noteEn: "Companion entered the memorial album: \(reasonEn).",
            noteDe: "Begleiter kam ins Erinnerungsalbum: \(reasonDe)."
        )
    }
}
