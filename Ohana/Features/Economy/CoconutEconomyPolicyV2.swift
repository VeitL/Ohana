import Foundation
import SwiftData

enum CoconutWalkRewardPolicy {
    static let minimumRewardDistanceMeters = 20.0

    static func isRewardable(distanceMeters: Double) -> Bool {
        distanceMeters >= minimumRewardDistanceMeters
    }

    static func baseGrowthXP(for distanceMeters: Double) -> Int {
        min(20, max(8, Int(max(0, distanceMeters) / 250)))
    }

    static func baseCoconuts(for distanceMeters: Double) -> Int {
        min(14, max(5, Int(max(0, distanceMeters) / 350)))
    }

    static func earnedCoconuts(for distanceMeters: Double) -> Int {
        isRewardable(distanceMeters: distanceMeters) ? baseCoconuts(for: distanceMeters) : 0
    }

    static func splitCoconuts(total: Int) -> (human: Int, pet: Int) {
        guard total > 0 else { return (0, 0) }
        let pet = max(1, total / 3)
        return (total - pet, pet)
    }
}

enum EconomyLuckTier: String, Equatable {
    case none
    case small
    case golden

    var growthXP: Int {
        switch self {
        case .none: 0
        case .small: 5
        case .golden: 15
        }
    }

    var coconuts: Int {
        switch self {
        case .none: 0
        case .small: 2
        case .golden: 8
        }
    }
}

enum EconomyBudgetStage: String, Equatable {
    case normal
    case fatigue
    case recordOnly
    case cooldown

    var xpMultiplier: Double {
        switch self {
        case .normal: 1.0
        case .fatigue: 0.5
        case .recordOnly, .cooldown: 0.2
        }
    }

    var coconutMultiplier: Double {
        switch self {
        case .normal: 1.0
        case .fatigue: 0.5
        case .recordOnly, .cooldown: 0
        }
    }

    var reason: String {
        switch self {
        case .normal: "normal"
        case .fatigue: "dailyBudgetFatigue"
        case .recordOnly: "dailyBudgetRecordOnly"
        case .cooldown: "cooldownReduced"
        }
    }

    private var rank: Int {
        switch self {
        case .normal: 0
        case .fatigue: 1
        case .recordOnly: 2
        case .cooldown: 3
        }
    }

    static func strictest(_ lhs: EconomyBudgetStage, _ rhs: EconomyBudgetStage) -> EconomyBudgetStage {
        lhs.rank >= rhs.rank ? lhs : rhs
    }
}

struct EconomyRewardResult: Equatable {
    let growthXP: Int
    let humanCoconuts: Int
    let petCoconuts: Int
    let bonusCoconuts: Int
    let luckyCoconuts: Int
    let budgetMultiplier: Double
    let budgetStage: EconomyBudgetStage
    let reason: String
    let actionKey: String
    let isOnCooldown: Bool
    let baseGrowthXP: Int
    let baseCoconuts: Int
    let luck: EconomyLuckTier

    var totalCoconuts: Int {
        humanCoconuts + petCoconuts
    }

    var feedbackMessage: String {
        feedbackMessage(l: .current)
    }

    func feedbackMessage(l: L10n) -> String {
        let coconutText = totalCoconuts > 0
            ? l.tr(zh: "，+\(totalCoconuts)椰子", en: ", +\(totalCoconuts) coconuts", de: ", +\(totalCoconuts) Kokosnüsse")
            : ""
        switch budgetStage {
        case .cooldown:
            return l.tr(
                zh: "已记录，冷却内成长 +\(growthXP)XP",
                en: "Recorded. Cooldown growth +\(growthXP)XP",
                de: "Erfasst. Abklingzeit-Wachstum +\(growthXP)XP"
            )
        case .fatigue:
            return l.tr(
                zh: "今日进入疲劳收益，+\(growthXP)XP\(coconutText)",
                en: "Gentle rewards now. +\(growthXP)XP\(coconutText)",
                de: "Sanfte Belohnung jetzt. +\(growthXP)XP\(coconutText)"
            )
        case .recordOnly:
            return l.tr(
                zh: "今日椰子已装满，明天继续～",
                en: "Coconuts are full today. More tomorrow.",
                de: "Kokosnüsse heute voll. Morgen weiter.",
                es: "Cocos llenos por hoy. Mañana seguimos.",
                pt: "Cocos cheios hoje. Amanhã seguimos.",
                fr: "Cocos pleins pour aujourd’hui. À demain.",
                ja: "今日のココナッツは満タン。続きは明日。",
                ko: "오늘 코코넛은 가득 찼어요. 내일 이어가요.",
                it: "Cocco pieno per oggi. Si continua domani."
            )
        case .normal:
            if luck == .golden {
                return l.tr(
                    zh: "金色幸运，+\(growthXP)XP\(coconutText)",
                    en: "Golden luck, +\(growthXP)XP\(coconutText)",
                    de: "Goldenes Glück, +\(growthXP)XP\(coconutText)"
                )
            }
            if luck == .small {
                return l.tr(
                    zh: "小幸运，+\(growthXP)XP\(coconutText)",
                    en: "Small luck, +\(growthXP)XP\(coconutText)",
                    de: "Kleines Glück, +\(growthXP)XP\(coconutText)"
                )
            }
            if bonusCoconuts > luckyCoconuts {
                return l.tr(
                    zh: "完整记录加成，+\(growthXP)XP\(coconutText)",
                    en: "Complete log bonus, +\(growthXP)XP\(coconutText)",
                    de: "Bonus für vollständigen Eintrag, +\(growthXP)XP\(coconutText)"
                )
            }
            return l.tr(
                zh: "成长 +\(growthXP)XP\(coconutText)",
                en: "Growth +\(growthXP)XP\(coconutText)",
                de: "Wachstum +\(growthXP)XP\(coconutText)"
            )
        }
    }

    var metadataJSON: String {
        """
        {"economyVersion":2,"growthXP":\(growthXP),"humanCoconuts":\(humanCoconuts),"petCoconuts":\(petCoconuts),"coconutBase":\(baseCoconuts),"coconutBonus":\(bonusCoconuts),"luckyCoconuts":\(luckyCoconuts),"budgetMultiplier":\(Self.format(budgetMultiplier)),"budgetStage":"\(budgetStage.rawValue)","reason":"\(Self.escape(reason))","actionKey":"\(Self.escape(actionKey))","cooldown":\(isOnCooldown),"luck":"\(luck.rawValue)"}
        """
    }

    static let empty = EconomyRewardResult(
        growthXP: 0,
        humanCoconuts: 0,
        petCoconuts: 0,
        bonusCoconuts: 0,
        luckyCoconuts: 0,
        budgetMultiplier: 0,
        budgetStage: .normal,
        reason: "none",
        actionKey: "none",
        isOnCooldown: false,
        baseGrowthXP: 0,
        baseCoconuts: 0,
        luck: .none
    )

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

struct EconomyDailyBudgetSnapshot: Equatable {
    let householdKey: String
    let memberKey: String
    let careObjectKeys: [String]
    let dayKey: String
    let xpUsed: Int
    let coconutUsed: Int
    let memberXPUsed: Int
    let memberCoconutUsed: Int
    let careObjectXPUsed: [String: Int]
    let careObjectCoconutUsed: [String: Int]
    let luckyCoconutUsed: Int
    let highXPBudget: Int
    let fatigueXPBudget: Int
    let highCoconutBudget: Int
    let fatigueCoconutBudget: Int
    let memberHighXPBudget: Int
    let memberFatigueXPBudget: Int
    let memberHighCoconutBudget: Int
    let memberFatigueCoconutBudget: Int
    let objectHighXPBudget: Int
    let objectFatigueXPBudget: Int
    let objectHighCoconutBudget: Int
    let objectFatigueCoconutBudget: Int

    var userKey: String { householdKey }
    var xpBudget: Int { highXPBudget }
    var coconutBudget: Int { highCoconutBudget }
    var remainingXP: Int { max(0, fatigueXPBudget - xpUsed) }
    var remainingCoconuts: Int { max(0, fatigueCoconutBudget - coconutUsed) }
    var remainingFatigueCoconuts: Int {
        min(
            max(0, fatigueCoconutBudget - coconutUsed),
            max(0, memberFatigueCoconutBudget - memberCoconutUsed),
            careObjectRemainingFatigueCoconuts
        )
    }

    var remainingLuckyCoconuts: Int { max(0, EconomyDailyBudgetStore.luckyCoconutBudget - luckyCoconutUsed) }

    var budgetStage: EconomyBudgetStage {
        let householdStage = Self.stage(
            xpUsed: xpUsed,
            coconutUsed: coconutUsed,
            highXPBudget: highXPBudget,
            fatigueXPBudget: fatigueXPBudget,
            highCoconutBudget: highCoconutBudget,
            fatigueCoconutBudget: fatigueCoconutBudget
        )
        let memberStage = Self.stage(
            xpUsed: memberXPUsed,
            coconutUsed: memberCoconutUsed,
            highXPBudget: memberHighXPBudget,
            fatigueXPBudget: memberFatigueXPBudget,
            highCoconutBudget: memberHighCoconutBudget,
            fatigueCoconutBudget: memberFatigueCoconutBudget
        )
        return careObjectKeys.reduce(EconomyBudgetStage.strictest(householdStage, memberStage)) { current, objectKey in
            let objectStage = Self.stage(
                xpUsed: careObjectXPUsed[objectKey] ?? 0,
                coconutUsed: careObjectCoconutUsed[objectKey] ?? 0,
                highXPBudget: objectHighXPBudget,
                fatigueXPBudget: objectFatigueXPBudget,
                highCoconutBudget: objectHighCoconutBudget,
                fatigueCoconutBudget: objectFatigueCoconutBudget
            )
            return EconomyBudgetStage.strictest(current, objectStage)
        }
    }

    private var careObjectRemainingFatigueCoconuts: Int {
        guard !careObjectKeys.isEmpty else { return Int.max }
        return careObjectKeys.reduce(0) { total, objectKey in
            total + max(0, objectFatigueCoconutBudget - (careObjectCoconutUsed[objectKey] ?? 0))
        }
    }

    private static func stage(
        xpUsed: Int,
        coconutUsed: Int,
        highXPBudget: Int,
        fatigueXPBudget: Int,
        highCoconutBudget: Int,
        fatigueCoconutBudget: Int
    ) -> EconomyBudgetStage {
        if xpUsed < highXPBudget, coconutUsed < highCoconutBudget {
            return .normal
        }
        if xpUsed < fatigueXPBudget, coconutUsed < fatigueCoconutBudget {
            return .fatigue
        }
        return .recordOnly
    }
}

enum EconomyDailyBudgetStore {
    static let luckyCoconutBudget = 12

    private static let prefix = "economyV2.dailyBudget"
    private static let usagePruneDayKey = "\(prefix).usagePrune.lastDay"
    private static let calendar = Calendar(identifier: .gregorian)

    static func snapshot(
        userKey: String,
        careObjectCount: Int,
        date: Date = Date(),
        context: ModelContext? = nil
    ) -> EconomyDailyBudgetSnapshot {
        snapshot(
            householdKey: userKey,
            memberKey: userKey,
            careObjectCount: careObjectCount,
            date: date,
            context: context
        )
    }

    static func snapshot(
        householdKey: String,
        memberKey: String,
        careObjectKeys: [String] = [],
        careObjectCount: Int,
        date: Date = Date(),
        context: ModelContext? = nil
    ) -> EconomyDailyBudgetSnapshot {
        let household = normalizedUserKey(householdKey)
        let member = normalizedUserKey(memberKey)
        let objects = normalizedCareObjectKeys(careObjectKeys)
        let day = dayKey(for: date)
        let highXP = highXPBudget(careObjectCount: careObjectCount)
        let fatigueXP = fatigueXPBudget(careObjectCount: careObjectCount)
        let highCoconuts = coconutBudget(careObjectCount: careObjectCount)
        let fatigueCoconuts = fatigueCoconutBudget(careObjectCount: careObjectCount)
        let persisted = persistedUsage(
            context: context,
            householdKey: household,
            memberKey: member,
            careObjectKeys: objects,
            dayKey: day
        )
        let defaultsCareObjectXP = usageByCareObject(
            householdKey: household,
            careObjectKeys: objects,
            metric: "xp",
            date: date
        )
        let defaultsCareObjectCoconuts = usageByCareObject(
            householdKey: household,
            careObjectKeys: objects,
            metric: "coconut",
            date: date
        )
        return EconomyDailyBudgetSnapshot(
            householdKey: household,
            memberKey: member,
            careObjectKeys: objects,
            dayKey: day,
            xpUsed: max(
                UserDefaults.standard.integer(forKey: householdStorageKey(householdKey: household, metric: "xp", date: date)),
                persisted.householdXP
            ),
            coconutUsed: max(
                UserDefaults.standard.integer(forKey: householdStorageKey(householdKey: household, metric: "coconut", date: date)),
                persisted.householdCoconuts
            ),
            memberXPUsed: max(
                UserDefaults.standard.integer(forKey: memberStorageKey(householdKey: household, memberKey: member, metric: "xp", date: date)),
                persisted.memberXP
            ),
            memberCoconutUsed: max(
                UserDefaults.standard.integer(forKey: memberStorageKey(householdKey: household, memberKey: member, metric: "coconut", date: date)),
                persisted.memberCoconuts
            ),
            careObjectXPUsed: mergedCareObjectUsage(defaults: defaultsCareObjectXP, persisted: persisted.careObjectXP, keys: objects),
            careObjectCoconutUsed: mergedCareObjectUsage(
                defaults: defaultsCareObjectCoconuts,
                persisted: persisted.careObjectCoconuts,
                keys: objects
            ),
            luckyCoconutUsed: max(
                UserDefaults.standard.integer(forKey: householdStorageKey(householdKey: household, metric: "lucky", date: date)),
                persisted.luckyCoconuts
            ),
            highXPBudget: highXP,
            fatigueXPBudget: fatigueXP,
            highCoconutBudget: highCoconuts,
            fatigueCoconutBudget: fatigueCoconuts,
            memberHighXPBudget: memberHighXPBudget(careObjectCount: careObjectCount),
            memberFatigueXPBudget: memberFatigueXPBudget(careObjectCount: careObjectCount),
            memberHighCoconutBudget: memberCoconutBudget(careObjectCount: careObjectCount),
            memberFatigueCoconutBudget: memberFatigueCoconutBudget(careObjectCount: careObjectCount),
            objectHighXPBudget: objectHighXPBudget,
            objectFatigueXPBudget: objectFatigueXPBudget,
            objectHighCoconutBudget: objectCoconutBudget,
            objectFatigueCoconutBudget: objectFatigueCoconutBudget
        )
    }

    static func commit(
        _ result: EconomyRewardResult,
        userKey: String,
        date: Date = Date(),
        context: ModelContext? = nil,
        save: Bool = true,
        writeDefaults: Bool = true
    ) {
        commit(
            result,
            householdKey: userKey,
            memberKey: userKey,
            date: date,
            context: context,
            save: save,
            writeDefaults: writeDefaults
        )
    }

    static func commit(
        _ result: EconomyRewardResult,
        householdKey: String,
        memberKey: String,
        careObjectKeys: [String] = [],
        date: Date = Date(),
        context: ModelContext? = nil,
        save: Bool = true,
        writeDefaults: Bool = true
    ) {
        let household = normalizedUserKey(householdKey)
        let member = normalizedUserKey(memberKey)
        let objects = normalizedCareObjectKeys(careObjectKeys)
        if writeDefaults {
            increment(householdStorageKey(householdKey: household, metric: "xp", date: date), by: result.growthXP)
            increment(householdStorageKey(householdKey: household, metric: "coconut", date: date), by: result.totalCoconuts)
            increment(householdStorageKey(householdKey: household, metric: "lucky", date: date), by: result.luckyCoconuts)
            increment(memberStorageKey(householdKey: household, memberKey: member, metric: "xp", date: date), by: result.growthXP)
            increment(memberStorageKey(householdKey: household, memberKey: member, metric: "coconut", date: date), by: result.totalCoconuts)
            for (objectKey, amount) in distribute(result.growthXP, across: objects) {
                increment(careObjectStorageKey(householdKey: household, careObjectKey: objectKey, metric: "xp", date: date), by: amount)
            }
            for (objectKey, amount) in distribute(result.totalCoconuts, across: objects) {
                increment(careObjectStorageKey(householdKey: household, careObjectKey: objectKey, metric: "coconut", date: date), by: amount)
            }
        }
        persistUsage(
            result,
            householdKey: household,
            memberKey: member,
            careObjectKeys: objects,
            date: date,
            context: context,
            save: save
        )
    }

    static func reset(userKey: String, date: Date = Date()) {
        reset(householdKey: userKey, memberKey: userKey, date: date)
    }

    static func reset(householdKey: String, memberKey: String, careObjectKeys: [String] = [], date: Date = Date()) {
        let household = normalizedUserKey(householdKey)
        let member = normalizedUserKey(memberKey)
        for item in ["xp", "coconut", "lucky"] {
            UserDefaults.standard.removeObject(forKey: householdStorageKey(householdKey: household, metric: item, date: date))
        }
        for item in ["xp", "coconut"] {
            UserDefaults.standard.removeObject(forKey: memberStorageKey(householdKey: household, memberKey: member, metric: item, date: date))
        }
        for objectKey in normalizedCareObjectKeys(careObjectKeys) {
            for item in ["xp", "coconut"] {
                UserDefaults.standard.removeObject(forKey: careObjectStorageKey(householdKey: household, careObjectKey: objectKey, metric: item, date: date))
            }
        }
    }

    static func resetAll() {
        let defaults = UserDefaults.standard
        for (key, _) in defaults.dictionaryRepresentation() where key.hasPrefix("\(prefix).") {
            defaults.removeObject(forKey: key)
        }
    }

    @discardableResult
    static func pruneOldUsageEvents(
        context: ModelContext,
        retainingDays: Int = 45,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Int {
        let todayKey = dayKey(for: now)
        guard defaults.string(forKey: usagePruneDayKey) != todayKey else { return 0 }
        let retainedDays = max(1, retainingDays)
        let cutoffDate = calendar.date(byAdding: .day, value: -retainedDays, to: now) ?? now
        let cutoffKey = dayKey(for: cutoffDate)
        let descriptor = FetchDescriptor<EconomyBudgetUsageEvent>(
            predicate: #Predicate { event in
                event.dayKey < cutoffKey
            }
        )

        do {
            let oldEvents = try context.fetch(descriptor)
            for event in oldEvents {
                context.delete(event)
            }
            if !oldEvents.isEmpty {
                try context.save()
            }
            defaults.set(todayKey, forKey: usagePruneDayKey)
            return oldEvents.count
        } catch {
            #if DEBUG
                OhanaLog.error("[EconomyDailyBudgetStore] prune failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return 0
        }
    }

    static func xpBudget(careObjectCount: Int) -> Int {
        highXPBudget(careObjectCount: careObjectCount)
    }

    static func highXPBudget(careObjectCount: Int) -> Int {
        min(160, 80 + max(0, careObjectCount - 1) * 20)
    }

    static func fatigueXPBudget(careObjectCount: Int) -> Int {
        min(240, highXPBudget(careObjectCount: careObjectCount) + 60)
    }

    static func coconutBudget(careObjectCount: Int) -> Int {
        min(64, 32 + max(0, careObjectCount - 1) * 8)
    }

    static func fatigueCoconutBudget(careObjectCount: Int) -> Int {
        min(96, coconutBudget(careObjectCount: careObjectCount) + 24)
    }

    static func memberHighXPBudget(careObjectCount: Int) -> Int {
        max(80, Int(Double(highXPBudget(careObjectCount: careObjectCount)) * 0.85))
    }

    static func memberFatigueXPBudget(careObjectCount: Int) -> Int {
        max(120, Int(Double(fatigueXPBudget(careObjectCount: careObjectCount)) * 0.85))
    }

    static func memberCoconutBudget(careObjectCount: Int) -> Int {
        max(32, Int(Double(coconutBudget(careObjectCount: careObjectCount)) * 0.85))
    }

    static func memberFatigueCoconutBudget(careObjectCount: Int) -> Int {
        max(56, Int(Double(fatigueCoconutBudget(careObjectCount: careObjectCount)) * 0.85))
    }

    static let objectHighXPBudget = 80
    static let objectFatigueXPBudget = 140
    static let objectCoconutBudget = 32
    static let objectFatigueCoconutBudget = 56

    static func dayKey(for date: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func normalizedUserKey(_ userKey: String) -> String {
        userKey.isEmpty ? "system" : userKey
    }

    private static func normalizedCareObjectKeys(_ careObjectKeys: [String]) -> [String] {
        Array(Set(careObjectKeys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }

    private static func usageByCareObject(
        householdKey: String,
        careObjectKeys: [String],
        metric: String,
        date: Date
    ) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: careObjectKeys.map { objectKey in
            (
                objectKey,
                UserDefaults.standard.integer(
                    forKey: careObjectStorageKey(householdKey: householdKey, careObjectKey: objectKey, metric: metric, date: date)
                )
            )
        })
    }

    private struct PersistedBudgetUsage {
        var householdXP: Int = 0
        var householdCoconuts: Int = 0
        var memberXP: Int = 0
        var memberCoconuts: Int = 0
        var careObjectXP: [String: Int] = [:]
        var careObjectCoconuts: [String: Int] = [:]
        var luckyCoconuts: Int = 0

        static let empty = PersistedBudgetUsage()
    }

    private static func persistedUsage(
        context: ModelContext?,
        householdKey: String,
        memberKey: String,
        careObjectKeys: [String],
        dayKey: String
    ) -> PersistedBudgetUsage {
        guard let context else { return .empty }
        let descriptor = FetchDescriptor<EconomyBudgetUsageEvent>(
            predicate: #Predicate { event in
                event.dayKey == dayKey && event.householdKey == householdKey
            }
        )
        let events: [EconomyBudgetUsageEvent]
        do {
            events = try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[CoconutEconomyPolicyV2] failed to fetch persisted budget usage: \(error.localizedDescription)",
                category: "Economy"
            )
            return .empty
        }
        guard !events.isEmpty else { return .empty }

        let objectKeySet = Set(careObjectKeys)
        return events.reduce(into: PersistedBudgetUsage()) { usage, event in
            switch event.scope {
            case .household:
                usage.householdXP += event.growthXPUsed
                usage.householdCoconuts += event.coconutUsed
                usage.luckyCoconuts += event.luckyCoconutUsed
            case .member:
                guard event.scopeKey == memberKey else { return }
                usage.memberXP += event.growthXPUsed
                usage.memberCoconuts += event.coconutUsed
            case .careObject:
                guard objectKeySet.contains(event.scopeKey) else { return }
                usage.careObjectXP[event.scopeKey, default: 0] += event.growthXPUsed
                usage.careObjectCoconuts[event.scopeKey, default: 0] += event.coconutUsed
            }
        }
    }

    private static func mergedCareObjectUsage(
        defaults: [String: Int],
        persisted: [String: Int],
        keys: [String]
    ) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: keys.map { key in
            (key, max(defaults[key] ?? 0, persisted[key] ?? 0))
        })
    }

    private static func persistUsage(
        _ result: EconomyRewardResult,
        householdKey: String,
        memberKey: String,
        careObjectKeys: [String],
        date: Date,
        context: ModelContext?,
        save: Bool
    ) {
        guard result.growthXP > 0 || result.totalCoconuts > 0 || result.luckyCoconuts > 0,
              let context else { return }

        let day = dayKey(for: date)
        let now = Date()
        let metadataJSON = result.metadataJSON
        context.insert(
            EconomyBudgetUsageEvent(
                dayKey: day,
                householdKey: householdKey,
                memberKey: memberKey,
                scope: .household,
                scopeKey: householdKey,
                growthXPUsed: result.growthXP,
                coconutUsed: result.totalCoconuts,
                luckyCoconutUsed: result.luckyCoconuts,
                actionKey: result.actionKey,
                source: "economyReward",
                metadataJSON: metadataJSON,
                occurredAt: date,
                createdAt: now
            )
        )
        context.insert(
            EconomyBudgetUsageEvent(
                dayKey: day,
                householdKey: householdKey,
                memberKey: memberKey,
                scope: .member,
                scopeKey: memberKey,
                growthXPUsed: result.growthXP,
                coconutUsed: result.totalCoconuts,
                actionKey: result.actionKey,
                source: "economyReward",
                metadataJSON: metadataJSON,
                occurredAt: date,
                createdAt: now
            )
        )
        let objectXP = distribute(result.growthXP, across: careObjectKeys)
        let objectCoconuts = distribute(result.totalCoconuts, across: careObjectKeys)
        for objectKey in Set(objectXP.keys).union(objectCoconuts.keys).sorted() {
            let xpAmount = objectXP[objectKey] ?? 0
            let coconutAmount = objectCoconuts[objectKey] ?? 0
            context.insert(
                EconomyBudgetUsageEvent(
                    dayKey: day,
                    householdKey: householdKey,
                    memberKey: memberKey,
                    careObjectKey: objectKey,
                    scope: .careObject,
                    scopeKey: objectKey,
                    growthXPUsed: xpAmount,
                    coconutUsed: coconutAmount,
                    actionKey: result.actionKey,
                    source: "economyReward",
                    metadataJSON: metadataJSON,
                    occurredAt: date,
                    createdAt: now
                )
            )
        }
        if save {
            context.safeSave()
        }
    }

    private static func distribute(_ total: Int, across keys: [String]) -> [String: Int] {
        guard total > 0, !keys.isEmpty else { return [:] }
        let base = total / keys.count
        let remainder = total % keys.count
        return Dictionary(uniqueKeysWithValues: keys.enumerated().map { index, key in
            (key, base + (index < remainder ? 1 : 0))
        })
    }

    private static func householdStorageKey(householdKey: String, metric: String, date: Date) -> String {
        "\(prefix).household.\(householdKey).\(dayKey(for: date)).\(metric)"
    }

    private static func memberStorageKey(householdKey: String, memberKey: String, metric: String, date: Date) -> String {
        "\(prefix).member.\(householdKey).\(memberKey).\(dayKey(for: date)).\(metric)"
    }

    private static func careObjectStorageKey(householdKey: String, careObjectKey: String, metric: String, date: Date) -> String {
        "\(prefix).object.\(householdKey).\(careObjectKey).\(dayKey(for: date)).\(metric)"
    }

    private static func increment(_ key: String, by amount: Int) {
        guard amount > 0 else { return }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + amount, forKey: key)
    }
}

enum CoconutEconomyPolicyV2 {
    static let version = 2

    static func reward(
        for type: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
        isOnCooldown: Bool,
        userKey: String,
        memberKey: String? = nil,
        careObjectKeys: [String] = [],
        careObjectCount: Int,
        hasHumanAccount: Bool,
        hasPetAccount: Bool,
        date: Date = Date(),
        forcedLuck: EconomyLuckTier? = nil,
        context: ModelContext? = nil
    ) -> EconomyRewardResult {
        reward(
            base: baseReward(for: type),
            quality: quality,
            isOnCooldown: isOnCooldown,
            userKey: userKey,
            memberKey: memberKey,
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount,
            hasHumanAccount: hasHumanAccount,
            hasPetAccount: hasPetAccount,
            date: date,
            forcedLuck: forcedLuck,
            context: context
        )
    }

    static func sharedReward(
        for type: QuestManager.OhanaActionType,
        targetCount: Int,
        quality: QuestManager.QualityBonus,
        isOnCooldown: Bool,
        userKey: String,
        memberKey: String? = nil,
        careObjectKeys: [String] = [],
        careObjectCount: Int,
        hasHumanAccount: Bool,
        date: Date = Date(),
        forcedLuck: EconomyLuckTier? = nil,
        context: ModelContext? = nil
    ) -> EconomyRewardResult {
        let base = baseReward(for: type)
        let petCount = max(1, targetCount)
        let merged = BaseReward(
            actionKey: base.actionKey,
            growthXP: base.growthXP + max(0, petCount - 1) * max(1, base.growthXP / 2),
            coconuts: base.humanShare + base.petShare * petCount,
            humanShare: base.humanShare,
            petShare: base.petShare * petCount
        )
        return reward(
            base: merged,
            quality: quality,
            isOnCooldown: isOnCooldown,
            userKey: userKey,
            memberKey: memberKey,
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount,
            hasHumanAccount: hasHumanAccount,
            hasPetAccount: true,
            date: date,
            forcedLuck: forcedLuck,
            context: context
        )
    }

    private static func reward(
        base: BaseReward,
        quality: QuestManager.QualityBonus,
        isOnCooldown: Bool,
        userKey: String,
        memberKey: String?,
        careObjectKeys: [String],
        careObjectCount: Int,
        hasHumanAccount: Bool,
        hasPetAccount: Bool,
        date: Date,
        forcedLuck: EconomyLuckTier?,
        context: ModelContext?
    ) -> EconomyRewardResult {
        let qualitySteps = qualityBonusSteps(for: quality)
        let qualityMultiplier = 1.0 + Double(qualitySteps) * 0.1
        let baseGrowthXP = Int(ceil(Double(base.growthXP) * qualityMultiplier))
        let qualityCoconutBonus = qualitySteps > 0 && base.coconuts > 0 ? 1 : 0
        let budget = EconomyDailyBudgetStore.snapshot(
            householdKey: userKey,
            memberKey: memberKey ?? userKey,
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount,
            date: date,
            context: context
        )
        let budgetStage = isOnCooldown ? EconomyBudgetStage.cooldown : budget.budgetStage

        let luck = budgetStage == .cooldown ? .none : (forcedLuck ?? rollLuck())
        let requestedLuckyCoconuts = min(luck.coconuts, budget.remainingLuckyCoconuts)
        let requestedCoconuts = base.coconuts + qualityCoconutBonus + requestedLuckyCoconuts
        let requestedGrowthXP = baseGrowthXP + luck.growthXP

        let growthXP = max(1, Int(ceil(Double(requestedGrowthXP) * budgetStage.xpMultiplier)))
        let scaledCoconuts = Int(ceil(Double(requestedCoconuts) * budgetStage.coconutMultiplier))
        let allowedCoconuts = min(scaledCoconuts, budget.remainingFatigueCoconuts)
        let effectiveStage: EconomyBudgetStage = if budgetStage == .normal, allowedCoconuts < requestedCoconuts {
            .fatigue
        } else if budgetStage != .cooldown, requestedCoconuts > 0, allowedCoconuts == 0 {
            .recordOnly
        } else {
            budgetStage
        }

        let actualLuckyCoconuts = min(requestedLuckyCoconuts, max(0, allowedCoconuts - base.coconuts - qualityCoconutBonus))
        let split = splitCoconuts(
            total: allowedCoconuts,
            preferredHuman: base.humanShare,
            preferredPet: base.petShare,
            hasHumanAccount: hasHumanAccount,
            hasPetAccount: hasPetAccount
        )

        return EconomyRewardResult(
            growthXP: growthXP,
            humanCoconuts: split.human,
            petCoconuts: split.pet,
            bonusCoconuts: actualLuckyCoconuts + (allowedCoconuts > base.coconuts ? min(qualityCoconutBonus, allowedCoconuts - base.coconuts) : 0),
            luckyCoconuts: actualLuckyCoconuts,
            budgetMultiplier: budgetStage.xpMultiplier,
            budgetStage: effectiveStage,
            reason: effectiveStage.reason,
            actionKey: base.actionKey,
            isOnCooldown: isOnCooldown,
            baseGrowthXP: baseGrowthXP,
            baseCoconuts: min(base.coconuts, allowedCoconuts),
            luck: actualLuckyCoconuts > 0 ? luck : .none
        )
    }

    static func careObjectCount(context: ModelContext) -> Int {
        let pets: [Pet]
        do {
            pets = try context.fetch(FetchDescriptor<Pet>())
        } catch {
            OhanaLog.warning(
                "[CoconutEconomyPolicyV2] failed to fetch pets for care object count: \(error.localizedDescription)",
                category: "Economy"
            )
            pets = []
        }
        let petCount = pets.count(where: { !$0.hasPassedAway })

        let plantCount: Int
        do {
            plantCount = try context.fetchCount(FetchDescriptor<Plant>())
        } catch {
            OhanaLog.warning(
                "[CoconutEconomyPolicyV2] failed to fetch plant count for care object count: \(error.localizedDescription)",
                category: "Economy"
            )
            plantCount = 0
        }
        return max(1, petCount + plantCount)
    }

    static func currentUserKey() -> String {
        UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 } ?? "system"
    }

    static func householdBudgetKey(context _: ModelContext? = nil) -> String {
        "household.local"
    }

    static func metadataValue(named key: String, in metadataJSON: String) -> Int {
        guard !metadataJSON.isEmpty,
              let data = metadataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }
        if let intValue = object[key] as? Int { return intValue }
        if let doubleValue = object[key] as? Double { return Int(doubleValue) }
        if let stringValue = object[key] as? String { return Int(stringValue) ?? 0 }
        return 0
    }

    private struct BaseReward {
        let actionKey: String
        let growthXP: Int
        let coconuts: Int
        let humanShare: Int
        let petShare: Int
    }

    private static func baseReward(for type: QuestManager.OhanaActionType) -> BaseReward {
        switch type {
        case .feed:
            return BaseReward(actionKey: "feed", growthXP: 6, coconuts: 3, humanShare: 2, petShare: 1)
        case .water:
            return BaseReward(actionKey: "water", growthXP: 5, coconuts: 3, humanShare: 2, petShare: 1)
        case let .potty(isLitter):
            return isLitter
                ? BaseReward(actionKey: "litter", growthXP: 7, coconuts: 3, humanShare: 2, petShare: 1)
                : BaseReward(actionKey: "potty", growthXP: 5, coconuts: 2, humanShare: 1, petShare: 1)
        case let .care(type):
            switch type {
            case .bath:
                return BaseReward(actionKey: "bath", growthXP: 14, coconuts: 8, humanShare: 6, petShare: 2)
            case .teeth, .nails, .ears:
                return BaseReward(actionKey: "hygiene", growthXP: 12, coconuts: 6, humanShare: 4, petShare: 2)
            case .brushing:
                return BaseReward(actionKey: "brushing", growthXP: 10, coconuts: 5, humanShare: 3, petShare: 2)
            }
        case let .walk(distanceMeters):
            let xp = CoconutWalkRewardPolicy.baseGrowthXP(for: distanceMeters)
            let coconuts = CoconutWalkRewardPolicy.baseCoconuts(for: distanceMeters)
            let split = CoconutWalkRewardPolicy.splitCoconuts(total: coconuts)
            return BaseReward(actionKey: "walk", growthXP: xp, coconuts: coconuts, humanShare: split.human, petShare: split.pet)
        case .health:
            return BaseReward(actionKey: "health", growthXP: 16, coconuts: 10, humanShare: 8, petShare: 2)
        case .expense:
            return BaseReward(actionKey: "expense", growthXP: 4, coconuts: 2, humanShare: 2, petShare: 0)
        case .weight:
            return BaseReward(actionKey: "weight", growthXP: 8, coconuts: 4, humanShare: 3, petShare: 1)
        case .milestone:
            return BaseReward(actionKey: "milestone", growthXP: 7, coconuts: 3, humanShare: 2, petShare: 1)
        case .dailyFocusCompletion:
            return BaseReward(actionKey: "dailyFocusCompletion", growthXP: 18, coconuts: 8, humanShare: 8, petShare: 0)
        case let .general(humanReward, petReward, _, title):
            let total = max(0, humanReward) + max(0, petReward)
            return BaseReward(
                actionKey: "general_\(title.prefix(18))",
                growthXP: max(1, total),
                coconuts: total,
                humanShare: max(0, humanReward),
                petShare: max(0, petReward)
            )
        }
    }

    private static func qualityBonusSteps(for quality: QuestManager.QualityBonus) -> Int {
        switch quality {
        case .none:
            0
        case .precise, .withNote, .withPhoto:
            1
        case .preciseAndNote, .preciseAndPhoto:
            2
        case .preciseNotePhoto:
            3
        }
    }

    private static func rollLuck() -> EconomyLuckTier {
        let roll = Int.random(in: 1 ... 100)
        if roll == 100 { return .golden }
        if roll >= 92 { return .small }
        return .none
    }

    private static func splitCoconuts(
        total: Int,
        preferredHuman: Int,
        preferredPet: Int,
        hasHumanAccount: Bool,
        hasPetAccount: Bool
    ) -> (human: Int, pet: Int) {
        guard total > 0 else { return (0, 0) }
        if hasHumanAccount, hasPetAccount {
            let preferredTotal = max(1, preferredHuman + preferredPet)
            let pet = min(total, Int((Double(total) * Double(preferredPet) / Double(preferredTotal)).rounded()))
            return (total - pet, pet)
        }
        if hasHumanAccount { return (total, 0) }
        if hasPetAccount { return (0, total) }
        return (0, 0)
    }
}
