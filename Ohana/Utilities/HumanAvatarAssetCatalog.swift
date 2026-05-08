//
//  HumanAvatarAssetCatalog.swift
//  Ohana
//
//  Deterministic mapping from human profile selections to bundled avatar PNGs.
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

    static let assetDirectory = "HumanAvatarAssets"

    static func avatarFilename(gender: String, birthday: Date?, now: Date = Date()) -> String? {
        guard let genderSlug = normalizedGenderSlug(gender) else { return nil }
        return "human_\(genderSlug)_\(ageGroup(for: birthday, now: now).rawValue).png"
    }

    static func avatarData(gender: String, birthday: Date?, now: Date = Date(), bundle: Bundle = .main) -> Data? {
        guard let filename = avatarFilename(gender: gender, birthday: birthday, now: now) else {
            return nil
        }
        return avatarData(filename: filename, bundle: bundle)
    }

    static func avatarData(filename: String, bundle: Bundle = .main) -> Data? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: assetDirectory) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func ageGroup(for birthday: Date?, now: Date = Date(), calendar: Calendar = .current) -> AgeGroup {
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

    private static func normalizedGenderSlug(_ value: String) -> String? {
        switch HumanProfileOptions.normalizedGender(value) {
        case "男":
            return "male"
        case "女":
            return "female"
        case "非二元":
            return "nonbinary"
        default:
            return nil
        }
    }
}
