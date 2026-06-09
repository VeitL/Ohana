//
//  FeatureGroupDashboardView.swift
//  Ohana
//
//  Grouped GO home FAB destination. Each group is a focused segmented detail
//  view; users can tap segments or swipe horizontally between child functions.
//

import SwiftUI

struct FeatureGroupDashboardView: View {
    let group: FeatureGroup
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]

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
            .filter {
                AppFeatureRouteGuard.isVisibleFunctionDestination(
                    $0.destination,
                    currentLevel: currentTreeLevel
                )
            }
    }

    private var selectedItem: FeatureGroupItem? {
        if let selectedItemID, let item = items.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return items.first
    }

    private var effectiveSelectedItemID: String {
        selectedItem?.id ?? ""
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            .ignoresSafeArea()

            VStack(spacing: 0) {
                pageHeader
                if items.isEmpty {
                    unavailableGroupFallback
                } else {
                    segmentBar
                    Rectangle().fill(Color.ohanaDivider).frame(height: 1)
                    pager
                }
            }
        }
        .onAppear(perform: ensureSelectedItem)
        .onChange(of: items.map(\.id)) { _, _ in ensureSelectedItem() }
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: group.icon)
                .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(group.color)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
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
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.feedback) {
                            selectedItemID = item.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(OhanaFont.adaptive(size: 11, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text(LocalizedStringKey(item.title))
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .lineLimit(1)
                        }
                        .foregroundStyle(effectiveSelectedItemID == item.id ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(effectiveSelectedItemID == item.id ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
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
            get: { effectiveSelectedItemID },
            set: { selectedItemID = $0 }
        )) {
            ForEach(items) { item in
                content(for: item)
                    .tag(item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(GoMotion.page, value: effectiveSelectedItemID)
    }

    @ViewBuilder
    private func content(for item: FeatureGroupItem) -> some View {
        switch AppFeatureRouteGuard.functionDestinationDecision(item.destination, currentLevel: currentTreeLevel) {
        case .allow:
            allowedContent(for: item)
        case .rootMenu:
            EmptyView()
        case let .redirectToRoadmap(note):
            lockedRouteFallback(note: note)
        case let .suppress(note):
            hiddenRouteFallback(note: note)
        }
    }

    @ViewBuilder
    private func allowedContent(for item: FeatureGroupItem) -> some View {
        switch item.destination {
        case .featureAggregate(let feature):
            FeatureAggregateView(
                feature: feature,
                parentPath: $parentPath,
                pets: pets,
                humans: humans,
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

    private var unavailableGroupFallback: some View {
        GrowthUnlockRoadmapView(
            currentLevel: currentTreeLevel,
            progressToNextLevel: treeManager.progressToNextLevel,
            appLanguage: appLanguage
        )
    }

    private func lockedRouteFallback(note: String) -> some View {
        GrowthUnlockRoadmapView(
            currentLevel: currentTreeLevel,
            progressToNextLevel: treeManager.progressToNextLevel,
            appLanguage: appLanguage
        )
        .onAppear {
            AppFeatureRouteGuard.recordIntercept(note)
        }
    }

    private func hiddenRouteFallback(note: String) -> some View {
        Color.clear
            .onAppear {
                AppFeatureRouteGuard.recordIntercept(note)
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
