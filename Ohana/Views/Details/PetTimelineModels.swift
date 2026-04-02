//
//  PetTimelineModels.swift
//  Ohana
//
//  统一时间轴条目（岁月史书 / 详情页摘要 / 重要时刻页共用）
//

import SwiftUI

struct UnifiedLogItem: Identifiable {
    let id: UUID
    let date: Date
    let type: String
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
}

enum PetTimelineItemsBuilder {
    /// 构建统一时间轴；`limit` 为 nil 时不截断
    static func items(for pet: Pet, limit: Int? = nil) -> [UnifiedLogItem] {
        var list: [UnifiedLogItem] = []

        for w in pet.walkLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.startDate, type: "walk",
                title: "巡岛 · \(w.distanceText)", subtitle: w.durationText,
                iconName: "figure.walk", color: .goPrimary))
        }
        for p in pet.pottyLogs {
            list.append(UnifiedLogItem(id: p.id, date: p.date, type: "potty",
                title: "噗噗 · \(p.pottyType.emoji)\(p.pottyType.rawValue)", subtitle: "",
                iconName: "drop.fill", color: .goOrange))
        }
        for h in pet.healthLogs {
            list.append(UnifiedLogItem(id: h.id, date: h.date, type: "health",
                title: "\(h.healthLogType.emoji) \(h.type)",
                subtitle: h.note.isEmpty ? (h.vetName.isEmpty ? "" : h.vetName) : h.note,
                iconName: "heart.text.clipboard", color: .goTeal))
        }
        for e in pet.expenseLogs {
            list.append(UnifiedLogItem(id: e.id, date: e.date, type: "expense",
                title: "¥\(Int(e.amount)) · \(e.note.isEmpty ? e.category : e.note)",
                subtitle: e.category,
                iconName: "yensign.circle.fill", color: .goYellow))
        }
        for w in pet.weightLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.date, type: "weight",
                title: String(format: "体重 %.1f kg", w.weight), subtitle: "",
                iconName: "scalemass.fill", color: .goTeal))
        }
        for c in pet.careLogs {
            list.append(UnifiedLogItem(id: c.id, date: c.date, type: "care",
                title: "护理 · \(c.careType.emoji)\(c.careType.rawValue)", subtitle: c.note,
                iconName: "sparkles", color: .goPurple))
        }

        let sorted = list.sorted { $0.date > $1.date }
        if let limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }
}
