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

    @Environment(\.ohanaDisplayCornerRadius) var displayCornerRadius
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared
    @Bindable var questMgr = QuestManager.shared

    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") var showDummyCards = false
    @AppStorage("shop_equip_fx_popout_card") var equipFxPopoutCard = true
    @AppStorage("ohana_show_first_success_card") var showFirstSuccessCard = false
    @AppStorage("ohana_first_quick_checkin_completed") var firstQuickCheckInCompleted = false
    @AppStorage("quickActionItems_v2") var quickActionItemsJSON: String = ""

    @StateObject var wallet = FocusHomeWalletController()
    @StateObject var verticalSolidMotion = VerticalSolidHomeMotionCoordinator()
    @StateObject var snapshotController = FocusHomeSnapshotController()
    @StateObject var expandedQuickEdit = ExpandedQuickActionEditController()
    @StateObject var routeCoordinator = HomeRouteCoordinator()
    @StateObject var walkTransform = FocusHomeWalkTransformController()

    @State var activeVerticalHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    @State var headerStreak = 0
    @State var didRecordHomeFirstFrame = false
    @State var lastAppliedCardSourceSignature = ""
    @State var firstFrameCards: [FocusCard] = []
    @State var firstFrameCardSourceSignature = ""
    @State var snapshotRefreshGeneration = 0
    @State var pressedExpandedActionId: String? = nil

    @State var fabExpanded = false
    @State var fabMenuItemsVisible = false
    @State var showExpandedCoconutReward = false
    @State var expandedCoconutRewardAmount = 0
    @State var expandedCoconutRewardLabel: String? = nil
    @State var verticalTabVisualState = VerticalHomeTabVisualState()
    @State var selectedVerticalTab: VerticalHomeTab = .home
    @State var isVerticalTodayFocusCollapsed = false
    @State var verticalCalendarAddEventTrigger = 0
    @State var verticalOasisInjectEnergyTrigger = 0

    var l: L10n { L10n(appLanguage) }
    var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full
    }

    var walletExpandAnimation: Animation {
        if shouldReduceWork { return HeroAnim.walletReduced }
        return GoMotion.zStackHero
    }

    var walletCollapseAnimation: Animation {
        if shouldReduceWork { return HeroAnim.walletReduced }
        return GoMotion.zStackHero
    }

    var directTabHiddenWalletCleanupDelayMilliseconds: UInt64 {
        shouldReduceWork ? 260 : 700
    }

    var routeAnimation: Animation { shouldReduceWork ? GoMotion.reduced : GoMotion.page }

    var activeHuman: Human? {
        if let id = UUID(uuidString: activeHumanIdStr), let human = humans.first(where: { $0.id == id }) {
            return human
        }
        return humans.first
    }

    var currentCoconutBalance: Int {
        activeHuman?.coconutBalance ?? questMgr.coconutCount
    }

    var headerContextCard: FocusCard? {
        guard verticalTabVisualState.selectedTab == .home,
              wallet.isExpanded || wallet.heroProgress > 0.98,
              let id = wallet.activeCardId else { return nil }
        let cachedCards = snapshotController.cards(fallback: [])
        return displayCards.first(where: { $0.id == id }) ?? cachedCards.first(where: { $0.id == id })
    }

    var headerCoconutBalance: Int {
        guard let card = headerContextCard else { return currentCoconutBalance }
        return card.coconutBalance
    }

    var headerCoconutDeltaContext: String {
        if let card = headerContextCard {
            return "card-\(card.id.uuidString)"
        }
        return "current-human-\(activeHuman?.id.uuidString ?? "global")"
    }

    var waterManagementLabel: String {
        l.tr(zh: "管理", en: "Manage", de: "Verwalten")
    }

    func buildHomeCards(now: Date = Date()) -> [FocusCard] {
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

    var activeHumanAvatarImage: UIImage? {
        guard let human = activeHuman else { return nil }
        let avatarData = snapshotController.avatarData(for: human.id)
            ?? (snapshotController.snapshotInitialized ? nil : human.avatarImageData)
        return FocusWalletAvatarCache.entry(for: human.id, data: avatarData).image
    }

    var visibleCards: [FocusCard] {
        let base = snapshotController.cards(fallback: firstFrameCards)
        return snapshotController.visibleCards(
            from: base,
            rosterPreviewCard: nil,
            isExpanded: wallet.isExpanded,
            activeCardId: wallet.activeCardId
        )
    }

    var displayCards: [FocusCard] {
        if let frozenCards = verticalSolidMotion.cards {
            return frozenCards
        }
        return visibleCards
    }

    var heroSelectedCardId: UUID? {
        guard wallet.isExpanded || wallet.transitionCardId != nil || wallet.heroProgress > 0.001 else { return nil }
        return wallet.activeCardId ?? wallet.transitionCardId
    }

    var activeCard: FocusCard? {
        guard let id = wallet.activeCardId else { return nil }
        return displayCards.first(where: { $0.id == id })
    }

    var shouldShowExpandedWalletCardRootHitZone: Bool {
        wallet.isExpanded && wallet.heroProgress > 0.985 && activeCard != nil
    }

    var isWalletHeroTransitioning: Bool {
        wallet.transitionCardId != nil || (wallet.heroProgress > 0.001 && wallet.heroProgress < 0.999)
    }

    var activePetForFocus: Pet? {
        if let id = wallet.activeCardId,
           let pet = activePets.first(where: { $0.id == id })
        {
            return pet
        }
        return activePets.first
    }

    var verticalSolidPageRenderSnapshot: VerticalSolidHomeRenderSnapshot {
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
            activeHumanIdStr: $activeHumanIdStr,
            onAddEntityDismissed: { refreshSnapshot(force: true) },
            onPetSavedFromAddEntity: handlePetSaved,
            onCrewPetSelected: { pet in openCard(FocusCard.from(pet, includeAvatarData: true)) },
            onCrewHumanSelected: { human in openCard(FocusCard.from(human, includeAvatarData: true)) },
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { humanId in showReward(amount: 2, label: "用药 +2🥥", cardId: humanId) }
        )
    }

    func handleHomeAppear() {
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
                AppPerformanceMonitor.shared.record("VerticalSolidHome 首帧", startedAt: ohanaProcessStartTime)
            }
        }
        routePendingReminderNotificationIfNeeded()
    }

    func handleActiveHumanChanged() {
        scheduleActiveHumanAvatarSeed()
        headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdStr)
    }

    func rootSceneWithLifecycle(geo: GeometryProxy) -> some View {
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
    func rootScene(geo: GeometryProxy) -> some View {
        verticalSolidRoot(geo: geo)
    }

    @ViewBuilder
    func verticalSolidRoot(geo: GeometryProxy) -> some View {
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
                        routeCoordinator.openAddEntity(.plant)
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

    var cardSourceDependencyKey: String {
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

    var firstFrameCardDependencyKey: String {
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

    func buildFirstFrameCards() -> [FocusCard] {
        FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards
        )
    }

    func primeFirstFrameCardsIfNeeded(force: Bool = false) {
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

    func homeSnapshotSignature(for cards: [FocusCard], dependencyKey: String) -> String {
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

    func header(safeTop: CGFloat) -> some View {
        FocusHomeHeaderView(
            safeTop: safeTop,
            streak: headerStreak,
            coconutBalance: headerCoconutBalance,
            coconutDeltaContext: headerCoconutDeltaContext,
            activeHumanDisplayName: activeHuman?.name ?? l.tr(zh: "本人", en: "Me", de: "Ich"),
            activeHumanAvatarImage: activeHumanAvatarImage,
            activeHumanAvatarEmoji: activeHuman?.avatarEmoji,
            onStreak: { routeCoordinator.openStreakDetail() },
            onCoconut: openHeaderCoconutDestination,
            onCrew: { routeCoordinator.openCrewRoster() },
            onAccountSwitcher: { routeCoordinator.openAccountSwitcher() },
            onCalendar: openHeaderCalendarDestination,
            onSettings: { routeCoordinator.openSettings() }
        )
    }

    func openHeaderCoconutDestination() {
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

    func openHeaderCalendarDestination() {
        let entityID: String?
        let humanID: String?
        if let card = headerContextCard {
            if card.isHuman, humans.contains(where: { $0.id == card.id }) {
                humanID = card.id.uuidString
                entityID = nil
            } else if pets.contains(where: { $0.id == card.id }) {
                entityID = card.id.uuidString
                humanID = nil
            } else {
                entityID = nil
                humanID = nil
            }
        } else {
            entityID = nil
            humanID = nil
        }
        routeCoordinator.openCalendar(entityID: entityID, humanID: humanID)
    }

    func expandedWalletCardRootHitZone(geo: GeometryProxy) -> some View {
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

    func homeSafeTop(_ geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.top, 50)
    }

    func homeSafeBottom(_ geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.bottom, 22)
    }

    func makeVerticalSolidRenderSnapshot(cards: [FocusCard]) -> VerticalSolidHomeRenderSnapshot {
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

    func verticalSolidHomePage(
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
            heroSnapshot: activeVerticalHeroSnapshot,
            onSelect: { snapshot in handleWalletCardTap(snapshot: snapshot, count: displayCards.count, isHero: false) },
            onCollapse: collapseWalletToHome,
            onLongPress: openCardBasicInfo,
            onAddPet: { routeCoordinator.openAddEntity(.pet) },
            onAddHuman: { routeCoordinator.openAddEntity(.human) },
            onOpenQuest: openTodayFocusQuestDetail,
            onCompleteQuest: completeTodayFocusQuest,
            onTapNegativeSignal: handleTodayFocusNegativeSignal,
            onTapOasis: { routeCoordinator.openOasisReward() },
            onTapFamilyTask: openFamilyTaskFromTodayFocus,
            onConfirmExchange: confirmTodayFocusExchange,
            onFirstSuccessFeed: { routeCoordinator.openSheet(.petFeed($0.id, opensManualSheet: false)) },
            onFirstSuccessPlay: { routeCoordinator.openSheet(.petPlay($0.id)) },
            onFirstSuccessMoment: { routeCoordinator.openQuickMoment($0) }
        )
    }

    func handleWalletCardTap(snapshot: FocusHomeVerticalSolidHeroSnapshot, count _: Int, isHero: Bool) {
        handleWalletCardTap(card: snapshot.card, heroSnapshot: snapshot, isHero: isHero)
    }

    func handleWalletCardTap(card: FocusCard, count _: Int, isHero: Bool) {
        handleWalletCardTap(card: card, heroSnapshot: nil, isHero: isHero)
    }

    private func handleWalletCardTap(card: FocusCard, heroSnapshot: FocusHomeVerticalSolidHeroSnapshot?, isHero: Bool) {
        wallet.triggerTapFeedback()
        AppPerformanceMonitor.shared.record("verticalSolidHome.cardTapAccepted", valueMS: 0, note: card.name)
        if isHero || wallet.isExpanded {
            collapseWalletToHome()
        } else {
            if let heroSnapshot {
                expandWalletToCard(snapshot: heroSnapshot)
            } else {
                expandWalletToCard(id: card.id)
            }
        }
    }

    func expandWalletToCard(id: UUID) {
        let card = displayCards.first(where: { $0.id == id })
        let snapshot = card.map { makeFallbackVerticalHeroSnapshot(for: $0) }
        expandWalletToCard(id: id, snapshot: snapshot)
    }

    func expandWalletToCard(snapshot: FocusHomeVerticalSolidHeroSnapshot) {
        expandWalletToCard(id: snapshot.card.id, snapshot: snapshot)
    }

    private func expandWalletToCard(id: UUID, snapshot: FocusHomeVerticalSolidHeroSnapshot?) {
        let frozenCards = displayCards
        verticalSolidMotion.freeze(makeVerticalSolidRenderSnapshot(cards: frozenCards))
        setActiveVerticalHeroSnapshot(snapshot ?? frozenCards.first(where: { $0.id == id }).map { makeFallbackVerticalHeroSnapshot(for: $0) })
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
        ) {
            guard wallet.isExpanded, wallet.activeCardId == id else { return }
            OhanaFrameScheduler.runAfterNextFrame {
                guard wallet.isExpanded, wallet.activeCardId == id else { return }
                refreshActiveVerticalHeroSnapshotIfPossible()
                verticalSolidMotion.unlockStableExpandedState()
            }
        }
    }

    private func makeFallbackVerticalHeroSnapshot(for card: FocusCard) -> FocusHomeVerticalSolidHeroSnapshot {
        let index = displayCards.firstIndex { $0.id == card.id } ?? 0
        return FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private func setActiveVerticalHeroSnapshot(_ snapshot: FocusHomeVerticalSolidHeroSnapshot?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVerticalHeroSnapshot = snapshot
        }
    }

    private func refreshActiveVerticalHeroSnapshotIfPossible() {
        guard let snapshot = activeVerticalHeroSnapshot,
              let card = visibleCards.first(where: { $0.id == snapshot.card.id }) ?? displayCards.first(where: { $0.id == snapshot.card.id })
        else { return }
        setActiveVerticalHeroSnapshot(snapshot.updatingCard(card))
    }

    var isWalkCardExpandedSurfaceVisible: Bool {
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

    func syncWalkCardSurfaceVisibility() {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = isWalkCardExpandedSurfaceVisible
    }

    func startWalkInExpandedCard(_ pet: Pet) {
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

    func resetExpandedWalletInteractionSurfaces() {
        expandedQuickEdit.reset()
        pressedExpandedActionId = nil
        fabExpanded = false
        fabMenuItemsVisible = false
    }

    func collapseWalletToHome() {
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
        ) {
            guard !wallet.isExpanded, wallet.heroProgress <= 0.001 else { return }
            OhanaFrameScheduler.runAfterNextFrame {
                guard !wallet.isExpanded, wallet.heroProgress <= 0.001 else { return }
                refreshSnapshot(force: true)
                verticalSolidMotion.thawAfterCollapse()
                OhanaFrameScheduler.runAfterNextFrame {
                    guard !wallet.isExpanded, wallet.heroProgress <= 0.001 else { return }
                    setActiveVerticalHeroSnapshot(nil)
                }
            }
        }
    }

    func collapseHiddenHomeWalletForDirectTabSelection() {
        wallet.collapseHiddenHomeWithoutAnimation(
            resetSurfaces: {
                resetExpandedWalletInteractionSurfaces()
            },
            clearRosterPreview: {}
        )
        refreshSnapshot(force: true)
    }

    func scheduleHiddenWalletCleanupAfterDirectTabSelection(to tab: VerticalHomeTab) {
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: directTabHiddenWalletCleanupDelayMilliseconds) {
            guard verticalTabVisualState.selectedTab == tab, wallet.isExpanded else { return }
            collapseHiddenHomeWalletForDirectTabSelection()
        }
    }

    var isHomeMotionBusy: Bool {
        isWalletHeroTransitioning || verticalSolidMotion.isHeroMotionActive || verticalSolidMotion.isTabMotionLocked
    }

    func scheduleSnapshotRefreshAfterFirstFrame(force: Bool = false) {
        snapshotRefreshGeneration &+= 1
        let generation = snapshotRefreshGeneration
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 48 : 96) {
            guard generation == snapshotRefreshGeneration else { return }
            requestSnapshotRefresh(force: force)
        }
    }

    func requestSnapshotRefresh(force: Bool = false) {
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

    func refreshSnapshot(force: Bool = false) {
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

    func seedActiveHumanAvatarData() {
        guard let human = activeHuman else { return }
        snapshotController.seedAvatarData(cardId: human.id, data: human.avatarImageData)
    }

    func scheduleActiveHumanAvatarSeed() {
        OhanaFrameScheduler.runAfterNextFrame {
            seedActiveHumanAvatarData()
        }
    }
}
