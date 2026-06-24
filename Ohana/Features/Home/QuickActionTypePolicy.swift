//
//  QuickActionTypePolicy.swift
//  Ohana
//
//  Species-scoped quick action availability policy shared by picker surfaces.
//

import Foundation

nonisolated enum QACardType: String, CaseIterable, Codable {
    case walk
    case feed
    case water
    case potty
    case litter
    case care
    case health
    case expense
    case weight
    case play
    case waterChange
    case filterClean
    case cageCleaning
    case freeFlight
    case misting
    case substrateChange

    static func available(for species: String) -> [QACardType] {
        let normalizedSpecies = species.lowercased()

        if species.contains("狗") || normalizedSpecies.contains("dog") {
            return [.walk, .feed, .water, .potty, .care, .play, .health, .expense, .weight]
        }

        if species.contains("猫") || normalizedSpecies.contains("cat") {
            return [.litter, .feed, .water, .potty, .play, .care, .health, .expense, .weight]
        }

        if species.contains("鱼") || species.contains("锦鲤") || species.contains("金鱼") ||
            normalizedSpecies.contains("fish") || normalizedSpecies.contains("koi") {
            return [.feed, .waterChange, .filterClean, .play, .health, .expense]
        }

        if species.contains("鸟") || species.contains("鹦鹉") || species.contains("文鸟") ||
            normalizedSpecies.contains("bird") || normalizedSpecies.contains("parrot") {
            return [.feed, .water, .cageCleaning, .freeFlight, .play, .health, .expense, .weight]
        }

        if species.contains("兔") || species.contains("仓鼠") || species.contains("龙猫") ||
            species.contains("豚鼠") || normalizedSpecies.contains("rabbit") ||
            normalizedSpecies.contains("hamster") {
            return [.feed, .water, .litter, .care, .play, .health, .expense, .weight]
        }

        if species.contains("爬") || species.contains("蜥") || species.contains("蛇") ||
            species.contains("龟") || species.contains("守宫") || species.contains("壁虎") ||
            normalizedSpecies.contains("reptile") || normalizedSpecies.contains("lizard") ||
            normalizedSpecies.contains("snake") || normalizedSpecies.contains("turtle") ||
            normalizedSpecies.contains("gecko") {
            return [.feed, .misting, .substrateChange, .play, .health, .expense, .weight]
        }

        return [.feed, .water, .play, .care, .health, .expense, .weight]
    }
}
