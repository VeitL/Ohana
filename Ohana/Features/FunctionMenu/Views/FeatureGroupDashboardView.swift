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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var selectedItemID: String?

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome && !$0.hasPassedAway } }
    private var currentTreeLevel: Int { appServices.oasisTree.treeLevel.rawValue }
    private var l: L10n { L10n(appLanguage) }

    private var hasDogs: Bool {
        activePets.contains {
            $0.species.localizedCaseInsensitiveContains("狗") ||
                $0.species.localizedCaseInsensitiveContains("dog")
        }
    }

    private var items: [FeatureGroupItem] {
        FeatureGroupItem.items(for: group, hasDogs: hasDogs, l: l)
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
                        }
                        .foregroundStyle(effectiveSelectedItemID == item.id ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(effectiveSelectedItemID == item.id ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("function-menu-group-segment-\(item.id)")
                    .accessibilityValue(effectiveSelectedItemID == item.id
                        ? l.tr(zh: "已选中", en: "Selected", de: "Ausgewählt")
                        : l.tr(zh: "未选中", en: "Not selected", de: "Nicht ausgewählt"))
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
                focusedPlantID: nil
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
            // 「提醒健康」迁出至「家」hub（属家庭层面审计）；本组聚焦个体健康指标
            return [
                feature(.health, l: l),
                feature(.medications, l: l),
                feature(.weight, l: l)
            ]
        case .archiveMemory:
            // 单一聚合入口：用户进入 hub 后再选择 基本信息 / 证件 / 重要时刻 / 成就
            return [feature(.retention, l: l)]
        case .householdHub:
            // 整合自旧 financeLedger + familyCollab + 提醒健康（跨模块协作类）
            var items: [FeatureGroupItem] = [
                feature(.expense, l: l),
                destination(
                    id: "care-ledger",
                    title: l.tr(zh: "照护分析", en: "Care Analysis", de: "Pflegeanalyse"),
                    icon: "list.bullet.rectangle.portrait.fill",
                    .careLedgerAnalysis
                ),
                destination(
                    id: "reminder-observability",
                    title: l.tr(zh: "提醒健康", en: "Reminder Health", de: "Erinnerungsstatus"),
                    icon: "bell.badge.fill",
                    .reminderObservability
                )
            ]
            items.append(destination(
                id: "weekly-report",
                title: l.tr(zh: "照护周报", en: "Care Weekly", de: "Pflegewoche"),
                icon: "chart.bar.doc.horizontal",
                .familyWeeklyReport
            ))
            return items
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
                    title: PlantCareFeatureDestination.water.title(l: l),
                    icon: PlantCareFeatureDestination.water.icon,
                    .plantCareAggregate(.water)
                ),
                destination(
                    id: "plants-fertilize",
                    title: PlantCareFeatureDestination.fertilize.title(l: l),
                    icon: PlantCareFeatureDestination.fertilize.icon,
                    .plantCareAggregate(.fertilize)
                ),
                destination(
                    id: "plants-log",
                    title: PlantCareFeatureDestination.log.title(l: l),
                    icon: PlantCareFeatureDestination.log.icon,
                    .plantCareAggregate(.log)
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
