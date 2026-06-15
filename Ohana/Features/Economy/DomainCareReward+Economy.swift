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

    func title(pet: Pet?) -> String {
        let name = pet?.name ?? ""
        switch self {
        case .walk:
            return "\(name) 遛狗奖励"
        case let .potty(isLitter):
            return isLitter
                ? L10n().tr(zh: "\(name) 铲砂奖励", en: "\(name) scoop reward", de: "\(name) Klo-Bonus")
                : L10n().tr(zh: "\(name) 噗噗打卡", en: "\(name) poop check-in", de: "\(name) Häufchen-Check-in")
        case .feed:
            return "\(name) 喂食奖励"
        case .water:
            return "\(name) 喂水奖励"
        case let .care(type):
            let label = switch type {
            case .bath: "洗澡"
            case .teeth: "刷牙"
            case .nails: "剪甲"
            case .brushing: "梳毛"
            case .ears: "清耳"
            }
            return "\(name) \(label)奖励"
        case .health:
            return "\(name) 健康打卡奖励"
        case .expense:
            return "记账奖励"
        case .weight:
            return "\(name) 体重记录奖励"
        case .milestone:
            return "\(name) 里程碑达成"
        case .dailyFocusCompletion:
            return "Today Focus 全完成"
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
        switch self {
        case .none: nil
        case .precise: "🎯 精准XP+10%"
        case .withNote: "📝 备注XP+10%"
        case .withPhoto: "📷 照片XP+10%"
        case .preciseAndNote: "🎯📝 XP+20%"
        case .preciseAndPhoto: "🎯📷 XP+20%"
        case .preciseNotePhoto: "✨ 完整记录XP+30%"
        }
    }
}
