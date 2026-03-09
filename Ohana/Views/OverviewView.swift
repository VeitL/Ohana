//
//  OverviewView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct OverviewView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \Household.createdAt) private var households: [Household]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    
    @State private var showingSettings = false
    @State private var showingAddEntity = false
    @State private var showingCalendar = false
    @State private var showingCrewRoster = false
    @State private var selectedDockTab: Int = 0
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var showingManageSheet = false
    @State private var pressedActionId: String? = nil
    @State private var deckResetFlip: Bool = false
    @State private var pendingActionId: String? = nil
    @State private var showingPetPicker = false
    @State private var showingAddQuickAction = false
    @State private var showIslandWeight = false
    @State private var showIslandExpense = false
    @State private var showIslandExplore = false
    @State private var showingAllFoodManagement = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    // 首页 section 可见性
    @AppStorage("home_section_order") private var sectionOrderRaw: String = "batchCheckIn,quickAccess,islandStats,todayTasks"
    @AppStorage("home_section_hidden") private var hiddenSectionsRaw: String = ""
    private var hiddenSections: Set<String> { Set(hiddenSectionsRaw.split(separator: ",").map(String.init)) }
    private var sectionOrder: [String] { sectionOrderRaw.split(separator: ",").map(String.init) }
    // Quick action 额外弹窗
    @State private var quickWeightPet: Pet? = nil   // 快速添加体重
    @State private var quickWeightValue: String = ""
    @State private var quickWalkPet: Pet? = nil     // 快速开始遛狗
    @State private var actionToast: (pet: Pet, message: String, emoji: String)? = nil  // N6: 打卡反馈 toast
    // Task31: Quick Access 长按导航
    @State private var quickAccessFoodPet: Pet? = nil
    @State private var quickAccessCarePet: Pet? = nil
    // task46: 喂食/喂水长按弹窗
    @State private var feedSheetItem: (pet: Pet, actionType: String)? = nil
    // 花费快速记录
    @State private var quickExpensePet: Pet? = nil
    // 任务三/五：批量打卡 + 自定义
    @State private var batchCheckInToast: String? = nil
    @State private var showingBatchCheckInSheet = false
    @AppStorage("customBatchActions") private var customBatchActionsJSON: String = ""
    @AppStorage("showBatchCheckIn") private var showBatchCheckIn: Bool = false
    private var customBatchActions: [BatchAction] {
        get {
            guard !customBatchActionsJSON.isEmpty,
                  let data = customBatchActionsJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([BatchAction].self, from: data)
            else { return BatchAction.defaults }
            return arr.isEmpty ? BatchAction.defaults : arr
        }
    }
    private func saveBatchActions(_ actions: [BatchAction]) {
        if let data = try? JSONEncoder().encode(actions),
           let str = String(data: data, encoding: .utf8) {
            customBatchActionsJSON = str
        }
    }
    // task48: 日历卡片 selectedPet
    @State private var calendarFilterPet: Pet? = nil
    // U5: 每日首次打开椰子收集
    @State private var showDailyCoconut = false
    @State private var coconutFlyOut = false
    // H27fix: 里程碑投喂椰子动效
    @State private var showMilestoneCoconut = false
    // U9: 记忆碎片滑动消失
    @State private var memoryDismissed = false
    @State private var memoryDragOffset: CGFloat = 0
    // 全局椰子日志显示
    @State private var showingCoconutLog = false
    // Task2 / Bug10: 当前顶牌对应的 Pet ID（AppStorage 保证 NavigationStack 返回后不丢失）
    @AppStorage("overview_activeCritterId") private var activeCritterIdStr: String = ""
    private var activeCritterId: UUID? {
        get { UUID(uuidString: activeCritterIdStr) }
        nonmutating set { activeCritterIdStr = newValue?.uuidString ?? "" }
    }
    
    private var isSearching: Bool { !searchText.isEmpty }

    private var islandLevel: IslandLevel {
        if let h = households.first {
            return IslandProsperityEXP.level(from: h.totalProsperity)
        }
        return IslandProsperityManager.level(pets: pets)
    }

    private var currentMood: IslandMood {
        IslandMoodCalculator.calculate(pets: pets, pendingReminders: pendingReminders, plants: plants)
    }
    
    // U5: 椰子飞入右上角动画
    private func dismissDailyCoconut() {
        withAnimation(.easeIn(duration: 0.45)) {
            coconutFlyOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showDailyCoconut = false
                coconutFlyOut = false
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
    
    var body: some View {
        ZStack {
            ArkBackgroundView(level: islandLevel)

            // 岛屿天气粒子特效层（全局覆盖）
            IslandMoodWeatherView(mood: currentMood)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            if pets.isEmpty && humans.isEmpty {
                emptyStateView
            } else if isSearching {
                searchResultsView
            } else {
                // F2: tab 内容区切换
                Group {
                    switch selectedDockTab {
                    case 1: CalendarView()
                    case 2: CrewRosterOverlay(
                        onSelectPet: { pet in
                            selectedPetTab = .overview
                            selectedPet = pet
                        },
                        onSelectHuman: { human in
                            selectedHuman = human
                        }
                    )
                    case 3: OasisRewardView()
                    default: mainScrollView
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: selectedDockTab)
            }
            
            // N6: 打卡反馈 toast
            if let toast = actionToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text(toast.emoji).font(.system(size: 20))
                        Text(toast.message)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.goLime, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 100)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: actionToast != nil)
                .allowsHitTesting(false)
            }

            // U5: 每日椰子收集弹窗
            if showDailyCoconut {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                        .onTapGesture { dismissDailyCoconut() }

                    VStack(spacing: 16) {
                        Text("🥥")
                            .font(.system(size: 64))
                            .scaleEffect(coconutFlyOut ? 0.2 : 1.0)
                            .opacity(coconutFlyOut ? 0 : 1)
                            .offset(y: coconutFlyOut ? -300 : 0)
                            .offset(x: coconutFlyOut ? 120 : 0)

                        if !coconutFlyOut {
                            VStack(spacing: 6) {
                                Text("每日登录奖励 +1🥥")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("坚持照顾家人，收获更多椰子")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .transition(.opacity)

                            Button {
                                dismissDailyCoconut()
                            } label: {
                                Text("收下")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 36).padding(.vertical, 12)
                                    .background(Color.goLime, in: Capsule())
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .zIndex(9999)
                .transition(.opacity)
            }

            // Floating Dock Nav
            VStack {
                Spacer()
                FloatingDockNav(
                    selectedTab: $selectedDockTab,
                    onHome: { selectedDockTab = 0 },
                    onStats: { selectedDockTab = 1 },
                    onCrew: { selectedDockTab = 2 },
                    onOasis: { selectedDockTab = 3 }
                )
                .padding(.bottom, 20)
            }
        }
        // H27fix: 椰子爆出动效挂在页面层（SmartTodayCard本身可能已消失）
        .coconutRewardOverlay(trigger: $showMilestoneCoconut, amount: 20)
        .onAppear {
            for pet in pets {
                StreakManager.refreshStreak(for: pet, context: modelContext)
            }
            if let household = households.first {
                IslandProsperityEXP.tryAddDailyOpenEXP(household: household, context: modelContext)
            }
            // U5: 每日首次打开椰子收集
            let dailyKey = "daily_coconut_shown"
            let today = Calendar.current.startOfDay(for: Date())
            if let last = UserDefaults.standard.object(forKey: dailyKey) as? Date,
               Calendar.current.isDate(last, inSameDayAs: today) {
                // 今天已显示过
            } else if !pets.isEmpty {
                UserDefaults.standard.set(today, forKey: dailyKey)
                QuestManager.shared.addCoconuts(1, emoji: "🌅", title: "每日登录奖励")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDailyCoconut = true
                    }
                }
            }
            // F1: 迁移旧 sectionOrder，确保所有 section 都存在
            var order = sectionOrderRaw.split(separator: ",").map(String.init)
            order.removeAll { $0 == "petCards" }  // 宠物卡片不再参与排序管理
            let managedIds = ["batchCheckIn", "quickAccess", "islandStats", "todayTasks"]
            for id in managedIds where !order.contains(id) { order.append(id) }
            sectionOrderRaw = order.joined(separator: ",")
        }
        .milestoneCheck(pets: pets)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddEntity) {
            AddEntityView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        // B2: manage sheet 提升到顶层，不受 section 隐藏影响
        .sheet(isPresented: $showingManageSheet) {
            HomeSectionManageSheet()
        }
        .sheet(item: $quickWeightPet) { pet in
            QuickWeightSheet(pet: pet)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showIslandWeight) {
            IslandWeightDashboard()
        }
        .fullScreenCover(isPresented: $showIslandExpense) {
            IslandExpenseDashboard()
        }
        .fullScreenCover(isPresented: $showIslandExplore) {
            IslandExplorationDashboard()
        }
        .sheet(isPresented: $showingAllFoodManagement) {
            AllPetsFoodOverviewSheet()
        }
        .sheet(isPresented: $showingCoconutLog) {
            CoconutLogView()
        }
    }
    
    // MARK: - Main Scroll View
    // Task3: 固定布局顺序（人体工学动线）：
    //   Greeting → MemoryDrop → Carousel → QuickAccess（拇指舒适区）→ IslandStats → SmartToday
    private var mainScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // ── 层1：问候 Header
                goGreetingHeader
                    .padding(.top, 8)

                // ── 层2：记忆碎片卡（可侧滑移出）
                if !memoryDismissed, let memory = MemoryEngine.pickFragment(pets: pets, plants: plants) {
                    MemoryDropCard(fragment: memory)
                        .padding(.horizontal, 16)
                        .offset(x: memoryDragOffset)
                        .opacity(1.0 - abs(memoryDragOffset) / 300.0)
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { val in
                                    let isH = abs(val.translation.width) > abs(val.translation.height)
                                    if isH { memoryDragOffset = val.translation.width }
                                }
                                .onEnded { val in
                                    if abs(val.translation.width) > 120 {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            memoryDragOffset = val.translation.width > 0 ? 400 : -400
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            memoryDismissed = true
                                            memoryDragOffset = 0
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3)) { memoryDragOffset = 0 }
                                    }
                                }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }

                // ── 层3引导：有Human无Pet时显示添加宠物引导卡
                if pets.isEmpty && !humans.isEmpty && !hiddenSections.contains("petCards") {
                    addFirstPetBanner
                }

                // ── 层3：3D 宠物卡牌转盘（第一视界）
                if (!pets.isEmpty || !humans.isEmpty) && !hiddenSections.contains("petCards") {
                    CritterDeckCarousel(
                        pets: pets,
                        humans: humans,
                        onSelectPet: { selectedPet = $0 },
                        onSelectHuman: { selectedHuman = $0 },
                        onTopCardChanged: { item in
                            if case .pet(let p) = item { activeCritterIdStr = p.id.uuidString }
                            else { activeCritterIdStr = "" }
                        },
                        initialTopId: activeCritterId,  // N5: 返回时恢复上次顶牌
                        resetFlip: deckResetFlip
                    )
                    .onAppear {
                        deckResetFlip.toggle()
                        // N5: 仅首次（无保存值时）初始化为第一只宠物
                        if activeCritterIdStr.isEmpty {
                            activeCritterId = pets.first?.id
                        }
                    }
                }

                // ── 层4+：按 orderedSections 驱动渲染（严格绑定排序与显隐）
                ForEach(orderedSections, id: \.self) { sectionId in
                    switch sectionId {
                    case "batchCheckIn":
                        if !hiddenSections.contains("batchCheckIn") &&
                           pets.filter({ !$0.hasPassedAway }).count > 1 {
                            batchCheckInBar
                                .padding(.horizontal, 16)
                        }
                    case "quickAccess":
                        if !hiddenSections.contains("quickAccess") {
                            quickActionsSection
                                .animation(.spring(response: 0.38, dampingFraction: 0.78),
                                           value: activeQuickActionItems.map(\.id))
                        }
                    case "islandStats":
                        if !pets.isEmpty && !hiddenSections.contains("islandStats") {
                            islandStatsBento
                        }
                    case "todayTasks":
                        if !pets.isEmpty && !hiddenSections.contains("todayTasks") {
                            let todayTask = SmartTaskEngine.topTask(pets: pets, reminders: pendingReminders)
                            if case .none = todayTask.actionTarget { } else {
                                dynamicInsightCard
                            }
                            DailyQuestsCard(
                                pets: pets,
                                reminders: pendingReminders,
                                onSelectPet: { selectedPet = $0 }
                            )
                            .padding(.horizontal, 16)
                        }
                    default:
                        EmptyView()
                    }
                }

                Spacer(minLength: 120)
            }
        }
    }

    private var orderedSections: [String] {
        let order = sectionOrder
        let allIds = ["batchCheckIn", "quickAccess", "islandStats", "todayTasks"]
        var result = order.filter { allIds.contains($0) }
        for id in allIds where !result.contains(id) { result.append(id) }
        return result
    }
    
    // MARK: - Greeting Header
    private var goGreetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(greetingText) 👋")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                if let firstPet = pets.first {
                    let hour = Calendar.current.component(.hour, from: Date())
                    let hint = hour >= 6 && hour < 10 ? "趁早晨凉爽，带 \(firstPet.name) 出去走走吧" :
                               hour >= 17 && hour < 20 ? "黄金时段，带 \(firstPet.name) 散个步吧 🌇" :
                               "\(firstPet.name) 在等你呢"
                    Text(hint)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
            HStack(spacing: 10) {
                // 全局椰子余额胶囊
                CoconutBalanceCapsule {
                    showingCoconutLog = true
                }
                
                // N8: 用户头像 → 点击展开二级菜单
                Menu {
                    Button { showingAddEntity = true } label: {
                        Label("添加成员", systemImage: "person.badge.plus")
                    }
                    Button { showingManageSheet = true } label: {
                        Label("管理主页", systemImage: "slider.horizontal.3")
                    }
                    Button { showingSettings = true } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                } label: {
                    avatarMenuLabel
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // N8: 用户头像标签（读取当前绑定 Human）
    @ViewBuilder private var avatarMenuLabel: some View {
        let boundId = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        let activeHuman = humans.first(where: { $0.id.uuidString == boundId })
        let colorHex: String = activeHuman?.themeColor ?? "4338FF"
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.3))
                .frame(width: 36, height: 36)
            if let h = activeHuman {
                Text(h.avatarEmoji)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Smart Today Card (C5 智能待办卡)
    private var dynamicInsightCard: some View {
        let task = SmartTaskEngine.topTask(pets: pets, reminders: pendingReminders)
        return SmartTodayCard(
            task: task,
            onAction: {
                switch task.actionTarget {
                case .pet(let pet): selectedPet = pet
                default: break
                }
            },
            onMilestoneRewardCompleted: {
                // H27fix: 卡片在自身层触发后立即从列表移除，所以椰子动画要在页面层触发
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showMilestoneCoconut = true
                }
            }
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Island Stats (横向滚动卡片，每张带专属图表)
    private var islandStatsBento: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ISLAND STATS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(3)
                Spacer()
                HStack(spacing: 4) {
                    Text("左滑查看更多")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
                    Image(systemName: "chevron.left.2")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // 1. 体重卡（所有宠物 分系列折线图）
                    // U11: 显示所有宠物的最新体重
                    let weightSeries = weightSeriesData
                    let totalWithWeight = weightSeries.count
                    let allLatestWeights: [(String, Double)] = pets.compactMap { p in
                        guard let w = p.weightLogs.sorted(by: { $0.date > $1.date }).first else { return nil }
                        return (p.name, w.weight)
                    }
                    let weightValueStr = allLatestWeights.isEmpty
                        ? "--"
                        : allLatestWeights.map { "\($0.0) \(String(format: "%.1f", $0.1))" }.joined(separator: " · ")
                    let weightSubtitle = totalWithWeight == 0 ? "暂无数据" : weightSeries.map { $0.0 }.joined(separator: " · ")
                    IslandStatCard(
                        icon: "scalemass.fill",
                        title: "体重",
                        value: allLatestWeights.count == 1
                            ? String(format: "%.1f", allLatestWeights[0].1)
                            : (allLatestWeights.isEmpty ? "--" : "\(allLatestWeights.count)只"),
                        unit: allLatestWeights.count == 1 ? "kg" : "",
                        subtitle: allLatestWeights.count > 1 ? weightValueStr : weightSubtitle,
                        accentColor: .goTeal,
                        avatarEmojis: (pets.map { $0.avatarEmoji } + humans.map { $0.avatarEmoji }),
                        onTap: { showIslandWeight = true }
                    ) {
                        MultiPetLineChart(series: weightSeries)
                    }

                    islandStatDivider

                    // 2. 遛狗卡（7天柱状图）
                    let weekWalkData = last7DayWalkCounts
                    let weekWalkTotal = weekWalkData.reduce(0) { $0 + $1.1 }
                    IslandStatCard(
                        icon: "figure.walk",
                        title: "全岛探索",
                        value: "\(weekWalkTotal)",
                        unit: "次",
                        subtitle: "本周合计",
                        accentColor: .goLime,
                        avatarEmojis: (pets.map { $0.avatarEmoji } + humans.map { $0.avatarEmoji }),
                        onTap: { showIslandExplore = true }
                    ) {
                        MiniBarChart(values: weekWalkData.map { Double($0.1) }, labels: weekWalkData.map { $0.0 }, accentColor: .goLime)
                    }

                    islandStatDivider

                    // 3. 本月花费（各宠物对比柱）
                    let monthTotal = pets.flatMap { $0.expenseLogs }.filter {
                        Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
                    }.reduce(0.0) { $0 + $1.amount }
                    let petExpenseSeries = petExpenseSeriesData
                    IslandStatCard(
                        icon: "yensign.circle.fill",
                        title: "本月花费",
                        value: "¥\(Int(monthTotal))",
                        unit: "",
                        subtitle: petExpenseSeries.isEmpty ? "暂无花费" : petExpenseSeries.map { $0.0 }.joined(separator: " · "),
                        accentColor: .goYellow,
                        avatarEmojis: pets.map { $0.avatarEmoji },
                        onTap: { showIslandExpense = true }
                    ) {
                        MultiPetExpenseBar(series: petExpenseSeries)
                    }

                    // 4. 粮仓卡（进度环）
                    if let urgentPet = pets.filter({ $0.remainingFoodDays > 0 })
                        .min(by: { $0.remainingFoodDays < $1.remainingFoodDays }) {
                        let progress = min(1.0, Double(urgentPet.remainingFoodDays) / 30.0)
                        let accent: Color = urgentPet.remainingFoodDays <= 7 ? .goRed : .goOrange

                        islandStatDivider

                        IslandStatCard(
                            icon: "bag.fill",
                            title: "粮仓",
                            value: "\(urgentPet.remainingFoodDays)",
                            unit: "天",
                            subtitle: urgentPet.name,
                            accentColor: accent,
                            onTap: { showingAllFoodManagement = true }
                        ) {
                            MiniRingChart(progress: progress, accentColor: accent)
                        }
                    }

                    // Phase 49: 羁绊简报卡
                    if !pets.isEmpty || !humans.isEmpty {
                        islandStatDivider
                        SynergyFlashCard(pets: pets, humans: humans)
                    }

                    // Phase 49: 椰子财富榜
                    islandStatDivider
                    CoconutWealthRankingCard(
                        pets: pets,
                        humans: humans
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private var islandStatDivider: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 16))
            p.addLine(to: CGPoint(x: 0, y: 224))
        }
        .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .frame(width: 1, height: 240)
    }

    private var weekWalkSteps: Int {
        guard let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let walks = pets.flatMap { $0.walkLogs }.filter { $0.startDate >= weekStart }
        guard !walks.isEmpty else { return 0 }
        let totalDist = walks.reduce(0.0) { acc, w in acc + w.distanceMeters }
        let avgDist = totalDist / Double(walks.count)
        return Int(avgDist / 0.75)
    }

    private var weightSeriesData: [(String, [Double], Color)] {
        let colors: [Color] = [.goTeal, .goLime, .goYellow, Color(hex: "FF8C42"), Color(hex: "C084FC"), .goMint, .goRed]
        return pets.enumerated().compactMap { (i, p) in
            let sorted = p.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { return nil }
            return (p.name, Array(sorted.suffix(8).map { $0.weight }), colors[i % colors.count])
        }
    }

    private var petExpenseSeriesData: [(String, Double, Color)] {
        let colors: [Color] = [.goYellow, .goTeal, .goLime, Color(hex: "FF8C42"), Color(hex: "C084FC")]
        return pets.enumerated().compactMap { (i, p) in
            let amt = p.expenseLogs.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }.reduce(0.0) { $0 + $1.amount }
            guard amt > 0 else { return nil }
            return (p.name, amt, colors[i % colors.count])
        }
    }

    private var last7DayWalkCounts: [(String, Int)] {
        let cal = Calendar.current
        let days = ["M","T","W","T","F","S","S"]
        return (0..<7).map { offset -> (String, Int) in
            let date = cal.date(byAdding: .day, value: -(6 - offset), to: Date())!
            let count = pets.flatMap { $0.walkLogs }.filter { cal.isDate($0.startDate, inSameDayAs: date) }.count
            return (days[offset], count)
        }
    }

    // MARK: - Today's Tasks (紧凑行)
    private var todaysTasksSection: some View {
        let todayReminders = pendingReminders.filter { Calendar.current.isDateInToday($0.scheduledAt) }
        let allTodayCount = pendingReminders.filter { Calendar.current.isDateInToday($0.scheduledAt) }.count
        let completedToday = 0 // 可后续接实际完成数

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("Today's Tasks")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(completedToday)/\(max(allTodayCount, 1))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { showingCalendar = true } label: {
                    Text("View Plan →")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)

            // Progress bar
            if allTodayCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(height: 4)
                        Capsule().fill(Color.goLime)
                            .frame(width: geo.size.width * CGFloat(completedToday) / CGFloat(allTodayCount), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
            }

            if todayReminders.isEmpty {
                HStack(spacing: 12) {
                    Text("🎉").font(.system(size: 22))
                    Text("All tasks done! Enjoy your day.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(14)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(todayReminders.prefix(5)) { reminder in
                        CompactTaskRow(reminder: reminder)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Batch Check-In Bar（Minimalist 极简胶囊条）
    @State private var batchPressedId: String? = nil

    private var batchCheckInBar: some View {
        let livePets = pets.filter { !$0.hasPassedAway }
        let actions = customBatchActions.filter { !$0.targetPets(from: livePets).isEmpty }

        return HStack(spacing: 0) {
            // 左侧标题（固定）
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.goLime)
                Text("全家")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.leading, 12)

            // 分隔线
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 20).padding(.horizontal, 8)

            // 动作按钮协（水平滚动）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(actions, id: \.id) { action in
                        batchPillButton(action: action, livePets: livePets)
                    }
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 4)
            }

            // 右侧编辑按钮
            Button { showingBatchCheckInSheet = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: Color.goPrimary.opacity(0.12), radius: 8, x: 0, y: 3)
        .sheet(isPresented: $showingBatchCheckInSheet) {
            BatchActionEditSheet(selected: Binding(
                get: { customBatchActions },
                set: { saveBatchActions($0) }
            ))
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // 极简胶囊按钮（Minimalist 风格）
    private func batchPillButton(action: BatchAction, livePets: [Pet]) -> some View {
        let isPressed = batchPressedId == action.id
        return Button {
            let targets = action.targetPets(from: livePets)
            guard !targets.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { batchPressedId = action.id }
            action.perform(pets: targets, context: modelContext)
            showBatchToast(action.toastMessage)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { batchPressedId = nil }
            }
        } label: {
            HStack(spacing: 4) {
                Text(action.label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(isPressed ? .black : .white.opacity(0.85))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                isPressed
                    ? action.color
                    : action.color.opacity(0.22),
                in: Capsule()
            )
            .scaleEffect(isPressed ? 0.93 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isPressed)
    }

    private func batchBentoCell(action: BatchAction, livePets: [Pet]) -> some View {
        let isPressed = batchPressedId == action.id
        return Button {
            let targets = action.targetPets(from: livePets)
            guard !targets.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                batchPressedId = action.id
            }
            action.perform(pets: targets, context: modelContext)
            showBatchToast(action.toastMessage)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { batchPressedId = nil }
            }
        } label: {
            VStack(spacing: 5) {
                // 多巴胺渐变图标背景
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [action.color.opacity(isPressed ? 0.9 : 0.75),
                                         action.color.mix(with: .black, by: 0.25).opacity(isPressed ? 0.95 : 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: action.color.opacity(isPressed ? 0.7 : 0.35),
                                radius: isPressed ? 12 : 6, x: 0, y: 3)
                    Text(action.type.emoji)
                        .font(.system(size: 26))
                        .scaleEffect(isPressed ? 1.15 : 1.0)
                }
                Text(action.label)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isPressed ? action.color.opacity(0.14) : Color.white.opacity(0.04))
            )
            .scaleEffect(isPressed ? 0.93 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isPressed)
    }

    private func batchPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color, in: Capsule())
    }

    private func showBatchToast(_ msg: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35)) {
            actionToast = (pet: pets.first!, message: msg, emoji: "🥥")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { actionToast = nil }
        }
    }

    // MARK: - Quick Actions (Go UI 毛玻璃正方形网格)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("QUICK ACCESS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(3)
                Spacer()
            }
            .padding(.horizontal, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 12
            ) {
                // Task2: 按顶牌动态过滤，Spring 动画确保切换丝滑
                ForEach(activeQuickActionItems, id: \.id) { item in
                    GoQuickActionCard(
                        item: item,
                        isPressed: pressedActionId == item.id,
                        petAvatar: avatarForAction(item),
                        petThemeColorHex: themeColorForAction(item),
                        pendingReminder: reminderForAction(item),
                        countText: countTextForAction(item),
                        onTap: {
                            pressedActionId = item.id
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                pressedActionId = nil
                                handleAction(item)
                            }
                        },
                        onLongPress: {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            handleLongPressAction(item)
                        },
                        onDoubleTap: item.actionType == "litter" || item.actionType == "potty" ? {
                            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                                // 任务5：猫咪铲屎长按→护理详情；狗便便长按→食物管理
                                if item.actionType == "litter" {
                                    quickAccessCarePet = pet
                                } else {
                                    quickAccessFoodPet = pet
                                }
                            }
                        } : nil,
                        onDelete: { removeQuickAction(item) },
                        onGroomCheckIn: item.actionType == "groom" ? { hygieneTypeRaw in
                            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                                applyGroomCheckIn(hygieneTypeRaw, pet: pet)
                            }
                        } : nil,
                        onAddReminder: item.actionType == "groom" ? {
                            quickAccessCarePet = pets.first(where: { $0.id == item.petId })
                        } : nil
                    )
                }
                // + 添加新 item 按钮
                Button { showingAddQuickAction = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    .foregroundStyle(.white.opacity(0.2))
                            )
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.45))
                            Text("Add")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .frame(height: 84)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showingAddQuickAction) {
            AddQuickActionSheet(
                pets: pets,
                defaultPetId: activeCritterId,
                existingItems: savedQuickActionItems
            ) { newItem in
                addQuickAction(newItem)
            }
        }
        .sheet(item: $quickAccessFoodPet) { pet in
            PetFoodManagementView(pet: pet)
        }
        .sheet(item: $quickAccessCarePet) { pet in
            PetHygieneCard(pet: pet)
        }
        .sheet(item: $quickExpensePet) { pet in
            AddExpenseSheet(pet: pet)
                .presentationDetents([.height(460), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { feedSheetItem != nil },
            set: { if !$0 { feedSheetItem = nil } }
        )) {
            if let fi = feedSheetItem {
                QuickFeedSheet(pet: fi.pet, actionType: fi.actionType) {
                    feedSheetItem = nil
                    if let found = savedQuickActionItems.first(where: { $0.petId == fi.pet.id && $0.actionType == fi.actionType }) {
                        removeQuickAction(found)
                    }
                }
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // Task2: 根据顶牌过滤 Quick Access items（顶牌是宠物时，过滤出该宠物 + 无宠物 items；顶牌是人时显示全部）
    private var activeQuickActionItems: [QuickActionItem] {
        let all = savedQuickActionItems
        guard let activeId = activeCritterId else { return all }
        return all.filter { item in
            item.petId == nil || item.petId == activeId
        }
    }

    // Task31 / Task45: 找到该 item 对应宠物今日待办，严格按 actionType 匹配，禁止跨卡片类型溢出
    private func reminderForAction(_ item: QuickActionItem) -> Reminder? {
        guard let pid = item.petId,
              let pet = pets.first(where: { $0.id == pid }) else { return nil }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current

        // 精确 EventType（非 daily），命中即返回
        let exactTypes: Set<String> = {
            switch item.actionType {
            case "feed":    return [EventType.foodChange.rawValue]
            case "potty", "litter": return [EventType.litterBox.rawValue]
            case "bath", "groom", "hygiene": return [EventType.grooming.rawValue]
            case "health":  return [EventType.vaccine.rawValue, EventType.vetVisit.rawValue,
                                    EventType.externalDeworming.rawValue, EventType.internalDeworming.rawValue,
                                    EventType.health.rawValue]
            default:        return []
            }
        }()

        // daily/task 类型时用标题关键词做二次过滤，防止串线
        let titleKeywords: [String] = {
            switch item.actionType {
            case "feed":    return ["喂食", "吃饭", "喂"]
            case "water":   return ["喂水", "饮水", "水"]
            case "walk":    return ["遛", "散步", "运动"]
            case "potty", "litter": return ["铲屎", "排泄", "便便", "猫砂"]
            case "bath":    return ["洗澡"]
            case "groom", "hygiene": return ["护理", "梳毛", "美容"]
            case "health":  return ["疫苗", "体检", "驱虫", "健康", "就诊"]
            default:        return []
            }
        }()

        return pendingReminders.first { reminder in
            guard cal.isDateInToday(reminder.scheduledAt),
                  reminder.event?.relatedEntityId == petIdStr else { return false }
            let evType = reminder.event?.eventType ?? ""
            // 精确类型命中
            if exactTypes.contains(evType) { return true }
            // daily/task 类型需要标题关键词匹配
            if evType == EventType.daily.rawValue || evType == EventType.task.rawValue {
                let evTitle = (reminder.event?.title ?? "").lowercased()
                return titleKeywords.contains { evTitle.contains($0) }
            }
            return false
        }
    }

    // Task31 / task46-48: 长按导航到对应详情页
    private func handleLongPressAction(_ item: QuickActionItem) {
        let pet: Pet?
        if let pid = item.petId {
            pet = pets.first(where: { $0.id == pid })
        } else {
            pet = pets.first
        }
        guard let p = pet else { return }
        switch item.actionType {
        case "feed", "water":
            // task46: 长按弹出喂食量 sheet
            feedSheetItem = (pet: p, actionType: item.actionType)
        case "potty", "litter":
            // task47: 长按→排泄护理页
            quickAccessFoodPet = p
        case "health":
            // task47: 长按→健康页（单击也直达，保持一致）
            selectedPet = p
            selectedPetTab = .health
        case "hygiene", "groom", "bath":
            quickAccessCarePet = p
        case "walk":
            selectedPet = p
            selectedPetTab = .overview
        default:
            selectedPet = p
            selectedPetTab = .overview
        }
    }

    // MARK: - Quick Action Persistence
    private var savedQuickActionItems: [QuickActionItem] {
        guard !quickActionItemsJSON.isEmpty,
              let data = quickActionItemsJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return defaultQuickActionItems }
        return items
    }

    private var defaultQuickActionItems: [QuickActionItem] { [] }

    private func addQuickAction(_ item: QuickActionItem) {
        var current = savedQuickActionItems
        current.append(item)
        if let data = try? JSONEncoder().encode(current),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func removeQuickAction(_ item: QuickActionItem) {
        var current = savedQuickActionItems
        current.removeAll { $0.id == item.id }
        if let data = try? JSONEncoder().encode(current),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    // task48: 走卡/喂食卡展示今日统计数
    private func countTextForAction(_ item: QuickActionItem) -> String? {
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return nil }
        let cal = Calendar.current
        switch item.actionType {
        case "walk":
            let count = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
            let dist = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.reduce(0.0) { $0 + $1.distanceMeters }
            if count == 0 { return "今日未遛" }
            let distStr = dist >= 1000 ? String(format: "%.1fkm", dist / 1000) : String(format: "%.0fm", dist)
            return "今日 \(count)次 · \(distStr)"
        case "feed":
            let count = pet.careLogs.filter { $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "water":
            let count = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "litter":
            let count = pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "potty":
            let count = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        default:
            return nil
        }
    }

    private func avatarForAction(_ item: QuickActionItem) -> UIImage? {
        guard let pid = item.petId,
              let pet = pets.first(where: { $0.id == pid }),
              let data = pet.avatarImageData else { return nil }
        return UIImage(data: data)
    }

    private func themeColorForAction(_ item: QuickActionItem) -> String? {
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return nil }
        return pet.themeColorHex
    }

    private func handleAction(_ item: QuickActionItem) {
        switch item.actionType {
        case "calendar": showingCalendar = true
        case "add":      showingAddEntity = true
        case "health", "navigate_health":
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                selectedPet = pet
                selectedPetTab = .health
            } else if let first = pets.first {
                selectedPet = first
                selectedPetTab = .health
            }
        case "groom", "hygiene", "navigate_groom":
            // 护理卡点击由 GoQuickActionCard 内部 confirmationDialog 处理，此处仅作兜底
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                quickAccessCarePet = pet
            } else if let first = pets.first {
                quickAccessCarePet = first
            }
        case "expense":
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                quickExpensePet = pet
            } else if let first = pets.first {
                quickExpensePet = first
            }
        default:
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                applyAction(item.actionType, pet: pet)
            } else if pets.count == 1 {
                applyAction(item.actionType, pet: pets[0])
            }
        }
    }

    private func applyGroomCheckIn(_ raw: String, pet: Pet) {
        let type: HygieneType
        switch raw {
        case "bath":     type = .bath
        case "teeth":    type = .teeth
        case "nails":    type = .nails
        case "brushing": type = .brushing
        case "ears":     type = .ears
        default: return
        }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet)
        modelContext.insert(log)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let got = QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
        showToast(pet, message: "\(pet.name) \(type.rawValue)打卡 +\(got.petGot + got.humanGot)🥥", emoji: type.emoji)
    }

    private func showToast(_ pet: Pet, message: String, emoji: String, duration: Double = 1.5) {
        actionToast = (pet: pet, message: message, emoji: emoji)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { actionToast = nil }
    }

    private func applyAction(_ actionType: String, pet: Pet) {
        switch actionType {
        case "walk":
            let mgr = PetWalkingManager.shared
            if case .idle = mgr.phase {
                mgr.start(pet: pet)
                deckResetFlip = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { deckResetFlip = true }
                showToast(pet, message: "开始遛 \(pet.name)！", emoji: "🦮", duration: 2.0)
            } else {
                selectedDockTab = 0
            }
        case "weight":
            quickWeightValue = ""
            quickWeightPet = pet
        case "health":
            // task47: 单击直接进入健康页
            selectedPetTab = .health
            selectedPet = pet
        case "hygiene", "groom":
            selectedPetTab = .health
            selectedPet = pet
        case "potty":
            let eid0 = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: eid0)
            modelContext.insert(log)
            if let h = households.first {
                IslandProsperityEXP.addEXP(source: .potty, household: h, context: modelContext)
            }
            let pottyGot = QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 便便打卡 +\(pottyGot.petGot + pottyGot.humanGot)🥥", emoji: "💩")
        case "litter":
            let eidL = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            let litterLog = PetCareLog(date: Date(), type: .litter, pet: pet, executorId: eidL)
            modelContext.insert(litterLog)
            if let h = households.first {
                IslandProsperityEXP.addEXP(source: .potty, household: h, context: modelContext)
            }
            let litterGot = QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 铲猫砂 +\(litterGot.humanGot)🥥", emoji: "🧹")
        case "feed":
            let eid1 = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            let log = PetCareLog(date: Date(), type: .feeding, amountGrams: pet.dailyPortionGrams, pet: pet, executorId: eid1)
            modelContext.insert(log)
            QuestManager.shared.recordFirstMeal()
            let feedGot = QuestManager.shared.awardAction(type: .feed, pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 喂食打卡 +\(feedGot.petGot + feedGot.humanGot)🥥", emoji: "🍗")
        case "water":
            let eid2 = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            let log = PetCareLog(date: Date(), type: .watering, amountGrams: 0, pet: pet, executorId: eid2)
            modelContext.insert(log)
            let waterGot = QuestManager.shared.awardAction(type: .water, pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 喂水打卡 +\(waterGot.petGot + waterGot.humanGot)🥥", emoji: "💧")
        case "bath":
            let log = PetHygieneLog(date: Date(), type: .bath, pet: pet)
            modelContext.insert(log)
            if let h = households.first {
                IslandProsperityEXP.addEXP(source: .hygiene, household: h, context: modelContext)
            }
            let bathGot = QuestManager.shared.awardAction(type: .care(type: .bath), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 洗澡打卡 +\(bathGot.petGot + bathGot.humanGot)🥥", emoji: "🛁")
        case "play":
            let eidP = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            let playLog = PetCareLog(date: Date(), type: .play, pet: pet, executorId: eidP)
            modelContext.insert(playLog)
            let oat = QuestManager.OhanaActionType.general(humanReward: 10, petReward: 12, emoji: "🎾", title: "\(pet.name) 互动奖励")
            let playGot = QuestManager.shared.awardAction(type: oat, pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 逗玩打卡 +\(playGot.petGot + playGot.humanGot)🥥", emoji: "🎾")
        default:
            selectedPetTab = .overview
            selectedPet = pet
        }
    }

    // MARK: - Legacy sections removed in Phase 59 (extracted / dead code cleanup)
    
    // MARK: - Empty State (Go UI Style)
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            // 大 Emoji 主视觉
            ZStack {
                Circle()
                    .fill(Color.goLime.opacity(0.08))
                    .frame(width: 140, height: 140)
                Circle()
                    .strokeBorder(Color.goLime.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 140, height: 140)
                Text("🏝️")
                    .font(.system(size: 64))
            }
            .padding(.bottom, 28)

            Text("欢迎来到 Ohana 岛")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("这里是你和家人的专属小岛\n还没有居民，快把第一个家人带来吧 🐾")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 32)

            // 三步引导
            VStack(spacing: 10) {
                emptyStateStep(emoji: "🐶", color: Color.goLime,
                               title: "添加宠物", subtitle: "记录它的成长与健康")
                emptyStateStep(emoji: "👨‍👩‍👧", color: Color.goMint,
                               title: "加入家庭成员", subtitle: "全家人的日历与提醒")
                emptyStateStep(emoji: "🌱", color: Color.goTeal,
                               title: "或者一株植物", subtitle: "浇水施肥不再忘记")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            Button { showingAddEntity = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .black))
                    Text("开始建岛")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.goLime, in: Capsule())
                .shadow(color: Color.goLime.opacity(0.4), radius: 16, x: 0, y: 6)
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }

    private func emptyStateStep(emoji: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(emoji).font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .goTranslucentCard(cornerRadius: 16)
    }
    
    // MARK: - Add First Pet Banner（有Human无Pet时的引导卡）
    private var addFirstPetBanner: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("🐾")
                    .font(.system(size: 56))
                Text("带你的毛孩子来！")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("添加第一只宠物，开启椰子奖励之旅")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("🥥")
                        .font(.system(size: 28))
                    Text("+10")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("添加宠物")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .goTranslucentCard(cornerRadius: 16)

                VStack(spacing: 4) {
                    Text("💩")
                        .font(.system(size: 28))
                    Text("+1")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("每次打卡")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .goTranslucentCard(cornerRadius: 16)

                VStack(spacing: 4) {
                    Text("🦮")
                        .font(.system(size: 28))
                    Text("+N")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("遛狗奖励")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .goTranslucentCard(cornerRadius: 16)
            }

            Button { showingAddEntity = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .black))
                    Text("添加第一只宠物")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.goLime, in: Capsule())
                .shadow(color: Color.goLime.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    // MARK: - Search Results (Go UI Style)
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let filteredPets = pets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                let filteredHumans = humans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                
                if !filteredPets.isEmpty {
                    Text("PETS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                        .padding(.horizontal, 16)
                    
                    ForEach(filteredPets) { pet in
                        Button { selectedPet = pet } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Text(pet.avatarEmoji)
                                        .font(.system(size: 24))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pet.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("\(pet.species) · \(pet.breed)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(12)
                            .goTranslucentCard(cornerRadius: 16)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                if !filteredHumans.isEmpty {
                    Text("FAMILY")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                        .padding(.horizontal, 16)
                    
                    ForEach(filteredHumans) { human in
                        Button { selectedHuman = human } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Text(human.avatarEmoji)
                                        .font(.system(size: 24))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(human.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(human.roleText)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(12)
                            .goTranslucentCard(cornerRadius: 16)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Sub-components extracted to:
//   Components/OverviewHelperViews.swift  (FloatingDockNav, CompactTaskRow, SwipeableReminderCard, PlantGardenCard, HomeSectionManageSheet, HomeSectionEntry, BentoStatCard, AllPetsFoodOverviewSheet)
//   Components/OverviewQuickActions.swift (QuickActionItem, GoQuickActionCard, AddQuickActionSheet, QuickFeedSheet)

#Preview {
    NavigationStack {
        OverviewView(selectedPet: .constant(nil), selectedHuman: .constant(nil), selectedPlant: .constant(nil), selectedPetTab: .constant(.overview))
    }
    .modelContainer(SharedModelContainer.make())
}
