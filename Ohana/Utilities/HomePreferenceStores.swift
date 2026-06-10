import CoreGraphics
import Foundation

enum IslandQuestClaimStore {
    static func isCoconutClaimedToday(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: coconutClaimedKey(date: date, calendar: calendar))
    }

    static func markCoconutClaimedToday(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: coconutClaimedKey(date: date, calendar: calendar))
    }

    private static func coconutClaimedKey(date: Date, calendar: Calendar) -> String {
        "coconut_claimed_\(calendar.startOfDay(for: date).timeIntervalSince1970)"
    }
}

enum TodayFocusHiddenStateStore {
    static func clearSkippedFocusKeys(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: skippedStorageKey(date: date, calendar: calendar))
    }

    static func save(skippedFocusKeys: Set<String>, closedNegativeKeys: Set<String>, date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        defaults.set(Array(skippedFocusKeys), forKey: skippedStorageKey(date: date, calendar: calendar))
        defaults.set(Array(closedNegativeKeys), forKey: closedNegativeStorageKey)
    }

    static func loadSkippedFocusKeys(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: skippedStorageKey(date: date, calendar: calendar)) ?? [])
    }

    static func loadClosedNegativeKeys(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: closedNegativeStorageKey) ?? [])
    }

    private static func skippedStorageKey(date: Date, calendar: Calendar) -> String {
        let day = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        return "todayFocus.skipped.\(day)"
    }

    private static let closedNegativeStorageKey = "todayFocus.closedNegativeSignals"
}

enum HomeSafeAreaCacheStore {
    static func cachedTop(defaults: UserDefaults = .standard) -> CGFloat? {
        cachedValue(forKey: cachedTopKey, defaults: defaults)
    }

    static func cachedBottom(defaults: UserDefaults = .standard) -> CGFloat? {
        cachedValue(forKey: cachedBottomKey, defaults: defaults)
    }

    static func cache(top: CGFloat, bottom: CGFloat, defaults: UserDefaults = .standard) {
        guard top > 1, bottom > 1 else { return }
        defaults.set(Double(top), forKey: cachedTopKey)
        defaults.set(Double(bottom), forKey: cachedBottomKey)
    }

    private static func cachedValue(forKey key: String, defaults: UserDefaults) -> CGFloat? {
        let cached = defaults.double(forKey: key)
        return cached > 1 ? CGFloat(cached) : nil
    }

    private static let cachedTopKey = "home.safeArea.top.v1"
    private static let cachedBottomKey = "home.safeArea.bottom.v1"
}

enum SettingsPreferenceStore {
    static func enabledByDefaultBool(forKey key: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    static func set(_ value: Bool, forKey key: String, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }
}

enum DatabaseFallbackPreferenceStore {
    static func isFallbackActive(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: fallbackActiveKey)
    }

    static func clearFallbackActive(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: fallbackActiveKey)
    }

    static func markFallbackActive(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: fallbackActiveKey)
    }

    private static let fallbackActiveKey = "ohana_db_fallback_active"
}
