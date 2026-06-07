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

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var selectedItemID: String?
    @State private var treeManager = OasisTreeManager.shared

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome } }
    private var currentTreeLevel: Int { treeManager.treeLevel.rawValue }

    private var hasDogs: Bool {
        activePets.contains {
            $0.species.localizedCaseInsensitiveContains("狗") ||
            $0.species.localizedCaseInsensitiveContains("dog")
        }
    }

    /// 家模块中周报在多家人时才展示；悬赏已统一收进 Ohana 成员页协作。
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
            OhanaAppBackground()
            .ignoresSafeArea()

            VStack(spacing: 0) {
                pageHeader
                segmentBar
                Rectangle().fill(Color.ohanaDivider).frame(height: 1)
                pager
            }
        }
        .onAppear(perform: ensureSelectedItem)
        .onChange(of: items.map(\.id)) { _, _ in ensureSelectedItem() }
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: group.icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(group.color)
                .frame(width: 34, height: 34)
            Text(LocalizedStringKey(group.title))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var segmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    let unlock = GrowthUnlockPolicy.status(for: item.destination, currentLevel: currentTreeLevel)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.feedback) {
                            selectedItemID = item.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: unlock.isUnlocked ? item.icon : "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(LocalizedStringKey(item.title))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedItem.id == item.id ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(selectedItem.id == item.id ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                        .overlay(alignment: .topTrailing) {
                            if !unlock.isUnlocked {
                                Text("Lv.\(unlock.step.requiredLevel)")
                                    .font(.system(size: 7, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.arkInk)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: unlock.step.tintHex), in: Capsule())
                                    .offset(x: 4, y: -6)
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
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
        .animation(GoMotion.page, value: selectedItem.id)
    }

    @ViewBuilder
    private func content(for item: FeatureGroupItem) -> some View {
        let unlock = GrowthUnlockPolicy.status(for: item.destination, currentLevel: currentTreeLevel)
        if !unlock.isUnlocked {
            GrowthLockedFeatureView(
                status: unlock,
                appLanguage: appLanguage,
                showsFullRoadmap: false
            )
        } else {
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
