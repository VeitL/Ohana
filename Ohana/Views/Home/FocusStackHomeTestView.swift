//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  GO Focus UI — default home page.
//  This is the primary app home.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import Combine

// ─────────────────────────────────────────────────
// MARK: – Layout constants
// ─────────────────────────────────────────────────

enum K {
    static let bg    = Color(hex: "F8D8DF")
    static let ink   = Color(hex: "23181A")
    static let muted = Color(hex: "8B6E74")

    static let hPad: CGFloat = 20        // header padding
    static let cardMargin: CGFloat = 7   // card-to-screen-edge gap (= hPad / 3)
    /// 标准信用卡比例 85.6×53.98mm ≈ 1.586:1（宽/高），随屏幕宽度动态计算
    static var cardH: CGFloat { (ScreenCompat.width - cardMargin * 2) / 1.586 }
    static let expandedCardH: CGFloat = 360
    // Default stack mode: each covered card exposes the one-line identity area
    // (name + species / role), while avoiding an overly loose card stack.
    static let cardTitleH: CGFloat = 49
    static let collapsedStackPeekH: CGFloat = cardTitleH * 0.9
    // Expanded hero mode keeps the inactive cards in a tighter mini-stack.
    static let stackPeekH: CGFloat = collapsedStackPeekH
    static var expandedInactiveStackPeekH: CGFloat { collapsedStackPeekH / 5 }
    // In expanded mode the inactive mini-stack lives mostly below the real
    // screen bottom, with only the front card's top edge peeking above it.
    static let expandedInactiveFrontPeekH: CGFloat = 18
    // Collapsed front card bottom gap above the screen bottom safe area.
    // The front card is always fully visible; additional cards grow upward.
    static let collapsedStackBottomGap: CGFloat = 22
    static let expandedStackBottomGap: CGFloat = 12
    // Global target for expanded card's top: safe-area top + this offset.
    // Keep the active card directly below the top controls so
    // the quick modules below it remain visible above the compressed card stack.
    static let expandedCardGlobalTopOffset: CGFloat = 76
    static let expandedQuickModuleH: CGFloat = 112
    static let expandedQuickModuleEditH: CGFloat = 206
    static var stackSpacing: CGFloat { -(cardH - collapsedStackPeekH) }

    static let heroMargin: CGFloat = 16
    static let focusCardPadding: CGFloat = heroMargin / 3
}

enum HeroAnim {
    static let stackCardCorner: CGFloat = 24
    static var transitionSpring: Animation {
        GoMotion.page
    }
    // Apple-Wallet-style card morph: quick, restrained, slight overshoot.
    static var walletSpring: Animation {
        GoMotion.hero
    }
    static var fabSpring: Animation {
        GoMotion.fab
    }
    static var buttonSpring: Animation {
        GoMotion.feedback
    }
    // Compact-mode peek (how much of each non-active card shows behind the active one)
    static let compactPeek: CGFloat = 14
}

struct HeroShellID: Hashable { let cardId: UUID }
struct HeroArtID:  Hashable { let cardId: UUID }

private struct ExpandedQuickPetRecordRoute: Identifiable {
    let id = UUID()
    let pet: Pet
}

private struct ExpandedQuickHumanRecordRoute: Identifiable {
    let id = UUID()
    let human: Human
}

private enum ExpandedQuickActionMenuTarget: Identifiable {
    case pet(QuickActionItem, Pet)
    case human(QuickActionItem, Human)

    var id: String {
        switch self {
        case .pet(let item, let pet):
            return "pet:\(pet.id.uuidString):\(item.id)"
        case .human(let item, let human):
            return "human:\(human.id.uuidString):\(item.id)"
        }
    }
}

private struct ExpandedQuickMenuOption: Identifiable {
    let id: String
    let icon: String
    let title: String
    let tint: Color
}

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
        let recentFeedStart = Calendar.current.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart
        _allFeedCareLogs = Query(
            filter: #Predicate<PetCareLog> { $0.type == "喂食" && $0.date >= recentFeedStart },
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
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(filter: #Predicate<PetCareLog> { $0.type == "喂食" },
           sort: \PetCareLog.date,
           order: .reverse) private var allFeedCareLogs: [PetCareLog]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    // Header state
    @State private var functionMenuPresentation: FunctionMenuPresentation?
    @State private var showStreakDetail    = false
    @State private var headerStreak        = 0
    @State private var fabExpanded         = false
    @State private var fabMenuItemsVisible = false
    @State private var showingCoconutLog   = false
    @State private var showingAddEntity    = false
    @State private var addEntityInitialType: EntityType? = nil
    @State private var showingCrewRoster   = false
    @State private var showingAccountSwitcher = false
    @State private var showingSettings     = false
    @State private var showingCalendar     = false
    @State private var calendarEntityFilterId: String? = nil
    @State private var calendarHumanFilterId: String? = nil
    @State private var showingOasisReward  = false
    @State private var cardFabExpanded     = false
    @State private var cardFabMenuItemsVisible = false
    @State private var expandedAllFeaturesPet: Pet? = nil
    @State private var expandedAllFeaturesHuman: Human? = nil
    @State private var expandedBasicInfoPet: Pet? = nil
    @State private var expandedBasicInfoHuman: Human? = nil
    @State private var pressedExpandedActionId: String? = nil
    @State private var expandedQuickActionMenuTarget: ExpandedQuickActionMenuTarget? = nil
    @State private var expandedQuickWeightPet: ExpandedQuickPetRecordRoute? = nil
    @State private var expandedQuickExpensePet: ExpandedQuickPetRecordRoute? = nil
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
    @State private var expandedQuickHumanWeight: ExpandedQuickHumanRecordRoute? = nil
    @State private var expandedQuickHumanWorkout: Human? = nil
    @State private var expandedQuickHumanMedicationAdd: Human? = nil
    @State private var expandedQuickHumanMedication: Human? = nil
    @State private var expandedQuickHumanNote: Human? = nil
    @State private var expandedQuickHumanExpense: Human? = nil
    @State private var expandedHumanWeightDetail: Human? = nil
    @State private var expandedHumanWorkoutDetail: Human? = nil
    @State private var expandedHumanExpenseDetail: Human? = nil
    @State private var expandedHumanNoteDetail: Human? = nil
    @State private var isExpandedQAEditMode = false
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    private var maxCardsPerPage: Int { 7 }
    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || workloadPolicy.shouldReduceWork()
    }
    private var walletAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : HeroAnim.walletSpring
    }
    private var transitionAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : HeroAnim.transitionSpring
    }
    @State private var expandedQAJiggle = false
    @State private var expandedQAEditItems: [QuickActionItem] = []
    @State private var expandedQADraggingItemId: String? = nil
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
    @State private var walkTransformBurstCardId: UUID? = nil
    @State private var showExpandedCoconutReward = false
    @State private var expandedCoconutRewardAmount = 0
    @State private var expandedCoconutRewardLabel: String? = nil
    @State private var homeCardReorderDragId: UUID? = nil
    @State private var homeCardReorderDragOffset: CGFloat = 0
    @State private var homeCardReorderStartOffsetY: CGFloat = 0
    @State private var homeCardReorderCards: [FocusCard]? = nil
    @State private var homeCardReorderDidMove = false
    @State private var homeCardPressCandidateId: UUID? = nil
    @State private var suppressNextHomeCardTap = false
    @State private var homeCardReorderSession = 0
    @State private var homeCardReorderEnabled = false
    @State private var homeCardReorderModeActive = false
    @State private var didRecordHomeFirstFrame = false
    @State private var homeDeferredContentReady = false
    @State private var avatarCacheRevision = 0
    @State private var quickActionClockTick = Date()
    @State private var homeCardSnapshot: [FocusCard] = []
    @State private var homeCardSnapshotInitialized = false

    // Debug-only: show Mochi/Luna dummy stack even when real data is empty.
    @AppStorage("debugShowDummyCards") private var showDummyCards: Bool = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw: String = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr: String = ""
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false
    @State private var pendingFirstSuccessMomentPetId: UUID?
    @State private var firstSuccessMomentCoconutBefore: Int?

    // Bloom expand (dummy cards only)
    @Namespace private var ns
    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var detailFooterVisible: Bool = false

    // Apple-Wallet-style three-state stack:
    //  • collapsed (isExpanded=false): all cards fan vertically below the focus strip;
    //    the bottom card is frontmost and fully visible.
    //  • expanded  (isExpanded=true): tapped card lifts below the top controls; the
    //    inactive cards compress into a tight wallet stack at the screen bottom.
    //  • restore: tapping the active card again, or swiping down, returns to collapsed.
    // Tapping cards only changes the wallet state. In collapsed mode, long-press
    // then drag reorders the home stack; expanded hero long-press opens basic info.
    @State private var isExpanded: Bool = false
    @State private var activeCardId: UUID?
    @State private var expandedQuickModulesReady = false
    @State private var rosterPreviewCard: FocusCard?
    @State private var pendingPromotedHomeCardId: UUID?
    @State private var walletTapFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    private let homeCardReorderLiftY: CGFloat = -10

    private var todayFocusActivePet: Pet? {
        if let id = activeCardId,
           let pet = pets.first(where: { $0.id == id && !$0.hasPassedAway }) {
            return pet
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 59
    }

    private var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 34
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
        activeWalletCard?.coconutBalance ?? activeHumanCoconutBalance
    }

    private var cards: [FocusCard] {
        homeCardSnapshotInitialized ? homeCardSnapshot : buildHomeCardSnapshot()
    }

    private var homeCardSnapshotSourceSignature: String {
        let petSignature = pets.map { pet in
            [
                pet.id.uuidString,
                pet.name,
                pet.species,
                pet.breed,
                pet.safeThemeColorHex,
                "\(pet.hasPassedAway)",
                "\(pet.currentStreak)",
                "\(pet.coconutBalance)",
                "\(pet.daysTogether)",
                pet.avatarImageData.map { FocusWalletAvatarCache.signature(for: $0) } ?? ""
            ].joined(separator: "|")
        }.joined(separator: ";")
        let humanSignature = humans.map { human in
            [
                human.id.uuidString,
                human.name,
                human.roleText,
                human.safeThemeColorHex,
                "\(human.shouldShowOnHome)",
                "\(human.coconutBalance)",
                human.avatarImageData.map { FocusWalletAvatarCache.signature(for: $0) } ?? ""
            ].joined(separator: "|")
        }.joined(separator: ";")
        return [
            petSignature,
            humanSignature,
            hiddenHomePetIDsRaw,
            homeCardOrderRaw,
            "\(showDummyCards)",
            appLanguage
        ].joined(separator: "||")
    }

    private func buildHomeCardSnapshot() -> [FocusCard] {
        let real = (
            pets
                .filter { !$0.hasPassedAway && HomeCardVisibility.isPetVisible($0, raw: hiddenHomePetIDsRaw) }
                .map { FocusCard.from($0) }
            + humans
                .filter { $0.shouldShowOnHome }
                .map { FocusCard.from($0) }
        )
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.name < rhs.name
        }
        if !real.isEmpty { return homeCardsOrderedByPreference(real) }
        // Real empty state → no dummy fallback (handled by EmptyStateWelcomeCard in stackLayer).
        // Debug flag preserves the old Mochi/Luna stack for UI exploration.
        guard showDummyCards else { return [] }
        let usedNames = Set(real.map { $0.name })
        let extras = FocusCard.dummies.filter { !usedNames.contains($0.name) }
        return homeCardsOrderedByPreference(real + extras)
    }

    private func refreshHomeCardSnapshot() {
        let snapshot = buildHomeCardSnapshot()
        homeCardSnapshot = snapshot
        homeCardSnapshotInitialized = true
        preheatAvatarCache(for: Array(snapshot.prefix(maxCardsPerPage)))
    }

    private func avatarPayloads(for cards: [FocusCard]) -> [FocusWalletAvatarCache.Payload] {
        cards.map { FocusWalletAvatarCache.Payload(id: $0.id, data: $0.avatarImageData) }
    }

    private func preheatAvatarCache(for cards: [FocusCard]) {
        let payloads = avatarPayloads(for: cards)
        guard !payloads.isEmpty else { return }
        Task(priority: .userInitiated) {
            let didRefresh = await FocusWalletAvatarCache.preload(payloads: payloads)
            guard !Task.isCancelled else { return }
            if didRefresh {
                avatarCacheRevision &+= 1
            }
        }
    }

    private func runHomePostFirstFrameMaintenance() {
        Task { @MainActor in
            await Task.yield()
            if !homeDeferredContentReady {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.14)) {
                    homeDeferredContentReady = true
                }
            }
            ensureTodayCheckIn()
            refreshHeaderStreak()
            syncWalkCardSurfaceVisibility()
            walletTapFeedbackGenerator.prepare()
        }
    }

    private func prepareExpandedQuickModulesAfterHeroFrame() {
        expandedQuickModulesReady = false
        let expectedCardId = activeCardId
        Task { @MainActor in
            await Task.yield()
            guard isExpanded, activeCardId == expectedCardId else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                expandedQuickModulesReady = true
            }
        }
    }

    private var visibleHomeCards: [FocusCard] {
        var visible = Array(cards.prefix(maxCardsPerPage))
        if let rosterPreviewCard,
           (isExpanded || activeCardId == rosterPreviewCard.id),
           !visible.contains(where: { $0.id == rosterPreviewCard.id }) {
            visible.append(rosterPreviewCard)
        }
        return visible
    }

    private var visibleHomeCardsAvatarSignature: String {
        visibleHomeCards
            .map { card in
                let data = card.avatarImageData
                let signature = data.map { FocusWalletAvatarCache.signature(for: $0) } ?? ""
                return "\(card.id.uuidString):\(signature)"
            }
            .joined(separator: "|")
    }

    private var isEmptyState: Bool {
        pets.allSatisfy { $0.hasPassedAway } && humans.isEmpty && !showDummyCards
    }

    private var activeWalletCard: FocusCard? {
        guard isExpanded else { return nil }
        let heroId = activeCardId ?? visibleHomeCards.first?.id
        return visibleHomeCards.first { $0.id == heroId }
    }

    private var isWalkCardExpandedSurfaceVisible: Bool {
        guard isExpanded,
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
        expandedQuickWeightPet != nil
        || expandedQuickExpensePet != nil
        || expandedQuickHumanWeight != nil
        || expandedQuickActionMenuTarget != nil
    }

    var body: some View {
        let windowSize = ScreenCompat.bounds.size
        let outerR = displayCornerRadius

        return GeometryReader { geo in
            ZStack {
                OhanaAppBackground()

                stackLayer(geo: geo, outerCornerRadius: outerR)
                    .opacity(expandedId == nil ? 1 : 0)
                    .allowsHitTesting(expandedId == nil)

                if let id = expandedId,
                   let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo, outerCornerRadius: outerR, windowSize: windowSize)
                }

                // FAB stays mounted while the wallet card stack changes modes; only its submenu content changes.
                if expandedId == nil && !isInlineRecordOverlayPresented {
                    if fabExpanded {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { closeHomeFabMenu() }
                            .transition(.opacity)
                    }
                    homeFabOverlay(activeCard: activeWalletCard)
                        .zIndex(999)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                }

                quickInlineRecordOverlays()
                    .zIndex(2500)

                expandedQuickActionMenuOverlay()
                    .zIndex(2600)
            }
            .animation(transitionAnimation, value: expandedId)
            .animation(GoMotion.page, value: expandedQuickWeightPet?.id)
            .animation(GoMotion.page, value: expandedQuickExpensePet?.id)
            .animation(GoMotion.page, value: expandedQuickHumanWeight?.id)
            .animation(GoMotion.page, value: expandedQuickActionMenuTarget?.id)
            .onChange(of: expandedId) { _, newId in
                if newId != nil {
                    detailFooterVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(GoMotion.quick) { detailFooterVisible = true }
                    }
                } else {
                    detailFooterVisible = false
                    // Collapse wallet hero mode when bloom closes
                    withAnimation(walletAnimation) { isExpanded = false }
                }
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .coconutRewardOverlay(
            trigger: $showExpandedCoconutReward,
            amount: expandedCoconutRewardAmount,
            label: expandedCoconutRewardLabel
        )
        // Sheets
        .sheet(item: $functionMenuPresentation) { presentation in
            FunctionMenuSheet(initialDestination: presentation.destination)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showStreakDetail) {
            DailyStreakDetailView(pets: pets, onClose: { showStreakDetail = false })
        }
        .fullScreenCover(isPresented: $showingCoconutLog) { IslandWealthDashboardView() }
        .fullScreenCover(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingAddEntity, onDismiss: handleAddEntityDismissed) {
            AddEntityView(
                initialType: addEntityInitialType,
                onPetSaved: { pet in
                    handlePetSavedFromAddEntity(pet)
                },
                onTypeChange: { type in
                    addEntityInitialType = type
                }
            )
        }
        .sheet(isPresented: $showingCrewRoster) {
            NavigationStack {
                CrewRosterOverlay(
                    onSelectPet: { pet in
                        openCrewRosterCard(FocusCard.from(pet))
                    },
                    onSelectHuman: { human in
                        openCrewRosterCard(FocusCard.from(human))
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingCrewRoster = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAccountSwitcher) {
            HumanAccountSwitcherSheet()
        }
        .sheet(isPresented: $showingCalendar, onDismiss: {
            calendarEntityFilterId = nil
            calendarHumanFilterId = nil
        }) {
            CalendarView(
                preselectedPetId: calendarEntityFilterId,
                preselectedHumanId: calendarHumanFilterId
            )
        }
        .sheet(item: $expandedAllFeaturesPet) { pet in
            PetAllFeaturesSheet(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedAllFeaturesHuman) { human in
            HumanAllFeaturesSheet(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedBasicInfoPet) { pet in
            NavigationStack { PetBasicInfoDetailView(pet: pet) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedBasicInfoHuman) { human in
            NavigationStack { HumanBasicInfoDetailView(human: human) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickWeightDetailPet) { pet in
            NavigationStack { WeightHistoryView(pet: pet) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickExpenseDetailPet) { pet in
            NavigationStack { ExpenseHistoryView(pet: pet) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickFeedDetailPet) { pet in
            QuickFeedDetailSheet(
                pet: pet,
                onRemove: { expandedQuickFeedDetailPet = nil },
                opensManualSheetOnAppear: expandedQuickFeedOpensManualSheet
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .onDisappear { expandedQuickFeedOpensManualSheet = false }
        }
        .sheet(item: $expandedQuickWaterDetailPet) { pet in
            QuickWaterDetailSheet(pet: pet) {
                expandedQuickWaterDetailPet = nil
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickPottyDetailPet) { pet in
            QuickPottyDetailSheet(pet: pet) { expandedQuickPottyDetailPet = nil }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickLitterDetailPet) { pet in
            QuickLitterDetailSheet(pet: pet) { expandedQuickLitterDetailPet = nil }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickPlayDetailPet) { pet in
            QuickPlayDetailSheet(pet: pet) { expandedQuickPlayDetailPet = nil }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickHygienePet) { pet in
            NavigationStack { PetHygieneDetailView(pet: pet) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickWalkPet) { pet in
            NavigationStack { WalkSummarySheet(pet: pet) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $todayFocusWalkPet) { pet in
            WalkTrackingFullScreen(pet: pet)
        }
        .sheet(item: $expandedQuickHealthPet, onDismiss: {
            expandedQuickHealthInitialSection = nil
        }) { pet in
            NavigationStack {
                PetHealthDetailView(
                    pet: pet,
                    isModal: true,
                    initialSection: expandedQuickHealthInitialSection
                )
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickPetMedicationPet) { pet in
            NavigationStack { PetMedicationView(pet: pet) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickMomentPet) { pet in
            QuickMomentSheet(pet: pet, onRemove: nil, onSaved: {
                expandedQuickMomentPet = nil
                completeFirstSuccessMomentIfNeeded(for: pet)
            })
        }
        .sheet(item: $expandedMomentHistoryPet) { pet in
            PetMomentsHubView(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickHumanWorkout) { human in
            AddWorkoutSheet(
                human: human,
                onSaved: {
                    triggerExpandedActionFeedback(cardId: human.id)
                }
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickHumanMedicationAdd) { human in
            AddMedicationSheet(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickHumanMedication) { human in
            NavigationStack {
                HumanMedicationView(
                    human: human,
                    showsDoneButton: true,
                    onDoseTaken: {
                        triggerExpandedActionFeedback(cardId: human.id)
                    }
                )
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickHumanNote) { human in
            QuickHumanNoteSheet(human: human)
        }
        .sheet(item: $expandedQuickHumanExpense) { human in
            QuickHumanExpenseSheet(human: human)
        }
        .sheet(item: $expandedHumanWeightDetail) { human in
            NavigationStack {
                HumanWeightHistoryView(human: human)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanWorkoutDetail) { human in
            HumanWorkoutHistoryView(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanExpenseDetail) { human in
            NavigationStack {
                HumanExpenseDetailView(human: human)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedHumanNoteDetail) { human in
            HumanNoteHistorySheet(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingOasisReward) {
            OasisRewardView()
        }
        .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
            Button(l.homeConfirmCheckIn, role: .destructive) {
                pendingRepeatAction?()
                pendingRepeatAction = nil
            }
            Button(l.cancel, role: .cancel) {
                pendingRepeatAction = nil
            }
        } message: {
            Text(antiRepeatMessage)
        }
        .alert(singleUseNoticeTitle, isPresented: $showingSingleUseNotice) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(singleUseNoticeMessage)
        }
        .alert(QuickActionLimit.title, isPresented: $showingQuickActionLimitAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(QuickActionLimit.message)
        }
        .alert("仅本人可见", isPresented: $showingHumanPrivacyAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("该成员已将此功能设为仅自己可见。")
        }
        // Collapse wallet hero state when returning from pet/human detail
        .onChange(of: selectedPet)   { _, new in if new == nil { withAnimation(walletAnimation) { isExpanded = false } } }
        .onChange(of: selectedHuman) { _, new in if new == nil { withAnimation(walletAnimation) { isExpanded = false } } }
        .onChange(of: isExpanded) { _, expanded in
            if expanded, homeCardPressCandidateId != nil || homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
                resetHomeCardReorderState()
            }
            if expanded {
                cardFabMenuItemsVisible = false
                cardFabExpanded = false
                prepareExpandedQuickModulesAfterHeroFrame()
            } else {
                expandedQuickModulesReady = false
            }
            syncWalkCardSurfaceVisibility()
        }
        .onChange(of: activeCardId) { _, _ in
            if isExpanded {
                cardFabMenuItemsVisible = false
                cardFabExpanded = false
                prepareExpandedQuickModulesAfterHeroFrame()
            }
            syncWalkCardSurfaceVisibility()
        }
        .onChange(of: PetWalkingManager.shared.phase) { _, _ in syncWalkCardSurfaceVisibility() }
        .onChange(of: PetWalkingManager.shared.currentPet?.id) { _, _ in syncWalkCardSurfaceVisibility() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshHeaderStreak()
        }
        .onChange(of: activeHumanIdStr) { _, _ in
            ensureTodayCheckIn()
            refreshHeaderStreak()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            guard workloadPolicy.shouldRunTimer() else { return }
            quickActionClockTick = date
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReturnHomeAfterHumanDeletion)) { _ in
            selectedHuman = nil
            expandedBasicInfoHuman = nil
            expandedAllFeaturesHuman = nil
            expandedQuickHumanWeight = nil
            expandedQuickHumanWorkout = nil
            expandedQuickHumanMedicationAdd = nil
            expandedQuickHumanMedication = nil
            expandedQuickHumanNote = nil
            expandedQuickHumanExpense = nil
            expandedHumanWeightDetail = nil
            expandedHumanWorkoutDetail = nil
            expandedHumanExpenseDetail = nil
            expandedHumanNoteDetail = nil
            withAnimation(walletAnimation) {
                activeCardId = nil
                isExpanded = false
            }
        }
        .onAppear {
            refreshHomeCardSnapshot()
            if !didRecordHomeFirstFrame {
                didRecordHomeFirstFrame = true
                DispatchQueue.main.async {
                    AppPerformanceMonitor.shared.record("启动到首页首帧", startedAt: ohanaProcessStartTime)
                }
            }
            if !homeCardReorderEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    homeCardReorderEnabled = true
                }
            }
            runHomePostFirstFrameMaintenance()
        }
        .onChange(of: homeCardSnapshotSourceSignature) { _, _ in
            refreshHomeCardSnapshot()
        }
        .onDisappear {
            PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = false
        }
        .task(id: visibleHomeCardsAvatarSignature) {
            guard !Task.isCancelled else { return }
            let payloads = avatarPayloads(for: visibleHomeCards)
            let didRefresh = await FocusWalletAvatarCache.preload(payloads: payloads)
            if didRefresh {
                avatarCacheRevision &+= 1
            }
        }
    }
}

private struct TodayFocusQuestCardHost: View {
    let pets: [Pet]
    let plants: [Plant]
    let reminders: [Reminder]
    let humans: [Human]
    let events: [Event]
    let activePet: Pet?
    var onCompleteQuest: (IslandQuest) -> Void
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void
    var onTapOasis: () -> Void
    var onTapFamilyTask: (FamilyCollaborationTask) -> Void

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var privacyVisibleHumans: [Human] {
        PrivacyService.unlockedHumans(for: .weight, from: humans, viewedBy: activeHumanId)
    }

    var body: some View {
        TodayFocusCard(
            pets: pets,
            plants: plants,
            quests: IslandQuestEngine.todayQuests(
                pets: pets,
                reminders: reminders,
                plants: plants,
                events: events,
                humans: privacyVisibleHumans
            ),
            humans: privacyVisibleHumans,
            activePet: activePet,
            onCompleteQuest: onCompleteQuest,
            onTapNegativeSignal: onTapNegativeSignal,
            onTapOasis: onTapOasis,
            onTapFamilyTask: onTapFamilyTask
        )
    }
}

// ─────────────────────────────────────────────────
// MARK: – Stack layer
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    @ViewBuilder
    private func quickInlineRecordOverlays() -> some View {
        if let route = expandedQuickWeightPet {
            let pet = route.pet
            GenericWeightEntrySheet(
                target: .pet(pet),
                onRewarded: { delta in
                    triggerExpandedActionFeedback(
                        cardId: pet.id,
                        coconutDelta: delta,
                        label: delta > 0 ? "体重记录 +\(delta)🥥" : nil
                    )
                },
                onDismiss: {
                    dismissExpandedQuickWeight(routeID: route.id)
                }
            )
            .id(route.id)
            .zIndex(1)
        }

        if let route = expandedQuickExpensePet {
            let pet = route.pet
            AddExpenseSheet(
                pet: pet,
                preselectedPayerId: UserDefaults.standard.string(forKey: "currentActiveHumanId"),
                onRewarded: { delta in
                    triggerExpandedActionFeedback(
                        cardId: pet.id,
                        coconutDelta: delta,
                        label: delta > 0 ? "花费记录 +\(delta)🥥" : nil
                    )
                },
                onDismiss: {
                    dismissExpandedQuickExpense(routeID: route.id)
                }
            )
            .id(route.id)
            .zIndex(2)
        }

        if let route = expandedQuickHumanWeight {
            let human = route.human
            GenericWeightEntrySheet(
                target: .human(human),
                onSaved: {
                    triggerExpandedActionFeedback(cardId: human.id)
                },
                onDismiss: {
                    dismissExpandedQuickHumanWeight(routeID: route.id)
                }
            )
            .id(route.id)
            .zIndex(3)
        }
    }

    private func openExpandedQuickWeight(for pet: Pet) {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickWeightPet = ExpandedQuickPetRecordRoute(pet: pet)
    }

    private func openExpandedQuickExpense(for pet: Pet) {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickExpensePet = ExpandedQuickPetRecordRoute(pet: pet)
    }

    private func openExpandedQuickHumanWeight(for human: Human) {
        fabMenuItemsVisible = false
        cardFabMenuItemsVisible = false
        fabExpanded = false
        cardFabExpanded = false
        expandedQuickHumanWeight = ExpandedQuickHumanRecordRoute(human: human)
    }

    private func dismissExpandedQuickWeight(routeID: UUID) {
        guard expandedQuickWeightPet?.id == routeID else { return }
        expandedQuickWeightPet = nil
    }

    private func dismissExpandedQuickExpense(routeID: UUID) {
        guard expandedQuickExpensePet?.id == routeID else { return }
        expandedQuickExpensePet = nil
    }

    private func dismissExpandedQuickHumanWeight(routeID: UUID) {
        guard expandedQuickHumanWeight?.id == routeID else { return }
        expandedQuickHumanWeight = nil
    }

    private var dailyCheckInKey: String { CheckInStreakStore.checkedInKey(for: activeHumanIdStr) }

    private func dailyCheckInDateString(_ date: Date = Date()) -> String {
        CheckInStreakStore.dateString(date)
    }

    private func ensureTodayCheckIn() {
        let today = dailyCheckInDateString()
        var checkedInDates = CheckInStreakStore.checkedInDates(for: activeHumanIdStr)
        guard !checkedInDates.contains(today) else { return }

        checkedInDates.insert(today)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: activeHumanIdStr)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: l.homeDailyCheckInRewardTitle)
    }

    private func refreshHeaderStreak() {
        headerStreak = CheckInStreakStore.currentStreak(for: activeHumanIdStr)
    }

    private func stackLayer(geo: GeometryProxy, outerCornerRadius: CGFloat) -> some View {
        let activePets = pets.filter { !$0.hasPassedAway }
        return VStack(spacing: 0) {
            goFocusHeader(safeT: safeAreaTop)

            todayFocusSection(activePets: activePets)
                .offset(y: -20)
                .padding(.bottom, -10)

            if isEmptyState {
                Spacer(minLength: 0)
                EmptyStateWelcomeCard(
                    onAddPet:   { presentAddEntity(initialType: .pet) },
                    onAddHuman: { presentAddEntity(initialType: .human) }
                )
                .padding(.horizontal, K.cardMargin)
                .padding(.bottom, 24)
            } else {
                // GeometryReader-based stack fills all remaining space below the header/focus strip.
                // Keep the same wallet stack mounted in both collapsed and expanded modes so
                // card positions animate instead of swapping between two separate layers.
                walletCardStack(cards: visibleHomeCards)
                    .padding(.horizontal, K.cardMargin)
            }
        }
    }

    @ViewBuilder
    private func todayFocusSection(activePets: [Pet]) -> some View {
        // Collapsed first screen answers: who needs care, what is urgent, what can be done now.
        if (!activePets.isEmpty || !humans.isEmpty) && !isExpanded {
            if homeDeferredContentReady {
                TodayFocusCarousel(cardMargin: K.cardMargin, animation: walletAnimation) { cardWidth in
                    TodayFocusQuestCardHost(
                        pets: activePets,
                        plants: plants,
                        reminders: pendingReminders,
                        humans: humans,
                        events: allEvents,
                        activePet: todayFocusActivePet,
                        onCompleteQuest: { completeQuestInFocusStack($0) },
                        onTapNegativeSignal: { handleTodayFocusNegativeSignal($0) },
                        onTapOasis: { showingOasisReward = true },
                        onTapFamilyTask: { openFamilyTaskFromTodayFocus($0) }
                    )
                    .frame(width: cardWidth)

                    if showFirstSuccessCard,
                       !firstQuickCheckInCompleted,
                       let pet = todayFocusActivePet {
                        HomeFirstSuccessCard(
                            pet: pet,
                            onFeed: { completeFirstSuccessFeed(for: pet) },
                            onPlay: { completeFirstSuccessPlay(for: pet) },
                            onMoment: { startFirstSuccessMoment(for: pet) }
                        )
                        .frame(width: cardWidth)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(walletAnimation, value: isExpanded)
            } else {
                Color.clear
                    .frame(height: 216)
                    .padding(.top, 12)
            }
        }
    }

    // MARK: Apple-Wallet card stack — three states
    //
    // fan  (isExpanded=false): all cards fan vertically at the bottom of the
    //   available area. idx n-1 is frontmost (highest z). Tap any card → hero.
    //
    // hero (isExpanded=true): tapped card lifts to top of available area;
    //   ALL other cards compress into a tight stack at the bottom. Tap hero → restore.
    //   Tap another card → switch hero. Swipe-down → restore fan.
    //
    // Layout uses GeometryReader so the stack fills all space below the mood strip
    // and cards can animate across the full height.

    @ViewBuilder
    private func expandedWalletLayer(cards: [FocusCard], geo: GeometryProxy) -> some View {
        let n = cards.count
        let heroId = activeCardId ?? cards.first?.id
        let cardW = geo.size.width - K.cardMargin * 2
        let activeTopY = safeAreaTop + K.expandedCardGlobalTopOffset
        let inactiveBottomY = geo.size.height + K.cardH - K.expandedInactiveFrontPeekH
        let quickModulesTopY = activeTopY + K.expandedCardH + 14

        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let isHero = card.id == heroId
                let isInteractiveWalkCard = isWalkTrackingCard(card: card, isHero: isHero)
                let visibleHeight = isHero ? K.expandedCardH : K.cardH

                transformedWalletCard(card: card, isHero: isHero)
                .frame(width: cardW)
                .frame(height: isHero ? K.expandedCardH : K.cardH)
                .frame(height: visibleHeight, alignment: .top)
                .clipped()
                .scaleEffect(expandedActionPulseCardId == card.id ? 1.025 : 1.0, anchor: .center)
                .overlay { expandedActionPulseOverlay(for: card.id) }
                .overlay { walkTransformBurstOverlay(for: card.id) }
                .shadow(
                    color: .black.opacity(isHero ? 0.22 : 0.11),
                    radius: isHero ? 20 : 8,
                    x: 0,
                    y: isHero ? 12 : 4
                )
                .offset(
                    x: K.cardMargin,
                    y: expandedWalletOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: inactiveBottomY,
                        heroId: heroId,
                        heroTopY: activeTopY,
                        cards: cards
                    )
                )
                .zIndex(walletZIndex(idx: idx, n: n, isHero: isHero, heroId: heroId, cards: cards))
                .if(!isInteractiveWalkCard) { view in
                    view
                        .onTapGesture { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            guard isHero else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            openWalletCardBasicInfo(card)
                        }
                        .simultaneousGesture(collapseWalletDragGesture())
                }
                .animation(walletAnimation, value: isExpanded)
                .animation(walletAnimation, value: activeCardId)
            }

            if let activeCard = cards.first(where: { $0.id == heroId }) {
                expandedQuickModules(card: activeCard)
                    .frame(width: cardW, height: expandedQuickModuleHeight(for: activeCard))
                    .offset(x: K.cardMargin, y: quickModulesTopY)
                    .zIndex(Double(n + 80))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .simultaneousGesture(collapseWalletDragGesture())
                    .animation(walletAnimation, value: activeCardId)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        .ignoresSafeArea(.all)
    }

    private func expandedQuickModuleHeight(for card: FocusCard) -> CGFloat {
        let visibleCount: Int
        if card.isReal,
           !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            if shouldShowFirstSuccessPrompt(for: pet) && !isExpandedQAEditMode {
                return K.expandedQuickModuleH
            }
            visibleCount = isExpandedQAEditMode
                ? expandedQAEditItems.count + 1
                : min(expandedQuickActionItems(for: pet).count, 8)
        } else if card.isReal,
                  card.isHuman,
                  let human = humans.first(where: { $0.id == card.id }) {
            visibleCount = isExpandedQAEditMode
                ? expandedQAEditItems.count + 1
                : min(expandedHumanQuickActionItems(for: human).count, 8)
        } else {
            visibleCount = card.actions.count
        }
        return visibleCount > 4 ? K.expandedQuickModuleEditH : K.expandedQuickModuleH
    }

    private func presentAddEntity(initialType: EntityType? = nil) {
        addEntityInitialType = initialType
        showingAddEntity = true
    }

    private func handleAddEntityDismissed() {
        addEntityInitialType = nil
    }

    private func handlePetSavedFromAddEntity(_ pet: Pet) {
        hiddenHomePetIDsRaw = HomeCardVisibility.rawBySettingPet(pet, visible: true, raw: hiddenHomePetIDsRaw)
        promoteHomeCardToFront(id: pet.id)
        pendingPromotedHomeCardId = pet.id
        rosterPreviewCard = nil
        firstQuickCheckInCompleted = false
        showFirstSuccessCard = true
        withAnimation(walletAnimation) {
            activeCardId = pet.id
            isExpanded = true
        }
    }

    private func homeCardsOrderedByPreference(_ base: [FocusCard]) -> [FocusCard] {
        let preferredIds = homeCardOrderRaw
            .split(separator: ",")
            .map(String.init)
        guard !preferredIds.isEmpty else { return base }

        var preferredRank: [String: Int] = [:]
        for (index, id) in preferredIds.enumerated() where preferredRank[id] == nil {
            preferredRank[id] = index
        }
        return base.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = preferredRank[lhs.element.id.uuidString] ?? Int.max
                let rhsRank = preferredRank[rhs.element.id.uuidString] ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func saveHomeCardOrder(_ cards: [FocusCard]) {
        homeCardOrderRaw = cards
            .map { $0.id.uuidString }
            .joined(separator: ",")
        refreshHomeCardSnapshot()
    }

    private func promoteHomeCardToFront(id: UUID) {
        var ids = homeCardOrderRaw
            .split(separator: ",")
            .map(String.init)
        let idString = id.uuidString
        ids.removeAll { $0 == idString }
        ids.insert(idString, at: 0)
        homeCardOrderRaw = ids.joined(separator: ",")
        refreshHomeCardSnapshot()
    }

    private func homeCardDisplayCards(from source: [FocusCard]) -> [FocusCard] {
        guard homeCardReorderDragId != nil, let reorderingCards = homeCardReorderCards else { return source }

        let sourceById = Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        let ordered = reorderingCards.compactMap { sourceById[$0.id] }
        let orderedIds = Set(ordered.map(\.id))
        let remaining = source.filter { !orderedIds.contains($0.id) }
        return ordered + remaining
    }

    private func collapseWalletDragGesture() -> some Gesture {
        DragGesture()
            .onEnded { v in
                guard v.translation.height > 80 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(walletAnimation) { isExpanded = false }
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
        let items = isExpandedQAEditMode
            ? expandedQAEditItems
            : Array(expandedQuickActionItems(for: pet).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: pet.id, data: pet.avatarImageData).image
        let themeHex = pet.safeThemeColorHex
        let showPrompt = shouldShowFirstSuccessPrompt(for: pet) && !isExpandedQAEditMode

        return ExpandedPetQuickActionsSection(
            title: showPrompt ? "第一次成功" : "快捷操作",
            pet: pet,
            items: items,
            avatar: avatar,
            themeHex: themeHex,
            editItems: $expandedQAEditItems,
            draggingItemId: $expandedQADraggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: isExpandedQAEditMode,
            jiggle: expandedQAJiggle,
            shouldReduceWork: shouldReduceWork,
            showFirstSuccessPrompt: showPrompt,
            waterManagementLabel: waterManagementLabel,
            onToggleEdit: {
                if isExpandedQAEditMode {
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
            onTap: { presentExpandedQuickActionMenu(.pet($0, pet)) },
            onLongPress: { presentExpandedQuickActionMenu(.pet($0, pet)) },
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
        let items = isExpandedQAEditMode
            ? expandedQAEditItems
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: human.id, data: human.avatarImageData).image
        let themeHex = human.safeThemeColorHex

        return ExpandedHumanQuickActionsSection(
            human: human,
            items: items,
            defaultItems: defaultExpandedHumanQuickActions(for: human),
            avatar: avatar,
            themeHex: themeHex,
            editItems: $expandedQAEditItems,
            draggingItemId: $expandedQADraggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: isExpandedQAEditMode,
            jiggle: expandedQAJiggle,
            shouldReduceWork: shouldReduceWork,
            onToggleEdit: {
                if isExpandedQAEditMode {
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
            onTap: { presentExpandedQuickActionMenu(.human($0, human)) },
            onLongPress: { presentExpandedQuickActionMenu(.human($0, human)) },
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

    private func dismissExpandedQuickActionMenu() {
        withAnimation(GoMotion.page) {
            expandedQuickActionMenuTarget = nil
        }
    }

    @ViewBuilder
    private func expandedQuickActionMenuOverlay() -> some View {
        if let target = expandedQuickActionMenuTarget {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10), // ui-v4: allow modal scrim
                            Color.black.opacity(colorScheme == .dark ? 0.46 : 0.22)  // ui-v4: allow modal scrim
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .onTapGesture { dismissExpandedQuickActionMenu() }

                    expandedQuickActionMenuPanel(for: target)
                        .padding(.horizontal, 6)
                        .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .bottom)))
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func expandedQuickActionMenuPanel(for target: ExpandedQuickActionMenuTarget) -> some View {
        switch target {
        case .pet(let item, let pet):
            let isSingleUseDone = ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil &&
                expandedPetQuickCompleted(item, pet: pet)
            let options = petQuickMenuOptions(for: item)
            ExpandedQuickActionMenuPanel(
                icon: WaterQuickActionPolicy.iconOverride(for: item, pet: pet) ?? item.icon,
                title: WaterQuickActionPolicy.titleOverride(for: item, pet: pet, managementLabel: waterManagementLabel) ?? item.label,
                status: expandedPetQuickCountText(item, pet: pet) ?? l.tr(zh: "选择下一步", en: "Choose next step", de: "Nächsten Schritt wählen"),
                accent: Color(hex: item.colorHex),
                isLocked: false,
                lockedText: nil,
                quickTitle: petQuickMenuPrimaryTitle(for: item, pet: pet, isSingleUseDone: isSingleUseDone),
                detailTitle: petQuickMenuDetailTitle(for: item),
                isQuickDisabled: isSingleUseDone,
                quickOptions: options,
                onQuick: {
                    dismissExpandedQuickActionMenu()
                    runPetQuickMenuPrimary(item, pet: pet)
                },
                onDetail: {
                    dismissExpandedQuickActionMenu()
                    handleExpandedQuickLongPress(item, pet: pet)
                },
                onOption: { optionId in
                    dismissExpandedQuickActionMenu()
                    runPetQuickMenuOption(optionId, item: item, pet: pet)
                },
                onClose: dismissExpandedQuickActionMenu
            )
        case .human(let item, let human):
            let locked = expandedHumanQuickActionIsPrivate(item, human: human)
            ExpandedQuickActionMenuPanel(
                icon: item.icon,
                title: item.label,
                status: locked
                    ? l.tr(zh: "仅本人可见", en: "Only visible to this member", de: "Nur für dieses Mitglied sichtbar")
                    : (expandedHumanQuickCountText(item, human: human) ?? l.tr(zh: "选择下一步", en: "Choose next step", de: "Nächsten Schritt wählen")),
                accent: Color(hex: item.colorHex),
                isLocked: locked,
                lockedText: l.tr(zh: "切换到该成员账户后才能查看或记录。", en: "Switch to this member account to view or record.", de: "Wechsle zu diesem Mitglied, um zu sehen oder zu erfassen."),
                quickTitle: humanQuickMenuPrimaryTitle(for: item),
                detailTitle: humanQuickMenuDetailTitle(for: item),
                isQuickDisabled: false,
                quickOptions: [],
                onQuick: {
                    dismissExpandedQuickActionMenu()
                    runHumanQuickMenuPrimary(item, human: human)
                },
                onDetail: {
                    dismissExpandedQuickActionMenu()
                    handleExpandedHumanQuickLongPress(item, human: human)
                },
                onOption: { _ in },
                onClose: dismissExpandedQuickActionMenu
            )
        }
    }

    private func petQuickMenuOptions(for item: QuickActionItem) -> [ExpandedQuickMenuOption] {
        switch item.actionType {
        case "groom":
            return [
                ExpandedQuickMenuOption(id: "bath", icon: "drop.fill", title: l.tr(zh: "洗澡", en: "Bath", de: "Bad"), tint: Color.goBlue),
                ExpandedQuickMenuOption(id: "teeth", icon: "mouth.fill", title: l.tr(zh: "刷牙", en: "Teeth", de: "Zähne"), tint: Color.goTeal),
                ExpandedQuickMenuOption(id: "nails", icon: "scissors", title: l.tr(zh: "剪甲", en: "Nails", de: "Krallen"), tint: Color.goPurple),
                ExpandedQuickMenuOption(id: "brushing", icon: "comb.fill", title: l.tr(zh: "梳毛", en: "Brush", de: "Bürsten"), tint: Color.goYellow),
                ExpandedQuickMenuOption(id: "ears", icon: "ear.fill", title: l.tr(zh: "清耳", en: "Ears", de: "Ohren"), tint: Color.goOrange)
            ]
        case "potty":
            return [
                ExpandedQuickMenuOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill", title: l.tr(zh: "完美", en: "Good", de: "Gut"), tint: Color(hex: "8B6914")),
                ExpandedQuickMenuOption(id: PottyType.softPoop.rawValue, icon: "circle.dashed", title: l.tr(zh: "软便", en: "Soft", de: "Weich"), tint: Color.goYellow),
                ExpandedQuickMenuOption(id: PottyType.liquidPoop.rawValue, icon: "exclamationmark.triangle.fill", title: l.tr(zh: "水便", en: "Loose", de: "Flüssig"), tint: Color.goRed),
                ExpandedQuickMenuOption(id: PottyType.pee.rawValue, icon: "drop.fill", title: l.tr(zh: "尿尿", en: "Pee", de: "Pipi"), tint: Color.goBlue)
            ]
        default:
            return []
        }
    }

    private func petQuickMenuPrimaryTitle(for item: QuickActionItem, pet: Pet, isSingleUseDone: Bool) -> String {
        if isSingleUseDone {
            return l.tr(zh: "今日已完成", en: "Done today", de: "Heute erledigt")
        }
        if !petQuickMenuOptions(for: item).isEmpty {
            return l.tr(zh: "选择类型", en: "Choose type", de: "Typ wählen")
        }
        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case .waterManagement:
            return l.tr(zh: "打开水管理", en: "Open water", de: "Wasser öffnen")
        case .health:
            return l.tr(zh: "打开健康", en: "Open health", de: "Gesundheit öffnen")
        case .weight, .expense, .moment:
            return l.tr(zh: "快速记录", en: "Quick record", de: "Schnell erfassen")
        case .perform(let actionType):
            return actionType == "walk"
                ? l.tr(zh: "开始遛狗", en: "Start walk", de: "Gassi starten")
                : l.tr(zh: "快速打卡", en: "Quick check-in", de: "Schnell abhaken")
        case .none:
            return l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
    }

    private func petQuickMenuDetailTitle(for item: QuickActionItem) -> String? {
        switch item.actionType {
        case "feed": return l.tr(zh: "查看粮食记录", en: "Feeding details", de: "Futterdetails")
        case "water", "waterChange", "filterClean": return l.tr(zh: "查看水管理", en: "Water details", de: "Wasserdetails")
        case "walk": return l.tr(zh: "查看遛狗", en: "Walk details", de: "Gassi-Details")
        case "play": return l.tr(zh: "查看陪玩", en: "Play details", de: "Spiel-Details")
        case "potty", "litter": return l.tr(zh: "查看便便管理", en: "Potty details", de: "Toiletten-Details")
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange": return l.tr(zh: "查看护理", en: "Care details", de: "Pflege-Details")
        case "health": return nil
        case "weight": return l.tr(zh: "查看体重", en: "Weight details", de: "Gewicht-Details")
        case "expense": return l.tr(zh: "查看花费", en: "Expense details", de: "Ausgaben-Details")
        case "moment": return l.tr(zh: "查看记录中心", en: "Moments hub", de: "Momente")
        default: return nil
        }
    }

    private func runPetQuickMenuPrimary(_ item: QuickActionItem, pet: Pet) {
        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case .waterManagement, .health, .none:
            handleExpandedQuickLongPress(item, pet: pet)
        default:
            handleExpandedQuickAction(item, pet: pet)
        }
    }

    private func runPetQuickMenuOption(_ optionId: String, item: QuickActionItem, pet: Pet) {
        switch item.actionType {
        case "groom":
            applyExpandedGroomCheckIn(optionId, pet: pet)
        case "potty":
            applyExpandedPottyCheckIn(optionId, pet: pet)
        default:
            break
        }
    }

    private func humanQuickMenuPrimaryTitle(for item: QuickActionItem) -> String {
        switch ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: false) {
        case .weightQuick, .workoutQuick, .medicationAdd, .noteQuick, .expenseQuick:
            return l.tr(zh: "快速记录", en: "Quick record", de: "Schnell erfassen")
        case .allFeatures:
            return l.tr(zh: "打开全部功能", en: "Open all", de: "Alles öffnen")
        default:
            return l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
    }

    private func humanQuickMenuDetailTitle(for item: QuickActionItem) -> String? {
        switch item.actionType {
        case "humanWeight": return l.tr(zh: "查看体重", en: "Weight history", de: "Gewicht")
        case "humanWorkout": return l.tr(zh: "查看运动", en: "Workout history", de: "Training")
        case "humanMedication": return l.tr(zh: "查看用药", en: "Medication", de: "Medikation")
        case "humanNote": return l.tr(zh: "查看备注", en: "Notes", de: "Notizen")
        case "humanExpense": return l.tr(zh: "查看花费", en: "Expenses", de: "Ausgaben")
        default: return nil
        }
    }

    private func runHumanQuickMenuPrimary(_ item: QuickActionItem, human: Human) {
        handleExpandedHumanQuickAction(item, human: human)
    }

    private func expandedWalletOffsetY(idx: Int, n: Int, bottomY: CGFloat,
                                       heroId: UUID?, heroTopY: CGFloat, cards: [FocusCard]) -> CGFloat {
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        if idx == heroIdx { return heroTopY }
        let cr = idx < heroIdx ? idx : idx - 1
        let inactiveCount = max(1, n - 1)
        return bottomY - K.cardH - CGFloat(inactiveCount - 1 - cr) * K.expandedInactiveStackPeekH
    }

    @ViewBuilder
    private func walletCardStack(cards: [FocusCard]) -> some View {
        let displayCards = homeCardDisplayCards(from: cards)
        let n = displayCards.count
        let heroId = activeCardId ?? displayCards.first?.id

        GeometryReader { geo in
            // Anchor the stack to the real screen bottom, then convert that
            // global target back into this lower-page GeometryReader's space.
            // This reader starts below the focus module, so using only
            // geo.size.height can push the front card below the visible screen.
            let bottomInset = max(safeAreaBottom, geo.safeAreaInsets.bottom)
            let collapsedBottomY = collapsedStackBottomY(in: geo, bottomInset: bottomInset)
            let expandedBottomY = expandedStackBottomY(in: geo, bottomInset: bottomInset)
            let heroTopY = safeAreaTop + K.expandedCardGlobalTopOffset - geo.frame(in: .global).minY

            ZStack(alignment: .topLeading) {
                ForEach(Array(displayCards.enumerated()), id: \.element.id) { idx, card in
                    let isHero = isExpanded && card.id == heroId
                    let visibleHeight = isHero ? K.expandedCardH : K.cardH
                    let offsetY = isExpanded
                    ? walletOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: expandedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                        cards: displayCards
                    )
                    : walletOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: collapsedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                        cards: displayCards
                    )

                    walletCardStackItem(
                        card: card,
                        idx: idx,
                        n: n,
                        isHero: isHero,
                        visibleHeight: visibleHeight,
                        offsetY: offsetY,
                        collapsedBottomY: collapsedBottomY,
                        heroId: heroId,
                        cards: displayCards
                    )
                }

                if isExpanded,
                   expandedQuickModulesReady,
                   let activeCard = displayCards.first(where: { $0.id == heroId }) {
                    expandedQuickModules(card: activeCard)
                        .frame(width: geo.size.width, height: expandedQuickModuleHeight(for: activeCard))
                        .offset(y: heroTopY + K.expandedCardH + 14)
                        .zIndex(Double(n + 80))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .simultaneousGesture(collapseWalletDragGesture())
                        .animation(walletAnimation, value: activeCardId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .animation(walletAnimation, value: isExpanded)
            .animation(walletAnimation, value: activeCardId)
            // Swipe-down anywhere collapses hero back to fan
            .gesture(
                DragGesture()
                    .onEnded { v in
                        guard isExpanded, v.translation.height > 80 else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(walletAnimation) { isExpanded = false }
                    }
            )
            .onAppear {
                if activeCardId == nil || !displayCards.contains(where: { $0.id == activeCardId }) {
                    activeCardId = displayCards.first?.id
                }
            }
            .onChange(of: displayCards.map(\.id)) { _, ids in
                if let dragging = homeCardReorderDragId, !ids.contains(dragging) {
                    resetHomeCardReorderState()
                } else if let candidate = homeCardPressCandidateId, !ids.contains(candidate) {
                    cancelHomeCardPressCandidate()
                }
                if let pendingPromotedHomeCardId,
                   ids.contains(pendingPromotedHomeCardId) {
                    activeCardId = pendingPromotedHomeCardId
                    self.pendingPromotedHomeCardId = nil
                    return
                }
                guard activeCardId == nil || !ids.contains(activeCardId!) else { return }
                activeCardId = ids.first
            }
        }
    }

    @ViewBuilder
    private func collapsedWalletCards(
        cards: [FocusCard],
        n: Int,
        heroId: UUID?,
        bottomY: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                walletCardStackItem(
                    card: card,
                    idx: idx,
                    n: n,
                    isHero: false,
                    visibleHeight: K.cardH,
                    offsetY: walletOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: bottomY,
                        heroId: heroId,
                        heroTopY: 0,
                        cards: cards
                    ),
                    collapsedBottomY: bottomY,
                    heroId: heroId,
                    cards: cards
                )
            }
        }
    }

    private func collapsedStackBottomY(in geo: GeometryProxy, bottomInset: CGFloat) -> CGFloat {
        // Fixed screen anchor: the front card's bottom edge always lands above
        // the device bottom safe area. Adding cards only changes the stack's
        // top edge, never the existing lower-card positions.
        let globalBottomY = ScreenCompat.bounds.height - bottomInset - K.collapsedStackBottomGap
        let localBottomY = globalBottomY - geo.frame(in: .global).minY
        return max(K.cardH, localBottomY)
    }

    private func expandedStackBottomY(in geo: GeometryProxy, bottomInset: CGFloat) -> CGFloat {
        let globalBottomY = ScreenCompat.bounds.height + K.cardH - K.expandedInactiveFrontPeekH
        let localBottomY = globalBottomY - geo.frame(in: .global).minY
        return max(K.stackPeekH, localBottomY)
    }

    private func homeCardCollapsedInteractionGesture(
        card: FocusCard,
        cards: [FocusCard],
        currentOffsetY: CGFloat,
        collapsedBottomY: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { drag in
                guard homeCardReorderEnabled, !isExpanded else { return }
                guard homeCardReorderDragId == card.id else { return }

                updateHomeCardReorder(
                    cardId: card.id,
                    cards: cards,
                    dragTranslationY: drag.translation.height,
                    collapsedBottomY: collapsedBottomY
                )
            }
            .onEnded { drag in
                guard homeCardReorderEnabled else { return }
                guard !isExpanded else {
                    if homeCardReorderDragId == card.id || homeCardPressCandidateId == card.id || homeCardReorderCards != nil || homeCardReorderModeActive {
                        resetHomeCardReorderState()
                    }
                    return
                }
                guard homeCardReorderDragId == card.id else { return }
                updateHomeCardReorder(
                    cardId: card.id,
                    cards: cards,
                    dragTranslationY: drag.translation.height,
                    collapsedBottomY: collapsedBottomY
                )
                commitHomeCardReorder()
                resetHomeCardReorderState()
            }
    }

    private func homeCardDragDistance(_ translation: CGSize) -> CGFloat {
        max(abs(translation.width), abs(translation.height))
    }

    private func updateHomeCardReorder(
        cardId: UUID,
        cards: [FocusCard],
        dragTranslationY: CGFloat,
        collapsedBottomY: CGFloat
    ) {
        var workingCards = homeCardReorderCards ?? cards
        guard let currentIndex = workingCards.firstIndex(where: { $0.id == cardId }) else { return }

        let draggedTopY = homeCardReorderStartOffsetY + homeCardReorderLiftY + dragTranslationY
        var targetIndex = currentIndex

        while targetIndex > 0 {
            let previousTopY = walletOffsetY(
                idx: targetIndex - 1,
                n: workingCards.count,
                bottomY: collapsedBottomY,
                heroId: nil,
                heroTopY: 0,
                cards: workingCards
            )
            guard draggedTopY < previousTopY else { break }
            targetIndex -= 1
        }

        while targetIndex < workingCards.count - 1 {
            let nextTopY = walletOffsetY(
                idx: targetIndex + 1,
                n: workingCards.count,
                bottomY: collapsedBottomY,
                heroId: nil,
                heroTopY: 0,
                cards: workingCards
            )
            guard draggedTopY > nextTopY else { break }
            targetIndex += 1
        }

        if targetIndex != currentIndex {
            let movedCard = workingCards.remove(at: currentIndex)
            workingCards.insert(movedCard, at: targetIndex)
            withAnimation(walletAnimation) {
                homeCardReorderCards = workingCards
            }
            homeCardReorderDidMove = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        let currentSlotTopY = walletOffsetY(
            idx: targetIndex,
            n: workingCards.count,
            bottomY: collapsedBottomY,
            heroId: nil,
            heroTopY: 0,
            cards: workingCards
        )
        var dragTransaction = Transaction(animation: .linear(duration: 0.045))
        dragTransaction.disablesAnimations = false
        withTransaction(dragTransaction) {
            homeCardReorderDragOffset = draggedTopY - currentSlotTopY
        }
    }

    private func commitHomeCardReorder() {
        guard let reorderedCards = homeCardReorderCards else { return }
        saveHomeCardOrder(reorderedCards)
    }

    private func resetHomeCardReorderState() {
        let didReorder = homeCardReorderDidMove
        homeCardReorderSession += 1
        homeCardPressCandidateId = nil
        homeCardReorderDragId = nil
        homeCardReorderDragOffset = 0
        homeCardReorderStartOffsetY = 0
        homeCardReorderCards = nil
        homeCardReorderDidMove = false
        homeCardReorderModeActive = false
        suppressNextHomeCardTap = false
        if didReorder {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    private func enterHomeCardReorderMode() {
        guard homeCardReorderEnabled, !isExpanded, visibleHomeCards.count > 1 else { return }
        guard !homeCardReorderModeActive else { return }
        withAnimation(GoMotion.feedback) {
            homeCardReorderModeActive = true
            fabExpanded = false
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func beginHomeCardPressCandidate(card: FocusCard, cards: [FocusCard], currentOffsetY: CGFloat) {
        guard cards.count > 1 else { return }
        homeCardReorderSession += 1
        let session = homeCardReorderSession
        homeCardPressCandidateId = card.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard homeCardReorderSession == session,
                  homeCardPressCandidateId == card.id,
                  homeCardReorderDragId == nil,
                  !isExpanded else { return }
            homeCardPressCandidateId = nil
            enterHomeCardReorderMode()
            beginHomeCardReorder(card: card, cards: cards, currentOffsetY: currentOffsetY)
        }
    }

    private func cancelHomeCardPressCandidate() {
        guard homeCardPressCandidateId != nil else { return }
        homeCardReorderSession += 1
        homeCardPressCandidateId = nil
    }

    private func beginHomeCardReorder(card: FocusCard, cards: [FocusCard], currentOffsetY: CGFloat) {
        guard homeCardReorderDragId == nil else { return }
        homeCardReorderDragId = card.id
        homeCardReorderStartOffsetY = currentOffsetY
        homeCardReorderCards = cards
        homeCardReorderDidMove = false
        homeCardReorderSession += 1
        let session = homeCardReorderSession
        withAnimation(walletAnimation) {
            homeCardReorderDragOffset = homeCardReorderLiftY
        }
        fabExpanded = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scheduleHomeCardReorderWatchdog(cardId: card.id, session: session)
    }

    private func scheduleHomeCardReorderWatchdog(cardId: UUID, session: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard homeCardReorderSession == session,
                  homeCardReorderDragId == cardId else { return }
            resetHomeCardReorderState()
        }
    }

    private func startHomeCardReorderFromLongPress(
        card: FocusCard,
        cards: [FocusCard],
        currentOffsetY: CGFloat
    ) {
        guard homeCardReorderEnabled, !isExpanded, cards.count > 1 else { return }
        guard homeCardReorderDragId == nil, !homeCardReorderModeActive else { return }
        suppressNextHomeCardTap = true
        enterHomeCardReorderMode()
        beginHomeCardReorder(card: card, cards: cards, currentOffsetY: currentOffsetY)
    }

    private func walletCardStackItem(
        card: FocusCard,
        idx: Int,
        n: Int,
        isHero: Bool,
        visibleHeight: CGFloat,
        offsetY: CGFloat,
        collapsedBottomY: CGFloat,
        heroId: UUID?,
        cards: [FocusCard]
    ) -> some View {
        let isReorderingCard = homeCardReorderDragId == card.id
        let isInteractiveWalkCard = isWalkTrackingCard(card: card, isHero: isHero)

        return transformedWalletCard(card: card, isHero: isHero)
            .frame(height: isHero ? K.expandedCardH : K.cardH)
            .frame(height: visibleHeight, alignment: .top)
            .clipped()
            .frame(maxWidth: .infinity)
            .overlay { expandedActionPulseOverlay(for: card.id) }
            .overlay { walkTransformBurstOverlay(for: card.id) }
            .shadow(
                color: .black.opacity(isHero ? 0.22 : (isReorderingCard ? 0.16 : 0.09)),
                radius: isHero ? 20 : (isReorderingCard ? 13 : 7),
                x: 0, y: isHero ? 12 : (isReorderingCard ? 8 : 4)
            )
            .scaleEffect(
                (isHero ? 1.0 : (isExpanded ? 0.97 : 1.0)) *
                (isReorderingCard ? 1.015 : 1.0) *
                (expandedActionPulseCardId == card.id ? 1.025 : 1.0),
                anchor: .top
            )
            .offset(y: offsetY + (isReorderingCard ? homeCardReorderDragOffset : 0))
            .zIndex(isReorderingCard ? Double(n + 120) : walletZIndex(idx: idx, n: n, isHero: isHero, heroId: heroId, cards: cards))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name) 的卡片")
            .accessibilityHint(isHero ? "点击返回首页，长按进入基本信息" :
                              (isExpanded ? "点击返回首页" :
                                (homeCardReorderModeActive ? "拖动调整排序，点击退出排序" : "点击展开查看，长按进入排序")))
            .if(isExpanded && !isHero && homeCardReorderDragId == nil) { view in
                view.contextMenu { cardContextMenu(card: card) }
            }
            .if(isExpanded && !isInteractiveWalkCard) { view in
                view.highPriorityGesture(
                    TapGesture()
                        .onEnded { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                )
            }
            .if(!isExpanded && !isInteractiveWalkCard) { view in
                view.highPriorityGesture(
                    TapGesture()
                        .onEnded { handleWalletCardTap(card: card, n: n, isHero: false) }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in
                            startHomeCardReorderFromLongPress(
                                card: card,
                                cards: cards,
                                currentOffsetY: offsetY
                            )
                        }
                )
                .simultaneousGesture(
                    homeCardCollapsedInteractionGesture(
                        card: card,
                        cards: cards,
                        currentOffsetY: offsetY,
                        collapsedBottomY: collapsedBottomY
                    )
                )
            }
            .if(isHero && isExpanded && !isInteractiveWalkCard) { view in
                view.onLongPressGesture(minimumDuration: 0.45) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    openWalletCardBasicInfo(card)
                }
            }
            .animation(walletAnimation, value: isExpanded)
            .animation(walletAnimation, value: activeCardId)
            .animation(walletAnimation, value: homeCardReorderDragId)
    }

    // Total height of the default fan stack (used to anchor it at the bottom of bottomY).
    // Keep the peek fixed so every covered card's top identity strip remains visible.
    // If the stack is taller than the wallet area, the whole stack becomes scrollable.
    private func fanHeight(n: Int, bottomY: CGFloat) -> CGFloat {
        CGFloat(max(0, n - 1)) * stackPeek(n: n, bottomY: bottomY) + K.cardH
    }

    private func stackPeek(n: Int, bottomY: CGFloat) -> CGFloat {
        guard n > 1 else { return 0 }
        return K.collapsedStackPeekH
    }

    // Fan  — cards anchored at container bottom, fanning upward.
    //   idx=0 is the backmost (topmost in fan), idx=n-1 is frontmost (at very bottom).
    //   y_i = bottomY − cardH − (n−1−i) × stackPeek
    //
    // Hero — hero card snaps just below the coconut/check-in buttons.
    //   Non-hero cards form a tighter version of the home card stack.
    //   compressedRank r = (idx < heroIdx ? idx : idx−1)
    //   y = bottomY − cardH − (inactiveCount−1−r) × expandedInactiveStackPeekH
    private func walletOffsetY(idx: Int, n: Int, bottomY: CGFloat,
                               heroId: UUID?, heroTopY: CGFloat, cards: [FocusCard]) -> CGFloat {
        if !isExpanded {
            return bottomY - K.cardH - CGFloat(n - 1 - idx) * stackPeek(n: n, bottomY: bottomY)
        }
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        if idx == heroIdx { return heroTopY }
        let cr = idx < heroIdx ? idx : idx - 1
        let inactiveCount = max(1, n - 1)
        return bottomY - K.cardH - CGFloat(inactiveCount - 1 - cr) * K.expandedInactiveStackPeekH
    }

    // Fan: higher idx = higher z (frontmost).
    // Hero: hero = n+100; compressed cards keep original relative z-order.
    private func walletZIndex(idx: Int, n: Int, isHero: Bool,
                              heroId: UUID?, cards: [FocusCard]) -> Double {
        if isHero { return Double(n + 100) }
        if !isExpanded { return Double(idx) }
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        let cr = idx < heroIdx ? idx : idx - 1
        return Double(cr)
    }

    // Fan:  tap any card → lift that card to the active position.
    // Hero: tap active card → restore fan; long-press active card → basic info.
    //       Tap any inactive card strip → restore fan.
    //       Swipe-down → restore fan (via DragGesture above).
    private func handleWalletCardTap(card: FocusCard, n: Int, isHero: Bool) {
        let tapStartedAt = CFAbsoluteTimeGetCurrent()

        if homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
            resetHomeCardReorderState()
            return
        }

        if suppressNextHomeCardTap {
            suppressNextHomeCardTap = false
            return
        }

        triggerWalletTapFeedback()

        if n <= 1 {
            if isExpanded {
                collapseWalletToHome()
            } else {
                withAnimation(walletAnimation) {
                    activeCardId = card.id
                    isExpanded = true
                }
            }
            DispatchQueue.main.async {
                AppPerformanceMonitor.shared.record("卡片展开状态提交", startedAt: tapStartedAt, note: card.name)
                AppPerformanceMonitor.shared.record("卡片点击延迟", startedAt: tapStartedAt, note: card.name)
            }
            return
        }

        if isHero {
            collapseWalletToHome()
        } else if isExpanded {
            collapseWalletToHome()
        } else {
            withAnimation(walletAnimation) {
                activeCardId = card.id
                isExpanded = true
            }
        }
        DispatchQueue.main.async {
            AppPerformanceMonitor.shared.record("卡片展开状态提交", startedAt: tapStartedAt, note: card.name)
            AppPerformanceMonitor.shared.record("卡片点击延迟", startedAt: tapStartedAt, note: card.name)
        }
    }

    private func triggerWalletTapFeedback() {
        walletTapFeedbackGenerator.impactOccurred()
        walletTapFeedbackGenerator.prepare()
    }

    private func collapseWalletToHome() {
        if homeCardReorderDragId != nil || homeCardReorderCards != nil || homeCardReorderModeActive {
            resetHomeCardReorderState()
        }
        expandedQuickModulesReady = false
        withAnimation(walletAnimation) {
            isExpanded = false
            fabExpanded = false
            isExpandedQAEditMode = false
        }
        if let rosterPreviewCard, activeCardId == rosterPreviewCard.id {
            activeCardId = visibleHomeCards.first(where: { $0.id != rosterPreviewCard.id })?.id
        }
        rosterPreviewCard = nil
    }

    private func openCrewRosterCard(_ card: FocusCard) {
        showingCrewRoster = false
        fabExpanded = false
        isExpandedQAEditMode = false

        if visibleHomeCards.contains(where: { $0.id == card.id }) {
            rosterPreviewCard = nil
        } else {
            rosterPreviewCard = card
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(walletAnimation) {
                activeCardId = card.id
                isExpanded = true
            }
        }
    }

    private func openWalletCardBasicInfo(_ card: FocusCard) {
        fabExpanded = false
        isExpandedQAEditMode = false
        withAnimation(walletAnimation) {
            isExpanded = false
        }

        if card.isHuman {
            expandedBasicInfoHuman = humans.first(where: { $0.id == card.id })
            return
        }

        if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            expandedBasicInfoPet = pet
        }
    }

    @ViewBuilder
    private func transformedWalletCard(card: FocusCard, isHero: Bool) -> some View {
        let showWalkCard = isWalkTrackingCard(card: card, isHero: isHero)
        ZStack {
            FocusWalletCardView(
                card: card,
                namespace: ns,
                heroNS: heroNS,
                expandedId: expandedId,
                isHeroExpanded: isHero,
                avatarCacheRevision: avatarCacheRevision
            )
            .opacity(showWalkCard ? 0 : 1)

            if showWalkCard, let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
                WalkTrackingCard(pet: pet)
                    .padding(10)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(HeroAnim.walletSpring, value: showWalkCard)
    }

    private func isWalkTrackingCard(card: FocusCard, isHero: Bool) -> Bool {
        guard isHero,
              !card.isHuman,
              PetWalkingManager.shared.currentPet?.id == card.id
        else { return false }

        switch PetWalkingManager.shared.phase {
        case .running, .paused, .finished:
            return true
        case .idle:
            return false
        }
    }

    @ViewBuilder
    private func expandedActionPulseOverlay(for cardId: UUID) -> some View {
        if expandedActionPulseCardId == cardId {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .strokeBorder(Color.goLime.opacity(0.88), lineWidth: 2)
                .shadow(color: Color.goLime.opacity(0.45), radius: 18, y: 0)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
        }
    }

    @ViewBuilder
    private func walkTransformBurstOverlay(for cardId: UUID) -> some View {
        if walkTransformBurstCardId == cardId {
            WalkLaunchBurst()
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func triggerExpandedActionFeedback(cardId: UUID, coconutDelta: Int = 0, label: String? = nil) {
        withAnimation(HeroAnim.buttonSpring) {
            expandedActionPulseCardId = cardId
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
            }
        }
    }

    private func prepareFirstSuccessPet(_ pet: Pet) {
        withAnimation(walletAnimation) {
            activeCardId = pet.id
            isExpanded = true
        }
    }

    private func completeFirstSuccessFeed(for pet: Pet) {
        prepareFirstSuccessPet(pet)
        applyExpandedQuickAction("feed", pet: pet)
    }

    private func completeFirstSuccessPlay(for pet: Pet) {
        prepareFirstSuccessPet(pet)
        applyExpandedQuickAction("play", pet: pet)
    }

    private func startFirstSuccessMoment(for pet: Pet) {
        prepareFirstSuccessPet(pet)
        pendingFirstSuccessMomentPetId = pet.id
        firstSuccessMomentCoconutBefore = QuestManager.shared.coconutCount
        expandedQuickMomentPet = pet
    }

    private func completeFirstSuccessMomentIfNeeded(for pet: Pet) {
        guard pendingFirstSuccessMomentPetId == pet.id else { return }
        let before = firstSuccessMomentCoconutBefore ?? QuestManager.shared.coconutCount
        let coconutDelta = max(0, QuestManager.shared.coconutCount - before)
        pendingFirstSuccessMomentPetId = nil
        firstSuccessMomentCoconutBefore = nil
        triggerExpandedActionFeedback(
            cardId: pet.id,
            coconutDelta: coconutDelta,
            label: coconutDelta > 0 ? "照片记录 +\(coconutDelta)🥥" : nil
        )
        markFirstQuickCheckInCompletedIfNeeded()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func markFirstQuickCheckInCompletedIfNeeded() {
        guard showFirstSuccessCard, !firstQuickCheckInCompleted else { return }
        firstQuickCheckInCompleted = true
        withAnimation(HeroAnim.buttonSpring) {
            showFirstSuccessCard = false
        }
    }

    private func triggerWalkCardTransform(for pet: Pet) {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = true
        withAnimation(walletAnimation) {
            activeCardId = pet.id
            isExpanded = true
        }
        withAnimation(HeroAnim.fabSpring) {
            walkTransformBurstCardId = pet.id
            expandedActionPulseCardId = pet.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard walkTransformBurstCardId == pet.id else { return }
            withAnimation(GoMotion.quick) {
                walkTransformBurstCardId = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            guard expandedActionPulseCardId == pet.id else { return }
            withAnimation(GoMotion.quick) {
                expandedActionPulseCardId = nil
            }
        }
    }

    private func syncWalkCardSurfaceVisibility() {
        PetWalkingManager.shared.isWalkCardExpandedSurfaceVisible = isWalkCardExpandedSurfaceVisible
    }

    private var savedQuickActionItems: [QuickActionItem] {
        guard !quickActionItemsJSON.isEmpty,
              let data = quickActionItemsJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return [] }
        return items
    }

    private func expandedQuickActionItems(for pet: Pet) -> [QuickActionItem] {
        let stored = savedQuickActionItems.filter { $0.petId == pet.id && $0.entityKind != .human }
        let items = (stored.isEmpty ? defaultExpandedQuickActions(for: pet) : stored)
            .filter { $0.actionType != "litterChange" }
        return WaterQuickActionPolicy.normalizedItems(
            items,
            for: pet,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
    }

    private func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        let stored = savedQuickActionItems.filter { $0.entityId == human.id && $0.entityKind == .human }
        return stored.isEmpty ? defaultExpandedHumanQuickActions(for: human) : stored
    }

    private func enterExpandedQAEditMode(for pet: Pet) {
        expandedQAEditItems = expandedQuickActionItems(for: pet)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) {
                expandedQAJiggle = true
            }
        }
    }

    private func exitExpandedQAEditMode(for pet: Pet) {
        saveExpandedQAEditItems(expandedQAEditItems, for: pet)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = false
        }
        withAnimation(nil) {
            expandedQAJiggle = false
        }
    }

    private func saveExpandedQAEditItems(_ edited: [QuickActionItem], for pet: Pet) {
        var saved = savedQuickActionItems
        let currentPetItemIds = Set(expandedQuickActionItems(for: pet).map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentPetItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { $0.petId == pet.id && $0.entityKind != .human }
        let cleaned = edited.filter { $0.actionType != "litterChange" }
        saved.insert(contentsOf: Array(cleaned.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func enterExpandedHumanQAEditMode(for human: Human) {
        expandedQAEditItems = expandedHumanQuickActionItems(for: human)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) {
                expandedQAJiggle = true
            }
        }
    }

    private func exitExpandedHumanQAEditMode(for human: Human) {
        saveExpandedHumanQAEditItems(expandedQAEditItems, for: human)
        expandedQADraggingItemId = nil
        withAnimation(HeroAnim.buttonSpring) {
            isExpandedQAEditMode = false
        }
        withAnimation(nil) {
            expandedQAJiggle = false
        }
    }

    private func saveExpandedHumanQAEditItems(_ edited: [QuickActionItem], for human: Human) {
        var saved = savedQuickActionItems
        let currentItemIds = Set(expandedHumanQuickActionItems(for: human).map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { $0.entityId == human.id && $0.entityKind == .human }
        saved.insert(contentsOf: Array(edited.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func defaultExpandedQuickActions(for pet: Pet) -> [QuickActionItem] {
        ExpandedQuickActionDefaults.items(
            for: pet,
            localization: l,
            waterManagementLabel: waterManagementLabel
        )
    }

    private func defaultExpandedHumanQuickActions(for human: Human) -> [QuickActionItem] {
        [
            QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA",
                            actionType: "humanWeight", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.expense, icon: "creditcard.fill", colorHex: "F59E0B",
                            actionType: "humanExpense", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A",
                            actionType: "humanMedication", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQASport, icon: "figure.run", colorHex: "F97316",
                            actionType: "humanWorkout", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQANote, icon: "note.text", colorHex: "A78BFA",
                            actionType: "humanNote", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "square.grid.2x2.fill", colorHex: "64748B",
                            actionType: "humanAllFeatures", entityId: human.id, entityKind: .human),
        ]
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
        switch route {
        case .privacyAlert:
            showingHumanPrivacyAlert = true
        case .weightQuick:
            openExpandedQuickHumanWeight(for: human)
        case .workoutQuick:
            expandedQuickHumanWorkout = human
        case .medicationAdd:
            expandedQuickHumanMedicationAdd = human
        case .noteQuick:
            expandedQuickHumanNote = human
        case .expenseQuick:
            expandedQuickHumanExpense = human
        case .weightDetail:
            expandedHumanWeightDetail = human
        case .workoutDetail:
            expandedHumanWorkoutDetail = human
        case .medicationDetail:
            expandedQuickHumanMedication = human
        case .noteDetail:
            expandedHumanNoteDetail = human
        case .expenseDetail:
            expandedHumanExpenseDetail = human
        case .allFeatures:
            expandedAllFeaturesHuman = human
        case .selectHuman:
            selectedHuman = human
        case .none:
            break
        }
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
        switch route {
        case .perform(let actionType):
            applyExpandedQuickAction(actionType, pet: pet)
        case .waterManagement:
            openExpandedWaterManagement(for: pet)
        case .weight:
            openExpandedQuickWeight(for: pet)
        case .expense:
            openExpandedQuickExpense(for: pet)
        case .moment:
            expandedQuickMomentPet = pet
        case .health:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
        case .none:
            break
        }
    }

    private func openExpandedFeedDetail(for pet: Pet, opensManualSheet: Bool = false) {
        expandedQuickFeedOpensManualSheet = opensManualSheet
        expandedQuickFeedDetailPet = pet
    }

    private func handleExpandedQuickLongPress(_ item: QuickActionItem, pet: Pet) {
        switch ExpandedQuickActionLogic.petLongPressRoute(for: item) {
        case .feedDetail:
            openExpandedFeedDetail(for: pet)
        case .waterManagement:
            openExpandedWaterManagement(for: pet)
        case .walk:
            expandedQuickWalkPet = pet
        case .playDetail:
            expandedQuickPlayDetailPet = pet
        case .pottyDetail:
            expandedQuickPottyDetailPet = pet
        case .hygiene:
            expandedQuickHygienePet = pet
        case .health:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
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

    private func performExpandedFeedCheckIn(pet: Pet, executorId: String?) {
        let performFeed = {
            let dashboard = self.expandedFeedDashboard(for: pet)
            switch dashboard.operatingMode {
            case .manual:
                let amount = pet.dailyPortionGrams
                guard amount > 0 else {
                    self.openExpandedFeedDetail(for: pet, opensManualSheet: true)
                    return
                }
                let coconutBefore = QuestManager.shared.coconutCount
                _ = CareEventService.recordManualFeed(
                    pet: pet,
                    amountGrams: amount,
                    context: self.modelContext,
                    executorId: executorId,
                    foodKind: pet.mainFoodKind
                )
                let coconutDelta = max(0, QuestManager.shared.coconutCount - coconutBefore)
                self.triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: coconutDelta, label: coconutDelta > 0 ? "喂食 +\(coconutDelta)🥥" : nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .manualReminder:
                if self.completeExpandedPlannedFeedFromHome(pet: pet) { return }
                self.openExpandedFeedDetail(for: pet)
            case .autoFeeder:
                self.openExpandedFeedDetail(for: pet)
                return
            }
        }

        let dashboard = expandedFeedDashboard(for: pet)
        let willWriteFeedLog = (dashboard.operatingMode == .manual && pet.dailyPortionGrams > 0) ||
            (dashboard.operatingMode == .manualReminder && dashboard.nextManualReminder != nil)
        if willWriteFeedLog, let warning = AntiRepeatCareManager.checkRecentCareLog(
            for: pet,
            type: .feeding,
            thresholdMinutes: 120,
            currentUserId: executorId,
            in: humans
        ) {
            antiRepeatTitle = l.homeAntiDupFeedTitle
            antiRepeatMessage = l.homeAntiDupFeedMessage(
                executor: warning.executorName,
                minutes: warning.minutesAgo,
                petName: pet.name
            )
            pendingRepeatAction = performFeed
            showingAntiRepeatAlert = true
        } else {
            performFeed()
        }
    }

    private func expandedFeedDashboard(for pet: Pet) -> FeedingDashboardState {
        ExpandedQuickActionLogic.feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: quickActionClockTick)
    }

    private func expandedWaterRuleState(for pet: Pet) -> WaterRuleState {
        ExpandedQuickActionLogic.waterRuleState(for: pet, allEvents: allEvents)
    }

    private func expandedDefaultWaterAmountMl(for pet: Pet) -> Double? {
        ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet)
    }

    private func completeExpandedPlannedWaterFromHome(pet: Pet) -> Bool {
        let state = expandedWaterRuleState(for: pet)
        guard let reminder = state.nextPendingReminder else { return false }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let reward = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: expandedDefaultWaterAmountMl(for: pet) ?? 0,
            context: modelContext,
            executorId: executorId
        )
        let delta = (reward?.humanGot ?? 0) + (reward?.petGot ?? 0)
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func performExpandedWaterCheckIn(pet: Pet, executorId: String?) {
        guard !WaterQuickActionPolicy.isAquatic(species: pet.species) else {
            openExpandedWaterManagement(for: pet)
            return
        }

        let state = expandedWaterRuleState(for: pet)
        if state.operatingMode == .reminder {
            if completeExpandedPlannedWaterFromHome(pet: pet) { return }
            openExpandedWaterManagement(for: pet)
            return
        }

        let got = CareEventService.recordCare(
            pet: pet,
            type: .watering,
            amountMl: expandedDefaultWaterAmountMl(for: pet) ?? 0,
            context: modelContext,
            executorId: executorId,
            reward: .water
        )
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyExpandedQuickAction(_ actionType: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }

        switch actionType {
        case "feed":
            performExpandedFeedCheckIn(pet: pet, executorId: executorId)
        case "water":
            performExpandedWaterCheckIn(pet: pet, executorId: executorId)
        case "walk":
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
            }
            triggerWalkCardTransform(for: pet)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "litter":
            let got = CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: executorId, reward: .potty(isLitter: true))
            let delta = got.humanGot + got.petGot
            triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "铲屎 +\(delta)🥥" : nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "play":
            performExpandedSpecialCare(.play, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "waterChange", "filterClean":
            openExpandedWaterManagement(for: pet)
        case "cageCleaning":
            performExpandedSpecialCare(.cageCleaning, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "freeFlight":
            performExpandedSpecialCare(.freeFlight, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "misting":
            performExpandedSpecialCare(.misting, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "substrateChange":
            performExpandedSpecialCare(.substrateChange, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            break
        }
    }

    private func applyExpandedGroomCheckIn(_ raw: String, pet: Pet) {
        let type: HygieneType
        switch raw {
        case "bath": type = .bath
        case "teeth": type = .teeth
        case "nails": type = .nails
        case "brushing": type = .brushing
        case "ears": type = .ears
        default: return
        }
        guard !pet.hygieneLogs.contains(where: { $0.type == type.rawValue && Calendar.current.isDateInToday($0.date) }) else {
            singleUseNoticeTitle = "今天已经完成了"
            singleUseNoticeMessage = "\(pet.name) 今天已经记录过\(type.rawValue)了，这类护理一天记录一次就够了。"
            showingSingleUseNotice = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet, executorId: executorId)
        modelContext.insert(log)
        modelContext.safeSave()
        let got = QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
        QuickActionReminderCompletionSyncService.completeNearestPetHygieneReminder(
            pet: pet,
            type: type,
            context: modelContext,
            executorId: executorId
        )
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyExpandedPottyCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let type = PottyType(rawValue: raw) ?? .perfectPoop
        let got = CareEventService.recordPotty(pet: pet, type: type, context: modelContext, executorId: executorId)
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyExpandedHealthCheckIn(_ raw: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        switch raw {
        case "vaccine":
            modelContext.insert(PetHealthLog(date: Date(), type: .vaccine, note: "快捷打卡", pet: pet, executorId: executorId))
        case "deworming":
            modelContext.insert(PetHealthLog(date: Date(), type: .dewormingExternal, note: "快捷打卡", pet: pet, executorId: executorId))
        case "visit":
            modelContext.insert(PetHealthLog(date: Date(), type: .checkup, note: "快捷打卡", pet: pet, executorId: executorId))
        default:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
            return
        }
        modelContext.safeSave()
        let reward = QuestManager.shared.awardAction(type: .health, pet: pet, context: modelContext)
        let delta = reward.humanGot + reward.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "💉 +\(delta)🥥" : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var waterManagementLabel: String {
        l.tr(zh: "水管理", en: "Water", de: "Wasser")
    }

    private func openExpandedWaterManagement(for pet: Pet) {
        expandedQuickWaterDetailPet = pet
    }

    private func expandedHumanQuickCompleted(_ item: QuickActionItem, human: Human) -> Bool {
        let humanId = human.id.uuidString
        return ExpandedQuickActionLogic.humanCompleted(
            item: item,
            human: human,
            isLocked: expandedHumanQuickActionIsPrivate(item, human: human),
            todayMedicationLogs: fetchTodayMedicationLogs(for: humanId)
        )
    }

    private func expandedHumanQuickCountText(_ item: QuickActionItem, human: Human) -> String? {
        let humanId = human.id.uuidString
        return ExpandedQuickActionLogic.humanCountText(
            item: item,
            human: human,
            isLocked: expandedHumanQuickActionIsPrivate(item, human: human),
            activeMedications: fetchActiveMedications(for: humanId),
            todayMedicationLogs: fetchTodayMedicationLogs(for: humanId),
            expenses: item.actionType == "humanExpense" ? fetchRecentHumanExpenses(for: humanId) : []
        )
    }

    private func fetchActiveMedications(for humanId: String) -> [HumanMedication] {
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanId && medication.isActive
            }
        )
        descriptor.fetchLimit = 24
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchTodayMedicationLogs(for humanId: String) -> [HumanMedicationLog] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        var descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                log.humanId == humanId &&
                log.scheduledTime >= start &&
                log.scheduledTime < end
            },
            sortBy: [SortDescriptor(\.scheduledTime)]
        )
        descriptor.fetchLimit = 48
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchRecentHumanExpenses(for humanId: String) -> [PetExpenseLog] {
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.executorId == humanId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func expandedHumanQuickActionIsPrivate(_ item: QuickActionItem, human: Human) -> Bool {
        PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: activeHumanId)
    }

    private func performExpandedQuickAction(_ action: FocusCard.Action, for card: FocusCard) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway })
        switch ExpandedQuickActionLogic.legacyRoute(action: action, card: card, pet: pet) {
        case .selectHuman:
            selectedHuman = humans.first(where: { $0.id == card.id })
        case .none:
            return
        case .recordFeed:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetCareLog(
                date: Date(),
                type: .feeding,
                amountGrams: pet.dailyPortionGrams,
                note: PetCareLog.manualFeedNoteMarker,
                pet: pet,
                executorId: executorId
            )
            modelContext.insert(log)
            QuestManager.shared.recordFirstMeal()
            QuestManager.shared.awardAction(type: .feed, pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                pet: pet,
                type: .feeding,
                context: modelContext,
                executorId: executorId
            )
        case .recordWater:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetCareLog(
                date: Date(),
                type: .watering,
                amountMl: 250,
                pet: pet,
                executorId: executorId
            )
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .water, pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                pet: pet,
                type: .watering,
                context: modelContext,
                executorId: executorId
            )
        case .startWalk:
            guard let pet else { return }
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
            }
            triggerWalkCardTransform(for: pet)
        case .recordPotty:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetPottyReminder(
                pet: pet,
                context: modelContext,
                executorId: executorId
            )
        case .recordLitter:
            guard let pet else { return }
            let executorId = currentExecutorId()
            let log = PetCareLog(date: Date(), type: .litter, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
            QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                pet: pet,
                type: .litter,
                context: modelContext,
                executorId: executorId
            )
        case .specialCare(let type):
            guard let pet else { return }
            performExpandedSpecialCare(type, pet: pet, executorId: currentExecutorId())
        case .waterManagement:
            guard let pet else { return }
            openExpandedWaterManagement(for: pet)
        case .selectPetOverview:
            guard let pet else { return }
            selectedPetTab = .overview
            selectedPet = pet
        }
    }

    private func currentExecutorId() -> String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func performExpandedSpecialCare(_ type: CareType, pet: Pet, executorId: String?) {
        let reward: QuestManager.OhanaActionType
        switch type {
        case .play:
            reward = .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            reward = .general(humanReward: 25, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            reward = .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理鸟笼奖励")
        case .freeFlight:
            reward = .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            reward = .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 保湿打卡奖励")
        case .substrateChange:
            reward = .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 环境清洁奖励")
        default:
            reward = .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 打卡奖励")
        }
        let got = CareEventService.recordCare(pet: pet, type: type, context: modelContext, executorId: executorId, reward: reward)
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
    }

    private func completeQuestInFocusStack(_ quest: IslandQuest) {
        let activePets = pets.filter { !$0.hasPassedAway }

        if quest.id.hasPrefix("q_feed_") {
            if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                openTodayFocusPetShortcut("feed", pet: p)
            }
        } else if quest.id.hasPrefix("q_water_") && !quest.id.hasPrefix("q_water_plant") {
            if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                openTodayFocusPetShortcut("water", pet: p)
            }
        } else {
            switch quest.id {
            case "q_walk":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    openTodayFocusWalk(pet: p)
                }
            case "q_potty":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    let actionType = (p.species.contains("猫") || p.species.contains("兔")) ? "litter" : "potty"
                    openTodayFocusPetShortcut(actionType, pet: p)
                }
            case let id where id.hasPrefix("q_play_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    openTodayFocusPetShortcut("play", pet: p)
                }
            case let id where id.hasPrefix("q_weight_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    focusTodayPetCard(p)
                    openExpandedQuickWeight(for: p)
                }
            case let id where IslandQuestEngine.humanWeightId(fromQuestId: id) != nil:
                if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: id),
                   let human = humans.first(where: { $0.id == humanId }) {
                    openTodayFocusHumanWeight(human)
                }
            case let id where id.hasPrefix("q_moment_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    focusTodayPetCard(p)
                    expandedQuickMomentPet = p
                }
            case "q_water_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                    selectedPlant = pl
                }
            case "q_fertilize_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                    selectedPlant = pl
                }
            case "q_reminder":
                openGlobalCalendar()
            case "q_visit":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    selectedPetTab = .overview
                    selectedPet = p
                } else if let p = activePets.first {
                    selectedPetTab = .overview
                    selectedPet = p
                }
            default:
                if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
                   let event = allEvents.first(where: { $0.id == eventId }) {
                    openTodayFocusEvent(event)
                } else if let mid = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
                    for p in activePets {
                        if let medication = p.medications.first(where: { $0.id == mid }) {
                            PetMedicationDoseLogging.recordDose(
                                medication: medication,
                                pet: p,
                                modelContext: modelContext,
                                awardCoconut: true
                            )
                            MedicationReminderService.shared.scheduleMedicationReminders(for: p, context: modelContext)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            triggerExpandedActionFeedback(cardId: p.id, coconutDelta: 1, label: "💊 +1🥥")
                            break
                        }
                    }
                }
            }
        }
    }

    private func focusTodayPetCard(_ pet: Pet) {
        fabExpanded = false
        isExpandedQAEditMode = false
        withAnimation(walletAnimation) {
            activeCardId = pet.id
            isExpanded = true
        }
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
            isExpandedQAEditMode = false
            withAnimation(walletAnimation) {
                activeCardId = human.id
                isExpanded = true
            }
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
        let eventType = EventType(rawValue: event.eventType)
        let entityType = event.relatedEntityType.lowercased()

        if entityType == EntityKind.pet.rawValue.lowercased() || entityType == "pet",
           let petId = UUID(uuidString: event.relatedEntityId),
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            switch eventType {
            case .vaccine, .externalDeworming, .internalDeworming, .health, .vetVisit:
                openTodayFocusHealth(pet: pet, section: .preventive)
                return true
            default:
                break
            }
        }

        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased(),
           let medicationId = UUID(uuidString: event.relatedEntityId) {
            for pet in pets where !pet.hasPassedAway {
                if pet.medications.contains(where: { $0.id == medicationId }) {
                    focusTodayPetCard(pet)
                    expandedQuickPetMedicationPet = pet
                    return true
                }
            }
        }

        return false
    }

    private func handleTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        guard let pet = petForNegativeSignal(signal) else { return }
        fabExpanded = false
        isExpandedQAEditMode = false

        if let alertType = signal.healthAlertType {
            switch alertType {
            case .checkupOverdue, .vaccineExpired, .vaccineExpiringSoon, .dewormingDue:
                openTodayFocusHealth(pet: pet, section: .preventive)
            case .weightGainAlert, .weightLossAlert:
                focusTodayPetCard(pet)
                expandedQuickWeightDetailPet = pet
            case .drinkingWeightAlert:
                openTodayFocusHealth(pet: pet, section: .symptomVisit)
            default:
                openTodayFocusHealth(pet: pet, section: .symptomVisit)
            }
            return
        }

        withAnimation(walletAnimation) {
            activeCardId = pet.id
            isExpanded = true
        }
    }

    private func petForNegativeSignal(_ signal: IslandNegativeSignal) -> Pet? {
        if let petId = signal.petId,
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            return pet
        }
        if let activePet = todayFocusActivePet {
            return activePet
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    // MARK: FAB (floating action button)

    private var floatingFabBottomPadding: CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 34
        return safeBottom + 40
    }

    private func openHomeFabMenu() {
        guard !fabExpanded else { return }
        fabMenuItemsVisible = false
        withAnimation(HeroAnim.fabSpring) {
            fabExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(HeroAnim.fabSpring) {
                fabMenuItemsVisible = true
            }
        }
    }

    private func closeHomeFabMenu() {
        guard fabExpanded else { return }
        withAnimation(HeroAnim.fabSpring) {
            fabMenuItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if fabExpanded && !fabMenuItemsVisible {
                withAnimation(HeroAnim.fabSpring) {
                    fabExpanded = false
                }
            }
        }
    }

    private func toggleHomeFabMenu() {
        fabExpanded ? closeHomeFabMenu() : openHomeFabMenu()
    }

    private func openCardFabMenu() {
        guard !cardFabExpanded else { return }
        cardFabMenuItemsVisible = false
        withAnimation(HeroAnim.fabSpring) {
            cardFabExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(HeroAnim.fabSpring) {
                cardFabMenuItemsVisible = true
            }
        }
    }

    private func closeCardFabMenu() {
        guard cardFabExpanded else { return }
        withAnimation(HeroAnim.fabSpring) {
            cardFabMenuItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if cardFabExpanded && !cardFabMenuItemsVisible {
                withAnimation(HeroAnim.fabSpring) {
                    cardFabExpanded = false
                }
            }
        }
    }

    private func toggleCardFabMenu() {
        cardFabExpanded ? closeCardFabMenu() : openCardFabMenu()
    }

    @ViewBuilder
    private func homeFabOverlay(activeCard: FocusCard?) -> some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Expanded action buttons (上方弹出)
            if fabExpanded, let activeCard {
                let activeItems = expandedCardFabShortcuts(for: activeCard)
                ForEach(Array(activeItems.enumerated()), id: \.element.id) { idx, item in
                    fabActionRow(
                        item: HomeFabFunctionShortcut(
                            label: item.label,
                            icon: item.icon,
                            isAvailable: item.isAvailable,
                            badge: item.badge
                        ),
                        rowHeight: 48
                    )
                    .scaleEffect(fabMenuItemsVisible ? 1 : 0.6, anchor: .bottomTrailing)
                    .opacity(fabMenuItemsVisible ? 1 : 0)
                    .offset(y: fabMenuItemsVisible ? 0 : 24)
                    .animation(
                        HeroAnim.fabSpring
                        .delay(fabMenuItemsVisible
                               ? Double(activeItems.count - 1 - idx) * 0.055
                               : Double(idx) * 0.04),
                        value: fabMenuItemsVisible
                    )
                    .onTapGesture {
                        guard item.isAvailable else {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            return
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        closeHomeFabMenu()
                        openExpandedCardFabShortcut(item, card: activeCard)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.label)
                    .accessibilityHint("前往\(item.label)详情")
                    .allowsHitTesting(fabMenuItemsVisible)
                    .accessibilityHidden(!fabMenuItemsVisible)
                }
            } else if fabExpanded {
                let fabItems = homeFabFunctionShortcuts
                ForEach(Array(fabItems.enumerated()), id: \.element.id) { idx, item in
                    fabActionRow(item: item, rowHeight: 48)
                        .scaleEffect(fabMenuItemsVisible ? 1 : 0.6, anchor: .bottomTrailing)
                        .opacity(fabMenuItemsVisible ? 1 : 0)
                        .offset(y: fabMenuItemsVisible ? 0 : 24)
                        .animation(
                            HeroAnim.fabSpring
                            .delay(fabMenuItemsVisible
                                   ? Double(fabItems.count - 1 - idx) * 0.055
                                   : Double(idx) * 0.04),
                            value: fabMenuItemsVisible
                        )
                        .onTapGesture { openHomeFabShortcut(item) }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.label)
                        .accessibilityHint(item.isAvailable ? "前往\(item.label)" : "当前不可用")
                        .allowsHitTesting(fabMenuItemsVisible)
                        .accessibilityHidden(!fabMenuItemsVisible)
                }
            }

            // Main FAB button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                toggleHomeFabMenu()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1A2E8A"))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: "1A2E8A").opacity(0.45), radius: 10, y: 4)
                    Image(systemName: fabExpanded ? "xmark" : "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(fabExpanded ? 90 : 0))
                        .animation(HeroAnim.buttonSpring, value: fabExpanded)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(fabExpanded ? "收起菜单" : "展开菜单")
            .accessibilityHint("点击展开常用功能")
        }
        .padding(.trailing, 20)
        .padding(.bottom, floatingFabBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var homeFabFunctionShortcuts: [HomeFabFunctionShortcut] {
        // FAB 只放最高频、最容易理解的入口；日历在顶部固定入口，绿洲从椰子数进入。
        // 其他低频或奖励/工具类能力统一收进「更多」。
        [
            HomeFabFunctionShortcut(label: PetFeature.food.title,     icon: PetFeature.food.icon,     destination: .featureAggregate(.food)),
            HomeFabFunctionShortcut(label: PetFeature.hygiene.title,  icon: PetFeature.hygiene.icon,  destination: .featureAggregate(.hygiene)),
            HomeFabFunctionShortcut(label: PetFeature.health.title,   icon: PetFeature.health.icon,   destination: .featureAggregate(.health)),
            HomeFabFunctionShortcut(label: PetFeature.weight.title,   icon: PetFeature.weight.icon,   destination: .featureAggregate(.weight)),
            HomeFabFunctionShortcut(label: PetFeature.expense.title,  icon: PetFeature.expense.icon,  destination: .featureAggregate(.expense)),
            HomeFabFunctionShortcut(label: "更多",                    icon: "ellipsis.circle.fill",   destination: nil)
        ]
    }

    private func homeFabFunctionTray(items: [HomeFabFunctionShortcut]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .trailing, spacing: 10) {
                ForEach(items) { item in
                    fabActionRow(item: item, rowHeight: 44)
                        .onTapGesture { openHomeFabShortcut(item) }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.label)
                        .accessibilityHint(item.isAvailable ? "前往\(item.label)" : "当前不可用")
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 430)
        .padding(.trailing, 1)
    }

    private func fabActionRow(item: HomeFabFunctionShortcut, rowHeight: CGFloat) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(item.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.goPrimary.opacity(0.14), in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.ohanaCardSurface.opacity(item.isAvailable ? 0.9 : 0.45), in: Capsule())
            .shadow(color: .black.opacity(item.isAvailable ? 0.15 : 0.06), radius: 4, y: 2)

            ZStack {
                Circle()
                    .fill(Color(hex: "1A2E8A").opacity(item.isAvailable ? 1 : 0.35))
                    .frame(width: rowHeight, height: rowHeight)
                    .shadow(color: .black.opacity(item.isAvailable ? 0.25 : 0.08), radius: 6, y: 3)
                Image(systemName: item.icon)
                    .font(.system(size: rowHeight >= 48 ? 16 : 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(item.isAvailable ? 1 : 0.5))
            }
        }
        .opacity(item.isAvailable ? 1 : 0.55)
    }

    private func openHomeFabShortcut(_ item: HomeFabFunctionShortcut) {
        guard item.isAvailable else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        closeHomeFabMenu()
        functionMenuPresentation = FunctionMenuPresentation(destination: item.destination)
    }

    private func expandedCardFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman {
            return [
                ExpandedCardFabShortcut(label: l.homeQAWeight, icon: "scalemass.fill", action: .humanQuick("humanWeight")),
                ExpandedCardFabShortcut(label: l.expense, icon: "creditcard.fill", action: .humanQuick("humanExpense")),
                ExpandedCardFabShortcut(label: l.homeQAMeds, icon: "pill.fill", action: .humanQuick("humanMedication")),
                ExpandedCardFabShortcut(label: l.homeQASport, icon: "figure.run", action: .humanQuick("humanWorkout")),
                ExpandedCardFabShortcut(label: l.homeQANote, icon: "note.text", action: .humanQuick("humanNote")),
                ExpandedCardFabShortcut(label: l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"), icon: "ellipsis.circle.fill", action: .humanAllFeatures)
            ]
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return [ExpandedCardFabShortcut(label: "全部功能", icon: "ellipsis.circle.fill", action: .allFeatures)]
        }

        let displayedItems = isExpandedQAEditMode && activeCardId == pet.id
            ? expandedQAEditItems
            : expandedQuickActionItems(for: pet)
        let displayedActionTypes = Set(
            displayedItems
                .prefix(QuickActionLimit.maxItemsPerEntity)
                .map(\.actionType)
        )
        let hiddenQuickItems = QuickActionPickerCatalog
            .available(for: pet, existingActionTypes: displayedActionTypes)
            .map { expandedFabShortcut(from: $0) }

        return hiddenQuickItems + [
            ExpandedCardFabShortcut(label: "全部功能", icon: "ellipsis.circle.fill", action: .allFeatures)
        ]
    }

    private func expandedFabShortcut(from option: QuickActionPickerCatalog.Option) -> ExpandedCardFabShortcut {
        switch option.id {
        case "health":
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .detail(.health))
        case "expense":
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .detail(.expense))
        case "weight":
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .detail(.weight))
        default:
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .quick(option.id))
        }
    }

    @ViewBuilder
    private func expandedCardFab(card: FocusCard) -> some View {
        let items = expandedCardFabShortcuts(for: card)

        VStack(alignment: .trailing, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                fabActionRow(
                    item: HomeFabFunctionShortcut(
                        label: item.label,
                        icon: item.icon,
                        isAvailable: item.isAvailable,
                        badge: item.badge
                ),
                rowHeight: 48
            )
                .scaleEffect(cardFabMenuItemsVisible ? 1 : 0.6, anchor: .bottomTrailing)
                .opacity(cardFabMenuItemsVisible ? 1 : 0)
                .offset(y: cardFabMenuItemsVisible ? 0 : 24)
                .animation(
                    HeroAnim.fabSpring
                    .delay(cardFabMenuItemsVisible ? Double(items.count - 1 - idx) * 0.055 : Double(idx) * 0.04),
                    value: cardFabMenuItemsVisible
                )
                .onTapGesture {
                    guard item.isAvailable else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        return
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    closeCardFabMenu()
                    openExpandedCardFabShortcut(item, card: card)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.label)
                .accessibilityHint("前往\(item.label)详情")
                .allowsHitTesting(cardFabMenuItemsVisible)
                .accessibilityHidden(!cardFabMenuItemsVisible)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                toggleCardFabMenu()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1A2E8A"))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: "1A2E8A").opacity(0.45), radius: 10, y: 4)
                    Image(systemName: cardFabExpanded ? "xmark" : "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(cardFabExpanded ? 90 : 0))
                        .animation(HeroAnim.buttonSpring, value: cardFabExpanded)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(cardFabExpanded ? "收起成员快捷菜单" : "展开成员快捷菜单")
            .accessibilityHint("点击展开常用功能")
        }
    }

    private func openExpandedCardFabShortcut(_ item: ExpandedCardFabShortcut, card: FocusCard) {
        switch item.action {
        case .allFeatures:
            if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
                expandedAllFeaturesPet = pet
            }
        case .humanAllFeatures:
            if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
                expandedAllFeaturesHuman = human
            }
        case .quick(let actionType):
            guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else { return }
            openExpandedPetShortcut(actionType, pet: pet)
        case .detail(let feature):
            guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else { return }
            openExpandedPetDetail(feature, pet: pet)
        case .humanQuick(let actionType):
            guard let human = humans.first(where: { $0.id == card.id }) else { return }
            openExpandedHumanShortcut(actionType, human: human)
        }
    }

    private func openExpandedPetShortcut(_ actionType: String, pet: Pet) {
        switch actionType {
        case "feed":
            openExpandedFeedDetail(for: pet)
        case "water", "waterChange", "filterClean":
            openExpandedWaterManagement(for: pet)
        case "walk":
            expandedQuickWalkPet = pet
        case "potty", "litter":
            expandedQuickPottyDetailPet = pet
        case "play":
            expandedQuickPlayDetailPet = pet
        case "groom":
            expandedQuickHygienePet = pet
        case "moment":
            expandedQuickMomentPet = pet
        default:
            break
        }
    }

    private func openExpandedPetDetail(_ feature: PetFeature, pet: Pet) {
        switch feature {
        case .health:
            expandedQuickHealthInitialSection = nil
            expandedQuickHealthPet = pet
        case .food:
            openExpandedFeedDetail(for: pet)
        case .hygiene:
            expandedQuickHygienePet = pet
        case .walks:
            expandedQuickWalkPet = pet
        case .potty:
            expandedQuickPottyDetailPet = pet
        case .weight:
            expandedQuickWeightDetailPet = pet
        case .expense:
            expandedQuickExpenseDetailPet = pet
        case .retention, .basicInfo, .documents, .moments, .achievements, .medications:
            expandedAllFeaturesPet = pet
        }
    }

    private func openExpandedHumanShortcut(_ actionType: String, human: Human) {
        if let field = PrivacyService.field(forHumanAction: actionType),
           PrivacyService.isLocked(field, for: human, viewedBy: activeHumanId) {
            showingHumanPrivacyAlert = true
            return
        }

        switch actionType {
        case "humanWeight":
            expandedHumanWeightDetail = human
        case "humanWorkout":
            expandedHumanWorkoutDetail = human
        case "humanMedication":
            expandedQuickHumanMedication = human
        case "humanNote":
            expandedHumanNoteDetail = human
        case "humanExpense":
            expandedQuickHumanExpense = human
        default:
            expandedAllFeaturesHuman = human
        }
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

        if activeCard.isHuman {
            calendarEntityFilterId = nil
            calendarHumanFilterId = activeCard.id.uuidString
        } else {
            calendarEntityFilterId = activeCard.id.uuidString
            calendarHumanFilterId = nil
        }
        showingCalendar = true
    }

    // MARK: 3-zone header

    private func goFocusHeader(safeT: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // ── Left: check-in capsule + coconut ──
            HStack(spacing: 8) {
                Button { showStreakDetail = true } label: {
                    topLimePill {
                        Text("🔥")
                            .font(OhanaFont.metric(size: 9, .medium))
                        Text("\(headerStreak)")
                            .font(OhanaFont.caption2(.black))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(GoMotion.feedback, value: headerStreak)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("连续打卡 \(headerStreak) 天")

                CoconutBalanceCapsule(balance: headerCoconutBalance, onTap: { showingOasisReward = true })
            }

            Spacer()

            // ── Right: calendar + ... menu ──
            HStack(spacing: 8) {
                topLimePill {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .black))
                        .frame(width: 18)
                }
                .contentShape(Capsule())
                .onTapGesture {
                    showingCrewRoster = true
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingAccountSwitcher = true
                }
                .accessibilityLabel("家庭协作")
                .accessibilityHint("点击打开家庭协作，长按切换人类账户")

                Button { openTopCalendar() } label: {
                    topLimePill {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .black))
                            .frame(width: 18)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("日历")

                Button { showingSettings = true } label: {
                    currentHumanSettingsPill
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("设置，当前用户 \(activeHumanDisplayName)")
            }
        }
        .padding(.horizontal, K.hPad)
        .padding(.top, safeT + 12)
        .frame(height: safeT + 56)
    }

    private func topLimePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 3) {
            content()
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(height: 26)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.goPrimary, in: Capsule())
    }

    private var currentHumanSettingsPill: some View {
        HStack(spacing: 5) {
            currentHumanMiniAvatar
            Text(activeHumanDisplayName)
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(.black)
        .padding(.leading, 4)
        .padding(.trailing, 7)
        .padding(.vertical, 3)
        .frame(height: 26)
        .frame(maxWidth: 104)
        .background(Color.goPrimary, in: Capsule())
    }

    @ViewBuilder
    private var currentHumanMiniAvatar: some View {
        if let human = activeHuman {
            let _ = avatarCacheRevision
            let avatarEntry = FocusWalletAvatarCache.entry(for: human.id, data: human.avatarImageData)
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 20, height: 20)
                if let image = avatarEntry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                } else {
                    Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                        .font(.system(size: 11))
                }
            }
        } else {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 14, weight: .black))
                .frame(width: 20, height: 20)
        }
    }

    // MARK: Context menu (long-press on card)

    @ViewBuilder
    private func cardContextMenu(card: FocusCard) -> some View {
        if card.isReal && !card.isDummy && !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                .flatMap { $0.isEmpty ? nil : $0 }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let log = PetCareLog(date: Date(), type: .feeding,
                                     amountGrams: pet.dailyPortionGrams,
                                     note: PetCareLog.manualFeedNoteMarker, pet: pet, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
            } label: {
                Label("喂食 \(pet.name)", systemImage: "fork.knife")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                openExpandedWaterManagement(for: pet)
            } label: {
                Label("水管理", systemImage: "water.waves")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
            } label: {
                Label("便便记录", systemImage: "drop.circle")
            }

            Divider()

            Button {
                selectedPet = pet
            } label: {
                Label("查看详情", systemImage: "arrow.right.circle")
            }
        }
    }

}

// ─────────────────────────────────────────────────
// MARK: – Wallet card view  (WalletPetCardFront style)
// ─────────────────────────────────────────────────

private struct WalkLaunchBurst: View {
    @State private var animate = false

    private let paws: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-92, 50, 0.00), (-48, 18, 0.06), (-6, 42, 0.12),
        (38, 10, 0.18), (82, 34, 0.24)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.goLime.opacity(animate ? 0.22 : 0.04),
                            Color.goTeal.opacity(animate ? 0.16 : 0.03),
                            .clear
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .scaleEffect(animate ? 1.02 : 0.96)

            HStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 20, weight: .black))
                Text("开始巡岛")
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.goLime, in: Capsule())
            .shadow(color: Color.goLime.opacity(0.45), radius: 18, y: 5)
            .scaleEffect(animate ? 1 : 0.72)
            .opacity(animate ? 1 : 0)

            ForEach(paws.indices, id: \.self) { index in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.goLime.opacity(0.88))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : 16))
                    .offset(
                        x: animate ? paws[index].x : paws[index].x - 28,
                        y: animate ? paws[index].y - 64 : paws[index].y
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.78).delay(paws[index].delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            withAnimation(HeroAnim.fabSpring) {
                animate = true
            }
        }
    }
}

private struct ExpandedHumanFeaturesSheet: View {
    let human: Human

    private enum HumanFeatureRoute: String, Identifiable {
        case basicInfo
        case weight
        case workout
        case medication
        case report
        case expense
        case wishlist
        case notes

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @Query private var allPets: [Pet]
    @Query private var allHumans: [Human]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var allPendingReminders: [Reminder]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]

    @State private var showingEditSheet = false
    @State private var showingCoconutLog = false
    @State private var showingDeleteConfirm = false
    @State private var activeFeatureRoute: HumanFeatureRoute?

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isAllPrivateForViewer: Bool {
        !isViewingOwnProfile && HumanPrivateField.allCases.allSatisfy { human.privateFields.contains($0.rawValue) }
    }

    private var humanReminders: [Reminder] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allPendingReminders.filter {
            $0.event?.relatedEntityType == "Human" &&
            $0.event?.relatedEntityId == human.id.uuidString
        }
    }

    private var myMeds: [HumanMedication] {
        guard !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allMeds.filter { $0.humanId == human.id.uuidString && $0.isActive && $0.isActiveToday }
    }

    private var myReports: [HumanHealthReport] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.weight, viewedBy: activeHumanId) else { return [] }
        return allReports.filter { $0.humanId == human.id.uuidString }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            activeFeatureRoute = .basicInfo
                        } label: {
                            humanFeatureHero
                        }
                        .buttonStyle(ScaleButtonStyle())

                        if isAllPrivateForViewer {
                            fullPrivacyCard
                        } else {
                            badgesCard
                            ownerPrivateDataNoticeStack
                        }

                        sectionHeader("功能入口")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .weight,
                                route: .weight,
                                lockedTitle: "体重",
                                label: {
                                    bentoCard(
                                        icon: "scalemass.fill",
                                        color: .goTeal,
                                        title: "体重",
                                        value: latestWeightText,
                                        subtitle: "趋势与记录",
                                        height: 146
                                    )
                                }
                            )
                            featureNavigation(
                                field: .workout,
                                route: .workout,
                                lockedTitle: "活动",
                                label: {
                                    bentoCard(
                                        icon: "figure.run",
                                        color: Color.goOrange,
                                        title: "活动",
                                        value: "\(visibleWorkoutCount)",
                                        subtitle: "运动与共同健康",
                                        height: 146
                                    )
                                }
                            )
                        }

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .medication,
                                route: .medication,
                                lockedTitle: "用药",
                                label: {
                                    compactBentoCard(icon: "pills.fill", color: .goPurple, title: "用药", subtitle: "服药与提醒")
                                }
                            )
                            featureNavigation(
                                field: .weight,
                                route: .report,
                                lockedTitle: "健康报告",
                                label: {
                                    compactBentoCard(icon: "cross.case.fill", color: .goRed, title: "健康报告", subtitle: "体检与档案")
                                }
                            )
                        }

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .expense,
                                route: .expense,
                                lockedTitle: "花费",
                                label: {
                                    bentoCard(
                                        icon: "creditcard.fill",
                                        color: .goOrange,
                                        title: "花费",
                                        value: "账本",
                                        subtitle: "谁花了多少钱",
                                        height: 132
                                    )
                                }
                            )
                            featureNavigation(
                                field: .wishlist,
                                route: .wishlist,
                                lockedTitle: "椰子资产",
                                label: {
                                    bentoCard(
                                        icon: "gift.fill",
                                        color: Color(hex: "EC4899"),
                                        title: "椰子资产",
                                        value: visibleCoconutText,
                                        subtitle: "愿望清单和资产",
                                        height: 132
                                    )
                                }
                            )
                        }

                        if !isAllPrivateForViewer {
                            sectionHeader("提醒与备注")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            remindersCard
                            notesCard
                            if isViewingOwnProfile {
                                deleteCard
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("\(human.name) 的功能")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CoconutBalanceCapsule {
                        showingCoconutLog = true
                    }
                    .disabled(human.isPrivate(.wishlist, viewedBy: activeHumanId))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        if isViewingOwnProfile {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(.black)
                                    .frame(width: 30, height: 30)
                                    .background(Color.goLime, in: Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        Button("完成") { dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.goLime)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) { EditHumanSheet(human: human) }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
            .fullScreenCover(item: $activeFeatureRoute) { route in
                humanFeatureRouteView(route)
                    .background(OhanaAppBackground().ignoresSafeArea())
            }
            .alert("确认删除", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteHumanAndDismiss()
                }
            } message: {
                Text("确定要删除 \(human.name) 吗？此操作不可撤销。")
            }
        }
    }

    @ViewBuilder
    private func featureNavigation<Label: View>(
        field: HumanPrivateField,
        route: HumanFeatureRoute,
        lockedTitle: String,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if human.isPrivate(field, viewedBy: activeHumanId) {
            lockedFeatureCard(title: lockedTitle)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                activeFeatureRoute = route
            } label: {
                label()
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @ViewBuilder
    private func humanFeatureRouteView(_ route: HumanFeatureRoute) -> some View {
        switch route {
        case .basicInfo:
            HumanBasicInfoDetailView(human: human)
        case .weight:
            HumanWeightHistoryView(human: human)
        case .workout:
            CoHealthDashboardFullView(human: human)
        case .medication:
            HumanMedicationView(human: human)
        case .report:
            HumanHealthReportView(human: human)
        case .expense:
            HumanExpenseDetailView(human: human)
        case .wishlist:
            HumanWishlistView(human: human)
        case .notes:
            HumanNoteHistorySheet(human: human)
        }
    }

    private var visibleWorkoutCount: Int {
        human.isPrivate(.workout, viewedBy: activeHumanId) ? 0 : human.workoutLogs.count
    }

    private var visibleCoconutText: String {
        human.isPrivate(.wishlist, viewedBy: activeHumanId) ? "—" : "\(human.coconutBalance)"
    }

    private var ownerPrivateDataNoticeStack: some View {
        VStack(spacing: 10) {
            ForEach(HumanPrivateField.allCases) { field in
                HumanPrivateDataNotice(human: human, field: field)
            }
        }
    }

    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                humanAvatar(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(human.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(humanSubtitle.isEmpty ? "OHANA MEMBER" : humanSubtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(Color.goLime, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoPill(title: "权限", value: human.roleText.isEmpty ? "成员" : human.roleText)
                infoPill(title: "性别/身份", value: HumanGenderIdentity.title(for: human.genderRaw))
                infoPill(title: "年龄", value: human.birthday == nil ? "未设置" : human.ageText)
                infoPill(title: "血型", value: human.bloodType.isEmpty ? "未设置" : human.bloodType)
                infoPill(title: "身高", value: human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f cm", human.heightCm) : "未设置")
                infoPill(title: "国籍", value: human.nationality.isEmpty ? "未设置" : human.nationality)
                infoPill(title: "城市", value: human.city.isEmpty ? "未设置" : human.city)
            }
        }
        .padding(16)
        .background(.white.opacity(0.085), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.11), lineWidth: 1)
        }
    }

    private var badgesCard: some View {
        let badges = human.dynamicBadges(allPets: allPets, allHumans: allHumans)
        return Group {
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Color.goYellow)
                        Text("动态称号")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(.white)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(badges) { badge in
                                HStack(spacing: 5) {
                                    Text(badge.emoji)
                                    Text(badge.title)
                                        .font(OhanaFont.caption(.bold))
                                }
                                .foregroundStyle(Color(hex: badge.color))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(hex: badge.color).opacity(0.16), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: badge.color).opacity(0.28), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                }
            }
        }
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(Color.goOrange)
                Text("待办提醒")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(humanReminders.count)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.goOrange, in: Capsule())
            }

            if humanReminders.isEmpty {
                emptyInlineRow(icon: "checkmark.circle", title: "暂无待办提醒")
            } else {
                ForEach(humanReminders.prefix(4)) { reminder in
                    reminderRow(reminder)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        if human.isPrivate(.note, viewedBy: activeHumanId) {
            lockedWideCard(title: "备注")
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                activeFeatureRoute = .notes
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("备注记录")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(.white)
                        Text(human.notes.isEmpty ? "暂无备注" : human.notes.components(separatedBy: "\n\n").first ?? "查看备注")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.white.opacity(0.26))
                }
                .padding(14)
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Label("删除成员", systemImage: "trash")
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.goRed.opacity(0.24), lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var fullPrivacyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text("此成员资料仅本人可见")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(.white)
            Text("当前家庭成员无法查看 TA 的体重、运动、吃药、备注、花费和椰子资产等相关数据。")
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(.white.opacity(0.54))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func lockedFeatureCard(title: String) -> some View {
        lockedWideCard(title: title)
            .frame(maxWidth: .infinity, minHeight: 132)
    }

    private func lockedWideCard(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.white.opacity(0.42))
            Text("\(title) · 仅本人可见")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func emptyInlineRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.34))
            Text(title)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Text(reminder.event?.emoji ?? "📌")
                .font(OhanaFont.title3())
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.event?.title ?? "提醒")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(.white)
                Text(reminder.scheduledAt, style: .date)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button {
                completeReminder(reminder)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goLime)
            }
            Button {
                skipReminder(reminder)
            } label: {
                Image(systemName: "forward.circle.fill")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goYellow)
            }
        }
        .padding(.vertical, 5)
    }

    private func completeReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ReminderCompletionService.complete(reminder, by: human.id.uuidString, context: modelContext)
    }

    private func skipReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ReminderCompletionService.skip(reminder, by: human.id.uuidString, context: modelContext)
    }

    private func deleteHumanAndDismiss() {
        let deletedHumanId = human.id.uuidString
        let hasRemainingHuman = allHumans.contains { $0.id.uuidString != deletedHumanId }
        let deletedCurrentHuman = activeHumanIdStr == deletedHumanId
        let requiresReplacementHuman = !hasRemainingHuman
        let requiresAccountSwitch = deletedCurrentHuman && hasRemainingHuman

        if deletedCurrentHuman || requiresReplacementHuman {
            activeHumanIdStr = ""
        }

        modelContext.delete(human)
        modelContext.safeSave()
        NotificationCenter.default.post(
            name: .ohanaReturnHomeAfterHumanDeletion,
            object: nil,
            userInfo: [
                "requiresReplacementHuman": requiresReplacementHuman,
                "requiresAccountSwitch": requiresAccountSwitch
            ]
        )
        dismiss()
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.12))
    }

    private var humanFeatureHero: some View {
        ZStack(alignment: .topLeading) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.54, 0.32), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: [
                    Color(hex: human.safeThemeColorHex).mix(with: .white, by: 0.2),
                    Color.goTeal.opacity(0.70),
                    Color.goOrange.opacity(0.48),
                    Color(hex: human.safeThemeColorHex),
                    Color(hex: "1A2E8A"),
                    Color(hex: "EC4899").opacity(0.7),
                    Color(hex: "0C1640"),
                    Color(hex: human.safeThemeColorHex).mix(with: .black, by: 0.28),
                    Color(hex: "050816")
                ]
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MEMBER OS")
                            .font(OhanaFont.caption2(.black))
                            .tracking(2.6)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(human.name)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(humanSubtitle)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                    Spacer()
                    humanAvatar(size: 54)
                }

                HStack(spacing: 9) {
                    heroChip(title: "椰子", value: privateAwareHeroValue(.wishlist, "\(human.coconutBalance)"))
                    heroChip(title: "运动", value: privateAwareHeroValue(.workout, "\(human.workoutLogs.count)"))
                    heroChip(title: "体重", value: privateAwareHeroValue(.weight, "\(human.weightLogs.count)"))
                }
            }
            .padding(18)

            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 22, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.68))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(16)

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 88, weight: .black))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 246, y: 76)
        }
        .frame(height: 188)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Color(hex: human.safeThemeColorHex).opacity(0.28), radius: 22, y: 12)
    }

    private var humanSubtitle: String {
        let zodiac = human.birthday.map { Human.westernZodiacChinese(for: $0) }
        return [human.roleText, HumanGenderIdentity.title(for: human.genderRaw), zodiac, human.mbti.isEmpty ? nil : human.mbti]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var latestWeightText: String {
        guard !human.isPrivate(.weight, viewedBy: activeHumanId) else { return "—" }
        guard let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first else { return "--" }
        return String(format: "%.1f", latest.weight)
    }

    private func privateAwareHeroValue(_ field: HumanPrivateField, _ value: String) -> String {
        human.isPrivate(field, viewedBy: activeHumanId) ? "—" : value
    }

    private func bentoCard(icon: String, color: Color, title: String, value: String, subtitle: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(.white.opacity(0.36))
            }
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [color.opacity(0.28), Color.white.opacity(0.07), Color.black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.11), lineWidth: 1)
        }
    }

    private func compactBentoCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(.white.opacity(0.26))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
        }
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(.white)
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func humanAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: size, height: size)
            if let data = human.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: size * 0.48))
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.58))
    }

    private func row(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(.vertical, 5)
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
        let safeB     = geo.safeAreaInsets.bottom
        let padding   = K.focusCardPadding
        let fullW     = windowSize.width
        let fullH     = windowSize.height
        let heroW     = fullW - padding * 2
        let heroH     = max(200, fullH * 0.55 - padding)
        let cardCornerRadius = max(4, min(outerCornerRadius - padding, heroW / 2 - 1, heroH / 2 - 1))
        let bgColor   = card.color.mix(with: K.bg, by: 0.18)

        let shellSourceDetail = expandedId == card.id
        let artSourceDetail   = expandedId == card.id

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(bgColor)
                .matchedGeometryEffect(id: HeroShellID(cardId: card.id), in: ns, isSource: shellSourceDetail)
                .frame(width: fullW, height: fullH)
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    heroCardView(card: card, width: heroW, height: heroH)
                        .matchedGeometryEffect(id: HeroArtID(cardId: card.id), in: ns, isSource: artSourceDetail)
                        .frame(width: heroW, height: heroH)
                        .padding(.init(top: padding, leading: padding, bottom: 0, trailing: padding))
                }
                .frame(width: fullW, height: padding + heroH, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))

                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(card.name)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(K.ink.opacity(0.88))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .padding(.top, 10).padding(.horizontal, padding)

                    goStyleActions(card: card)
                        .padding(.horizontal, padding).padding(.top, 12)

                    Spacer(minLength: 0)

                    if card.isDummy {
                        Text("DEMO DATA")
                            .fcMicro()
                            .foregroundStyle(K.ink.opacity(0.16))
                            .padding(.bottom, safeB + 6)
                    }
                }
                .offset(y: detailFooterVisible ? 0 : 28)
                .opacity(detailFooterVisible ? 1 : 0)
                .animation(GoMotion.quick, value: detailFooterVisible)

                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: [.top, .leading, .trailing])

            VStack {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        detailFooterVisible = false
                        withAnimation(transitionAnimation) {
                            expandedId = nil
                            dragOffset = 0
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    Spacer()
                }
                .padding(.leading, padding + 4)
                .padding(.top, safeAreaTop + 8)
                Spacer()
            }
            .allowsHitTesting(true)

            if !isInlineRecordOverlayPresented {
                expandedCardFab(card: card)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, floatingFabBottomPadding)
                    .allowsHitTesting(true)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
        }
        .frame(width: fullW, height: fullH)
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { v in if v.translation.height > 0 { dragOffset = v.translation.height } }
                .onEnded { v in
                    if v.translation.height > 80 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        detailFooterVisible = false
                        withAnimation(transitionAnimation) { expandedId = nil; dragOffset = 0 }
                    } else {
                        withAnimation(transitionAnimation) { dragOffset = 0 }
                    }
                }
        )
        .ignoresSafeArea(.all)
    }

    private func heroCardView(card: FocusCard, width: CGFloat, height: CGFloat) -> some View {
        let avatarEntry = FocusWalletAvatarCache.entry(for: card.id, data: card.avatarImageData)
        let avatarImage = avatarEntry.image

        return ZStack {
            LinearGradient(
                colors: [card.color.mix(with: .white, by: 0.28),
                         card.color,
                         card.color.mix(with: .black, by: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(width: width, height: height)

            Group {
                if let img = avatarImage {
                    if avatarEntry.isTransparent {
                        expandedTransparentAvatarLayer(img, card: card, width: width, height: height)
                    } else {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: width, height: height).clipped()
                    }
                } else if card.isHuman {
                    FocusHumanPortrait(emoji: card.emoji, color: card.color)
                } else if let sp = card.petSpecies {
                    PetSilhouetteView(
                        species: normalizeSpecies(sp),
                        coatColor: card.coatColor,
                        eyeColor: card.eyeColor,
                        patternName: card.patternName,
                        isAnimationEnabled: false
                    )
                    .scaleEffect(1.55).offset(y: 12)
                } else {
                    Text(card.emoji)
                        .font(.system(size: height * 0.40))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            LinearGradient(
                colors: [.clear, card.color.mix(with: .black, by: 0.10).opacity(0.50)],
                startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }

    private func expandedTransparentAvatarLayer(_ image: UIImage, card: FocusCard, width: CGFloat, height: CGFloat) -> some View {
        let avatarWidth = width * (card.isHuman ? 0.72 : 0.78)
        let avatarHeight = height * (card.isHuman ? 0.98 : 0.92)
        let offsetX = width * (card.isHuman ? 0.05 : 0.04)
        let offsetY = card.isHuman ? 0 : -height * 0.02

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: avatarWidth, height: avatarHeight, alignment: .bottom)
            .frame(width: width, height: height, alignment: .bottomLeading)
            .offset(x: offsetX, y: offsetY)
            .shadow(color: .white.opacity(0.38), radius: 4)
            .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 12)
    }

    private func goStyleActions(card: FocusCard) -> some View {
        let acts = card.actions
        let cols = min(acts.count, 4)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols),
            spacing: 10
        ) {
            ForEach(acts) { goActionCell(action: $0) }
        }
    }

    private func goActionCell(action: FocusCard.Action) -> some View {
        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: action.colorHex).opacity(0.92))
                Text(action.label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.65)
                    .foregroundStyle(K.ink.opacity(0.62))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.ink.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func normalizeSpecies(_ s: String) -> String {
        let l = s.lowercased()
        if s.contains("猫") || l.contains("cat")      { return "猫"  }
        if s.contains("狗") || l.contains("dog")      { return "狗"  }
        if s.contains("兔") || l.contains("rabbit")   { return "兔子" }
        if s.contains("仓鼠") || l.contains("hamster") { return "仓鼠" }
        if s.contains("鸟") || l.contains("bird")     { return "鸟"  }
        return s
    }
}

// ─────────────────────────────────────────────────
// MARK: – Human portrait placeholder
// ─────────────────────────────────────────────────

private struct FocusHumanPortrait: View {
    let emoji: String
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle()
                    .fill(color.mix(with: .white, by: 0.45).opacity(0.30))
                    .frame(width: g.size.width * 0.65)
                    .offset(x: -g.size.width * 0.18, y: -g.size.height * 0.14)
                Text(emoji)
                    .font(.system(size: g.size.height * 0.44))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -g.size.height * 0.04)
            }
        }
    }
}

private struct ExpandedQuickActionMenuPanel: View {
    let icon: String
    let title: String
    let status: String
    let accent: Color
    let isLocked: Bool
    let lockedText: String?
    let quickTitle: String
    let detailTitle: String?
    let isQuickDisabled: Bool
    let quickOptions: [ExpandedQuickMenuOption]
    let onQuick: () -> Void
    let onDetail: () -> Void
    let onOption: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                .padding(.top, 8)
                .gesture(
                    DragGesture(minimumDistance: 12).onEnded { value in
                        if value.translation.height > 32 {
                            onClose()
                        }
                    }
                )

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(status)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            VStack(spacing: 10) {
                if isLocked {
                    lockedBlock
                } else if !quickOptions.isEmpty {
                    optionGrid
                } else {
                    actionButton(
                        title: quickTitle,
                        icon: isQuickDisabled ? "checkmark.circle.fill" : "bolt.fill",
                        tint: isQuickDisabled ? Color.ohanaControlFill : accent,
                        foreground: isQuickDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText,
                        isDisabled: isQuickDisabled,
                        action: onQuick
                    )
                }

                if !isLocked, let detailTitle {
                    actionButton(
                        title: detailTitle,
                        icon: "chart.line.uptrend.xyaxis",
                        tint: Color.ohanaControlFill,
                        foreground: Color.ohanaPrimaryText,
                        isDisabled: false,
                        action: onDetail
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background { OhanaPopupGlassSurface(cornerRadius: 52) }
        .shadow(color: Color.black.opacity(0.34), radius: 30, x: 0, y: -8) // ui-v4: allow lifted overlay shadow
    }

    private var lockedBlock: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text(lockedText ?? "")
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var optionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quickTitle)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(quickOptions) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onOption(option.id)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(option.tint)
                            Text(option.title)
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        tint: Color,
        foreground: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                Text(title)
                    .font(OhanaFont.body(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint, in: Capsule())
        }
        .disabled(isDisabled)
        .buttonStyle(ScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────
// MARK: – Text style helper
// ─────────────────────────────────────────────────

private extension Text {
    func fcMicro(weight: Font.Weight = .medium) -> some View {
        self
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
