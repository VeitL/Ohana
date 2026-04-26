// GoDashboardView.swift
// GO UI 风格首页 — 重构自 OverviewView，蓝色岛屿主题
// 设计规范：GO_Club_UI_Design_Reference.md

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Main View

struct GoDashboardView: View {
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
    @Query private var allHumanMedications: [HumanMedication]
    @Query private var allMedicationLogs: [HumanMedicationLog]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(filter: #Predicate<Reminder> { $0.status == "failed" },
           sort: \Reminder.scheduledAt) private var failedReminders: [Reminder]
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    // MARK: – Sheet state (mirrors OverviewView exactly)
    @State private var showingSettings = false
    @State private var showingAddEntity = false
    @State private var showingCalendar = false
    @State private var showingCrewRoster = false
    @State private var selectedDockTab: Int = 0
    @State private var showingManageSheet = false
    @State private var pressedActionId: String? = nil
    @State private var deckResetFlip: Bool = false
    @State private var showIslandWeight = false
    @State private var showIslandExpense = false
    @State private var showIslandExplore = false
    @State private var showIslandWealth = false
    @State private var showingAllFoodManagement = false
    @State private var quickWeightPet: Pet? = nil
    @State private var quickHumanWeightHuman: Human? = nil
    @State private var quickHumanWorkoutHuman: Human? = nil
    @State private var quickHumanMedicationHuman: Human? = nil
    @State private var quickHumanNoteHuman: Human? = nil
    @State private var quickHumanWeightDetailHuman: Human? = nil
    @State private var quickHumanWorkoutDetailHuman: Human? = nil
    @State private var quickWeightValue: String = ""
    @State private var quickWalkPet: Pet? = nil
    @State private var actionToast: (pet: Pet, message: String, emoji: String)? = nil
    @State private var quickAccessFoodPet: Pet? = nil
    @State private var quickAccessCarePet: Pet? = nil
    @State private var quickWeightDetailPet: Pet? = nil
    @State private var quickExpenseDetailPet: Pet? = nil
    @State private var quickWalkDetailPet: Pet? = nil
    @State private var quickHealthDetailPet: Pet? = nil
    @State private var quickGroomDetailPet: Pet? = nil
    @State private var feedSheetItem: (pet: Pet, actionType: String)? = nil
    @State private var feedDetailPet: Pet? = nil
    @State private var waterDetailPet: Pet? = nil
    @State private var waterDetailModeRaw: String? = nil
    @State private var playDetailPet: Pet? = nil
    @State private var pottyDetailPet: Pet? = nil
    @State private var litterDetailPet: Pet? = nil
    @State private var quickActionDetailSheetDetent: PresentationDetent = .large
    @State private var quickExpensePet: Pet? = nil
    @State private var showingCoconutLog = false
    @State private var showIslandDailyReport = false
    @State private var showOasisReward = false
    @State private var showStreakDetail = false
    @State private var headerStreak: Int = 0
    @State private var showDailyCoconut = false
    @State private var coconutFlyOut = false
    @State private var showRewardCoconut = false
    @State private var rewardCoconutAmount: Int = 20
    @State private var rewardCoconutLabel: String? = nil
    @State private var memoryDismissed = false
    @State private var memoryDragOffset: CGFloat = 0
    @State private var showMomentPet: Pet? = nil
    @State private var isQAEditMode = false
    @State private var qaJiggle = false
    @State private var qaEditItems: [QuickActionItem] = []
    @State private var showingQAQuickAdd = false
    @State private var isCardDragging = false
    @State private var activeHumanId: UUID? = nil
    @State private var showWalkFullScreen = false
    @State private var walkMinimized = false
    @State private var lastWalkPhase: WalkPhase = .idle
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)? = nil
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""
    @State private var showingHumanPrivacyAlert = false
    @State private var showingAddSymptomSheet = false
    @State private var symptomSheetPet: Pet? = nil
    @State private var showingAddHeatCycleSheet = false
    @State private var heatCycleSheetPet: Pet? = nil
    @State private var showingFamilyStripFull = false
    @State private var bentoUrgentGlow = false
    @State private var cardBackHealthPet: Pet? = nil
    @State private var calendarAddEventTrigger = false
    @State private var oasisRulesTrigger = false
    @State private var oasisInventoryTrigger = false
    @State private var homeScrollContentMinY: CGFloat = 0
    @State private var batchPressedId: String? = nil
    @State private var showingBatchCheckInSheet = false
    // Blob animation states (design-system floating-blob background)
    @State private var blobPulse: Bool = false

    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeViewerHumanIdStr: String = ""
    @AppStorage("overview_activeCritterId") private var activeCritterIdStr: String = ""
    @AppStorage("lastIslandReportDate") private var lastIslandReportDate: String = ""
    @AppStorage("customBatchActions") private var customBatchActionsJSON: String = ""
    @AppStorage("showBatchCheckIn") private var showBatchCheckIn: Bool = false
    @AppStorage("calendar_viewMode") private var calendarViewModeRaw: String = CalendarViewMode.list.rawValue

    private var l: L10n { L10n(appLanguage) }
    private var activeViewerHumanId: UUID? { UUID(uuidString: activeViewerHumanIdStr) }
    private var activeCritterId: UUID? {
        get { UUID(uuidString: activeCritterIdStr) }
        nonmutating set { activeCritterIdStr = newValue?.uuidString ?? "" }
    }
    private var activeHuman: Human? {
        guard let id = activeHumanId else { return nil }
        return humans.first(where: { $0.id == id })
    }
    private var deckActivePet: Pet? {
        if activeHumanId != nil { return nil }
        if let id = activeCritterId { return pets.first(where: { $0.id == id && !$0.hasPassedAway }) }
        return pets.first(where: { !$0.hasPassedAway })
    }
    private var currentMood: IslandMood {
        IslandMoodCalculator.calculate(pets: pets, pendingReminders: pendingReminders, plants: plants)
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

    // MARK: – Body
    var body: some View {
        ZStack {
            // 1. 深海军蓝渐变底色
            LinearGradient(
                colors: [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 2. 设计规范浮动色球（lime + indigo + purple）
            goBackgroundBlobs

            // 3. 岛屿粒子特效（透明叠加）
            IslandMoodWeatherView(mood: currentMood)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 4. Tab 内容区
            Group {
                switch selectedDockTab {
                case 1: PlantDashboardView(selectedPlant: $selectedPlant)
                case 2: CalendarView(hideToolbar: true, addEventTrigger: calendarAddEventTrigger)
                case 3: OasisRewardView(hideToolbar: true, rulesTrigger: oasisRulesTrigger, inventoryTrigger: oasisInventoryTrigger)
                default: homeScrollView
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.18), value: selectedDockTab)

            // 5. 固定顶栏（随滚动渐隐）
            VStack(spacing: 0) {
                goFixedHeader
                    .opacity(selectedDockTab == 0 ? max(0, 1 - (-homeScrollContentMinY / 60)) : 1)
                Spacer()
            }

            // 6. 打卡 Toast
            toastOverlay

            // 7. 每日椰子弹窗
            if showDailyCoconut { dailyCoconutModal }

            // 8. Lime 风格底部导航（设计规范：活跃标签 = lime 胶囊）
            VStack {
                Spacer()
                goLimeDock
                    .padding(.bottom, 20)
            }
        }
        .coconutRewardOverlay(trigger: $showRewardCoconut, amount: rewardCoconutAmount, label: rewardCoconutLabel)
        .navigationBarHidden(true)
        // Primary sheets (split to avoid type-checker timeout)
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingAddEntity) { AddEntityView() }
        .sheet(isPresented: $showingManageSheet) { HomeSectionManageSheet() }
        .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
        .sheet(isPresented: $showStreakDetail) {
            DailyStreakDetailView(pets: pets)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickWeightPet) { pet in
            GenericWeightEntrySheet(target: .pet(pet))
                .presentationDetents([.medium]).presentationDragIndicator(.visible).presentationBackground(.regularMaterial)
        }
        .sheet(item: $quickHumanWeightHuman) { human in
            GenericWeightEntrySheet(target: .human(human))
                .presentationDetents([.medium]).presentationDragIndicator(.visible).presentationBackground(.regularMaterial)
        }
        .sheet(item: $quickHumanWorkoutHuman) { human in
            AddWorkoutSheet(human: human)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickHumanMedicationHuman) { human in
            NavigationStack { HumanMedicationView(human: human) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickHumanNoteHuman) { human in
            QuickHumanNoteSheet(human: human)
                .presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickHumanWeightDetailHuman) { human in
            NavigationStack { HumanWeightHistoryView(human: human) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickHumanWorkoutDetailHuman) { human in
            HumanWorkoutHistoryView(human: human)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $showMomentPet) { pet in
            NavigationStack {
                QuickMomentSheet(pet: pet, onRemove: nil)
                    .navigationTitle(l.homeRecordMoment).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(l.addEntityClose) { showMomentPet = nil } } }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .background(goSecondarySheets)
        .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
            Button(l.homeConfirmCheckIn, role: .destructive) { pendingRepeatAction?(); pendingRepeatAction = nil }
            Button(l.cancel, role: .cancel) { pendingRepeatAction = nil }
        } message: { Text(antiRepeatMessage) }
        .alert("仅本人可见", isPresented: $showingHumanPrivacyAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("该成员已将此功能设为仅自己可见。")
        }
        .islandToastOverlay()
        .onAppear { onAppearSetup() }
        .onChange(of: PetWalkingManager.shared.phase) { _, newPhase in
            if newPhase == .idle {
                showWalkFullScreen = false
                walkMinimized = false
            }
            lastWalkPhase = newPhase
        }
        .onChange(of: pets.count) { oldCount, newCount in
            guard newCount > oldCount else { return }
            let existingPetIds = Set(savedQuickActionItems.compactMap(\.petId))
            for pet in pets where !pet.hasPassedAway && !existingPetIds.contains(pet.id) {
                for item in defaultActions(for: pet) { addQuickAction(item) }
            }
        }
        .milestoneCheck(pets: pets)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshHeaderStreak()
        }
    }
}

// MARK: - Home Scroll View

private extension GoDashboardView {
    var homeScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header spacer
                Spacer().frame(height: 72)

                VStack(spacing: 16) {
                    // A. 岛屿情绪胶囊
                    if !pets.isEmpty {
                        IslandMoodHeaderStrip(
                            pets: pets,
                            plants: plants,
                            pendingReminders: pendingReminders,
                            activePet: deckActivePet,
                            checkInStreak: headerStreak,
                            onExpand: { showStreakDetail = true }
                        )
                        .padding(.horizontal, 16)
                    }

                    // B. 3D 宠物卡转盘
                    if !pets.isEmpty || !humans.isEmpty {
                        PetWalletStack(
                            pets: pets,
                            humans: humans,
                            heroNS: heroNS,
                            onSelectPet: { selectedPetTab = .overview; selectedPet = $0 },
                            onSelectHuman: { selectedHuman = $0 },
                            onTopCardChanged: { item in
                                switch item {
                                case .pet(let p):
                                    activeCritterIdStr = p.id.uuidString; activeHumanId = nil
                                case .human(let h):
                                    activeCritterIdStr = ""; activeHumanId = h.id
                                }
                            },
                            onDraggingChanged:  { isCardDragging = $0 }
                        )
                        .onAppear {
                            if activeCritterIdStr.isEmpty { activeCritterId = pets.first?.id }
                        }
                    }

                    // C. 家庭协作 mini 胶囊
                    if let topPet = deckActivePet {
                        FamilyActivityStripView(pet: topPet, style: .compact, onExpand: { showingFamilyStripFull = true })
                            .padding(.horizontal, 16)
                    }

                    // D. 今日委托（DailyQuestsCard 套 GO 卡片容器）
                    if !pets.isEmpty {
                        goSectionCard(title: l.goSectionIslandQuests, label: l.goSectionIslandQuestsLabel) {
                            TodayFocusCard(
                                pets: pets,
                                plants: plants,
                                quests: IslandQuestEngine.todayQuests(pets: pets, reminders: pendingReminders, plants: plants, events: allEvents),
                                activePet: deckActivePet,
                                onCompleteQuest: { completeIslandQuest($0) },
                                onTapMemory: {},
                                onTapOasis: { selectedDockTab = 3 }
                            )
                        }
                        .padding(.horizontal, 16)
                    }

                    // E. 快捷操作网格
                    if !pets.isEmpty || !humans.isEmpty {
                        goSectionCard(title: l.goSectionQuickActions, label: l.goSectionQuickActionsLabel, trailingButton: {
                            AnyView(
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if isQAEditMode { exitQAEditMode() } else { enterQAEditMode() }
                                } label: {
                                    Image(systemName: isQAEditMode ? "checkmark.circle.fill" : "pencil")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isQAEditMode ? Color(hex: "3B5BDB") : Color(hex: "6B82C4"))
                                }
                                .buttonStyle(.plain)
                            )
                        }) {
                            quickActionsGrid
                        }
                        .padding(.horizontal, 16)
                    }

                    // F. 功能入口 Hub
                    goFeatureHub
                        .padding(.horizontal, 16)

                    // G. 巡岛进行中胶囊
                    // GlobalWalkBanner (ContentView overlay) handles the minimized bubble

                    // H. 记忆碎片
                    if !memoryDismissed {
                        if let memory = MemoryEngine.pickFragment(pets: pets, plants: plants) {
                            MemoryDropCard(fragment: memory)
                                .padding(.horizontal, 16)
                                .offset(x: memoryDragOffset)
                                .opacity(1.0 - abs(memoryDragOffset) / 300.0)
                                .gesture(memorySwipeGesture)
                        }
                    }

                    // I. 岛屿统计横向卡
                    goIslandStatsSection

                    Spacer(minLength: 120)
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: HomeScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("goHomeScroll")).minY
                    )
                }
            )
        }
        .coordinateSpace(name: "goHomeScroll")
        .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { minY in
            homeScrollContentMinY = minY
        }
        .scrollDisabled(isCardDragging)
    }

    // 记忆碎片滑动手势
    var memorySwipeGesture: some Gesture {
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
                        QuestManager.shared.addCoconuts(1, emoji: "💭", title: l.homeMemoryCoconutTitle)
                    }
                } else {
                    withAnimation(.spring(response: 0.3)) { memoryDragOffset = 0 }
                }
            }
    }
}

// MARK: - Design-System Elements (blobs · Life Tree · Lime Dock)

private extension GoDashboardView {

    // MARK: Floating blobs (设计规范: lime + indigo + purple)
    var goBackgroundBlobs: some View {
        GeometryReader { geo in
            ZStack {
                // Lime blob — top-left
                Circle()
                    .fill(Color.goLime)
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .opacity(0.22)
                    .offset(x: blobPulse ? -50 : -70,
                            y: blobPulse ? -70 : -90)

                // Indigo blob — mid-right
                Circle()
                    .fill(Color(hex: "5B6AFF"))
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .opacity(0.40)
                    .offset(x: blobPulse ? geo.size.width - 80 : geo.size.width - 100,
                            y: blobPulse ? 180 : 220)

                // Purple blob — lower-left
                Circle()
                    .fill(Color(hex: "A855F7"))
                    .frame(width: 240, height: 240)
                    .blur(radius: 90)
                    .opacity(0.30)
                    .offset(x: blobPulse ? -40 : -60,
                            y: blobPulse ? geo.size.height * 0.55 : geo.size.height * 0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Life Tree Hero Card (设计规范核心组件)
    var goLifeTreeHeroCard: some View {
        let treeMgr = OasisTreeManager.shared
        let level = treeMgr.treeLevel
        let progress = treeMgr.progressToNextLevel
        let energyNeeded = treeMgr.nextLevelThreshold - treeMgr.totalEnergy

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Tree icon tile
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "1A0E4B"), Color(hex: "0C1640")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.goLime.opacity(0.45), lineWidth: 1)
                        )
                        .frame(width: 72, height: 72)

                    Text("🌴")
                        .font(.system(size: 40))
                        .frame(width: 72, height: 72)

                    // Level badge
                    Text("Lv.\(level.rawValue)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A2E"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.goLime, in: Capsule())
                        .offset(x: 6, y: -6)
                }

                // Info column
                VStack(alignment: .leading, spacing: 6) {
                    Text(l.goLifeTreeTitle(levelName: level.displayName))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(light: Color(hex: "1E3A8A"), dark: .primary))

                    if level < .lv10 {
                        Text(l.goTreeNeedEnergy(max(0, energyNeeded)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(light: Color(hex: "6B82C4"), dark: .secondary))
                    } else {
                        Text(l.goTreeMaxLevel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.goLime)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(light: Color(hex: "E8EEFF"), dark: Color.white.opacity(0.12)))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.goLime, Color(hex: "00D4AA")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }

            // CTA row
            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    selectedDockTab = 3
                } label: {
                    Text(l.goInjectEnergy)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A2E"))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Color.goLime, in: Capsule())
                        .shadow(color: Color.goLime.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(.plain)

                Button { selectedDockTab = 3 } label: {
                    Text(l.goToOasis)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "6B82C4"))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Color(hex: "EEF2FF"), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            Color(light: .white, dark: Color.white.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04), lineWidth: 1)
        )
        .shadow(color: (colorScheme == .dark ? Color.black.opacity(0.24) : Color(hex: "0C1640").opacity(0.2)), radius: 8, y: 3)
    }

    // MARK: Lime-style dock (设计规范: 活跃标签 = lime 胶囊 + 墨色文字)
    @ViewBuilder var goLimeDock: some View {
        let tabs: [(String, String, Int)] = [
            ("house.fill", l.tabHome, 0),
            ("camera.macro", l.tabPlant, 1),
            ("calendar", l.tabCalendar, 2),
            ("leaf.fill", l.tabOasis, 3),
        ]
        HStack(spacing: 4) {
            ForEach(tabs, id: \.2) { icon, label, idx in
                let isActive = selectedDockTab == idx
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedDockTab = idx
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isActive ? Color(hex: "1A1A2E") : .white.opacity(0.55))
                        if isActive {
                            Text(label)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "1A1A2E"))
                        }
                    }
                    .padding(.horizontal, isActive ? 16 : 14)
                    .padding(.vertical, 12)
                    .background(
                        isActive ? Color.goLime : Color.clear,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selectedDockTab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(hex: "141628").opacity(0.7))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)
        .padding(.horizontal, 32)
    }
}

// MARK: - GO Fixed Header

private extension GoDashboardView {
    var goFixedHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            // 左：greeting
            VStack(alignment: .leading, spacing: 2) {
                switch selectedDockTab {
                case 0:
                    Text("\(greetingText) 👋")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    if let greetPet = activeCritterId.flatMap({ id in pets.first(where: { $0.id == id }) }) ?? pets.first {
                        let hour = Calendar.current.component(.hour, from: Date())
                        let hint = PetTagGreeting.homeSubtitleHint(pet: greetPet, hour: hour, l: l)
                        Text(hint)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                case 1: Text(l.tabPlant).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
                case 2: Text(l.tabCalendar).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
                case 3: Text(l.tabOasis).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
                default: EmptyView()
                }
            }

            Spacer()

            // 右：功能按钮
            HStack(spacing: 8) {
                switch selectedDockTab {
                case 0:
                    Button { showStreakDetail = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold))
                            Text("\(headerStreak)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                        }
                        .foregroundStyle(headerStreak >= 7 ? Color(hex: "0C1640") : .white)
                        .padding(.horizontal, 8).frame(height: 28)
                        .background(headerStreak >= 7 ? Color.goLime : .white.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Menu {
                        Button { showingAddEntity = true } label: { Label(l.addMember, systemImage: "person.badge.plus") }
                        Button { showingCrewRoster = true } label: { Label(l.ohanaCrew, systemImage: "person.2.fill") }
                        Button { showingManageSheet = true } label: { Label(l.manageHomeModules, systemImage: "slider.horizontal.3") }
                        Button { showingSettings = true } label: { Label(l.settings, systemImage: "gearshape") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                case 1:
                    goHeaderIconButton(systemName: "plus.circle.fill") { showingAddEntity = true }
                case 2:
                    goHeaderIconButton(systemName: "plus.circle.fill") { calendarAddEventTrigger.toggle() }
                case 3:
                    goHeaderIconButton(systemName: "info.circle") { oasisRulesTrigger.toggle() }
                    goHeaderIconButton(systemName: "shippingbox.fill") { oasisInventoryTrigger.toggle() }
                default: EmptyView()
                }
                CoconutBalanceCapsule(onTap: { showingCoconutLog = true })
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(hex: "2D4ECC").opacity(0.95), Color(hex: "2D4ECC").opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    func goHeaderIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GO Section Card wrapper

private extension GoDashboardView {
    @ViewBuilder
    func goSectionCard<Content: View>(
        title: String,
        label: String,
        trailingButton: (() -> AnyView)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color(light: Color(hex: "1E3A8A"), dark: .primary))
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.goLime.opacity(0.7))
                        .tracking(2.5)
                }
                Spacer()
                trailingButton?()
            }
            content()
        }
        .padding(16)
        .background(
            Color(light: .white, dark: Color.white.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04), lineWidth: 1)
        )
        .shadow(color: (colorScheme == .dark ? Color.black.opacity(0.24) : Color(hex: "0C1640").opacity(0.18)), radius: 8, y: 3)
    }
}

// MARK: - Quick Actions Grid

private extension GoDashboardView {
    @ViewBuilder
    func goQuickActionGridItem(idx: Int, item: QuickActionItem) -> some View {
        ZStack {
            GoQuickActionCard(
                item: item,
                isPressed: !isQAEditMode && pressedActionId == item.id,
                petAvatar: avatarForAction(item),
                petThemeColorHex: themeColorForAction(item),
                pendingReminder: isQAEditMode ? nil : reminderForAction(item),
                countText: isQAEditMode ? nil : countTextForAction(item),
                privacyBadgeText: isQAEditMode ? nil : privacyBadgeText(for: item),
                isPrivacyLocked: !isQAEditMode && isHumanQuickActionPrivate(item),
                isCompletedToday: !isQAEditMode && isCompletedToday(for: item),
                onTap: {
                    guard !isQAEditMode else { return }
                    pressedActionId = item.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        pressedActionId = nil
                        handleAction(item)
                    }
                },
                onLongPress: isQAEditMode ? nil : {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    handleLongPressAction(item)
                },
                onDelete: isQAEditMode ? nil : (quickActionUsesDetailSheetRemove(item.actionType) ? nil : { removeQuickAction(item) }),
                onGroomCheckIn: (!isQAEditMode && item.actionType == "groom") ? { raw in
                    if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) { applyGroomCheckIn(raw, pet: p) }
                } : nil,
                onPottySelect: (!isQAEditMode && item.actionType == "potty") ? { raw in
                    if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) { applyPottyCheckIn(raw, pet: p) }
                } : nil,
                onHealthSelect: (!isQAEditMode && item.actionType == "health") ? { raw in
                    if let pid = item.petId, let p = pets.first(where: { $0.id == pid }) { applyHealthCheckIn(raw, pet: p) }
                } : nil,
                onAddReminder: (!isQAEditMode && item.actionType == "potty") ? {
                    quickAccessCarePet = pets.first(where: { $0.id == item.petId })
                } : nil
            )
            .overlay {
                if !isQAEditMode && bentoCardState(for: item) == .urgentPending {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.goRed.opacity(bentoUrgentGlow ? 0.8 : 0.3), lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(!isQAEditMode)

            if isQAEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeColorForAction(item))
            }
        }
        .rotationEffect(.degrees(isQAEditMode ? (qaJiggle ? -2.5 : 2.5) : 0))
        .animation(
            isQAEditMode
            ? .easeInOut(duration: 0.12 + Double(idx % 4) * 0.015).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.2),
            value: qaJiggle
        )
        .overlay(alignment: .topLeading) {
            if isQAEditMode {
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    withAnimation(.spring(response: 0.3)) { qaEditItems.removeAll { $0.id == item.id } }
                } label: {
                    ZStack {
                        Circle().fill(Color.goRed).frame(width: 20, height: 20)
                        Image(systemName: "minus").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
            }
        }
        .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(targetItem: item, items: $qaEditItems))
    }

    var quickActionsGrid: some View {
        VStack(spacing: 0) {
            let displayItems = isQAEditMode ? qaEditItems : activeQuickActionItems
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                    goQuickActionGridItem(idx: idx, item: item)
                }

                if isQAEditMode {
                    Button {
                        guard pets.first(where: { $0.id == activeCritterId }) != nil else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingQAQuickAdd = true
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(Color(hex: "E8EEFF")).frame(width: 44, height: 44)
                                Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "6B82C4"))
                            }
                            Text(l.goAddChip).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: "6B82C4"))
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color(hex: "B8C8F0"), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingQAQuickAdd, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                        if let pet = pets.first(where: { $0.id == activeCritterId }) {
                            QAQuickAddPopoverContent(pet: pet, existingItems: qaEditItems) { newItem in
                                withAnimation(.spring(response: 0.3)) {
                                    if QuickActionLimit.count(for: pet, in: qaEditItems) < QuickActionLimit.maxItemsPerEntity {
                                        qaEditItems.append(newItem)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: activeQuickActionItems.map(\.id))
        }
        .sheet(item: $quickAccessFoodPet) { pet in PetFoodManagementView(pet: pet) }
        .sheet(item: $quickAccessCarePet) { pet in PetHygieneCard(pet: pet) }
        .sheet(item: $quickExpensePet) { pet in
            AddExpenseSheet(pet: pet, preselectedPayerId: UserDefaults.standard.string(forKey: "currentActiveHumanId"))
        }
        .sheet(isPresented: Binding(get: { feedSheetItem != nil }, set: { if !$0 { feedSheetItem = nil } })) {
            if let fi = feedSheetItem {
                QuickFeedSheet(pet: fi.pet, actionType: fi.actionType) { feedSheetItem = nil }
                    .presentationDetents([.height(320)]).presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $feedDetailPet) { pet in
            QuickFeedDetailSheet(pet: pet) { feedDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible).presentationContentInteraction(.scrolls)
        }
        .sheet(item: $waterDetailPet) { pet in
            QuickWaterDetailSheet(
                pet: pet,
                initialModeRaw: waterDetailModeRaw,
                lockedModeRaw: waterDetailModeRaw
            ) {
                waterDetailPet = nil
                waterDetailModeRaw = nil
            }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible).presentationContentInteraction(.scrolls)
                .onDisappear { waterDetailModeRaw = nil }
        }
        .sheet(item: $playDetailPet) { pet in
            QuickPlayDetailSheet(pet: pet) { playDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible).presentationContentInteraction(.scrolls)
        }
        .sheet(item: $pottyDetailPet) { pet in
            QuickPottyDetailSheet(pet: pet) { pottyDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible).presentationContentInteraction(.scrolls)
        }
        .sheet(item: $litterDetailPet) { pet in
            QuickLitterDetailSheet(pet: pet) { litterDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large], selection: $quickActionDetailSheetDetent)
                .presentationDragIndicator(.visible).presentationContentInteraction(.scrolls)
        }
        .sheet(item: $quickWeightDetailPet) { pet in
            NavigationStack { WeightHistoryView(pet: pet, onRemove: { quickWeightDetailPet = nil }) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickExpenseDetailPet) { pet in
            NavigationStack { ExpenseHistoryView(pet: pet, onRemove: { quickExpenseDetailPet = nil }) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickWalkDetailPet) { pet in
            NavigationStack { WalkSummarySheet(pet: pet) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickHealthDetailPet) { pet in
            NavigationStack { PetHealthDetailView(pet: pet, isModal: true) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $quickGroomDetailPet) { pet in
            NavigationStack { PetHygieneDetailView(pet: pet) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .background(cardBackSheets)
    }

    @ViewBuilder var cardBackSheets: some View {
        Color.clear
            .sheet(item: $cardBackHealthPet) { pet in NavigationStack { PetHealthDetailView(pet: pet, isModal: true) } }
    }
}

// MARK: - GO Feature Hub (功能入口 2×3 网格)

private struct GoFeatureItem {
    let emoji: String
    let title: String
    let subtitle: String
    let colorHex: String
    var requiresPet: Bool = false
    /// 背景色亮时需要深色文字（如石灰绿卡片）
    var darkText: Bool = false
    let action: () -> Void
}

private extension GoDashboardView {
    var goFeatureHub: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.goFeatureHubTitle)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("ISLAND FEATURES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.goLime.opacity(0.75))
                        .tracking(2.5)
                }
                Spacer()
            }

            let hasPet = !pets.isEmpty
            let features: [GoFeatureItem] = [
                GoFeatureItem(emoji: "🦮", title: l.goFeatPatrol, subtitle: l.goFeatPatrolSub, colorHex: "0EA5E9", requiresPet: true) {
                    if let pet = deckActivePet ?? pets.first(where: { !$0.hasPassedAway }) {
                        PetWalkingManager.shared.start(pet: pet)
                    }
                },
                GoFeatureItem(emoji: "❤️", title: l.goFeatHealth, subtitle: l.goFeatHealthSub, colorHex: "EF4444", requiresPet: true) {
                    if let pet = deckActivePet { cardBackHealthPet = pet }
                },
                GoFeatureItem(emoji: "📅", title: l.goFeatCalendar, subtitle: l.goFeatCalendarSub, colorHex: "8B5CF6") {
                    selectedDockTab = 2
                },
                GoFeatureItem(emoji: "💰", title: l.goFeatExpense, subtitle: l.goFeatExpenseSub, colorHex: "D97706") {
                    showIslandExpense = true
                },
                GoFeatureItem(emoji: "⚖️", title: l.goFeatWeight, subtitle: l.goFeatWeightSub, colorHex: "16A34A", requiresPet: true) {
                    showIslandWeight = true
                },
                GoFeatureItem(emoji: "🌴", title: l.goFeatOasis, subtitle: l.goFeatOasisSub, colorHex: "C8FF00", darkText: true) {
                    selectedDockTab = 3
                },
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                    let locked = feature.requiresPet && !hasPet
                    let fgColor: Color = feature.darkText ? Color(hex: "0C1640") : .white
                    Button(action: { if !locked { feature.action() } }) {
                        VStack(spacing: 6) {
                            Text(feature.emoji)
                                .font(.system(size: 26))
                                .opacity(locked ? 0.45 : 1)
                            Text(feature.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(fgColor.opacity(locked ? 0.4 : 1))
                            Text(locked ? l.goAddPetLocked : feature.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(fgColor.opacity(locked ? 0.3 : 0.75))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Color(hex: feature.colorHex).opacity(locked ? 0.25 : 1),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            locked ?
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!locked)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "162660"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "0C1640").opacity(0.3), radius: 8, y: 3)
    }
}

// MARK: - Island Stats (horizontal scroll)

private extension GoDashboardView {
    var goIslandStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l.goStatsTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                // 生命之树等级徽章
                let _treeLv = OasisTreeManager.shared.treeLevel
                HStack(spacing: 4) {
                    Text("🌴")
                        .font(.system(size: 11))
                    Text("Lv.\(_treeLv.rawValue) · \(_treeLv.displayName)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "C8FF00"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "C8FF00").opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "C8FF00").opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 无宠物引导卡
                    if pets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🐾")
                                .font(.system(size: 28))
                            Text(l.goEmptyPetsTitle)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text(l.goEmptyPetsSub)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineSpacing(3)
                            Spacer()
                            Button { showingAddEntity = true } label: {
                                Text(l.goEmptyPetsCTA)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Color(hex: "C8FF00"), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 180, alignment: .leading)
                        .padding(14)
                        .frame(height: 160)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(hex: "C8FF00").opacity(0.2), lineWidth: 1))
                    }

                    // 本周散步
                    let weekWalk = last7DayWalkCounts
                    let weekWalkTotal = weekWalk.reduce(0) { $0 + $1.1 }
                    goStatMiniCard(
                        icon: "figure.walk", iconColor: "22D3EE",
                        value: "\(weekWalkTotal)", unit: l.times,
                        label: l.goWeekWalks, onTap: { showIslandExplore = true }
                    )

                    // 体重（最近一次）
                    let lastWeight = pets.compactMap { p in
                        p.weightLogs.sorted(by: { $0.date > $1.date }).first.map { (p.name, $0.weightInKg) }
                    }.first
                    goStatMiniCard(
                        icon: "scalemass.fill", iconColor: "4ADE80",
                        value: lastWeight.map { String(format: "%.1f", $0.1) } ?? "--", unit: "kg",
                        label: lastWeight.map { $0.0 } ?? l.homeQAWeight, onTap: { showIslandWeight = true }
                    )

                    // 本月花费
                    let monthExpense = pets.flatMap { $0.expenseLogs }
                        .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                        .reduce(0.0) { $0 + $1.amount }
                    goStatMiniCard(
                        icon: "yensign.circle.fill", iconColor: "FFDD44",
                        value: "¥\(Int(monthExpense))", unit: "",
                        label: l.goThisMonthExpense, onTap: { showIslandExpense = true }
                    )

                    // 粮仓
                    if let urgentPet = pets.filter({ $0.remainingFoodDays > 0 }).min(by: { $0.remainingFoodDays < $1.remainingFoodDays }) {
                        goStatMiniCard(
                            icon: "bag.fill", iconColor: urgentPet.remainingFoodDays <= 7 ? "FF4757" : "FB923C",
                            value: "\(urgentPet.remainingFoodDays)", unit: l.petCardDayUnit,
                            label: l.goPetFoodPantry(urgentPet.name), onTap: { showingAllFoodManagement = true }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    func goStatMiniCard(icon: String, iconColor: String, value: String, unit: String, label: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: iconColor))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: iconColor).opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(light: Color(hex: "1E3A8A"), dark: .primary))
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(light: Color(hex: "6B82C4"), dark: .secondary))
                        }
                    }
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(light: Color(hex: "6B82C4"), dark: .secondary))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(light: .white, dark: Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04), lineWidth: 1)
            )
            .shadow(color: (colorScheme == .dark ? Color.black.opacity(0.18) : Color(hex: "0C1640").opacity(0.12)), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    var last7DayWalkCounts: [(String, Int)] {
        let cal = Calendar.current
        let days = ["M","T","W","T","F","S","S"]
        return (0..<7).map { offset -> (String, Int) in
            let date = cal.date(byAdding: .day, value: -(6 - offset), to: Date())!
            let count = pets.flatMap { $0.walkLogs }.filter { cal.isDate($0.startDate, inSameDayAs: date) }.count
            return (days[offset], count)
        }
    }
}

// MARK: - Toast & Daily Coconut

private extension GoDashboardView {
    @ViewBuilder var toastOverlay: some View {
        if let toast = actionToast {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Text(toast.emoji).font(.system(size: 18))
                    Text(toast.message).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.black)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Color.goPrimary, in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 110)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: actionToast != nil)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder var dailyCoconutModal: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { dismissDailyCoconut() }
            VStack(spacing: 16) {
                Text("🥥")
                    .font(.system(size: 64))
                    .scaleEffect(coconutFlyOut ? 0.2 : 1.0)
                    .opacity(coconutFlyOut ? 0 : 1)
                    .offset(x: coconutFlyOut ? 120 : 0, y: coconutFlyOut ? -300 : 0)
                if !coconutFlyOut {
                    VStack(spacing: 6) {
                        Text(l.homeDailyCoconutTitle).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(Color(light: Color(hex: "1E3A8A"), dark: .primary))
                        Text(l.homeDailyCoconutSub).font(.system(size: 13)).foregroundStyle(Color(light: Color(hex: "6B82C4"), dark: .secondary))
                    }
                    .transition(.opacity)
                    Button { dismissDailyCoconut() } label: {
                        Text(l.homeClaimCoconuts).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 36).padding(.vertical, 12)
                            .background(Color(hex: "3B5BDB"), in: Capsule())
                    }
                    .transition(.opacity)
                }
            }
            .padding(32)
            .background(
                Color(light: .white, dark: Color(hex: "141628")),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: (colorScheme == .dark ? Color.black.opacity(0.35) : Color(hex: "0C1640").opacity(0.3)), radius: 24, y: 8)
        }
        .zIndex(9999)
        .transition(.opacity)
    }

    func dismissDailyCoconut() {
        withAnimation(.easeIn(duration: 0.45)) { coconutFlyOut = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) { showDailyCoconut = false; coconutFlyOut = false }
        }
    }
}

// MARK: - onAppear Setup

private extension GoDashboardView {
    func onAppearSetup() {
        refreshHeaderStreak()
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { bentoUrgentGlow = true }
        // 浮动色球呼吸动画
        withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { blobPulse = true }
        for pet in pets { StreakManager.refreshStreak(for: pet, context: modelContext) }
        ReminderSchedulingService.compensate(reminders: Array(pendingReminders), context: modelContext)

        // 每日打卡
        let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
        let today = fmt.string(from: Date())
        let key = "oasis_checkedIn_dates"
        var set = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        if !set.contains(today) {
            set.insert(today)
            UserDefaults.standard.set(Array(set), forKey: key)
            QuestManager.shared.addCoconuts(1, emoji: "📅", title: l.homeDailyCheckInRewardTitle)
            refreshHeaderStreak()
        }

        // 每日椰子弹窗
        let dKey = "daily_coconut_shown"
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: dKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: startOfToday) {
            // 已显示
        } else if !pets.isEmpty || !humans.isEmpty {
            UserDefaults.standard.set(startOfToday, forKey: dKey)
            QuestManager.shared.addCoconuts(1, emoji: "🌅", title: l.homeDailyLoginRewardTitle)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showDailyCoconut = true }
            }
        }

        // 岛屿日报
        if !pets.isEmpty || !plants.isEmpty {
            let todayStr = AppLanguage.calendarDayKeyToday
            if lastIslandReportDate != todayStr {
                lastIslandReportDate = todayStr
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showIslandDailyReport = true }
            }
        }

        lastWalkPhase = PetWalkingManager.shared.phase
    }

    func refreshHeaderStreak() {
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
}

// MARK: - Quick Action Helpers (mirrors OverviewView)

private extension GoDashboardView {
    var activeQuickActionItems: [QuickActionItem] {
        let all = savedQuickActionItems.map { item -> QuickActionItem in
            var n = item; if item.actionType == "care" { n.actionType = "groom" }; return n
        }
        if let humanId = activeHumanId {
            let humanItems = all.filter { $0.entityKind == .human && $0.entityId == humanId }
            if humanItems.isEmpty, let human = activeHuman { return defaultHumanActions(for: human) }
            return humanItems
        }
        guard let activeId = activeCritterId else { return all.filter { $0.entityKind != .human } }
        let items = all.filter { $0.petId == activeId || ($0.petId == nil && $0.entityKind != .human) }
        guard let pet = pets.first(where: { $0.id == activeId }) else { return items }
        return ensureIndependentWaterChangeAction(in: items, for: pet)
    }

    func ensureIndependentWaterChangeAction(in items: [QuickActionItem], for pet: Pet) -> [QuickActionItem] {
        let actionTypes = Set(items.map(\.actionType))
        guard actionTypes.contains("water"),
              !actionTypes.contains("waterChange"),
              QuickActionLimit.count(for: pet, in: items) < QuickActionLimit.maxItemsPerEntity
        else { return items }

        var result = items
        let waterChange = QuickActionItem(
            label: l.homeQAWaterChange,
            icon: "drop.circle.fill",
            colorHex: "4ECDC4",
            petId: pet.id,
            actionType: "waterChange",
            entityId: pet.id,
            entityKind: .pet
        )
        if let waterIndex = result.firstIndex(where: { $0.actionType == "water" }) {
            result.insert(waterChange, at: min(waterIndex + 1, result.count))
        } else {
            result.append(waterChange)
        }
        return result
    }

    var savedQuickActionItems: [QuickActionItem] {
        guard !quickActionItemsJSON.isEmpty,
              let data = quickActionItemsJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return defaultQuickActionItems }
        return items
    }

    var defaultQuickActionItems: [QuickActionItem] {
        guard let pet = pets.first(where: { !$0.hasPassedAway }) else { return [] }
        return defaultActions(for: pet)
    }

    func defaultHumanActions(for human: Human) -> [QuickActionItem] {
        [
            QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA", actionType: "humanWeight", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQASport, icon: "figure.run", colorHex: "C8FF00", actionType: "humanWorkout", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A", actionType: "humanMedication", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQANote, icon: "note.text", colorHex: "A78BFA", actionType: "humanNote", entityId: human.id, entityKind: .human),
        ]
    }

    func defaultActions(for pet: Pet) -> [QuickActionItem] {
        let isDog = pet.species.contains("狗") || pet.species.lowercased().contains("dog")
        let isCat = pet.species.contains("猫") || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")
        var items: [QuickActionItem] = []
        items.append(QuickActionItem(label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44", petId: pet.id, actionType: "feed", entityId: pet.id, entityKind: .pet))
        if isFish {
            items.append(QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4", petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAFilterClean, icon: "wrench.and.screwdriver.fill", colorHex: "A78BFA", petId: pet.id, actionType: "filterClean", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA", petId: pet.id, actionType: "weight", entityId: pet.id, entityKind: .pet))
        } else if isDog {
            items.append(QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA", petId: pet.id, actionType: "water", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4", petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAWalk, icon: "figure.walk", colorHex: "C8FF00", petId: pet.id, actionType: "walk", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAPotty, icon: "allergens", colorHex: "A78BFA", petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet))
        } else if isCat {
            items.append(QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA", petId: pet.id, actionType: "water", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4", petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQALitter, icon: "trash.fill", colorHex: "5B6AFF", petId: pet.id, actionType: "litter", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAPotty, icon: "allergens", colorHex: "A78BFA", petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet))
        } else {
            items.append(QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA", petId: pet.id, actionType: "water", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4", petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAGroom, icon: "scissors", colorHex: "F472B6", petId: pet.id, actionType: "groom", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA", petId: pet.id, actionType: "weight", entityId: pet.id, entityKind: .pet))
        }
        return Array(items.prefix(4))
    }

    func addQuickAction(_ item: QuickActionItem) {
        var current = savedQuickActionItems
        if let petId = item.petId,
           let pet = pets.first(where: { $0.id == petId }),
           QuickActionLimit.count(for: pet, in: current) >= QuickActionLimit.maxItemsPerEntity {
            return
        }
        current.append(item)
        if let data = try? JSONEncoder().encode(current), let str = String(data: data, encoding: .utf8) { quickActionItemsJSON = str }
    }

    func removeQuickAction(_ item: QuickActionItem) {
        var current = savedQuickActionItems; current.removeAll { $0.id == item.id }
        if let data = try? JSONEncoder().encode(current), let str = String(data: data, encoding: .utf8) { quickActionItemsJSON = str }
    }

    func enterQAEditMode() {
        qaEditItems = activeQuickActionItems
        withAnimation(.spring(response: 0.3)) { isQAEditMode = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation(nil) { qaJiggle = true } }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func exitQAEditMode() {
        saveQAEditItems(qaEditItems)
        withAnimation(.spring(response: 0.3)) { isQAEditMode = false }
        withAnimation(nil) { qaJiggle = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func saveQAEditItems(_ edited: [QuickActionItem]) {
        var saved = savedQuickActionItems
        let activeIds = Set(activeQuickActionItems.map { $0.id })
        let insertionIdx = saved.firstIndex(where: { activeIds.contains($0.id) }) ?? saved.count
        saved.removeAll { activeIds.contains($0.id) }
        saved.insert(contentsOf: Array(edited.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved), let str = String(data: data, encoding: .utf8) { quickActionItemsJSON = str }
    }

    func isCompletedToday(for item: QuickActionItem) -> Bool {
        let cal = Calendar.current
        if item.entityKind == .human, let hid = item.entityId, let human = humans.first(where: { $0.id == hid }) {
            guard !isHumanQuickActionPrivate(item, human: human) else { return false }
            switch item.actionType {
            case "humanWeight":  return human.weightLogs.contains { cal.isDateInToday($0.date) }
            case "humanWorkout": return human.workoutLogs.contains { cal.isDateInToday($0.date) }
            case "humanMedication":
                return false
            default:             return false
            }
        }
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return false }
        switch item.actionType {
        case "walk":    return pet.walkLogs.contains { cal.isDateInToday($0.startDate) }
        case "feed":    return feedQuickActionAppearsComplete(for: pet)
        case "water":
            return pet.careLogs.contains { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }
        case "waterChange":
            return pet.careLogs.contains { $0.type == CareType.waterChange.rawValue && cal.isDateInToday($0.date) }
        case "litter":  return pet.careLogs.contains { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }
        case "potty":   return pet.pottyLogs.contains { cal.isDateInToday($0.date) }
        case "play":    return pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
        case "groom":   return pet.hygieneLogs.contains { cal.isDateInToday($0.date) }
        default:        return false
        }
    }

    enum BentoCardState { case urgentPending, normalPending, completed, notRequired }

    func bentoCardState(for item: QuickActionItem) -> BentoCardState {
        if isCompletedToday(for: item) { return .completed }
        if item.actionType == "weight" {
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
                if pet.weightLogs.contains(where: { $0.date > weekAgo }) { return .notRequired }
            }
        }
        if item.actionType == "expense" { return .normalPending }
        if item.actionType != "feed", reminderForAction(item) != nil { return .urgentPending }
        return .normalPending
    }

    func reminderForAction(_ item: QuickActionItem) -> Reminder? {
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return nil }
        if item.actionType == "feed" { return pendingFeedReminderForPlannedMode(pet: pet) }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return pendingReminders.first { reminder in
            guard cal.isDateInToday(reminder.scheduledAt), reminder.event?.relatedEntityId == petIdStr else { return false }
            return true
        }
    }

    func countTextForAction(_ item: QuickActionItem) -> String? {
        let cal = Calendar.current
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return nil }
        switch item.actionType {
        case "walk":
            let count = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
            let dist = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.reduce(0.0) { $0 + $1.distanceMeters }
            if count == 0 { return l.homeWalkNoneToday }
            let ds = dist >= 1000 ? String(format: "%.1fkm", dist/1000) : String(format: "%.0fm", dist)
            return l.homeWalkTodayBadge(count: count, dist: ds)
        case "feed":
            let goal = max(UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)"), 3)
            let count = pet.careLogs.filter { $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) && $0.isManualFeedLogEntry }.count
            return l.homeFeedMealsProgress(current: count, goal: goal)
        case "water":
            let count = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? l.homeTimesToday(count) : nil
        case "waterChange":
            if let last = pet.careLogs.filter({ $0.type == CareType.waterChange.rawValue }).max(by: { $0.date < $1.date }) {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已换" : "\(days)天前"
            }
            return nil
        case "potty":
            let count = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            return count > 0 ? l.homeTimesToday(count) : nil
        case "expense":
            let total = pet.expenseLogs.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }.reduce(0.0) { $0 + $1.amount }
            return total > 0 ? l.homeExpenseMonthCNY(Int(total)) : nil
        case "weight":
            if let last = pet.weightLogs.sorted(by: { $0.date < $1.date }).last {
                return l.homeLastWeightKg(last.weight)
            }
            return nil
        default: return nil
        }
    }

    func avatarForAction(_ item: QuickActionItem) -> UIImage? {
        if item.entityKind == .human, let hid = item.entityId, let human = humans.first(where: { $0.id == hid }), let data = human.avatarImageData { return UIImage(data: data) }
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }), let data = pet.avatarImageData else { return nil }
        return UIImage(data: data)
    }

    func themeColorForAction(_ item: QuickActionItem) -> String? {
        if item.entityKind == .human, let hid = item.entityId, let human = humans.first(where: { $0.id == hid }) {
            return human.themeColorHex.isEmpty ? "233BFF" : human.themeColorHex
        }
        guard let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) else { return nil }
        return pet.themeColorHex
    }

    func quickActionUsesDetailSheetRemove(_ actionType: String) -> Bool {
        ["feed","water","waterChange","filterClean","play","potty","litter","weight","expense","health"].contains(actionType)
    }

    func feedQuickActionAppearsComplete(for pet: Pet) -> Bool {
        let cal = Calendar.current
        if HomeFeedRecordMode.isPlanned(for: pet.id) {
            if !petHasPlannedFeedSchedules(pet) { return false }
            return pendingFeedReminderForPlannedMode(pet: pet) == nil
        }
        let goal = max(UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)"), 3)
        return pet.careLogs.filter { cal.isDateInToday($0.date) && $0.type == CareType.feeding.rawValue && $0.isManualFeedLogEntry }.count >= goal
    }

    func petHasPlannedFeedSchedules(_ pet: Pet) -> Bool {
        let id = pet.id.uuidString
        return allEvents.contains { $0.relatedEntityId == id && $0.eventType == EventType.foodChange.rawValue }
    }

    func pendingFeedReminderForPlannedMode(pet: Pet) -> Reminder? {
        guard HomeFeedRecordMode.isPlanned(for: pet.id) else { return nil }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return pendingReminders.first { cal.isDateInToday($0.scheduledAt) && $0.event?.relatedEntityId == petIdStr && $0.event?.eventType == EventType.foodChange.rawValue }
    }
}

// MARK: - Action Handlers

private extension GoDashboardView {
    func handleAction(_ item: QuickActionItem) {
        if item.entityKind == .human, let hid = item.entityId, let human = humans.first(where: { $0.id == hid }) {
            if isHumanQuickActionPrivate(item, human: human) {
                showingHumanPrivacyAlert = true
                return
            }
            switch item.actionType {
            case "humanWeight":     quickHumanWeightHuman = human
            case "humanWorkout":    quickHumanWorkoutHuman = human
            case "humanMedication": quickHumanMedicationHuman = human
            case "humanNote":       quickHumanNoteHuman = human
            default:                selectedHuman = human
            }
            return
        }
        switch item.actionType {
        case "calendar": showingCalendar = true
        case "add":      showingAddEntity = true
        case "moment":
            showMomentPet = item.petId.flatMap { pid in pets.first(where: { $0.id == pid }) } ?? pets.first
        case "health":
            quickHealthDetailPet = item.petId.flatMap { pid in pets.first(where: { $0.id == pid }) } ?? pets.first
        case "groom", "hygiene":
            quickAccessCarePet = item.petId.flatMap { pid in pets.first(where: { $0.id == pid }) } ?? pets.first
        case "expense":
            quickExpensePet = item.petId.flatMap { pid in pets.first(where: { $0.id == pid }) } ?? pets.first
        default:
            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) { applyAction(item.actionType, pet: pet) }
            else if pets.count == 1 { applyAction(item.actionType, pet: pets[0]) }
        }
    }

    func privacyField(forHumanAction actionType: String) -> HumanPrivateField? {
        PrivacyService.field(forHumanAction: actionType)
    }

    func isHumanQuickActionPrivate(_ item: QuickActionItem, human: Human? = nil) -> Bool {
        let target = human ?? item.entityId.flatMap { id in humans.first(where: { $0.id == id }) }
        return PrivacyService.isHumanQuickActionLocked(item, human: target, viewedBy: activeViewerHumanId)
    }

    func privacyBadgeText(for item: QuickActionItem) -> String? {
        guard item.entityKind == .human,
              let field = privacyField(forHumanAction: item.actionType),
              let human = item.entityId.flatMap({ id in humans.first(where: { $0.id == id }) }) else { return nil }
        return PrivacyService.badgeText(for: field, human: human, viewedBy: activeViewerHumanId)
    }

    func handleLongPressAction(_ item: QuickActionItem) {
        if item.entityKind == .human, let hid = item.entityId, let human = humans.first(where: { $0.id == hid }) {
            if isHumanQuickActionPrivate(item, human: human) {
                showingHumanPrivacyAlert = true
                return
            }
            switch item.actionType {
            case "humanWeight":     quickHumanWeightDetailHuman = human
            case "humanWorkout":    quickHumanWorkoutDetailHuman = human
            case "humanMedication": quickHumanMedicationHuman = human
            case "humanNote":       selectedHuman = human
            default:                selectedHuman = human
            }
            return
        }

        let pet = item.petId.flatMap { pid in pets.first(where: { $0.id == pid }) } ?? pets.first
        guard let p = pet else { return }
        switch item.actionType {
        case "feed":                feedDetailPet = p
        case "water":
            waterDetailModeRaw = QuickWaterDetailSheet.WaterMode.drink.rawValue
            waterDetailPet = p
        case "waterChange":
            waterDetailModeRaw = QuickWaterDetailSheet.WaterMode.change.rawValue
            waterDetailPet = p
        case "filterClean":
            waterDetailModeRaw = nil
            waterDetailPet = p
        case "play":                playDetailPet = p
        case "potty":               pottyDetailPet = p
        case "litter":              litterDetailPet = p
        case "health":              quickHealthDetailPet = p
        case "hygiene","groom":     quickGroomDetailPet = p
        case "walk":                quickWalkDetailPet = p
        case "weight":              quickWeightDetailPet = p
        case "expense":             quickExpenseDetailPet = p
        default:                    selectedPet = p; selectedPetTab = .overview
        }
    }

    func applyAction(_ actionType: String, pet: Pet) {
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        switch actionType {
        case "walk":
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
                showToast(pet, message: l.homeToastWalkStarted(pet.name), emoji: "🦮", duration: 2.0)
            }
        case "weight": quickWeightPet = pet
        case "hygiene","groom": quickAccessCarePet = pet
        case "potty":
            let got = CareEventService.recordPotty(pet: pet, context: modelContext, executorId: uid)
            showToast(pet, message: l.homeToastPotty(pet.name, points: got.petGot + got.humanGot), emoji: "💩")
        case "litter":
            let got = CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: uid, reward: .potty(isLitter: true))
            showToast(pet, message: l.homeToastLitter(pet.name, points: got.humanGot), emoji: "🧹")
        case "feed":
            let performFeed = {
                if HomeFeedRecordMode.isPlanned(for: pet.id) {
                    if self.completePlannedFeedFromHome(pet: pet) { return }
                    self.feedDetailPet = pet
                } else {
                    let got = CareEventService.recordManualFeed(pet: pet, amountGrams: pet.dailyPortionGrams, context: self.modelContext, executorId: uid)
                    self.showToast(pet, message: l.homeToastManualFeed(pet.name, points: got.petGot + got.humanGot), emoji: "🍗")
                }
            }
            if let w = AntiRepeatCareManager.checkRecentCareLog(for: pet, type: .feeding, thresholdMinutes: 120, currentUserId: uid, in: humans) {
                antiRepeatTitle = l.homeAntiDupFeedTitle
                antiRepeatMessage = l.homeAntiDupFeedMessage(executor: w.executorName, minutes: w.minutesAgo, petName: pet.name)
                pendingRepeatAction = performFeed
                showingAntiRepeatAlert = true
            } else { performFeed() }
        case "water":
            let got = CareEventService.recordCare(pet: pet, type: .watering, amountMl: 250, context: modelContext, executorId: uid, reward: .water)
            showToast(pet, message: l.homeToastWater(pet.name, points: got.petGot + got.humanGot), emoji: "💧")
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
        case "play":
            let playReward = QuestManager.OhanaActionType.general(
                humanReward: 2,
                petReward: 3,
                emoji: "🎾",
                title: l.homePlayQuestTitle(pet.name)
            )
            let got = CareEventService.recordCare(pet: pet, type: .play, context: modelContext, executorId: uid, reward: playReward)
            showToast(pet, message: l.homeToastPlay(pet.name, points: got.petGot + got.humanGot), emoji: "🎾")
        default:
            selectedPet = pet; selectedPetTab = .overview
        }
    }

    func applySpecialCareCheckIn(type: CareType, pet: Pet) {
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let careLabel = l.careTypeUILabel(type)
        let oat: QuestManager.OhanaActionType = .general(humanReward: 15, petReward: 20, emoji: type.emoji, title: "\(pet.name) \(careLabel)")
        let got = CareEventService.recordCare(pet: pet, type: type, context: modelContext, executorId: uid, reward: oat)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(pet, message: "\(pet.name) \(careLabel) +\(got.petGot + got.humanGot)🥥", emoji: type.emoji)
    }

    func applyGroomCheckIn(_ raw: String, pet: Pet) {
        let type: HygieneType
        switch raw {
        case "bath": type = .bath; case "teeth": type = .teeth; case "nails": type = .nails
        case "brushing": type = .brushing; case "ears": type = .ears; default: return
        }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet)
        modelContext.insert(log); modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let got = QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
        showToast(pet, message: l.homeToastGroomLine(petName: pet.name, type: type, points: got.petGot + got.humanGot), emoji: type.emoji)
    }

    func applyPottyCheckIn(_ raw: String, pet: Pet) {
        let type = PottyType(rawValue: raw) ?? .perfectPoop
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let got = CareEventService.recordPotty(pet: pet, type: type, context: modelContext, executorId: uid)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(pet, message: l.homeToastPottyLine(petName: pet.name, type: type, points: got.petGot + got.humanGot), emoji: type.emoji)
    }

    func applyHealthCheckIn(_ raw: String, pet: Pet) {
        switch raw {
        case "symptom": showingAddSymptomSheet = true; symptomSheetPet = pet
        case "vaccine":
            modelContext.insert(PetHealthLog(date: Date(), type: .vaccine, note: l.homeQuickCheckInNote, pet: pet))
            modelContext.safeSave()
            showToast(pet, message: l.homeToastHealthVaccine(pet.name), emoji: "💉")
        case "deworming":
            modelContext.insert(PetHealthLog(date: Date(), type: .dewormingExternal, note: l.homeQuickCheckInNote, pet: pet))
            modelContext.safeSave()
            showToast(pet, message: l.homeToastHealthDeworm(pet.name), emoji: "💊")
        case "visit":
            modelContext.insert(PetHealthLog(date: Date(), type: .checkup, note: l.homeQuickCheckInNote, pet: pet))
            modelContext.safeSave()
            showToast(pet, message: l.homeToastHealthVisit(pet.name), emoji: "🏥")
        case "heatCycle":
            if !pet.isNeutered { showingAddHeatCycleSheet = true; heatCycleSheetPet = pet }
        default: break
        }
    }

    @discardableResult
    func completePlannedFeedFromHome(pet: Pet) -> Bool {
        guard let reminder = pendingFeedReminderForPlannedMode(pet: pet) else { return false }
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let got = CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: modelContext,
            quality: .precise,
            executorId: uid
        ) ?? (humanGot: 0, petGot: 0)
        showToast(pet, message: l.homeToastPlannedFeed(pet.name, points: got.petGot + got.humanGot), emoji: "🍗")
        return true
    }

    @MainActor
    func completeIslandQuest(_ quest: IslandQuest) {
        if quest.id.hasPrefix("q_feed_") {
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) { applyAction("feed", pet: p) }
        } else if quest.id.hasPrefix("q_water_") && !quest.id.hasPrefix("q_water_plant") {
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) { applyAction("water", pet: p) }
        } else {
            switch quest.id {
            case "q_walk":
                if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) { applyAction("walk", pet: p) }
            case "q_potty":
                if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) { applyAction("potty", pet: p) }
            case let id where id.hasPrefix("q_play_"):
                if let petId = quest.targetPetId, let p = pets.first(where: { $0.id == petId }) { applyAction("play", pet: p) }
            case let id where id.hasPrefix("q_weight_"):
                if let petId = quest.targetPetId, let p = pets.first(where: { $0.id == petId }) {
                    quickWeightPet = p
                    return
                }
            case let id where id.hasPrefix("q_moment_"):
                if let petId = quest.targetPetId, let p = pets.first(where: { $0.id == petId }) {
                    showMomentPet = p
                    return
                }
            case "q_water_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) { completePlantWatering(pl) }
            case "q_fertilize_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) { completePlantFertilizing(pl) }
            case "q_reminder": showingCalendar = true
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
        }
        let amt = IslandQuestEngine.coconutReward(forQuestId: quest.id)
        if amt > 0 && quest.id != "q_walk" {
            QuestManager.shared.addCoconuts(amt, title: l.homeIslandQuestRewardTitle)
            rewardCoconutAmount = amt; showRewardCoconut = true
        }
    }

    @MainActor func completePlantWatering(_ plant: Plant) {
        plant.lastWateredDate = Date()
        let log = PlantCareLog(date: Date(), careType: .watering); log.plant = plant; modelContext.insert(log)
        modelContext.insert(Event(title: l.homePlantWaterEventTitle(plantName: plant.name), startDate: Date(), isAllDay: false, eventType: EventType.watering.rawValue, relatedEntityType: EntityKind.plant.rawValue, relatedEntityId: plant.id.uuidString))
        modelContext.safeSave()
    }

    @MainActor func completePlantFertilizing(_ plant: Plant) {
        plant.lastFertilizedDate = Date()
        let log = PlantCareLog(date: Date(), careType: .fertilizing); log.plant = plant; modelContext.insert(log)
        modelContext.insert(Event(title: l.homePlantFertilizeEventTitle(plantName: plant.name), startDate: Date(), isAllDay: false, eventType: EventType.fertilizing.rawValue, relatedEntityType: EntityKind.plant.rawValue, relatedEntityId: plant.id.uuidString))
        modelContext.safeSave()
    }

    func showToast(_ pet: Pet, message: String, emoji: String, duration: Double = 1.5) {
        actionToast = (pet: pet, message: message, emoji: emoji)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { actionToast = nil }
    }

    func triggerCoconutReward(amount: Int, label: String? = nil) {
        rewardCoconutAmount = amount; rewardCoconutLabel = label; showRewardCoconut = true
    }
}

// MARK: - Secondary Sheets (applied via .background to avoid type-checker timeout)

private extension GoDashboardView {
    @ViewBuilder var goSecondarySheets: some View {
        Color.clear
            .sheet(isPresented: $showingFamilyStripFull) {
                if let pet = deckActivePet {
                    NavigationStack {
                        ScrollView {
                            FamilyActivityStripView(pet: pet, style: .full).padding(.vertical, 20)
                        }
                        .navigationTitle(l.homeFamilyCareTitle(petName: pet.name)).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(l.done) { showingFamilyStripFull = false }.foregroundStyle(Color.goPrimary) } }
                    }
                    .presentationDetents([.medium]).presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showIslandDailyReport) {
                IslandDailyReportSheet(isPresented: $showIslandDailyReport, pets: pets, reminders: pendingReminders, plants: plants, events: allEvents)
            }
            .sheet(isPresented: $showingAddSymptomSheet) {
                if let pet = symptomSheetPet { NavigationStack { AddSymptomSheet(pet: pet) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
            }
            .sheet(isPresented: $showingAddHeatCycleSheet) {
                if let pet = heatCycleSheetPet { NavigationStack { AddHeatCycleSheet(pet: pet) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
            }
            .sheet(isPresented: $showingCrewRoster) {
                NavigationStack {
                    CrewRosterOverlay(
                        onSelectPet: { pet in showingCrewRoster = false; selectedPetTab = .overview; selectedPet = pet },
                        onSelectHuman: { human in showingCrewRoster = false; selectedHuman = human }
                    )
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button { showingCrewRoster = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } } }
                }
            }
            .fullScreenCover(isPresented: $showIslandWeight) { IslandWeightDashboard() }
            .fullScreenCover(isPresented: $showIslandExpense) { IslandExpenseDashboard() }
            .fullScreenCover(isPresented: $showIslandExplore) { IslandExplorationDashboard() }
            .fullScreenCover(isPresented: $showIslandWealth) { IslandWealthDashboardView() }
            .fullScreenCover(isPresented: $showingAllFoodManagement) { AllPetsFoodOverviewSheet() }
            .fullScreenCover(isPresented: $showOasisReward) { OasisRewardView() }
            .fullScreenCover(isPresented: $showWalkFullScreen, onDismiss: {
                if PetWalkingManager.shared.phase != .idle { walkMinimized = true }
            }) {
                if let walkPet = PetWalkingManager.shared.currentPet ?? deckActivePet ?? pets.first {
                    WalkTrackingFullScreen(pet: walkPet, onMinimize: { walkMinimized = true })
                }
            }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var ns
    @Previewable @State var pet: Pet? = nil
    @Previewable @State var human: Human? = nil
    @Previewable @State var plant: Plant? = nil
    @Previewable @State var tab: PetDetailTab = .overview

    GoDashboardView(selectedPet: $pet, selectedHuman: $human, selectedPlant: $plant, selectedPetTab: $tab, heroNS: ns)
        .modelContainer(SharedModelContainer.make())
}
