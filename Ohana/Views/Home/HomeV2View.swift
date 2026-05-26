//
//  HomeV2View.swift
//  Ohana
//
//  Rebuilt home shell with local-first interactions and snapshot handoffs.
//

import SwiftUI

struct HomeV2View: View {
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

    @StateObject private var controller: HomeV2Controller
    @StateObject private var safeAreaController = FocusHomeSafeAreaController()

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Bindable private var questMgr = QuestManager.shared

    @State private var activeAddEntityType: EntityType?
    @State private var quickRoute: HomeV2QuickRoute?
    @State private var showingCrewRoster = false
    @State private var showingSettings = false
    @State private var showingStreakDetail = false
    @State private var activeCoconutLogSubject: CoconutLogSubject?
    @State private var headerContextCardId: UUID?
    @State private var calendarAddEventTrigger = 0
    @State private var oasisInjectEnergyTrigger = 0
    @State private var avatarCacheRevision = 0
    @State private var headerStreak = 0
    @State private var isHomeCardExpandedOrTransitioning = false
    @State private var homeCardHeroProgress: CGFloat = 0

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
        let initialSource = HomeV2SourceState(
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
        let signature = HomeV2SnapshotBuilder.signature(for: initialSource)
        _controller = StateObject(
            wrappedValue: HomeV2Controller(
                initialSnapshot: HomeV2SnapshotBuilder.build(from: initialSource),
                initialSignature: signature
            )
        )
    }

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var dataSignature: String {
        HomeV2SnapshotBuilder.signature(for: sourceState)
    }

    private var sourceState: HomeV2SourceState {
        HomeV2SourceState(
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
        HomeV2PreloadPlanner.avatarSignature(for: sourceState)
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
            let todayFocusVisualProgress = shouldReserveFocusSpace ? (1 - cardHeroProgress) : 0
            let isTodayFocusInteractive = shouldReserveFocusSpace &&
                !isHomeCardExpandedOrTransitioning &&
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

                HomeV2PageDeck(
                    selectedTab: controller.selectedTab,
                    preparedTabs: controller.preparedTabs,
                    canAnimate: canAnimate
                ) { lifecycle in
                    HomeV2DashboardPage(
                        snapshot: controller.snapshot,
                        pets: pets,
                        avatarCacheRevision: avatarCacheRevision,
                        isLive: lifecycle.isLive,
                        collapsedTopInset: homeCollapsedTopInset,
                        headerContextCardId: $headerContextCardId,
                        isCardExpandedOrTransitioning: $isHomeCardExpandedOrTransitioning,
                        cardHeroProgress: $homeCardHeroProgress,
                        onOpenCard: openCard,
                        onQuickActionForCard: openQuickAction,
                        onAddPet: { activeAddEntityType = .pet }
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
                    HomeV2PlantsPage(
                        plants: controller.snapshot.plants,
                        onOpenPlant: openPlant,
                        onAddPlant: { activeAddEntityType = .plant }
                    )
                }
                .frame(width: proxy.size.width, height: contentHeight)
                .position(x: proxy.size.width / 2, y: topChromeHeight + contentHeight / 2)

                if shouldReserveFocusSpace {
                    HomeV2TodayFocusChrome(
                        snapshot: controller.snapshot.todayFocus,
                        isLive: isTodayFocusInteractive,
                        onOpenOasis: { controller.select(.oasis) }
                    )
                    .padding(.horizontal, 8)
                    .frame(width: proxy.size.width, height: focusHeight, alignment: .top)
                    .position(
                        x: proxy.size.width / 2,
                        y: safeTop + headerTopGap + headerContentHeight + focusTopGap + focusHeight / 2
                    )
                    .opacity(Double(todayFocusVisualProgress))
                    .scaleEffect(0.96 + 0.04 * todayFocusVisualProgress, anchor: .top)
                    .offset(y: -14 * (1 - todayFocusVisualProgress))
                    .allowsHitTesting(isTodayFocusInteractive)
                    .accessibilityHidden(todayFocusVisualProgress < 0.5)
                    .animation(canAnimate ? GoMotion.zStackHero : GoMotion.reduced, value: todayFocusVisualProgress)
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
                    onStreak: { showingStreakDetail = true },
                    onCoconut: openHeaderCoconutDestination,
                    onCrew: { showingCrewRoster = true },
                    onAccountSwitcher: { showingCrewRoster = true },
                    onCalendar: { controller.select(.calendar) },
                    onSettings: { showingSettings = true }
                )
                .contentShape(Rectangle())
                .zIndex(10)

                HomeV2BottomBar(
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
        .task(id: dataSignature) {
            let signature = dataSignature
            controller.scheduleSnapshotRefresh(signature: signature) {
                makeSnapshot()
            }
        }
        .task(id: avatarPreloadSignature) {
            await preloadFirstScreenAvatars()
        }
        .onDisappear {
            controller.cancel()
        }
        .sheet(item: $activeAddEntityType) { type in
            AddEntityDestinationView(
                type: type,
                onComplete: { activeAddEntityType = nil },
                onPetSaved: { selectedPet = $0 },
                onHumanSaved: { human in
                    activeHumanIdRaw = human.id.uuidString
                    selectedHuman = human
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow creation flow as a long sheet
        }
        .sheet(item: $quickRoute) { route in
            quickRouteDestination(route)
        }
        .fullScreenCover(item: $activeCoconutLogSubject) { subject in
            CoconutLogView(subject: subject)
        }
        .sheet(isPresented: $showingCrewRoster) {
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
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .black))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow member hub as a long sheet
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingStreakDetail) {
            DailyStreakDetailView(pets: pets, onClose: { showingStreakDetail = false })
                .ohanaSheetPagePresentation() // ui-v4: allow existing streak detail sheet
        }
        .onChange(of: activeHumanIdRaw) { _, _ in
            refreshHeaderStreak()
        }
    }

    private func makeSnapshot() -> HomeV2Snapshot {
        HomeV2SnapshotBuilder.build(from: sourceState)
    }

    private func selectTab(_ tab: HomeV2Tab) {
        guard controller.selectedTab != tab else { return }
        OhanaFeedback.selection()
        controller.select(tab)
    }

    private func centerAction() {
        OhanaFeedback.light()
        switch controller.selectedTab {
        case .home:
            activeAddEntityType = pets.isEmpty ? .pet : .human
        case .calendar:
            calendarAddEventTrigger += 1
        case .oasis:
            oasisInjectEnergyTrigger += 1
        case .plants:
            activeAddEntityType = .plant
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

    private func openPlant(_ plant: HomeV2PlantSnapshot) {
        selectedPlant = plants.first { $0.id == plant.id }
    }

    private func openHeaderCoconutDestination() {
        if let card = headerContextCard {
            if card.isHuman, humans.contains(where: { $0.id == card.id }) {
                activeCoconutLogSubject = .human(card.id)
                return
            }
            if pets.contains(where: { $0.id == card.id }) {
                activeCoconutLogSubject = .pet(card.id)
                return
            }
        }
        if let human = activeHuman {
            activeCoconutLogSubject = .human(human.id)
        }
    }

    private func openQuickAction(_ action: HomeV2QuickAction, card: FocusCard, opensQuickSheet: Bool) {
        guard !card.isHuman, !card.isElectronicPet else {
            openCard(card)
            return
        }
        switch action {
        case .feed:
            quickRoute = .feed(card.id, opensManualSheetOnAppear: opensQuickSheet)
        case .water:
            quickRoute = .water(card.id)
        case .potty:
            quickRoute = .potty(card.id)
        case .play:
            quickRoute = .play(card.id)
        }
    }

    private func refreshHeaderStreak() {
        headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdRaw)
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
        HomeV2PreloadPlanner.avatarPayloads(source: sourceState, snapshot: controller.snapshot)
    }

    @ViewBuilder
    private func quickRouteDestination(_ route: HomeV2QuickRoute) -> some View {
        switch route {
        case let .feed(id, opensManualSheetOnAppear):
            if let pet = pets.first(where: { $0.id == id }) {
                QuickFeedDetailSheet(
                    pet: pet,
                    onRemove: { quickRoute = nil },
                    showsRemoveQuickActionFooter: false,
                    opensManualSheetOnAppear: opensManualSheetOnAppear
                )
                .ohanaSheetPagePresentation() // ui-v4: allow feeding as long sheet
            } else {
                HomeV2MissingRouteView { quickRoute = nil }
            }
        case let .water(id):
            if let pet = pets.first(where: { $0.id == id }) {
                QuickWaterDetailSheet(pet: pet) { quickRoute = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow water as long sheet
            } else {
                HomeV2MissingRouteView { quickRoute = nil }
            }
        case let .potty(id):
            if let pet = pets.first(where: { $0.id == id }) {
                QuickPottyDetailSheet(pet: pet) { quickRoute = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow potty as long sheet
            } else {
                HomeV2MissingRouteView { quickRoute = nil }
            }
        case let .play(id):
            if let pet = pets.first(where: { $0.id == id }) {
                QuickPlayDetailSheet(pet: pet) { quickRoute = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow play as long sheet
            } else {
                HomeV2MissingRouteView { quickRoute = nil }
            }
        }
    }
}

private struct HomeV2MissingRouteView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color.goOrange)
                Text("对象不存在")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Button {
                    onClose()
                } label: {
                    Text("关闭")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}
