//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  GO Focus UI — default home page.
//  Formerly a test page; now the primary app home when appUIStyle == "go".
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────
// MARK: – Data model
// ─────────────────────────────────────────────────

private struct FocusCard: Identifiable {
    let id: UUID
    let name: String
    let kind: String
    let emoji: String
    let color: Color
    let streak: Int
    let coconutBalance: Int
    var daysTogetherText: String?
    var ageText: String?
    var zodiacText: String?
    var genderText: String?
    var avatarImageData: Data?
    var petSpecies: String?
    var coatColor:      Color = Color(hex: "E8C49A")
    var eyeColor:       Color = Color(hex: "6B3A2A")
    var patternName:    String?
    var themeColorHex:  String = ""
    var daysTogether:   Int = 0
    var breed:          String = ""
    var isHuman:  Bool = false
    var isDummy:  Bool = false
    var isReal:   Bool = false
    var actions: [Action]

    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let colorHex: String
    }
}

private extension FocusCard {

    static func from(_ pet: Pet) -> FocusCard {
        let isDog  = pet.species.contains("狗") || pet.species.lowercased().contains("dog")
        let isCat  = pet.species.contains("猫") || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")

        var acts: [Action] = [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44")]
        if isFish {
            acts += [.init(label: "WATER",  icon: "drop.circle",             colorHex: "00D4AA"),
                     .init(label: "FILTER", icon: "wrench.and.screwdriver",  colorHex: "A78BFA")]
        } else if isDog {
            acts += [.init(label: "WALK",  icon: "figure.walk", colorHex: "C8FF00"),
                     .init(label: "WATER", icon: "drop",         colorHex: "00D4AA"),
                     .init(label: "POTTY", icon: "allergens",    colorHex: "A78BFA")]
        } else if isCat {
            acts += [.init(label: "WATER",  icon: "drop",     colorHex: "00D4AA"),
                     .init(label: "LITTER", icon: "trash",     colorHex: "5B6AFF"),
                     .init(label: "PLAY",   icon: "sparkles",  colorHex: "F472B6")]
        } else {
            acts += [.init(label: "WATER", icon: "drop",     colorHex: "00D4AA"),
                     .init(label: "PLAY",  icon: "sparkles",  colorHex: "F472B6")]
        }

        let hex = pet.themeColorHex.isEmpty ? "FFB3C6" : pet.themeColorHex
        return FocusCard(
            id: pet.id,
            name: pet.name.isEmpty ? "Unnamed" : pet.name,
            kind: pet.species.isEmpty ? "PET" : pet.species,
            emoji: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
            color: Color(hex: hex),
            streak: pet.currentStreak,
            coconutBalance: pet.coconutBalance,
            daysTogetherText: pet.homeDate == nil ? nil : "\(pet.daysTogether) 天",
            ageText: pet.birthday == nil ? nil : pet.ageText,
            zodiacText: pet.birthday.map { Human.westernZodiacDisplay(for: $0, isEnglish: false) },
            genderText: pet.genderSymbol + (pet.isNeutered ? " 已绝育" : ""),
            avatarImageData: pet.avatarImageData,
            petSpecies: pet.species,
            coatColor:    WalletPetCardTheme.silhouetteCoatColor(for: pet),
            eyeColor:     WalletPetCardTheme.silhouetteEyeColor(for: pet),
            patternName:  WalletPetCardTheme.coatPatternName(for: pet),
            themeColorHex: hex,
            daysTogether:  pet.homeDate == nil ? 0 : pet.daysTogether,
            breed:         pet.breed,
            isReal: true,
            actions: Array(acts.prefix(4))
        )
    }

    static func from(_ human: Human) -> FocusCard {
        let hex = human.themeColorHex.isEmpty ? "B9E8D2" : human.themeColorHex
        let days = max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
        return FocusCard(
            id: human.id,
            name: human.name.isEmpty ? "Human" : human.name,
            kind: human.roleText.isEmpty ? "HUMAN" : human.roleText,
            emoji: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji,
            color: Color(hex: hex),
            streak: 0,
            coconutBalance: human.coconutBalance,
            daysTogetherText: "\(days) 天",
            ageText: human.birthday == nil ? nil : human.ageText,
            zodiacText: human.birthday.map { Human.westernZodiacDisplay(for: $0, isEnglish: false) },
            genderText: human.roleText,
            avatarImageData: human.avatarImageData,
            themeColorHex: hex,
            daysTogether:  days,
            isHuman: true,
            isReal: true,
            actions: [.init(label: "WEIGHT",  icon: "scalemass",  colorHex: "80FFEA"),
                      .init(label: "WORKOUT", icon: "figure.run",  colorHex: "C8FF00"),
                      .init(label: "NOTE",    icon: "note.text",   colorHex: "5B6AFF")]
        )
    }

    static let dummies: [FocusCard] = [
        FocusCard(id: UUID(), name: "Mochi", kind: "DOG", emoji: "🐶",
                  color: Color(hex: "F4A7B9"), streak: 7, coconutBalance: 42,
                  petSpecies: "狗", coatColor: Color(hex: "D7A76D"), eyeColor: Color(hex: "57341E"),
                  isDummy: true,
                  actions: [.init(label: "FEED",  icon: "fork.knife",  colorHex: "FFDD44"),
                             .init(label: "WALK",  icon: "figure.walk", colorHex: "C8FF00"),
                             .init(label: "WATER", icon: "drop",        colorHex: "00D4AA"),
                             .init(label: "POTTY", icon: "allergens",   colorHex: "A78BFA")]),

        FocusCard(id: UUID(), name: "Luna", kind: "CAT", emoji: "🐱",
                  color: Color(hex: "C9B6E4"), streak: 12, coconutBalance: 66,
                  petSpecies: "猫", coatColor: Color(hex: "9CA7B2"), eyeColor: Color(hex: "7A4E20"),
                  isDummy: true,
                  actions: [.init(label: "FEED",   icon: "fork.knife", colorHex: "FFDD44"),
                             .init(label: "WATER",  icon: "drop",        colorHex: "00D4AA"),
                             .init(label: "LITTER", icon: "trash",       colorHex: "5B6AFF"),
                             .init(label: "PLAY",   icon: "sparkles",    colorHex: "F472B6")]),

        FocusCard(id: UUID(), name: "Alex", kind: "HUMAN", emoji: "🧑‍💻",
                  color: Color(hex: "B9E8D2"), streak: 3, coconutBalance: 18,
                  isHuman: true, isDummy: true,
                  actions: [.init(label: "WEIGHT",  icon: "scalemass",  colorHex: "80FFEA"),
                             .init(label: "WORKOUT", icon: "figure.run", colorHex: "C8FF00"),
                             .init(label: "NOTE",    icon: "note.text",  colorHex: "5B6AFF")]),

        FocusCard(id: UUID(), name: "Nemo", kind: "FISH", emoji: "🐟",
                  color: Color(hex: "C7E7F1"), streak: 4, coconutBalance: 24,
                  petSpecies: "鱼", isDummy: true,
                  actions: [.init(label: "FEED",   icon: "fork.knife",             colorHex: "FFDD44"),
                             .init(label: "WATER",  icon: "drop.circle",            colorHex: "00D4AA"),
                             .init(label: "FILTER", icon: "wrench.and.screwdriver", colorHex: "A78BFA")]),
    ]
}

// ─────────────────────────────────────────────────
// MARK: – Layout constants
// ─────────────────────────────────────────────────

private enum K {
    static let bg    = Color(hex: "F8D8DF")
    static let ink   = Color(hex: "23181A")
    static let muted = Color(hex: "8B6E74")

    static let hPad: CGFloat = 20        // header padding
    static let cardMargin: CGFloat = 7   // card-to-screen-edge gap (= hPad / 3)
    static let cardH: CGFloat = 200
    static let expandedCardH: CGFloat = 360
    static let stackPeekH: CGFloat = 38
    static let cardTitleH: CGFloat = 76
    // Visible gap between front card's bottom edge and the GeometryReader's bottom edge.
    // Must clear the FAB (≈80pt above safe area: 24pt padding + 56pt circle) and the
    // home indicator (34pt) with comfortable breathing room.
    static let stackBottomGap: CGFloat = 220
    static let expandedStackBottomGap: CGFloat = 12
    // Global target for expanded card's top: safe-area top + this offset.
    // Keep the active card directly below the top controls so
    // the quick modules below it remain visible above the compressed card stack.
    static let expandedCardGlobalTopOffset: CGFloat = 76
    static let expandedQuickModuleH: CGFloat = 112
    static let expandedQuickModuleEditH: CGFloat = 206
    static var stackSpacing: CGFloat { -(cardH - stackPeekH) }

    static let heroMargin: CGFloat = 16
    static let focusCardPadding: CGFloat = heroMargin / 3
}

private enum HeroAnim {
    static let stackCardCorner: CGFloat = 24
    static var transitionSpring: Animation {
        .interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.8)
    }
    // Apple-Wallet-style card morph: quick, restrained, slight overshoot.
    static var walletSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.85)
    }
    // Compact-mode peek (how much of each non-active card shows behind the active one)
    static let compactPeek: CGFloat = 14
}

private struct HeroShellID: Hashable { let cardId: UUID }
private struct HeroArtID:  Hashable { let cardId: UUID }

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

    @Environment(\.ohanaDisplayCornerRadius) private var displayCornerRadius
    @Environment(\.modelContext) private var modelContext
    @Bindable private var questMgr = QuestManager.shared
    @Query(sort: \Pet.createdAt,   order: .reverse) private var pets:   [Pet]
    @Query(sort: \Human.createdAt, order: .reverse) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query private var allHumanMedications: [HumanMedication]
    @Query private var allMedicationLogs: [HumanMedicationLog]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(filter: #Predicate<Reminder> { $0.status == "failed" },
           sort: \Reminder.scheduledAt) private var failedReminders: [Reminder]
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    // Header state
    @State private var showingFunctionMenu = false
    @State private var showStreakDetail    = false
    @State private var fabExpanded         = false
    @State private var showingCoconutLog   = false
    @State private var showingAddEntity    = false
    @State private var showingSettings     = false
    @State private var showingCrewRoster   = false
    @State private var showingCalendar     = false
    @State private var familyActivityPet: Pet? = nil
    @State private var weeklyReportPet: Pet? = nil
    @State private var calendarEntityFilterId: String? = nil
    @State private var showingOasisReward  = false
    @State private var cardFabExpanded     = false
    @State private var expandedAllFeaturesPet: Pet? = nil
    @State private var expandedAllFeaturesHuman: Human? = nil
    @State private var pressedExpandedActionId: String? = nil
    @State private var expandedQuickWeightPet: Pet? = nil
    @State private var expandedQuickExpensePet: Pet? = nil
    @State private var expandedQuickWeightDetailPet: Pet? = nil
    @State private var expandedQuickExpenseDetailPet: Pet? = nil
    @State private var expandedQuickFeedDetailPet: Pet? = nil
    @State private var expandedQuickWaterDetailPet: Pet? = nil
    @State private var expandedQuickWaterDetailModeRaw: String? = nil
    @State private var expandedQuickPottyDetailPet: Pet? = nil
    @State private var expandedQuickPlayDetailPet: Pet? = nil
    @State private var expandedQuickHygienePet: Pet? = nil
    @State private var expandedQuickWalkPet: Pet? = nil
    @State private var expandedQuickHealthPet: Pet? = nil
    @State private var expandedQuickMomentPet: Pet? = nil
    @State private var expandedQuickHumanWeight: Human? = nil
    @State private var expandedQuickHumanWorkout: Human? = nil
    @State private var expandedQuickHumanMedicationAdd: Human? = nil
    @State private var expandedQuickHumanMedication: Human? = nil
    @State private var expandedQuickHumanNote: Human? = nil
    @State private var expandedHumanWeightDetail: Human? = nil
    @State private var expandedHumanWorkoutDetail: Human? = nil
    @State private var isExpandedQAEditMode = false
    @State private var expandedQAJiggle = false
    @State private var expandedQAEditItems: [QuickActionItem] = []
    @State private var showingExpandedQAQuickAdd = false
    @State private var showingQuickActionLimitAlert = false
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)? = nil
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""
    @State private var showingHumanPrivacyAlert = false
    @State private var expandedActionPulseCardId: UUID? = nil
    @State private var walkTransformBurstCardId: UUID? = nil
    @State private var showExpandedCoconutReward = false
    @State private var expandedCoconutRewardAmount = 0
    @State private var expandedCoconutRewardLabel: String? = nil

    // Debug-only: show Mochi/Luna dummy stack even when real data is empty.
    @AppStorage("debugShowDummyCards") private var showDummyCards: Bool = false
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr: String = ""
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false

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
    // Tapping cards only changes the wallet state. Detail navigation remains in the
    // long-press context menu for real data.
    @State private var isExpanded: Bool = false
    @State private var activeCardId: UUID?

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

    private var headerStreak: Int {
        pets.map { $0.currentStreak }.max() ?? 0
    }

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }

    private var cards: [FocusCard] {
        let real = pets.filter { !$0.hasPassedAway }.map { FocusCard.from($0) }
                 + humans.map { FocusCard.from($0) }
        if !real.isEmpty { return real }
        // Real empty state → no dummy fallback (handled by EmptyStateWelcomeCard in stackLayer).
        // Debug flag preserves the old Mochi/Luna stack for UI exploration.
        guard showDummyCards else { return [] }
        let usedNames = Set(real.map { $0.name })
        let extras = FocusCard.dummies.filter { !usedNames.contains($0.name) }
        return real + extras
    }

    private var isEmptyState: Bool {
        pets.allSatisfy { $0.hasPassedAway } && humans.isEmpty && !showDummyCards
    }

    var body: some View {
        let windowSize = ScreenCompat.bounds.size
        let outerR = displayCornerRadius

        return GeometryReader { geo in
            ZStack {
                ArkBackgroundView()

                stackLayer(geo: geo, outerCornerRadius: outerR)
                    .opacity(expandedId == nil ? 1 : 0)
                    .allowsHitTesting(expandedId == nil)

                if let id = expandedId,
                   let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo, outerCornerRadius: outerR, windowSize: windowSize)
                }

                if expandedId == nil, isExpanded, !cards.isEmpty {
                    expandedWalletLayer(cards: cards, geo: geo)
                }

                // FAB: only visible when card stack is shown (not in card-expand mode)
                if expandedId == nil && !isExpanded {
                    // Dim scrim when FAB is open
                    if fabExpanded {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation(.spring(response: 0.3)) { fabExpanded = false } }
                            .transition(.opacity)
                    }
                    fabOverlay(geo: geo)
                }
            }
            .animation(HeroAnim.transitionSpring, value: expandedId)
            .onChange(of: expandedId) { _, newId in
                if newId != nil {
                    detailFooterVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(.easeOut(duration: 0.38)) { detailFooterVisible = true }
                    }
                } else {
                    detailFooterVisible = false
                    // Collapse wallet hero mode when bloom closes
                    withAnimation(HeroAnim.walletSpring) { isExpanded = false }
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
        .sheet(isPresented: $showingFunctionMenu) {
            FunctionMenuSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showStreakDetail) { DailyStreakDetailView(pets: pets) }
        .fullScreenCover(isPresented: $showingCoconutLog) { IslandWealthDashboardView() }
        .sheet(isPresented: $showingAddEntity) { AddEntityView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingCrewRoster) {
            NavigationStack {
                CrewRosterOverlay(
                    onSelectPet:   { pet   in showingCrewRoster = false; selectedPetTab = .overview; selectedPet = pet },
                    onSelectHuman: { human in showingCrewRoster = false; selectedHuman = human }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingCrewRoster = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCalendar, onDismiss: { calendarEntityFilterId = nil }) {
            CalendarView(preselectedPetId: calendarEntityFilterId)
        }
        .sheet(item: $familyActivityPet) { pet in
            NavigationStack {
                ScrollView {
                    FamilyActivityStripView(pet: pet, style: .full)
                        .padding(.vertical, 20)
                }
                .navigationTitle("谁在照顾 \(pet.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { familyActivityPet = nil }
                            .foregroundStyle(Color.goPrimary)
                    }
                }
            }
        }
        .sheet(item: $weeklyReportPet) { _ in
            NavigationStack {
                FamilyWeeklyReportDashboardView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { weeklyReportPet = nil }
                            .foregroundStyle(Color.goPrimary)
                    }
                }
            }
        }
        .sheet(item: $expandedAllFeaturesPet) { pet in
            PetAllFeaturesSheet(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedAllFeaturesHuman) { human in
            ExpandedHumanFeaturesSheet(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickWeightPet) { pet in
            GenericWeightEntrySheet(
                target: .pet(pet),
                onRewarded: { delta in
                    triggerExpandedActionFeedback(
                        cardId: pet.id,
                        coconutDelta: delta,
                        label: delta > 0 ? "体重记录 +\(delta)🥥" : nil
                    )
                }
            )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
        .sheet(item: $expandedQuickExpensePet) { pet in
            AddExpenseSheet(
                pet: pet,
                preselectedPayerId: UserDefaults.standard.string(forKey: "currentActiveHumanId")
            )
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
            QuickFeedDetailSheet(pet: pet) { expandedQuickFeedDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickWaterDetailPet) { pet in
            QuickWaterDetailSheet(
                pet: pet,
                initialModeRaw: expandedQuickWaterDetailModeRaw,
                lockedModeRaw: expandedQuickWaterDetailModeRaw
            ) {
                expandedQuickWaterDetailPet = nil
                expandedQuickWaterDetailModeRaw = nil
            }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .onDisappear { expandedQuickWaterDetailModeRaw = nil }
        }
        .sheet(item: $expandedQuickPottyDetailPet) { pet in
            QuickPottyDetailSheet(pet: pet) { expandedQuickPottyDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $expandedQuickPlayDetailPet) { pet in
            QuickPlayDetailSheet(pet: pet) { expandedQuickPlayDetailPet = nil }
                .presentationDetents([.fraction(0.86), .large])
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
        .sheet(item: $expandedQuickHealthPet) { pet in
            NavigationStack { PetHealthDetailView(pet: pet, isModal: true) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickMomentPet) { pet in
            NavigationStack {
                QuickMomentSheet(pet: pet, onRemove: nil)
                    .navigationTitle("记录时刻")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { expandedQuickMomentPet = nil }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $expandedQuickHumanWeight) { human in
            GenericWeightEntrySheet(
                target: .human(human),
                onSaved: {
                    triggerExpandedActionFeedback(cardId: human.id)
                }
            )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
        .onChange(of: selectedPet)   { _, new in if new == nil { withAnimation(HeroAnim.walletSpring) { isExpanded = false } } }
        .onChange(of: selectedHuman) { _, new in if new == nil { withAnimation(HeroAnim.walletSpring) { isExpanded = false } } }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Stack layer
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    private func stackLayer(geo: GeometryProxy, outerCornerRadius: CGFloat) -> some View {
        let activePets = pets.filter { !$0.hasPassedAway }
        return VStack(spacing: 0) {
            goFocusHeader(safeT: safeAreaTop)

            todayFocusSection(activePets: activePets)

            if isEmptyState {
                Spacer(minLength: 0)
                EmptyStateWelcomeCard(
                    onAddPet:   { showingAddEntity = true },
                    onAddHuman: { showingAddEntity = true }
                )
                .padding(.horizontal, K.cardMargin)
                .padding(.bottom, 24)
            } else if !isExpanded {
                // GeometryReader-based stack fills all remaining space below mood strip
                walletCardStack(cards: cards)
                    .padding(.horizontal, K.cardMargin)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func todayFocusSection(activePets: [Pet]) -> some View {
        // Collapsed first screen answers: who needs care, what is urgent, what can be done now.
        if !activePets.isEmpty && !isExpanded {
            TodayFocusCarousel(cardMargin: K.cardMargin, animation: HeroAnim.walletSpring) { cardWidth in
                TodayFocusCard(
                    pets: activePets,
                    plants: plants,
                    quests: IslandQuestEngine.todayQuests(
                        pets: activePets,
                        reminders: pendingReminders,
                        plants: plants,
                        events: allEvents
                    ),
                    activePet: todayFocusActivePet,
                    onCompleteQuest: { completeQuestInFocusStack($0) },
                    onTapOasis: { showingOasisReward = true }
                )
                .frame(width: cardWidth)

                if showFirstSuccessCard,
                   !firstQuickCheckInCompleted,
                   let pet = todayFocusActivePet {
                    HomeFirstSuccessCard(pet: pet) {
                        completeFirstSuccessCheckIn(for: pet)
                    }
                    .frame(width: cardWidth)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let pet = todayFocusActivePet {
                    HomeFamilyCollaborationCard(
                        pet: pet,
                        pendingReminders: pendingReminders,
                        humans: humans,
                        onOpenActivity: { familyActivityPet = pet },
                        onOpenWeeklyReport: { weeklyReportPet = pet }
                    )
                    .frame(width: cardWidth)
                }
            }
            .animation(HeroAnim.walletSpring, value: isExpanded)
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
        let inactiveBottomY = geo.size.height
        let quickModulesTopY = activeTopY + K.expandedCardH + 14

        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let isHero = card.id == heroId
                let visibleHeight = isHero ? K.expandedCardH : K.stackPeekH

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
                .contextMenu { cardContextMenu(card: card) }
                .onTapGesture { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                .simultaneousGesture(collapseWalletDragGesture())
                .animation(HeroAnim.walletSpring, value: isExpanded)
                .animation(HeroAnim.walletSpring, value: activeCardId)
            }

            if let activeCard = cards.first(where: { $0.id == heroId }) {
                let quickModuleH = expandedQuickModuleHeight(for: activeCard)
                expandedQuickModules(card: activeCard)
                    .frame(width: cardW, height: quickModuleH)
                    .offset(x: K.cardMargin, y: quickModulesTopY)
                    .zIndex(Double(n + 80))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .simultaneousGesture(collapseWalletDragGesture())
                    .animation(HeroAnim.walletSpring, value: activeCardId)

                expandedCardFab(card: activeCard, safeBottom: geo.safeAreaInsets.bottom)
                    .frame(width: cardW, alignment: .trailing)
                    .offset(x: K.cardMargin, y: geo.size.height - geo.safeAreaInsets.bottom - 74)
                    .zIndex(Double(n + 120))
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

    private func collapseWalletDragGesture() -> some Gesture {
        DragGesture()
            .onEnded { v in
                guard v.translation.height > 80 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(HeroAnim.walletSpring) { isExpanded = false }
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
        let avatar = pet.avatarImageData.flatMap { UIImage(data: $0) }
        let themeHex = pet.themeColorHex.isEmpty ? nil : pet.themeColorHex

        return VStack(spacing: 8) {
            HStack {
                Text("快捷操作")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(2.6)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isExpandedQAEditMode {
                        exitExpandedQAEditMode(for: pet)
                    } else {
                        enterExpandedQAEditMode(for: pet)
                    }
                } label: {
                    Image(systemName: isExpandedQAEditMode ? "checkmark.circle.fill" : "pencil")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(isExpandedQAEditMode ? Color.goLime : .white.opacity(0.78))
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    expandedQuickActionGridItem(
                        idx: idx,
                        item: item,
                        pet: pet,
                        avatar: avatar,
                        themeHex: themeHex
                    )
                }

                if isExpandedQAEditMode {
                    expandedQuickAddButton(pet: pet)
                }
            }
        }
        .padding(.horizontal, 2)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private func expandedHumanQuickActions(human: Human) -> some View {
        let items = isExpandedQAEditMode
            ? expandedQAEditItems
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let avatar = human.avatarImageData.flatMap { UIImage(data: $0) }
        let themeHex = human.themeColorHex.isEmpty ? nil : human.themeColorHex

        return VStack(spacing: 8) {
            HStack {
                Text("快捷操作")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(2.6)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isExpandedQAEditMode {
                        exitExpandedHumanQAEditMode(for: human)
                    } else {
                        enterExpandedHumanQAEditMode(for: human)
                    }
                } label: {
                    Image(systemName: isExpandedQAEditMode ? "checkmark.circle.fill" : "pencil")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(isExpandedQAEditMode ? Color.goLime : .white.opacity(0.78))
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    expandedHumanQuickActionGridItem(
                        idx: idx,
                        item: item,
                        human: human,
                        avatar: avatar,
                        themeHex: themeHex
                    )
                }

                if isExpandedQAEditMode {
                    expandedHumanQuickAddButton(human: human)
                }
            }
        }
        .padding(.horizontal, 2)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    @ViewBuilder
    private func expandedQuickActionGridItem(idx: Int, item: QuickActionItem, pet: Pet, avatar: UIImage?, themeHex: String?) -> some View {
        ZStack {
            GoQuickActionCard(
                item: item,
                isPressed: !isExpandedQAEditMode && pressedExpandedActionId == item.id,
                petAvatar: avatar,
                petThemeColorHex: themeHex,
                countText: isExpandedQAEditMode ? nil : expandedQuickCountText(for: item, pet: pet),
                isCompletedToday: !isExpandedQAEditMode && expandedQuickActionCompleted(item, pet: pet),
                prefersLightForeground: true,
                onTap: {
                    guard !isExpandedQAEditMode else { return }
                    pressedExpandedActionId = item.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        pressedExpandedActionId = nil
                        handleExpandedQuickAction(item, pet: pet)
                    }
                },
                onLongPress: isExpandedQAEditMode ? nil : { handleExpandedQuickLongPress(item, pet: pet) },
                onGroomCheckIn: (!isExpandedQAEditMode && item.actionType == "groom") ? { raw in
                    applyExpandedGroomCheckIn(raw, pet: pet)
                } : nil,
                onPottySelect: (!isExpandedQAEditMode && item.actionType == "potty") ? { raw in
                    applyExpandedPottyCheckIn(raw, pet: pet)
                } : nil,
                onHealthSelect: (!isExpandedQAEditMode && item.actionType == "health") ? { raw in
                    applyExpandedHealthCheckIn(raw, pet: pet)
                } : nil
            )
            .allowsHitTesting(!isExpandedQAEditMode)

            if isExpandedQAEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeHex)
            }
        }
        .rotationEffect(.degrees(isExpandedQAEditMode ? (expandedQAJiggle ? -2.5 : 2.5) : 0))
        .animation(
            isExpandedQAEditMode
                ? .easeInOut(duration: 0.12 + Double(idx % 4) * 0.015).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
            value: expandedQAJiggle
        )
        .overlay(alignment: .topLeading) {
            if isExpandedQAEditMode {
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    withAnimation(.spring(response: 0.3)) {
                        expandedQAEditItems.removeAll { $0.id == item.id }
                    }
                } label: {
                    ZStack {
                        Circle().fill(Color.goRed).frame(width: 20, height: 20)
                        Image(systemName: "minus")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
            }
        }
        .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(targetItem: item, items: $expandedQAEditItems))
    }

    private func expandedQuickAddButton(pet: Pet) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard QuickActionLimit.count(for: pet, in: expandedQAEditItems) < QuickActionLimit.maxItemsPerEntity else {
                showingQuickActionLimitAlert = true
                return
            }
            showingExpandedQAQuickAdd = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goLime)
                }
                Text("添加")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), style: StrokeStyle(lineWidth: 1.4, dash: [5]))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingExpandedQAQuickAdd, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            QAQuickAddPopoverContent(pet: pet, existingItems: expandedQAEditItems) { newItem in
                withAnimation(.spring(response: 0.3)) {
                    if QuickActionLimit.count(for: pet, in: expandedQAEditItems) < QuickActionLimit.maxItemsPerEntity {
                        expandedQAEditItems.append(newItem)
                    }
                }
            }
            .presentationCompactAdaptation(.popover)
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    @ViewBuilder
    private func expandedHumanQuickActionGridItem(idx: Int, item: QuickActionItem, human: Human, avatar: UIImage?, themeHex: String?) -> some View {
        ZStack {
            GoQuickActionCard(
                item: item,
                isPressed: !isExpandedQAEditMode && pressedExpandedActionId == item.id,
                petAvatar: avatar,
                petThemeColorHex: themeHex,
                countText: isExpandedQAEditMode ? nil : expandedHumanQuickCountText(for: item, human: human),
                privacyBadgeText: isExpandedQAEditMode ? nil : expandedHumanPrivacyBadgeText(for: item, human: human),
                isPrivacyLocked: !isExpandedQAEditMode && expandedHumanQuickActionIsPrivate(item, human: human),
                isCompletedToday: !isExpandedQAEditMode && expandedHumanQuickActionCompleted(item, human: human),
                prefersLightForeground: true,
                onTap: {
                    guard !isExpandedQAEditMode else { return }
                    pressedExpandedActionId = item.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        pressedExpandedActionId = nil
                        handleExpandedHumanQuickAction(item, human: human)
                    }
                },
                onLongPress: isExpandedQAEditMode ? nil : {
                    handleExpandedHumanQuickLongPress(item, human: human)
                }
            )
            .allowsHitTesting(!isExpandedQAEditMode)

            if isExpandedQAEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeHex)
            }
        }
        .rotationEffect(.degrees(isExpandedQAEditMode ? (expandedQAJiggle ? -2.5 : 2.5) : 0))
        .animation(
            isExpandedQAEditMode
                ? .easeInOut(duration: 0.12 + Double(idx % 4) * 0.015).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
            value: expandedQAJiggle
        )
        .overlay(alignment: .topLeading) {
            if isExpandedQAEditMode {
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    withAnimation(.spring(response: 0.3)) {
                        expandedQAEditItems.removeAll { $0.id == item.id }
                    }
                } label: {
                    ZStack {
                        Circle().fill(Color.goRed).frame(width: 20, height: 20)
                        Image(systemName: "minus")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
            }
        }
        .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(targetItem: item, items: $expandedQAEditItems))
    }

    private func expandedHumanQuickAddButton(human: Human) -> some View {
        Menu {
            if expandedQAEditItems.count >= QuickActionLimit.maxItemsPerEntity {
                Button("已达 8 个上限，可去「全部功能」查看更多") {
                    showingQuickActionLimitAlert = true
                }
            }
            let existing = Set(expandedQAEditItems.map(\.actionType))
            ForEach(defaultExpandedHumanQuickActions(for: human).filter { !existing.contains($0.actionType) }) { item in
                Button {
                    guard expandedQAEditItems.count < QuickActionLimit.maxItemsPerEntity else {
                        showingQuickActionLimitAlert = true
                        return
                    }
                    withAnimation(.spring(response: 0.3)) {
                        expandedQAEditItems.append(item)
                    }
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goLime)
                }
                Text("添加")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), style: StrokeStyle(lineWidth: 1.4, dash: [5]))
            )
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private func legacyExpandedQuickModules(card: FocusCard) -> some View {
        HStack(spacing: 10) {
            ForEach(card.actions.prefix(4)) { action in
                Button {
                    performExpandedQuickAction(action, for: card)
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(hex: action.colorHex).opacity(0.22))
                                .frame(width: 34, height: 34)
                            Image(systemName: action.icon)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color(hex: action.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(expandedQuickActionTitle(action.label))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(card.isReal && !card.isHuman ? "快速打卡" : "查看")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.7)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(card.name) \(expandedQuickActionTitle(action.label))")
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private func expandedWalletOffsetY(idx: Int, n: Int, bottomY: CGFloat,
                                       heroId: UUID?, heroTopY: CGFloat, cards: [FocusCard]) -> CGFloat {
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        if idx == heroIdx { return heroTopY }
        let cr = idx < heroIdx ? idx : idx - 1
        let inactiveCount = max(1, n - 1)
        return bottomY - CGFloat(inactiveCount - cr) * K.stackPeekH
    }

    @ViewBuilder
    private func walletCardStack(cards: [FocusCard]) -> some View {
        let n = cards.count
        let heroId = activeCardId ?? cards.first?.id

        GeometryReader { geo in
            // Anchor card stack relative to GR's bottom edge (more robust than
            // global-coord math, which can read stale during initial layout).
            // K.stackBottomGap = visible space between front card's bottom and the GR's bottom.
            // Add the bottom safe-area inset (home indicator) so the gap is on top of it.
            let bottomInset = max(safeAreaBottom, geo.safeAreaInsets.bottom)
            let collapsedBottomY = max(K.cardH, geo.size.height - bottomInset - K.stackBottomGap)
            let expandedBottomY = max(K.stackPeekH, geo.size.height - bottomInset - K.expandedStackBottomGap)
            let stackBottomY = isExpanded ? expandedBottomY : collapsedBottomY
            let heroTopY = safeAreaTop + K.expandedCardGlobalTopOffset - geo.frame(in: .global).minY

            ZStack(alignment: .topLeading) {
                // Add button floats above the fan, hidden in hero mode.
                if !isExpanded {
                    HStack {
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingAddEntity = true
                        } label: {
                            addMemberCapsuleLabel
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("添加成员")
                    }
                    .offset(y: max(0, stackBottomY - fanHeight(n: n, bottomY: stackBottomY) - 44))
                    .animation(HeroAnim.walletSpring, value: isExpanded)
                    .zIndex(999)
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    let isHero = isExpanded && card.id == heroId
                    let visibleHeight = isHero ? K.expandedCardH : (isExpanded ? K.stackPeekH : K.cardH)

                    transformedWalletCard(card: card, isHero: isHero)
                        .frame(height: isHero ? K.expandedCardH : K.cardH)
                        .frame(height: visibleHeight, alignment: .top)
                        .clipped()
                        .frame(maxWidth: .infinity)
                        .overlay { expandedActionPulseOverlay(for: card.id) }
                        .overlay { walkTransformBurstOverlay(for: card.id) }
                        .shadow(
                            color: .black.opacity(isHero ? 0.22 : 0.09),
                            radius: isHero ? 20 : 7,
                            x: 0, y: isHero ? 12 : 4
                        )
                        .scaleEffect(
                            (isHero ? 1.0 : (isExpanded ? 0.97 : 1.0)) *
                            (expandedActionPulseCardId == card.id ? 1.025 : 1.0),
                            anchor: .top
                        )
                        .offset(y: walletOffsetY(idx: idx, n: n, bottomY: stackBottomY,
                                                  heroId: heroId, heroTopY: heroTopY, cards: cards))
                        .zIndex(walletZIndex(idx: idx, n: n, isHero: isHero,
                                             heroId: heroId, cards: cards))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(card.name) 的卡片")
                        .accessibilityHint(isHero ? "再次点击收起卡片堆" :
                                          (isExpanded ? "点击选为当前卡片" : "点击展开查看"))
                        .contextMenu { cardContextMenu(card: card) }
                        .onTapGesture { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                        .animation(HeroAnim.walletSpring, value: isExpanded)
                        .animation(HeroAnim.walletSpring, value: activeCardId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Swipe-down anywhere collapses hero back to fan
            .gesture(
                DragGesture()
                    .onEnded { v in
                        guard isExpanded, v.translation.height > 80 else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(HeroAnim.walletSpring) { isExpanded = false }
                    }
            )
            .onAppear {
                if activeCardId == nil || !cards.contains(where: { $0.id == activeCardId }) {
                    activeCardId = cards.first?.id
                }
            }
        }
    }

    private var addMemberCapsuleLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 11, weight: .semibold))
            Text("添加")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.58))
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    // Total height of the fan stack (used to anchor it at the bottom of bottomY).
    private func fanHeight(n: Int, bottomY: CGFloat) -> CGFloat {
        CGFloat(max(0, n - 1)) * stackPeek(n: n, bottomY: bottomY) + K.cardH
    }

    private func stackPeek(n: Int, bottomY: CGFloat) -> CGFloat {
        guard n > 1 else { return 0 }
        let maxPeekThatKeepsBottomCardVisible = max(0, (bottomY - K.cardH) / CGFloat(n - 1))
        return min(K.stackPeekH, maxPeekThatKeepsBottomCardVisible)
    }

    // Fan  — cards anchored at container bottom, fanning upward.
    //   idx=0 is the backmost (topmost in fan), idx=n-1 is frontmost (at very bottom).
    //   y_i = bottomY − cardH − (n−1−i) × stackPeek
    //
    // Hero — hero card snaps just below the coconut/check-in buttons.
    //   Non-hero cards compress at the screen bottom; each card only reveals its
    //   top identity strip.
    //   compressedRank r = (idx < heroIdx ? idx : idx−1)
    //   y = bottomY − (inactiveCount−r) × stackPeekH
    private func walletOffsetY(idx: Int, n: Int, bottomY: CGFloat,
                               heroId: UUID?, heroTopY: CGFloat, cards: [FocusCard]) -> CGFloat {
        if !isExpanded {
            return bottomY - K.cardH - CGFloat(n - 1 - idx) * stackPeek(n: n, bottomY: bottomY)
        }
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        if idx == heroIdx { return heroTopY }
        let cr = idx < heroIdx ? idx : idx - 1
        let inactiveCount = max(1, n - 1)
        return bottomY - CGFloat(inactiveCount - cr) * K.stackPeekH
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
    // Hero: tap active card → restore fan; tap another card → switch active card.
    //       Swipe-down → restore fan (via DragGesture above).
    private func handleWalletCardTap(card: FocusCard, n: Int, isHero: Bool) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if n <= 1 {
            withAnimation(HeroAnim.walletSpring) {
                activeCardId = card.id
                isExpanded.toggle()
            }
            return
        }

        if isHero {
            withAnimation(HeroAnim.walletSpring) {
                isExpanded = false
            }
        } else if isExpanded {
            withAnimation(HeroAnim.walletSpring) {
                activeCardId = card.id
            }
        } else {
            withAnimation(HeroAnim.walletSpring) {
                activeCardId = card.id
                isExpanded = true
            }
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
                isHeroExpanded: isHero
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
        .animation(.spring(response: 0.44, dampingFraction: 0.74), value: showWalkCard)
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
        withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
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
            withAnimation(.easeOut(duration: 0.22)) {
                expandedActionPulseCardId = nil
            }
        }
    }

    private func completeFirstSuccessCheckIn(for pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let coconutBefore = QuestManager.shared.coconutCount
        let reward = QuestManager.OhanaActionType.general(
            humanReward: 10,
            petReward: 12,
            emoji: "🎾",
            title: "\(pet.name) 互动奖励"
        )
        _ = CareEventService.recordCare(
            pet: pet,
            type: .play,
            context: modelContext,
            executorId: executorId,
            reward: reward
        )
        let coconutDelta = max(0, QuestManager.shared.coconutCount - coconutBefore)
        withAnimation(HeroAnim.walletSpring) {
            activeCardId = pet.id
            isExpanded = true
        }
        triggerExpandedActionFeedback(
            cardId: pet.id,
            coconutDelta: coconutDelta,
            label: coconutDelta > 0 ? "第一次打卡 +\(coconutDelta)🥥" : nil
        )
        markFirstQuickCheckInCompletedIfNeeded()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func markFirstQuickCheckInCompletedIfNeeded() {
        guard showFirstSuccessCard, !firstQuickCheckInCompleted else { return }
        firstQuickCheckInCompleted = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showFirstSuccessCard = false
        }
    }

    private func triggerWalkCardTransform(for pet: Pet) {
        withAnimation(HeroAnim.walletSpring) {
            activeCardId = pet.id
            isExpanded = true
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
            walkTransformBurstCardId = pet.id
            expandedActionPulseCardId = pet.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard walkTransformBurstCardId == pet.id else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                walkTransformBurstCardId = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            guard expandedActionPulseCardId == pet.id else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                expandedActionPulseCardId = nil
            }
        }
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
        let items = stored.isEmpty ? defaultExpandedQuickActions(for: pet) : stored
        return ensureIndependentWaterChangeAction(in: items, for: pet)
    }

    private func ensureIndependentWaterChangeAction(in items: [QuickActionItem], for pet: Pet) -> [QuickActionItem] {
        let actionTypes = Set(items.map(\.actionType))
        guard actionTypes.contains("water"),
              !actionTypes.contains("waterChange"),
              QuickActionLimit.count(for: pet, in: items) < QuickActionLimit.maxItemsPerEntity
        else { return items }

        var result = items
        let waterChange = QuickActionItem(
            label: l.homeQAWaterChange,
            icon: "drop.circle.fill",
            colorHex: "4ECDC4",
            petId: pet.id,
            actionType: "waterChange",
            entityId: pet.id,
            entityKind: .pet
        )
        if let waterIndex = result.firstIndex(where: { $0.actionType == "water" }) {
            result.insert(waterChange, at: min(waterIndex + 1, result.count))
        } else {
            result.append(waterChange)
        }
        return result
    }

    private func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        let stored = savedQuickActionItems.filter { $0.entityId == human.id && $0.entityKind == .human }
        return stored.isEmpty ? defaultExpandedHumanQuickActions(for: human) : stored
    }

    private func enterExpandedQAEditMode(for pet: Pet) {
        expandedQAEditItems = expandedQuickActionItems(for: pet)
        withAnimation(.spring(response: 0.3)) {
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
        withAnimation(.spring(response: 0.3)) {
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
        saved.insert(contentsOf: Array(edited.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved),
           let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func enterExpandedHumanQAEditMode(for human: Human) {
        expandedQAEditItems = expandedHumanQuickActionItems(for: human)
        withAnimation(.spring(response: 0.3)) {
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
        withAnimation(.spring(response: 0.3)) {
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
        let isDog = pet.species.contains("狗") || pet.species.lowercased().contains("dog")
        let isCat = pet.species.contains("猫") || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")

        if isFish {
            return [
                QuickActionItem(label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44",
                                petId: pet.id, actionType: "feed", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4",
                                petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAFilterClean, icon: "wrench.and.screwdriver.fill", colorHex: "A78BFA",
                                petId: pet.id, actionType: "filterClean", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA",
                                petId: pet.id, actionType: "weight", entityId: pet.id, entityKind: .pet)
            ]
        }

        if isDog {
            return [
                QuickActionItem(label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44",
                                petId: pet.id, actionType: "feed", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA",
                                petId: pet.id, actionType: "water", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4",
                                petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWalk, icon: "figure.walk", colorHex: "C8FF00",
                                petId: pet.id, actionType: "walk", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAPotty, icon: "allergens", colorHex: "FF8C42",
                                petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet)
            ]
        }

        if isCat {
            return [
                QuickActionItem(label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44",
                                petId: pet.id, actionType: "feed", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA",
                                petId: pet.id, actionType: "water", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4",
                                petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQALitter, icon: "trash.fill", colorHex: "5B6AFF",
                                petId: pet.id, actionType: "litter", entityId: pet.id, entityKind: .pet),
                QuickActionItem(label: l.homeQAPotty, icon: "allergens", colorHex: "FF8C42",
                                petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet)
            ]
        }

        return [
            QuickActionItem(label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44",
                            petId: pet.id, actionType: "feed", entityId: pet.id, entityKind: .pet),
            QuickActionItem(label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA",
                            petId: pet.id, actionType: "water", entityId: pet.id, entityKind: .pet),
            QuickActionItem(label: l.homeQAWaterChange, icon: "drop.circle.fill", colorHex: "4ECDC4",
                            petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet),
            QuickActionItem(label: l.homeQAGroom, icon: "scissors", colorHex: "FF8C42",
                            petId: pet.id, actionType: "groom", entityId: pet.id, entityKind: .pet),
            QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA",
                            petId: pet.id, actionType: "weight", entityId: pet.id, entityKind: .pet)
        ]
    }

    private func defaultExpandedHumanQuickActions(for human: Human) -> [QuickActionItem] {
        [
            QuickActionItem(label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA",
                            actionType: "humanWeight", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQASport, icon: "figure.run", colorHex: "C8FF00",
                            actionType: "humanWorkout", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A",
                            actionType: "humanMedication", entityId: human.id, entityKind: .human),
            QuickActionItem(label: l.homeQANote, icon: "note.text", colorHex: "A78BFA",
                            actionType: "humanNote", entityId: human.id, entityKind: .human),
        ]
    }

    private func handleExpandedHumanQuickAction(_ item: QuickActionItem, human: Human) {
        guard !expandedHumanQuickActionIsPrivate(item, human: human) else {
            showingHumanPrivacyAlert = true
            return
        }
        switch item.actionType {
        case "humanWeight":
            expandedQuickHumanWeight = human
        case "humanWorkout":
            expandedQuickHumanWorkout = human
        case "humanMedication":
            expandedQuickHumanMedicationAdd = human
        case "humanNote":
            expandedQuickHumanNote = human
        default:
            selectedHuman = human
        }
    }

    private func handleExpandedHumanQuickLongPress(_ item: QuickActionItem, human: Human) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard !expandedHumanQuickActionIsPrivate(item, human: human) else {
            showingHumanPrivacyAlert = true
            return
        }

        switch item.actionType {
        case "humanWeight":
            expandedHumanWeightDetail = human
        case "humanWorkout":
            expandedHumanWorkoutDetail = human
        case "humanMedication":
            expandedQuickHumanMedication = human
        case "humanNote":
            selectedHuman = human
        default:
            selectedHuman = human
        }
    }

    private func handleExpandedQuickAction(_ item: QuickActionItem, pet: Pet) {
        switch item.actionType {
        case "feed": applyExpandedQuickAction("feed", pet: pet)
        case "walk": applyExpandedQuickAction("walk", pet: pet)
        case "water": applyExpandedQuickAction("water", pet: pet)
        case "waterChange": applyExpandedQuickAction("waterChange", pet: pet)
        case "play": applyExpandedQuickAction("play", pet: pet)
        case "litter": applyExpandedQuickAction("litter", pet: pet)
        case "filterClean": applyExpandedQuickAction("filterClean", pet: pet)
        case "weight": expandedQuickWeightPet = pet
        case "expense": expandedQuickExpensePet = pet
        case "moment": expandedQuickMomentPet = pet
        case "health": expandedQuickHealthPet = pet
        default: break
        }
    }

    private func handleExpandedQuickLongPress(_ item: QuickActionItem, pet: Pet) {
        switch item.actionType {
        case "feed": expandedQuickFeedDetailPet = pet
        case "water":
            expandedQuickWaterDetailModeRaw = QuickWaterDetailSheet.WaterMode.drink.rawValue
            expandedQuickWaterDetailPet = pet
        case "waterChange":
            expandedQuickWaterDetailModeRaw = QuickWaterDetailSheet.WaterMode.change.rawValue
            expandedQuickWaterDetailPet = pet
        case "walk": expandedQuickWalkPet = pet
        case "play": expandedQuickPlayDetailPet = pet
        case "potty", "litter": expandedQuickPottyDetailPet = pet
        case "groom", "filterClean": expandedQuickHygienePet = pet
        case "health": expandedQuickHealthPet = pet
        case "weight": expandedQuickWeightDetailPet = pet
        case "expense": expandedQuickExpenseDetailPet = pet
        case "moment": expandedQuickMomentPet = pet
        default: break
        }
    }

    private func expandedIsPlannedFeedReminder(_ reminder: Reminder, petIdStr: String) -> Bool {
        guard reminder.event?.relatedEntityId == petIdStr else { return false }
        let evType = reminder.event?.eventType ?? ""
        if evType == EventType.foodChange.rawValue { return true }
        if evType == EventType.daily.rawValue || evType == EventType.task.rawValue {
            let title = (reminder.event?.title ?? "").lowercased()
            return ["喂食", "吃饭", "喂"].contains { title.contains($0) }
        }
        return false
    }

    private func expandedPetHasPlannedFeedSchedules(_ pet: Pet) -> Bool {
        let petIdStr = pet.id.uuidString
        return allEvents.contains {
            ($0.relatedEntityType == EntityKind.pet.rawValue || $0.relatedEntityType == "pet")
                && $0.relatedEntityId == petIdStr
                && $0.eventType == EventType.foodChange.rawValue
        }
    }

    private func expandedPendingFeedReminderForPlannedMode(pet: Pet) -> Reminder? {
        guard HomeFeedRecordMode.isPlanned(for: pet.id) else { return nil }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return pendingReminders.first {
            cal.isDateInToday($0.scheduledAt) && expandedIsPlannedFeedReminder($0, petIdStr: petIdStr)
        }
    }

    private func expandedHasFailedPlannedFeedToday(pet: Pet) -> Bool {
        guard HomeFeedRecordMode.isPlanned(for: pet.id) else { return false }
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return failedReminders.contains {
            cal.isDateInToday($0.scheduledAt) && expandedIsPlannedFeedReminder($0, petIdStr: petIdStr)
        }
    }

    private func expandedFeedAppearsComplete(for pet: Pet) -> Bool {
        let cal = Calendar.current
        if HomeFeedRecordMode.isPlanned(for: pet.id) {
            guard expandedPetHasPlannedFeedSchedules(pet) else { return false }
            if expandedHasFailedPlannedFeedToday(pet: pet) { return false }
            return expandedPendingFeedReminderForPlannedMode(pet: pet) == nil
        }

        let storedGoal = UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)")
        let goal = storedGoal > 0 ? storedGoal : 3
        let manualCount = pet.careLogs.filter {
            cal.isDateInToday($0.date)
                && $0.type == CareType.feeding.rawValue
                && $0.isManualFeedLogEntry
        }.count
        return manualCount >= goal
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
            if HomeFeedRecordMode.isPlanned(for: pet.id) {
                if self.completeExpandedPlannedFeedFromHome(pet: pet) { return }
                self.expandedQuickFeedDetailPet = pet
                return
            }

            let coconutBefore = QuestManager.shared.coconutCount
            _ = CareEventService.recordManualFeed(
                pet: pet,
                amountGrams: pet.dailyPortionGrams,
                context: self.modelContext,
                executorId: executorId
            )
            let coconutDelta = max(0, QuestManager.shared.coconutCount - coconutBefore)
            self.triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: coconutDelta, label: coconutDelta > 0 ? "喂食 +\(coconutDelta)🥥" : nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        if let warning = AntiRepeatCareManager.checkRecentCareLog(
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

    private func applyExpandedQuickAction(_ actionType: String, pet: Pet) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }

        switch actionType {
        case "feed":
            performExpandedFeedCheckIn(pet: pet, executorId: executorId)
        case "water":
            let got = CareEventService.recordCare(pet: pet, type: .watering, amountMl: 250, context: modelContext, executorId: executorId, reward: .water)
            let delta = got.humanGot + got.petGot
            triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        case "waterChange":
            performExpandedSpecialCare(.waterChange, pet: pet, executorId: executorId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "filterClean":
            performExpandedSpecialCare(.filterClean, pet: pet, executorId: executorId)
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
        let log = PetHygieneLog(date: Date(), type: type, pet: pet)
        modelContext.insert(log)
        modelContext.safeSave()
        let got = QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
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
        switch raw {
        case "vaccine":
            modelContext.insert(PetHealthLog(date: Date(), type: .vaccine, note: "快捷打卡", pet: pet))
        case "deworming":
            modelContext.insert(PetHealthLog(date: Date(), type: .dewormingExternal, note: "快捷打卡", pet: pet))
        case "visit":
            modelContext.insert(PetHealthLog(date: Date(), type: .checkup, note: "快捷打卡", pet: pet))
        default:
            expandedQuickHealthPet = pet
            return
        }
        modelContext.safeSave()
        triggerExpandedActionFeedback(cardId: pet.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func expandedQuickActionCompleted(_ item: QuickActionItem, pet: Pet) -> Bool {
        let cal = Calendar.current
        switch item.actionType {
        case "feed":
            return expandedFeedAppearsComplete(for: pet)
        case "water":
            return pet.careLogs.contains { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }
        case "waterChange":
            return pet.careLogs.contains { $0.type == CareType.waterChange.rawValue && cal.isDateInToday($0.date) }
        case "walk":
            return pet.walkLogs.contains { cal.isDateInToday($0.startDate) }
        case "potty":
            return pet.pottyLogs.contains { cal.isDateInToday($0.date) }
        case "litter":
            return pet.careLogs.contains { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }
        case "play":
            return pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
        case "groom":
            return pet.hygieneLogs.contains { cal.isDateInToday($0.date) }
        case "filterClean":
            return pet.careLogs.contains { $0.type == CareType.filterClean.rawValue && cal.isDateInToday($0.date) }
        case "weight":
            return pet.weightLogs.contains { cal.isDateInToday($0.date) }
        default:
            return false
        }
    }

    private func expandedQuickCountText(for item: QuickActionItem, pet: Pet) -> String? {
        let cal = Calendar.current
        switch item.actionType {
        case "feed":
            let count = pet.careLogs.filter {
                $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) && $0.isManualFeedLogEntry
            }.count
            return count > 0 ? "手动 \(count)餐" : nil
        case "water":
            let count = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "waterChange":
            if let last = pet.careLogs.filter({ $0.type == CareType.waterChange.rawValue }).max(by: { $0.date < $1.date }) {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已换" : "\(days)天前"
            }
            return nil
        case "walk":
            let walks = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }
            guard !walks.isEmpty else { return "今日未遛" }
            let dist = walks.reduce(0.0) { $0 + $1.distanceMeters }
            let distText = dist >= 1000 ? String(format: "%.1fkm", dist / 1000) : String(format: "%.0fm", dist)
            return "今日 \(walks.count)次 · \(distText)"
        case "potty":
            let count = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "litter":
            let count = pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "play":
            let count = pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日逗玩 \(count)次" : "今日未逗玩"
        case "weight":
            if let last = pet.weightLogs.max(by: { $0.date < $1.date }) {
                return String(format: "%.1fkg", last.weight)
            }
            return nil
        case "expense":
            let total = pet.expenseLogs
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                .reduce(0.0) { $0 + $1.amount }
            return total > 0 ? "本月 ¥\(String(format: "%.0f", total))" : nil
        case "filterClean":
            if let last = pet.careLogs.filter({ $0.type == CareType.filterClean.rawValue }).max(by: { $0.date < $1.date }) {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已清" : "\(days)天前"
            }
            return nil
        default:
            return nil
        }
    }

    private func expandedHumanQuickActionCompleted(_ item: QuickActionItem, human: Human) -> Bool {
        guard !expandedHumanQuickActionIsPrivate(item, human: human) else { return false }
        let cal = Calendar.current
        switch item.actionType {
        case "humanWeight":
            return human.weightLogs.contains { cal.isDateInToday($0.date) }
        case "humanWorkout":
            return human.workoutLogs.contains { cal.isDateInToday($0.date) }
        case "humanMedication":
            let humanId = human.id.uuidString
            return allMedicationLogs.contains {
                $0.humanId == humanId &&
                cal.isDateInToday($0.scheduledTime) &&
                $0.status == .taken
            }
        default:
            return false
        }
    }

    private func expandedHumanQuickCountText(for item: QuickActionItem, human: Human) -> String? {
        guard !expandedHumanQuickActionIsPrivate(item, human: human) else { return nil }
        let cal = Calendar.current
        switch item.actionType {
        case "humanWeight":
            if let last = human.weightLogs.max(by: { $0.date < $1.date }) {
                return String(format: "%.1fkg", last.weight)
            }
            return nil
        case "humanWorkout":
            let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let count = human.workoutLogs.filter { $0.date >= cutoff }.count
            return count > 0 ? "近30天 \(count)次" : nil
        case "humanMedication":
            let humanId = human.id.uuidString
            let activeMedCount = allHumanMedications.filter {
                $0.humanId == humanId && $0.isActive && $0.isActiveToday
            }.count
            guard activeMedCount > 0 else { return nil }
            let takenToday = allMedicationLogs.filter {
                $0.humanId == humanId &&
                cal.isDateInToday($0.scheduledTime) &&
                $0.status == .taken
            }.count
            return "今日已服 \(takenToday)/\(activeMedCount)"
        default:
            return nil
        }
    }

    private func expandedHumanPrivacyField(for actionType: String) -> HumanPrivateField? {
        PrivacyService.field(forHumanAction: actionType)
    }

    private func expandedHumanQuickActionIsPrivate(_ item: QuickActionItem, human: Human) -> Bool {
        PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: activeHumanId)
    }

    private func expandedHumanPrivacyBadgeText(for item: QuickActionItem, human: Human) -> String? {
        guard let field = expandedHumanPrivacyField(for: item.actionType) else { return nil }
        return PrivacyService.badgeText(for: field, human: human, viewedBy: activeHumanId)
    }

    private func expandedQuickActionTitle(_ raw: String) -> String {
        switch raw.uppercased() {
        case "FEED": return "喂食"
        case "WALK": return "出行"
        case "WATER": return "喂水"
        case "POTTY": return "便便"
        case "LITTER": return "铲屎"
        case "PLAY": return "逗玩"
        case "FILTER": return "滤材"
        case "WEIGHT": return "体重"
        case "WORKOUT": return "运动"
        case "NOTE": return "记录"
        default: return raw.capitalized
        }
    }

    private func performExpandedQuickAction(_ action: FocusCard.Action, for card: FocusCard) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if card.isHuman {
            selectedHuman = humans.first(where: { $0.id == card.id })
            return
        }

        guard card.isReal,
              let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return
        }

        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }

        switch action.label.uppercased() {
        case "FEED":
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

        case "WATER":
            let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")
            let careType: CareType = isFish ? .waterChange : .watering
            let log = PetCareLog(
                date: Date(),
                type: careType,
                amountMl: isFish ? 0 : 250,
                pet: pet,
                executorId: executorId
            )
            modelContext.insert(log)
            if isFish {
                let reward = QuestManager.OhanaActionType.general(
                    humanReward: 15,
                    petReward: 20,
                    emoji: careType.emoji,
                    title: "\(pet.name) 换水奖励"
                )
                QuestManager.shared.awardAction(type: reward, pet: pet, context: modelContext)
            } else {
                QuestManager.shared.awardAction(type: .water, pet: pet, context: modelContext)
            }

        case "WALK":
            if case .idle = PetWalkingManager.shared.phase {
                PetWalkingManager.shared.start(pet: pet)
            }
            triggerWalkCardTransform(for: pet)

        case "POTTY":
            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)

        case "LITTER":
            let log = PetCareLog(date: Date(), type: .litter, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)

        case "PLAY":
            performExpandedSpecialCare(.play, pet: pet, executorId: executorId)

        case "FILTER":
            performExpandedSpecialCare(.filterClean, pet: pet, executorId: executorId)

        default:
            selectedPetTab = .overview
            selectedPet = pet
        }
    }

    private func performExpandedSpecialCare(_ type: CareType, pet: Pet, executorId: String?) {
        let reward: QuestManager.OhanaActionType
        switch type {
        case .play:
            reward = .general(humanReward: 10, petReward: 12, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            reward = .general(humanReward: 25, petReward: 40, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        default:
            reward = .general(humanReward: 3, petReward: 3, emoji: type.emoji, title: "\(pet.name) 打卡奖励")
        }
        let got = CareEventService.recordCare(pet: pet, type: type, context: modelContext, executorId: executorId, reward: reward)
        let delta = got.humanGot + got.petGot
        triggerExpandedActionFeedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil)
    }

    private func completeQuestInFocusStack(_ quest: IslandQuest) {
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let activePets = pets.filter { !$0.hasPassedAway }

        if quest.id.hasPrefix("q_feed_") {
            if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                let log = PetCareLog(date: Date(), type: .feeding,
                                     amountGrams: p.dailyPortionGrams,
                                     note: PetCareLog.manualFeedNoteMarker, pet: p, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
                QuestManager.shared.recordFirstMeal()
            }
        } else if quest.id.hasPrefix("q_water_") && !quest.id.hasPrefix("q_water_plant") {
            if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                let log = PetCareLog(date: Date(), type: .waterChange, pet: p, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
            }
        } else {
            switch quest.id {
            case "q_walk":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }),
                   case .idle = PetWalkingManager.shared.phase {
                    PetWalkingManager.shared.start(pet: p)
                }
            case "q_potty":
                if let id = quest.targetPetId, let p = activePets.first(where: { $0.id == id }) {
                    let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: p, executorId: uid)
                    modelContext.insert(log); modelContext.safeSave()
                }
            case let id where id.hasPrefix("q_play_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    let reward = QuestManager.OhanaActionType.general(humanReward: 10, petReward: 12, emoji: "🎾", title: "\(p.name) 互动奖励")
                    CareEventService.recordCare(pet: p, type: .play, context: modelContext, executorId: uid, reward: reward)
                }
            case let id where id.hasPrefix("q_weight_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    expandedQuickWeightPet = p
                    return
                }
            case let id where id.hasPrefix("q_moment_"):
                if let petId = quest.targetPetId, let p = activePets.first(where: { $0.id == petId }) {
                    expandedQuickMomentPet = p
                    return
                }
            case "q_water_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                    pl.lastWateredDate = Date()
                    let log = PlantCareLog(date: Date(), careType: .watering); log.plant = pl
                    modelContext.insert(log); modelContext.safeSave()
                }
            case "q_fertilize_plant":
                if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                    pl.lastFertilizedDate = Date()
                    let log = PlantCareLog(date: Date(), careType: .fertilizing); log.plant = pl
                    modelContext.insert(log); modelContext.safeSave()
                }
            case "q_reminder":
                openGlobalCalendar()
            default:
                if let mid = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
                    for p in activePets {
                        if let med = p.medications.first(where: { $0.id == mid }) {
                            PetMedicationDoseLogging.recordDose(medication: med, pet: p, modelContext: modelContext)
                            break
                        }
                    }
                }
            }
        }

        let amt = IslandQuestEngine.coconutReward(forQuestId: quest.id)
        if amt > 0 && quest.id != "q_walk" {
            QuestManager.shared.addCoconuts(amt, title: "岛屿任务")
        }
    }

    // MARK: FAB (floating action button)

    @ViewBuilder
    private func fabOverlay(geo: GeometryProxy) -> some View {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 34
        let fabItems: [(label: String, icon: String, isAvailable: Bool, badge: String?)] = [
            ("全部功能", "square.grid.2x2.fill", true, nil),
            ("日历",     "calendar", true, nil),
            ("绿洲",     "leaf.fill", true, nil),
            ("植物", "camera.macro", false, "待开发"),
        ]

        VStack(alignment: .trailing, spacing: 14) {
            // Expanded action buttons (上方弹出)
            ForEach(Array(fabItems.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 10) {
                    // Label pill
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        if let badge = item.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.goPrimary.opacity(0.14), in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial.opacity(item.isAvailable ? 0.9 : 0.45), in: Capsule())
                    .shadow(color: .black.opacity(item.isAvailable ? 0.15 : 0.06), radius: 4, y: 2)

                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(Color(hex: "1A2E8A").opacity(item.isAvailable ? 1 : 0.35))
                            .frame(width: 48, height: 48)
                            .shadow(color: .black.opacity(item.isAvailable ? 0.25 : 0.08), radius: 6, y: 3)
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(item.isAvailable ? 1 : 0.5))
                    }
                }
                .opacity(item.isAvailable ? 1 : 0.55)
                .scaleEffect(fabExpanded ? 1 : 0.6, anchor: .bottomTrailing)
                .opacity(fabExpanded ? 1 : 0)
                .offset(y: fabExpanded ? 0 : 24)
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.72)
                    .delay(fabExpanded
                           ? Double(fabItems.count - 1 - idx) * 0.055
                           : Double(idx) * 0.04),
                    value: fabExpanded
                )
                .onTapGesture {
                    guard item.isAvailable else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        return
                    }
                    withAnimation(.spring(response: 0.3)) { fabExpanded = false }
                    switch idx {
                    case 0: showingFunctionMenu = true
                    case 1: openGlobalCalendar()
                    case 2: showingOasisReward  = true
                    default: break
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.label)
                .accessibilityHint("前往\(item.label)")
                .accessibilityHidden(!fabExpanded)
            }

            // Main FAB button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    fabExpanded.toggle()
                }
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
                        .animation(.spring(response: 0.3), value: fabExpanded)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fabExpanded ? "收起菜单" : "展开菜单")
            .accessibilityHint("点击展开全部功能、日历、绿洲")
        }
        .padding(.trailing, 20)
        .padding(.bottom, safeBottom + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    @ViewBuilder
    private func expandedCardFab(card: FocusCard, safeBottom: CGFloat) -> some View {
        let items: [(label: String, icon: String)] = [
            ("全部功能", "square.grid.2x2.fill"),
            ("日历", "calendar"),
            ("个人信息", "person.crop.circle")
        ]

        VStack(alignment: .trailing, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        cardFabExpanded = false
                    }
                    openExpandedCardFabAction(index: idx, card: card)
                } label: {
                    HStack(spacing: 10) {
                        Text(item.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)

                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: "1A2E8A"), in: Circle())
                            .shadow(color: Color(hex: "1A2E8A").opacity(0.35), radius: 8, y: 3)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(cardFabExpanded ? 1 : 0.65, anchor: .bottomTrailing)
                .opacity(cardFabExpanded ? 1 : 0)
                .offset(y: cardFabExpanded ? 0 : 18)
                .animation(
                    .spring(response: 0.32, dampingFraction: 0.74)
                    .delay(cardFabExpanded ? Double(items.count - 1 - idx) * 0.05 : Double(idx) * 0.03),
                    value: cardFabExpanded
                )
                .accessibilityHidden(!cardFabExpanded)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    cardFabExpanded.toggle()
                }
            } label: {
                Image(systemName: cardFabExpanded ? "xmark" : "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.goPrimary, in: Circle())
                    .shadow(color: Color.goPrimary.opacity(0.4), radius: 10, y: 4)
                    .rotationEffect(.degrees(cardFabExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(cardFabExpanded ? "收起成员快捷菜单" : "展开成员快捷菜单")
            .accessibilityHint("打开全部功能、日历或个人信息页")
        }
    }

    private func openExpandedCardFabAction(index: Int, card: FocusCard) {
        switch index {
        case 0:
            if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
                expandedAllFeaturesHuman = human
            } else if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
                expandedAllFeaturesPet = pet
            }
        case 1:
            calendarEntityFilterId = card.id.uuidString
            showingCalendar = true
        case 2:
            if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
                selectedHuman = human
            } else if let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
                selectedPetTab = .overview
                selectedPet = pet
            }
        default:
            break
        }
    }

    private func openGlobalCalendar() {
        calendarEntityFilterId = nil
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
                            .animation(.spring(response: 0.4), value: headerStreak)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("连续打卡 \(headerStreak) 天")

                CoconutBalanceCapsule(onTap: { showingCoconutLog = true })
            }

            Spacer()

            // ── Right: ... menu ──
            Menu {
                Button { showingAddEntity = true }   label: { Label("添加成员", systemImage: "person.badge.plus") }
                Button { showingCrewRoster = true }  label: { Label("OHANA 成员", systemImage: "person.2.fill") }
                Button { showingSettings = true }    label: { Label("设置", systemImage: "gearshape") }
            } label: {
                topLimePill {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .black))
                        .frame(width: 18)
                }
            }
            .buttonStyle(.plain)
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
                let log = PetCareLog(date: Date(), type: .waterChange, pet: pet, executorId: uid)
                modelContext.insert(log); modelContext.safeSave()
            } label: {
                Label("换水", systemImage: "drop.fill")
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

private struct FocusWalletCardView: View {
    let card: FocusCard
    let namespace: Namespace.ID
    let heroNS: Namespace.ID
    let expandedId: UUID?
    let isHeroExpanded: Bool

    private let accent = Color(hex: "FF5A3D")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = card.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent = card.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let hasPopout    = isTransparent && avatarImage != nil
            let usesFullBleed = avatarImage != nil && !isTransparent

            ZStack(alignment: .topLeading) {
                // 1. Background: mesh gradient (real pet/human) or flat gradient (dummy)
                cardBackground(usesFullBleed: usesFullBleed)

                // Geometry capture for bloom expand animation
                Color.clear
                    .matchedGeometryEffect(
                        id: HeroShellID(cardId: card.id),
                        in: namespace,
                        isSource: !(expandedId == card.id)
                    )
                    .allowsHitTesting(false)

                // 2. Full-bleed photo + right-side readability scrim
                if usesFullBleed, let img = avatarImage {
                    ZStack {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: w, height: h).clipped()
                            .saturation(1.02).contrast(1.03)
                        WalletCardTrailingReadabilityOverlay(width: w, height: h)
                    }
                    .allowsHitTesting(false)
                }

                // 3. Left avatar (silhouette or transparent photo popout)
                if !usesFullBleed {
                    leftAvatarContent(avatarImage: avatarImage, hasPopout: hasPopout, w: w, h: h)
                        .matchedGeometryEffect(
                            id: HeroArtID(cardId: card.id),
                            in: namespace,
                            isSource: !(expandedId == card.id)
                        )
                        .frame(width: w * 0.52, height: h)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                // 4. Right info column: streak · days together · footnote · barcode
                rightInfoColumn(h: h)

                // 5. Headline name at top-center
                Text(card.name.uppercased())
                    .font(.system(
                        size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: card.name.count),
                        weight: .black, design: .rounded
                    ))
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1).minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8).padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isHeroExpanded ? 1 : 0)
                    .allowsHitTesting(false)

                // 6. Kind subtitle below headline
                Text(card.kind.prefix(10).uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, kindSubtitleTop(w: w))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isHeroExpanded ? 1 : 0)
                    .allowsHitTesting(false)

                // 7. Top identity bar (peek strip shown when card is behind others)
                topIdentityBar
                    .opacity(isHeroExpanded ? 0 : 1)

                // 8. Compact cards now keep the same uninterrupted background as the hero card.
            }
            .animation(HeroAnim.walletSpring, value: isHeroExpanded)
        }
        .frame(height: isHeroExpanded ? K.expandedCardH : K.cardH)
        .clipShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .modifier(RealPetTransitionModifier(card: card, heroNS: heroNS))
    }

    // MARK: – Background

    @ViewBuilder
    private func cardBackground(usesFullBleed: Bool) -> some View {
        if !card.themeColorHex.isEmpty {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0),  SIMD2(1.0, 1.0)
                ],
                colors: WalletPetCardTheme.meshColors(for: card.themeColorHex)
            )
        } else {
            LinearGradient(
                colors: [
                    card.color.mix(with: .white, by: 0.22),
                    card.color,
                    card.color.mix(with: .black, by: 0.12)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        // Dark bottom overlay for text readability
        LinearGradient(
            colors: [.clear, .black.opacity(usesFullBleed ? 0.12 : 0.28)],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: – Left avatar

    @ViewBuilder
    private func leftAvatarContent(avatarImage: UIImage?, hasPopout: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage, hasPopout {
            // Transparent cutout: white outline + actual image, popout shadow
            ZStack(alignment: .bottom) {
                Image(uiImage: img).resizable().scaledToFit()
                    .scaleEffect(0.88).colorMultiply(.white)
                    .shadow(color: .white, radius: 0, x: 2, y: 0)
                    .shadow(color: .white, radius: 0, x: -2, y: 0)
                    .shadow(color: .white, radius: 0, x: 0, y: -2)
                Image(uiImage: img).resizable().scaledToFit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
        } else if !card.isHuman, let species = card.petSpecies {
            // Pet silhouette
            let silSpecies = FocusWalletCardView.normalizeSpecies(species)
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: w * 0.28, height: 24).blur(radius: 10)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: card.coatColor,
                    eyeColor: card.eyeColor,
                    patternName: card.patternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(0.92)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Human or unknown: emoji
            Text(card.emoji.isEmpty ? "👤" : card.emoji)
                .font(.system(size: min(w * 0.22, 60)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: – Right info column

    private func rightInfoColumn(h: CGFloat) -> some View {
        return VStack(alignment: .trailing, spacing: isHeroExpanded ? 5 : 3) {
            if card.streak > 1 {
                Text("🔥 \(card.streak)天连续")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.goPrimary, in: Capsule())
            }
            Spacer(minLength: 4)
            Text(card.daysTogether > 0 ? "\(card.daysTogether)" : "—")
                .font(.system(size: isHeroExpanded ? 34 : 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("Days Together")
                .font(.system(size: isHeroExpanded ? 11 : 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Text(footnoteText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1).minimumScaleFactor(0.7)
            if isHeroExpanded {
                barcodeView.padding(.top, 8)
            }
        }
        .padding(.trailing, 16).padding(.top, 18).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var footnoteText: String {
        var parts: [String] = []
        if let age = card.ageText, !age.isEmpty { parts.append(age) }
        if !card.breed.isEmpty { parts.append(card.breed) }
        else if let sp = card.petSpecies, !sp.isEmpty { parts.append(sp) }
        if parts.isEmpty { parts.append("Ohana ID") }
        return parts.joined(separator: " · ")
    }

    private var barcodeView: some View {
        let pattern: [CGFloat] = [18, 6, 10, 14, 5, 12, 8, 16, 7, 10, 13, 6]
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(.white.opacity(0.95))
                        .frame(width: 2, height: h)
                }
            }
            Text("O H A N A   P E T")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .tracking(1.2)
        }
    }

    // MARK: – Top identity bar (peek strip)

    private var topIdentityBar: some View {
        HStack(spacing: 8) {
            Text(card.name)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(card.kind.prefix(6).uppercased())
                .fcMicro(weight: .bold)
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: K.stackPeekH, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.black.opacity(0.06), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: K.stackPeekH + 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        )
    }

    // MARK: – Helpers

    /// Top padding for the kind subtitle so it sits just below the headline name
    private func kindSubtitleTop(w: CGFloat) -> CGFloat {
        let headlineSize = WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: card.name.count)
        return 8 + headlineSize + 4
    }

    private static func normalizeSpecies(_ s: String) -> String {
        let l = s.lowercased()
        if s.contains("猫") || l.contains("cat")       { return "猫" }
        if s.contains("狗") || l.contains("dog")       { return "狗" }
        if s.contains("兔") || l.contains("rabbit")    { return "兔子" }
        if s.contains("仓鼠") || l.contains("hamster") { return "仓鼠" }
        if s.contains("鸟") || l.contains("bird")      { return "鸟" }
        return s
    }
}

// ─────────────────────────────────────────────────
// MARK: – matchedTransitionSource helper (real pets only)
// ─────────────────────────────────────────────────

private struct RealPetTransitionModifier: ViewModifier {
    let card: FocusCard
    let heroNS: Namespace.ID

    func body(content: Content) -> some View {
        if card.isReal && !card.isDummy {
            content
                .matchedTransitionSource(id: card.id as UUID, in: heroNS) { cfg in
                    cfg.clipShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner,
                                                   style: .continuous))
                }
        } else {
            content
        }
    }
}

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
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                animate = true
            }
        }
    }
}

private struct ExpandedHumanFeaturesSheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    Section {
                        NavigationLink {
                            HumanWeightHistoryView(human: human)
                        } label: {
                            row(icon: "scalemass.fill", color: .goTeal, title: "体重记录", subtitle: "查看体重趋势")
                        }
                        NavigationLink {
                            HumanMedicationView(human: human)
                        } label: {
                            row(icon: "pills.fill", color: .goPurple, title: "用药管理", subtitle: "记录服药和提醒")
                        }
                        NavigationLink {
                            HumanHealthReportView(human: human)
                        } label: {
                            row(icon: "cross.case.fill", color: .goRed, title: "健康报告", subtitle: "体检与健康档案")
                        }
                    } header: {
                        sectionHeader("健康 & 身体")
                    }
                    .listRowBackground(rowBackground)

                    Section {
                        NavigationLink {
                            CoHealthDashboardFullView(human: human)
                        } label: {
                            row(icon: "figure.run", color: .goTeal, title: "活动记录", subtitle: "运动与共同健康")
                        }
                        NavigationLink {
                            HumanExpenseDetailView(human: human)
                        } label: {
                            row(icon: "creditcard.fill", color: .goOrange, title: "花费记录", subtitle: "查看支出明细")
                        }
                        NavigationLink {
                            HumanWishlistView(human: human)
                        } label: {
                            row(icon: "gift.fill", color: Color(hex: "EC4899"), title: "椰子资产", subtitle: "愿望清单和资产")
                        }
                    } header: {
                        sectionHeader("活动 & 财务")
                    }
                    .listRowBackground(rowBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("\(human.name) 的功能")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.goLime)
                }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.12))
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
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
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
                        Text(card.kind.uppercased())
                            .fcMicro()
                            .foregroundStyle(K.ink.opacity(0.28))
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
                .animation(.easeOut(duration: 0.38), value: detailFooterVisible)

                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: [.top, .leading, .trailing])

            VStack {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        detailFooterVisible = false
                        withAnimation(HeroAnim.transitionSpring) {
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
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.leading, padding + 4)
                .padding(.top, safeAreaTop + 8)
                Spacer()
            }
            .allowsHitTesting(true)

            expandedCardFab(card: card, safeBottom: safeB)
                .frame(width: heroW, alignment: .trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, padding)
                .padding(.bottom, safeB + 24)
                .allowsHitTesting(true)
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
                        withAnimation(HeroAnim.transitionSpring) { expandedId = nil; dragOffset = 0 }
                    } else {
                        withAnimation(HeroAnim.transitionSpring) { dragOffset = 0 }
                    }
                }
        )
        .ignoresSafeArea(.all)
    }

    private func heroCardView(card: FocusCard, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [card.color.mix(with: .white, by: 0.28),
                         card.color,
                         card.color.mix(with: .black, by: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(width: width, height: height)

            Group {
                if let data = card.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: width, height: height).clipped()
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
        .buttonStyle(.plain)
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

// ─────────────────────────────────────────────────
// MARK: – Wrapper for Settings preview entry
// ─────────────────────────────────────────────────

struct FocusStackHomeTestViewPreviewWrapper: View {
    @State private var selectedPet:    Pet?    = nil
    @State private var selectedHuman:  Human?  = nil
    @State private var selectedPlant:  Plant?  = nil
    @State private var selectedPetTab: PetDetailTab = .overview
    @Namespace private var heroNS

    var body: some View {
        FocusStackHomeTestView(
            selectedPet:    $selectedPet,
            selectedHuman:  $selectedHuman,
            selectedPlant:  $selectedPlant,
            selectedPetTab: $selectedPetTab,
            heroNS:         heroNS
        )
    }
}
