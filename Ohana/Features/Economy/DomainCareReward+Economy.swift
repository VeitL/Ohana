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
            return l.tr(zh: "\(name) 体重记录奖励", en: "\(name) weight log reward", de: "\(name) Gewichtslog-Bonus")
        case .milestone:
            return l.tr(zh: "\(name) 里程碑达成", en: "\(name) milestone reached", de: "\(name) Meilenstein erreicht")
        case .dailyFocusCompletion:
            return l.tr(zh: "Today Focus 全完成", en: "Today Focus complete", de: "Today Focus abgeschlossen")
        case let .general(_, _, _, title):
            return title
        }
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
