//
//  MemberAvatar2DCandidateProvider.swift
//  Ohana
//
//  2D avatar candidate discovery for member creation.
//

import Foundation

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

