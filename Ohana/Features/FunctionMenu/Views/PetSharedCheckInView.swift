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
        activePets.filter { Pet.isCatSpecies($0.species) }
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
                subtitle: l.tr(
                    zh: "同类成员 · 餐食", en: "Same species · Meal", de: "Gleiche Tierart · Mahlzeit",
                    es: "Misma especie · Comida", pt: "Mesma espécie · Refeição", fr: "Même espèce · Repas",
                    ja: "同じ種類 · 食事", ko: "같은 종 · 식사", it: "Stessa specie · Pasto"
                ),
                icon: "fork.knife",
                tint: Color.goYellow,
                pets: activePets,
                destination: { .petFood($0.persistentModelID) }
            ),
            PetSharedCheckInAction(
                id: "water",
                title: l.tr(zh: "共同喂水", en: "Shared Water", de: "Gemeinsam trinken"),
                value: "\(activePets.count)",
                subtitle: l.tr(
                    zh: "宠物 · 水量", en: "Pets · Amount", de: "Tiere · Menge",
                    es: "Mascotas · Cantidad", pt: "Pets · Quantidade", fr: "Animaux · Quantité",
                    ja: "ペット · 水量", ko: "반려동물 · 물의 양", it: "Animali · Quantità"
                ),
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

            Text(l.tr(
                zh: "多宠物打卡", en: "Multi-Pet Check-in", de: "Mehrere Tiere",
                es: "Check-in de varias mascotas", pt: "Check-in de vários pets", fr: "Check-in multi-animaux",
                ja: "複数ペットのチェックイン", ko: "여러 반려동물 체크인", it: "Check-in multi-animale"
            ))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .accessibilityHint(l.tr(
                    zh: "选择共同动作后确认详情",
                    en: "Choose a shared action, then confirm the details",
                    de: "Gemeinsame Aktion wählen und Details bestätigen",
                    es: "Elige una acción compartida y confirma los detalles",
                    pt: "Escolha uma ação compartilhada e confirme os detalhes",
                    fr: "Choisissez une action partagée, puis confirmez les détails",
                    ja: "共同アクションを選び、詳細を確認します",
                    ko: "공동 활동을 선택한 다음 세부 내용을 확인하세요",
                    it: "Scegli un’azione condivisa e conferma i dettagli"
                ))

            Spacer(minLength: 54)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
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
