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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

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
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .accessibilityIdentifier("pet-feature-collection")
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
                caption: l.tr(zh: "饮食聚合", en: "Food aggregate", de: "Futterübersicht")
            )
        case .hygiene:
            PetFeatureCardSummary(
                value: "\(summary.hygieneLogsLast7Days)",
                label: l.tr(zh: "近 7 天", en: "last 7 days", de: "7 Tage"),
                detail: l.tr(zh: "清洁与护理记录", en: "hygiene and care logs", de: "Pflegeeinträge"),
                caption: l.tr(zh: "护理节奏", en: "Care rhythm", de: "Pflegerhythmus")
            )
        case .walks:
            PetFeatureCardSummary(
                value: summary.todayWalkCount > 0 ? "\(summary.todayWalkCount)" : "0",
                label: l.tr(zh: "今日遛狗", en: "walks today", de: "heute"),
                detail: walkDistanceText,
                caption: l.tr(zh: "遛狗聚合", en: "Walk aggregate", de: "Gassi-Übersicht")
            )
        case .potty:
            PetFeatureCardSummary(
                value: "\(summary.todayPottyLogs)",
                label: l.tr(zh: "今日记录", en: "today logs", de: "heute"),
                detail: l.tr(zh: "便便与猫砂相关记录", en: "potty and litter logs", de: "Toilette und Streu"),
                caption: l.tr(zh: "排便观察", en: "Potty signals", de: "Toiletten-Signale")
            )
        case .health:
            PetFeatureCardSummary(
                value: "\(summary.healthSignalCount)",
                label: l.tr(zh: "健康提醒", en: "health signals", de: "Signale"),
                detail: summary.healthSignalCount == 0
                    ? l.tr(zh: "暂无异常", en: "No issues", de: "Keine Auffälligkeiten")
                    : l.tr(zh: "有项目需要关注", en: "Needs attention", de: "Braucht Aufmerksamkeit"),
                caption: l.tr(zh: "健康档案", en: "Health records", de: "Gesundheitsakte")
            )
        case .medications:
            PetFeatureCardSummary(
                value: "\(summary.activeMedicationCount)",
                label: l.tr(zh: "当前用药", en: "active meds", de: "aktive Mittel"),
                detail: summary.activeMedicationCount == 0
                    ? l.tr(zh: "暂无用药", en: "No medications", de: "Keine Medikamente")
                    : l.tr(zh: "用药计划进行中", en: "Medication plans active", de: "Medikation aktiv"),
                caption: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente")
            )
        case .weight:
            PetFeatureCardSummary(
                value: "\(summary.weightMemberCount)",
                label: l.tr(zh: "有记录成员", en: "tracked members", de: "mit Verlauf"),
                detail: recentDateText(summary.latestWeightDate),
                caption: l.tr(zh: "体重趋势", en: "Weight trend", de: "Gewichtstrend")
            )
        case .expense:
            PetFeatureCardSummary(
                value: "\(summary.monthExpenseCount)",
                label: l.tr(zh: "本月记录", en: "this month", de: "diesen Monat"),
                detail: expenseAmountText,
                caption: l.tr(zh: "花费聚合", en: "Expense aggregate", de: "Ausgabenübersicht")
            )
        case .retention:
            PetFeatureCardSummary(
                value: "\(summary.archiveItemCount)",
                label: l.tr(zh: "档案项目", en: "archive items", de: "Archivstücke"),
                detail: l.tr(zh: "照片、证件与里程碑", en: "Photos, documents and milestones", de: "Fotos, Dokumente und Meilensteine"),
                caption: l.tr(zh: "成长档案", en: "Growth records", de: "Wachstumsakte")
            )
        case .basicInfo, .documents, .moments, .achievements:
            PetFeatureCardSummary(
                value: "\(summary.archiveItemCount)",
                label: l.tr(zh: "档案项目", en: "archive items", de: "Archivstücke"),
                detail: l.tr(zh: "已收进成长档案", en: "Included in growth records", de: "In der Wachstumsakte"),
                caption: feature.title(l: l)
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
}

private struct PetFeatureCollectionCard: View {
    let item: PetFeatureCollectionItem
    let summary: PetFeatureCardSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.icon)
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow decorative card glyph; button label text carries meaning.
                        .foregroundStyle(Color.ohanaFunctionalIcon)
                        .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame.

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
                            .foregroundStyle(Color.goPrimary)
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
        .accessibilityIdentifier("pet-feature-card-\(item.feature.rawValue)")
    }
}
