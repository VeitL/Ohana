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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

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
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .accessibilityIdentifier("plant-feature-collection")
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(l.tr(
                    zh: "\(summary.plantCount) 株植物 · 聚合入口",
                    en: "\(summary.plantCount) plants · aggregate tools",
                    de: "\(summary.plantCount) Pflanzen · Gesamtansicht"
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
                caption: l.tr(zh: "批量浇水 / 施肥", en: "Batch water and fertilize", de: "Gießen und düngen")
            )
        case "dashboard":
            PlantFeatureCardSummary(
                value: "\(summary.plantCount)",
                label: l.tr(zh: "总数", en: "plants", de: "Pflanzen"),
                detail: roomSummaryText,
                caption: l.tr(zh: "房间、状态与计划总览", en: "Rooms, status and plans", de: "Räume, Status und Pläne")
            )
        case "water":
            PlantFeatureCardSummary(
                value: "\(summary.wateringDueCount)",
                label: l.tr(zh: "待浇水", en: "need water", de: "brauchen Wasser"),
                detail: l.tr(zh: "含浇水和喷雾任务", en: "Includes watering and misting", de: "Gießen und Besprühen"),
                caption: PlantCareFeatureDestination.water.aggregateTitle(l: l)
            )
        case "fertilize":
            PlantFeatureCardSummary(
                value: "\(summary.fertilizingDueCount)",
                label: l.tr(zh: "待施肥", en: "need fertilizer", de: "brauchen Dünger"),
                detail: l.tr(zh: "查看施肥节奏和历史", en: "Review rhythm and history", de: "Rhythmus und Verlauf prüfen"),
                caption: PlantCareFeatureDestination.fertilize.aggregateTitle(l: l)
            )
        case "log":
            PlantFeatureCardSummary(
                value: "\(summary.recentLogCount)",
                label: l.tr(zh: "近 30 天", en: "last 30 days", de: "30 Tage"),
                detail: recentLogText,
                caption: PlantCareFeatureDestination.log.aggregateTitle(l: l)
            )
        case "photos":
            PlantFeatureCardSummary(
                value: "\(summary.photoCount)",
                label: l.tr(zh: "照片", en: "photos", de: "Fotos"),
                detail: l.tr(zh: "头像、成长照片和护理照片", en: "Avatars, growth and care photos", de: "Profil-, Wachstums- und Pflegefotos"),
                caption: l.tr(zh: "成长照片", en: "Growth Photos", de: "Wachstumsfotos")
            )
        case "list":
            PlantFeatureCardSummary(
                value: "\(summary.reminderEnabledCount)",
                label: l.tr(zh: "提醒开启", en: "reminders on", de: "Erinnerungen an"),
                detail: l.tr(
                    zh: "\(summary.plantCount) 株植物列表",
                    en: "\(summary.plantCount) plants in list",
                    de: "\(summary.plantCount) Pflanzen in der Liste"
                ),
                caption: l.tr(zh: "最渴优先和筛选", en: "Sort and filter plants", de: "Sortieren und filtern")
            )
        default:
            PlantFeatureCardSummary(
                value: "\(summary.plantCount)",
                label: l.tr(zh: "植物", en: "plants", de: "Pflanzen"),
                detail: l.tr(zh: "查看聚合信息", en: "View aggregate information", de: "Gesamtdaten ansehen"),
                caption: l.tr(zh: "植物功能", en: "Plant feature", de: "Pflanzenfunktion")
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
                id: "batch-care",
                title: l.tr(zh: "今日照护", en: "Today Care", de: "Heutige Pflege"),
                icon: "checkmark.circle.fill",
                tint: Color.goPrimary,
                destination: .plantsBatchCare
            ),
            PlantFeatureCollectionItem(
                id: "dashboard",
                title: l.tr(zh: "植物总览", en: "Plant Overview", de: "Pflanzenübersicht"),
                icon: "leaf.fill",
                tint: Color.goTeal,
                destination: .plantsDashboard
            ),
            PlantFeatureCollectionItem(
                id: "water",
                title: PlantCareFeatureDestination.water.title(l: l),
                icon: PlantCareFeatureDestination.water.icon,
                tint: PlantCareFeatureDestination.water.tint,
                destination: .plantCareAggregate(.water)
            ),
            PlantFeatureCollectionItem(
                id: "fertilize",
                title: PlantCareFeatureDestination.fertilize.title(l: l),
                icon: PlantCareFeatureDestination.fertilize.icon,
                tint: PlantCareFeatureDestination.fertilize.tint,
                destination: .plantCareAggregate(.fertilize)
            ),
            PlantFeatureCollectionItem(
                id: "log",
                title: PlantCareFeatureDestination.log.title(l: l),
                icon: PlantCareFeatureDestination.log.icon,
                tint: PlantCareFeatureDestination.log.tint,
                destination: .plantCareAggregate(.log)
            ),
            PlantFeatureCollectionItem(
                id: "photos",
                title: l.tr(zh: "成长照片", en: "Growth Photos", de: "Wachstumsfotos"),
                icon: "photo.stack.fill",
                tint: Color.goYellow,
                destination: .plantsPhotos
            ),
            PlantFeatureCollectionItem(
                id: "list",
                title: l.tr(zh: "植物列表", en: "Plant List", de: "Pflanzenliste"),
                icon: "list.bullet.rectangle.fill",
                tint: Color.ohanaFunctionalIcon,
                destination: .plantsList
            )
        ]
    }
}

private struct PlantFeatureCardSummary: Equatable {
    let value: String
    let label: String
    let detail: String
    let caption: String
}

private struct PlantFeatureCollectionCard: View {
    let item: PlantFeatureCollectionItem
    let summary: PlantFeatureCardSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.icon)
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow decorative card glyph; button label text carries meaning.
                        .foregroundStyle(item.tint)
                        .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame.
                        .accessibilityHidden(true)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right") // a11y: allow decorative navigation glyph; card button text owns meaning.
                        .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow decorative navigation glyph.
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(summary.value)
                            .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(item.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .ohanaNumericMotion(summary.value)

                        Text(summary.label)
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }

                    Text(summary.detail)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(summary.caption)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-feature-card-\(item.id)")
    }
}
