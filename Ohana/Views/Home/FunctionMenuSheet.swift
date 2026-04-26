// FunctionMenuSheet.swift
// GO Focus UI — 左上角功能菜单，跨宠物聚合所有功能入口

import SwiftUI
import SwiftData

// MARK: - Navigation Destination Enum (internal — shared with FeatureAggregateView & PetAllFeaturesSheet)

enum FMDest: Hashable {
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

    @State private var path = NavigationPath()
    // Stub binding for PlantDashboardView (full navigation into plant detail happens via its own sheet)
    @State private var plantRouteStub: Plant?

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    // ── Section 1: 健康管理 ──
                    Section {
                        fmRow(icon: "cross.fill", iconColor: Color(hex: "EF4444"),
                              title: "健康档案", subtitle: healthSubtitle) {
                            path.append(FMDest.featureAggregate(.health))
                        }
                        fmRow(icon: "scalemass.fill", iconColor: Color(hex: "16A34A"),
                              title: "体重记录", subtitle: weightSubtitle) {
                            path.append(FMDest.featureAggregate(.weight))
                        }
                        fmRow(icon: PetFeature.medications.icon, iconColor: Color(hex: "8B5CF6"),
                              title: PetFeature.medications.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.medications))
                        }
                    } header: {
                        fmSectionHeader(icon: "cross.fill", title: "健康管理", label: "HEALTH")
                    }
                    .listRowBackground(rowBackground)

                    // ── Section 2: 日常生活 ──
                    Section {
                        fmRow(icon: PetFeature.food.icon, iconColor: Color(hex: "F59E0B"),
                              title: PetFeature.food.title, subtitle: foodSubtitle) {
                            path.append(FMDest.featureAggregate(.food))
                        }
                        fmRow(icon: PetFeature.hygiene.icon, iconColor: Color(hex: "06B6D4"),
                              title: PetFeature.hygiene.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.hygiene))
                        }
                        if hasDogs {
                            fmRow(icon: PetFeature.walks.icon, iconColor: Color(hex: "0EA5E9"),
                                  title: PetFeature.walks.title, subtitle: walkSubtitle) {
                                path.append(FMDest.featureAggregate(.walks))
                            }
                        }
                        fmRow(icon: PetFeature.potty.icon, iconColor: Color(hex: "D97706"),
                              title: PetFeature.potty.title, subtitle: pottySubtitle) {
                            path.append(FMDest.featureAggregate(.potty))
                        }
                        fmRow(icon: "creditcard.fill", iconColor: Color(hex: "D97706"),
                              title: "花费记录", subtitle: expenseSubtitle) {
                            path.append(FMDest.featureAggregate(.expense))
                        }
                    } header: {
                        fmSectionHeader(icon: "sun.max.fill", title: "日常生活", label: "DAILY LIFE")
                    }
                    .listRowBackground(rowBackground)

                    // ── Section 3: 植物与绿洲 ──
                    Section {
                        fmRow(icon: "leaf.fill", iconColor: Color(hex: "22C55E"),
                              title: "植物管理", subtitle: plantsSubtitle) {
                            path.append(FMDest.plantsDashboard)
                        }
                    } header: {
                        fmSectionHeader(icon: "leaf.fill", title: "植物与绿洲", label: "GARDEN")
                    }
                    .listRowBackground(rowBackground)

                    // ── Section 4: 档案与记忆 ──
                    Section {
                        fmRow(icon: PetFeature.retention.icon, iconColor: Color(hex: "C8FF00"),
                              title: PetFeature.retention.title, subtitle: retentionSubtitle) {
                            path.append(FMDest.featureAggregate(.retention))
                        }
                        fmRow(icon: PetFeature.basicInfo.icon, iconColor: Color(hex: "6B82C4"),
                              title: PetFeature.basicInfo.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.basicInfo))
                        }
                        fmRow(icon: PetFeature.documents.icon, iconColor: Color(hex: "6B7280"),
                              title: PetFeature.documents.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.documents))
                        }
                        fmRow(icon: PetFeature.moments.icon, iconColor: Color(hex: "C8FF00"),
                              title: PetFeature.moments.title, subtitle: momentsSubtitle) {
                            path.append(FMDest.featureAggregate(.moments))
                        }
                        fmRow(icon: PetFeature.achievements.icon, iconColor: Color(hex: "F59E0B"),
                              title: PetFeature.achievements.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.achievements))
                        }
                    } header: {
                        fmSectionHeader(icon: "folder.fill", title: "档案与记忆", label: "ARCHIVE")
                    }
                    .listRowBackground(rowBackground)

                    // ── Section 5: 家庭岛屿 ──
                    Section {
                        fmRow(icon: "chart.pie.fill", iconColor: Color(hex: "EAB308"),
                              title: "岛屿财富", subtitle: wealthSubtitle) {
                            path.append(FMDest.wealthDashboard)
                        }
                        fmRow(icon: "megaphone.fill", iconColor: Color(hex: "EF4444"),
                              title: "家庭悬赏榜", subtitle: bountySubtitle) {
                            path.append(FMDest.bountyBoard)
                        }
                        fmRow(icon: "chart.bar.doc.horizontal", iconColor: Color(hex: "38BDF8"),
                              title: "家庭周报", subtitle: weeklyReportSubtitle) {
                            path.append(FMDest.familyWeeklyReport)
                        }
                        fmRow(icon: "list.bullet.rectangle.portrait.fill", iconColor: Color(hex: "C8FF00"),
                              title: "照护账本分析", subtitle: ledgerSubtitle) {
                            path.append(FMDest.careLedgerAnalysis)
                        }
                        fmRow(icon: "bell.badge.fill", iconColor: Color(hex: "F59E0B"),
                              title: "提醒健康", subtitle: "权限 · 队列 · 失败补偿") {
                            path.append(FMDest.reminderObservability)
                        }
                        fmRow(icon: "bag.fill", iconColor: Color(hex: "F472B6"),
                              title: "椰子商店", subtitle: shopSubtitle) {
                            path.append(FMDest.coconutShop)
                        }
                        fmRow(icon: "sparkles", iconColor: Color(hex: "A78BFA"),
                              title: "欧气扭蛋机", subtitle: "30🥥 / 次 · 随机奖励") {
                            path.append(FMDest.gacha)
                        }
                        fmRow(icon: "calendar", iconColor: Color(hex: "38BDF8"),
                              title: "岛屿日历", subtitle: "行程 · 提醒 · 纪念日") {
                            path.append(FMDest.calendar)
                        }
                    } header: {
                        fmSectionHeader(icon: "globe.asia.australia.fill", title: "家庭岛屿", label: "ISLAND")
                    }
                    .listRowBackground(rowBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("所有功能")
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

    // MARK: - Destination Views

    @ViewBuilder
    private func fmDestinationView(_ dest: FMDest) -> some View {
        switch dest {
        case .featureAggregate(let feature):
            FeatureAggregateView(feature: feature, parentPath: $path)
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
