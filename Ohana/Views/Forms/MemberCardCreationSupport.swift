//
//  MemberCardCreationSupport.swift
//  Ohana
//
//  Models, candidate provider, save service and avatar media helpers extracted
//  from MemberCardCreationView so the view file stays focused on UI.
//

import AVFoundation
import Combine
import ImageIO
import os
import PhotosUI
import SwiftData
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

struct Avatar2DCandidate: Identifiable, Equatable {
    let id: String
    let filename: String
    let title: String
    let subtitle: String
    let data: Data
    let isDefault: Bool
}

enum Avatar2DCandidateProvider {
    static func candidates(for draft: MemberCreationDraft, l: L10n) -> [Avatar2DCandidate] {
        switch draft.kind {
        case .human:
            return humanCandidates(for: draft, l: l)
        case .pet:
            return petCandidates(for: draft, l: l)
        }
    }

    private static func humanCandidates(for draft: MemberCreationDraft, l: L10n) -> [Avatar2DCandidate] {
        let gender = HumanProfileOptions.normalizedGender(draft.humanGender)
        let fallbackGender = ["男", "女", "非二元"].contains(gender) ? gender : "非二元"
        let birthday = draft.hasBirthday ? draft.birthday : nil
        let defaultFilename = HumanAvatarAssetCatalog.avatarFilename(gender: fallbackGender, birthday: birthday)
        let genderSlug = humanGenderSlug(fallbackGender)
        let groups = HumanAvatarAssetCatalog.AgeGroup.allCases
        let defaultGroup = HumanAvatarAssetCatalog.ageGroup(for: birthday)
        let orderedGroups = ([defaultGroup] + groups.filter { $0 != defaultGroup }).prefix(4)
        var filenames = orderedGroups.map { "human_\(genderSlug)_\($0.rawValue).png" }
        if let defaultFilename {
            filenames.removeAll { $0 == defaultFilename }
            filenames.insert(defaultFilename, at: 0)
        }
        return makeCandidates(
            filenames: Array(filenames),
            defaultFilename: defaultFilename,
            directory: HumanAvatarAssetCatalog.assetDirectory,
            titlePrefix: l.tr(zh: "2.5D 家人", en: "2.5D Member", de: "2,5D Mitglied")
        )
    }

    private static func petCandidates(for draft: MemberCreationDraft, l: L10n) -> [Avatar2DCandidate] {
        let defaultFilename = PetAvatarAssetCatalog.avatarFilename(
            species: draft.species,
            breed: draft.resolvedBreed,
            gender: draft.petGender,
            coatColor: draft.coatColor,
            eyeColor: draft.eyeColor
        )
        let allFilenames = bundledFilenames(directory: PetAvatarAssetCatalog.assetDirectory)
        let speciesPrefix = petSpeciesPrefix(draft.species)
        let breedPrefix = defaultFilename.flatMap { petBreedPrefix(from: $0) }
        var matches: [String] = []
        if let breedPrefix {
            matches = allFilenames.filter { $0.hasPrefix(breedPrefix) }
        }
        if matches.count < 4 {
            matches += allFilenames.filter { $0.hasPrefix(speciesPrefix) && !matches.contains($0) }
        }
        if let defaultFilename {
            matches.removeAll { $0 == defaultFilename }
            matches.insert(defaultFilename, at: 0)
        }
        let limited = Array(matches.prefix(6))
        return makeCandidates(
            filenames: limited,
            defaultFilename: defaultFilename,
            directory: PetAvatarAssetCatalog.assetDirectory,
            titlePrefix: l.tr(zh: "2.5D 宠物", en: "2.5D Pet", de: "2,5D Tier")
        )
    }

    private static func makeCandidates(
        filenames: [String],
        defaultFilename: String?,
        directory: String,
        titlePrefix: String
    ) -> [Avatar2DCandidate] {
        var seen: Set<String> = []
        return filenames.compactMap { filename in
            guard seen.insert(filename).inserted,
                  let data = data(filename: filename, directory: directory)
            else { return nil }
            let clean = filename
                .replacingOccurrences(of: ".png", with: "")
                .split(separator: "_")
                .suffix(2)
                .joined(separator: " ")
            return Avatar2DCandidate(
                id: filename,
                filename: filename,
                title: titlePrefix,
                subtitle: clean.isEmpty ? filename : clean,
                data: data,
                isDefault: filename == defaultFilename
            )
        }
    }

    private static func data(filename: String, directory: String) -> Data? {
        if directory == HumanAvatarAssetCatalog.assetDirectory {
            return HumanAvatarAssetCatalog.avatarData(filename: filename)
        }
        return PetAvatarAssetCatalog.avatarData(filename: filename)
    }

    private static func bundledFilenames(directory: String) -> [String] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: directory) else {
            return []
        }
        return urls
            .map(\.lastPathComponent)
            .filter { $0.contains("_") }
            .sorted()
    }

    private static func humanGenderSlug(_ gender: String) -> String {
        switch HumanProfileOptions.normalizedGender(gender) {
        case "男": return "male"
        case "女": return "female"
        default: return "nonbinary"
        }
    }

    private static func petSpeciesPrefix(_ species: String) -> String {
        let value = species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "猫", "cat", "cats": return "cat_"
        case "狗", "dog", "dogs": return "dog_"
        case "鸟", "bird", "birds": return "bird_"
        case "鱼", "fish", "fishes": return "fish_"
        case "兔", "兔子", "rabbit", "rabbits": return "rabbit_"
        case "爬宠", "爬虫", "reptile", "reptiles": return "reptile_"
        case "仓鼠", "hamster", "hamsters": return "hamster_"
        default: return "pet_"
        }
    }

    private static func petBreedPrefix(from filename: String) -> String? {
        let stem = (filename as NSString).deletingPathExtension
        let parts = stem.split(separator: "_")
        guard parts.count >= 4 else { return nil }
        if parts[1] == "boy" || parts[1] == "girl" { return "\(parts[0])_" }
        return parts.dropLast(2).joined(separator: "_") + "_"
    }
}

enum MemberCreationService {
    struct SaveResult {
        let pet: Pet?
        let human: Human?
    }

    enum ServiceError: LocalizedError {
        case emptyName
        case duplicateName
        case avatarPassRequired
        case insufficientCoconuts(missing: Int)
        case missingActiveHuman
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Name is required."
            case .duplicateName:
                return "Name already exists."
            case .avatarPassRequired:
                return "A 2.5D avatar pass is required."
            case let .insufficientCoconuts(missing):
                return "Need \(missing) more coconuts."
            case .missingActiveHuman:
                return "No active human member."
            case let .saveFailed(message):
                return message
            }
        }
    }

    static var avatarPassCost: Int {
        ShopCatalog.item(id: Avatar2DAccess.shopItemId)?.cost ?? 1500
    }

    @MainActor
    static func currentHuman(in humans: [Human]) -> Human? {
        let activeId = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        if let match = humans.first(where: { $0.id.uuidString == activeId }) {
            return match
        }
        return humans.first
    }

    @MainActor
    static func purchaseAvatarPassForCurrentDraft(humans: [Human], context: ModelContext, l: L10n) throws {
        let cost = avatarPassCost
        guard let human = currentHuman(in: humans) else {
            throw ServiceError.missingActiveHuman
        }
        guard human.coconutBalance >= cost else {
            throw ServiceError.insufficientCoconuts(missing: max(0, cost - human.coconutBalance))
        }
        human.coconutBalance -= cost
        QuestManager.shared.recordCoconutDelta(
            -cost,
            emoji: "2.5D",
            title: l.tr(zh: "兑换「2.5D 头像券」", en: "Redeemed 2.5D Avatar Pass", de: "2,5D-Avatarpass eingelöst"),
            actorId: human.id.uuidString,
            actorName: human.name
        )
        CareLedgerService.record(
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "memberCreationAvatarPassPurchase",
            note: l.tr(zh: "2.5D 头像券", en: "2.5D Avatar Pass", de: "2,5D-Avatarpass"),
            source: .economy,
            coconutDelta: -cost,
            metadataJSON: "{\"shopItemId\":\"\(Avatar2DAccess.shopItemId)\",\"surface\":\"memberCreation\"}",
            context: context,
            save: false
        )
        Avatar2DAccess.addExtraPasses(1)
        context.safeSave()
    }

    @MainActor
    static func save(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String
    ) throws -> SaveResult {
        let trimmed = draft.trimmedName
        guard !trimmed.isEmpty else { throw ServiceError.emptyName }
        let candidate = trimmed.lowercased()
        let names = existingPets.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            + existingHumans.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard !names.contains(candidate) else { throw ServiceError.duplicateName }

        switch draft.kind {
        case .pet:
            return try savePet(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: context
            )
        case .human:
            return try saveHuman(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: context,
                countryCode: countryCode
            )
        }
    }

    @MainActor
    private static func savePet(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext
    ) throws -> SaveResult {
        let existingCount = existingPets.count
        let shouldUse2D = draft.avatarSource == .avatar2D && draft.avatarImageData != nil
        if shouldUse2D && !Avatar2DAccess.hasAccess(kind: .pet, existingCount: existingCount) {
            throw ServiceError.avatarPassRequired
        }
        let pet = Pet(
            name: draft.trimmedName,
            species: draft.species,
            breed: draft.resolvedBreed,
            birthday: draft.hasBirthday ? draft.birthday : nil,
            gender: draft.petGender,
            isNeutered: draft.isNeutered,
            avatarEmoji: speciesEmoji(draft.species),
            themeColorHex: draft.normalizedThemeHex,
            homeDate: draft.hasHomeDate ? draft.homeDate : nil
        )
        pet.avatarImageData = draft.avatarImageData
        pet.coatColor = draft.coatColor
        pet.eyeColor = draft.eyeColor
        pet.personalityTagsRaw = draft.personalityTagIds.joined(separator: ",")
        let previousHiddenHomePetIDsRaw = UserDefaults.standard.string(forKey: HomeCardVisibility.hiddenPetIDsKey)
        let currentHiddenHomePetIDsRaw = previousHiddenHomePetIDsRaw ?? ""
        let shouldShowOnHome = shouldShowNewMemberOnHome(
            existingPets: existingPets,
            existingHumans: existingHumans,
            hiddenPetIDsRaw: currentHiddenHomePetIDsRaw
        )
        if !shouldShowOnHome {
            UserDefaults.standard.set(
                HomeCardVisibility.rawBySettingPet(
                    pet,
                    visible: false,
                    raw: currentHiddenHomePetIDsRaw
                ),
                forKey: HomeCardVisibility.hiddenPetIDsKey
            )
        }
        context.insert(pet)
        do {
            try context.save()
        } catch {
            if !shouldShowOnHome {
                restoreHiddenHomePetIDs(previousHiddenHomePetIDsRaw)
            }
            context.delete(pet)
            throw ServiceError.saveFailed(error.localizedDescription)
        }

        if shouldUse2D {
            Avatar2DAccess.consumeIfNeeded(kind: .pet, existingCount: existingCount)
        }
        insertPetRelatedRecords(pet: pet, draft: draft, context: context)
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context)
        context.safeSave()

        let isFirstPet = !QuestManager.shared.isPetWizardCompleted
        if isFirstPet {
            QuestManager.shared.isPetWizardCompleted = true
            QuestManager.shared.addCoconuts(50, emoji: "2.5D", reason: "新家人入住欢迎奖励")
        }
        NotificationCenter.default.post(
            name: .ohanaMemberProfileDidChange,
            object: nil,
            userInfo: ["id": pet.id.uuidString, "kind": "pet"]
        )
        return SaveResult(pet: pet, human: nil)
    }

    @MainActor
    private static func saveHuman(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String
    ) throws -> SaveResult {
        let existingCount = existingHumans.count
        let shouldUse2D = draft.avatarSource == .avatar2D && draft.avatarImageData != nil
        if shouldUse2D && !Avatar2DAccess.hasAccess(kind: .human, existingCount: existingCount) {
            throw ServiceError.avatarPassRequired
        }
        let human = Human(
            name: draft.trimmedName,
            birthday: draft.hasBirthday ? draft.birthday : nil,
            bloodType: draft.bloodType,
            avatarEmoji: HumanGenderIdentity.fallbackAvatarEmoji(for: draft.humanGender),
            role: existingCount == 0 ? "owner" : "member",
            nationality: draft.nationality,
            city: residenceText(country: draft.residenceCountry, city: draft.residenceCity)
        )
        human.avatarImageData = draft.avatarImageData
        human.themeColorHex = draft.normalizedThemeHex
        human.shouldShowOnHome = shouldShowNewMemberOnHome(
            existingPets: existingPets,
            existingHumans: existingHumans,
            hiddenPetIDsRaw: UserDefaults.standard.string(forKey: HomeCardVisibility.hiddenPetIDsKey) ?? ""
        )
        human.mbti = draft.mbti.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        human.notes = humanNotes(draft: draft)
        if let height = CountryDecimalInput.parse(draft.heightText, countryCode: countryCode), height > 0 {
            human.heightCm = height
        }
        human.setPrivate(.weight, draft.privateWeight)
        human.setPrivate(.workout, draft.privateWorkout)
        human.setPrivate(.medication, draft.privateMedication)
        human.setPrivate(.wishlist, draft.privateWishlist)
        human.setPrivate(.expense, draft.privateExpense)
        context.insert(human)
        if let weight = CountryDecimalInput.parse(draft.weightText, countryCode: countryCode), weight > 0 {
            let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                .flatMap { $0.isEmpty ? nil : $0 }
            context.insert(HumanWeightLog(date: Date(), weight: weight, human: human, executorId: executorId))
            IslandQuestEngine.markInitialHumanWeightRecorded(humanId: human.id)
        }
        if draft.hasBirthday {
            let event = Event(
                title: "\(draft.trimmedName)\(L10n.current.humanWizBirthdayEventSuffix)",
                startDate: draft.birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Human",
                relatedEntityId: human.id.uuidString
            )
            event.recurrenceDays = 365
            context.insert(event)
        }
        do {
            try context.save()
        } catch {
            context.delete(human)
            throw ServiceError.saveFailed(error.localizedDescription)
        }

        if shouldUse2D {
            Avatar2DAccess.consumeIfNeeded(kind: .human, existingCount: existingCount)
        }
        NotificationCenter.default.post(
            name: .ohanaMemberProfileDidChange,
            object: nil,
            userInfo: ["id": human.id.uuidString, "kind": "human"]
        )
        return SaveResult(pet: nil, human: human)
    }

    private static func shouldShowNewMemberOnHome(
        existingPets: [Pet],
        existingHumans: [Human],
        hiddenPetIDsRaw: String
    ) -> Bool {
        HomeCardVisibility.visibleCardCount(
            pets: existingPets,
            humans: existingHumans,
            raw: hiddenPetIDsRaw
        ) < HomeCardVisibility.maxVisibleCards
    }

    private static func restoreHiddenHomePetIDs(_ previousRaw: String?) {
        if let previousRaw {
            UserDefaults.standard.set(previousRaw, forKey: HomeCardVisibility.hiddenPetIDsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: HomeCardVisibility.hiddenPetIDsKey)
        }
    }

    @MainActor
    private static func insertPetRelatedRecords(pet: Pet, draft: MemberCreationDraft, context: ModelContext) {
        if draft.hasBirthday {
            let birthdayEvent = Event(
                title: "\(draft.trimmedName) 的生日 🎂",
                startDate: draft.birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            birthdayEvent.recurrenceDays = 365
            context.insert(birthdayEvent)
            context.insert(Reminder(event: birthdayEvent, scheduledAt: draft.birthday))
        }
        if draft.hasHomeDate {
            let event = Event(
                title: "\(draft.trimmedName) 的到家纪念日 🏠",
                startDate: draft.homeDate,
                isAllDay: true,
                eventType: EventType.anniversary.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 365
            context.insert(event)
        }
    }

    private static func speciesEmoji(_ species: String) -> String {
        switch species {
        case "狗": return "🐕"
        case "猫": return "🐈"
        case "兔子": return "🐇"
        case "鱼": return "🐟"
        case "鸟": return "🦜"
        case "爬宠": return "🦎"
        case "仓鼠": return "🐹"
        default: return "🐾"
        }
    }

    private static func residenceText(country: String, city: String) -> String {
        if country.isEmpty { return city }
        if city.isEmpty { return country }
        return "\(country)·\(city)"
    }

    private static func humanNotes(draft: MemberCreationDraft) -> String {
        [
            "性别:\(HumanProfileOptions.normalizedGender(draft.humanGender))",
            draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "｜")
    }
}

enum MemberAvatarMediaRoute: Identifiable {
    case photoLibrary
    case camera
    case portraitCrop(MemberPortraitCropItem)
    case permissionAlert

    var id: String {
        switch self {
        case .photoLibrary: return "photoLibrary"
        case .camera: return "camera"
        case let .portraitCrop(item): return "portraitCrop-\(item.id.uuidString)"
        case .permissionAlert: return "permissionAlert"
        }
    }
}

enum MemberPortraitCropSource {
    case image(UIImage)
    case photoItem(PhotosPickerItem)
}

struct MemberPortraitCropItem: Identifiable {
    let id = UUID()
    let source: MemberPortraitCropSource
}

@MainActor
final class MemberAvatarMediaCoordinator: ObservableObject {
    @Published var route: MemberAvatarMediaRoute?
    @Published var photoItem: PhotosPickerItem?
    private var didPrepareCamera = false
    private var isRequestingCameraPermission = false

    var isPhotoPickerPresented: Bool {
        if case .photoLibrary = route { return true }
        return false
    }

    var isCameraPresented: Bool {
        if case .camera = route { return true }
        return false
    }

    var cropItem: MemberPortraitCropItem? {
        if case let .portraitCrop(item) = route { return item }
        return nil
    }

    func openPhotoLibrary() {
        MemberCreationPerformance.event("Avatar PhotoPicker Open")
        route = .photoLibrary
    }

    func prepareCameraIfNeeded() {
        guard !didPrepareCamera else { return }
        didPrepareCamera = true
        Task.detached(priority: .utility) {
            let signpostID = MemberCreationPerformance.begin("Camera Device Warmup")
            _ = AVCaptureDevice.authorizationStatus(for: .video)
            _ = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            ).devices.count
            MemberCreationPerformance.end("Camera Device Warmup", signpostID)
        }
    }

    func openCamera() {
        MemberCreationPerformance.event("Avatar Camera Open Request")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            MemberCreationPerformance.event("Avatar Camera Route Presented")
            route = .camera
        case .notDetermined:
            guard !isRequestingCameraPermission else { return }
            isRequestingCameraPermission = true
            let permissionID = MemberCreationPerformance.begin("Camera Permission Request")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    MemberCreationPerformance.end("Camera Permission Request", permissionID)
                    self?.isRequestingCameraPermission = false
                    if granted {
                        MemberCreationPerformance.event("Avatar Camera Route Presented")
                    }
                    self?.route = granted ? .camera : .permissionAlert
                }
            }
        case .denied, .restricted:
            route = .permissionAlert
        @unknown default:
            route = .permissionAlert
        }
    }

    func showCrop(for item: MemberPortraitCropItem) {
        MemberCreationPerformance.event("Avatar Crop Route Presented")
        route = .portraitCrop(item)
    }

    func clearIfRoute(_ routeId: String) {
        guard route?.id == routeId else { return }
        route = nil
    }
}

enum MemberAvatarImageProcessor {
    nonisolated static let portraitAspect: CGFloat = 1.58

    nonisolated static func image(from data: Data, maxPixel: CGFloat = 2400) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data).map(normalized)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data).map(normalized)
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    nonisolated static func downsample(_ image: UIImage, maxPixel: CGFloat, preserveAlpha: Bool) -> UIImage {
        let image = normalized(image)
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preserveAlpha
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    nonisolated static func encodedAvatarData(from image: UIImage) -> Data? {
        let normalized = normalized(image)
        let hasAlpha = ImageCutoutService.imageHasTransparentPixels(normalized)
        if hasAlpha {
            let trimmed = ImageCutoutService.trimmedTransparentSubjectImage(from: normalized) ?? normalized
            return downsample(trimmed, maxPixel: 900, preserveAlpha: true).pngData()
        }
        return downsample(normalized, maxPixel: 1200, preserveAlpha: false).jpegData(compressionQuality: 0.88)
    }

    nonisolated static func encodedCroppedAvatarData(
        image: UIImage,
        scale: CGFloat,
        offset: CGSize,
        outputWidth: CGFloat = 900
    ) -> Data? {
        let outputSize = CGSize(width: outputWidth, height: outputWidth * portraitAspect)
        let cropRect = CGRect(origin: .zero, size: outputSize)
        let baseScale = max(outputSize.width / image.size.width, outputSize.height / image.size.height)
        let renderedSize = CGSize(width: image.size.width * baseScale * scale, height: image.size.height * baseScale * scale)
        let imageFrame = CGRect(
            x: cropRect.midX - renderedSize.width / 2 + offset.width * (outputWidth / 320),
            y: cropRect.midY - renderedSize.height / 2 + offset.height * (outputWidth / 320),
            width: renderedSize.width,
            height: renderedSize.height
        )
        let cropped = croppedImage(
            image: image,
            cropRect: cropRect,
            renderedImageFrame: imageFrame,
            outputSize: outputSize
        )
        return encodedAvatarData(from: cropped)
    }

    nonisolated static func croppedImage(image: UIImage, cropRect: CGRect, renderedImageFrame: CGRect, outputSize: CGSize) -> UIImage {
        let source = normalized(image)
        let scale = max(renderedImageFrame.width / source.size.width, renderedImageFrame.height / source.size.height)
        let originX = (cropRect.minX - renderedImageFrame.minX) / scale
        let originY = (cropRect.minY - renderedImageFrame.minY) / scale
        let sourceRect = CGRect(
            x: max(0, min(source.size.width - 1, originX)),
            y: max(0, min(source.size.height - 1, originY)),
            width: min(source.size.width, cropRect.width / scale),
            height: min(source.size.height, cropRect.height / scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            source.draw(
                in: CGRect(
                    x: -sourceRect.minX * outputSize.width / sourceRect.width,
                    y: -sourceRect.minY * outputSize.height / sourceRect.height,
                    width: source.size.width * outputSize.width / sourceRect.width,
                    height: source.size.height * outputSize.height / sourceRect.height
                )
            )
        }
    }
}
