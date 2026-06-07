import SwiftUI
import SwiftData

struct FunctionMenuRootView: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    @State private var treeManager = OasisTreeManager.shared
    @State private var lockedStatus: GrowthUnlockStatus?
    @State private var ruleStatus: GrowthUnlockStatus?

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

                    if let lockedStatus {
                        lockedCallout(lockedStatus)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            icon: "square.grid.2x2.fill",
                            title: l.tr(zh: "功能", en: "Features", de: "Funktionen"),
                            label: "CORE"
                        )

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(functionMenuGroups, id: \.self) { group in
                                let unlock = GrowthUnlockPolicy.status(for: group, currentLevel: currentTreeLevel)
                                menuTile(
                                    icon: group.icon,
                                    iconColor: group.color,
                                    title: group.title,
                                    status: compactSubtitle(for: subtitle(for: group)),
                                    unlockStatus: unlock,
                                    onInfo: {
                                        presentUnlockRules(unlock)
                                    }
                                ) {
                                    select(.featureGroup(group), unlock: unlock)
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
                                let unlock = GrowthUnlockPolicy.status(for: entry.destination, currentLevel: currentTreeLevel)
                                menuTile(
                                    icon: entry.icon,
                                    iconColor: entry.color,
                                    title: entry.title,
                                    status: compactSubtitle(for: entry.subtitle),
                                    unlockStatus: unlock,
                                    onInfo: {
                                        presentUnlockRules(unlock)
                                    }
                                ) {
                                    select(entry.destination, unlock: unlock)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $ruleStatus) { status in
            GrowthUnlockRulesSheet(
                status: status,
                appLanguage: appLanguage,
                onClose: { ruleStatus = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

            Text("Lv.\(currentTreeLevel)")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.goPrimary, in: Capsule())

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

    private func select(_ destination: FMDest, unlock: GrowthUnlockStatus) {
        guard unlock.isUnlocked else {
            OhanaFeedback.light()
            withAnimation(GoMotion.feedback) {
                lockedStatus = unlock
            }
            return
        }
        lockedStatus = nil
        onSelect(destination)
    }

    private func presentUnlockRules(_ status: GrowthUnlockStatus) {
        ruleStatus = status
    }

    private func menuTile(
        icon: String,
        iconColor: Color,
        title: String,
        status: String,
        unlockStatus: GrowthUnlockStatus,
        onInfo: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(unlockStatus.isUnlocked ? Color.ohanaFunctionalIcon : Color.ohanaTertiaryText)
                        Spacer()
                        Image(systemName: unlockStatus.isUnlocked ? "chevron.right" : "lock.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(unlockStatus.isUnlocked ? Color.ohanaSecondaryText.opacity(0.6) : iconColor)
                            .padding(.trailing, unlockStatus.isUnlocked ? 0 : 30)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(unlockStatus.isUnlocked ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(unlockStatus.isUnlocked ? status : lockedSubtitle(unlockStatus))
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

            if !unlockStatus.isUnlocked {
                GrowthUnlockRuleInfoButton(
                    status: unlockStatus,
                    appLanguage: appLanguage,
                    onTap: onInfo
                )
                .padding(.top, 2)
                .padding(.trailing, 2)
                .zIndex(2)
            }
        }
    }

    private func lockedCallout(_ status: GrowthUnlockStatus) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(hex: status.step.tintHex))
                .frame(width: 30, height: 30)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(status.step.title(language: appLanguage))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(status.step.detail(language: appLanguage))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            GrowthUnlockRuleInfoButton(
                status: status,
                appLanguage: appLanguage,
                onTap: { presentUnlockRules(status) }
            )

            Text("Lv.\(status.step.requiredLevel)")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.goPrimary, in: Capsule())
        }
        .frame(minHeight: 52)
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func lockedSubtitle(_ status: GrowthUnlockStatus) -> String {
        l.tr(
            zh: "Lv.\(status.step.requiredLevel) 解锁",
            en: "Unlocks at Lv.\(status.step.requiredLevel)",
            de: "Ab Lv.\(status.step.requiredLevel)"
        )
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
