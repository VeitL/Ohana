//
//  PlantDashboardView+EmptyStates.swift
//  Ohana
//
//  Empty and urgent states for the Plants dashboard.
//

import SwiftUI

extension PlantDashboardView {
    var loadingState: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 110)

            ProgressView()
                .controlSize(.large)
                .tint(Color.goTeal)
                .accessibilityLabel(l.tr(
                    zh: "正在加载植物",
                    en: "Loading plants",
                    de: "Pflanzen werden geladen"
                ))

            Text(l.tr(
                zh: "正在加载植物",
                en: "Loading plants",
                de: "Pflanzen werden geladen"
            ))
            .font(OhanaFont.body(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("plant-dashboard-loading")
    }

    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            Image(systemName: "leaf.circle.fill") // a11y: allow decorative empty-state glyph; following title describes the state.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 72, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goTeal)

            Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                .font(OhanaFont.adaptive(size: 24, weight: .semibold, design: .default)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)

            Button {
                showingAddPlant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                        .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .default)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-dashboard-empty-add-action")

            Spacer()
        }
    }

    var urgentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 6))
            headerLayout {
                Label {
                    Text(l.tr(zh: "需要浇水", en: "Needs watering", de: "Braucht Wasser"))
                        .foregroundStyle(Color.ohanaPrimaryText)
                } icon: {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.ohanaFunctionalIcon)
                        .accessibilityHidden(true)
                }
                    .font(OhanaFont.callout(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Button {
                    waterAll()
                } label: {
                    Text(l.tr(zh: "全部浇水", en: "Water all", de: "Alle gießen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .default)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .frame(minHeight: 44)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-water-all-action")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plantsNeedingWater) { plant in
                        urgentPlantChip(plant)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    func urgentPlantChip(_ plant: Plant) -> some View {
        HStack(spacing: 8) {
            Text(plant.avatarEmoji)
                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .default)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if let days = plant.daysSinceWatered {
                    Text(l.tr(
                        zh: "\(days)天未浇水",
                        en: "\(days)d since watering",
                        de: "Seit \(days) T. nicht gegossen",
                        es: "\(days) días sin regar",
                        pt: "\(days) dias sem regar",
                        fr: "\(days) j depuis l’arrosage",
                        ja: "水やりから\(days)日",
                        ko: "물을 준 지 \(days)일",
                        it: "\(days) giorni dall’ultima annaffiatura"
                    ))
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .default)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goRed)
                }
            }
            Button {
                waterPlant(plant)
            } label: {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(Color.goTeal, in: Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "给\(plant.name)浇水", en: "Water \(plant.name)", de: "\(plant.name) gießen"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    var plantSearchEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isSearchingPlants ? "magnifyingglass.circle.fill" : "line.3.horizontal.decrease.circle.fill") // a11y: allow decorative empty-search glyph; adjacent text states the result.
                    .font(OhanaFont.adaptive(size: 22, weight: .semibold))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                Text(isSearchingPlants
                    ? l.tr(zh: "没有匹配的植物", en: "No matching plants", de: "Keine passenden Pflanzen")
                    : l.tr(zh: "当前筛选没有植物", en: "No plants in this filter", de: "Keine Pflanzen in diesem Filter"))
                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }

            Button {
                clearPlantSearchAndFilters()
            } label: {
                Text(l.tr(zh: "显示全部植物", en: "Show all plants", de: "Alle Pflanzen anzeigen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-dashboard-search-reset")
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-search-empty")
    }
}
