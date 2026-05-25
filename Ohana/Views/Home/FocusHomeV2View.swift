//
//  FocusHomeV2View.swift
//  Ohana
//
//  New default home shell. It uses the same WalletHeroTimeline as the
//  Apple Wallet motion lab instead of wrapping FocusStackHomeTestView.
//

import SwiftUI
import SwiftData

struct FocusHomeV2View: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    let heroNS: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaDisplayCornerRadius) private var displayCornerRadius
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Bindable private var questMgr = QuestManager.shared

    @Query(sort: \Pet.createdAt, order: .reverse) private var pets: [Pet]
    @Query(sort: \Human.createdAt, order: .reverse) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \OasisElectronicPet.obtainedAt, order: .reverse) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(sort: \HumanMedication.createdAt, order: .reverse) private var humanMedications: [HumanMedication]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" || $0.status == "failed" }, sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]

    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard = true
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""

    @Namespace private var ns
    @StateObject private var wallet = FocusHomeWalletController()
    @StateObject private var snapshotController = FocusHomeSnapshotController()
    @StateObject private var expandedQuickEdit = ExpandedQuickActionEditController()

    @State private var headerStreak = 0
    @State private var didRecordHomeFirstFrame = false
    @State private var walletHeroCardsSnapshot: [FocusCard]? = nil
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

    @State private var expandedAllFeaturesPet: Pet? = nil
    @State private var expandedAllFeaturesHuman: Human? = nil
    @State private var expandedBasicInfoPet: Pet? = nil
    @State private var expandedBasicInfoHuman: Human? = nil
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
    @State private var todayFocusWalkPet: Pet? = nil
    @State private var expandedQuickHealthPet: Pet? = nil
    @State private var expandedQuickHealthInitialSection: PetHealthInitialSection? = nil
    @State private var expandedQuickPetMedicationPet: Pet? = nil
    @State private var expandedQuickMomentPet: Pet? = nil
    @State private var expandedMomentHistoryPet: Pet? = nil
    @State private var expandedQuickHumanMedication: Human? = nil
    @State private var expandedHumanWeightDetail: Human? = nil
    @State private var expandedHumanWorkoutDetail: Human? = nil
    @State private var expandedHumanExpenseDetail: Human? = nil
    @State private var expandedHumanNoteDetail: Human? = nil

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

    private var l: L10n { L10n(appLanguage) }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full
    }
    private var walletExpandAnimation: Animation { shouldReduceWork ? HeroAnim.walletReduced : HeroAnim.walletSpring }
    private var walletCollapseAnimation: Animation { shouldReduceWork ? HeroAnim.walletReduced : HeroAnim.walletCollapseSpring }
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
        guard wallet.isExpanded || wallet.heroProgress > 0.98,
              let id = wallet.activeCardId else { return nil }
        return displayCards.first(where: { $0.id == id }) ?? sourceCards.first(where: { $0.id == id })
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

    private var activeHumanAvatarImage: UIImage? {
        guard let human = activeHuman else { return nil }
        let avatarData = snapshotController.avatarData(for: human.id) ?? human.avatarImageData
        return FocusWalletAvatarCache.entry(for: human.id, data: avatarData).image
    }

    private var sourceCards: [FocusCard] {
        FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards
        )
    }

    private var visibleCards: [FocusCard] {
        let base = snapshotController.cards(fallback: sourceCards)
        return snapshotController.visibleCards(
            from: base,
            rosterPreviewCard: nil,
            isExpanded: wallet.isExpanded,
            activeCardId: wallet.activeCardId
        )
    }

    private var displayCards: [FocusCard] {
        walletHeroCardsSnapshot ?? visibleCards
    }

    private var heroSelectedCardId: UUID? {
        guard wallet.isExpanded || wallet.transitionCardId != nil || wallet.heroProgress > 0.001 else { return nil }
        return wallet.activeCardId ?? wallet.transitionCardId
    }

    private var activeCard: FocusCard? {
        guard let id = wallet.activeCardId else { return nil }
        return displayCards.first(where: { $0.id == id })
    }

    private var activePetForFocus: Pet? {
        if let id = wallet.activeCardId,
           let pet = activePets.first(where: { $0.id == id }) {
            return pet
        }
        return activePets.first
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                OhanaAppBackground()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: homeSafeTop(geo) + 56)

                    FocusHomeTodayFocusSection(
                        activePets: activePets,
                        plants: plants,
                        reminders: pendingReminders,
                        humans: humans,
                        events: allEvents,
                        activePet: activePetForFocus,
                        showFirstSuccessCard: showFirstSuccessCard,
                        firstQuickCheckInCompleted: firstQuickCheckInCompleted,
                        isExpanded: wallet.isExpanded,
                        cardMargin: K.cardMargin,
                        animation: walletExpandAnimation,
                        onOpenQuest: { _ in },
                        onCompleteQuest: { _ in },
                        onTapNegativeSignal: { _ in },
                        onTapOasis: { showingOasisReward = true },
                        onTapFamilyTask: { _ in showingCrewRoster = true },
                        onFirstSuccessFeed: { expandedQuickFeedDetailPet = $0 },
                        onFirstSuccessPlay: { expandedQuickPlayDetailPet = $0 },
                        onFirstSuccessMoment: { expandedQuickMomentPet = $0 }
                    )
                    .offset(y: -20)
                    .padding(.bottom, -12)

                    if displayCards.isEmpty {
                        Spacer(minLength: 0)
                        EmptyStateWelcomeCard(
                            onAddPet: { activeAddEntityType = .pet },
                            onAddHuman: { activeAddEntityType = .human }
                        )
                        .padding(.horizontal, K.cardMargin)
                        .padding(.bottom, 24)
                    } else {
                        Spacer(minLength: 0)
                    }
                }

                header(safeTop: homeSafeTop(geo))
                    .zIndex(1_200)

                if !displayCards.isEmpty {
                    walletScene(geo: geo)
                        .padding(.horizontal, K.cardMargin)
                        .zIndex(30)
                }

                FocusHomeFabOverlayHost(
                    isVisible: activeAddEntityType == nil,
                    activeCard: wallet.isExpanded ? activeCard : nil,
                    bottomPadding: homeSafeBottom(geo) + 34,
                    homeShortcuts: HomeFabShortcutCatalog.primaryShortcuts,
                    expandedShortcuts: activeCard.map(expandedFabShortcuts(for:)) ?? [],
                    isExpanded: $fabExpanded,
                    itemsVisible: $fabMenuItemsVisible,
                    onHomeShortcut: openHomeFabShortcut,
                    onExpandedShortcut: openExpandedFabShortcut
                )
                .zIndex(999)
            }
            .onAppear {
                refreshSnapshot()
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
            .onChange(of: cardSourceSignature) { _, _ in refreshSnapshot() }
            .onReceive(NotificationCenter.default.publisher(for: .ohanaMemberProfileDidChange)) { notification in
                handleMemberProfileDidChange(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .ohanaReminderRouteRequested)) { notification in
                handleReminderRouteRequest(notification.userInfo)
            }
            .onChange(of: activeHumanIdStr) { _, _ in
                headerStreak = FocusHomeFirstFrameMaintenance.currentStreak(activeHumanId: activeHumanIdStr)
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
            onAddEntityDismissed: refreshSnapshot,
            onPetSavedFromAddEntity: handlePetSaved,
            onCrewPetSelected: { pet in openCard(FocusCard.from(pet, includeAvatarData: true)) },
            onCrewHumanSelected: { human in openCard(FocusCard.from(human, includeAvatarData: true)) },
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { humanId in showReward(amount: 2, label: "用药 +2🥥", cardId: humanId) }
        )
    }

    private var cardSourceSignature: String {
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

    private func walletScene(geo: GeometryProxy) -> some View {
        FocusHomeV2WalletScene(
            cards: displayCards,
            pets: pets,
            safeTop: homeSafeTop(geo),
            safeBottom: homeSafeBottom(geo),
            selectedCardId: heroSelectedCardId,
            progress: wallet.heroProgress,
            heroDirection: wallet.heroDirection,
            reduceMotion: shouldReduceWork,
            namespace: ns,
            heroNamespace: heroNS,
            avatarCacheRevision: snapshotController.avatarCacheRevision,
            quickActions: { card in quickModules(for: card) },
            contextMenu: { card in contextMenu(for: card) },
            onSelect: { card in handleWalletCardTap(card: card, count: displayCards.count, isHero: false) },
            onCollapse: collapseWalletToHome,
            onLongPress: openCardBasicInfo
        )
    }

    private func homeSafeTop(_ geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.top, 50)
    }

    private func homeSafeBottom(_ geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.bottom, 22)
    }

    @ViewBuilder
    private func quickModules(for card: FocusCard) -> some View {
        if card.isReal,
           !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            expandedPetQuickActions(pet: pet)
        } else if card.isReal,
                  card.isHuman,
                  let human = humans.first(where: { $0.id == card.id }) {
            expandedHumanQuickActions(human: human)
        } else {
            FocusHomeV2QuickModulesView(card: card) { action in
                openQuickModule(action, for: card)
            }
        }
    }

    private func expandedPetQuickActions(pet: Pet) -> some View {
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedQuickActionItems(for: pet).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: pet.id, data: snapshotController.avatarData(for: pet.id)).image

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
            onGroomCheckIn: { _ in expandedQuickHygienePet = pet },
            onPottySelect: { _ in expandedQuickPottyDetailPet = pet },
            onHealthSelect: { _ in expandedQuickHealthPet = pet },
            onLimitReached: { showingQuickActionLimitAlert = true }
        )
    }

    private func expandedHumanQuickActions(human: Human) -> some View {
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let defaultItems = ExpandedQuickActionDefaults.humanItems(for: human, localization: l)
        let avatar = FocusWalletAvatarCache.entry(for: human.id, data: snapshotController.avatarData(for: human.id)).image

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
            onToggleEdit: {
                expandedQuickEdit.isEditMode ? exitExpandedHumanQAEditMode(for: human) : enterExpandedHumanQAEditMode(for: human)
            },
            countText: { _ in nil },
            privacyIconName: { ExpandedQuickActionLogic.humanPrivacyIconName(for: $0, human: human) },
            privacyIconTint: { ExpandedQuickActionLogic.humanPrivacyIconTint(for: $0, human: human) },
            isPrivacyLocked: { _ in false },
            isCompleted: { _ in false },
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
        quickActionItemsJSON = ExpandedQuickActionStore.savingHumanItems(
            expandedQuickEdit.items,
            human: human,
            raw: quickActionItemsJSON,
            localization: l
        )
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    private func handlePetQuickPrimary(_ item: QuickActionItem, pet: Pet) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case .perform(let actionType):
            switch actionType {
            case "feed":
                expandedQuickFeedOpensManualSheet = true
                expandedQuickFeedDetailPet = pet
            case "water":
                expandedQuickWaterDetailPet = pet
            case "walk":
                expandedQuickWalkPet = pet
            case "play":
                expandedQuickPlayDetailPet = pet
            case "litter":
                expandedQuickLitterDetailPet = pet
            case "medication":
                expandedQuickPetMedicationPet = pet
            case "cageCleaning", "freeFlight", "misting", "substrateChange", "groom":
                expandedQuickHygienePet = pet
            default:
                expandedAllFeaturesPet = pet
            }
        case .waterManagement:
            expandedQuickWaterDetailPet = pet
        case .weight:
            expandedQuickWeightDetailPet = pet
        case .expense:
            expandedQuickExpenseDetailPet = pet
        case .moment:
            expandedQuickMomentPet = pet
        case .health:
            expandedQuickHealthPet = pet
        case .none:
            break
        }
    }

    private func handlePetQuickDetail(_ item: QuickActionItem, pet: Pet) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.petLongPressRoute(for: item) {
        case .feedDetail:
            expandedQuickFeedDetailPet = pet
        case .waterManagement:
            expandedQuickWaterDetailPet = pet
        case .walk:
            expandedQuickWalkPet = pet
        case .playDetail:
            expandedQuickPlayDetailPet = pet
        case .pottyDetail:
            expandedQuickPottyDetailPet = pet
        case .hygiene:
            expandedQuickHygienePet = pet
        case .health:
            expandedQuickHealthPet = pet
        case .medication:
            expandedQuickPetMedicationPet = pet
        case .weightDetail:
            expandedQuickWeightDetailPet = pet
        case .expenseDetail:
            expandedQuickExpenseDetailPet = pet
        case .momentHistory:
            expandedMomentHistoryPet = pet
        case .none:
            break
        }
    }

    private func handleHumanQuickPrimary(_ item: QuickActionItem, human: Human) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: false) {
        case .weightQuick, .weightDetail:
            expandedHumanWeightDetail = human
        case .workoutQuick, .workoutDetail:
            expandedHumanWorkoutDetail = human
        case .medicationAdd, .medicationDetail:
            expandedQuickHumanMedication = human
        case .noteQuick, .noteDetail:
            expandedHumanNoteDetail = human
        case .expenseQuick, .expenseDetail:
            expandedHumanExpenseDetail = human
        case .allFeatures, .selectHuman:
            expandedAllFeaturesHuman = human
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
            expandedHumanWeightDetail = human
        case .workoutDetail, .workoutQuick:
            expandedHumanWorkoutDetail = human
        case .medicationDetail, .medicationAdd:
            expandedQuickHumanMedication = human
        case .noteDetail, .noteQuick:
            expandedHumanNoteDetail = human
        case .expenseDetail, .expenseQuick:
            expandedHumanExpenseDetail = human
        case .allFeatures, .selectHuman:
            expandedAllFeaturesHuman = human
        case .privacyAlert:
            showingHumanPrivacyAlert = true
        case .none:
            break
        }
    }

    private func handleWalletCardTap(card: FocusCard, count: Int, isHero: Bool) {
        wallet.triggerTapFeedback()
        AppPerformanceMonitor.shared.record("homeV2.cardTapAccepted", valueMS: 0, note: card.name)
        if isHero || wallet.isExpanded {
            collapseWalletToHome()
        } else {
            expandWalletToCard(id: card.id)
        }
    }

    private func expandWalletToCard(id: UUID) {
        walletHeroCardsSnapshot = displayCards
        wallet.expandToCard(
            id: id,
            animation: walletExpandAnimation,
            shouldReduceWork: shouldReduceWork,
            cancelAvatarLoad: { snapshotController.cancelAvatarLoad() },
            resetSurfaces: {
                fabExpanded = false
                fabMenuItemsVisible = false
            }
        )
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 220 : 680) {
            guard wallet.isExpanded, wallet.activeCardId == id else { return }
            walletHeroCardsSnapshot = nil
        }
    }

    private func collapseWalletToHome() {
        refreshSnapshot()
        walletHeroCardsSnapshot = displayCards
        wallet.collapseToHome(
            animation: walletCollapseAnimation,
            shouldReduceWork: shouldReduceWork,
            returningPreviewId: nil,
            visibleCards: { visibleCards },
            resetSurfaces: {
                fabExpanded = false
                fabMenuItemsVisible = false
            },
            clearRosterPreview: {}
        )
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 220 : 580) {
            guard !wallet.isExpanded, wallet.heroProgress <= 0.001 else { return }
            walletHeroCardsSnapshot = nil
        }
    }

    private func refreshSnapshot() {
        snapshotController.refresh(
            snapshot: sourceCards,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            isExpanded: wallet.isExpanded,
            walletTransitionCardId: wallet.transitionCardId
        )
        if let human = activeHuman {
            snapshotController.seedAvatarData(cardId: human.id, data: human.avatarImageData)
        }
    }

    private func handleMemberProfileDidChange(_ notification: Notification) {
        let id = (notification.userInfo?["id"] as? String).flatMap(UUID.init(uuidString:))
        snapshotController.invalidateMemberAppearance(cardId: id)
        refreshSnapshot()
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
        expandedAllFeaturesPet = nil
        expandedAllFeaturesHuman = nil
        expandedBasicInfoPet = nil
        expandedBasicInfoHuman = nil
        expandedQuickWeightDetailPet = nil
        expandedQuickExpenseDetailPet = nil
        expandedQuickFeedDetailPet = nil
        expandedQuickFeedOpensManualSheet = false
        expandedQuickWaterDetailPet = nil
        expandedQuickPottyDetailPet = nil
        expandedQuickLitterDetailPet = nil
        expandedQuickPlayDetailPet = nil
        expandedQuickHygienePet = nil
        expandedQuickWalkPet = nil
        todayFocusWalkPet = nil
        expandedQuickHealthPet = nil
        expandedQuickHealthInitialSection = nil
        expandedQuickPetMedicationPet = nil
        expandedQuickMomentPet = nil
        expandedMomentHistoryPet = nil
        expandedQuickHumanMedication = nil
        expandedHumanWeightDetail = nil
        expandedHumanWorkoutDetail = nil
        expandedHumanExpenseDetail = nil
        expandedHumanNoteDetail = nil
        fabExpanded = false
        fabMenuItemsVisible = false
    }

    private func openReminderNotificationDestination(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case .petQuick(let key, let pet):
            openPetQuickKey(key, card: FocusCard.from(pet, includeAvatarData: true))
        case .petFeature(let feature, let pet):
            openPetFeature(feature, card: FocusCard.from(pet, includeAvatarData: true))
        case .petHealth(let pet, let section):
            expandedQuickHealthInitialSection = section
            expandedQuickHealthPet = pet
        case .humanQuick(let key, let human):
            openHumanQuickKey(key, card: FocusCard.from(human, includeAvatarData: true))
        case .humanDetail(let human):
            selectedHuman = human
        case .plant(let plant):
            selectedPlant = plant
        case .functionMenu(let destination):
            functionMenuPresentation = FunctionMenuPresentation(destination: destination)
        case .calendar(let entityId, let humanId):
            calendarEntityFilterId = entityId
            calendarHumanFilterId = humanId
            showingCalendar = true
        }
    }

    private func handlePetSaved(_ pet: Pet) {
        refreshSnapshot()
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
            refreshSnapshot()
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            expandWalletToCard(id: card.id)
        }
    }

    private func openCardBasicInfo(_ card: FocusCard) {
        if card.isHuman {
            expandedBasicInfoHuman = humans.first(where: { $0.id == card.id })
        } else {
            expandedBasicInfoPet = pets.first(where: { $0.id == card.id })
        }
    }

    private func openAllFeatures(_ card: FocusCard) {
        if card.isHuman {
            expandedAllFeaturesHuman = humans.first(where: { $0.id == card.id })
        } else {
            expandedAllFeaturesPet = pets.first(where: { $0.id == card.id })
        }
    }

    private func openQuickModule(_ action: FocusHomeV2QuickAction, for card: FocusCard) {
        OhanaFeedback.light()
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            switch action {
            case .primary: expandedHumanWeightDetail = human
            case .secondary: expandedHumanExpenseDetail = human
            case .tertiary: expandedQuickHumanMedication = human
            case .all: expandedAllFeaturesHuman = human
            }
            return
        }

        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch action {
        case .primary:
            expandedQuickFeedDetailPet = pet
        case .secondary:
            expandedQuickWaterDetailPet = pet
        case .tertiary:
            expandedQuickHealthPet = pet
        case .all:
            expandedAllFeaturesPet = pet
        }
    }

    private func expandedFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman { return FocusHomeFabShortcutPolicy.humanShortcuts(localization: l) }
        return [
            ExpandedCardFabShortcut(label: l.tr(zh: "饮食", en: "Food", de: "Futter"), icon: "fork.knife", action: .detail(.food)),
            ExpandedCardFabShortcut(label: l.tr(zh: "健康", en: "Health", de: "Gesundheit"), icon: "cross.fill", action: .detail(.health)),
            ExpandedCardFabShortcut(label: l.tr(zh: "记录", en: "Moments", de: "Momente"), icon: "sparkles", action: .detail(.moments)),
            ExpandedCardFabShortcut(label: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "ellipsis.circle.fill", action: .allFeatures)
        ]
    }

    private func openHomeFabShortcut(_ shortcut: HomeFabFunctionShortcut) {
        guard shortcut.isAvailable else { return }
        functionMenuPresentation = FunctionMenuPresentation(destination: shortcut.destination)
    }

    private func openExpandedFabShortcut(_ shortcut: ExpandedCardFabShortcut, card: FocusCard) {
        switch shortcut.action {
        case .allFeatures:
            openAllFeatures(card)
        case .humanAllFeatures:
            openAllFeatures(card)
        case .detail(let feature):
            openPetFeature(feature, card: card)
        case .quick(let key):
            openPetQuickKey(key, card: card)
        case .humanQuick(let key):
            openHumanQuickKey(key, card: card)
        }
    }

    private func openPetFeature(_ feature: PetFeature, card: FocusCard) {
        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch feature {
        case .food: expandedQuickFeedDetailPet = pet
        case .hygiene: expandedQuickHygienePet = pet
        case .health: expandedQuickHealthPet = pet
        case .medications: expandedQuickPetMedicationPet = pet
        case .walks: expandedQuickWalkPet = pet
        case .potty: expandedQuickPottyDetailPet = pet
        case .weight: expandedQuickWeightDetailPet = pet
        case .expense: expandedQuickExpenseDetailPet = pet
        case .moments: expandedMomentHistoryPet = pet
        case .basicInfo: expandedBasicInfoPet = pet
        default: expandedAllFeaturesPet = pet
        }
    }

    private func openPetQuickKey(_ key: String, card: FocusCard) {
        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch key {
        case "feed": expandedQuickFeedDetailPet = pet
        case "water": expandedQuickWaterDetailPet = pet
        case "potty": expandedQuickPottyDetailPet = pet
        case "litter": expandedQuickLitterDetailPet = pet
        case "walk": expandedQuickWalkPet = pet
        case "play": expandedQuickPlayDetailPet = pet
        case "health": expandedQuickHealthPet = pet
        case "weight": expandedQuickWeightDetailPet = pet
        case "expense": expandedQuickExpenseDetailPet = pet
        case "moment": expandedMomentHistoryPet = pet
        default: expandedAllFeaturesPet = pet
        }
    }

    private func openHumanQuickKey(_ key: String, card: FocusCard) {
        guard let human = humans.first(where: { $0.id == card.id }) else { return }
        switch key {
        case "humanWeight": expandedHumanWeightDetail = human
        case "humanExpense": expandedHumanExpenseDetail = human
        case "humanMedication": expandedQuickHumanMedication = human
        case "humanWorkout": expandedHumanWorkoutDetail = human
        case "humanNote": expandedHumanNoteDetail = human
        default: expandedAllFeaturesHuman = human
        }
    }

    private func showReward(amount: Int, label: String?, cardId: UUID?) {
        expandedCoconutRewardAmount = amount
        expandedCoconutRewardLabel = label
        showExpandedCoconutReward = true
    }
}

enum FocusHomeV2QuickAction {
    case primary
    case secondary
    case tertiary
    case all
}

struct FocusHomeV2QuickModulesView: View {
    let card: FocusCard
    let onAction: (FocusHomeV2QuickAction) -> Void

    private var items: [(FocusHomeV2QuickAction, String, String)] {
        if card.isHuman {
            return [
                (.primary, "scalemass.fill", "体重"),
                (.secondary, "creditcard.fill", "花费"),
                (.tertiary, "pill.fill", "用药"),
                (.all, "ellipsis.circle.fill", "全部")
            ]
        }
        return [
            (.primary, "fork.knife", "饮食"),
            (.secondary, "drop.fill", "喂水"),
            (.tertiary, "cross.fill", "健康"),
            (.all, "ellipsis.circle.fill", "全部")
        ]
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button {
                    onAction(item.0)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: item.1)
                            .font(.system(size: 19, weight: .black))
                            .symbolRenderingMode(.monochrome)
                        Text(item.2)
                            .font(OhanaFont.caption(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 16)
    }
}

private struct FocusHomeV2QuickMotionShell: View {
    let card: FocusCard

    private var itemCount: Int { card.isHuman ? 6 : 8 }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.16))
                    .frame(width: 52, height: 7)
                Spacer()
                Circle()
                    .fill(Color.goPrimary)
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(0..<itemCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.ohanaCardSurface)
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(index == 0 ? Color.goPrimary : Color.ohanaSecondaryText.opacity(0.22))
                                .frame(width: 20, height: 20)
                                .padding(13)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Capsule()
                                .fill(Color.ohanaSecondaryText.opacity(0.16))
                                .frame(width: index % 3 == 0 ? 34 : 24, height: 5)
                                .padding(.leading, 14)
                                .padding(.bottom, 12)
                        }
                        .frame(height: 78)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .allowsHitTesting(false)
    }
}

private struct FocusHomeV2WalletScene<QuickActions: View, ContextMenuContent: View>: View {
    private let sceneCoordinateSpace = "FocusHomeV2WalletSceneSpace"

    let cards: [FocusCard]
    let pets: [Pet]
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let selectedCardId: UUID?
    let progress: CGFloat
    let heroDirection: Int
    let reduceMotion: Bool
    let namespace: Namespace.ID
    let heroNamespace: Namespace.ID
    let avatarCacheRevision: Int
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusCard) -> Void
    let onCollapse: () -> Void
    let onLongPress: (FocusCard) -> Void

    private var selectedCardIndex: Int? {
        selectedCardId.flatMap { selectedId in
            cards.firstIndex(where: { $0.id == selectedId })
        }
    }

    var body: some View {
        GeometryReader { geo in
            let layout = WalletHeroLayout(
                size: geo.size,
                safeTop: safeTop,
                safeBottom: safeBottom,
                cardCount: cards.count,
                horizontalInset: 0,
                collapsedPeek: 44,
                collapsedBottomGap: 42,
                expandedTopOffset: 140,
                expandedHeightRatio: 0.43,
                expandedMinHeight: K.expandedCardH,
                expandedMaxHeight: K.expandedCardH,
                quickGap: K.expandedQuickModuleGap,
                quickHeight: 206
            )

            ZStack {
                if let activeCard {
                    quickActions(activeCard)
                        .frame(width: layout.cardWidth, height: layout.quickHeight)
                        .position(x: layout.centerX, y: layout.quickFrame.midY)
                        .contentShape(Rectangle())
                        .clipShape(WalletHeroRevealShape(reveal: WalletHeroTimeline.quickReveal(progress: progress)))
                        .opacity(WalletHeroTimeline.quickReveal(progress: progress) > 0.01 ? 1 : 0)
                        .allowsHitTesting(isExpandedInteractionReady)
                        .zIndex(10)
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isActive = card.id == selectedCardId
                    let frame = frame(for: card, index: index, layout: layout)
                    let opacity = opacity(for: card, index: index)
                    let scale = inactiveScale(for: card, index: index)
                    let walkTrackingPet = FocusHomeWalletCardContent.walkTrackingPet(for: card, isHero: isActive, pets: pets)

                    FocusHomeWalletCardContent(
                        card: card,
                        namespace: namespace,
                        heroNamespace: heroNamespace,
                        expandedId: selectedCardId,
                        isHeroExpanded: isActive,
                        heroProgress: isActive ? progress : 0,
                        avatarCacheRevision: avatarCacheRevision,
                        walkTrackingPet: walkTrackingPet,
                        usesMatchedGeometry: false
                    )
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(scale)
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(opacity)
                    .zIndex(zIndex(index: index, isActive: isActive))
                    .contentShape(RoundedRectangle(cornerRadius: WalletHeroTimeline.cornerRadius(progress: isActive ? progress : 0), style: .continuous))
                    .if(selectedCardId != nil && !isActive) { view in
                        view.contextMenu { contextMenu(card) }
                    }
                    .onTapGesture {
                        guard isActive, isExpandedInteractionReady, walkTrackingPet == nil else { return }
                        OhanaFeedback.light()
                        onCollapse()
                    }
                    .onLongPressGesture(minimumDuration: 0.45) {
                        guard isActive, isExpandedInteractionReady, walkTrackingPet == nil else { return }
                        OhanaFeedback.medium()
                        onLongPress(card)
                    }
                    .simultaneousGesture(collapseDragGesture(height: layout.size.height, isEnabled: walkTrackingPet == nil))
                    .allowsHitTesting(isActive && isExpandedInteractionReady)
                }

                if selectedCardId == nil {
                    collapsedHitZones(layout: layout)
                        .zIndex(70)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: sceneCoordinateSpace)
        }
    }

    private var activeCard: FocusCard? {
        selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    private var isExpandedInteractionReady: Bool {
        selectedCardId != nil && progress > 0.98
    }

    private func frame(for card: FocusCard, index: Int, layout: WalletHeroLayout) -> CGRect {
        let collapsed = layout.collapsedFrame(index: index, count: cards.count)
        guard card.id == selectedCardId else {
            return WalletHeroTimeline.inactiveFrame(
                from: collapsed,
                index: index,
                selectedIndex: selectedCardIndex,
                progress: progress,
                layout: layout,
                direction: heroDirection
            )
        }
        return WalletHeroTimeline.activeFrame(
            from: collapsed,
            to: layout.expandedFrame,
            progress: progress
        )
    }

    private func opacity(for card: FocusCard, index: Int) -> Double {
        guard selectedCardId != nil else { return 1 }
        if card.id == selectedCardId { return 1 }
        return WalletHeroTimeline.inactiveOpacity(
            index: index,
            selectedIndex: selectedCardIndex,
            progress: progress,
            direction: heroDirection
        )
    }

    private func inactiveScale(for card: FocusCard, index: Int) -> CGFloat {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        return WalletHeroTimeline.inactiveScale(
            index: index,
            selectedIndex: selectedCardIndex,
            progress: progress,
            direction: heroDirection
        )
    }

    private func zIndex(index: Int, isActive: Bool) -> Double {
        if isActive {
            return heroDirection < 0 ? Double(index) + 0.25 : 40
        }
        if selectedCardId != nil { return Double(index) }
        return Double(index)
    }

    private func collapsedHitZones(layout: WalletHeroLayout) -> some View {
        let bounds = collapsedHitBounds(layout: layout)
        return Rectangle()
            .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible Wallet stack hit zone
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(sceneCoordinateSpace))
                    .onEnded { value in
                        let moved = hypot(value.translation.width, value.translation.height)
                        guard moved < 24,
                              let card = collapsedCard(at: value.startLocation, layout: layout) else { return }
                        OhanaFeedback.medium()
                        onSelect(card)
                    }
            )
            .accessibilityLabel("Wallet cards")
    }

    private func collapsedHitBounds(layout: WalletHeroLayout) -> CGRect {
        guard !cards.isEmpty else { return .zero }
        return cards.indices
            .map { layout.collapsedHitFrame(index: $0, count: cards.count) }
            .reduce(CGRect.null) { $0.union($1) }
    }

    private func collapsedCard(at point: CGPoint, layout: WalletHeroLayout) -> FocusCard? {
        for index in cards.indices {
            if layout.collapsedHitFrame(index: index, count: cards.count).contains(point) {
                return cards[index]
            }
        }
        return nil
    }

    private func collapseDragGesture(height: CGFloat, isEnabled: Bool = true) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard isEnabled, selectedCardId != nil, value.translation.height > 80 else { return }
                OhanaFeedback.light()
                onCollapse()
            }
    }
}
