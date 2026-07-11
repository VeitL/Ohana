//
//  IslandWealthViewModel2.swift
//  Ohana
//

import SwiftData
import SwiftUI

// MARK: - Time Range
enum WealthTimeRange: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"
    case all = "全部"
    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .day:
            l.tr(zh: "日", en: "Day", de: "Tag")
        case .week:
            l.tr(zh: "周", en: "Week", de: "Woche")
        case .month:
            l.tr(zh: "月", en: "Month", de: "Monat")
        case .all:
            l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }
}

// MARK: - Chart Bar（用于历史趋势：按时间桶聚合 log）
struct WealthBarData: Identifiable {
    let id = UUID()
    let bucket: Date
    let entityName: String
    let entityId: String
    let amount: Int
}

struct WealthBalancePoint: Identifiable {
    let id = UUID()
    let bucket: Date
    let balance: Int
}

struct WealthTrendPoint: Identifiable {
    let id = UUID()
    let bucket: Date
    let amount: Int
}

enum WealthActorKind {
    case pet
    case human
}

struct WealthActorSnapshot: Identifiable, Equatable {
    let id: String
    let emoji: String
    let name: String
    let balance: Int
    let kind: WealthActorKind
}

struct WealthAccountSnapshot: Equatable {
    let ownerKind: CoconutWalletOwnerKind
    let ownerId: String
    let balance: Int
}

struct IslandWealthSnapshot {
    let pets: [WealthActorSnapshot]
    let visibleHumans: [WealthActorSnapshot]
    let allHumanBalances: [String: Int]
    let hiddenHumanIds: Set<String>
    let formalAccounts: [WealthAccountSnapshot]
    let visibleLogs: [CoconutLogEntry]

    static let empty = IslandWealthSnapshot(
        pets: [],
        visibleHumans: [],
        allHumanBalances: [:],
        hiddenHumanIds: [],
        formalAccounts: [],
        visibleLogs: []
    )

    @MainActor
    static func make(
        pets: [Pet],
        allHumans: [Human],
        visibleHumans: [Human],
        hiddenHumanIds: Set<String>,
        walletAccounts: [CoconutAccount],
        walletLedgerEntries: [CoconutLedgerEntry]
    ) -> IslandWealthSnapshot {
        let activePets = pets.filter(EconomyWalletWritePolicy.canWrite)
        let activeAllHumans = allHumans.filter(EconomyWalletWritePolicy.canWrite)
        let activeVisibleHumans = visibleHumans.filter(EconomyWalletWritePolicy.canWrite)
        let frozenOwnerIds = Set(
            pets.filter { !EconomyWalletWritePolicy.canWrite($0) }.map(\.id.uuidString) +
                allHumans.filter { !EconomyWalletWritePolicy.canWrite($0) }.map(\.id.uuidString)
        )
        let petSnapshots = activePets.map { pet in
            WealthActorSnapshot(
                id: pet.id.uuidString,
                emoji: pet.avatarEmoji,
                name: pet.name,
                balance: pet.coconutBalance,
                kind: .pet
            )
        }
        let visibleHumanSnapshots = activeVisibleHumans.map { human in
            WealthActorSnapshot(
                id: human.id.uuidString,
                emoji: human.avatarEmoji,
                name: human.name,
                balance: human.coconutBalance,
                kind: .human
            )
        }
        let allHumanBalances = Dictionary(uniqueKeysWithValues: activeAllHumans.map { ($0.id.uuidString, $0.coconutBalance) })
        let formalAccounts = walletAccounts.compactMap { account -> WealthAccountSnapshot? in
            guard account.ownerKind != .system || account.accountKey == CoconutAccountKey.islandReserve else { return nil }
            guard !frozenOwnerIds.contains(account.ownerId) else { return nil }
            return WealthAccountSnapshot(
                ownerKind: account.ownerKind,
                ownerId: account.ownerId,
                balance: account.balance
            )
        }
        let formalOwnerIds = Set(formalAccounts.map(\.ownerId))
        let visibleLogs = walletLedgerEntries
            .filter {
                $0.delta != 0 &&
                    ($0.ownerKind != .system || $0.accountKey == CoconutAccountKey.islandReserve)
            }
            .filter { formalOwnerIds.contains($0.ownerId) }
            .map { $0.asCoconutLogEntry() }
            .filter { !hiddenHumanIds.contains($0.actorId ?? "") }
            .filter { !frozenOwnerIds.contains($0.actorId ?? "") }
        return IslandWealthSnapshot(
            pets: petSnapshots,
            visibleHumans: visibleHumanSnapshots,
            allHumanBalances: allHumanBalances,
            hiddenHumanIds: hiddenHumanIds,
            formalAccounts: formalAccounts,
            visibleLogs: visibleLogs
        )
    }
}

// MARK: - Leaderboard Row（直接用实体余额）
struct WealthLeaderRow: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let entityId: String
    let amount: Int // 直接读 coconutBalance
    let periodIncome: Int
    let periodSpending: Int
    let periodNet: Int
    let percentage: Double
}

// MARK: - Screen Model
@Observable
final class IslandWealthScreenModel {
    var timeRange: WealthTimeRange = .week
    var showSystemCoconuts: Bool = false
    var selectedActorId: String?

    private var snapshot: IslandWealthSnapshot = .empty
    // 宠物 id → 主题色（由 View 注入）
    var petColorMap: [String: Color] = [:]

    @MainActor
    func applyQuerySnapshot(
        pets: [Pet],
        allHumans: [Human]? = nil,
        visibleHumans: [Human],
        hiddenHumanIds: Set<String>,
        walletAccounts: [CoconutAccount],
        walletLedgerEntries: [CoconutLedgerEntry],
        petColorMap: [String: Color],
        selectedActorId: String?
    ) {
        snapshot = IslandWealthSnapshot.make(
            pets: pets,
            allHumans: allHumans ?? visibleHumans,
            visibleHumans: visibleHumans,
            hiddenHumanIds: hiddenHumanIds,
            walletAccounts: walletAccounts,
            walletLedgerEntries: walletLedgerEntries
        )
        self.petColorMap = petColorMap
        self.selectedActorId = selectedActorId
    }

    // 正式岛屿总资产包含岛屿储备与所有正式成员钱包；隐私只隐藏明细，不改变总数。
    var totalAssets: Int {
        if !snapshot.formalAccounts.isEmpty {
            return snapshot.formalAccounts.reduce(0) { $0 + $1.balance }
        }
        return snapshot.pets.reduce(0) { $0 + $1.balance } +
            snapshot.allHumanBalances.values.reduce(0, +)
    }

    var displayedAssets: Int {
        guard let selectedActorId else { return totalAssets }
        if let balance = walletBalance(ownerId: selectedActorId) {
            return balance
        }
        if let pet = snapshot.pets.first(where: { $0.id == selectedActorId }) {
            return pet.balance
        }
        if let human = snapshot.visibleHumans.first(where: { $0.id == selectedActorId }) {
            return human.balance
        }
        return 0
    }

    // MARK: - 排行榜（直接读个人余额，不从 log 聚合）
    var leaderboard: [WealthLeaderRow] {
        var all: [WealthLeaderRow] = []
        let total = max(1, totalAssets)
        all += snapshot.pets.map { pet in
            let stats = periodStats(for: pet.id)
            let balance = walletBalance(ownerId: pet.id) ?? pet.balance
            return WealthLeaderRow(emoji: pet.emoji, name: pet.name,
                                   entityId: pet.id, amount: balance,
                                   periodIncome: stats.income, periodSpending: stats.spending, periodNet: stats.net,
                                   percentage: Double(balance) / Double(total))
        }
        all += snapshot.visibleHumans.map { h in
            let stats = periodStats(for: h.id)
            let balance = walletBalance(ownerId: h.id) ?? h.balance
            return WealthLeaderRow(emoji: h.emoji, name: h.name,
                                   entityId: h.id, amount: balance,
                                   periodIncome: stats.income, periodSpending: stats.spending, periodNet: stats.net,
                                   percentage: Double(balance) / Double(total))
        }
        return all
            .filter { $0.amount > 0 || $0.periodIncome > 0 || $0.periodSpending > 0 }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - 图表数据（按时间桶聚合 log，仅用于趋势图）
    private var visibleLogs: [CoconutLogEntry] {
        snapshot.visibleLogs
    }

    private var logs: [CoconutLogEntry] {
        guard let selectedActorId else { return visibleLogs }
        return visibleLogs.filter { $0.actorId == selectedActorId }
    }

    // 按时间范围过滤（不区分正负）
    private var filteredByTimeRange: [CoconutLogEntry] {
        timeFiltered(logs)
    }

    private var visibleFilteredByTimeRange: [CoconutLogEntry] {
        timeFiltered(visibleLogs)
    }

    private func timeFiltered(_ entries: [CoconutLogEntry]) -> [CoconutLogEntry] {
        let cal = Calendar.current
        let now = Date()
        switch timeRange {
        case .day:
            let start = cal.startOfDay(for: now)
            return entries.filter { $0.date >= start }
        case .week:
            guard let start = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return entries }
            return entries.filter { $0.date >= start }
        case .month:
            guard let start = cal.dateInterval(of: .month, for: now)?.start else { return entries }
            return entries.filter { $0.date >= start }
        case .all:
            return entries
        }
    }

    // 收入（正数）
    private var filteredIncome: [CoconutLogEntry] {
        filteredByTimeRange.filter { $0.amount > 0 }
    }

    // 花费（负数）
    private var filteredSpending: [CoconutLogEntry] {
        filteredByTimeRange.filter { $0.amount < 0 }
    }

    // MARK: - 收支汇总
    var periodIncome: Int { filteredIncome.reduce(0) { $0 + $1.amount } }
    var periodSpending: Int { filteredSpending.reduce(0) { $0 + abs($1.amount) } }
    var periodNet: Int { periodIncome - periodSpending }

    private func periodStats(for actorId: String) -> (income: Int, spending: Int, net: Int) {
        let entries = visibleFilteredByTimeRange.filter { $0.actorId == actorId }
        let income = entries.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let spending = entries.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        return (income, spending, income - spending)
    }

    private var visibleWalletAccounts: [WealthAccountSnapshot] {
        snapshot.formalAccounts.filter { account in
            !(account.ownerKind == .human && snapshot.hiddenHumanIds.contains(account.ownerId))
        }
    }

    private func walletBalance(ownerId: String) -> Int? {
        visibleWalletAccounts.first { account in
            account.ownerId == ownerId
        }?.balance
    }

    // 时间段内活跃实体名集合（用于图例）
    var activeEntityNames: [String] {
        let names = Set(filteredIncome.compactMap(\.actorName))
        return Array(names).sorted()
    }

    // 共享桶化组件
    private var bucketComponent: Calendar.Component {
        switch timeRange {
        case .day: .hour
        case .week: .day
        case .month: .day
        case .all: .month
        }
    }

    private var rangeStartDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch timeRange {
        case .day:
            return cal.startOfDay(for: now)
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        case .month:
            return cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
        case .all:
            if let earliest = logs.map(\.date).min() {
                return cal.dateInterval(of: bucketComponent, for: earliest)?.start ?? earliest
            }
            return cal.date(byAdding: .day, value: -1, to: now) ?? now
        }
    }

    private var chartBuckets: [Date] {
        let cal = Calendar.current
        let component = bucketComponent
        let start = cal.dateInterval(of: component, for: rangeStartDate)?.start ?? rangeStartDate
        let end = cal.dateInterval(of: component, for: Date())?.start ?? Date()
        var buckets: [Date] = []
        var cursor = start
        while cursor <= end {
            buckets.append(cursor)
            guard let next = cal.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return buckets.isEmpty ? [start] : buckets
    }

    var wealthTrendPoints: [WealthBalancePoint] {
        let cal = Calendar.current
        let component = bucketComponent
        var bucketDeltas: [Date: Int] = [:]
        for log in filteredByTimeRange {
            let bucket = cal.dateInterval(of: component, for: log.date)?.start ?? log.date
            bucketDeltas[bucket, default: 0] += log.amount
        }

        let sortedBuckets = bucketDeltas.keys.sorted()
        let periodNetChange = sortedBuckets.reduce(0) { $0 + (bucketDeltas[$1] ?? 0) }
        let startBucket = cal.dateInterval(of: component, for: rangeStartDate)?.start ?? rangeStartDate
        var runningBalance = max(0, displayedAssets - periodNetChange)
        var points = [WealthBalancePoint(bucket: startBucket, balance: runningBalance)]

        for bucket in sortedBuckets {
            runningBalance += bucketDeltas[bucket] ?? 0
            points.append(WealthBalancePoint(bucket: bucket, balance: max(0, runningBalance)))
        }

        let now = Date()
        if let last = points.last {
            let isCurrentBucket = cal.isDate(last.bucket, equalTo: now, toGranularity: component)
            if !isCurrentBucket || points.count == 1 {
                points.append(WealthBalancePoint(bucket: now, balance: displayedAssets))
            }
        }
        return points
    }

    var incomeTrendPoints: [WealthTrendPoint] {
        trendPoints(from: filteredIncome) { $0.amount }
    }

    var spendingTrendPoints: [WealthTrendPoint] {
        trendPoints(from: filteredSpending) { abs($0.amount) }
    }

    private func trendPoints(
        from entries: [CoconutLogEntry],
        value: (CoconutLogEntry) -> Int
    ) -> [WealthTrendPoint] {
        let cal = Calendar.current
        let component = bucketComponent
        var bucketTotals: [Date: Int] = [:]
        for entry in entries {
            let bucket = cal.dateInterval(of: component, for: entry.date)?.start ?? entry.date
            bucketTotals[bucket, default: 0] += value(entry)
        }
        return chartBuckets.map { bucket in
            WealthTrendPoint(bucket: bucket, amount: bucketTotals[bucket] ?? 0)
        }
    }

    var chartBars: [WealthBarData] {
        let cal = Calendar.current
        let component = bucketComponent
        var dict: [String: (bucket: Date, entity: String, eid: String, sum: Int)] = [:]
        for log in filteredIncome {
            let bucket = cal.dateInterval(of: component, for: log.date)?.start ?? log.date
            let rawId = log.actorId ?? ""
            let eid: String
            let name: String
            if let actor = actor(id: rawId) {
                eid = actor.id
                name = actor.name
            } else {
                eid = "system"
                name = "其他/系统"
            }
            // 过滤系统椰子（当 toggle 关闭时）
            if !showSystemCoconuts, eid == "system" { continue }
            let key = "\(bucket.timeIntervalSince1970)_\(eid)"
            if let existing = dict[key] {
                dict[key] = (bucket, name, eid, existing.sum + log.amount)
            } else {
                dict[key] = (bucket, name, eid, log.amount)
            }
        }
        return dict.values
            .sorted { $0.bucket < $1.bucket }
            .map { WealthBarData(bucket: $0.bucket, entityName: $0.entity, entityId: $0.eid, amount: $0.sum) }
    }

    // 所有图表中出现的实体名（用于 chartForegroundStyleScale domain）
    var chartEntityNames: [String] {
        Array(Set(chartBars.map(\.entityName))).sorted()
    }

    // 对应的颜色数组（与 chartEntityNames 严格一一对应）
    var chartEntityColors: [Color] {
        chartEntityNames.map { name -> Color in
            if let entityId = chartBars.first(where: { $0.entityName == name })?.entityId {
                return color(for: entityId)
            }
            return Color.ohanaSecondaryText.opacity(0.7)
        }
    }

    // 花费柱状图数据（按时间桶聚合，单一"花费"系列，amount 取绝对值）
    var spendingBars: [WealthBarData] {
        let cal = Calendar.current
        let component = bucketComponent
        var dict: [Date: Int] = [:]
        for log in filteredSpending {
            let bucket = cal.dateInterval(of: component, for: log.date)?.start ?? log.date
            dict[bucket, default: 0] += abs(log.amount)
        }
        return dict.map { WealthBarData(bucket: $0.key, entityName: "花费", entityId: "spending", amount: $0.value) }
            .sorted { $0.bucket < $1.bucket }
    }

    // 时间段内收入总额（图表标题用）
    var periodLogTotal: Int { periodIncome }

    // MARK: - 色板
    static let palette: [Color] = [
        Color(hex: "C8FF00"), Color(hex: "FFF44F"), Color(hex: "00D4AA"),
        Color(hex: "FF8C42"), Color(hex: "FF4757"), Color(hex: "80FFEA")
    ]
    func color(for entityId: String) -> Color {
        if entityId == "system" { return Color.ohanaSecondaryText.opacity(0.7) }
        if let petColor = petColorMap[entityId] { return petColor }
        // human：从调色板取稳定色
        let idx = abs(entityId.hashValue) % Self.palette.count
        return Self.palette[idx]
    }

    private func actor(id: String) -> WealthActorSnapshot? {
        snapshot.pets.first { $0.id == id } ?? snapshot.visibleHumans.first { $0.id == id }
    }
}

typealias IslandWealthViewModel = IslandWealthScreenModel
