//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  GO Focus UI — default home page.
//  Formerly a test page; now the primary app home when appUIStyle == "go".
//

import SwiftUI
import SwiftData

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
    var avatarImageData: Data?
    var petSpecies: String?
    var coatColor:   Color = Color(hex: "E8C49A")
    var eyeColor:    Color = Color(hex: "6B3A2A")
    var patternName: String?
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
            avatarImageData: pet.avatarImageData,
            petSpecies: pet.species,
            coatColor: WalletPetCardTheme.silhouetteCoatColor(for: pet),
            eyeColor:  WalletPetCardTheme.silhouetteEyeColor(for: pet),
            patternName: WalletPetCardTheme.coatPatternName(for: pet),
            isReal: true,
            actions: Array(acts.prefix(4))
        )
    }

    static func from(_ human: Human) -> FocusCard {
        let hex = human.themeColorHex.isEmpty ? "B9E8D2" : human.themeColorHex
        return FocusCard(
            id: human.id,
            name: human.name.isEmpty ? "Human" : human.name,
            kind: human.roleText.isEmpty ? "HUMAN" : human.roleText,
            emoji: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji,
            color: Color(hex: hex),
            streak: 0,
            coconutBalance: human.coconutBalance,
            avatarImageData: human.avatarImageData,
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
    static let peekH: CGFloat = 76
    static var stackSpacing: CGFloat { -(cardH - peekH) }

    static let heroMargin: CGFloat = 16
    static let focusCardPadding: CGFloat = heroMargin / 3
}

private enum HeroAnim {
    static let stackCardCorner: CGFloat = 24
    static var transitionSpring: Animation {
        .interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.8)
    }
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
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
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
    @State private var selectedDockTab: Int = 0  // 0=home,1=plants,2=calendar,3=oasis

    // Debug-only: show Mochi/Luna dummy stack even when real data is empty.
    @AppStorage("debugShowDummyCards") private var showDummyCards: Bool = false

    // Bloom expand (dummy cards only)
    @Namespace private var ns
    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var detailFooterVisible: Bool = false

    // Apple-Wallet-style: id of card "pulled out" of the stack (others compress at bottom).
    // nil = collapsed stack (bottom card in front, top cards peek behind).
    @State private var selectedCardId: UUID?

    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 59
    }

    private var headerStreak: Int {
        pets.map { $0.currentStreak }.max() ?? 0
    }

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
                K.bg.ignoresSafeArea()

                stackLayer(geo: geo, outerCornerRadius: outerR)
                    .opacity(expandedId == nil ? 1 : 0)
                    .allowsHitTesting(expandedId == nil)

                if let id = expandedId,
                   let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo, outerCornerRadius: outerR, windowSize: windowSize)
                }

                // FAB: only visible when card stack is shown (not in card-expand mode)
                if expandedId == nil {
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
                }
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        // Sheets
        .sheet(isPresented: $showingFunctionMenu) {
            FunctionMenuSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStreakDetail) { DailyStreakDetailView(pets: pets) }
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
        .sheet(isPresented: $showingCalendar) { CalendarView() }
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

            // Mood + quest strip — fixed below header
            if !activePets.isEmpty {
                FocusMoodQuestStrip(
                    pets: activePets,
                    plants: plants,
                    pendingReminders: pendingReminders,
                    activePet: activePets.first,
                    checkInStreak: headerStreak,
                    quests: IslandQuestEngine.todayQuests(
                        pets: activePets,
                        reminders: pendingReminders,
                        plants: plants,
                        events: allEvents
                    ),
                    onCompleteQuest: { completeQuestInFocusStack($0) },
                    onExpand: { showStreakDetail = true }
                )
                .padding(.horizontal, K.cardMargin)
                .padding(.top, 12)
            }

            Spacer(minLength: 0)

            if !isEmptyState && cards.count > 1 {
                HStack {
                    Spacer()
                    Text("\(cards.count) 家人")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(K.ink.opacity(0.4))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.white.opacity(0.35), in: Capsule())
                }
                .padding(.horizontal, K.cardMargin)
                .padding(.bottom, 6)
            }

            if isEmptyState {
                EmptyStateWelcomeCard(
                    onAddPet:   { showingAddEntity = true },
                    onAddHuman: { showingAddEntity = true }
                )
                .padding(.horizontal, K.cardMargin)
                .padding(.bottom, 24)
            } else {
                walletCardStack(cards: cards)
                    .padding(.horizontal, K.cardMargin)
            }
        }
    }

    // MARK: Apple-Wallet-style card stack
    //
    // Layout rules:
    //  • Collapsed: cards fan top-to-bottom with `peekH` offset. Bottom-most card
    //    is frontmost (highest zIndex). Top cards peek from behind.
    //  • Selected: tapped card lifts to top of the container. Remaining cards
    //    compress into a tight fan at the bottom (`compactPeek`), preserving
    //    their original relative order.
    //  • Tap selected card → navigate (real pet/human) or bloom-expand (dummy).
    //  • Tap any compressed card → restore collapsed stack.

    @ViewBuilder
    private func walletCardStack(cards: [FocusCard]) -> some View {
        let n = cards.count
        let containerH = CGFloat(max(0, n - 1)) * K.peekH + K.cardH
        let selectedIdx = selectedCardId.flatMap { sid in cards.firstIndex(where: { $0.id == sid }) }

        ZStack(alignment: .top) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let isSelected = selectedCardId == card.id
                stackCard(card: card)
                    .frame(height: K.cardH)
                    .frame(maxWidth: .infinity)
                    .offset(y: walletCardOffset(idx: idx, n: n,
                                                containerH: containerH,
                                                selectedIdx: selectedIdx,
                                                isSelected: isSelected))
                    .scaleEffect(walletCardScale(idx: idx, n: n,
                                                 selectedIdx: selectedIdx,
                                                 isSelected: isSelected),
                                 anchor: .top)
                    .zIndex(walletCardZ(idx: idx, n: n, isSelected: isSelected))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(card.name) 的卡片")
                    .accessibilityHint(isSelected ? "再次点击查看详情" :
                                       (selectedIdx == nil ? "点击抽出卡片" : "点击收起卡片堆"))
                    .contextMenu { cardContextMenu(card: card) }
                    .onTapGesture { handleWalletCardTap(card: card, n: n) }
            }
        }
        .frame(height: containerH)
    }

    private func walletCardOffset(idx: Int, n: Int, containerH: CGFloat,
                                  selectedIdx: Int?, isSelected: Bool) -> CGFloat {
        guard let sel = selectedIdx else {
            // Collapsed: top-anchored fan.
            return CGFloat(idx) * K.peekH
        }
        if isSelected { return 0 }
        // Compressed at bottom, preserving relative order.
        let compactPeek: CGFloat = 14
        let compactCount = n - 1
        let pos = idx < sel ? idx : idx - 1   // 0 = topmost of compressed stack
        let bottomCardTop = containerH - K.cardH
        return bottomCardTop - CGFloat(compactCount - 1 - pos) * compactPeek
    }

    private func walletCardScale(idx: Int, n: Int,
                                 selectedIdx: Int?, isSelected: Bool) -> CGFloat {
        guard selectedIdx != nil else { return 1 }
        return isSelected ? 1 : 0.96
    }

    private func walletCardZ(idx: Int, n: Int, isSelected: Bool) -> Double {
        if isSelected { return Double(n + 100) }
        // Bottom card in front: higher idx → higher zIndex.
        return Double(idx)
    }

    private func handleWalletCardTap(card: FocusCard, n: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Single card: skip the stack-selection step, act immediately.
        if n <= 1 {
            navigateOrBloom(card: card)
            return
        }

        if let sel = selectedCardId {
            if card.id == sel {
                navigateOrBloom(card: card)
            } else {
                withAnimation(HeroAnim.transitionSpring) { selectedCardId = nil }
            }
        } else {
            withAnimation(HeroAnim.transitionSpring) { selectedCardId = card.id }
        }
    }

    private func navigateOrBloom(card: FocusCard) {
        if card.isReal && !card.isDummy {
            if card.isHuman {
                selectedHuman = humans.first(where: { $0.id == card.id })
            } else {
                selectedPet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway })
            }
        } else {
            withAnimation(HeroAnim.transitionSpring) { expandedId = card.id }
        }
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
                showingCalendar = true
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
        let fabItems: [(label: String, icon: String)] = [
            ("全部功能", "square.grid.2x2.fill"),
            ("日历",     "calendar"),
            ("绿洲",     "leaf.fill"),
            ("添加成员", "person.badge.plus"),
        ]

        VStack(alignment: .trailing, spacing: 14) {
            // Expanded action buttons (上方弹出)
            ForEach(Array(fabItems.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 10) {
                    // Label pill
                    Text(item.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(Color(hex: "1A2E8A"))
                            .frame(width: 48, height: 48)
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
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
                    withAnimation(.spring(response: 0.3)) { fabExpanded = false }
                    switch idx {
                    case 0: showingFunctionMenu = true
                    case 1: showingCalendar     = true
                    case 2: selectedDockTab     = 3
                    case 3: showingAddEntity    = true
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

    // MARK: 3-zone header

    private func goFocusHeader(safeT: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {

            Spacer()

            // ── Center: check-in capsule + coconut ──
            HStack(spacing: 8) {
                Button { showStreakDetail = true } label: {
                    HStack(spacing: 4) {
                        if headerStreak > 0 {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                        } else {
                            Image(systemName: "calendar.badge.checkmark").font(.system(size: 10, weight: .bold))
                        }
                        Text(headerStreak > 0 ? "\(headerStreak)天" : "打卡")
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(headerStreak > 0 ? Color(hex: "0C1640") : K.ink.opacity(0.6))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(headerStreak > 0 ? Color.goLime : K.ink.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)

                CoconutBalanceCapsule(onTap: { showingCoconutLog = true })
            }

            Spacer()

            // ── Right: ... menu ──
            Menu {
                Button { showingAddEntity = true }   label: { Label("添加成员", systemImage: "person.badge.plus") }
                Button { showingCrewRoster = true }  label: { Label("OHANA 成员", systemImage: "person.2.fill") }
                Button { showingSettings = true }    label: { Label("设置", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(K.ink.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(K.ink.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, K.hPad)
        .padding(.top, safeT + 12)
        .frame(height: safeT + 56)
    }

    // MARK: Single stack card

    private func stackCard(card: FocusCard) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .fill(card.color)
                .matchedGeometryEffect(id: HeroShellID(cardId: card.id), in: ns,
                                       isSource: !(expandedId == card.id))

            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.50)
            )
            .clipShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous))
            .allowsHitTesting(false)

            stackHeroArtPreview(card: card)
                .matchedGeometryEffect(id: HeroArtID(cardId: card.id), in: ns,
                                       isSource: !(expandedId == card.id))
                .frame(maxWidth: .infinity)
                .frame(height: K.cardH - K.peekH - 8, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 18)
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.kind.prefix(6).uppercased())
                        .fcMicro()
                        .foregroundStyle(K.ink.opacity(0.38))
                    Text(card.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(K.ink.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)
                }

                Spacer(minLength: 8)

                if card.streak > 0 {
                    HStack(spacing: 3) {
                        Text("🔥")
                        Text("\(card.streak)").fcMicro(weight: .bold).foregroundStyle(K.ink.opacity(0.55))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.32), in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(height: K.peekH)
        }
        .frame(height: K.cardH)
        .clipShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous))
        // NavigationStack zoom source for real pets
        .modifier(RealPetTransitionModifier(card: card, heroNS: heroNS))
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

    private func stackHeroArtPreview(card: FocusCard) -> some View {
        ZStack {
            LinearGradient(
                colors: [card.color.mix(with: .white, by: 0.28),
                         card.color,
                         card.color.mix(with: .black, by: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Group {
                if let data = card.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(minHeight: 120).clipped()
                } else if card.isHuman {
                    Text(card.emoji.isEmpty ? "👤" : card.emoji)
                        .font(.system(size: 56))
                } else if card.petSpecies != nil {
                    PetSilhouetteView(
                        species: normalizeSpecies(card.petSpecies ?? ""),
                        coatColor: card.coatColor,
                        eyeColor: card.eyeColor,
                        patternName: card.patternName,
                        isAnimationEnabled: false
                    )
                    .scaleEffect(1.15)
                } else {
                    Text(card.emoji).font(.system(size: 56))
                }
            }
        }
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
