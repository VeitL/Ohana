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
    let onCreatedEntitySignalHandled: (HomeCreatedEntitySignal) -> Void
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
    let cardStateResetToken: UUID

    let payload: HomeReadModelPayload

    @StateObject var controller: VerticalSolidHomeController
    @StateObject var safeAreaController = FocusHomeSafeAreaController()
    @StateObject var routeCoordinator = HomeRouteCoordinator()
    @StateObject var commandQueue = DeferredDomainCommandQueue()

    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") var showDummyCards = false
    @AppStorage("ohana_has_onboarded") var hasOnboarded = false
    @AppStorage(StarterGiftStorageKey.ceremonySeen) var starterGiftCeremonySeen = false
    @AppStorage(StarterGiftStorageKey.oasisTabPromptPending) var starterOasisTabPromptPending = false
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
    @State var plantBottomChromeHidden = false
    @State var calendarBottomChromeHidden = false
    @State var calendarAddEventTrigger = 0
    @State var embeddedCalendarPreselectedPetId: String?
    @State var embeddedCalendarPreselectedHumanId: String?
    @State var isCalendarAddEventPresented = false
    @State var calendarAddEventProgress: CGFloat = 0
    @State var embeddedCalendarPlants: [Plant] = []
    @State var calendarAddEventPlants: [Plant] = []
    @State var isCalendarAddEventContentMounted = false
    @State var calendarAddEventPresentationTask: Task<Void, Never>?
    @State var calendarAddEventContentMountTask: Task<Void, Never>?
    @State var oasisInjectEnergyTrigger = 0
    @State var oasisEnergyInjectionTask: Task<Void, Never>?
    @State var pendingOasisEnergyInjectionCount = 0
    @State var avatarCacheRevision = 0
    @State var headerStreak = 0
    @State var isHomeCardExpandedOrTransitioning = false
    @State var isHomeCardHeroAnimating = false
    @State var homeCardHeroProgress: CGFloat = 0
    @State var arrivingHomeCardId: UUID?
    @State var arrivingPlantCardId: UUID?
    @State var arrivalClearTask: Task<Void, Never>?
    @State var plantArrivalClearTask: Task<Void, Never>?
    var treeManager: OasisTreeManaging { appServices.oasisTree }
    @State var showGrowthOnboarding = false
    @State var growthOnboardingTask: Task<Void, Never>?
    @State var growthUnlockToastStatus: GrowthUnlockStatus?
    @State var growthUnlockToastPresentationTask: Task<Void, Never>?
    @State var growthUnlockToastDismissTask: Task<Void, Never>?
    @State var growthLoopPulseStatus: GrowthLoopPulseStatus?
    @State var growthLoopSyncTask: Task<Void, Never>?
    @State var growthLoopPulseDismissTask: Task<Void, Never>?
    @State var todayFocusDailyCompletionTask: Task<Void, Never>?
    @State var snapshotRefreshGate = HomeSnapshotRefreshGate()
    @State var homeAppearHandoffTask: Task<Void, Never>?
    @State var memberMediaAttachmentIndexRepairTask: Task<Void, Never>?
    @State var handledCreatedEntityToken: UUID?
    @State var walkCardPresentationRevision = 0

    init(
        onOpenPet: @escaping (UUID, PetDetailTab) -> Void,
        onOpenHuman: @escaping (UUID) -> Void,
        onOpenPlant: @escaping (UUID) -> Void,
        createdEntitySignal: HomeCreatedEntitySignal?,
        onCreatedEntitySignalHandled: @escaping (HomeCreatedEntitySignal) -> Void = { _ in },
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
        cardStateResetToken: UUID,
        payload: HomeReadModelPayload
    ) {
        self.onOpenPet = onOpenPet
        self.onOpenHuman = onOpenHuman
        self.onOpenPlant = onOpenPlant
        self.createdEntitySignal = createdEntitySignal
        self.onCreatedEntitySignalHandled = onCreatedEntitySignalHandled
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
        self.cardStateResetToken = cardStateResetToken
        self.payload = payload
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
        "\(payload.signature)#revision:\(payload.revision.value)#today:\(payload.snapshot.todayFocus.dayToken)"
    }

    var interaction: HomeInteractionSnapshot {
        payload.interaction
    }

    var avatarPreloadSignature: String {
        [
            payload.avatarPreloadSignature,
            payload.popoutPreloadSignature
        ].joined(separator: "||popout:")
    }

    var activeHumanDisplayName: String {
        interaction.activeHuman?.name ?? controller.snapshot.activeName
    }

    var activeHumanAvatarEmoji: String? {
        interaction.activeHuman?.avatarEmoji
    }

    var islandCoconutBalance: Int {
        interaction.islandCoconutBalance
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
        headerContextCard?.coconutBalance ?? islandCoconutBalance
    }

    var headerCoconutDeltaContext: String {
        if let card = headerContextCard {
            return "card-\(card.id.uuidString)"
        }
        return "island"
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
            let todayFocusHeight = min(
                TodayFocusCardLayout.homeChromeMaxHeight,
                max(TodayFocusCardLayout.homeChromeMinHeight, proxy.size.height * TodayFocusCardLayout.homeChromeHeightRatio)
            )
            let focusHeight = todayFocusHeight
            let contentTopGap: CGFloat = 4
            let compactContentGap: CGFloat = 8
            let isHomeTabVisible = controller.selectedTab == .home
            let cardHeroProgress = min(max(homeCardHeroProgress, 0), 1)
            let todayFocusVisualProgress = Self.todayFocusVisualProgress(cardHeroProgress: cardHeroProgress)
            let isWaitingForArrivingCardSnapshot = arrivingHomeCardId.map { arrivingID in
                !controller.snapshot.cards.contains { $0.id == arrivingID }
            } ?? false
            let shouldSuppressTodayFocusDuringArrival = isWaitingForArrivingCardSnapshot &&
                controller.snapshot.firstPetEmptyState != nil
            let shouldMountTodayFocusChrome = isHomeTabVisible &&
                !shouldSuppressTodayFocusDuringArrival &&
                todayFocusVisualProgress > 0.001
            let isTodayFocusInteractive = isHomeTabVisible &&
                !shouldSuppressTodayFocusDuringArrival &&
                !isHomeCardExpandedOrTransitioning &&
                !isHomeCardHeroAnimating &&
                todayFocusVisualProgress > 0.98
            let todayFocusHorizontalOffset = -CGFloat(controller.selectedTab.index) * proxy.size.width
            let compactTopChromeHeight = safeTop + headerTopGap + headerContentHeight + compactContentGap
            let homeCollapsedTopInset = max(0, focusTopGap + focusHeight + contentTopGap - compactContentGap)
            let topChromeHeight = compactTopChromeHeight
            let bottomHeight = max(84, safeBottom + 70)
            let contentHeight = VerticalSolidHomePageContentHeightPolicy.height(
                selectedTab: controller.selectedTab,
                containerHeight: proxy.size.height,
                topChromeHeight: topChromeHeight,
                bottomChromeHeight: bottomHeight
            )
            let bottomChromeHidden = (plantBottomChromeHidden && controller.selectedTab == .plants)
                || (calendarBottomChromeHidden && controller.selectedTab == .calendar)

            ZStack(alignment: .top) {
                OhanaAppBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VerticalSolidHomePageDeck(
                    selectedTab: controller.selectedTab,
                    outgoingTab: controller.outgoingTab,
                    preparingTab: controller.preparingTab,
                    preparedTabs: controller.preparedTabs,
                    visibleTabs: AppFeatureRouteGuard.visibleHomeTabs(currentLevel: treeManager.treeLevel.rawValue),
                    canAnimate: canAnimate
                ) { lifecycle in
                    VerticalSolidHomeDashboardPage(
                        snapshot: controller.snapshot,
                        interaction: interaction,
                        avatarCacheRevision: avatarCacheRevision + avatarPipeline.revision,
                        isLive: lifecycle.isLive,
                        walkPresentationRevision: walkCardPresentationRevision,
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
                        cardStateResetToken: cardStateResetToken,
                        onOpenCardDetails: openCard,
                        onQuickActionForCard: openQuickActionItem,
                        onQuickActionOptionForCard: openQuickActionOption,
                        onQuickActionLimitReached: { routeCoordinator.showQuickActionLimit() },
                        onExpandedCardCollapseIntent: dismissExpandedFabBeforeCardCollapse,
                        onWalkCardMinimizeToFloatingControl: minimizeWalkCardToFloatingControl,
                        onAddFirstPet: { routeCoordinator.openAddEntity(.pet) }
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
                        onPlantsLoaded: { plants in
                            embeddedCalendarPlants = plants
                        },
                        onEmbeddedScrollOffsetChange: updateCalendarBottomChromeVisibility,
                        onOpenEventDestination: openCalendarEventDestination,
                        onPresentCoconutLog: { subject in
                            onPresentCoconutLog(subject)
                        }
                    )
                    .padding(.top, 4)
                } oasis: { lifecycle in
                    let treeLevel = treeManager.treeLevel.rawValue
                    let shopUnlockLevel = GrowthUnlockPolicy.status(for: FMDest.coconutShop, currentLevel: 0).step.requiredLevel
                    let gachaUnlockLevel = GrowthUnlockPolicy.status(for: FMDest.gacha, currentLevel: 0).step.requiredLevel
                    let critterUnlockLevel = OasisUpgradeRewardCatalog.critter(id: OasisUpgradeRewardCatalog.firstCritterId)?.sourceLevel ?? 10
                    let shopInitialCategory: ShopItem.ShopCategory = treeLevel >= 5 ? .plantDecor : .effect

                    OasisHomeTabHost(
                        lifecycle: lifecycle,
                        treeSnapshot: OasisTreeRenderSnapshot(
                            level: treeLevel,
                            progressToNextLevel: treeManager.progressToNextLevel,
                            totalEnergy: treeManager.totalEnergy,
                            nextLevelThreshold: treeManager.nextLevelThreshold,
                            shopLockedLevel: treeLevel >= shopUnlockLevel ? nil : shopUnlockLevel,
                            shopInitialCategory: shopInitialCategory,
                            crittersLockedLevel: treeLevel >= critterUnlockLevel ? nil : critterUnlockLevel,
                            gachaLockedLevel: treeLevel >= gachaUnlockLevel ? nil : gachaUnlockLevel
                        ),
                        injectEnergyTrigger: oasisInjectEnergyTrigger,
                        onPresentCoconutLog: onPresentCoconutLog,
                        onOpenShop: { category in
                            routeCoordinator.openCoconutShop(category, currentLevel: treeLevel)
                        }
                    )
                } plants: { _ in
                    VerticalSolidHomePlantsPage(
                        plants: controller.snapshot.plants,
                        localization: l,
                        hidesBottomChrome: $plantBottomChromeHidden,
                        topChromeHeight: topChromeHeight,
                        bottomChromeHeight: bottomHeight,
                        arrivingPlantCardId: arrivingPlantCardId,
                        onOpenPlant: openPlant,
                        onQuickAction: { plant, action in
                            performPlantQuickAction(action, plant: plant)
                        },
                        onAddPlant: { routeCoordinator.openAddEntity(.plant) }
                    )
                }
                .frame(width: proxy.size.width, height: contentHeight)
                .position(x: proxy.size.width / 2, y: topChromeHeight + contentHeight / 2)

                if controller.preparedTabs.contains(.home), shouldMountTodayFocusChrome {
                    VerticalSolidHomeTodayFocusChrome(
                        snapshot: controller.snapshot.todayFocus,
                        isLive: isTodayFocusInteractive,
                        onOpenOasis: { selectTab(.oasis) },
                        onOpenQuest: openTodayFocusQuest,
                        onCompleteQuest: completeTodayFocusQuest,
                        onTapNegativeSignal: openTodayFocusNegativeSignal,
                        onTapFamilyTask: openTodayFocusFamilyTask,
                        onOpenExchange: openTodayFocusExchange,
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
                }

                FocusHomeHeaderView(
                    safeTop: safeTop,
                    topGap: headerTopGap,
                    contentHeight: headerContentHeight,
                    streak: headerStreak,
                    coconutBalance: headerCoconutBalance,
                    coconutDeltaContext: headerCoconutDeltaContext,
                    activeHumanDisplayName: activeHumanDisplayName,
                    activeHumanAvatarImage: activeHumanAvatarImage,
                    activeHumanAvatarEmoji: activeHumanAvatarEmoji,
                    onStreak: { routeCoordinator.openStreakDetail() },
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
                    plantShortcuts: HomeFabShortcutCatalog.plantShortcuts(l: l),
                    expandedShortcuts: expandedBottomBarShortcuts,
                    safeBottom: safeBottom,
                    treeLevel: treeManager.treeLevel.rawValue,
                    treeProgress: treeManager.progressToNextLevel,
                    canAnimate: canAnimate,
                    localization: l,
                    onSelect: selectTab,
                    onHomeShortcut: openHomeFabShortcut,
                    onExpandedShortcut: openExpandedFabShortcut,
                    onCenter: centerAction
                )
                .offset(y: bottomChromeHidden ? max(126, safeBottom + 108) : 0)
                .opacity(bottomChromeHidden ? 0 : 1)
                .allowsHitTesting(!bottomChromeHidden)
                .accessibilityHidden(bottomChromeHidden)
                .animation(canAnimate ? GoMotion.page : GoMotion.reduced, value: bottomChromeHidden)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .zIndex(9)

                if shouldShowStarterOasisTabPrompt {
                    StarterOasisTabPromptView(localization: l)
                        .padding(.horizontal, 18)
                        .padding(.bottom, max(146, safeBottom + 128))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(12)
                }

                if isCalendarAddEventPresented || calendarAddEventProgress > 0.001 {
                    OhanaDeferredInlinePageCover(
                        progress: calendarAddEventProgress,
                        isContentMounted: isCalendarAddEventContentMounted,
                        reservesSafeArea: false
                    ) {
                        AddEventView(onClose: closeCalendarAddEvent, plants: calendarAddEventPlants)
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
                    GrowthUnlockPopupView(
                        status: growthUnlockToastStatus,
                        appLanguage: appLanguage,
                        onDismiss: dismissGrowthUnlockToast,
                        onOpen: {
                            openGrowthUnlockDestination(growthUnlockToastStatus)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96)))
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
            scheduleHomeAppearHandoff()
            scheduleMemberMediaAttachmentIndexRepair()
            handleCreatedEntitySignalIfNeeded(createdEntitySignal)
        }
        .onChange(of: dataSignature) { _, _ in
            if !interaction.petsByID.isEmpty || !interaction.humansByID.isEmpty {
                cancelGrowthOnboardingPrompt()
            }
            requestHomeSnapshotRefresh()
        }
        .onChange(of: controller.snapshot.todayFocus.refreshedQuests) { previous, current in
            scheduleTodayFocusDailyCompletionIfCleared(previousQuests: previous, currentQuests: current)
        }
        .onChange(of: isHomeCardHeroAnimating) { _, isAnimating in
            flushDeferredHomeSnapshotRefreshIfNeeded(isAnimating: isAnimating)
        }
        .task(id: avatarPreloadSignature) {
            await preloadFirstScreenAvatars()
        }
        .onDisappear {
            homeAppearHandoffTask?.cancel()
            homeAppearHandoffTask = nil
            clearArrivalState()
            calendarAddEventPresentationTask?.cancel()
            calendarAddEventContentMountTask?.cancel()
            growthOnboardingTask?.cancel()
            growthUnlockToastPresentationTask?.cancel()
            growthUnlockToastDismissTask?.cancel()
            growthLoopSyncTask?.cancel()
            growthLoopPulseDismissTask?.cancel()
            todayFocusDailyCompletionTask?.cancel()
            memberMediaAttachmentIndexRepairTask?.cancel()
            oasisEnergyInjectionTask?.cancel()
            pendingOasisEnergyInjectionCount = 0
            todayFocusDailyCompletionTask = nil
            memberMediaAttachmentIndexRepairTask = nil
            growthLoopPulseStatus = nil
            avatarPipeline.cancel(key: avatarPreloadSignature)
            commandQueue.cancelAll()
            snapshotRefreshGate.cancel()
            controller.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                requestTodayFocusRefreshIfDayChanged()
            } else {
                clearArrivalState()
            }
        }
        .onChange(of: createdEntitySignal) { _, signal in
            handleCreatedEntitySignalIfNeeded(signal)
        }
        .focusHomeRouteSheets(
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
            onPlantSavedFromAddEntity: { plantID in
                handleNewHomePlantSaved(id: plantID)
            },
            onCrewPetSelected: { pet in
                onOpenPet(pet.id, .overview)
            },
            onCrewHumanSelected: { human in
                onOpenHuman(human.id)
            },
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { _ in },
            onStartWalkFromQuickAction: { petID in
                startWalkFromQuickAction(petID: petID)
            }
        )
        .onChange(of: activeHumanIdRaw) { _, _ in
            refreshHeaderStreak()
        }
        .onChange(of: controller.selectedTab) { _, _ in
            closeVerticalFabMenu(immediate: true)
            if plantBottomChromeHidden {
                withAnimation(canAnimate ? GoMotion.quick : GoMotion.reduced) {
                    plantBottomChromeHidden = false
                }
            }
            if calendarBottomChromeHidden {
                resetCalendarBottomChromeForTabSelection()
            }
        }
        .onChange(of: starterGiftCeremonySeen) { _, _ in
            closeVerticalFabMenu(immediate: true)
        }
        .onReceive(routeCoordinator.$sheet) { sheet in
            if sheet != nil {
                closeVerticalFabMenu(immediate: true)
            }
        }
        .onChange(of: expandedBottomBarCard?.id) { _, _ in
            closeVerticalFabMenu(immediate: true)
        }
        .onChange(of: plantBottomChromeHidden) { _, isHidden in
            if isHidden {
                closeVerticalFabMenu(immediate: false)
            }
        }
        .onChange(of: calendarBottomChromeHidden) { _, isHidden in
            if isHidden {
                closeVerticalFabMenu(immediate: false)
            }
        }
        .onChange(of: treeManager.treeLevel.rawValue) { _, _ in
            scheduleGrowthUnlockFeedbackIfNeeded()
            requestHomeSnapshotRefresh()
        }
    }

    private var shouldShowStarterOasisTabPrompt: Bool {
        starterOasisTabPromptPending &&
            starterGiftCeremonySeen &&
            controller.selectedTab == .home &&
            !isHomeCardExpandedOrTransitioning &&
            !isHomeCardHeroAnimating &&
            AppFeatureRouteGuard.allowsHomeTab(.oasis, currentLevel: treeManager.treeLevel.rawValue)
    }
}
