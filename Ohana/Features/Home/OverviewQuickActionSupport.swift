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
            Option(id: "allFeatures", label: l.quickActionLabel(for: "allFeatures"), icon: "square.grid.2x2.fill", colorHex: "5B6AFF"),
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
        allowed.insert("allFeatures")
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
        case "allFeatures":
            tr(zh: "全部", en: "All", de: "Alle")
        default:
            fallback ?? actionType
        }
    }
}

enum OhanaQuickActionGlyphKind: CaseIterable, Equatable, Sendable {
    case feed
    case calendar
    case walk
    case water
    case potty
    case medicine
    case groom
    case health
    case sleep
    case vet
    case weight
    case reminder
    case plantWater
    case play
    case bath
    case task
    case foodStock
    case dryFood
    case wetFood
    case treat
    case foodBag
    case feeder
    case waterChange
    case filterChange
    case litter
    case cleanup
    case walkMap
    case distance
    case training
    case mood
    case checkIn
    case family
    case profile
    case privacy
    case expense
    case insurance
    case document
    case photo
    case birthday
    case reward
    case temperature
    case plantFertilize
    case notificationHealth
    case settings

    // Production-only extensions for live quick actions that are not part of
    // the original 44-icon review sheet. They keep the same duotone grammar.
    case allFeatures
    case freeFlight
    case misting
    case substrateChange
    case workout
    case plantPruning
    case plantPestCheck
    case plantRotating
    case plantRepotting
    case plantNewLeaf
    case plantIssue

    static let previewCases: [Self] = [
        .feed, .calendar, .walk, .water, .potty, .medicine, .groom, .health,
        .sleep, .vet, .weight, .reminder, .plantWater, .play, .bath, .task,
        .foodStock, .dryFood, .wetFood, .treat, .foodBag, .feeder, .waterChange,
        .filterChange, .litter, .cleanup, .walkMap, .distance, .training, .mood,
        .checkIn, .family, .profile, .privacy, .expense, .insurance, .document,
        .photo, .birthday, .reward, .temperature, .plantFertilize,
        .notificationHealth, .settings
    ]

    var previewSlug: String {
        switch self {
        case .feed: "feed"
        case .calendar: "calendar"
        case .walk: "walk"
        case .water: "water"
        case .potty: "potty"
        case .medicine: "medicine"
        case .groom: "groom"
        case .health: "health"
        case .sleep: "sleep"
        case .vet: "vet"
        case .weight: "weight"
        case .reminder: "reminder"
        case .plantWater: "plant-water"
        case .play: "play"
        case .bath: "bath"
        case .task: "task"
        case .foodStock: "food-stock"
        case .dryFood: "dry-food"
        case .wetFood: "wet-food"
        case .treat: "treat"
        case .foodBag: "food-bag"
        case .feeder: "feeder"
        case .waterChange: "water-change"
        case .filterChange: "filter-change"
        case .litter: "litter"
        case .cleanup: "cleanup"
        case .walkMap: "walk-map"
        case .distance: "distance"
        case .training: "training"
        case .mood: "mood"
        case .checkIn: "check-in"
        case .family: "family"
        case .profile: "profile"
        case .privacy: "privacy"
        case .expense: "expense"
        case .insurance: "insurance"
        case .document: "document"
        case .photo: "photo"
        case .birthday: "birthday"
        case .reward: "reward"
        case .temperature: "temperature"
        case .plantFertilize: "plant-fertilize"
        case .notificationHealth: "notification-health"
        case .settings: "settings"
        case .allFeatures: "all-features"
        case .freeFlight: "free-flight"
        case .misting: "misting"
        case .substrateChange: "substrate-change"
        case .workout: "workout"
        case .plantPruning: "plant-pruning"
        case .plantPestCheck: "plant-pest-check"
        case .plantRotating: "plant-rotating"
        case .plantRepotting: "plant-repotting"
        case .plantNewLeaf: "plant-new-leaf"
        case .plantIssue: "plant-issue"
        }
    }

    static func resolve(actionType: String, fallbackSystemName: String) -> OhanaQuickActionGlyphKind? {
        let action = actionType.lowercased().filter { $0.isLetter || $0.isNumber }
        let symbol = fallbackSystemName.lowercased()

        if action == "water", symbol.contains("water.waves") {
            return .waterChange
        }

        if let exactKind = exactActionKinds[action] {
            return exactKind
        }

        return resolveFluidFallback(action: action, symbol: symbol)
            ?? resolveFoodFallback(action: action, symbol: symbol)
            ?? resolveMovementFallback(action: action, symbol: symbol)
            ?? resolveHygieneFallback(action: action, symbol: symbol)
            ?? resolveHealthFallback(action: action, symbol: symbol)
            ?? resolveLifestyleFallback(action: action, symbol: symbol)
            ?? resolvePeopleFallback(action: action, symbol: symbol)
            ?? resolvePlantFallback(action: action, symbol: symbol)
            ?? resolveUtilityFallback(action: action, symbol: symbol)
    }

    private static let exactActionKinds: [String: OhanaQuickActionGlyphKind] = [
        "feed": .feed,
        "feeding": .feed,
        "calendar": .calendar,
        "walk": .walk,
        "water": .water,
        "potty": .potty,
        "medication": .medicine,
        "humanmedication": .medicine,
        "medicine": .medicine,
        "groom": .groom,
        "brushing": .groom,
        "teeth": .groom,
        "nails": .groom,
        "ears": .groom,
        "health": .health,
        "rest": .sleep,
        "sleep": .sleep,
        "vet": .vet,
        "vaccine": .vet,
        "visit": .vet,
        "deworming": .vet,
        "weight": .weight,
        "humanweight": .weight,
        "reminder": .reminder,
        "plantwater": .plantWater,
        "waterplant": .plantWater,
        "misting": .misting,
        "plantmisting": .misting,
        "play": .play,
        "bath": .bath,
        "task": .task,
        "allfeatures": .allFeatures,
        "humanallfeatures": .allFeatures,
        "foodinventory": .foodStock,
        "foodstock": .foodStock,
        "inventory": .foodStock,
        "stock": .foodStock,
        "restock": .foodStock,
        "dryfood": .dryFood,
        "fooddry": .dryFood,
        "dry": .dryFood,
        "wetfood": .wetFood,
        "foodwet": .wetFood,
        "wet": .wetFood,
        "canned": .wetFood,
        "can": .wetFood,
        "treat": .treat,
        "foodbag": .foodBag,
        "feeder": .feeder,
        "autofeeder": .feeder,
        "waterchange": .waterChange,
        "filterclean": .filterChange,
        "filterchange": .filterChange,
        "litter": .litter,
        "cleanup": .cleanup,
        "cagecleaning": .cleanup,
        "plantleafcleaning": .cleanup,
        "walkmap": .walkMap,
        "distance": .distance,
        "training": .training,
        "freeflight": .freeFlight,
        "humanworkout": .workout,
        "workout": .workout,
        "mood": .mood,
        "checkin": .checkIn,
        "family": .family,
        "profile": .profile,
        "plantdetail": .profile,
        "privacy": .privacy,
        "expense": .expense,
        "humanexpense": .expense,
        "insurance": .insurance,
        "document": .document,
        "humannote": .document,
        "plantnote": .document,
        "note": .document,
        "moment": .photo,
        "photo": .photo,
        "birthday": .birthday,
        "reward": .reward,
        "temperature": .temperature,
        "humidity": .temperature,
        "substratechange": .substrateChange,
        "fertilizeplant": .plantFertilize,
        "plantpruning": .plantPruning,
        "plantpestcheck": .plantPestCheck,
        "plantrotating": .plantRotating,
        "plantrepotting": .plantRepotting,
        "plantnewleaf": .plantNewLeaf,
        "plantyellowleaf": .plantIssue,
        "plantpestfound": .plantIssue,
        "plantissue": .plantIssue,
        "notificationhealth": .notificationHealth,
        "settings": .settings,
        "setting": .settings
    ]

    private static func resolveFluidFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("filter") { return .filterChange }
        if action.contains("waterchange") || symbol.contains("water.waves") || symbol.contains("arrow.2.circlepath") { return .waterChange }
        if action.contains("plant") && (action.contains("water") || action.contains("mist")) { return .plantWater }
        return nil
    }

    private static func resolveFoodFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("dryfood") || action.contains("fooddry") || symbol.contains("hexagongrid") { return .dryFood }
        if action.contains("wetfood") || action.contains("foodwet") || action.contains("canned") || symbol.contains("takeoutbag") { return .wetFood }
        if action.contains("inventory") || action.contains("stock") { return .foodStock }
        if action.contains("feeder") { return .feeder }
        if action.contains("treat") { return .treat }
        if action.contains("feed") || action.contains("food") || symbol.contains("fork") { return .feed }
        return nil
    }

    private static func resolveMovementFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if symbol.contains("calendar") { return .calendar }
        if action.contains("walkmap") { return .walkMap }
        if action.contains("distance") { return .distance }
        if action.contains("walk") || symbol.contains("figure.walk") { return .walk }
        if action.contains("misting") || symbol.contains("cloud.drizzle") { return .misting }
        if action.contains("water") || symbol.contains("drop") { return .water }
        if action.contains("potty") || action.contains("poop") || action == "pee" || symbol.contains("allergens") { return .potty }
        if action.contains("litter") || symbol.contains("trash") { return .litter }
        if action.contains("bath") || symbol.contains("bubbles") { return .bath }
        return nil
    }

    private static func resolveHygieneFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("groom") || action.contains("hygiene") || action.contains("teeth") || action.contains("nails") || action.contains("brushing") || action.contains("ears") || symbol.contains("scissors") || symbol.contains("comb") { return .groom }
        if action.contains("vaccine") || action.contains("visit") || symbol.contains("stethoscope") || symbol.contains("syringe") { return .vet }
        return nil
    }

    private static func resolveHealthFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("health") || symbol.contains("heart") || symbol.contains("cross") { return .health }
        if action.contains("medication") || action.contains("medicine") || symbol.contains("pill") { return .medicine }
        if action.contains("weight") || symbol.contains("scale") { return .weight }
        if action.contains("reminder") || symbol.contains("bell") { return .reminder }
        if action.contains("expense") || symbol.contains("credit") || symbol.contains("banknote") || symbol.contains("yensign") || symbol.contains("dollarsign") || symbol.contains("eurosign") || symbol.contains("sterlingsign") { return .expense }
        return nil
    }

    private static func resolveLifestyleFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("play") || symbol.contains("gamecontroller") || symbol.contains("tennisball") { return .play }
        if action.contains("rest") || action.contains("sleep") || symbol.contains("zzz") || symbol.contains("tent") { return .sleep }
        if action.contains("moment") || symbol.contains("camera") { return .photo }
        if action.contains("cleanup") || action.contains("cleaning") || symbol.contains("basket") { return .cleanup }
        if action.contains("freeflight") || symbol.contains("bird") { return .freeFlight }
        if action.contains("workout") || symbol.contains("figure.run") { return .workout }
        return nil
    }

    private static func resolvePeopleFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("training") { return .training }
        if action.contains("mood") { return .mood }
        if action.contains("checkin") || symbol.contains("checkmark.seal") { return .checkIn }
        if action.contains("family") || symbol.contains("person.2") { return .family }
        if action.contains("profile") { return .profile }
        if action.contains("privacy") || symbol.contains("lock") { return .privacy }
        if action.contains("insurance") { return .insurance }
        if action.contains("note") || action.contains("document") || symbol.contains("note") || symbol.contains("doc") { return .document }
        if action.contains("birthday") || symbol.contains("birthday") { return .birthday }
        if action.contains("reward") || symbol.contains("medal") { return .reward }
        if action.contains("temperature") || action.contains("humidity") || symbol.contains("thermometer") { return .temperature }
        return nil
    }

    private static func resolvePlantFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("pruning") { return .plantPruning }
        if action.contains("pestcheck") || symbol.contains("ladybug") { return .plantPestCheck }
        if action.contains("rotating") || symbol.contains("arrow.triangle.2.circlepath") { return .plantRotating }
        if action.contains("repot") || symbol.contains("shippingbox") { return .plantRepotting }
        if action.contains("newleaf") || symbol.contains("leaf.arrow") { return .plantNewLeaf }
        if action.contains("pestfound") || action.contains("yellowleaf") { return .plantIssue }
        if action.contains("pest") { return .notificationHealth }
        if action.contains("substrate") { return .substrateChange }
        if action.contains("fertilize") || symbol.contains("leaf") { return .plantFertilize }
        return nil
    }

    private static func resolveUtilityFallback(action: String, symbol: String) -> OhanaQuickActionGlyphKind? {
        if action.contains("allfeatures") || symbol.contains("square.grid") { return .allFeatures }
        if action.contains("task") { return .task }
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
