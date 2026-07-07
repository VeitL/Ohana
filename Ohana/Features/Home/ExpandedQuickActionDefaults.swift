//
//  ExpandedQuickActionDefaults.swift
//  Ohana
//
//  Species-aware default quick actions for the expanded home card.
//

import Foundation

nonisolated enum ExpandedQuickActionDefaults {
    static func humanItems(for human: Human, localization l: L10n) -> [QuickActionItem] {
        [
            QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA",
                            actionType: "humanWeight", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.expense, icon: "creditcard.fill", colorHex: "F59E0B",
                            actionType: "humanExpense", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A",
                            actionType: "humanMedication", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQASport, icon: "figure.run", colorHex: "F97316",
                            actionType: "humanWorkout", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQANote, icon: "note.text", colorHex: "A78BFA",
                            actionType: "humanNote", entityId: human.id, entityKind: .human)
        ]
    }

    static func items(for pet: Pet, localization l: L10n, waterManagementLabel: String) -> [QuickActionItem] {
        let isDog = Pet.isDogSpecies(pet.species)
        let isCat = Pet.isCatSpecies(pet.species)
        let isFish = Pet.isFishSpecies(pet.species)
        let isBird = Pet.isBirdSpecies(pet.species)
        let isRabbit = Pet.isRabbitSpecies(pet.species) || Pet.isSmallMammalSpecies(pet.species)
        let isReptile = Pet.isReptileSpecies(pet.species)

        if isFish {
            return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
                .waterManagement,
                .feed
            ])
        }

        if isDog {
            return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
                .feed,
                .water,
                .walk,
                .play,
                .weight,
                .moment,
                .expense
            ])
        }

        if isCat {
            return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
                .feed,
                .water,
                .litter,
                .play,
                .weight,
                .moment,
                .expense
            ])
        }

        if isBird {
            return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
                .feed,
                .water,
                .cageCleaning,
                .freeFlight
            ])
        }

        if isRabbit {
            return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
                .feed,
                .water,
                .litter,
                .play
            ])
        }

        if isReptile {
            return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
                .misting,
                .feed,
                .substrateChange
            ])
        }

        return items(for: pet, localization: l, waterManagementLabel: waterManagementLabel, [
            .feed,
            .water,
            .play
        ])
    }

    private enum DefaultAction {
        case feed
        case water
        case waterManagement
        case walk
        case potty
        case litter
        case play
        case weight
        case moment
        case expense
        case cageCleaning
        case freeFlight
        case misting
        case substrateChange
    }

    private static func items(
        for pet: Pet,
        localization l: L10n,
        waterManagementLabel: String,
        _ actions: [DefaultAction]
    ) -> [QuickActionItem] {
        actions.map { item($0, for: pet, localization: l, waterManagementLabel: waterManagementLabel) }
    }

    private static func item(
        _ action: DefaultAction,
        for pet: Pet,
        localization l: L10n,
        waterManagementLabel: String
    ) -> QuickActionItem {
        let entityId = pet.id
        switch action {
        case .feed:
            return QuickActionItem(label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44",
                                   petId: pet.id, actionType: "feed", entityId: entityId, entityKind: .pet)
        case .water:
            return QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA",
                                   petId: pet.id, actionType: "water", entityId: entityId, entityKind: .pet)
        case .waterManagement:
            return QuickActionItem(label: waterManagementLabel, icon: "water.waves", colorHex: "00D4AA",
                                   petId: pet.id, actionType: "water", entityId: entityId, entityKind: .pet)
        case .walk:
            return QuickActionItem(label: l.homeQAWalk, icon: "figure.walk", colorHex: "14B8A6",
                                   petId: pet.id, actionType: "walk", entityId: entityId, entityKind: .pet)
        case .potty:
            return QuickActionItem(label: l.homeQAPotty, icon: "allergens", colorHex: "FF8C42",
                                   petId: pet.id, actionType: "potty", entityId: entityId, entityKind: .pet)
        case .litter:
            return QuickActionItem(label: l.homeQALitter, icon: "trash.fill", colorHex: "5B6AFF",
                                   petId: pet.id, actionType: "litter", entityId: entityId, entityKind: .pet)
        case .play:
            return QuickActionItem(label: l.homeQAPlay, icon: "tennisball.fill", colorHex: "FF6B6B",
                                   petId: pet.id, actionType: "play", entityId: entityId, entityKind: .pet)
        case .weight:
            return QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA",
                                   petId: pet.id, actionType: "weight", entityId: entityId, entityKind: .pet)
        case .moment:
            return QuickActionItem(label: l.homeQANote, icon: "camera.circle.fill", colorHex: "FF6B9D",
                                   petId: pet.id, actionType: "moment", entityId: entityId, entityKind: .pet)
        case .expense:
            return QuickActionItem(label: l.expense, icon: AppCurrency.systemIconName, colorHex: "A78BFA",
                                   petId: pet.id, actionType: "expense", entityId: entityId, entityKind: .pet)
        case .cageCleaning:
            return QuickActionItem(label: l.homeQACageClean, icon: "basket.fill", colorHex: "FFD166",
                                   petId: pet.id, actionType: "cageCleaning", entityId: entityId, entityKind: .pet)
        case .freeFlight:
            return QuickActionItem(label: l.homeQAFreeFlight, icon: "bird.fill", colorHex: "06D6A0",
                                   petId: pet.id, actionType: "freeFlight", entityId: entityId, entityKind: .pet)
        case .misting:
            return QuickActionItem(label: l.tr(zh: "喷水", en: "Mist", de: "Sprühen"), icon: "cloud.drizzle.fill", colorHex: "118AB2",
                                   petId: pet.id, actionType: "misting", entityId: entityId, entityKind: .pet)
        case .substrateChange:
            return QuickActionItem(label: l.tr(zh: "换垫材", en: "Substrate", de: "Substrat"), icon: "leaf.fill", colorHex: "07DB8B",
                                   petId: pet.id, actionType: "substrateChange", entityId: entityId, entityKind: .pet)
        }
    }
}
