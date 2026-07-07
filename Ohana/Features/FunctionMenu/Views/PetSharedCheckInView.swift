//
//  PetSharedCheckInView.swift
//  Ohana
//
//  Explicit multi-pet check-in entry for shared-care capable routines.
//

import SwiftData
import SwiftUI

struct PetSharedCheckInView: View {
    @Binding var parentPath: NavigationPath
    let pets: [Pet]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var cats: [Pet] {
        activePets.filter {
            $0.species.localizedCaseInsensitiveContains("猫") ||
                $0.species.localizedCaseInsensitiveContains("cat")
        }
    }
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
    private var actions: [PetSharedCheckInAction] {
        [
            PetSharedCheckInAction(
                id: "feed",
                title: l.tr(zh: "共同喂食", en: "Shared Feeding", de: "Gemeinsam füttern"),
                value: "\(activePets.count)",
                subtitle: l.tr(zh: "进入后选择同类成员和餐食", en: "Choose same-species members and meal details", de: "Gleiche Tierart und Mahlzeit wählen"),
                icon: "fork.knife",
                tint: Color.goYellow,
                pets: activePets,
                destination: { .petFood($0.persistentModelID) }
            ),
            PetSharedCheckInAction(
                id: "water",
                title: l.tr(zh: "共同喂水", en: "Shared Water", de: "Gemeinsam trinken"),
                value: "\(activePets.count)",
                subtitle: l.tr(zh: "进入后选择目标宠物和水量", en: "Choose target pets and amount inside", de: "Zieltiere und Menge wählen"),
                icon: "drop.fill",
                tint: Color.goTeal,
                pets: activePets,
                destination: { .petWater($0.persistentModelID) }
            ),
            PetSharedCheckInAction(
                id: "litter",
                title: l.tr(zh: "共同猫砂", en: "Shared Litter", de: "Gemeinsame Streu"),
                value: "\(cats.count)",
                subtitle: l.tr(zh: "铲砂、换砂和未知噗噗", en: "Scoop, change litter and unknown potty", de: "Reinigen, wechseln und unbekanntes Klo"),
                icon: "tray.full.fill",
                tint: Color.goOrange,
                pets: cats,
                destination: { .petPotty($0.persistentModelID) }
            )
        ]
        .filter { !$0.pets.isEmpty }
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

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(actions) { action in
                                Button {
                                    guard let pet = action.pets.first else { return }
                                    parentPath.append(action.destination(pet))
                                } label: {
                                    FeatureSummaryChartCard(data: tileData(for: action))
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .accessibilityIdentifier("pet-shared-check-in-card-\(action.id)")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .accessibilityIdentifier("pet-shared-check-in-view")
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist.checked") // a11y: allow decorative header glyph; title text owns meaning.
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive header glyph.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "多宠物打卡", en: "Multi-Pet Check-in", de: "Mehrere Tiere"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.tr(
                    zh: "选择一个共同动作，再进入已有详情页确认",
                    en: "Pick a shared action, then confirm in the detail page",
                    de: "Aktion wählen und im Detail bestätigen"
                ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "共同照护入口", en: "Shared Care Entries", de: "Gemeinsame Pflege"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            FeatureHubMetricStrip(metrics: [
                FeatureHubMetric(id: "pets", title: l.tr(zh: "活跃宠物", en: "Active pets", de: "Aktive Tiere"), value: "\(activePets.count)"),
                FeatureHubMetric(id: "cats", title: l.tr(zh: "猫砂可用", en: "Litter ready", de: "Streu bereit"), value: "\(cats.count)"),
                FeatureHubMetric(id: "actions", title: l.tr(zh: "共同动作", en: "Shared actions", de: "Aktionen"), value: "\(actions.count)")
            ])
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func tileData(for action: PetSharedCheckInAction) -> FeatureHubTileData {
        FeatureHubTileData(
            id: action.id,
            title: action.title,
            value: action.value,
            subtitle: action.subtitle,
            icon: action.icon,
            tint: action.tint,
            chart: FeatureHubMiniChartData(
                style: .bar,
                points: FeatureHubChartPointFactory.level(
                    current: Double(action.pets.count),
                    total: Double(max(activePets.count, 1)),
                    idPrefix: "pet-shared-\(action.id)"
                )
            )
        )
    }
}

private struct PetSharedCheckInAction: Identifiable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let pets: [Pet]
    let destination: (Pet) -> FMDest
}
