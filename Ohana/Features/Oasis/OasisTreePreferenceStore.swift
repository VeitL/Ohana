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

    private nonisolated static let injectedEnergyKey = "oasis_injectedEnergy"
    private nonisolated static let careGrowthEnergyKey = "oasis_careGrowthEnergy"
    private static let careGrowthBaselineKey = "oasis_careGrowthBaselineXP"
    private static let lastRewardedLevelKey = "oasis_lastRewardedLevel"
    private static let dailyTreeCoconutDayKey = "oasis_dailyTreeCoconutDay"
    private static let dailyTreeCoconutCountKey = "oasis_dailyTreeCoconutCount"
    private static let dailyTreeCoconutHarvestedKey = "oasis_dailyTreeCoconutHarvestedIndices"
    private static let v2LegacyBaselineXPKey = "oasis_v2LegacyBaselineXP"
    private static let v2LegacyBaselineXPScaleVersionKey = "oasis_v2LegacyBaselineXPScaleVersion"
    private static let ledgerEnergyCacheVersionKey = "oasis_ledgerEnergyCacheVersion"
    private static let ledgerEnergyProcessedCountKey = "oasis_ledgerEnergyProcessedCount"
    private static let ledgerEnergyLatestEventIdKey = "oasis_ledgerEnergyLatestEventId"
    private static let ledgerEnergyLatestOccurredAtKey = "oasis_ledgerEnergyLatestOccurredAt"
    private static let ledgerEnergyGrowthXPKey = "oasis_ledgerEnergyGrowthXP"
    private static let ledgerEnergyInjectedXPKey = "oasis_ledgerEnergyInjectedXP"
    private static let legacyBaselineXPScaleVersion = 2
    private static let ledgerEnergyCacheVersion = 1
    private static let defaults = UserDefaults.standard

    nonisolated static var injectedEnergy: Int {
        get { UserDefaults.standard.integer(forKey: injectedEnergyKey) }
        set { UserDefaults.standard.set(newValue, forKey: injectedEnergyKey) }
    }

    /// 照护养分累计能量(计入树等级)。派生自账本,持久化仅为冷启动即时显示。
    nonisolated static var careGrowthEnergy: Int {
        get { UserDefaults.standard.integer(forKey: careGrowthEnergyKey) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: careGrowthEnergyKey) }
    }

    /// 迁移基线:接入"照护养树"当刻的历史养分总量;之后只有超过基线的新增养分
    /// 才计入树,避免既有存档因历史照护一次性爆级。nil 表示尚未设立基线。
    static func careGrowthBaseline() -> Int? {
        defaults.object(forKey: careGrowthBaselineKey) == nil
            ? nil
            : defaults.integer(forKey: careGrowthBaselineKey)
    }

    static func storeCareGrowthBaseline(_ value: Int) {
        defaults.set(max(0, value), forKey: careGrowthBaselineKey)
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
        legacyBaselineXPRecord()?.xp
    }

    static func legacyBaselineXPRecord() -> (xp: Int, isCurrentScale: Bool)? {
        defaults.object(forKey: v2LegacyBaselineXPKey) == nil
            ? nil
            : (
                defaults.integer(forKey: v2LegacyBaselineXPKey),
                defaults.integer(forKey: v2LegacyBaselineXPScaleVersionKey) == legacyBaselineXPScaleVersion
            )
    }

    static func storeLegacyBaselineXP(_ xp: Int) {
        defaults.set(xp, forKey: v2LegacyBaselineXPKey)
        defaults.set(legacyBaselineXPScaleVersion, forKey: v2LegacyBaselineXPScaleVersionKey)
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
