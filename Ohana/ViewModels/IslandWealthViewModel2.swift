//
//  IslandWealthViewModel2.swift
//  Ohana
//

import SwiftUI
import SwiftData

// MARK: - Time Range
enum WealthTimeRange: String, CaseIterable, Identifiable {
    case day   = "日"
    case week  = "周"
    case month = "月"
    case all   = "全部"
    var id: String { rawValue }
}

// MARK: - Chart Bar（用于历史趋势：按时间桶聚合 log）
struct WealthBarData: Identifiable {
    let id = UUID()
    let bucket: Date
    let entityName: String
    let entityId: String
    let amount: Int
}

// MARK: - Leaderboard Row（直接用实体余额）
struct WealthLeaderRow: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let entityId: String
    let amount: Int        // 直接读 coconutBalance
    let percentage: Double
}

// MARK: - ViewModel
@Observable
final class IslandWealthViewModel {
    var timeRange: WealthTimeRange = .week

    // 注入实体列表（由 View 从 @Query 传入）
    var pets: [Pet] = []
    var humans: [Human] = []
    // 宠物 id → 主题色（由 View 注入）
    var petColorMap: [String: Color] = [:]

    // 全岛总资产 = QuestManager 全局计数（唯一真相来源）
    var totalAssets: Int { QuestManager.shared.coconutCount }

    // MARK: - 排行榜（直接读个人余额，不从 log 聚合）
    var leaderboard: [WealthLeaderRow] {
        var all: [WealthLeaderRow] = []
        let total = max(1, totalAssets)
        all += pets.map { pet in
            WealthLeaderRow(emoji: pet.avatarEmoji, name: pet.name,
                            entityId: pet.id.uuidString, amount: pet.coconutBalance,
                            percentage: Double(pet.coconutBalance) / Double(total))
        }
        all += humans.map { h in
            WealthLeaderRow(emoji: h.avatarEmoji, name: h.name,
                            entityId: h.id.uuidString, amount: h.coconutBalance,
                            percentage: Double(h.coconutBalance) / Double(total))
        }
        return all.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }
    }

    // MARK: - 图表数据（按时间桶聚合 log，仅用于趋势图）
    private var logs: [CoconutLogEntry] { QuestManager.shared.coconutLogs }

    private var filtered: [CoconutLogEntry] {
        let all = logs.filter { $0.amount > 0 }
        let cal = Calendar.current
        let now = Date()
        switch timeRange {
        case .day:
            let start = cal.startOfDay(for: now)
            return all.filter { $0.date >= start }
        case .week:
            guard let start = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return all }
            return all.filter { $0.date >= start }
        case .month:
            guard let start = cal.dateInterval(of: .month, for: now)?.start else { return all }
            return all.filter { $0.date >= start }
        case .all:
            return all
        }
    }

    // 时间段内活跃实体名集合（用于图例）
    var activeEntityNames: [String] {
        let names = Set(filtered.compactMap { $0.actorName })
        return Array(names).sorted()
    }

    var chartBars: [WealthBarData] {
        let cal = Calendar.current
        let component: Calendar.Component = {
            switch timeRange {
            case .day:   return .hour
            case .week:  return .day
            case .month: return .day
            case .all:   return .month
            }
        }()
        var dict: [String: (bucket: Date, entity: String, eid: String, sum: Int)] = [:]
        for log in filtered {
            let bucket = cal.dateInterval(of: component, for: log.date)?.start ?? log.date
            // 严格按 actorId 分桶；未知实体归入 system
            let rawId = log.actorId ?? ""
            let isPet   = !rawId.isEmpty && pets.contains   { $0.id.uuidString == rawId }
            let isHuman = !rawId.isEmpty && humans.contains { $0.id.uuidString == rawId }
            let eid: String
            let name: String
            if isPet {
                eid  = rawId
                name = pets.first { $0.id.uuidString == rawId }?.name ?? (log.actorName ?? "宠物")
            } else if isHuman {
                eid  = rawId
                name = humans.first { $0.id.uuidString == rawId }?.name ?? (log.actorName ?? "家人")
            } else {
                eid  = "system"
                name = "其他/系统"
            }
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
        Array(Set(chartBars.map { $0.entityName })).sorted()
    }

    // 对应的颜色数组（与 chartEntityNames 严格一一对应）
    var chartEntityColors: [Color] {
        chartEntityNames.map { name -> Color in
            // 优先从 petColorMap（以 entityId 为 key）查宠物色
            if let pet = pets.first(where: { $0.name == name }) {
                return petColorMap[pet.id.uuidString] ?? pet.themeColor.color
            }
            if humans.contains(where: { $0.name == name }) {
                return Color.goLime
            }
            return Color.white.opacity(0.35)   // system / 其他
        }
    }

    // 时间段内日志总额（图表标题用）
    var periodLogTotal: Int { filtered.reduce(0) { $0 + $1.amount } }

    // MARK: - 色板
    static let palette: [Color] = [
        Color(hex: "C8FF00"), Color(hex: "FFF44F"), Color(hex: "00D4AA"),
        Color(hex: "FF8C42"), Color(hex: "FF4757"), Color(hex: "80FFEA")
    ]
    func color(for entityId: String) -> Color {
        if entityId == "system" { return Color.white.opacity(0.35) }
        if let petColor = petColorMap[entityId] { return petColor }
        // human：从调色板取稳定色
        let idx = abs(entityId.hashValue) % Self.palette.count
        return Self.palette[idx]
    }
}
