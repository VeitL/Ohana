import Foundation

// MARK: - 首页喂食模式（与 QuickFeedDetailSheet 分段控件同步）

enum HomeFeedRecordMode: String {
    case manual
    case planned

    static func storedRaw(for petId: UUID) -> String {
        HomeFeedRecordModePreferenceStore.storedRaw(for: petId, fallback: manual.rawValue)
    }

    static func isPlanned(for petId: UUID) -> Bool {
        storedRaw(for: petId) == planned.rawValue
    }

    static func set(_ petId: UUID, mode: HomeFeedRecordMode) {
        HomeFeedRecordModePreferenceStore.set(petId, rawValue: mode.rawValue)
    }
}

private enum HomeFeedRecordModePreferenceStore {
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
