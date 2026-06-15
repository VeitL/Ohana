import Foundation

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
