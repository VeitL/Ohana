//
//  FeatureGroupDashboardView.swift
//  Ohana
//
//  Grouped GO home FAB destination. Each group is a focused segmented detail
//  view; users can tap segments or swipe horizontally between child functions.
//

import SwiftUI
import SwiftData

struct FeatureGroupDashboardView: View {
    let group: FeatureGroup
    @Binding var parentPath: NavigationPath

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name)    private var humans: [Human]

    @State private var selectedItemID: String?

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome } }

    private var hasDogs: Bool {
        activePets.contains {
            $0.species.localizedCaseInsensitiveContains("狗") ||
            $0.species.localizedCaseInsensitiveContains("dog")
        }
    }

    /// 家模块中悬赏榜/周报 在多家人时才展示（单家人没有协作语义）
    private var hasMultipleHumans: Bool { visibleHumans.count > 1 }

    private var items: [FeatureGroupItem] {
        FeatureGroupItem.items(for: group, hasDogs: hasDogs, hasMultipleHumans: hasMultipleHumans)
    }

    private var selectedItem: FeatureGroupItem {
        if let selectedItemID, let item = items.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return items.first ?? FeatureGroupItem.fallback
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                segmentBar
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                pager
            }
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: ensureSelectedItem)
        .onChange(of: items.map(\.id)) { _, _ in ensureSelectedItem() }
    }

    private var segmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedItemID = item.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(item.title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedItem.id == item.id ? .black : .white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(selectedItem.id == item.id ? Color.goLime : Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var pager: some View {
        TabView(selection: Binding(
            get: { selectedItem.id },
            set: { selectedItemID = $0 }
        )) {
            ForEach(items) { item in
                content(for: item)
                    .tag(item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedItem.id)
    }

    @ViewBuilder
    private func content(for item: FeatureGroupItem) -> some View {
        switch item.destination {
        case .featureAggregate(let feature):
            FeatureAggregateView(
                feature: feature,
                parentPath: $parentPath,
                showsNavigationChrome: false,
                showsEntityChips: false
            )
        case .careLedgerAnalysis:
            CareLedgerAnalysisView()
        case .reminderObservability:
            ReminderObservabilityView()
        case .bountyBoard:
            BountyBoardView()
        case .familyWeeklyReport:
            FamilyWeeklyReportDashboardView()
        default:
            EmptyView()
        }
    }

    private func ensureSelectedItem() {
        guard !items.isEmpty else { return }
        if let selectedItemID, items.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = items[0].id
    }
}

private struct FeatureGroupItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let destination: FMDest

    static let fallback = FeatureGroupItem(
        id: "fallback",
        title: "功能",
        icon: "square.grid.2x2.fill",
        destination: .featureAggregate(.food)
    )

    static func items(for group: FeatureGroup, hasDogs: Bool, hasMultipleHumans: Bool) -> [FeatureGroupItem] {
        switch group {
        case .dailyCare:
            var items = [
                feature(.food),
                feature(.hygiene)
            ]
            if hasDogs {
                items.append(feature(.walks))
            }
            items.append(feature(.potty))
            return items
        case .healthBody:
            // 「提醒健康」迁出至「家」hub（属家庭层面审计）；本组聚焦个体健康指标
            return [
                feature(.health),
                feature(.medications),
                feature(.weight)
            ]
        case .archiveMemory:
            // 单一聚合入口：用户进入 hub 后再选择 基本信息 / 证件 / 重要时刻 / 成就
            return [feature(.retention)]
        case .householdHub:
            // 整合自旧 financeLedger + familyCollab + 提醒健康（跨模块协作类）
            var items: [FeatureGroupItem] = [
                feature(.expense),
                destination(id: "care-ledger", title: "照护分析", icon: "list.bullet.rectangle.portrait.fill", .careLedgerAnalysis),
                destination(id: "reminder-observability", title: "提醒健康", icon: "bell.badge.fill", .reminderObservability)
            ]
            if hasMultipleHumans {
                items.append(destination(id: "bounty", title: "悬赏榜", icon: "megaphone.fill", .bountyBoard))
                items.append(destination(id: "weekly-report", title: "家庭周报", icon: "chart.bar.doc.horizontal", .familyWeeklyReport))
            }
            return items
        case .oasisRewards, .plants:
            return []
        }
    }

    private static func feature(_ feature: PetFeature) -> FeatureGroupItem {
        FeatureGroupItem(
            id: "feature-\(feature.rawValue)",
            title: feature.title,
            icon: feature.icon,
            destination: .featureAggregate(feature)
        )
    }

    private static func destination(id: String, title: String, icon: String, _ destination: FMDest) -> FeatureGroupItem {
        FeatureGroupItem(id: id, title: title, icon: icon, destination: destination)
    }
}
