//
//  CheckInStreakStore.swift
//  Ohana
//
//  User-scoped daily check-in streak persistence.
//

import Foundation

enum CheckInStreakStore {
    static let legacyCheckedInKey = "oasis_checkedIn_dates"
    static let legacyMakeupDatesKey = "oasis_makeup_dates"
    nonisolated static let makeupPackKey = "inventory_backdate_1day_count"
    private static let legacyMigrationMarkerKey = "oasis_checkin_legacy_migrated_to_human_id"
    private static let legacyMilestoneKey = "checkIn_lastClaimedMilestone"

    static func ownerKey(for humanId: String) -> String {
        let trimmed = humanId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unbound" : trimmed
    }

    static func checkedInKey(for humanId: String) -> String {
        "oasis_checkedIn_dates_\(ownerKey(for: humanId))"
    }

    static func makeupDatesKey(for humanId: String) -> String {
        "oasis_makeup_dates_\(ownerKey(for: humanId))"
    }

    static func milestoneKey(for humanId: String) -> String {
        "checkIn_lastClaimedMilestone_\(ownerKey(for: humanId))"
    }

    static func migrateLegacyIfNeeded(for humanId: String) {
        let owner = ownerKey(for: humanId)
        guard owner != "unbound" else { return }

        let defaults = UserDefaults.standard
        if defaults.string(forKey: legacyMigrationMarkerKey) == nil,
           defaults.object(forKey: checkedInKey(for: owner)) == nil,
           let legacyDates = defaults.stringArray(forKey: legacyCheckedInKey),
           !legacyDates.isEmpty {
            defaults.set(legacyDates, forKey: checkedInKey(for: owner))
            if let legacyMakeupDates = defaults.stringArray(forKey: legacyMakeupDatesKey), !legacyMakeupDates.isEmpty {
                defaults.set(legacyMakeupDates, forKey: makeupDatesKey(for: owner))
            }
            let legacyMilestone = defaults.integer(forKey: legacyMilestoneKey)
            if legacyMilestone > 0 {
                defaults.set(legacyMilestone, forKey: milestoneKey(for: owner))
            }
            defaults.set(owner, forKey: legacyMigrationMarkerKey)
        }
    }

    static func checkedInDates(for humanId: String) -> Set<String> {
        migrateLegacyIfNeeded(for: humanId)
        return Set(UserDefaults.standard.stringArray(forKey: checkedInKey(for: humanId)) ?? [])
    }

    static func setCheckedInDates(_ dates: Set<String>, for humanId: String) {
        UserDefaults.standard.set(Array(dates).sorted(), forKey: checkedInKey(for: humanId))
    }

    static func makeupDates(for humanId: String) -> Set<String> {
        migrateLegacyIfNeeded(for: humanId)
        return Set(UserDefaults.standard.stringArray(forKey: makeupDatesKey(for: humanId)) ?? [])
    }

    static func setMakeupDates(_ dates: Set<String>, for humanId: String) {
        UserDefaults.standard.set(Array(dates).sorted(), forKey: makeupDatesKey(for: humanId))
    }

    static func lastClaimedMilestone(for humanId: String) -> Int {
        migrateLegacyIfNeeded(for: humanId)
        return UserDefaults.standard.integer(forKey: milestoneKey(for: humanId))
    }

    static func setLastClaimedMilestone(_ days: Int, for humanId: String) {
        UserDefaults.standard.set(days, forKey: milestoneKey(for: humanId))
    }

    static func dateString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    static func currentStreak(for humanId: String, calendar: Calendar = .current, from date: Date = Date()) -> Int {
        let checkedInDates = checkedInDates(for: humanId)
        var streak = 0
        var day = date
        while true {
            let value = dateString(day)
            guard checkedInDates.contains(value) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    static func longestStreak(for humanId: String, calendar: Calendar = .current) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let sorted = checkedInDates(for: humanId).compactMap { formatter.date(from: $0) }.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<sorted.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: sorted[index - 1]),
               calendar.isDate(expected, inSameDayAs: sorted[index]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
