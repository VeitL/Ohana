//
//  FocusHomeView.swift
//  Ohana
//
//  Single verticalSolid home shell.
//

import SwiftData
import SwiftUI

struct FocusHomeView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    let heroNS: Namespace.ID
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let electronicPets: [OasisElectronicPet]
    let allEvents: [Event]
    let pendingReminders: [Reminder]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let commandExecutor: HomeCommandExecutor

    @Environment(\.ohanaDisplayCornerRadius) private var displayCornerRadius
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Bindable private var questMgr = QuestManager.shared

    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard = true
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""

    @StateObject private var wallet = FocusHomeWalletController()
    @StateObject private var verticalSolidMotion = VerticalSolidHomeMotionCoordinator()
    @StateObject private var snapshotController = FocusHomeSnapshotController()
    @StateObject private var expandedQuickEdit = ExpandedQuickActionEditController()
    @StateObject private var routeCoordinator = HomeRouteCoordinator()
    @StateObject private var walkTransform = FocusHomeWalkTransformController()

    @State private var headerStreak = 0
    @State private var didRecordHomeFirstFrame = false
    @State private var lastAppliedCardSourceSignature = ""
    @State private var firstFrameCards: [FocusCard] = []
    @State private var firstFrameCardSourceSignature = ""
    @State private var snapshotRefreshGeneration = 0
    @State private var pressedExpandedActionId: String? = nil

    @State private var functionMenuPresentation: FunctionMenuPresentation?
    @State private var showStreakDetail = false
    @State private var showingSettings = false
    @State private var activeAddEntityType: EntityType? = nil
    @State private var showingCrewRoster = false
    @State private var showingAccountSwitcher = false
    @State private var showingCalendar = false
    @State private var calendarEntityFilterId: String? = nil
    @State private var calendarHumanFilterId: String? = nil
    @State private var showingOasisReward = false
    @State private var activeCoconutLogSubject: CoconutLogSubject? = nil

    @State private var todayFocusWalkPet: Pet? = nil
    @State private var expandedQuickMomentPet: Pet? = nil

    @State private var fabExpanded = false
    @State private var fabMenuItemsVisible = false
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)? = nil
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""
    @State private var showingSingleUseNotice = false
    @State private var singleUseNoticeTitle = ""
    @State private var singleUseNoticeMessage = ""
    @State private var showingQuickActionLimitAlert = false
    @State private var showingHumanPrivacyAlert = false
    @State private var showExpandedCoconutReward = false
    @State private var expandedCoconutRewardAmount = 0
    @State private var expandedCoconutRewardLabel: String? = nil
    @State private var verticalTabVisualState = VerticalHomeTabVisualState()
    @State private var selectedVerticalTab: VerticalHomeTab = .home
    @State private var isVerticalTodayFocusCollapsed = false
    @State private var verticalCalendarAddEventTrigger = 0
    @State private var verticalOasisInjectEnergyTrigger = 0

    private var l: L10n { L10n(appLanguage) }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full
    }

    private var walletExpandAnimation: Animation {
        if shouldReduceWork { return HeroAnim.walletReduced }
        return GoMotion.zStackHero
    }

    private var walletCollapseAnimation: Animation {
        if shouldReduceWork { return HeroAnim.walletReduced }
        return GoMotion.zStackHero
    }

    private var directTabHiddenWalletCleanupDelayMilliseconds: UInt64 {
        shouldReduceWork ? 260 : 700
    }

    private var routeAnimation: Animation { shouldReduceWork ? GoMotion.reduced : GoMotion.page }

    private var activeHuman: Human? {
        if let id = UUID(uuidString: activeHumanIdStr), let human = humans.first(where: { $0.id == id }) {
            return human
        }
        return humans.first
    }

    private var currentCoconutBalance: Int {
        activeHuman?.coconutBalance ?? questMgr.coconutCount
    }

    private var headerContextCard: FocusCard? {
        guard verticalTabVisualState.selectedTab == .home,
              wallet.isExpanded || wallet.heroProgress > 0.98,
              let id = wallet.activeCardId else { return nil }
        let cachedCards = snapshotController.cards(fallback: [])
        return displayCards.first(where: { $0.id == id }) ?? cachedCards.first(where: { $0.id == id })
    }

    private var headerCoconutBalance: Int {
        guard let card = headerContextCard else { return currentCoconutBalance }
        return card.coconutBalance
    }

    private var headerCoconutDeltaContext: String {
        if let card = headerContextCard {
            return "card-\(card.id.uuidString)"
        }
        return "current-human-\(activeHuman?.id.uuidString ?? "global")"
    }

    private var waterManagementLabel: String {
        l.tr(zh: "管理", en: "Manage", de: "Verwalten")
    }

    private func buildHomeCards(now: Date = Date()) -> [FocusCard] {
        HomeSnapshotBuilder.buildCards(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            events: allEvents,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            now: now
        )
    }

    private var activeHumanAvatarImage: UIImage? {
        guard let human = activeHuman else { return nil }
        let avatarData = snapshotController.avatarData(for: human.id)
            ?? (snapshotController.snapshotInitialized ? nil : human.avatarImageData)
        return FocusWalletAvatarCache.entry(for: human.id, data: avatarData).image
    }

    private var visibleCards: [FocusCard] {
        let base = snapshotController.cards(fallback: firstFrameCards)
        return snapshotController.visibleCards(
            from: base,
            rosterPreviewCard: nil,
            isExpanded: wallet.isExpanded,
            activeCardId: wallet.activeCardId
        )
    }

    private var displayCards: [FocusCard] {
        if let frozenCards = verticalSolidMotion.cards {
            return frozenCards
        }
        return visibleCards
    }

    private var heroSelectedCardId: UUID? {
        guard wallet.isExpanded || wallet.transitionCardId != nil || wallet.heroProgress > 0.001 else { return nil }
        return wallet.activeCardId ?? wallet.transitionCardId
    }

    private var activeCard: FocusCard? {
        guard let id = wallet.activeCardId else { return nil }
        return displayCards.first(where: { $0.id == id })
    }

    private var shouldShowExpandedWalletCardRootHitZone: Bool {
        wallet.isExpanded && wallet.heroProgress > 0.985 && activeCard != nil
    }

    private var isWalletHeroTransitioning: Bool {
        wallet.transitionCardId != nil || (wallet.heroProgress > 0.001 && wallet.heroProgress < 0.999)
    }

    private var activePetForFocus: Pet? {
        if let id = wallet.activeCardId,
           let pet = activePets.first(where: { $0.id == id })
        {
            return pet
        }
        return activePets.first
    }

    private var verticalSolidPageRenderSnapshot: VerticalSolidHomeRenderSnapshot {
        verticalSolidMotion.renderSnapshot ?? makeVerticalSolidRenderSnapshot(cards: displayCards)
    }

    var body: some View {
        GeometryReader { geo in
            rootSceneWithLifecycle(geo: geo)
        }
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .coconutRewardOverlay(
            trigger: $showExpandedCoconutReward,
            amount: expandedCoconutRewardAmount,
            label: expandedCoconutRewardLabel
        )
        .focusHomeRouteSheets(
            pets: pets,
            humans: humans,
            l: l,
            routes: routeCoordinator,
            functionMenuPresentation: $functionMenuPresentation,
            showStreakDetail: $showStreakDetail,
            showingSettings: $showingSettings,
            activeAddEntityType: $activeAddEntityType,
            activeHumanIdStr: $activeHumanIdStr,
            showingCrewRoster: $showingCrewRoster,
            showingAccountSwitcher: $showingAccountSwitcher,
            showingCalendar: $showingCalendar,
            calendarEntityFilterId: $calendarEntityFilterId,
            calendarHumanFilterId: $calendarHumanFilterId,
            todayFocusWalkPet: $todayFocusWalkPet,
            expandedQuickMomentPet: $expandedQuickMomentPet,
            showingOasisReward: $showingOasisReward,
            activeCoconutLogSubject: $activeCoconutLogSubject,
            showingAntiRepeatAlert: $showingAntiRepeatAlert,
            pendingRepeatAction: $pendingRepeatAction,
            antiRepeatTitle: $antiRepeatTitle,
            antiRepeatMessage: $antiRepeatMessage,
            showingSingleUseNotice: $showingSingleUseNotice,
            singleUseNoticeTitle: $singleUseNoticeTitle,
            singleUseNoticeMessage: $singleUseNoticeMessage,
            showingQuickActionLimitAlert: $showingQuickActionLimitAlert,
            showingHumanPrivacyAlert: $showingHumanPrivacyAlert,
            onAddEntityDismissed: { refreshSnapshot(force: true) },
            onPetSavedFromAddEntity: handlePetSaved,
            onCrewPetSelected: { pet in openCard(FocusCard.from(pet, includeAvatarData: true)) },
            onCrewHumanSelected: { human in openCard(FocusCard.from(human, includeAvatarData: true)) },
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { humanId in showReward(amount: 2, label: "用药 +2🥥", cardId: humanId) }
        )
    }

    private func handleHomeAppear() {
        verticalTabVisualState.sync(selectedVerticalTab)
        primeFirstFrameCardsIfNeeded(force: firstFrameCards.isEmpty)
        if snapshotController.snapshotInitialized {
            scheduleActiveHumanAvatarSeed()
            snapshotController.scheduleVisibleAvatarDataLoad(
                pets: pets,
                humans: humans,
                equipFxPopoutCard: equipFxPopoutCard,
                isExpanded: wallet.isExpanded,
                walletTransitionCardId: wallet.transitionCardId
            )
        } else {
            scheduleSnapshotRefreshAfterFirstFrame(force: true)
        }
        syncWalkCardSurfaceVisibility()
        headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdStr)
        wallet.prepareTapFeedback()
        if !didRecordHomeFirstFrame {
            didRecordHomeFirstFrame = true
            DispatchQueue.main.async {
                AppPerformanceMonitor.shared.record("HomeV2 首帧", startedAt: ohanaProcessStartTime)
            }
        }
        routePendingReminderNotificationIfNeeded()
    }

    private func handleActiveHumanChanged() {
        scheduleActiveHumanAvatarSeed()
        headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdStr)
    }

    private func rootSceneWithLifecycle(geo: GeometryProxy) -> some View {
        rootScene(geo: geo)
            .onAppear(perform: handleHomeAppear)
            .task(id: cardSourceDependencyKey) {
                await OhanaFrameScheduler.waitAfterNextFrame()
                guard !Task.isCancelled else { return }
                requestSnapshotRefresh()
            }
            .task(id: firstFrameCardDependencyKey) {
                await OhanaFrameScheduler.waitAfterNextFrame()
                guard !Task.isCancelled else { return }
                primeFirstFrameCardsIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .ohanaMemberProfileDidChange)) { notification in
                handleMemberProfileDidChange(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .ohanaReminderRouteRequested)) { notification in
                handleReminderRouteRequest(notification.userInfo)
            }
            .onDisappear {
                verticalTabVisualState.cancelCommit()
            }
            .onChange(of: wallet.isExpanded) { _, _ in syncWalkCardSurfaceVisibility() }
            .onChange(of: wallet.activeCardId) { _, _ in syncWalkCardSurfaceVisibility() }
            .onChange(of: PetWalkingManager.shared.phase) { _, _ in syncWalkCardSurfaceVisibility() }
            .onChange(of: PetWalkingManager.shared.currentPet?.id) { _, _ in syncWalkCardSurfaceVisibility() }
            .onChange(of: activeHumanIdStr) { _, _ in handleActiveHumanChanged() }
    }

    @ViewBuilder
    private func rootScene(geo: GeometryProxy) -> some View {
        verticalSolidRoot(geo: geo)
    }

    @ViewBuilder
    private func verticalSolidRoot(geo: GeometryProxy) -> some View {
        let safeTop = homeSafeTop(geo)
        let safeBottom = homeSafeBottom(geo)
        let headerHeight = safeTop + 62
        let bottomBarHeight = safeBottom + 82
        let contentHeight = max(320, geo.size.height - headerHeight - bottomBarHeight)

        ZStack(alignment: .top) {
            OhanaAppBackground()

            VerticalHomePagedContent(tabState: verticalTabVisualState) { lifecycle in
                verticalSolidHomePage(
                    size: CGSize(width: geo.size.width, height: contentHeight),
                    safeBottom: safeBottom,
                    isPageVisible: lifecycle.isPreparingForDisplay || lifecycle.isVisible,
                    isPageLive: lifecycle.isLive
                )
            } calendar: { lifecycle in
                CalendarView(
                    hideToolbar: true,
                    showsEmbeddedControls: true,
                    addEventTrigger: verticalCalendarAddEventTrigger,
                    isEmbeddedPrepared: lifecycle.isPrepared,
                    isEmbeddedVisible: lifecycle.isPreparingForDisplay || lifecycle.isVisible,
                    isEmbeddedActive: lifecycle.isLive
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.top, 4)
            } oasis: { lifecycle in
                OasisHomeTabHost(
                    lifecycle: lifecycle,
                    injectEnergyTrigger: verticalOasisInjectEnergyTrigger
                )
            } plants: { _ in
                VerticalHomeComingSoonPage(
                    icon: "leaf.fill",
                    title: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                    subtitle: l.tr(zh: "植物照护正在生长中", en: "Plant care is growing", de: "Pflanzenpflege wächst noch")
                )
                .padding(.horizontal, 18)
            }
            .frame(width: geo.size.width, height: contentHeight)
            .position(x: geo.size.width / 2, y: headerHeight + contentHeight / 2)

            header(safeTop: safeTop)
                .contentShape(Rectangle())
                .allowsHitTesting(true)
                .zIndex(10000)

            if fabExpanded {
                Color.black.opacity(0.001) // ui-v4: allow invisible nav FAB dismissal layer
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeVerticalFabMenu() }
                    .zIndex(900)
            }

            VerticalHomeBottomBar(
                tabState: verticalTabVisualState,
                isFabExpanded: $fabExpanded,
                itemsVisible: $fabMenuItemsVisible,
                activeCard: wallet.isExpanded && verticalTabVisualState.selectedTab == .home ? activeCard : nil,
                homeShortcuts: HomeFabShortcutCatalog.primaryShortcuts,
                expandedShortcuts: activeCard.map(expandedFabShortcuts(for:)) ?? [],
                safeBottom: safeBottom,
                onTabSelected: { tab in
                    selectVerticalTab(tab)
                },
                onShortcut: { shortcut in
                    guard shortcut.isAvailable else {
                        OhanaFeedback.light()
                        return
                    }
                    closeVerticalFabMenuForNavigation()
                    openHomeFabShortcut(shortcut)
                },
                onExpandedShortcut: { shortcut, card in
                    guard shortcut.isAvailable else {
                        OhanaFeedback.light()
                        return
                    }
                    closeVerticalFabMenuForNavigation()
                    openExpandedFabShortcut(shortcut, card: card)
                },
                onAddTapped: {
                    switch verticalTabVisualState.selectedTab {
                    case .home:
                        return false
                    case .calendar:
                        closeVerticalFabMenu()
                        verticalCalendarAddEventTrigger += 1
                        return true
                    case .oasis:
                        closeVerticalFabMenu()
                        verticalOasisInjectEnergyTrigger += 1
                        return true
                    case .plants:
                        closeVerticalFabMenu()
                        activeAddEntityType = .plant
                        return true
                    }
                }
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .zIndex(1000)

            quickInlineRecordOverlays()
                .zIndex(30000)
        }
    }

    private var cardSourceDependencyKey: String {
        let petKey = pets.map { pet in
            [
                pet.id.uuidString,
                pet.name,
                pet.species,
                pet.breed,
                pet.avatarEmoji,
                pet.gender,
                "\(pet.isNeutered)",
                pet.birthday.map { "\(Int($0.timeIntervalSince1970))" } ?? "",
                pet.homeDate.map { "\(Int($0.timeIntervalSince1970))" } ?? "",
                pet.coatColor,
                pet.eyeColor,
                pet.safeThemeColorHex,
                pet.cardStyleRaw,
                pet.cardPopoutSourceRaw ?? "",
                "\(pet.hasPassedAway)",
                pet.passedAwayDate.map { "\(Int($0.timeIntervalSince1970))" } ?? "",
                "\(pet.daysTogetherAtPassing)",
                "\(HomeCardVisibility.isPetVisible(pet, raw: hiddenHomePetIDsRaw))",
                "\(pet.currentStreak)",
                "\(pet.coconutBalance)",
                "\(pet.daysTogether)",
            ].joined(separator: ":")
        }.joined(separator: ";")
        let humanKey = humans.map { human in
            [
                human.id.uuidString,
                human.name,
                human.avatarEmoji,
                human.roleText,
                human.genderRaw,
                human.birthday.map { "\(Int($0.timeIntervalSince1970))" } ?? "",
                human.mbti,
                human.safeThemeColorHex,
                "\(human.shouldShowOnHome)",
                "\(human.hasPassedAway)",
                human.passedAwayDate.map { "\(Int($0.timeIntervalSince1970))" } ?? "",
                "\(human.daysTogetherAtPassing)",
                "\(human.coconutBalance)",
            ].joined(separator: ":")
        }.joined(separator: ";")
        let oasisKey = electronicPets.map { critter in
            [
                critter.id.uuidString,
                critter.catalogId,
                critter.displayName(l),
                "\(critter.isFeaturedOnOasis)",
                critter.lifeStateRaw,
                "\(critter.isArchived)",
                "\(critter.level)",
                "\(critter.appearanceStage)",
                "\(critter.hunger)",
                "\(critter.mood)",
                "\(critter.health)",
                "\(critter.bond)",
            ].joined(separator: ":")
        }.joined(separator: ";")
        let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
        return [
            petKey,
            humanKey,
            oasisKey,
            "plants:\(plants.count)",
            "events:\(allEvents.count)",
            "pendingReminders:\(pendingReminders.count)",
            "meds:\(humanMedications.count):\(humanMedicationLogs.count)",
            hiddenHomePetIDsRaw,
            homeCardOrderRaw,
            "\(showDummyCards)",
            appLanguage,
            "minute:\(minuteBucket)",
        ].joined(separator: "||")
    }

    private var firstFrameCardDependencyKey: String {
        let petKey = pets.map { pet in
            [
                pet.id.uuidString,
                pet.name,
                pet.species,
                pet.breed,
                pet.avatarEmoji,
                pet.safeThemeColorHex,
                pet.cardStyleRaw,
                pet.cardPopoutSourceRaw ?? "",
                "\(pet.hasPassedAway)",
                "\(HomeCardVisibility.isPetVisible(pet, raw: hiddenHomePetIDsRaw))",
                "\(pet.currentStreak)",
                "\(pet.coconutBalance)",
                "\(pet.daysTogether)",
            ].joined(separator: ":")
        }.joined(separator: ";")
        let humanKey = humans.map { human in
            [
                human.id.uuidString,
                human.name,
                human.avatarEmoji,
                human.roleText,
                human.genderRaw,
                human.safeThemeColorHex,
                "\(human.shouldShowOnHome)",
                "\(human.hasPassedAway)",
                "\(human.coconutBalance)",
            ].joined(separator: ":")
        }.joined(separator: ";")
        let oasisKey = electronicPets.map { critter in
            [
                critter.id.uuidString,
                critter.catalogId,
                "\(critter.isFeaturedOnOasis)",
                critter.lifeStateRaw,
                "\(critter.isArchived)",
                "\(critter.level)",
                "\(critter.appearanceStage)",
            ].joined(separator: ":")
        }.joined(separator: ";")
        return [
            petKey,
            humanKey,
            oasisKey,
            hiddenHomePetIDsRaw,
            homeCardOrderRaw,
            "\(showDummyCards)",
            appLanguage,
        ].joined(separator: "||")
    }

    private func buildFirstFrameCards() -> [FocusCard] {
        FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards
        )
    }

    private func primeFirstFrameCardsIfNeeded(force: Bool = false) {
        let signature = firstFrameCardDependencyKey
        guard force || signature != firstFrameCardSourceSignature else { return }
        let cards = buildFirstFrameCards()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            firstFrameCards = cards
            firstFrameCardSourceSignature = signature
        }
    }

    private func homeSnapshotSignature(for cards: [FocusCard], dependencyKey: String) -> String {
        let cardsKey = cards.map { card in
            let actionKey = card.actions
                .map { "\($0.label):\($0.icon):\($0.colorHex)" }
                .joined(separator: ",")
            return [
                card.id.uuidString,
                card.name,
                card.kind,
                card.emoji,
                "\(card.streak)",
                "\(card.coconutBalance)",
                "\(Int(card.createdAt.timeIntervalSince1970))",
                card.daysTogetherText ?? "",
                card.ageText ?? "",
                card.zodiacText ?? "",
                card.mbtiText ?? "",
                card.humanEquivalentAgeText ?? "",
                card.genderText ?? "",
                card.personalityHint ?? "",
                card.cardStyleRaw,
                card.cardPopoutSourceRaw,
                card.petSpecies ?? "",
                card.themeColorHex,
                "\(card.daysTogether)",
                card.breed,
                "\(card.hasPassedAway)",
                card.passedAwayDate.map { "\(Int($0.timeIntervalSince1970))" } ?? "",
                "\(card.daysTogetherAtPassing)",
                "\(card.isShownOnHome)",
                card.statusBadgeText ?? "",
                "\(card.statusBadgeIsWarning)",
                "\(card.isHuman)",
                "\(card.isElectronicPet)",
                card.critterCatalogId ?? "",
                "\(card.critterAppearanceStage)",
                card.critterLifeStateRaw,
                "\(card.isDummy)",
                "\(card.isReal)",
                "\(Int(card.homeWalkDistanceMeters.rounded()))",
                actionKey,
            ].joined(separator: "|")
        }.joined(separator: ";")
        return "\(dependencyKey)||cards:\(cardsKey)"
    }

    private func header(safeTop: CGFloat) -> some View {
        FocusHomeHeaderView(
            safeTop: safeTop,
            streak: headerStreak,
            coconutBalance: headerCoconutBalance,
            coconutDeltaContext: headerCoconutDeltaContext,
            activeHumanDisplayName: activeHuman?.name ?? l.tr(zh: "本人", en: "Me", de: "Ich"),
            activeHumanAvatarImage: activeHumanAvatarImage,
            activeHumanAvatarEmoji: activeHuman?.avatarEmoji,
            onStreak: { showStreakDetail = true },
            onCoconut: openHeaderCoconutDestination,
            onCrew: { showingCrewRoster = true },
            onAccountSwitcher: { showingAccountSwitcher = true },
            onCalendar: openHeaderCalendarDestination,
            onSettings: { showingSettings = true }
        )
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

    private func openHeaderCalendarDestination() {
        if let card = headerContextCard {
            if card.isHuman, humans.contains(where: { $0.id == card.id }) {
                calendarHumanFilterId = card.id.uuidString
                calendarEntityFilterId = nil
            } else if pets.contains(where: { $0.id == card.id }) {
                calendarEntityFilterId = card.id.uuidString
                calendarHumanFilterId = nil
            } else {
                calendarEntityFilterId = nil
                calendarHumanFilterId = nil
            }
        } else {
            calendarEntityFilterId = nil
            calendarHumanFilterId = nil
        }
        showingCalendar = true
    }

    private func expandedWalletCardRootHitZone(geo: GeometryProxy) -> some View {
        let layoutSize = CGSize(
            width: max(0, geo.size.width - K.cardMargin * 2),
            height: geo.size.height
        )
        let layout = WalletHeroLayout(
            size: layoutSize,
            safeTop: homeSafeTop(geo),
            safeBottom: homeSafeBottom(geo),
            cardCount: displayCards.count,
            horizontalInset: 0,
            collapsedPeek: 44,
            collapsedBottomGap: 38,
            expandedTopOffset: 116,
            expandedHeightRatio: 0.43,
            expandedMinHeight: K.expandedCardH,
            expandedMaxHeight: K.expandedCardH,
            quickGap: K.expandedQuickModuleGap,
            quickHeight: K.expandedQuickModuleEditH
        )
        let frame = layout.expandedFrame.offsetBy(dx: K.cardMargin, dy: 0)
        let headerClearance = homeSafeTop(geo) + 72
        let tappableMinY = max(frame.minY, headerClearance)
        let tappableHeight = max(0, frame.maxY - tappableMinY)
        let tappableFrame = CGRect(
            x: frame.minX,
            y: tappableMinY,
            width: frame.width,
            height: tappableHeight
        )

        return Button {
            OhanaFeedback.light()
            collapseWalletToHome()
        } label: {
            RoundedRectangle(cornerRadius: WalletHeroTimeline.cornerRadius(progress: wallet.heroProgress), style: .continuous)
                .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible Wallet root hit zone
                .frame(width: tappableFrame.width, height: tappableFrame.height)
        }
        .buttonStyle(.plain) // ui-v4: allow invisible Wallet root hit zone; visible card handles feedback
        .position(x: tappableFrame.midX, y: tappableFrame.midY)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onEnded { value in
                    guard value.translation.height > 80 else { return }
                    OhanaFeedback.light()
                    collapseWalletToHome()
                }
        )
        .accessibilityLabel(activeCard?.name ?? "Expanded card")
    }

    private func homeSafeTop(_ geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.top, 50)
    }

    private func homeSafeBottom(_ geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.bottom, 22)
    }

    private func makeVerticalSolidRenderSnapshot(cards: [FocusCard]) -> VerticalSolidHomeRenderSnapshot {
        VerticalSolidHomeRenderSnapshot(
            cards: cards,
            pets: pets,
            activePets: activePets,
            plants: plants,
            reminders: pendingReminders,
            humans: humans,
            events: allEvents,
            activePetId: activePetForFocus?.id,
            selectedTab: selectedVerticalTab
        )
    }

    private func verticalSolidHomePage(
        size: CGSize,
        safeBottom: CGFloat,
        isPageVisible: Bool,
        isPageLive: Bool
    ) -> some View {
        let renderSnapshot = verticalSolidPageRenderSnapshot
        return VerticalSolidHomePage(
            size: size,
            safeBottom: safeBottom,
            displayCards: renderSnapshot.cards,
            pets: renderSnapshot.pets,
            activePets: renderSnapshot.activePets,
            plants: renderSnapshot.plants,
            reminders: renderSnapshot.reminders,
            humans: renderSnapshot.humans,
            events: renderSnapshot.events,
            activePet: renderSnapshot.activePet,
            selectedCardId: heroSelectedCardId,
            heroProgress: wallet.heroProgress,
            heroDirection: wallet.heroDirection,
            reduceMotion: shouldReduceWork,
            isVisible: isPageVisible,
            isLive: isPageLive,
            showFirstSuccessCard: showFirstSuccessCard,
            firstQuickCheckInCompleted: firstQuickCheckInCompleted,
            isTodayFocusCollapsed: $isVerticalTodayFocusCollapsed,
            quickActions: { card in
                verticalEmbeddedQuickModules(
                    for: card,
                    pets: renderSnapshot.pets,
                    humans: renderSnapshot.humans,
                    events: renderSnapshot.events
                )
            },
            contextMenu: { card in contextMenu(for: card) },
            onSelect: { card in handleWalletCardTap(card: card, count: displayCards.count, isHero: false) },
            onCollapse: collapseWalletToHome,
            onLongPress: openCardBasicInfo,
            onAddPet: { activeAddEntityType = .pet },
            onAddHuman: { activeAddEntityType = .human },
            onOpenQuest: openTodayFocusQuestDetail,
            onCompleteQuest: completeTodayFocusQuest,
            onTapNegativeSignal: handleTodayFocusNegativeSignal,
            onTapOasis: { showingOasisReward = true },
            onTapFamilyTask: openFamilyTaskFromTodayFocus,
            onConfirmExchange: confirmTodayFocusExchange,
            onFirstSuccessFeed: { routeCoordinator.openSheet(.petFeed($0.id, opensManualSheet: false)) },
            onFirstSuccessPlay: { routeCoordinator.openSheet(.petPlay($0.id)) },
            onFirstSuccessMoment: { expandedQuickMomentPet = $0 }
        )
    }

    @ViewBuilder
    private func verticalEmbeddedQuickModules(
        for card: FocusCard,
        pets sourcePets: [Pet]? = nil,
        humans sourceHumans: [Human]? = nil,
        events sourceEvents: [Event]? = nil
    ) -> some View {
        let quickPets = sourcePets ?? pets
        let quickHumans = sourceHumans ?? humans
        let quickEvents = sourceEvents ?? allEvents
        if card.isReal,
           !card.isHuman,
           let pet = quickPets.first(where: { $0.id == card.id && !$0.hasPassedAway })
        {
            let sourceItems = expandedQuickEdit.isEditMode
                ? expandedQuickEdit.items
                : expandedQuickActionItems(for: pet)
            let visibleLimit = expandedQuickEdit.isEditMode ? QuickActionLimit.maxItemsPerEntity : 6
            let items = Array(sourceItems.prefix(visibleLimit))
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: items.map { item in
                    VerticalHomeEmbeddedAction(
                        id: item.id,
                        title: item.label,
                        icon: item.icon,
                        isCompleted: ExpandedQuickActionLogic.isCompleted(item: item, pet: pet, allEvents: quickEvents, allFeedCareLogs: pet.careLogs, now: Date()),
                        detailIcon: verticalEmbeddedDetailIcon(for: item.actionType, isHuman: false),
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { handlePetQuickDetail(item, pet: pet) },
                        action: { handlePetQuickPrimary(item, pet: pet) }
                    )
                },
                isEditMode: expandedQuickEdit.isEditMode,
                jiggle: expandedQuickEdit.jiggle,
                shouldReduceWork: shouldReduceWork,
                draggingItemId: $expandedQuickEdit.draggingItemId,
                onToggleEdit: {
                    expandedQuickEdit.isEditMode ? exitExpandedQAEditMode(for: pet) : enterExpandedQAEditMode(for: pet)
                },
                onMove: { fromId, toId in moveExpandedQuickEditItem(fromId: fromId, toId: toId) },
                onRemove: { id in removeExpandedQuickEditItem(id: id) }
            )
        } else if card.isReal,
                  card.isHuman,
                  let human = quickHumans.first(where: { $0.id == card.id })
        {
            let sourceItems = expandedQuickEdit.isEditMode
                ? expandedQuickEdit.items
                : expandedHumanQuickActionItems(for: human)
            let visibleLimit = expandedQuickEdit.isEditMode ? QuickActionLimit.maxItemsPerEntity : 6
            let items = Array(sourceItems.prefix(visibleLimit))
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: items.map { item in
                    VerticalHomeEmbeddedAction(
                        id: item.id,
                        title: item.label,
                        icon: item.icon,
                        isCompleted: false,
                        detailIcon: verticalEmbeddedDetailIcon(for: item.actionType, isHuman: true),
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { handleHumanQuickDetail(item, human: human) },
                        action: { handleHumanQuickPrimary(item, human: human) }
                    )
                },
                isEditMode: expandedQuickEdit.isEditMode,
                jiggle: expandedQuickEdit.jiggle,
                shouldReduceWork: shouldReduceWork,
                draggingItemId: $expandedQuickEdit.draggingItemId,
                onToggleEdit: {
                    expandedQuickEdit.isEditMode ? exitExpandedHumanQAEditMode(for: human) : enterExpandedHumanQAEditMode(for: human)
                },
                onMove: { fromId, toId in moveExpandedQuickEditItem(fromId: fromId, toId: toId) },
                onRemove: { id in removeExpandedQuickEditItem(id: id) }
            )
        } else {
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: [
                    VerticalHomeEmbeddedAction(
                        id: "primary",
                        title: card.isHuman ? l.homeQAWeight : l.homeQAFeed,
                        icon: card.isHuman ? "scalemass.fill" : "fork.knife",
                        isCompleted: false,
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { openQuickModule(.all, for: card) }
                    ) { openQuickModule(.primary, for: card) },
                    VerticalHomeEmbeddedAction(
                        id: "secondary",
                        title: card.isHuman ? l.expense : l.homeQAWater,
                        icon: card.isHuman ? "creditcard.fill" : "drop.fill",
                        isCompleted: false,
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { openQuickModule(.all, for: card) }
                    ) { openQuickModule(.secondary, for: card) },
                    VerticalHomeEmbeddedAction(
                        id: "tertiary",
                        title: card.isHuman ? l.homeQAMeds : l.tr(zh: "健康", en: "Health", de: "Gesundheit"),
                        icon: card.isHuman ? "pill.fill" : "cross.fill",
                        isCompleted: false,
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { openQuickModule(.all, for: card) }
                    ) { openQuickModule(.tertiary, for: card) },
                ]
            )
        }
    }

    private func verticalEmbeddedDetailIcon(for actionType: String, isHuman: Bool) -> String {
        if actionType.contains("medication") { return "list.bullet.rectangle.fill" }
        if actionType.contains("note") || actionType == "moment" { return "sparkles" }
        if actionType.contains("expense") { return "creditcard.fill" }
        if actionType.contains("weight") { return "chart.line.uptrend.xyaxis" }
        if isHuman { return "rectangle.stack.fill" }
        return "chart.line.uptrend.xyaxis"
    }

    private func expandedPetQuickActions(pet: Pet) -> some View {
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedQuickActionItems(for: pet).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: pet.id, data: snapshotController.avatarData(for: pet.id)).image
        let embedsActionsInVerticalCard = true

        return ExpandedPetQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            pet: pet,
            items: items,
            avatar: avatar,
            themeHex: pet.safeThemeColorHex,
            editItems: $expandedQuickEdit.items,
            draggingItemId: $expandedQuickEdit.draggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: expandedQuickEdit.isEditMode,
            jiggle: expandedQuickEdit.jiggle,
            shouldReduceWork: shouldReduceWork,
            showsHeader: !embedsActionsInVerticalCard,
            longPressStartsEdit: embedsActionsInVerticalCard,
            showFirstSuccessPrompt: false,
            waterManagementLabel: waterManagementLabel,
            onToggleEdit: {
                expandedQuickEdit.isEditMode ? exitExpandedQAEditMode(for: pet) : enterExpandedQAEditMode(for: pet)
            },
            onFirstSuccessFeed: { openPetQuickKey("feed", card: FocusCard.from(pet, includeAvatarData: true)) },
            onFirstSuccessPlay: { openPetQuickKey("play", card: FocusCard.from(pet, includeAvatarData: true)) },
            onFirstSuccessMoment: { expandedQuickMomentPet = pet },
            showsAttentionDot: { _ in false },
            countText: { ExpandedQuickActionLogic.countText(item: $0, pet: pet, allEvents: allEvents, allFeedCareLogs: pet.careLogs, now: Date()) },
            isCompleted: { ExpandedQuickActionLogic.isCompleted(item: $0, pet: pet, allEvents: allEvents, allFeedCareLogs: pet.careLogs, now: Date()) },
            onTap: { handlePetQuickPrimary($0, pet: pet) },
            onLongPress: { handlePetQuickDetail($0, pet: pet) },
            onGroomCheckIn: { _ in routeCoordinator.openSheet(.petHygiene(pet.id)) },
            onPottySelect: { _ in routeCoordinator.openSheet(.petPotty(pet.id)) },
            onHealthSelect: { _ in routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil)) },
            onLimitReached: { showingQuickActionLimitAlert = true }
        )
    }

    private func expandedHumanQuickActions(human: Human) -> some View {
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let defaultItems = ExpandedQuickActionDefaults.humanItems(for: human, localization: l)
        let avatar = FocusWalletAvatarCache.entry(for: human.id, data: snapshotController.avatarData(for: human.id)).image
        let embedsActionsInVerticalCard = true
        let viewedBy = UUID(uuidString: activeHumanIdStr)

        return ExpandedHumanQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            human: human,
            items: items,
            defaultItems: defaultItems,
            avatar: avatar,
            themeHex: human.safeThemeColorHex,
            editItems: $expandedQuickEdit.items,
            draggingItemId: $expandedQuickEdit.draggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: expandedQuickEdit.isEditMode,
            jiggle: expandedQuickEdit.jiggle,
            shouldReduceWork: shouldReduceWork,
            showsHeader: !embedsActionsInVerticalCard,
            longPressStartsEdit: embedsActionsInVerticalCard,
            onToggleEdit: {
                expandedQuickEdit.isEditMode ? exitExpandedHumanQAEditMode(for: human) : enterExpandedHumanQAEditMode(for: human)
            },
            countText: { item in
                if item.actionType == "humanMedication",
                   let warning = CarePlanOverdueStatusCalculator.humanMedicationWarning(
                       for: human,
                       medications: humanMedications,
                       logs: humanMedicationLogs
                   )
                {
                    return warning.compactText
                }
                return ExpandedQuickActionLogic.humanCountText(
                    item: item,
                    human: human,
                    isLocked: PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: viewedBy),
                    activeMedications: humanMedications,
                    todayMedicationLogs: humanMedicationLogs
                )
            },
            privacyIconName: { ExpandedQuickActionLogic.humanPrivacyIconName(for: $0, human: human) },
            privacyIconTint: { ExpandedQuickActionLogic.humanPrivacyIconTint(for: $0, human: human) },
            isPrivacyLocked: { PrivacyService.isHumanQuickActionLocked($0, human: human, viewedBy: viewedBy) },
            isCompleted: {
                ExpandedQuickActionLogic.humanCompleted(
                    item: $0,
                    human: human,
                    isLocked: PrivacyService.isHumanQuickActionLocked($0, human: human, viewedBy: viewedBy),
                    todayMedicationLogs: humanMedicationLogs
                )
            },
            feedbackActionKey: nil,
            feedbackToken: nil,
            onTap: { handleHumanQuickPrimary($0, human: human) },
            onLongPress: { handleHumanQuickDetail($0, human: human) },
            onLimitReached: { showingQuickActionLimitAlert = true }
        )
    }

    @ViewBuilder
    private func contextMenu(for card: FocusCard) -> some View {
        Button(l.tr(zh: "基本信息", en: "Basic Info", de: "Basisdaten")) { openCardBasicInfo(card) }
        Button(l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen")) { openAllFeatures(card) }
    }

    private func expandedQuickActionItems(for pet: Pet) -> [QuickActionItem] {
        ExpandedQuickActionStore.petItems(
            raw: quickActionItemsJSON,
            pet: pet,
            localization: l,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
    }

    private func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        ExpandedQuickActionStore.humanItems(
            raw: quickActionItemsJSON,
            human: human,
            localization: l
        )
    }

    private func enterExpandedQAEditMode(for pet: Pet) {
        expandedQuickEdit.enter(with: expandedQuickActionItems(for: pet), animation: HeroAnim.buttonSpring)
    }

    private func exitExpandedQAEditMode(for pet: Pet) {
        pressedExpandedActionId = nil
        quickActionItemsJSON = ExpandedQuickActionStore.savingPetItems(
            expandedQuickEdit.items,
            pet: pet,
            raw: quickActionItemsJSON,
            localization: l,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    private func enterExpandedHumanQAEditMode(for human: Human) {
        expandedQuickEdit.enter(with: expandedHumanQuickActionItems(for: human), animation: HeroAnim.buttonSpring)
    }

    private func exitExpandedHumanQAEditMode(for human: Human) {
        pressedExpandedActionId = nil
        quickActionItemsJSON = ExpandedQuickActionStore.savingHumanItems(
            expandedQuickEdit.items,
            human: human,
            raw: quickActionItemsJSON,
            localization: l
        )
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    private func moveExpandedQuickEditItem(fromId: String, toId: String) {
        guard let fromIndex = expandedQuickEdit.items.firstIndex(where: { $0.id == fromId }),
              let toIndex = expandedQuickEdit.items.firstIndex(where: { $0.id == toId })
        else { return }
        withAnimation(GoMotion.selection) {
            expandedQuickEdit.items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    private func removeExpandedQuickEditItem(id: String) {
        withAnimation(HeroAnim.buttonSpring) {
            expandedQuickEdit.items.removeAll { $0.id == id }
        }
    }

    private func handlePetQuickPrimary(_ item: QuickActionItem, pet: Pet) {
        OhanaFeedback.light()
        if item.actionType == "medication" {
            openExpandedQuickPetMedicationAdd(for: pet)
            return
        }

        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case let .perform(actionType):
            switch actionType {
            case "feed":
                performTodayFocusPetAction("feed", pet: pet)
            case "water":
                performTodayFocusPetAction("water", pet: pet)
            case "walk":
                performTodayFocusPetAction("walk", pet: pet)
            case "play":
                performTodayFocusPetAction("play", pet: pet)
            case "litter":
                performTodayFocusPetAction("litter", pet: pet)
            case "cageCleaning", "freeFlight", "misting", "substrateChange", "groom":
                performTodayFocusPetAction(actionType, pet: pet)
            default:
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            }
        case .waterManagement:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .weight:
            openExpandedQuickWeight(for: pet)
        case .expense:
            openExpandedQuickExpense(for: pet)
        case .moment:
            expandedQuickMomentPet = pet
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .none:
            break
        }
    }

    private func handlePetQuickDetail(_ item: QuickActionItem, pet: Pet) {
        OhanaFeedback.light()
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
            break
        }
    }

    private func handleHumanQuickPrimary(_ item: QuickActionItem, human: Human) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: false) {
        case .weightQuick:
            openExpandedQuickHumanWeight(for: human)
        case .workoutQuick:
            openExpandedQuickHumanWorkout(for: human)
        case .medicationAdd:
            openExpandedQuickHumanMedication(for: human)
        case .noteQuick:
            openExpandedQuickHumanNote(for: human)
        case .expenseQuick:
            openExpandedQuickHumanExpense(for: human)
        case .weightDetail:
            routeCoordinator.openSheet(.humanWeight(human.id))
        case .workoutDetail:
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case .medicationDetail:
            routeCoordinator.openSheet(.humanMedication(human.id))
        case .noteDetail:
            routeCoordinator.openSheet(.humanNote(human.id))
        case .expenseDetail:
            routeCoordinator.openSheet(.humanExpense(human.id))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        case .privacyAlert:
            showingHumanPrivacyAlert = true
        case .none:
            break
        }
    }

    private func handleHumanQuickDetail(_ item: QuickActionItem, human: Human) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.humanLongPressRoute(actionType: item.actionType, isLocked: false) {
        case .weightDetail, .weightQuick:
            routeCoordinator.openSheet(.humanWeight(human.id))
        case .workoutDetail, .workoutQuick:
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case .medicationDetail, .medicationAdd:
            routeCoordinator.openSheet(.humanMedication(human.id))
        case .noteDetail, .noteQuick:
            routeCoordinator.openSheet(.humanNote(human.id))
        case .expenseDetail, .expenseQuick:
            routeCoordinator.openSheet(.humanExpense(human.id))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        case .privacyAlert:
            showingHumanPrivacyAlert = true
        case .none:
            break
        }
    }

    @ViewBuilder
    private func quickInlineRecordOverlays() -> some View {
        FocusHomeQuickRecordOverlayLayer(
            router: routeCoordinator,
            pets: pets,
            humans: humans,
            preselectedPayerId: activeHumanIdStr,
            onPetWeightRewarded: { petId, delta in
                requestSnapshotRefresh()
                if delta > 0 {
                    showReward(amount: delta, label: "体重 +\(delta)🥥", cardId: petId)
                }
            },
            onPetExpenseRewarded: { petId, delta in
                requestSnapshotRefresh()
                if delta > 0 {
                    showReward(amount: delta, label: "花费 +\(delta)🥥", cardId: petId)
                }
            },
            onHumanSaved: { humanId, actionKey in
                requestSnapshotRefresh()
                showReward(amount: 2, label: rewardLabel(for: actionKey), cardId: humanId)
            },
            onManageHumanMedication: { human in
                routeCoordinator.openSheet(.humanMedication(human.id))
            },
            onPetMedicationSaved: { pet in
                commandExecutor.scheduleMedicationReminders(for: pet)
                requestSnapshotRefresh()
            }
        )
    }

    private func openExpandedQuickWeight(for pet: Pet) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openPetWeight(pet)
    }

    private func openExpandedQuickExpense(for pet: Pet) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openPetExpense(pet)
    }

    private func openExpandedQuickPetMedicationAdd(for pet: Pet) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openPetMedication(pet)
    }

    private func openExpandedQuickHumanWeight(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanWeight(human)
    }

    private func openExpandedQuickHumanWorkout(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanWorkout(human)
    }

    private func openExpandedQuickHumanMedication(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanMedication(human)
    }

    private func openExpandedQuickHumanNote(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanNote(human)
    }

    private func openExpandedQuickHumanExpense(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanExpense(human)
    }

    private func closeTransientMenusForQuickRecord() {
        withAnimation(routeAnimation) {
            fabExpanded = false
            fabMenuItemsVisible = false
        }
    }

    private func rewardLabel(for actionKey: String) -> String? {
        if actionKey.contains("humanWeight") { return l.tr(zh: "体重 +2🥥", en: "Weight +2🥥", de: "Gewicht +2🥥") }
        if actionKey.contains("humanExpense") { return l.tr(zh: "花费 +2🥥", en: "Expense +2🥥", de: "Ausgaben +2🥥") }
        if actionKey.contains("humanMedication") { return l.tr(zh: "用药 +2🥥", en: "Medication +2🥥", de: "Medikation +2🥥") }
        if actionKey.contains("humanWorkout") { return l.tr(zh: "运动 +2🥥", en: "Workout +2🥥", de: "Training +2🥥") }
        if actionKey.contains("humanNote") { return l.tr(zh: "记录 +2🥥", en: "Moment +2🥥", de: "Moment +2🥥") }
        return nil
    }

    private func currentExecutorId() -> String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }

    private func openTodayFocusQuestDetail(_ quest: IslandQuest) {
        routeTodayFocusQuest(quest, prefersDirectCompletion: false)
    }

    private func completeTodayFocusQuest(_ quest: IslandQuest) {
        routeTodayFocusQuest(quest, prefersDirectCompletion: true)
    }

    private func routeTodayFocusQuest(_ quest: IslandQuest, prefersDirectCompletion: Bool) {
        let activePets = pets.filter { !$0.hasPassedAway }

        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            switch quest.id {
            case IslandQuestEngine.oasisPetWizardQuestId:
                activeAddEntityType = humans.isEmpty ? .human : .pet
            case IslandQuestEngine.oasisFirstMealQuestId:
                if let pet = activePets.first {
                    if prefersDirectCompletion {
                        performTodayFocusPetAction("feed", pet: pet)
                    } else {
                        routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
                    }
                } else {
                    activeAddEntityType = .pet
                }
            default:
                showingOasisReward = true
            }
            return
        }

        if quest.id.hasPrefix("q_feed_"), let pet = todayFocusPet(for: quest, in: activePets) {
            prefersDirectCompletion ? performTodayFocusPetAction("feed", pet: pet) : (routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false)))
            return
        }

        if quest.id.hasPrefix("q_water_"), !quest.id.hasPrefix("q_water_plant"), let pet = todayFocusPet(for: quest, in: activePets) {
            prefersDirectCompletion ? performTodayFocusPetAction("water", pet: pet) : (routeCoordinator.openSheet(.petWater(pet.id)))
            return
        }

        switch quest.id {
        case "q_walk":
            if let pet = todayFocusPet(for: quest, in: activePets) {
                todayFocusWalkPet = pet
            }
        case "q_potty":
            if let pet = todayFocusPet(for: quest, in: activePets) {
                let isSharedLitterPet = pet.species.contains("猫") || pet.species.contains("兔")
                if prefersDirectCompletion {
                    isSharedLitterPet ? performTodayFocusPetAction("litter", pet: pet) : performTodayFocusPottyCheckIn(pet)
                } else {
                    isSharedLitterPet ? (routeCoordinator.openSheet(.petLitter(pet.id))) : (routeCoordinator.openSheet(.petPotty(pet.id)))
                }
            }
        case let id where id.hasPrefix("q_play_"):
            if let pet = todayFocusPet(for: quest, in: activePets) {
                prefersDirectCompletion ? performTodayFocusPetAction("play", pet: pet) : (routeCoordinator.openSheet(.petPlay(pet.id)))
            }
        case let id where id.hasPrefix("q_weight_"):
            if let pet = todayFocusPet(for: quest, in: activePets) {
                routeCoordinator.openSheet(.petWeight(pet.id))
            }
        case let id where IslandQuestEngine.humanWeightId(fromQuestId: id) != nil:
            if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: id),
               let human = humans.first(where: { $0.id == humanId })
            {
                openTodayFocusHumanWeight(human)
            }
        case let id where id.hasPrefix("q_moment_"):
            if let pet = todayFocusPet(for: quest, in: activePets) {
                routeCoordinator.openSheet(.petMomentHistory(pet.id))
            }
        case "q_water_plant", "q_fertilize_plant":
            if let plant = todayFocusPlant(for: quest) {
                selectedPlant = plant
            }
        case "q_reminder":
            openHeaderCalendarDestination()
        case "q_visit":
            if let pet = todayFocusPet(for: quest, in: activePets) ?? activePets.first {
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: .symptomVisit))
            }
        default:
            if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
               let event = allEvents.first(where: { $0.id == eventId })
            {
                prefersDirectCompletion ? completeTodayFocusEvent(event) : openTodayFocusEvent(event)
            } else if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id),
                      let pet = activePets.first(where: { $0.medications.contains(where: { $0.id == medicationId }) })
            {
                prefersDirectCompletion ? performTodayFocusMedicationDose(pet: pet, medicationId: medicationId) : (routeCoordinator.openSheet(.petMedication(pet.id)))
            }
        }
    }

    private func todayFocusPet(for quest: IslandQuest, in activePets: [Pet]) -> Pet? {
        guard let target = quest.targetPetId else { return activePets.first }
        return activePets.first { $0.id == target }
    }

    private func todayFocusPlant(for quest: IslandQuest) -> Plant? {
        guard let target = quest.targetPlantId else { return plants.first }
        return plants.first { $0.id == target }
    }

    private func performTodayFocusPetAction(_ actionType: String, pet: Pet) {
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
            completePlannedFeed: completeTodayFocusPlannedFeed,
            showAntiRepeat: { title, message, pendingAction in
                antiRepeatTitle = title
                antiRepeatMessage = message
                pendingRepeatAction = pendingAction
                showingAntiRepeatAlert = true
            },
            startWalk: startWalkInExpandedCard,
            openWaterManagement: { routeCoordinator.openSheet(.petWater($0.id)) },
            openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) },
            feedback: applyTodayFocusExecutorFeedback
        )
    }

    private func completeTodayFocusPlannedFeed(_ pet: Pet) -> Bool {
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
        let delta = (reward?.humanGot ?? 0) + (reward?.petGot ?? 0)
        applyTodayFocusExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: pet.id,
                coconutDelta: delta,
                label: delta > 0 ? "喂食 +\(delta)🥥" : nil
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func performTodayFocusPottyCheckIn(_ pet: Pet) {
        commandExecutor.applyPottyCheckIn(
            raw: PottyType.perfectPoop.rawValue,
            pet: pet,
            executorId: currentExecutorId(),
            feedback: applyTodayFocusExecutorFeedback
        )
    }

    private func performTodayFocusMedicationDose(pet: Pet, medicationId: UUID) {
        guard let medication = pet.medications.first(where: { $0.id == medicationId }) else {
            routeCoordinator.openSheet(.petMedication(pet.id))
            return
        }
        commandExecutor.recordMedicationDose(medication: medication, pet: pet)
        applyTodayFocusExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(cardId: pet.id, coconutDelta: 1, label: "用药 +1🥥")
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func completeTodayFocusEvent(_ event: Event) {
        commandExecutor.completeTodayFocusEvent(event)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyTodayFocusExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        requestSnapshotRefresh()
        if feedback.coconutDelta > 0 {
            showReward(amount: feedback.coconutDelta, label: feedback.label, cardId: feedback.cardId)
        }
    }

    private func openTodayFocusHumanWeight(_ human: Human) {
        guard !PrivacyService.isLocked(.weight, for: human, viewedBy: UUID(uuidString: activeHumanIdStr)) else {
            showingHumanPrivacyAlert = true
            return
        }
        routeCoordinator.openSheet(.humanWeight(human.id))
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
        FocusHomeTodayFocusRouter.routeEventToFeature(
            event,
            pets: pets,
            actions: FocusHomeTodayFocusRouter.EventActions(
                openHealth: { pet, section in
                    routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
                },
                openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) }
            )
        )
    }

    private func openFamilyTaskFromTodayFocus(_ task: FamilyCollaborationTask) {
        if let petId = task.relatedPetId,
           let petUUID = UUID(uuidString: petId),
           let pet = pets.first(where: { $0.id == petUUID && !$0.hasPassedAway })
        {
            if let eventId = task.relatedEventId,
               let eventUUID = UUID(uuidString: eventId),
               let event = allEvents.first(where: { $0.id == eventUUID })
            {
                openTodayFocusEvent(event)
            } else {
                selectedPetTab = .overview
                selectedPet = pet
            }
            return
        }
        showingCrewRoster = true
    }

    private func confirmTodayFocusExchange(_ request: CoconutExchangeRequest) {
        guard let receiver = activeHuman else { return }
        do {
            try commandExecutor.confirmCoconutExchange(request, receiver: receiver)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            requestSnapshotRefresh()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func handleTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        guard let pet = FocusHomeTodayFocusRouter.petForNegativeSignal(
            signal,
            pets: pets,
            activePet: activePetForFocus
        ) else { return }

        FocusHomeTodayFocusRouter.handleNegativeSignal(
            signal,
            pet: pet,
            actions: FocusHomeTodayFocusRouter.NegativeSignalActions(
                openHealth: { pet, section in
                    routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
                },
                openWeight: { routeCoordinator.openSheet(.petWeight($0.id)) },
                expandPet: { expandWalletToCard(id: $0.id) }
            )
        )
    }

    private func handleWalletCardTap(card: FocusCard, count _: Int, isHero: Bool) {
        wallet.triggerTapFeedback()
        AppPerformanceMonitor.shared.record("homeV3.cardTapAccepted", valueMS: 0, note: card.name)
        if isHero || wallet.isExpanded {
            collapseWalletToHome()
        } else {
            expandWalletToCard(id: card.id)
        }
    }

    private func expandWalletToCard(id: UUID) {
        let frozenCards = displayCards
        verticalSolidMotion.freeze(makeVerticalSolidRenderSnapshot(cards: frozenCards))
        wallet.expandToCard(
            id: id,
            animation: walletExpandAnimation,
            shouldReduceWork: shouldReduceWork,
            cancelAvatarLoad: { snapshotController.cancelAvatarLoad() },
            resetSurfaces: {
                expandedQuickEdit.reset()
                pressedExpandedActionId = nil
                fabExpanded = false
                fabMenuItemsVisible = false
            }
        )
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 220 : 680) {
            guard wallet.isExpanded, wallet.activeCardId == id else { return }
            verticalSolidMotion.unlockStableExpandedState()
        }
    }

    private var isWalkCardExpandedSurfaceVisible: Bool {
        guard wallet.isExpanded,
              let activeCard,
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

    private func syncWalkCardSurfaceVisibility() {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = isWalkCardExpandedSurfaceVisible
    }

    private func startWalkInExpandedCard(_ pet: Pet) {
        let isAlreadyExpandedPetCard = wallet.isExpanded && wallet.activeCardId == pet.id
        let startIfIdle = {
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
            }
            syncWalkCardSurfaceVisibility()
        }

        if isAlreadyExpandedPetCard {
            startIfIdle()
            return
        }

        walkTransform.trigger(
            for: pet,
            expand: expandWalletToCard(id:),
            pulse: { _ in }
        )
        syncWalkCardSurfaceVisibility()
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 140 : 540) {
            guard wallet.activeCardId == pet.id else { return }
            startIfIdle()
        }
    }

    private func resetExpandedWalletInteractionSurfaces() {
        expandedQuickEdit.reset()
        pressedExpandedActionId = nil
        fabExpanded = false
        fabMenuItemsVisible = false
    }

    private func collapseWalletToHome() {
        let frozenCards = displayCards
        verticalSolidMotion.freeze(makeVerticalSolidRenderSnapshot(cards: frozenCards))
        wallet.collapseToHome(
            animation: walletCollapseAnimation,
            shouldReduceWork: shouldReduceWork,
            returningPreviewId: nil,
            visibleCards: { visibleCards },
            resetSurfaces: {
                resetExpandedWalletInteractionSurfaces()
            },
            clearRosterPreview: {}
        )
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 220 : 580) {
            guard !wallet.isExpanded, wallet.heroProgress <= 0.001 else { return }
            refreshSnapshot(force: true)
            verticalSolidMotion.thawAfterCollapse()
        }
    }

    private func collapseHiddenHomeWalletForDirectTabSelection() {
        wallet.collapseHiddenHomeWithoutAnimation(
            resetSurfaces: {
                resetExpandedWalletInteractionSurfaces()
            },
            clearRosterPreview: {}
        )
        refreshSnapshot(force: true)
    }

    private func scheduleHiddenWalletCleanupAfterDirectTabSelection(to tab: VerticalHomeTab) {
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: directTabHiddenWalletCleanupDelayMilliseconds) {
            guard verticalTabVisualState.selectedTab == tab, wallet.isExpanded else { return }
            collapseHiddenHomeWalletForDirectTabSelection()
        }
    }

    private var isHomeMotionBusy: Bool {
        isWalletHeroTransitioning || verticalSolidMotion.isHeroMotionActive || verticalSolidMotion.isTabMotionLocked
    }

    private func scheduleSnapshotRefreshAfterFirstFrame(force: Bool = false) {
        snapshotRefreshGeneration &+= 1
        let generation = snapshotRefreshGeneration
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 48 : 96) {
            guard generation == snapshotRefreshGeneration else { return }
            requestSnapshotRefresh(force: force)
        }
    }

    private func requestSnapshotRefresh(force: Bool = false) {
        snapshotRefreshGeneration &+= 1
        let generation = snapshotRefreshGeneration
        guard isHomeMotionBusy else {
            refreshSnapshot(force: force)
            return
        }

        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 180 : 620) {
            guard generation == snapshotRefreshGeneration else { return }
            if isHomeMotionBusy {
                requestSnapshotRefresh(force: force)
            } else {
                refreshSnapshot(force: force)
            }
        }
    }

    private func refreshSnapshot(force: Bool = false) {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let now = Date()
        let nextCards = buildHomeCards(now: now)
        let nextSignature = homeSnapshotSignature(for: nextCards, dependencyKey: cardSourceDependencyKey)
        guard force || !snapshotController.snapshotInitialized || nextSignature != lastAppliedCardSourceSignature else {
            seedActiveHumanAvatarData()
            return
        }
        lastAppliedCardSourceSignature = nextSignature
        snapshotController.refresh(
            snapshot: nextCards,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            isExpanded: wallet.isExpanded,
            walletTransitionCardId: wallet.transitionCardId
        )
        seedActiveHumanAvatarData()
        AppPerformanceMonitor.shared.record("home.snapshotRefresh", startedAt: startedAt, note: "\(nextCards.count) cards")
    }

    private func seedActiveHumanAvatarData() {
        guard let human = activeHuman else { return }
        snapshotController.seedAvatarData(cardId: human.id, data: human.avatarImageData)
    }

    private func scheduleActiveHumanAvatarSeed() {
        OhanaFrameScheduler.runAfterNextFrame {
            seedActiveHumanAvatarData()
        }
    }

    private func handleMemberProfileDidChange(_ notification: Notification) {
        let id = (notification.userInfo?["id"] as? String).flatMap(UUID.init(uuidString:))
        snapshotController.invalidateMemberAppearance(cardId: id)
        requestSnapshotRefresh(force: true)
        if let id {
            snapshotController.seedAvatarData(
                cardId: id,
                data: FocusHomeCardDataSource.avatarDataForHomeCard(id: id, pets: pets, humans: humans)
            )
            snapshotController.seedPopoutData(
                cardId: id,
                data: FocusHomeCardDataSource.popoutDataForHomeCard(
                    id: id,
                    pets: pets,
                    equipFxPopoutCard: equipFxPopoutCard
                )
            )
        }
    }

    private func routePendingReminderNotificationIfNeeded() {
        guard let userInfo = OhanaNotificationRouteCenter.shared.pendingRoute() else { return }
        _ = routeReminderNotification(userInfo)
    }

    private func handleReminderRouteRequest(_ userInfo: [AnyHashable: Any]?) {
        _ = routeReminderNotification(userInfo)
    }

    @discardableResult
    private func routeReminderNotification(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let payload = OhanaReminderRoutePayload(userInfo: userInfo) else { return false }
        return routeReminderNotification(payload)
    }

    @discardableResult
    private func routeReminderNotification(_ userInfo: [String: Any]?) -> Bool {
        guard let payload = OhanaReminderRoutePayload(userInfo: userInfo) else { return false }
        return routeReminderNotification(payload)
    }

    @discardableResult
    private func routeReminderNotification(_ payload: OhanaReminderRoutePayload) -> Bool {
        guard let destination = FocusHomeReminderDeepLinkRouter.destination(
            for: payload,
            reminders: pendingReminders,
            events: allEvents,
            pets: pets,
            humans: humans,
            plants: plants,
            humanMedications: humanMedications
        ) else {
            return false
        }

        closeReminderNotificationSurfaces()
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 40 : 90) {
            openReminderNotificationDestination(destination)
        }
        OhanaNotificationRouteCenter.shared.clearPendingRoute(reminderId: payload.reminderId?.uuidString)
        return true
    }

    private func closeReminderNotificationSurfaces() {
        selectedPet = nil
        selectedHuman = nil
        selectedPlant = nil
        selectedPetTab = .overview
        functionMenuPresentation = nil
        showingCalendar = false
        calendarEntityFilterId = nil
        calendarHumanFilterId = nil
        todayFocusWalkPet = nil
        expandedQuickMomentPet = nil
        routeCoordinator.resetAllRoutes()
        fabExpanded = false
        fabMenuItemsVisible = false
    }

    private func openReminderNotificationDestination(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            openPetQuickKey(key, card: FocusCard.from(pet, includeAvatarData: true))
        case let .petFeature(feature, pet):
            openPetFeature(feature, card: FocusCard.from(pet, includeAvatarData: true))
        case let .petHealth(pet, section):
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, card: FocusCard.from(human, includeAvatarData: true))
        case let .humanDetail(human):
            selectedHuman = human
        case let .plant(plant):
            selectedPlant = plant
        case let .functionMenu(destination):
            functionMenuPresentation = FunctionMenuPresentation(destination: destination)
        case let .calendar(entityId, humanId):
            calendarEntityFilterId = entityId
            calendarHumanFilterId = humanId
            showingCalendar = true
        }
    }

    private func handlePetSaved(_ pet: Pet) {
        refreshSnapshot(force: true)
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
            openCard(FocusCard.from(pet, includeAvatarData: true))
        }
    }

    private func openCard(_ card: FocusCard) {
        snapshotController.seedAvatarData(cardId: card.id, data: card.avatarImageData)
        snapshotController.seedPopoutData(cardId: card.id, data: card.cardPopoutImageData)
        showingCrewRoster = false
        if !displayCards.contains(where: { $0.id == card.id }) {
            homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: card.id, currentRaw: homeCardOrderRaw)
            refreshSnapshot(force: true)
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            expandWalletToCard(id: card.id)
        }
    }

    private func openCardBasicInfo(_ card: FocusCard) {
        if card.isHuman {
            if let human = humans.first(where: { $0.id == card.id }) {
                routeCoordinator.openSheet(.humanBasicInfo(human.id))
            }
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            routeCoordinator.openSheet(.petBasicInfo(pet.id))
        }
    }

    private func openAllFeatures(_ card: FocusCard) {
        if card.isHuman {
            if let human = humans.first(where: { $0.id == card.id }) {
                routeCoordinator.openSheet(.humanAllFeatures(human.id))
            }
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openQuickModule(_ action: FocusHomeQuickAction, for card: FocusCard) {
        OhanaFeedback.light()
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            switch action {
            case .primary: routeCoordinator.openSheet(.humanWeight(human.id))
            case .secondary: routeCoordinator.openSheet(.humanExpense(human.id))
            case .tertiary: routeCoordinator.openSheet(.humanMedication(human.id))
            case .all: routeCoordinator.openSheet(.humanAllFeatures(human.id))
            }
            return
        }

        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch action {
        case .primary:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .secondary:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .tertiary:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .all:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func expandedFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman { return FocusHomeFabShortcutPolicy.humanShortcuts(localization: l) }
        return [
            ExpandedCardFabShortcut(label: l.tr(zh: "饮食", en: "Food", de: "Futter"), icon: "fork.knife", action: .detail(.food)),
            ExpandedCardFabShortcut(label: l.tr(zh: "健康", en: "Health", de: "Gesundheit"), icon: "cross.fill", action: .detail(.health)),
            ExpandedCardFabShortcut(label: l.tr(zh: "记录", en: "Moments", de: "Momente"), icon: "sparkles", action: .detail(.moments)),
            ExpandedCardFabShortcut(label: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "ellipsis.circle.fill", action: .allFeatures),
        ]
    }

    private func openHomeFabShortcut(_ shortcut: HomeFabFunctionShortcut) {
        guard shortcut.isAvailable else { return }
        functionMenuPresentation = FunctionMenuPresentation(destination: shortcut.destination)
    }

    private func selectVerticalTab(_ tab: VerticalHomeTab) {
        guard verticalTabVisualState.selectedTab != tab else {
            closeVerticalFabMenu()
            return
        }
        guard !verticalSolidMotion.isTabMotionLocked, !isWalletHeroTransitioning else {
            OhanaFeedback.light()
            return
        }
        if wallet.isExpanded {
            selectVerticalTabFromExpandedWallet(tab)
            return
        }
        applyVerticalTabSelection(tab)
    }

    private func selectVerticalTabFromExpandedWallet(_ tab: VerticalHomeTab) {
        guard verticalTabVisualState.selectedTab == .home else {
            collapseHiddenHomeWalletForDirectTabSelection()
            applyVerticalTabSelection(tab)
            return
        }

        applyVerticalTabSelection(tab)
        scheduleHiddenWalletCleanupAfterDirectTabSelection(to: tab)
    }

    private func applyVerticalTabSelection(_ tab: VerticalHomeTab) {
        closeVerticalFabMenuForNavigation()
        verticalSolidMotion.lockForTabMotion()
        verticalTabVisualState.select(tab)
        let commitDelay: UInt64 = shouldReduceWork ? 140 : 520
        verticalTabVisualState.scheduleCommit(for: tab, milliseconds: commitDelay) {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedVerticalTab = tab
            }
        }
        verticalSolidMotion.unlockAfterTabMotion(milliseconds: shouldReduceWork ? 160 : 560)
    }

    private func closeVerticalFabMenu() {
        guard fabExpanded || fabMenuItemsVisible else { return }
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

    private func closeVerticalFabMenuForNavigation() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            fabMenuItemsVisible = false
            fabExpanded = false
        }
    }

    private func openExpandedFabShortcut(_ shortcut: ExpandedCardFabShortcut, card: FocusCard) {
        switch shortcut.action {
        case .allFeatures:
            openAllFeatures(card)
        case .humanAllFeatures:
            openAllFeatures(card)
        case let .detail(feature):
            openPetFeature(feature, card: card)
        case let .quick(key):
            openPetQuickKey(key, card: card)
        case let .humanQuick(key):
            openHumanQuickKey(key, card: card)
        }
    }

    private func openPetFeature(_ feature: PetFeature, card: FocusCard) {
        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch feature {
        case .food: routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .hygiene: routeCoordinator.openSheet(.petHygiene(pet.id))
        case .health: routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medications: routeCoordinator.openSheet(.petMedication(pet.id))
        case .walks: routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .potty: routeCoordinator.openSheet(.petPotty(pet.id))
        case .weight: routeCoordinator.openSheet(.petWeight(pet.id))
        case .expense: routeCoordinator.openSheet(.petExpense(pet.id))
        case .moments: routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .basicInfo: routeCoordinator.openSheet(.petBasicInfo(pet.id))
        default: routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openPetQuickKey(_ key: String, card: FocusCard) {
        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch key {
        case "feed": routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case "water": routeCoordinator.openSheet(.petWater(pet.id))
        case "potty": routeCoordinator.openSheet(.petPotty(pet.id))
        case "litter": routeCoordinator.openSheet(.petLitter(pet.id))
        case "walk": routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case "play": routeCoordinator.openSheet(.petPlay(pet.id))
        case "health": routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case "weight": routeCoordinator.openSheet(.petWeight(pet.id))
        case "expense": routeCoordinator.openSheet(.petExpense(pet.id))
        case "moment": routeCoordinator.openSheet(.petMomentHistory(pet.id))
        default: routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openHumanQuickKey(_ key: String, card: FocusCard) {
        guard let human = humans.first(where: { $0.id == card.id }) else { return }
        switch key {
        case "humanWeight": routeCoordinator.openSheet(.humanWeight(human.id))
        case "humanExpense": routeCoordinator.openSheet(.humanExpense(human.id))
        case "humanMedication": routeCoordinator.openSheet(.humanMedication(human.id))
        case "humanWorkout": routeCoordinator.openSheet(.humanWorkout(human.id))
        case "humanNote": routeCoordinator.openSheet(.humanNote(human.id))
        default: routeCoordinator.openSheet(.humanAllFeatures(human.id))
        }
    }

    private func showReward(amount: Int, label: String?, cardId _: UUID?) {
        expandedCoconutRewardAmount = amount
        expandedCoconutRewardLabel = label
        showExpandedCoconutReward = true
    }
}

enum FocusHomeQuickAction {
    case primary
    case secondary
    case tertiary
    case all
}
