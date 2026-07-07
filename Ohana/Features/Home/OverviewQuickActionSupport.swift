//
//  OverviewQuickActionSupport.swift
//  Ohana
//
//  Catalog, storage model, glyph kind, and policy values for quick actions.
//

import Foundation
import SwiftUI

// MARK: - 快捷操作候选（与 QACardType.available 物种规则一致，供添加面板共用）
nonisolated enum QuickActionPickerCatalog {
    struct Option: Identifiable, Hashable {
        let id: String
        let label: String
        let icon: String
        let colorHex: String
    }

    private static func all(localization l: L10n) -> [Option] {
        [
            Option(id: "walk", label: l.quickActionLabel(for: "walk"), icon: "figure.walk", colorHex: "14B8A6"),
            Option(id: "feed", label: l.quickActionLabel(for: "feed"), icon: "fork.knife", colorHex: "FFDD44"),
            Option(id: "water", label: l.quickActionLabel(for: "water"), icon: "drop.fill", colorHex: "00D4AA"),
            Option(id: "potty", label: l.quickActionLabel(for: "potty"), icon: "allergens", colorHex: "FF8C42"),
            Option(id: "litter", label: l.quickActionLabel(for: "litter"), icon: "trash.fill", colorHex: "5B6AFF"),
            Option(id: "waterChange", label: l.quickActionLabel(for: "waterChange"), icon: "arrow.2.circlepath", colorHex: "4ECDC4"),
            Option(id: "filterClean", label: l.quickActionLabel(for: "filterClean"), icon: "sparkles", colorHex: "A78BFA"),
            Option(id: "groom", label: l.quickActionLabel(for: "groom"), icon: "scissors", colorHex: "FF8C42"),
            Option(id: "health", label: l.quickActionLabel(for: "health"), icon: "heart.fill", colorHex: "FF4757"),
            Option(id: "medication", label: l.quickActionLabel(for: "medication"), icon: "pill.fill", colorHex: "A855F7"),
            Option(id: "expense", label: l.quickActionLabel(for: "expense"), icon: AppCurrency.systemIconName, colorHex: "A78BFA"),
            Option(id: "weight", label: l.quickActionLabel(for: "weight"), icon: "scalemass.fill", colorHex: "80FFEA"),
            Option(id: "play", label: l.quickActionLabel(for: "play"), icon: "tennisball.fill", colorHex: "FF6B6B"),
            Option(id: "moment", label: l.quickActionLabel(for: "moment"), icon: "camera.circle.fill", colorHex: "FF6B9D"),
            Option(id: "cageCleaning", label: l.quickActionLabel(for: "cageCleaning"), icon: "basket.fill", colorHex: "FFD166"),
            Option(id: "freeFlight", label: l.quickActionLabel(for: "freeFlight"), icon: "bird.fill", colorHex: "06D6A0"),
            Option(id: "misting", label: l.quickActionLabel(for: "misting"), icon: "cloud.drizzle.fill", colorHex: "118AB2"),
            Option(id: "substrateChange", label: l.quickActionLabel(for: "substrateChange"), icon: "leaf.fill", colorHex: "07DB8B")
        ]
    }

    /// 当前物种可出现的 actionType 集合（与 QACardType.available 物种规则一致）
    static func allowedActionTypeIds(forSpecies species: String) -> Set<String> {
        var allowed = Set(QACardType.available(for: species).map(\.rawValue))
        if allowed.contains("care") { allowed.insert("groom") }
        allowed.insert("water")
        allowed.insert("moment")
        allowed.insert("medication")
        if Pet.isCatSpecies(species) {
            allowed.insert("litter")
            allowed.insert("play")
            allowed.insert("weight")
        }
        if Pet.isDogSpecies(species) {
            allowed.insert("walk")
            allowed.insert("groom")
            allowed.insert("weight")
        }
        return allowed
    }

    static func options(for pet: Pet, localization l: L10n = L10n()) -> [Option] {
        let allowed = allowedActionTypeIds(forSpecies: pet.species)
        return all(localization: l).filter { allowed.contains($0.id) }
    }

    static func available(for pet: Pet, existingActionTypes: Set<String>, localization l: L10n = L10n()) -> [Option] {
        let existing = normalizedExistingActionTypes(existingActionTypes)
        return options(for: pet, localization: l).filter { !existing.contains($0.id) }
    }

    private static func normalizedExistingActionTypes(_ actionTypes: Set<String>) -> Set<String> {
        var result = actionTypes
        if result.contains("water") || !result.isDisjoint(with: WaterQuickActionPolicy.foldedActionTypes) {
            result.insert("water")
            result.formUnion(WaterQuickActionPolicy.foldedActionTypes)
        }
        return result
    }
}

// MARK: - QuickActionItem Data Model
nonisolated struct QuickActionItem: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var icon: String
    var colorHex: String
    var petId: UUID?
    var entityId: UUID?
    var entityKindRaw: String?
    var actionType: String // "walk","health","groom","potty","feed","calendar","add","waterPlant","fertilizePlant"

    var entityKind: EntityKind? {
        get { entityKindRaw.flatMap { EntityKind(rawValue: $0) } }
        set { entityKindRaw = newValue?.rawValue }
    }

    var resolvedEntityId: UUID? { entityId ?? petId }

    init(id: String = UUID().uuidString, label: String, icon: String,
         colorHex: String, petId: UUID? = nil, actionType: String,
         entityId: UUID? = nil, entityKind: EntityKind? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
        self.colorHex = colorHex
        self.petId = petId
        self.actionType = actionType
        self.entityId = entityId
        self.entityKindRaw = entityKind?.rawValue
    }

    func displayLabel(localization l: L10n) -> String {
        l.quickActionLabel(for: actionType, fallback: label)
    }
}

extension L10n {
    nonisolated func quickActionLabel(for actionType: String, fallback: String? = nil) -> String {
        switch actionType {
        case "feed":
            homeQAFeed
        case "water":
            homeQAWater
        case "waterChange":
            homeQAWaterChange
        case "filterClean":
            homeQAFilterClean
        case "walk":
            homeQAWalk
        case "potty":
            homeQAPotty
        case "litter":
            homeQALitter
        case "groom":
            homeQAGroom
        case "health":
            tr(zh: "健康", en: "Health", de: "Gesundheit")
        case "medication", "humanMedication":
            homeQAMeds
        case "expense", "humanExpense":
            expense
        case "weight", "humanWeight":
            homeQAWeight
        case "play":
            homeQAPlay
        case "moment", "humanNote":
            homeQANote
        case "cageCleaning":
            homeQACageClean
        case "freeFlight":
            homeQAFreeFlight
        case "misting":
            tr(zh: "喷水", en: "Mist", de: "Sprühen")
        case "substrateChange":
            tr(zh: "换垫材", en: "Substrate", de: "Substrat")
        case "humanWorkout":
            homeQASport
        default:
            fallback ?? actionType
        }
    }
}

enum OhanaQuickActionGlyphKind {
    case feed
    case dryFood
    case wetFood
    case foodInventory
    case calendar
    case walk
    case water
    case waterChange
    case potty
    case litter
    case groom
    case health
    case medicine
    case weight
    case expense
    case play
    case rest
    case photo
    case cleanup
    case training
    case plantFertilize
    case document
    case settings

    static func resolve(actionType: String, fallbackSystemName: String) -> OhanaQuickActionGlyphKind? {
        let action = actionType.lowercased()
        let symbol = fallbackSystemName.lowercased()

        if action == "water", symbol.contains("water.waves") {
            return .waterChange
        }

        switch action {
        case "feed":
            return .feed
        case "dryfood", "fooddry", "dry":
            return .dryFood
        case "wetfood", "foodwet", "wet", "canned", "can":
            return .wetFood
        case "foodinventory", "foodstock", "inventory", "stock", "restock":
            return .foodInventory
        case "calendar":
            return .calendar
        case "walk":
            return .walk
        case "water":
            return .water
        case "waterchange", "filterclean":
            return .waterChange
        case "potty":
            return .potty
        case "litter":
            return .litter
        case "groom":
            return .groom
        case "health":
            return .health
        case "medication", "humanmedication":
            return .medicine
        case "weight", "humanweight":
            return .weight
        case "expense", "humanexpense":
            return .expense
        case "play":
            return .play
        case "rest", "sleep":
            return .rest
        case "moment":
            return .photo
        case "cagecleaning":
            return .cleanup
        case "freeflight", "humanworkout":
            return .training
        case "misting":
            return .water
        case "substratechange", "fertilizeplant":
            return .plantFertilize
        case "humannote", "note":
            return .document
        case "settings", "setting":
            return .settings
        default:
            break
        }

        if action.contains("dryfood") || action.contains("fooddry") || symbol.contains("hexagongrid") { return .dryFood }
        if action.contains("wetfood") || action.contains("foodwet") || action.contains("canned") || symbol.contains("takeoutbag") { return .wetFood }
        if action.contains("inventory") || action.contains("stock") || action.contains("restock") || symbol.contains("shippingbox") { return .foodInventory }
        if action.contains("feed") || action.contains("food") || symbol.contains("fork") { return .feed }
        if symbol.contains("calendar") { return .calendar }
        if action.contains("walk") || symbol.contains("figure.walk") { return .walk }
        if action.contains("waterchange") || action.contains("filterclean") || symbol.contains("water.waves") || symbol.contains("arrow.2.circlepath") { return .waterChange }
        if action.contains("water") || action.contains("misting") || symbol.contains("drop") || symbol.contains("cloud.drizzle") { return .water }
        if action.contains("potty") || action.contains("poop") || action == "pee" || symbol.contains("allergens") { return .potty }
        if action.contains("litter") || symbol.contains("trash") { return .litter }
        if action.contains("groom") || action.contains("hygiene") || action.contains("bath") || action.contains("teeth") || action.contains("nails") || action.contains("brushing") || action.contains("ears") || symbol.contains("scissors") || symbol.contains("comb") || symbol.contains("bubbles") { return .groom }
        if action.contains("health") || action.contains("visit") || symbol.contains("heart") || symbol.contains("stethoscope") || symbol.contains("cross") { return .health }
        if action.contains("medication") || action.contains("medicine") || action.contains("vaccine") || action.contains("deworming") || symbol.contains("pill") || symbol.contains("syringe") || symbol.contains("shield") { return .medicine }
        if action.contains("weight") || symbol.contains("scale") { return .weight }
        if action.contains("expense") || symbol.contains("credit") || symbol.contains("banknote") || symbol.contains("yensign") || symbol.contains("dollarsign") || symbol.contains("eurosign") || symbol.contains("sterlingsign") { return .expense }
        if action.contains("play") || symbol.contains("gamecontroller") || symbol.contains("tennisball") { return .play }
        if action.contains("rest") || action.contains("sleep") || symbol.contains("zzz") || symbol.contains("tent") { return .rest }
        if action.contains("moment") || symbol.contains("camera") { return .photo }
        if action.contains("cagecleaning") || symbol.contains("basket") { return .cleanup }
        if action.contains("freeflight") || action.contains("workout") { return .training }
        if action.contains("substratechange") || action.contains("fertilizeplant") || symbol.contains("leaf") { return .plantFertilize }
        if action.contains("note") || action.contains("document") || symbol.contains("note") || symbol.contains("doc") { return .document }
        if action.contains("settings") || action.contains("setting") || symbol.contains("gear") { return .settings }
        return nil
    }
}

nonisolated enum QuickActionLimit {
    static let maxItemsPerEntity = 8
    static let title = "快捷操作已达上限"
    static let message = "快捷操作区最多只能添加 8 个。更多功能可以在「全部功能」里查看和使用。"

    static func count(for pet: Pet, in items: [QuickActionItem]) -> Int {
        items.count(where: { $0.petId == pet.id && $0.entityKind != .human })
    }
}

nonisolated enum WaterQuickActionPolicy {
    static let foldedActionTypes: Set<String> = ["waterChange", "filterClean"]

    static func isAquatic(species: String) -> Bool {
        Pet.isFishSpecies(species)
    }

    static func normalizedItems(
        _ items: [QuickActionItem],
        for pet: Pet,
        waterLabel: String,
        managementLabel: String
    ) -> [QuickActionItem] {
        var result = items.filter { !foldedActionTypes.contains($0.actionType) }
        let hadFoldedWaterAction = items.contains { foldedActionTypes.contains($0.actionType) }
        let hasWater = result.contains { $0.actionType == "water" }
        guard !hasWater, hadFoldedWaterAction else { return result }

        let firstFoldedIndex = items.firstIndex { foldedActionTypes.contains($0.actionType) } ?? result.count
        let insertIndex = min(firstFoldedIndex, result.count)
        let item = QuickActionItem(
            label: isAquatic(species: pet.species) ? managementLabel : waterLabel,
            icon: isAquatic(species: pet.species) ? "water.waves" : "drop.fill",
            colorHex: "00D4AA",
            petId: pet.id,
            actionType: "water",
            entityId: pet.id,
            entityKind: .pet
        )
        result.insert(item, at: insertIndex)
        return result
    }

    static func titleOverride(for item: QuickActionItem, pet: Pet, managementLabel: String) -> String? {
        item.actionType == "water" && isAquatic(species: pet.species) ? managementLabel : nil
    }

    static func iconOverride(for item: QuickActionItem, pet: Pet) -> String? {
        item.actionType == "water" && isAquatic(species: pet.species) ? "water.waves" : nil
    }
}
