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
    
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showingQAManageSheet = false
    @State private var showIslandWeight = false
    @State private var showIslandExpense = false
    @State private var showIslandExplore = false
    @State private var showIslandWealth = false
    @State private var showingAllFoodManagement = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    // 首页 section 可见性
    @AppStorage("home_section_order") private var sectionOrderRaw: String = "batchCheckIn,homeModule,quickAccess,islandStats,todayTasks"
    @AppStorage("home_section_hidden") private var hiddenSectionsRaw: String = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"
    private var l: L10n { L10n(appLanguage) }
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
    // B7: 长按查看详情 — 对应 sheet
    @State private var quickWeightDetailPet: Pet? = nil
    @State private var quickExpenseDetailPet: Pet? = nil
    @State private var quickWalkDetailPet: Pet? = nil
    @State private var quickHealthDetailPet: Pet? = nil
    @State private var quickGroomDetailPet: Pet? = nil
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
    @State private var showRewardCoconut = false
    @State private var rewardCoconutAmount: Int = 20
    @State private var rewardCoconutLabel: String? = nil
    // U9: 记忆碎片滑动消失
    @State private var memoryDismissed = false
    @State private var memoryDragOffset: CGFloat = 0
    // 全局椰子日志显示
    @State private var showingCoconutLog = false
    // HomeBentoBoxes 跳转
    @State private var showOasisReward = false
    @State private var showStreakDetail = false
    // Header 触发器（tab 1-3 按钮通过 toggle 触发子视图动作）
    @AppStorage("calendar_viewMode") private var calendarViewModeRaw: String = CalendarViewMode.list.rawValue
    @State private var calendarAddEventTrigger = false
    @State private var crewSearchTrigger = false
    @State private var crewAddMemberTrigger = false
    @State private var oasisRulesTrigger = false
    @State private var oasisInventoryTrigger = false
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
        case 5..<12: return l.goodMorning
        case 12..<17: return l.goodAfternoon
        case 17..<22: return l.goodEvening
        default: return l.goodNight
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
                    case 1: CalendarView(hideToolbar: true, addEventTrigger: calendarAddEventTrigger)
                    case 2: CrewRosterOverlay(
                        onSelectPet: { pet in
                            selectedPetTab = .overview
                            selectedPet = pet
                        },
                        onSelectHuman: { human in
                            selectedHuman = human
                        },
                        hideToolbar: true,
                        searchTrigger: crewSearchTrigger,
                        addMemberTrigger: crewAddMemberTrigger
                    )
                    case 3: OasisRewardView(hideToolbar: true, rulesTrigger: oasisRulesTrigger, inventoryTrigger: oasisInventoryTrigger)
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
                                    .foregroundStyle(.primary)
                                Text("坚持照顾家人，收获更多椰子")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.5))
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

            // R6: 全局固定前置层 — glass header，4 个 tab 保持不动
            VStack(spacing: 0) {
                globalFixedHeader
                    .padding(.top, 4)
                Spacer()
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
        .coconutRewardOverlay(trigger: $showRewardCoconut, amount: rewardCoconutAmount, label: rewardCoconutLabel)
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
            let managedIds = ["batchCheckIn", "homeModule", "quickAccess", "islandStats", "todayTasks"]
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
                .presentationDetents([.medium, .large])
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
        .fullScreenCover(isPresented: $showIslandWealth) {
            IslandWealthDashboardView()
        }
        .sheet(isPresented: $showingAllFoodManagement) {
            AllPetsFoodOverviewSheet()
        }
        .sheet(isPresented: $showingCoconutLog) {
            CoconutLogView()
        }
        .fullScreenCover(isPresented: $showOasisReward) {
            OasisRewardView()
        }
        .sheet(isPresented: $showStreakDetail) {
            DailyStreakDetailView(pets: pets)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Main Scroll View
    // Task3: 固定布局顺序（人体工学动线）：
    //   Greeting → MemoryDrop → Carousel → QuickAccess（拇指舒适区）→ IslandStats → SmartToday
    private var mainScrollView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
            // R6: 全局 header 占位
            Spacer().frame(height: 70)
            VStack(spacing: 24) {
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
                        onSelectPet: { selectedPetTab = .overview; selectedPet = $0 },
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
                    case "homeModule":
                        if !hiddenSections.contains("homeModule") {
                            HomeBentoBoxes(
                                islandLevel: islandLevel,
                                pets: pets,
                                onOasisTap: { selectedDockTab = 3 },
                                onStreakTap: { showStreakDetail = true }
                            )
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
            } // end ScrollView
        } // end VStack
    }

    private var orderedSections: [String] {
        let order = sectionOrder
        let allIds = ["batchCheckIn", "homeModule", "quickAccess", "islandStats", "todayTasks"]
        var result = order.filter { allIds.contains($0) }
        for id in allIds where !result.contains(id) { result.append(id) }
        return result
    }
    
    // MARK: - R6: Global Fixed Header（全局固定前置层）
    private var globalFixedHeader: some View {
        HStack(alignment: .center) {
            // 左侧：标题区
            VStack(alignment: .leading, spacing: 2) {
                switch selectedDockTab {
                case 0:
                    Text("\(greetingText) 👋")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    if let firstPet = pets.first {
                        let hour = Calendar.current.component(.hour, from: Date())
                        let hint = hour >= 6 && hour < 10 ? l.morningHint(firstPet.name) :
                                   hour >= 17 && hour < 20 ? l.eveningHint(firstPet.name) :
                                   l.defaultHint(firstPet.name)
                        Text(hint)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                case 1:
                    Text(l.tabCalendar)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                case 2:
                    Text(l.ohanaCrew)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                case 3:
                    Text(l.tabOasis)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                default:
                    EmptyView()
                }
            }
            Spacer()
            // 右侧：按 tab 显示不同按钮
            HStack(spacing: 8) {
                switch selectedDockTab {
                case 0:
                    // 首页：椰子 + 头像菜单
                    CoconutBalanceCapsule { showingCoconutLog = true }
                    Menu {
                        Button { showingAddEntity = true } label: {
                            Label(l.addMember, systemImage: "person.badge.plus")
                        }
                        Button { showingManageSheet = true } label: {
                            Label(l.manageHome, systemImage: "slider.horizontal.3")
                        }
                        Button { showingSettings = true } label: {
                            Label(l.settings, systemImage: "gearshape")
                        }
                    } label: {
                        avatarMenuLabel
                    }
                case 1:
                    // 日历：视图切换 + 添加日程 + 椰子
                    headerCalendarViewToggle
                    headerIconButton(systemName: "plus.circle.fill", color: Color.goLime) {
                        calendarAddEventTrigger.toggle()
                    }
                    CoconutBalanceCapsule { showingCoconutLog = true }
                case 2:
                    // 图鉴：搜索 + 添加岛民 + 椰子
                    headerIconButton(systemName: "magnifyingglass", color: .primary) {
                        crewSearchTrigger.toggle()
                    }
                    headerIconButton(systemName: "person.badge.plus", color: Color.goLime) {
                        crewAddMemberTrigger.toggle()
                    }
                    CoconutBalanceCapsule { showingCoconutLog = true }
                case 3:
                    // 绿洲：椰子指南 + 百宝箱 + 椰子
                    headerIconButton(systemName: "info.circle", color: .primary.opacity(0.7)) {
                        oasisRulesTrigger.toggle()
                    }
                    headerIconButton(systemName: "shippingbox.fill", color: .primary) {
                        oasisInventoryTrigger.toggle()
                    }
                    CoconutBalanceCapsule { showingCoconutLog = true }
                default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    // MARK: - Header 通用图标按钮
    private func headerIconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header 日历视图切换
    private var headerCalendarViewToggle: some View {
        let current = CalendarViewMode(rawValue: calendarViewModeRaw) ?? .list
        return HStack(spacing: 2) {
            headerViewModeBtn(systemName: "calendar", mode: .month, current: current)
            headerViewModeBtn(systemName: "list.bullet", mode: .list, current: current)
        }
        .padding(3)
        .background(.white.opacity(0.1), in: Capsule())
    }

    private func headerViewModeBtn(systemName: String, mode: CalendarViewMode, current: CalendarViewMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.28)) { calendarViewModeRaw = mode.rawValue }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(current == mode ? Color.arkInk : .white.opacity(0.45))
                .frame(width: 30, height: 26)
                .background { if current == mode { Capsule().fill(Color.goLime) } }
        }
    }

    // MARK: - Greeting Header (legacy, replaced by globalFixedHeader)
    private var goGreetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText) 👋")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                if let firstPet = pets.first {
                    let hour = Calendar.current.component(.hour, from: Date())
                    let hint = hour >= 6 && hour < 10 ? "带 \(firstPet.name) 早晨出去走走吧" :
                               hour >= 17 && hour < 20 ? "黄金时段，带 \(firstPet.name) 散个步 🌇" :
                               "\(firstPet.name) 在等你呢"
                    Text(hint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
            Spacer()
            HStack(spacing: 8) {
                CoconutBalanceCapsule {
                    showingCoconutLog = true
                }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
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
                    .foregroundStyle(.primary.opacity(0.7))
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
                    triggerCoconutReward(amount: 20)
                }
            }
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Island Stats（iOS 26 规范：图表直接浮在背景上，无卡片容器）
    private var islandStatsBento: some View {
        VStack(alignment: .leading, spacing: 8) {
                // Section Header — 浮动标题，无背景
                HStack {
                    Text("ISLAND STATS")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.4))
                        .tracking(3)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("左滑查看更多")
                            .font(OhanaFont.caption2())
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.3))
                        Image(systemName: "chevron.left.2")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.25))
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // 1. 体重卡（所有宠物 分系列折线图）
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
                    let totalWeight = allLatestWeights.reduce(0.0) { $0 + $1.1 }
                    IslandStatCard(
                        icon: "scalemass.fill",
                        title: "体重",
                        value: allLatestWeights.isEmpty
                            ? "--"
                            : String(format: "%.1f", totalWeight),
                        unit: allLatestWeights.isEmpty ? "" : "kg",
                        subtitle: allLatestWeights.count > 1 ? weightValueStr : weightSubtitle,
                        accentColor: .goTeal,
                        avatarEmojis: (pets.map { $0.avatarEmoji } + humans.filter { $0.shouldShowOnHome }.map { $0.avatarEmoji }),
                        onTap: { showIslandWeight = true }
                    ) {
                        MultiPetLineChart(series: weightSeries)
                    }

                    verticalDashDivider

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

                    verticalDashDivider

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
                        verticalDashDivider
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
                        verticalDashDivider
                        SynergyFlashCard(pets: pets, humans: humans)
                    }

                    // Phase 49: 椰子财富榜
                    CoconutWealthRankingCard(
                        pets: pets,
                        humans: humans,
                        onTap: { showIslandWealth = true }
                    )
                    .padding(16)
                    .frame(width: 260, height: 212)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
    }

    private var verticalDashDivider: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 1, height: 160)
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 160))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.primary.opacity(0.15))
            )
            .padding(.horizontal, 4)
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
        return pets.enumerated().compactMap { (i, p) in
            let sorted = p.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { return nil }
            return (p.name, Array(sorted.suffix(8).map { $0.weight }), Color(hex: p.themeColorHex))
        }
    }

    private var petExpenseSeriesData: [(String, Double, Color)] {
        return pets.enumerated().compactMap { (i, p) in
            let amt = p.expenseLogs.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }.reduce(0.0) { $0 + $1.amount }
            guard amt > 0 else { return nil }
            return (p.name, amt, Color(hex: p.themeColorHex))
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
                        .foregroundStyle(.primary)
                    Text("\(completedToday)/\(max(allTodayCount, 1))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                Button { showingCalendar = true } label: {
                    Text("View Plan →")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
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
                        .foregroundStyle(.primary.opacity(0.7))
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

    // MARK: - Batch Check-In Grid（与快捷操作一致的网格布局）
    @State private var batchPressedId: String? = nil

    private var batchCheckInBar: some View {
        let livePets = pets.filter { !$0.hasPassedAway }
        let actions = customBatchActions.filter { !$0.targetPets(from: livePets).isEmpty }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("一键全家")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingBatchCheckInSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(actions, id: \.id) { action in
                    batchGridCell(action: action, livePets: livePets)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingBatchCheckInSheet) {
            BatchActionEditSheet(selected: Binding(
                get: { customBatchActions },
                set: { saveBatchActions($0) }
            ))
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // 与 GoQuickActionCard 一致的网格单元：无背景 icon，打卡后 goLime
    private func batchGridCell(action: BatchAction, livePets: [Pet]) -> some View {
        let isPressed = batchPressedId == action.id
        let isDone = isBatchDoneToday(action: action, livePets: livePets)
        return Button {
            let targets = action.targetPets(from: livePets)
            guard !targets.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.12)) { batchPressedId = action.id }
            DispatchQueue.main.async {
                performBatchAction(action, targets: targets)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeOut(duration: 0.22)) {
                    if batchPressedId == action.id { batchPressedId = nil }
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: action.type.sfIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isDone ? Color.goLime : .primary.opacity(0.75))
                    .scaleEffect(isPressed ? 0.90 : 1.0)
                    .frame(width: 44, height: 44)

                VStack(spacing: 1) {
                    Text(action.type.label)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineLimit(1)
                    Text(isDone ? "已完成" : "全家")
                        .font(OhanaFont.caption2(.medium))
                        .foregroundStyle(.primary.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
    }

    private func isBatchDoneToday(action: BatchAction, livePets: [Pet]) -> Bool {
        let targets = action.targetPets(from: livePets)
        guard !targets.isEmpty else { return false }
        let cal = Calendar.current
        return targets.allSatisfy { pet in
            switch action.type {
            case .feed:
                return pet.careLogs.contains { $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) }
            case .water:
                return pet.careLogs.contains { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }
            case .potty:
                return pet.pottyLogs.contains { cal.isDateInToday($0.date) }
            case .litter:
                return pet.careLogs.contains { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }
            case .play:
                return pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
            }
        }
    }


    private func showBatchToast(_ msg: String, emoji: String = "✅") {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let anyPet = pets.first else { return }
        withAnimation(.spring(response: 0.35)) {
            actionToast = (pet: anyPet, message: msg, emoji: emoji)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                if actionToast?.message == msg {
                    actionToast = nil
                }
            }
        }
    }

    private func performBatchAction(_ action: BatchAction, targets: [Pet]) {
        let coconutBefore = QuestManager.shared.coconutCount
        let energyBefore = OasisTreeManager.shared.totalEnergy
        let levelBefore = OasisTreeManager.shared.treeLevel

        action.perform(pets: targets, context: modelContext)
        OasisTreeManager.shared.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans)

        let coconutDelta = max(QuestManager.shared.coconutCount - coconutBefore, 0)
        let energyDelta = max(OasisTreeManager.shared.totalEnergy - energyBefore, 0)
        let levelAfter = OasisTreeManager.shared.treeLevel

        if coconutDelta > 0 {
            triggerCoconutReward(amount: coconutDelta, label: "全家\(action.type.label)")
            showBatchToast("全家\(action.type.label) +\(coconutDelta)🥥", emoji: "🥥")
        } else {
            showBatchToast(action.toastMessage)
        }

        if levelAfter > levelBefore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                showBatchTreeToast("生命之树升级到 \(levelAfter.displayName) · Lv.\(levelAfter.rawValue)")
            }
        } else if energyDelta > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                showBatchTreeToast("生命之树吸收了 +\(energyDelta) 能量")
            }
        }
    }

    private func triggerCoconutReward(amount: Int, label: String? = nil) {
        rewardCoconutAmount = amount
        rewardCoconutLabel = label
        showRewardCoconut = true
    }

    private func showBatchTreeToast(_ message: String) {
        guard let anyPet = pets.first else { return }
        withAnimation(.spring(response: 0.35)) {
            actionToast = (pet: anyPet, message: message, emoji: "🌴")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                if actionToast?.message == message {
                    actionToast = nil
                }
            }
        }
    }

    // MARK: - Quick Actions (iOS 26 Liquid Glass)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // E2: 标题行 + 右上角 + 按钮
            HStack {
                Text("快捷操作")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingAddQuickAction = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                // 现有卡片
                ForEach(activeQuickActionItems, id: \.id) { item in
                    GoQuickActionCard(
                        item: item,
                        isPressed: pressedActionId == item.id,
                        petAvatar: avatarForAction(item),
                        petThemeColorHex: themeColorForAction(item),
                        pendingReminder: reminderForAction(item),
                        countText: countTextForAction(item),
                        isCompletedToday: isCompletedToday(for: item),
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
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingAddQuickAction) {
                AddQuickActionSheet(
                    pets: pets,
                    defaultPetId: activeCritterId,
                    existingItems: savedQuickActionItems
                ) { newItem in
                    var items = savedQuickActionItems
                    items.append(newItem)
                    if let data = try? JSONEncoder().encode(items),
                       let str = String(data: data, encoding: .utf8) {
                        quickActionItemsJSON = str
                    }
                }
        }
        .sheet(isPresented: $showingQAManageSheet) {
                QAManageSheet(
                    pets: pets,
                    defaultPetId: activeCritterId,
                    savedItems: Binding(get: { savedQuickActionItems }, set: { newItems in
                        if let data = try? JSONEncoder().encode(newItems),
                           let str = String(data: data, encoding: .utf8) {
                            quickActionItemsJSON = str
                        }
                    })
                )
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
            // B7: 长按详情页 sheets
            .sheet(item: $quickWeightDetailPet) { pet in
                NavigationStack {
                    WeightHistoryView(pet: pet)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $quickExpenseDetailPet) { pet in
                NavigationStack {
                    ExpenseHistoryView(pet: pet)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $quickWalkDetailPet) { pet in
                NavigationStack {
                    DogActivityCard(pet: pet)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $quickHealthDetailPet) { pet in
                NavigationStack {
                    PetHealthDetailView(pet: pet, isModal: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $quickGroomDetailPet) { pet in
                PetHygieneCard(pet: pet)
            }
    }


    // Task2: 根据顶牌过滤 Quick Access items（顶牌是宠物时，过滤出该宠物 + 无宠物 items；顶牌是人时显示全部）
    private var activeQuickActionItems: [QuickActionItem] {
        let all = savedQuickActionItems.map { item -> QuickActionItem in
            // C2: 旧版存储的 actionType="care" 规范化为 "groom"
            var normalized = item
            if item.actionType == "care" { normalized.actionType = "groom" }
            return normalized
        }
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
            // 长按弹出喂食量 sheet
            feedSheetItem = (pet: p, actionType: item.actionType)
        case "potty", "litter":
            quickAccessFoodPet = p
        case "health":
            // B7/B8: 长按→健康详情 modal sheet（避免 NavigationStack 重复 push 死锁）
            quickHealthDetailPet = p
        case "hygiene", "groom", "bath":
            // B7: 长按→护理历史
            quickGroomDetailPet = p
        case "walk":
            // B7: 长按→遛狗历史
            quickWalkDetailPet = p
        case "weight":
            // B7: 长按→体重历史
            quickWeightDetailPet = p
        case "expense":
            // B7: 长按→花费历史
            quickExpenseDetailPet = p
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

    // Task 2: 检查今日是否已打卡（改变 icon 为 goLime 主色）
    private func isCompletedToday(for item: QuickActionItem) -> Bool {
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return false }
        let cal = Calendar.current
        switch item.actionType {
        case "walk":
            return pet.walkLogs.contains { cal.isDateInToday($0.startDate) }
        case "feed":
            return pet.careLogs.contains { $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) }
        case "water":
            return pet.careLogs.contains { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }
        case "litter":
            return pet.careLogs.contains { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }
        case "potty":
            return pet.pottyLogs.contains { cal.isDateInToday($0.date) }
        case "play":
            return pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
        case "groom":
            return pet.hygieneLogs.contains { cal.isDateInToday($0.date) }
        case "bath":
            return pet.hygieneLogs.contains { $0.type == HygieneType.bath.rawValue && cal.isDateInToday($0.date) }
        default:
            return false
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
        case "play":
            let count = pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日逗玩 \(count)次" : "今日未逗玩"
        case "groom":
            let count = pet.hygieneLogs.filter { cal.isDateInToday($0.date) }.count
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
            // B8: 单击弹出健康详情 modal，避免 NavigationStack 重复 push 死锁
            quickHealthDetailPet = pet
        case "hygiene", "groom":
            // groom 单击由 GoQuickActionCard.isGroom 内部弹 GroomMenuSheet 处理；此处兜底
            quickAccessCarePet = pet
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
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("这里是你和家人的专属小岛\n还没有居民，快把第一个家人带来吧 🐾")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary.opacity(0.5))
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
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.15))
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
                    .foregroundStyle(.primary)
                Text("添加第一只宠物，开启椰子奖励之旅")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
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
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))

                VStack(spacing: 4) {
                    Text("💩")
                        .font(.system(size: 28))
                    Text("+1")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("每次打卡")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))

                VStack(spacing: 4) {
                    Text("🦮")
                        .font(.system(size: 28))
                    Text("+N")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("遛狗奖励")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
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
                        .foregroundStyle(.primary.opacity(0.5))
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
                                        .foregroundStyle(.primary)
                                    Text("\(pet.species) · \(pet.breed)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.primary.opacity(0.3))
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
                        .foregroundStyle(.primary.opacity(0.5))
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
                                        .foregroundStyle(.primary)
                                    Text(human.roleText)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.primary.opacity(0.3))
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
