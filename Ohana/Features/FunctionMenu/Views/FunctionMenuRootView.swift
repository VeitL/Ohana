import SwiftUI

struct FunctionMenuRootView: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void
    let pets: [Pet]
    let humans: [Human]

    @Environment(AppServices.self) private var appServices
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { !$0.hasPassedAway } }
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
                    rootHeader
                        .padding(.top, 10)

                    GrowthUnlockProgressCard(
                        currentLevel: currentTreeLevel,
                        progressToNextLevel: appServices.oasisTree.progressToNextLevel,
                        appLanguage: appLanguage,
                        isCompact: true
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            icon: "square.grid.2x2.fill",
                            title: l.tr(zh: "功能", en: "Features", de: "Funktionen"),
                            label: "CORE"
                        )

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(functionMenuGroups, id: \.self) { group in
                                menuTile(
                                    icon: group.icon,
                                    iconColor: group.color,
                                    title: group.title(l: l),
                                    status: compactSubtitle(for: subtitle(for: group)),
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
                                title: l.tr(zh: "工具", en: "Tools", de: "Tools"),
                                label: "TOOLS"
                            )

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(toolEntries) { entry in
                                    menuTile(
                                        icon: entry.icon,
                                        iconColor: entry.color,
                                        title: entry.title,
                                        status: compactSubtitle(for: entry.subtitle),
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
        .accessibilityIdentifier("function-menu-root")
    }

    private var rootHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent

            Text(l.tr(zh: "更多功能", en: "More", de: "Mehr"))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            Text("Lv.\(currentTreeLevel)")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.goPrimary, in: Capsule())

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var functionMenuGroups: [FeatureGroup] {
        AppFeatureRouteGuard.visibleFeatureGroups(
            from: [.dailyCare, .healthBody, .archiveMemory, .householdHub],
            currentLevel: currentTreeLevel
        )
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var toolEntries: [ToolEntry] {
        [
            ToolEntry(
                id: "wealth",
                title: l.tr(zh: "Oasis 收益", en: "Oasis Income", de: "Oasis-Erträge"),
                subtitle: wealthSubtitle,
                icon: "creditcard.fill",
                color: Color(hex: "EAB308"),
                destination: .wealthDashboard
            ),
            ToolEntry(
                id: "shop",
                title: l.tr(zh: "椰子商店", en: "Coconut Shop", de: "Kokos-Shop"),
                subtitle: l.tr(zh: "装饰 · 周报 · 奖励", en: "Cosmetics · Reports · Rewards", de: "Deko · Berichte · Belohnungen"),
                icon: "bag.fill",
                color: Color(hex: "EAB308"),
                destination: .coconutShop
            ),
            ToolEntry(
                id: "gacha",
                title: l.tr(zh: "收藏玩法", en: "Collection Play", de: "Sammlungsspiel"),
                subtitle: l.tr(zh: "扭蛋 · 电子宠物", en: "Draws · E-critter", de: "Ziehungen · E-Critter"),
                icon: "circle.grid.cross.fill",
                color: Color(hex: "F97316"),
                destination: .gacha
            )
        ]
        .filter { AppFeatureRouteGuard.isVisibleFunctionDestination($0.destination, currentLevel: currentTreeLevel) }
    }

    private func subtitle(for group: FeatureGroup) -> String {
        switch group {
        case .dailyCare:
            hasDogs
                ? l.tr(zh: "饮食 · 清洁 · 遛狗 · 便便", en: "Food · Hygiene · Walks · Potty", de: "Futter · Pflege · Gassi · Toilette")
                : l.tr(zh: "饮食 · 清洁 · 便便", en: "Food · Hygiene · Potty", de: "Futter · Pflege · Toilette")
        case .healthBody:
            l.tr(zh: "健康档案 · 用药 · 体重", en: "Health · Medication · Weight", de: "Gesundheit · Medikamente · Gewicht")
        case .archiveMemory:
            l.tr(zh: "成长 · 基本信息 · 证件 · 时刻", en: "Growth · Profile · Documents · Moments", de: "Wachstum · Profil · Dokumente · Momente")
        case .householdHub:
            l.tr(zh: "花费 · 照护分析 · 提醒 · 周报", en: "Expenses · Care analysis · Reminders · Weekly", de: "Ausgaben · Pflegeanalyse · Erinnerungen · Woche")
        case .oasisRewards:
            l.tr(zh: "\(wealthSubtitle) · 商店 · 扭蛋", en: "\(wealthSubtitle) · Shop · Gacha", de: "\(wealthSubtitle) · Shop · Gacha")
        case .plants:
            l.tr(zh: "浇水 · 施肥 · 状态", en: "Watering · Fertilizing · Status", de: "Gießen · Düngen · Status")
        }
    }

    private var hasDogs: Bool {
        activePets.contains { Pet.isDogSpecies($0.species) }
    }

    private var wealthSubtitle: String {
        l.tr(
            zh: "总资产 \(humans.reduce(0) { $0 + $1.coconutBalance } + pets.reduce(0) { $0 + $1.coconutBalance })🥥",
            en: "Assets \(humans.reduce(0) { $0 + $1.coconutBalance } + pets.reduce(0) { $0 + $1.coconutBalance })🥥",
            de: "Vermoegen \(humans.reduce(0) { $0 + $1.coconutBalance } + pets.reduce(0) { $0 + $1.coconutBalance })🥥"
        )
    }

    private func compactSubtitle(for subtitle: String) -> String {
        subtitle.components(separatedBy: " · ").first ?? subtitle
    }

    private func select(_ destination: FMDest) {
        switch AppFeatureRouteGuard.functionDestinationDecision(destination, currentLevel: currentTreeLevel) {
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
        iconColor: Color,
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
                            .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaFunctionalIcon)
                        Spacer()
                        Image(systemName: "chevron.right") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                            .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(status)
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(iconColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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

    private func sectionHeader(icon: String, title: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary.opacity(0.8))
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary.opacity(0.6))
                .tracking(2)
        }
        .padding(.bottom, 2)
    }
}

private struct ToolEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: FMDest
}
