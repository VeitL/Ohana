import SwiftUI
import SwiftData

struct FunctionMenuRootView: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome } }
    private var showsFamilyCollaboration: Bool { visibleHumans.count > 1 }
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    rootHeader
                        .padding(.top, 10)

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
                                    status: compactSubtitle(for: subtitle(for: group))
                                ) {
                                    onSelect(.featureGroup(group))
                                }
                            }
                        }
                    }

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
                                    status: compactSubtitle(for: entry.subtitle)
                                ) {
                                    onSelect(entry.destination)
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
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 36, height: 36)

            Text(l.tr(zh: "更多功能", en: "More", de: "Mehr"))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var functionMenuGroups: [FeatureGroup] {
        [.dailyCare, .healthBody, .archiveMemory, .householdHub]
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var toolEntries: [ToolEntry] {
        [
            ToolEntry(
                id: "wealth",
                title: "总资产",
                subtitle: wealthSubtitle,
                icon: "creditcard.fill",
                color: Color(hex: "EAB308"),
                destination: .wealthDashboard
            ),
            ToolEntry(
                id: "plants",
                title: "植物",
                subtitle: plantsSubtitle,
                icon: "leaf.fill",
                color: Color(hex: "22C55E"),
                destination: .plantsDashboard
            )
        ]
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
            return plantsSubtitle
        }
    }

    private var hasDogs: Bool {
        activePets.contains { $0.species.localizedCaseInsensitiveContains("狗") || $0.species.localizedCaseInsensitiveContains("dog") }
    }

    private var plantsSubtitle: String {
        if plants.isEmpty { return "暂无植物 · 点击添加" }
        let thirsty = plants.filter { $0.needsWatering }.count
        if thirsty > 0 { return "\(plants.count)种 · \(thirsty)种需浇水" }
        return "\(plants.count)种植物"
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

    private func menuTile(icon: String, iconColor: Color, title: String, status: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.ohanaFunctionalIcon)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.goPrimary.opacity(0.8))
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(label)
                .font(.system(size: 9, weight: .bold))
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
