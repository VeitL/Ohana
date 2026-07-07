//
//  PetFeatureCollectionView.swift
//  Ohana
//
//  Pet home FAB "All" destination: summary cards that route into aggregate pages.
//

import Foundation
import SwiftUI

struct PetFeatureCollectionView: View {
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]
    let summary: PetFeatureCollectionSummary

    @Environment(AppServices.self) private var appServices
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var currentTreeLevel: Int { appServices.oasisTree.treeLevel.rawValue }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var hasDogs: Bool {
        activePets.contains {
            $0.species.localizedCaseInsensitiveContains("狗") ||
                $0.species.localizedCaseInsensitiveContains("dog")
        }
    }
    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 12)]
        } else {
            [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
    }
    private var items: [PetFeatureCollectionItem] {
        PetFeatureCollectionItem.items(hasDogs: hasDogs, l: l)
            .filter {
                AppFeatureRouteGuard.isVisibleFunctionDestination(
                    .featureAggregate($0.feature),
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
                        summaryPanel

                        Button {
                            parentPath.append(FMDest.petSharedCheckIn)
                        } label: {
                            FeatureSummaryChartCard(data: sharedCheckInActionData)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("pet-feature-collection-shared-check-in")

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(items) { item in
                                PetFeatureCollectionCard(
                                    item: item,
                                    summary: cardSummary(for: item.feature)
                                ) {
                                    parentPath.append(FMDest.featureAggregate(item.feature))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .accessibilityIdentifier("pet-feature-collection")
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(l.tr(zh: "家庭宠物摘要", en: "Pet Summary", de: "Tierübersicht"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 8)
                Text(summary.healthSignalCount > 0
                    ? l.tr(zh: "\(summary.healthSignalCount) 项需关注", en: "\(summary.healthSignalCount) signals", de: "\(summary.healthSignalCount) Signale")
                    : l.tr(zh: "状态稳定", en: "Steady", de: "Stabil"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(summary.healthSignalCount > 0 ? Color.goYellow : Color.goTeal)
            }

            FeatureHubMetricStrip(metrics: [
                FeatureHubMetric(id: "pets", title: l.tr(zh: "活跃宠物", en: "Active pets", de: "Aktive Tiere"), value: "\(summary.activePetCount)"),
                FeatureHubMetric(id: "today", title: l.tr(zh: "今日记录", en: "Today logs", de: "Heute"), value: "\(summary.todayFoodLogs + summary.todayPottyLogs + summary.todayWalkCount)"),
                FeatureHubMetric(id: "expense", title: l.tr(zh: "本月花费", en: "This month", de: "Diesen Monat"), value: expenseAmountText),
                FeatureHubMetric(id: "archive", title: l.tr(zh: "成长档案", en: "Archive", de: "Archiv"), value: "\(summary.archiveItemCount)")
            ])
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pet-feature-collection-summary")
    }

    private var sharedCheckInActionData: FeatureHubTileData {
        FeatureHubTileData(
            id: "pet-shared-check-in",
            title: l.tr(zh: "多宠物打卡", en: "Multi-Pet Check-in", de: "Mehrere Tiere"),
            value: "\(summary.activePetCount)",
            subtitle: l.tr(
                zh: "共同喂食、喂水、猫砂等动作入口",
                en: "Shared feeding, water, litter and care actions",
                de: "Gemeinsame Futter-, Wasser- und Streuaktionen"
            ),
            icon: "checklist.checked",
            tint: Color.goPrimary,
            chart: FeatureHubMiniChartData(
                style: .bar,
                points: FeatureHubChartPointFactory.bars(
                    [
                        Double(summary.todayFoodLogs),
                        Double(summary.todayPottyLogs),
                        Double(summary.todayWalkCount),
                        Double(summary.hygieneLogsLast7Days)
                    ],
                    idPrefix: "pet-feature-shared-check-in"
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
                Text(l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.tr(
                    zh: "\(summary.activePetCount) 只宠物 · 聚合数据",
                    en: "\(summary.activePetCount) pets · aggregate data",
                    de: "\(summary.activePetCount) Tiere · Gesamtdaten"
                ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
            }

            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func cardSummary(for feature: PetFeature) -> PetFeatureCardSummary {
        switch feature {
        case .food:
            PetFeatureCardSummary(
                value: "\(summary.todayFoodLogs)",
                label: l.tr(zh: "今日记录", en: "today logs", de: "heute"),
                detail: l.tr(
                    zh: "覆盖 \(summary.todayFoodPetCount)/\(max(summary.activePetCount, 1)) 只宠物",
                    en: "\(summary.todayFoodPetCount)/\(max(summary.activePetCount, 1)) pets covered",
                    de: "\(summary.todayFoodPetCount)/\(max(summary.activePetCount, 1)) Tiere versorgt"
                ),
                caption: l.tr(zh: "饮食聚合", en: "Food aggregate", de: "Futterübersicht"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.todayFoodLogs), Double(summary.todayFoodPetCount), Double(summary.activePetCount)],
                        idPrefix: "pet-feature-food"
                    )
                ),
                tint: Color(hex: "F59E0B")
            )
        case .hygiene:
            PetFeatureCardSummary(
                value: "\(summary.hygieneLogsLast7Days)",
                label: l.tr(zh: "近 7 天", en: "last 7 days", de: "7 Tage"),
                detail: l.tr(zh: "清洁与护理记录", en: "hygiene and care logs", de: "Pflegeeinträge"),
                caption: l.tr(zh: "护理节奏", en: "Care rhythm", de: "Pflegerhythmus"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.quietPlaceholder(
                        seed: Double(max(1, summary.hygieneLogsLast7Days)),
                        idPrefix: "pet-feature-hygiene"
                    )
                ),
                tint: Color.goTeal
            )
        case .walks:
            PetFeatureCardSummary(
                value: summary.todayWalkCount > 0 ? "\(summary.todayWalkCount)" : "0",
                label: l.tr(zh: "今日遛狗", en: "walks today", de: "heute"),
                detail: walkDistanceText,
                caption: l.tr(zh: "遛狗聚合", en: "Walk aggregate", de: "Gassi-Übersicht"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.todayWalkCount), max(0, summary.todayWalkDistanceMeters / 1000.0)],
                        idPrefix: "pet-feature-walk"
                    )
                ),
                tint: Color(hex: "14B8A6")
            )
        case .potty:
            PetFeatureCardSummary(
                value: "\(summary.todayPottyLogs)",
                label: l.tr(zh: "今日记录", en: "today logs", de: "heute"),
                detail: l.tr(zh: "便便与猫砂相关记录", en: "potty and litter logs", de: "Toilette und Streu"),
                caption: l.tr(zh: "排便观察", en: "Potty signals", de: "Toiletten-Signale"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.todayPottyLogs), Double(summary.activePetCount)],
                        idPrefix: "pet-feature-potty"
                    )
                ),
                tint: Color(hex: "D97706")
            )
        case .health:
            PetFeatureCardSummary(
                value: "\(summary.healthSignalCount)",
                label: l.tr(zh: "健康提醒", en: "health signals", de: "Signale"),
                detail: summary.healthSignalCount == 0
                    ? l.tr(zh: "暂无异常", en: "No issues", de: "Keine Auffälligkeiten")
                    : l.tr(zh: "有项目需要关注", en: "Needs attention", de: "Braucht Aufmerksamkeit"),
                caption: l.tr(zh: "健康档案", en: "Health records", de: "Gesundheitsakte"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.level(
                        current: Double(summary.healthSignalCount),
                        total: Double(max(summary.activePetCount, summary.healthSignalCount, 1)),
                        idPrefix: "pet-feature-health"
                    )
                ),
                tint: Color.goRed
            )
        case .medications:
            PetFeatureCardSummary(
                value: "\(summary.activeMedicationCount)",
                label: l.tr(zh: "当前用药", en: "active meds", de: "aktive Mittel"),
                detail: summary.activeMedicationCount == 0
                    ? l.tr(zh: "暂无用药", en: "No medications", de: "Keine Medikamente")
                    : l.tr(zh: "用药计划进行中", en: "Medication plans active", de: "Medikation aktiv"),
                caption: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.level(
                        current: Double(summary.activeMedicationCount),
                        total: Double(max(summary.activeMedicationCount, summary.activePetCount, 1)),
                        idPrefix: "pet-feature-medication"
                    )
                ),
                tint: Color.goPurple
            )
        case .weight:
            PetFeatureCardSummary(
                value: "\(summary.weightMemberCount)",
                label: l.tr(zh: "有记录成员", en: "tracked members", de: "mit Verlauf"),
                detail: recentDateText(summary.latestWeightDate),
                caption: l.tr(zh: "体重趋势", en: "Weight trend", de: "Gewichtstrend"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.level(
                        current: Double(summary.weightMemberCount),
                        total: Double(max(summary.activePetCount, 1)),
                        idPrefix: "pet-feature-weight"
                    )
                ),
                tint: Color(hex: "16A34A")
            )
        case .expense:
            PetFeatureCardSummary(
                value: "\(summary.monthExpenseCount)",
                label: l.tr(zh: "本月记录", en: "this month", de: "diesen Monat"),
                detail: expenseAmountText,
                caption: l.tr(zh: "花费聚合", en: "Expense aggregate", de: "Ausgabenübersicht"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.bars(
                        [Double(summary.monthExpenseCount), max(0, summary.monthExpenseAmount)],
                        idPrefix: "pet-feature-expense"
                    )
                ),
                tint: Color.goOrange
            )
        case .retention:
            PetFeatureCardSummary(
                value: "\(summary.archiveItemCount)",
                label: l.tr(zh: "档案项目", en: "archive items", de: "Archivstücke"),
                detail: l.tr(zh: "照片、证件与里程碑", en: "Photos, documents and milestones", de: "Fotos, Dokumente und Meilensteine"),
                caption: l.tr(zh: "成长档案", en: "Growth records", de: "Wachstumsakte"),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.quietPlaceholder(
                        seed: Double(max(1, summary.archiveItemCount)),
                        idPrefix: "pet-feature-retention"
                    )
                ),
                tint: Color(hex: "EC4899")
            )
        case .basicInfo, .documents, .moments, .achievements:
            PetFeatureCardSummary(
                value: "\(summary.archiveItemCount)",
                label: l.tr(zh: "档案项目", en: "archive items", de: "Archivstücke"),
                detail: l.tr(zh: "已收进成长档案", en: "Included in growth records", de: "In der Wachstumsakte"),
                caption: feature.title(l: l),
                chart: FeatureHubMiniChartData(
                    points: FeatureHubChartPointFactory.quietPlaceholder(
                        seed: Double(max(1, summary.archiveItemCount)),
                        idPrefix: "pet-feature-\(feature.rawValue)"
                    )
                ),
                tint: Color(hex: "94A3B8")
            )
        }
    }

    private var walkDistanceText: String {
        if summary.todayWalkDistanceMeters > 0 {
            return AppMeasurementSystem.formatDistanceMeters(summary.todayWalkDistanceMeters)
        }
        return l.tr(zh: "今天还没有距离记录", en: "No distance yet today", de: "Heute noch keine Distanz")
    }

    private var expenseAmountText: String {
        if summary.monthExpenseAmount > 0 {
            let value = String(format: "%.0f", summary.monthExpenseAmount)
            return l.tr(zh: "约 \(value)", en: "about \(value)", de: "ca. \(value)")
        }
        return l.tr(zh: "本月暂无花费", en: "No expenses this month", de: "Diesen Monat keine Ausgaben")
    }

    private func recentDateText(_ date: Date?) -> String {
        guard let date else {
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

private struct PetFeatureCollectionItem: Identifiable {
    let feature: PetFeature
    let title: String
    let icon: String

    var id: String { feature.rawValue }

    static func items(hasDogs: Bool, l: L10n) -> [PetFeatureCollectionItem] {
        var features: [PetFeature] = [.food, .hygiene]
        if hasDogs {
            features.append(.walks)
        }
        features.append(contentsOf: [.potty, .health, .medications, .weight, .expense, .retention])
        return features.map {
            PetFeatureCollectionItem(feature: $0, title: $0.title(l: l), icon: $0.icon)
        }
    }
}

private struct PetFeatureCardSummary: Equatable {
    let value: String
    let label: String
    let detail: String
    let caption: String
    let chart: FeatureHubMiniChartData
    let tint: Color
}

private struct PetFeatureCollectionCard: View {
    let item: PetFeatureCollectionItem
    let summary: PetFeatureCardSummary
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
        .accessibilityIdentifier("pet-feature-card-\(item.feature.rawValue)")
    }
}
