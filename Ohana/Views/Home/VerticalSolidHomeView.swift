//
//  VerticalSolidHomeView.swift
//  Ohana
//
//  Rebuilt home shell with local-first interactions and snapshot handoffs.
//

import SwiftUI

struct VerticalSolidHomeView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab

    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let electronicPets: [OasisElectronicPet]
    let allEvents: [Event]
    let pendingReminders: [Reminder]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let careLogs: [PetCareLog]
    let walkLogs: [PetWalkLog]
    let pottyLogs: [PetPottyLog]
    let humanWeightLogs: [HumanWeightLog]
    let familyTasks: [FamilyCollaborationTask]
    let exchangeRequests: [CoconutExchangeRequest]

    @StateObject private var controller: VerticalSolidHomeController
    @StateObject private var safeAreaController = FocusHomeSafeAreaController()
    @StateObject private var routeCoordinator = HomeRouteCoordinator()

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Bindable private var questMgr = QuestManager.shared

    @State private var headerContextCardId: UUID?
    @State private var calendarAddEventTrigger = 0
    @State private var oasisInjectEnergyTrigger = 0
    @State private var avatarCacheRevision = 0
    @State private var headerStreak = 0
    @State private var isHomeCardExpandedOrTransitioning = false
    @State private var isHomeCardHeroAnimating = false
    @State private var homeCardHeroProgress: CGFloat = 0
    @State private var arrivingHomeCardId: UUID?
    @State private var arrivalClearTask: Task<Void, Never>?

    init(
        selectedPet: Binding<Pet?>,
        selectedHuman: Binding<Human?>,
        selectedPlant: Binding<Plant?>,
        selectedPetTab: Binding<PetDetailTab>,
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        electronicPets: [OasisElectronicPet],
        allEvents: [Event],
        pendingReminders: [Reminder],
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest]
    ) {
        _selectedPet = selectedPet
        _selectedHuman = selectedHuman
        _selectedPlant = selectedPlant
        _selectedPetTab = selectedPetTab
        self.pets = pets
        self.humans = humans
        self.plants = plants
        self.electronicPets = electronicPets
        self.allEvents = allEvents
        self.pendingReminders = pendingReminders
        self.humanMedications = humanMedications
        self.humanMedicationLogs = humanMedicationLogs
        self.careLogs = careLogs
        self.walkLogs = walkLogs
        self.pottyLogs = pottyLogs
        self.humanWeightLogs = humanWeightLogs
        self.familyTasks = familyTasks
        self.exchangeRequests = exchangeRequests

        let defaults = UserDefaults.standard
        let language = defaults.string(forKey: "appLanguage") ?? AppLanguage.code
        let activeHumanIdRaw = defaults.string(forKey: "currentActiveHumanId") ?? ""
        let hiddenPetIDsRaw = defaults.string(forKey: HomeCardVisibility.hiddenPetIDsKey) ?? ""
        let homeCardOrderRaw = defaults.string(forKey: "goFocusHomeCardOrder.v1") ?? ""
        let showDummyCards = defaults.bool(forKey: "debugShowDummyCards")
        let initialSource = VerticalSolidHomeSourceState(
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            events: allEvents,
            pendingReminders: pendingReminders,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            familyTasks: familyTasks,
            exchangeRequests: exchangeRequests,
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            language: language
        )
        let signature = VerticalSolidHomeSnapshotBuilder.signature(for: initialSource)
        _controller = StateObject(
            wrappedValue: VerticalSolidHomeController(
                initialSnapshot: VerticalSolidHomeSnapshotBuilder.build(from: initialSource),
                initialSignature: signature
            )
        )
    }

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var l: L10n {
        L10n(appLanguage)
    }

    private var dataSignature: String {
        VerticalSolidHomeSnapshotBuilder.signature(for: sourceState)
    }

    private var sourceState: VerticalSolidHomeSourceState {
        VerticalSolidHomeSourceState(
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            events: allEvents,
            pendingReminders: pendingReminders,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            familyTasks: familyTasks,
            exchangeRequests: exchangeRequests,
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            language: appLanguage
        )
    }

    private var avatarPreloadSignature: String {
        VerticalSolidHomePreloadPlanner.avatarSignature(for: sourceState)
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
        guard let human = activeHuman else { return nil }
        return FocusWalletAvatarCache.entry(for: human.id, data: human.avatarImageData).image
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = safeAreaController.resolvedTop(in: proxy)
            let safeBottom = safeAreaController.resolvedBottom(in: proxy)
            let headerTopGap: CGFloat = 8
            let headerContentHeight: CGFloat = 30
            let focusTopGap: CGFloat = 2
            let focusHeight = min(128, max(118, proxy.size.height * 0.145))
            let contentTopGap: CGFloat = 4
            let compactContentGap: CGFloat = 8
            let shouldReserveFocusSpace = controller.selectedTab == .home
            let cardHeroProgress = min(max(homeCardHeroProgress, 0), 1)
            let todayFocusVisualProgress = shouldReserveFocusSpace
                ? Self.todayFocusVisualProgress(cardHeroProgress: cardHeroProgress)
                : 0
            let todayFocusUsesLiveStack = shouldReserveFocusSpace &&
                !isHomeCardExpandedOrTransitioning &&
                !isHomeCardHeroAnimating &&
                todayFocusVisualProgress > 0.98
            let isTodayFocusInteractive = shouldReserveFocusSpace &&
                !isHomeCardExpandedOrTransitioning &&
                !isHomeCardHeroAnimating &&
                todayFocusVisualProgress > 0.98
            let compactTopChromeHeight = safeTop + headerTopGap + headerContentHeight + compactContentGap
            let homeCollapsedTopInset = max(0, focusTopGap + focusHeight + contentTopGap - compactContentGap)
            let topChromeHeight = compactTopChromeHeight
            let bottomHeight = max(84, safeBottom + 70)
            let contentHeight = max(300, proxy.size.height - topChromeHeight - bottomHeight)

            ZStack(alignment: .top) {
                OhanaAppBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VerticalSolidHomePageDeck(
                    selectedTab: controller.selectedTab,
                    preparedTabs: controller.preparedTabs,
                    canAnimate: canAnimate
                ) { lifecycle in
                    VerticalSolidHomeDashboardPage(
                        snapshot: controller.snapshot,
                        pets: pets,
                        avatarCacheRevision: avatarCacheRevision,
                        isLive: lifecycle.isLive,
                        collapsedTopInset: homeCollapsedTopInset,
                        headerContextCardId: $headerContextCardId,
                        isCardExpandedOrTransitioning: $isHomeCardExpandedOrTransitioning,
                        isCardHeroAnimating: $isHomeCardHeroAnimating,
                        cardHeroProgress: $homeCardHeroProgress,
                        arrivingCardId: arrivingHomeCardId,
                        onOpenCard: openCard,
                        onQuickActionForCard: openQuickAction,
                        onAddPet: { routeCoordinator.openAddEntity(.pet) }
                    )
                } calendar: { lifecycle in
                    CalendarView(
                        hideToolbar: true,
                        showsEmbeddedControls: true,
                        addEventTrigger: calendarAddEventTrigger,
                        isEmbeddedPrepared: lifecycle.isPrepared,
                        isEmbeddedVisible: lifecycle.isVisible,
                        isEmbeddedActive: lifecycle.isLive
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                } oasis: { lifecycle in
                    OasisRewardView(
                        hideToolbar: true,
                        injectEnergyTrigger: oasisInjectEnergyTrigger,
                        isEmbeddedPrepared: lifecycle.isPrepared,
                        isEmbeddedVisible: lifecycle.isVisible,
                        isEmbeddedActive: lifecycle.isLive
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                } plants: { _ in
                    VerticalSolidHomePlantsPage(
                        plants: controller.snapshot.plants,
                        onOpenPlant: openPlant,
                        onAddPlant: { routeCoordinator.openAddEntity(.plant) }
                    )
                }
                .frame(width: proxy.size.width, height: contentHeight)
                .position(x: proxy.size.width / 2, y: topChromeHeight + contentHeight / 2)

                if shouldReserveFocusSpace {
                    VerticalSolidHomeTodayFocusChrome(
                        snapshot: controller.snapshot.todayFocus,
                        isLive: todayFocusUsesLiveStack,
                        onOpenOasis: { controller.select(.oasis) }
                    )
                    .padding(.horizontal, 8)
                    .frame(width: proxy.size.width, height: focusHeight, alignment: .top)
                    .position(
                        x: proxy.size.width / 2,
                        y: safeTop + headerTopGap + headerContentHeight + focusTopGap + focusHeight / 2
                    )
                    .opacity(Double(todayFocusVisualProgress))
                    .allowsHitTesting(isTodayFocusInteractive)
                    .accessibilityHidden(todayFocusVisualProgress < 0.5)
                    .zIndex(8)
                }

                FocusHomeHeaderView(
                    safeTop: safeTop,
                    topGap: headerTopGap,
                    contentHeight: headerContentHeight,
                    streak: headerStreak,
                    coconutBalance: headerCoconutBalance,
                    coconutDeltaContext: headerCoconutDeltaContext,
                    activeHumanDisplayName: activeHuman?.name ?? controller.snapshot.activeName,
                    activeHumanAvatarImage: activeHumanAvatarImage,
                    activeHumanAvatarEmoji: activeHuman?.avatarEmoji,
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
                    safeBottom: safeBottom,
                    canAnimate: canAnimate,
                    onSelect: selectTab,
                    onCenter: centerAction
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .zIndex(9)
            }
            .onAppear {
                safeAreaController.stabilize(from: proxy)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            controller.applySnapshot(makeSnapshot(), signature: dataSignature, force: !controller.snapshot.isReady)
            refreshHeaderStreak()
            controller.startWarmup()
        }
        .task(id: "\(dataSignature)|hero:\(isHomeCardHeroAnimating)") {
            let signature = dataSignature
            controller.scheduleSnapshotRefresh(
                signature: signature,
                delayMilliseconds: isHomeCardHeroAnimating ? 760 : 96
            ) {
                makeSnapshot()
            }
        }
        .task(id: avatarPreloadSignature) {
            await preloadFirstScreenAvatars()
        }
        .onDisappear {
            arrivalClearTask?.cancel()
            arrivalClearTask = nil
            controller.cancel()
        }
        .focusHomeRouteSheets(
            pets: pets,
            humans: humans,
            l: l,
            routes: routeCoordinator,
            activeHumanIdStr: $activeHumanIdRaw,
            onAddEntityDismissed: {},
            onPetSavedFromAddEntity: { pet in
                selectedPet = pet
                handleNewHomeMemberSaved(id: pet.id)
            },
            onHumanSavedFromAddEntity: { human in
                selectedHuman = human
                handleNewHomeMemberSaved(id: human.id)
            },
            onCrewPetSelected: { pet in
                selectedPetTab = .overview
                selectedPet = pet
            },
            onCrewHumanSelected: { human in
                selectedHuman = human
            },
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { _ in }
        )
        .onChange(of: activeHumanIdRaw) { _, _ in
            refreshHeaderStreak()
        }
    }

    private func makeSnapshot() -> VerticalSolidHomeSnapshot {
        VerticalSolidHomeSnapshotBuilder.build(from: sourceState)
    }

    private func selectTab(_ tab: VerticalSolidHomeTab) {
        guard controller.selectedTab != tab else { return }
        OhanaFeedback.selection()
        controller.select(tab)
    }

    private func centerAction() {
        OhanaFeedback.light()
        switch controller.selectedTab {
        case .home:
            routeCoordinator.openAddEntity(pets.isEmpty ? .pet : .human)
        case .calendar:
            calendarAddEventTrigger += 1
        case .oasis:
            oasisInjectEnergyTrigger += 1
        case .plants:
            routeCoordinator.openAddEntity(.plant)
        }
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

    private func openCard(_ card: FocusCard) {
        if card.isHuman {
            selectedHuman = humans.first { $0.id == card.id }
        } else if card.isElectronicPet {
            controller.select(.oasis)
        } else {
            selectedPetTab = .overview
            selectedPet = pets.first { $0.id == card.id }
        }
    }

    private func openPlant(_ plant: VerticalSolidHomePlantSnapshot) {
        selectedPlant = plants.first { $0.id == plant.id }
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

    private func openQuickAction(_ action: VerticalSolidHomeQuickAction, card: FocusCard, opensQuickSheet: Bool) {
        guard !card.isHuman, !card.isElectronicPet else {
            openCard(card)
            return
        }
        switch action {
        case .feed:
            routeCoordinator.openSheet(.petFeed(card.id, opensManualSheet: opensQuickSheet))
        case .water:
            routeCoordinator.openSheet(.petWater(card.id))
        case .potty:
            routeCoordinator.openSheet(.petPotty(card.id))
        case .play:
            routeCoordinator.openSheet(.petPlay(card.id))
        }
    }

    private func refreshHeaderStreak() {
        headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdRaw)
    }

    private static func todayFocusVisualProgress(cardHeroProgress: CGFloat) -> CGFloat {
        let visible = min(max(1 - cardHeroProgress, 0), 1)
        return visible * visible * (3 - 2 * visible)
    }

    private func preloadFirstScreenAvatars() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 72)
        guard !Task.isCancelled else { return }
        let payloads = avatarPreloadPayloads()
        guard !payloads.isEmpty else { return }
        let didChange = await FocusWalletAvatarCache.preload(payloads: payloads)
        guard didChange, !Task.isCancelled else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            avatarCacheRevision += 1
        }
    }

    private func avatarPreloadPayloads() -> [FocusWalletAvatarCache.Payload] {
        VerticalSolidHomePreloadPlanner.avatarPayloads(source: sourceState, snapshot: controller.snapshot)
    }
}
