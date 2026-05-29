//
//  VerticalSolidHomeView.swift
//  Ohana
//
//  Rebuilt home shell with local-first interactions and snapshot handoffs.
//

import SwiftData
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
    let expenseLogs: [PetExpenseLog]
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
    @AppStorage("quickActionItems_v2") private var quickActionItemsRaw = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
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
        expenseLogs: [PetExpenseLog],
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
        self.expenseLogs = expenseLogs
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
        let initialSnapshot = VerticalSolidHomeSnapshotBuilder.build(from: initialSource)
        FocusWalletAvatarCache.seedPreviewEntries(
            payloads: VerticalSolidHomePreloadPlanner.avatarPayloads(
                source: initialSource,
                snapshot: initialSnapshot
            )
        )
        _controller = StateObject(
            wrappedValue: VerticalSolidHomeController(
                initialSnapshot: initialSnapshot,
                initialSignature: signature
            )
        )
    }

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var commandExecutor: HomeCommandExecutor {
        HomeCommandExecutor(modelContext: modelContext)
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
                        humans: humans,
                        allEvents: allEvents,
                        humanMedications: humanMedications,
                        humanMedicationLogs: humanMedicationLogs,
                        expenseLogs: expenseLogs,
                        avatarCacheRevision: avatarCacheRevision,
                        isLive: lifecycle.isLive,
                        collapsedTopInset: homeCollapsedTopInset,
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
                    CalendarView(
                        preselectedPetId: embeddedCalendarPreselectedPetId,
                        preselectedHumanId: embeddedCalendarPreselectedHumanId,
                        hideToolbar: true,
                        showsEmbeddedControls: true,
                        addEventTrigger: calendarAddEventTrigger,
                        isEmbeddedPrepared: lifecycle.isPrepared,
                        isEmbeddedVisible: lifecycle.isVisible,
                        isEmbeddedActive: lifecycle.isLive,
                        onRequestAddEvent: openCalendarAddEvent,
                        onOpenEventDestination: openCalendarEventDestination
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

                if controller.preparedTabs.contains(.home) {
                    VerticalSolidHomeTodayFocusChrome(
                        snapshot: controller.snapshot.todayFocus,
                        isLive: true,
                        onOpenOasis: { controller.select(.oasis) }
                    )
                    .padding(.horizontal, 8)
                    .frame(width: proxy.size.width, height: focusHeight, alignment: .top)
                    .position(
                        x: proxy.size.width / 2 + todayFocusHorizontalOffset,
                        y: safeTop + headerTopGap + headerContentHeight + focusTopGap + focusHeight / 2
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
                    isFabExpanded: $fabExpanded,
                    itemsVisible: $fabMenuItemsVisible,
                    activeCard: expandedBottomBarCard,
                    homeShortcuts: HomeFabShortcutCatalog.primaryShortcuts,
                    expandedShortcuts: expandedBottomBarShortcuts,
                    safeBottom: safeBottom,
                    canAnimate: canAnimate,
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
                        isContentMounted: isCalendarAddEventContentMounted
                    ) {
                        AddEventView(onClose: closeCalendarAddEvent)
                    }
                    .zIndex(40)
                }
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
            clearArrivalState()
            calendarAddEventPresentationTask?.cancel()
            calendarAddEventContentMountTask?.cancel()
            controller.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                clearArrivalState()
            }
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
        .onChange(of: controller.selectedTab) { _, _ in
            closeVerticalFabMenu(immediate: true)
        }
        .onChange(of: expandedBottomBarCard?.id) { _, _ in
            closeVerticalFabMenu(immediate: true)
        }
    }

    private func makeSnapshot() -> VerticalSolidHomeSnapshot {
        VerticalSolidHomeSnapshotBuilder.build(from: sourceState)
    }

    private func selectTab(_ tab: VerticalSolidHomeTab) {
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
            commandExecutor.applyGroomCheckIn(
                raw: optionId,
                pet: pet,
                executorId: currentExecutorId(),
                showSingleUseNotice: { title, message in
                    routeCoordinator.showSingleUseNotice(title: title, message: message)
                },
                feedback: applyQuickActionExecutorFeedback
            )
        case "potty":
            commandExecutor.applyPottyCheckIn(
                raw: optionId,
                pet: pet,
                executorId: currentExecutorId(),
                feedback: applyQuickActionExecutorFeedback
            )
        case "health":
            commandExecutor.applyHealthCheckIn(
                raw: optionId,
                pet: pet,
                executorId: currentExecutorId(),
                openHealth: { routeCoordinator.openSheet(.petHealth($0.id, initialSection: nil)) },
                feedback: applyQuickActionExecutorFeedback
            )
        default:
            openPetQuickActionItem(item, pet: pet, usesPrimaryAction: true)
        }
    }

    private func openPetQuickActionItem(_ item: QuickActionItem, pet: Pet, usesPrimaryAction: Bool) {
        if usesPrimaryAction {
            switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
            case let .perform(actionType):
                performPetQuickAction(actionType, pet: pet)
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

    private func performPetQuickAction(_ actionType: String, pet: Pet) {
        commandExecutor.performActionType(
            actionType,
            pet: pet,
            executorId: currentExecutorId(),
            allEvents: allEvents,
            allFeedCareLogs: pet.careLogs,
            humans: humans,
            now: Date(),
            antiRepeatTitle: l.tr(zh: "刚刚已经记录过", en: "Already logged", de: "Bereits erfasst"),
            antiRepeatMessage: { warning in
                l.tr(
                    zh: "\(warning.executorName) \(warning.minutesAgo)分钟前刚记录过，确定再记一次吗？",
                    en: "\(warning.executorName) logged this \(warning.minutesAgo)m ago. Log again?",
                    de: "\(warning.executorName) hat das vor \(warning.minutesAgo) Min. erfasst. Erneut erfassen?"
                )
            },
            openFeedDetail: { opensManualSheet in
                routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: opensManualSheet))
            },
            completePlannedFeed: completePlannedFeed,
            showAntiRepeat: { title, message, pendingAction in
                routeCoordinator.showAntiRepeat(
                    title: title,
                    message: message,
                    pendingAction: pendingAction
                )
            },
            startWalk: { routeCoordinator.openWalk($0) },
            openWaterManagement: { routeCoordinator.openSheet(.petWater($0.id)) },
            openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) },
            feedback: applyQuickActionExecutorFeedback
        )
    }

    private func completePlannedFeed(_ pet: Pet) -> Bool {
        guard let reminder = ExpandedQuickActionLogic.pendingFeedReminder(
            for: pet,
            allEvents: allEvents,
            allFeedCareLogs: pet.careLogs,
            now: Date()
        ) else {
            return false
        }

        let reward = commandExecutor.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            executorId: currentExecutorId()
        )
        guard let reward else { return false }
        let delta = reward.humanGot + reward.petGot
        applyQuickActionExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: pet.id,
                coconutDelta: delta,
                label: delta > 0 ? "喂食 +\(delta)🥥" : nil
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func applyQuickActionExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        refreshHeaderStreak()
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 72) {
            controller.applySnapshot(makeSnapshot(), signature: dataSignature, force: true)
        }
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
            routeCoordinator.openFunctionMenu(destination: .plantsDashboard)
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

    private func preloadFirstScreenAvatars() async {
        let payloads = avatarPreloadPayloads()
        guard !payloads.isEmpty else { return }
        if FocusWalletAvatarCache.seedPreviewEntries(payloads: payloads) {
            bumpAvatarCacheRevision()
        }
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 72)
        guard !Task.isCancelled else { return }
        let didChange = await FocusWalletAvatarCache.preload(payloads: payloads)
        guard didChange, !Task.isCancelled else { return }
        bumpAvatarCacheRevision()
    }

    private func bumpAvatarCacheRevision() {
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
