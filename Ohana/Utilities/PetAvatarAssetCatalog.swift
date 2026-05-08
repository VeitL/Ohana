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

    private static let britishShorthairBreedNames: Set<String> = [
        "英国短毛猫",
        "英国短毛",
        "英短",
        "British Shorthair",
        "british shorthair"
    ]

    private static let americanShorthairBreedNames: Set<String> = [
        "美国短毛猫",
        "美国短毛",
        "美短",
        "American Shorthair",
        "american shorthair"
    ]

    private static let ragdollBreedNames: Set<String> = [
        "布偶猫",
        "布偶",
        "Ragdoll",
        "ragdoll"
    ]

    private static let siameseBreedNames: Set<String> = [
        "暹罗猫",
        "暹罗",
        "Siamese",
        "siamese"
    ]

    private static let abyssinianBreedNames: Set<String> = [
        "阿比西尼亚猫",
        "阿比西尼亚",
        "Abyssinian",
        "abyssinian"
    ]

    private static let maineCoonBreedNames: Set<String> = [
        "缅因库恩猫",
        "缅因猫",
        "缅因",
        "Maine Coon",
        "maine coon"
    ]

    private static let persianBreedNames: Set<String> = [
        "波斯猫",
        "波斯",
        "Persian",
        "persian"
    ]

    private static let liHuaBreedNames: Set<String> = [
        "狸花猫",
        "狸花",
        "中华狸花猫",
        "Chinese Li Hua",
        "chinese li hua",
        "Dragon Li",
        "dragon li",
        "Li Hua",
        "li hua"
    ]

    private static let shibaInuBreedNames: Set<String> = [
        "柴犬",
        "Shiba Inu",
        "shiba inu"
    ]

    private static let goldenRetrieverBreedNames: Set<String> = [
        "金毛",
        "金毛寻回犬",
        "黄金猎犬",
        "Golden Retriever",
        "golden retriever"
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

    static let britishShorthairAppearances: [Appearance] = [
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF"),
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "金渐层", coatSlug: "golden_shaded", coatHex: "D4A017"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "重点色", coatSlug: "colorpoint", coatHex: "4A2A10")
    ]

    static let americanShorthairAppearances: [Appearance] = [
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "橘虎斑", coatSlug: "orange_tabby", coatHex: "C8622A"),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF")
    ]

    static let ragdollAppearances: [Appearance] = [
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10"),
        .init(coatName: "海豹双色", coatSlug: "seal_bicolor", coatHex: "4A2A10"),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "蓝双色", coatSlug: "blue_bicolor", coatHex: "7A9AAF"),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A"),
        .init(coatName: "丁香重点色", coatSlug: "lilac_point", coatHex: "B0A0B0"),
        .init(coatName: "火焰重点色", coatSlug: "flame_point", coatHex: "E36A2E")
    ]

    static let siameseAppearances: [Appearance] = [
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10"),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A"),
        .init(coatName: "丁香重点色", coatSlug: "lilac_point", coatHex: "B0A0B0")
    ]

    static let abyssinianAppearances: [Appearance] = [
        .init(coatName: "黄褐色", coatSlug: "ruddy", coatHex: "C8822A"),
        .init(coatName: "肉桂红", coatSlug: "sorrel", coatHex: "B5451B"),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF"),
        .init(coatName: "浅黄褐色", coatSlug: "fawn", coatHex: "C9A66B")
    ]

    static let maineCoonAppearances: [Appearance] = [
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A"),
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "红虎斑", coatSlug: "red_tabby", coatHex: "B5451B"),
        .init(coatName: "黑烟色", coatSlug: "black_smoke", coatHex: "4B4B4B"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "三花", coatSlug: "calico", coatHex: "D4B896")
    ]

    static let persianAppearances: [Appearance] = [
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF")
    ]

    static let liHuaAppearances: [Appearance] = [
        .init(coatName: "棕狸花", coatSlug: "brown_mackerel_tabby", coatHex: "7A5C3A"),
        .init(coatName: "银灰狸花", coatSlug: "silver_mackerel_tabby", coatHex: "9A9A92")
    ]

    static let shibaInuAppearances: [Appearance] = [
        .init(coatName: "赤色", coatSlug: "red", coatHex: "C8622A"),
        .init(coatName: "黑褐色", coatSlug: "black_tan", coatHex: "2A1A12"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "胡麻色", coatSlug: "sesame", coatHex: "7A6A4A")
    ]

    static let goldenRetrieverAppearances: [Appearance] = [
        .init(coatName: "浅金色", coatSlug: "light_golden", coatHex: "F2D38A"),
        .init(coatName: "金色", coatSlug: "golden", coatHex: "D4A017"),
        .init(coatName: "深金色", coatSlug: "dark_golden", coatHex: "B66A1F")
    ]

    private static var catBreedAppearances: [String: [Appearance]] {
        [
            "devon_rex": devonRexAppearances,
            "british_shorthair": britishShorthairAppearances,
            "american_shorthair": americanShorthairAppearances,
            "ragdoll": ragdollAppearances,
            "siamese": siameseAppearances,
            "abyssinian": abyssinianAppearances,
            "maine_coon": maineCoonAppearances,
            "persian": persianAppearances,
            "li_hua": liHuaAppearances
        ]
    }

    private static var dogBreedAppearances: [String: [Appearance]] {
        [
            "shiba_inu": shibaInuAppearances,
            "golden_retriever": goldenRetrieverAppearances
        ]
    }

    static func supports(species: String, breed: String) -> Bool {
        breedAppearances(speciesSlug: normalizedSpecies(species), breedSlug: normalizedBreed(breed)) != nil
    }

    static func coatColors(species: String, breed: String) -> [CoatColor]? {
        guard let appearances = breedAppearances(
            speciesSlug: normalizedSpecies(species),
            breedSlug: normalizedBreed(breed)
        ) else { return nil }
        var seen: Set<String> = []
        return appearances.compactMap { appearance in
            guard !seen.contains(appearance.coatName) else { return nil }
            seen.insert(appearance.coatName)
            return CoatColor(name: appearance.coatName, hex: appearance.coatHex)
        }
    }

    static func eyeColors(species: String, breed: String, coatColor: String) -> [EyeColor]? {
        guard let appearances = breedAppearances(
            speciesSlug: normalizedSpecies(species),
            breedSlug: normalizedBreed(breed)
        ),
              coatColor == "自定义" || appearances.contains(where: { $0.coatName == coatColor }) else { return nil }
        return [EyeColor(name: "黑色", hex: "111111")]
    }

    static func defaultAppearance(species: String, breed: String) -> Appearance? {
        breedAppearances(speciesSlug: normalizedSpecies(species), breedSlug: normalizedBreed(breed))?.first
    }

    static func avatarFilename(species: String, breed: String, gender: String, coatColor: String, eyeColor: String) -> String? {
        let speciesSlug = normalizedSpecies(species)
        let genderSlug = normalizedGender(gender)

        guard speciesStandardSlugs.contains(speciesSlug) else { return nil }
        let breedSlug = normalizedBreed(breed)
        guard let appearances = breedAppearances(speciesSlug: speciesSlug, breedSlug: breedSlug) else {
            return "\(speciesSlug)_\(genderSlug)_standard.png"
        }

        guard coatColor != "自定义",
              let appearance = appearances.first(where: { $0.coatName == coatColor }) else {
            return "\(speciesSlug)_\(genderSlug)_standard.png"
        }

        return "\(speciesSlug)_\(breedSlug)_\(genderSlug)_\(appearance.coatSlug).png"
    }

    private static func breedAppearances(speciesSlug: String, breedSlug: String) -> [Appearance]? {
        switch speciesSlug {
        case "cat": return catBreedAppearances[breedSlug]
        case "dog": return dogBreedAppearances[breedSlug]
        default: return nil
        }
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
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if devonRexBreedNames.contains(trimmed) {
            return "devon_rex"
        }
        if britishShorthairBreedNames.contains(trimmed) {
            return "british_shorthair"
        }
        if americanShorthairBreedNames.contains(trimmed) {
            return "american_shorthair"
        }
        if ragdollBreedNames.contains(trimmed) {
            return "ragdoll"
        }
        if siameseBreedNames.contains(trimmed) {
            return "siamese"
        }
        if abyssinianBreedNames.contains(trimmed) {
            return "abyssinian"
        }
        if maineCoonBreedNames.contains(trimmed) {
            return "maine_coon"
        }
        if persianBreedNames.contains(trimmed) {
            return "persian"
        }
        if liHuaBreedNames.contains(trimmed) {
            return "li_hua"
        }
        if shibaInuBreedNames.contains(trimmed) {
            return "shiba_inu"
        }
        if goldenRetrieverBreedNames.contains(trimmed) {
            return "golden_retriever"
        }
        return trimmed
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
