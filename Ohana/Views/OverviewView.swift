//
//  OverviewView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OverviewView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    var heroNS: Namespace.ID
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \Household.createdAt) private var households: [Household]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(filter: #Predicate<Reminder> { $0.status == "failed" },
           sort: \Reminder.scheduledAt) private var failedReminders: [Reminder]
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    
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
    @State private var showingQAManageSheet = false
    @State private var showIslandWeight = false
    @State private var showIslandExpense = false
    @State private var showIslandExplore = false
    @State private var showIslandWealth = false
    @State private var showingAllFoodManagement = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    // 首页 section 可见性
    @AppStorage("home_section_order") private var sectionOrderRaw: String = "todayActions,memoryDrop,islandStats"
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
    // 快捷操作详情 sheet
    @State private var feedDetailPet: Pet? = nil
    @State private var waterDetailPet: Pet? = nil
    @State private var playDetailPet: Pet? = nil
    @State private var pottyDetailPet: Pet? = nil
    @State private var litterDetailPet: Pet? = nil
    /// 喂食/喂水等详情 sheet 默认用大高度，避免 medium 裁切「打卡」按钮
    @State private var quickActionDetailSheetDetent: PresentationDetent = .large
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
    // 卡片背面功能弹窗
    @State private var cardBackSettingsPet: Pet? = nil
    // 健康管理
    @State private var cardBackHealthPet: Pet? = nil
    @State private var cardBackMedicationsPet: Pet? = nil
    @State private var cardBackWeightPet: Pet? = nil
    // 日常生活
    @State private var cardBackFoodPet: Pet? = nil
    @State private var cardBackHygienePet: Pet? = nil
    @State private var cardBackWalksPet: Pet? = nil
    @State private var cardBackPottyPet: Pet? = nil
    @State private var cardBackExpensesPet: Pet? = nil
    // 档案证件
    @State private var cardBackBasicInfoPet: Pet? = nil
    @State private var cardBackDocumentsPet: Pet? = nil
    // 记忆成长
    @State private var cardBackMomentsPet: Pet? = nil
    @State private var cardBackCalendarPet: Pet? = nil
    @State private var cardBackAchievementsPet: Pet? = nil
    // 全局椰子日志显示
    @State private var showingCoconutLog = false
    // 打卡连击详情（顶栏 / 横滑甲板共用）
    @State private var showOasisReward = false
    @State private var showStreakDetail = false
    @State private var headerStreak: Int = 0
    // 岛屿日报（每日首次弹窗）
    @AppStorage("lastIslandReportDate") private var lastIslandReportDate: String = ""
    @State private var showIslandDailyReport = false
    // Phase 5: Bento 卡急迫发光动画
    @State private var bentoUrgentGlow = false
    // Quick Action 编辑模式（iOS 桌面风格）
    @State private var isQAEditMode = false
    @State private var qaJiggle = false
    @State private var qaEditItems: [QuickActionItem] = []
    @State private var showMomentPet: Pet? = nil
    @State private var showingQAQuickAdd = false
    // Header 触发器（tab 1-3 按钮通过 toggle 触发子视图动作）
    @AppStorage("calendar_viewMode") private var calendarViewModeRaw: String = CalendarViewMode.list.rawValue
    @State private var calendarAddEventTrigger = false
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
        let treeLevel = OasisTreeManager.shared.treeLevel
        switch treeLevel.rawValue {
        case 1...3: return .seedling
        case 4...6: return .blooming
        default:    return .paradise
        }
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
    
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)? = nil
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""
    // 健康快捷操作 popover sheets
    @State private var showingAddSymptomSheet = false
    @State private var symptomSheetPet: Pet? = nil
    @State private var showingAddHeatCycleSheet = false
    @State private var heatCycleSheetPet: Pet? = nil

    var body: some View {
        ZStack {
            ArkBackgroundView()

            // 岛屿天气粒子特效层（全局覆盖）
            IslandMoodWeatherView(mood: currentMood)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            if pets.isEmpty && humans.isEmpty && plants.isEmpty {
                emptyStateView
            } else if isSearching {
                searchResultsView
            } else {
                // F2: tab 内容区切换
                Group {
                    switch selectedDockTab {
                    case 1: PlantDashboardView(selectedPlant: $selectedPlant)
                    case 2: CalendarView(hideToolbar: true, addEventTrigger: calendarAddEventTrigger)
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
                        Text(toast.emoji).font(OhanaFont.metric(size: 20, .medium))
                        Text(toast.message)
                            .font(OhanaFont.body(.black))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
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
                            .font(OhanaFont.metric(size: 64, .medium))
                            .scaleEffect(coconutFlyOut ? 0.2 : 1.0)
                            .opacity(coconutFlyOut ? 0 : 1)
                            .offset(y: coconutFlyOut ? -300 : 0)
                            .offset(x: coconutFlyOut ? 120 : 0)

                        if !coconutFlyOut {
                            VStack(spacing: 6) {
                                Text("每日登录奖励 +1🥥")
                                    .font(OhanaFont.title2(.black))
                                    .foregroundStyle(.primary)
                                Text("坚持照顾家人，收获更多椰子")
                                    .font(OhanaFont.callout(.medium))
                                    .foregroundStyle(.primary.opacity(0.5))
                            }
                            .transition(.opacity)

                            Button {
                                dismissDailyCoconut()
                            } label: {
                                Text("收下")
                                    .font(OhanaFont.body(.bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 36).padding(.vertical, 12)
                                    .background(Color.goPrimary, in: Capsule())
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
                if selectedDockTab == 2 {
                    CalendarPetChipFilterBar()
                }
                Spacer()
            }

            // Floating Dock Nav
            VStack {
                Spacer()
                FloatingDockNav(
                    selectedTab: $selectedDockTab,
                    onHome: { selectedDockTab = 0 },
                    onPlant: { selectedDockTab = 1 },
                    onCalendar: { selectedDockTab = 2 },
                    onOasis: { selectedDockTab = 3 }
                )
                .padding(.bottom, 20)
            }
        }
        // H27fix: 椰子爆出动效挂在页面层（SmartTodayCard本身可能已消失）
        .coconutRewardOverlay(trigger: $showRewardCoconut, amount: rewardCoconutAmount, label: rewardCoconutLabel)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshHeaderStreak()
        }
        .onAppear {
            refreshHeaderStreak()
            // Phase 5: 启动紧急卡片橙色发光呼吸动画
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bentoUrgentGlow = true
            }
            for pet in pets {
                StreakManager.refreshStreak(for: pet, context: modelContext)
            }
            NotificationManager.shared.compensate(reminders: Array(pendingReminders))
            modelContext.safeSave()
            // U5: 每日首次打开椰子收集
            let dailyKey = "daily_coconut_shown"
            let today = Calendar.current.startOfDay(for: Date())
            if let last = UserDefaults.standard.object(forKey: dailyKey) as? Date,
               Calendar.current.isDate(last, inSameDayAs: today) {
                // 今天已显示过
            } else if !pets.isEmpty || !humans.isEmpty || !plants.isEmpty {
                UserDefaults.standard.set(today, forKey: dailyKey)
                QuestManager.shared.addCoconuts(1, emoji: "🌅", title: "每日登录奖励")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDailyCoconut = true
                    }
                }
            }
            // 岛屿日报：每日首次打开时弹出
            if !pets.isEmpty || !plants.isEmpty {
                let todayStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                if lastIslandReportDate != todayStr {
                    lastIslandReportDate = todayStr
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showIslandDailyReport = true
                    }
                }
            }
            // F1: 迁移旧 sectionOrder → 合并为 todayActions
            var order = sectionOrderRaw.split(separator: ",").map(String.init)
            order.removeAll { $0 == "petCards" }
            let legacyActionIds = ["quickAccess", "batchCheckIn", "todayTasks"]
            if order.contains(where: { legacyActionIds.contains($0) }) && !order.contains("todayActions") {
                order.removeAll { legacyActionIds.contains($0) }
                order.insert("todayActions", at: 0)
            }
            order.removeAll { $0 == "homeModule" }
            let managedIds = ["todayActions", "memoryDrop", "islandStats"]
            for id in managedIds where !order.contains(id) { order.append(id) }
            order = order.filter { managedIds.contains($0) }
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
            GenericWeightEntrySheet(target: .pet(pet))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
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
        .fullScreenCover(isPresented: $showingCrewRoster) {
            NavigationStack {
                CrewRosterOverlay(
                    onSelectPet: { pet in
                        showingCrewRoster = false
                        selectedPetTab = .overview
                        selectedPet = pet
                    },
                    onSelectHuman: { human in
                        showingCrewRoster = false
                        selectedHuman = human
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingCrewRoster = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(OhanaFont.metric(size: 18, .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showStreakDetail) {
            DailyStreakDetailView(pets: pets)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $showMomentPet) { pet in
            NavigationStack {
                QuickMomentSheet(
                    pet: pet,
                    onRemove: savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "moment" }).map { found in
                        { removeQuickAction(found) }
                    }
                )
                .navigationTitle("记录时刻")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { showMomentPet = nil }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showIslandDailyReport) {
            IslandDailyReportSheet(
                isPresented: $showIslandDailyReport,
                pets: pets,
                reminders: pendingReminders,
                plants: plants,
                events: allEvents,
                onStartTasks: {
                    // 自动滚动到委托区域（由 ScrollViewReader 处理）
                }
            )
            .presentationBackground(.clear)
        }
        .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
            Button("确定打卡", role: .destructive) {
                pendingRepeatAction?()
                pendingRepeatAction = nil
            }
            Button("取消", role: .cancel) {
                pendingRepeatAction = nil
            }
        } message: {
            Text(antiRepeatMessage)
        }
        .islandToastOverlay()
        .sheet(isPresented: $showingAddSymptomSheet) {
            if let pet = symptomSheetPet {
                NavigationStack {
                    AddSymptomSheet(pet: pet)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingAddHeatCycleSheet) {
            if let pet = heatCycleSheetPet {
                NavigationStack {
                    AddHeatCycleSheet(pet: pet)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Main Scroll View
    // 信息层级（产品动线）：
    //   Header → Wallet Stack → [⚠️紧急警告] → 快捷操作 → 今日任务 → 游戏化面板 → 记忆碎片 → 岛屿统计
    private var mainScrollView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
            // R6: 全局 header 占位
            Spacer().frame(height: 70)
            VStack(spacing: 20) {
                // ── 层2引导：有Human无Pet时显示添加宠物引导卡
                if pets.isEmpty && !humans.isEmpty && !hiddenSections.contains("petCards") {
                    addFirstPetBanner
                }

                // ── 层2：3D 宠物卡牌转盘（第一视界）
                if (!pets.isEmpty || !humans.isEmpty) && !hiddenSections.contains("petCards") {
                    PetWalletStack(
                        pets: pets,
                        humans: humans,
                        heroNS: heroNS,
                        onSelectPet: { selectedPetTab = .overview; selectedPet = $0 },
                        onSelectHuman: { selectedHuman = $0 },
                        onTopCardChanged: { item in
                            if case .pet(let p) = item { activeCritterIdStr = p.id.uuidString }
                            else { activeCritterIdStr = "" }
                        },
                        onShowBackSettings: { cardBackSettingsPet = $0 },
                        onShowHealth:       { cardBackHealthPet = $0 },
                        onShowMedications:  { cardBackMedicationsPet = $0 },
                        onShowWeight:       { cardBackWeightPet = $0 },
                        onShowFood:         { cardBackFoodPet = $0 },
                        onShowHygiene:      { cardBackHygienePet = $0 },
                        onShowWalks:        { cardBackWalksPet = $0 },
                        onShowPotty:        { cardBackPottyPet = $0 },
                        onShowExpenses:     { cardBackExpensesPet = $0 },
                        onShowBasicInfo:    { cardBackBasicInfoPet = $0 },
                        onShowDocuments:    { cardBackDocumentsPet = $0 },
                        onShowMoments:      { cardBackMomentsPet = $0 },
                        onShowCalendar:     { cardBackCalendarPet = $0 },
                        onShowAchievements: { cardBackAchievementsPet = $0 }
                    )
                    .onAppear {
                        if activeCritterIdStr.isEmpty {
                            activeCritterId = pets.first?.id
                        }
                    }
                }

                // ── 层3：⚠️ 紧急健康警告拦截层（仅 urgent 级别时显示）
                emergencyAlertBanner

                // ── 宠物状态一览卡已整合进 HomeHighlightDeck（由 todayActionsSection 渲染）

                // ── 层4+：按 orderedSections 驱动渲染（严格绑定排序与显隐）
                ForEach(orderedSections, id: \.self) { sectionId in
                    switch sectionId {
                    case "todayActions", "quickAccess", "batchCheckIn", "todayTasks":
                        if sectionId == (orderedSections.first(where: { ["todayActions", "quickAccess", "batchCheckIn", "todayTasks"].contains($0) }) ?? "") &&
                           !hiddenSections.contains("todayActions") {
                            todayActionsSection
                        }
                    case "memoryDrop":
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
                                                    QuestManager.shared.addCoconuts(1, emoji: "💭", title: "珍惜记忆 +1🥥")
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
                    case "islandStats":
                        if (!pets.isEmpty || !plants.isEmpty) && !hiddenSections.contains("islandStats") {
                            islandStatsBento
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
        let allIds = ["todayActions", "memoryDrop", "islandStats"]
        let legacyIds = ["quickAccess", "batchCheckIn", "todayTasks"]
        var result = order.filter { allIds.contains($0) || legacyIds.contains($0) }
        for id in allIds where !result.contains(id) { result.append(id) }
        return result
    }
    
    // MARK: - Header Streak
    private func refreshHeaderStreak() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let checkedInDates = Set(UserDefaults.standard.stringArray(forKey: "oasis_checkedIn_dates") ?? [])
        var streak = 0
        var day = Date()
        while true {
            let dayStr = formatter.string(from: day)
            if checkedInDates.contains(dayStr) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else { break }
        }
        headerStreak = streak
    }

    // MARK: - R6: Global Fixed Header（全局固定前置层）
    private var globalFixedHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧：标题区
            VStack(alignment: .leading, spacing: 2) {
                switch selectedDockTab {
                case 0:
                    Text("\(greetingText) 👋")
                        .font(OhanaFont.metric(size: 22, .black))
                        .foregroundStyle(.primary)
                    if let greetPet = activeCritterId.flatMap({ id in pets.first(where: { $0.id == id }) }) ?? pets.first {
                        let hour = Calendar.current.component(.hour, from: Date())
                        let hint = PetTagGreeting.homeSubtitleHint(pet: greetPet, hour: hour, l: l)
                        Text(hint)
                            .font(OhanaFont.footnote(.medium))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                case 1:
                    Text(l.tabPlant)
                        .font(OhanaFont.metric(size: 22, .black))
                        .foregroundStyle(.primary)
                case 2:
                    Text(l.tabCalendar)
                        .font(OhanaFont.metric(size: 22, .black))
                        .foregroundStyle(.primary)
                case 3:
                    Text(l.tabOasis)
                        .font(OhanaFont.metric(size: 22, .black))
                        .foregroundStyle(.primary)
                default:
                    EmptyView()
                }
            }
            .frame(minHeight: 52, alignment: .topLeading)
            Spacer()
            // 右侧：tab 专属按钮 + 椰子胶囊（行高 32；椰子胶囊 26 更紧凑）
            HStack {
                HStack(spacing: 8) {
                    // Tab 专属按钮（不含椰子，保证椰子位置静止）
                    switch selectedDockTab {
                    case 0:
                        // 首页：更多（圆角矩形 ⋯）+ 连续打卡数字 + 椰子
                        Menu {
                            Button { showingAddEntity = true } label: {
                                Label("添加成员", systemImage: "person.badge.plus")
                            }
                            Button { showingSettings = true } label: {
                                Label("设置", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 32, height: 28)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .menuActionDismissBehavior(.automatic)
                        .buttonStyle(.plain)

                        Button { showStreakDetail = true } label: {
                            Text("\(headerStreak)")
                                .font(OhanaFont.headline(.black))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .minimumScaleFactor(0.65)
                                .lineLimit(1)
                                .foregroundStyle(headerStreak >= 7 ? Color.arkInk : Color.primary)
                                .frame(minWidth: 26)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .frame(height: 28)
                                .background(
                                    headerStreak >= 7 ? Color.orange : Color.primary.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    case 1:
                        // 植物：添加
                        headerIconButton(systemName: "plus.circle.fill", color: Color.goPrimary) {
                            showingAddEntity = true
                        }
                    case 2:
                        // 日历：视图切换 + 添加日程
                        headerCalendarViewToggle
                        headerIconButton(systemName: "plus.circle.fill", color: Color.goPrimary) {
                            calendarAddEventTrigger.toggle()
                        }
                    case 3:
                        // 绿洲：椰子指南 + 百宝箱
                        headerIconButton(systemName: "info.circle", color: .primary.opacity(0.7)) {
                            oasisRulesTrigger.toggle()
                        }
                        headerIconButton(systemName: "shippingbox.fill", color: .primary) {
                            oasisInventoryTrigger.toggle()
                        }
                    default:
                        EmptyView()
                    }
                    // 椰子胶囊：始终在最右，切换 tab 不移位
                    CoconutBalanceCapsule { showingCoconutLog = true }
                }
            }
            .frame(height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Header 通用图标按钮
    /// 顶栏行高 32；图标区 32×32，椰子胶囊本体 26pt 高，纵向居中对齐
    private func headerIconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(OhanaFont.headline(.semibold))
                .symbolRenderingMode(.monochrome)
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
            headerViewModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list, current: current)
        }
        .padding(.horizontal, 2)
        .frame(height: 32)
        .glassEffect(.regular, in: Capsule())
    }

    private func headerViewModeBtn(systemName: String, mode: CalendarViewMode, current: CalendarViewMode) -> some View {
        let unselectedTint = colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.5)
        return Button {
            withAnimation(.spring(response: 0.28)) { calendarViewModeRaw = mode.rawValue }
        } label: {
            Image(systemName: systemName)
                .font(OhanaFont.subheadline(.bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(current == mode ? Color.arkInk : unselectedTint)
                .frame(width: 30, height: 30)
                .background { if current == mode { Capsule().fill(Color.goPrimary) } }
        }
    }

    // MARK: - Greeting Header (legacy, replaced by globalFixedHeader)
    private var goGreetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText) 👋")
                    .font(OhanaFont.metric(size: 22, .black))
                    .foregroundStyle(.primary)
                if let greetPet = activeCritterId.flatMap({ id in pets.first(where: { $0.id == id }) }) ?? pets.first {
                    let hour = Calendar.current.component(.hour, from: Date())
                    let hint = PetTagGreeting.homeSubtitleHint(pet: greetPet, hour: hour, l: l)
                    Text(hint)
                        .font(OhanaFont.footnote(.medium))
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
                    Button { showingCrewRoster = true } label: {
                        Label(l.ohanaCrew, systemImage: "pawprint.fill")
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
                    .font(OhanaFont.metric(size: 18, .medium))
            } else {
                Image(systemName: "person.fill")
                    .font(OhanaFont.headline(.semibold))
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Emergency Alert Banner（仅 .urgent 级别时显示，纯实色背景无 glass）
    @ViewBuilder
    private var emergencyAlertBanner: some View {
        let activePets: [Pet] = {
            if let id = activeCritterId, let p = pets.first(where: { $0.id == id }) { return [p] }
            return pets.filter { !$0.hasPassedAway }
        }()
        let urgentAlerts = PetHealthAlertEngine.shared.scanAlerts(pets: activePets)
            .filter { $0.severity == .urgent }
        if !urgentAlerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(urgentAlerts.prefix(3)) { alert in
                    Button {
                        if let pet = pets.first(where: { $0.id == alert.petId }) {
                            selectedPet = pet
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(alert.emoji)
                                .font(OhanaFont.metric(size: 20, .medium))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(alert.petName) · \(alert.title)")
                                    .font(OhanaFont.subheadline(.black))
                                    .foregroundStyle(.white)
                                Text(alert.detail)
                                    .font(OhanaFont.caption(.medium))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(OhanaFont.footnote(.bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.goRed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Island Stats（iOS 26 规范：图表直接浮在背景上，无卡片容器）
    private var islandStatsBento: some View {
        VStack(alignment: .leading, spacing: 8) {
                // Section Header — 浮动标题，无背景
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("岛屿统计")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.4))
                            .tracking(3)
                        Text("ISLAND STATS")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25))
                            .tracking(2)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("左滑查看更多")
                            .font(OhanaFont.caption2())
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.3))
                        Image(systemName: "chevron.left.2")
                            .font(OhanaFont.caption2(.bold))
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
                        accentColor: .goPrimary,
                        avatarEmojis: (pets.map { $0.avatarEmoji } + humans.map { $0.avatarEmoji }),
                        onTap: { showIslandExplore = true }
                    ) {
                        MiniBarChart(values: weekWalkData.map { Double($0.1) }, labels: weekWalkData.map { $0.0 }, accentColor: .goPrimary)
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
        return pets.enumerated().compactMap { (_, p) in
            let sorted = p.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { return nil }
            return (p.name, Array(sorted.suffix(8).map(\.weightInKg)), Color(hex: p.themeColorHex))
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
                        .font(OhanaFont.metric(size: 18, .black))
                        .foregroundStyle(.primary)
                    Text("\(completedToday)/\(max(allTodayCount, 1))")
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                Button { showingCalendar = true } label: {
                    Text("View Plan →")
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)

            // Progress bar
            if allTodayCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(height: 4)
                        Capsule().fill(Color.goPrimary)
                            .frame(width: geo.size.width * CGFloat(completedToday) / CGFloat(allTodayCount), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
            }

            if todayReminders.isEmpty {
                HStack(spacing: 12) {
                    Text("🎉").font(OhanaFont.metric(size: 22, .medium))
                    Text("All tasks done! Enjoy your day.")
                        .font(OhanaFont.callout(.bold))
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
                        .font(OhanaFont.callout(.bold))
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
                    .font(OhanaFont.metric(size: 26, .semibold))
                    .foregroundStyle(isDone ? Color.goPrimary : .primary.opacity(0.75))
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
                return feedQuickActionAppearsComplete(for: pet)
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
        OasisTreeManager.shared.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants)

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

    // MARK: - Deck active pet helper
    private var deckActivePet: Pet? {
        if let id = activeCritterId {
            return pets.first(where: { $0.id == id && !$0.hasPassedAway })
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    // MARK: - Today Actions (unified section)
    @ViewBuilder
    private var todayActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 横滑高亮甲板：宠物状态 + 委托 + 岛屿等级（替代独立 PetWellnessCard + EnergyBar + QuestCarousel）
            HomeHighlightDeck(
                activePet: deckActivePet,
                pets: pets,
                plants: plants,
                quests: IslandQuestEngine.todayQuests(pets: pets, reminders: pendingReminders, plants: plants, events: allEvents),
                checkInStreak: headerStreak,
                onStreakTap: { showStreakDetail = true },
                onCompleteQuest: { completeIslandQuest($0) },
                onSkipQuest: { _ in },
                onQuestProgress: { completed, total in
                    IslandToastManager.shared.showQuestProgress(completed: completed, total: total)
                },
                onOasisTap: { selectedDockTab = 3 }
            )
            .padding(.top, 12)

            // Quick actions grid
            quickActionsSection
                .animation(.spring(response: 0.38, dampingFraction: 0.78),
                           value: activeQuickActionItems.map(\.id))

            // Batch check-in (collapsed into single row)
            if pets.filter({ !$0.hasPassedAway }).count > 1 {
                batchCheckInBar
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Quick Actions (iOS 桌面风格编辑模式)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text("快捷操作")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.4))
                    .tracking(3)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isQAEditMode { exitQAEditMode() } else { enterQAEditMode() }
                } label: {
                    Image(systemName: isQAEditMode ? "checkmark.circle.fill" : "pencil")
                        .font(OhanaFont.title3(.semibold))
                        .foregroundStyle(isQAEditMode ? Color.goPrimary : .primary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.2), value: isQAEditMode)
            }
            .padding(.horizontal, 20)

            // 卡片网格
            let displayItems = isQAEditMode ? qaEditItems : activeQuickActionItems
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                    let cardState = isQAEditMode ? BentoCardState.normalPending : bentoCardState(for: item)
                    let onTapAction: () -> Void = {
                        guard !isQAEditMode else { return }
                        pressedActionId = item.id
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            pressedActionId = nil; handleAction(item)
                        }
                    }
                    let onLongPressAction: (() -> Void)? = isQAEditMode ? nil : {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        handleLongPressAction(item)
                    }
                    let onDeleteAction: (() -> Void)? = isQAEditMode ? nil
                        : (quickActionUsesDetailSheetRemove(item.actionType) ? nil : { removeQuickAction(item) })
                    let onGroomAction: ((String) -> Void)? = (!isQAEditMode && item.actionType == "groom") ? { raw in
                        if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) { applyGroomCheckIn(raw, pet: p) }
                    } : nil
                    let onPottyAction: ((String) -> Void)? = (!isQAEditMode && item.actionType == "potty") ? { raw in
                        if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) { applyPottyCheckIn(raw, pet: p) }
                    } : nil
                    let onHealthAction: ((String) -> Void)? = (!isQAEditMode && item.actionType == "health") ? { raw in
                        if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) { applyHealthCheckIn(raw, pet: p) }
                    } : nil
                    let onAddReminderAction: (() -> Void)? = (!isQAEditMode && item.actionType == "potty") ? {
                        quickAccessCarePet = pets.first(where: { $0.id == item.petId })
                    } : nil
                    let onDoubleTapAction: (() -> Void)? = (!isQAEditMode && (item.actionType == "litter" || item.actionType == "potty")) ? {
                        if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) {
                            if item.actionType == "litter" { quickAccessCarePet = p } else { quickAccessFoodPet = p }
                        }
                    } : nil

                    // ZStack：编辑模式时透明拦截层在卡片上方，独立捕获拖拽手势
                    ZStack {
                        // 实际卡片（编辑模式下禁用交互，避免内部 DragGesture 阻断系统拖拽）
                        GoQuickActionCard(
                            item: item,
                            isPressed: !isQAEditMode && pressedActionId == item.id,
                            petAvatar: avatarForAction(item),
                            petThemeColorHex: themeColorForAction(item),
                            displayIcon: (!isQAEditMode && item.actionType == "water" && waterQuickDisplayUsesChangeMode(for: item.petId))
                                ? "drop.circle.fill" : nil,
                            titleLabelOverride: (!isQAEditMode && item.actionType == "water" && waterQuickDisplayUsesChangeMode(for: item.petId))
                                ? "换水" : nil,
                            pendingReminder: isQAEditMode ? nil : reminderForAction(item),
                            countText: isQAEditMode ? nil : countTextForAction(item),
                            isCompletedToday: !isQAEditMode && isCompletedToday(for: item),
                            onTap: onTapAction,
                            onLongPress: onLongPressAction,
                            onDoubleTap: onDoubleTapAction,
                            onDelete: onDeleteAction,
                            onGroomCheckIn: onGroomAction,
                            onPottySelect: onPottyAction,
                            onHealthSelect: onHealthAction,
                            onAddReminder: onAddReminderAction
                        )
                        // 非编辑模式视觉状态：打卡后保持原色，不做降饱和/透明处理
                        .overlay {
                            if !isQAEditMode && cardState == .urgentPending {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.orange.opacity(bentoUrgentGlow ? 0.8 : 0.3), lineWidth: 1.5)
                                    .shadow(color: Color.orange.opacity(bentoUrgentGlow ? 0.35 : 0.08),
                                            radius: bentoUrgentGlow ? 8 : 2)
                                    .allowsHitTesting(false)
                            }
                        }
                        .allowsHitTesting(!isQAEditMode)

                        // 编辑模式：透明拖拽捕获层（必须在卡片上方）
                        if isQAEditMode {
                            QAEditModeDragLayer(
                                item: item,
                                themeHex: themeColorForAction(item)
                            )
                        }
                    }
                    // 抖动（作用于整个 ZStack）
                    .rotationEffect(
                        .degrees(isQAEditMode ? (qaJiggle ? -2.5 : 2.5) : 0),
                        anchor: .center
                    )
                    .animation(
                        isQAEditMode
                            ? .easeInOut(duration: 0.12 + Double(idx % 4) * 0.015).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.2),
                        value: qaJiggle
                    )
                    // 删除徽章（在 ZStack 外层，始终可点击）
                    .overlay(alignment: .topLeading) {
                        if isQAEditMode {
                            Button {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                withAnimation(.spring(response: 0.3)) {
                                    qaEditItems.removeAll { $0.id == item.id }
                                }
                            } label: {
                                ZStack {
                                    Circle().fill(Color.goRed).frame(width: 20, height: 20)
                                    Image(systemName: "minus")
                                        .font(OhanaFont.caption2(.black))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .offset(x: -4, y: -4)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    // 拖拽放置目标
                    .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(
                        targetItem: item,
                        items: $qaEditItems
                    ))
                }

                // 末尾"+"添加占位卡（仅编辑模式）
                if isQAEditMode {
                    Button {
                        guard pets.first(where: { $0.id == activeCritterId }) != nil else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingQAQuickAdd = true
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .font(OhanaFont.title2(.bold))
                                    .foregroundStyle(Color.primary.opacity(0.4))
                            }
                            Text("添加")
                                .font(OhanaFont.caption2(.semibold))
                                .foregroundStyle(.primary.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingQAQuickAdd, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                        if let pet = pets.first(where: { $0.id == activeCritterId }) {
                            QAQuickAddPopoverContent(pet: pet, existingItems: qaEditItems) { newItem in
                                withAnimation(.spring(response: 0.3)) {
                                    qaEditItems.append(newItem)
                                }
                            }
                        }
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .sheet(item: $quickAccessFoodPet) { pet in
                PetFoodManagementView(pet: pet)
            }
            .sheet(item: $quickAccessCarePet) { pet in
                PetHygieneCard(pet: pet)
            }
            .sheet(item: $quickExpensePet) { pet in
                AddExpenseSheet(
                    pet: pet,
                    preselectedPayerId: UserDefaults.standard.string(forKey: "currentActiveHumanId")
                )
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
                    WeightHistoryView(pet: pet, onRemove: {
                        quickWeightDetailPet = nil
                        if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "weight" }) {
                            removeQuickAction(found)
                        }
                    })
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $quickExpenseDetailPet) { pet in
                NavigationStack {
                    ExpenseHistoryView(pet: pet, onRemove: {
                        quickExpenseDetailPet = nil
                        if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "expense" }) {
                            removeQuickAction(found)
                        }
                    })
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
                NavigationStack {
                    PetHygieneDetailView(pet: pet)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $feedDetailPet) { pet in
                QuickFeedDetailSheet(pet: pet) {
                    feedDetailPet = nil
                    if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "feed" }) {
                        removeQuickAction(found)
                    }
                }
                .onAppear { quickActionDetailSheetDetent = .large }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $waterDetailPet) { pet in
                QuickWaterDetailSheet(pet: pet) {
                    waterDetailPet = nil
                    if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && ($0.actionType == "water" || $0.actionType == "waterChange" || $0.actionType == "filterClean") }) {
                        removeQuickAction(found)
                    }
                }
                .onAppear { quickActionDetailSheetDetent = .large }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $playDetailPet) { pet in
                QuickPlayDetailSheet(pet: pet) {
                    playDetailPet = nil
                    if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "play" }) {
                        removeQuickAction(found)
                    }
                }
                .onAppear { quickActionDetailSheetDetent = .large }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $pottyDetailPet) { pet in
                QuickPottyDetailSheet(pet: pet) {
                    pottyDetailPet = nil
                    if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "potty" }) {
                        removeQuickAction(found)
                    }
                }
                .onAppear { quickActionDetailSheetDetent = .large }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $litterDetailPet) { pet in
                QuickLitterDetailSheet(pet: pet) {
                    litterDetailPet = nil
                    if let found = savedQuickActionItems.first(where: { $0.petId == pet.id && $0.actionType == "litter" }) {
                        removeQuickAction(found)
                    }
                }
                .onAppear { quickActionDetailSheetDetent = .large }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
            // 卡片背面 — 功能入口 sheets（独立 background context 避免编译器类型检查超时）
            .background(cardBackSheets)
    }


    // MARK: - 卡片背面功能入口 sheets（独立 computed property，打破类型检查链）
    @ViewBuilder private var cardBackSheets: some View {
        Color.clear
            // 设置
            .sheet(item: $cardBackSettingsPet) { pet in
                PetCardBackSettingsSheet(pet: pet)
            }
            // 健康管理
            .sheet(item: $cardBackHealthPet) { pet in
                NavigationStack { PetHealthDetailView(pet: pet, isModal: true) }
            }
            .sheet(item: $cardBackMedicationsPet) { pet in
                NavigationStack { PetMedicationView(pet: pet) }
            }
            .sheet(item: $cardBackWeightPet) { pet in
                NavigationStack { WeightHistoryView(pet: pet) }
            }
            // 日常生活
            .sheet(item: $cardBackFoodPet) { pet in
                NavigationStack { PetFoodManagementView(pet: pet) }
            }
            .sheet(item: $cardBackHygienePet) { pet in
                NavigationStack { PetHygieneDetailView(pet: pet) }
            }
            .sheet(item: $cardBackWalksPet) { pet in
                WalkSummarySheet(pet: pet)
            }
            .sheet(item: $cardBackPottyPet) { pet in
                NavigationStack { PottyOverviewView(pet: pet) }
            }
            .sheet(item: $cardBackExpensesPet) { pet in
                NavigationStack { ExpenseHistoryView(pet: pet) }
            }
            // 档案证件
            .sheet(item: $cardBackBasicInfoPet) { pet in
                NavigationStack { PetBasicInfoDetailView(pet: pet) }
            }
            .sheet(item: $cardBackDocumentsPet) { pet in
                NavigationStack { DocumentsListView(pet: pet) }
            }
            // 记忆成长
            .sheet(item: $cardBackMomentsPet) { pet in
                PetMomentsHubView(pet: pet)
            }
            .sheet(item: $cardBackCalendarPet) { pet in
                NavigationStack { CalendarView(preselectedPetId: pet.id.uuidString) }
            }
            .sheet(item: $cardBackAchievementsPet) { pet in
                AchievementWallView(pet: pet)
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

    /// 是否存在「按计划喂食」日历事件（用于计划模式下判断卡片状态）
    private func petHasPlannedFeedSchedules(_ pet: Pet) -> Bool {
        let id = pet.id.uuidString
        return allEvents.contains { ev in
            (ev.relatedEntityType == EntityKind.pet.rawValue || ev.relatedEntityType == "pet")
                && ev.relatedEntityId == id
                && ev.eventType == EventType.foodChange.rawValue
        }
    }

    /// 与 `pendingFeedReminderForPlannedMode` 相同规则，用于判断 Reminder 是否属于该宠物的计划喂食
    private func isPlannedFeedReminder(_ reminder: Reminder, petIdStr: String) -> Bool {
        guard reminder.event?.relatedEntityId == petIdStr else { return false }
        let exactTypes: Set<String> = [EventType.foodChange.rawValue]
        let titleKeywords = ["喂食", "吃饭", "喂"]
        let evType = reminder.event?.eventType ?? ""
        if exactTypes.contains(evType) { return true }
        if evType == EventType.daily.rawValue || evType == EventType.task.rawValue {
            let evTitle = (reminder.event?.title ?? "").lowercased()
            return titleKeywords.contains { evTitle.contains($0) }
        }
        return false
    }

    /// 今日有计划喂食 Reminder 已记为失败（到点未打卡）
    private func hasFailedPlannedFeedToday(pet: Pet) -> Bool {
        guard HomeFeedRecordMode.isPlanned(for: pet.id) else { return false }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return failedReminders.contains {
            cal.isDateInToday($0.scheduledAt) && isPlannedFeedReminder($0, petIdStr: petIdStr)
        }
    }

    /// 最近的未来计划喂食时间点（用于首页副标题「下次 HH:mm」）
    private func nextPlannedFeedSlotDate(pet: Pet) -> Date? {
        let petIdStr = pet.id.uuidString
        let now = Date()
        let candidates = pendingReminders.filter {
            $0.scheduledAt > now && isPlannedFeedReminder($0, petIdStr: petIdStr)
        }
        return candidates.map(\.scheduledAt).min()
    }

    /// 首页喂水卡是否处于「换水」展示模式（按宠物独立存储）
    private func waterQuickDisplayUsesChangeMode(for petId: UUID?) -> Bool {
        guard let petId else { return false }
        let key = "waterSheetMode_\(petId.uuidString)"
        let mode = UserDefaults.standard.string(forKey: key) ?? UserDefaults.standard.string(forKey: "waterSheetMode") ?? "drink"
        return mode == "change"
    }

    /// 换水卡副标题：上次 / 下次换水（取与「今天」更近的一侧）
    private func waterChangeSubtitle(for pet: Pet) -> String? {
        let cal = Calendar.current
        let petKey = pet.id.uuidString
        let interval = {
            let i = UserDefaults.standard.integer(forKey: "waterInterval_\(petKey)")
            return i > 0 ? i : 3
        }()
        let logs = pet.careLogs.filter { $0.type == CareType.waterChange.rawValue }
        guard let last = logs.map(\.date).max() else {
            return "尚未记录换水"
        }
        let today = cal.startOfDay(for: Date())
        let lastDay = cal.startOfDay(for: last)
        guard let rawNext = cal.date(byAdding: .day, value: interval, to: lastDay) else { return nil }
        let nextDay = cal.startOfDay(for: rawNext)
        let daysSinceLast = abs(cal.dateComponents([.day], from: lastDay, to: today).day ?? 0)
        let daysToNext = cal.dateComponents([.day], from: today, to: nextDay).day ?? 0
        if nextDay <= today {
            return daysSinceLast == 0 ? "今天已换水" : "上次 \(daysSinceLast) 天前换水·已逾期"
        }
        if daysSinceLast <= max(0, daysToNext) {
            return daysSinceLast == 0 ? "今天已换水" : "上次 \(daysSinceLast) 天前换水"
        }
        return "下次 \(nextDay.formatted(.dateTime.month(.defaultDigits).day())) 换水"
    }

    /// 铲屎卡副标题：上次 / 下次（由间隔与起算日推算）
    private func scoopScheduleSubtitle(for pet: Pet) -> String? {
        let cal = Calendar.current
        let petKey = pet.id.uuidString
        let interval = {
            let i = UserDefaults.standard.integer(forKey: "scoopIntervalDays_\(petKey)")
            return i > 0 ? i : 1
        }()
        let anchorTI = UserDefaults.standard.double(forKey: "scoopAnchorDate_\(petKey)")
        let today = cal.startOfDay(for: Date())
        let anchorDay = anchorTI > 0
            ? cal.startOfDay(for: Date(timeIntervalSince1970: anchorTI))
            : today
        let last = pet.careLogs.filter { $0.type == CareType.litter.rawValue }.map(\.date).max()
        var base = anchorDay
        if let last { base = max(base, cal.startOfDay(for: last)) }
        var next = cal.date(byAdding: .day, value: interval, to: base) ?? base
        while next < today {
            next = cal.date(byAdding: .day, value: interval, to: next) ?? next
        }
        let lastDay = last.map { cal.startOfDay(for: $0) }
        let dLast = lastDay.map { abs(cal.dateComponents([.day], from: $0, to: today).day ?? 0) }
        let dNext = abs(cal.dateComponents([.day], from: today, to: next).day ?? 0)
        if let dLast, dLast <= dNext {
            return dLast == 0 ? "今天已铲屎" : "上次 \(dLast) 天前铲屎"
        }
        if dNext == 0 { return "建议今天铲屎" }
        return "下次 \(next.formatted(.dateTime.month(.defaultDigits).day())) 铲屎"
    }

    /// 换猫砂（UserDefaults 周期）副标题
    private func litterFullChangeSubtitle(for pet: Pet) -> String? {
        let cal = Calendar.current
        let petKey = pet.id.uuidString
        let interval = {
            let i = UserDefaults.standard.integer(forKey: "litterChangeInterval_\(petKey)")
            return i > 0 ? i : 14
        }()
        let anchorTI = UserDefaults.standard.double(forKey: "litterChangeCycleAnchor_\(petKey)")
        let lastTI = UserDefaults.standard.double(forKey: "lastLitterChangeDate_\(petKey)")
        let today = cal.startOfDay(for: Date())
        let anchorDay: Date = {
            if anchorTI > 0 { return cal.startOfDay(for: Date(timeIntervalSince1970: anchorTI)) }
            if lastTI > 0 { return cal.startOfDay(for: Date(timeIntervalSince1970: lastTI)) }
            return today
        }()
        let lastDay = lastTI > 0 ? cal.startOfDay(for: Date(timeIntervalSince1970: lastTI)) : nil
        var next: Date
        if let ld = lastDay {
            var d = cal.date(byAdding: .day, value: interval, to: ld) ?? ld
            while d < today {
                d = cal.date(byAdding: .day, value: interval, to: d) ?? d
            }
            next = d
        } else {
            var d = anchorDay
            while d < today {
                d = cal.date(byAdding: .day, value: interval, to: d) ?? d
            }
            next = d
        }
        let dLast = lastDay.map { abs(cal.dateComponents([.day], from: $0, to: today).day ?? 0) }
        let dNext = abs(cal.dateComponents([.day], from: today, to: next).day ?? 0)
        if cal.startOfDay(for: next) <= today {
            let dl = dLast ?? 0
            return dl == 0 ? "今天已换砂" : "上次 \(dl) 天前换砂·已逾期"
        }
        if let dLast, dLast <= dNext {
            return dLast == 0 ? "今天已换砂" : "上次 \(dLast) 天前换砂"
        }
        return "下次 \(next.formatted(.dateTime.month(.defaultDigits).day())) 换砂"
    }

    private func substrateChangeSubtitle(for pet: Pet) -> String? {
        let cal = Calendar.current
        let petKey = pet.id.uuidString
        let interval = {
            let i = UserDefaults.standard.integer(forKey: "substrateChangeInterval_\(petKey)")
            return i > 0 ? i : 14
        }()
        let logs = pet.careLogs.filter { $0.type == CareType.substrateChange.rawValue }
        guard let last = logs.map(\.date).max() else {
            return "尚未换垫材"
        }
        let today = cal.startOfDay(for: Date())
        let lastDay = cal.startOfDay(for: last)
        guard let rawNext = cal.date(byAdding: .day, value: interval, to: lastDay) else { return nil }
        let nextDay = cal.startOfDay(for: rawNext)
        let daysSinceLast = abs(cal.dateComponents([.day], from: lastDay, to: today).day ?? 0)
        let daysToNext = cal.dateComponents([.day], from: today, to: nextDay).day ?? 0
        if nextDay <= today {
            return daysSinceLast == 0 ? "今天已换" : "上次 \(daysSinceLast) 天前·已逾期"
        }
        if daysSinceLast <= max(0, daysToNext) {
            return daysSinceLast == 0 ? "今天已换" : "上次 \(daysSinceLast) 天前换垫材"
        }
        return "下次 \(nextDay.formatted(.dateTime.month(.defaultDigits).day())) 换垫材"
    }

    /// 仅在「按计划」模式下返回今日喂食待办；手动模式下不显示红点，避免与手动打卡混淆
    private func pendingFeedReminderForPlannedMode(pet: Pet) -> Reminder? {
        guard HomeFeedRecordMode.isPlanned(for: pet.id) else { return nil }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return pendingReminders.first { reminder in
            cal.isDateInToday(reminder.scheduledAt) && isPlannedFeedReminder(reminder, petIdStr: petIdStr)
        }
    }

    /// 首页喂食卡片：手动=达手动餐数目标；计划=无待办、无今日失败记录且已有计划表
    private func feedQuickActionAppearsComplete(for pet: Pet) -> Bool {
        let cal = Calendar.current
        if HomeFeedRecordMode.isPlanned(for: pet.id) {
            guard petHasPlannedFeedSchedules(pet) else { return false }
            if hasFailedPlannedFeedToday(pet: pet) { return false }
            return pendingFeedReminderForPlannedMode(pet: pet) == nil
        }
        let storedGoal = UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)")
        let goal = storedGoal > 0 ? storedGoal : 3
        let manualCount = pet.careLogs.filter {
            cal.isDateInToday($0.date)
                && $0.type == CareType.feeding.rawValue
                && $0.isManualFeedLogEntry
        }.count
        return manualCount >= goal
    }

    @discardableResult
    private func completePlannedFeedFromHome(pet: Pet) -> Bool {
        guard let reminder = pendingFeedReminderForPlannedMode(pet: pet),
              let event = reminder.event else { return false }
        let amount = Double(event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
            ?? pet.dailyPortionGrams
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let planNote = "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)"
        let log = PetCareLog(date: Date(), type: .feeding, amountGrams: amount, note: planNote, pet: pet, executorId: eid)
        modelContext.insert(log)
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        modelContext.safeSave()
        QuestManager.shared.recordFirstMeal()
        let feedGot = QuestManager.shared.awardAction(type: .feed, pet: pet, context: modelContext)
        showToast(pet, message: "\(pet.name) 计划喂食打卡 +\(feedGot.petGot + feedGot.humanGot)🥥", emoji: "🍗")
        return true
    }

    // Task31 / Task45: 找到该 item 对应宠物今日待办，严格按 actionType 匹配，禁止跨卡片类型溢出
    private func reminderForAction(_ item: QuickActionItem) -> Reminder? {
        guard let pid = item.petId,
              let pet = pets.first(where: { $0.id == pid }) else { return nil }
        if item.actionType == "feed" {
            return pendingFeedReminderForPlannedMode(pet: pet)
        }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current

        // 精确 EventType（非 daily），命中即返回
        let exactTypes: Set<String> = {
            switch item.actionType {
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

    /// 长按打开详情 sheet 且 sheet 内已有「移除此快捷入口」时，不在网格 context menu 中重复提供移除，避免菜单盖住 sheet
    private func quickActionUsesDetailSheetRemove(_ actionType: String) -> Bool {
        ["feed", "water", "waterChange", "filterClean", "play", "potty", "litter", "weight", "expense", "health"].contains(actionType)
    }

    // MARK: - Quick Action Edit Mode

    private func enterQAEditMode() {
        qaEditItems = activeQuickActionItems
        withAnimation(.spring(response: 0.3)) { isQAEditMode = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) { qaJiggle = true }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func exitQAEditMode() {
        // 保存编辑后的排序与删除结果回 savedQuickActionItems
        saveQAEditItems(qaEditItems)
        withAnimation(.spring(response: 0.3)) { isQAEditMode = false }
        withAnimation(nil) { qaJiggle = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 将编辑模式中修改过的 activeQuickActionItems 写回完整 savedQuickActionItems
    private func saveQAEditItems(_ edited: [QuickActionItem]) {
        var saved = savedQuickActionItems
        let activeIds = Set(activeQuickActionItems.map { $0.id })
        // 找到原始 active 区域的第一个插入点
        let insertionIdx = saved.firstIndex(where: { activeIds.contains($0.id) }) ?? saved.count
        // 移除旧的 active 条目
        saved.removeAll { activeIds.contains($0.id) }
        // 在原位置插回编辑后的条目
        let clamped = min(insertionIdx, saved.count)
        saved.insert(contentsOf: edited, at: clamped)
        if let data = try? JSONEncoder().encode(saved),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    // MARK: - Phase 5: Bento Card Visual States

    private enum BentoCardState: Equatable {
        case urgentPending   // 未完成·紧急
        case normalPending   // 未完成·普通
        case completed       // 已完成
        case notRequired     // 今日无需
    }

    private func bentoCardState(for item: QuickActionItem) -> BentoCardState {
        // 已完成优先
        if isCompletedToday(for: item) { return .completed }

        // 体重：本周已记录则「今日无需」
        if item.actionType == "weight" {
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
                if pet.weightLogs.contains(where: { $0.date > weekAgo }) { return .notRequired }
            }
        }

        // 花费：始终普通待办（无完成态）
        if item.actionType == "expense" { return .normalPending }

        // 有待办提醒 → 紧急（喂食仅保留角标红点，不套橙色外框）
        if item.actionType != "feed", reminderForAction(item) != nil { return .urgentPending }

        return .normalPending
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
        case "feed":
            feedDetailPet = p
        case "water", "waterChange", "filterClean":
            waterDetailPet = p
        case "play":
            playDetailPet = p
        case "potty":
            pottyDetailPet = p
        case "litter":
            litterDetailPet = p
        case "health":
            quickHealthDetailPet = p
        case "hygiene", "groom", "bath":
            quickGroomDetailPet = p
        case "walk":
            quickWalkDetailPet = p
        case "weight":
            quickWeightDetailPet = p
        case "expense":
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
            return feedQuickActionAppearsComplete(for: pet)
        case "water":
            if waterQuickDisplayUsesChangeMode(for: pet.id) {
                return pet.careLogs.contains { $0.type == CareType.waterChange.rawValue && cal.isDateInToday($0.date) }
            }
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
        case "substrateChange":
            return pet.careLogs.contains { $0.type == CareType.substrateChange.rawValue && cal.isDateInToday($0.date) }
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
            if HomeFeedRecordMode.isPlanned(for: pid) {
                if !petHasPlannedFeedSchedules(pet) { return "请添加时间表" }
                let failedToday = hasFailedPlannedFeedToday(pet: pet)
                if let next = nextPlannedFeedSlotDate(pet: pet) {
                    let t = next.formatted(.dateTime.hour().minute())
                    return failedToday ? "未打卡·下次 \(t)" : "下次 \(t)"
                }
                if let pending = pendingFeedReminderForPlannedMode(pet: pet) {
                    let t = pending.scheduledAt.formatted(.dateTime.hour().minute())
                    return failedToday ? "未打卡·\(t)" : "下次 \(t)"
                }
                if failedToday { return "计划打卡已失败" }
                return "今日计划已完成"
            }
            let storedGoal = UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)")
            let goal = storedGoal > 0 ? storedGoal : 3
            let manualCount = pet.careLogs.filter {
                $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) && $0.isManualFeedLogEntry
            }.count
            return "手动 \(manualCount)/\(goal)餐"
        case "water":
            if waterQuickDisplayUsesChangeMode(for: pid) {
                return waterChangeSubtitle(for: pet)
            }
            let count = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "litter":
            let scoop = scoopScheduleSubtitle(for: pet)
            let full = litterFullChangeSubtitle(for: pet)
            if let scoop, let full { return "\(scoop) · \(full)" }
            return scoop ?? full
        case "substrateChange":
            return substrateChangeSubtitle(for: pet)
        case "potty":
            let count = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "play":
            let count = pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日逗玩 \(count)次" : "今日未逗玩"
        case "groom":
            let count = pet.hygieneLogs.filter { cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "expense":
            let now = Date()
            let monthTotal = pet.expenseLogs
                .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
                .reduce(0.0) { $0 + $1.amount }
            return monthTotal > 0 ? "本月 ¥\(String(format: "%.0f", monthTotal))" : nil
        case "weight":
            if let last = pet.weightLogs.sorted(by: { $0.date < $1.date }).last {
                return "上次 \(String(format: "%.1f", last.weight))kg"
            }
            return nil
        case "waterChange":
            if let last = pet.careLogs.filter({ $0.type == CareType.waterChange.rawValue }).sorted(by: { $0.date < $1.date }).last {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已换" : "\(days)天前换水"
            }
            return nil
        case "filterClean":
            if let last = pet.careLogs.filter({ $0.type == CareType.filterClean.rawValue }).sorted(by: { $0.date < $1.date }).last {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已清" : "\(days)天前"
            }
            return nil
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

    /// 岛屿委托轮播「完成打卡」：与 Bento 同路径，避免数据分叉
    @MainActor
    private func completeIslandQuest(_ quest: IslandQuest) {
        switch quest.id {
        case "q_walk":
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) {
                applyAction("walk", pet: p)
            }
        case "q_potty":
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) {
                applyAction("potty", pet: p)
            }
        case "q_water_plant":
            if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                completePlantWatering(pl)
            }
        case "q_fertilize_plant":
            if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                completePlantFertilizing(pl)
            }
        case "q_visit":
            IslandQuestEngine.markVisited()
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) {
                selectedPet = p
            } else if let p = pets.first {
                selectedPet = p
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "q_reminder":
            showingCalendar = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        default:
            if let mid = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
                for p in pets {
                    if let med = p.medications.first(where: { $0.id == mid }) {
                        PetMedicationDoseLogging.recordDose(medication: med, pet: p, modelContext: modelContext)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        break
                    }
                }
            }
        }
        let amt = IslandQuestEngine.coconutReward(forQuestId: quest.id)
        if amt > 0 {
            triggerCoconutReward(amount: amt, label: nil)
        }
    }

    @MainActor
    private func completePlantWatering(_ plant: Plant) {
        plant.lastWateredDate = Date()
        let log = PlantCareLog(date: Date(), careType: .watering)
        log.plant = plant
        modelContext.insert(log)
        let event = Event(
            title: "💧 给 \(plant.name) 浇水",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    private func completePlantFertilizing(_ plant: Plant) {
        plant.lastFertilizedDate = Date()
        let log = PlantCareLog(date: Date(), careType: .fertilizing)
        log.plant = plant
        modelContext.insert(log)
        let event = Event(
            title: "🌿 给 \(plant.name) 施肥",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.fertilizing.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func handleAction(_ item: QuickActionItem) {
        switch item.actionType {
        case "calendar": showingCalendar = true
        case "add":      showingAddEntity = true
        case "moment":
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                showMomentPet = pet
            } else {
                showMomentPet = pets.first
            }
        case "health", "navigate_health":
            // 直接打开健康详情 Sheet，避免先进入宠物详情再切 Tab
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                quickHealthDetailPet = pet
            } else if let first = pets.first {
                quickHealthDetailPet = first
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

    private func applyPottyCheckIn(_ raw: String, pet: Pet) {
        let type = PottyType(rawValue: raw) ?? .perfectPoop
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetPottyLog(date: Date(), type: type, pet: pet, executorId: eid)
        modelContext.insert(log)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let got = QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
        showToast(pet, message: "\(pet.name) \(type.emoji)\(type.rawValue) +\(got.petGot + got.humanGot)🥥", emoji: type.emoji)
    }

    private func applyHealthCheckIn(_ raw: String, pet: Pet) {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        
        switch raw {
        case "symptom":
            // 打开添加症状 sheet
            showingAddSymptomSheet = true
            symptomSheetPet = pet
            let got = QuestManager.shared.awardAction(type: .general(humanReward: 5, petReward: 3, emoji: "⚠️", title: "\(pet.name) 记录症状"), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 准备记录症状 +\(got.petGot + got.humanGot)🥥", emoji: "⚠️")
        case "vaccine":
            // 快速打卡疫苗（创建健康记录）
            let record = PetHealthLog(date: Date(), type: .vaccine, note: "快捷打卡", pet: pet)
            modelContext.insert(record)
            modelContext.safeSave()
            let got = QuestManager.shared.awardAction(type: .general(humanReward: 10, petReward: 8, emoji: "💉", title: "\(pet.name) 疫苗记录"), pet: pet, context: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(pet, message: "\(pet.name) 疫苗记录 +\(got.petGot + got.humanGot)🥥", emoji: "💉")
        case "deworming":
            // 快速打卡驱虫
            let record = PetHealthLog(date: Date(), type: .dewormingExternal, note: "快捷打卡", pet: pet)
            modelContext.insert(record)
            modelContext.safeSave()
            let got = QuestManager.shared.awardAction(type: .general(humanReward: 10, petReward: 8, emoji: "💊", title: "\(pet.name) 驱虫记录"), pet: pet, context: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(pet, message: "\(pet.name) 驱虫记录 +\(got.petGot + got.humanGot)🥥", emoji: "💊")
        case "visit":
            // 快速打卡就诊
            let record = PetHealthLog(date: Date(), type: .checkup, note: "快捷打卡", pet: pet)
            modelContext.insert(record)
            modelContext.safeSave()
            let got = QuestManager.shared.awardAction(type: .general(humanReward: 8, petReward: 5, emoji: "🏥", title: "\(pet.name) 就诊记录"), pet: pet, context: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(pet, message: "\(pet.name) 就诊记录 +\(got.petGot + got.humanGot)🥥", emoji: "🏥")
        case "heatCycle":
            // 打开添加生理期 sheet（仅未绝育宠物）
            if !pet.isNeutered {
                showingAddHeatCycleSheet = true
                heatCycleSheetPet = pet
                let got = QuestManager.shared.awardAction(type: .general(humanReward: 3, petReward: 2, emoji: "🌸", title: "\(pet.name) 记录生理期"), pet: pet, context: modelContext)
                showToast(pet, message: "\(pet.name) 准备记录生理期 +\(got.petGot + got.humanGot)🥥", emoji: "🌸")
            } else {
                showToast(pet, message: "\(pet.name) 已绝育，无需记录", emoji: "✅")
            }
        default:
            break
        }
    }

    private func showToast(_ pet: Pet, message: String, emoji: String, duration: Double = 1.5) {
        actionToast = (pet: pet, message: message, emoji: emoji)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { actionToast = nil }
    }

    /// 与 `ArkCrewIDCardView.performSpecialCareCheckIn` 奖励一致；首页快捷操作单击打卡
    private func applySpecialCareCheckIn(type: CareType, pet: Pet) {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetCareLog(date: Date(), type: type, pet: pet, executorId: eid)
        modelContext.insert(log)
        modelContext.safeSave()
        let oat: QuestManager.OhanaActionType
        switch type {
        case .waterChange:
            oat = .general(humanReward: 15, petReward: 20, emoji: type.emoji, title: "\(pet.name) 换水奖励")
        case .filterClean:
            oat = .general(humanReward: 25, petReward: 40, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            oat = .general(humanReward: 15, petReward: 20, emoji: type.emoji, title: "\(pet.name) 清理鸟笼报酬")
        case .freeFlight:
            oat = .general(humanReward: 10, petReward: 12, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            oat = .general(humanReward: 3, petReward: 4, emoji: type.emoji, title: "\(pet.name) 喷水保湿奖励")
        case .substrateChange:
            oat = .general(humanReward: 15, petReward: 22, emoji: type.emoji, title: "\(pet.name) 换垫材报酬")
        default:
            oat = .general(humanReward: 3, petReward: 3, emoji: type.emoji, title: "\(pet.name) 打卡奖励")
        }
        let got = QuestManager.shared.awardAction(type: oat, pet: pet, context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(pet, message: "\(pet.name) \(type.label) +\(got.petGot + got.humanGot)🥥", emoji: type.emoji)
    }

    private func applyAction(_ actionType: String, pet: Pet) {
        let currentUserId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        
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
        case "hygiene", "groom":
            // groom 单击由 GoQuickActionCard.isGroom 内部弹 GroomMenuSheet 处理；此处兜底
            quickAccessCarePet = pet
        case "potty":
            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: currentUserId)
            modelContext.insert(log)
            let pottyGot = QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 便便打卡 +\(pottyGot.petGot + pottyGot.humanGot)🥥", emoji: "💩")
        case "litter":
            let litterLog = PetCareLog(date: Date(), type: .litter, pet: pet, executorId: currentUserId)
            modelContext.insert(litterLog)
            let litterGot = QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 铲猫砂 +\(litterGot.humanGot)🥥", emoji: "🧹")
        case "feed":
            let performFeed = {
                if HomeFeedRecordMode.isPlanned(for: pet.id) {
                    if self.completePlannedFeedFromHome(pet: pet) { return }
                    if !self.petHasPlannedFeedSchedules(pet) {
                        self.feedDetailPet = pet
                    } else {
                        self.showToast(pet, message: "\(pet.name) 今日计划暂无待打卡", emoji: "🍗")
                    }
                } else {
                    let grams = pet.dailyPortionGrams
                    let log = PetCareLog(date: Date(), type: .feeding, amountGrams: grams, note: PetCareLog.manualFeedNoteMarker, pet: pet, executorId: currentUserId)
                    self.modelContext.insert(log)
                    self.modelContext.safeSave()
                    QuestManager.shared.recordFirstMeal()
                    let feedGot = QuestManager.shared.awardAction(type: .feed, pet: pet, context: self.modelContext)
                    self.showToast(pet, message: "\(pet.name) 手动喂食 +\(feedGot.petGot + feedGot.humanGot)🥥", emoji: "🍗")
                }
            }
            
            if let warning = AntiRepeatCareManager.checkRecentCareLog(for: pet, type: .feeding, thresholdMinutes: 120, currentUserId: currentUserId, in: humans) {
                antiRepeatTitle = "重复喂食提醒"
                antiRepeatMessage = "\(warning.executorName) 在 \(warning.minutesAgo) 分钟前刚喂过 \(pet.name) ，确定要再喂一次吗？"
                pendingRepeatAction = performFeed
                showingAntiRepeatAlert = true
            } else {
                performFeed()
            }
            
        case "water":
            if waterQuickDisplayUsesChangeMode(for: pet.id) {
                applySpecialCareCheckIn(type: .waterChange, pet: pet)
            } else {
                let performWater = {
                    let log = PetCareLog(date: Date(), type: .watering, amountGrams: 0, pet: pet, executorId: currentUserId)
                    self.modelContext.insert(log)
                    let waterGot = QuestManager.shared.awardAction(type: .water, pet: pet, context: self.modelContext)
                    self.showToast(pet, message: "\(pet.name) 喂水打卡 +\(waterGot.petGot + waterGot.humanGot)🥥", emoji: "💧")
                }
                
                if let warning = AntiRepeatCareManager.checkRecentCareLog(for: pet, type: .watering, thresholdMinutes: 60, currentUserId: currentUserId, in: humans) {
                    antiRepeatTitle = "重复喂水提醒"
                    antiRepeatMessage = "\(warning.executorName) 在 \(warning.minutesAgo) 分钟前刚喂过 \(pet.name) 水，确定要再记录一次吗？"
                    pendingRepeatAction = performWater
                    showingAntiRepeatAlert = true
                } else {
                    performWater()
                }
            }
        case "bath":
            let log = PetHygieneLog(date: Date(), type: .bath, pet: pet)
            modelContext.insert(log)
            let bathGot = QuestManager.shared.awardAction(type: .care(type: .bath), pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 洗澡打卡 +\(bathGot.petGot + bathGot.humanGot)🥥", emoji: "🛁")
        case "play":
            let eidP = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            let playLog = PetCareLog(date: Date(), type: .play, pet: pet, executorId: eidP)
            modelContext.insert(playLog)
            let oat = QuestManager.OhanaActionType.general(humanReward: 10, petReward: 12, emoji: "🎾", title: "\(pet.name) 互动奖励")
            let playGot = QuestManager.shared.awardAction(type: oat, pet: pet, context: modelContext)
            showToast(pet, message: "\(pet.name) 逗玩打卡 +\(playGot.petGot + playGot.humanGot)🥥", emoji: "🎾")
        case "waterChange":
            applySpecialCareCheckIn(type: .waterChange, pet: pet)
        case "filterClean":
            applySpecialCareCheckIn(type: .filterClean, pet: pet)
        case "cageCleaning":
            applySpecialCareCheckIn(type: .cageCleaning, pet: pet)
        case "freeFlight":
            applySpecialCareCheckIn(type: .freeFlight, pet: pet)
        case "misting":
            applySpecialCareCheckIn(type: .misting, pet: pet)
        case "substrateChange":
            applySpecialCareCheckIn(type: .substrateChange, pet: pet)
        default:
            selectedPetTab = .overview
            selectedPet = pet
        }
    }

    // MARK: - Legacy sections removed in Phase 59 (extracted / dead code cleanup)
    
    // MARK: - Empty State (Go UI Style)
    @State private var islandBounce: CGFloat = 0
    @State private var islandRotate: Double = 0
    @State private var emptyParticlePhase: Double = 0
    @State private var emptyAppeared: Bool = false

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            // 漂浮气泡装饰层 + 主视觉岛屿
            ZStack {
                let floatEmojis = ["🐾", "🌿", "💛", "🐟", "🌸", "⭐️"]
                let floatOffsets: [(CGFloat, CGFloat)] = [(-120,-60),(110,-80),(-90,40),(130,20),(-50,90),(70,80)]
                ForEach(0..<6, id: \.self) { i in
                    Text(floatEmojis[i])
                        .font(OhanaFont.metric(size: 18, .medium))
                        .offset(x: floatOffsets[i].0,
                                y: floatOffsets[i].1 + (emptyParticlePhase > 0 ? sin(emptyParticlePhase + Double(i)) * 6 : 0))
                        .opacity(0.45)
                }

                ZStack {
                    Circle().fill(Color.goPrimary.opacity(0.10)).frame(width: 150, height: 150)
                    Circle().strokeBorder(Color.goPrimary.opacity(0.18), lineWidth: 1.5).frame(width: 150, height: 150)
                    Text("🏝️")
                        .font(OhanaFont.metric(size: 72, .medium))
                        .offset(y: islandBounce)
                        .rotationEffect(.degrees(islandRotate))
                }
            }
            .frame(height: 200)
            .padding(.bottom, 12)

            Text("欢迎来到 Ohana 岛")
                .font(OhanaFont.metric(size: 32, .black))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .opacity(emptyAppeared ? 1 : 0)
                .offset(y: emptyAppeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: emptyAppeared)
                .padding(.bottom, 10)

            VStack(spacing: 6) {
                Text("Ohana 的意思是\u{201C}家人\u{201D}")
                    .font(OhanaFont.body(.bold))
                    .foregroundStyle(Color.goPrimary)
                Text("没有人会被遗忘，也不会被抛下")
                    .font(OhanaFont.callout(.medium))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            .multilineTextAlignment(.center)
            .opacity(emptyAppeared ? 1 : 0)
            .offset(y: emptyAppeared ? 0 : 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: emptyAppeared)
            .padding(.bottom, 44)

            Button { showingAddEntity = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").font(OhanaFont.title2(.black))
                    Text("开始建岛").font(OhanaFont.metric(size: 18, .black))
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.goPrimary, in: Capsule())
                .shadow(color: Color.goPrimary.opacity(0.45), radius: 20, x: 0, y: 8)
            }
            .padding(.horizontal, 36)
            .opacity(emptyAppeared ? 1 : 0)
            .scaleEffect(emptyAppeared ? 1 : 0.85)
            .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.3), value: emptyAppeared)

            Spacer()
        }
        .onAppear {
            emptyAppeared = true
            emptyParticlePhase = Double.pi
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { islandBounce = -10 }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) { islandRotate = 4 }
        }
    }

    private func emptyStateStep(emoji: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(emoji).font(OhanaFont.metric(size: 22, .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(OhanaFont.footnote(.medium))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(OhanaFont.caption(.semibold))
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
                    .font(OhanaFont.metric(size: 56, .medium))
                Text("带你的毛孩子来！")
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(.primary)
                Text("添加第一只宠物，开启椰子奖励之旅")
                    .font(OhanaFont.callout(.medium))
                    .foregroundStyle(.primary.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("🥥")
                        .font(OhanaFont.metric(size: 28, .medium))
                    Text("+10")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.goPrimary)
                    Text("添加宠物")
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))

                VStack(spacing: 4) {
                    Text("💩")
                        .font(OhanaFont.metric(size: 28, .medium))
                    Text("+1")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.goPrimary)
                    Text("每次打卡")
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))

                VStack(spacing: 4) {
                    Text("🦮")
                        .font(OhanaFont.metric(size: 28, .medium))
                    Text("+N")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.goPrimary)
                    Text("遛狗奖励")
                        .font(OhanaFont.caption(.medium))
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
                        .font(OhanaFont.metric(size: 18, .black))
                    Text("添加第一只宠物")
                        .font(OhanaFont.title3(.black))
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.goPrimary, in: Capsule())
                .shadow(color: Color.goPrimary.opacity(0.4), radius: 12, x: 0, y: 6)
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
                let filteredPlants = plants.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.species.localizedCaseInsensitiveContains(searchText) }
                
                if !filteredPets.isEmpty {
                    Text("PETS")
                        .font(OhanaFont.footnote(.black))
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
                                        .font(OhanaFont.metric(size: 24, .medium))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pet.name)
                                        .font(OhanaFont.headline(.bold))
                                        .foregroundStyle(.primary)
                                    Text("\(pet.species) · \(pet.breed)")
                                        .font(OhanaFont.footnote(.medium))
                                        .foregroundStyle(.primary.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(OhanaFont.footnote(.bold))
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
                        .font(OhanaFont.footnote(.black))
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
                                        .font(OhanaFont.metric(size: 24, .medium))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(human.name)
                                        .font(OhanaFont.headline(.bold))
                                        .foregroundStyle(.primary)
                                    Text(human.roleText)
                                        .font(OhanaFont.footnote(.medium))
                                        .foregroundStyle(.primary.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(OhanaFont.footnote(.bold))
                                    .foregroundStyle(.primary.opacity(0.3))
                            }
                            .padding(12)
                            .goTranslucentCard(cornerRadius: 16)
                        }
                        .padding(.horizontal, 16)
                    }
                }

                if !filteredPlants.isEmpty {
                    Text("PLANTS")
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(.primary.opacity(0.35))
                        .tracking(2)
                        .padding(.horizontal, 16)

                    ForEach(filteredPlants) { plant in
                        Button { selectedPlant = plant } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color(hex: plant.themeColorHex).opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Text(plant.avatarEmoji)
                                        .font(OhanaFont.metric(size: 24, .medium))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plant.name)
                                        .font(OhanaFont.headline(.bold))
                                        .foregroundStyle(.primary)
                                    Text(plant.species)
                                        .font(OhanaFont.footnote(.medium))
                                        .foregroundStyle(.primary.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(OhanaFont.footnote(.bold))
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

// MARK: - QADropDelegate（快捷操作拖拽排序）
/// 编辑模式拖拽层：自定义预览仅图标+标题（无整张卡片矩形）
private struct QAEditModeDragLayer: View {
    let item: QuickActionItem
    let themeHex: String?

    var body: some View {
        Color.clear
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .draggable(item.id) {
                QuickActionReorderDragPreview(item: item, themeHex: themeHex)
            }
    }
}

struct QADropDelegate: DropDelegate {
    let targetItem: QuickActionItem
    @Binding var items: [QuickActionItem]

    func performDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) {
        let types: [UTType] = [.plainText, .utf8PlainText]
        guard let provider = info.itemProviders(for: types).first else { return }
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let ns = obj as? NSString else { return }
            let fromId = ns as String
            guard fromId != targetItem.id else { return }
            DispatchQueue.main.async {
                guard let fromIdx = items.firstIndex(where: { $0.id == fromId }),
                      let toIdx = items.firstIndex(where: { $0.id == targetItem.id })
                else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items.move(
                        fromOffsets: IndexSet(integer: fromIdx),
                        toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
                    )
                }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    @Previewable @Namespace var previewNS
    NavigationStack {
        OverviewView(selectedPet: .constant(nil), selectedHuman: .constant(nil), selectedPlant: .constant(nil), selectedPetTab: .constant(.overview), heroNS: previewNS)
    }
    .modelContainer(SharedModelContainer.make())
}
