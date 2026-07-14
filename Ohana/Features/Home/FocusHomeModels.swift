//
//  FocusHomeModels.swift
//  Ohana
//
//  Lightweight model helpers for the GO Focus home wallet.
//

import Foundation
import SwiftData
import SwiftUI

nonisolated enum FocusCardStatusBadgeTone: String, Equatable, Sendable {
    case ok
    case due
    case urgent
}

nonisolated struct FocusCard: Identifiable, @unchecked Sendable {
    let id: UUID
    var modelID: PersistentIdentifier? = nil
    let name: String
    let kind: String
    let emoji: String
    let color: Color
    let streak: Int
    let coconutBalance: Int
    var createdAt: Date = .distantPast
    var daysTogetherText: String?
    var togetherHeadlineText: String?
    var ageText: String?
    var zodiacText: String?
    var mbtiText: String?
    var humanEquivalentAgeText: String?
    var genderText: String?
    var personalityHint: String?
    var avatarImageData: Data?
    var avatarImageSignature: String = ""
    var avatarImageAssetName: String?
    var cardStyleRaw: String = "classic"
    var cardPopoutImageData: Data?
    var cardPopoutImageSignature: String = ""
    var cardPopoutSourceRaw: String = ""
    var petBondCardBorderActive: Bool = false
    var petBondNameplateActive: Bool = false
    var petBondNameplateText: String?
    var humanGender: String?
    var petSpecies: String?
    var coatColor: Color = .init(hex: "E8C49A")
    var patternName: String?
    var themeColorHex: String = ""
    var daysTogether: Int = 0
    var breed: String = ""
    var hasPassedAway: Bool = false
    var passedAwayDate: Date?
    var daysTogetherAtPassing: Int = 0
    var isShownOnHome: Bool = true
    var equippedTitleBadgeText: String?
    var statusBadgeText: String?
    var statusBadgeIsWarning: Bool = false
    var statusBadgeToneRaw: String = FocusCardStatusBadgeTone.ok.rawValue
    var isHuman: Bool = false
    var isPlant: Bool = false
    var isElectronicPet: Bool = false
    var critterCatalogId: String?
    var critterAppearanceStage: Int = 1
    var critterLifeStateRaw: String = ""
    var isDummy: Bool = false
    var isReal: Bool = false
    var homeWalkDistanceMeters: Double = 0
    var actions: [Action]

    struct Action: Identifiable, Sendable {
        let id = UUID()
        let label: String
        let icon: String
        let colorHex: String
    }
}

extension FocusCard {
    nonisolated var statusBadgeTone: FocusCardStatusBadgeTone {
        get {
            if statusBadgeIsWarning {
                return .urgent
            }
            return FocusCardStatusBadgeTone(rawValue: statusBadgeToneRaw) ?? .ok
        }
        set {
            statusBadgeToneRaw = newValue.rawValue
            statusBadgeIsWarning = newValue == .urgent
        }
    }

    nonisolated var homePrimaryMetricValue: String {
        if isElectronicPet {
            return electronicPetLevelMetricValue
        }
        if isRegularPetCard {
            if daysTogether > 0 {
                return "\(daysTogether)"
            }
            if isDogCard, homeWalkDistanceMeters > 0 {
                return homeWalkDistanceMetric.value
            }
        }
        return "\(coconutBalance)"
    }

    nonisolated var homePrimaryMetricUnit: String {
        if isElectronicPet {
            return "Lv"
        }
        if isRegularPetCard {
            if daysTogether > 0 {
                return "d"
            }
            if isDogCard, homeWalkDistanceMeters > 0 {
                return homeWalkDistanceMetric.unit
            }
        }
        return "c"
    }

    private nonisolated var isRegularPetCard: Bool {
        !isHuman && !isElectronicPet
    }

    private nonisolated var isDogCard: Bool {
        Pet.isDogSpecies(petSpecies ?? kind)
    }

    private nonisolated var homeWalkDistanceMetric: (value: String, unit: String) {
        let formatted = AppMeasurementSystem.formatDistanceMeters(homeWalkDistanceMeters)
        let parts = formatted.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return (formatted, "")
        }
        return (parts[0], parts[1])
    }

    private nonisolated var electronicPetLevelMetricValue: String {
        let trimmed = (ageText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstNumber = trimmed.split(whereSeparator: { !$0.isNumber }).first,
           !firstNumber.isEmpty {
            return String(firstNumber)
        }
        return "\(max(1, critterAppearanceStage))"
    }
}

enum HomeFabShortcutSubmenu: String, Hashable {
    case addMember
}

enum HomeFabFunctionShortcutAction: Hashable {
    case addEntity(EntityType)
    case destination(FMDest)
    case submenu(HomeFabShortcutSubmenu)
    case unavailable
}

struct HomeFabFunctionShortcut: Identifiable {
    var label: String
    var icon: String
    var isAvailable: Bool = true
    var badge: String?
    var action: HomeFabFunctionShortcutAction = .unavailable

    var id: String {
        switch action {
        case let .addEntity(type):
            "\(label)-add-\(type.rawValue)"
        case let .destination(destination):
            "\(label)-destination-\(String(describing: destination))"
        case let .submenu(submenu):
            "\(label)-submenu-\(submenu.rawValue)"
        case .unavailable:
            "\(label)-unavailable"
        }
    }

    var destination: FMDest? {
        if case let .destination(destination) = action {
            return destination
        }
        return nil
    }

    var entityToAdd: EntityType? {
        if case let .addEntity(type) = action {
            return type
        }
        return nil
    }

    init(
        label: String,
        icon: String,
        isAvailable: Bool = true,
        badge: String? = nil,
        destination: FMDest? = nil,
        entityToAdd: EntityType? = nil,
        action: HomeFabFunctionShortcutAction? = nil
    ) {
        self.label = label
        self.icon = icon
        self.isAvailable = isAvailable
        self.badge = badge
        if let action {
            self.action = action
        } else if let entityToAdd {
            self.action = .addEntity(entityToAdd)
        } else if let destination {
            self.action = .destination(destination)
        } else {
            self.action = .unavailable
        }
    }
}

enum ExpandedCardFabAction: Hashable {
    case quick(String)
    case detail(PetFeature)
    case allFeatures
    case humanQuick(String)
    case humanAllFeatures
}

struct ExpandedCardFabShortcut: Identifiable {
    var label: String
    var icon: String
    var action: ExpandedCardFabAction
    var isAvailable: Bool = true
    var badge: String?

    var id: String { "\(label)-\(String(describing: action))" }
}

extension FocusCard {
    nonisolated static func from(
        _ pet: Pet,
        includeAvatarData: Bool = false,
        homeWalkDistanceMeters: Double = 0,
        l: L10n = .current
    ) -> FocusCard {
        let isDog = Pet.isDogSpecies(pet.species)
        let isCat = Pet.isCatSpecies(pet.species)
        let isFish = Pet.isFishSpecies(pet.species)
        let isBird = Pet.isBirdSpecies(pet.species)
        let isRabbit = Pet.isRabbitSpecies(pet.species) || Pet.isSmallMammalSpecies(pet.species)
        let isReptile = Pet.isReptileSpecies(pet.species)

        var acts: [Action] = [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44")]
        if isFish {
            acts += [.init(label: "WATER", icon: "drop.circle", colorHex: "00D4AA"),
                     .init(label: "FILTER", icon: "wrench.and.screwdriver", colorHex: "A78BFA")]
        } else if isBird {
            acts += [.init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                     .init(label: "CAGE", icon: "basket", colorHex: "FFD166"),
                     .init(label: "FLIGHT", icon: "bird", colorHex: "06D6A0")]
        } else if isReptile {
            acts += [.init(label: "MIST", icon: "cloud.drizzle", colorHex: "118AB2"),
                     .init(label: "SUBSTRATE", icon: "leaf", colorHex: "07DB8B"),
                     .init(label: "PLAY", icon: "sparkles", colorHex: "F472B6")]
        } else if isDog {
            acts += [.init(label: "WALK", icon: "figure.walk", colorHex: "14B8A6"),
                     .init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                     .init(label: "POTTY", icon: "allergens", colorHex: "A78BFA")]
        } else if isCat {
            acts += [.init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                     .init(label: "LITTER", icon: "trash", colorHex: "5B6AFF"),
                     .init(label: "PLAY", icon: "sparkles", colorHex: "F472B6")]
        } else if isRabbit {
            acts += [.init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                     .init(label: "LITTER", icon: "trash", colorHex: "5B6AFF"),
                     .init(label: "GROOM", icon: "comb", colorHex: "FF8C42")]
        } else {
            acts += [.init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                     .init(label: "PLAY", icon: "sparkles", colorHex: "F472B6")]
        }

        let hex = pet.safeThemeColorHex
        let hour = Calendar.current.component(.hour, from: Date())
        let togetherDays = pet.hasPassedAway ? pet.daysTogetherAtPassing : pet.daysTogether
        let togetherHeadline: String
        if pet.homeDate == nil {
            togetherHeadline = l.tr(zh: "新成员", en: "New Family", de: "Neue Familie")
        } else if togetherDays < 0 {
            let days = abs(togetherDays)
            togetherHeadline = l.tr(zh: "\(days) 天后到家", en: "\(days) Days Until Home", de: "\(days) Tage bis Zuhause")
        } else {
            togetherHeadline = l.tr(zh: "相伴 \(togetherDays) 天", en: "\(togetherDays) Days Together", de: "\(togetherDays) Tage zusammen")
        }
        let hasAvatarAttachment = pet.hasAvatarImageAttachment
        let avatarImageData = includeAvatarData && hasAvatarAttachment ? pet.avatarImageData : nil
        let avatarImageSignature = hasAvatarAttachment ? pet.avatarThumbnailSignature : ""
        let popoutImageData = includeAvatarData && pet.cardStyleRaw == "popout"
            ? (pet.hasCardPopoutImageAttachment ? pet.cardPopoutImageData : avatarImageData)
            : nil
        let popoutImageSignature = pet.cardStyleRaw == "popout"
            ? (pet.hasCardPopoutImageAttachment ? pet.cardPopoutThumbnailSignature : avatarImageSignature)
            : ""
        return FocusCard(
            id: pet.id,
            modelID: pet.persistentModelID,
            name: pet.name.isEmpty ? l.tr(zh: "未命名", en: "Unnamed", de: "Unbenannt") : pet.name,
            kind: pet.hasPassedAway
                ? l.tr(zh: "彩虹桥", en: "Rainbow Bridge", de: "Regenbogenbrücke")
                : (pet.species.isEmpty ? "PET" : pet.localizedSpeciesName(l: l)),
            emoji: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
            color: Color(hex: hex),
            streak: pet.currentStreak,
            coconutBalance: pet.coconutBalance,
            createdAt: pet.createdAt,
            daysTogetherText: pet.homeDate == nil ? nil : l.tr(
                zh: "\(togetherDays) 天",
                en: "\(togetherDays) days",
                de: "\(togetherDays) Tage"
            ),
            togetherHeadlineText: togetherHeadline,
            ageText: pet.hasPassedAway ? pet.ageAtPassingText : pet.birthday.map { pet.localizedAgeTextForWallet(birthday: $0, l: l) },
            zodiacText: pet.birthday.map { Human.westernZodiacDisplay(for: $0, l: l) },
            humanEquivalentAgeText: pet.birthday.map { pet.humanEquivalentAgeTextForWallet(birthday: $0, l: l) },
            genderText: pet.genderSymbol + (pet.isNeutered ? l.tr(zh: " 已绝育", en: " neutered", de: " kastriert") : ""),
            personalityHint: PetTagGreeting.homeSubtitleHint(pet: pet, hour: hour, l: l),
            avatarImageData: avatarImageData,
            avatarImageSignature: avatarImageSignature,
            cardStyleRaw: pet.cardStyleRaw,
            cardPopoutImageData: popoutImageData,
            cardPopoutImageSignature: popoutImageSignature,
            cardPopoutSourceRaw: pet.cardPopoutSourceRaw ?? "",
            petSpecies: pet.species,
            coatColor: WalletPetCardTheme.silhouetteCoatColor(for: pet),
            patternName: WalletPetCardTheme.coatPatternName(for: pet),
            themeColorHex: hex,
            daysTogether: pet.homeDate == nil ? 0 : togetherDays,
            breed: pet.breed,
            hasPassedAway: pet.hasPassedAway,
            passedAwayDate: pet.passedAwayDate,
            daysTogetherAtPassing: pet.daysTogetherAtPassing,
            isReal: true,
            homeWalkDistanceMeters: homeWalkDistanceMeters,
            actions: Array(acts.prefix(4))
        )
    }

    nonisolated static func from(_ human: Human, includeAvatarData: Bool = false) -> FocusCard {
        let hex = human.safeThemeColorHex
        let days = human.hasPassedAway
            ? human.daysTogetherAtPassing
            : max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
        let language = AppLanguage.code
        let l = L10n(language)
        let hasAvatarAttachment = human.hasAvatarImageAttachment
        return FocusCard(
            id: human.id,
            modelID: human.persistentModelID,
            name: human.name.isEmpty ? l.tr(zh: "成员", en: "Human", de: "Mitglied") : human.name,
            kind: human.hasPassedAway ? l.tr(zh: "纪念", en: "Memorial", de: "Gedenken") : l.tr(zh: "家人", en: "Member", de: "Mitglied"),
            emoji: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji,
            color: Color(hex: hex),
            streak: 0,
            coconutBalance: human.coconutBalance,
            createdAt: human.createdAt,
            daysTogetherText: l.tr(
                zh: "\(days) 天",
                en: "\(days) days",
                de: "\(days) Tage"
            ),
            ageText: human.hasPassedAway ? human.ageAtPassingText : human.birthday.map { human.localizedAgeTextForWallet(birthday: $0, l: l) },
            zodiacText: human.birthday.map { Human.westernZodiacDisplay(for: $0, l: l) },
            mbtiText: human.mbti.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : human.mbti.uppercased(),
            genderText: HumanProfileOptions.localizedGenderTitle(human.genderRaw, l: l),
            avatarImageData: includeAvatarData && hasAvatarAttachment ? human.avatarImageData : nil,
            avatarImageSignature: hasAvatarAttachment ? human.avatarThumbnailSignature : "",
            humanGender: human.genderRaw,
            themeColorHex: hex,
            daysTogether: days,
            hasPassedAway: human.hasPassedAway,
            passedAwayDate: human.passedAwayDate,
            daysTogetherAtPassing: human.daysTogetherAtPassing,
            isShownOnHome: human.shouldShowOnHome,
            isHuman: true,
            isReal: true,
            actions: [.init(label: "WEIGHT", icon: "scalemass", colorHex: "80FFEA"),
                      .init(label: "WORKOUT", icon: "figure.run", colorHex: "F97316"),
                      .init(label: "NOTE", icon: "note.text", colorHex: "5B6AFF")]
        )
    }

    nonisolated static func from(_ critter: OasisElectronicPet) -> FocusCard {
        let language = AppLanguage.code
        let l = L10n(language)
        let state = critter.lifeState
        let days = max(0, Calendar.current.dateComponents([.day], from: critter.obtainedAt, to: Date()).day ?? 0)
        let themeHex = switch state {
        case .healthy:
            "9EF06A"
        case .dead:
            "7C828D"
        case .needsCare, .atRisk, .sick, .critical:
            "FF4757"
        }
        return FocusCard(
            id: critter.id,
            name: critter.displayName(l),
            kind: l.tr(zh: "电子宠物", en: "Critter", de: "Critter"),
            emoji: critter.emoji,
            color: Color(hex: themeHex),
            streak: 0,
            coconutBalance: 0,
            createdAt: critter.obtainedAt,
            daysTogetherText: l.tr(zh: "\(days) 天", en: "\(days) days", de: "\(days) Tage"),
            ageText: l.tr(zh: "Lv.\(critter.level)", en: "Lv.\(critter.level)", de: "Lv.\(critter.level)"),
            personalityHint: state.name(l),
            themeColorHex: themeHex,
            daysTogether: days,
            isShownOnHome: critter.isFeaturedOnOasis,
            isElectronicPet: true,
            critterCatalogId: critter.catalogId,
            critterAppearanceStage: max(
                max(1, min(OasisCritterPresentationRules.maxAppearanceStage, critter.appearanceStage)),
                OasisCritterPresentationRules.appearanceStage(forLevel: critter.level)
            ),
            critterLifeStateRaw: critter.lifeStateRaw,
            isReal: true,
            actions: [
                .init(label: l.tr(zh: "照顾", en: "CARE", de: "PFLEGE"), icon: "cross.case.fill", colorHex: "9EF06A"),
                .init(label: l.tr(zh: "喂", en: "FEED", de: "FUTTER"), icon: "fork.knife", colorHex: "FFDD44"),
                .init(label: l.tr(zh: "玩", en: "PLAY", de: "SPIEL"), icon: "sparkles", colorHex: "80FFEA")
            ]
        )
    }

    nonisolated static let dummies: [FocusCard] = [
        FocusCard(id: UUID(), name: "Mochi", kind: "DOG", emoji: "🐶",
                  color: Color(hex: "F4A7B9"), streak: 7, coconutBalance: 42,
                  petSpecies: "狗", coatColor: Color(hex: "D7A76D"),
                  isDummy: true,
                  actions: [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44"),
                            .init(label: "WALK", icon: "figure.walk", colorHex: "14B8A6"),
                            .init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                            .init(label: "POTTY", icon: "allergens", colorHex: "A78BFA")]),

        FocusCard(id: UUID(), name: "Luna", kind: "CAT", emoji: "🐱",
                  color: Color(hex: "C9B6E4"), streak: 12, coconutBalance: 66,
                  petSpecies: "猫", coatColor: Color(hex: "9CA7B2"),
                  isDummy: true,
                  actions: [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44"),
                            .init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                            .init(label: "LITTER", icon: "trash", colorHex: "5B6AFF"),
                            .init(label: "PLAY", icon: "sparkles", colorHex: "F472B6")]),

        FocusCard(id: UUID(), name: "Alex", kind: "HUMAN", emoji: "🧑‍💻",
                  color: Color(hex: "B9E8D2"), streak: 3, coconutBalance: 18,
                  isHuman: true, isDummy: true,
                  actions: [.init(label: "WEIGHT", icon: "scalemass", colorHex: "80FFEA"),
                            .init(label: "WORKOUT", icon: "figure.run", colorHex: "F97316"),
                            .init(label: "NOTE", icon: "note.text", colorHex: "5B6AFF")]),

        FocusCard(id: UUID(), name: "Nemo", kind: "FISH", emoji: "🐟",
                  color: Color(hex: "C7E7F1"), streak: 4, coconutBalance: 24,
                  petSpecies: "鱼", isDummy: true,
                  actions: [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44"),
                            .init(label: "WATER", icon: "drop.circle", colorHex: "00D4AA"),
                            .init(label: "FILTER", icon: "wrench.and.screwdriver", colorHex: "A78BFA")])
    ]
}

extension Pet {
    nonisolated func localizedAgeTextForWallet(birthday: Date, l: L10n) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
        let years = max(0, components.year ?? 0)
        let months = max(0, components.month ?? 0)
        if years > 0 {
            if months > 0 {
                return l.tr(
                    zh: "\(years)岁\(months)月",
                    en: "\(years)y \(months)m",
                    de: "\(years) J. \(months) Mon."
                )
            }
            return l.tr(zh: "\(years)岁", en: "\(years)y", de: "\(years) J.")
        }
        return l.tr(zh: "\(months)个月", en: "\(months)m", de: "\(months) Mon.")
    }

    nonisolated func humanEquivalentAgeTextForWallet(birthday: Date, l: L10n) -> String {
        let equivalent = FocusPetHumanAgeEstimator.equivalentHumanYears(
            birthday: birthday,
            species: species,
            breed: breed
        )
        guard equivalent > 0 else { return "" }
        return l.tr(
            zh: "约人类\(equivalent)岁",
            en: "about \(equivalent) human years",
            de: "ca. \(equivalent) Menschenjahre"
        )
    }
}

extension Human {
    nonisolated func localizedAgeTextForWallet(birthday: Date, l: L10n) -> String {
        let years = max(0, Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0)
        if years >= 1 {
            return l.tr(zh: "\(years)岁", en: "\(years)y", de: "\(years) J.")
        }
        return l.tr(zh: "不满1岁", en: "Under 1", de: "Unter 1")
    }
}

nonisolated enum FocusPetHumanAgeEstimator {
    static func equivalentHumanYears(birthday: Date, species: String, breed: String) -> Int {
        let ageYears = max(0, Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0) / 365
        let preciseAge = max(0, Double(Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0) / 365.25)
        switch Pet.canonicalSpeciesKey(species) {
        case "dog":
            return dogHumanYears(age: preciseAge, breed: breed)
        case "cat":
            return catHumanYears(age: preciseAge)
        case "rabbit":
            return Int((preciseAge * 8.0).rounded())
        case "hamster":
            return Int((preciseAge * 26.0).rounded())
        case "bird":
            return Int((preciseAge * 5.0).rounded())
        case "fish":
            return Int((preciseAge * 6.0).rounded())
        default:
            return max(0, ageYears)
        }
    }

    private static func dogHumanYears(age: Double, breed: String) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }

        let increment: Double = switch dogSize(for: breed) {
        case .small: 4
        case .medium: 5
        case .large: 6
        case .giant: 7
        }
        return Int((24 + (age - 2) * increment).rounded())
    }

    private static func catHumanYears(age: Double) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }
        return Int((24 + (age - 2) * 4).rounded())
    }

    private enum DogSize { case small, medium, large, giant }

    private static func dogSize(for breed: String) -> DogSize {
        let b = breed.lowercased()
        if ["马尔济斯", "约克夏", "博美", "比熊", "西施", "查理王", "泰迪", "贵宾", "腊肠", "法斗", "法国斗牛", "corgi", "poodle", "yorkshire", "pomeranian", "bichon", "maltese", "dachshund", "shih"].contains(where: { b.contains($0.lowercased()) }) {
            return .small
        }
        if ["阿拉斯加", "大丹", "圣伯纳", "獒", "纽芬兰", "giant", "great dane", "mastiff", "saint bernard", "newfoundland", "alaskan"].contains(where: { b.contains($0.lowercased()) }) {
            return .giant
        }
        if ["金毛", "拉布拉多", "德国牧羊", "杜宾", "哈士奇", "萨摩耶", "大麦町", "边境牧羊", "golden", "labrador", "german shepherd", "husky", "samoyed", "doberman", "dalmatian", "border collie"].contains(where: { b.contains($0.lowercased()) }) {
            return .large
        }
        return .medium
    }
}
