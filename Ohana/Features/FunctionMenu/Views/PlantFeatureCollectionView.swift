//
//  PlantFeatureCollectionView.swift
//  Ohana
//
//  Plant FAB "All" destination: summary cards that route into plant aggregate pages.
//

import Foundation
import SwiftUI

struct PlantFeatureCollectionView: View {
    @Binding var parentPath: NavigationPath
    let plants: [Plant]
    let summary: PlantFeatureCollectionSummary

    @Environment(AppServices.self) private var appServices
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var currentTreeLevel: Int { appServices.oasisTree.treeLevel.rawValue }
    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 12)]
        } else {
            [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
    }
    private var items: [PlantFeatureCollectionItem] {
        PlantFeatureCollectionItem.items(l: l)
            .filter {
                AppFeatureRouteGuard.isVisibleFunctionDestination(
                    $0.destination,
                    currentLevel: currentTreeLevel
                )
            }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                pageHeader
                commandCenterPanel
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        batchActionPanel

                        VStack(alignment: .leading, spacing: 10) {
                            featureCardsHeader

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items) { item in
                                    PlantFeatureCollectionCard(
                                        item: item,
                                        summary: cardSummary(for: item.id)
                                    ) {
                                        parentPath.append(item.destination)
                                    }
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("plant-feature-collection-stat-section")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
            }
        }
        .accessibilityIdentifier("plant-feature-collection")
    }

    private var batchActionPanel: some View {
        FeatureHubSectionActionView(section: plantActionSection) { destination in
            parentPath.append(destination)
        }
    }

    private var plantActionSection: FeatureHubSectionData<FMDest> {
        FeatureHubSectionData(
            id: "plant-care-actions",
            title: l.tr(zh: "多植物动作", en: "Multi-Plant Actions", de: "Mehrere Pflanzen"),
            subtitle: l.tr(
                zh: "这里负责批量执行；下面的卡片负责统计、比较和资料入口",
                en: "Batch actions live here; statistics and profiles stay below",
                de: "Sammelaktionen hier, Statistiken und Profile darunter"
            ),
            items: [
                FeatureHubDestinationItem(
                    data: dueCareActionData,
                    destination: FMDest.plantsBatchCare
                ),
                FeatureHubDestinationItem(
                    data: quickRecordActionData,
                    destination: FMDest.plantsBatchQuickRecord
                )
            ]
        )
    }

    private var featureCardsHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(l.tr(zh: "功能数据", en: "Feature Data", de: "Funktionsdaten"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(l.tr(
                zh: "点击卡片进入植物护理分类、成长记录或管理视图",
                en: "Open care categories, growth records or plant management",
                de: "Pflegekategorien, Wachstum oder Verwaltung öffnen"
            ))
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dueCareActionData: FeatureHubTileData {
        FeatureHubTileData(
            id: "plant-due-care-action",
            title: l.tr(zh: "完成到期护理", en: "Complete Due Care", de: "Fällige Pflege"),
            value: "\(summary.dueTaskCount)",
            subtitle: l.tr(
                zh: "按到期任务批量浇水、施肥和养护",
                en: "Batch complete due watering, nutrition and care",
                de: "Fälliges Gießen, Düngen und Pflege bündeln"
            ),
            icon: "checkmark.circle.fill",
            tint: summary.dueTaskCount > 0 ? Color.goYellow : Color.goTeal,
            chart: FeatureHubMiniChartData(
                style: .bar,
                points: FeatureHubChartPointFactory.bars(
                    [
                        Double(summary.wateringDueCount),
                        Double(summary.fertilizingDueCount),
                        Double(summary.maintenanceDueCount),
                        Double(summary.healthDueCount)
                    ],
                    idPrefix: "plant-feature-due-care"
                )
            )
        )
    }

    private var quickRecordActionData: FeatureHubTileData {
        FeatureHubTileData(
            id: "plant-quick-record-action",
            title: l.tr(zh: "多选快速记录", en: "Multi-Select Log", de: "Mehrfach erfassen"),
            value: "\(summary.plantCount)",
            subtitle: l.tr(
                zh: "给多株植物一次记录浇水、喷雾、修剪等",
                en: "Log water, mist, prune and more for multiple plants",
                de: "Gießen, Besprühen, Schneiden für mehrere Pflanzen"
            ),
            icon: "checklist.checked",
            tint: Color.goPrimary,
            chart: FeatureHubMiniChartData(
                style: .bar,
                points: FeatureHubChartPointFactory.bars(
                    [
                        Double(summary.plantCount),
                        Double(summary.recentLogCount),
                        Double(summary.photoCount)
                    ],
                    idPrefix: "plant-feature-quick-record"
                )
            )
        )
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative header glyph; title text owns meaning.
                .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow decorative header glyph; surrounding title owns meaning.
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "植物全部功能", en: "All Plant Features", de: "Alle Pflanzenfunktionen"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(l.tr(
                    zh: "\(summary.plantCount) 株植物 · 聚合入口",
                    en: "\(summary.plantCount) plants · aggregate tools",
                    de: "\(summary.plantCount) Pflanzen · Gesamtansicht"
                ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var commandCenterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    commandCenterTitle
                    Spacer(minLength: 8)
                    commandCenterStatus
                }

                VStack(alignment: .leading, spacing: 4) {
                    commandCenterTitle
                    commandCenterStatus
                }
            }

            LazyVGrid(columns: commandCenterMetricColumns, alignment: .leading, spacing: 8) {
                commandCenterMetric(
                    icon: "leaf.fill",
                    title: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                    value: "\(summary.plantCount)",
                    tint: Color.goTeal
                )
                commandCenterMetric(
                    icon: "checkmark.circle.fill",
                    title: l.tr(zh: "今日照护", en: "Today care", de: "Heute"),
                    value: "\(summary.dueTaskCount)",
                    tint: summary.dueTaskCount > 0 ? Color.goYellow : Color.goTeal
                )
                commandCenterMetric(
                    icon: "house.fill",
                    title: l.tr(zh: "位置", en: "Rooms", de: "Orte"),
                    value: "\(summary.roomCount)",
                    tint: Color.ohanaFunctionalIcon
                )
                commandCenterMetric(
                    icon: "bell.badge.fill",
                    title: l.tr(zh: "系统提醒", en: "Alerts", de: "Hinweise"),
                    value: "\(summary.systemReminderEnabledCount)",
                    tint: Color.goPrimary
                )
            }

            LazyVGrid(columns: commandCenterPillColumns, alignment: .leading, spacing: 8) {
                commandCenterMiniPill(
                    icon: "drop.fill",
                    text: l.tr(zh: "待水分 \(summary.wateringDueCount)", en: "\(summary.wateringDueCount) water", de: "\(summary.wateringDueCount) Wasser"),
                    tint: Color.goTeal
                )
                commandCenterMiniPill(
                    icon: "leaf.fill",
                    text: l.tr(zh: "待营养 \(summary.fertilizingDueCount)", en: "\(summary.fertilizingDueCount) nutrition", de: "\(summary.fertilizingDueCount) Nährstoff"),
                    tint: Color.goPrimary
                )
                commandCenterMiniPill(
                    icon: "exclamationmark.triangle.fill",
                    text: l.tr(zh: "关注 \(summary.healthSignalCount)", en: "\(summary.healthSignalCount) signals", de: "\(summary.healthSignalCount) Signale"),
                    tint: summary.healthSignalCount > 0 ? Color.goYellow : Color.goTeal
                )
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-feature-collection-command-center")
    }

    private var commandCenterMetricColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 8, alignment: .top)]
        }
        return [GridItem(.adaptive(minimum: 128), spacing: 8, alignment: .top)]
    }

    private var commandCenterPillColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 8, alignment: .top)]
        }
        return [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .top)]
    }

    private var commandCenterTitle: some View {
        Text(l.tr(zh: "植物中枢", en: "Plant hub", de: "Pflanzenzentrale"))
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var commandCenterStatus: some View {
        Text(commandCenterStatusText)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(summary.dueTaskCount > 0 ? Color.goYellow : Color.goTeal)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var commandCenterStatusText: String {
        if summary.dueTaskCount > 0 {
            return l.tr(
                zh: "\(summary.duePlantCount) 株待处理",
                en: "\(summary.duePlantCount) plants due",
                de: "\(summary.duePlantCount) Pflanzen fällig"
            )
        }
        return l.tr(zh: "今天稳定", en: "Steady today", de: "Heute stabil")
    }

    private func commandCenterMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24) // a11y: allow non-interactive metric glyph; parent card owns the accessible content.
                .background(tint.opacity(0.13), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.ohanaControlFill.opacity(0.72), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func commandCenterMiniPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(tint.opacity(0.11), in: Capsule())
    }

    private func cardSummary(for id: String) -> PlantFeatureCardSummary {
        switch id {
        case "batch-care":
            PlantFeatureCardSummary(
                value: "\(summary.dueTaskCount)",
                label: l.tr(zh: "今日待处理", en: "due today", de: "heute fällig"),
                detail: l.tr(
                    zh: "覆盖 \(summary.duePlantCount) 株植物",
                    en: "\(summary.duePlantCount) plants need care",
                    de: "\(summary.duePlantCount) Pflanzen brauchen Pflege"
                ),
                caption: l.tr(zh: "批量浇水 / 施肥", en: "Batch water and fertilize", de: "Gießen und düngen"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.wateringDueCount), Double(summary.fertilizingDueCount), Double(summary.maintenanceDueCount)],
                        idPrefix: "plant-feature-batch-care"
                    )
                ),
                tint: Color.goPrimary
            )
        case "dashboard":
            PlantFeatureCardSummary(
                value: "\(summary.plantCount)",
                label: l.tr(zh: "可管理", en: "managed", de: "verwaltet"),
                detail: roomSummaryText,
                caption: l.tr(zh: "房间、状态与资料管理", en: "Rooms, status and profiles", de: "Räume, Status und Profile"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.plantCount), Double(summary.roomCount), Double(summary.calendarPlanEnabledCount)],
                        idPrefix: "plant-feature-dashboard"
                    )
                ),
                tint: Color.goTeal
            )
        case "water":
            PlantFeatureCardSummary(
                value: "\(summary.wateringDueCount)",
                label: l.tr(zh: "待处理", en: "due", de: "fällig"),
                detail: l.tr(zh: "浇水 / 喷雾", en: "Watering / misting", de: "Gießen / Besprühen"),
                caption: PlantCareFeatureDestination.water.aggregateTitle(l: l),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.wateringDueCount), Double(summary.recentLogCount)],
                        idPrefix: "plant-feature-water"
                    )
                ),
                tint: PlantCareFeatureDestination.water.tint
            )
        case "fertilize":
            PlantFeatureCardSummary(
                value: "\(summary.fertilizingDueCount)",
                label: l.tr(zh: "待处理", en: "due", de: "fällig"),
                detail: l.tr(zh: "施肥 / 换盆", en: "Fertilizing / repotting", de: "Düngen / Umtopfen"),
                caption: PlantCareFeatureDestination.fertilize.aggregateTitle(l: l),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.fertilizingDueCount), Double(summary.recentLogCount)],
                        idPrefix: "plant-feature-fertilize"
                    )
                ),
                tint: PlantCareFeatureDestination.fertilize.tint
            )
        case "maintenance":
            PlantFeatureCardSummary(
                value: "\(summary.maintenanceDueCount)",
                label: l.tr(zh: "待处理", en: "due", de: "fällig"),
                detail: l.tr(zh: "修剪 / 擦叶 / 转盆", en: "Prune / clean / rotate", de: "Schneiden / reinigen / drehen"),
                caption: PlantCareFeatureDestination.maintenance.aggregateTitle(l: l),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.maintenanceDueCount), Double(summary.recentLogCount)],
                        idPrefix: "plant-feature-maintenance"
                    )
                ),
                tint: PlantCareFeatureDestination.maintenance.tint
            )
        case "health":
            PlantFeatureCardSummary(
                value: "\(summary.healthSignalCount + summary.healthDueCount)",
                label: l.tr(zh: "需关注", en: "signals", de: "Signale"),
                detail: l.tr(zh: "查虫 / 黄叶 / 虫害", en: "Pest check / yellow leaves / pests", de: "Schädlinge / gelbe Blätter"),
                caption: PlantCareFeatureDestination.health.aggregateTitle(l: l),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.healthDueCount), Double(summary.healthSignalCount)],
                        idPrefix: "plant-feature-health"
                    )
                ),
                tint: PlantCareFeatureDestination.health.tint
            )
        case "growth":
            PlantFeatureCardSummary(
                value: "\(summary.growthLogCount)",
                label: l.tr(zh: "近 30 天", en: "last 30 days", de: "30 Tage"),
                detail: l.tr(zh: "拍照 / 新叶 / 备注观察", en: "Photos / new leaves / notes", de: "Fotos / neue Blätter / Notizen"),
                caption: recentLogText,
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.growthLogCount), Double(summary.photoCount), Double(summary.recentLogCount)],
                        idPrefix: "plant-feature-growth"
                    )
                ),
                tint: PlantCareFeatureDestination.growth.tint
            )
        default:
            PlantFeatureCardSummary(
                value: "\(summary.plantCount)",
                label: l.tr(zh: "植物", en: "plants", de: "Pflanzen"),
                detail: l.tr(zh: "查看聚合信息", en: "View aggregate information", de: "Gesamtdaten ansehen"),
                caption: l.tr(zh: "植物功能", en: "Plant feature", de: "Pflanzenfunktion"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.quietPlaceholder(
                        seed: Double(max(1, summary.plantCount)),
                        idPrefix: "plant-feature-default"
                    )
                ),
                tint: Color.goTeal
            )
        }
    }

    private var roomSummaryText: String {
        if summary.healthSignalCount > 0 {
            return l.tr(
                zh: "\(summary.roomCount) 个位置 · \(summary.healthSignalCount) 条需关注",
                en: "\(summary.roomCount) rooms · \(summary.healthSignalCount) signals",
                de: "\(summary.roomCount) Räume · \(summary.healthSignalCount) Signale"
            )
        }
        return l.tr(
            zh: "\(summary.roomCount) 个位置 · 暂无异常",
            en: "\(summary.roomCount) rooms · no issues",
            de: "\(summary.roomCount) Räume · keine Auffälligkeiten"
        )
    }

    private var recentLogText: String {
        guard let date = summary.latestLogDate else {
            return l.tr(zh: "暂无记录", en: "No records yet", de: "Noch keine Einträge")
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return l.tr(zh: "最近：今天", en: "Latest: today", de: "Zuletzt: heute")
        }
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 1)
        return l.tr(zh: "最近：\(days) 天前", en: "Latest: \(days)d ago", de: "Zuletzt: vor \(days) T.")
    }
}

private struct PlantFeatureCollectionItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let destination: FMDest

    static func items(l: L10n) -> [PlantFeatureCollectionItem] {
        [
            PlantFeatureCollectionItem(
                id: "water",
                title: PlantCareCategory.hydration.title(l: l),
                icon: PlantCareFeatureDestination.water.icon,
                tint: PlantCareFeatureDestination.water.tint,
                destination: .plantCareAggregate(.water)
            ),
            PlantFeatureCollectionItem(
                id: "fertilize",
                title: PlantCareCategory.nutrition.title(l: l),
                icon: PlantCareFeatureDestination.fertilize.icon,
                tint: PlantCareFeatureDestination.fertilize.tint,
                destination: .plantCareAggregate(.fertilize)
            ),
            PlantFeatureCollectionItem(
                id: "maintenance",
                title: PlantCareFeatureDestination.maintenance.title(l: l),
                icon: PlantCareFeatureDestination.maintenance.icon,
                tint: PlantCareFeatureDestination.maintenance.tint,
                destination: .plantCareAggregate(.maintenance)
            ),
            PlantFeatureCollectionItem(
                id: "health",
                title: PlantCareFeatureDestination.health.title(l: l),
                icon: PlantCareFeatureDestination.health.icon,
                tint: PlantCareFeatureDestination.health.tint,
                destination: .plantCareAggregate(.health)
            ),
            PlantFeatureCollectionItem(
                id: "growth",
                title: PlantCareFeatureDestination.growth.title(l: l),
                icon: PlantCareFeatureDestination.growth.icon,
                tint: PlantCareFeatureDestination.growth.tint,
                destination: .plantCareAggregate(.growth)
            ),
            PlantFeatureCollectionItem(
                id: "dashboard",
                title: l.tr(zh: "植物管理", en: "Plant Management", de: "Pflanzenverwaltung"),
                icon: "leaf.fill",
                tint: Color.goTeal,
                destination: .plantsDashboard
            )
        ]
    }
}

private struct PlantFeatureCardSummary: Equatable {
    let value: String
    let label: String
    let detail: String
    let caption: String
    let chart: FeatureHubMiniChartData
    let tint: Color
}

private struct PlantFeatureCollectionCard: View {
    let item: PlantFeatureCollectionItem
    let summary: PlantFeatureCardSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FeatureSummaryChartCard(
                data: FeatureHubTileData(
                    id: item.id,
                    title: item.title,
                    value: summary.value,
                    subtitle: "\(summary.label) · \(summary.detail)",
                    icon: item.icon,
                    tint: summary.tint,
                    chart: summary.chart
                )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-feature-card-\(item.id)")
    }
}
