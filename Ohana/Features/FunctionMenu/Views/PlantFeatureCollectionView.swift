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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        batchActionPanel

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
                zh: "批量护理", en: "Batch care", de: "Sammelpflege",
                es: "Cuidado por lotes", pt: "Cuidados em lote", fr: "Entretien groupé",
                ja: "まとめてケア", ko: "일괄 관리", it: "Cura in gruppo"
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

    private var dueCareActionData: FeatureHubTileData {
        FeatureHubTileData(
            id: "plant-due-care-action",
            title: l.tr(zh: "完成到期护理", en: "Complete Due Care", de: "Fällige Pflege"),
            value: "\(summary.dueTaskCount)",
            subtitle: l.tr(
                zh: "浇水 · 施肥 · 养护",
                en: "Water · Feed · Care",
                de: "Gießen · Düngen · Pflege",
                es: "Riego · Abono · Cuidado",
                pt: "Rega · Adubo · Cuidados",
                fr: "Arrosage · Engrais · Entretien",
                ja: "水やり · 施肥 · お手入れ",
                ko: "물주기 · 비료 · 관리",
                it: "Acqua · Concime · Cura"
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
                zh: "浇水 · 喷雾 · 修剪",
                en: "Water · Mist · Prune",
                de: "Gießen · Sprühen · Schneiden",
                es: "Riego · Pulverización · Poda",
                pt: "Rega · Borrifar · Podar",
                fr: "Arroser · Vaporiser · Tailler",
                ja: "水やり · 葉水 · 剪定",
                ko: "물주기 · 분무 · 가지치기",
                it: "Acqua · Nebulizza · Pota"
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

            Text(l.tr(
                zh: "植物功能", en: "Plant Features", de: "Pflanzenfunktionen",
                es: "Funciones de plantas", pt: "Funcionalidades de plantas", fr: "Fonctions des plantes",
                ja: "植物の機能", ko: "식물 기능", it: "Funzioni delle piante"
            ))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var dueCareCoverageText: String {
        l.tr(
            zh: "需护理：\(summary.duePlantCount)", en: "Need care: \(summary.duePlantCount)", de: "Pflege nötig: \(summary.duePlantCount)",
            es: "Necesitan cuidado: \(summary.duePlantCount)", pt: "Precisam de cuidado: \(summary.duePlantCount)", fr: "À entretenir : \(summary.duePlantCount)",
            ja: "要ケア：\(summary.duePlantCount)", ko: "관리 필요: \(summary.duePlantCount)", it: "Da curare: \(summary.duePlantCount)"
        )
    }

    private func cardSummary(for id: String) -> PlantFeatureCardSummary {
        switch id {
        case "batch-care":
            PlantFeatureCardSummary(
                value: "\(summary.dueTaskCount)",
                label: l.tr(zh: "今日待处理", en: "due today", de: "heute fällig"),
                detail: dueCareCoverageText,
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
                zh: "位置 \(summary.roomCount) · 关注 \(summary.healthSignalCount)",
                en: "Locations \(summary.roomCount) · Attention \(summary.healthSignalCount)",
                de: "Orte \(summary.roomCount) · Hinweise \(summary.healthSignalCount)",
                es: "Ubicaciones \(summary.roomCount) · Atención \(summary.healthSignalCount)",
                pt: "Locais \(summary.roomCount) · Atenção \(summary.healthSignalCount)",
                fr: "Emplacements \(summary.roomCount) · Alertes \(summary.healthSignalCount)",
                ja: "場所 \(summary.roomCount) · 要確認 \(summary.healthSignalCount)",
                ko: "위치 \(summary.roomCount) · 확인 \(summary.healthSignalCount)",
                it: "Posizioni \(summary.roomCount) · Avvisi \(summary.healthSignalCount)"
            )
        }
        return l.tr(
            zh: "位置 \(summary.roomCount) · 正常",
            en: "Locations \(summary.roomCount) · Clear",
            de: "Orte \(summary.roomCount) · Unauffällig",
            es: "Ubicaciones \(summary.roomCount) · Sin alertas",
            pt: "Locais \(summary.roomCount) · Sem alertas",
            fr: "Emplacements \(summary.roomCount) · RAS",
            ja: "場所 \(summary.roomCount) · 問題なし",
            ko: "위치 \(summary.roomCount) · 이상 없음",
            it: "Posizioni \(summary.roomCount) · Tutto bene"
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
                    subtitle: summary.detail,
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
