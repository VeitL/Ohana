//
//  PetAvatarAssetCatalog.swift
//  Ohana
//
//  Deterministic mapping from pet appearance selections to bundled avatar PNGs.
//

import Foundation

enum PetAvatarAssetCatalog {
    struct Appearance: Hashable {
        let coatName: String
        let coatSlug: String
        let coatHex: String
        let eyeName: String = "黑色"
    }

    static let assetDirectory = "PetAvatarAssets"

    private static let devonRexBreedNames: Set<String> = [
        "德文卷毛猫",
        "德文卷毛",
        "Devon Rex",
        "devon rex"
    ]

    private static let speciesStandardSlugs: Set<String> = [
        "cat",
        "dog",
        "fish",
        "bird",
        "rabbit",
        "reptile",
        "hamster",
        "other"
    ]

    static let devonRexAppearances: [Appearance] = [
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "红虎斑", coatSlug: "red_tabby", coatHex: "B5451B"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A"),
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "黑烟色", coatSlug: "black_smoke", coatHex: "4B4B4B"),
        .init(coatName: "玳瑁", coatSlug: "tortoiseshell", coatHex: "6E2C00"),
        .init(coatName: "三花", coatSlug: "calico", coatHex: "D4B896"),
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2C2C2C"),
        .init(coatName: "蓝白", coatSlug: "blue_white", coatHex: "8FA8BE"),
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10"),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A"),
        .init(coatName: "丁香重点色", coatSlug: "lilac_point", coatHex: "B0A0B0"),
        .init(coatName: "火焰重点色", coatSlug: "flame_point", coatHex: "E36A2E"),
        .init(coatName: "奶油重点色", coatSlug: "cream_point", coatHex: "F5E6C8"),
        .init(coatName: "海豹山猫重点色", coatSlug: "seal_lynx_point", coatHex: "6B4F32"),
        .init(coatName: "蓝山猫重点色", coatSlug: "blue_lynx_point", coatHex: "8FA8BE")
    ]

    static func supports(species: String, breed: String) -> Bool {
        normalizedSpecies(species) == "cat" && normalizedBreed(breed) == "devon_rex"
    }

    static func coatColors(species: String, breed: String) -> [CoatColor]? {
        guard supports(species: species, breed: breed) else { return nil }
        var seen: Set<String> = []
        return devonRexAppearances.compactMap { appearance in
            guard !seen.contains(appearance.coatName) else { return nil }
            seen.insert(appearance.coatName)
            return CoatColor(name: appearance.coatName, hex: appearance.coatHex)
        }
    }

    static func eyeColors(species: String, breed: String, coatColor: String) -> [EyeColor]? {
        guard supports(species: species, breed: breed),
              coatColor == "自定义" || devonRexAppearances.contains(where: { $0.coatName == coatColor }) else { return nil }
        return [EyeColor(name: "黑色", hex: "111111")]
    }

    static func defaultAppearance(species: String, breed: String) -> Appearance? {
        guard supports(species: species, breed: breed) else { return nil }
        return devonRexAppearances.first
    }

    static func avatarFilename(species: String, breed: String, gender: String, coatColor: String, eyeColor: String) -> String? {
        let speciesSlug = normalizedSpecies(species)
        let genderSlug = normalizedGender(gender)

        guard speciesStandardSlugs.contains(speciesSlug) else { return nil }
        guard speciesSlug == "cat", normalizedBreed(breed) == "devon_rex" else {
            return "\(speciesSlug)_\(genderSlug)_standard.png"
        }

        let breedSlug = normalizedBreed(breed)
        guard coatColor != "自定义",
              let appearance = devonRexAppearances.first(where: { $0.coatName == coatColor }) else {
            return "\(speciesSlug)_\(genderSlug)_standard.png"
        }

        return "\(speciesSlug)_\(breedSlug)_\(genderSlug)_\(appearance.coatSlug).png"
    }

    static func avatarData(species: String, breed: String, gender: String, coatColor: String, eyeColor: String) -> Data? {
        guard let filename = avatarFilename(species: species, breed: breed, gender: gender, coatColor: coatColor, eyeColor: eyeColor) else {
            return nil
        }
        return avatarData(filename: filename)
    }

    static func avatarData(filename: String, bundle: Bundle = .main) -> Data? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: assetDirectory) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func normalizedSpecies(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "猫", "cat", "cats": return "cat"
        case "狗", "dog", "dogs": return "dog"
        case "鱼", "fish", "fishes": return "fish"
        case "鸟", "bird", "birds": return "bird"
        case "兔", "兔子", "rabbit", "rabbits", "bunny", "bunnies": return "rabbit"
        case "爬宠", "爬虫", "爬行动物", "reptile", "reptiles", "lizard", "gecko": return "reptile"
        case "仓鼠", "hamster", "hamsters": return "hamster"
        case "其他", "other", "others": return "other"
        default: return "pet"
        }
    }

    private static func normalizedBreed(_ value: String) -> String {
        if devonRexBreedNames.contains(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return "devon_rex"
        }
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func normalizedGender(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "female", "girl", "女", "女孩", "母": return "girl"
        default: return "boy"
        }
    }
}
