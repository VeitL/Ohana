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
    var createdAt: Date = .distantPast
    var daysTogetherText: String?
    var ageText: String?
    var zodiacText: String?
    var mbtiText: String?
    var humanEquivalentAgeText: String?
    var genderText: String?
    var avatarImageData: Data?
    var humanGender: String? = nil
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

private struct HomeFabFunctionShortcut: Identifiable {
    var label: String
    var icon: String
    var isAvailable: Bool = true
    var badge: String? = nil
    var destination: FMDest? = nil

    var id: String { label }
}

private enum ExpandedCardFabAction: Hashable {
    case quick(String)
    case detail(PetFeature)
    case allFeatures
    case humanQuick(String)
    case humanAllFeatures
}

private struct ExpandedCardFabShortcut: Identifiable {
    var label: String
    var icon: String
    var action: ExpandedCardFabAction
    var isAvailable: Bool = true
    var badge: String? = nil

    var id: String { "\(label)-\(String(describing: action))" }
}

private struct FunctionMenuPresentation: Identifiable {
    let id = UUID()
    let destination: FMDest?
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
            createdAt: pet.createdAt,
            daysTogetherText: pet.homeDate == nil ? nil : "\(pet.daysTogether) 天",
            ageText: pet.birthday == nil ? nil : pet.ageText,
            zodiacText: pet.birthday.map { Human.westernZodiacDisplay(for: $0, isEnglish: false) },
            humanEquivalentAgeText: pet.birthday.map { pet.humanEquivalentAgeTextForWallet(birthday: $0) },
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
            createdAt: human.createdAt,
            daysTogetherText: "\(days) 天",
            ageText: human.birthday == nil ? nil : human.ageText,
            zodiacText: human.birthday.map { Human.westernZodiacDisplay(for: $0, isEnglish: false) },
            mbtiText: human.mbti.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : human.mbti.uppercased(),
            genderText: human.roleText,
            avatarImageData: human.avatarImageData,
            humanGender: human.genderRaw,
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

private extension Pet {
    func humanEquivalentAgeTextForWallet(birthday: Date) -> String {
        let equivalent = FocusPetHumanAgeEstimator.equivalentHumanYears(
            birthday: birthday,
            species: species,
            breed: breed
        )
        guard equivalent > 0 else { return "" }
        return "约人类\(equivalent)岁"
    }
}

private enum FocusPetHumanAgeEstimator {
    static func equivalentHumanYears(birthday: Date, species: String, breed: String) -> Int {
        let ageYears = max(0, Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0) / 365
        let preciseAge = max(0, Double(Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0) / 365.25)
        let normalizedSpecies = species.lowercased()

        if species.contains("狗") || normalizedSpecies.contains("dog") {
            return dogHumanYears(age: preciseAge, breed: breed)
        }
        if species.contains("猫") || normalizedSpecies.contains("cat") {
            return catHumanYears(age: preciseAge)
        }
        if species.contains("兔") || normalizedSpecies.contains("rabbit") {
            return Int((preciseAge * 8.0).rounded())
        }
        if species.contains("仓鼠") || normalizedSpecies.contains("hamster") {
            return Int((preciseAge * 26.0).rounded())
        }
        if species.contains("鸟") || normalizedSpecies.contains("bird") {
            return Int((preciseAge * 5.0).rounded())
        }
        if species.contains("鱼") || normalizedSpecies.contains("fish") {
            return Int((preciseAge * 6.0).rounded())
        }
        return max(0, ageYears)
    }

    private static func dogHumanYears(age: Double, breed: String) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }

        let increment: Double
        switch dogSize(for: breed) {
        case .small: increment = 4
        case .medium: increment = 5
        case .large: increment = 6
        case .giant: increment = 7
        }
        return Int((24 + (age - 2) * increment).rounded())
    }

    private static func catHumanYears(age: Double) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }
        return Int((24 + (age - 2) * 4).rounded())
    }

    private enum DogSize { case small, medium, large, giant }

    private static func dogSize(for breed: String) -> DogSize {
        let b = breed.lowercased()
        if ["马尔济斯", "约克夏", "博美", "比熊", "西施", "查理王", "泰迪", "贵宾", "腊肠", "法斗", "法国斗牛", "corgi", "poodle", "yorkshire", "pomeranian", "bichon", "maltese", "dachshund", "shih"].contains(where: { b.contains($0.lowercased()) }) {
            return .small
        }
        if ["阿拉斯加", "大丹", "圣伯纳", "獒", "纽芬兰", "giant", "great dane", "mastiff", "saint bernard", "newfoundland", "alaskan"].contains(where: { b.contains($0.lowercased()) }) {
            return .giant
        }
        if ["金毛", "拉布拉多", "德国牧羊", "杜宾", "哈士奇", "萨摩耶", "大麦町", "边境牧羊", "golden", "labrador", "german shepherd", "husky", "samoyed", "doberman", "dalmatian", "border collie"].contains(where: { b.contains($0.lowercased()) }) {
            return .large
        }
        return .medium
    }
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
    /// 标准信用卡比例 85.6×53.98mm ≈ 1.586:1（宽/高），随屏幕宽度动态计算
    static var cardH: CGFloat { (ScreenCompat.width - cardMargin * 2) / 1.586 }
    static let expandedCardH: CGFloat = 360
    // Default stack mode: each covered card exposes the one-line identity area
    // (name + species / role), while avoiding an overly loose card stack.
    static let cardTitleH: CGFloat = 52
    static let collapsedStackPeekH: CGFloat = cardTitleH
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
    static let stackAddButtonH: CGFloat = 28
    static let stackAddButtonTopGap: CGFloat = 8
    static let stackAddButtonToCardsGap: CGFloat = 8
    static var stackMinTopY: CGFloat {
        stackAddButtonTopGap + stackAddButtonH + stackAddButtonToCardsGap
    }
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
    @State private var functionMenuPresentation: FunctionMenuPresentation?
    @State private var showStreakDetail    = false
    @State private var headerStreak        = 0
    @State private var fabExpanded         = false
    @State private var showingCoconutLog   = false
    @State private var showingAddEntity    = false
    @State private var showingCrewRoster   = false
    @State private var showingCalendar     = false
    @State private var familyActivityPet: Pet? = nil
    @State private var weeklyReportPet: Pet? = nil
    @State private var calendarEntityFilterId: String? = nil
    @State private var showingOasisReward  = false
    @State private var cardFabExpanded     = false
    @State private var expandedAllFeaturesPet: Pet? = nil
    @State private var expandedAllFeaturesHuman: Human? = nil
    @State private var expandedBasicInfoPet: Pet? = nil
    @State private var expandedBasicInfoHuman: Human? = nil
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
    @State private var expandedHumanNoteDetail: Human? = nil
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

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }

    private var cards: [FocusCard] {
        let real = (
            pets.filter { !$0.hasPassedAway }.map { FocusCard.from($0) }
            + humans.map { FocusCard.from($0) }
        )
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.name < rhs.name
        }
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

    private var activeWalletCard: FocusCard? {
        guard isExpanded else { return nil }
        let heroId = activeCardId ?? cards.first?.id
        return cards.first { $0.id == heroId }
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

                // FAB stays mounted while the wallet card stack changes modes; only its submenu content changes.
                if expandedId == nil {
                    if fabExpanded {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { fabExpanded = false }
                            .transition(.opacity)
                    }
                    homeFabOverlay(activeCard: activeWalletCard)
                        .zIndex(999)
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
        .sheet(item: $functionMenuPresentation) { presentation in
            FunctionMenuSheet(initialDestination: presentation.destination)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showStreakDetail) { DailyStreakDetailView(pets: pets) }
        .fullScreenCover(isPresented: $showingCoconutLog) { IslandWealthDashboardView() }
        .sheet(isPresented: $showingAddEntity) { AddEntityView() }
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
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshHeaderStreak()
        }
        .onAppear {
            ensureTodayCheckIn()
            refreshHeaderStreak()
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Stack layer
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    private var dailyCheckInKey: String { "oasis_checkedIn_dates" }

    private func dailyCheckInDateString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func ensureTodayCheckIn() {
        let today = dailyCheckInDateString()
        var checkedInDates = Set(UserDefaults.standard.stringArray(forKey: dailyCheckInKey) ?? [])
        guard !checkedInDates.contains(today) else { return }

        checkedInDates.insert(today)
        UserDefaults.standard.set(Array(checkedInDates), forKey: dailyCheckInKey)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: l.homeDailyCheckInRewardTitle)
    }

    private func refreshHeaderStreak() {
        let calendar = Calendar.current
        let checkedInDates = Set(UserDefaults.standard.stringArray(forKey: dailyCheckInKey) ?? [])
        var streak = 0
        var day = Date()

        while true {
            let dayString = dailyCheckInDateString(day)
            guard checkedInDates.contains(dayString) else { break }
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        headerStreak = streak
    }

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
            } else {
                // GeometryReader-based stack fills all remaining space below the header/focus strip.
                // Keep the same wallet stack mounted in both collapsed and expanded modes so
                // card positions animate instead of swapping between two separate layers.
                walletCardStack(cards: cards)
                    .padding(.horizontal, K.cardMargin)
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

                if humans.count > 1, let pet = todayFocusActivePet {
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
        let inactiveBottomY = geo.size.height + K.cardH - K.expandedInactiveFrontPeekH
        let quickModulesTopY = activeTopY + K.expandedCardH + 14

        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let isHero = card.id == heroId
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
                .onTapGesture { handleWalletCardTap(card: card, n: n, isHero: isHero) }
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard isHero else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    openWalletCardBasicInfo(card)
                }
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
            HStack(spacing: 8) {
                Text("快捷操作")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(2.6)
                Spacer(minLength: 4)
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

                if isExpandedQAEditMode && QuickActionLimit.count(for: pet, in: expandedQAEditItems) < QuickActionLimit.maxItemsPerEntity {
                    expandedQuickAddButton(pet: pet)
                }
            }

            if isExpandedQAEditMode && QuickActionLimit.count(for: pet, in: expandedQAEditItems) >= QuickActionLimit.maxItemsPerEntity {
                Text("最多 8 个快捷操作")
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .transition(.opacity)
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
            HStack(spacing: 8) {
                Text("快捷操作")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(2.6)
                Spacer(minLength: 4)
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

                if isExpandedQAEditMode && expandedQAEditItems.count < QuickActionLimit.maxItemsPerEntity {
                    expandedHumanQuickAddButton(human: human)
                }
            }

            if isExpandedQAEditMode && expandedQAEditItems.count >= QuickActionLimit.maxItemsPerEntity {
                Text("最多 8 个快捷操作")
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .transition(.opacity)
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
        return bottomY - K.cardH - CGFloat(inactiveCount - 1 - cr) * K.expandedInactiveStackPeekH
    }

    @ViewBuilder
    private func walletCardStack(cards: [FocusCard]) -> some View {
        let n = cards.count
        let heroId = activeCardId ?? cards.first?.id

        GeometryReader { geo in
            // Anchor the stack to the real screen bottom, then convert that
            // global target back into this lower-page GeometryReader's space.
            // This reader starts below the focus module, so using only
            // geo.size.height can push the front card below the visible screen.
            let bottomInset = max(safeAreaBottom, geo.safeAreaInsets.bottom)
            let collapsedBottomY = collapsedStackBottomY(in: geo, bottomInset: bottomInset)
            let expandedBottomY = expandedStackBottomY(in: geo, bottomInset: bottomInset)
            let heroTopY = safeAreaTop + K.expandedCardGlobalTopOffset - geo.frame(in: .global).minY
            let stackTopY = collapsedWalletStackTopY(n: n, bottomY: collapsedBottomY)
            let addButtonY = max(
                K.stackAddButtonTopGap,
                min(
                    stackTopY - K.stackAddButtonToCardsGap - K.stackAddButtonH,
                    collapsedBottomY - K.cardH - K.stackAddButtonToCardsGap - K.stackAddButtonH
                )
            )

            ZStack(alignment: .topLeading) {
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
                    .frame(height: K.stackAddButtonH, alignment: .center)
                    .offset(y: addButtonY)
                    .zIndex(999)
                    .transition(.opacity)
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    let isHero = isExpanded && card.id == heroId
                    let visibleHeight = isHero ? K.expandedCardH : K.cardH
                    let offsetY = isExpanded
                    ? walletOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: expandedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                        cards: cards
                    )
                    : walletOffsetY(
                        idx: idx,
                        n: n,
                        bottomY: collapsedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                        cards: cards
                    )

                    walletCardStackItem(
                        card: card,
                        idx: idx,
                        n: n,
                        isHero: isHero,
                        visibleHeight: visibleHeight,
                        offsetY: offsetY,
                        heroId: heroId,
                        cards: cards
                    )
                }

                if isExpanded, let activeCard = cards.first(where: { $0.id == heroId }) {
                    let quickModuleH = expandedQuickModuleHeight(for: activeCard)
                    expandedQuickModules(card: activeCard)
                        .frame(width: geo.size.width, height: quickModuleH)
                        .offset(y: heroTopY + K.expandedCardH + 14)
                        .zIndex(Double(n + 80))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .simultaneousGesture(collapseWalletDragGesture())
                        .animation(HeroAnim.walletSpring, value: activeCardId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .animation(HeroAnim.walletSpring, value: isExpanded)
            .animation(HeroAnim.walletSpring, value: activeCardId)
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

    private func walletCardStackItem(
        card: FocusCard,
        idx: Int,
        n: Int,
        isHero: Bool,
        visibleHeight: CGFloat,
        offsetY: CGFloat,
        heroId: UUID?,
        cards: [FocusCard]
    ) -> some View {
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
            .offset(y: offsetY)
            .zIndex(walletZIndex(idx: idx, n: n, isHero: isHero,
                                 heroId: heroId, cards: cards))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name) 的卡片")
            .accessibilityHint(isHero ? "点击返回首页，长按进入基本信息" :
                              (isExpanded ? "点击返回首页" : "点击展开查看"))
            .if(!(isHero && isExpanded)) { view in
                view.contextMenu { cardContextMenu(card: card) }
            }
            .onTapGesture { handleWalletCardTap(card: card, n: n, isHero: isHero) }
            .onLongPressGesture(minimumDuration: 0.45) {
                guard isHero && isExpanded else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                openWalletCardBasicInfo(card)
            }
            .animation(HeroAnim.walletSpring, value: isExpanded)
            .animation(HeroAnim.walletSpring, value: activeCardId)
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

    private func collapsedWalletStackTopY(n: Int, bottomY: CGFloat) -> CGFloat {
        bottomY - fanHeight(n: n, bottomY: bottomY)
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if n <= 1 {
            if isExpanded {
                collapseWalletToHome()
            } else {
                withAnimation(HeroAnim.walletSpring) {
                    activeCardId = card.id
                    isExpanded = true
                }
            }
            return
        }

        if isHero {
            collapseWalletToHome()
        } else if isExpanded {
            collapseWalletToHome()
        } else {
            withAnimation(HeroAnim.walletSpring) {
                activeCardId = card.id
                isExpanded = true
            }
        }
    }

    private func collapseWalletToHome() {
        withAnimation(HeroAnim.walletSpring) {
            isExpanded = false
            fabExpanded = false
            isExpandedQAEditMode = false
        }
    }

    private func openWalletCardBasicInfo(_ card: FocusCard) {
        fabExpanded = false
        isExpandedQAEditMode = false
        withAnimation(HeroAnim.walletSpring) {
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
            expandedHumanNoteDetail = human
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
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet, executorId: executorId)
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

    private var floatingFabBottomPadding: CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 34
        return safeBottom + 40
    }

    @ViewBuilder
    private func homeFabOverlay(activeCard: FocusCard?) -> some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Expanded action buttons (上方弹出)
            if let activeCard {
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
                    .scaleEffect(fabExpanded ? 1 : 0.6, anchor: .bottomTrailing)
                    .opacity(fabExpanded ? 1 : 0)
                    .offset(y: fabExpanded ? 0 : 24)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.72)
                        .delay(fabExpanded
                               ? Double(activeItems.count - 1 - idx) * 0.055
                               : Double(idx) * 0.04),
                        value: fabExpanded
                    )
                    .onTapGesture {
                        guard item.isAvailable else {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            return
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        fabExpanded = false
                        openExpandedCardFabShortcut(item, card: activeCard)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.label)
                    .accessibilityHint("前往\(item.label)详情")
                    .allowsHitTesting(fabExpanded)
                    .accessibilityHidden(!fabExpanded)
                }
            } else {
                let fabItems = homeFabFunctionShortcuts
                ForEach(Array(fabItems.enumerated()), id: \.element.id) { idx, item in
                    fabActionRow(item: item, rowHeight: 48)
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
                        .onTapGesture { openHomeFabShortcut(item) }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.label)
                        .accessibilityHint(item.isAvailable ? "前往\(item.label)" : "当前不可用")
                        .allowsHitTesting(fabExpanded)
                        .accessibilityHidden(!fabExpanded)
                }
            }

            // Main FAB button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                fabExpanded.toggle()
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
            .background(.ultraThinMaterial.opacity(item.isAvailable ? 0.9 : 0.45), in: Capsule())
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
        fabExpanded = false
        functionMenuPresentation = FunctionMenuPresentation(destination: item.destination)
    }

    private func expandedCardFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman {
            return [
                ExpandedCardFabShortcut(label: "体重", icon: "scalemass.fill", action: .humanQuick("humanWeight")),
                ExpandedCardFabShortcut(label: "运动", icon: "figure.run", action: .humanQuick("humanWorkout")),
                ExpandedCardFabShortcut(label: "用药", icon: "pill.fill", action: .humanQuick("humanMedication")),
                ExpandedCardFabShortcut(label: "记录", icon: "note.text", action: .humanQuick("humanNote")),
                ExpandedCardFabShortcut(label: "其他", icon: "ellipsis.circle.fill", action: .humanAllFeatures)
            ]
        }

        let species = card.petSpecies?.lowercased() ?? card.kind.lowercased()
        let isDog = species.contains("狗") || species.contains("dog")
        let isCat = species.contains("猫") || species.contains("cat")
        let isFish = species.contains("鱼") || species.contains("fish")

        if isDog {
            return [
                ExpandedCardFabShortcut(label: "喂食", icon: "fork.knife", action: .quick("feed")),
                ExpandedCardFabShortcut(label: "喂水", icon: "drop.fill", action: .quick("water")),
                ExpandedCardFabShortcut(label: "遛狗", icon: "figure.walk", action: .quick("walk")),
                ExpandedCardFabShortcut(label: "便便", icon: "allergens", action: .quick("potty")),
                ExpandedCardFabShortcut(label: "逗玩", icon: "sparkles", action: .quick("play")),
                ExpandedCardFabShortcut(label: "其他", icon: "ellipsis.circle.fill", action: .allFeatures)
            ]
        }

        if isCat {
            return [
                ExpandedCardFabShortcut(label: "喂食", icon: "fork.knife", action: .quick("feed")),
                ExpandedCardFabShortcut(label: "喂水", icon: "drop.fill", action: .quick("water")),
                ExpandedCardFabShortcut(label: "铲屎", icon: "trash.fill", action: .quick("litter")),
                ExpandedCardFabShortcut(label: "便便", icon: "allergens", action: .quick("potty")),
                ExpandedCardFabShortcut(label: "逗玩", icon: "sparkles", action: .quick("play")),
                ExpandedCardFabShortcut(label: "其他", icon: "ellipsis.circle.fill", action: .allFeatures)
            ]
        }

        if isFish {
            return [
                ExpandedCardFabShortcut(label: "喂食", icon: "fork.knife", action: .quick("feed")),
                ExpandedCardFabShortcut(label: "换水", icon: "drop.circle.fill", action: .quick("waterChange")),
                ExpandedCardFabShortcut(label: "清滤", icon: "wrench.and.screwdriver.fill", action: .quick("filterClean")),
                ExpandedCardFabShortcut(label: "健康", icon: "cross.fill", action: .detail(.health)),
                ExpandedCardFabShortcut(label: "记录", icon: "sparkles", action: .quick("moment")),
                ExpandedCardFabShortcut(label: "其他", icon: "ellipsis.circle.fill", action: .allFeatures)
            ]
        }

        return [
            ExpandedCardFabShortcut(label: "喂食", icon: "fork.knife", action: .quick("feed")),
            ExpandedCardFabShortcut(label: "喂水", icon: "drop.fill", action: .quick("water")),
            ExpandedCardFabShortcut(label: "清洁", icon: "bubbles.and.sparkles.fill", action: .quick("groom")),
            ExpandedCardFabShortcut(label: "体重", icon: "scalemass.fill", action: .detail(.weight)),
            ExpandedCardFabShortcut(label: "记录", icon: "sparkles", action: .quick("moment")),
            ExpandedCardFabShortcut(label: "其他", icon: "ellipsis.circle.fill", action: .allFeatures)
        ]
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
                .scaleEffect(cardFabExpanded ? 1 : 0.6, anchor: .bottomTrailing)
                .opacity(cardFabExpanded ? 1 : 0)
                .offset(y: cardFabExpanded ? 0 : 24)
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.72)
                    .delay(cardFabExpanded ? Double(items.count - 1 - idx) * 0.055 : Double(idx) * 0.04),
                    value: cardFabExpanded
                )
                .onTapGesture {
                    guard item.isAvailable else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        return
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    cardFabExpanded = false
                    openExpandedCardFabShortcut(item, card: card)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.label)
                .accessibilityHint("前往\(item.label)详情")
                .accessibilityHidden(!cardFabExpanded)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                cardFabExpanded.toggle()
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
                        .animation(.spring(response: 0.3), value: cardFabExpanded)
                }
            }
            .buttonStyle(.plain)
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
            expandedQuickFeedDetailPet = pet
        case "water":
            expandedQuickWaterDetailModeRaw = QuickWaterDetailSheet.WaterMode.drink.rawValue
            expandedQuickWaterDetailPet = pet
        case "waterChange":
            expandedQuickWaterDetailModeRaw = QuickWaterDetailSheet.WaterMode.change.rawValue
            expandedQuickWaterDetailPet = pet
        case "walk":
            expandedQuickWalkPet = pet
        case "potty", "litter":
            expandedQuickPottyDetailPet = pet
        case "play":
            expandedQuickPlayDetailPet = pet
        case "groom", "filterClean":
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
            expandedQuickHealthPet = pet
        case .food:
            expandedQuickFeedDetailPet = pet
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
        default:
            expandedAllFeaturesHuman = human
        }
    }

    private func openGlobalCalendar() {
        calendarEntityFilterId = nil
        showingCalendar = true
    }

    private func openTopCalendar() {
        if let activeCard = activeWalletCard, !activeCard.isHuman {
            calendarEntityFilterId = activeCard.id.uuidString
        } else {
            calendarEntityFilterId = nil
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
                            .animation(.spring(response: 0.4), value: headerStreak)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("连续打卡 \(headerStreak) 天")

                CoconutBalanceCapsule(onTap: { showingOasisReward = true })
            }

            Spacer()

            // ── Right: calendar + ... menu ──
            HStack(spacing: 8) {
                Button { openTopCalendar() } label: {
                    topLimePill {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .black))
                            .frame(width: 18)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("日历")

                HeaderMenuButton {
                    showingCrewRoster = true
                }
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

                // 2. Full-card photo + right-side readability scrim
                if usesFullBleed, let img = avatarImage {
                    cardPhotoLayer(img, w: w, h: h)
                    .allowsHitTesting(false)
                }

                // 3. Oversized background identity. For regular photos this sits
                // above the image as a translucent orange watermark; for pasted
                // transparent subjects it still remains behind the subject.
                backgroundHeadlineLayer(w: w)

                // 4. Left avatar (silhouette or transparent photo popout)
                if !usesFullBleed {
                    leftAvatarContent(avatarImage: avatarImage, hasPopout: hasPopout, w: w, h: h)
                        .matchedGeometryEffect(
                            id: HeroArtID(cardId: card.id),
                            in: namespace,
                            isSource: !(expandedId == card.id)
                        )
                        .frame(width: w * avatarContentWidthRatio, height: h)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                // 5. Right info column: streak · days together · footnote · barcode
                rightInfoColumn(h: h)

                // 6. Top identity bar (peek strip shown when card is behind others)
                topIdentityBar
                    .opacity(isHeroExpanded ? 0 : 1)

                // 7. Compact cards now keep the same uninterrupted background as the hero card.
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

    private var avatarContentWidthRatio: CGFloat {
        if isHeroExpanded && !card.isHuman && card.petSpecies != nil {
            return 0.98
        }
        return 0.52
    }

    private func backgroundHeadlineLayer(w: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(card.name.uppercased())
                .font(.system(
                    size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: card.name.count),
                    weight: .black, design: .rounded
                ))
                .foregroundStyle(accent.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.22)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(card.kind.prefix(10).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isHeroExpanded ? 1 : 0.78)
        .allowsHitTesting(false)
    }

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

    @ViewBuilder
    private func cardPhotoLayer(_ img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        if isHeroExpanded {
            ZStack {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                WalletCardTrailingReadabilityOverlay(width: w, height: h)
                bottomRightTextShadow(width: w, height: h, isExpanded: true)
            }
        } else {
            let photoW = compactPhotoRenderedWidth(img, h: h, cardW: w)
            ZStack(alignment: .leading) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoW, height: h)
                    .clipped()
                    .frame(width: w, height: h, alignment: .leading)
                    .saturation(1.04)
                    .contrast(1.02)
                    .mask(compactPhotoSoftMask(width: w, height: h))
                bottomRightTextShadow(width: w, height: h, isExpanded: false)
            }
        }
    }

    private func compactPhotoRenderedWidth(_ img: UIImage, h: CGFloat, cardW: CGFloat) -> CGFloat {
        guard img.size.height > 0 else { return cardW }
        return max(cardW, h * img.size.width / img.size.height)
    }

    private func compactPhotoSoftMask(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.46),
                .init(color: .white.opacity(0.72), location: 0.60),
                .init(color: .white.opacity(0.18), location: 0.76),
                .init(color: .clear, location: 0.92)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width, height: height)
    }

    private func bottomRightTextShadow(width: CGFloat, height: CGFloat, isExpanded: Bool) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(isExpanded ? 0.18 : 0.10), location: 0.38),
                    .init(color: .black.opacity(isExpanded ? 0.44 : 0.32), location: 0.76),
                    .init(color: .black.opacity(isExpanded ? 0.62 : 0.46), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    .black.opacity(isExpanded ? 0.56 : 0.42),
                    .black.opacity(isExpanded ? 0.28 : 0.20),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 8,
                endRadius: min(width, height) * (isExpanded ? 0.78 : 0.66)
            )
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    // MARK: – Left avatar

    @ViewBuilder
    private func leftAvatarContent(avatarImage: UIImage?, hasPopout: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage, hasPopout {
            // Transparent cutout. In expanded pet cards we intentionally avoid the
            // white-outline duplicate layer; sibling FAB animations can otherwise
            // redraw that outline one frame before the real image and create a flash.
            ZStack(alignment: .bottom) {
                if !(isHeroExpanded && !card.isHuman) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .scaleEffect(0.88)
                        .colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                        .allowsHitTesting(false)
                }
                Image(uiImage: img).resizable().scaledToFit()
                    .scaleEffect(1)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(isHeroExpanded && !card.isHuman ? 16 : 0)
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
        } else if !card.isHuman, let species = card.petSpecies {
            // Pet silhouette
            let silSpecies = FocusWalletCardView.normalizeSpecies(species)
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: w * (isHeroExpanded ? 0.32 : 0.28), height: isHeroExpanded ? 26 : 24)
                    .blur(radius: 10)
                    .offset(y: h * (isHeroExpanded ? 0.18 : 0.14))
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: card.coatColor,
                    eyeColor: card.eyeColor,
                    patternName: card.patternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(isHeroExpanded ? 1.0 : 0.92)
                .frame(
                    width: w * (isHeroExpanded ? 0.78 : 0.38),
                    height: h * (isHeroExpanded ? 0.90 : 0.68)
                )
                .offset(x: isHeroExpanded ? -w * 0.03 : 0, y: isHeroExpanded ? h * 0.04 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if card.isHuman {
            HumanSilhouetteView(gender: card.humanGender ?? "", accent: .white.opacity(0.78))
                .scaleEffect(0.9)
                .frame(width: w * 0.34, height: h * 0.68)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            // Unknown: emoji fallback
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
            if card.isHuman {
                humanInfoStack
            } else {
                petInfoStack
            }
            if isHeroExpanded {
                barcodeView.padding(.top, 8)
            }
        }
        .padding(.trailing, 16).padding(.top, 18).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var humanInfoStack: some View {
        let details = [card.zodiacText, card.mbtiText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .trailing, spacing: isHeroExpanded ? 5 : 3) {
            Text(details.first ?? "OHANA MEMBER")
                .font(.system(size: isHeroExpanded ? 20 : 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if details.count > 1 {
                Text(details.dropFirst().joined(separator: " · "))
                    .font(.system(size: isHeroExpanded ? 11 : 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var petInfoStack: some View {
        let meta = [card.ageText, card.humanEquivalentAgeText, card.zodiacText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "未知" }

        return VStack(alignment: .trailing, spacing: isHeroExpanded ? 5 : 3) {
            Text(petTogetherHeadline)
                .font(.system(size: isHeroExpanded ? 20 : 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(.system(size: isHeroExpanded ? 10 : 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(isHeroExpanded ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
            }
        }
    }

    private var petTogetherHeadline: String {
        guard card.daysTogetherText != nil else { return "New Family" }
        if card.daysTogether < 0 { return "\(abs(card.daysTogether)) Days Until Home" }
        return "\(card.daysTogether) Days Together"
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
            Text(card.isHuman ? "O H A N A   H U M A N" : "O H A N A   P E T")
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
                        NavigationLink {
                            HumanBasicInfoDetailView(human: human)
                        } label: {
                            humanFeatureHero
                        }
                        .buttonStyle(.plain)

                        if isAllPrivateForViewer {
                            fullPrivacyCard
                        } else {
                            badgesCard
                            visibilityCard
                        }

                        sectionHeader("功能入口")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .weight,
                                destination: HumanWeightHistoryView(human: human),
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
                                destination: CoHealthDashboardFullView(human: human),
                                lockedTitle: "活动",
                                label: {
                                    bentoCard(
                                        icon: "figure.run",
                                        color: Color(hex: "38BDF8"),
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
                                destination: HumanMedicationView(human: human),
                                lockedTitle: "用药",
                                label: {
                                    compactBentoCard(icon: "pills.fill", color: .goPurple, title: "用药", subtitle: "服药与提醒")
                                }
                            )
                            featureNavigation(
                                field: .weight,
                                destination: HumanHealthReportView(human: human),
                                lockedTitle: "健康报告",
                                label: {
                                    compactBentoCard(icon: "cross.case.fill", color: .goRed, title: "健康报告", subtitle: "体检与档案")
                                }
                            )
                        }

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .expense,
                                destination: HumanExpenseDetailView(human: human),
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
                                destination: HumanWishlistView(human: human),
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
                            deleteCard
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
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 30, height: 30)
                                .background(Color.goLime, in: Circle())
                        }
                        .buttonStyle(.plain)
                        Button("完成") { dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.goLime)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) { EditHumanSheet(human: human) }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
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
    private func featureNavigation<Destination: View, Label: View>(
        field: HumanPrivateField,
        destination: Destination,
        lockedTitle: String,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if human.isPrivate(field, viewedBy: activeHumanId) {
            lockedFeatureCard(title: lockedTitle)
        } else {
            NavigationLink {
                destination
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }

    private var visibleWorkoutCount: Int {
        human.isPrivate(.workout, viewedBy: activeHumanId) ? 0 : human.workoutLogs.count
    }

    private var visibleCoconutText: String {
        human.isPrivate(.wishlist, viewedBy: activeHumanId) ? "—" : "\(human.coconutBalance)"
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
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoPill(title: "身份", value: human.roleText.isEmpty ? "成员" : human.roleText)
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

    private var visibilityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(Color.goLime, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("在首页显示")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(.white)
                Text(human.shouldShowOnHome ? "已加入首页卡堆与岛屿统计" : "不在首页卡堆与岛屿体重中显示")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { human.shouldShowOnHome },
                set: { human.shouldShowOnHome = $0; modelContext.safeSave() }
            ))
            .tint(Color.goLime)
            .labelsHidden()
        }
        .padding(14)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
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
            NavigationLink {
                HumanNoteHistorySheet(human: human)
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
            .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        let fallbackHumanId = allHumans.first(where: { $0.id.uuidString != deletedHumanId })?.id.uuidString ?? ""

        if activeHumanIdStr == deletedHumanId {
            activeHumanIdStr = fallbackHumanId
        }

        modelContext.delete(human)
        modelContext.safeSave()
        NotificationCenter.default.post(name: .ohanaReturnHomeAfterHumanDeletion, object: nil)
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
                    Color(hex: human.themeColorHex).mix(with: .white, by: 0.2),
                    Color(hex: "38BDF8").opacity(0.88),
                    Color(hex: "C8FF00").opacity(0.62),
                    Color(hex: human.themeColorHex),
                    Color(hex: "1A2E8A"),
                    Color(hex: "EC4899").opacity(0.7),
                    Color(hex: "0C1640"),
                    Color(hex: human.themeColorHex).mix(with: .black, by: 0.28),
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
                    heroChip(title: "椰子", value: "\(human.coconutBalance)")
                    heroChip(title: "运动", value: "\(human.workoutLogs.count)")
                    heroChip(title: "体重", value: "\(human.weightLogs.count)")
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
        .shadow(color: Color(hex: human.themeColorHex).opacity(0.28), radius: 22, y: 12)
    }

    private var humanSubtitle: String {
        let zodiac = human.birthday.map { Human.westernZodiacChinese(for: $0) }
        return [human.roleText, zodiac, human.mbti.isEmpty ? nil : human.mbti]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var latestWeightText: String {
        guard !human.isPrivate(.weight, viewedBy: activeHumanId) else { return "—" }
        guard let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first else { return "--" }
        return String(format: "%.1f", latest.weight)
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

            expandedCardFab(card: card)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20)
                .padding(.bottom, floatingFabBottomPadding)
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


// MARK: - Header Menu
private struct HeaderMenuButton: View {
    let onCrew: () -> Void

    @State private var showingPopover = false
    @State private var showingSettings = false

    var body: some View {
        Button {
            showingPopover = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .black))
                    .frame(width: 18)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(height: 26)
            .fixedSize(horizontal: true, vertical: false)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            HeaderPopoverMenu(
                onCrew: {
                    showingPopover = false
                    DispatchQueue.main.async {
                        onCrew()
                    }
                },
                onSettings: {
                    showingPopover = false
                    DispatchQueue.main.async {
                        showingSettings = true
                    }
                }
            )
            .presentationCompactAdaptation(.popover)
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Header Popover Menu (replacement for Menu to avoid Menu+sheet UIContextMenuInteraction conflict)
private struct HeaderPopoverMenu: View {
    let onCrew: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            popoverRow(icon: "person.3.fill", title: "OHANA 成员", action: onCrew)
            Divider()
            popoverRow(icon: "gearshape.fill", title: "设置", action: onSettings)
        }
        .frame(minWidth: 200)
        .padding(.vertical, 4)
    }

    private func popoverRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
