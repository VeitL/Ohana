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
            humanCandidates(for: draft, l: l)
        case .pet:
            petCandidates(for: draft, l: l)
        }
    }

    private static func humanCandidates(for draft: MemberCreationDraft, l: L10n) -> [Avatar2DCandidate] {
        let gender = HumanProfileOptions.normalizedGender(draft.humanGender)
        let fallbackGender = ["男", "女", "非二元"].contains(gender) ? gender : "nonbinary"
        let birthday = draft.hasBirthday ? draft.birthday : nil
        let defaultFilename = HumanAvatarAssetCatalog.avatarFilename(gender: fallbackGender, birthday: birthday)
        let genderSlug = humanGenderSlug(fallbackGender)
        let groups = HumanAvatarAssetCatalog.AgeGroup.allCases
        let defaultGroup = HumanAvatarAssetCatalog.ageGroup(for: birthday)
        let orderedGroups = ([defaultGroup] + groups.filter { $0 != defaultGroup }).prefix(4)
        var filenames = orderedGroups.map { "human_\(genderSlug)_\($0.rawValue).webp" }
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
        guard let defaultFilename = PetAvatarAssetCatalog.avatarFilename(
            species: draft.resolvedSpecies,
            breed: draft.resolvedBreed,
            gender: draft.petGender,
            coatColor: draft.coatColor
        ) else { return [] }
        return makeCandidates(
            filenames: [defaultFilename],
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
            let clean = (filename as NSString)
                .deletingPathExtension
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

    private static func humanGenderSlug(_ gender: String) -> String {
        switch HumanProfileOptions.normalizedGender(gender) {
        case "男": "male"
        case "女": "female"
        default: "nonbinary"
        }
    }
}
