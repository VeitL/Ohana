//
//  IslandUnifiedStatsViewModel.swift
//  Ohana
//
//  全岛数据聚合 ViewModel — 体重变动% + 探索里程 + 趣味排行
//

import SwiftUI
import SwiftData
import Observation

// MARK: - Data Structs

struct WeightDeltaPoint: Identifiable {
    let id = UUID()
    let date: Date
    let entityName: String
    let percentChange: Double   // 相对首条记录的变动百分比
    let isHuman: Bool
}

struct WeightAbsolutePoint: Identifiable {
    let id = UUID()
    let date: Date
    let entityName: String
    let weight: Double          // 实际体重（kg）
    let isHuman: Bool
}

struct ExplorationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let entityName: String
    let distanceKm: Double
    let isHuman: Bool
}

struct FameRanking {
    let entityName: String
    let emoji: String
    let deltaPercent: Double    // 正为增重，负为减重
    let isHuman: Bool
}

// MARK: - ViewModel

@Observable
final class IslandUnifiedStatsViewModel {

    var weightDeltas: [WeightDeltaPoint] = []
    var weightAbsolutes: [WeightAbsolutePoint] = []
    var explorations: [ExplorationPoint] = []
    var totalWeeklyExplorationKm: Double = 0
    var totalMonthlyExplorationKm: Double = 0

    // 趣味排行
    var gainChampion: FameRanking?   // 🏆 干饭王
    var lossChampion: FameRanking?   // 🏃 自律王

    // 全岛探索次数（周）= PetWalkLog 次数 + HumanWorkoutLog 步行/跑步/徒步次数
    var weeklyExplorationCount: Int = 0

    // MARK: - Load

    func load(modelContext: ModelContext, pets: [Pet], humans: [Human]) {
        loadWeightDeltas(pets: pets, humans: humans)
        loadExplorations(modelContext: modelContext, pets: pets, humans: humans)
        computeWeeklyExplorationCount(pets: pets, humans: humans)
    }

    // MARK: - Weight Gravity（变动百分比，消除量纲差异）

    private func loadWeightDeltas(pets: [Pet], humans: [Human]) {
        var points: [WeightDeltaPoint] = []

        // 宠物体重
        for pet in pets {
            let sorted = pet.weightLogs.sorted { $0.date < $1.date }
            guard let baseline = sorted.first?.weight, baseline > 0 else { continue }
            for log in sorted {
                let pct = (log.weight - baseline) / baseline * 100
                points.append(WeightDeltaPoint(
                    date: log.date,
                    entityName: pet.name,
                    percentChange: pct,
                    isHuman: false
                ))
            }
        }

        // 人类体重
        for human in humans {
            let sorted = human.weightLogs.sorted { $0.date < $1.date }
            guard let baseline = sorted.first?.weight, baseline > 0 else { continue }
            for log in sorted {
                let pct = (log.weight - baseline) / baseline * 100
                points.append(WeightDeltaPoint(
                    date: log.date,
                    entityName: human.name,
                    percentChange: pct,
                    isHuman: true
                ))
            }
        }

        weightDeltas = points.sorted { $0.date < $1.date }

        // F4: 加载实际体重绝对值
        loadWeightAbsolutes(pets: pets, humans: humans)

        // 计算排行榜（本月）
        computeRankings(pets: pets, humans: humans)
    }

    private func loadWeightAbsolutes(pets: [Pet], humans: [Human]) {
        var pts: [WeightAbsolutePoint] = []
        for pet in pets {
            for log in pet.weightLogs {
                pts.append(WeightAbsolutePoint(date: log.date, entityName: pet.name, weight: log.weight, isHuman: false))
            }
        }
        for human in humans {
            for log in human.weightLogs {
                pts.append(WeightAbsolutePoint(date: log.date, entityName: human.name, weight: log.weight, isHuman: true))
            }
        }
        weightAbsolutes = pts.sorted { $0.date < $1.date }
    }

    // 按实体名分组
    var weightAbsolutesBySeries: [(String, [WeightAbsolutePoint], Bool)] {
        let names = Array(Set(weightAbsolutes.map { $0.entityName })).sorted()
        return names.map { name in
            let pts = weightAbsolutes.filter { $0.entityName == name }
            return (name, pts, pts.first?.isHuman ?? false)
        }
    }

    private func computeRankings(pets: [Pet], humans: [Human]) {
        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now

        var entries: [FameRanking] = []

        for pet in pets {
            let sorted = pet.weightLogs.sorted { $0.date < $1.date }
            guard let baseline = sorted.first?.weight, baseline > 0 else { continue }
            let monthLogs = sorted.filter { $0.date >= startOfMonth }
            guard let latest = monthLogs.last else { continue }
            let pct = (latest.weight - baseline) / baseline * 100
            entries.append(FameRanking(entityName: pet.name, emoji: pet.avatarEmoji, deltaPercent: pct, isHuman: false))
        }

        for human in humans {
            let sorted = human.weightLogs.sorted { $0.date < $1.date }
            guard let baseline = sorted.first?.weight, baseline > 0 else { continue }
            let monthLogs = sorted.filter { $0.date >= startOfMonth }
            guard let latest = monthLogs.last else { continue }
            let pct = (latest.weight - baseline) / baseline * 100
            entries.append(FameRanking(entityName: human.name, emoji: human.avatarEmoji, deltaPercent: pct, isHuman: true))
        }

        // 任务9：排重逻辑——干饭王必须 delta>0，自律王必须 delta<0，且两者不能是同一实体
        let gainers = entries.filter { $0.deltaPercent > 0 }
        let losers  = entries.filter { $0.deltaPercent < 0 }
        gainChampion = gainers.max(by: { $0.deltaPercent < $1.deltaPercent })
        // 自律王排除已被选为干饭王的实体（虽然概率极低，但理论上可能）
        let gainName = gainChampion?.entityName
        lossChampion = losers
            .filter { $0.entityName != gainName }
            .min(by: { $0.deltaPercent < $1.deltaPercent })
    }

    // MARK: - Exploration（近 7 天里程聚合）

    private func loadExplorations(modelContext: ModelContext, pets: [Pet], humans: [Human]) {
        let cal = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) else { return }
        guard let thirtyDaysAgo = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) else { return }

        var points: [ExplorationPoint] = []

        // 宠物遛狗
        for pet in pets {
            let recentWalks = pet.walkLogs.filter { $0.startDate >= sevenDaysAgo }
            for log in recentWalks {
                points.append(ExplorationPoint(
                    date: cal.startOfDay(for: log.startDate),
                    entityName: pet.name,
                    distanceKm: log.distanceMeters / 1000,
                    isHuman: false
                ))
            }
        }

        // 人类步行/跑步/徒步
        let walkingTypes = [WorkoutType.walking.rawValue, WorkoutType.running.rawValue, WorkoutType.hiking.rawValue]
        for human in humans {
            let recentWorkouts = human.workoutLogs.filter {
                $0.date >= sevenDaysAgo && walkingTypes.contains($0.typeRaw)
            }
            for log in recentWorkouts {
                points.append(ExplorationPoint(
                    date: cal.startOfDay(for: log.date),
                    entityName: human.name,
                    distanceKm: log.distanceKm,
                    isHuman: true
                ))
            }
        }

        explorations = points.sorted { $0.date < $1.date }

        // 计算周/月总里程
        totalWeeklyExplorationKm = points.reduce(0) { $0 + $1.distanceKm }

        // 月里程：包含 30 天
        var monthPoints: [ExplorationPoint] = []
        for pet in pets {
            let logs = pet.walkLogs.filter { $0.startDate >= thirtyDaysAgo }
            monthPoints += logs.map {
                ExplorationPoint(date: $0.startDate, entityName: pet.name, distanceKm: $0.distanceMeters / 1000, isHuman: false)
            }
        }
        for human in humans {
            let logs = human.workoutLogs.filter { $0.date >= thirtyDaysAgo && walkingTypes.contains($0.typeRaw) }
            monthPoints += logs.map {
                ExplorationPoint(date: $0.date, entityName: human.name, distanceKm: $0.distanceKm, isHuman: true)
            }
        }
        totalMonthlyExplorationKm = monthPoints.reduce(0) { $0 + $1.distanceKm }
    }

    // MARK: - 全岛探索次数（本周，用于 IslandStatCard 大数字）

    private func computeWeeklyExplorationCount(pets: [Pet], humans: [Human]) {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return }

        var count = 0
        for pet in pets {
            count += pet.walkLogs.filter { $0.startDate >= weekStart }.count
        }
        let walkingTypes = [WorkoutType.walking.rawValue, WorkoutType.running.rawValue, WorkoutType.hiking.rawValue]
        for human in humans {
            count += human.workoutLogs.filter { $0.date >= weekStart && walkingTypes.contains($0.typeRaw) }.count
        }
        weeklyExplorationCount = count
    }

    // MARK: - Chart Helpers

    // 按实体名分组，返回 [(name, [points], isHuman)]
    var weightDeltasBySeries: [(String, [WeightDeltaPoint], Bool)] {
        let names = Array(Set(weightDeltas.map { $0.entityName })).sorted()
        return names.map { name in
            let pts = weightDeltas.filter { $0.entityName == name }
            let isHuman = pts.first?.isHuman ?? false
            return (name, pts, isHuman)
        }
    }

    // 近 7 天日期轴
    var last7Days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: today) }
    }

    // 每天每实体的探索 km（用于堆叠图）
    var explorationByDayAndEntity: [(Date, String, Double)] {
        var result: [(Date, String, Double)] = []
        for day in last7Days {
            let dayPoints = explorations.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            let byEntity = Dictionary(grouping: dayPoints) { $0.entityName }
            for (name, pts) in byEntity {
                result.append((day, name, pts.reduce(0) { $0 + $1.distanceKm }))
            }
            // 若当天无数据，添加零值保持连续性
            if dayPoints.isEmpty {
                result.append((day, "—", 0))
            }
        }
        return result
    }
}
