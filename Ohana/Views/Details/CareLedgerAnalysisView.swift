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

    @State private var screenModel = CareLedgerAnalysisScreenModel()

    var body: some View {
        ZStack {
            OhanaAppBackground()
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
        .onAppear(perform: syncScreenModel)
        .onChange(of: ledgerEvents.count) { syncScreenModel() }
        .onChange(of: pets.count) { syncScreenModel() }
        .onChange(of: humans.count) { syncScreenModel() }
    }

    private func syncScreenModel() {
        screenModel.applyQuerySnapshot(
            ledgerEvents: ledgerEvents,
            pets: pets,
            humans: humans
        )
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("统一照护事件账本")
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                    Text("用同一事件层查看谁、给谁、做了什么")
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                metric("事件", "\(screenModel.filteredEvents.count)", .goPrimary)
                metric("奖励", "\(screenModel.positiveRewardTotal)🥥", .goYellow)
                metric("类型", "\(screenModel.kindStats.count)", .goTeal)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("筛选", icon: "line.3.horizontal.decrease.circle.fill")
            Picker("范围", selection: $screenModel.selectedRange) {
                ForEach(CareLedgerRangeFilter.allCases, id: \.self) { range in
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
            if screenModel.kindStats.isEmpty {
                emptyText("暂无账本事件")
            } else {
                ForEach(screenModel.kindStats, id: \.0) { kind, count in
                    statBar(title: kind.displayName, count: count, total: max(screenModel.filteredEvents.count, 1), color: kind.color)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var actorBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("谁做得最多", icon: "person.fill.checkmark")
            if screenModel.actorStats.isEmpty {
                emptyText("暂无成员统计")
            } else {
                ForEach(screenModel.actorStats.prefix(6), id: \.0) { name, count in
                    statBar(title: name, count: count, total: max(screenModel.filteredEvents.count, 1), color: .goPrimary)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var latestEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近账本流水", icon: "list.bullet.rectangle")
            if screenModel.filteredEvents.isEmpty {
                emptyText("完成一次照护、提醒或椰子操作后，这里会出现流水")
            } else {
                ForEach(screenModel.filteredEvents.prefix(20)) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.eventKindEnum.icon)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold))
                            .foregroundStyle(event.eventKindEnum.color)
                            .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .background(event.eventKindEnum.color.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.eventKindEnum.displayName) · \(event.actionType)")
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text("\(screenModel.actorName(for: event.actorId, kind: event.actorKind)) → \(screenModel.subjectName(for: event.subjectId, kind: event.subjectKind))")
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(event.occurredAt, format: .dateTime.month().day().hour().minute())
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private func kindChip(title: String, kind: CareLedgerEventKind?) -> some View {
        let isSelected = screenModel.selectedKind == kind
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                screenModel.selectedKind = kind
            }
        } label: {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func statBar(title: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text("\(count)").font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)).foregroundStyle(color)
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
            Text(value).font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
            Spacer()
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
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
