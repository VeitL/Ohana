//
//  VerticalSolidHomeView.swift
//  Ohana
//
//  Rebuilt home shell with local-first interactions and snapshot handoffs.
//

import SwiftData
import SwiftUI

struct VerticalSolidHomeView: View {
    let onOpenPet: (UUID, PetDetailTab) -> Void
    let onOpenHuman: (UUID) -> Void
    let onOpenPlant: (UUID) -> Void
    let createdEntitySignal: HomeCreatedEntitySignal?
    let onPresentAccountSwitcher: () -> Void
    let onPresentAddEntity: (EntityType) -> Void
    let onPresentAppSheet: (AppSheetRoute) -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void
    let onPresentCrewRoster: (CrewRosterMode) -> Void
    let onPresentFunctionMenu: (FMDest?) -> Void
    let onPresentOasisReward: () -> Void
    let onPresentQuickMoment: (UUID) -> Void
    let onPresentSettings: () -> Void
    let onPresentStreakDetail: () -> Void
    let onPresentWalk: (UUID) -> Void

    let payload: HomeReadModelPayload

    @StateObject private var controller: VerticalSolidHomeController
    @StateObject private var safeAreaController = FocusHomeSafeAreaController()
    @StateObject private var routeCoordinator = HomeRouteCoordinator()
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @StateObject private var expensePreviewStore = HomeExpensePreviewStore()

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @AppStorage("ohanaGrowthOnboardingCompletedV1") private var growthOnboardingCompleted = false
    @AppStorage("ohanaGrowthLastSeenTreeLevelV1") private var growthLastSeenTreeLevel = 0
    @AppStorage("quickActionItems_v2") private var quickActionItemsRaw = ""
    @AppStorage("home_cards_enable_ambient_float") private var enablesHomeCardAmbientFloat = false
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @ObservedObject private var avatarPipeline = AvatarPipeline.shared
    @Bindable private var questMgr = QuestManager.shared

    @State private var headerContextCardId: UUID?
    @State private var fabExpanded = false
    @State private var fabMenuItemsVisible = false
    @State private var calendarAddEventTrigger = 0
    @State private var embeddedCalendarPreselectedPetId: String?
    @State private var embeddedCalendarPreselectedHumanId: String?
    @State private var isCalendarAddEventPresented = false
    @State private var calendarAddEventProgress: CGFloat = 0
    @State private var isCalendarAddEventContentMounted = false
    @State private var calendarAddEventPresentationTask: Task<Void, Never>?
    @State private var calendarAddEventContentMountTask: Task<Void, Never>?
    @State private var oasisInjectEnergyTrigger = 0
    @State private var avatarCacheRevision = 0
    @State private var headerStreak = 0
    @State private var isHomeCardExpandedOrTransitioning = false
    @State private var isHomeCardHeroAnimating = false
    @State private var homeCardHeroProgress: CGFloat = 0
    @State private var arrivingHomeCardId: UUID?
    @State private var arrivalClearTask: Task<Void, Never>?
    @State private var treeManager = OasisTreeManager.shared
    @State private var showGrowthOnboarding = false
    @State private var growthOnboardingTask: Task<Void, Never>?
    @State private var growthUnlockToastStatus: GrowthUnlockStatus?
    @State private var growthUnlockToastPresentationTask: Task<Void, Never>?
    @State private var growthUnlockToastDismissTask: Task<Void, Never>?
    @State private var growthLoopPulseStatus: GrowthLoopPulseStatus?
    @State private var growthLoopSyncTask: Task<Void, Never>?
    @State private var growthLoopPulseDismissTask: Task<Void, Never>?
    @State private var snapshotRefreshGate = HomeSnapshotRefreshGate()

    init(
        onOpenPet: @escaping (UUID, PetDetailTab) -> Void,
        onOpenHuman: @escaping (UUID) -> Void,
        onOpenPlant: @escaping (UUID) -> Void,
        createdEntitySignal: HomeCreatedEntitySignal?,
        onPresentAccountSwitcher: @escaping () -> Void,
        onPresentAddEntity: @escaping (EntityType) -> Void,
        onPresentAppSheet: @escaping (AppSheetRoute) -> Void,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void,
        onPresentCrewRoster: @escaping (CrewRosterMode) -> Void,
        onPresentFunctionMenu: @escaping (FMDest?) -> Void,
        onPresentOasisReward: @escaping () -> Void,
        onPresentQuickMoment: @escaping (UUID) -> Void,
        onPresentSettings: @escaping () -> Void,
        onPresentStreakDetail: @escaping () -> Void,
        onPresentWalk: @escaping (UUID) -> Void,
        payload: HomeReadModelPayload
    ) {
        self.onOpenPet = onOpenPet
        self.onOpenHuman = onOpenHuman
        self.onOpenPlant = onOpenPlant
        self.createdEntitySignal = createdEntitySignal
        self.onPresentAccountSwitcher = onPresentAccountSwitcher
        self.onPresentAddEntity = onPresentAddEntity
        self.onPresentAppSheet = onPresentAppSheet
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onPresentCrewRoster = onPresentCrewRoster
        self.onPresentFunctionMenu = onPresentFunctionMenu
        self.onPresentOasisReward = onPresentOasisReward
        self.onPresentQuickMoment = onPresentQuickMoment
        self.onPresentSettings = onPresentSettings
        self.onPresentStreakDetail = onPresentStreakDetail
        self.onPresentWalk = onPresentWalk
        self.payload = payload
        AvatarPipeline.shared.seedPreviewEntries(
            payload.avatarPreloadPayloads
        )
        _controller = StateObject(
            wrappedValue: VerticalSolidHomeController(
                initialSnapshot: payload.snapshot,
                initialSignature: payload.signature
            )
        )
    }

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var commandExecutor: HomeCommandExecutor {
        HomeCommandExecutor(modelContext: modelContext, careEvents: appServices.careEvents)
    }

    private var l: L10n {
        L10n(appLanguage)
    }

    private var activeHumanID: UUID? {
        UUID(uuidString: activeHumanIdRaw)
    }

    private var dataSignature: String {
        payload.signature
    }

    private var sourceState: VerticalSolidHomeSourceState {
        payload.source
    }

    private var pets: [Pet] {
        sourceState.pets
    }

    private var humans: [Human] {
        sourceState.humans
    }

    private var plants: [Plant] {
        sourceState.plants
    }

    private var electronicPets: [OasisElectronicPet] {
        sourceState.electronicPets
    }

    private var allEvents: [Event] {
        sourceState.events
    }

    private var humanMedications: [HumanMedication] {
        sourceState.humanMedications
    }

    private var humanMedicationLogs: [HumanMedicationLog] {
        sourceState.humanMedicationLogs
    }

    private var expenseLogs: [PetExpenseLog] {
        expensePreviewStore.expenseLogs
    }

    private var avatarPreloadSignature: String {
        [
            payload.avatarPreloadSignature,
            payload.popoutPreloadSignature
        ].joined(separator: "||popout:")
    }

    private var activeHuman: Human? {
        sourceState.activeHuman
    }

    private var currentCoconutBalance: Int {
        activeHuman?.coconutBalance ?? questMgr.coconutCount
    }

    private var headerContextCard: FocusCard? {
        guard controller.selectedTab == .home,
              let headerContextCardId else {
            return nil
        }
        return controller.snapshot.cards.first { $0.id == headerContextCardId }
    }

    private var expandedBottomBarCard: FocusCard? {
        guard controller.selectedTab == .home,
              isHomeCardExpandedOrTransitioning || homeCardHeroProgress > 0.98,
              let card = headerContextCard,
              !card.isElectronicPet else {
            return nil
        }
        return card
    }

    private var expandedBottomBarShortcuts: [ExpandedCardFabShortcut] {
        guard let card = expandedBottomBarCard else { return [] }
        return expandedFabShortcuts(for: card)
    }

    private var headerCoconutBalance: Int {
        headerContextCard?.coconutBalance ?? currentCoconutBalance
    }

    private var headerCoconutDeltaContext: String {
        if let card = headerContextCard {
            return "card-\(card.id.uuidString)"
        }
        return "current-human-\(activeHuman?.id.uuidString ?? "global")"
    }

    private var activeHumanAvatarImage: UIImage? {
        guard let id = payload.activeHumanAvatar.id else { return nil }
        return avatarPipeline.cachedImage(for: id, signature: payload.activeHumanAvatar.signature)
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = safeAreaController.resolvedTop(in: proxy)
            let safeBottom = safeAreaController.resolvedBottom(in: proxy)
            let headerTopGap: CGFloat = 8
            let headerContentHeight: CGFloat = 30
            let focusTopGap: CGFloat = 2
            let todayFocusHeight = min(128, max(118, proxy.size.height * 0.145))
            let growthLoopHeight = min(86, max(78, proxy.size.height * 0.092))
            let focusHeight = todayFocusHeight + 7 + growthLoopHeight
            let contentTopGap: CGFloat = 4
            let compactContentGap: CGFloat = 8
            let isHomeTabVisible = controller.selectedTab == .home
            let cardHeroProgress = min(max(homeCardHeroProgress, 0), 1)
            let todayFocusVisualProgress = Self.todayFocusVisualProgress(cardHeroProgress: cardHeroProgress)
            let isTodayFocusInteractive = isHomeTabVisible &&
                !isHomeCardExpandedOrTransitioning &&
                !isHomeCardHeroAnimating &&
                todayFocusVisualProgress > 0.98
            let todayFocusHorizontalOffset = -CGFloat(controller.selectedTab.index) * proxy.size.width
            let compactTopChromeHeight = safeTop + headerTopGap + headerContentHeight + compactContentGap
            let homeCollapsedTopInset = max(0, focusTopGap + focusHeight + contentTopGap - compactContentGap)
            let topChromeHeight = compactTopChromeHeight
            let bottomHeight = max(84, safeBottom + 70)
            let contentHeight = max(300, proxy.size.height - topChromeHeight - bottomHeight)
            let growthPendingCount = Self.growthLoopPendingCount(from: controller.snapshot.todayFocus)
            let hasAnyMember = !pets.isEmpty || !humans.isEmpty

            ZStack(alignment: .top) {
                OhanaAppBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VerticalSolidHomePageDeck(
                    selectedTab: controller.selectedTab,
                    outgoingTab: controller.outgoingTab,
                    preparingTab: controller.preparingTab,
                    preparedTabs: controller.preparedTabs,
                    canAnimate: canAnimate
                ) { lifecycle in
                    VerticalSolidHomeDashboardPage(
                        snapshot: controller.snapshot,
                        pets: pets,
                        humans: humans,
                        allEvents: allEvents,
                        humanMedications: humanMedications,
                        humanMedicationLogs: humanMedicationLogs,
                        expenseLogs: expenseLogs,
                        avatarCacheRevision: avatarCacheRevision + avatarPipeline.revision,
                        isLive: lifecycle.isLive,
                        collapsedTopInset: homeCollapsedTopInset,
                        localization: l,
                        activeHumanID: activeHumanID,
                        allowsAmbientFloat: enablesHomeCardAmbientFloat,
                        quickActionItemsRaw: $quickActionItemsRaw,
                        headerContextCardId: $headerContextCardId,
                        isCardExpandedOrTransitioning: $isHomeCardExpandedOrTransitioning,
                        isCardHeroAnimating: $isHomeCardHeroAnimating,
                        cardHeroProgress: $homeCardHeroProgress,
                        arrivingCardId: arrivingHomeCardId,
                        onOpenCard: openCard,
                        onQuickActionForCard: openQuickActionItem,
                        onQuickActionOptionForCard: openQuickActionOption,
                        onQuickActionLimitReached: { routeCoordinator.showQuickActionLimit() },
                        onAddPet: { routeCoordinator.openAddEntity(.pet) }
                    )
                } calendar: { lifecycle in
                    CalendarRouteContainer(
                        preselectedPetId: embeddedCalendarPreselectedPetId,
                        preselectedHumanId: embeddedCalendarPreselectedHumanId,
                        hideToolbar: true,
                        showsEmbeddedControls: true,
                        addEventTrigger: calendarAddEventTrigger,
                        isEmbeddedPrepared: lifecycle.isPrepared,
                        isEmbeddedVisible: lifecycle.isVisible,
                        isEmbeddedActive: lifecycle.isLive,
                        onRequestAddEvent: openCalendarAddEvent,
                        onOpenEventDestination: openCalendarEventDestination,
                        onPresentCoconutLog: { subject in
                            onPresentCoconutLog(subject)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                } oasis: { lifecycle in
                    OasisHomeTabHost(
                        lifecycle: lifecycle,
                        injectEnergyTrigger: oasisInjectEnergyTrigger,
                        onPresentCoconutLog: onPresentCoconutLog
                    )
                } plants: { _ in
                    VerticalSolidHomePlantsPage(
                        plants: controller.snapshot.plants,
                        localization: l,
                        onOpenPlant: openPlant,
                        onAddPlant: { routeCoordinator.openAddEntity(.plant) }
                    )
                }
                .frame(width: proxy.size.width, height: contentHeight)
                .position(x: proxy.size.width / 2, y: topChromeHeight + contentHeight / 2)

                if controller.selectedTab == .home && controller.preparedTabs.contains(.home) {
                    VerticalSolidHomeTodayFocusChrome(
                        snapshot: controller.snapshot.todayFocus,
                        isLive: isTodayFocusInteractive,
                        onOpenOasis: { selectTab(.oasis) },
                        onOpenQuest: openTodayFocusQuest,
                        onCompleteQuest: completeTodayFocusQuest,
                        onTapNegativeSignal: openTodayFocusNegativeSignal,
                        onTapFamilyTask: openTodayFocusFamilyTask,
                        onConfirmExchange: confirmTodayFocusExchange
                    )
                    .padding(.horizontal, 8)
                    .frame(width: proxy.size.width, height: todayFocusHeight, alignment: .top)
                    .position(
                        x: proxy.size.width / 2 + todayFocusHorizontalOffset,
                        y: safeTop + headerTopGap + headerContentHeight + focusTopGap + todayFocusHeight / 2
                    )
                    .opacity(Double(todayFocusVisualProgress))
                    .allowsHitTesting(isTodayFocusInteractive)
                    .accessibilityHidden(!isHomeTabVisible || todayFocusVisualProgress < 0.5)
                    .animation(canAnimate ? GoMotion.page : GoMotion.reduced, value: controller.selectedTab)
                    .zIndex(8)

                    GrowthDailyLoopStrip(
                        currentLevel: treeManager.treeLevel.rawValue,
                        progressToNextLevel: treeManager.progressToNextLevel,
                        pendingFocusCount: growthPendingCount,
                        hasAnyMember: hasAnyMember,
                        appLanguage: appLanguage,
                        onPrimaryAction: {
                            openGrowthDailyLoop(
                                hasAnyMember: hasAnyMember,
                                pendingFocusCount: growthPendingCount,
                                currentLevel: treeManager.treeLevel.rawValue
                            )
                        }
                    )
                    .padding(.horizontal, 12)
                    .frame(width: proxy.size.width, height: growthLoopHeight, alignment: .top)
                    .position(
                        x: proxy.size.width / 2 + todayFocusHorizontalOffset,
                        y: safeTop + headerTopGap + headerContentHeight + focusTopGap + todayFocusHeight + 7 + growthLoopHeight / 2
                    )
                    .opacity(Double(todayFocusVisualProgress))
                    .allowsHitTesting(isTodayFocusInteractive)
                    .accessibilityHidden(!isHomeTabVisible || todayFocusVisualProgress < 0.5)
                    .animation(canAnimate ? GoMotion.page : GoMotion.reduced, value: controller.selectedTab)
                    .zIndex(8)
                }

                FocusHomeHeaderView(
                    safeTop: safeTop,
                    topGap: headerTopGap,
                    contentHeight: headerContentHeight,
                    streak: headerStreak,
                    treeLevel: treeManager.treeLevel.rawValue,
                    treeProgress: treeManager.progressToNextLevel,
                    appLanguage: appLanguage,
                    coconutBalance: headerCoconutBalance,
                    coconutDeltaContext: headerCoconutDeltaContext,
                    activeHumanDisplayName: activeHuman?.name ?? controller.snapshot.activeName,
                    activeHumanAvatarImage: activeHumanAvatarImage,
                    activeHumanAvatarEmoji: activeHuman?.avatarEmoji,
                    onStreak: { routeCoordinator.openStreakDetail() },
                    onTreeLevel: {
                        openHeaderTreeLevelDestination(hasAnyMember: hasAnyMember)
                    },
                    onCoconut: openHeaderCoconutDestination,
                    onCrew: { routeCoordinator.openCrewRoster() },
                    onAccountSwitcher: { routeCoordinator.openAccountSwitcher() },
                    onCalendar: { controller.select(.calendar) },
                    onSettings: { routeCoordinator.openSettings() }
                )
                .contentShape(Rectangle())
                .zIndex(10)

                VerticalSolidHomeBottomBar(
                    selectedTab: controller.selectedTab,
                    isFabExpanded: $fabExpanded,
                    itemsVisible: $fabMenuItemsVisible,
                    activeCard: expandedBottomBarCard,
                    homeShortcuts: HomeFabShortcutCatalog.primaryShortcuts,
                    expandedShortcuts: expandedBottomBarShortcuts,
                    safeBottom: safeBottom,
                    canAnimate: canAnimate,
                    localization: l,
                    onSelect: selectTab,
                    onHomeShortcut: openHomeFabShortcut,
                    onExpandedShortcut: openExpandedFabShortcut,
                    onCenter: centerAction
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .zIndex(9)

                if isCalendarAddEventPresented || calendarAddEventProgress > 0.001 {
                    OhanaDeferredInlinePageCover(
                        progress: calendarAddEventProgress,
                        isContentMounted: isCalendarAddEventContentMounted,
                        reservesSafeArea: false
                    ) {
                        AddEventView(onClose: closeCalendarAddEvent)
                    }
                    .zIndex(40)
                }

                if let growthLoopPulseStatus {
                    GrowthLoopPulseToastView(
                        status: growthLoopPulseStatus,
                        appLanguage: appLanguage
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, max(92, safeBottom + 84))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(61)
                }

                if let growthUnlockToastStatus {
                    GrowthUnlockToastView(
                        status: growthUnlockToastStatus,
                        appLanguage: appLanguage,
                        onDismiss: dismissGrowthUnlockToast,
                        onOpen: {
                            openGrowthUnlockDestination(growthUnlockToastStatus)
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, max(92, safeBottom + 84))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(62)
                }

                if showGrowthOnboarding {
                    OhanaGrowthOnboardingOverlay(
                        appLanguage: appLanguage,
                        treeLevel: treeManager.treeLevel.rawValue,
                        onFinish: completeGrowthOnboarding,
                        onSkip: completeGrowthOnboarding
                    )
                    .zIndex(70)
                }

            }
            .onAppear {
                safeAreaController.stabilize(from: proxy)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            bindHomeAppRouteSink()
            controller.applySnapshot(makeSnapshot(), signature: dataSignature, force: !controller.snapshot.isReady)
            AppPerformanceMonitor.shared.record("home_first_render", valueMS: 0)
            refreshHeaderStreak()
            controller.startWarmup()
            scheduleGrowthOnboardingIfNeeded()
            scheduleGrowthUnlockFeedbackIfNeeded()
        }
        .onChange(of: dataSignature) { _, _ in
            requestHomeSnapshotRefresh()
        }
        .onChange(of: isHomeCardHeroAnimating) { _, isAnimating in
            flushDeferredHomeSnapshotRefreshIfNeeded(isAnimating: isAnimating)
        }
        .task(id: avatarPreloadSignature) {
            await preloadFirstScreenAvatars()
        }
        .onDisappear {
            clearArrivalState()
            expensePreviewStore.cancel()
            calendarAddEventPresentationTask?.cancel()
            calendarAddEventContentMountTask?.cancel()
            growthOnboardingTask?.cancel()
            growthUnlockToastPresentationTask?.cancel()
            growthUnlockToastDismissTask?.cancel()
            growthLoopSyncTask?.cancel()
            growthLoopPulseDismissTask?.cancel()
            growthLoopPulseStatus = nil
            avatarPipeline.cancel(key: avatarPreloadSignature)
            commandQueue.cancelAll()
            snapshotRefreshGate.cancel()
            controller.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                clearArrivalState()
            }
        }
        .onChange(of: createdEntitySignal) { _, signal in
            guard let signal else { return }
            handleNewHomeMemberSaved(id: signal.entityID)
        }
        .focusHomeRouteSheets(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            l: l,
            routes: routeCoordinator,
            activeHumanIdStr: $activeHumanIdRaw,
            onAddEntityDismissed: {},
            onPetSavedFromAddEntity: { pet in
                handleNewHomeMemberSaved(id: pet.id)
            },
            onHumanSavedFromAddEntity: { human in
                handleNewHomeMemberSaved(id: human.id)
            },
            onCrewPetSelected: { pet in
                onOpenPet(pet.id, .overview)
            },
            onCrewHumanSelected: { human in
                onOpenHuman(human.id)
            },
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { _ in }
        )
        .onChange(of: activeHumanIdRaw) { _, _ in
            refreshHeaderStreak()
        }
        .onChange(of: controller.selectedTab) { _, _ in
            closeVerticalFabMenu(immediate: true)
        }
        .onChange(of: expandedBottomBarCard?.id) { _, _ in
            closeVerticalFabMenu(immediate: true)
            requestExpandedExpensePreview()
        }
        .onChange(of: treeManager.treeLevel.rawValue) { _, _ in
            scheduleGrowthUnlockFeedbackIfNeeded()
        }
    }

    private func bindHomeAppRouteSink() {
        routeCoordinator.bindAppRouteSink { route in
            switch route {
            case let .petProfile(id, initialTab):
                onOpenPet(id, initialTab)
            case let .humanProfile(id):
                onOpenHuman(id)
            }
        }
        routeCoordinator.bindAppSheetRouteSink { route in
            switch route {
            case .accountSwitcher:
                onPresentAccountSwitcher()
            case let .addEntity(type):
                onPresentAddEntity(type)
            case let .appSheet(route):
                onPresentAppSheet(route)
            case let .functionMenu(destination):
                onPresentFunctionMenu(destination)
            case .streakDetail:
                onPresentStreakDetail()
            }
        }
        routeCoordinator.bindAppFullScreenRouteSink { route in
            switch route {
            case .oasisReward:
                onPresentOasisReward()
            case let .walk(petID):
                onPresentWalk(petID)
            }
        }
        routeCoordinator.bindAppOverlayRouteSink { route in
            switch route {
            case let .quickMoment(petID):
                onPresentQuickMoment(petID)
            }
        }
    }

    private func makeSnapshot() -> VerticalSolidHomeSnapshot {
        payload.snapshot
    }

    private func requestHomeSnapshotRefresh() {
        guard let request = snapshotRefreshGate.dataDidChange(
            signature: dataSignature,
            isHeroAnimating: isHomeCardHeroAnimating
        ) else {
            return
        }
        scheduleHomeSnapshotRefresh(request)
    }

    private func flushDeferredHomeSnapshotRefreshIfNeeded(isAnimating: Bool) {
        guard let request = snapshotRefreshGate.heroAnimationDidChange(isAnimating: isAnimating) else {
            return
        }
        scheduleHomeSnapshotRefresh(request)
    }

    private func scheduleHomeSnapshotRefresh(_ request: HomeSnapshotRefreshRequest) {
        controller.scheduleSnapshotRefresh(
            signature: request.signature,
            delayMilliseconds: request.delayMilliseconds
        ) {
            makeSnapshot()
        }
    }

    private func requestExpandedExpensePreview() {
        guard let card = expandedBottomBarCard, card.isHuman else {
            expensePreviewStore.clear()
            return
        }
        expensePreviewStore.request(context: modelContext, humanID: card.id)
    }

    private func selectTab(_ tab: VerticalSolidHomeTab) {
        guard AppFeatureRouteGuard.allowsHomeTab(tab) else {
            AppFeatureRouteGuard.recordIntercept("homeTab:\(tab.rawValue)")
            return
        }
        guard controller.selectedTab != tab else { return }
        OhanaFeedback.selection()
        closeVerticalFabMenu(immediate: true)
        if tab == .calendar {
            prepareEmbeddedCalendarFilterForCurrentContext()
        }
        controller.select(tab)
    }

    private func prepareEmbeddedCalendarFilterForCurrentContext() {
        guard let card = expandedBottomBarCard else {
            embeddedCalendarPreselectedPetId = nil
            embeddedCalendarPreselectedHumanId = nil
            return
        }

        if card.isHuman {
            embeddedCalendarPreselectedPetId = nil
            embeddedCalendarPreselectedHumanId = card.id.uuidString
        } else {
            embeddedCalendarPreselectedPetId = card.id.uuidString
            embeddedCalendarPreselectedHumanId = nil
        }
    }

    private func centerAction() {
        OhanaFeedback.light()
        switch controller.selectedTab {
        case .home:
            routeCoordinator.openFunctionMenu(destination: nil)
        case .calendar:
            openCalendarAddEvent()
        case .oasis:
            oasisInjectEnergyTrigger += 1
        case .plants:
            routeCoordinator.openAddEntity(.plant)
        }
    }

    private func openGrowthDailyLoop(
        hasAnyMember: Bool,
        pendingFocusCount: Int,
        currentLevel: Int
    ) {
        closeVerticalFabMenu(immediate: true)
        guard hasAnyMember else {
            routeCoordinator.openAddEntity(.pet)
            return
        }

        let destination: FMDest = pendingFocusCount > 0
            ? .featureGroup(.dailyCare)
            : AppFeatureRouteGuard.recommendedDestination(
                for: AppFeatureRouteGuard.currentGrowthStep(currentLevel: currentLevel),
                currentLevel: currentLevel
            )
        routeCoordinator.openFunctionMenu(destination: destination)
    }

    private func openHeaderTreeLevelDestination(hasAnyMember: Bool) {
        closeVerticalFabMenu(immediate: true)
        guard hasAnyMember else {
            OhanaFrameScheduler.runAfterNextFrame {
                routeCoordinator.openAddEntity(.pet)
            }
            return
        }

        OhanaFrameScheduler.runAfterNextFrame {
            AppPerformanceMonitor.shared.record("growth_roadmap_opened", valueMS: 0, note: "homeHeader")
            routeCoordinator.openFunctionMenu(destination: .growthRoadmap)
        }
    }

    private func openCalendarAddEvent() {
        guard !isCalendarAddEventPresented else { return }
        closeVerticalFabMenu(immediate: true)
        calendarAddEventPresentationTask?.cancel()
        calendarAddEventContentMountTask?.cancel()
        isCalendarAddEventPresented = true
        calendarAddEventProgress = 0
        isCalendarAddEventContentMounted = false
        calendarAddEventPresentationTask = OhanaFrameScheduler.runAfterNextFrame {
            guard isCalendarAddEventPresented else {
                calendarAddEventPresentationTask = nil
                return
            }
            withAnimation(GoMotion.sheetEnter) {
                calendarAddEventProgress = 1
            }
            calendarAddEventPresentationTask = nil
        }
        calendarAddEventContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            guard isCalendarAddEventPresented else {
                calendarAddEventContentMountTask = nil
                return
            }
            withAnimation(GoMotion.quick) {
                isCalendarAddEventContentMounted = true
            }
            calendarAddEventContentMountTask = nil
        }
    }

    private func closeCalendarAddEvent() {
        guard isCalendarAddEventPresented || calendarAddEventProgress > 0.001 else { return }
        calendarAddEventContentMountTask?.cancel()
        isCalendarAddEventContentMounted = false
        withAnimation(GoMotion.sheetEnter) {
            calendarAddEventProgress = 0
        }
        calendarAddEventPresentationTask?.cancel()
        calendarAddEventPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 340) {
            guard calendarAddEventProgress <= 0.02 else {
                calendarAddEventPresentationTask = nil
                return
            }
            isCalendarAddEventPresented = false
            isCalendarAddEventContentMounted = false
            calendarAddEventPresentationTask = nil
        }
    }

    private func scheduleGrowthOnboardingIfNeeded() {
        guard !growthOnboardingCompleted,
              !showGrowthOnboarding,
              pets.isEmpty,
              humans.isEmpty else {
            return
        }
        growthOnboardingTask?.cancel()
        growthOnboardingTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 680) {
            guard !growthOnboardingCompleted,
                  pets.isEmpty,
                  humans.isEmpty else {
                growthOnboardingTask = nil
                return
            }
            withAnimation(GoMotion.feedback) {
                showGrowthOnboarding = true
            }
            growthOnboardingTask = nil
        }
    }

    private func completeGrowthOnboarding() {
        growthOnboardingCompleted = true
        growthOnboardingTask?.cancel()
        growthOnboardingTask = nil
        withAnimation(GoMotion.feedback) {
            showGrowthOnboarding = false
        }
    }

    private func scheduleGrowthUnlockFeedbackIfNeeded() {
        let currentLevel = treeManager.treeLevel.rawValue
        guard currentLevel > 0 else { return }

        guard growthLastSeenTreeLevel > 0 else {
            growthLastSeenTreeLevel = currentLevel
            return
        }

        guard currentLevel > growthLastSeenTreeLevel else {
            if currentLevel < growthLastSeenTreeLevel {
                growthLastSeenTreeLevel = currentLevel
            }
            return
        }

        let unlockedSteps = AppFeatureRouteGuard.newlyUnlockedStages(
            from: growthLastSeenTreeLevel,
            to: currentLevel
        )
        growthLastSeenTreeLevel = currentLevel
        guard let step = unlockedSteps.last else { return }

        growthUnlockToastPresentationTask?.cancel()
        growthUnlockToastDismissTask?.cancel()
        growthUnlockToastPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: showGrowthOnboarding ? 1_800 : 520) {
            guard !showGrowthOnboarding else {
                growthUnlockToastPresentationTask = nil
                return
            }
            withAnimation(GoMotion.sheetEnter) {
                growthUnlockToastStatus = GrowthUnlockStatus(step: step, currentLevel: currentLevel)
            }
            growthUnlockToastPresentationTask = nil
            growthUnlockToastDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3_800) {
                dismissGrowthUnlockToast()
            }
        }
    }

    private func dismissGrowthUnlockToast() {
        growthUnlockToastPresentationTask?.cancel()
        growthUnlockToastDismissTask?.cancel()
        growthUnlockToastPresentationTask = nil
        growthUnlockToastDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            growthUnlockToastStatus = nil
        }
    }

    private func openGrowthUnlockDestination(_ status: GrowthUnlockStatus) {
        OhanaFeedback.light()
        let destination = AppFeatureRouteGuard.recommendedDestination(
            for: status.step,
            currentLevel: status.currentLevel
        )
        dismissGrowthUnlockToast()
        OhanaFrameScheduler.runAfterNextFrame {
            routeCoordinator.openFunctionMenu(destination: destination)
        }
    }

    private func scheduleGrowthLoopSync(after mutation: DomainMutationResult) {
        guard mutation.wroteBusinessFact else { return }
        OnboardingJourneyCoordinator.markFirstCareCompleted()
        let previousLevel = treeManager.treeLevel.rawValue
        let previousEnergy = treeManager.totalEnergy
        let previousProgress = treeManager.progressToNextLevel

        growthLoopSyncTask?.cancel()
        growthLoopSyncTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            let startedAt = CFAbsoluteTimeGetCurrent()
            treeManager.refreshEnergy(
                modelContext: modelContext,
                pets: pets,
                humans: humans,
                plants: plants
            )
            let currentLevel = treeManager.treeLevel.rawValue
            let currentEnergy = treeManager.totalEnergy
            let currentProgress = treeManager.progressToNextLevel
            let energyDelta = max(0, currentEnergy - previousEnergy)

            AppPerformanceMonitor.shared.record(
                "growth_loop_energy_synced",
                startedAt: startedAt,
                note: "command=\(mutation.command), energyDelta=\(energyDelta), level=\(previousLevel)->\(currentLevel)"
            )

            if currentLevel > previousLevel {
                growthLoopPulseDismissTask?.cancel()
                growthLoopPulseDismissTask = nil
                growthLoopPulseStatus = nil
                scheduleGrowthUnlockFeedbackIfNeeded()
            } else if energyDelta > 0 || currentProgress > previousProgress {
                presentGrowthLoopPulse(
                    currentLevel: currentLevel,
                    energyDelta: max(energyDelta, 1),
                    progress: currentProgress
                )
            }
            growthLoopSyncTask = nil
        }
    }

    private func presentGrowthLoopPulse(
        currentLevel: Int,
        energyDelta: Int,
        progress: Double
    ) {
        growthLoopPulseDismissTask?.cancel()
        let progressPercent = min(100, max(0, Int((progress * 100).rounded())))
        withAnimation(GoMotion.sheetEnter) {
            growthLoopPulseStatus = GrowthLoopPulseStatus(
                currentLevel: currentLevel,
                energyDelta: energyDelta,
                progressPercent: progressPercent
            )
        }
        growthLoopPulseDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 2_600) {
            dismissGrowthLoopPulse()
        }
    }

    private func dismissGrowthLoopPulse() {
        growthLoopPulseDismissTask?.cancel()
        growthLoopPulseDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            growthLoopPulseStatus = nil
        }
    }

    private func openHomeFabShortcut(_ shortcut: HomeFabFunctionShortcut) {
        closeVerticalFabMenu(immediate: true)
        routeCoordinator.openFunctionMenu(destination: shortcut.destination)
    }

    private func handleNewHomeMemberSaved(id: UUID) {
        homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: id, currentRaw: homeCardOrderRaw)
        arrivingHomeCardId = id
        arrivalClearTask?.cancel()
        arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1_500) {
            guard arrivingHomeCardId == id else { return }
            arrivingHomeCardId = nil
            arrivalClearTask = nil
        }
    }

    private func clearArrivalState() {
        arrivalClearTask?.cancel()
        arrivalClearTask = nil
        arrivingHomeCardId = nil
    }

    private func openCard(_ card: FocusCard) {
        if card.isHuman {
            onOpenHuman(card.id)
        } else if card.isElectronicPet {
            controller.select(.oasis)
        } else {
            onOpenPet(card.id, .overview)
        }
    }

    private func openPlant(_ plant: VerticalSolidHomePlantSnapshot) {
        onOpenPlant(plant.id)
    }

    private func openTodayFocusQuest(_ quest: IslandQuest) {
        if openTodayFocusOasisQuest(quest) { return }

        if let destination = eventDestination(for: quest) {
            openCalendarEventDestinationAfterDismiss(destination)
            return
        }

        if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id),
           let target = petMedicationTarget(medicationId) {
            routeCoordinator.openSheet(.petMedication(target.pet.id))
            return
        }

        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           let human = humans.first(where: { $0.id == humanId }) {
            routeCoordinator.openSheet(.humanWeight(human.id))
            return
        }

        if let pet = targetPet(for: quest) {
            openPetQuickKey(todayFocusPetQuickKey(for: quest, pet: pet), pet: pet)
            return
        }

        if let plant = targetPlant(for: quest) {
            openTodayFocusPlant(plant)
            return
        }

        if quest.id == "q_reminder" {
            selectTab(.calendar)
            return
        }

        selectTab(.oasis)
    }

    private func completeTodayFocusQuest(_ quest: IslandQuest) {
        OhanaFeedback.light()

        if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id),
           let target = petMedicationTarget(medicationId) {
            let petID = target.pet.id
            let medicationID = target.medication.id
            enqueueHomeCommand(.medicationDose(petID: petID, medicationID: medicationID)) {
                commandExecutor.recordMedicationDose(petID: petID, medicationID: medicationID)
                applyTodayFocusMutationFeedback(entityId: petID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
           let event = allEvents.first(where: { $0.id == eventId }) {
            let eventID = event.id
            enqueueHomeCommand(.todayFocus(entityID: eventID, action: "eventComplete")) {
                commandExecutor.completeTodayFocusEvent(eventID: eventID)
                applyTodayFocusMutationFeedback(entityId: eventID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if quest.id == "q_water_plant",
           let plant = targetPlant(for: quest) {
            let plantID = plant.id
            enqueueHomeCommand(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
                commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
                applyTodayFocusMutationFeedback(entityId: plantID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if quest.id == "q_fertilize_plant",
           let plant = targetPlant(for: quest) {
            let plantID = plant.id
            enqueueHomeCommand(.plantCare(plantID: plantID, action: PlantCareType.fertilizing.rawValue)) {
                commandExecutor.recordPlantCare(.fertilizing, plantID: plantID, executorId: currentExecutorId())
                applyTodayFocusMutationFeedback(entityId: plantID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           let human = humans.first(where: { $0.id == humanId }) {
            routeCoordinator.openSheet(.humanWeight(human.id))
            return
        }

        guard let pet = targetPet(for: quest) else {
            openTodayFocusQuest(quest)
            return
        }

        switch todayFocusPetQuickKey(for: quest, pet: pet) {
        case "feed", "water", "walk", "play":
            performPetQuickAction(todayFocusPetQuickKey(for: quest, pet: pet), petID: pet.id)
        case "potty":
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "potty")) {
                commandExecutor.applyPottyCheckIn(
                    raw: PottyType.perfectPoop.rawValue,
                    petID: petID,
                    executorId: currentExecutorId(),
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        case "litter":
            performPetQuickAction("litter", petID: pet.id)
        case "weight", "moment":
            openPetQuickKey(todayFocusPetQuickKey(for: quest, pet: pet), pet: pet)
        default:
            openTodayFocusQuest(quest)
        }
    }

    private func openTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        if let petId = signal.petId,
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            switch signal.healthAlertType {
            case .some(.weightGainAlert), .some(.weightLossAlert):
                routeCoordinator.openSheet(.petWeight(pet.id))
            case .some(.drinkingWeightAlert):
                routeCoordinator.openSheet(.petWater(pet.id))
            case .some(.noPotty):
                routeCoordinator.openSheet(.petPotty(pet.id))
            case .some(.noWalk):
                routeCoordinator.openSheet(.petWalkSummary(pet.id))
            case .some(.documentExpiringSoon):
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            default:
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: .preventive))
            }
            return
        }

        if signal.iconName.contains("fork.knife"),
           let pet = pets.first(where: { signal.title.contains($0.name) && !$0.hasPassedAway }) {
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
            return
        }

        if signal.iconName.contains("drop"),
           let pet = pets.first(where: { signal.title.contains($0.name) && !$0.hasPassedAway }) {
            routeCoordinator.openSheet(.petWater(pet.id))
            return
        }

        if signal.iconName.contains("triangle"),
           let pet = pets.first(where: { signal.title.contains($0.name) && !$0.hasPassedAway }) {
            routeCoordinator.openSheet(.petPotty(pet.id))
            return
        }

        routeCoordinator.openFunctionMenu(destination: .featureGroup(.healthBody))
    }

    private func openTodayFocusFamilyTask(_ task: FamilyCollaborationTask) {
        routeCoordinator.openCrewRoster(mode: .collaboration)
    }

    private func confirmTodayFocusExchange(_ request: CoconutExchangeRequest) {
        guard let receiver = activeHuman else {
            routeCoordinator.openAccountSwitcher()
            return
        }
        let requestID = request.id
        let receiverID = receiver.id
        OhanaFeedback.light()
        enqueueHomeCommand(.coconutExchange(requestID: requestID)) {
            do {
                try commandExecutor.confirmCoconutExchange(requestID: requestID, receiverID: receiverID)
                applyTodayFocusMutationFeedback(entityId: requestID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                routeCoordinator.openCoconutLog(.human(receiverID))
            }
        }
    }

    private func openTodayFocusOasisQuest(_ quest: IslandQuest) -> Bool {
        guard IslandQuestEngine.isOasisBuildQuest(quest.id) else { return false }
        switch quest.id {
        case IslandQuestEngine.oasisPetWizardQuestId:
            routeCoordinator.openAddEntity(humans.isEmpty ? .human : .pet)
        case IslandQuestEngine.oasisFirstMealQuestId:
            if let pet = pets.first(where: { !$0.hasPassedAway }) {
                routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
            } else {
                routeCoordinator.openAddEntity(.pet)
            }
        case IslandQuestEngine.oasisThemeQuestId:
            routeCoordinator.openCrewRoster()
        default:
            selectTab(.oasis)
        }
        return true
    }

    private func eventDestination(for quest: IslandQuest) -> FocusHomeReminderDestination? {
        guard let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
              let event = allEvents.first(where: { $0.id == eventId }) else {
            return nil
        }
        return FocusHomeReminderDeepLinkRouter.destination(
            for: event,
            pets: pets,
            humans: humans,
            plants: plants,
            humanMedications: humanMedications
        )
    }

    private func petMedicationTarget(_ medicationId: UUID) -> (pet: Pet, medication: PetMedication)? {
        for pet in pets where !pet.hasPassedAway {
            if let medication = pet.medications.first(where: { $0.id == medicationId }) {
                return (pet, medication)
            }
        }
        return nil
    }

    private func targetPet(for quest: IslandQuest) -> Pet? {
        if let targetPetId = quest.targetPetId,
           let pet = pets.first(where: { $0.id == targetPetId && !$0.hasPassedAway }) {
            return pet
        }
        if quest.id == "q_walk" || quest.id == "q_potty" {
            return pets.first(where: { !$0.hasPassedAway })
        }
        return nil
    }

    private func targetPlant(for quest: IslandQuest) -> Plant? {
        if let targetPlantId = quest.targetPlantId {
            return plants.first(where: { $0.id == targetPlantId })
        }
        switch quest.id {
        case "q_water_plant":
            return plants.first(where: { $0.needsWatering })
        case "q_fertilize_plant":
            return plants.first(where: { $0.needsFertilizing })
        default:
            return nil
        }
    }

    private func openTodayFocusPlant(_ plant: Plant) {
        onOpenPlant(plant.id)
    }

    private func todayFocusPetQuickKey(for quest: IslandQuest, pet: Pet) -> String {
        if quest.id.hasPrefix("q_feed_") { return "feed" }
        if quest.id.hasPrefix("q_water_") { return "water" }
        if quest.id == "q_walk" { return "walk" }
        if quest.id == "q_potty" {
            return pet.species.contains("猫") || pet.species.contains("兔") ? "litter" : "potty"
        }
        if quest.id.hasPrefix("q_play_") { return "play" }
        if quest.id.hasPrefix("q_weight_") { return "weight" }
        if quest.id.hasPrefix("q_moment_") { return "moment" }
        return "basic"
    }

    private func applyTodayFocusMutationFeedback(entityId: UUID) {
        applyQuickActionExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: entityId,
                coconutDelta: 0,
                label: nil
            )
        )
        let pending = controller.snapshot.todayFocus.refreshedQuests.filter { !$0.isCompleted }
        if pending.count == 1,
           let finalQuest = pending.first,
           TodayFocusService.quest(finalQuest, matchesCompletedEntity: entityId) {
            TodayFocusEconomyService.awardDailyCompletionIfNeeded(
                context: modelContext,
                executorId: currentExecutorId()
            )
        }
    }

    private func openHeaderCoconutDestination() {
        if let card = headerContextCard {
            if card.isHuman, humans.contains(where: { $0.id == card.id }) {
                routeCoordinator.openCoconutLog(.human(card.id))
                return
            }
            if pets.contains(where: { $0.id == card.id }) {
                routeCoordinator.openCoconutLog(.pet(card.id))
                return
            }
        }
        if let human = activeHuman {
            routeCoordinator.openCoconutLog(.human(human.id))
        }
    }

    private func openQuickActionItem(_ item: QuickActionItem, card: FocusCard, usesPrimaryAction: Bool) {
        OhanaFeedback.light()
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            openHumanQuickActionItem(item, human: human, usesPrimaryAction: usesPrimaryAction)
            return
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            openCard(card)
            return
        }
        openPetQuickActionItem(item, pet: pet, usesPrimaryAction: usesPrimaryAction)
    }

    private func openQuickActionOption(_ item: QuickActionItem, card: FocusCard, optionId: String) {
        guard !card.isHuman,
              let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return
        }

        switch item.actionType {
        case "groom":
            OhanaFeedback.light()
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "groom:\(optionId)")) {
                commandExecutor.applyGroomCheckIn(
                    raw: optionId,
                    petID: petID,
                    executorId: currentExecutorId(),
                    showSingleUseNotice: { title, message in
                        routeCoordinator.showSingleUseNotice(title: title, message: message)
                    },
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        case "potty":
            OhanaFeedback.light()
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "potty:\(optionId)")) {
                commandExecutor.applyPottyCheckIn(
                    raw: optionId,
                    petID: petID,
                    executorId: currentExecutorId(),
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        case "health":
            OhanaFeedback.light()
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "health:\(optionId)")) {
                commandExecutor.applyHealthCheckIn(
                    raw: optionId,
                    petID: petID,
                    executorId: currentExecutorId(),
                    openHealth: { routeCoordinator.openSheet(.petHealth($0, initialSection: nil)) },
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        default:
            openPetQuickActionItem(item, pet: pet, usesPrimaryAction: true)
        }
    }

    private func openPetQuickActionItem(_ item: QuickActionItem, pet: Pet, usesPrimaryAction: Bool) {
        if usesPrimaryAction {
            switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
            case let .perform(actionType):
                performPetQuickAction(actionType, petID: pet.id)
            case .waterManagement:
                routeCoordinator.openSheet(.petWater(pet.id))
            case .weight:
                routeCoordinator.openSheet(.petWeight(pet.id))
            case .expense:
                routeCoordinator.openSheet(.petExpense(pet.id))
            case .moment:
                routeCoordinator.openQuickMoment(pet)
            case .health:
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
            case .none:
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            }
            return
        }

        switch ExpandedQuickActionLogic.petLongPressRoute(for: item) {
        case .feedDetail:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .waterManagement:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .walk:
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .playDetail:
            routeCoordinator.openSheet(.petPlay(pet.id))
        case .pottyDetail:
            routeCoordinator.openSheet(.petPotty(pet.id))
        case .hygiene:
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medication:
            routeCoordinator.openSheet(.petMedication(pet.id))
        case .weightDetail:
            routeCoordinator.openSheet(.petWeight(pet.id))
        case .expenseDetail:
            routeCoordinator.openSheet(.petExpense(pet.id))
        case .momentHistory:
            routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .none:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func performPetQuickAction(_ actionType: String, petID: UUID) {
        enqueueHomeCommand(.quickCare(entityID: petID, action: actionType)) {
            commandExecutor.performActionType(
                actionType,
                petID: petID,
                executorId: currentExecutorId(),
                now: Date(),
                antiRepeatTitle: l.tr(zh: "刚刚已经记录过", en: "Already logged", de: "Bereits erfasst"),
                antiRepeatMessage: { warning in
                    l.tr(
                        zh: "\(warning.executorName) \(warning.minutesAgo)分钟前刚记录过，确定再记一次吗？",
                        en: "\(warning.executorName) logged this \(warning.minutesAgo)m ago. Log again?",
                        de: "\(warning.executorName) hat das vor \(warning.minutesAgo) Min. erfasst. Erneut erfassen?"
                    )
                },
                openFeedDetail: { routeCoordinator.openSheet(.petFeed($0, opensManualSheet: $1)) },
                showAntiRepeat: { title, message, pendingAction in
                    routeCoordinator.showAntiRepeat(
                        title: title,
                        message: message,
                        pendingAction: pendingAction
                    )
                },
                startWalk: { routeCoordinator.openFullScreen(.walk($0)) },
                openWaterManagement: { routeCoordinator.openSheet(.petWater($0)) },
                openMedication: { routeCoordinator.openSheet(.petMedication($0)) },
                feedback: applyQuickActionExecutorFeedback
            )
        }
    }

    private func applyQuickActionExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        refreshHeaderStreak()
        if feedback.coconutDelta > 0 {
            OhanaFeedback.success()
        }
    }

    private func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    private func openHumanQuickActionItem(_ item: QuickActionItem, human: Human, usesPrimaryAction: Bool) {
        let viewedBy = UUID(uuidString: activeHumanIdRaw)
        let isLocked = PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: viewedBy)
        let route = usesPrimaryAction
            ? ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: isLocked)
            : ExpandedQuickActionLogic.humanLongPressRoute(actionType: item.actionType, isLocked: isLocked)

        switch route {
        case .weightQuick, .weightDetail:
            routeCoordinator.openSheet(.humanWeight(human.id))
        case .workoutQuick, .workoutDetail:
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case .medicationAdd, .medicationDetail:
            routeCoordinator.openSheet(.humanMedication(human.id))
        case .noteQuick, .noteDetail:
            routeCoordinator.openSheet(.humanNote(human.id))
        case .expenseQuick, .expenseDetail:
            routeCoordinator.openSheet(.humanExpense(human.id))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        case .privacyAlert:
            routeCoordinator.showHumanPrivacy()
        case .none:
            break
        }
    }

    private func expandedFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman {
            guard let human = humans.first(where: { $0.id == card.id }) else {
                return FocusHomeFabShortcutPolicy.humanShortcuts(localization: l)
            }
            return FocusHomeFabShortcutPolicy.humanShortcuts(
                for: human,
                displayedItems: expandedHumanQuickActionItems(for: human),
                localization: l
            )
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return [
                ExpandedCardFabShortcut(
                    label: l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"),
                    icon: "ellipsis.circle.fill",
                    action: .allFeatures
                ),
            ]
        }
        return FocusHomeFabShortcutPolicy.petShortcuts(
            for: pet,
            displayedItems: expandedQuickActionItems(for: pet),
            localization: l
        )
    }

    private func expandedQuickActionItems(for pet: Pet) -> [QuickActionItem] {
        stableQuickActionItems(
            ExpandedQuickActionStore.petItems(
                raw: quickActionItemsRaw,
                pet: pet,
                localization: l,
                waterLabel: l.homeQAWater,
                managementLabel: waterManagementLabel
            ),
            entityID: pet.id,
            kind: .pet
        )
    }

    private func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        stableQuickActionItems(
            ExpandedQuickActionStore.humanItems(
                raw: quickActionItemsRaw,
                human: human,
                localization: l
            ),
            entityID: human.id,
            kind: .human
        )
    }

    private func stableQuickActionItems(_ items: [QuickActionItem], entityID: UUID, kind: EntityKind) -> [QuickActionItem] {
        items.map { item in
            var stableItem = item
            stableItem.id = "\(kind.rawValue)-\(entityID.uuidString)-\(item.actionType)"
            return stableItem
        }
    }

    private var waterManagementLabel: String {
        l.tr(zh: "管理", en: "Manage", de: "Verwalten")
    }

    private func openExpandedFabShortcut(_ shortcut: ExpandedCardFabShortcut, card: FocusCard) {
        closeVerticalFabMenu(immediate: true)
        FocusHomeExpandedFabRouter.open(
            shortcut,
            card: card,
            pets: pets,
            humans: humans,
            activeHumanId: UUID(uuidString: activeHumanIdRaw),
            actions: FocusHomeExpandedFabRouter.Actions(
                showPetAllFeatures: { routeCoordinator.openSheet(.petAllFeatures($0.id)) },
                showHumanAllFeatures: { routeCoordinator.openSheet(.humanAllFeatures($0.id)) },
                openFeed: { routeCoordinator.openSheet(.petFeed($0.id, opensManualSheet: false)) },
                openWater: { routeCoordinator.openSheet(.petWater($0.id)) },
                openWalk: { routeCoordinator.openSheet(.petWalkSummary($0.id)) },
                openPotty: { routeCoordinator.openSheet(.petPotty($0.id)) },
                openPlay: { routeCoordinator.openSheet(.petPlay($0.id)) },
                openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) },
                openHygiene: { routeCoordinator.openSheet(.petHygiene($0.id)) },
                openMoment: { routeCoordinator.openQuickMoment($0) },
                openHealth: { routeCoordinator.openSheet(.petHealth($0.id, initialSection: nil)) },
                openWeight: { routeCoordinator.openSheet(.petWeight($0.id)) },
                openExpense: { routeCoordinator.openSheet(.petExpense($0.id)) },
                showHumanWeight: { routeCoordinator.openSheet(.humanWeight($0.id)) },
                showHumanWorkout: { routeCoordinator.openSheet(.humanWorkout($0.id)) },
                showHumanMedication: { routeCoordinator.openSheet(.humanMedication($0.id)) },
                showHumanNote: { routeCoordinator.openSheet(.humanNote($0.id)) },
                quickHumanExpense: { routeCoordinator.openSheet(.humanExpense($0.id)) },
                showPrivacyAlert: { routeCoordinator.showHumanPrivacy() }
            )
        )
    }

    private func openPetQuickKey(_ key: String, pet: Pet) {
        switch key {
        case "feed":
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case "water", "waterChange", "filterClean":
            routeCoordinator.openSheet(.petWater(pet.id))
        case "potty":
            routeCoordinator.openSheet(.petPotty(pet.id))
        case "litter":
            routeCoordinator.openSheet(.petLitter(pet.id))
        case "walk":
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case "play":
            routeCoordinator.openSheet(.petPlay(pet.id))
        case "health":
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case "medication":
            routeCoordinator.openSheet(.petMedication(pet.id))
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case "weight":
            routeCoordinator.openSheet(.petWeight(pet.id))
        case "expense":
            routeCoordinator.openSheet(.petExpense(pet.id))
        case "moment":
            routeCoordinator.openQuickMoment(pet)
        default:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openCalendarEventDestination(_ destination: FocusHomeReminderDestination) {
        routeCoordinator.dismissModal()
        openCalendarEventDestinationAfterDismiss(destination)
    }

    private func openCalendarEventDestinationAfterDismiss(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            openPetQuickKey(key, pet: pet)
        case let .petFeature(feature, pet):
            openPetFeature(feature, pet: pet)
        case let .petHealth(pet, section):
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, human: human)
        case let .humanDetail(human):
            routeCoordinator.openSheet(.humanBasicInfo(human.id))
        case .plant:
            AppFeatureRouteGuard.recordIntercept("homeReminderPlant")
            routeCoordinator.openFunctionMenu(destination: .growthRoadmap)
        case let .functionMenu(destination):
            routeCoordinator.openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId):
            routeCoordinator.openCalendar(entityID: entityId, humanID: humanId)
        }
    }

    private func openPetFeature(_ feature: PetFeature, pet: Pet) {
        switch feature {
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medications:
            routeCoordinator.openSheet(.petMedication(pet.id))
        case .food:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .hygiene:
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case .walks:
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .potty:
            routeCoordinator.openSheet(.petPotty(pet.id))
        case .basicInfo:
            routeCoordinator.openSheet(.petBasicInfo(pet.id))
        case .moments:
            routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .weight:
            routeCoordinator.openSheet(.petWeight(pet.id))
        case .expense:
            routeCoordinator.openSheet(.petExpense(pet.id))
        case .retention, .documents, .achievements:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openHumanQuickKey(_ key: String, human: Human) {
        switch key {
        case "humanWeight":
            routeCoordinator.openSheet(.humanWeight(human.id))
        case "humanWorkout":
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case "humanMedication":
            routeCoordinator.openSheet(.humanMedication(human.id))
        case "humanExpense":
            routeCoordinator.openSheet(.humanExpense(human.id))
        case "humanNote":
            routeCoordinator.openSheet(.humanNote(human.id))
        default:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        }
    }

    private func closeVerticalFabMenu(immediate: Bool) {
        guard fabExpanded || fabMenuItemsVisible else { return }
        if immediate || !canAnimate {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                fabMenuItemsVisible = false
                fabExpanded = false
            }
            return
        }

        withAnimation(HeroAnim.fabSpring) {
            fabMenuItemsVisible = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            guard !fabMenuItemsVisible else { return }
            withAnimation(HeroAnim.fabSpring) {
                fabExpanded = false
            }
        }
    }

    private func refreshHeaderStreak() {
        headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdRaw)
    }

    private static func todayFocusVisualProgress(cardHeroProgress: CGFloat) -> CGFloat {
        let visible = min(max(1 - cardHeroProgress, 0), 1)
        return visible * visible * (3 - 2 * visible)
    }

    private static func growthLoopPendingCount(from snapshot: TodayFocusSnapshot) -> Int {
        let pendingQuests = snapshot.refreshedQuests.filter { !$0.isCompleted }.count
        return pendingQuests
            + snapshot.assignedFamilyTasks.count
            + snapshot.pendingExchangeRequests.count
            + snapshot.negativeSignals.count
    }

    private func preloadFirstScreenAvatars() async {
        let payloads = avatarPreloadPayloads()
        let popoutPayloads = popoutPreloadPayloads()
        guard !payloads.isEmpty || !popoutPayloads.isEmpty else { return }
        if avatarPipeline.seedPreviewEntries(payloads) {
            bumpAvatarCacheRevision()
        }
        avatarPipeline.preload(
            payloads: payloads,
            popoutPayloads: popoutPayloads,
            key: avatarPreloadSignature
        )
    }

    private func bumpAvatarCacheRevision() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            avatarCacheRevision += 1
        }
    }

    private func avatarPreloadPayloads() -> [FocusWalletAvatarCache.Payload] {
        payload.avatarPreloadPayloads
    }

    private func popoutPreloadPayloads() -> [FocusWalletAvatarCache.Payload] {
        payload.popoutPreloadPayloads
    }

    private func enqueueHomeCommand(
        _ command: DomainCommand,
        operation: @escaping @MainActor () -> Void
    ) {
        commandQueue.enqueue(command) {
            let previousMutationID = ReadModelRevisionCenter.shared.lastMutation?.id
            operation()
            guard let mutation = ReadModelRevisionCenter.shared.lastMutation,
                  mutation.id != previousMutationID,
                  mutation.wroteBusinessFact else {
                return
            }
            scheduleGrowthLoopSync(after: mutation)
        }
    }
}
