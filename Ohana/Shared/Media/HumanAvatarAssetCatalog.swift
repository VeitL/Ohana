//
//  HumanAvatarAssetCatalog.swift
//  Ohana
//
//  Deterministic mapping from human profile selections to bundled avatar assets.
//

import Foundation

enum HumanAvatarAssetCatalog {
    enum AgeGroup: String, CaseIterable {
        case teen
        case youngAdult = "young_adult"
        case midAdult = "mid_adult"
        case lateAdult = "late_adult"
        case senior
    }

    nonisolated static let assetDirectory = "HumanAvatarAssets"

    nonisolated static func avatarFilename(gender: String, birthday: Date?, now: Date = Date()) -> String? {
        guard let genderSlug = normalizedGenderSlug(gender) else { return nil }
        return "human_\(genderSlug)_\(ageGroup(for: birthday, now: now).rawValue).webp"
    }

    nonisolated static func avatarData(gender: String, birthday: Date?, now: Date = Date(), bundle: Bundle = .main) -> Data? {
        guard let filename = avatarFilename(gender: gender, birthday: birthday, now: now) else {
            return nil
        }
        return avatarData(filename: filename, bundle: bundle)
    }

    nonisolated static func avatarData(filename: String, bundle: Bundle = .main) -> Data? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = avatarURL(name: name, preferredExtension: ext, bundle: bundle) else {
            return nil
        }
        return try? Data(contentsOf: url) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
    }

    private nonisolated static func avatarURL(name: String, preferredExtension: String, bundle: Bundle) -> URL? {
        if preferredExtension != "webp",
           let url = bundle.url(forResource: name, withExtension: "webp", subdirectory: assetDirectory) {
            return url
        }
        if let url = bundle.url(forResource: name, withExtension: preferredExtension, subdirectory: assetDirectory) {
            return url
        }
        return bundle.url(forResource: name, withExtension: "png", subdirectory: assetDirectory)
    }

    nonisolated static func ageGroup(for birthday: Date?, now: Date = Date(), calendar: Calendar = .current) -> AgeGroup {
        guard let birthday,
              let years = calendar.dateComponents([.year], from: birthday, to: now).year,
              years >= 0 else {
            return .youngAdult
        }

        switch years {
        case ..<20:
            return .teen
        case ..<35:
            return .youngAdult
        case ..<50:
            return .midAdult
        case ..<65:
            return .lateAdult
        default:
            return .senior
        }
    }

    private nonisolated static func normalizedGenderSlug(_ value: String) -> String? {
        switch HumanProfileOptions.normalizedGender(value) {
        case "男":
            "male"
        case "女":
            "female"
        case "非二元":
            "nonbinary"
        default:
            nil
        }
    }
}

enum Avatar2DAccess {
    enum Kind {
        case human
        case pet
    }

    private static let freeHumanUsedKey = "avatar2d_free_human_used"
    private static let freePetUsedKey = "avatar2d_free_pet_used"
    static let extraPassInventoryKey = "inventory_avatar2d_extra_count"
    static let shopItemId = "boost_avatar2d_extra"

    static func hasAccess(kind: Kind, existingCount: Int) -> Bool {
        freeSlotAvailable(kind: kind, existingCount: existingCount) || extraPassCount > 0
    }

    static func requiresPurchase(kind: Kind, existingCount: Int) -> Bool {
        !hasAccess(kind: kind, existingCount: existingCount)
    }

    static func usesFreeSlot(kind: Kind, existingCount: Int) -> Bool {
        freeSlotAvailable(kind: kind, existingCount: existingCount)
    }

    static func consumeIfNeeded(kind: Kind, existingCount: Int) {
        if freeSlotAvailable(kind: kind, existingCount: existingCount) {
            markFreeSlotUsed(kind: kind)
            return
        }

        let passes = extraPassCount
        if passes > 0 {
            UserDefaults.standard.set(passes - 1, forKey: extraPassInventoryKey)
        }
    }

    static func addExtraPasses(_ count: Int) {
        guard count > 0 else { return }
        UserDefaults.standard.set(extraPassCount + count, forKey: extraPassInventoryKey)
    }

    @discardableResult
    static func consumeExtraPass() -> Bool {
        let passes = extraPassCount
        guard passes > 0 else { return false }
        UserDefaults.standard.set(passes - 1, forKey: extraPassInventoryKey)
        return true
    }

    static var extraPassCount: Int {
        UserDefaults.standard.integer(forKey: extraPassInventoryKey)
    }

    private static func freeSlotAvailable(kind _: Kind, existingCount: Int) -> Bool {
        existingCount == 0
    }

    private static func markFreeSlotUsed(kind: Kind) {
        UserDefaults.standard.set(true, forKey: freeUsedKey(kind))
    }

    private static func freeUsedKey(_ kind: Kind) -> String {
        switch kind {
        case .human:
            freeHumanUsedKey
        case .pet:
            freePetUsedKey
        }
    }
}
