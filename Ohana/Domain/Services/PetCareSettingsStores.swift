import Foundation

nonisolated struct WaterCareSettingsSnapshot {
    let waterIntervalDays: Int
    let filterCleanIntervalDays: Int
    let filterReplaceIntervalDays: Int
    let waterReminderOn: Bool
    let filterReminderOn: Bool
    let waterAmountEnabled: Bool
    let waterAmountMl: Double
    let waterChangeAnchorDate: Date
    let createdWaterChangeAnchor: Bool
}

enum WaterCareSettingsStore {
    nonisolated static func snapshot(
        petKey: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> WaterCareSettingsSnapshot {
        let anchorTimeInterval = defaults.double(forKey: waterChangeCycleAnchorKey(petKey))
        let createdAnchor = anchorTimeInterval <= 0
        let amount = defaults.double(forKey: waterAmountKey(petKey))
        return WaterCareSettingsSnapshot(
            waterIntervalDays: positiveInteger(defaults.integer(forKey: waterIntervalKey(petKey)), fallback: 3),
            filterCleanIntervalDays: positiveInteger(defaults.integer(forKey: filterCleanIntervalKey(petKey)), fallback: 14),
            filterReplaceIntervalDays: positiveInteger(defaults.integer(forKey: filterReplaceIntervalKey(petKey)), fallback: 90),
            waterReminderOn: defaults.bool(forKey: waterReminderKey(petKey)),
            filterReminderOn: defaults.bool(forKey: filterReminderKey(petKey)),
            waterAmountEnabled: defaults.object(forKey: waterAmountEnabledKey(petKey)) == nil
                ? true
                : defaults.bool(forKey: waterAmountEnabledKey(petKey)),
            waterAmountMl: amount > 0 ? amount : 250,
            waterChangeAnchorDate: createdAnchor
                ? calendar.startOfDay(for: now)
                : Date(timeIntervalSince1970: anchorTimeInterval),
            createdWaterChangeAnchor: createdAnchor
        )
    }

    nonisolated static func waterIntervalDays(petKey: String, defaults: UserDefaults = .standard) -> Int {
        positiveInteger(defaults.integer(forKey: waterIntervalKey(petKey)), fallback: 3)
    }

    nonisolated static func filterCleanIntervalDays(petKey: String, defaults: UserDefaults = .standard) -> Int {
        positiveInteger(defaults.integer(forKey: filterCleanIntervalKey(petKey)), fallback: 14)
    }

    nonisolated static func filterReplaceIntervalDays(petKey: String, defaults: UserDefaults = .standard) -> Int {
        positiveInteger(defaults.integer(forKey: filterReplaceIntervalKey(petKey)), fallback: 90)
    }

    static func saveWaterSettings(
        petKey: String,
        intervalDays: Int,
        reminderOn: Bool,
        cycleAnchor: Date,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(intervalDays, forKey: waterIntervalKey(petKey))
        defaults.set(cycleAnchor.timeIntervalSince1970, forKey: waterChangeCycleAnchorKey(petKey))
        defaults.set(reminderOn, forKey: waterReminderKey(petKey))
    }

    static func saveWaterAmountSettings(
        petKey: String,
        enabled: Bool,
        amountMl: Double?,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: waterAmountEnabledKey(petKey))
        if let amountMl {
            defaults.set(amountMl, forKey: waterAmountKey(petKey))
        }
    }

    static func saveFilterSettings(
        petKey: String,
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(cleanIntervalDays, forKey: filterCleanIntervalKey(petKey))
        defaults.set(replaceIntervalDays, forKey: filterReplaceIntervalKey(petKey))
        defaults.set(reminderOn, forKey: filterReminderKey(petKey))
    }

    private nonisolated static func positiveInteger(_ value: Int, fallback: Int) -> Int {
        max(value > 0 ? value : fallback, 1)
    }

    private nonisolated static func waterIntervalKey(_ petKey: String) -> String { "waterInterval_\(petKey)" }
    private nonisolated static func filterCleanIntervalKey(_ petKey: String) -> String { "filterCleanInterval_\(petKey)" }
    private nonisolated static func filterReplaceIntervalKey(_ petKey: String) -> String { "filterReplaceInterval_\(petKey)" }
    private nonisolated static func waterReminderKey(_ petKey: String) -> String { "waterReminder_\(petKey)" }
    private nonisolated static func filterReminderKey(_ petKey: String) -> String { "filterReminder_\(petKey)" }
    private nonisolated static func waterAmountEnabledKey(_ petKey: String) -> String { "waterAmountEnabled_\(petKey)" }
    private nonisolated static func waterAmountKey(_ petKey: String) -> String { "waterAmountMl_\(petKey)" }
    private nonisolated static func waterChangeCycleAnchorKey(_ petKey: String) -> String { "waterChangeCycleAnchor_\(petKey)" }
}

struct LitterCareSettingsSnapshot {
    let scoopIntervalDays: Int
    let scoopReminderOn: Bool
    let scoopAnchorDate: Date
    let createdScoopAnchor: Bool
    let litterChangeIntervalDays: Int
    let litterReminderOn: Bool
    let litterCycleAnchorDate: Date
    let createdLitterCycleAnchor: Bool
    let lastFullChangeDate: Date?
}

enum LitterCareSettingsStore {
    static func snapshot(
        petKey: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> LitterCareSettingsSnapshot {
        let scoopAnchorTimestamp = defaults.double(forKey: scoopAnchorKey(petKey))
        let createdScoopAnchor = scoopAnchorTimestamp <= 0
        let litterAnchorTimestamp = defaults.double(forKey: litterChangeCycleAnchorKey(petKey))
        let createdLitterAnchor = litterAnchorTimestamp <= 0
        return LitterCareSettingsSnapshot(
            scoopIntervalDays: positiveInteger(defaults.integer(forKey: scoopIntervalKey(petKey)), fallback: 1),
            scoopReminderOn: defaults.bool(forKey: scoopReminderKey(petKey)),
            scoopAnchorDate: createdScoopAnchor
                ? calendar.startOfDay(for: now)
                : Date(timeIntervalSince1970: scoopAnchorTimestamp),
            createdScoopAnchor: createdScoopAnchor,
            litterChangeIntervalDays: positiveInteger(defaults.integer(forKey: litterChangeIntervalKey(petKey)), fallback: 14),
            litterReminderOn: defaults.bool(forKey: litterReminderKey(petKey)),
            litterCycleAnchorDate: createdLitterAnchor
                ? calendar.startOfDay(for: now)
                : Date(timeIntervalSince1970: litterAnchorTimestamp),
            createdLitterCycleAnchor: createdLitterAnchor,
            lastFullChangeDate: lastFullChangeDate(petKey: petKey, defaults: defaults)
        )
    }

    static func saveScoopSettings(
        petKey: String,
        intervalDays: Int,
        anchorDate: Date,
        reminderOn: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(intervalDays, forKey: scoopIntervalKey(petKey))
        defaults.set(anchorDate.timeIntervalSince1970, forKey: scoopAnchorKey(petKey))
        defaults.set(reminderOn, forKey: scoopReminderKey(petKey))
    }

    static func saveLitterChangeSettings(
        petKey: String,
        intervalDays: Int,
        anchorDate: Date,
        reminderOn: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(intervalDays, forKey: litterChangeIntervalKey(petKey))
        defaults.set(anchorDate.timeIntervalSince1970, forKey: litterChangeCycleAnchorKey(petKey))
        defaults.set(reminderOn, forKey: litterReminderKey(petKey))
    }

    static func markFullChange(
        petKey: String,
        changedAt: Date,
        cycleAnchor: Date,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(changedAt.timeIntervalSince1970, forKey: lastLitterChangeKey(petKey))
        defaults.set(cycleAnchor.timeIntervalSince1970, forKey: litterChangeCycleAnchorKey(petKey))
    }

    static func lastFullChangeDate(petKey: String, defaults: UserDefaults = .standard) -> Date? {
        let timestamp = defaults.double(forKey: lastLitterChangeKey(petKey))
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    private static func positiveInteger(_ value: Int, fallback: Int) -> Int {
        max(value > 0 ? value : fallback, 1)
    }

    private static func scoopIntervalKey(_ petKey: String) -> String { "scoopIntervalDays_\(petKey)" }
    private static func scoopAnchorKey(_ petKey: String) -> String { "scoopAnchorDate_\(petKey)" }
    private static func scoopReminderKey(_ petKey: String) -> String { "scoopReminder_\(petKey)" }
    private static func litterChangeIntervalKey(_ petKey: String) -> String { "litterChangeInterval_\(petKey)" }
    private static func litterChangeCycleAnchorKey(_ petKey: String) -> String { "litterChangeCycleAnchor_\(petKey)" }
    private static func litterReminderKey(_ petKey: String) -> String { "litterReminder_\(petKey)" }
    private static func lastLitterChangeKey(_ petKey: String) -> String { "lastLitterChangeDate_\(petKey)" }
}
