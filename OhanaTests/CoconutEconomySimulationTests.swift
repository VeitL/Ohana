import Foundation
import Testing
@testable import Ohana

struct CoconutEconomySimulationTests {
    @Test func walkCoconutRewardUsesSharedV2Formula() {
        #expect(CoconutWalkRewardPolicy.earnedCoconuts(for: 10) == 0)
        #expect(PetWalkLog.coconuts(for: 10) == 0)
        #expect(CoconutWalkRewardPolicy.earnedCoconuts(for: 3000) == 8)
        #expect(PetWalkLog.coconuts(for: 3000) == 8)
        #expect(CoconutWalkRewardPolicy.baseCoconuts(for: 6000) == 14)
    }

    @Test func economyCohortsStayInside30_60_90DayPacing() {
        let light = EconomyCohortSimulator(preset: .lightOnePet).run(days: 90)
        let normal = EconomyCohortSimulator(preset: .normalOnePet).run(days: 90)
        let family = EconomyCohortSimulator(preset: .familyThreePets).run(days: 90)
        let focusOnly = EconomyCohortSimulator(preset: .todayFocusOnly).run(days: 90)
        let healthOnly = EconomyCohortSimulator(preset: .healthOnly).run(days: 90)
        let returning = EconomyCohortSimulator(preset: .returningLegacyNormal).run(days: 30)

        OhanaLog.info(EconomySimulationDashboard.makeMarkdown(reports: [
            light,
            normal,
            family,
            focusOnly,
            healthOnly,
            returning
        ]), category: "EconomySimulation")

        #expect((4 ... 5).contains(light.levelAtDay(30).rawValue))
        #expect(light.levelAtDay(90).rawValue >= TreeLevel.lv7.rawValue)

        #expect((28 ... 42).contains(normal.daysToLevel[.lv7] ?? 0))
        #expect(normal.levelAtDay(60).rawValue >= TreeLevel.lv8.rawValue)
        #expect(normal.levelAtDay(90).rawValue >= TreeLevel.lv9.rawValue)
        #expect(normal.injectedXP * 100 <= normal.totalXP * 15)
        #expect(normal.weeklySpendRate > 0.15)
        #expect(normal.finalBalance < normal.coconutsEarned)

        #expect((18 ... 35).contains(family.daysToLevel[.lv7] ?? 0))
        #expect(family.levelAtDay(90).rawValue >= TreeLevel.lv10.rawValue)
        #expect(family.coconutsEarned <= normal.coconutsEarned * 2)
        #expect(family.careCoconutsEarned < normal.careCoconutsEarned * 2)

        #expect(focusOnly.levelAtDay(30) == .lv5)
        #expect(focusOnly.levelAtDay(60) == .lv6)
        #expect(focusOnly.levelAtDay(90) == .lv7)
        #expect(focusOnly.dailyGoalCoverage == 1.0)

        #expect((5 ... 6).contains(healthOnly.levelAtDay(90).rawValue))

        #expect((1 ... 24).contains(returning.daysToLevel[.lv7] ?? 0))
        #expect(returning.levelAtDay(30).rawValue >= TreeLevel.lv7.rawValue)
        #expect((returning.daysToLevel[.lv8] ?? 31) > 30)
    }

    @Test func heavyFeedSpamRecordsCareButDoesNotInflateCurrency() {
        let report = EconomyCohortSimulator(preset: .heavyFeedSpam).run(days: 1)
        OhanaLog.info(EconomySimulationDashboard.makeMarkdown(reports: [report]), category: "EconomySimulation")

        #expect(report.totalXP >= 90)
        #expect(report.careCoconutsEarned <= 5)
        #expect(report.recordOnlyEvents == 0)
        #expect(report.cooldownEvents == 49)
    }
}

private enum EconomyCohortPreset {
    case lightOnePet
    case normalOnePet
    case familyThreePets
    case todayFocusOnly
    case healthOnly
    case returningLegacyNormal
    case heavyFeedSpam

    var displayName: String {
        switch self {
        case .lightOnePet: "1宠轻用户90天"
        case .normalOnePet: "1宠普通用户90天"
        case .familyThreePets: "3宠家庭90天"
        case .todayFocusOnly: "只做Today Focus"
        case .healthOnly: "只用健康管理"
        case .returningLegacyNormal: "回流老用户30天"
        case .heavyFeedSpam: "重度刷50次喂食"
        }
    }
}

private struct EconomyCohortReport {
    let preset: EconomyCohortPreset
    var totalXP = 0
    var injectedXP = 0
    var careCoconutsEarned = 0
    var coconutsEarned = 0
    var coconutsSpent = 0
    var balance = 0
    var fatigueEvents = 0
    var recordOnlyEvents = 0
    var cooldownEvents = 0
    var dailyGoalDays = 0
    var daysToLevel: [TreeLevel: Int] = [:]
    var levelsByDay: [TreeLevel] = []
    var days: [EconomyCohortDay] = []

    var simulatedDays: Int { max(1, days.count) }
    var finalBalance: Int { balance }
    var averageDailyNetCoconuts: Double {
        Double(coconutsEarned - coconutsSpent) / Double(simulatedDays)
    }

    var weeklySpendRate: Double {
        guard coconutsEarned > 0 else { return 0 }
        return Double(coconutsSpent) / Double(coconutsEarned)
    }

    var budgetTouchRatio: Double {
        Double(days.count(where: { $0.touchedBudget })) / Double(simulatedDays)
    }

    var dailyGoalCoverage: Double {
        Double(dailyGoalDays) / Double(simulatedDays)
    }

    func levelAtDay(_ day: Int) -> TreeLevel {
        guard day > 0 else { return levelsByDay.first ?? .lv1 }
        return levelsByDay[min(day - 1, max(0, levelsByDay.count - 1))]
    }

    func dayToLevelText(_ level: TreeLevel) -> String {
        daysToLevel[level].map(String.init) ?? "-"
    }
}

private struct EconomyCohortDay {
    let index: Int
    let xp: Int
    let earned: Int
    let spent: Int
    let endingBalance: Int
    let fatigueEvents: Int
    let recordOnlyEvents: Int
    let cooldownEvents: Int
    let didCompleteDailyGoal: Bool

    var touchedBudget: Bool {
        fatigueEvents > 0 || recordOnlyEvents > 0
    }
}

private struct EconomyCohortSimulator {
    let preset: EconomyCohortPreset

    private let petObjectKeys = ["pet.sim.1", "pet.sim.2", "pet.sim.3"]

    func run(days: Int) -> EconomyCohortReport {
        var report = EconomyCohortReport(preset: preset, totalXP: legacyBaselineXP)
        var previousLevel = OasisTreeManager.treeLevel(forTotalEnergy: report.totalXP)
        var lastWeeklyInjectionDay: Int?
        var budgetStore = EconomySimulationBudgetStore()

        for dayIndex in 0 ..< days {
            budgetStore.startNewDay()
            let startXP = report.totalXP
            let startEarned = report.coconutsEarned
            let startSpent = report.coconutsSpent
            let startFatigue = report.fatigueEvents
            let startRecordOnly = report.recordOnlyEvents
            let startCooldown = report.cooldownEvents
            let startGoalDays = report.dailyGoalDays
            runCareDay(dayIndex: dayIndex, budgetStore: &budgetStore, report: &report)
            applyLevelRewards(previousLevel: &previousLevel, report: &report, day: dayIndex + 1)
            tryWeeklyInjection(dayIndex: dayIndex, lastWeeklyInjectionDay: &lastWeeklyInjectionDay, previousLevel: &previousLevel, report: &report)
            applyLevelRewards(previousLevel: &previousLevel, report: &report, day: dayIndex + 1)
            report.levelsByDay.append(previousLevel)
            report.days.append(EconomyCohortDay(
                index: dayIndex + 1,
                xp: report.totalXP - startXP,
                earned: report.coconutsEarned - startEarned,
                spent: report.coconutsSpent - startSpent,
                endingBalance: report.balance,
                fatigueEvents: report.fatigueEvents - startFatigue,
                recordOnlyEvents: report.recordOnlyEvents - startRecordOnly,
                cooldownEvents: report.cooldownEvents - startCooldown,
                didCompleteDailyGoal: report.dailyGoalDays > startGoalDays
            ))
        }

        return report
    }

    private var legacyBaselineXP: Int {
        switch preset {
        case .returningLegacyNormal:
            500
        default:
            0
        }
    }

    private func runCareDay(
        dayIndex: Int,
        budgetStore: inout EconomySimulationBudgetStore,
        report: inout EconomyCohortReport
    ) {
        switch preset {
        case .lightOnePet:
            perform(.feed, budgetStore: &budgetStore, report: &report)
            perform(.water, budgetStore: &budgetStore, report: &report)
            if dayIndex.isMultiple(of: 2) {
                perform(.dailyFocusCompletion, budgetStore: &budgetStore, report: &report, hasPetAccount: false)
                report.dailyGoalDays += 1
            }
            if (dayIndex + 1).isMultiple(of: 7) {
                perform(.weight, budgetStore: &budgetStore, report: &report)
            }
        case .normalOnePet, .returningLegacyNormal:
            perform(.feed, budgetStore: &budgetStore, report: &report)
            perform(.water, budgetStore: &budgetStore, report: &report)
            perform(.potty(isLitter: false), budgetStore: &budgetStore, report: &report)
            perform(.dailyFocusCompletion, budgetStore: &budgetStore, report: &report, hasPetAccount: false)
            report.dailyGoalDays += 1
            if (dayIndex + 1).isMultiple(of: 7) {
                perform(.health, budgetStore: &budgetStore, report: &report)
                perform(.weight, budgetStore: &budgetStore, report: &report)
            }
        case .familyThreePets:
            performShared(.feed, targetCount: 3, careObjectCount: 3, budgetStore: &budgetStore, report: &report)
            performShared(.water, targetCount: 3, careObjectCount: 3, budgetStore: &budgetStore, report: &report)
            performShared(.potty(isLitter: false), targetCount: 3, careObjectCount: 3, budgetStore: &budgetStore, report: &report)
            perform(.dailyFocusCompletion, careObjectCount: 3, budgetStore: &budgetStore, report: &report, hasPetAccount: false)
            report.dailyGoalDays += 1
            if (dayIndex + 1).isMultiple(of: 7) {
                performShared(.health, targetCount: 3, careObjectCount: 3, budgetStore: &budgetStore, report: &report)
                performShared(.weight, targetCount: 3, careObjectCount: 3, budgetStore: &budgetStore, report: &report)
            }
        case .todayFocusOnly:
            perform(.dailyFocusCompletion, budgetStore: &budgetStore, report: &report, hasPetAccount: false)
            report.dailyGoalDays += 1
        case .healthOnly:
            if dayIndex.isMultiple(of: 3) {
                perform(.health, budgetStore: &budgetStore, report: &report)
            }
            if (dayIndex + 1).isMultiple(of: 7) {
                perform(.weight, budgetStore: &budgetStore, report: &report)
            }
        case .heavyFeedSpam:
            perform(.feed, budgetStore: &budgetStore, report: &report)
            for _ in 0 ..< 49 {
                perform(.feed, budgetStore: &budgetStore, report: &report, isOnCooldown: true)
            }
        }
    }

    private func perform(
        _ type: QuestManager.OhanaActionType,
        careObjectCount: Int = 1,
        budgetStore: inout EconomySimulationBudgetStore,
        report: inout EconomyCohortReport,
        isOnCooldown: Bool = false,
        hasPetAccount: Bool = true
    ) {
        let careObjectKeys = hasPetAccount ? [petObjectKeys[0]] : []
        let result = budgetStore.reward(
            for: type,
            isOnCooldown: isOnCooldown,
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount,
            hasHumanAccount: true,
            hasPetAccount: hasPetAccount
        )
        commit(result, report: &report)
    }

    private func performShared(
        _ type: QuestManager.OhanaActionType,
        targetCount: Int,
        careObjectCount: Int,
        budgetStore: inout EconomySimulationBudgetStore,
        report: inout EconomyCohortReport
    ) {
        let result = budgetStore.sharedReward(
            for: type,
            targetCount: targetCount,
            isOnCooldown: false,
            careObjectKeys: Array(petObjectKeys.prefix(targetCount)),
            careObjectCount: careObjectCount,
            hasHumanAccount: true
        )
        commit(result, report: &report)
    }

    private func commit(
        _ result: EconomySimulationRewardResult,
        report: inout EconomyCohortReport
    ) {
        report.totalXP += result.growthXP
        report.careCoconutsEarned += result.totalCoconuts
        report.coconutsEarned += result.totalCoconuts
        report.balance += result.totalCoconuts

        switch result.budgetStage {
        case .fatigue:
            report.fatigueEvents += 1
        case .recordOnly:
            report.recordOnlyEvents += 1
        case .cooldown:
            report.cooldownEvents += 1
        case .normal:
            break
        }
    }

    private func tryWeeklyInjection(
        dayIndex: Int,
        lastWeeklyInjectionDay: inout Int?,
        previousLevel: inout TreeLevel,
        report: inout EconomyCohortReport
    ) {
        guard preset == .normalOnePet || preset == .returningLegacyNormal else { return }
        guard previousLevel.rawValue >= TreeLevel.lv5.rawValue, report.balance >= 260 else { return }
        guard lastWeeklyInjectionDay.map({ dayIndex - $0 >= 7 }) ?? true else { return }

        report.balance -= 220
        report.coconutsSpent += 220
        report.injectedXP += 60
        report.totalXP += 60
        lastWeeklyInjectionDay = dayIndex
    }

    private func applyLevelRewards(previousLevel: inout TreeLevel, report: inout EconomyCohortReport, day: Int) {
        let currentLevel = OasisTreeManager.treeLevel(forTotalEnergy: report.totalXP)
        guard currentLevel.rawValue > previousLevel.rawValue else { return }

        for rawValue in (previousLevel.rawValue + 1) ... currentLevel.rawValue {
            guard let level = TreeLevel(rawValue: rawValue) else { continue }
            report.daysToLevel[level] = report.daysToLevel[level] ?? day
            report.coconutsEarned += level.levelUpReward
            report.balance += level.levelUpReward
        }
        previousLevel = currentLevel
    }
}

private struct EconomySimulationRewardResult {
    let growthXP: Int
    let totalCoconuts: Int
    let budgetStage: EconomyBudgetStage
}

private struct EconomySimulationBaseReward {
    let growthXP: Int
    let coconuts: Int
    let humanShare: Int
    let petShare: Int
}

private struct EconomySimulationBudgetStore {
    private var householdXPUsed = 0
    private var householdCoconutUsed = 0
    private var memberXPUsed = 0
    private var memberCoconutUsed = 0
    private var objectXPUsed: [String: Int] = [:]
    private var objectCoconutUsed: [String: Int] = [:]

    mutating func startNewDay() {
        householdXPUsed = 0
        householdCoconutUsed = 0
        memberXPUsed = 0
        memberCoconutUsed = 0
        objectXPUsed.removeAll(keepingCapacity: true)
        objectCoconutUsed.removeAll(keepingCapacity: true)
    }

    mutating func reward(
        for type: QuestManager.OhanaActionType,
        isOnCooldown: Bool,
        careObjectKeys: [String],
        careObjectCount: Int,
        hasHumanAccount: Bool,
        hasPetAccount: Bool
    ) -> EconomySimulationRewardResult {
        let result = calculate(
            base: Self.baseReward(for: type),
            isOnCooldown: isOnCooldown,
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount,
            hasHumanAccount: hasHumanAccount,
            hasPetAccount: hasPetAccount
        )
        commit(result, careObjectKeys: careObjectKeys)
        return result
    }

    mutating func sharedReward(
        for type: QuestManager.OhanaActionType,
        targetCount: Int,
        isOnCooldown: Bool,
        careObjectKeys: [String],
        careObjectCount: Int,
        hasHumanAccount: Bool
    ) -> EconomySimulationRewardResult {
        let base = Self.baseReward(for: type)
        let normalizedCount = max(1, targetCount)
        let sharedCoconuts = base.humanShare + (base.petShare * normalizedCount)
        let sharedBase = EconomySimulationBaseReward(
            growthXP: base.growthXP + max(0, normalizedCount - 1) * max(1, base.growthXP / 2),
            coconuts: sharedCoconuts,
            humanShare: base.humanShare,
            petShare: max(0, sharedCoconuts - base.humanShare)
        )
        let result = calculate(
            base: sharedBase,
            isOnCooldown: isOnCooldown,
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount,
            hasHumanAccount: hasHumanAccount,
            hasPetAccount: true
        )
        commit(result, careObjectKeys: careObjectKeys)
        return result
    }

    private func calculate(
        base: EconomySimulationBaseReward,
        isOnCooldown: Bool,
        careObjectKeys: [String],
        careObjectCount: Int,
        hasHumanAccount: Bool,
        hasPetAccount: Bool
    ) -> EconomySimulationRewardResult {
        let requestedCoconuts = hasHumanAccount || hasPetAccount ? base.coconuts : 0
        let initialStage = isOnCooldown ? EconomyBudgetStage.cooldown : budgetStage(
            careObjectKeys: careObjectKeys,
            careObjectCount: careObjectCount
        )
        let growthXP = max(1, Int(ceil(Double(base.growthXP) * initialStage.xpMultiplier)))
        let scaledCoconuts = Int(ceil(Double(requestedCoconuts) * initialStage.coconutMultiplier))
        let allowedCoconuts = min(scaledCoconuts, remainingFatigueCoconuts(careObjectKeys: careObjectKeys, careObjectCount: careObjectCount))
        let effectiveStage: EconomyBudgetStage = if initialStage == .normal, allowedCoconuts < requestedCoconuts {
            .fatigue
        } else if initialStage != .cooldown, requestedCoconuts > 0, allowedCoconuts == 0 {
            .recordOnly
        } else {
            initialStage
        }
        return EconomySimulationRewardResult(
            growthXP: growthXP,
            totalCoconuts: allowedCoconuts,
            budgetStage: effectiveStage
        )
    }

    private mutating func commit(_ result: EconomySimulationRewardResult, careObjectKeys: [String]) {
        householdXPUsed += result.growthXP
        householdCoconutUsed += result.totalCoconuts
        memberXPUsed += result.growthXP
        memberCoconutUsed += result.totalCoconuts
        for (objectKey, amount) in Self.distribute(result.growthXP, across: careObjectKeys) {
            objectXPUsed[objectKey, default: 0] += amount
        }
        for (objectKey, amount) in Self.distribute(result.totalCoconuts, across: careObjectKeys) {
            objectCoconutUsed[objectKey, default: 0] += amount
        }
    }

    private func budgetStage(careObjectKeys: [String], careObjectCount: Int) -> EconomyBudgetStage {
        let householdStage = Self.stage(
            xpUsed: householdXPUsed,
            coconutUsed: householdCoconutUsed,
            highXPBudget: EconomyDailyBudgetStore.highXPBudget(careObjectCount: careObjectCount),
            fatigueXPBudget: EconomyDailyBudgetStore.fatigueXPBudget(careObjectCount: careObjectCount),
            highCoconutBudget: EconomyDailyBudgetStore.coconutBudget(careObjectCount: careObjectCount),
            fatigueCoconutBudget: EconomyDailyBudgetStore.fatigueCoconutBudget(careObjectCount: careObjectCount)
        )
        let memberStage = Self.stage(
            xpUsed: memberXPUsed,
            coconutUsed: memberCoconutUsed,
            highXPBudget: EconomyDailyBudgetStore.memberHighXPBudget(careObjectCount: careObjectCount),
            fatigueXPBudget: EconomyDailyBudgetStore.memberFatigueXPBudget(careObjectCount: careObjectCount),
            highCoconutBudget: EconomyDailyBudgetStore.memberCoconutBudget(careObjectCount: careObjectCount),
            fatigueCoconutBudget: EconomyDailyBudgetStore.memberFatigueCoconutBudget(careObjectCount: careObjectCount)
        )
        return careObjectKeys.reduce(EconomyBudgetStage.strictest(householdStage, memberStage)) { current, objectKey in
            let objectStage = Self.stage(
                xpUsed: objectXPUsed[objectKey] ?? 0,
                coconutUsed: objectCoconutUsed[objectKey] ?? 0,
                highXPBudget: EconomyDailyBudgetStore.objectHighXPBudget,
                fatigueXPBudget: EconomyDailyBudgetStore.objectFatigueXPBudget,
                highCoconutBudget: EconomyDailyBudgetStore.objectCoconutBudget,
                fatigueCoconutBudget: EconomyDailyBudgetStore.objectFatigueCoconutBudget
            )
            return EconomyBudgetStage.strictest(current, objectStage)
        }
    }

    private func remainingFatigueCoconuts(careObjectKeys: [String], careObjectCount: Int) -> Int {
        let householdRemaining = max(
            0,
            EconomyDailyBudgetStore.fatigueCoconutBudget(careObjectCount: careObjectCount) - householdCoconutUsed
        )
        let memberRemaining = max(
            0,
            EconomyDailyBudgetStore.memberFatigueCoconutBudget(careObjectCount: careObjectCount) - memberCoconutUsed
        )
        let objectRemaining = careObjectKeys.isEmpty ? Int.max : careObjectKeys.reduce(0) { total, objectKey in
            total + max(0, EconomyDailyBudgetStore.objectFatigueCoconutBudget - (objectCoconutUsed[objectKey] ?? 0))
        }
        return min(min(householdRemaining, memberRemaining), objectRemaining)
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

    private static func distribute(_ total: Int, across keys: [String]) -> [String: Int] {
        guard total > 0, !keys.isEmpty else { return [:] }
        let uniqueKeys = Array(Set(keys)).sorted()
        let base = total / uniqueKeys.count
        let remainder = total % uniqueKeys.count
        return Dictionary(uniqueKeysWithValues: uniqueKeys.enumerated().map { index, key in
            (key, base + (index < remainder ? 1 : 0))
        })
    }

    private static func baseReward(for type: QuestManager.OhanaActionType) -> EconomySimulationBaseReward {
        switch type {
        case .feed:
            return EconomySimulationBaseReward(growthXP: 6, coconuts: 3, humanShare: 2, petShare: 1)
        case .water:
            return EconomySimulationBaseReward(growthXP: 5, coconuts: 3, humanShare: 2, petShare: 1)
        case let .potty(isLitter):
            return isLitter
                ? EconomySimulationBaseReward(growthXP: 7, coconuts: 3, humanShare: 2, petShare: 1)
                : EconomySimulationBaseReward(growthXP: 5, coconuts: 2, humanShare: 1, petShare: 1)
        case let .care(type):
            switch type {
            case .bath:
                return EconomySimulationBaseReward(growthXP: 14, coconuts: 8, humanShare: 6, petShare: 2)
            case .teeth, .nails, .ears:
                return EconomySimulationBaseReward(growthXP: 12, coconuts: 6, humanShare: 4, petShare: 2)
            case .brushing:
                return EconomySimulationBaseReward(growthXP: 10, coconuts: 5, humanShare: 3, petShare: 2)
            }
        case let .walk(distanceMeters):
            let xp = CoconutWalkRewardPolicy.baseGrowthXP(for: distanceMeters)
            let coconuts = CoconutWalkRewardPolicy.baseCoconuts(for: distanceMeters)
            let split = CoconutWalkRewardPolicy.splitCoconuts(total: coconuts)
            return EconomySimulationBaseReward(growthXP: xp, coconuts: coconuts, humanShare: split.human, petShare: split.pet)
        case .health:
            return EconomySimulationBaseReward(growthXP: 16, coconuts: 10, humanShare: 8, petShare: 2)
        case .expense:
            return EconomySimulationBaseReward(growthXP: 4, coconuts: 2, humanShare: 2, petShare: 0)
        case .weight:
            return EconomySimulationBaseReward(growthXP: 8, coconuts: 4, humanShare: 3, petShare: 1)
        case .milestone:
            return EconomySimulationBaseReward(growthXP: 7, coconuts: 3, humanShare: 2, petShare: 1)
        case .dailyFocusCompletion:
            return EconomySimulationBaseReward(growthXP: 18, coconuts: 8, humanShare: 8, petShare: 0)
        case let .general(humanReward, petReward, _, _):
            let total = max(0, humanReward) + max(0, petReward)
            return EconomySimulationBaseReward(
                growthXP: max(1, total),
                coconuts: total,
                humanShare: max(0, humanReward),
                petShare: max(0, petReward)
            )
        }
    }
}

private enum EconomySimulationDashboard {
    static func makeMarkdown(reports: [EconomyCohortReport]) -> String {
        var lines = [
            "",
            "=== Coconut Economy Simulation ===",
            "cohort | Lv2 | Lv3 | Lv4 | Lv5 | Lv6 | Lv7 | Lv8 | Lv9 | Lv10 | avg net/day | weekly spend | final balance | budget touch | goal days",
            "--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:"
        ]
        for report in reports {
            lines.append([
                report.preset.displayName,
                report.dayToLevelText(.lv2),
                report.dayToLevelText(.lv3),
                report.dayToLevelText(.lv4),
                report.dayToLevelText(.lv5),
                report.dayToLevelText(.lv6),
                report.dayToLevelText(.lv7),
                report.dayToLevelText(.lv8),
                report.dayToLevelText(.lv9),
                report.dayToLevelText(.lv10),
                format(report.averageDailyNetCoconuts),
                percent(report.weeklySpendRate),
                "\(report.finalBalance)",
                percent(report.budgetTouchRatio),
                percent(report.dailyGoalCoverage)
            ].joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
