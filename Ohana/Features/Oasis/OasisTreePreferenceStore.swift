import Foundation

enum OasisTreePreferenceStore {
    static let passiveIncomeKey = "lastTreeHarvestDate"
    static let dailyInjectionDayKey = "oasis_v2DailyTreeInjectionDay"
    static let weeklyInjectionWeekKey = "oasis_v2WeeklyTreeInjectionWeek"

    private static let injectedEnergyKey = "oasis_injectedEnergy"
    private static let lastRewardedLevelKey = "oasis_lastRewardedLevel"
    private static let dailyTreeCoconutDayKey = "oasis_dailyTreeCoconutDay"
    private static let dailyTreeCoconutCountKey = "oasis_dailyTreeCoconutCount"
    private static let dailyTreeCoconutHarvestedKey = "oasis_dailyTreeCoconutHarvestedIndices"
    private static let v2LegacyBaselineXPKey = "oasis_v2LegacyBaselineXP"
    private static let defaults = UserDefaults.standard

    static var injectedEnergy: Int {
        get { defaults.integer(forKey: injectedEnergyKey) }
        set { defaults.set(newValue, forKey: injectedEnergyKey) }
    }

    static var lastRewardedLevel: Int {
        get { defaults.integer(forKey: lastRewardedLevelKey) }
        set { defaults.set(newValue, forKey: lastRewardedLevelKey) }
    }

    static func lastPassiveIncomeDate() -> Date? {
        defaults.object(forKey: passiveIncomeKey) as? Date
    }

    static func markPassiveIncomeHarvested(_ date: Date) {
        defaults.set(date, forKey: passiveIncomeKey)
    }

    static func dailyTreeCoconutState() -> (dayKey: String?, coconutCount: Int, harvestedIndices: Set<Int>) {
        (
            defaults.string(forKey: dailyTreeCoconutDayKey),
            defaults.integer(forKey: dailyTreeCoconutCountKey),
            Set((defaults.array(forKey: dailyTreeCoconutHarvestedKey) as? [Int]) ?? [])
        )
    }

    static func storeDailyTreeCoconutState(
        dayKey: String,
        coconutCount: Int,
        harvestedIndices: Set<Int>
    ) {
        defaults.set(dayKey, forKey: dailyTreeCoconutDayKey)
        defaults.set(coconutCount, forKey: dailyTreeCoconutCountKey)
        defaults.set(harvestedIndices.sorted(), forKey: dailyTreeCoconutHarvestedKey)
    }

    static func legacyBaselineXP() -> Int? {
        defaults.object(forKey: v2LegacyBaselineXPKey) == nil
            ? nil
            : defaults.integer(forKey: v2LegacyBaselineXPKey)
    }

    static func storeLegacyBaselineXP(_ xp: Int) {
        defaults.set(xp, forKey: v2LegacyBaselineXPKey)
    }

    static func injectionUsedPeriod(for limitKey: String) -> String? {
        defaults.string(forKey: limitKey)
    }

    static func markInjectionUsed(limitKey: String, periodKey: String) {
        defaults.set(periodKey, forKey: limitKey)
    }
}
