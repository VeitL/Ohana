//
//  IslandUnifiedStatsViewModel.swift
//  Ohana
//
//  全岛数据聚合 ViewModel — 体重变动% + 探索里程 + 趣味排行
//

import Observation
import SwiftData
import SwiftUI

// MARK: - Data Structs

struct WeightDeltaPoint: Identifiable {
    let id = UUID()
    let date: Date
    let entityName: String
    let percentChange: Double // 相对首条记录的变动百分比
    let isHuman: Bool
}

nonisolated struct WeightAbsolutePoint: Identifiable, Equatable, Sendable {
    /// 对应 `PetWeightLog.id` / `HumanWeightLog.id`，图表 ForEach 稳定标识
    let id: UUID
    let date: Date
    /// 分组键：`pet:<Pet.id>` / `human:<Human.id>`，避免同名成员折线被合并
    let seriesID: String
    let displayName: String
    let weight: Double // 实际体重（ kg；宠物已统一换算）
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
    let deltaPercent: Double // 正为增重，负为减重
    let isHuman: Bool
}

private struct PetLedgerMetricEntry {
    let id: UUID
    let petID: UUID
    let date: Date
    let value: Double
}

private struct HumanWeightMetricEntry {
    let id: UUID
    let humanID: UUID
    let date: Date
    let value: Double
}

// MARK: - ViewModel

@Observable
final class IslandUnifiedStatsViewModel {

    var weightDeltas: [WeightDeltaPoint] = []
    var weightAbsolutes: [WeightAbsolutePoint] = []
    var explorations: [ExplorationPoint] = []
    var totalWeeklyExplorationKm: Double = 0
    var totalMonthlyExplorationKm: Double = 0
    private(set) var isWeightDataTruncated = false

    // 趣味排行
    var gainChampion: FameRanking? // 🏆 干饭王
    var lossChampion: FameRanking? // 🏃 自律王

    // 全岛探索次数（周）= PetWalkLog 次数 + HumanWorkoutLog 步行/跑步/徒步次数
    var weeklyExplorationCount: Int = 0

    // MARK: - Load

    func load(modelContext: ModelContext, pets: [Pet], humans: [Human]) {
        let petWeightFetch = Self.fetchPetLedgerMetricEntries(
            modelContext: modelContext,
            pets: pets,
            eventKind: .weight,
            valueTransform: { $0.amountValue }
        )
        let humanWeightFetch = Self.fetchHumanWeightEntries(
            modelContext: modelContext,
            humans: humans
        )
        isWeightDataTruncated = petWeightFetch.isTruncated || humanWeightFetch.isTruncated
        loadWeightDeltas(
            pets: pets,
            humans: humans,
            petWeightEntriesByPetId: petWeightFetch.entries,
            humanWeightEntriesByHumanId: humanWeightFetch.entries
        )
    }

    func applyWeightInsightSnapshot(
        _ snapshot: WeightInsightSnapshot,
        pets: [Pet],
        humans: [Human]
    ) {
        weightAbsolutes = snapshot.points.sorted { $0.date < $1.date }
        isWeightDataTruncated = snapshot.isTruncated

        let petBySeries = Dictionary(uniqueKeysWithValues: pets.map {
            ("pet:\($0.id.uuidString)", (name: $0.name, emoji: $0.avatarEmoji, isHuman: false))
        })
        let humanBySeries = Dictionary(uniqueKeysWithValues: humans.map {
            ("human:\($0.id.uuidString)", (name: $0.name, emoji: $0.avatarEmoji, isHuman: true))
        })
        let subjectBySeries = petBySeries.merging(humanBySeries) { current, _ in current }

        var deltas: [WeightDeltaPoint] = []
        var rankings: [FameRanking] = []
        for (seriesID, points) in Dictionary(grouping: weightAbsolutes, by: \.seriesID) {
            let sorted = points.sorted { $0.date < $1.date }
            guard let first = sorted.first, first.weight > 0,
                  let subject = subjectBySeries[seriesID] else { continue }
            for point in sorted {
                deltas.append(WeightDeltaPoint(
                    date: point.date,
                    entityName: subject.name,
                    percentChange: (point.weight - first.weight) / first.weight * 100,
                    isHuman: subject.isHuman
                ))
            }
            guard let last = sorted.last, last.id != first.id else { continue }
            rankings.append(FameRanking(
                entityName: subject.name,
                emoji: subject.emoji,
                deltaPercent: (last.weight - first.weight) / first.weight * 100,
                isHuman: subject.isHuman
            ))
        }
        weightDeltas = deltas.sorted { $0.date < $1.date }
        gainChampion = rankings.filter { $0.deltaPercent > 0 }
            .max(by: { $0.deltaPercent < $1.deltaPercent })
        let gainName = gainChampion?.entityName
        lossChampion = rankings
            .filter { $0.deltaPercent < 0 && $0.entityName != gainName }
            .min(by: { $0.deltaPercent < $1.deltaPercent })
    }

    // MARK: - Weight Gravity（变动百分比，消除量纲差异）

    private func loadWeightDeltas(
        pets: [Pet],
        humans: [Human],
        petWeightEntriesByPetId: [UUID: [PetLedgerMetricEntry]],
        humanWeightEntriesByHumanId: [UUID: [HumanWeightMetricEntry]]
    ) {
        var points: [WeightDeltaPoint] = []

        // 宠物体重
        for pet in pets {
            let sorted = petWeightEntriesByPetId[pet.id] ?? []
            guard let baseline = sorted.first?.value, baseline > 0 else { continue }
            for log in sorted {
                let pct = (log.value - baseline) / baseline * 100
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
            let sorted = humanWeightEntriesByHumanId[human.id] ?? []
            guard let baseline = sorted.first?.value, baseline > 0 else { continue }
            for log in sorted {
                let pct = (log.value - baseline) / baseline * 100
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
        loadWeightAbsolutes(
            pets: pets,
            humans: humans,
            petWeightEntriesByPetId: petWeightEntriesByPetId,
            humanWeightEntriesByHumanId: humanWeightEntriesByHumanId
        )

        // 计算排行榜（本月）
        computeRankings(
            pets: pets,
            humans: humans,
            petWeightEntriesByPetId: petWeightEntriesByPetId,
            humanWeightEntriesByHumanId: humanWeightEntriesByHumanId
        )
    }

    private func loadWeightAbsolutes(
        pets: [Pet],
        humans: [Human],
        petWeightEntriesByPetId: [UUID: [PetLedgerMetricEntry]],
        humanWeightEntriesByHumanId: [UUID: [HumanWeightMetricEntry]]
    ) {
        var pts: [WeightAbsolutePoint] = []
        for pet in pets {
            let sid = "pet:\(pet.id.uuidString)"
            for log in petWeightEntriesByPetId[pet.id] ?? [] {
                pts.append(WeightAbsolutePoint(
                    id: log.id,
                    date: log.date,
                    seriesID: sid,
                    displayName: pet.name,
                    weight: log.value,
                    isHuman: false
                ))
            }
        }
        for human in humans {
            let sid = "human:\(human.id.uuidString)"
            for log in humanWeightEntriesByHumanId[human.id] ?? [] {
                pts.append(WeightAbsolutePoint(
                    id: log.id,
                    date: log.date,
                    seriesID: sid,
                    displayName: human.name,
                    weight: log.value,
                    isHuman: true
                ))
            }
        }
        weightAbsolutes = pts.sorted { $0.date < $1.date }
    }

    /// 按 `seriesID` 分组（同名宠物/人各一条曲线）
    var weightAbsolutesBySeries: [(seriesID: String, displayName: String, points: [WeightAbsolutePoint], isHuman: Bool)] {
        let ids = Array(Set(weightAbsolutes.map(\.seriesID))).sorted()
        return ids.map { sid in
            let pts = weightAbsolutes.filter { $0.seriesID == sid }.sorted { $0.date < $1.date }
            return (sid, pts.first?.displayName ?? "", pts, pts.first?.isHuman ?? false)
        }
    }

    private func computeRankings(
        pets: [Pet],
        humans: [Human],
        petWeightEntriesByPetId: [UUID: [PetLedgerMetricEntry]],
        humanWeightEntriesByHumanId: [UUID: [HumanWeightMetricEntry]]
    ) {
        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now

        var entries: [FameRanking] = []

        for pet in pets {
            let sorted = petWeightEntriesByPetId[pet.id] ?? []
            guard let baseline = sorted.first?.value, baseline > 0 else { continue }
            let monthLogs = sorted.filter { $0.date >= startOfMonth }
            guard let latest = monthLogs.last else { continue }
            let pct = (latest.value - baseline) / baseline * 100
            entries.append(FameRanking(entityName: pet.name, emoji: pet.avatarEmoji, deltaPercent: pct, isHuman: false))
        }

        for human in humans {
            let sorted = humanWeightEntriesByHumanId[human.id] ?? []
            guard let baseline = sorted.first?.value, baseline > 0 else { continue }
            let monthLogs = sorted.filter { $0.date >= startOfMonth }
            guard let latest = monthLogs.last else { continue }
            let pct = (latest.value - baseline) / baseline * 100
            entries.append(FameRanking(entityName: human.name, emoji: human.avatarEmoji, deltaPercent: pct, isHuman: true))
        }

        // 任务9：排重逻辑——干饭王必须 delta>0，自律王必须 delta<0，且两者不能是同一实体
        let gainers = entries.filter { $0.deltaPercent > 0 }
        let losers = entries.filter { $0.deltaPercent < 0 }
        gainChampion = gainers.max(by: { $0.deltaPercent < $1.deltaPercent })
        // 自律王排除已被选为干饭王的实体（虽然概率极低，但理论上可能）
        let gainName = gainChampion?.entityName
        lossChampion = losers
            .filter { $0.entityName != gainName }
            .min(by: { $0.deltaPercent < $1.deltaPercent })
    }

    // MARK: - Exploration（近 7 天里程聚合）

    private func loadExplorations(
        petWalkEntriesByPetId: [UUID: [PetLedgerMetricEntry]],
        pets: [Pet],
        humans: [Human]
    ) {
        let cal = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) else { return }
        guard let thirtyDaysAgo = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) else { return }

        var points: [ExplorationPoint] = []

        // 宠物遛狗
        for pet in pets {
            let recentWalks = (petWalkEntriesByPetId[pet.id] ?? []).filter { $0.date >= sevenDaysAgo }
            for log in recentWalks {
                points.append(ExplorationPoint(
                    date: cal.startOfDay(for: log.date),
                    entityName: pet.name,
                    distanceKm: log.value / 1000,
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
            let logs = (petWalkEntriesByPetId[pet.id] ?? []).filter { $0.date >= thirtyDaysAgo }
            monthPoints += logs.map {
                ExplorationPoint(date: $0.date, entityName: pet.name, distanceKm: $0.value / 1000, isHuman: false)
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

    private func computeWeeklyExplorationCount(petWalkEntriesByPetId: [UUID: [PetLedgerMetricEntry]], humans: [Human]) {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return }

        var count = 0
        for logs in petWalkEntriesByPetId.values {
            count += logs.count(where: { $0.date >= weekStart })
        }
        let walkingTypes = [WorkoutType.walking.rawValue, WorkoutType.running.rawValue, WorkoutType.hiking.rawValue]
        for human in humans {
            count += human.workoutLogs.count(where: { $0.date >= weekStart && walkingTypes.contains($0.typeRaw) })
        }
        weeklyExplorationCount = count
    }

    private static func fetchPetLedgerMetricEntries(
        modelContext: ModelContext,
        pets: [Pet],
        eventKind: CareLedgerEventKind,
        valueTransform: (CareLedgerEvent) -> Double
    ) -> (entries: [UUID: [PetLedgerMetricEntry]], isTruncated: Bool) {
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        let eventKindRaw = eventKind.rawValue
        let petIDs = Set(pets.map(\.id.uuidString))
        guard !petIDs.isEmpty else { return ([:], false) }
        let maximumResultCount = 20000
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubjectKind &&
                    event.eventKind == eventKindRaw
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = maximumResultCount + 1
        do {
            let fetched = try modelContext.fetch(descriptor)
            let isTruncated = fetched.count > maximumResultCount
            let entries = fetched.prefix(maximumResultCount).compactMap { event -> PetLedgerMetricEntry? in
                guard let subjectId = event.subjectId,
                      petIDs.contains(subjectId),
                      let petID = UUID(uuidString: subjectId) else { return nil }
                let value = valueTransform(event)
                guard value > 0 else { return nil }
                return PetLedgerMetricEntry(
                    id: event.id,
                    petID: petID,
                    date: event.occurredAt,
                    value: value
                )
            }
            let grouped = Dictionary(grouping: entries, by: \.petID)
                .mapValues { $0.sorted { $0.date < $1.date } }
            return (grouped, isTruncated)
        } catch {
            OhanaLog.warning(
                "Island unified stats failed to fetch pet \(eventKind.rawValue) ledger events: \(error.localizedDescription)",
                category: "DashboardRecords"
            )
            return ([:], false)
        }
    }

    private static func fetchHumanWeightEntries(
        modelContext: ModelContext,
        humans: [Human]
    ) -> (entries: [UUID: [HumanWeightMetricEntry]], isTruncated: Bool) {
        let humanIDs = Set(humans.map(\.id))
        guard !humanIDs.isEmpty else { return ([:], false) }
        let maximumResultCount = 20000
        var descriptor = FetchDescriptor<HumanWeightLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = maximumResultCount + 1
        do {
            let fetched = try modelContext.fetch(descriptor)
            let isTruncated = fetched.count > maximumResultCount
            let entries = fetched.prefix(maximumResultCount).compactMap { log -> HumanWeightMetricEntry? in
                guard let humanID = log.human?.id,
                      humanIDs.contains(humanID),
                      log.weight > 0 else { return nil }
                return HumanWeightMetricEntry(
                    id: log.id,
                    humanID: humanID,
                    date: log.date,
                    value: log.weight
                )
            }
            let grouped = Dictionary(grouping: entries, by: \.humanID)
                .mapValues { $0.sorted { $0.date < $1.date } }
            return (grouped, isTruncated)
        } catch {
            OhanaLog.warning(
                "Island unified stats failed to fetch human weight records: \(error.localizedDescription)",
                category: "DashboardRecords"
            )
            return ([:], false)
        }
    }

    // MARK: - Chart Helpers

    // 按实体名分组，返回 [(name, [points], isHuman)]
    var weightDeltasBySeries: [(String, [WeightDeltaPoint], Bool)] {
        let names = Array(Set(weightDeltas.map(\.entityName))).sorted()
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
        return (0 ..< 7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: today) }
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
