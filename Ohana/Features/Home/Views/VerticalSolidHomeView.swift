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

    @StateObject var controller: VerticalSolidHomeController
    @StateObject var safeAreaController = FocusHomeSafeAreaController()
    @StateObject var routeCoordinator = HomeRouteCoordinator()
    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @StateObject var expensePreviewStore = HomeExpensePreviewStore()

    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") var showDummyCards = false
    @AppStorage("ohanaGrowthOnboardingCompletedV1") var growthOnboardingCompleted = false
    @AppStorage("ohanaGrowthLastSeenTreeLevelV1") var growthLastSeenTreeLevel = 0
    @AppStorage("quickActionItems_v2") var quickActionItemsRaw = ""
    @AppStorage("home_cards_enable_ambient_float") var enablesHomeCardAmbientFloat = false
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var workloadPolicy = AppWorkloadPolicy.shared
    @ObservedObject var avatarPipeline = AvatarPipelineRegistry.current

    @State var headerContextCardId: UUID?
    @State var fabExpanded = false
    @State var fabMenuItemsVisible = false
    @State var calendarAddEventTrigger = 0
    @State var embeddedCalendarPreselectedPetId: String?
    @State var embeddedCalendarPreselectedHumanId: String?
    @State var isCalendarAddEventPresented = false
    @State var calendarAddEventProgress: CGFloat = 0
    @State var isCalendarAddEventContentMounted = false
    @State var calendarAddEventPresentationTask: Task<Void, Never>?
    @State var calendarAddEventContentMountTask: Task<Void, Never>?
    @State var oasisInjectEnergyTrigger = 0
    @State var avatarCacheRevision = 0
    @State var headerStreak = 0
    @State var isHomeCardExpandedOrTransitioning = false
    @State var isHomeCardHeroAnimating = false
    @State var homeCardHeroProgress: CGFloat = 0
    @State var arrivingHomeCardId: UUID?
    @State var arrivalClearTask: Task<Void, Never>?
    var treeManager: OasisTreeManaging { appServices.oasisTree }
    @State var showGrowthOnboarding = false
    @State var growthOnboardingTask: Task<Void, Never>?
    @State var growthUnlockToastStatus: GrowthUnlockStatus?
    @State var growthUnlockToastPresentationTask: Task<Void, Never>?
    @State var growthUnlockToastDismissTask: Task<Void, Never>?
    @State var growthLoopPulseStatus: GrowthLoopPulseStatus?
    @State var growthLoopSyncTask: Task<Void, Never>?
    @State var growthLoopPulseDismissTask: Task<Void, Never>?
    @State var snapshotRefreshGate = HomeSnapshotRefreshGate()

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
        AvatarPipelineRegistry.current.seedPreviewEntries(
            payload.avatarPreloadPayloads
        )
        _controller = StateObject(
            wrappedValue: VerticalSolidHomeController(
                initialSnapshot: payload.snapshot,
                initialSignature: payload.signature
            )
        )
    }

    var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    var commandExecutor: HomeCommandExecutor {
        HomeCommandExecutor(
            modelContext: modelContext,
            services: appServices
        )
    }

    var l: L10n {
        L10n(appLanguage)
    }

    var activeHumanID: UUID? {
        UUID(uuidString: activeHumanIdRaw)
    }

    var dataSignature: String {
        payload.signature
    }

    var sourceState: VerticalSolidHomeSourceState {
        payload.source
    }

    var pets: [Pet] {
        sourceState.pets
    }

    var humans: [Human] {
        sourceState.humans
    }

    var plants: [Plant] {
        sourceState.plants
    }

    var electronicPets: [OasisElectronicPet] {
        sourceState.electronicPets
    }

    var allEvents: [Event] {
        sourceState.events
    }

    var humanMedications: [HumanMedication] {
        sourceState.humanMedications
    }

    var humanMedicationLogs: [HumanMedicationLog] {
        sourceState.humanMedicationLogs
    }

    var expenseLogs: [PetExpenseLog] {
        expensePreviewStore.expenseLogs
    }

    var avatarPreloadSignature: String {
        [
            payload.avatarPreloadSignature,
            payload.popoutPreloadSignature
        ].joined(separator: "||popout:")
    }

    var activeHuman: Human? {
        sourceState.activeHuman
    }

    var currentCoconutBalance: Int {
        activeHuman?.coconutBalance
            ?? sourceState.humans.reduce(0) { $0 + $1.coconutBalance }
            + sourceState.pets.reduce(0) { $0 + $1.coconutBalance }
    }

    var headerContextCard: FocusCard? {
        guard controller.selectedTab == .home,
              let headerContextCardId else {
            return nil
        }
        return controller.snapshot.cards.first { $0.id == headerContextCardId }
    }

    var expandedBottomBarCard: FocusCard? {
        guard controller.selectedTab == .home,
              isHomeCardExpandedOrTransitioning || homeCardHeroProgress > 0.98,
              let card = headerContextCard,
              !card.isElectronicPet else {
            return nil
        }
        return card
    }

    var expandedBottomBarShortcuts: [ExpandedCardFabShortcut] {
        guard let card = expandedBottomBarCard else { return [] }
        return expandedFabShortcuts(for: card)
    }

    var headerCoconutBalance: Int {
        headerContextCard?.coconutBalance ?? currentCoconutBalance
    }

    var headerCoconutDeltaContext: String {
        if let card = headerContextCard {
            return "card-\(card.id.uuidString)"
        }
        return "current-human-\(activeHuman?.id.uuidString ?? "global")"
    }

    var activeHumanAvatarImage: UIImage? {
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
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
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
}
