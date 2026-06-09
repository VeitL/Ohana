import SwiftUI

struct FunctionMenuRootView: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void
    let pets: [Pet]
    let humans: [Human]

    @State private var treeManager = OasisTreeManager.shared

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome } }
    private var showsFamilyCollaboration: Bool { visibleHumans.count > 1 }
    private var l: L10n { L10n(appLanguage) }
    private var currentTreeLevel: Int { treeManager.treeLevel.rawValue }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    rootHeader
                        .padding(.top, 10)

                    GrowthUnlockProgressCard(
                        currentLevel: currentTreeLevel,
                        progressToNextLevel: treeManager.progressToNextLevel,
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
                                    title: group.title,
                                    status: compactSubtitle(for: subtitle(for: group)),
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
            ),
            ToolEntry(
                id: "insights",
                title: l.tr(zh: "高级洞察", en: "Advanced Insights", de: "Erweiterte Einsichten"),
                subtitle: l.tr(zh: "趋势 · 异常", en: "Trends · Signals", de: "Trends · Signale"),
                icon: "chart.xyaxis.line",
                color: Color(hex: "06B6D4"),
                destination: .careLedgerAnalysis
            ),
            ToolEntry(
                id: "report",
                title: l.tr(zh: "成长回顾", en: "Growth Review", de: "Wachstumsrückblick"),
                subtitle: l.tr(zh: "周报 · 归档", en: "Reports · Archive", de: "Berichte · Archiv"),
                icon: "book.closed.fill",
                color: Color(hex: "EC4899"),
                destination: .familyWeeklyReport
            )
        ]
        .filter { AppFeatureRouteGuard.isVisibleFunctionDestination($0.destination, currentLevel: currentTreeLevel) }
    }

    private func subtitle(for group: FeatureGroup) -> String {
        switch group {
        case .dailyCare:
            return hasDogs ? "饮食 · 清洁 · 遛狗 · 便便" : "饮食 · 清洁 · 便便"
        case .healthBody:
            return "健康档案 · 用药 · 体重"
        case .archiveMemory:
            return "成长 · 基本信息 · 证件 · 时刻"
        case .householdHub:
            return showsFamilyCollaboration
                ? "花费 · 照护分析 · 提醒 · 周报"
                : "花费 · 照护分析 · 提醒"
        case .oasisRewards:
            return "\(wealthSubtitle) · 商店 · 扭蛋"
        case .plants:
            return l.tr(zh: "当前版本暂不开放", en: "Hidden for this version", de: "In dieser Version verborgen")
        }
    }

    private var hasDogs: Bool {
        activePets.contains { $0.species.localizedCaseInsensitiveContains("狗") || $0.species.localizedCaseInsensitiveContains("dog") }
    }

    private var wealthSubtitle: String {
        "总资产 \(QuestManager.shared.coconutCount)🥥"
    }

    private func compactSubtitle(for subtitle: String) -> String {
        if subtitle.contains("待完成") || subtitle.contains("任务") {
            return subtitle.components(separatedBy: " · ").first ?? subtitle
        }
        if subtitle.contains("全家庭") { return "全家" }
        if subtitle.contains("椰子") { return "椰子" }
        if subtitle.contains("提醒") { return "提醒" }
        if subtitle.contains("花费") { return "花费" }
        return subtitle.components(separatedBy: " · ").first ?? subtitle
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaFunctionalIcon)
                    Spacer()
                    Image(systemName: "chevron.right")
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
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
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
