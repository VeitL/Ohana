//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  GO Focus UI — default home page.
//  This is the primary app home.
//

import SwiftUI
import SwiftData
import Foundation
import Combine

// ─────────────────────────────────────────────────
// MARK: – Main view
// ─────────────────────────────────────────────────

struct FocusStackHomeTestView: View {
    // Bindings wired by ContentView for NavigationStack zoom transitions
    @Binding var selectedPet:    Pet?
    @Binding var selectedHuman:  Human?
    @Binding var selectedPlant:  Plant?
    @Binding var selectedPetTab: PetDetailTab
    let heroNS: Namespace.ID

    init(
        selectedPet: Binding<Pet?>,
        selectedHuman: Binding<Human?>,
        selectedPlant: Binding<Plant?>,
        selectedPetTab: Binding<PetDetailTab>,
        heroNS: Namespace.ID
    ) {
        self._selectedPet = selectedPet
        self._selectedHuman = selectedHuman
        self._selectedPlant = selectedPlant
        self._selectedPetTab = selectedPetTab
        self.heroNS = heroNS

        // 首页只需要判断近期喂食状态；完整历史由粮食详情页负责加载。
        // 收窄这条 Query 能避免启动时水合长期喂食历史，减少首次点卡片前的主线程压力。
        let todayStart = Calendar.current.startOfDay(for: Date())
        let eventStart = Calendar.current.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let eventEnd = Calendar.current.date(byAdding: .day, value: 45, to: todayStart) ?? todayStart
        let recentFeedStart = Calendar.current.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let recentExpenseStart = Calendar.current.date(byAdding: .day, value: -90, to: todayStart) ?? todayStart
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                (event.startDate >= eventStart && event.startDate <= eventEnd) || event.recurrenceDays > 0
            },
            sort: \.startDate
        )
        _allFeedCareLogs = Query(
            filter: #Predicate<PetCareLog> { $0.type == "喂食" && $0.date >= recentFeedStart },
            sort: \.date,
            order: .reverse
        )
        _pendingReminders = Query(
            filter: #Predicate<Reminder> { reminder in
                reminder.status == "pending" && reminder.scheduledAt <= eventEnd
            },
            sort: \.scheduledAt
        )
        _activeHumanMedications = Query(
            filter: #Predicate<HumanMedication> { medication in
                medication.isActive
            }
        )
        _todayHumanMedicationLogs = Query(
            filter: #Predicate<HumanMedicationLog> { log in
                log.scheduledTime >= todayStart && log.scheduledTime < todayEnd
            },
            sort: \.scheduledTime
        )
        _recentHumanExpenseLogs = Query(
            filter: #Predicate<PetExpenseLog> { log in
                log.date >= recentExpenseStart
            },
            sort: \.date,
            order: .reverse
        )
    }

    @Environment(\.ohanaDisplayCornerRadius) private var displayCornerRadius
    @Environment(\.modelContext) private var modelContext
    @Bindable private var questMgr = QuestManager.shared
    @Query(sort: \Pet.createdAt,   order: .reverse) private var pets:   [Pet]
    @Query(sort: \Human.createdAt, order: .reverse) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(filter: #Predicate<PetCareLog> { $0.type == "喂食" },
           sort: \PetCareLog.date,
           order: .reverse) private var allFeedCareLogs: [PetCareLog]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query private var activeHumanMedications: [HumanMedication]
    @Query private var todayHumanMedicationLogs: [HumanMedicationLog]
    @Query private var recentHumanExpenseLogs: [PetExpenseLog]
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    // Header state
    @State private var functionMenuPresentation: FunctionMenuPresentation?
    @State private var showStreakDetail    = false
    @State private var headerStreak        = 0
    @State private var fabExpanded         = false
    @State private var fabMenuItemsVisible = false
    @State private var activeAddEntityType: EntityType? = nil
    @State private var showingCrewRoster   = false
    @State private var showingAccountSwitcher = false
    @State private var showingSettings     = false
    @State private var showingCalendar     = false
    @State private var calendarEntityFilterId: String? = nil
    @State private var calendarHumanFilterId: String? = nil
    @State private var showingOasisReward  = false
    @State private var activeCoconutLogSubject: CoconutLogSubject? = nil
    @State private var cardFabExpanded     = false
    @State private var cardFabMenuItemsVisible = false
    @State private var expandedAllFeaturesPet: Pet? = nil
    @State private var expandedAllFeaturesHuman: Human? = nil
    @State private var expandedBasicInfoPet: Pet? = nil
    @State private var expandedBasicInfoHuman: Human? = nil
    @State private var pressedExpandedActionId: String? = nil
    @State private var expandedQuickActionMenuTarget: ExpandedQuickActionMenuTarget? = nil
    @State private var expandedQuickWeightPet: ExpandedQuickPetRecordRoute? = nil
    @State private var expandedQuickExpensePet: ExpandedQuickPetRecordRoute? = nil
    @State private var expandedQuickWeightDetailPet: Pet? = nil
    @State private var expandedQuickExpenseDetailPet: Pet? = nil
    @State private var expandedQuickFeedDetailPet: Pet? = nil
    @State private var expandedQuickFeedOpensManualSheet = false
    @State private var expandedQuickWaterDetailPet: Pet? = nil
    @State private var expandedQuickPottyDetailPet: Pet? = nil
    @State private var expandedQuickLitterDetailPet: Pet? = nil
    @State private var expandedQuickPlayDetailPet: Pet? = nil
    @State private var expandedQuickHygienePet: Pet? = nil
    @State private var expandedQuickWalkPet: Pet? = nil
    @State private var expandedQuickHealthPet: Pet? = nil
    @State private var expandedQuickHealthInitialSection: PetHealthInitialSection? = nil
    @State private var expandedQuickPetMedicationPet: Pet? = nil
    @State private var expandedQuickPetMedicationAdd: ExpandedQuickPetRecordRoute? = nil
    @State private var todayFocusWalkPet: Pet? = nil
    @State private var expandedQuickMomentPet: Pet? = nil
    @State private var expandedMomentHistoryPet: Pet? = nil
    @State private var expandedQuickHumanWeight: ExpandedQuickHumanRecordRoute? = nil
    @State private var expandedQuickHumanWorkout: ExpandedQuickHumanRecordRoute? = nil
    @State private var expandedQuickHumanMedicationAdd: ExpandedQuickHumanRecordRoute? = nil
    @State private var expandedQuickHumanMedication: Human? = nil
    @State private var expandedQuickHumanNote: ExpandedQuickHumanRecordRoute? = nil
    @State private var expandedQuickHumanExpense: ExpandedQuickHumanRecordRoute? = nil
    @State private var expandedHumanWeightDetail: Human? = nil
    @State private var expandedHumanWorkoutDetail: Human? = nil
    @State private var expandedHumanExpenseDetail: Human? = nil
    @State private var expandedHumanNoteDetail: Human? = nil
    @State private var isExpandedQAEditMode = false
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    private var maxCardsPerPage: Int { FocusHomeCardDataSource.maxCardsPerPage }
    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || workloadPolicy.shouldReduceWork()
    }
    private var walletAnimation: Animation {
        walletExpandAnimation
    }
    private var walletExpandAnimation: Animation {
        shouldReduceWork ? HeroAnim.walletReduced : HeroAnim.walletSpring
    }
    private var walletCollapseAnimation: Animation {
        shouldReduceWork ? HeroAnim.walletReduced : HeroAnim.walletCollapseSpring
    }
    private var walletContentAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : HeroAnim.walletContentSpring
    }
    private var transitionAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : HeroAnim.transitionSpring
    }
    @State private var expandedQAJiggle = false
    @State private var expandedQAEditItems: [QuickActionItem] = []
    @State private var expandedQADraggingItemId: String? = nil
    @State private var showingQuickActionLimitAlert = false
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)? = nil
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""
    @State private var showingSingleUseNotice = false
    @State private var singleUseNoticeTitle = ""
    @State private var singleUseNoticeMessage = ""
    @State private var showingHumanPrivacyAlert = false
    @State private var expandedActionPulseCardId: UUID? = nil
    @State private var expandedQuickActionPulseKey: String? = nil
    @State private var expandedQuickActionPulseToken: CheckInFeedbackToken? = nil
    @State private var walkTransformBurstCardId: UUID? = nil
    @State private var showExpandedCoconutReward = false
    @State private var expandedCoconutRewardAmount = 0
    @State private var expandedCoconutRewardLabel: String? = nil
    @State private var homeCardReorderDragId: UUID? = nil
    @State private var homeCardReorderDragOffset: CGFloat = 0
    @State private var homeCardReorderStartOffsetY: CGFloat = 0
    @State private var homeCardReorderCards: [FocusCard]? = nil
    @State private var homeCardReorderDidMove = false
    @State private var homeCardPressCandidateId: UUID? = nil
    @State private var suppressNextHomeCardTap = false
    @State private var homeCardReorderSession = 0
    @State private var homeCardReorderEnabled = false
    @State private var homeCardReorderModeActive = false
    @State private var didRecordHomeFirstFrame = false
    @State private var avatarCacheRevision = 0
    @State private var homeAvatarDataById: [UUID: Data] = [:]
    @State private var homePopoutDataById: [UUID: Data] = [:]
    @State private var homeAvatarLoadTask: Task<Void, Never>? = nil
    @State private var quickActionClockTick = Date()
    @State private var homeCardSnapshot: [FocusCard] = []
    @State private var homeCardSnapshotInitialized = false
    @State private var stableHomeSafeAreaTop: CGFloat?
    @State private var stableHomeSafeAreaBottom: CGFloat?

    // Debug-only: show Mochi/Luna dummy stack even when real data is empty.
    @AppStorage("debugShowDummyCards") private var showDummyCards: Bool = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw: String = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr: String = ""
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard: Bool = true
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false
    @State private var pendingFirstSuccessMomentPetId: UUID?
    @State private var firstSuccessMomentCoconutBefore: Int?

    // Bloom expand (dummy cards only)
    @Namespace private var ns
    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var detailFooterVisible: Bool = false

    // Apple-Wallet-style three-state stack:
    //  • collapsed (isExpanded=false): all cards fan vertically below the focus strip;
    //    the bottom card is frontmost and fully visible.
    //  • expanded  (isExpanded=true): tapped card lifts below the top controls; the
    //    inactive cards compress into a tight wallet stack at the screen bottom.
    //  • restore: tapping the active card again, or swiping down, returns to collapsed.
    // Tapping cards only changes the wallet state. In collapsed mode, long-press
    // then drag reorders the home stack; expanded hero long-press opens basic info.
    @State private var isExpanded: Bool = false
    @State private var activeCardId: UUID?
    @State private var expandedQuickModulesReady = false
    @State private var walletTransitionCardId: UUID?
    @State private var walletTransitionSession = 0
    @State private var rosterPreviewCard: FocusCard?
    @State private var pendingPromotedHomeCardId: UUID?
    @State private var walletTapFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    private var todayFocusActivePet: Pet? {
        if let id = activeCardId,
           let pet = pets.first(where: { $0.id == id && !$0.hasPassedAway }) {
            return pet
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    private var safeAreaTop: CGFloat {
        resolvedSafeAreaTop()
    }

    private var safeAreaBottom: CGFloat {
        resolvedSafeAreaBottom()
    }

    private func resolvedSafeAreaTop(in geo: GeometryProxy? = nil) -> CGFloat {
        if let stableHomeSafeAreaTop, stableHomeSafeAreaTop > 1 {
            return stableHomeSafeAreaTop
        }
        if let geoTop = geo?.safeAreaInsets.top, geoTop > 1 {
            return geoTop
        }
        let windowTop = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 0
        return windowTop > 1 ? windowTop : 59
    }

    private func resolvedSafeAreaBottom(in geo: GeometryProxy? = nil) -> CGFloat {
        if let stableHomeSafeAreaBottom, stableHomeSafeAreaBottom > 1 {
            return stableHomeSafeAreaBottom
        }
        if let geoBottom = geo?.safeAreaInsets.bottom, geoBottom > 1 {
            return geoBottom
        }
        let windowBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 0
        return windowBottom > 1 ? windowBottom : 34
    }

    private func stabilizeHomeSafeArea(from geo: GeometryProxy) {
        let top = geo.safeAreaInsets.top > 1 ? geo.safeAreaInsets.top : resolvedSafeAreaTop()
        let bottom = geo.safeAreaInsets.bottom > 1 ? geo.safeAreaInsets.bottom : resolvedSafeAreaBottom()
        guard stableHomeSafeAreaTop == nil || stableHomeSafeAreaBottom == nil else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if stableHomeSafeAreaTop == nil, top > 1 {
                stableHomeSafeAreaTop = top
            }
            if stableHomeSafeAreaBottom == nil, bottom > 1 {
                stableHomeSafeAreaBottom = bottom
            }
        }
        AppPerformanceMonitor.shared.record(
            "home.layoutStable",
            valueMS: 0,
            note: "top \(Int(top)), bottom \(Int(bottom))"
        )
    }

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanIdStr }
    }

    private var activeHumanDisplayName: String {
        guard let human = activeHuman else { return "未绑定" }
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "成员" }
        return name.count > 6 ? "\(String(name.prefix(6)))…" : name
    }

    private var activeHumanCoconutBalance: Int {
        activeHuman?.coconutBalance ?? 0
    }

    private var headerCoconutBalance: Int {
        guard let activeWalletCard else { return activeHumanCoconutBalance }
        if activeWalletCard.isHuman,
           let human = humans.first(where: { $0.id == activeWalletCard.id }),
           PrivacyService.isLocked(.wishlist, for: human, viewedBy: activeHumanId) {
            return 0
        }
        return activeWalletCard.coconutBalance
    }

    private var cards: [FocusCard] {
        homeCardSnapshotInitialized ? homeCardSnapshot : buildHomeCardSnapshot()
    }

    private var homeCardSnapshotSourceSignature: String {
        FocusHomeCardDataSource.sourceSignature(
            pets: pets,
            humans: humans,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            appLanguage: appLanguage
        )
    }

    private func buildHomeCardSnapshot() -> [FocusCard] {
        FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards
        )
    }

    private func refreshHomeCardSnapshot() {
        let snapshot = buildHomeCardSnapshot()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            homeCardSnapshot = snapshot
            homeCardSnapshotInitialized = true
            seedVisibleAvatarData(from: snapshot)
        }
        AppPerformanceMonitor.shared.record("home.firstSnapshotReady", valueMS: 0)
        scheduleVisibleAvatarDataLoad(from: snapshot)
    }

    private func seedVisibleAvatarData(from source: [FocusCard]) {
        let seeded = FocusHomeCardDataSource.seedAvatarData(
            from: source,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            currentAvatarData: homeAvatarDataById,
            currentPopoutData: homePopoutDataById
        )
        homeAvatarDataById = seeded.avatarData
        homePopoutDataById = seeded.popoutData
        let visibleCount = min(source.count, maxCardsPerPage)
        AppPerformanceMonitor.shared.record("home.avatarPreviewReady", valueMS: 0, note: "\(visibleCount) visible")
    }

    private func scheduleVisibleAvatarDataLoad(from source: [FocusCard]? = nil) {
        homeAvatarLoadTask?.cancel()
        let sourceCards = source ?? cards
        let targetIds = Array(sourceCards.prefix(maxCardsPerPage)).map(\.id)
        let targetIdSet = Set(targetIds)
        if !targetIdSet.isEmpty {
            homeAvatarDataById = homeAvatarDataById.filter { targetIdSet.contains($0.key) }
            homePopoutDataById = homePopoutDataById.filter { targetIdSet.contains($0.key) }
        }

        homeAvatarLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            guard expandedId == nil && !isExpanded else { return }

            var payloads: [FocusWalletAvatarCache.Payload] = []
            for id in targetIds where homeAvatarDataById[id] == nil {
                guard !Task.isCancelled else { return }
                guard expandedId == nil && !isExpanded else { return }
                guard let data = avatarDataForHomeCard(id: id) else {
                    if let popout = popoutDataForHomeCard(id: id) {
                        homePopoutDataById[id] = popout
                    }
                    await Task.yield()
                    continue
                }
                homeAvatarDataById[id] = data
                if let popout = popoutDataForHomeCard(id: id) {
                    homePopoutDataById[id] = popout
                }
                payloads.append(FocusWalletAvatarCache.Payload(id: id, data: data))
            }

            if payloads.isEmpty {
                payloads = targetIds.compactMap { id in
                    guard let data = homeAvatarDataById[id] ?? avatarDataForHomeCard(id: id) else { return nil }
                    return FocusWalletAvatarCache.Payload(id: id, data: data)
                }
            }

            let didRefresh = await FocusWalletAvatarCache.preload(payloads: payloads)
            guard !Task.isCancelled else { return }
            guard !isExpanded, walletTransitionCardId == nil else { return }
            if didRefresh {
                avatarCacheRevision &+= 1
                AppPerformanceMonitor.shared.record("home.avatarFinalReady", valueMS: 0, note: "\(payloads.count) visible")
            }
        }
    }

    private func avatarDataForHomeCard(id: UUID) -> Data? {
        FocusHomeCardDataSource.avatarDataForHomeCard(id: id, pets: pets, humans: humans)
    }

    private func popoutDataForHomeCard(id: UUID) -> Data? {
        FocusHomeCardDataSource.popoutDataForHomeCard(id: id, pets: pets, equipFxPopoutCard: equipFxPopoutCard)
    }

    private func runHomePostFirstFrameMaintenance() {
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            ensureTodayCheckIn()
            refreshHeaderStreak()
            syncWalkCardSurfaceVisibility()
            walletTapFeedbackGenerator.prepare()
        }
    }

    private func prepareExpandedQuickModulesAfterHeroFrame() {
        expandedQuickModulesReady = false
        let expectedCardId = activeCardId
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: shouldReduceWork ? 80 : 220)
            guard isExpanded, activeCardId == expectedCardId else { return }
            withAnimation(walletContentAnimation) {
                expandedQuickModulesReady = true
            }
        }
    }

    private var visibleHomeCards: [FocusCard] {
        FocusHomeCardDataSource.visibleCards(
            from: cards,
            rosterPreviewCard: rosterPreviewCard,
            isExpanded: isExpanded,
            activeCardId: activeCardId,
            avatarData: homeAvatarDataById,
            popoutData: homePopoutDataById
        )
    }

    private var visibleHomeCardIdsSignature: String {
        FocusHomeCardDataSource.visibleIdsSignature(cards: cards, rosterPreviewCard: rosterPreviewCard)
    }

    private func withLoadedAvatarData(_ cards: [FocusCard]) -> [FocusCard] {
        FocusHomeCardDataSource.withLoadedAvatarData(
            cards,
            avatarData: homeAvatarDataById,
            popoutData: homePopoutDataById
        )
    }

    private var isEmptyState: Bool {
        pets.allSatisfy { $0.hasPassedAway } && humans.isEmpty && !showDummyCards
    }

    private var activeWalletCard: FocusCard? {
        guard isExpanded else { return nil }
        let heroId = activeCardId ?? visibleHomeCards.first?.id
        return visibleHomeCards.first { $0.id == heroId }
    }

    private var isWalkCardExpandedSurfaceVisible: Bool {
        guard isExpanded,
              let activeCard = activeWalletCard,
              !activeCard.isHuman,
              PetWalkingManager.shared.currentPet?.id == activeCard.id
        else { return false }

        switch PetWalkingManager.shared.phase {
        case .running, .paused, .finished:
            return true
        case .idle:
            return false
        }
    }

    private var isInlineRecordOverlayPresented: Bool {
        FocusHomeOverlayState.hasInlineRecordOverlay(
            petWeight: expandedQuickWeightPet,
            petExpense: expandedQuickExpensePet,
            humanWeight: expandedQuickHumanWeight,
            humanWorkout: expandedQuickHumanWorkout,
            humanMedication: expandedQuickHumanMedicationAdd,
            petMedication: expandedQuickPetMedicationAdd,
            humanNote: expandedQuickHumanNote,
            humanExpense: expandedQuickHumanExpense,
            quickActionMenu: expandedQuickActionMenuTarget
        )
    }

    var body: some View {
        let outerR = displayCornerRadius

        return GeometryReader { geo in
            let windowSize = geo.size
            ZStack {
                OhanaAppBackground()

                stackLayer(geo: geo, outerCornerRadius: outerR)
                    .opacity(expandedId == nil ? 1 : 0)
                    .allowsHitTesting(expandedId == nil)

                if let id = expandedId,
                   let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo, outerCornerRadius: outerR, windowSize: windowSize)
                }

                // FAB stays mounted while the wallet card stack changes modes; only its submenu content changes.
                if expandedId == nil && !isInlineRecordOverlayPresented {
                    if fabExpanded {
                        Color.black.opacity(0.25) // ui-v4: allow home FAB modal scrim backdrop
                            .ignoresSafeArea()
                            .onTapGesture { closeHomeFabMenu() }
                            .transition(.opacity)
                    }
                    homeFabOverlay(activeCard: activeWalletCard)
                        .zIndex(999)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                }

                quickInlineRecordOverlays()
                    .zIndex(2500)

                expandedQuickActionMenuOverlay()
                    .zIndex(2600)
            }
            .onAppear { stabilizeHomeSafeArea(from: geo) }
            .onChange(of: geo.safeAreaInsets.top) { _, _ in
                stabilizeHomeSafeArea(from: geo)
            }
            .onChange(of: geo.safeAreaInsets.bottom) { _, _ in
                stabilizeHomeSafeArea(from: geo)
            }
            .animation(transitionAnimation, value: expandedId)
            .animation(GoMotion.page, value: expandedQuickWeightPet?.id)
            .animation(GoMotion.page, value: expandedQuickExpensePet?.id)
            .animation(GoMotion.page, value: expandedQuickHumanWeight?.id)
            .animation(GoMotion.page, value: expandedQuickHumanWorkout?.id)
            .animation(GoMotion.page, value: expandedQuickHumanMedicationAdd?.id)
            .animation(GoMotion.page, value: expandedQuickPetMedicationAdd?.id)
            .animation(GoMotion.page, value: expandedQuickHumanNote?.id)
            .animation(GoMotion.page, value: expandedQuickHumanExpense?.id)
            .animation(GoMotion.page, value: expandedQuickActionMenuTarget?.id)
            .onChange(of: expandedId) { _, newId in
                if newId != nil {
                    detailFooterVisible = false
                    OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
                        guard expandedId == newId else { return }
                        withAnimation(GoMotion.quick) { detailFooterVisible = true }
                    }
                } else {
                    detailFooterVisible = false
                    // Collapse wallet hero mode when bloom closes
                    collapseWalletToHome()
                }
            }
        }
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .coconutRewardOverlay(
            trigger: $showExpandedCoconutReward,
            amount: expandedCoconutRewardAmount,
            label: expandedCoconutRewardLabel
        )
        // Sheets
        .sheet(item: $functionMenuPresentation) { presentation in
            FunctionMenuSheet(initialDestination: presentation.destination)
                .presentationDetents([.large]) // ui-v4: allow long feature hub sheet
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(36)
                .presentationBackground(Color.clear)
        }
        .fullScreenCover(isPresented: $showStreakDetail) {
            DailyStreakDetailView(pets: pets, onClose: { showStreakDetail = false })
        }
        .fullScreenCover(isPresented: $showingSettings) { SettingsView() }
        .sheet(item: $activeAddEntityType, onDismiss: handleAddEntityDismissed) { type in
            AddEntityDestinationView(
                type: type,
                onComplete: { activeAddEntityType = nil },
                onPetSaved: { pet in
                    handlePetSavedFromAddEntity(pet)
                },
                onHumanSaved: { human in
                    activeHumanIdStr = human.id.uuidString
                }
            )
        }
        .sheet(isPresented: $showingCrewRoster) {
            NavigationStack {
                CrewRosterOverlay(
                    onSelectPet: { pet in
                        openCrewRosterCard(FocusCard.from(pet, includeAvatarData: true))
                    },
                    onSelectHuman: { human in
                        openCrewRosterCard(FocusCard.from(human, includeAvatarData: true))
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingCrewRoster = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAccountSwitcher) {
            HumanAccountSwitcherSheet()
        }
        .sheet(isPresented: $showingCalendar, onDismiss: {
            calendarEntityFilterId = nil
            calendarHumanFilterId = nil
        }) {
            CalendarView(
                preselectedPetId: calendarEntityFilterId,
                preselectedHumanId: calendarHumanFilterId
            )
        }
        .sheet(item: $expandedAllFeaturesPet) { pet in
            PetAllFeaturesSheet(pet: pet)
                .presentationDetents([.large]) // ui-v4: allow long feature hub sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedAllFeaturesHuman) { human in
            HumanAllFeaturesSheet(human: human)
                .presentationDetents([.large]) // ui-v4: allow long feature hub sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedBasicInfoPet) { pet in
            NavigationStack { PetBasicInfoDetailView(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedBasicInfoHuman) { human in
            NavigationStack { HumanBasicInfoDetailView(human: human) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickWeightDetailPet) { pet in
            NavigationStack { WeightHistoryView(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickExpenseDetailPet) { pet in
            NavigationStack { ExpenseHistoryView(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickFeedDetailPet) { pet in
            QuickFeedDetailSheet(
                pet: pet,
                onRemove: { expandedQuickFeedDetailPet = nil },
                opensManualSheetOnAppear: expandedQuickFeedOpensManualSheet
            )
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .onDisappear { expandedQuickFeedOpensManualSheet = false }
        }
        .sheet(item: $expandedQuickWaterDetailPet) { pet in
            QuickWaterDetailSheet(pet: pet) {
                expandedQuickWaterDetailPet = nil
            }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickPottyDetailPet) { pet in
            QuickPottyDetailSheet(pet: pet) { expandedQuickPottyDetailPet = nil }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickLitterDetailPet) { pet in
            QuickLitterDetailSheet(pet: pet) { expandedQuickLitterDetailPet = nil }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickPlayDetailPet) { pet in
            QuickPlayDetailSheet(pet: pet) { expandedQuickPlayDetailPet = nil }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickHygienePet) { pet in
            NavigationStack { PetHygieneDetailView(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickWalkPet) { pet in
            NavigationStack { WalkSummarySheet(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $todayFocusWalkPet) { pet in
            WalkTrackingFullScreen(pet: pet)
        }
        .sheet(item: $expandedQuickHealthPet, onDismiss: {
            expandedQuickHealthInitialSection = nil
        }) { pet in
            NavigationStack {
                PetHealthDetailView(
                    pet: pet,
                    isModal: true,
                    initialSection: expandedQuickHealthInitialSection
                )
            }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickPetMedicationPet) { pet in
            NavigationStack { PetMedicationView(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if let pet = expandedQuickMomentPet {
                QuickMomentSheet(
                    pet: pet,
                    onRemove: nil,
                    onSaved: {
                        completeFirstSuccessMomentIfNeeded(for: pet)
                    },
                    onClose: {
                        expandedQuickMomentPet = nil
                    }
                )
                .ignoresSafeArea()
                .zIndex(100)
            }
        }
        .sheet(item: $expandedMomentHistoryPet) { pet in
            PetMomentsHubView(pet: pet)
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickHumanMedication) { human in
            NavigationStack {
                HumanMedicationView(
                    human: human,
                    showsDoneButton: true,
                    onDoseTaken: {
                        triggerExpandedActionFeedback(cardId: human.id)
                    }
                )
            }
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanWeightDetail) { human in
            NavigationStack {
                HumanWeightHistoryView(human: human)
            }
            .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanWorkoutDetail) { human in
            HumanWorkoutHistoryView(human: human)
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanExpenseDetail) { human in
            NavigationStack {
                HumanExpenseDetailView(human: human)
            }
            .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanNoteDetail) { human in
            HumanNoteHistorySheet(human: human)
                .presentationDetents([.large]) // ui-v4: allow long overview/detail sheet
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingOasisReward) {
            OasisRewardView()
        }
        .fullScreenCover(item: $activeCoconutLogSubject) { subject in
            CoconutLogView(subject: subject)
        }
        .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
            Button(l.homeConfirmCheckIn, role: .destructive) {
                pendingRepeatAction?()
                pendingRepeatAction = nil
            }
            Button(l.cancel, role: .cancel) {
                pendingRepeatAction = nil
            }
        } message: {
            Text(antiRepeatMessage)
        }
        .alert(singleUseNoticeTitle, isPresented: $showingSingleUseNotice) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(singleUseNoticeMessage)
        }
        .alert(QuickActionLimit.title, isPresented: $showingQuickActionLimitAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(QuickActionLimit.message)
        }
        .alert("仅本人可见", isPresented: $showingHumanPrivacyAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("该成员已将此功能设为仅自己可见。")
        }
        // Collapse wallet hero state when returning from pet/human detail
        .onChange(of: selectedPet)   { _, new in if new == nil { collapseWalletToHome() } }
        .onChange(of: selectedHuman) { _, new in if new == nil { collapseWalletToHome() } }
        .onChange(of: isExpanded) { _, expanded in
            if expanded, homeCardPressCandidateId != nil || homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
                resetHomeCardReorderState()
            }
            if expanded {
                cardFabMenuItemsVisible = false
                cardFabExpanded = false
                prepareExpandedQuickModulesAfterHeroFrame()
            } else {
                expandedQuickModulesReady = false
                scheduleVisibleAvatarDataLoad()
            }
            syncWalkCardSurfaceVisibility()
        }
        .onChange(of: activeCardId) { _, _ in
            if isExpanded {
                cardFabMenuItemsVisible = false
                cardFabExpanded = false
                prepareExpandedQuickModulesAfterHeroFrame()
            }
            syncWalkCardSurfaceVisibility()
        }
        .onChange(of: PetWalkingManager.shared.phase) { _, _ in syncWalkCardSurfaceVisibility() }
        .onChange(of: PetWalkingManager.shared.currentPet?.id) { _, _ in syncWalkCardSurfaceVisibility() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshHeaderStreak()
        }
        .onChange(of: activeHumanIdStr) { _, _ in
            ensureTodayCheckIn()
            refreshHeaderStreak()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            guard workloadPolicy.shouldRunTimer() else { return }
            quickActionClockTick = date
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReturnHomeAfterHumanDeletion)) { _ in
            selectedHuman = nil
            expandedBasicInfoHuman = nil
            expandedAllFeaturesHuman = nil
            expandedQuickHumanWeight = nil
            expandedQuickHumanWorkout = nil
            expandedQuickHumanMedicationAdd = nil
            expandedQuickHumanMedication = nil
            expandedQuickHumanNote = nil
            expandedQuickHumanExpense = nil
            expandedHumanWeightDetail = nil
            expandedHumanWorkoutDetail = nil
            expandedHumanExpenseDetail = nil
            expandedHumanNoteDetail = nil
            withAnimation(walletCollapseAnimation) {
                activeCardId = nil
                isExpanded = false
            }
        }
        .onAppear(perform: handleHomeAppear)
        .onChange(of: homeCardSnapshotSourceSignature) { _, _ in
            refreshHomeCardSnapshot()
        }
        .onDisappear {
            PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = false
        }
        .task(id: visibleHomeCardIdsSignature) {
            scheduleVisibleAvatarDataLoad()
        }
	}
}

private extension FocusStackHomeTestView {
    func handleHomeAppear() {
        refreshHomeCardSnapshot()
        if !didRecordHomeFirstFrame {
            didRecordHomeFirstFrame = true
            DispatchQueue.main.async {
                AppPerformanceMonitor.shared.record("启动到首页首帧", startedAt: ohanaProcessStartTime)
            }
        }
        if !homeCardReorderEnabled {
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 800) {
                homeCardReorderEnabled = true
            }
        }
        runHomePostFirstFrameMaintenance()
    }
}

// ─────────────────────────────────────────────────
// MARK: – Stack layer
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    @ViewBuilder
    private func quickInlineRecordOverlays() -> some View {
        FocusHomeQuickRecordOverlayLayer(
            petWeight: expandedQuickWeightPet,
            petExpense: expandedQuickExpensePet,
            humanWeight: expandedQuickHumanWeight,
            humanWorkout: expandedQuickHumanWorkout,
            humanMedication: expandedQuickHumanMedicationAdd,
            petMedication: expandedQuickPetMedicationAdd,
            humanNote: expandedQuickHumanNote,
            humanExpense: expandedQuickHumanExpense,
            preselectedPayerId: UserDefaults.standard.string(forKey: "currentActiveHumanId"),
            onPetWeightRewarded: { petId, delta in
                triggerExpandedActionFeedback(
                    cardId: petId,
                    coconutDelta: delta,
                    label: delta > 0 ? "体重记录 +\(delta)🥥" : nil
                )
            },
            onPetExpenseRewarded: { petId, delta in
                triggerExpandedActionFeedback(
                    cardId: petId,
                    coconutDelta: delta,
                    label: delta > 0 ? "花费记录 +\(delta)🥥" : nil
                )
            },
            onHumanSaved: { humanId, actionKey in
                triggerExpandedActionFeedback(cardId: humanId, actionKey: actionKey)
            },
            onManageHumanMedication: { human in
                expandedQuickHumanMedication = human
            },
            onPetMedicationSaved: { pet in
                MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
            },
            dismissPetWeight: dismissExpandedQuickWeight,
            dismissPetExpense: dismissExpandedQuickExpense,
            dismissHumanWeight: dismissExpandedQuickHumanWeight,
            dismissHumanWorkout: dismissExpandedQuickHumanWorkout,
            dismissHumanMedication: dismissExpandedQuickHumanMedication,
            dismissPetMedication: dismissExpandedQuickPetMedicationAdd,
            dismissHumanNote: dismissExpandedQuickHumanNote,
            dismissHumanExpense: dismissExpandedQuickHumanExpense
        )
    }

    private func openExpandedQuickWeight(for pet: Pet) {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickWeightPet = ExpandedQuickPetRecordRoute(pet: pet)
    }

    private func openExpandedQuickExpense(for pet: Pet) {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickExpensePet = ExpandedQuickPetRecordRoute(pet: pet)
    }

    private func openExpandedQuickHumanWeight(for human: Human, actionType: String = "humanWeight") {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickHumanWeight = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    private func openExpandedQuickHumanExpense(for human: Human, actionType: String = "humanExpense") {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickHumanExpense = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    private func openExpandedQuickHumanNote(for human: Human, actionType: String = "humanNote") {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickHumanNote = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    private func openExpandedQuickHumanWorkout(for human: Human, actionType: String = "humanWorkout") {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickHumanWorkout = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    private func openExpandedQuickHumanMedication(for human: Human, actionType: String = "humanMedication") {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickHumanMedicationAdd = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    private func openExpandedQuickPetMedicationAdd(for pet: Pet) {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickPetMedicationAdd = ExpandedQuickPetRecordRoute(pet: pet)
    }

    private func dismissExpandedQuickWeight(routeID: UUID) {
        guard expandedQuickWeightPet?.id == routeID else { return }
        expandedQuickWeightPet = nil
    }

    private func dismissExpandedQuickExpense(routeID: UUID) {
        guard expandedQuickExpensePet?.id == routeID else { return }
        expandedQuickExpensePet = nil
    }

    private func dismissExpandedQuickHumanWeight(routeID: UUID) {
        guard expandedQuickHumanWeight?.id == routeID else { return }
        expandedQuickHumanWeight = nil
    }

    private func dismissExpandedQuickHumanExpense(routeID: UUID) {
        guard expandedQuickHumanExpense?.id == routeID else { return }
        expandedQuickHumanExpense = nil
    }

    private func dismissExpandedQuickHumanNote(routeID: UUID) {
        guard expandedQuickHumanNote?.id == routeID else { return }
        expandedQuickHumanNote = nil
    }

    private func dismissExpandedQuickHumanWorkout(routeID: UUID) {
        guard expandedQuickHumanWorkout?.id == routeID else { return }
        expandedQuickHumanWorkout = nil
    }

    private func dismissExpandedQuickHumanMedication(routeID: UUID) {
        guard expandedQuickHumanMedicationAdd?.id == routeID else { return }
        expandedQuickHumanMedicationAdd = nil
    }

    private func dismissExpandedQuickPetMedicationAdd(routeID: UUID) {
        guard expandedQuickPetMedicationAdd?.id == routeID else { return }
        expandedQuickPetMedicationAdd = nil
    }

    private var dailyCheckInKey: String { CheckInStreakStore.checkedInKey(for: activeHumanIdStr) }

    private func dailyCheckInDateString(_ date: Date = Date()) -> String {
        CheckInStreakStore.dateString(date)
    }

    private func ensureTodayCheckIn() {
        let today = dailyCheckInDateString()
        var checkedInDates = CheckInStreakStore.checkedInDates(for: activeHumanIdStr)
        guard !checkedInDates.contains(today) else { return }

        checkedInDates.insert(today)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: activeHumanIdStr)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: l.homeDailyCheckInRewardTitle)
    }

    private func refreshHeaderStreak() {
        headerStreak = CheckInStreakStore.currentStreak(for: activeHumanIdStr)
    }

    private func stackLayer(geo: GeometryProxy, outerCornerRadius: CGFloat) -> some View {
        let activePets = pets.filter { !$0.hasPassedAway }
        let topInset = resolvedSafeAreaTop(in: geo)
        return VStack(spacing: 0) {
            goFocusHeader(safeT: topInset)

            todayFocusSection(activePets: activePets)
                .offset(y: -20)
                .padding(.bottom, -10)

            if isEmptyState {
                Spacer(minLength: 0)
                EmptyStateWelcomeCard(
                    onAddPet:   { presentAddEntity(initialType: .pet) },
                    onAddHuman: { presentAddEntity(initialType: .human) }
                )
                .padding(.horizontal, K.cardMargin)
                .padding(.bottom, 24)
            } else {
                // GeometryReader-based stack fills all remaining space below the header/focus strip.
                // Keep the same wallet stack mounted in both collapsed and expanded modes so
                // card positions animate instead of swapping between two separate layers.
                walletCardStack(cards: visibleHomeCards)
                    .padding(.horizontal, K.cardMargin)
            }
        }
    }

    @ViewBuilder
    private func todayFocusSection(activePets: [Pet]) -> some View {
        // Collapsed first screen answers: who needs care, what is urgent, what can be done now.
        let hasFocusSurface = !activePets.isEmpty || !humans.isEmpty

        if hasFocusSurface {
            FocusHomeTodayFocusSection(
                activePets: activePets,
                plants: plants,
                reminders: pendingReminders,
                humans: humans,
                events: allEvents,
                activePet: todayFocusActivePet,
                showFirstSuccessCard: showFirstSuccessCard,
                firstQuickCheckInCompleted: firstQuickCheckInCompleted,
                isExpanded: isExpanded,
                cardMargin: K.cardMargin,
                animation: walletAnimation,
                onCompleteQuest: { completeQuestInFocusStack($0) },
                onTapNegativeSignal: { handleTodayFocusNegativeSignal($0) },
                onTapOasis: { showingOasisReward = true },
                onTapFamilyTask: { openFamilyTaskFromTodayFocus($0) },
                onFirstSuccessFeed: { completeFirstSuccessFeed(for: $0) },
                onFirstSuccessPlay: { completeFirstSuccessPlay(for: $0) },
                onFirstSuccessMoment: { startFirstSuccessMoment(for: $0) }
            )
        }
    }

    // MARK: Apple-Wallet card stack — three states
    //
    // fan  (isExpanded=false): all cards fan vertically at the bottom of the
    //   available area. idx n-1 is frontmost (highest z). Tap any card → hero.
    //
    // hero (isExpanded=true): tapped card lifts to top of available area;
    //   ALL other cards compress into a tight stack at the bottom. Tap hero → restore.
    //   Tap another card → switch hero. Swipe-down → restore fan.
    //
    // Layout uses GeometryReader so the stack fills all space below the mood strip
    // and cards can animate across the full height.

    @ViewBuilder
    private func expandedWalletLayer(cards: [FocusCard], geo: GeometryProxy) -> some View {
        let n = cards.count
        let heroId = activeCardId ?? cards.first?.id
        let cardW = geo.size.width - K.cardMargin * 2
        let activeTopY = resolvedSafeAreaTop(in: geo) + K.expandedCardGlobalTopOffset
        let inactiveBottomY = geo.size.height + K.cardH - K.expandedInactiveFrontPeekH
        let quickModulesTopY = activeTopY + K.expandedCardH + K.expandedQuickModuleGap

        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let isHero = card.id == heroId
                let isInteractiveWalkCard = isWalkTrackingCard(card: card, isHero: isHero)
                let visibleHeight = isHero ? K.expandedCardH : K.cardH

                transformedWalletCard(card: card, isHero: isHero)
                .frame(width: cardW)
                .frame(height: isHero ? K.expandedCardH : K.cardH)
                .frame(height: visibleHeight, alignment: .top)
                .clipped()
                .scaleEffect(expandedActionPulseCardId == card.id ? 1.025 : 1.0, anchor: .center)
                .overlay { expandedActionPulseOverlay(for: card.id) }
                .overlay { walkTransformBurstOverlay(for: card.id) }
                .shadow( // ui-v4: allow home card stack depth
                    color: .black.opacity(isHero ? 0.22 : 0.11),
                    radius: isHero ? 20 : 8,
                    x: 0,
                    y: isHero ? 12 : 4
                )
                .offset(
                    x: K.cardMargin,
                    y: FocusWalletLayout.expandedOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: inactiveBottomY,
                        heroId: heroId,
                        heroTopY: activeTopY,
                        cards: cards
                    )
                )
                .zIndex(FocusWalletLayout.zIndex(idx: idx, n: n, isHero: isHero, heroId: heroId, cards: cards, isExpanded: isExpanded))
                .if(!isInteractiveWalkCard) { view in
                    view
                        .onTapGesture { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            guard isHero else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            openWalletCardBasicInfo(card)
                        }
                        .simultaneousGesture(collapseWalletDragGesture())
                }
                .animation(walletAnimation, value: isExpanded)
                .animation(walletAnimation, value: activeCardId)
            }

            if let activeCard = cards.first(where: { $0.id == heroId }) {
                expandedQuickModules(card: activeCard)
                    .frame(width: cardW, height: expandedQuickModuleHeight(for: activeCard))
                    .offset(x: K.cardMargin, y: quickModulesTopY)
                    .zIndex(Double(n + 80))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .simultaneousGesture(collapseWalletDragGesture())
                    .animation(walletAnimation, value: activeCardId)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        .ignoresSafeArea(.all)
    }

    private func expandedQuickModuleHeight(for card: FocusCard) -> CGFloat {
        let visibleCount: Int
        if card.isReal,
           !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            visibleCount = isExpandedQAEditMode
                ? expandedQAEditItems.count + 1
                : min(expandedQuickActionItems(for: pet).count, 8)
        } else if card.isReal,
                  card.isHuman,
                  let human = humans.first(where: { $0.id == card.id }) {
            visibleCount = isExpandedQAEditMode
                ? expandedQAEditItems.count + 1
                : min(expandedHumanQuickActionItems(for: human).count, 8)
        } else {
            visibleCount = card.actions.count
        }
        return visibleCount > 4 ? K.expandedQuickModuleEditH : K.expandedQuickModuleH
    }

    private func presentAddEntity(initialType: EntityType) {
        guard activeAddEntityType == nil else { return }
        GoKeyboard.dismiss()
        activeAddEntityType = initialType
    }

    private func handleAddEntityDismissed() {
        activeAddEntityType = nil
    }

    private func handlePetSavedFromAddEntity(_ pet: Pet) {
        hiddenHomePetIDsRaw = HomeCardVisibility.rawBySettingPet(pet, visible: true, raw: hiddenHomePetIDsRaw)
        promoteHomeCardToFront(id: pet.id)
        seedHomeAvatarData(cardId: pet.id, data: pet.avatarImageData)
        pendingPromotedHomeCardId = pet.id
        rosterPreviewCard = nil
        firstQuickCheckInCompleted = false
        showFirstSuccessCard = true
        expandWalletToCard(id: pet.id)
    }

    private func homeCardsOrderedByPreference(_ base: [FocusCard]) -> [FocusCard] {
        FocusHomeCardDataSource.orderedByPreference(base, homeCardOrderRaw: homeCardOrderRaw)
    }

    private func saveHomeCardOrder(_ cards: [FocusCard]) {
        homeCardOrderRaw = FocusHomeCardDataSource.encodedOrder(for: cards)
        refreshHomeCardSnapshot()
    }

    private func promoteHomeCardToFront(id: UUID) {
        homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: id, currentRaw: homeCardOrderRaw)
        refreshHomeCardSnapshot()
    }

    private func homeCardDisplayCards(from source: [FocusCard]) -> [FocusCard] {
        guard homeCardReorderDragId != nil else { return source }
        return FocusHomeCardDataSource.displayCards(from: source, reorderingCards: homeCardReorderCards)
    }

    private func collapseWalletDragGesture() -> some Gesture {
        DragGesture()
            .onEnded { v in
                guard v.translation.height > 80 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                collapseWalletToHome()
            }
    }

    @ViewBuilder
    private func expandedQuickModules(card: FocusCard) -> some View {
        if card.isReal,
           !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            expandedPetQuickActions(pet: pet)
        } else if card.isReal,
                  card.isHuman,
                  let human = humans.first(where: { $0.id == card.id }) {
            expandedHumanQuickActions(human: human)
        } else {
            legacyExpandedQuickModules(card: card)
        }
    }

    private func expandedPetQuickActions(pet: Pet) -> some View {
        let items = isExpandedQAEditMode
            ? expandedQAEditItems
            : Array(expandedQuickActionItems(for: pet).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: pet.id, data: homeAvatarDataById[pet.id]).image
        let themeHex = pet.safeThemeColorHex

        return ExpandedPetQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            pet: pet,
            items: items,
            avatar: avatar,
            themeHex: themeHex,
            editItems: $expandedQAEditItems,
            draggingItemId: $expandedQADraggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: isExpandedQAEditMode,
            jiggle: expandedQAJiggle,
            shouldReduceWork: shouldReduceWork,
            showFirstSuccessPrompt: false,
            waterManagementLabel: waterManagementLabel,
            onToggleEdit: {
                if isExpandedQAEditMode {
                    exitExpandedQAEditMode(for: pet)
                } else {
                    enterExpandedQAEditMode(for: pet)
                }
            },
            onFirstSuccessFeed: { completeFirstSuccessFeed(for: pet) },
            onFirstSuccessPlay: { completeFirstSuccessPlay(for: pet) },
            onFirstSuccessMoment: { startFirstSuccessMoment(for: pet) },
            showsAttentionDot: { expandedPetQuickShowsAttentionDot($0, pet: pet) },
            countText: { expandedPetQuickCountText($0, pet: pet) },
            isCompleted: { expandedPetQuickCompleted($0, pet: pet) },
            onTap: { runPetQuickMenuPrimary($0, pet: pet) },
            onLongPress: { handleExpandedQuickLongPress($0, pet: pet) },
            onGroomCheckIn: { applyExpandedGroomCheckIn($0, pet: pet) },
            onPottySelect: { applyExpandedPottyCheckIn($0, pet: pet) },
            onHealthSelect: { applyExpandedHealthCheckIn($0, pet: pet) },
            onLimitReached: { showingQuickActionLimitAlert = true }
        )
    }

    private func shouldShowFirstSuccessPrompt(for pet: Pet) -> Bool {
        showFirstSuccessCard && !firstQuickCheckInCompleted && !pet.hasPassedAway
    }

    private func expandedHumanQuickActions(human: Human) -> some View {
        let items = isExpandedQAEditMode
            ? expandedQAEditItems
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: human.id, data: homeAvatarDataById[human.id]).image
        let themeHex = human.safeThemeColorHex

        return ExpandedHumanQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            human: human,
            items: items,
            defaultItems: defaultExpandedHumanQuickActions(for: human),
            avatar: avatar,
            themeHex: themeHex,
            editItems: $expandedQAEditItems,
            draggingItemId: $expandedQADraggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: isExpandedQAEditMode,
            jiggle: expandedQAJiggle,
            shouldReduceWork: shouldReduceWork,
            onToggleEdit: {
                if isExpandedQAEditMode {
                    exitExpandedHumanQAEditMode(for: human)
                } else {
                    enterExpandedHumanQAEditMode(for: human)
                }
            },
            countText: { expandedHumanQuickCountText($0, human: human) },
            privacyIconName: { ExpandedQuickActionLogic.humanPrivacyIconName(for: $0, human: human) },
            privacyIconTint: { ExpandedQuickActionLogic.humanPrivacyIconTint(for: $0, human: human) },
            isPrivacyLocked: { expandedHumanQuickActionIsPrivate($0, human: human) },
            isCompleted: { expandedHumanQuickCompleted($0, human: human) },
            feedbackActionKey: expandedQuickActionPulseKey,
            feedbackToken: expandedQuickActionPulseToken,
            onTap: { runHumanQuickMenuPrimary($0, human: human) },
            onLongPress: { handleExpandedHumanQuickLongPress($0, human: human) },
            onLimitReached: { showingQuickActionLimitAlert = true }
        )
    }

    private func legacyExpandedQuickModules(card: FocusCard) -> some View {
        LegacyExpandedQuickModulesView(
            card: card,
            titleForAction: { ExpandedQuickActionLogic.quickActionTitle($0) },
            onAction: { performExpandedQuickAction($0, for: card) }
        )
    }

    private func presentExpandedQuickActionMenu(_ target: ExpandedQuickActionMenuTarget) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(GoMotion.page) {
            expandedQuickActionMenuTarget = target
        }
    }

    private func dismissExpandedQuickActionMenu() {
        withAnimation(GoMotion.page) {
            expandedQuickActionMenuTarget = nil
        }
    }

    @ViewBuilder
    private func expandedQuickActionMenuOverlay() -> some View {
        if let target = expandedQuickActionMenuTarget {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10), // ui-v4: allow modal scrim
                            Color.black.opacity(colorScheme == .dark ? 0.46 : 0.22)  // ui-v4: allow modal scrim
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .onTapGesture { dismissExpandedQuickActionMenu() }

                    expandedQuickActionMenuPanel(for: target)
                        .padding(.horizontal, 6)
                        .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .bottom)))
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func expandedQuickActionMenuPanel(for target: ExpandedQuickActionMenuTarget) -> some View {
        switch target {
        case .pet(let item, let pet):
            let isSingleUseDone = ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil &&
                expandedPetQuickCompleted(item, pet: pet)
            let options = ExpandedQuickActionMenuPolicy.petOptions(for: item, l: l)
            ExpandedQuickActionMenuPanel(
                icon: WaterQuickActionPolicy.iconOverride(for: item, pet: pet) ?? item.icon,
                title: WaterQuickActionPolicy.titleOverride(for: item, pet: pet, managementLabel: waterManagementLabel) ?? item.label,
                status: expandedPetQuickCountText(item, pet: pet) ?? l.tr(zh: "选择下一步", en: "Choose next step", de: "Nächsten Schritt wählen"),
                accent: Color(hex: item.colorHex),
                isLocked: false,
                lockedText: nil,
                quickTitle: ExpandedQuickActionMenuPolicy.petPrimaryTitle(for: item, pet: pet, isSingleUseDone: isSingleUseDone, hasOptions: !options.isEmpty, l: l),
                detailTitle: ExpandedQuickActionMenuPolicy.petDetailTitle(for: item, l: l),
                isQuickDisabled: isSingleUseDone,
                quickOptions: options,
                onQuick: {
                    dismissExpandedQuickActionMenu()
                    runPetQuickMenuPrimary(item, pet: pet)
                },
                onDetail: {
                    dismissExpandedQuickActionMenu()
                    handleExpandedQuickLongPress(item, pet: pet)
                },
                onOption: { optionId in
                    dismissExpandedQuickActionMenu()
                    runPetQuickMenuOption(optionId, item: item, pet: pet)
                },
                onClose: dismissExpandedQuickActionMenu
            )
        case .human(let item, let human):
            let locked = expandedHumanQuickActionIsPrivate(item, human: human)
            ExpandedQuickActionMenuPanel(
                icon: item.icon,
                title: item.label,
                status: locked
                    ? l.tr(zh: "仅本人可见", en: "Only visible to this member", de: "Nur für dieses Mitglied sichtbar")
                    : (expandedHumanQuickCountText(item, human: human) ?? l.tr(zh: "选择下一步", en: "Choose next step", de: "Nächsten Schritt wählen")),
                accent: Color(hex: item.colorHex),
                isLocked: locked,
                lockedText: l.tr(zh: "切换到该成员账户后才能查看或记录。", en: "Switch to this member account to view or record.", de: "Wechsle zu diesem Mitglied, um zu sehen oder zu erfassen."),
                quickTitle: ExpandedQuickActionMenuPolicy.humanPrimaryTitle(for: item, l: l),
                detailTitle: ExpandedQuickActionMenuPolicy.humanDetailTitle(for: item, l: l),
                isQuickDisabled: false,
                quickOptions: [],
                onQuick: {
                    dismissExpandedQuickActionMenu()
                    runHumanQuickMenuPrimary(item, human: human)
                },
                onDetail: {
                    dismissExpandedQuickActionMenu()
                    handleExpandedHumanQuickLongPress(item, human: human)
                },
                onOption: { _ in },
                onClose: dismissExpandedQuickActionMenu
            )
        }
    }

    private func runPetQuickMenuPrimary(_ item: QuickActionItem, pet: Pet) {
        if !ExpandedQuickActionMenuPolicy.petOptions(for: item, l: l).isEmpty {
            handleExpandedQuickLongPress(item, pet: pet)
            return
        }
        if item.actionType == "medication" {
            openExpandedQuickPetMedicationAdd(for: pet)
            return
        }
        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case .waterManagement, .health, .none:
            handleExpandedQuickLongPress(item, pet: pet)
        default:
            handleExpandedQuickAction(item, pet: pet)
        }
    }

    private func runPetQuickMenuOption(_ optionId: String, item: QuickActionItem, pet: Pet) {
        switch item.actionType {
        case "groom":
            applyExpandedGroomCheckIn(optionId, pet: pet)
        case "potty":
            applyExpandedPottyCheckIn(optionId, pet: pet)
        default:
            break
        }
    }

    private func runHumanQuickMenuPrimary(_ item: QuickActionItem, human: Human) {
        handleExpandedHumanQuickAction(item, human: human)
    }

    @ViewBuilder
    private func walletCardStack(cards: [FocusCard]) -> some View {
        let displayCards = homeCardDisplayCards(from: cards)
        let n = displayCards.count
        let heroId = activeCardId ?? displayCards.first?.id

        GeometryReader { geo in
            // Anchor the stack to the real screen bottom, then convert that
            // global target back into this lower-page GeometryReader's space.
            // This reader starts below the focus module, so using only
            // geo.size.height can push the front card below the visible screen.
            let bottomInset = resolvedSafeAreaBottom(in: geo)
            let collapsedBottomY = FocusWalletLayout.collapsedStackBottomY(containerHeight: geo.size.height, bottomInset: bottomInset)
            let expandedBottomY = FocusWalletLayout.expandedStackBottomY(containerHeight: geo.size.height)
            let heroTopY = resolvedSafeAreaTop(in: geo) + K.expandedCardGlobalTopOffset - geo.frame(in: .global).minY

            ZStack(alignment: .topLeading) {
                ForEach(Array(displayCards.enumerated()), id: \.element.id) { idx, card in
                    let isHero = isExpanded && card.id == heroId
                    let visibleHeight = isHero ? K.expandedCardH : K.cardH
                    let offsetY = isExpanded
                    ? FocusWalletLayout.offsetY(
                        idx: idx,
                        n: n,
                        bottomY: expandedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                        cards: displayCards,
                        isExpanded: true
                    )
                    : FocusWalletLayout.offsetY(
                        idx: idx,
                        n: n,
                        bottomY: collapsedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                        cards: displayCards,
                        isExpanded: false
                    )

                    walletCardStackItem(
                        card: card,
                        idx: idx,
                        n: n,
                        isHero: isHero,
                        visibleHeight: visibleHeight,
                        offsetY: offsetY,
                        collapsedBottomY: collapsedBottomY,
                        heroId: heroId,
                        cards: displayCards
                    )
                }

                if isExpanded,
                   expandedQuickModulesReady,
                   let activeCard = displayCards.first(where: { $0.id == heroId }) {
                    expandedQuickModules(card: activeCard)
                        .frame(width: geo.size.width, height: expandedQuickModuleHeight(for: activeCard))
                        .offset(y: heroTopY + K.expandedCardH + K.expandedQuickModuleGap)
                        .zIndex(Double(n + 80))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .simultaneousGesture(collapseWalletDragGesture())
                        .animation(walletAnimation, value: activeCardId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .animation(walletAnimation, value: isExpanded)
            .animation(walletAnimation, value: activeCardId)
            // Swipe-down anywhere collapses hero back to fan
            .gesture(
                DragGesture()
                    .onEnded { v in
                        guard isExpanded, v.translation.height > 80 else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        collapseWalletToHome()
                    }
            )
            .onAppear {
                if activeCardId == nil || !displayCards.contains(where: { $0.id == activeCardId }) {
                    activeCardId = displayCards.first?.id
                }
            }
            .onChange(of: displayCards.map(\.id)) { _, ids in
                if let dragging = homeCardReorderDragId, !ids.contains(dragging) {
                    resetHomeCardReorderState()
                } else if let candidate = homeCardPressCandidateId, !ids.contains(candidate) {
                    cancelHomeCardPressCandidate()
                }
                if let pendingPromotedHomeCardId,
                   ids.contains(pendingPromotedHomeCardId) {
                    activeCardId = pendingPromotedHomeCardId
                    self.pendingPromotedHomeCardId = nil
                    return
                }
                guard activeCardId == nil || !ids.contains(activeCardId!) else { return }
                activeCardId = ids.first
            }
        }
    }

    @ViewBuilder
    private func collapsedWalletCards(
        cards: [FocusCard],
        n: Int,
        heroId: UUID?,
        bottomY: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                walletCardStackItem(
                    card: card,
                    idx: idx,
                    n: n,
                    isHero: false,
                    visibleHeight: K.cardH,
                    offsetY: FocusWalletLayout.offsetY(
                        idx: idx,
                        n: n,
                        bottomY: bottomY,
                        heroId: heroId,
                        heroTopY: 0,
                        cards: cards,
                        isExpanded: false
                    ),
                    collapsedBottomY: bottomY,
                    heroId: heroId,
                    cards: cards
                )
            }
        }
    }

    private func homeCardCollapsedInteractionGesture(
        card: FocusCard,
        cards: [FocusCard],
        currentOffsetY: CGFloat,
        collapsedBottomY: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { drag in
                guard homeCardReorderEnabled, !isExpanded else { return }
                guard homeCardReorderDragId == card.id else { return }

                updateHomeCardReorder(
                    cardId: card.id,
                    cards: cards,
                    dragTranslationY: drag.translation.height,
                    collapsedBottomY: collapsedBottomY
                )
            }
            .onEnded { drag in
                guard homeCardReorderEnabled else { return }
                guard !isExpanded else {
                    if homeCardReorderDragId == card.id || homeCardPressCandidateId == card.id || homeCardReorderCards != nil || homeCardReorderModeActive {
                        resetHomeCardReorderState()
                    }
                    return
                }
                guard homeCardReorderDragId == card.id else { return }
                updateHomeCardReorder(
                    cardId: card.id,
                    cards: cards,
                    dragTranslationY: drag.translation.height,
                    collapsedBottomY: collapsedBottomY
                )
                commitHomeCardReorder()
                resetHomeCardReorderState()
            }
    }

    private func homeCardDragDistance(_ translation: CGSize) -> CGFloat {
        max(abs(translation.width), abs(translation.height))
    }

    private func updateHomeCardReorder(
        cardId: UUID,
        cards: [FocusCard],
        dragTranslationY: CGFloat,
        collapsedBottomY: CGFloat
    ) {
        guard let update = FocusHomeReorderPolicy.update(
            cardId: cardId,
            sourceCards: cards,
            currentCards: homeCardReorderCards,
            startOffsetY: homeCardReorderStartOffsetY,
            dragTranslationY: dragTranslationY,
            collapsedBottomY: collapsedBottomY
        ) else { return }

        if update.didMove {
            withAnimation(walletAnimation) {
                homeCardReorderCards = update.cards
            }
            homeCardReorderDidMove = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        var dragTransaction = Transaction(animation: .linear(duration: 0.045))
        dragTransaction.disablesAnimations = false
        withTransaction(dragTransaction) {
            homeCardReorderDragOffset = update.dragOffset
        }
    }

    private func commitHomeCardReorder() {
        guard let reorderedCards = homeCardReorderCards else { return }
        saveHomeCardOrder(reorderedCards)
    }

    private func resetHomeCardReorderState() {
        let didReorder = homeCardReorderDidMove
        homeCardReorderSession += 1
        homeCardPressCandidateId = nil
        homeCardReorderDragId = nil
        homeCardReorderDragOffset = 0
        homeCardReorderStartOffsetY = 0
        homeCardReorderCards = nil
        homeCardReorderDidMove = false
        homeCardReorderModeActive = false
        suppressNextHomeCardTap = false
        if didReorder {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    private func enterHomeCardReorderMode() {
        guard homeCardReorderEnabled, !isExpanded, visibleHomeCards.count > 1 else { return }
        guard !homeCardReorderModeActive else { return }
        withAnimation(GoMotion.feedback) {
            homeCardReorderModeActive = true
            fabExpanded = false
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func beginHomeCardPressCandidate(card: FocusCard, cards: [FocusCard], currentOffsetY: CGFloat) {
        guard cards.count > 1 else { return }
        homeCardReorderSession += 1
        let session = homeCardReorderSession
        homeCardPressCandidateId = card.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard homeCardReorderSession == session,
                  homeCardPressCandidateId == card.id,
                  homeCardReorderDragId == nil,
                  !isExpanded else { return }
            homeCardPressCandidateId = nil
            enterHomeCardReorderMode()
            beginHomeCardReorder(card: card, cards: cards, currentOffsetY: currentOffsetY)
        }
    }

    private func cancelHomeCardPressCandidate() {
        guard homeCardPressCandidateId != nil else { return }
        homeCardReorderSession += 1
        homeCardPressCandidateId = nil
    }

    private func beginHomeCardReorder(card: FocusCard, cards: [FocusCard], currentOffsetY: CGFloat) {
        guard homeCardReorderDragId == nil else { return }
        homeCardReorderDragId = card.id
        homeCardReorderStartOffsetY = currentOffsetY
        homeCardReorderCards = cards
        homeCardReorderDidMove = false
        homeCardReorderSession += 1
        let session = homeCardReorderSession
        withAnimation(walletAnimation) {
            homeCardReorderDragOffset = FocusHomeReorderPolicy.liftY
        }
        fabExpanded = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scheduleHomeCardReorderWatchdog(cardId: card.id, session: session)
    }

    private func scheduleHomeCardReorderWatchdog(cardId: UUID, session: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard homeCardReorderSession == session,
                  homeCardReorderDragId == cardId else { return }
            resetHomeCardReorderState()
        }
    }

    private func startHomeCardReorderFromLongPress(
        card: FocusCard,
        cards: [FocusCard],
        currentOffsetY: CGFloat
    ) {
        guard homeCardReorderEnabled, !isExpanded, cards.count > 1 else { return }
        guard homeCardReorderDragId == nil, !homeCardReorderModeActive else { return }
        suppressNextHomeCardTap = true
        enterHomeCardReorderMode()
        beginHomeCardReorder(card: card, cards: cards, currentOffsetY: currentOffsetY)
    }

    private func walletCardStackItem(
        card: FocusCard,
        idx: Int,
        n: Int,
        isHero: Bool,
        visibleHeight: CGFloat,
        offsetY: CGFloat,
        collapsedBottomY: CGFloat,
        heroId: UUID?,
        cards: [FocusCard]
    ) -> some View {
        let isReorderingCard = homeCardReorderDragId == card.id
        let isTransitioningCard = walletTransitionCardId == card.id
        let isInteractiveWalkCard = isWalkTrackingCard(card: card, isHero: isHero)

        return transformedWalletCard(card: card, isHero: isHero)
            .frame(height: isHero ? K.expandedCardH : K.cardH)
            .frame(height: visibleHeight, alignment: .top)
            .clipped()
            .frame(maxWidth: .infinity)
            .overlay { expandedActionPulseOverlay(for: card.id) }
            .overlay { walkTransformBurstOverlay(for: card.id) }
            .shadow( // ui-v4: allow home card stack depth
                color: .black.opacity(isHero ? 0.24 : (isReorderingCard || isTransitioningCard ? 0.17 : 0.09)),
                radius: isHero ? 22 : (isReorderingCard || isTransitioningCard ? 14 : 7),
                x: 0, y: isHero ? 13 : (isReorderingCard || isTransitioningCard ? 8 : 4)
            )
            .scaleEffect(
                (isHero ? 1.0 : (isExpanded ? 0.97 : 1.0)) *
                (isTransitioningCard && !isExpanded ? 1.012 : 1.0) *
                (isReorderingCard ? 1.015 : 1.0) *
                (expandedActionPulseCardId == card.id ? 1.025 : 1.0),
                anchor: isHero ? .center : .top
            )
            .offset(y: offsetY + (isReorderingCard ? homeCardReorderDragOffset : 0))
            .zIndex(isReorderingCard ? Double(n + 120) : FocusWalletLayout.zIndex(idx: idx, n: n, isHero: isHero, heroId: heroId, cards: cards, isExpanded: isExpanded))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name) 的卡片")
            .accessibilityHint(isHero ? "点击返回首页，长按进入基本信息" :
                              (isExpanded ? "点击返回首页" :
                                (homeCardReorderModeActive ? "拖动调整排序，点击退出排序" : "点击展开查看，长按进入排序")))
            .if(isExpanded && !isHero && homeCardReorderDragId == nil) { view in
                view.contextMenu { cardContextMenu(card: card) }
            }
            .if(isExpanded && !isInteractiveWalkCard) { view in
                view.highPriorityGesture(
                    TapGesture()
                        .onEnded { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                )
            }
            .if(!isExpanded && !isInteractiveWalkCard) { view in
                view.highPriorityGesture(
                    TapGesture()
                        .onEnded { handleWalletCardTap(card: card, n: n, isHero: false) }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in
                            startHomeCardReorderFromLongPress(
                                card: card,
                                cards: cards,
                                currentOffsetY: offsetY
                            )
                        }
                )
                .simultaneousGesture(
                    homeCardCollapsedInteractionGesture(
                        card: card,
                        cards: cards,
                        currentOffsetY: offsetY,
                        collapsedBottomY: collapsedBottomY
                    )
                )
            }
            .if(isHero && isExpanded && !isInteractiveWalkCard) { view in
                view.onLongPressGesture(minimumDuration: 0.45) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    openWalletCardBasicInfo(card)
                }
            }
            .animation(walletAnimation, value: isExpanded)
            .animation(walletAnimation, value: activeCardId)
            .animation(walletAnimation, value: homeCardReorderDragId)
    }

    // Fan:  tap any card → lift that card to the active position.
    // Hero: tap active card → restore fan; long-press active card → basic info.
    //       Tap any inactive card strip → restore fan.
    //       Swipe-down → restore fan (via DragGesture above).
    private func handleWalletCardTap(card: FocusCard, n: Int, isHero: Bool) {
        let tapStartedAt = CFAbsoluteTimeGetCurrent()

        if homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
            resetHomeCardReorderState()
            return
        }

        if suppressNextHomeCardTap {
            suppressNextHomeCardTap = false
            return
        }

        triggerWalletTapFeedback()

        if n <= 1 {
            if isExpanded {
                collapseWalletToHome()
            } else {
                expandWalletToCard(id: card.id)
            }
            DispatchQueue.main.async {
                AppPerformanceMonitor.shared.record("卡片展开状态提交", startedAt: tapStartedAt, note: card.name)
                AppPerformanceMonitor.shared.record("卡片点击延迟", startedAt: tapStartedAt, note: card.name)
            }
            return
        }

        if isHero {
            collapseWalletToHome()
        } else if isExpanded {
            collapseWalletToHome()
        } else {
            expandWalletToCard(id: card.id)
        }
        DispatchQueue.main.async {
            AppPerformanceMonitor.shared.record("卡片展开状态提交", startedAt: tapStartedAt, note: card.name)
            AppPerformanceMonitor.shared.record("卡片点击延迟", startedAt: tapStartedAt, note: card.name)
        }
    }

    private func expandWalletToCard(id: UUID) {
        if homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
            resetHomeCardReorderState()
        }

        homeAvatarLoadTask?.cancel()
        expandedQuickModulesReady = false
        fabExpanded = false
        cardFabExpanded = false
        cardFabMenuItemsVisible = false
        isExpandedQAEditMode = false

        walletTransitionSession += 1
        let session = walletTransitionSession
        walletTransitionCardId = id

        var selectTransaction = Transaction(animation: nil)
        selectTransaction.disablesAnimations = true
        withTransaction(selectTransaction) {
            activeCardId = id
        }

        withAnimation(walletExpandAnimation) {
            isExpanded = true
        }

        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: shouldReduceWork ? 180 : 560)
            guard walletTransitionSession == session else { return }
            walletTransitionCardId = nil
        }
    }

    private func triggerWalletTapFeedback() {
        walletTapFeedbackGenerator.impactOccurred()
        walletTapFeedbackGenerator.prepare()
    }

    private func collapseWalletToHome() {
        if homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
            resetHomeCardReorderState()
        }
        walletTransitionSession += 1
        let session = walletTransitionSession
        let returningPreviewId = rosterPreviewCard?.id == activeCardId ? rosterPreviewCard?.id : nil
        walletTransitionCardId = activeCardId
        expandedQuickModulesReady = false
        withAnimation(walletCollapseAnimation) {
            isExpanded = false
            fabExpanded = false
            cardFabExpanded = false
            cardFabMenuItemsVisible = false
            isExpandedQAEditMode = false
        }
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: shouldReduceWork ? 180 : 520)
            guard walletTransitionSession == session else { return }
            walletTransitionCardId = nil
            if let returningPreviewId {
                var selectTransaction = Transaction(animation: nil)
                selectTransaction.disablesAnimations = true
                withTransaction(selectTransaction) {
                    activeCardId = visibleHomeCards.first(where: { $0.id != returningPreviewId })?.id
                    rosterPreviewCard = nil
                }
            } else if rosterPreviewCard != nil {
                rosterPreviewCard = nil
            }
        }
    }

    private func openCrewRosterCard(_ card: FocusCard) {
        seedHomeAvatarData(cardId: card.id, data: card.avatarImageData)
        seedHomePopoutData(cardId: card.id, data: card.cardPopoutImageData)
        showingCrewRoster = false
        fabExpanded = false
        isExpandedQAEditMode = false

        if visibleHomeCards.contains(where: { $0.id == card.id }) {
            rosterPreviewCard = nil
        } else {
            rosterPreviewCard = card
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            expandWalletToCard(id: card.id)
        }
    }

    private func seedHomeAvatarData(cardId: UUID, data: Data?) {
        guard let data, !data.isEmpty else { return }
        homeAvatarDataById[cardId] = data
        Task { @MainActor in
            let didRefresh = await FocusWalletAvatarCache.preload(payloads: [
                FocusWalletAvatarCache.Payload(id: cardId, data: data)
            ])
            if didRefresh {
                avatarCacheRevision &+= 1
            }
        }
    }

    private func seedHomePopoutData(cardId: UUID, data: Data?) {
        guard let data, !data.isEmpty else { return }
        homePopoutDataById[cardId] = data
    }

    private func openWalletCardBasicInfo(_ card: FocusCard) {
        fabExpanded = false
        isExpandedQAEditMode = false
        collapseWalletToHome()

        if card.isHuman {
            expandedBasicInfoHuman = humans.first(where: { $0.id == card.id })
            return
        }

        if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            expandedBasicInfoPet = pet
        }
    }

    @ViewBuilder
    private func transformedWalletCard(card: FocusCard, isHero: Bool) -> some View {
        let showWalkCard = isWalkTrackingCard(card: card, isHero: isHero)
        ZStack {
            FocusWalletCardView(
                card: card,
                namespace: ns,
                heroNS: heroNS,
                expandedId: expandedId,
                isHeroExpanded: isHero,
                avatarCacheRevision: avatarCacheRevision
            )
            .opacity(showWalkCard ? 0 : 1)

            if showWalkCard, let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
                WalkTrackingCard(pet: pet)
                    .padding(10)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(HeroAnim.walletSpring, value: showWalkCard)
    }

    private func isWalkTrackingCard(card: FocusCard, isHero: Bool) -> Bool {
        guard isHero,
              !card.isHuman,
              PetWalkingManager.shared.currentPet?.id == card.id
        else { return false }

        switch PetWalkingManager.shared.phase {
        case .running, .paused, .finished:
            return true
        case .idle:
            return false
        }
    }

    @ViewBuilder
    private func expandedActionPulseOverlay(for cardId: UUID) -> some View {
        if expandedActionPulseCardId == cardId {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.88), lineWidth: 2)
                .shadow(color: Color.goPrimary.opacity(0.45), radius: 18, y: 0) // ui-v4: allow quick-action success pulse
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
        }
    }

    @ViewBuilder
    private func walkTransformBurstOverlay(for cardId: UUID) -> some View {
        if walkTransformBurstCardId == cardId {
            WalkLaunchBurst()
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func triggerExpandedActionFeedback(
        cardId: UUID,
        coconutDelta: Int = 0,
        label: String? = nil,
        actionKey: String? = nil
    ) {
        withAnimation(HeroAnim.buttonSpring) {
            expandedActionPulseCardId = cardId
            if let actionKey {
                expandedQuickActionPulseKey = actionKey
                expandedQuickActionPulseToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: .goPrimary)
            }
        }
        if coconutDelta > 0 {
            markFirstQuickCheckInCompletedIfNeeded()
            expandedCoconutRewardAmount = coconutDelta
            expandedCoconutRewardLabel = label
            showExpandedCoconutReward = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            guard expandedActionPulseCardId == cardId else { return }
            withAnimation(GoMotion.quick) {
                expandedActionPulseCardId = nil
                if let actionKey, expandedQuickActionPulseKey == actionKey {
                    expandedQuickActionPulseKey = nil
                    expandedQuickActionPulseToken = nil
                }
            }
        }
    }

    private func prepareFirstSuccessPet(_ pet: Pet) {
        expandWalletToCard(id: pet.id)
    }

    private func completeFirstSuccessFeed(for pet: Pet) {
        prepareFirstSuccessPet(pet)
        applyExpandedQuickAction("feed", pet: pet)
    }

    private func completeFirstSuccessPlay(for pet: Pet) {
        prepareFirstSuccessPet(pet)
        applyExpandedQuickAction("play", pet: pet)
    }

    private func startFirstSuccessMoment(for pet: Pet) {
        prepareFirstSuccessPet(pet)
        pendingFirstSuccessMomentPetId = pet.id
        firstSuccessMomentCoconutBefore = QuestManager.shared.coconutCount
        expandedQuickMomentPet = pet
    }

    private func completeFirstSuccessMomentIfNeeded(for pet: Pet) {
        guard pendingFirstSuccessMomentPetId == pet.id else { return }
        let before = firstSuccessMomentCoconutBefore ?? QuestManager.shared.coconutCount
        let coconutDelta = max(0, QuestManager.shared.coconutCount - before)
        pendingFirstSuccessMomentPetId = nil
        firstSuccessMomentCoconutBefore = nil
        triggerExpandedActionFeedback(
            cardId: pet.id,
            coconutDelta: coconutDelta,
            label: coconutDelta > 0 ? "照片记录 +\(coconutDelta)🥥" : nil
        )
        markFirstQuickCheckInCompletedIfNeeded()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func markFirstQuickCheckInCompletedIfNeeded() {
        guard showFirstSuccessCard, !firstQuickCheckInCompleted else { return }
        firstQuickCheckInCompleted = true
        withAnimation(HeroAnim.buttonSpring) {
            showFirstSuccessCard = false
        }
    }

    private func triggerWalkCardTransform(for pet: Pet) {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = true
        expandWalletToCard(id: pet.id)
        withAnimation(HeroAnim.fabSpring) {
            walkTransformBurstCardId = pet.id
            expandedActionPulseCardId = pet.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard walkTransformBurstCardId == pet.id else { return }
            withAnimation(GoMotion.quick) {
                walkTransformBurstCardId = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            guard expandedActionPulseCardId == pet.id else { return }
            withAnimation(GoMotion.quick) {
                expandedActionPulseCardId = nil
            }
        }
    }

    private func syncWalkCardSurfaceVisibility() {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = isWalkCardExpandedSurfaceVisible
    }

    private var savedQuickActionItems: [QuickActionItem] {
        guard !quickActionItemsJSON.isEmpty,
              let data = quickActionItemsJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return [] }
        return items
    }

    private func expandedQuickActionItems(for pet: Pet) -> [QuickActionItem] {
        let stored = savedQuickActionItems.filter { $0.petId == pet.id && $0.entityKind != .human }
        let items = (stored.isEmpty ? defaultExpandedQuickActions(for: pet) : stored)
            .filter { $0.actionType != "litterChange" }
        return WaterQuickActionPolicy.normalizedItems(
            items,
            for: pet,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
    }

    private func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        let stored = savedQuickActionItems.filter {
            $0.entityId == human.id &&
            $0.entityKind == .human &&
            $0.actionType != "humanAllFeatures"
        }
        return stored.isEmpty ? defaultExpandedHumanQuickActions(for: human) : stored
    }

    private func enterExpandedQAEditMode(for pet: Pet) {
        expandedQAEditItems = expandedQuickActionItems(for: pet)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) {
                expandedQAJiggle = true
            }
        }
    }

    private func exitExpandedQAEditMode(for pet: Pet) {
        saveExpandedQAEditItems(expandedQAEditItems, for: pet)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = false
        }
        withAnimation(nil) {
            expandedQAJiggle = false
        }
    }

    private func saveExpandedQAEditItems(_ edited: [QuickActionItem], for pet: Pet) {
        var saved = savedQuickActionItems
        let currentPetItemIds = Set(expandedQuickActionItems(for: pet).map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentPetItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { $0.petId == pet.id && $0.entityKind != .human }
        let cleaned = edited.filter { $0.actionType != "litterChange" }
        saved.insert(contentsOf: Array(cleaned.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func enterExpandedHumanQAEditMode(for human: Human) {
        expandedQAEditItems = expandedHumanQuickActionItems(for: human)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) {
                expandedQAJiggle = true
            }
        }
    }

    private func exitExpandedHumanQAEditMode(for human: Human) {
        saveExpandedHumanQAEditItems(expandedQAEditItems, for: human)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = false
        }
        withAnimation(nil) {
            expandedQAJiggle = false
        }
    }

    private func saveExpandedHumanQAEditItems(_ edited: [QuickActionItem], for human: Human) {
        var saved = savedQuickActionItems
        let currentItemIds = Set(expandedHumanQuickActionItems(for: human).map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { $0.entityId == human.id && $0.entityKind == .human }
        let cleaned = edited.filter { $0.actionType != "humanAllFeatures" }
        saved.insert(contentsOf: Array(cleaned.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func defaultExpandedQuickActions(for pet: Pet) -> [QuickActionItem] {
        ExpandedQuickActionDefaults.items(
            for: pet,
            localization: l,
            waterManagementLabel: waterManagementLabel
        )
    }

    private func defaultExpandedHumanQuickActions(for human: Human) -> [QuickActionItem] {
        ExpandedQuickActionDefaults.humanItems(for: human, localization: l)
    }

    private func handleExpandedHumanQuickAction(_ item: QuickActionItem, human: Human) {
        handleExpandedHumanRoute(ExpandedQuickActionLogic.humanTapRoute(
            actionType: item.actionType,
            isLocked: expandedHumanQuickActionIsPrivate(item, human: human)
        ), human: human)
    }

    private func handleExpandedHumanQuickLongPress(_ item: QuickActionItem, human: Human) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        handleExpandedHumanRoute(ExpandedQuickActionLogic.humanLongPressRoute(
            actionType: item.actionType,
            isLocked: expandedHumanQuickActionIsPrivate(item, human: human)
        ), human: human)
    }

    private func handleExpandedHumanRoute(_ route: ExpandedHumanQuickRoute, human: Human) {
        switch route {
        case .privacyAlert:
            showingHumanPrivacyAlert = true
        case .weightQuick:
            openExpandedQuickHumanWeight(for: human, actionType: "humanWeight")
        case .workoutQuick:
            openExpandedQuickHumanWorkout(for: human, actionType: "humanWorkout")
        case .medicationAdd:
            openExpandedQuickHumanMedication(for: human, actionType: "humanMedication")
        case .noteQuick:
            openExpandedQuickHumanNote(for: human, actionType: "humanNote")
        case .expenseQuick:
            openExpandedQuickHumanExpense(for: human, actionType: "humanExpense")
        case .weightDetail:
            expandedHumanWeightDetail = human
        case .workoutDetail:
            expandedHumanWorkoutDetail = human
        case .medicationDetail:
            expandedQuickHumanMedication = human
        case .noteDetail:
            expandedHumanNoteDetail = human
        case .expenseDetail:
            expandedHumanExpenseDetail = human
        case .allFeatures:
            expandedAllFeaturesHuman = human
        case .selectHuman:
            selectedHuman = human
        case .none:
            break
        }
    }

    private func shouldBlockSingleUseAction(_ actionType: String, pet: Pet) -> Bool {
        guard let label = ExpandedQuickActionLogic.singleUseLabel(for: actionType),
              expandedPetQuickCompleted(
                QuickActionItem(label: "", icon: "", colorHex: "", petId: pet.id, actionType: actionType),
                pet: pet
              )
        else { return false }

        singleUseNoticeTitle = "今天已经完成了"
        singleUseNoticeMessage = "\(pet.name) 今天已经\(label)过了，这类操作一天记录一次就够了。需要修改记录的话，可以进入详情页处理。"
        showingSingleUseNotice = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        return true
    }

    private func handleExpandedQuickAction(_ item: QuickActionItem, pet: Pet) {
        if shouldBlockSingleUseAction(item.actionType, pet: pet) { return }

        handleExpandedPetTapRoute(ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet), pet: pet)
    }

    private func handleExpandedPetTapRoute(_ route: ExpandedPetQuickTapRoute, pet: Pet) {
        switch route {
        case .perform(let actionType):
            applyExpandedQuickAction(actionType, pet: pet)
        case .waterManagement:
            openExpandedWaterManagement(for: pet)
        case .weight:
            openExpandedQuickWeight(for: pet)
        case .expense:
            openExpandedQuickExpense(for: pet)
        case .moment:
            expandedQuickMomentPet = pet
        case .health:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
        case .none:
            break
        }
    }

    private func openExpandedFeedDetail(for pet: Pet, opensManualSheet: Bool = false) {
        expandedQuickFeedOpensManualSheet = opensManualSheet
        expandedQuickFeedDetailPet = pet
    }

    private func handleExpandedQuickLongPress(_ item: QuickActionItem, pet: Pet) {
        switch ExpandedQuickActionLogic.petLongPressRoute(for: item) {
        case .feedDetail:
            openExpandedFeedDetail(for: pet)
        case .waterManagement:
            openExpandedWaterManagement(for: pet)
        case .walk:
            expandedQuickWalkPet = pet
        case .playDetail:
            expandedQuickPlayDetailPet = pet
        case .pottyDetail:
            expandedQuickPottyDetailPet = pet
        case .hygiene:
            expandedQuickHygienePet = pet
        case .health:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
        case .medication:
            expandedQuickPetMedicationPet = pet
        case .weightDetail:
            expandedQuickWeightDetailPet = pet
        case .expenseDetail:
            expandedQuickExpenseDetailPet = pet
        case .momentHistory:
            expandedMomentHistoryPet = pet
        case .none:
            break
        }
    }

    private func expandedPendingFeedReminderForPlannedMode(pet: Pet) -> Reminder? {
        ExpandedQuickActionLogic.pendingFeedReminder(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    private func expandedPetQuickShowsAttentionDot(_ item: QuickActionItem, pet: Pet) -> Bool {
        ExpandedQuickActionLogic.showsAttentionDot(item: item, pet: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    private func expandedPetQuickCompleted(_ item: QuickActionItem, pet: Pet) -> Bool {
        ExpandedQuickActionLogic.isCompleted(item: item, pet: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    private func expandedPetQuickCountText(_ item: QuickActionItem, pet: Pet) -> String? {
        ExpandedQuickActionLogic.countText(item: item, pet: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    @discardableResult
    private func completeExpandedPlannedFeedFromHome(pet: Pet) -> Bool {
        guard let reminder = expandedPendingFeedReminderForPlannedMode(pet: pet) else { return false }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let coconutBefore = QuestManager.shared.coconutCount
        _ = CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: modelContext,
            quality: .precise,
            executorId: executorId
        )
        let coconutDelta = max(0, QuestManager.shared.coconutCount - coconutBefore)
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: coconutDelta, label: coconutDelta > 0 ? "喂食 +\(coconutDelta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func performExpandedFeedCheckIn(pet: Pet, executorId: String?) {
        let performFeed = {
            let dashboard = self.expandedFeedDashboard(for: pet)
            switch dashboard.operatingMode {
            case .manual:
                let amount = pet.dailyPortionGrams
                guard amount > 0 else {
                    self.openExpandedFeedDetail(for: pet, opensManualSheet: true)
                    return
                }
                let coconutBefore = QuestManager.shared.coconutCount
                _ = CareEventService.recordManualFeed(
                    pet: pet,
                    amountGrams: amount,
                    context: self.modelContext,
                    executorId: executorId,
                    foodKind: pet.mainFoodKind
                )
                let coconutDelta = max(0, QuestManager.shared.coconutCount - coconutBefore)
                self.triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: coconutDelta, label: coconutDelta > 0 ? "喂食 +\(coconutDelta)🥥" : nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .manualReminder:
                if self.completeExpandedPlannedFeedFromHome(pet: pet) { return }
                self.openExpandedFeedDetail(for: pet)
            case .autoFeeder:
                self.openExpandedFeedDetail(for: pet)
                return
            }
        }

        let dashboard = expandedFeedDashboard(for: pet)
        let willWriteFeedLog = (dashboard.operatingMode == .manual && pet.dailyPortionGrams > 0) ||
            (dashboard.operatingMode == .manualReminder && dashboard.nextManualReminder != nil)
        if willWriteFeedLog, let warning = AntiRepeatCareManager.checkRecentCareLog(
            for: pet,
            type: .feeding,
            thresholdMinutes: 120,
            currentUserId: executorId,
            in: humans
        ) {
            antiRepeatTitle = l.homeAntiDupFeedTitle
            antiRepeatMessage = l.homeAntiDupFeedMessage(
                executor: warning.executorName,
                minutes: warning.minutesAgo,
                petName: pet.name
            )
            pendingRepeatAction = performFeed
            showingAntiRepeatAlert = true
        } else {
            performFeed()
        }
    }

    private func expandedFeedDashboard(for pet: Pet) -> FeedingDashboardState {
        ExpandedQuickActionLogic.feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    private func expandedWaterRuleState(for pet: Pet) -> WaterRuleState {
        ExpandedQuickActionLogic.waterRuleState(for: pet, allEvents: allEvents)
    }

    private func expandedDefaultWaterAmountMl(for pet: Pet) -> Double? {
        ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet)
    }

    private func completeExpandedPlannedWaterFromHome(pet: Pet) -> Bool {
        let state = expandedWaterRuleState(for: pet)
        guard let reminder = state.nextPendingReminder else { return false }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let reward = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: expandedDefaultWaterAmountMl(for: pet) ?? 0,
            context: modelContext,
            executorId: executorId
        )
        let delta = (reward?.humanGot ?? 0) + (reward?.petGot ?? 0)
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func performExpandedWaterCheckIn(pet: Pet, executorId: String?) {
        guard !WaterQuickActionPolicy.isAquatic(species: pet.species) else {
            openExpandedWaterManagement(for: pet)
            return
        }

        let state = expandedWaterRuleState(for: pet)
        if state.operatingMode == .reminder {
            if completeExpandedPlannedWaterFromHome(pet: pet) { return }
            openExpandedWaterManagement(for: pet)
            return
        }

        let got = CareEventService.recordCare(
            pet: pet,
            type: .watering,
            amountMl: expandedDefaultWaterAmountMl(for: pet) ?? 0,
            context: modelContext,
            executorId: executorId,
            reward: .water
        )
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func performExpandedMedicationCheckIn(pet: Pet) {
        let activeMeds = pet.medications.filter(\.isActiveToday)
        guard !activeMeds.isEmpty else {
            expandedQuickPetMedicationPet = pet
            return
        }

        let targetMedication = activeMeds.first { med in
            let required = PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
            guard required > 0 else { return false }
            let done = PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: med.id)
            return done < required
        } ?? activeMeds.first(where: { PetMedicationDoseLogging.requiredDoses(on: Date(), for: $0) == 0 })

        guard let medication = targetMedication else {
            expandedQuickPetMedicationPet = pet
            return
        }

        PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true
        )
        MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: 1, label: "用药 +1🥥")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyExpandedQuickAction(_ actionType: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }

        switch actionType {
        case "feed":
            performExpandedFeedCheckIn(pet: pet, executorId: executorId)
        case "water":
            performExpandedWaterCheckIn(pet: pet, executorId: executorId)
        case "walk":
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
            }
            triggerWalkCardTransform(for: pet)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "litter":
            let got = CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: executorId, reward: .potty(isLitter: true))
            let delta = got.humanGot + got.petGot
            triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "铲屎 +\(delta)🥥" : nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "play":
            performExpandedSpecialCare(.play, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "medication":
            performExpandedMedicationCheckIn(pet: pet)
        case "waterChange", "filterClean":
            openExpandedWaterManagement(for: pet)
        case "cageCleaning":
            performExpandedSpecialCare(.cageCleaning, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "freeFlight":
            performExpandedSpecialCare(.freeFlight, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "misting":
            performExpandedSpecialCare(.misting, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "substrateChange":
            performExpandedSpecialCare(.substrateChange, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            break
        }
    }

    private func applyExpandedGroomCheckIn(_ raw: String, pet: Pet) {
        let type: HygieneType
        switch raw {
        case "bath": type = .bath
        case "teeth": type = .teeth
        case "nails": type = .nails
        case "brushing": type = .brushing
        case "ears": type = .ears
        default: return
        }
        guard !pet.hygieneLogs.contains(where: { $0.type == type.rawValue && Calendar.current.isDateInToday($0.date) }) else {
            singleUseNoticeTitle = "今天已经完成了"
            singleUseNoticeMessage = "\(pet.name) 今天已经记录过\(type.rawValue)了，这类护理一天记录一次就够了。"
            showingSingleUseNotice = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet, executorId: executorId)
        modelContext.insert(log)
        modelContext.safeSave()
        let got = QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
        QuickActionReminderCompletionSyncService.completeNearestPetHygieneReminder(
            pet: pet,
            type: type,
            context: modelContext,
            executorId: executorId
        )
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyExpandedPottyCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let type = PottyType(rawValue: raw) ?? .perfectPoop
        let got = CareEventService.recordPotty(pet: pet, type: type, context: modelContext, executorId: executorId)
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyExpandedHealthCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        switch raw {
        case "vaccine":
            modelContext.insert(PetHealthLog(date: Date(), type: .vaccine, note: "快捷打卡", pet: pet, executorId: executorId))
        case "deworming":
            modelContext.insert(PetHealthLog(date: Date(), type: .dewormingExternal, note: "快捷打卡", pet: pet, executorId: executorId))
        case "visit":
            modelContext.insert(PetHealthLog(date: Date(), type: .checkup, note: "快捷打卡", pet: pet, executorId: executorId))
        default:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
            return
        }
        modelContext.safeSave()
        let reward = QuestManager.shared.awardAction(type: .health, pet: pet, context: modelContext)
        let delta = reward.humanGot + reward.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "💉 +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var waterManagementLabel: String {
        l.tr(zh: "水管理", en: "Water", de: "Wasser")
    }

    private func openExpandedWaterManagement(for pet: Pet) {
        expandedQuickWaterDetailPet = pet
    }

    private func expandedHumanQuickCompleted(_ item: QuickActionItem, human: Human) -> Bool {
        let humanId = human.id.uuidString
        return ExpandedQuickActionLogic.humanCompleted(
            item: item,
            human: human,
            isLocked: expandedHumanQuickActionIsPrivate(item, human: human),
            todayMedicationLogs: fetchTodayMedicationLogs(for: humanId)
        )
    }

    private func expandedHumanQuickCountText(_ item: QuickActionItem, human: Human) -> String? {
        let humanId = human.id.uuidString
        return ExpandedQuickActionLogic.humanCountText(
            item: item,
            human: human,
            isLocked: expandedHumanQuickActionIsPrivate(item, human: human),
            activeMedications: fetchActiveMedications(for: humanId),
            todayMedicationLogs: fetchTodayMedicationLogs(for: humanId),
            expenses: item.actionType == "humanExpense" ? fetchRecentHumanExpenses(for: humanId) : []
        )
    }

    private func fetchActiveMedications(for humanId: String) -> [HumanMedication] {
        Array(activeHumanMedications.lazy.filter { $0.humanId == humanId }.prefix(24))
    }

    private func fetchTodayMedicationLogs(for humanId: String) -> [HumanMedicationLog] {
        Array(todayHumanMedicationLogs.lazy.filter { $0.humanId == humanId }.prefix(48))
    }

    private func fetchRecentHumanExpenses(for humanId: String) -> [PetExpenseLog] {
        Array(recentHumanExpenseLogs.lazy.filter { $0.executorId == humanId }.prefix(80))
    }

    private func expandedHumanQuickActionIsPrivate(_ item: QuickActionItem, human: Human) -> Bool {
        PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: activeHumanId)
    }

    private func performExpandedQuickAction(_ action: FocusCard.Action, for card: FocusCard) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway })
        switch ExpandedQuickActionLogic.legacyRoute(action: action, card: card, pet: pet) {
        case .selectHuman:
            selectedHuman = humans.first(where: { $0.id == card.id })
        case .none:
            return
        case .recordFeed:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetCareLog(
                date: Date(),
                type: .feeding,
                amountGrams: pet.dailyPortionGrams,
                note: PetCareLog.manualFeedNoteMarker,
                pet: pet,
                executorId: executorId
            )
            modelContext.insert(log)
            QuestManager.shared.recordFirstMeal()
            QuestManager.shared.awardAction(type: .feed, pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                pet: pet,
                type: .feeding,
                context: modelContext,
                executorId: executorId
            )
        case .recordWater:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetCareLog(
                date: Date(),
                type: .watering,
                amountMl: 250,
                pet: pet,
                executorId: executorId
            )
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .water, pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                pet: pet,
                type: .watering,
                context: modelContext,
                executorId: executorId
            )
        case .startWalk:
            guard let pet else { return }
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
            }
            triggerWalkCardTransform(for: pet)
        case .recordPotty:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetPottyReminder(
                pet: pet,
                context: modelContext,
                executorId: executorId
            )
        case .recordLitter:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetCareLog(date: Date(), type: .litter, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                pet: pet,
                type: .litter,
                context: modelContext,
                executorId: executorId
            )
        case .specialCare(let type):
            guard let pet else { return }
            performExpandedSpecialCare(type, pet: pet, executorId: currentExecutorId())
        case .waterManagement:
            guard let pet else { return }
            openExpandedWaterManagement(for: pet)
        case .selectPetOverview:
            guard let pet else { return }
            selectedPetTab = .overview
            selectedPet = pet
        }
    }

    private func currentExecutorId() -> String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func performExpandedSpecialCare(_ type: CareType, pet: Pet, executorId: String?) {
        let reward: QuestManager.OhanaActionType
        switch type {
        case .play:
            reward = .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            reward = .general(humanReward: 25, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            reward = .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理鸟笼奖励")
        case .freeFlight:
            reward = .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            reward = .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 保湿打卡奖励")
        case .substrateChange:
            reward = .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 环境清洁奖励")
        default:
            reward = .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 打卡奖励")
        }
        let got = CareEventService.recordCare(pet: pet, type: type, context: modelContext, executorId: executorId, reward: reward)
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
    }

    private func completeQuestInFocusStack(_ quest: IslandQuest) {
        let activePets = pets.filter { !$0.hasPassedAway }

        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            switch quest.id {
            case IslandQuestEngine.oasisPetWizardQuestId:
                presentAddEntity(initialType: humans.isEmpty ? .human : .pet)
            case IslandQuestEngine.oasisFirstMealQuestId:
                if let pet = activePets.first {
                    openTodayFocusPetShortcut("feed", pet: pet)
                } else {
                    presentAddEntity(initialType: .pet)
                }
            case IslandQuestEngine.oasisThemeQuestId:
                showingOasisReward = true
            default:
                showingOasisReward = true
            }
        } else if quest.id.hasPrefix("q_feed_") {
            if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                openTodayFocusPetShortcut("feed", pet: p)
            }
        } else if quest.id.hasPrefix("q_water_") && !quest.id.hasPrefix("q_water_plant") {
            if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                openTodayFocusPetShortcut("water", pet: p)
            }
        } else {
            switch quest.id {
            case "q_walk":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    openTodayFocusWalk(pet: p)
                }
            case "q_potty":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    let actionType = (p.species.contains("猫") || p.species.contains("兔")) ? "litter" : "potty"
                    openTodayFocusPetShortcut(actionType, pet: p)
                }
            case let id where id.hasPrefix("q_play_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    openTodayFocusPetShortcut("play", pet: p)
                }
            case let id where id.hasPrefix("q_weight_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    focusTodayPetCard(p)
                    openExpandedQuickWeight(for: p)
                }
            case let id where IslandQuestEngine.humanWeightId(fromQuestId: id) != nil:
                if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: id),
                   let human = humans.first(where: { $0.id == humanId }) {
                    openTodayFocusHumanWeight(human)
                }
            case let id where id.hasPrefix("q_moment_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    focusTodayPetCard(p)
                    expandedQuickMomentPet = p
                }
            case "q_water_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                    selectedPlant = pl
                }
            case "q_fertilize_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                    selectedPlant = pl
                }
            case "q_reminder":
                openGlobalCalendar()
            case "q_visit":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    selectedPetTab = .overview
                    selectedPet = p
                } else if let p = activePets.first {
                    selectedPetTab = .overview
                    selectedPet = p
                }
            default:
                if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
                   let event = allEvents.first(where: { $0.id == eventId }) {
                    openTodayFocusEvent(event)
                } else if let mid = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
                    for p in activePets {
                        if let medication = p.medications.first(where: { $0.id == mid }) {
                            PetMedicationDoseLogging.recordDose(
                                medication: medication,
                                pet: p,
                                modelContext: modelContext,
                                awardCoconut: true
                            )
                            MedicationReminderService.shared.scheduleMedicationReminders(for: p, context: modelContext)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            triggerExpandedActionFeedback(cardId: p.id, coconutDelta: 1, label: "💊 +1🥥")
                            break
                        }
                    }
                }
            }
        }
    }

    private func focusTodayPetCard(_ pet: Pet) {
        fabExpanded = false
        isExpandedQAEditMode = false
        expandWalletToCard(id: pet.id)
    }

    private func openFamilyTaskFromTodayFocus(_ task: FamilyCollaborationTask) {
        if let petId = task.relatedPetId,
           let petUUID = UUID(uuidString: petId),
           let pet = pets.first(where: { $0.id == petUUID && !$0.hasPassedAway }) {
            focusTodayPetCard(pet)
            if let eventId = task.relatedEventId,
               let eventUUID = UUID(uuidString: eventId),
               let event = allEvents.first(where: { $0.id == eventUUID }) {
                openTodayFocusEvent(event)
                return
            }
            selectedPetTab = .overview
            selectedPet = pet
            return
        }

        showingCrewRoster = true
    }

    private func openTodayFocusHealth(pet: Pet, section: PetHealthInitialSection = .preventive) {
        focusTodayPetCard(pet)
        expandedQuickHealthInitialSection = section
        expandedQuickHealthPet = pet
    }

    private func openTodayFocusPetShortcut(_ actionType: String, pet: Pet) {
        focusTodayPetCard(pet)
        openExpandedPetShortcut(actionType, pet: pet)
    }

    private func openTodayFocusHumanWeight(_ human: Human) {
        guard !PrivacyService.isLocked(.weight, for: human, viewedBy: activeHumanId) else {
            showingHumanPrivacyAlert = true
            return
        }
        if visibleHomeCards.contains(where: { $0.id == human.id }) {
            fabExpanded = false
            isExpandedQAEditMode = false
            expandWalletToCard(id: human.id)
        }
        openExpandedQuickHumanWeight(for: human)
    }

    private func openTodayFocusWalk(pet: Pet) {
        switch PetWalkingManager.shared.phase {
        case .idle:
            todayFocusWalkPet = pet
        case .running, .paused, .finished:
            if PetWalkingManager.shared.currentPet?.id == pet.id {
                todayFocusWalkPet = pet
            } else {
                focusTodayPetCard(pet)
                expandedQuickWalkPet = pet
            }
        }
    }

    private func openTodayFocusEvent(_ event: Event) {
        if routeTodayFocusEventToFeature(event) {
            return
        }
        calendarEntityFilterId = event.relatedEntityId
        calendarHumanFilterId = nil
        showingCalendar = true
    }

    private func routeTodayFocusEventToFeature(_ event: Event) -> Bool {
        let eventType = EventType(rawValue: event.eventType)
        let entityType = event.relatedEntityType.lowercased()

        if entityType == EntityKind.pet.rawValue.lowercased() || entityType == "pet",
           let petId = UUID(uuidString: event.relatedEntityId),
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            switch eventType {
            case .vaccine, .externalDeworming, .internalDeworming, .health, .vetVisit:
                openTodayFocusHealth(pet: pet, section: .preventive)
                return true
            default:
                break
            }
        }

        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased(),
           let medicationId = UUID(uuidString: event.relatedEntityId) {
            for pet in pets where !pet.hasPassedAway {
                if pet.medications.contains(where: { $0.id == medicationId }) {
                    focusTodayPetCard(pet)
                    expandedQuickPetMedicationPet = pet
                    return true
                }
            }
        }

        return false
    }

    private func handleTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        guard let pet = petForNegativeSignal(signal) else { return }
        fabExpanded = false
        isExpandedQAEditMode = false

        if let alertType = signal.healthAlertType {
            switch alertType {
            case .checkupOverdue, .vaccineExpired, .vaccineExpiringSoon, .dewormingDue:
                openTodayFocusHealth(pet: pet, section: .preventive)
            case .weightGainAlert, .weightLossAlert:
                focusTodayPetCard(pet)
                expandedQuickWeightDetailPet = pet
            case .drinkingWeightAlert:
                openTodayFocusHealth(pet: pet, section: .symptomVisit)
            default:
                openTodayFocusHealth(pet: pet, section: .symptomVisit)
            }
            return
        }

        expandWalletToCard(id: pet.id)
    }

    private func petForNegativeSignal(_ signal: IslandNegativeSignal) -> Pet? {
        if let petId = signal.petId,
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            return pet
        }
        if let activePet = todayFocusActivePet {
            return activePet
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    // MARK: FAB (floating action button)

    private var floatingFabBottomPadding: CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 34
        return safeBottom + 40
    }

    private func openHomeFabMenu() {
        guard !fabExpanded else { return }
        fabMenuItemsVisible = false
        withAnimation(HeroAnim.fabSpring) {
            fabExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(HeroAnim.fabSpring) {
                fabMenuItemsVisible = true
            }
        }
    }

    private func closeHomeFabMenu() {
        guard fabExpanded else { return }
        withAnimation(HeroAnim.fabSpring) {
            fabMenuItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if fabExpanded && !fabMenuItemsVisible {
                withAnimation(HeroAnim.fabSpring) {
                    fabExpanded = false
                }
            }
        }
    }

    private func toggleHomeFabMenu() {
        fabExpanded ? closeHomeFabMenu() : openHomeFabMenu()
    }

    private func openCardFabMenu() {
        guard !cardFabExpanded else { return }
        cardFabMenuItemsVisible = false
        withAnimation(HeroAnim.fabSpring) {
            cardFabExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(HeroAnim.fabSpring) {
                cardFabMenuItemsVisible = true
            }
        }
    }

    private func closeCardFabMenu() {
        guard cardFabExpanded else { return }
        withAnimation(HeroAnim.fabSpring) {
            cardFabMenuItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if cardFabExpanded && !cardFabMenuItemsVisible {
                withAnimation(HeroAnim.fabSpring) {
                    cardFabExpanded = false
                }
            }
        }
    }

    private func toggleCardFabMenu() {
        cardFabExpanded ? closeCardFabMenu() : openCardFabMenu()
    }

    @ViewBuilder
    private func homeFabOverlay(activeCard: FocusCard?) -> some View {
        HomeFabMenuView(
            activeCard: activeCard,
            isExpanded: fabExpanded,
            itemsVisible: fabMenuItemsVisible,
            bottomPadding: floatingFabBottomPadding,
            homeShortcuts: HomeFabShortcutCatalog.primaryShortcuts,
            expandedShortcuts: activeCard.map { expandedCardFabShortcuts(for: $0) } ?? [],
            onToggle: {
                OhanaFeedback.medium()
                toggleHomeFabMenu()
            },
            onHomeShortcut: openHomeFabShortcut,
            onExpandedShortcut: { item in
                guard let activeCard else { return }
                guard item.isAvailable else {
                    OhanaFeedback.light()
                    return
                }
                OhanaFeedback.light()
                closeHomeFabMenu()
                openExpandedCardFabShortcut(item, card: activeCard)
            }
        )
    }

    private func openHomeFabShortcut(_ item: HomeFabFunctionShortcut) {
        guard item.isAvailable else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        closeHomeFabMenu()
        functionMenuPresentation = FunctionMenuPresentation(destination: item.destination)
    }

    private func expandedCardFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman {
            return FocusHomeFabShortcutPolicy.humanShortcuts(localization: l)
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return [ExpandedCardFabShortcut(label: "全部功能", icon: "ellipsis.circle.fill", action: .allFeatures)]
        }

        let displayedItems = isExpandedQAEditMode && activeCardId == pet.id
            ? expandedQAEditItems
            : expandedQuickActionItems(for: pet)
        let displayedActionTypes = Set(
            displayedItems
                .prefix(QuickActionLimit.maxItemsPerEntity)
                .map(\.actionType)
        )
        let hiddenQuickItems = QuickActionPickerCatalog
            .available(for: pet, existingActionTypes: displayedActionTypes)
            .map { FocusHomeFabShortcutPolicy.petShortcut(from: $0) }

        return hiddenQuickItems + [
            ExpandedCardFabShortcut(label: "全部功能", icon: "ellipsis.circle.fill", action: .allFeatures)
        ]
    }

    @ViewBuilder
    private func expandedCardFab(card: FocusCard) -> some View {
        let items = expandedCardFabShortcuts(for: card)

        ExpandedCardFabMenuView(
            items: items,
            isExpanded: cardFabExpanded,
            itemsVisible: cardFabMenuItemsVisible,
            onToggle: {
                OhanaFeedback.medium()
                toggleCardFabMenu()
            },
            onShortcut: { item in
                guard item.isAvailable else {
                    OhanaFeedback.light()
                    return
                }
                OhanaFeedback.light()
                closeCardFabMenu()
                openExpandedCardFabShortcut(item, card: card)
            }
        )
    }

    private func openExpandedCardFabShortcut(_ item: ExpandedCardFabShortcut, card: FocusCard) {
        switch item.action {
        case .allFeatures:
            if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
                expandedAllFeaturesPet = pet
            }
        case .humanAllFeatures:
            if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
                expandedAllFeaturesHuman = human
            }
        case .quick(let actionType):
            guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else { return }
            openExpandedPetShortcut(actionType, pet: pet)
        case .detail(let feature):
            guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else { return }
            openExpandedPetDetail(feature, pet: pet)
        case .humanQuick(let actionType):
            guard let human = humans.first(where: { $0.id == card.id }) else { return }
            openExpandedHumanShortcut(actionType, human: human)
        }
    }

    private func openExpandedPetShortcut(_ actionType: String, pet: Pet) {
        switch actionType {
        case "feed":
            openExpandedFeedDetail(for: pet)
        case "water", "waterChange", "filterClean":
            openExpandedWaterManagement(for: pet)
        case "walk":
            expandedQuickWalkPet = pet
        case "potty", "litter":
            expandedQuickPottyDetailPet = pet
        case "play":
            expandedQuickPlayDetailPet = pet
        case "medication":
            expandedQuickPetMedicationPet = pet
        case "groom":
            expandedQuickHygienePet = pet
        case "moment":
            expandedQuickMomentPet = pet
        default:
            break
        }
    }

    private func openExpandedPetDetail(_ feature: PetFeature, pet: Pet) {
        switch feature {
        case .health:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
        case .food:
            openExpandedFeedDetail(for: pet)
        case .hygiene:
            expandedQuickHygienePet = pet
        case .walks:
            expandedQuickWalkPet = pet
        case .potty:
            expandedQuickPottyDetailPet = pet
        case .weight:
            expandedQuickWeightDetailPet = pet
        case .expense:
            expandedQuickExpenseDetailPet = pet
        case .retention, .basicInfo, .documents, .moments, .achievements, .medications:
            expandedAllFeaturesPet = pet
        }
    }

    private func openExpandedHumanShortcut(_ actionType: String, human: Human) {
        if let field = PrivacyService.field(forHumanAction: actionType),
           PrivacyService.isLocked(field, for: human, viewedBy: activeHumanId) {
            showingHumanPrivacyAlert = true
            return
        }

        switch actionType {
        case "humanWeight":
            expandedHumanWeightDetail = human
        case "humanWorkout":
            expandedHumanWorkoutDetail = human
        case "humanMedication":
            expandedQuickHumanMedication = human
        case "humanNote":
            expandedHumanNoteDetail = human
        case "humanExpense":
            openExpandedQuickHumanExpense(for: human)
        default:
            expandedAllFeaturesHuman = human
        }
    }

    private func openGlobalCalendar() {
        calendarEntityFilterId = nil
        calendarHumanFilterId = nil
        showingCalendar = true
    }

    private func openTopCalendar() {
        guard let activeCard = activeWalletCard else {
            calendarEntityFilterId = nil
            calendarHumanFilterId = nil
            showingCalendar = true
            return
        }

        if activeCard.isHuman {
            calendarEntityFilterId = nil
            calendarHumanFilterId = activeCard.id.uuidString
        } else {
            calendarEntityFilterId = activeCard.id.uuidString
            calendarHumanFilterId = nil
        }
        showingCalendar = true
    }

    private func openHeaderCoconut() {
        guard let activeCard = activeWalletCard, activeCard.isReal else {
            showingOasisReward = true
            return
        }
        if activeCard.isHuman {
            guard let human = humans.first(where: { $0.id == activeCard.id }) else { return }
            guard !PrivacyService.isLocked(.wishlist, for: human, viewedBy: activeHumanId) else {
                showingHumanPrivacyAlert = true
                return
            }
            activeCoconutLogSubject = .human(human.id)
        } else {
            activeCoconutLogSubject = .pet(activeCard.id)
        }
    }

    // MARK: 3-zone header

    private func goFocusHeader(safeT: CGFloat) -> some View {
        let human = activeHuman
        let avatarEntry = human.map { FocusWalletAvatarCache.entry(for: $0.id, data: homeAvatarDataById[$0.id]) }
        return FocusHomeHeaderView(
            safeTop: safeT,
            streak: headerStreak,
            coconutBalance: headerCoconutBalance,
            activeHumanDisplayName: activeHumanDisplayName,
            activeHumanAvatarImage: avatarEntry?.image,
            activeHumanAvatarEmoji: human?.avatarEmoji,
            onStreak: { showStreakDetail = true },
            onCoconut: openHeaderCoconut,
            onCrew: { showingCrewRoster = true },
            onAccountSwitcher: { showingAccountSwitcher = true },
            onCalendar: openTopCalendar,
            onSettings: { showingSettings = true }
        )
    }

    // MARK: Context menu (long-press on card)

    @ViewBuilder
    private func cardContextMenu(card: FocusCard) -> some View {
        if card.isReal && !card.isDummy && !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                .flatMap { $0.isEmpty ? nil : $0 }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let log = PetCareLog(date: Date(), type: .feeding,
                                     amountGrams: pet.dailyPortionGrams,
                                     note: PetCareLog.manualFeedNoteMarker, pet: pet, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
            } label: {
                Label("喂食 \(pet.name)", systemImage: "fork.knife")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                openExpandedWaterManagement(for: pet)
            } label: {
                Label("水管理", systemImage: "water.waves")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
            } label: {
                Label("便便记录", systemImage: "drop.circle")
            }

            Divider()

            Button {
                selectedPet = pet
            } label: {
                Label("查看详情", systemImage: "arrow.right.circle")
            }
        }
    }

}

// ─────────────────────────────────────────────────
// MARK: – Expanded layer (bloom — dummy cards only)
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    private func expandedLayer(card: FocusCard,
                               geo: GeometryProxy,
                               outerCornerRadius: CGFloat,
                               windowSize: CGSize) -> some View {
        FocusHomeExpandedDemoLayer(
            card: card,
            outerCornerRadius: outerCornerRadius,
            windowSize: windowSize,
            safeAreaTop: safeAreaTop,
            floatingFabBottomPadding: floatingFabBottomPadding,
            namespace: ns,
            expandedId: expandedId,
            transitionAnimation: transitionAnimation,
            isInlineRecordOverlayPresented: isInlineRecordOverlayPresented,
            detailFooterVisible: $detailFooterVisible,
            dragOffset: $dragOffset,
            onClose: { expandedId = nil }
        ) {
            if !isInlineRecordOverlayPresented {
                expandedCardFab(card: card)
            }
        }
    }
}
