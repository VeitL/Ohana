import SwiftUI

struct FunctionMenuRootView: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void
    let pets: [Pet]
    let humans: [Human]

    @Environment(AppServices.self) private var appServices
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    private var l: L10n { L10n(appLanguage) }
    private var currentTreeLevel: Int { appServices.oasisTree.treeLevel.rawValue }

    var body: some View {
        let showsPendingGroup: (FeatureGroup) -> Bool = { group in
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(group: group)
        }
        let showsPendingDestination: (FMDest) -> Bool = { destination in
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(destination)
        }

        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    GrowthUnlockProgressCard(
                        currentLevel: currentTreeLevel,
                        progressToNextLevel: appServices.oasisTree.progressToNextLevel,
                        appLanguage: appLanguage,
                        isCompact: true
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            icon: "square.grid.2x2.fill",
                            title: l.tr(
                                zh: "功能", en: "Features", de: "Funktionen",
                                es: "Funciones", pt: "Funcionalidades", fr: "Fonctionnalités",
                                ja: "機能", ko: "기능", it: "Funzioni"
                            )
                        )

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(functionMenuGroups, id: \.self) { group in
                                menuTile(
                                    icon: group.icon,
                                    title: group.title(l: l),
                                    status: subtitle(for: group),
                                    showsNewFeature: showsPendingGroup(group),
                                    accessibilityIdentifier: "function-menu-group-\(group.rawValue)"
                                ) {
                                    select(.featureGroup(group))
                                }
                            }
                        }
                    }

                    if !toolEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader(
                                icon: "wrench.and.screwdriver.fill",
                                title: l.tr(
                                    zh: "工具", en: "Tools", de: "Tools",
                                    es: "Herramientas", pt: "Ferramentas", fr: "Outils",
                                    ja: "ツール", ko: "도구", it: "Strumenti"
                                )
                            )

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(toolEntries) { entry in
                                    menuTile(
                                        icon: entry.icon,
                                        title: entry.title,
                                        status: entry.subtitle,
                                        showsNewFeature: showsPendingDestination(entry.destination),
                                        accessibilityIdentifier: "function-menu-tool-\(entry.id)"
                                    ) {
                                        select(entry.destination)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(l.tr(zh: "更多功能", en: "More", de: "Mehr", es: "Más", pt: "Mais", fr: "Plus", ja: "その他", ko: "더보기", it: "Altro"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            OhanaModalToolbar(onClose: onClose, closeIdentifier: "function-menu-close")
        }
        .accessibilityIdentifier("function-menu-root")
    }

    private var functionMenuGroups: [FeatureGroup] {
        AppFeatureRouteGuard.visibleFeatureGroups(
            from: [.dailyCare, .healthBody, .archiveMemory, .householdHub],
            currentLevel: currentTreeLevel,
            plan: appServices.commerce.ohanaPlanLevel
        )
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private var toolEntries: [ToolEntry] {
        [
            ToolEntry(
                id: "wealth",
                title: l.tr(zh: "Oasis 收益", en: "Oasis Income", de: "Oasis-Erträge"),
                subtitle: wealthSubtitle,
                icon: "creditcard.fill",
                destination: .wealthDashboard
            ),
            ToolEntry(
                id: "achievements",
                title: l.tr(zh: "成就", en: "Achievements", de: "Erfolge"),
                subtitle: l.tr(zh: "本人 · 伙伴 · 全岛", en: "You · Pets · Island", de: "Du · Tiere · Insel"),
                icon: "trophy.fill",
                destination: .featureAggregate(.achievements)
            ),
            ToolEntry(
                id: "shop",
                title: l.tr(zh: "椰子商店", en: "Coconut Shop", de: "Kokos-Shop"),
                subtitle: l.tr(
                    zh: "绿洲装饰、图标与成员外观", en: "Oasis decor, icons and member looks", de: "Oasis-Deko, Symbole und Mitglieder-Looks",
                    es: "Decoración, iconos y aspecto de miembros", pt: "Decoração, ícones e visual dos membros", fr: "Décor, icônes et apparence des membres",
                    ja: "オアシスの装飾、アイコン、メンバーの外観", ko: "오아시스 장식, 아이콘과 멤버 외관", it: "Decorazioni, icone e aspetto dei membri"
                ),
                icon: "bag.fill",
                destination: .coconutShop
            ),
            ToolEntry(
                id: "gacha",
                title: l.tr(
                    zh: "盲盒收藏", en: "Blind Box", de: "Blindbox",
                    es: "Caja sorpresa", pt: "Caixa surpresa", fr: "Boîte surprise",
                    ja: "ブラインドボックス", ko: "블라인드 박스", it: "Scatola sorpresa"
                ),
                subtitle: l.tr(
                    zh: "用椰子抽取收藏品", en: "Draw collectibles with coconuts", de: "Sammelfiguren mit Kokosnüssen ziehen",
                    es: "Consigue coleccionables con cocos", pt: "Sorteie colecionáveis com cocos", fr: "Obtenez des objets avec des noix de coco",
                    ja: "ココナッツでコレクションを引く", ko: "코코넛으로 수집품 뽑기", it: "Estrai oggetti da collezione con il cocco"
                ),
                icon: "circle.grid.cross.fill",
                destination: .gacha
            )
        ]
        .filter {
            AppFeatureRouteGuard.isVisibleFunctionDestination(
                $0.destination,
                currentLevel: currentTreeLevel,
                plan: appServices.commerce.ohanaPlanLevel
            )
        }
    }

    private func subtitle(for group: FeatureGroup) -> String {
        switch group {
        case .dailyCare:
            l.tr(
                zh: "记录饮食与日常照护", en: "Log food and daily care", de: "Futter und tägliche Pflege erfassen",
                es: "Registra comida y cuidados diarios", pt: "Registre alimentação e cuidados diários", fr: "Notez les repas et les soins quotidiens",
                ja: "食事と日々のお世話を記録", ko: "식사와 일상 돌봄 기록", it: "Registra cibo e cure quotidiane"
            )
        case .healthBody:
            l.tr(
                zh: "查看健康与用药记录", en: "Review health and medication", de: "Gesundheit und Medikamente ansehen",
                es: "Revisa salud y medicación", pt: "Veja saúde e medicação", fr: "Consultez la santé et les médicaments",
                ja: "健康と投薬の記録を確認", ko: "건강과 투약 기록 확인", it: "Consulta salute e farmaci"
            )
        case .archiveMemory:
            l.tr(
                zh: "资料、证件与成长时刻", en: "Profiles, documents and moments", de: "Profile, Dokumente und Momente",
                es: "Perfiles, documentos y momentos", pt: "Perfis, documentos e momentos", fr: "Profils, documents et moments",
                ja: "プロフィール、書類、成長の思い出", ko: "프로필, 문서와 성장 순간", it: "Profili, documenti e momenti"
            )
        case .householdHub:
            l.tr(
                zh: "体重、花费与照护回顾", en: "Weight, expenses and care review", de: "Gewicht, Ausgaben und Pflegerückblick",
                es: "Peso, gastos y resumen de cuidados", pt: "Peso, gastos e resumo dos cuidados", fr: "Poids, dépenses et bilan des soins",
                ja: "体重、支出、お世話の振り返り", ko: "체중, 지출과 돌봄 돌아보기", it: "Peso, spese e riepilogo delle cure"
            )
        case .oasisRewards:
            l.tr(
                zh: "椰子、商店与收藏", en: "Coconuts, shop and collections", de: "Kokosnüsse, Shop und Sammlungen",
                es: "Cocos, tienda y colecciones", pt: "Cocos, loja e coleções", fr: "Noix de coco, boutique et collections",
                ja: "ココナッツ、ショップ、コレクション", ko: "코코넛, 상점과 컬렉션", it: "Cocco, negozio e collezioni"
            )
        case .plants:
            l.tr(
                zh: "浇水、施肥与植物状态", en: "Watering, fertilizer and plant status", de: "Gießen, Düngen und Pflanzenzustand",
                es: "Riego, abono y estado de las plantas", pt: "Rega, adubo e estado das plantas", fr: "Arrosage, engrais et état des plantes",
                ja: "水やり、肥料、植物の状態", ko: "물주기, 비료와 식물 상태", it: "Acqua, concime e stato delle piante"
            )
        }
    }

    private var wealthSubtitle: String {
        l.tr(
            zh: "总资产 \(humans.reduce(0) { $0 + $1.coconutBalance } + pets.reduce(0) { $0 + $1.coconutBalance })🥥",
            en: "Assets \(humans.reduce(0) { $0 + $1.coconutBalance } + pets.reduce(0) { $0 + $1.coconutBalance })🥥",
            de: "Vermoegen \(humans.reduce(0) { $0 + $1.coconutBalance } + pets.reduce(0) { $0 + $1.coconutBalance })🥥"
        )
    }

    private func select(_ destination: FMDest) {
        switch AppFeatureRouteGuard.functionDestinationDecision(
            destination,
            currentLevel: currentTreeLevel,
            plan: appServices.commerce.ohanaPlanLevel
        ) {
        case let .allow(destination):
            onSelect(destination)
        case let .redirectToRoadmap(note):
            AppFeatureRouteGuard.recordIntercept(note)
            onSelect(.growthRoadmap)
        case let .suppress(note):
            AppFeatureRouteGuard.recordIntercept(note)
            OhanaFeedback.light()
            return
        case .rootMenu:
            return
        }
    }

    private func menuTile(
        icon: String,
        title: String,
        status: String,
        showsNewFeature: Bool = false,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 18, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaFunctionalIcon)
                        Spacer()
                        Image(systemName: "chevron.right") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                            .accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(status)
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)

                if showsNewFeature {
                    GrowthNewFeatureDot()
                        .offset(x: 4, y: -4)
                }
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier ?? "function-menu-tile-\(title)")
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary.opacity(0.8))
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .default)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

private struct ToolEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let destination: FMDest
}
