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
        if Pet.isDogSpecies(species) {
            return [.walk, .feed, .water, .potty, .care, .play, .health, .expense, .weight]
        }

        if Pet.isCatSpecies(species) {
            return [.litter, .feed, .water, .potty, .play, .care, .health, .expense, .weight]
        }

        if Pet.isFishSpecies(species) {
            return [.feed, .waterChange, .filterClean, .play, .health, .expense]
        }

        if Pet.isBirdSpecies(species) {
            return [.feed, .water, .cageCleaning, .freeFlight, .play, .health, .expense, .weight]
        }

        if Pet.isRabbitSpecies(species) || Pet.isSmallMammalSpecies(species) {
            return [.feed, .water, .litter, .care, .play, .health, .expense, .weight]
        }

        if Pet.isReptileSpecies(species) {
            return [.feed, .misting, .substrateChange, .play, .health, .expense, .weight]
        }

        return [.feed, .water, .play, .care, .health, .expense, .weight]
    }
}
