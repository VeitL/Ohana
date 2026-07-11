import CoreGraphics
import Foundation

nonisolated enum TodayFocusHiddenStateStore {
    static func clearSkippedFocusKeys(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: date, calendar: calendar, defaults: defaults)
        defaults.removeObject(forKey: skippedStorageKey(date: date, calendar: calendar))
    }

    static func clearHiddenFocusKeys(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: date, calendar: calendar, defaults: defaults)
        defaults.removeObject(forKey: skippedStorageKey(date: date, calendar: calendar))
        defaults.removeObject(forKey: closedNegativeStorageKey(date: date, calendar: calendar))
        defaults.removeObject(forKey: legacyClosedNegativeStorageKey)
    }

    static func save(skippedFocusKeys: Set<String>, closedNegativeKeys: Set<String>, date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: date, calendar: calendar, defaults: defaults)
        defaults.set(Array(skippedFocusKeys), forKey: skippedStorageKey(date: date, calendar: calendar))
        defaults.set(Array(closedNegativeKeys), forKey: closedNegativeStorageKey(date: date, calendar: calendar))
        defaults.removeObject(forKey: legacyClosedNegativeStorageKey)
    }

    static func loadSkippedFocusKeys(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Set<String> {
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: date, calendar: calendar, defaults: defaults)
        return Set(defaults.stringArray(forKey: skippedStorageKey(date: date, calendar: calendar)) ?? [])
    }

    static func loadClosedNegativeKeys(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Set<String> {
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: date, calendar: calendar, defaults: defaults)
        return Set(defaults.stringArray(forKey: closedNegativeStorageKey(date: date, calendar: calendar)) ?? [])
    }

    private static func skippedStorageKey(date: Date, calendar: Calendar) -> String {
        let day = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        return "todayFocus.skipped.\(day)"
    }

    private static func closedNegativeStorageKey(date: Date, calendar: Calendar) -> String {
        let day = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        return "todayFocus.closedNegativeSignals.\(day)"
    }

    private static let legacyClosedNegativeStorageKey = "todayFocus.closedNegativeSignals"
}

nonisolated enum TodayFocusDailyPreferenceCleanupStore {
    static func cleanupIfNeeded(date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        let today = calendar.startOfDay(for: date)
        let dayToken = Int(today.timeIntervalSince1970)
        guard defaults.integer(forKey: lastCleanupDayKey) != dayToken else { return }

        let cutoff = calendar.date(byAdding: .day, value: -retainedDayCount, to: today) ?? today
        let cutoffTime = cutoff.timeIntervalSince1970
        for key in defaults.dictionaryRepresentation().keys where shouldRemove(key: key, before: cutoffTime, calendar: calendar) {
            defaults.removeObject(forKey: key)
        }
        defaults.set(dayToken, forKey: lastCleanupDayKey)
    }

    private static func shouldRemove(key: String, before cutoffTime: TimeInterval, calendar: Calendar) -> Bool {
        if timestampSuffix(in: key, prefix: "coconut_claimed_").map({ $0 < cutoffTime }) == true {
            return true
        }
        if timestampSuffix(in: key, prefix: "quest_visit_").map({ $0 < cutoffTime }) == true {
            return true
        }
        if timestampSuffix(in: key, prefix: "todayFocus.skipped.").map({ $0 < cutoffTime }) == true {
            return true
        }
        if timestampSuffix(in: key, prefix: "todayFocus.closedNegativeSignals.").map({ $0 < cutoffTime }) == true {
            return true
        }
        if let recordedDay = initialHumanWeightDate(from: key, calendar: calendar) {
            return recordedDay.timeIntervalSince1970 < cutoffTime
        }
        return false
    }

    private static func timestampSuffix(in key: String, prefix: String) -> TimeInterval? {
        guard key.hasPrefix(prefix) else { return nil }
        return TimeInterval(key.dropFirst(prefix.count))
    }

    private static func initialHumanWeightDate(from key: String, calendar: Calendar) -> Date? {
        let prefix = "ohana.initialHumanWeightRecorded."
        guard key.hasPrefix(prefix), let dateStart = key.lastIndex(of: ".") else { return nil }
        let pieces = key[key.index(after: dateStart)...].split(separator: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static let retainedDayCount = 45
    private static let lastCleanupDayKey = "todayFocus.dailyPreferenceCleanup.lastDay"
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
