//
//  VerticalSolidHomeView.swift
//  Ohana
//
//  Rebuilt home shell with local-first interactions and snapshot handoffs.
//

import SwiftData
import SwiftUI

struct HomeAvatarPreloadTaskKey: Hashable {
    let signature: String
    let canRun: Bool
}

struct VerticalSolidHomeView: View {
    private static let readModelLoadingPresentationDelayMilliseconds: UInt64 = 500

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
    let onPresentHumanWeightQuick: (UUID) -> Void
    let onPresentOasisReward: () -> Void
    let onPresentPetWeightQuick: (UUID) -> Void
    let onPresentQuickMoment: (UUID) -> Void
    let onRequestStarterGiftClaim: () -> Void
    let onPresentSettings: () -> Void
    let onPresentStreakDetail: () -> Void
    let onPresentWalk: (UUID) -> Void
    let cardStateResetToken: UUID

    let payload: HomeReadModelPayload

    @StateObject var controller: VerticalSolidHomeController
    @StateObject var routeCoordinator = HomeRouteCoordinator()
    @StateObject var commandQueue = DeferredDomainCommandQueue()

    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @AppStorage("currentActiveHumanId") var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") var showDummyCards = false
    @AppStorage("ohana_has_onboarded") var hasOnboarded = false
    @AppStorage(StarterGiftStorageKey.claimed) var starterGiftClaimed = false
    @AppStorage(StarterGiftStorageKey.pending) var starterGiftPending = false
    @AppStorage(StarterGiftStorageKey.ceremonySeen) var starterGiftCeremonySeen = false
    @AppStorage(StarterGiftStorageKey.oasisTabPromptPending) var starterOasisTabPromptPending = false
    @AppStorage("ohanaGrowthOnboardingCompletedV1") var growthOnboardingCompleted = false
    @AppStorage("ohanaGrowthLastSeenTreeLevelV1") var growthLastSeenTreeLevel = 0
    @AppStorage("quickActionItems_v2") var quickActionItemsRaw = ""
    @AppStorage("plantQuickActionItems_v1") var plantQuickActionItemsRaw = ""
    @AppStorage(OasisTreePreferenceStore.renderRevisionKey) var oasisTreeRenderRevision = 0
    @AppStorage("home_cards_enable_ambient_float") var enablesHomeCardAmbientFloat = false
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var workloadPolicy = AppWorkloadPolicy.shared

    @State var headerContextCardId: UUID?
    @State var taskCenterBadge = TaskCenterBadgeSnapshot.empty
    @State var calendarAddEventTrigger = 0
    @State var embeddedCalendarPreselectedPetId: String?
    @State var embeddedCalendarPreselectedHumanId: String?
    @State var taskCenterFocusedItemID: String?
    @State var taskCenterFocusedFamilyTaskID: UUID?
    @State var taskCenterFocusRequestID: UUID?
    @State var isCalendarAddEventPresented = false
    @State var embeddedCalendarPlants: [Plant] = []
    @State var calendarAddEventPlants: [Plant] = []
    @State var oasisInjectEnergyTrigger = 0
    @State var oasisEnergyInjectionTask: Task<Void, Never>?
    @State var pendingOasisEnergyInjectionCount = 0
    @State var avatarCacheRevision = 0
    @State var isHomeCardExpandedOrTransitioning = false
    @State var isHomeCardHeroAnimating = false
    @State var homeCardHeroProgress: CGFloat = 0
    @State var arrivingHomeCardId: UUID?
    @State var arrivingPlantCardId: UUID?
    @State var arrivalClearTask: Task<Void, Never>?
    @State var plantArrivalClearTask: Task<Void, Never>?
    @State var pendingPlantQuickCareKeys: Set<String> = []
    @State var completedPlantQuickCareKeys: Set<String> = []
    @State var failedPlantQuickCareKeys: Set<String> = []
    @State var plantQuickCareFeedbackClearTasks: [String: Task<Void, Never>] = [:]
    var treeManager: OasisTreeManaging { appServices.oasisTree }
    @State var showGrowthOnboarding = false
    @State var growthOnboardingTask: Task<Void, Never>?
    @State var growthUnlockToastStatus: GrowthUnlockStatus?
    @State var growthUnlockToastPresentationTask: Task<Void, Never>?
    @State var growthUnlockToastDismissTask: Task<Void, Never>?
    @State var growthLoopPulseStatus: GrowthLoopPulseStatus?
    @State var growthLoopSyncTask: Task<Void, Never>?
    @State var growthLoopPulseDismissTask: Task<Void, Never>?
    @State var pendingActionHumanConfirmation: ActionHumanConfirmationDraft?
    @State var snapshotRefreshGate = HomeSnapshotRefreshGate()
    @State var homeAppearHandoffTask: Task<Void, Never>?
    @State var memberMediaAttachmentIndexRepairTask: Task<Void, Never>?
    @State var handledCreatedEntityToken: UUID?
    @State var walkCardPresentationRevision = 0
    @State private var showsHomeReadModelLoadingOverlay = false

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
        onPresentHumanWeightQuick: @escaping (UUID) -> Void,
        onPresentOasisReward: @escaping () -> Void,
        onPresentPetWeightQuick: @escaping (UUID) -> Void,
        onPresentQuickMoment: @escaping (UUID) -> Void,
        onRequestStarterGiftClaim: @escaping () -> Void,
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
        self.onPresentHumanWeightQuick = onPresentHumanWeightQuick
        self.onPresentOasisReward = onPresentOasisReward
        self.onPresentPetWeightQuick = onPresentPetWeightQuick
        self.onPresentQuickMoment = onPresentQuickMoment
        self.onRequestStarterGiftClaim = onRequestStarterGiftClaim
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
        "\(payload.signature)#revision:\(payload.revision.value)"
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

    var canRunAvatarPreload: Bool {
        workloadPolicy.backgroundWorkBudget(
            operation: "home_first_screen_avatars",
            requestedItemCount: 1
        ).hasWorkCapacity
    }

    var avatarPreloadTaskKey: HomeAvatarPreloadTaskKey {
        HomeAvatarPreloadTaskKey(
            signature: avatarPreloadSignature,
            canRun: canRunAvatarPreload
        )
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
        return FocusWalletAvatarCache.cachedEntry(for: id, signature: payload.activeHumanAvatar.signature)?.image
    }

    private var homeGeometryContent: some View {
        GeometryReader { proxy in
            let globalFrame = proxy.frame(in: .global)
            let backgroundViewportTopOffset = max(0, globalFrame.minY)
            let backgroundViewportSize = ScreenCompat.bounds.size
            let safeTop: CGFloat = 0
            let safeBottom = proxy.safeAreaInsets.bottom
            let headerTopGap: CGFloat = 0
            let headerContentHeight: CGFloat = 0
            let compactContentGap: CGFloat = 8
            let compactTopChromeHeight = safeTop + headerTopGap + headerContentHeight + compactContentGap
            let homeCollapsedTopInset: CGFloat = 0
            let topChromeHeight = compactTopChromeHeight
            let bottomHeight = max(84, safeBottom + 70)
            let contentHeight = VerticalSolidHomePageContentHeightPolicy.height(
                selectedTab: controller.selectedTab,
                containerHeight: proxy.size.height,
                topChromeHeight: topChromeHeight,
                bottomChromeHeight: bottomHeight
            )

            ZStack(alignment: .top) {
                OhanaStaticAppBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    VerticalSolidHomePageDeck(
                        selectedTab: controller.selectedTab,
                        outgoingTab: controller.outgoingTab,
                        preparingTab: controller.preparingTab,
                        preparedTabs: controller.preparedTabs,
                        visibleTabs: currentVisibleHomeTabs,
                        taskCenterBadge: taskCenterBadge,
                        localization: l,
                        backgroundViewportSize: backgroundViewportSize,
                        backgroundViewportTopOffset: backgroundViewportTopOffset,
                        onSelect: { tab in selectTab(tab) }
                    ) { lifecycle in
                        VerticalSolidHomeDashboardPage(
                            snapshot: controller.snapshot,
                            interaction: interaction,
                            avatarCacheRevision: avatarCacheRevision,
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
                            onExpandedCardCollapseIntent: { false },
                            onWalkCardMinimizeToFloatingControl: minimizeWalkCardToFloatingControl,
                            onAddFirstPet: { routeCoordinator.openAddEntity(.pet) },
                            onOpenAllMembers: { routeCoordinator.openCrewRoster() }
                        )
                    } calendar: { lifecycle in
                        embeddedTaskCenterPage(lifecycle: lifecycle)
                    } oasis: { lifecycle in
                        embeddedOasisPage(lifecycle: lifecycle)
                    } plants: { _ in
                        embeddedPlantsPage(topChromeHeight: topChromeHeight)
                    }
                    .frame(width: proxy.size.width, height: contentHeight)

                    VerticalSolidHomeBottomBar(
                        selectedTab: controller.selectedTab,
                        visibleTabs: currentVisibleHomeTabs,
                        taskCenterBadge: taskCenterBadge,
                        quickRecordTargets: homeToolbarQuickRecordTargets,
                        safeBottom: safeBottom,
                        allowsSelectionMotion: canAnimate,
                        contextActionDisabledReason: homeBottomContextActionDisabledReason,
                        localization: l,
                        onSelect: { tab in selectTab(tab) },
                        onQuickRecord: openHomeToolbarQuickRecord,
                        onContextAction: performHomeBottomContextAction
                    )
                    .frame(width: proxy.size.width, height: bottomHeight, alignment: .bottom)
                }
                .frame(
                    width: proxy.size.width,
                    height: contentHeight + bottomHeight,
                    alignment: .top
                )
                .position(
                    x: proxy.size.width / 2,
                    y: topChromeHeight + (contentHeight + bottomHeight) / 2
                )

                if showsHomeReadModelLoadingOverlay {
                    HomeReadModelLoadingOverlay(localization: l)
                        .frame(width: proxy.size.width, height: contentHeight)
                        .position(x: proxy.size.width / 2, y: topChromeHeight + contentHeight / 2)
                        .zIndex(20)
                }

                if shouldShowStarterOasisTabPrompt {
                    StarterOasisTabPromptView(localization: l)
                        .padding(.horizontal, 18)
                        .padding(.bottom, max(146, safeBottom + 128))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(12)
                        .allowsHitTesting(false)
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
        }
    }

    var body: some View {
        homeGeometryContent
        .sheet(isPresented: $isCalendarAddEventPresented, onDismiss: completeCalendarAddEventDismissal) {
            AddEventView(onClose: closeCalendarAddEvent, plants: calendarAddEventPlants)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            FocusHomeToolbar(
                selectedTab: controller.selectedTab,
                coconutBalance: controller.snapshot.isReady ? headerCoconutBalance : nil,
                activeHumanDisplayName: activeHumanDisplayName,
                primaryActionIcon: homeToolbarPrimaryActionIcon,
                primaryActionAccessibilityLabel: homeToolbarPrimaryActionAccessibilityLabel,
                showsHomePrimaryAction: showsHomeToolbarPrimaryAction,
                localization: l,
                onCoconut: openHeaderCoconutDestination,
                onPrimaryAction: performHomeToolbarPrimaryAction,
                onOpenAllFeatures: { openFunctionMenu(destination: nil) },
                onOpenPlantData: { openFunctionMenu(destination: .plantFeatureCollection) },
                onCrew: { routeCoordinator.openCrewRoster() },
                onAccountSwitcher: { routeCoordinator.openAccountSwitcher() },
                onSettings: { routeCoordinator.openSettings() }
            )
        }
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
        .onChange(of: isHomeCardHeroAnimating) { _, isAnimating in
            flushDeferredHomeSnapshotRefreshIfNeeded(isAnimating: isAnimating)
        }
        .task(id: avatarPreloadTaskKey) {
            guard canRunAvatarPreload else { return }
            await preloadFirstScreenAvatars()
        }
        .task(id: controller.snapshot.isReady) {
            guard !controller.snapshot.isReady else {
                showsHomeReadModelLoadingOverlay = false
                return
            }
            showsHomeReadModelLoadingOverlay = false
            await OhanaFrameScheduler.waitAfterNextFrame(
                milliseconds: Self.readModelLoadingPresentationDelayMilliseconds
            )
            guard !Task.isCancelled, !controller.snapshot.isReady else { return }
            showsHomeReadModelLoadingOverlay = true
        }
        .onDisappear {
            homeAppearHandoffTask?.cancel()
            homeAppearHandoffTask = nil
            clearArrivalState()
            growthOnboardingTask?.cancel()
            growthUnlockToastPresentationTask?.cancel()
            growthUnlockToastDismissTask?.cancel()
            growthLoopSyncTask?.cancel()
            growthLoopPulseDismissTask?.cancel()
            memberMediaAttachmentIndexRepairTask?.cancel()
            oasisEnergyInjectionTask?.cancel()
            plantQuickCareFeedbackClearTasks.values.forEach { $0.cancel() }
            pendingOasisEnergyInjectionCount = 0
            pendingPlantQuickCareKeys.removeAll()
            completedPlantQuickCareKeys.removeAll()
            failedPlantQuickCareKeys.removeAll()
            plantQuickCareFeedbackClearTasks.removeAll()
            memberMediaAttachmentIndexRepairTask = nil
            growthLoopPulseStatus = nil
            commandQueue.cancelAll()
            snapshotRefreshGate.cancel()
            controller.cancel()
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
        .actionHumanConfirmationDialog(draft: $pendingActionHumanConfirmation)
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

    private var currentVisibleHomeTabs: [VerticalSolidHomeTab] {
        // Reading both AppStorage facts makes the tab rail react to the durable
        // gift transaction immediately; the ceremony is presentation-only.
        _ = starterGiftClaimed
        _ = starterGiftPending
        return AppFeatureRouteGuard.visibleHomeTabs(currentLevel: treeManager.treeLevel.rawValue)
    }
}

private struct HomeReadModelLoadingOverlay: View {
    let localization: L10n

    var body: some View {
        ProgressView()
            .tint(Color.goPrimary)
            .padding(16)
            .background(Color.ohanaCardSurface.opacity(0.88), in: Circle())
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localization.tr(
            zh: "正在恢复家庭数据",
            en: "Loading household data",
            de: "Haushaltsdaten werden geladen"
        ))
        .accessibilityIdentifier("home-read-model-loading")
    }
}
