//
//  MemberCardCreationSupport.swift
//  Ohana
//
//  Value models and render snapshots for member card creation.
//

import os
import SwiftUI
import UIKit

enum MemberCreationPerformance {
    private nonisolated static let log = OSLog(subsystem: "HT.Ohana", category: "MemberCreationPerformance")

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

enum MemberCreationKind: String, Identifiable {
    case pet
    case human

    var id: String { rawValue }

    var avatarKind: Avatar2DAccess.Kind {
        switch self {
        case .pet: return .pet
        case .human: return .human
        }
    }

    var fallbackThemeHex: String {
        switch self {
        case .pet: return OhanaThemeColorPolicy.petFallbackHex
        case .human: return OhanaThemeColorPolicy.humanFallbackHex
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .pet:
            return l.tr(zh: "制作宠物卡", en: "Create Pet Card", de: "Tierkarte erstellen")
        case .human:
            return l.tr(zh: "制作家人卡", en: "Create Member Card", de: "Mitgliedskarte erstellen")
        }
    }

    func typeLabel(_ l: L10n) -> String {
        switch self {
        case .pet:
            return l.tr(zh: "宠物", en: "Pet", de: "Tier")
        case .human:
            return l.tr(zh: "家人", en: "Member", de: "Mitglied")
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .human: return "person.fill"
        }
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
    var avatarSource: MemberAvatarSource = .placeholder
    var selectedAvatarCandidateId: String?
    var avatarImageData: Data?
    var usesPurchasedOrInventoryPass = false

    var species = "狗"
    var breed = ""
    var customBreed = ""
    var isCustomBreed = false
    var petGender = "unknown"
    var isNeutered = false
    var coatColor = ""
    var eyeColor = ""
    var hasBirthday = true
    var birthday = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    var hasHomeDate = false
    var homeDate = Date()
    var personalityTagIds: [String] = []

    var humanGender = "非二元"
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
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedBreed: String {
        isCustomBreed ? customBreed.trimmingCharacters(in: .whitespacesAndNewlines) : breed
    }

    var normalizedThemeHex: String {
        OhanaThemeColorPolicy.normalizedMemberThemeHex(themeColorHex, fallback: kind.fallbackThemeHex)
    }
}

struct MemberCreationMediaRecoverySnapshot: Codable {
    var sessionId: String
    var capturedAt: Date
    var name: String
    var themeColorHex: String
    var species: String
    var breed: String
    var customBreed: String
    var isCustomBreed: Bool
    var petGender: String
    var isNeutered: Bool
    var coatColor: String
    var eyeColor: String
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
        species = draft.species
        breed = draft.breed
        customBreed = draft.customBreed
        isCustomBreed = draft.isCustomBreed
        petGender = draft.petGender
        isNeutered = draft.isNeutered
        coatColor = draft.coatColor
        eyeColor = draft.eyeColor
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
        draft.species = species
        draft.breed = breed
        draft.customBreed = customBreed
        draft.isCustomBreed = isCustomBreed
        draft.petGender = petGender
        draft.isNeutered = isNeutered
        draft.coatColor = coatColor
        draft.eyeColor = eyeColor
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
    case petProfile
    case avatar
    case theme

    var id: String { rawValue }

    static func steps(for kind: MemberCreationKind) -> [MemberCreationStep] {
        switch kind {
        case .human:
            return [.basicInfo, .avatar, .theme]
        case .pet:
            return [.basicInfo, .petProfile, .avatar, .theme]
        }
    }

    func title(kind _: MemberCreationKind, l: L10n) -> String {
        switch self {
        case .basicInfo:
            return l.tr(zh: "基础信息", en: "Basic info", de: "Basisdaten")
        case .petProfile:
            return l.tr(zh: "品种与性格", en: "Breed & vibe", de: "Rasse & Charakter")
        case .avatar:
            return l.tr(zh: "头像", en: "Avatar", de: "Avatar")
        case .theme:
            return l.tr(zh: "主题色", en: "Theme color", de: "Themenfarbe")
        }
    }
}

