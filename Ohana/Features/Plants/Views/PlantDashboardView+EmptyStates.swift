//
//  PlantDashboardView+EmptyStates.swift
//  Ohana
//
//  Empty and urgent states for the Plants dashboard.
//

import SwiftUI

extension PlantDashboardView {
    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            Image(systemName: "leaf.circle.fill") // a11y: allow decorative empty-state glyph; following title describes the state.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 72, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goTeal)

            Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)

            Text(l.tr(
                zh: "添加你的第一棵植物，开始记录浇水和施肥",
                en: "Add your first plant and start tracking watering and fertilizing",
                de: "Füge deine erste Pflanze hinzu und tracke Gießen und Düngen"
            ))
            .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Button {
                showingAddPlant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                        .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.arkInk)
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
            HStack(spacing: 6) {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goTeal)
                Text(l.tr(zh: "需要浇水", en: "Needs watering", de: "Braucht Wasser"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    waterAll()
                } label: {
                    Text(l.tr(zh: "全部浇水", en: "Water all", de: "Alle gießen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
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
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if let days = plant.daysSinceWatered {
                    Text(l.tr(
                        zh: "\(days)天未浇水",
                        en: "\(days)d overdue",
                        de: "\(days) T. überfällig"
                    ))
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goRed)
                }
            }
            Button {
                waterPlant(plant)
            } label: {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
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
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSearchingPlants
                        ? l.tr(zh: "没有匹配的植物", en: "No matching plants", de: "Keine passenden Pflanzen")
                        : l.tr(zh: "当前筛选没有植物", en: "No plants in this filter", de: "Keine Pflanzen in diesem Filter"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isSearchingPlants
                        ? l.tr(zh: "换个名字、品种或房间试试", en: "Try another name, species, or room", de: "Anderen Namen, Art oder Raum versuchen")
                        : l.tr(zh: "清空筛选即可回到完整植物列表", en: "Clear filters to return to the full plant list", de: "Filter leeren, um alle Pflanzen zu sehen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
            }

            Button {
                clearPlantSearchAndFilters()
            } label: {
                Text(l.tr(zh: "显示全部植物", en: "Show all plants", de: "Alle Pflanzen anzeigen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
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
