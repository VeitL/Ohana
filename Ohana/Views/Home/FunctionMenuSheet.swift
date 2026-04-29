// FunctionMenuSheet.swift
// GO Focus UI — 左上角功能菜单，跨宠物聚合所有功能入口

import SwiftUI
import SwiftData

// MARK: - Navigation Destination Enum (internal — shared with FeatureAggregateView & PetAllFeaturesSheet)

enum FeatureGroup: String, Hashable, CaseIterable {
    // Top-level information architecture (post-2026-04 IA refactor):
    //   • dailyCare      — 每日照护：饮食 / 清洁 / 遛狗 / 便便 / 玩耍
    //   • healthBody     — 健康：健康档案 / 用药 / 体重
    //   • archiveMemory  — 成长档案：单一聚合入口 (PetRetentionHub)；
    //                      子页（基本信息 / 证件 / 重要时刻 / 成就）只能通过 hub 访问
    //   • householdHub   — 家：花费记录 / 照护分析 / 提醒 / 悬赏榜 / 家庭周报
    //                      (合并自旧 financeLedger + familyCollab)
    //   • oasisRewards / plants — 保留 case，供深链或未来菜单使用
    case dailyCare
    case healthBody
    case archiveMemory
    case householdHub
    case oasisRewards
    case plants

    var title: String {
        switch self {
        case .dailyCare:     return "每日照护"
        case .healthBody:    return "健康"
        case .archiveMemory: return "成长档案"
        case .householdHub:  return "家庭事务"
        case .oasisRewards:  return "绿洲奖励"
        case .plants:        return "植物"
        }
    }

    var icon: String {
        switch self {
        case .dailyCare:     return "sun.max.fill"
        case .healthBody:    return "cross.fill"
        case .archiveMemory: return "folder.fill"
        case .householdHub:  return "house.fill"
        case .oasisRewards:  return "globe.asia.australia.fill"
        case .plants:        return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .dailyCare:     return Color(hex: "F59E0B")
        case .healthBody:    return Color(hex: "EF4444")
        case .archiveMemory: return Color(hex: "C8FF00")
        case .householdHub:  return Color(hex: "38BDF8")
        case .oasisRewards:  return Color(hex: "EAB308")
        case .plants:        return Color(hex: "22C55E")
        }
    }
}

enum FMDest: Hashable {
    case featureGroup(FeatureGroup)
    case featureAggregate(PetFeature)
    case petHealth(PersistentIdentifier)
    case petMedications(PersistentIdentifier)
    case petFood(PersistentIdentifier)
    case petHygiene(PersistentIdentifier)
    case petWalks(PersistentIdentifier)
    case petPotty(PersistentIdentifier)
    case petBasicInfo(PersistentIdentifier)
    case petDocuments(PersistentIdentifier)
    case petMoments(PersistentIdentifier)
    case petAchievements(PersistentIdentifier)
    case petRetention(PersistentIdentifier)
    case petWeight(PersistentIdentifier)
    case petExpense(PersistentIdentifier)
    case humanWeight(PersistentIdentifier)
    case humanExpense(PersistentIdentifier)
    // Island-wide destinations (not per-pet)
    case plantsDashboard
    case wealthDashboard
    case bountyBoard
    case familyWeeklyReport
    case careLedgerAnalysis
    case reminderObservability
    case coconutShop
    case gacha
    case calendar
}

enum PetFeature: String, Hashable, CaseIterable {
    case health, medications, food, hygiene, walks, potty
    case retention, basicInfo, documents, moments, achievements
    case weight, expense

    var title: String {
        switch self {
        case .health:        return "健康档案"
        case .medications:   return "用药管理"
        case .food:          return "饮食管理"
        case .hygiene:       return "清洁护理"
        case .walks:         return "遛狗记录"
        case .potty:         return "便便记录"
        case .retention:     return "成长档案"
        case .basicInfo:     return "基本信息"
        case .documents:     return "证件保障"
        case .moments:       return "重要时刻"
        case .achievements:  return "成就"
        case .weight:        return "体重记录"
        case .expense:       return "花费记录"
        }
    }
    var icon: String {
        switch self {
        case .health:        return "cross.fill"
        case .medications:   return "pills.fill"
        case .food:          return "fork.knife"
        case .hygiene:       return "bubbles.and.sparkles.fill"
        case .walks:         return "figure.walk"
        case .potty:         return "drop.fill"
        case .retention:     return "sparkles.rectangle.stack.fill"
        case .basicInfo:     return "person.fill"
        case .documents:     return "doc.fill"
        case .moments:       return "sparkles"
        case .achievements:  return "trophy.fill"
        case .weight:        return "scalemass.fill"
        case .expense:       return "creditcard.fill"
        }
    }
}

// MARK: - Main Sheet

struct FunctionMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var allHumans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Bindable private var questMgr = QuestManager.shared

    let initialDestination: FMDest?
    @State private var path = NavigationPath()
    @State private var didOpenInitialDestination = false
    // Stub binding for PlantDashboardView (full navigation into plant detail happens via its own sheet)
    @State private var plantRouteStub: Plant?

    init(initialDestination: FMDest? = nil) {
        self.initialDestination = initialDestination
    }

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { allHumans.filter { $0.shouldShowOnHome } }
    private var showsFamilyCollaboration: Bool { visibleHumans.count > 1 }

    /// 当 FAB 直达到这些目的地之一时，跳过根列表，直接以该目的地作为 NavigationStack 根视图，
    /// 避免出现「先闪一下菜单列表再 push」的视觉跳动。
    /// pet/human 特定的 destination（带 PersistentIdentifier）继续走 onAppear 的 path.append 路径。
    private var directLandingDestination: FMDest? {
        guard let dest = initialDestination else { return nil }
        switch dest {
        case .featureGroup,
             .featureAggregate,
             .calendar,
             .bountyBoard,
             .familyWeeklyReport,
             .careLedgerAnalysis,
             .reminderObservability,
             .coconutShop,
             .gacha,
             .wealthDashboard,
             .plantsDashboard:
            return dest
        default:
            return nil
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            if let landing = directLandingDestination {
                fmDestinationView(landing)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { dismiss() }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.goLime)
                        }
                    }
                    .navigationDestination(for: FMDest.self) { dest in
                        fmDestinationView(dest)
                    }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    List {
                        Section {
                            ForEach(functionMenuGroups, id: \.self) { group in
                                fmRow(icon: group.icon, iconColor: group.color,
                                      title: group.title, subtitle: subtitle(for: group)) {
                                    path.append(destination(for: group))
                                }
                            }
                        } header: {
                            fmSectionHeader(icon: "square.grid.2x2.fill", title: "聚合功能", label: "FUNCTIONS")
                        }
                        .listRowBackground(rowBackground)

                        Section {
                            ForEach(toolEntries, id: \.id) { entry in
                                fmRow(icon: entry.icon, iconColor: entry.color,
                                      title: entry.title, subtitle: entry.subtitle) {
                                    path.append(entry.destination)
                                }
                            }
                        } header: {
                            fmSectionHeader(icon: "wrench.and.screwdriver.fill", title: "工具与奖励", label: "TOOLS")
                        }
                        .listRowBackground(rowBackground)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
                .navigationTitle("更多功能")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.goLime)
                    }
                }
                .navigationDestination(for: FMDest.self) { dest in
                    fmDestinationView(dest)
                }
            }
        }
        .onAppear {
            // 直达 destination 已作为 NavigationStack 根视图渲染，无需再 push
            guard directLandingDestination == nil else { return }
            guard !didOpenInitialDestination, let initialDestination else { return }
            didOpenInitialDestination = true
            DispatchQueue.main.async {
                path.append(initialDestination)
            }
        }
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func fmDestinationView(_ dest: FMDest) -> some View {
        switch dest {
        case .featureGroup(let group):
            FeatureGroupDashboardView(group: group, parentPath: $path)
        case .featureAggregate(let feature):
            FeatureAggregateView(feature: feature, parentPath: $path, showsEntityChips: false)
        case .petHealth(let id):
            if let p = pet(for: id) { PetHealthDetailView(pet: p, isModal: false) }
        case .petMedications(let id):
            if let p = pet(for: id) { PetMedicationView(pet: p) }
        case .petFood(let id):
            if let p = pet(for: id) { PetFoodManagementView(pet: p) }
        case .petHygiene(let id):
            if let p = pet(for: id) { PetHygieneDetailView(pet: p) }
        case .petWalks(let id):
            if let p = pet(for: id) { WalkSummarySheet(pet: p) }
        case .petPotty(let id):
            if let p = pet(for: id) { PottyOverviewView(pet: p) }
        case .petBasicInfo(let id):
            if let p = pet(for: id) { PetBasicInfoDetailView(pet: p) }
        case .petDocuments(let id):
            if let p = pet(for: id) { DocumentsListView(pet: p) }
        case .petMoments(let id):
            if let p = pet(for: id) { PetMomentsHubView(pet: p) }
        case .petAchievements(let id):
            if let p = pet(for: id) { AchievementWallView(pet: p) }
        case .petRetention(let id):
            if let p = pet(for: id) { PetRetentionHubView(pet: p) }
        case .petWeight(let id):
            if let p = pet(for: id) { WeightHistoryView(pet: p) }
        case .petExpense(let id):
            if let p = pet(for: id) { ExpenseHistoryView(pet: p) }
        case .humanWeight(let id):
            if let h = human(for: id) { HumanWeightHistoryView(human: h) }
        case .humanExpense(let id):
            if let h = human(for: id) { HumanExpenseDetailView(human: h) }
        case .plantsDashboard:
            PlantDashboardView(selectedPlant: $plantRouteStub)
        case .wealthDashboard:
            IslandWealthDashboardView()
        case .bountyBoard:
            BountyBoardView()
        case .familyWeeklyReport:
            FamilyWeeklyReportDashboardView()
        case .careLedgerAnalysis:
            CareLedgerAnalysisView()
        case .reminderObservability:
            ReminderObservabilityView()
        case .coconutShop:
            CoconutShopView()
        case .gacha:
            GachaView()
        case .calendar:
            CalendarView()
        }
    }

    private func pet(for id: PersistentIdentifier) -> Pet? {
        pets.first { $0.persistentModelID == id }
    }

    private func human(for id: PersistentIdentifier) -> Human? {
        allHumans.first { $0.persistentModelID == id }
    }

    // MARK: - Function Groups

    private var functionMenuGroups: [FeatureGroup] {
        // 4 主分组（不再随家人数量条件插入；「家」hub 内部自行决定是否展示悬赏/周报）
        [.dailyCare, .healthBody, .archiveMemory, .householdHub]
    }

    private func destination(for group: FeatureGroup) -> FMDest {
        .featureGroup(group)
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
                ? "花费 · 照护分析 · 提醒 · 悬赏 · 周报"
                : "花费 · 照护分析 · 提醒"
        case .oasisRewards:
            return "\(wealthSubtitle) · 商店 · 扭蛋"
        case .plants:
            return plantsSubtitle
        }
    }

    // MARK: - Tools / Rewards Section

    private struct ToolEntry: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let destination: FMDest
    }

    private var toolEntries: [ToolEntry] {
        [
            ToolEntry(id: "wealth", title: "总资产",
                      subtitle: wealthSubtitle,
                      icon: "creditcard.fill", color: Color(hex: "EAB308"),
                      destination: .wealthDashboard),
            ToolEntry(id: "shop", title: "商店",
                      subtitle: shopSubtitle,
                      icon: "bag.fill", color: Color(hex: "F472B6"),
                      destination: .coconutShop),
            ToolEntry(id: "gacha", title: "扭蛋",
                      subtitle: "随机奖励 · 限定皮肤",
                      icon: "gift.fill", color: Color(hex: "C084FC"),
                      destination: .gacha),
            ToolEntry(id: "plants", title: "植物",
                      subtitle: plantsSubtitle,
                      icon: "leaf.fill", color: Color(hex: "22C55E"),
                      destination: .plantsDashboard)
        ]
    }

    // MARK: - Aggregate Subtitles

    private var healthSubtitle: String {
        let total = activePets.flatMap { $0.healthLogs }.count
        return total > 0 ? "\(total)条健康记录" : "\(activePets.count)只宠物"
    }
    private var weightSubtitle: String {
        let total = activePets.flatMap { $0.weightLogs }.count
        return total > 0 ? "\(total)条体重记录" : "\(activePets.count)只宠物"
    }
    private var foodSubtitle: String {
        let todayLogs = activePets.flatMap { $0.careLogs }.filter {
            $0.careType == .feeding && Calendar.current.isDateInToday($0.date)
        }
        return todayLogs.isEmpty ? "今日未喂食" : "今日喂食\(todayLogs.count)次"
    }
    private var walkSubtitle: String {
        let dogs = activePets.filter { $0.species.lowercased().contains("狗") || $0.species.lowercased().contains("dog") }
        return "\(dogs.count)只犬"
    }
    private var pottySubtitle: String {
        let todayLogs = activePets.flatMap { $0.pottyLogs }.filter {
            Calendar.current.isDateInToday($0.date)
        }
        return todayLogs.isEmpty ? "今日暂无记录" : "今日\(todayLogs.count)次"
    }
    private var expenseSubtitle: String {
        let total = activePets.flatMap { $0.expenseLogs }.count
        return total > 0 ? "\(total)条花费记录" : "\(activePets.count)只宠物"
    }
    private var momentsSubtitle: String {
        let total = activePets.map { $0.photoLogs.count }.reduce(0, +)
        return total > 0 ? "\(total)个时刻" : "\(activePets.count)只宠物"
    }
    private var retentionSubtitle: String {
        let petsWithArchive = activePets.filter {
            !$0.weightLogs.isEmpty || !$0.photoLogs.isEmpty || !$0.expenseLogs.isEmpty || !$0.documents.isEmpty || !$0.insurances.isEmpty
        }.count
        return petsWithArchive > 0 ? "\(petsWithArchive)只宠物已有成长档案" : "健康 · 相册 · 花费 · 保障 · 成就"
    }
    private var hasDogs: Bool {
        activePets.contains { $0.species.lowercased().contains("狗") || $0.species.lowercased().contains("dog") }
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
    private var bountySubtitle: String {
        let all = BountyTask.loadAll()
        let pending = all.filter { !$0.isCompleted }.count
        if pending > 0 { return "\(pending) 个待完成任务" }
        return "暂无悬赏 · 发布或接单"
    }
    private var shopSubtitle: String {
        "消耗椰子 · 特效 / 称号 / 加成"
    }
    private var weeklyReportSubtitle: String {
        "全家庭 · 多宠物 · 成员排行"
    }
    private var ledgerSubtitle: String {
        "谁做了什么 · 提醒与奖励流水"
    }

    // MARK: - Row / Header Builders

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.07))
    }

    @ViewBuilder
    private func fmRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    @ViewBuilder
    private func fmSectionHeader(icon: String, title: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.goLime.opacity(0.8))
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.goLime.opacity(0.6))
                .tracking(2)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Shared Pet Avatar (used by FeatureAggregateView & PetAllFeaturesSheet)

struct FMPetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: pet.themeColorHex.isEmpty ? "233BFF" : pet.themeColorHex).opacity(0.3))
                .frame(width: size, height: size)
            if let data = pet.avatarImageData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(String(pet.name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: pet.themeColorHex.isEmpty ? "233BFF" : pet.themeColorHex))
            }
        }
    }
}
