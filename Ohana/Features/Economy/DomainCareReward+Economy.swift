//
//  DomainCareReward+Economy.swift
//  Ohana
//
//  Economy feature interpretation for domain-neutral reward payloads.
//

import Foundation

extension DomainCareRewardAction {
    var baseRewards: (human: Int, pet: Int) {
        switch self {
        case let .walk(distanceMeters):
            let total = CoconutWalkRewardPolicy.baseCoconuts(for: distanceMeters)
            return CoconutWalkRewardPolicy.splitCoconuts(total: total)
        case let .potty(isLitter):
            return isLitter ? (2, 1) : (1, 1)
        case .feed:
            return (2, 1)
        case .water:
            return (2, 1)
        case let .care(type):
            switch type {
            case .bath: return (6, 2)
            case .teeth: return (4, 2)
            case .nails: return (4, 2)
            case .brushing: return (3, 2)
            case .ears: return (4, 2)
            }
        case .health:
            return (8, 2)
        case .expense:
            return (2, 0)
        case .weight:
            return (3, 1)
        case .milestone:
            return (2, 1)
        case .dailyFocusCompletion:
            return (8, 0)
        case .plantWatering:
            return (2, 0)
        case .plantFertilizing:
            return (3, 0)
        case let .general(humanReward, petReward, _, _):
            return (humanReward, petReward)
        }
    }

    var emoji: String {
        switch self {
        case .walk: "🦮"
        case let .potty(isLitter): isLitter ? "🧹" : "💩"
        case .feed: "🍗"
        case .water: "💧"
        case let .care(type):
            switch type {
            case .bath: "🛁"
            case .teeth: "🦷"
            case .nails: "✂️"
            case .brushing: "🪮"
            case .ears: "👂"
            }
        case .health: "💉"
        case .expense: "💰"
        case .weight: "⚖️"
        case .milestone: "🏆"
        case .dailyFocusCompletion: "🎯"
        case .plantWatering: "💧"
        case .plantFertilizing: "🌿"
        case let .general(_, _, emoji, _): emoji
        }
    }

    func title(pet: Pet?, l: L10n = .current) -> String {
        let name = pet?.name ?? ""
        switch self {
        case .walk:
            return l.tr(zh: "\(name) 遛狗奖励", en: "\(name) walk reward", de: "\(name) Spaziergang-Bonus")
        case let .potty(isLitter):
            return isLitter
                ? l.tr(zh: "\(name) 铲砂奖励", en: "\(name) scoop reward", de: "\(name) Klo-Bonus")
                : l.tr(zh: "\(name) 噗噗打卡", en: "\(name) poop check-in", de: "\(name) Häufchen-Check-in")
        case .feed:
            return l.tr(zh: "\(name) 喂食奖励", en: "\(name) feeding reward", de: "\(name) Futter-Bonus")
        case .water:
            return l.tr(zh: "\(name) 喂水奖励", en: "\(name) water reward", de: "\(name) Wasser-Bonus")
        case let .care(type):
            switch type {
            case .bath:
                return l.tr(zh: "\(name) 洗澡奖励", en: "\(name) bath reward", de: "\(name) Bade-Bonus")
            case .teeth:
                return l.tr(zh: "\(name) 刷牙奖励", en: "\(name) teeth care reward", de: "\(name) Zahnpflege-Bonus")
            case .nails:
                return l.tr(zh: "\(name) 剪甲奖励", en: "\(name) nail care reward", de: "\(name) Krallenpflege-Bonus")
            case .brushing:
                return l.tr(zh: "\(name) 梳毛奖励", en: "\(name) brushing reward", de: "\(name) Fellpflege-Bonus")
            case .ears:
                return l.tr(zh: "\(name) 清耳奖励", en: "\(name) ear care reward", de: "\(name) Ohrenpflege-Bonus")
            }
        case .health:
            return l.tr(zh: "\(name) 健康打卡奖励", en: "\(name) health check-in reward", de: "\(name) Gesundheits-Check-in-Bonus")
        case .expense:
            return l.tr(zh: "记账奖励", en: "Expense reward", de: "Ausgaben-Bonus")
        case .weight:
            guard !name.isEmpty else {
                return l.tr(zh: "体重记录奖励", en: "Weight log reward", de: "Gewichtslog-Bonus")
            }
            return l.tr(zh: "\(name) 体重记录奖励", en: "\(name) weight log reward", de: "\(name) Gewichtslog-Bonus")
        case .milestone:
            return l.tr(zh: "\(name) 里程碑达成", en: "\(name) milestone reached", de: "\(name) Meilenstein erreicht")
        case .dailyFocusCompletion:
            return l.tr(zh: "Today Focus 全完成", en: "Today Focus complete", de: "Today Focus abgeschlossen")
        case .plantWatering:
            return l.tr(zh: "浇水奖励", en: "Plant watering reward", de: "Pflanzen-Gießbonus")
        case .plantFertilizing:
            return l.tr(zh: "施肥奖励", en: "Plant fertilizing reward", de: "Pflanzen-Düngebonus")
        case let .general(_, _, _, title):
            return DomainCareRewardGeneralTitle.localized(title, fallbackActorName: pet?.name, l: l) ?? title
        }
    }
}

enum DomainCareRewardGeneralTitle {
    static let petCarePlay = "reward.petCare.play"
    static let petCareFilterClean = "reward.petCare.filterClean"
    static let petCareCageCleaning = "reward.petCare.cageCleaning"
    static let petCareFreeFlight = "reward.petCare.freeFlight"
    static let petCareMisting = "reward.petCare.misting"
    static let petCareSubstrateChange = "reward.petCare.substrateChange"
    static let petCareWaterChange = "reward.petCare.waterChange"
    static let sharedWaterChange = "reward.shared.waterChange"
    static let sharedFilterClean = "reward.shared.filterClean"
    static let sharedPlay = "reward.shared.play"
    static let questFirstMeal = "reward.quest.firstMeal"
    static let questThemeColor = "reward.quest.themeColor"
    static let questDailyStepGoal = "reward.quest.dailyStepGoal"
    static let questBondedWalk = "reward.quest.bondedWalk"
    static let exchangeRequest = "wallet.exchange.request"
    static let exchangeRefund = "wallet.exchange.refund"
    static let oasisHarvestedCoconut = "reward.oasis.harvestedCoconut"
    static let oasisTreeGift = "reward.oasis.treeGift"
    static let oasisDailyCheckIn = "reward.oasis.dailyCheckIn"
    static let oasisCheckInStreak = "reward.oasis.checkInStreak"
    static let oasisUpgradeCoconut = "reward.oasis.upgradeCoconut"
    static let oasisCritterDailyWish = "reward.oasis.critterDailyWish"
    static let oasisCritterFeed = "wallet.oasis.critterFeed"
    static let oasisCritterPlay = "wallet.oasis.critterPlay"
    static let oasisCritterRest = "wallet.oasis.critterRest"
    static let oasisCritterStarUpgrade = "wallet.oasis.critterStarUpgrade"
    static let oasisCritterAwaken = "wallet.oasis.critterAwaken"
    static let oasisTreeEnergyLarge = "wallet.oasis.treeEnergyLarge"
    static let oasisTreeEnergyStarter = "wallet.oasis.treeEnergyStarter"
    static let momentCapture = "reward.moment.capture"
    static let familyTaskComplete = "reward.familyTask.complete"
    static let familyTaskRewardPaid = "wallet.familyTask.rewardPaid"
    static let familyTaskRewardReceived = "wallet.familyTask.rewardReceived"

    private static let separator = "::"

    static func scoped(_ key: String, petName: String) -> String {
        "\(key)\(separator)\(petName)"
    }

    static func counted(_ key: String, count: Int) -> String {
        "\(key)\(separator)\(count)"
    }

    static func baseKey(_ title: String) -> String {
        title.components(separatedBy: separator).first ?? title
    }

    static func localized(_ title: String, fallbackActorName: String? = nil, l: L10n) -> String? {
        let key = baseKey(title)
        let petName = scopedValue(from: title) ?? fallbackActorName ?? legacyPetName(from: title)

        switch key {
        case petCarePlay:
            return namedReward(petName: petName, zh: "互动奖励", en: "play reward", de: "Spiel-Bonus", l: l)
        case petCareFilterClean:
            return namedReward(petName: petName, zh: "清理滤材报酬", en: "filter cleaning reward", de: "Filterreinigungs-Bonus", l: l)
        case petCareCageCleaning:
            return namedReward(petName: petName, zh: "清理鸟笼奖励", en: "cage cleaning reward", de: "Käfigreinigungs-Bonus", l: l)
        case petCareFreeFlight:
            return namedReward(petName: petName, zh: "放飞互动奖励", en: "free-flight reward", de: "Freiflug-Bonus", l: l)
        case petCareMisting:
            return namedReward(petName: petName, zh: "保湿打卡奖励", en: "misting reward", de: "Befeuchtungs-Bonus", l: l)
        case petCareSubstrateChange:
            return namedReward(petName: petName, zh: "环境清洁奖励", en: "habitat cleaning reward", de: "Habitatreinigungs-Bonus", l: l)
        case petCareWaterChange:
            return namedReward(petName: petName, zh: "换水奖励", en: "water change reward", de: "Wasserwechsel-Bonus", l: l)
        case sharedWaterChange:
            return sharedReward(title, zh: "共同换水", en: "Shared water change", de: "Gemeinsamer Wasserwechsel", l: l)
        case sharedFilterClean:
            return sharedReward(title, zh: "共同清理滤材", en: "Shared filter cleaning", de: "Gemeinsame Filterreinigung", l: l)
        case sharedPlay:
            return sharedReward(title, zh: "共同陪玩", en: "Shared play", de: "Gemeinsames Spielen", l: l)
        case questFirstMeal:
            return l.tr(zh: "首次喜食打卡奖励", en: "First meal check-in reward", de: "Bonus für den ersten Futtereintrag")
        case questThemeColor:
            return l.tr(zh: "设置家人主题色", en: "Family theme color set", de: "Familien-Akzentfarbe gesetzt")
        case questDailyStepGoal:
            return l.tr(zh: "今日步数达标奖励", en: "Daily step goal reward", de: "Bonus für Tages-Schrittziel")
        case questBondedWalk:
            return l.tr(zh: "人宠同行奖励", en: "Human-pet walk reward", de: "Mensch-Tier-Gehbonus")
        case exchangeRequest:
            return l.tr(zh: "货币兑换申请", en: "Currency exchange request", de: "Währungsumtausch-Anfrage")
        case exchangeRefund:
            return l.tr(zh: "货币兑换取消退款", en: "Currency exchange cancellation refund", de: "Rueckerstattung fuer abgebrochenen Umtausch")
        case oasisHarvestedCoconut:
            return payloadCount(title).map {
                l.tr(zh: "摘下椰子 +\($0)🥥", en: "Harvested coconuts +\($0)🥥", de: "Kokosnüsse geerntet +\($0)🥥")
            } ?? l.tr(zh: "摘下椰子", en: "Harvested coconuts", de: "Kokosnüsse geerntet")
        case oasisTreeGift:
            return payloadCount(title).map {
                l.tr(zh: "生命之树的馈赠 +\($0)🥥", en: "Life Tree gift +\($0)🥥", de: "Lebensbaum-Gabe +\($0)🥥")
            } ?? l.tr(zh: "生命之树的馈赠", en: "Life Tree gift", de: "Lebensbaum-Gabe")
        case oasisDailyCheckIn:
            return l.tr(zh: "每日打卡奖励", en: "Daily check-in reward", de: "Taeglicher Check-in-Bonus")
        case oasisCheckInStreak:
            return payloadCount(title).map {
                l.tr(zh: "\($0)天连胜奖励", en: "\($0)-day streak reward", de: "\($0)-Tage-Serienbonus")
            } ?? l.tr(zh: "连胜奖励", en: "Streak reward", de: "Serienbonus")
        case oasisUpgradeCoconut:
            return payloadCount(title).map {
                l.tr(zh: "升级椰子 Lv.\($0)", en: "Upgrade coconut Lv.\($0)", de: "Upgrade-Kokosnuss Lv.\($0)")
            } ?? l.tr(zh: "升级椰子", en: "Upgrade coconut", de: "Upgrade-Kokosnuss")
        case oasisCritterDailyWish:
            return l.tr(zh: "电子宠物小愿望", en: "Critter daily wish", de: "Begleiter-Tageswunsch")
        case oasisCritterFeed:
            return l.tr(zh: "喂养电子宠物", en: "Feed critter", de: "Begleiter fuettern")
        case oasisCritterPlay:
            return l.tr(zh: "陪电子宠物玩耍", en: "Play with critter", de: "Mit Begleiter spielen")
        case oasisCritterRest:
            return l.tr(zh: "电子宠物休息", en: "Critter rest", de: "Begleiter ruhen lassen")
        case oasisCritterStarUpgrade:
            return l.tr(zh: "电子宠物升星", en: "Critter star upgrade", de: "Begleiter-Sternupgrade")
        case oasisCritterAwaken:
            return l.tr(zh: "碎片唤醒电子宠物", en: "Awaken critter with fragments", de: "Begleiter mit Fragmenten wecken")
        case oasisTreeEnergyLarge:
            return payloadCount(title).map {
                l.tr(zh: "生命之树能量包 +\($0)XP", en: "Life Tree energy pack +\($0)XP", de: "Lebensbaum-Energiepaket +\($0)XP")
            } ?? l.tr(zh: "生命之树能量包", en: "Life Tree energy pack", de: "Lebensbaum-Energiepaket")
        case oasisTreeEnergyStarter:
            return payloadCount(title).map {
                l.tr(zh: "注入生命之树能量 +\($0)XP", en: "Inject Life Tree energy +\($0)XP", de: "Lebensbaum-Energie geben +\($0)XP")
            } ?? l.tr(zh: "注入生命之树能量", en: "Inject Life Tree energy", de: "Lebensbaum-Energie geben")
        case momentCapture:
            return l.tr(zh: "记录时刻 +1🥥", en: "Moment captured +1🥥", de: "Moment festgehalten +1🥥")
        case familyTaskComplete:
            return l.tr(zh: "完成家庭任务", en: "Family task completed", de: "Familienaufgabe erledigt")
        case familyTaskRewardPaid:
            return l.tr(zh: "家庭任务悬赏支付", en: "Family task bounty paid", de: "Familienaufgaben-Bonus bezahlt")
        case familyTaskRewardReceived:
            return l.tr(zh: "家庭任务悬赏收入", en: "Family task bounty received", de: "Familienaufgaben-Bonus erhalten")
        default:
            return localizedLegacyTitle(title, l: l)
        }
    }

    static func isLitterRewardTitle(_ title: String) -> Bool {
        title.contains("铲砂") || title.contains("铲屎") || title.contains("litter") || title.contains("scoop")
    }

    static func isPlayRewardTitle(_ title: String) -> Bool {
        let key = baseKey(title)
        return key == petCarePlay || key == sharedPlay || title.contains("陪玩") || title.contains("逗玩") || title.contains("play")
    }

    private static func scopedValue(from title: String) -> String? {
        let parts = title.components(separatedBy: separator)
        guard parts.count >= 2 else { return nil }
        return parts.dropFirst().joined(separator: separator)
    }

    private static func namedReward(petName: String?, zh: String, en: String, de: String, l: L10n) -> String {
        guard let petName, !petName.isEmpty else {
            return l.tr(zh: zh, en: en.capitalized, de: de.capitalized)
        }
        return l.tr(zh: "\(petName) \(zh)", en: "\(petName) \(en)", de: "\(petName) \(de)")
    }

    private static func sharedReward(_ title: String, zh: String, en: String, de: String, l: L10n) -> String {
        let countText = scopedValue(from: title)
        if let countText, let count = Int(countText) {
            return l.tr(zh: "\(zh) · \(count)只", en: "\(en) · \(count)", de: "\(de) · \(count)")
        }
        return l.tr(zh: zh, en: en, de: de)
    }

    private static func localizedLegacyTitle(_ title: String, l: L10n) -> String? {
        let legacy: [(suffix: String, zh: String, en: String, de: String)] = [
            ("互动奖励", "互动奖励", "play reward", "Spiel-Bonus"),
            ("清理滤材报酬", "清理滤材报酬", "filter cleaning reward", "Filterreinigungs-Bonus"),
            ("清理鸟笼奖励", "清理鸟笼奖励", "cage cleaning reward", "Käfigreinigungs-Bonus"),
            ("放飞互动奖励", "放飞互动奖励", "free-flight reward", "Freiflug-Bonus"),
            ("保湿打卡奖励", "保湿打卡奖励", "misting reward", "Befeuchtungs-Bonus"),
            ("环境清洁奖励", "环境清洁奖励", "habitat cleaning reward", "Habitatreinigungs-Bonus"),
            ("换水奖励", "换水奖励", "water change reward", "Wasserwechsel-Bonus")
        ]
        for item in legacy where title.hasSuffix(item.suffix) {
            return namedReward(petName: legacyPetName(from: title, removing: item.suffix), zh: item.zh, en: item.en, de: item.de, l: l)
        }
        if title.hasPrefix("共同换水") {
            return localizedSharedLegacy(title, zh: "共同换水", en: "Shared water change", de: "Gemeinsamer Wasserwechsel", l: l)
        }
        if title.hasPrefix("共同清理滤材") {
            return localizedSharedLegacy(title, zh: "共同清理滤材", en: "Shared filter cleaning", de: "Gemeinsame Filterreinigung", l: l)
        }
        if title.hasPrefix("共同陪玩") {
            return localizedSharedLegacy(title, zh: "共同陪玩", en: "Shared play", de: "Gemeinsames Spielen", l: l)
        }
        switch title {
        case "首次喜食打卡奖励":
            return localized(questFirstMeal, l: l)
        case "设置家人主题色":
            return localized(questThemeColor, l: l)
        case "今日步数达标奖励":
            return localized(questDailyStepGoal, l: l)
        case "人宠同行奖励":
            return localized(questBondedWalk, l: l)
        case "货币兑换申请":
            return localized(exchangeRequest, l: l)
        case "货币兑换取消退款":
            return localized(exchangeRefund, l: l)
        case "每日打卡奖励":
            return localized(oasisDailyCheckIn, l: l)
        case "电子宠物小愿望":
            return localized(oasisCritterDailyWish, l: l)
        case "喂养电子宠物":
            return localized(oasisCritterFeed, l: l)
        case "陪电子宠物玩耍":
            return localized(oasisCritterPlay, l: l)
        case "电子宠物休息":
            return localized(oasisCritterRest, l: l)
        case "电子宠物升星":
            return localized(oasisCritterStarUpgrade, l: l)
        case "碎片唤醒电子宠物":
            return localized(oasisCritterAwaken, l: l)
        case "记录时刻 +1🥥":
            return localized(momentCapture, l: l)
        case "完成家庭任务":
            return localized(familyTaskComplete, l: l)
        case "家庭任务悬赏支付":
            return localized(familyTaskRewardPaid, l: l)
        case "家庭任务悬赏收入":
            return localized(familyTaskRewardReceived, l: l)
        default:
            break
        }
        if title.hasPrefix("摘下椰子") {
            return localized(counted(oasisHarvestedCoconut, count: firstNumber(in: title)), l: l)
        }
        if title.hasPrefix("生命之树的馈赠") {
            return localized(counted(oasisTreeGift, count: firstNumber(in: title)), l: l)
        }
        if title.hasPrefix("升级椰子 Lv.") {
            return localized(counted(oasisUpgradeCoconut, count: firstNumber(in: title)), l: l)
        }
        if title.hasSuffix("天连胜奖励") {
            return localized(counted(oasisCheckInStreak, count: firstNumber(in: title)), l: l)
        }
        if title.hasPrefix("生命之树能量包") {
            return localized(counted(oasisTreeEnergyLarge, count: firstNumber(in: title)), l: l)
        }
        if title.hasPrefix("注入生命之树能量") {
            return localized(counted(oasisTreeEnergyStarter, count: firstNumber(in: title)), l: l)
        }
        return nil
    }

    private static func localized(_ key: String, l: L10n) -> String? {
        localized(key, fallbackActorName: nil, l: l)
    }

    private static func localizedSharedLegacy(_ title: String, zh: String, en: String, de: String, l: L10n) -> String {
        let count = firstNumber(in: title)
        if count > 0 {
            return l.tr(zh: "\(zh) · \(count)只", en: "\(en) · \(count)", de: "\(de) · \(count)")
        }
        return l.tr(zh: zh, en: en, de: de)
    }

    private static func legacyPetName(from title: String, removing suffix: String? = nil) -> String? {
        let cleaned = suffix.map { title.replacingOccurrences(of: $0, with: "") } ?? title
        let name = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func payloadCount(_ title: String) -> Int? {
        guard let value = scopedValue(from: title) else { return nil }
        return Int(value)
    }

    private static func firstNumber(in title: String) -> Int {
        var digits = ""
        for character in title {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits) ?? 0
    }
}

extension DomainCareRewardQuality {
    var multiplier: Double {
        switch self {
        case .none: 1.0
        case .precise: 1.1
        case .withNote: 1.1
        case .withPhoto: 1.1
        case .preciseAndNote: 1.2
        case .preciseAndPhoto: 1.2
        case .preciseNotePhoto: 1.3
        }
    }

    var badgeLabel: String? {
        badgeLabel(l: .current)
    }

    func badgeLabel(l: L10n = .current) -> String? {
        switch self {
        case .none: nil
        case .precise:
            l.tr(zh: "🎯 精准XP+10%", en: "🎯 Precise XP+10%", de: "🎯 Präzise XP+10%")
        case .withNote:
            l.tr(zh: "📝 备注XP+10%", en: "📝 Note XP+10%", de: "📝 Notiz XP+10%")
        case .withPhoto:
            l.tr(zh: "📷 照片XP+10%", en: "📷 Photo XP+10%", de: "📷 Foto XP+10%")
        case .preciseAndNote:
            l.tr(zh: "🎯📝 XP+20%", en: "🎯📝 XP+20%", de: "🎯📝 XP+20%")
        case .preciseAndPhoto:
            l.tr(zh: "🎯📷 XP+20%", en: "🎯📷 XP+20%", de: "🎯📷 XP+20%")
        case .preciseNotePhoto:
            l.tr(zh: "✨ 完整记录XP+30%", en: "✨ Complete log XP+30%", de: "✨ Vollständiger Eintrag XP+30%")
        }
    }
}
