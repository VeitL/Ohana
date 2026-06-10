import Foundation

enum PetBondVaultPreferenceStore {
    static let revisionKey = "petBondVaultRevision"
    private static let defaults = UserDefaults.standard

    static func unlockedIDs(for petId: UUID) -> Set<String> {
        let raw = defaults.string(forKey: key(for: petId)) ?? ""
        return Set(raw.split(separator: ",").map(String.init))
    }

    static func unlock(_ kind: PetBondVaultItemKind, for petId: UUID) {
        var ids = unlockedIDs(for: petId)
        ids.insert(kind.rawValue)
        defaults.set(ids.sorted().joined(separator: ","), forKey: key(for: petId))
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }

    static func consumptionCount(_ kind: PetBondVaultItemKind, for petId: UUID) -> Int {
        defaults.integer(forKey: consumptionKey(petId: petId, kind: kind))
    }

    static func consume(_ kind: PetBondVaultItemKind, for petId: UUID) {
        let key = consumptionKey(petId: petId, kind: kind)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }

    private static func key(for petId: UUID) -> String {
        "petBondVaultUnlocked_\(petId.uuidString)"
    }

    private static func consumptionKey(petId: UUID, kind: PetBondVaultItemKind) -> String {
        "petBondVaultConsumed_\(petId.uuidString)_\(kind.rawValue)"
    }
}

enum HomeFeedRecordModePreferenceStore {
    private static let defaults = UserDefaults.standard

    static func storedRaw(for petId: UUID, fallback: String) -> String {
        defaults.string(forKey: storageKey(petId: petId)) ?? fallback
    }

    static func set(_ petId: UUID, rawValue: String) {
        defaults.set(rawValue, forKey: storageKey(petId: petId))
    }

    private static func storageKey(petId: UUID) -> String {
        "feedRecordMode_\(petId.uuidString)"
    }
}

enum PetHygieneCyclePreferenceStore {
    private static let defaults = UserDefaults.standard

    static func customCycleDays(for type: HygieneType, petId: UUID) -> Int? {
        let value = defaults.integer(forKey: customCycleDaysKey(petId: petId, type: type))
        return value > 0 ? value : nil
    }

    static func setCustomCycleDays(_ days: Int, for type: HygieneType, petId: UUID) {
        let key = customCycleDaysKey(petId: petId, type: type)
        if days > 0 {
            defaults.set(days, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func customCycleDaysKey(petId: UUID, type: HygieneType) -> String {
        "hygiene_cycle_\(petId.uuidString)_\(type.rawValue)"
    }
}

enum CustomPersonalityTagPreferenceStore {
    private static let key = "ohana_custom_personality_tags_v1"
    private static let defaults = UserDefaults.standard

    static func load() -> [CustomPersonalityTagRecord] {
        guard let data = defaults.string(forKey: key)?.data(using: .utf8),
              let arr = try? JSONDecoder().decode([CustomPersonalityTagRecord].self, from: data) else {
            return []
        }
        return arr
    }
}
