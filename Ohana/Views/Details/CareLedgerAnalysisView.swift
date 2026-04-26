//
//  CareLedgerAnalysisView.swift
//  Ohana
//
//  Analysis surface for the unified care ledger.
//

import SwiftUI
import SwiftData

struct CareLedgerAnalysisView: View {
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    @State private var selectedRange: RangeFilter = .week
    @State private var selectedKind: CareLedgerEventKind? = nil

    private var filteredEvents: [CareLedgerEvent] {
        let cutoff = selectedRange.cutoff
        return ledgerEvents.filter { event in
            let inRange = cutoff.map { event.occurredAt >= $0 } ?? true
            let matchesKind = selectedKind.map { event.eventKindEnum == $0 } ?? true
            return inRange && matchesKind
        }
    }

    private var kindStats: [(CareLedgerEventKind, Int)] {
        let grouped = Dictionary(grouping: filteredEvents, by: \.eventKindEnum)
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    private var actorStats: [(String, Int)] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            actorName(for: event.actorId, kind: event.actorKind)
        }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    filterCard
                    kindBreakdownCard
                    actorBreakdownCard
                    latestEventsCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("照护账本分析")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("统一照护事件账本")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text("用同一事件层查看谁、给谁、做了什么")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                metric("事件", "\(filteredEvents.count)", .goPrimary)
                metric("奖励", "\(filteredEvents.reduce(0) { $0 + max($1.coconutDelta, 0) })🥥", .goYellow)
                metric("类型", "\(kindStats.count)", .goTeal)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("筛选", icon: "line.3.horizontal.decrease.circle.fill")
            Picker("范围", selection: $selectedRange) {
                ForEach(RangeFilter.allCases, id: \.self) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    kindChip(title: "全部", kind: nil)
                    ForEach(CareLedgerEventKind.allCases, id: \.self) { kind in
                        if kind != .unknown {
                            kindChip(title: kind.displayName, kind: kind)
                        }
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var kindBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("事件类型分布", icon: "chart.bar.xaxis")
            if kindStats.isEmpty {
                emptyText("暂无账本事件")
            } else {
                ForEach(kindStats, id: \.0) { kind, count in
                    statBar(title: kind.displayName, count: count, total: max(filteredEvents.count, 1), color: kind.color)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var actorBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("谁做得最多", icon: "person.fill.checkmark")
            if actorStats.isEmpty {
                emptyText("暂无成员统计")
            } else {
                ForEach(actorStats.prefix(6), id: \.0) { name, count in
                    statBar(title: name, count: count, total: max(filteredEvents.count, 1), color: .goPrimary)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var latestEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近账本流水", icon: "list.bullet.rectangle")
            if filteredEvents.isEmpty {
                emptyText("完成一次照护、提醒或椰子操作后，这里会出现流水")
            } else {
                ForEach(filteredEvents.prefix(20)) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.eventKindEnum.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(event.eventKindEnum.color)
                            .frame(width: 30, height: 30)
                            .background(event.eventKindEnum.color.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.eventKindEnum.displayName) · \(event.actionType)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text("\(actorName(for: event.actorId, kind: event.actorKind)) → \(subjectName(for: event.subjectId, kind: event.subjectKind))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(event.occurredAt, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private func kindChip(title: String, kind: CareLedgerEventKind?) -> some View {
        let isSelected = selectedKind == kind
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedKind = kind
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statBar(title: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text("\(count)").font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(count) / CGFloat(total))
                }
            }
            .frame(height: 8)
        }
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(.system(size: 15, weight: .black, design: .rounded))
            Spacer()
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actorName(for id: String?, kind: String) -> String {
        guard let id, !id.isEmpty else { return "系统/未指定" }
        if kind == CareLedgerActorKind.human.rawValue {
            return humans.first { $0.id.uuidString == id }?.name ?? "家人"
        }
        if kind == CareLedgerActorKind.pet.rawValue {
            return pets.first { $0.id.uuidString == id }?.name ?? "宠物"
        }
        if kind == CareLedgerActorKind.plant.rawValue {
            return plants.first { $0.id.uuidString == id }?.name ?? "植物"
        }
        return "系统"
    }

    private func subjectName(for id: String?, kind: String) -> String {
        guard let id, !id.isEmpty else { return "全家" }
        if kind == CareLedgerSubjectKind.pet.rawValue {
            return pets.first { $0.id.uuidString == id }?.name ?? "宠物"
        }
        if kind == CareLedgerSubjectKind.human.rawValue {
            return humans.first { $0.id.uuidString == id }?.name ?? "家人"
        }
        if kind == CareLedgerSubjectKind.plant.rawValue {
            return plants.first { $0.id.uuidString == id }?.name ?? "植物"
        }
        return "全家"
    }
}

private enum RangeFilter: CaseIterable {
    case week
    case month
    case all

    var title: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .all: return "全部"
        }
    }

    var cutoff: Date? {
        switch self {
        case .week:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month:
            return Calendar.current.date(byAdding: .month, value: -1, to: Date())
        case .all:
            return nil
        }
    }
}

private extension CareLedgerEventKind {
    var displayName: String {
        switch self {
        case .care: return "照护"
        case .potty: return "便便"
        case .walk: return "遛狗"
        case .hygiene: return "护理"
        case .health: return "健康"
        case .weight: return "体重"
        case .medication: return "吃药"
        case .workout: return "运动"
        case .expense: return "花费"
        case .reminder: return "提醒"
        case .plantCare: return "植物"
        case .coconut: return "椰子"
        case .milestone: return "里程碑"
        case .unknown: return "未知"
        }
    }

    var icon: String {
        switch self {
        case .care: return "pawprint.fill"
        case .potty: return "drop.fill"
        case .walk: return "figure.walk"
        case .hygiene: return "sparkles"
        case .health: return "cross.fill"
        case .weight: return "scalemass.fill"
        case .medication: return "pills.fill"
        case .workout: return "figure.run"
        case .expense: return "creditcard.fill"
        case .reminder: return "bell.fill"
        case .plantCare: return "leaf.fill"
        case .coconut: return "circle.hexagongrid.fill"
        case .milestone: return "flag.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .expense: return .goYellow
        case .reminder: return .goOrange
        case .coconut: return .goLime
        case .health, .medication: return .goRed
        case .walk, .workout: return .goTeal
        default: return .goPrimary
        }
    }
}
