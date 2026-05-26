//
//  MemberCardCreationView.swift
//  Ohana
//
//  Portrait-card member creation flow for humans and pets.
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
    case avatar
    case humanRegion
    case humanWellbeing
    case petProfile
    case petVibe
    case theme

    var id: String { rawValue }

    static func steps(for kind: MemberCreationKind) -> [MemberCreationStep] {
        switch kind {
        case .human:
            return [.basicInfo, .avatar, .humanRegion, .humanWellbeing, .theme]
        case .pet:
            return [.basicInfo, .avatar, .petProfile, .petVibe, .theme]
        }
    }

    func title(kind _: MemberCreationKind, l: L10n) -> String {
        switch self {
        case .basicInfo:
            return l.tr(zh: "基础信息", en: "Basic info", de: "Basisdaten")
        case .avatar:
            return l.tr(zh: "头像", en: "Avatar", de: "Avatar")
        case .humanRegion:
            return l.tr(zh: "地区", en: "Region", de: "Region")
        case .humanWellbeing:
            return l.tr(zh: "个性与身体", en: "Personality & body", de: "Persönlichkeit & Körper")
        case .petProfile:
            return l.tr(zh: "物种与外观", en: "Species & look", de: "Art & Aussehen")
        case .petVibe:
            return l.tr(zh: "性格", en: "Vibe", de: "Charakter")
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

struct MemberPortraitCropItem: Identifiable {
    let id = UUID()
    let image: UIImage
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

    func showCrop(for image: UIImage) {
        MemberCreationPerformance.event("Avatar Crop Route Presented")
        route = .portraitCrop(MemberPortraitCropItem(image: image))
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

struct MemberCardCreationView: View {
    let kind: MemberCreationKind
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onPetSaved: ((Pet) -> Void)?
    var onHumanSaved: ((Human) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage(Avatar2DAccess.extraPassInventoryKey) private var avatarPassCount = 0
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    @State private var draft: MemberCreationDraft
    @State private var decodedAvatar: UIImage?
    @State private var decodedAvatarTransparent = false
    @State private var decodeTask: Task<Void, Never>?
    @StateObject private var media = MemberAvatarMediaCoordinator()
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showPurchaseConfirm = false
    @State private var didConfigureInitialAvatar = false
    @State private var didConfigureAvatarStep = false
    @State private var shouldApply2DAfterPurchase = false
    @State private var didShowSuccess = false
    @State private var isPreparingCamera = false
    @State private var currentStep: MemberCreationStep = .basicInfo
    @State private var mbtiEnergy = ""
    @State private var mbtiInformation = ""
    @State private var mbtiDecision = ""
    @State private var mbtiLifestyle = ""
    @State private var usesCustomResidenceCity = false
    @State private var isJoinHandoffRunning = false
    @State private var joinHandoffProgress: CGFloat = 0
    @State private var joinSaveTask: Task<Void, Never>?

    init(
        kind: MemberCreationKind,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onPetSaved: ((Pet) -> Void)? = nil,
        onHumanSaved: ((Human) -> Void)? = nil
    ) {
        self.kind = kind
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onPetSaved = onPetSaved
        self.onHumanSaved = onHumanSaved
        _draft = State(initialValue: MemberCreationDraft(kind: kind))
    }

    private var l: L10n { L10n(appLanguage) }
    private var existingCount: Int { kind == .pet ? existingPets.count : existingHumans.count }
    private var canUseFree2D: Bool { Avatar2DAccess.usesFreeSlot(kind: kind.avatarKind, existingCount: existingCount) }
    private var has2DAccess: Bool { canUseFree2D || avatarPassCount > 0 }
    private var currentHuman: Human? { MemberCreationService.currentHuman(in: existingHumans) }
    private var currentBalance: Int { currentHuman?.coconutBalance ?? 0 }
    private var avatarPassCost: Int { MemberCreationService.avatarPassCost }
    private var duplicateName: Bool {
        let candidate = draft.trimmedName.lowercased()
        guard !candidate.isEmpty else { return false }
        let names = existingPets.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            + existingHumans.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return names.contains(candidate)
    }

    private var canSave: Bool {
        !isSaving && !isJoinHandoffRunning && !draft.trimmedName.isEmpty && !duplicateName
    }

    private var creationSteps: [MemberCreationStep] { MemberCreationStep.steps(for: kind) }
    private var currentStepIndex: Int { creationSteps.firstIndex(of: currentStep) ?? 0 }
    private var isLastStep: Bool { currentStepIndex == creationSteps.count - 1 }
    private var canAdvanceStep: Bool {
        guard !isSaving, !isJoinHandoffRunning else { return false }
        if currentStep == .basicInfo {
            return !draft.trimmedName.isEmpty && !duplicateName
        }
        return true
    }

    private var canRunHomeJoinHandoff: Bool {
        HomeCardVisibility.visibleCardCount(
            pets: existingPets,
            humans: existingHumans,
            raw: hiddenHomePetIDsRaw
        ) < HomeCardVisibility.maxVisibleCards
    }

    private var mbtiSignature: String {
        [mbtiEnergy, mbtiInformation, mbtiDecision, mbtiLifestyle].joined(separator: "|")
    }

    private var cardAccent: Color {
        Color(hex: draft.normalizedThemeHex)
    }

    private var prefersDarkCardForeground: Bool {
        WalletPetCardTheme.prefersDarkForeground(for: draft.normalizedThemeHex)
    }

    private var cardForeground: Color {
        prefersDarkCardForeground ? Color.arkInk : Color.goCardWhite
    }

    private var cardSecondaryForeground: Color {
        cardForeground.opacity(0.68)
    }

    private var cardControlFill: Color {
        prefersDarkCardForeground
            ? cardAccent.mix(with: .white, by: 0.82)
            : cardAccent.mix(with: .black, by: 0.48)
    }

    private var cardControlStroke: Color {
        prefersDarkCardForeground
            ? cardAccent.mix(with: .black, by: 0.18)
            : cardAccent.mix(with: .white, by: 0.22)
    }

    private var cardSelectedFill: Color {
        Color.goPrimary
    }

    private var cardSelectedForeground: Color {
        Color.arkInk
    }

    private var stepContentSpacing: CGFloat { 18 }

    private var snapshot: MemberCardRenderSnapshot {
        let displayName = draft.trimmedName.isEmpty ? l.tr(zh: "新成员", en: "New member", de: "Neues Mitglied") : draft.trimmedName
        return MemberCardRenderSnapshot(
            kind: kind,
            title: displayName,
            subtitle: cardSubtitle,
            themeColorHex: draft.normalizedThemeHex,
            avatarImage: decodedAvatar,
            avatarIsTransparent: decodedAvatarTransparent,
            avatarSource: draft.avatarSource,
            fallbackSymbol: kind == .pet ? petFallbackSymbol : "person.fill",
            statusText: avatarStatusText
        )
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 12) {
                topChrome
                    .opacity(isJoinHandoffRunning ? 0.28 : 1)
                MemberPortraitDraftCardSurface(snapshot: snapshot) {
                    cardControls
                }
                .frame(maxWidth: 390)
                .frame(maxHeight: .infinity)
                .modifier(MemberCreationJoinHandoffModifier(
                    progress: joinHandoffProgress,
                    reduceMotion: reduceMotion
                ))
                .allowsHitTesting(!isJoinHandoffRunning)
                bottomCTA
                    .opacity(isJoinHandoffRunning ? 0 : 1)
                    .allowsHitTesting(!isJoinHandoffRunning)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            if didShowSuccess {
                AddWizardJoinCelebrationOverlay(
                    title: l.tr(zh: "\(draft.trimmedName) 已加入 Ohana", en: "\(draft.trimmedName) joined Ohana", de: "\(draft.trimmedName) ist bei Ohana"),
                    subtitle: l.tr(zh: "成员竖卡已准备好", en: "The portrait card is ready", de: "Die Hochformatkarte ist bereit"),
                    systemImage: kind == .pet ? "pawprint.fill" : "person.crop.circle.badge.checkmark",
                    accent: Color(hex: draft.normalizedThemeHex)
                )
                .zIndex(50)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            MemberCreationPerformance.event("Member Creation Appeared")
            configureInitialAvatarIfNeeded()
            scheduleAvatarDecode()
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
                media.prepareCameraIfNeeded()
            }
        }
        .onDisappear {
            MemberCreationPerformance.event("Member Creation Disappeared")
            decodeTask?.cancel()
            joinSaveTask?.cancel()
        }
        .onChange(of: draft.name) { _, _ in
            MemberCreationPerformance.event("Draft Name Changed")
        }
        .onChange(of: draft.avatarImageData) { _, _ in scheduleAvatarDecode() }
        .onChange(of: avatarRefreshSignature) { _, _ in refresh2DAvatarForProfileChange() }
        .onChange(of: mbtiSignature) { _, _ in updateDraftMBTI() }
        .onChange(of: currentStep) { _, newStep in
            if newStep == .avatar {
                configureAvatarStepIfNeeded()
            }
        }
        .onChange(of: media.photoItem) { _, item in handlePhotoPickerItem(item) }
        .photosPicker(
            isPresented: Binding(
                get: { media.isPhotoPickerPresented },
                set: { isPresented in
                    if !isPresented, media.isPhotoPickerPresented {
                        media.route = nil
                    }
                }
            ),
            selection: $media.photoItem,
            matching: .images
        )
        .fullScreenCover(
            isPresented: Binding(
                get: { media.isCameraPresented },
                set: { isPresented in
                    if !isPresented, media.isCameraPresented {
                        media.route = nil
                    }
                }
            )
        ) {
            MemberCameraCaptureView(maxPixel: 2000) { image in
                media.route = nil
                OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let normalizeID = MemberCreationPerformance.begin("Camera Image Normalize")
                        let prepared = MemberAvatarImageProcessor.normalized(image)
                        MemberCreationPerformance.end("Camera Image Normalize", normalizeID)
                        DispatchQueue.main.async {
                            media.showCrop(for: prepared)
                        }
                    }
                }
            } onCancel: {
                media.route = nil
            }
        }
        .sheet(
            item: Binding<MemberPortraitCropItem?>(
                get: { media.cropItem },
                set: { item in
                    if item == nil, media.cropItem != nil {
                        media.route = nil
                    }
                }
            )
        ) { item in
            MemberPortraitCropView(image: item.image) { data in
                withAnimation(GoMotion.selection) {
                    draft.avatarSource = .customImage
                    draft.selectedAvatarCandidateId = nil
                    draft.usesPurchasedOrInventoryPass = false
                    draft.avatarImageData = data
                }
                media.route = nil
            } onCancel: {
                media.route = nil
            }
            .presentationDetents([.large]) // ui-v4: allow portrait crop editor needs full-height working area
        }
        .alert(l.tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar"), isPresented: permissionAlertBinding) {
            Button(l.done, role: .cancel) { media.route = nil }
        } message: {
            Text(l.tr(zh: "请在系统设置中允许 Ohana 访问相机，或在支持相机的设备上使用。", en: "Allow camera access in Settings, or use a device with a camera.", de: "Erlaube den Kamerazugriff in den Einstellungen oder nutze ein Gerät mit Kamera."))
        }
        .alert(l.tr(zh: "购买 2.5D 头像券", en: "Buy 2.5D Avatar Pass", de: "2,5D-Avatarpass kaufen"), isPresented: $showPurchaseConfirm) {
            Button(l.cancel, role: .cancel) { shouldApply2DAfterPurchase = false }
            Button(l.tr(zh: "购买头像券", en: "Buy pass", de: "Pass kaufen")) {
                purchaseAvatarPass()
            }
        } message: {
            Text(l.tr(zh: "将消耗 \(avatarPassCost) 个椰子。购买后会为当前草稿开启智能 2.5D 头像；取消创建时头像券仍保留。", en: "Costs \(avatarPassCost) coconuts. After purchase, the smart 2.5D avatar is applied to this draft; canceling creation keeps the pass.", de: "Kostet \(avatarPassCost) Kokosnüsse. Danach wird der smarte 2,5D-Avatar auf diesen Entwurf angewendet; beim Abbrechen bleibt der Pass erhalten."))
        }
        .alert(l.tr(zh: "无法创建成员", en: "Could not create member", de: "Mitglied konnte nicht erstellt werden"), isPresented: $showError) {
            Button(l.done, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var permissionAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .permissionAlert = media.route { return true }
                return false
            },
            set: { isShowing in
                if !isShowing, case .permissionAlert = media.route {
                    media.route = nil
                }
            }
        )
    }

    private var topChrome: some View {
        HStack(spacing: 10) {
            Button {
                onCancel?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.cancel)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title(l))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(l.tr(zh: "在卡片上完成资料", en: "Build the profile on the card", de: "Profil direkt auf der Karte erstellen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var cardControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            MemberCreationStepIndicator(
                steps: creationSteps,
                currentStep: currentStep,
                kind: kind,
                l: l,
                foreground: cardForeground,
                secondaryForeground: cardSecondaryForeground,
                inactiveFill: cardControlFill
            )
            currentStepContent
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch currentStep {
        case .basicInfo:
            if kind == .pet {
                petBasicInfoStep
            } else {
                humanBasicInfoStep
            }
        case .avatar:
            avatarSection
        case .humanRegion:
            humanRegionSection
        case .humanWellbeing:
            humanWellbeingSection
        case .petProfile:
            petProfileSection
        case .petVibe:
            petVibeSection
        case .theme:
            themeSection
        }
    }

    private var bottomCTA: some View {
        let isEnabled = isLastStep ? canSave : canAdvanceStep
        return VStack(spacing: 8) {
            if duplicateName {
                Text(l.tr(zh: "这个名字已经被使用。", en: "This name is already in use.", de: "Dieser Name wird bereits verwendet."))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
            }
            HStack(spacing: 10) {
                if currentStepIndex > 0 {
                    Button {
                        retreatStep()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .black))
                            Text(l.tr(zh: "上一步", en: "Back", de: "Zurück"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                        .frame(width: 104, height: 54)
                        .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isJoinHandoffRunning)
                }

                Button {
                    if isLastStep {
                        save()
                    } else {
                        advanceStep()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(Color.ohanaPrimaryActionText)
                        } else {
                            Image(systemName: isLastStep ? "checkmark.seal.fill" : "chevron.right")
                        }
                        Text(isLastStep ? creationCTA : l.tr(zh: "下一步", en: "Next", de: "Weiter"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(isEnabled ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isEnabled ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!isEnabled)
            }
            .frame(maxWidth: 390)
        }
    }

    private var creationCTA: String {
        l.tr(zh: "加入岛屿", en: "Join Island", de: "Insel beitreten")
    }

    private var humanBasicInfoStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "基础与日期", en: "Basics & date", de: "Basis & Datum"),
            icon: "person.crop.rectangle.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    compactNameInput(width: 148)
                    compactOptionRow(options: humanGenderOptions, selection: $draft.humanGender) { humanGenderLabel($0) }
                }
                MemberCompactDateRow(
                    title: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"),
                    icon: "birthday.cake.fill",
                    isEnabled: $draft.hasBirthday,
                    date: $draft.birthday,
                    range: birthdayRange,
                    foreground: cardForeground,
                    secondaryForeground: cardSecondaryForeground,
                    fill: cardControlFill,
                    stroke: cardControlStroke
                )
            }
        }
    }

    private var petBasicInfoStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "基础与日期", en: "Basics & dates", de: "Basis & Daten"),
            icon: "pawprint.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    compactNameInput(width: 148)
                    compactOptionRow(options: petGenderOptions, selection: $draft.petGender) { petGenderLabel($0) }
                }
                MemberCompactDateRow(
                    title: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"),
                    icon: "birthday.cake.fill",
                    isEnabled: $draft.hasBirthday,
                    date: $draft.birthday,
                    range: birthdayRange,
                    foreground: cardForeground,
                    secondaryForeground: cardSecondaryForeground,
                    fill: cardControlFill,
                    stroke: cardControlStroke
                )
                MemberCompactDateRow(
                    title: l.tr(zh: "到家日", en: "Home date", de: "Einzugstag"),
                    icon: "house.fill",
                    isEnabled: $draft.hasHomeDate,
                    date: $draft.homeDate,
                    range: birthdayRange,
                    foreground: cardForeground,
                    secondaryForeground: cardSecondaryForeground,
                    fill: cardControlFill,
                    stroke: cardControlStroke
                )
            }
        }
    }

    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(l.tr(zh: "头像", en: "Avatar", de: "Avatar"), systemImage: "sparkles")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardForeground)
                Spacer()
                avatar2DToggleButton
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    mediaButton(title: l.tr(zh: "相册", en: "Photos", de: "Fotos"), icon: "photo.on.rectangle") {
                        GoKeyboard.dismiss()
                        media.openPhotoLibrary()
                    }
                    mediaButton(title: isPreparingCamera ? l.tr(zh: "打开中", en: "Opening", de: "Öffnet") : l.tr(zh: "相机", en: "Camera", de: "Kamera"), icon: "camera.fill") {
                        openCameraAfterFirstFrame()
                    }
                }
                if let hint = avatarHintText {
                    Text(hint)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(cardSecondaryForeground)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var avatar2DToggleButton: some View {
        let isOn = draft.avatarSource == .avatar2D
        return Button {
            toggle2DAvatar()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .black))
                Text("2.5D")
                    .font(OhanaFont.caption(.black))
                Circle()
                    .fill(isOn ? cardSelectedForeground : cardForeground)
                    .frame(width: 8, height: 8)
            }
            .foregroundStyle(isOn ? cardSelectedForeground : cardForeground)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isOn ? cardSelectedFill : cardControlFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(cardControlStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "2.5D 头像开关", en: "2.5D avatar switch", de: "2,5D-Avatar-Schalter"))
    }

    private var avatarHintText: String? {
        if draft.avatarSource == .avatar2D {
            return canUseFree2D
                ? l.tr(zh: "已使用首位免费智能 2.5D。", en: "Using the first free smart 2.5D avatar.", de: "Der erste kostenlose smarte 2,5D-Avatar ist aktiv.")
                : l.tr(zh: "保存时将消耗 1 张头像券。", en: "Saving will use 1 avatar pass.", de: "Beim Speichern wird 1 Avatarpass verwendet.")
        }
        if !canUseFree2D, avatarPassCount > 0 {
            return l.tr(zh: "你有 \(avatarPassCount) 张头像券，可手动开启 2.5D。", en: "You have \(avatarPassCount) avatar pass; turn on 2.5D when you want it.", de: "Du hast \(avatarPassCount) Avatarpass; aktiviere 2,5D bei Bedarf.")
        }
        if !canUseFree2D {
            return l.tr(zh: "2.5D 头像券 \(avatarPassCost) 椰子。", en: "A 2.5D avatar pass costs \(avatarPassCost) coconuts.", de: "Ein 2,5D-Avatarpass kostet \(avatarPassCost) Kokosnüsse.")
        }
        return nil
    }

    private var petProfileSection: some View {
        MemberCreationSection(
            title: l.tr(zh: "物种与外观", en: "Species & look", de: "Art & Aussehen"),
            icon: "list.bullet.clipboard.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 10) {
                compactMenuPicker(
                    title: l.tr(zh: "物种", en: "Species", de: "Art"),
                    value: speciesLabel(draft.species)
                ) {
                    ForEach(speciesOptions, id: \.self) { species in
                        Button(speciesLabel(species)) {
                            draft.species = species
                            draft.breed = ""
                            draft.customBreed = ""
                            draft.isCustomBreed = false
                            clampPetAppearance()
                        }
                    }
                }
                menuPicker(title: l.tr(zh: "品种", en: "Breed", de: "Rasse"), value: draft.resolvedBreed.isEmpty ? l.tr(zh: "选择品种", en: "Choose breed", de: "Rasse wählen") : draft.resolvedBreed) {
                    ForEach(petBreedOptions.prefix(40), id: \.name) { breed in
                        Button(breed.name) {
                            draft.isCustomBreed = breed.name == "其他"
                            draft.breed = breed.name == "其他" ? "" : breed.name
                            clampPetAppearance()
                        }
                    }
                }
                if draft.isCustomBreed {
                    flatTextField(l.tr(zh: "自定义品种", en: "Custom breed", de: "Eigene Rasse"), text: $draft.customBreed)
                }
                HStack(spacing: 10) {
                    compactMenuPicker(title: l.tr(zh: "毛色", en: "Coat", de: "Fell"), value: draft.coatColor.isEmpty ? l.tr(zh: "自动", en: "Auto", de: "Auto") : draft.coatColor) {
                        ForEach(petCoatOptions, id: \.self) { option in
                            Button(option) {
                                draft.coatColor = option
                                clampPetAppearance()
                            }
                        }
                    }
                    compactMenuPicker(title: l.tr(zh: "眼睛", en: "Eyes", de: "Augen"), value: draft.eyeColor.isEmpty ? l.tr(zh: "自动", en: "Auto", de: "Auto") : draft.eyeColor) {
                        ForEach(petEyeOptions, id: \.self) { option in
                            Button(option) {
                                draft.eyeColor = option
                                clampPetAppearance()
                            }
                        }
                    }
                }
            }
        }
    }

    private var petVibeSection: some View {
        MemberCreationSection(
            title: l.tr(zh: "性格", en: "Vibe", de: "Charakter"),
            icon: "heart.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                compactTogglePill(
                    title: l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"),
                    icon: "checkmark.seal.fill",
                    isOn: $draft.isNeutered
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], spacing: 7) {
                    ForEach(Array(PetPersonalityTag.allTags.prefix(8).map(\.id)), id: \.self) { id in
                        let isSelected = draft.personalityTagIds.contains(id)
                        Button {
                            withAnimation(GoMotion.selection) {
                                if draft.personalityTagIds.contains(id) {
                                    draft.personalityTagIds.removeAll { $0 == id }
                                } else {
                                    if draft.personalityTagIds.count >= 3 {
                                        draft.personalityTagIds.removeFirst()
                                    }
                                    draft.personalityTagIds.append(id)
                                }
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text(personalityLabel(id))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(cardControlStroke, lineWidth: 1)
                                }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var humanRegionSection: some View {
        MemberCreationSection(title: l.tr(zh: "地区", en: "Region", de: "Region"), icon: "location.fill", foreground: cardForeground) {
            VStack(alignment: .leading, spacing: 10) {
                menuPicker(title: l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), value: draft.nationality.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : draft.nationality) {
                    ForEach(PetBreedDatabase.countries, id: \.self) { country in
                        Button(country) { draft.nationality = country }
                    }
                }
                menuPicker(title: l.tr(zh: "现居国家", en: "Residence", de: "Wohnort"), value: draft.residenceCountry.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : draft.residenceCountry) {
                    ForEach(PetBreedDatabase.countries, id: \.self) { country in
                        Button(country) {
                            draft.residenceCountry = country
                            draft.residenceCity = ""
                            usesCustomResidenceCity = false
                        }
                    }
                }
                MemberCompactCityPicker(
                    country: draft.residenceCountry,
                    city: $draft.residenceCity,
                    usesCustomCity: $usesCustomResidenceCity
                )
            }
        }
    }

    private var humanWellbeingSection: some View {
        MemberCreationSection(title: l.tr(zh: "个性与身体", en: "Personality & body", de: "Persönlichkeit & Körper"), icon: "person.text.rectangle.fill", foreground: cardForeground) {
            VStack(alignment: .leading, spacing: 12) {
                compactOptionRow(options: bloodTypes, selection: $draft.bloodType) { bloodTypeLabel($0) }
                MemberCompactMBTIBar(
                    energy: $mbtiEnergy,
                    information: $mbtiInformation,
                    decision: $mbtiDecision,
                    lifestyle: $mbtiLifestyle,
                    foreground: cardForeground
                ) {
                    updateDraftMBTI()
                }
                HStack(spacing: 10) {
                    compactHumanMetricInput(
                        title: l.tr(zh: "身高", en: "Height", de: "Größe"),
                        text: $draft.heightText,
                        placeholder: "170",
                        unit: "cm",
                        maxFractionDigits: 0
                    )
                    compactHumanMetricInput(
                        title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                        text: $draft.weightText,
                        placeholder: "60",
                        unit: "kg",
                        maxFractionDigits: 1
                    )
                }
                privacyPillGrid
            }
        }
    }

    private var themeSection: some View {
        MemberCreationSection(title: l.tr(zh: "主题色", en: "Theme color", de: "Themenfarbe"), icon: "circle.hexagongrid.fill", foreground: cardForeground) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(AddWizardThemePalette.memberOptions, id: \.hex) { option in
                    Button {
                        withAnimation(GoMotion.selection) {
                            draft.themeColorHex = option.hex
                        }
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 34, height: 34)
                            .overlay {
                                if draft.normalizedThemeHex.uppercased() == option.hex.uppercased() {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(WalletPetCardTheme.prefersDarkForeground(for: option.hex) ? Color.arkInk : Color.goCardWhite)
                                }
                            }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(option.label)
                }
            }
        }
    }

    private var privacyToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(l.tr(zh: "体重隐私", en: "Private weight", de: "Gewicht privat"), isOn: $draft.privateWeight)
            Toggle(l.tr(zh: "运动隐私", en: "Private workouts", de: "Training privat"), isOn: $draft.privateWorkout)
            Toggle(l.tr(zh: "用药隐私", en: "Private medication", de: "Medikation privat"), isOn: $draft.privateMedication)
            Toggle(l.tr(zh: "愿望隐私", en: "Private wishlist", de: "Wunschliste privat"), isOn: $draft.privateWishlist)
            Toggle(l.tr(zh: "消费隐私", en: "Private expenses", de: "Ausgaben privat"), isOn: $draft.privateExpense)
        }
        .font(OhanaFont.caption(.bold))
        .foregroundStyle(cardForeground)
        .tint(Color.goPrimary)
    }

    private var birthdayRange: ClosedRange<Date> {
        let end = Date()
        let start = Calendar.current.date(byAdding: .year, value: -120, to: end) ?? end
        return start ... end
    }

    private var avatarCandidates: [Avatar2DCandidate] {
        Avatar2DCandidateProvider.candidates(for: draft, l: l)
    }

    private var avatarRefreshSignature: String {
        [
            draft.kind.rawValue,
            draft.species,
            draft.resolvedBreed,
            draft.petGender,
            draft.coatColor,
            draft.eyeColor,
            draft.humanGender,
            "\(draft.hasBirthday)",
            "\(draft.birthday.timeIntervalSince1970.rounded())",
        ].joined(separator: "|")
    }

    private var cardSubtitle: String {
        switch kind {
        case .pet:
            return [speciesLabel(draft.species), draft.resolvedBreed, draft.petGender == "unknown" ? "" : petGenderLabel(draft.petGender)]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .human:
            return [humanGenderLabel(draft.humanGender), draft.mbti.uppercased()]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }

    private var avatarStatusText: String {
        ""
    }

    private var petFallbackSymbol: String {
        switch draft.species {
        case "狗": return "dog.fill"
        case "猫": return "cat.fill"
        case "鸟": return "bird.fill"
        case "鱼": return "fish.fill"
        default: return "pawprint.fill"
        }
    }

    private var speciesOptions: [String] {
        ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]
    }

    private var petGenderOptions: [String] {
        ["unknown", "boy", "girl"]
    }

    private var humanGenderOptions: [String] {
        ["男", "女", "非二元"]
    }

    private var humanRoleOptions: [String] {
        ["owner", "member"]
    }

    private var bloodTypes: [String] {
        ["", "A", "B", "AB", "O"]
    }

    private var petBreedOptions: [BreedInfo] {
        PetBreedDatabase.breeds(for: draft.species)
    }

    private var petCoatOptions: [String] {
        let options = PetAvatarAssetCatalog.coatColors(species: draft.species, breed: draft.resolvedBreed)
            ?? PetBreedDatabase.genericCoatColors
        return options.map(\.name)
    }

    private var petEyeOptions: [String] {
        let options = PetAvatarAssetCatalog.eyeColors(species: draft.species, breed: draft.resolvedBreed, coatColor: draft.coatColor)
            ?? PetBreedDatabase.genericEyeColors
        return options.map(\.name)
    }

    private var personalitySelection: Binding<String> {
        Binding(
            get: { draft.personalityTagIds.first ?? "" },
            set: { id in
                if draft.personalityTagIds.contains(id) {
                    draft.personalityTagIds.removeAll { $0 == id }
                } else {
                    if draft.personalityTagIds.count >= 3 {
                        draft.personalityTagIds.removeFirst()
                    }
                    draft.personalityTagIds.append(id)
                }
            }
        )
    }

    private func configureInitialAvatarIfNeeded() {
        guard !didConfigureInitialAvatar else { return }
        didConfigureInitialAvatar = true
        clampPetAppearance()
    }

    private func configureAvatarStepIfNeeded() {
        guard !didConfigureAvatarStep else { return }
        didConfigureAvatarStep = true
        guard canUseFree2D, draft.avatarSource == .placeholder else { return }
        applyDefault2DCandidate(usesInventoryPass: false)
    }

    private func advanceStep() {
        guard canAdvanceStep, !isLastStep else { return }
        GoKeyboard.dismiss()
        withAnimation(GoMotion.selection) {
            currentStep = creationSteps[min(currentStepIndex + 1, creationSteps.count - 1)]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func retreatStep() {
        guard currentStepIndex > 0 else { return }
        GoKeyboard.dismiss()
        withAnimation(GoMotion.selection) {
            currentStep = creationSteps[max(currentStepIndex - 1, 0)]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func updateDraftMBTI() {
        let letters = [mbtiEnergy, mbtiInformation, mbtiDecision, mbtiLifestyle]
        draft.mbti = letters.allSatisfy { !$0.isEmpty } ? letters.joined() : ""
    }

    private func refresh2DAvatarForProfileChange() {
        clampPetAppearance()
        guard draft.avatarSource == .avatar2D else { return }
        applyDefault2DCandidate(usesInventoryPass: draft.usesPurchasedOrInventoryPass)
    }

    private func applyDefault2DCandidate(usesInventoryPass: Bool? = nil) {
        guard let candidate = avatarCandidates.first else { return }
        apply(candidate, usesInventoryPass: usesInventoryPass ?? !canUseFree2D)
    }

    private func apply(_ candidate: Avatar2DCandidate, usesInventoryPass: Bool? = nil) {
        withAnimation(GoMotion.selection) {
            draft.avatarSource = .avatar2D
            draft.selectedAvatarCandidateId = candidate.id
            draft.avatarImageData = candidate.data
            draft.usesPurchasedOrInventoryPass = usesInventoryPass ?? !canUseFree2D
        }
    }

    private func toggle2DAvatar() {
        if draft.avatarSource == .avatar2D {
            clearAvatarSelection()
        } else {
            enable2DAvatarFromToggle()
        }
    }

    private func enable2DAvatarFromToggle() {
        if canUseFree2D {
            applyDefault2DCandidate(usesInventoryPass: false)
            return
        }
        if avatarPassCount > 0 {
            applyDefault2DCandidate(usesInventoryPass: true)
            return
        }
        guard currentHuman != nil else {
            showInlineError(l.tr(zh: "需要先有一个当前人类成员来支付椰子。", en: "Create or select a human member before spending coconuts.", de: "Erstelle oder wähle zuerst ein menschliches Mitglied."))
            return
        }
        guard currentBalance >= avatarPassCost else {
            let missing = avatarPassCost - currentBalance
            showInlineError(l.tr(zh: "还差 \(missing) 个椰子。", en: "Need \(missing) more coconuts.", de: "Noch \(missing) Kokosnüsse nötig."))
            return
        }
        shouldApply2DAfterPurchase = true
        showPurchaseConfirm = true
    }

    private func clearAvatarSelection() {
        withAnimation(GoMotion.selection) {
            draft.avatarSource = .placeholder
            draft.selectedAvatarCandidateId = nil
            draft.avatarImageData = nil
            draft.usesPurchasedOrInventoryPass = false
        }
    }

    private func openCameraAfterFirstFrame() {
        guard !isPreparingCamera else { return }
        MemberCreationPerformance.event("Camera Button Tap")
        GoKeyboard.dismiss()
        isPreparingCamera = true
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
            media.openCamera()
            isPreparingCamera = false
        }
    }

    private func handlePhotoPickerItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            let loadID = MemberCreationPerformance.begin("PhotoPicker LoadTransferable")
            guard let data = try? await item.loadTransferable(type: Data.self)
            else {
                MemberCreationPerformance.end("PhotoPicker LoadTransferable", loadID)
                await MainActor.run {
                    media.photoItem = nil
                    media.route = nil
                }
                return
            }
            MemberCreationPerformance.end("PhotoPicker LoadTransferable", loadID)
            let decodeID = MemberCreationPerformance.begin("Avatar Photo Decode")
            let image = await Task.detached(priority: .userInitiated) {
                MemberAvatarImageProcessor.image(from: data)
            }.value
            MemberCreationPerformance.end("Avatar Photo Decode", decodeID)
            guard let image else {
                await MainActor.run {
                    media.photoItem = nil
                    media.route = nil
                }
                return
            }
            await MainActor.run {
                media.photoItem = nil
                media.route = nil
                OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
                    media.showCrop(for: image)
                }
            }
        }
    }

    private func scheduleAvatarDecode() {
        decodeTask?.cancel()
        guard let data = draft.avatarImageData else {
            decodedAvatar = nil
            decodedAvatarTransparent = false
            return
        }
        let snapshot = data
        decodeTask = Task.detached(priority: .userInitiated) {
            let decodeID = MemberCreationPerformance.begin("Avatar Preview Decode")
            let image = UIImage(data: snapshot)
            let transparent = image.map { ImageCutoutService.imageHasTransparentPixels($0) } ?? false
            let rendered = image.map { image -> UIImage in
                let downsampled = MemberAvatarImageProcessor.downsample(image, maxPixel: 900, preserveAlpha: transparent)
                if transparent, let trimmed = ImageCutoutService.trimmedTransparentSubjectImage(from: downsampled) {
                    return trimmed
                }
                return downsampled
            }
            MemberCreationPerformance.end("Avatar Preview Decode", decodeID)
            await MainActor.run {
                guard draft.avatarImageData == snapshot else { return }
                decodedAvatar = rendered
                decodedAvatarTransparent = transparent
            }
        }
    }

    private func purchaseAvatarPass() {
        do {
            try MemberCreationService.purchaseAvatarPassForCurrentDraft(
                humans: existingHumans,
                context: modelContext,
                l: l
            )
            draft.usesPurchasedOrInventoryPass = false
            if shouldApply2DAfterPurchase {
                applyDefault2DCandidate(usesInventoryPass: true)
                shouldApply2DAfterPurchase = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let MemberCreationService.ServiceError.insufficientCoconuts(missing) {
            shouldApply2DAfterPurchase = false
            showInlineError(l.tr(zh: "还差 \(missing) 个椰子。", en: "Need \(missing) more coconuts.", de: "Noch \(missing) Kokosnüsse nötig."))
        } catch MemberCreationService.ServiceError.missingActiveHuman {
            shouldApply2DAfterPurchase = false
            showInlineError(l.tr(zh: "需要先有一个当前人类成员来支付椰子。", en: "Create or select a human member before spending coconuts.", de: "Erstelle oder wähle zuerst ein menschliches Mitglied."))
        } catch {
            shouldApply2DAfterPurchase = false
            showInlineError(error.localizedDescription)
        }
    }

    private func save() {
        guard canSave else { return }
        joinSaveTask?.cancel()
        if canRunHomeJoinHandoff {
            startHomeJoinHandoff()
        } else {
            isSaving = true
            performSave(showsHomeJoinHandoff: false)
        }
    }

    private func startHomeJoinHandoff() {
        isSaving = true
        isJoinHandoffRunning = true
        joinHandoffProgress = 0
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            joinHandoffProgress = 1
        }
        joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: reduceMotion ? 90 : 340) {
            performSave(showsHomeJoinHandoff: true)
        }
    }

    private func performSave(showsHomeJoinHandoff: Bool) {
        do {
            let result = try MemberCreationService.save(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: modelContext,
                countryCode: appCountry
            )
            if let pet = result.pet {
                onPetSaved?(pet)
            }
            if let human = result.human {
                onHumanSaved?(human)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if showsHomeJoinHandoff {
                joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: reduceMotion ? 70 : 160) {
                    isSaving = false
                    onComplete()
                }
                return
            }
            withAnimation(GoMotion.sheet) {
                didShowSuccess = true
            }
            joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 780) {
                didShowSuccess = false
                isSaving = false
                onComplete()
            }
        } catch MemberCreationService.ServiceError.duplicateName {
            handleSaveFailure(l.tr(zh: "这个名字已经被使用。", en: "This name is already in use.", de: "Dieser Name wird bereits verwendet."))
        } catch MemberCreationService.ServiceError.emptyName {
            handleSaveFailure(l.tr(zh: "请先输入名字。", en: "Enter a name first.", de: "Gib zuerst einen Namen ein."))
        } catch {
            handleSaveFailure(error.localizedDescription)
        }
    }

    private func handleSaveFailure(_ message: String) {
        isSaving = false
        restoreHomeJoinHandoffAfterFailure()
        showInlineError(message)
    }

    private func restoreHomeJoinHandoffAfterFailure() {
        guard isJoinHandoffRunning else { return }
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.sheet) {
            joinHandoffProgress = 0
        }
        joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: reduceMotion ? 90 : 240) {
            isSaving = false
            isJoinHandoffRunning = false
        }
    }

    private func showInlineError(_ message: String) {
        errorMessage = message
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        showError = true
    }

    private func compactNameInput(width: CGFloat) -> some View {
        MemberNameInputField(
            text: $draft.name,
            placeholder: kind == .pet
                ? l.tr(zh: "名字", en: "Name", de: "Name")
                : l.tr(zh: "名字", en: "Name", de: "Name"),
            foreground: cardForeground,
            placeholderForeground: cardSecondaryForeground
        )
        .padding(.horizontal, 12)
        .frame(width: width, height: 44)
        .background(cardControlFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(cardControlStroke, lineWidth: 1)
        }
    }

    private func compactOptionRow(options: [String], selection: Binding<String>, label: @escaping (String) -> String) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    withAnimation(GoMotion.selection) {
                        selection.wrappedValue = option
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(label(option))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.54)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(cardControlStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func compactHumanMetricInput(
        title: String,
        text: Binding<String>,
        placeholder: String,
        unit: String,
        maxFractionDigits: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(cardSecondaryForeground)
            InlineNumericInput(
                text: text,
                placeholder: placeholder,
                unit: unit,
                countryCode: appCountry,
                maxFractionDigits: maxFractionDigits,
                accent: Color.goPrimary,
                valueFont: OhanaFont.callout(.black),
                unitFont: OhanaFont.caption2(.black),
                fill: cardControlFill,
                cornerRadius: 20,
                horizontalPadding: 10,
                verticalPadding: 8,
                usesMiniKeypad: true
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var privacyPillGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 7)], spacing: 7) {
            privacyPill(title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"), icon: "scalemass", isOn: $draft.privateWeight)
            privacyPill(title: l.tr(zh: "运动", en: "Workout", de: "Training"), icon: "figure.run", isOn: $draft.privateWorkout)
            privacyPill(title: l.tr(zh: "用药", en: "Meds", de: "Medizin"), icon: "pills.fill", isOn: $draft.privateMedication)
            privacyPill(title: l.tr(zh: "愿望", en: "Wish", de: "Wunsch"), icon: "sparkle", isOn: $draft.privateWishlist)
            privacyPill(title: l.tr(zh: "消费", en: "Expense", de: "Kosten"), icon: "creditcard.fill", isOn: $draft.privateExpense)
        }
    }

    private func privacyPill(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        compactTogglePill(title: title, icon: icon, isOn: isOn)
    }

    private func humanMetricInput(
        title: String,
        text: Binding<String>,
        placeholder: String,
        unit: String,
        maxFractionDigits: Int
    ) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(cardSecondaryForeground)
            InlineNumericInput(
                text: text,
                placeholder: placeholder,
                unit: unit,
                countryCode: appCountry,
                maxFractionDigits: maxFractionDigits,
                accent: Color.goPrimary,
                valueFont: OhanaFont.title3(.black),
                unitFont: OhanaFont.caption(.black),
                fill: cardControlFill,
                cornerRadius: 21,
                horizontalPadding: 12,
                verticalPadding: 8,
                usesMiniKeypad: true
            )
        }
    }

    private func clampPetAppearance() {
        guard kind == .pet else { return }
        let coats = petCoatOptions
        if !coats.isEmpty, !coats.contains(draft.coatColor) {
            draft.coatColor = coats[0]
        }
        let eyes = petEyeOptions
        if !eyes.isEmpty, !eyes.contains(draft.eyeColor) {
            draft.eyeColor = eyes[0]
        }
    }

    private func mediaButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(cardForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(cardControlFill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(cardControlStroke, lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func compactTogglePill(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(GoMotion.selection) {
                isOn.wrappedValue.toggle()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isOn.wrappedValue ? cardSelectedForeground : cardForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isOn.wrappedValue ? cardSelectedFill : cardControlFill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(cardControlStroke, lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func statusPill(text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(tint.mix(with: .white, by: 0.84), in: Capsule())
    }

    private func flatTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.words)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.ohanaControlFill, in: Capsule())
    }

    private func menuPicker<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .frame(height: 42)
            .padding(.horizontal, 12)
            .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func compactMenuPicker<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(cardSecondaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 4)
                Text(value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(cardSecondaryForeground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.horizontal, 12)
            .background(cardControlFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(cardControlStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func chipRow(options: [String], selection: Binding<String>, label: @escaping (String) -> String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option || draft.personalityTagIds.contains(option)
                    Button {
                        withAnimation(GoMotion.selection) {
                            selection.wrappedValue = option
                        }
                    } label: {
                        Text(label(option))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func speciesLabel(_ species: String) -> String {
        switch species {
        case "狗": return l.tr(zh: "狗", en: "Dog", de: "Hund")
        case "猫": return l.tr(zh: "猫", en: "Cat", de: "Katze")
        case "鱼": return l.tr(zh: "鱼", en: "Fish", de: "Fisch")
        case "鸟": return l.tr(zh: "鸟", en: "Bird", de: "Vogel")
        case "兔子": return l.tr(zh: "兔子", en: "Rabbit", de: "Kaninchen")
        case "爬宠": return l.tr(zh: "爬宠", en: "Reptile", de: "Reptil")
        case "仓鼠": return l.tr(zh: "仓鼠", en: "Hamster", de: "Hamster")
        default: return l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }

    private func personalityLabel(_ id: String) -> String {
        guard let tag = PetPersonalityTag.lookup(id) else { return id }
        return l.tr(zh: tag.titleZh, en: tag.titleEn, de: tag.titleEn)
    }

    private func petGenderLabel(_ gender: String) -> String {
        switch gender {
        case "boy", "male", "男": return l.tr(zh: "男孩", en: "Boy", de: "Junge")
        case "girl", "female", "女": return l.tr(zh: "女孩", en: "Girl", de: "Mädchen")
        default: return l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")
        }
    }

    private func humanGenderLabel(_ gender: String) -> String {
        switch HumanProfileOptions.normalizedGender(gender) {
        case "男": return l.tr(zh: "男", en: "Male", de: "Männlich")
        case "女": return l.tr(zh: "女", en: "Female", de: "Weiblich")
        case "非二元": return l.tr(zh: "非二元", en: "Nonbinary", de: "Nichtbinär")
        default: return l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt")
        }
    }

    private func humanRoleLabel(_ role: String) -> String {
        switch HumanProfileOptions.normalizedRole(role) {
        case "owner": return l.tr(zh: "主人", en: "Owner", de: "Besitzer")
        default: return l.tr(zh: "家人", en: "Family", de: "Familie")
        }
    }

    private func bloodTypeLabel(_ value: String) -> String {
        value.isEmpty ? l.tr(zh: "不设置", en: "Skip", de: "Überspringen") : value
    }
}

struct MemberNameInputField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let foreground: Color
    let placeholderForeground: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .default
        textField.returnKeyType = .done
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.font = .systemFont(ofSize: 17, weight: .bold)
        textField.adjustsFontForContentSizeCategory = true
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.text = $text
        if !context.coordinator.isEditing, textField.text != text {
            textField.text = text
        }
        textField.textColor = UIColor(foreground)
        textField.tintColor = UIColor(foreground)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(placeholderForeground),
                .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isEditing = false
        private var latestText = ""

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            MemberCreationPerformance.event("Name Keystroke Received")
            latestText = sender.text ?? ""
            commitLatestText()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            MemberCreationPerformance.event("Name Editing Began")
            isEditing = true
            latestText = textField.text ?? ""
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            MemberCreationPerformance.event("Name Editing Ended")
            isEditing = false
            latestText = textField.text ?? ""
            commitLatestText()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            latestText = textField.text ?? ""
            commitLatestText()
            textField.resignFirstResponder()
            return true
        }

        private func commitLatestText() {
            guard text.wrappedValue != latestText else { return }
            let signpostID = MemberCreationPerformance.begin("Name Draft Commit")
            text.wrappedValue = latestText
            MemberCreationPerformance.end("Name Draft Commit", signpostID)
        }
    }
}

struct MemberCreationStepIndicator: View {
    let steps: [MemberCreationStep]
    let currentStep: MemberCreationStep
    let kind: MemberCreationKind
    let l: L10n
    let foreground: Color
    let secondaryForeground: Color
    let inactiveFill: Color

    private var currentIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currentStep.title(kind: kind, l: l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text("\(currentIndex + 1) / \(steps.count)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(secondaryForeground)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? Color.goPrimary : inactiveFill)
                        .frame(width: index == currentIndex ? 26 : 9, height: 7)
                        .animation(GoMotion.selection, value: currentIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MemberCompactDateRow: View {
    let title: String
    let icon: String
    @Binding var isEnabled: Bool
    @Binding var date: Date
    let range: ClosedRange<Date>
    let foreground: Color
    let secondaryForeground: Color
    let fill: Color
    let stroke: Color

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28)

            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            if isEnabled {
                DatePicker("", selection: $date, in: range, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, AppLanguage.effectiveLocale)
                    .tint(foreground)
                    .frame(maxWidth: 142, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Toggle(title, isOn: $isEnabled)
                .labelsHidden()
                .tint(foreground)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(fill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(stroke, lineWidth: 1)
        }
        .animation(GoMotion.selection, value: isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEnabled ? "\(title), \(formattedDate)" : title)
    }
}

struct MemberCompactMBTIBar: View {
    @Binding var energy: String
    @Binding var information: String
    @Binding var decision: String
    @Binding var lifestyle: String
    let foreground: Color
    let onSelectionChanged: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var result: String {
        [energy, information, decision, lifestyle].map { $0.isEmpty ? "-" : $0 }.joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("MBTI")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(foreground.opacity(0.70))
                Spacer()
                Text(result)
                    .font(OhanaFont.callout(.black))
                    .monospaced()
                    .foregroundStyle(result.contains("-") ? foreground.opacity(0.58) : foreground)
            }
            HStack(spacing: 7) {
                dimensionMenu(title: "I/E", first: "I", second: "E", selection: $energy)
                dimensionMenu(title: "S/N", first: "S", second: "N", selection: $information)
                dimensionMenu(title: "T/F", first: "T", second: "F", selection: $decision)
                dimensionMenu(title: "J/P", first: "J", second: "P", selection: $lifestyle)
            }
        }
    }

    private func dimensionMenu(title: String, first: String, second: String, selection: Binding<String>) -> some View {
        Menu {
            Button(first) { select(first, selection: selection) }
            Button(second) { select(second, selection: selection) }
            Button(l.tr(zh: "清空", en: "Clear", de: "Leeren"), role: .destructive) { select("", selection: selection) }
        } label: {
            Text(selection.wrappedValue.isEmpty ? title : selection.wrappedValue)
                .font(OhanaFont.caption(.black))
                .monospaced()
                .foregroundStyle(selection.wrappedValue.isEmpty ? foreground.opacity(0.72) : Color.arkInk)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selection.wrappedValue.isEmpty ? Color.ohanaControlFill : Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func select(_ value: String, selection: Binding<String>) {
        withAnimation(GoMotion.selection) {
            selection.wrappedValue = value
        }
        onSelectionChanged()
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct MemberCompactCityPicker: View {
    let country: String
    @Binding var city: String
    @Binding var usesCustomCity: Bool

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var cities: [String] {
        country.isEmpty ? [] : PetBreedDatabase.cities(for: country)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                if cities.isEmpty {
                    Button(l.tr(zh: "先选择现居国家", en: "Choose residence first", de: "Zuerst Wohnland wählen")) {}
                } else {
                    ForEach(cities, id: \.self) { option in
                        Button(localizedCity(option)) {
                            if option == "其他" {
                                usesCustomCity = true
                                city = ""
                            } else {
                                usesCustomCity = false
                                city = option
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(l.tr(zh: "城市", en: "City", de: "Stadt"))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Text(cityValueText)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                .frame(height: 42)
                .padding(.horizontal, 12)
                .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            if usesCustomCity {
                TextField(l.tr(zh: "自定义城市", en: "Custom city", de: "Eigene Stadt"), text: $city)
                    .textInputAutocapitalization(.words)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
        }
    }

    private var cityValueText: String {
        if country.isEmpty {
            return l.tr(zh: "先选国家", en: "Choose country", de: "Land wählen")
        }
        if usesCustomCity {
            return city.isEmpty ? l.tr(zh: "自定义", en: "Custom", de: "Eigen") : city
        }
        return city.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : localizedCity(city)
    }

    private func localizedCity(_ value: String) -> String {
        value == "其他" ? l.tr(zh: "其他", en: "Other", de: "Andere") : value
    }
}

struct MemberDateInputBlock: View {
    let title: String
    let subtitle: String
    let toggleTitle: String
    let icon: String
    @Binding var isEnabled: Bool
    @Binding var date: Date
    let range: ClosedRange<Date>

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var isExpanded = false

    private var l: L10n { L10n(appLanguage) }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle(toggleTitle, isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Color.goPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            if isEnabled {
                Button {
                    withAnimation(GoMotion.selection) {
                        isExpanded.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l.tr(zh: "已选择日期", en: "Selected date", de: "Ausgewähltes Datum"))
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.ohanaSecondaryText)
                            Text(formattedDate)
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 64)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())

                if isExpanded {
                    DatePicker("", selection: $date, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .environment(\.locale, AppLanguage.effectiveLocale)
                        .tint(Color.goPrimary)
                        .padding(12)
                        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if !newValue {
                withAnimation(GoMotion.selection) {
                    isExpanded = false
                }
            }
        }
    }
}

struct MemberMBTIChoiceGrid: View {
    @Binding var energy: String
    @Binding var information: String
    @Binding var decision: String
    @Binding var lifestyle: String
    let onSelectionChanged: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var displayResult: String {
        [energy, information, decision, lifestyle]
            .map { $0.isEmpty ? "-" : $0 }
            .joined()
    }

    private var dimensionColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 138), spacing: 8),
            GridItem(.flexible(minimum: 138), spacing: 8),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("MBTI")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(displayResult)
                    .font(OhanaFont.title3(.black))
                    .monospaced()
                    .foregroundStyle(displayResult.contains("-") ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
            }
            LazyVGrid(columns: dimensionColumns, spacing: 8) {
                dimensionBlock(
                    title: l.tr(zh: "能量", en: "Energy", de: "Energie"),
                    first: ("I", l.tr(zh: "内向", en: "Introvert", de: "Introvertiert")),
                    second: ("E", l.tr(zh: "外向", en: "Extravert", de: "Extravertiert")),
                    selection: $energy
                )
                dimensionBlock(
                    title: l.tr(zh: "信息", en: "Information", de: "Information"),
                    first: ("S", l.tr(zh: "实感", en: "Sensing", de: "Sensorisch")),
                    second: ("N", l.tr(zh: "直觉", en: "Intuition", de: "Intuition")),
                    selection: $information
                )
                dimensionBlock(
                    title: l.tr(zh: "判断", en: "Decision", de: "Entscheidung"),
                    first: ("T", l.tr(zh: "思考", en: "Thinking", de: "Denken")),
                    second: ("F", l.tr(zh: "情感", en: "Feeling", de: "Fühlen")),
                    selection: $decision
                )
                dimensionBlock(
                    title: l.tr(zh: "生活", en: "Lifestyle", de: "Lebensstil"),
                    first: ("J", l.tr(zh: "判断", en: "Judging", de: "Geplant")),
                    second: ("P", l.tr(zh: "感知", en: "Perceiving", de: "Spontan")),
                    selection: $lifestyle
                )
            }
        }
    }

    private func dimensionBlock(
        title: String,
        first: (String, String),
        second: (String, String),
        selection: Binding<String>
    ) -> some View {
        return VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(spacing: 6) {
                mbtiOption(first.0, label: first.1, selection: selection)
                mbtiOption(second.0, label: second.1, selection: selection)
            }
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func mbtiOption(_ letter: String, label: String, selection: Binding<String>) -> some View {
        let isSelected = selection.wrappedValue == letter
        return Button {
            withAnimation(GoMotion.selection) {
                selection.wrappedValue = letter
            }
            onSelectionChanged()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Text(letter)
                    .font(OhanaFont.callout(.black))
                    .monospaced()
                Text(label)
                    .font(OhanaFont.caption(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isSelected ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct MemberCityPicker: View {
    let country: String
    @Binding var city: String
    @Binding var usesCustomCity: Bool

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var cities: [String] {
        country.isEmpty ? [] : PetBreedDatabase.cities(for: country)
    }

    private var cityColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 94), spacing: 7)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cities.isEmpty {
                Text(l.tr(zh: "先选择现居国家", en: "Choose a country first", de: "Zuerst ein Land wählen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ohanaControlFill, in: Capsule())
            } else {
                LazyVGrid(columns: cityColumns, spacing: 7) {
                    ForEach(cities, id: \.self) { option in
                        cityButton(option)
                    }
                }
            }

            if usesCustomCity {
                TextField(l.tr(zh: "自定义城市", en: "Custom city", de: "Eigene Stadt"), text: $city)
                    .textInputAutocapitalization(.words)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
        }
    }

    private func cityButton(_ option: String) -> some View {
        let isOther = option == "其他"
        let isSelected = isOther ? usesCustomCity : city == option && !usesCustomCity
        return Button {
            withAnimation(GoMotion.selection) {
                if isOther {
                    usesCustomCity = true
                    city = ""
                } else {
                    usesCustomCity = false
                    city = city == option ? "" : option
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(localizedCity(option))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func localizedCity(_ value: String) -> String {
        value == "其他" ? l.tr(zh: "其他", en: "Other", de: "Andere") : value
    }
}

private struct MemberCreationJoinHandoffModifier: ViewModifier {
    let progress: CGFloat
    let reduceMotion: Bool

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var easedProgress: CGFloat {
        let p = clampedProgress
        return p * p * (3 - 2 * p)
    }

    func body(content: Content) -> some View {
        let p = easedProgress
        let scale = reduceMotion ? mix(1, 0.92, p) : mix(1, 0.58, p)
        let flip = reduceMotion ? 0 : Double(mix(0, -78, p))
        let turn = reduceMotion ? 0 : Double(mix(0, -4, p))
        let x = reduceMotion ? CGFloat(0) : mix(0, 18, p)
        let y = reduceMotion ? mix(0, -8, p) : mix(0, -34, p)
        let opacity = reduceMotion ? Double(mix(1, 0.78, p)) : Double(mix(1, 0.90, p))

        content
            .compositingGroup()
            .scaleEffect(scale, anchor: .center)
            .rotation3DEffect(.degrees(flip), axis: (x: 0.06, y: 1, z: 0), perspective: 0.78)
            .rotationEffect(.degrees(turn))
            .offset(x: x, y: y)
            .opacity(opacity)
            .zIndex(progress > 0 ? 20 : 0)
    }

    private func mix(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

struct MemberPortraitDraftCardSurface<Controls: View>: View {
    let snapshot: MemberCardRenderSnapshot
    @ViewBuilder var controls: () -> Controls

    private var accent: Color {
        Color(hex: snapshot.themeColorHex)
    }

    private var useDarkText: Bool {
        WalletPetCardTheme.prefersDarkForeground(for: snapshot.themeColorHex)
    }

    private var primaryText: Color {
        useDarkText ? Color.arkInk : Color.goCardWhite
    }

    private var usesWidePhoto: Bool {
        snapshot.avatarSource == .customImage && !snapshot.avatarIsTransparent && snapshot.avatarImage != nil
    }

    private var statusPillForeground: Color {
        usesWidePhoto ? Color.goCardWhite : primaryText
    }

    private var statusPillFill: Color {
        if usesWidePhoto {
            return Color.arkInk.opacity(0.34)
        }
        return useDarkText ? Color.arkInk.opacity(0.10) : Color.goCardWhite.opacity(0.15)
    }

    private var statusPillStroke: Color {
        useDarkText ? Color.arkInk.opacity(0.14) : Color.goCardWhite.opacity(0.22)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero(width: width)
                        .frame(height: min(max(width * 0.92, 260), 330))
                    controls()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.24), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.arkInk.opacity(0.22), radius: 24, x: 0, y: 16) // ui-v4: allow intentional member portrait card depth
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                accent.mix(with: .white, by: 0.14),
                accent,
                accent.mix(with: .black, by: 0.34),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func hero(width: CGFloat) -> some View {
        let heroHeight = min(max(width * 0.92, 260), 330)
        let readableText = usesWidePhoto ? Color.goCardWhite : primaryText
        return ZStack(alignment: .topLeading) {
            if usesWidePhoto {
                widePhotoLayer(width: width, height: heroHeight)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(readableText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(snapshot.subtitle.isEmpty ? snapshot.kind.typeLabel(L10n(AppLanguage.code)) : snapshot.subtitle)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(readableText.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    Spacer()
                    if !snapshot.statusText.isEmpty {
                        Text(snapshot.statusText)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(statusPillForeground)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(statusPillFill, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(statusPillStroke, lineWidth: 1)
                            }
                    }
                }
                Spacer(minLength: 18)
                avatar(width: width)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 12)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private func avatar(width: CGFloat) -> some View {
        if usesWidePhoto {
            Color.clear
                .frame(width: width * 0.72, height: width * 0.58)
        } else if let image = snapshot.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: width * (snapshot.kind == .pet ? 0.72 : 0.58), height: width * 0.58)
                .shadow(color: Color.arkInk.opacity(snapshot.avatarIsTransparent ? 0.30 : 0.18), radius: 16, y: 10) // ui-v4: allow intentional avatar depth
        } else {
            Color.clear
                .frame(width: width * 0.72, height: width * 0.50)
        }
    }

    @ViewBuilder
    private func widePhotoLayer(width: CGFloat, height: CGFloat) -> some View {
        if let image = snapshot.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.arkInk.opacity(0.36),
                            Color.arkInk.opacity(0.08),
                            Color.arkInk.opacity(0.58),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    accent.opacity(0.14)
                }
                .allowsHitTesting(false)
        }
    }
}

struct MemberCreationSection<Content: View>: View {
    let title: String
    let icon: String
    var foreground: Color = .ohanaPrimaryText
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(foreground)
            content()
        }
    }
}

struct MemberAvatarCandidateCell: View {
    let candidate: Avatar2DCandidate
    let isSelected: Bool
    let action: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var image: UIImage?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? Color.goPrimary : Color.ohanaControlFill)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    } else {
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .frame(width: 76, height: 96)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2)
                }
                Text(candidate.isDefault ? l.tr(zh: "智能", en: "Smart", de: "Smart") : candidate.subtitle)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 76)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .task(id: candidate.id) {
            let data = candidate.data
            image = await Task.detached(priority: .utility) {
                UIImage(data: data)
            }.value
        }
    }
}

struct MemberPortraitCropView: View {
    let image: UIImage
    let onComplete: (Data) -> Void
    let onCancel: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isProcessing = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.arkInk.ignoresSafeArea()
                VStack(spacing: 18) {
                    cropStage
                    HStack(spacing: 12) {
                        Button {
                            onCancel()
                        } label: {
                            Text(l.cancel)
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.goCardWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.arkCardDark, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isProcessing)

                        Button {
                            finishCrop()
                        } label: {
                            HStack(spacing: 8) {
                                if isProcessing {
                                    ProgressView()
                                        .tint(Color.arkInk)
                                }
                                Text(isProcessing ? l.tr(zh: "处理中", en: "Processing", de: "Verarbeitet") : l.done)
                            }
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(isProcessing)
        }
    }

    private var cropStage: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width - 36
            let availableHeight = proxy.size.height - 12
            let cropWidth = min(availableWidth, availableHeight / MemberAvatarImageProcessor.portraitAspect)
            let cropHeight = cropWidth * MemberAvatarImageProcessor.portraitAspect
            let cropRect = CGRect(
                x: (proxy.size.width - cropWidth) / 2,
                y: (proxy.size.height - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
            let baseScale = max(cropWidth / image.size.width, cropHeight / image.size.height)
            let renderedSize = CGSize(
                width: image.size.width * baseScale * scale,
                height: image.size.height * baseScale * scale
            )
            let imageFrame = CGRect(
                x: cropRect.midX - renderedSize.width / 2 + offset.width,
                y: cropRect.midY - renderedSize.height / 2 + offset.height,
                width: renderedSize.width,
                height: renderedSize.height
            )

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: renderedSize.width, height: renderedSize.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)

                Color.arkInk.opacity(0.54)
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .frame(width: cropWidth, height: cropHeight)
                                    .blendMode(.destinationOut)
                            }
                    }
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.goPrimary, lineWidth: 2)
                    .frame(width: cropWidth, height: cropHeight)
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "MemberPortraitCropSpace")
            .onChange(of: cropRect) { _, _ in
                clampOffset(cropRect: cropRect, imageFrame: imageFrame)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    private func clampOffset(cropRect: CGRect, imageFrame: CGRect) {
        var newOffset = offset
        if imageFrame.width <= cropRect.width {
            newOffset.width = 0
        } else {
            let overflow = (imageFrame.width - cropRect.width) / 2
            newOffset.width = min(max(newOffset.width, -overflow), overflow)
        }
        if imageFrame.height <= cropRect.height {
            newOffset.height = 0
        } else {
            let overflow = (imageFrame.height - cropRect.height) / 2
            newOffset.height = min(max(newOffset.height, -overflow), overflow)
        }
        offset = newOffset
        lastOffset = newOffset
    }

    private func finishCrop() {
        guard !isProcessing else { return }
        isProcessing = true
        let sourceImage = image
        let scaleSnapshot = scale
        let offsetSnapshot = offset
        DispatchQueue.global(qos: .userInitiated).async {
            let signpostID = MemberCreationPerformance.begin("Avatar Crop Encode")
            let data = MemberAvatarImageProcessor.encodedCroppedAvatarData(
                image: sourceImage,
                scale: scaleSnapshot,
                offset: offsetSnapshot
            )
            MemberCreationPerformance.end("Avatar Crop Encode", signpostID)
            DispatchQueue.main.async {
                isProcessing = false
                if let data {
                    onComplete(data)
                }
            }
        }
    }
}

struct MemberCameraCaptureView: UIViewControllerRepresentable {
    let maxPixel: CGFloat
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context _: Context) -> OhanaCameraViewController {
        let viewController = OhanaCameraViewController()
        viewController.maxCapturePixel = maxPixel
        viewController.onCapture = onImage
        viewController.onCancel = onCancel
        return viewController
    }

    func updateUIViewController(_: OhanaCameraViewController, context _: Context) {}
}
