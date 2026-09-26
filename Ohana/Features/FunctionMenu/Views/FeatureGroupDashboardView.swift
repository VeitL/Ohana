//
//  FeatureGroupDashboardView.swift
//  Ohana
//
//  Grouped GO home FAB destination. Each group is a focused segmented detail
//  view; users tap segments to mount one child function at a time.
//

import SwiftUI

struct FeatureGroupDashboardView: View {
    let group: FeatureGroup
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    var isRouteDataLoaded = true
    var petAggregateSummaries: [UUID: FunctionMenuPetAggregateSummary] = [:]

    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedItemID: String?
    @State private var showingPersonalPlan = false

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { !$0.hasPassedAway } }
    private var currentTreeLevel: Int { appServices.oasisTree.treeLevel.rawValue }
    private var currentPlan: OhanaPlanLevel { appServices.commerce.ohanaPlanLevel }
    private var l: L10n { L10n(appLanguage) }

    private var hasDogs: Bool {
        activePets.contains { Pet.isDogSpecies($0.species) }
    }

    private var items: [FeatureGroupItem] {
        let allItems = FeatureGroupItem.items(for: group, hasDogs: hasDogs, l: l)
        if group == .householdHub {
            return allItems
        }
        return allItems.filter {
                AppFeatureRouteGuard.isVisibleFunctionDestination(
                    $0.destination,
                    currentLevel: currentTreeLevel,
                    plan: currentPlan
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
        .sheet(isPresented: $showingPersonalPlan) {
            PersonalPlanView()
                .ohanaSheetPagePresentation()
        }
        .accessibilityIdentifier("function-menu-group-screen-\(group.rawValue)")
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: group.icon)
                .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(group.color)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(group.title(l: l))
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
                    let access = householdAccess(for: item)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.feedback) {
                            selectedItemID = item.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(OhanaFont.adaptive(size: 11, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text(item.title)
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .lineLimit(1)
                            if case let .locked(requiredLevel) = access {
                                Image(systemName: "lock.fill").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 8, weight: .black))
                                Text("Lv.\(requiredLevel)")
                                    .font(OhanaFont.caption2(.black))
                            }
                        }
                        .foregroundStyle(effectiveSelectedItemID == item.id ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(effectiveSelectedItemID == item.id ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("function-menu-group-segment-\(item.id)")
                    .accessibilityValue(segmentAccessibilityValue(for: item, access: access))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var pager: some View {
        if let selectedItem {
            content(for: selectedItem)
                .id(selectedItem.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(GoMotion.page, value: effectiveSelectedItemID)
        }
    }

    @ViewBuilder
    private func content(for item: FeatureGroupItem) -> some View {
        switch AppFeatureRouteGuard.functionDestinationDecision(
            item.destination,
            currentLevel: currentTreeLevel,
            plan: currentPlan
        ) {
        case .allow:
            allowedContent(for: item)
        case .rootMenu:
            EmptyView()
        case let .redirectToRoadmap(note):
            if group == .householdHub, let tab = item.householdInsightTab {
                householdInsightLockedContent(tab: tab, note: note)
            } else {
                lockedRouteFallback(note: note)
            }
        case let .suppress(note):
            hiddenRouteFallback(note: note)
        }
    }

    @ViewBuilder
    private func allowedContent(for item: FeatureGroupItem) -> some View {
        switch item.destination {
        case let .featureAggregate(feature):
            FeatureAggregateView(
                feature: feature,
                parentPath: $parentPath,
                pets: pets,
                humans: humans,
                petAggregateSummaries: petAggregateSummaries,
                showsNavigationChrome: false,
                showsEntityChips: false
            )
        case .careLedgerAnalysis:
            CareLedgerAnalysisView()
        case .reminderObservability:
            ReminderObservabilityView()
        case .bountyBoard:
            if OnlineFeatureGate.allows(.onlineCollaboration) {
                BountyBoardView()
            }
        case .familyWeeklyReport:
            FamilyWeeklyReportDashboardView()
        case .familyLongTermReview:
            FamilyLongTermReviewView()
        case .plantsDashboard:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .sites,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsBatchCare:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                opensBatchCareOnAppear: true,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case let .plantsBatchCareFiltered(careType):
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                opensBatchCareOnAppear: true,
                initialBatchCareType: careType,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsList:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsPhotos:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .photos,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case let .plantCareAggregate(feature):
            PlantCareFeatureDetailView(
                plants: plants,
                feature: feature,
                focusedPlantID: nil,
                focusedCareType: nil
            )
        default:
            EmptyView()
        }
    }

    private var unavailableGroupFallback: some View {
        GrowthUnlockRoadmapView(
            currentLevel: currentTreeLevel,
            progressToNextLevel: appServices.oasisTree.progressToNextLevel,
            appLanguage: appLanguage
        )
    }

    private func lockedRouteFallback(note: String) -> some View {
        GrowthUnlockRoadmapView(
            currentLevel: currentTreeLevel,
            progressToNextLevel: appServices.oasisTree.progressToNextLevel,
            appLanguage: appLanguage
        )
        .onAppear {
            AppFeatureRouteGuard.recordIntercept(note)
        }
    }

    private func householdInsightLockedContent(
        tab: HouseholdInsightTab,
        note: String
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if HouseholdInsightAccessPolicy.includesUngatedSafetySummary(for: tab) {
                    ReminderSafetySummaryView()
                }
                HouseholdInsightLockedCard(
                    tab: tab,
                    currentLevel: currentTreeLevel,
                    appLanguage: appLanguage,
                    onShowPersonal: { showingPersonalPlan = true }
                )
            }
            .padding(16)
            .padding(.bottom, 30)
        }
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

    private func householdAccess(for item: FeatureGroupItem) -> HouseholdInsightAccess {
        guard let tab = item.householdInsightTab else { return .available }
        return HouseholdInsightAccessPolicy.access(
            for: tab,
            currentLevel: currentTreeLevel,
            plan: currentPlan
        )
    }

    private func segmentAccessibilityValue(
        for item: FeatureGroupItem,
        access: HouseholdInsightAccess
    ) -> String {
        let selection = effectiveSelectedItemID == item.id
            ? l.tr(zh: "已选中", en: "Selected", de: "Ausgewählt")
            : l.tr(zh: "未选中", en: "Not selected", de: "Nicht ausgewählt")
        switch access {
        case .available:
            return selection
        case .availableThroughPersonal:
            return "\(selection), \(l.tr(zh: "Personal 已解锁", en: "Unlocked by Personal", de: "Durch Personal freigeschaltet"))"
        case let .locked(requiredLevel):
            return "\(selection), \(l.tr(zh: "Lv.\(requiredLevel) 解锁", en: "Unlocks at Lv.\(requiredLevel)", de: "Ab Lv.\(requiredLevel)"))"
        }
    }
}

private struct FeatureGroupItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let destination: FMDest

    var householdInsightTab: HouseholdInsightTab? {
        HouseholdInsightTab.tab(for: destination)
    }

    static func items(for group: FeatureGroup, hasDogs: Bool, l: L10n) -> [FeatureGroupItem] {
        switch group {
        case .dailyCare:
            var items = [
                feature(.food, l: l),
                feature(.hygiene, l: l)
            ]
            if hasDogs {
                items.append(feature(.walks, l: l))
            }
            items.append(feature(.potty, l: l))
            return items
        case .healthBody:
            // Raw health and medication records are Lv.1 entity routes. This
            // Lv.2 group contains only their household aggregate dashboards.
            return [
                feature(.health, l: l),
                feature(.medications, l: l)
            ]
        case .archiveMemory:
            // 单一聚合入口：用户进入 hub 后再选择 基本信息 / 证件 / 重要时刻 / 成就
            return [feature(.retention, l: l)]
        case .householdHub:
            return [
                feature(.weight, l: l),
                feature(.expense, l: l),
                destination(
                    id: "weekly-report",
                    title: HouseholdInsightTab.weeklyReport.title(language: l.languageCode),
                    icon: "chart.bar.doc.horizontal",
                    .familyWeeklyReport
                ),
                destination(
                    id: "care-ledger",
                    title: HouseholdInsightTab.careAnalysis.title(language: l.languageCode),
                    icon: "list.bullet.rectangle.portrait.fill",
                    .careLedgerAnalysis
                ),
                destination(
                    id: "reminder-observability",
                    title: HouseholdInsightTab.reminderHealth.title(language: l.languageCode),
                    icon: "bell.badge.fill",
                    .reminderObservability
                ),
                destination(
                    id: "long-term-review",
                    title: HouseholdInsightTab.longTermReview.title(language: l.languageCode),
                    icon: "book.closed.fill",
                    .familyLongTermReview
                )
            ]
        case .plants:
            return [
                destination(
                    id: "plants-dashboard",
                    title: l.tr(zh: "植物总览", en: "Plant Overview", de: "Pflanzenübersicht"),
                    icon: "leaf.fill",
                    .plantsDashboard
                ),
                destination(
                    id: "plants-list",
                    title: l.tr(zh: "植物列表", en: "Plant List", de: "Pflanzenliste"),
                    icon: "list.bullet.rectangle.fill",
                    .plantsList
                ),
                destination(
                    id: "plants-photos",
                    title: l.tr(zh: "成长照片", en: "Growth Photos", de: "Wachstumsfotos"),
                    icon: "photo.stack.fill",
                    .plantsPhotos
                ),
                destination(
                    id: "plants-water",
                    title: PlantCareCategory.hydration.title(l: l),
                    icon: PlantCareFeatureDestination.water.icon,
                    .plantCareAggregate(.water)
                ),
                destination(
                    id: "plants-fertilize",
                    title: PlantCareCategory.nutrition.title(l: l),
                    icon: PlantCareFeatureDestination.fertilize.icon,
                    .plantCareAggregate(.fertilize)
                ),
                destination(
                    id: "plants-maintenance",
                    title: PlantCareFeatureDestination.maintenance.title(l: l),
                    icon: PlantCareFeatureDestination.maintenance.icon,
                    .plantCareAggregate(.maintenance)
                ),
                destination(
                    id: "plants-health",
                    title: PlantCareFeatureDestination.health.title(l: l),
                    icon: PlantCareFeatureDestination.health.icon,
                    .plantCareAggregate(.health)
                ),
                destination(
                    id: "plants-growth",
                    title: PlantCareFeatureDestination.growth.title(l: l),
                    icon: PlantCareFeatureDestination.growth.icon,
                    .plantCareAggregate(.growth)
                )
            ]
        case .oasisRewards:
            return []
        }
    }

    private static func feature(_ feature: PetFeature, l: L10n) -> FeatureGroupItem {
        FeatureGroupItem(
            id: "feature-\(feature.rawValue)",
            title: feature.title(l: l),
            icon: feature.icon,
            destination: .featureAggregate(feature)
        )
    }

    private static func destination(id: String, title: String, icon: String, _ destination: FMDest) -> FeatureGroupItem {
        FeatureGroupItem(id: id, title: title, icon: icon, destination: destination)
    }
}
