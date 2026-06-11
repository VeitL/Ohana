import Foundation

struct OasisLedgerEnergyCache: Equatable {
    var processedEventCount: Int
    var latestEventId: String?
    var latestOccurredAt: Date?
    var growthXP: Int
    var injectedXP: Int
}

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
    private static let ledgerEnergyCacheVersionKey = "oasis_ledgerEnergyCacheVersion"
    private static let ledgerEnergyProcessedCountKey = "oasis_ledgerEnergyProcessedCount"
    private static let ledgerEnergyLatestEventIdKey = "oasis_ledgerEnergyLatestEventId"
    private static let ledgerEnergyLatestOccurredAtKey = "oasis_ledgerEnergyLatestOccurredAt"
    private static let ledgerEnergyGrowthXPKey = "oasis_ledgerEnergyGrowthXP"
    private static let ledgerEnergyInjectedXPKey = "oasis_ledgerEnergyInjectedXP"
    private static let ledgerEnergyCacheVersion = 1
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

    static func ledgerEnergyCache() -> OasisLedgerEnergyCache? {
        guard defaults.integer(forKey: ledgerEnergyCacheVersionKey) == ledgerEnergyCacheVersion,
              defaults.object(forKey: ledgerEnergyProcessedCountKey) != nil else {
            return nil
        }
        return OasisLedgerEnergyCache(
            processedEventCount: defaults.integer(forKey: ledgerEnergyProcessedCountKey),
            latestEventId: defaults.string(forKey: ledgerEnergyLatestEventIdKey),
            latestOccurredAt: defaults.object(forKey: ledgerEnergyLatestOccurredAtKey) as? Date,
            growthXP: defaults.integer(forKey: ledgerEnergyGrowthXPKey),
            injectedXP: defaults.integer(forKey: ledgerEnergyInjectedXPKey)
        )
    }

    static func storeLedgerEnergyCache(_ cache: OasisLedgerEnergyCache) {
        defaults.set(ledgerEnergyCacheVersion, forKey: ledgerEnergyCacheVersionKey)
        defaults.set(max(0, cache.processedEventCount), forKey: ledgerEnergyProcessedCountKey)
        if let latestEventId = cache.latestEventId {
            defaults.set(latestEventId, forKey: ledgerEnergyLatestEventIdKey)
        } else {
            defaults.removeObject(forKey: ledgerEnergyLatestEventIdKey)
        }
        if let latestOccurredAt = cache.latestOccurredAt {
            defaults.set(latestOccurredAt, forKey: ledgerEnergyLatestOccurredAtKey)
        } else {
            defaults.removeObject(forKey: ledgerEnergyLatestOccurredAtKey)
        }
        defaults.set(max(0, cache.growthXP), forKey: ledgerEnergyGrowthXPKey)
        defaults.set(max(0, cache.injectedXP), forKey: ledgerEnergyInjectedXPKey)
    }

    static func clearLedgerEnergyCache() {
        defaults.removeObject(forKey: ledgerEnergyCacheVersionKey)
        defaults.removeObject(forKey: ledgerEnergyProcessedCountKey)
        defaults.removeObject(forKey: ledgerEnergyLatestEventIdKey)
        defaults.removeObject(forKey: ledgerEnergyLatestOccurredAtKey)
        defaults.removeObject(forKey: ledgerEnergyGrowthXPKey)
        defaults.removeObject(forKey: ledgerEnergyInjectedXPKey)
    }

    static func injectionUsedPeriod(for limitKey: String) -> String? {
        defaults.string(forKey: limitKey)
    }

    static func markInjectionUsed(limitKey: String, periodKey: String) {
        defaults.set(periodKey, forKey: limitKey)
    }

    static func restoreInjectionUsed(limitKey: String, previousPeriodKey: String?) {
        if let previousPeriodKey {
            defaults.set(previousPeriodKey, forKey: limitKey)
        } else {
            defaults.removeObject(forKey: limitKey)
        }
    }
}
