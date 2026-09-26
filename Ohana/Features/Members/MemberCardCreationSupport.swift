//
//  MemberCardCreationSupport.swift
//  Ohana
//
//  Value models and render snapshots for member card creation.
//

import os
import SwiftUI
import UIKit

private struct MemberCreationCardFlipProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var memberCreationCardFlipProgress: CGFloat? {
        get { self[MemberCreationCardFlipProgressKey.self] }
        set { self[MemberCreationCardFlipProgressKey.self] = newValue }
    }
}

enum MemberCreationPerformance {
    private nonisolated static let log = OSLog(subsystem: "com.guanchen.li.Ohana", category: "MemberCreationPerformance")

    nonisolated static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name)
    }

    @discardableResult
    nonisolated static func begin(_ name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    nonisolated static func end(_ name: StaticString, _ id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }
}

enum MemberCreationCardLayout {
    static let maxCardWidth: CGFloat = 390
    static let horizontalPadding: CGFloat = 16
    static let stackSpacing: CGFloat = 12

    private static let maxCardHeight: CGFloat = 660
    private static let minCardHeight: CGFloat = 430
    private static let bottomActionReserve: CGFloat = 88
    private static let topChromeReserve: CGFloat = 56

    static func cardWidth(in containerWidth: CGFloat) -> CGFloat {
        min(containerWidth - horizontalPadding * 2, maxCardWidth)
    }

    static func cardHeight(in containerHeight: CGFloat, includesTopChrome: Bool) -> CGFloat {
        let chromeReserve = includesTopChrome ? topChromeReserve + stackSpacing : 0
        let availableHeight = max(containerHeight - chromeReserve - bottomActionReserve, minCardHeight)
        return min(max(availableHeight, minCardHeight), maxCardHeight)
    }
}

enum MemberCreationKind: String, Identifiable {
    case pet
    case human

    var id: String { rawValue }

    var avatarKind: Avatar2DAccess.Kind {
        switch self {
        case .pet: .pet
        case .human: .human
        }
    }

    var fallbackThemeHex: String {
        switch self {
        case .pet: OhanaThemeColorPolicy.petFallbackHex
        case .human: OhanaThemeColorPolicy.humanFallbackHex
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .pet:
            l.tr(zh: "制作宠物卡", en: "Create Pet Card", de: "Tierkarte erstellen")
        case .human:
            l.tr(zh: "制作家人卡", en: "Create Member Card", de: "Mitgliedskarte erstellen")
        }
    }

    func typeLabel(_ l: L10n) -> String {
        switch self {
        case .pet:
            l.tr(zh: "宠物", en: "Pet", de: "Tier")
        case .human:
            l.tr(zh: "家人", en: "Member", de: "Mitglied")
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .pet: "pawprint.fill"
        case .human: "person.fill"
        }
    }
}

enum MemberCreationPresentationStyle: Equatable {
    case standard
    case onboarding

    var showsTopChrome: Bool {
        self == .standard
    }

    var keepsBackButtonVisible: Bool {
        self == .onboarding
    }

    var cameraPreparationDelayMilliseconds: UInt64 {
        self == .onboarding ? 560 : 180
    }
}

enum MemberAvatarSource: Equatable {
    case avatar2D
    case customImage
    case placeholder
}

struct MemberCreationDraft: Equatable {
    var kind: MemberCreationKind
    var name = ""
    var themeColorHex: String
    var hasExplicitThemeColor = false
    var avatarSource: MemberAvatarSource = .placeholder
    var selectedAvatarCandidateId: String?
    var avatarImageData: Data?
    var usesPurchasedOrInventoryPass = false

    var species = ""
    var customSpecies = ""
    var isCustomSpecies = false
    var breed = ""
    var customBreed = ""
    var isCustomBreed = false
    var petGender = ""
    var isNeutered = false
    var coatColor = ""
    var hasBirthday = false
    var birthday = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    var hasHomeDate = false
    var homeDate = Date()
    var personalityTagIds: [String] = []

    var humanGender = "nonbinary"
    var bloodType = ""
    var mbti = ""
    var role = "owner"
    var usesExplicitHumanRole = false
    var nationality = ""
    var residenceCountry = ""
    var residenceCity = ""
    var notes = ""
    var heightText = ""
    var weightText = ""
    var privateWeight = false
    var privateWorkout = false
    var privateMedication = false
    var privateWishlist = false
    var privateExpense = false

    init(kind: MemberCreationKind) {
        self.kind = kind
        themeColorHex = kind.fallbackThemeHex
        if kind == .human {
            // A Human profile is optional in Solo. If the user creates one,
            // only its display name is required; birthday and gender stay
            // genuinely absent until the user chooses to add them.
            hasBirthday = false
            humanGender = ""
        }
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedSpecies: String {
        isCustomSpecies ? customSpecies.trimmingCharacters(in: .whitespacesAndNewlines) : species
    }

    var resolvedBreed: String {
        isCustomBreed ? customBreed.trimmingCharacters(in: .whitespacesAndNewlines) : breed
    }

    var normalizedThemeHex: String {
        if kind == .pet, !hasExplicitThemeColor {
            return PetCreationThemePolicy.automaticThemeHex(
                name: trimmedName,
                species: resolvedSpecies,
                breed: resolvedBreed,
                coatColor: coatColor
            )
        }
        return OhanaThemeColorPolicy.normalizedMemberThemeHex(themeColorHex, fallback: kind.fallbackThemeHex)
    }
}

/// Keeps automatic pet colors stable across previews, restarts, and retries.
/// The selection varies with the pet profile without relying on Swift's
/// process-randomized `hashValue`.
nonisolated enum PetCreationThemePolicy {
    private static let palettes: [String: [String]] = [
        "dog": ["E15F41", "E67E22", "8D6E63", "833471"],
        "cat": ["E84393", "8A2BE2", "475569", "D35400"],
        "fish": ["3C40C6", "4834D4", "C71585", "F39C12"],
        "bird": ["C71585", "F39C12", "4834D4", "D35400"],
        "rabbit": ["E84393", "8D6E63", "8A2BE2", "E15F41"],
        "reptile": ["D35400", "8D6E63", "3C40C6", "833471"],
        "hamster": ["E67E22", "F39C12", "8D6E63", "E84393"],
        "other": ["E15F41", "F39C12", "833471", "3C40C6", "E84393"]
    ]

    static func automaticThemeHex(
        name: String,
        species: String,
        breed: String,
        coatColor: String
    ) -> String {
        let speciesKey = Pet.canonicalSpeciesKey(species)
        let normalizedCoat = coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if let coatHex = coatThemeHex(
            species: speciesKey,
            breed: breed,
            coatColor: normalizedCoat
        ) {
            return OhanaThemeColorPolicy.normalizedMemberThemeHex(
                coatHex,
                fallback: OhanaThemeColorPolicy.petFallbackHex
            )
        }

        if !normalizedCoat.isEmpty {
            return stablePaletteHex(
                name: name,
                speciesKey: speciesKey,
                breed: breed,
                coatColor: normalizedCoat
            )
        }

        if let suggested = PetBreedDatabase.breeds(for: speciesKey)
            .first(where: { $0.name == breed })?
            .suggestedThemeHex {
            return OhanaThemeColorPolicy.normalizedMemberThemeHex(
                suggested,
                fallback: OhanaThemeColorPolicy.petFallbackHex
            )
        }

        return stablePaletteHex(
            name: name,
            speciesKey: speciesKey,
            breed: breed,
            coatColor: ""
        )
    }

    private static func coatThemeHex(
        species: String,
        breed: String,
        coatColor: String
    ) -> String? {
        guard !coatColor.isEmpty else { return nil }
        let catalogColors = PetAvatarAssetCatalog.coatColors(species: species, breed: breed) ?? []
        if let match = catalogColors.first(where: { $0.name == coatColor }) {
            return match.hex
        }
        return PetBreedDatabase.breeds(for: species)
            .first(where: { $0.name == breed })?
            .coatColors
            .first(where: { $0.name == coatColor })?
            .hex
    }

    private static func stablePaletteHex(
        name: String,
        speciesKey: String,
        breed: String,
        coatColor: String
    ) -> String {
        let options = palettes[speciesKey] ?? palettes["other"] ?? [OhanaThemeColorPolicy.petFallbackHex]
        let seed = [name, speciesKey, breed, coatColor]
            .joined(separator: "|")
            .lowercased()
        let index = stableIndex(seed, count: options.count)
        return OhanaThemeColorPolicy.normalizedMemberThemeHex(
            options[index],
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
    }

    private static func stableIndex(_ value: String, count: Int) -> Int {
        guard count > 1 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct MemberCreationMediaRecoverySnapshot: Codable {
    var sessionId: String
    var capturedAt: Date
    var name: String
    var themeColorHex: String
    var hasExplicitThemeColor: Bool?
    var species: String
    var customSpecies: String?
    var isCustomSpecies: Bool?
    var breed: String
    var customBreed: String
    var isCustomBreed: Bool
    var petGender: String
    var isNeutered: Bool
    var coatColor: String
    var hasBirthday: Bool
    var birthday: Date
    var hasHomeDate: Bool
    var homeDate: Date
    var personalityTagIds: [String]
    var humanGender: String
    var bloodType: String
    var mbti: String
    var role: String
    var nationality: String
    var residenceCountry: String
    var residenceCity: String
    var notes: String
    var heightText: String
    var weightText: String
    var privateWeight: Bool
    var privateWorkout: Bool
    var privateMedication: Bool
    var privateWishlist: Bool
    var privateExpense: Bool

    init(draft: MemberCreationDraft, sessionId: String, capturedAt: Date = Date()) {
        self.sessionId = sessionId
        self.capturedAt = capturedAt
        name = draft.name
        themeColorHex = draft.themeColorHex
        hasExplicitThemeColor = draft.hasExplicitThemeColor
        species = draft.species
        customSpecies = draft.customSpecies
        isCustomSpecies = draft.isCustomSpecies
        breed = draft.breed
        customBreed = draft.customBreed
        isCustomBreed = draft.isCustomBreed
        petGender = draft.petGender
        isNeutered = draft.isNeutered
        coatColor = draft.coatColor
        hasBirthday = draft.hasBirthday
        birthday = draft.birthday
        hasHomeDate = draft.hasHomeDate
        homeDate = draft.homeDate
        personalityTagIds = draft.personalityTagIds
        humanGender = draft.humanGender
        bloodType = draft.bloodType
        mbti = draft.mbti
        role = draft.role
        nationality = draft.nationality
        residenceCountry = draft.residenceCountry
        residenceCity = draft.residenceCity
        notes = draft.notes
        heightText = draft.heightText
        weightText = draft.weightText
        privateWeight = draft.privateWeight
        privateWorkout = draft.privateWorkout
        privateMedication = draft.privateMedication
        privateWishlist = draft.privateWishlist
        privateExpense = draft.privateExpense
    }

    func apply(to draft: inout MemberCreationDraft) {
        draft.name = name
        draft.themeColorHex = themeColorHex
        draft.hasExplicitThemeColor = hasExplicitThemeColor ?? false
        draft.species = species
        draft.customSpecies = customSpecies ?? ""
        draft.isCustomSpecies = isCustomSpecies ?? false
        draft.breed = breed
        draft.customBreed = customBreed
        draft.isCustomBreed = isCustomBreed
        draft.petGender = ["boy", "girl"].contains(petGender) ? petGender : ""
        draft.isNeutered = isNeutered
        draft.coatColor = coatColor
        draft.hasBirthday = hasBirthday
        draft.birthday = birthday
        draft.hasHomeDate = hasHomeDate
        draft.homeDate = homeDate
        draft.personalityTagIds = personalityTagIds
        draft.humanGender = humanGender
        draft.bloodType = bloodType
        draft.mbti = mbti
        draft.role = role
        draft.nationality = nationality
        draft.residenceCountry = residenceCountry
        draft.residenceCity = residenceCity
        draft.notes = notes
        draft.heightText = heightText
        draft.weightText = weightText
        draft.privateWeight = privateWeight
        draft.privateWorkout = privateWorkout
        draft.privateMedication = privateMedication
        draft.privateWishlist = privateWishlist
        draft.privateExpense = privateExpense
    }

    var isFresh: Bool {
        Date().timeIntervalSince(capturedAt) < 30 * 60
    }
}

struct MemberCardRenderSnapshot {
    let kind: MemberCreationKind
    let title: String
    let subtitle: String
    let themeColorHex: String
    let avatarImage: UIImage?
    let avatarIsTransparent: Bool
    let avatarSource: MemberAvatarSource
    let fallbackSymbol: String
    let statusText: String
}

enum MemberCreationStep: String, Identifiable, Hashable {
    case basicInfo
    case petName
    case petIdentity
    case petAppearance
    case avatar
    case petPersonality
    case theme

    var id: String { rawValue }

    static func steps(for kind: MemberCreationKind) -> [MemberCreationStep] {
        switch kind {
        case .human:
            [.basicInfo, .avatar, .theme]
        case .pet:
            [.petName, .petIdentity, .petAppearance, .petPersonality, .avatar]
        }
    }

    func title(kind _: MemberCreationKind, l: L10n) -> String {
        switch self {
        case .basicInfo:
            l.tr(zh: "基础信息", en: "Basic info", de: "Basisdaten")
        case .petName:
            l.tr(zh: "名字", en: "Name", de: "Name")
        case .petIdentity:
            l.tr(zh: "物种与品种", en: "Species & breed", de: "Art & Rasse")
        case .petAppearance:
            l.tr(zh: "外观", en: "Appearance", de: "Aussehen")
        case .avatar:
            l.tr(zh: "头像", en: "Avatar", de: "Avatar")
        case .petPersonality:
            l.tr(zh: "性格", en: "Personality", de: "Charakter")
        case .theme:
            l.tr(zh: "主题色", en: "Theme color", de: "Themenfarbe")
        }
    }
}
