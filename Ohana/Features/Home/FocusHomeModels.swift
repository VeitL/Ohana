//
//  FocusHomeModels.swift
//  Ohana
//
//  Lightweight model helpers for the GO Focus home wallet.
//

import Foundation
import SwiftUI

struct FocusCard: Identifiable {
    let id: UUID
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
    var cardStyleRaw: String = "classic"
    var cardPopoutImageData: Data? = nil
    var cardPopoutImageSignature: String = ""
    var cardPopoutSourceRaw: String = ""
    var petBondCardBorderActive: Bool = false
    var petBondNameplateActive: Bool = false
    var petBondNameplateText: String? = nil
    var humanGender: String? = nil
    var petSpecies: String?
    var coatColor: Color = .init(hex: "E8C49A")
    var eyeColor: Color = .init(hex: "6B3A2A")
    var patternName: String?
    var themeColorHex: String = ""
    var daysTogether: Int = 0
    var breed: String = ""
    var hasPassedAway: Bool = false
    var passedAwayDate: Date? = nil
    var daysTogetherAtPassing: Int = 0
    var isShownOnHome: Bool = true
    var equippedTitleBadgeText: String? = nil
    var statusBadgeText: String? = nil
    var statusBadgeIsWarning: Bool = false
    var isHuman: Bool = false
    var isElectronicPet: Bool = false
    var critterCatalogId: String? = nil
    var critterAppearanceStage: Int = 1
    var critterLifeStateRaw: String = ""
    var isDummy: Bool = false
    var isReal: Bool = false
    var homeWalkDistanceMeters: Double = 0
    var actions: [Action]

    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let colorHex: String
    }
}

extension FocusCard {
    var homePrimaryMetricValue: String {
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

    var homePrimaryMetricUnit: String {
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

    static func weeklyWalkDistanceMeters(for pet: Pet, now: Date = Date()) -> Double {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
        return pet.walkLogs
            .filter { $0.startDate >= start }
            .reduce(0.0) { $0 + $1.distanceMeters }
    }

    private var isRegularPetCard: Bool {
        !isHuman && !isElectronicPet
    }

    private var isDogCard: Bool {
        let species = (petSpecies ?? kind).lowercased()
        return species.contains("dog") || species.contains("狗")
    }

    private var homeWalkDistanceMetric: (value: String, unit: String) {
        let formatted = AppMeasurementSystem.formatDistanceMeters(homeWalkDistanceMeters)
        let parts = formatted.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return (formatted, "")
        }
        return (parts[0], parts[1])
    }

    private var electronicPetLevelMetricValue: String {
        let trimmed = (ageText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstNumber = trimmed.split(whereSeparator: { !$0.isNumber }).first,
           !firstNumber.isEmpty
        {
            return String(firstNumber)
        }
        return "\(max(1, critterAppearanceStage))"
    }
}

struct HomeFabFunctionShortcut: Identifiable {
    var label: String
    var icon: String
    var isAvailable: Bool = true
    var badge: String? = nil
    var destination: FMDest? = nil

    var id: String { label }
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
    var badge: String? = nil

    var id: String { "\(label)-\(String(describing: action))" }
}

extension FocusCard {
    static func from(
        _ pet: Pet,
        includeAvatarData: Bool = true,
        includeWalkDistance: Bool = true
    ) -> FocusCard {
        let isDog = pet.species.contains("狗") || pet.species.lowercased().contains("dog")
        let isCat = pet.species.contains("猫") || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")
        let isBird = pet.species.contains("鸟") || pet.species.lowercased().contains("bird")
        let isRabbit = pet.species.contains("兔") || pet.species.lowercased().contains("rabbit")
        let isReptile = pet.species.contains("爬") || pet.species.contains("龟") || pet.species.contains("蛇") || pet.species.contains("蜥") || pet.species.contains("守宫") || pet.species.lowercased().contains("reptile")

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
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh"
        let l = L10n(language)
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
        let walkDistanceMeters = includeWalkDistance ? weeklyWalkDistanceMeters(for: pet) : 0
        let popoutImageData = includeAvatarData && pet.cardStyleRaw == "popout"
            ? (pet.cardPopoutImageData ?? pet.avatarImageData)
            : nil
        return FocusCard(
            id: pet.id,
            name: pet.name.isEmpty ? l.tr(zh: "未命名", en: "Unnamed", de: "Unbenannt") : pet.name,
            kind: pet.hasPassedAway ? l.tr(zh: "彩虹桥", en: "Rainbow Bridge", de: "Regenbogenbrücke") : (pet.species.isEmpty ? "PET" : pet.species),
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
            personalityHint: PetTagGreeting.homeSubtitleHint(pet: pet, hour: hour, l: L10n(language)),
            avatarImageData: includeAvatarData ? pet.avatarImageData : nil,
            avatarImageSignature: includeAvatarData ? pet.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? "" : "",
            cardStyleRaw: pet.cardStyleRaw,
            cardPopoutImageData: popoutImageData,
            cardPopoutImageSignature: popoutImageData.map(FocusWalletAvatarCache.signature(for:)) ?? "",
            cardPopoutSourceRaw: pet.cardPopoutSourceRaw ?? "",
            petSpecies: pet.species,
            coatColor: WalletPetCardTheme.silhouetteCoatColor(for: pet),
            eyeColor: WalletPetCardTheme.silhouetteEyeColor(for: pet),
            patternName: WalletPetCardTheme.coatPatternName(for: pet),
            themeColorHex: hex,
            daysTogether: pet.homeDate == nil ? 0 : togetherDays,
            breed: pet.breed,
            hasPassedAway: pet.hasPassedAway,
            passedAwayDate: pet.passedAwayDate,
            daysTogetherAtPassing: pet.daysTogetherAtPassing,
            isReal: true,
            homeWalkDistanceMeters: walkDistanceMeters,
            actions: Array(acts.prefix(4))
        )
    }

    static func from(_ human: Human, includeAvatarData: Bool = true) -> FocusCard {
        let hex = human.safeThemeColorHex
        let days = human.hasPassedAway
            ? human.daysTogetherAtPassing
            : max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
        let language = AppLanguage.code
        let l = L10n(language)
        return FocusCard(
            id: human.id,
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
            genderText: HumanGenderIdentity.title(for: human.genderRaw),
            avatarImageData: includeAvatarData ? human.avatarImageData : nil,
            avatarImageSignature: includeAvatarData ? human.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? "" : "",
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

    static func from(_ critter: OasisElectronicPet) -> FocusCard {
        let language = AppLanguage.code
        let l = L10n(language)
        let state = critter.lifeState
        let days = max(0, Calendar.current.dateComponents([.day], from: critter.obtainedAt, to: Date()).day ?? 0)
        let themeHex: String
        switch state {
        case .healthy:
            themeHex = "9EF06A"
        case .dead:
            themeHex = "7C828D"
        case .needsCare, .atRisk, .sick, .critical:
            themeHex = "FF4757"
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
                .init(label: l.tr(zh: "玩", en: "PLAY", de: "SPIEL"), icon: "sparkles", colorHex: "80FFEA"),
            ]
        )
    }

    static let dummies: [FocusCard] = [
        FocusCard(id: UUID(), name: "Mochi", kind: "DOG", emoji: "🐶",
                  color: Color(hex: "F4A7B9"), streak: 7, coconutBalance: 42,
                  petSpecies: "狗", coatColor: Color(hex: "D7A76D"), eyeColor: Color(hex: "57341E"),
                  isDummy: true,
                  actions: [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44"),
                            .init(label: "WALK", icon: "figure.walk", colorHex: "14B8A6"),
                            .init(label: "WATER", icon: "drop", colorHex: "00D4AA"),
                            .init(label: "POTTY", icon: "allergens", colorHex: "A78BFA")]),

        FocusCard(id: UUID(), name: "Luna", kind: "CAT", emoji: "🐱",
                  color: Color(hex: "C9B6E4"), streak: 12, coconutBalance: 66,
                  petSpecies: "猫", coatColor: Color(hex: "9CA7B2"), eyeColor: Color(hex: "7A4E20"),
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
                            .init(label: "FILTER", icon: "wrench.and.screwdriver", colorHex: "A78BFA")]),
    ]
}

extension Pet {
    func localizedAgeTextForWallet(birthday: Date, l: L10n) -> String {
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

    func humanEquivalentAgeTextForWallet(birthday: Date, l: L10n) -> String {
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
    func localizedAgeTextForWallet(birthday: Date, l: L10n) -> String {
        let years = max(0, Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0)
        if years >= 1 {
            return l.tr(zh: "\(years)岁", en: "\(years)y", de: "\(years) J.")
        }
        return l.tr(zh: "不满1岁", en: "Under 1", de: "Unter 1")
    }
}

enum FocusPetHumanAgeEstimator {
    static func equivalentHumanYears(birthday: Date, species: String, breed: String) -> Int {
        let ageYears = max(0, Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0) / 365
        let preciseAge = max(0, Double(Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0) / 365.25)
        let normalizedSpecies = species.lowercased()

        if species.contains("狗") || normalizedSpecies.contains("dog") {
            return dogHumanYears(age: preciseAge, breed: breed)
        }
        if species.contains("猫") || normalizedSpecies.contains("cat") {
            return catHumanYears(age: preciseAge)
        }
        if species.contains("兔") || normalizedSpecies.contains("rabbit") {
            return Int((preciseAge * 8.0).rounded())
        }
        if species.contains("仓鼠") || normalizedSpecies.contains("hamster") {
            return Int((preciseAge * 26.0).rounded())
        }
        if species.contains("鸟") || normalizedSpecies.contains("bird") {
            return Int((preciseAge * 5.0).rounded())
        }
        if species.contains("鱼") || normalizedSpecies.contains("fish") {
            return Int((preciseAge * 6.0).rounded())
        }
        return max(0, ageYears)
    }

    private static func dogHumanYears(age: Double, breed: String) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }

        let increment: Double
        switch dogSize(for: breed) {
        case .small: increment = 4
        case .medium: increment = 5
        case .large: increment = 6
        case .giant: increment = 7
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
