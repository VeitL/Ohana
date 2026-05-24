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
    @Query(sort: \OasisElectronicPet.obtainedAt, order: .reverse) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(filter: #Predicate<PetCareLog> { $0.type == "喂食" },
           sort: \PetCareLog.date,
           order: .reverse) private var allFeedCareLogs: [PetCareLog]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query private var activeHumanMedications: [HumanMedication]
    @Query private var todayHumanMedicationLogs: [HumanMedicationLog]
    @Query private var recentHumanExpenseLogs: [PetExpenseLog]
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
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
    @State private var homeCritterNestCatalogId: String? = nil
    @State private var activeCoconutLogSubject: CoconutLogSubject? = nil
    @State private var cardFabExpanded     = false
    @State private var cardFabMenuItemsVisible = false
    @State private var expandedAllFeaturesPet: Pet? = nil
    @State private var expandedAllFeaturesHuman: Human? = nil
    @State private var expandedBasicInfoPet: Pet? = nil
    @State private var expandedBasicInfoHuman: Human? = nil
    @State private var pressedExpandedActionId: String? = nil
    @State private var expandedQuickActionMenuTarget: ExpandedQuickActionMenuTarget? = nil
    @StateObject private var quickRecordRouter = FocusHomeQuickRecordRouter()
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
    @State private var todayFocusWalkPet: Pet? = nil
    @State private var expandedQuickMomentPet: Pet? = nil
    @State private var expandedMomentHistoryPet: Pet? = nil
    @State private var expandedQuickHumanMedication: Human? = nil
    @State private var expandedHumanWeightDetail: Human? = nil
    @State private var expandedHumanWorkoutDetail: Human? = nil
    @State private var expandedHumanExpenseDetail: Human? = nil
    @State private var expandedHumanNoteDetail: Human? = nil
    @StateObject private var expandedQuickEdit = ExpandedQuickActionEditController()
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    private var maxCardsPerPage: Int { FocusHomeCardDataSource.maxCardsPerPage }
    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full
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
    private var transitionAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : HeroAnim.transitionSpring
    }
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
    @State private var showExpandedCoconutReward = false
    @State private var expandedCoconutRewardAmount = 0
    @State private var expandedCoconutRewardLabel: String? = nil
    @StateObject private var homeReorder = FocusHomeReorderController()
    @StateObject private var homeSafeArea = FocusHomeSafeAreaController()
    @StateObject private var firstSuccess = FocusHomeFirstSuccessController()
    @StateObject private var walkTransform = FocusHomeWalkTransformController()
    @State private var didRecordHomeFirstFrame = false
    @StateObject private var homeSnapshotController = FocusHomeSnapshotController()
    @State private var walletHeroCardsSnapshot: [FocusCard]? = nil
    @State private var quickActionClockTick = Date()

    // Debug-only: show Mochi/Luna dummy stack even when real data is empty.
    @AppStorage("debugShowDummyCards") private var showDummyCards: Bool = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw: String = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr: String = ""
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard: Bool = true
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false

    // Bloom expand (dummy cards only)
    @Namespace private var ns
    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var detailFooterVisible: Bool = false

    // Apple-Wallet-style stack state lives in a controller so card taps only touch
    // the wallet state machine, not every unrelated home route.
    @StateObject private var wallet = FocusHomeWalletController()
    @State private var rosterPreviewCard: FocusCard?
    @State private var pendingPromotedHomeCardId: UUID?

    private var todayFocusActivePet: Pet? {
        if let id = wallet.activeCardId,
           let pet = pets.first(where: { $0.id == id && !$0.hasPassedAway }) {
            return pet
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    private var safeAreaTop: CGFloat {
        homeSafeArea.top
    }

    private var safeAreaBottom: CGFloat {
        homeSafeArea.bottom
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

    private var headerCoconutDeltaContext: String {
        if let activeWalletCard {
            return "card-\(activeWalletCard.id.uuidString)"
        }
        return "current-human-\(activeHuman?.id.uuidString ?? "global")"
    }

    private var cards: [FocusCard] {
        homeSnapshotController.cards(fallback: buildHomeCardSnapshot())
    }

    private var homeCardSnapshotSourceSignature: String {
        FocusHomeCardDataSource.sourceSignature(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
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
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards
        )
    }

    private func refreshHomeCardSnapshot() {
        let snapshot = buildHomeCardSnapshot()
        homeSnapshotController.refresh(
            snapshot: snapshot,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            isExpanded: wallet.isExpanded,
            walletTransitionCardId: wallet.transitionCardId
        )
    }

    private func scheduleVisibleAvatarDataLoad(from source: [FocusCard]? = nil) {
        homeSnapshotController.scheduleVisibleAvatarDataLoad(
            from: source,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            isExpanded: wallet.isExpanded,
            walletTransitionCardId: wallet.transitionCardId
        )
    }

    private func runHomePostFirstFrameMaintenance() {
        FocusHomeFirstFrameMaintenance.runAfterFirstFrame(
            activeHumanId: activeHumanIdStr,
            rewardTitle: l.homeDailyCheckInRewardTitle,
            updateHeaderStreak: { headerStreak = $0 },
            syncWalkSurfaceVisibility: syncWalkCardSurfaceVisibility,
            prepareWalletTapFeedback: { wallet.prepareTapFeedback() }
        )
    }

    private var visibleHomeCards: [FocusCard] {
        var visible = homeSnapshotController.visibleCards(
            from: cards,
            rosterPreviewCard: rosterPreviewCard,
            isExpanded: wallet.isExpanded,
            activeCardId: wallet.activeCardId
        )
        guard let liveCard = liveHeroCardForCurrentTransition(),
              let index = visible.firstIndex(where: { $0.id == liveCard.id })
        else { return visible }

        var merged = liveCard
        merged.avatarImageData = visible[index].avatarImageData ?? liveCard.avatarImageData
        merged.cardPopoutImageData = visible[index].cardPopoutImageData ?? liveCard.cardPopoutImageData
        visible[index] = merged
        return visible
    }

    private var visibleHomeCardIdsSignature: String {
        homeSnapshotController.visibleIdsSignature(cards: cards, rosterPreviewCard: rosterPreviewCard)
    }

    private func withLoadedAvatarData(_ cards: [FocusCard]) -> [FocusCard] {
        homeSnapshotController.withLoadedAvatarData(cards)
    }

    private var isEmptyState: Bool {
        pets.allSatisfy { $0.hasPassedAway } && humans.isEmpty && !showDummyCards
    }

    private var activeWalletCard: FocusCard? {
        guard wallet.isExpanded else { return nil }
        let heroId = wallet.activeCardId ?? visibleHomeCards.first?.id
        return visibleHomeCards.first { $0.id == heroId }
    }

    private var heroQuickModuleCard: FocusCard? {
        guard wallet.isExpanded || wallet.transitionCardId != nil || wallet.heroProgress > 0.001 else { return nil }
        let heroId = wallet.activeCardId ?? wallet.transitionCardId ?? visibleHomeCards.first?.id
        return visibleHomeCards.first { $0.id == heroId }
    }

    private func liveHeroCardForCurrentTransition() -> FocusCard? {
        guard wallet.isExpanded || wallet.transitionCardId != nil || wallet.heroProgress > 0.001 else { return nil }
        guard let id = wallet.activeCardId ?? wallet.transitionCardId else { return nil }
        if let pet = pets.first(where: { $0.id == id }) {
            return FocusCard.from(pet, includeAvatarData: false)
        }
        if let human = humans.first(where: { $0.id == id }) {
            return FocusCard.from(human, includeAvatarData: false)
        }
        return nil
    }

    private var isWalkCardExpandedSurfaceVisible: Bool {
        guard wallet.isExpanded,
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
            router: quickRecordRouter,
            quickActionMenu: expandedQuickActionMenuTarget
        )
    }

    private var isHomeCritterNestPresented: Bool {
        homeCritterNestCatalogId != nil
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

                if expandedId == nil && !isHomeCritterNestPresented {
                    heroQuickModulesOverlay(geo: geo)
                        .zIndex(640)
                }

                if let id = expandedId,
                   let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo, outerCornerRadius: outerR, windowSize: windowSize)
                }

                // FAB stays mounted while the wallet card stack changes modes; only its submenu content changes.
                FocusHomeFabOverlayHost(
                    isVisible: expandedId == nil && !isInlineRecordOverlayPresented && !isHomeCritterNestPresented,
                    activeCard: activeWalletCard,
                    bottomPadding: floatingFabBottomPadding,
                    homeShortcuts: HomeFabShortcutCatalog.primaryShortcuts,
                    expandedShortcuts: activeWalletCard.map { expandedCardFabShortcuts(for: $0) } ?? [],
                    isExpanded: $fabExpanded,
                    itemsVisible: $fabMenuItemsVisible,
                    onHomeShortcut: openHomeFabShortcut,
                    onExpandedShortcut: openExpandedCardFabShortcut
                )
                .zIndex(999)

                if isHomeCritterNestPresented {
                    homeCritterNestPopupOverlay(geo: geo)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(2400)
                }

                quickInlineRecordOverlays()
                    .zIndex(2500)

                expandedQuickActionMenuOverlay()
                    .zIndex(2600)
            }
            .onAppear { homeSafeArea.stabilize(from: geo) }
            .onChange(of: geo.safeAreaInsets.top) { _, _ in
                homeSafeArea.stabilize(from: geo)
            }
            .onChange(of: geo.safeAreaInsets.bottom) { _, _ in
                homeSafeArea.stabilize(from: geo)
            }
            .animation(transitionAnimation, value: expandedId)
            .animation(GoMotion.page, value: quickRecordRouter.petWeight?.id)
            .animation(GoMotion.page, value: quickRecordRouter.petExpense?.id)
            .animation(GoMotion.page, value: quickRecordRouter.humanWeight?.id)
            .animation(GoMotion.page, value: quickRecordRouter.humanWorkout?.id)
            .animation(GoMotion.page, value: quickRecordRouter.humanMedication?.id)
            .animation(GoMotion.page, value: quickRecordRouter.petMedication?.id)
            .animation(GoMotion.page, value: quickRecordRouter.humanNote?.id)
            .animation(GoMotion.page, value: quickRecordRouter.humanExpense?.id)
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
        .focusHomeRouteSheets(
            pets: pets,
            l: l,
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
            expandedAllFeaturesPet: $expandedAllFeaturesPet,
            expandedAllFeaturesHuman: $expandedAllFeaturesHuman,
            expandedBasicInfoPet: $expandedBasicInfoPet,
            expandedBasicInfoHuman: $expandedBasicInfoHuman,
            expandedQuickWeightDetailPet: $expandedQuickWeightDetailPet,
            expandedQuickExpenseDetailPet: $expandedQuickExpenseDetailPet,
            expandedQuickFeedDetailPet: $expandedQuickFeedDetailPet,
            expandedQuickFeedOpensManualSheet: $expandedQuickFeedOpensManualSheet,
            expandedQuickWaterDetailPet: $expandedQuickWaterDetailPet,
            expandedQuickPottyDetailPet: $expandedQuickPottyDetailPet,
            expandedQuickLitterDetailPet: $expandedQuickLitterDetailPet,
            expandedQuickPlayDetailPet: $expandedQuickPlayDetailPet,
            expandedQuickHygienePet: $expandedQuickHygienePet,
            expandedQuickWalkPet: $expandedQuickWalkPet,
            todayFocusWalkPet: $todayFocusWalkPet,
            expandedQuickHealthPet: $expandedQuickHealthPet,
            expandedQuickHealthInitialSection: $expandedQuickHealthInitialSection,
            expandedQuickPetMedicationPet: $expandedQuickPetMedicationPet,
            expandedQuickMomentPet: $expandedQuickMomentPet,
            expandedMomentHistoryPet: $expandedMomentHistoryPet,
            expandedQuickHumanMedication: $expandedQuickHumanMedication,
            expandedHumanWeightDetail: $expandedHumanWeightDetail,
            expandedHumanWorkoutDetail: $expandedHumanWorkoutDetail,
            expandedHumanExpenseDetail: $expandedHumanExpenseDetail,
            expandedHumanNoteDetail: $expandedHumanNoteDetail,
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
            onAddEntityDismissed: handleAddEntityDismissed,
            onPetSavedFromAddEntity: handlePetSavedFromAddEntity,
            onCrewPetSelected: { pet in
                openCrewRosterCard(FocusCard.from(pet, includeAvatarData: true))
            },
            onCrewHumanSelected: { human in
                openCrewRosterCard(FocusCard.from(human, includeAvatarData: true))
            },
            onFirstSuccessMomentCompleted: completeFirstSuccessMomentIfNeeded,
            onHumanDoseTaken: { humanId in
                triggerExpandedActionFeedback(cardId: humanId)
            }
        )
        // Collapse wallet hero state when returning from pet/human detail
        .onChange(of: selectedPet)   { _, new in if new == nil { collapseWalletToHome() } }
        .onChange(of: selectedHuman) { _, new in if new == nil { collapseWalletToHome() } }
        .onChange(of: wallet.isExpanded) { _, expanded in
            if expanded, homeReorder.pressCandidateId != nil || homeReorder.hasActiveInteraction {
                resetHomeCardReorderState()
            }
            if expanded {
                cardFabMenuItemsVisible = false
                cardFabExpanded = false
            } else {
                scheduleVisibleAvatarDataLoad()
            }
            syncWalkCardSurfaceVisibility()
        }
        .onChange(of: wallet.activeCardId) { _, _ in
            if wallet.isExpanded {
                cardFabMenuItemsVisible = false
                cardFabExpanded = false
            }
            syncWalkCardSurfaceVisibility()
        }
        .onChange(of: PetWalkingManager.shared.phase) { _, _ in syncWalkCardSurfaceVisibility() }
        .onChange(of: PetWalkingManager.shared.currentPet?.id) { _, _ in syncWalkCardSurfaceVisibility() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdStr)
        }
        .onChange(of: activeHumanIdStr) { _, _ in
            FocusHomeFirstFrameMaintenance.refreshDailyCheckIn(
                activeHumanId: activeHumanIdStr,
                rewardTitle: l.homeDailyCheckInRewardTitle,
                updateHeaderStreak: { headerStreak = $0 }
            )
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            guard workloadPolicy.shouldRunTimer() else { return }
            quickActionClockTick = date
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReturnHomeAfterHumanDeletion)) { _ in
            selectedHuman = nil
            expandedBasicInfoHuman = nil
            expandedAllFeaturesHuman = nil
            quickRecordRouter.resetHumanRoutes()
            expandedQuickHumanMedication = nil
            expandedHumanWeightDetail = nil
            expandedHumanWorkoutDetail = nil
            expandedHumanExpenseDetail = nil
            expandedHumanNoteDetail = nil
            withAnimation(walletCollapseAnimation) {
                wallet.activeCardId = nil
                wallet.isExpanded = false
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
        if !homeReorder.isEnabled {
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 800) {
                homeReorder.setEnabled(true)
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
            router: quickRecordRouter,
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
            }
        )
    }

    private func closeQuickActionMenusForInlineRecord() {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
    }

    private func openExpandedQuickWeight(for pet: Pet) {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openPetWeight(pet)
    }

    private func openExpandedQuickExpense(for pet: Pet) {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openPetExpense(pet)
    }

    private func openExpandedQuickHumanWeight(for human: Human, actionType: String = "humanWeight") {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openHumanWeight(human, actionType: actionType)
    }

    private func openExpandedQuickHumanExpense(for human: Human, actionType: String = "humanExpense") {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openHumanExpense(human, actionType: actionType)
    }

    private func openExpandedQuickHumanNote(for human: Human, actionType: String = "humanNote") {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openHumanNote(human, actionType: actionType)
    }

    private func openExpandedQuickHumanWorkout(for human: Human, actionType: String = "humanWorkout") {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openHumanWorkout(human, actionType: actionType)
    }

    private func openExpandedQuickHumanMedication(for human: Human, actionType: String = "humanMedication") {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openHumanMedication(human, actionType: actionType)
    }

    private func openExpandedQuickPetMedicationAdd(for pet: Pet) {
        closeQuickActionMenusForInlineRecord()
        quickRecordRouter.openPetMedication(pet)
    }

    private func stackLayer(geo: GeometryProxy, outerCornerRadius: CGFloat) -> some View {
        let activePets = pets.filter { !$0.hasPassedAway }
        let topInset = homeSafeArea.resolvedTop(in: geo)
        return FocusHomeStackLayerView(
            topInset: topInset,
            isEmptyState: isEmptyState,
            cardMargin: K.cardMargin,
            onAddPet: { presentAddEntity(initialType: .pet) },
            onAddHuman: { presentAddEntity(initialType: .human) },
            header: goFocusHeader,
            todayFocus: { todayFocusSection(activePets: activePets) },
            wallet: {
                walletCardStack(cards: visibleHomeCards)
                    .opacity(isHomeCritterNestPresented ? 0 : 1)
                    .allowsHitTesting(!isHomeCritterNestPresented)
            }
        )
    }

    private func homeCritterNestPopupOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.34) // ui-v4: allow modal scrim
                .ignoresSafeArea()
                .onTapGesture {
                    closeHomeCritterNest()
                }

            OasisCritterCodexView(
                mode: .nest,
                initialCatalogId: homeCritterNestCatalogId,
                isPopup: true
            ) {
                closeHomeCritterNest()
            }
            .frame(
                width: min(geo.size.width - 20, 430),
                height: min(geo.size.height - 86, 760)
            )
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func heroQuickModulesOverlay(geo: GeometryProxy) -> some View {
        let progress = HomeHeroTransitionProgress(value: wallet.heroProgress).clamped
        if let card = heroQuickModuleCard, progress > 0.001 {
            let moduleHeight = expandedQuickModuleHeight(for: card)
            expandedQuickModules(card: card)
                .frame(width: max(0, geo.size.width - K.cardMargin * 2), height: moduleHeight)
                .position(
                    x: geo.size.width / 2,
                    y: safeAreaTop + K.expandedCardGlobalTopOffset + K.expandedCardH + K.expandedQuickModuleGap + moduleHeight / 2
                )
                .modifier(HomeHeroQuickModuleRevealModifier(progress: progress))
                .simultaneousGesture(collapseWalletDragGesture())
                .transition(.identity)
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
                isExpanded: wallet.isExpanded,
                cardMargin: K.cardMargin,
                animation: walletAnimation,
                onOpenQuest: { completeQuestInFocusStack($0) },
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
    // fan  (wallet.isExpanded=false): all cards fan vertically at the bottom of the
    //   available area. idx n-1 is frontmost (highest z). Tap any card → hero.
    //
    // hero (wallet.isExpanded=true): tapped card lifts to top of available area;
    //   ALL other cards compress into a tight stack at the bottom. Tap hero → restore.
    //   Tap another card → switch hero. Swipe-down → restore fan.
    //
    // Layout uses GeometryReader so the stack fills all space below the mood strip
    // and cards can animate across the full height.

    private func expandedQuickModuleHeight(for card: FocusCard) -> CGFloat {
        let visibleCount: Int
        if card.isReal,
           !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            visibleCount = expandedQuickEdit.isEditMode
                ? expandedQuickEdit.items.count + 1
                : min(expandedQuickActionItems(for: pet).count, 8)
        } else if card.isReal,
                  card.isHuman,
                  let human = humans.first(where: { $0.id == card.id }) {
            visibleCount = expandedQuickEdit.isEditMode
                ? expandedQuickEdit.items.count + 1
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

    private func saveHomeCardOrder(_ cards: [FocusCard]) {
        homeCardOrderRaw = FocusHomeCardDataSource.encodedOrder(for: cards)
        refreshHomeCardSnapshot()
    }

    private func promoteHomeCardToFront(id: UUID) {
        homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: id, currentRaw: homeCardOrderRaw)
        refreshHomeCardSnapshot()
    }

    private func homeCardDisplayCards(from source: [FocusCard]) -> [FocusCard] {
        homeReorder.displayCards(from: source)
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
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedQuickActionItems(for: pet).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: pet.id, data: homeSnapshotController.avatarData(for: pet.id)).image
        let themeHex = pet.safeThemeColorHex

        return ExpandedPetQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            pet: pet,
            items: items,
            avatar: avatar,
            themeHex: themeHex,
            editItems: $expandedQuickEdit.items,
            draggingItemId: $expandedQuickEdit.draggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: expandedQuickEdit.isEditMode,
            jiggle: expandedQuickEdit.jiggle,
            shouldReduceWork: shouldReduceWork,
            showFirstSuccessPrompt: false,
            waterManagementLabel: waterManagementLabel,
            onToggleEdit: {
                if expandedQuickEdit.isEditMode {
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
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: human.id, data: homeSnapshotController.avatarData(for: human.id)).image
        let themeHex = human.safeThemeColorHex

        return ExpandedHumanQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            human: human,
            items: items,
            defaultItems: ExpandedQuickActionDefaults.humanItems(for: human, localization: l),
            avatar: avatar,
            themeHex: themeHex,
            editItems: $expandedQuickEdit.items,
            draggingItemId: $expandedQuickEdit.draggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: expandedQuickEdit.isEditMode,
            jiggle: expandedQuickEdit.jiggle,
            shouldReduceWork: shouldReduceWork,
            onToggleEdit: {
                if expandedQuickEdit.isEditMode {
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

    @ViewBuilder
    private func expandedQuickActionMenuOverlay() -> some View {
        ExpandedQuickActionMenuOverlayHost(
            target: $expandedQuickActionMenuTarget,
            colorScheme: colorScheme,
            l: l,
            waterManagementLabel: waterManagementLabel,
            petIsCompleted: expandedPetQuickCompleted,
            petStatus: expandedPetQuickCountText,
            humanIsLocked: expandedHumanQuickActionIsPrivate,
            humanStatus: expandedHumanQuickCountText,
            onPetQuick: runPetQuickMenuPrimary,
            onPetDetail: handleExpandedQuickLongPress,
            onPetOption: runPetQuickMenuOption,
            onHumanQuick: runHumanQuickMenuPrimary,
            onHumanDetail: handleExpandedHumanQuickLongPress
        )
    }

    private func runPetQuickMenuPrimary(_ item: QuickActionItem, pet: Pet) {
        ExpandedQuickActionMenuRouter.runPetPrimary(
            item,
            pet: pet,
            localization: l,
            actions: expandedQuickMenuPetActions
        )
    }

    private func runPetQuickMenuOption(_ optionId: String, item: QuickActionItem, pet: Pet) {
        ExpandedQuickActionMenuRouter.runPetOption(
            optionId,
            item: item,
            pet: pet,
            actions: expandedQuickMenuPetActions
        )
    }

    private func runHumanQuickMenuPrimary(_ item: QuickActionItem, human: Human) {
        ExpandedQuickActionMenuRouter.runHumanPrimary(
            item,
            human: human,
            actions: expandedQuickMenuHumanActions
        )
    }

    private var expandedQuickMenuPetActions: ExpandedQuickActionMenuRouter.PetActions {
        ExpandedQuickActionMenuRouter.PetActions(
            detail: handleExpandedQuickLongPress,
            quick: handleExpandedQuickAction,
            medicationAdd: openExpandedQuickPetMedicationAdd,
            groomOption: applyExpandedGroomCheckIn,
            pottyOption: applyExpandedPottyCheckIn
        )
    }

    private var expandedQuickMenuHumanActions: ExpandedQuickActionMenuRouter.HumanActions {
        ExpandedQuickActionMenuRouter.HumanActions(
            quick: handleExpandedHumanQuickAction
        )
    }

    @ViewBuilder
    private func walletCardStack(cards: [FocusCard]) -> some View {
        let displayCards = walletHeroCardsSnapshot ?? homeCardDisplayCards(from: cards)

        FocusWalletCardStackView(
            cards: displayCards,
            pets: pets,
            isExpanded: wallet.isExpanded,
            activeCardId: wallet.activeCardId,
            heroProgress: wallet.heroProgress,
            heroDirection: wallet.heroDirection,
            namespace: ns,
            heroNamespace: heroNS,
            expandedId: expandedId,
            avatarCacheRevision: homeSnapshotController.avatarCacheRevision,
            safeAreaTop: safeAreaTop,
            safeAreaBottom: safeAreaBottom,
            walletAnimation: walletAnimation,
            reorderDragId: homeReorder.dragId,
            reorderDragOffset: homeReorder.dragOffset,
            isReorderModeActive: homeReorder.isModeActive,
            isReorderEnabled: homeReorder.isEnabled,
            transitionCardId: wallet.transitionCardId,
            actionPulseCardId: expandedActionPulseCardId,
            walkTransformBurstCardId: walkTransform.burstCardId,
            quickModuleHeight: expandedQuickModuleHeight,
            quickModules: { card in
                expandedQuickModules(card: card)
                    .simultaneousGesture(collapseWalletDragGesture())
            },
            contextMenuContent: { card in
                cardContextMenu(card: card)
            },
            onTapCard: handleWalletCardTap,
            onCollapsedLongPress: startHomeCardReorderFromLongPress,
            onCollapsedDragChanged: { card, cards, translationY, collapsedBottomY in
                updateHomeCardReorder(
                    cardId: card.id,
                    cards: cards,
                    dragTranslationY: translationY,
                    collapsedBottomY: collapsedBottomY
                )
            },
            onCollapsedDragEnded: { card, cards, translationY, collapsedBottomY in
                updateHomeCardReorder(
                    cardId: card.id,
                    cards: cards,
                    dragTranslationY: translationY,
                    collapsedBottomY: collapsedBottomY
                )
                commitHomeCardReorder()
                resetHomeCardReorderState()
            },
            onHeroLongPress: { card in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                openWalletCardBasicInfo(card)
            },
            onSwipeDownToCollapse: collapseWalletToHome,
            onInitialActiveCardNeeded: { id in
                wallet.activeCardId = id
            },
            onCardsChanged: { ids in
                if let dragging = homeReorder.dragId, !ids.contains(dragging) {
                    resetHomeCardReorderState()
                } else if let candidate = homeReorder.pressCandidateId, !ids.contains(candidate) {
                    cancelHomeCardPressCandidate()
                }
                if let pendingPromotedHomeCardId,
                   ids.contains(pendingPromotedHomeCardId) {
                    wallet.activeCardId = pendingPromotedHomeCardId
                    self.pendingPromotedHomeCardId = nil
                    return
                }
                guard wallet.activeCardId == nil || !ids.contains(wallet.activeCardId!) else { return }
                wallet.activeCardId = ids.first
            }
        )
    }

    private func updateHomeCardReorder(
        cardId: UUID,
        cards: [FocusCard],
        dragTranslationY: CGFloat,
        collapsedBottomY: CGFloat
    ) {
        homeReorder.update(
            cardId: cardId,
            sourceCards: cards,
            dragTranslationY: dragTranslationY,
            collapsedBottomY: collapsedBottomY,
            animation: walletAnimation
        )
    }

    private func commitHomeCardReorder() {
        guard let reorderedCards = homeReorder.reorderedCardsForCommit() else { return }
        saveHomeCardOrder(reorderedCards)
    }

    private func resetHomeCardReorderState() {
        homeReorder.reset()
    }

    private func enterHomeCardReorderMode() {
        homeReorder.enterMode(
            isExpanded: wallet.isExpanded,
            visibleCount: visibleHomeCards.count,
            animation: GoMotion.feedback
        ) {
            fabExpanded = false
        }
    }

    private func beginHomeCardPressCandidate(card: FocusCard, cards: [FocusCard], currentOffsetY: CGFloat) {
        homeReorder.beginPressCandidate(
            card: card,
            cards: cards,
            currentOffsetY: currentOffsetY,
            isExpanded: { wallet.isExpanded }
        ) {
            enterHomeCardReorderMode()
            beginHomeCardReorder(card: card, cards: cards, currentOffsetY: currentOffsetY)
        }
    }

    private func cancelHomeCardPressCandidate() {
        homeReorder.cancelPressCandidate()
    }

    private func beginHomeCardReorder(card: FocusCard, cards: [FocusCard], currentOffsetY: CGFloat) {
        homeReorder.beginReorder(
            card: card,
            cards: cards,
            currentOffsetY: currentOffsetY,
            animation: walletAnimation
        )
        fabExpanded = false
    }

    private func startHomeCardReorderFromLongPress(
        card: FocusCard,
        cards: [FocusCard],
        currentOffsetY: CGFloat
    ) {
        homeReorder.startFromLongPress(
            card: card,
            cards: cards,
            currentOffsetY: currentOffsetY,
            isExpanded: wallet.isExpanded,
            visibleCount: visibleHomeCards.count,
            modeAnimation: GoMotion.feedback,
            liftAnimation: walletAnimation
        ) {
            fabExpanded = false
        }
    }

    // Fan:  tap any card → lift that card to the active position.
    // Hero: tap active card → restore fan; long-press active card → basic info.
    //       Tap any inactive card strip → restore fan.
    //       Swipe-down → restore fan (via DragGesture above).
    private func handleWalletCardTap(card: FocusCard, n: Int, isHero: Bool) {
        if card.isElectronicPet {
            guard !homeReorder.suppressNextTap else {
                homeReorder.suppressNextTap = false
                return
            }
            guard !homeReorder.hasActiveInteraction else {
                resetHomeCardReorderState()
                return
            }
            presentHomeCritterNest(for: card)
            return
        }

        wallet.handleCardTap(
            card: card,
            visibleCount: n,
            isHero: isHero,
            hasActiveReorderInteraction: { homeReorder.hasActiveInteraction },
            consumeSuppressedTap: {
                guard homeReorder.suppressNextTap else { return false }
                homeReorder.suppressNextTap = false
                return true
            },
            resetReorder: resetHomeCardReorderState,
            expand: expandWalletToCard(id:),
            collapse: collapseWalletToHome,
            recordLatency: { startedAt, cardName in
                DispatchQueue.main.async {
                    AppPerformanceMonitor.shared.record("卡片展开状态提交", startedAt: startedAt, note: cardName)
                    AppPerformanceMonitor.shared.record("卡片点击延迟", startedAt: startedAt, note: cardName)
                }
            }
        )
    }

    private func presentHomeCritterNest(for card: FocusCard? = nil) {
        fabExpanded = false
        fabMenuItemsVisible = false
        cardFabExpanded = false
        cardFabMenuItemsVisible = false
        expandedQuickEdit.reset()
        if wallet.isExpanded || wallet.transitionCardId != nil || wallet.heroProgress > 0.001 {
            collapseWalletToHome()
        } else if homeReorder.hasActiveInteraction {
            resetHomeCardReorderState()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(GoMotion.page) {
            homeCritterNestCatalogId = card?.critterCatalogId ?? activeWalletCard?.critterCatalogId ?? OasisUpgradeRewardCatalog.firstCritterId
        }
    }

    private func closeHomeCritterNest() {
        withAnimation(GoMotion.page) {
            homeCritterNestCatalogId = nil
        }
    }

    private func expandWalletToCard(id: UUID) {
        if homeReorder.hasActiveInteraction {
            resetHomeCardReorderState()
        }
        walletHeroCardsSnapshot = homeCardDisplayCards(from: visibleHomeCards)

        wallet.expandToCard(
            id: id,
            animation: walletExpandAnimation,
            shouldReduceWork: shouldReduceWork,
            cancelAvatarLoad: { homeSnapshotController.cancelAvatarLoad() },
            resetSurfaces: {
                fabExpanded = false
                cardFabExpanded = false
                cardFabMenuItemsVisible = false
                expandedQuickEdit.reset()
            }
        )
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 240 : 760) {
            guard wallet.isExpanded, wallet.activeCardId == id else { return }
            walletHeroCardsSnapshot = nil
        }
    }

    private func collapseWalletToHome() {
        if homeReorder.hasActiveInteraction {
            resetHomeCardReorderState()
        }
        refreshHomeCardSnapshot()
        walletHeroCardsSnapshot = homeCardDisplayCards(from: visibleHomeCards)
        let returningPreviewId = rosterPreviewCard?.id == wallet.activeCardId ? rosterPreviewCard?.id : nil
        wallet.collapseToHome(
            animation: walletCollapseAnimation,
            shouldReduceWork: shouldReduceWork,
            returningPreviewId: returningPreviewId,
            visibleCards: { visibleHomeCards },
            resetSurfaces: {
                fabExpanded = false
                cardFabExpanded = false
                cardFabMenuItemsVisible = false
                expandedQuickEdit.reset()
            },
            clearRosterPreview: {
                rosterPreviewCard = nil
            }
        )
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 240 : 660) {
            guard !wallet.isExpanded, wallet.heroProgress <= 0.001 else { return }
            walletHeroCardsSnapshot = nil
        }
    }

    private func openCrewRosterCard(_ card: FocusCard) {
        seedHomeAvatarData(cardId: card.id, data: card.avatarImageData)
        seedHomePopoutData(cardId: card.id, data: card.cardPopoutImageData)
        showingCrewRoster = false
        fabExpanded = false
        expandedQuickEdit.reset()

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
        homeSnapshotController.seedAvatarData(cardId: cardId, data: data)
    }

    private func seedHomePopoutData(cardId: UUID, data: Data?) {
        homeSnapshotController.seedPopoutData(cardId: cardId, data: data)
    }

    private func openWalletCardBasicInfo(_ card: FocusCard) {
        fabExpanded = false
        expandedQuickEdit.reset()
        collapseWalletToHome()

        if card.isElectronicPet {
            presentHomeCritterNest(for: card)
            return
        }

        if card.isHuman {
            expandedBasicInfoHuman = humans.first(where: { $0.id == card.id })
            return
        }

        if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            expandedBasicInfoPet = pet
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
        refreshHomeCardSnapshot()
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            refreshHomeCardSnapshot()
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

    private func applyExpandedExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        triggerExpandedActionFeedback(
            cardId: feedback.cardId,
            coconutDelta: feedback.coconutDelta,
            label: feedback.label
        )
    }

    private func completeFirstSuccessFeed(for pet: Pet) {
        firstSuccess.completeFeed(
            for: pet,
            expand: expandWalletToCard(id:),
            performFeed: { applyExpandedQuickAction("feed", pet: $0) }
        )
    }

    private func completeFirstSuccessPlay(for pet: Pet) {
        firstSuccess.completePlay(
            for: pet,
            expand: expandWalletToCard(id:),
            performPlay: { applyExpandedQuickAction("play", pet: $0) }
        )
    }

    private func startFirstSuccessMoment(for pet: Pet) {
        firstSuccess.startMoment(
            for: pet,
            expand: expandWalletToCard(id:),
            presentMoment: { expandedQuickMomentPet = $0 }
        )
    }

    private func completeFirstSuccessMomentIfNeeded(for pet: Pet) {
        firstSuccess.completeMomentIfNeeded(
            for: pet,
            triggerFeedback: { coconutDelta, label in
                triggerExpandedActionFeedback(
                    cardId: pet.id,
                    coconutDelta: coconutDelta,
                    label: label
                )
            },
            markCompleted: markFirstQuickCheckInCompletedIfNeeded
        )
    }

    private func markFirstQuickCheckInCompletedIfNeeded() {
        guard showFirstSuccessCard, !firstQuickCheckInCompleted else { return }
        firstQuickCheckInCompleted = true
        withAnimation(HeroAnim.buttonSpring) {
            showFirstSuccessCard = false
        }
    }

    private func triggerWalkCardTransform(for pet: Pet) {
        walkTransform.trigger(
            for: pet,
            expand: expandWalletToCard(id:),
            pulse: { cardId in
                if let cardId {
                    expandedActionPulseCardId = cardId
                } else {
                    guard expandedActionPulseCardId == pet.id else { return }
                    withAnimation(GoMotion.quick) {
                        expandedActionPulseCardId = nil
                    }
                }
            }
        )
    }

    private func syncWalkCardSurfaceVisibility() {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = isWalkCardExpandedSurfaceVisible
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
        saveExpandedQAEditItems(expandedQuickEdit.items, for: pet)
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    private func saveExpandedQAEditItems(_ edited: [QuickActionItem], for pet: Pet) {
        quickActionItemsJSON = ExpandedQuickActionStore.savingPetItems(
            edited,
            pet: pet,
            raw: quickActionItemsJSON,
            localization: l,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
    }

    private func enterExpandedHumanQAEditMode(for human: Human) {
        expandedQuickEdit.enter(with: expandedHumanQuickActionItems(for: human), animation: HeroAnim.buttonSpring)
    }

    private func exitExpandedHumanQAEditMode(for human: Human) {
        saveExpandedHumanQAEditItems(expandedQuickEdit.items, for: human)
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    private func saveExpandedHumanQAEditItems(_ edited: [QuickActionItem], for human: Human) {
        quickActionItemsJSON = ExpandedQuickActionStore.savingHumanItems(
            edited,
            human: human,
            raw: quickActionItemsJSON,
            localization: l
        )
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
        FocusHomeExpandedQuickRouteRouter.handleHuman(route, human: human, actions: expandedQuickRouteActions)
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
        FocusHomeExpandedQuickRouteRouter.handlePetTap(route, pet: pet, actions: expandedQuickRouteActions)
    }

    private func openExpandedFeedDetail(for pet: Pet, opensManualSheet: Bool = false) {
        expandedQuickFeedOpensManualSheet = opensManualSheet
        expandedQuickFeedDetailPet = pet
    }

    private func handleExpandedQuickLongPress(_ item: QuickActionItem, pet: Pet) {
        FocusHomeExpandedQuickRouteRouter.handlePetLongPress(
            ExpandedQuickActionLogic.petLongPressRoute(for: item),
            pet: pet,
            actions: expandedQuickRouteActions
        )
    }

    private var expandedQuickRouteActions: FocusHomeExpandedQuickRouteRouter.Actions {
        FocusHomeExpandedQuickRouteRouter.Actions(
            showPrivacyAlert: { showingHumanPrivacyAlert = true },
            humanWeightQuick: { openExpandedQuickHumanWeight(for: $0, actionType: "humanWeight") },
            humanWorkoutQuick: { openExpandedQuickHumanWorkout(for: $0, actionType: "humanWorkout") },
            humanMedicationAdd: { openExpandedQuickHumanMedication(for: $0, actionType: "humanMedication") },
            humanNoteQuick: { openExpandedQuickHumanNote(for: $0, actionType: "humanNote") },
            humanExpenseQuick: { openExpandedQuickHumanExpense(for: $0, actionType: "humanExpense") },
            humanWeightDetail: { expandedHumanWeightDetail = $0 },
            humanWorkoutDetail: { expandedHumanWorkoutDetail = $0 },
            humanMedicationDetail: { expandedQuickHumanMedication = $0 },
            humanNoteDetail: { expandedHumanNoteDetail = $0 },
            humanExpenseDetail: { expandedHumanExpenseDetail = $0 },
            humanAllFeatures: { expandedAllFeaturesHuman = $0 },
            selectHuman: { selectedHuman = $0 },
            performPetAction: { actionType, pet in applyExpandedQuickAction(actionType, pet: pet) },
            waterManagement: openExpandedWaterManagement,
            petWeightQuick: openExpandedQuickWeight,
            petExpenseQuick: openExpandedQuickExpense,
            petMomentQuick: { expandedQuickMomentPet = $0 },
            petHealth: {
                expandedQuickHealthInitialSection = nil
                expandedQuickHealthPet = $0
            },
            feedDetail: { openExpandedFeedDetail(for: $0) },
            walk: { expandedQuickWalkPet = $0 },
            playDetail: { expandedQuickPlayDetailPet = $0 },
            pottyDetail: { expandedQuickPottyDetailPet = $0 },
            hygiene: { expandedQuickHygienePet = $0 },
            petMedication: { expandedQuickPetMedicationPet = $0 },
            petWeightDetail: { expandedQuickWeightDetailPet = $0 },
            petExpenseDetail: { expandedQuickExpenseDetailPet = $0 },
            momentHistory: { expandedMomentHistoryPet = $0 }
        )
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

    private func expandedFeedDashboard(for pet: Pet) -> FeedingDashboardState {
        ExpandedQuickActionLogic.feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    private func applyExpandedQuickAction(_ actionType: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }

        ExpandedQuickActionExecutor.performActionType(
            actionType,
            pet: pet,
            executorId: executorId,
            allEvents: allEvents,
            allFeedCareLogs: allFeedCareLogs,
            humans: humans,
            modelContext: modelContext,
            now: quickActionClockTick,
            antiRepeatTitle: l.homeAntiDupFeedTitle,
            antiRepeatMessage: { warning in
                l.homeAntiDupFeedMessage(
                    executor: warning.executorName,
                    minutes: warning.minutesAgo,
                    petName: pet.name
                )
            },
            openFeedDetail: { opensManualSheet in
                openExpandedFeedDetail(for: pet, opensManualSheet: opensManualSheet)
            },
            completePlannedFeed: { completeExpandedPlannedFeedFromHome(pet: $0) },
            showAntiRepeat: { title, message, pendingAction in
                antiRepeatTitle = title
                antiRepeatMessage = message
                pendingRepeatAction = pendingAction
                showingAntiRepeatAlert = true
            },
            startWalk: { pet in
                if case .idle = PetWalkingManager.shared.phase {
                    PetWalkingManager.shared.start(pet: pet)
                }
                triggerWalkCardTransform(for: pet)
            },
            openWaterManagement: openExpandedWaterManagement,
            openMedication: { expandedQuickPetMedicationPet = $0 },
            feedback: applyExpandedExecutorFeedback
        )
    }

    private func applyExpandedGroomCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        ExpandedQuickActionExecutor.applyGroomCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            showSingleUseNotice: { title, message in
                singleUseNoticeTitle = title
                singleUseNoticeMessage = message
                showingSingleUseNotice = true
            },
            feedback: applyExpandedExecutorFeedback
        )
    }

    private func applyExpandedPottyCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        ExpandedQuickActionExecutor.applyPottyCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            feedback: applyExpandedExecutorFeedback
        )
    }

    private func applyExpandedHealthCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        ExpandedQuickActionExecutor.applyHealthCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            openHealth: { pet in
                expandedQuickHealthInitialSection = nil
                expandedQuickHealthPet = pet
            },
            feedback: applyExpandedExecutorFeedback
        )
    }

    private var waterManagementLabel: String {
        l.tr(zh: "水管理", en: "Water", de: "Wasser")
    }

    private func openExpandedWaterManagement(for pet: Pet) {
        expandedQuickWaterDetailPet = pet
    }

    private func expandedHumanQuickCompleted(_ item: QuickActionItem, human: Human) -> Bool {
        ExpandedHumanQuickActionStateProvider.completed(
            item: item,
            human: human,
            viewedBy: activeHumanId,
            todayMedicationLogs: todayHumanMedicationLogs
        )
    }

    private func expandedHumanQuickCountText(_ item: QuickActionItem, human: Human) -> String? {
        ExpandedHumanQuickActionStateProvider.countText(
            item: item,
            human: human,
            viewedBy: activeHumanId,
            activeMedications: activeHumanMedications,
            todayMedicationLogs: todayHumanMedicationLogs,
            recentExpenses: recentHumanExpenseLogs
        )
    }

    private func expandedHumanQuickActionIsPrivate(_ item: QuickActionItem, human: Human) -> Bool {
        ExpandedHumanQuickActionStateProvider.isPrivate(item, human: human, viewedBy: activeHumanId)
    }

    private func performExpandedQuickAction(_ action: FocusCard.Action, for card: FocusCard) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway })
        let route = ExpandedQuickActionLogic.legacyRoute(action: action, card: card, pet: pet)
        switch route {
        case .selectHuman:
            selectedHuman = humans.first(where: { $0.id == card.id })
        case .none:
            return
        default:
            guard let pet else { return }
            ExpandedQuickActionExecutor.performLegacyPetRoute(
                route,
                pet: pet,
                executorId: currentExecutorId(),
                modelContext: modelContext,
                startWalk: { pet in
                    if case .idle = PetWalkingManager.shared.phase {
                        PetWalkingManager.shared.start(pet: pet)
                    }
                    triggerWalkCardTransform(for: pet)
                },
                openWaterManagement: openExpandedWaterManagement,
                openPetOverview: { pet in
                    selectedPetTab = .overview
                    selectedPet = pet
                },
                feedback: applyExpandedExecutorFeedback
            )
        }
    }

    private func currentExecutorId() -> String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func completeQuestInFocusStack(_ quest: IslandQuest) {
        FocusHomeTodayFocusRouter.completeQuest(
            quest,
            pets: pets,
            humans: humans,
            plants: plants,
            events: allEvents,
            actions: FocusHomeTodayFocusRouter.QuestActions(
                presentAddEntity: { presentAddEntity(initialType: $0) },
                showOasis: { showingOasisReward = true },
                openPetShortcut: { actionType, pet in openTodayFocusPetShortcut(actionType, pet: pet) },
                openWalk: { openTodayFocusWalk(pet: $0) },
                openPetWeight: {
                    focusTodayPetCard($0)
                    openExpandedQuickWeight(for: $0)
                },
                openHumanWeight: openTodayFocusHumanWeight,
                openPetMoment: {
                    focusTodayPetCard($0)
                    expandedQuickMomentPet = $0
                },
                selectPlant: { selectedPlant = $0 },
                openCalendar: openGlobalCalendar,
                selectPetOverview: {
                    selectedPetTab = .overview
                    selectedPet = $0
                },
                openEvent: openTodayFocusEvent,
                completeMedicationDose: { pet, medicationId in
                    guard let medication = pet.medications.first(where: { $0.id == medicationId }) else { return }
                    PetMedicationDoseLogging.recordDose(
                        medication: medication,
                        pet: pet,
                        modelContext: modelContext,
                        awardCoconut: true
                    )
                    MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: 1, label: "💊 +1🥥")
                }
            )
        )
    }

    private func focusTodayPetCard(_ pet: Pet) {
        fabExpanded = false
        expandedQuickEdit.reset()
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
            expandedQuickEdit.reset()
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
        FocusHomeTodayFocusRouter.routeEventToFeature(
            event,
            pets: pets,
            actions: FocusHomeTodayFocusRouter.EventActions(
                openHealth: { pet, section in openTodayFocusHealth(pet: pet, section: section) },
                openMedication: {
                    focusTodayPetCard($0)
                    expandedQuickPetMedicationPet = $0
                }
            )
        )
    }

    private func handleTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        guard let pet = FocusHomeTodayFocusRouter.petForNegativeSignal(
            signal,
            pets: pets,
            activePet: todayFocusActivePet
        ) else { return }
        fabExpanded = false
        expandedQuickEdit.reset()

        FocusHomeTodayFocusRouter.handleNegativeSignal(
            signal,
            pet: pet,
            actions: FocusHomeTodayFocusRouter.NegativeSignalActions(
                openHealth: { pet, section in openTodayFocusHealth(pet: pet, section: section) },
                openWeight: {
                    focusTodayPetCard($0)
                    expandedQuickWeightDetailPet = $0
                },
                expandPet: { expandWalletToCard(id: $0.id) }
            )
        )
    }

    // MARK: FAB (floating action button)

    private var floatingFabBottomPadding: CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 34
        return safeBottom + 40
    }

    private func openHomeFabShortcut(_ item: HomeFabFunctionShortcut) {
        guard item.isAvailable else { return }
        functionMenuPresentation = FunctionMenuPresentation(destination: item.destination)
    }

    private func expandedCardFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman {
            return FocusHomeFabShortcutPolicy.humanShortcuts(localization: l)
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return [ExpandedCardFabShortcut(label: "全部功能", icon: "ellipsis.circle.fill", action: .allFeatures)]
        }

        let displayedItems = expandedQuickEdit.isEditMode && wallet.activeCardId == pet.id
            ? expandedQuickEdit.items
            : expandedQuickActionItems(for: pet)
        return FocusHomeFabShortcutPolicy.petShortcuts(for: pet, displayedItems: displayedItems, localization: l)
    }

    private func openExpandedCardFabShortcut(_ item: ExpandedCardFabShortcut, card: FocusCard) {
        FocusHomeExpandedFabRouter.open(
            item,
            card: card,
            pets: pets,
            humans: humans,
            activeHumanId: activeHumanId,
            actions: expandedFabRouteActions
        )
    }

    private func openExpandedPetShortcut(_ actionType: String, pet: Pet) {
        FocusHomeExpandedFabRouter.openPetShortcut(actionType, pet: pet, actions: expandedFabRouteActions)
    }

    private func openExpandedPetDetail(_ feature: PetFeature, pet: Pet) {
        FocusHomeExpandedFabRouter.openPetDetail(feature, pet: pet, actions: expandedFabRouteActions)
    }

    private func openExpandedHumanShortcut(_ actionType: String, human: Human) {
        FocusHomeExpandedFabRouter.openHumanShortcut(
            actionType,
            human: human,
            activeHumanId: activeHumanId,
            actions: expandedFabRouteActions
        )
    }

    private var expandedFabRouteActions: FocusHomeExpandedFabRouter.Actions {
        FocusHomeExpandedFabRouter.Actions(
            showPetAllFeatures: { expandedAllFeaturesPet = $0 },
            showHumanAllFeatures: { expandedAllFeaturesHuman = $0 },
            openFeed: { openExpandedFeedDetail(for: $0) },
            openWater: openExpandedWaterManagement,
            openWalk: { expandedQuickWalkPet = $0 },
            openPotty: { expandedQuickPottyDetailPet = $0 },
            openPlay: { expandedQuickPlayDetailPet = $0 },
            openMedication: { expandedQuickPetMedicationPet = $0 },
            openHygiene: { expandedQuickHygienePet = $0 },
            openMoment: { expandedQuickMomentPet = $0 },
            openHealth: {
                expandedQuickHealthInitialSection = nil
                expandedQuickHealthPet = $0
            },
            openWeight: { expandedQuickWeightDetailPet = $0 },
            openExpense: { expandedQuickExpenseDetailPet = $0 },
            showHumanWeight: { expandedHumanWeightDetail = $0 },
            showHumanWorkout: { expandedHumanWorkoutDetail = $0 },
            showHumanMedication: { expandedQuickHumanMedication = $0 },
            showHumanNote: { expandedHumanNoteDetail = $0 },
            quickHumanExpense: { openExpandedQuickHumanExpense(for: $0) },
            showPrivacyAlert: { showingHumanPrivacyAlert = true }
        )
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

        if activeCard.isElectronicPet {
            presentHomeCritterNest(for: activeCard)
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
        if let activeCard = activeWalletCard, activeCard.isReal {
            if activeCard.isElectronicPet {
                if let human = activeHuman {
                    activeCoconutLogSubject = .human(human.id)
                }
                return
            }
            if activeCard.isHuman {
                guard let human = humans.first(where: { $0.id == activeCard.id }) else { return }
                guard !PrivacyService.isLocked(.wishlist, for: human, viewedBy: activeHumanId) else {
                    showingHumanPrivacyAlert = true
                    return
                }
                activeCoconutLogSubject = .human(human.id)
                return
            }
            activeCoconutLogSubject = .pet(activeCard.id)
            return
        }
        if let human = activeHuman {
            activeCoconutLogSubject = .human(human.id)
        }
    }

    // MARK: 3-zone header

    private func goFocusHeader(safeT: CGFloat) -> some View {
        let human = activeHuman
        let avatarEntry = human.map { FocusWalletAvatarCache.entry(for: $0.id, data: homeSnapshotController.avatarData(for: $0.id)) }
        return FocusHomeHeaderView(
            safeTop: safeT,
            streak: headerStreak,
            coconutBalance: headerCoconutBalance,
            coconutDeltaContext: headerCoconutDeltaContext,
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
        FocusHomeCardContextMenu(
            card: card,
            pets: pets,
            currentUserId: currentExecutorId(),
            modelContext: modelContext,
            onWaterManagement: openExpandedWaterManagement,
            onOpenPet: { selectedPet = $0 }
        )
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
                FocusHomeExpandedCardFabHost(
                    items: expandedCardFabShortcuts(for: card),
                    isExpanded: $cardFabExpanded,
                    itemsVisible: $cardFabMenuItemsVisible,
                    onShortcut: { openExpandedCardFabShortcut($0, card: card) }
                )
            }
        }
    }
}
