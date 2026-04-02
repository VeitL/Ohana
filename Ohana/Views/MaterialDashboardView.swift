//  MaterialDashboardView.swift — strict replica of Ai_Studio_New_UI/PetDashboard.tsx

import SwiftUI
import SwiftData
import Charts
import MapKit

private enum MatCardType: String, Equatable {
    case feeding, waterChange, litter, expenses, weight, walk
}

private struct MatUrgentPulseModifier: ViewModifier {
    let isUrgent: Bool
    let cornerRadius: CGFloat
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isUrgent {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.goOrange.opacity(pulse ? 0.85 : 0.25), lineWidth: 1.5)
                }
            }
            .onAppear {
                guard isUrgent else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

struct MaterialDashboardView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    var heroNS: Namespace.ID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    // MARK: – Tab / Pet
    @State private var activeTab = 0
    @State private var calendarAddEventTrigger = false
    @State private var activePetIndex = 0

    // MARK: – Action States
    @State private var fedPets:     Set<UUID> = []
    @State private var wateredPets: Set<UUID> = []

    // Feeding
    @State private var feedingAnim:  [UUID: Bool]   = [:]
    @State private var feedingDrops: [UUID: [UUID]] = [:]

    // Card Expansion (unified)
    @State private var expandedCard: MatCardType? = nil

    // Water Change
    @State private var lastWaterChangeDates: [UUID: Date] = [:]
    @State private var lastDeepCleanDates:   [UUID: Date] = [:]

    // Quick Expense entry
    @State private var quickExpenseAmount = ""

    // Water
    @State private var waterAnim:  [UUID: Bool]   = [:]
    @State private var waterDrops: [UUID: [UUID]] = [:]

    // Litter
    @State private var litterAnim:  [UUID: Bool]   = [:]
    @State private var litterDrops: [UUID: [UUID]] = [:]

    // Expenses
    @State private var expenseAnim: [UUID: Bool] = [:]

    // Walk
    @State private var walkExpanded      = false
    @State private var isWalkActive      = false
    @State private var isWalking         = false
    @State private var showWalkSummary   = false
    @State private var walkStartDate:    Date? = nil   // non-nil only while timer running
    @State private var walkPausedElapsed: Int  = 0    // accumulated seconds while paused
    @State private var walkGoalMins      = 30
    @State private var lastWalkTime      = 0
    @State private var walkPoopCount: [UUID: Int] = [:]  // per-pet poop taps during walk

    @State private var appeared     = false
    @State private var showSettings  = false
    @State private var showAddEntity = false
    @State private var showAddWeight  = false
    @State private var showAddExpense = false
    @State private var cardVisible    = Array(repeating: true, count: 6)

    // Suck-in coconut particles
    @State private var coinParticles: [MatCoinParticle] = []
    @State private var matQuestCoconutReward = false
    @State private var matQuestCoconutAmount = 0

    // Tree widget inject press
    @State private var treeInjectPressing = false

    // Card expand namespace
    @Namespace private var cardExpandNS

    // Coconut button position (for particle target)
    @State private var coconutBtnOrigin: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 56, y: 52)
    // Card origins for particle source
    @State private var cardOrigins: [MatCardType: CGPoint] = [:]

    // MARK: – Colors (cached — updated only when colorScheme changes)
    private static let accentC  = Color(hex: "FF5A00")
    private static let bgLight  = Color(hex: "F5F5F7")
    private static let bgDark   = Color(hex: "0A0A0C")
    private static let surf1D   = Color(hex: "1C1C1E")
    private static let surf2L   = Color(hex: "F0F2F5")
    private static let surf2D   = Color(hex: "2C2C2E")
    private static let textSecL = Color(hex: "8E8E93")
    private static let textSecD = Color(hex: "64748B")

    private var bg:      Color { colorScheme == .light ? Self.bgLight  : Self.bgDark  }
    private var surface: Color { colorScheme == .light ? .white         : Self.surf1D  }
    private var surf2:   Color { colorScheme == .light ? Self.surf2L    : Self.surf2D  }
    private let accent   = Self.accentC
    private var textSec: Color { colorScheme == .light ? Self.textSecL  : Self.textSecD }

    private var activePet: Pet? {
        guard !pets.isEmpty else { return nil }
        return pets[activePetIndex % pets.count]
    }
    private var ownerName:  String  { humans.first?.name ?? "there" }

    // Background image based on active pet species
    private var activePetBgImageName: String {
        let s = (activePet?.species ?? "").lowercased()
        if s.contains("猫") || s.contains("cat") { return "bg_cat" }
        return "bg_dog"
    }
    private static let cardSize: CGFloat = (UIScreen.main.bounds.width - 32 - 14) / 2
    private var cardSize: CGFloat { Self.cardSize }
    private var coconutCount: Int   { QuestManager.shared.coconutCount }

    // MARK: – Body
    var body: some View {
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()
            Group {
                switch activeTab {
                case 0: homeTab
                case 1: PlantDashboardView(selectedPlant: $selectedPlant)
                case 2: CalendarView(hideToolbar: true, addEventTrigger: calendarAddEventTrigger)
                case 3: OasisRewardView(hideToolbar: true)
                default: homeTab
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activeTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            matBottomNav
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { appeared = true }
        }
        .sheet(isPresented: $showSettings)  { SettingsView() }
        .sheet(isPresented: $showAddEntity) { AddEntityView() }
        .sheet(isPresented: $showAddWeight) {
            if let pet = activePet { QuickWeightSheet(pet: pet) }
        }
        .sheet(isPresented: $showAddExpense) {
            if let pet = activePet { AddExpenseSheet(pet: pet, preselectedPayerId: humans.first?.id.uuidString) }
        }
        .coconutRewardOverlay(trigger: $matQuestCoconutReward, amount: matQuestCoconutAmount)
    }

    // MARK: – Home Tab (full-screen bg + hero top 1/3 + glass panel bottom 2/3)
    private var homeTab: some View {
        let screenH = UIScreen.main.bounds.height
        let heroH   = screenH * 0.42   // hero occupies ~42% of screen height

        return ZStack(alignment: .top) {
            // ── 1. Background image (fixed, full screen)
            Image(activePetBgImageName)
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: screenH)
                .clipped()
                .ignoresSafeArea()
                .blur(radius: 0, opaque: false)  // Top area: sharp
                .animation(.easeInOut(duration: 0.7), value: activePetBgImageName)

            // ── 1b. Blurred background for bottom 2/3 with gradient mask
            Image(activePetBgImageName)
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: screenH)
                .clipped()
                .blur(radius: 24, opaque: false)  // Heavy blur for content area
                .ignoresSafeArea()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.38),
                            .init(color: .white, location: 0.48),
                            .init(color: .white, location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .animation(.easeInOut(duration: 0.7), value: activePetBgImageName)

            // ── 2. Gradient scrim (top subtle dark, mid neutral, bottom fades into glass)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.32), location: 0.0),
                    .init(color: .black.opacity(0.08), location: 0.20),
                    .init(color: .black.opacity(0.00), location: 0.32),
                    .init(color: .black.opacity(0.18), location: 0.42),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── 3. Scrollable layer
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero area — transparent, background image shows through
                    Group {
                        if let pet = activePet {
                            petHeroSection(pet: pet)
                        } else {
                            Color.clear.frame(height: heroH)
                        }
                    }
                    .frame(height: heroH)

                    // ── Glass panel (bottom 2/3)
                    VStack(spacing: 0) {
                        // Pull handle
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(width: 36, height: 4)
                            .padding(.top, 10).padding(.bottom, 6)

                        if pets.isEmpty {
                            matEmptyState
                                .padding(.horizontal, 20).padding(.bottom, 28)
                        } else if let pet = activePet {
                            IslandEnergyBarContainer()
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.45).delay(0.08), value: appeared)

                            IslandQuestCarousel(
                                pets: pets,
                                plants: plants,
                                todayQuests: IslandQuestEngine.todayQuests(pets: pets, reminders: pendingReminders, plants: plants, events: allEvents),
                                onComplete: { matCompleteIslandQuest($0) },
                                onSkip: { _ in },
                                onQuestProgress: { completed, total in
                                    IslandToastManager.shared.showQuestProgress(completed: completed, total: total)
                                }
                            )
                            .padding(.bottom, 12)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.45).delay(0.1), value: appeared)

                            actionsSectionHeader(pet: pet)
                                .padding(.horizontal, 24).padding(.bottom, 16)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.45).delay(0.15), value: appeared)

                            activityGrid(pet: pet)
                                .padding(.horizontal, 16).padding(.bottom, 16)
                                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                                .animation(.easeOut(duration: 0.45).delay(0.18), value: appeared)

                            lifeTreeWidget
                                .padding(.horizontal, 16).padding(.bottom, 32)
                                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                                .animation(.easeOut(duration: 0.45).delay(0.22), value: appeared)

                            globalOverviewSection
                                .padding(.horizontal, 16).padding(.bottom, 120)
                                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                                .animation(.easeOut(duration: 0.45).delay(0.25), value: appeared)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 32, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 32,
                        style: .continuous))
                }
            }

            // ── 4. Sticky header
            matStickyHeader

            // ── 5. Tap overlay to dismiss expanded card
            if expandedCard != nil {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            expandedCard = nil
                        }
                    }
            }

            // ── 6. Coin particles
            ForEach(coinParticles) { p in
                MatCoinParticleView(particle: p)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: – Pet Hero Section (shown in the transparent top area over background image)
    private func petHeroSection(pet: Pet) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)   // clear space below sticky header
            Spacer()
            VStack(spacing: 14) {
                // Avatar
                Group {
                    if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(Color(hex: pet.themeColorHex).opacity(0.55))
                            Text(pet.speciesEmoji)
                                .font(.system(size: 44))
                        }
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)

                // Name
                Text(pet.name)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                    .lineLimit(1).minimumScaleFactor(0.6)

                // Species + status chips
                HStack(spacing: 8) {
                    if !pet.species.isEmpty {
                        Text(pet.species)
                            .font(.system(size: 12, weight: .bold)).tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.black.opacity(0.30), in: Capsule())
                    }
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: "34C759")).frame(width: 7, height: 7)
                        Text("Happy & Active")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: Capsule())
                }

                // Pet switcher dots
                if pets.count > 1 {
                    HStack(spacing: 7) {
                        ForEach(0..<pets.count, id: \.self) { i in
                            Circle()
                                .fill(i == activePetIndex ? .white : .white.opacity(0.38))
                                .frame(width: i == activePetIndex ? 8 : 5,
                                       height: i == activePetIndex ? 8 : 5)
                                .animation(.spring(response: 0.3), value: activePetIndex)
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                        activePetIndex = i
                                    }
                                }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { val in
                    guard pets.count > 1 else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        if val.translation.width < 0 {
                            activePetIndex = (activePetIndex + 1) % pets.count
                        } else {
                            activePetIndex = (activePetIndex - 1 + pets.count) % pets.count
                        }
                    }
                }
        )
    }

    // MARK: – Sticky 3-button header (settings | add | … | coconut)
    private var matStickyHeader: some View {
        HStack(spacing: 10) {
            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(textSec)
                    .frame(width: 40, height: 40)
                    .background(surface, in: Circle())
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }.buttonStyle(ScaleButtonStyle())

            // Add entity
            Button { showAddEntity = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 2)
            }.buttonStyle(ScaleButtonStyle())

            Spacer()

            // Coconut balance (rightmost)
            Button { activeTab = 3 } label: {
                HStack(spacing: 5) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("\(coconutCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: coconutCount)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(surface, in: Capsule())
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        let frame = geo.frame(in: .global)
                        coconutBtnOrigin = CGPoint(x: frame.midX, y: frame.midY)
                    }
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 52)   // clear Dynamic Island + status bar
        .padding(.bottom, 10)
        .background(
            .ultraThinMaterial
                .opacity(activeTab == 0 ? 0.85 : 1)
        )
        .background(activeTab == 0 ? .clear : bg.opacity(0.92))
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: appeared)
    }

    // MARK: – Greeting (scrolls with content)
    private var matGreeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Hi \(ownerName),")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary).tracking(-0.5)
                Text("Welcome Home!")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .foregroundStyle(textSec).tracking(-0.5)
            }
            Spacer()
        }
    }

    // MARK: – Stacked Pet Cards
    /// Rotating window: always shows 3 pets centered on activePetIndex
    private var visibleStackPets: [(stackPos: Int, pet: Pet)] {
        guard !pets.isEmpty else { return [] }
        let n = pets.count
        return (0..<min(3, n)).map { slot in
            (slot, pets[(activePetIndex + slot) % n])
        }
    }

    private var stackedPetCards: some View {
        ZStack {
            ForEach(visibleStackPets, id: \.pet.id) { item in
                stackedCard(pet: item.pet, stackOffset: item.stackPos)
                    .zIndex(Double(10 - item.stackPos))
            }
        }
        .frame(height: 340)
        .onChange(of: pets.count) { old, new in
            guard new > old else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                activePetIndex = new - 1
            }
            triggerCardStagger()
        }
    }

    private func stackedCard(pet: Pet, stackOffset: Int) -> some View {
        let isTop  = stackOffset == 0
        let scale  = 1.0 - CGFloat(stackOffset) * 0.06
        let yOff   = CGFloat(stackOffset) * 30
        let rotDeg: Double = stackOffset == 0 ? 0 : stackOffset == 1 ? -4 : 4
        let cardW  = UIScreen.main.bounds.width * 0.82

        return ZStack {
            // Gradient background from pet theme color
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: pet.themeColorHex).opacity(0.85),
                             Color(hex: pet.themeColorHex)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            // Pet photo (fills card) or fallback paw
            if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                ZStack {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: cardW, height: cardW)
                        .clipped()
                    // Dark-to-transparent overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom)
                }
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable().scaledToFit().frame(width: 130)
                    .foregroundStyle(.white.opacity(0.15))
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(24)
            }

            // Content overlay
            VStack(alignment: .leading) {
                // Breed / species tag
                HStack {
                    Text(pet.species.isEmpty ? "Pet" : pet.species)
                        .font(.system(size: 11, weight: .bold)).tracking(1.5).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.black.opacity(0.25), in: Capsule())
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Pet name
                        Text(pet.name)
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        // Status chip
                        HStack(spacing: 6) {
                            Circle().fill(.white.opacity(0.9)).frame(width: 8, height: 8)
                                .overlay(Circle().fill(Color(hex: "34C759")).frame(width: 5, height: 5))
                            Text("Happy & Active")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Spacer()
                    if isTop {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 48, height: 48)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: cardW, height: cardW)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(isTop ? 0.22 : 0.12), radius: 20, x: 0, y: 8)
        .scaleEffect(scale)
        .offset(y: yOff)
        .rotationEffect(.degrees(rotDeg), anchor: .top)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: activePetIndex)
        .onTapGesture {
            guard isTop else { return }
            guard pets.count > 1 else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                activePetIndex = (activePetIndex + 1) % pets.count
            }
            triggerCardStagger()
        }
    }

    // MARK: – "{pet.name}'s Actions" pill header
    private func actionsSectionHeader(pet: Pet) -> some View {
        HStack {
            Text("\(pet.name)'s Actions")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(surface, in: Capsule())
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            Spacer()
            Circle().fill(surf2).frame(width: 36, height: 36)
                .overlay(Text("🐾").font(.system(size: 16)))
        }
    }

    // MARK: – Activity Grid (5-card bento: feeding/water/litter/expenses/weight + full-width walk)
    @ViewBuilder
    private func activityGrid(pet: Pet) -> some View {
        let bentoTypes: [MatCardType] = [.feeding, .waterChange, .litter, .expenses, .weight]
        let inBento = expandedCard.map { bentoTypes.contains($0) } ?? false

        VStack(spacing: 14) {
            if inBento, let exp = expandedCard {
                // — Expanded card: grows in place via matchedGeometryEffect —
                bentoCardView(type: exp, pet: pet, isExpanded: true)
                    .frame(maxWidth: .infinity)
                    .modifier(MatUrgentPulseModifier(
                        isUrgent: matShouldPulseUrgent(type: exp, pet: pet),
                        cornerRadius: 24
                    ))
                    .matchedGeometryEffect(id: exp.rawValue, in: cardExpandNS)

                // — Remaining 4 cards dimmed below in 2 rows —
                let rest = bentoTypes.filter { $0 != exp }
                HStack(spacing: 14) {
                    bentoCardView(type: rest[0], pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: rest[0], pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(0.4).scaleEffect(0.97)
                    bentoCardView(type: rest[1], pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: rest[1], pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(0.4).scaleEffect(0.97)
                }
                HStack(spacing: 14) {
                    bentoCardView(type: rest[2], pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: rest[2], pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(0.4).scaleEffect(0.97)
                    bentoCardView(type: rest[3], pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: rest[3], pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(0.4).scaleEffect(0.97)
                }
            } else {
                // — Normal 2×3 Bento grid —
                HStack(spacing: 14) {
                    bentoCardView(type: .feeding, pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: .feeding, pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(cardVisible[0] ? focusOpacity(.feeding) : 0)
                        .scaleEffect(cardVisible[0] ? focusScale(.feeding) : 0.85, anchor: .center)
                        .matchedGeometryEffect(id: MatCardType.feeding.rawValue, in: cardExpandNS)
                        .onGeometryChange(for: CGPoint.self) { g in let f = g.frame(in: .global); return CGPoint(x: f.midX, y: f.midY) } action: { cardOrigins[.feeding] = $0 }
                    bentoCardView(type: .waterChange, pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: .waterChange, pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(cardVisible[1] ? focusOpacity(.waterChange) : 0)
                        .scaleEffect(cardVisible[1] ? focusScale(.waterChange) : 0.85, anchor: .center)
                        .matchedGeometryEffect(id: MatCardType.waterChange.rawValue, in: cardExpandNS)
                        .onGeometryChange(for: CGPoint.self) { g in let f = g.frame(in: .global); return CGPoint(x: f.midX, y: f.midY) } action: { cardOrigins[.waterChange] = $0 }
                }
                HStack(spacing: 14) {
                    bentoCardView(type: .litter, pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: .litter, pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(cardVisible[2] ? focusOpacity(.litter) : 0)
                        .scaleEffect(cardVisible[2] ? focusScale(.litter) : 0.85, anchor: .center)
                        .matchedGeometryEffect(id: MatCardType.litter.rawValue, in: cardExpandNS)
                        .onGeometryChange(for: CGPoint.self) { g in let f = g.frame(in: .global); return CGPoint(x: f.midX, y: f.midY) } action: { cardOrigins[.litter] = $0 }
                    bentoCardView(type: .expenses, pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: .expenses, pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(cardVisible[3] ? focusOpacity(.expenses) : 0)
                        .scaleEffect(cardVisible[3] ? focusScale(.expenses) : 0.85, anchor: .center)
                        .matchedGeometryEffect(id: MatCardType.expenses.rawValue, in: cardExpandNS)
                        .onGeometryChange(for: CGPoint.self) { g in let f = g.frame(in: .global); return CGPoint(x: f.midX, y: f.midY) } action: { cardOrigins[.expenses] = $0 }
                }
                HStack(spacing: 14) {
                    bentoCardView(type: .weight, pet: pet, isExpanded: false)
                        .modifier(MatUrgentPulseModifier(
                            isUrgent: matShouldPulseUrgent(type: .weight, pet: pet),
                            cornerRadius: 16
                        ))
                        .opacity(cardVisible[4] ? focusOpacity(.weight) : 0)
                        .scaleEffect(cardVisible[4] ? focusScale(.weight) : 0.85, anchor: .center)
                        .matchedGeometryEffect(id: MatCardType.weight.rawValue, in: cardExpandNS)
                        .onGeometryChange(for: CGPoint.self) { g in let f = g.frame(in: .global); return CGPoint(x: f.midX, y: f.midY) } action: { cardOrigins[.weight] = $0 }
                    Color.clear.frame(maxWidth: .infinity, maxHeight: cardSize)
                }
            }

            // — Walk card (full-width) —
            walkCard(pet: pet)
                .modifier(MatUrgentPulseModifier(
                    isUrgent: matBentoUrgent(type: .walk, pet: pet) && !matTodayWalkDone(for: pet),
                    cornerRadius: 24
                ))
                .opacity(cardVisible[5] ? focusOpacity(.walk) : 0)
                .scaleEffect(cardVisible[5] ? 1 : 0.85, anchor: .center)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.88), value: expandedCard)
    }

    @ViewBuilder
    private func bentoCardView(type: MatCardType, pet: Pet, isExpanded: Bool) -> some View {
        switch type {
        case .feeding:     feedingCard(pet: pet, isExpanded: isExpanded)
        case .waterChange: waterChangeCard(pet: pet, isExpanded: isExpanded)
        case .litter:      litterCard(pet: pet, isExpanded: isExpanded)
        case .expenses:    expensesCard(pet: pet, isExpanded: isExpanded)
        case .weight:      weightCard(pet: pet, isExpanded: isExpanded)
        default:           EmptyView()
        }
    }

    private func focusOpacity(_ type: MatCardType) -> Double {
        guard let exp = expandedCard else { return 1 }
        return exp == type ? 1 : 0.4
    }

    private func focusScale(_ type: MatCardType) -> CGFloat {
        guard let exp = expandedCard else { return 1 }
        return exp == type ? 1 : 0.97
    }

    // MARK: – Feeding Card (split-half transparent container)
    private func feedingCard(pet: Pet, isExpanded: Bool) -> some View {
        let isFed       = fedPets.contains(pet.id)
        let isAnimating = feedingAnim[pet.id] == true

        return ZStack(alignment: .top) {
            // Food particle drops
            if let drops = feedingDrops[pet.id] {
                ForEach(drops, id: \.self) { _ in FoodParticleView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isExpanded {
                // Expanded: full white card with detail
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(surface)
                    .overlay(feedingExpandedContent(pet: pet, isFed: isFed))
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            } else {
                // Compact: two seamless white halves (no gap)
                VStack(spacing: 0) {
                    // TOP HALF
                    HStack(alignment: .top) {
                        Circle().fill(Color(hex: "F0F4F8")).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "fork.knife")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "4A90E2")))
                        Spacer()
                        Button {
                            guard feedingDrops[pet.id] == nil else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            triggerFeedingAnim(for: pet.id, origin: cardOrigins[.feeding])
                        } label: {
                            Circle()
                                .fill(isFed ? Color(hex: "34C759") : surf2)
                                .frame(width: 32, height: 32)
                                .overlay(Image(systemName: isFed ? "checkmark" : "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isFed ? .white : textSec))
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 18).padding(.top, 18)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .background(surface)
                    .clipShape(MatTopRoundedRect(radius: 24))
                    .offset(y: isAnimating ? -12 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isAnimating)

                    // BOTTOM HALF
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Feeding")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text(isFed ? "Just now" : "Last: 2h ago")
                                .font(.system(size: 12)).foregroundStyle(textSec)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .background(surface)
                    .clipShape(MatBottomRoundedRect(radius: 24))
                    .offset(y: isAnimating ? 12 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isAnimating)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 280 : cardSize)
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandedCard != .feeding else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = .feeding }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExpanded)
    }

    private func feedingExpandedContent(pet: Pet, isFed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(Color(hex: "F0F4F8")).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "4A90E2")))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        expandedCard = nil
                    }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                        .frame(width: 32, height: 32).background(surf2, in: Circle())
                }.buttonStyle(ScaleButtonStyle())
            }
            Text("Feeding").font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Manage \(pet.name)'s diet").font(.system(size: 14)).foregroundStyle(textSec)

            VStack(spacing: 8) {
                feedingRow(title: "Morning Portion", sub: "80g Dry Food", done: true)
                feedingRow(title: "Evening Portion", sub: "80g Wet Food", done: isFed)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                triggerFeedingAnim(for: pet.id)
            } label: {
                Text(isFed ? "Fed Successfully ✓" : "Mark as Fed")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(isFed ? Color(hex: "34C759") : Color(hex: "4A90E2"),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
    }

    private func feedingRow(title: String, sub: String, done: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(sub).font(.system(size: 12)).foregroundStyle(textSec)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: "34C759")).font(.system(size: 20))
            } else {
                Circle().strokeBorder(Color(hex: "C7C7CC"), lineWidth: 2).frame(width: 20, height: 20)
            }
        }
        .padding(14).background(surf2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func triggerFeedingAnim(for id: UUID, origin: CGPoint? = nil) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { feedingAnim[id] = true }
        feedingDrops[id] = (0..<6).map { _ in UUID() }
        launchCoconutParticles(from: origin)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { feedingAnim[id] = false }
            _ = fedPets.insert(id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { feedingDrops[id] = nil }
    }

    // MARK: – Water Change Card (wave bg + collapsed/expanded)
    private func waterChangeCard(pet: Pet, isExpanded: Bool) -> some View {
        let isRising = waterAnim[pet.id] == true
        let lastChange = lastWaterChangeDates[pet.id] ?? Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let daysSince  = max(0, Calendar.current.dateComponents([.day], from: lastChange, to: Date()).day ?? 0)
        let lastDeep   = lastDeepCleanDates[pet.id]   ?? Calendar.current.date(byAdding: .day, value: -18, to: Date())!
        let deepDays   = max(0, Calendar.current.dateComponents([.day], from: lastDeep, to: Date()).day ?? 0)
        let filterLeft = max(0, 30 - deepDays)
        let waveColor  = daysSince > 5 ? Color(hex: "E8C840") : Color(hex: "4A90E2")

        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(surface)
            if !isExpanded {
                MatWaveView(isRising: isRising)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .opacity(daysSince > 5 ? 0.6 : 1.0)
            }
            if let drops = waterDrops[pet.id] {
                ForEach(drops, id: \.self) { _ in WaterParticleView() }
            }

            if isExpanded {
                // — Expanded micro-dashboard —
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Circle().fill(Color(hex: "E6F0FA")).frame(width: 48, height: 48)
                            .overlay(Image(systemName: "drop.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(waveColor))
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = nil }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                                .frame(width: 32, height: 32).background(surf2, in: Circle())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    Text("Water Change").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("已换水 \(daysSince) 天").font(.system(size: 13)).foregroundStyle(textSec)

                    // Filter countdown
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("下次换滤芯").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("\(filterLeft) 天后").font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(surf2).frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(filterLeft < 7 ? Color(hex: "FF3B30") : accent)
                                    .frame(width: geo.size.width * CGFloat(filterLeft) / 30.0, height: 8)
                            }
                        }.frame(height: 8)
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            lastWaterChangeDates[pet.id] = Date()
                            triggerWaterAnim(for: pet.id)
                        } label: {
                            Label("日常换水", systemImage: "drop.fill")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color(hex: "4A90E2"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(ScaleButtonStyle())

                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            lastWaterChangeDates[pet.id] = Date()
                            lastDeepCleanDates[pet.id]   = Date()
                            triggerWaterAnim(for: pet.id)
                        } label: {
                            Label("深度清洗", systemImage: "sparkles")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color(hex: "30B0C7"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(20)
            } else {
                // — Collapsed state —
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Circle().fill(Color(hex: "E6F0FA")).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "drop.fill")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(waveColor))
                        Spacer()
                        Button {
                            guard waterDrops[pet.id] == nil else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            lastWaterChangeDates[pet.id] = Date()
                            triggerWaterAnim(for: pet.id)
                        } label: {
                            Circle().fill(surf2).frame(width: 32, height: 32)
                                .overlay(Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(textSec))
                        }.buttonStyle(ScaleButtonStyle())
                    }.padding(.horizontal, 18).padding(.top, 18)
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Water Change")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text("已换水 \(daysSince) 天")
                                .font(.system(size: 12)).foregroundStyle(textSec)
                        }
                        Spacer()
                    }.padding(.horizontal, 18).padding(.bottom, 18)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 300 : cardSize)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandedCard != .waterChange else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = .waterChange }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExpanded)
    }

    private func triggerWaterAnim(for id: UUID, origin: CGPoint? = nil) {
        withAnimation(.easeInOut(duration: 0.8)) { waterAnim[id] = true }
        waterDrops[id] = (0..<5).map { _ in UUID() }
        launchCoconutParticles(from: origin)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { _ = wateredPets.insert(id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { waterDrops[id] = nil; waterAnim[id] = false }
    }

    // MARK: – Litter Card (split halves, lid rotation + expanded Bristol log)
    private func litterCard(pet: Pet, isExpanded: Bool) -> some View {
        let isOpen = litterAnim[pet.id] == true
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(surface)
            if let drops = litterDrops[pet.id] {
                ForEach(drops, id: \.self) { _ in PoopParticleView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isExpanded {
                // — Expanded: Bristol stool log —
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Circle().fill(Color(hex: "F4F8E6")).frame(width: 48, height: 48)
                            .overlay(Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: "8BC34A")))
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = nil }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                                .frame(width: 32, height: 32).background(surf2, in: Circle())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    Text("Litter / Potty").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("记录便便状态").font(.system(size: 13)).foregroundStyle(textSec)

                    // Bristol type quick log
                    HStack(spacing: 8) {
                        ForEach([("干硬","💩"), ("正常","💩"), ("软便","💩"), ("稀便","💧"), ("水样","🌊")], id: \.0) { type, emoji in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                triggerLitterAnim(for: pet.id)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(emoji).font(.system(size: 18))
                                    Text(type).font(.system(size: 9, weight: .semibold)).foregroundStyle(textSec)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(surf2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }.buttonStyle(ScaleButtonStyle())
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("上次全盆更换").font(.system(size: 12)).foregroundStyle(textSec)
                            Text("14 天前").font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Text("记录更换").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(hex: "8BC34A"), in: Capsule())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(20)
            } else {
                // — Collapsed: split halves lid animation —
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Circle()
                            .fill(isOpen ? Color(hex: "FFF0F0") : Color(hex: "F4F8E6"))
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "trash.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isOpen ? Color(hex: "FF3B30") : Color(hex: "8BC34A")))
                        Spacer()
                        Button {
                            guard litterDrops[pet.id] == nil else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            triggerLitterAnim(for: pet.id)
                        } label: {
                            Circle().fill(surf2).frame(width: 32, height: 32)
                                .overlay(Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(textSec))
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 18).padding(.top, 18)
                    .frame(maxWidth: .infinity).frame(maxHeight: .infinity)
                    .background(surface)
                    .clipShape(MatTopRoundedRect(radius: 24))
                    .rotationEffect(.degrees(isOpen ? 15 : 0), anchor: .bottomTrailing)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isOpen)
                    .zIndex(2)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Litter").font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text(isOpen ? "Cleaning..." : "Clean")
                                .font(.system(size: 12)).foregroundStyle(textSec)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.bottom, 18)
                    .frame(maxWidth: .infinity).frame(maxHeight: .infinity)
                    .background(surface)
                    .clipShape(MatBottomRoundedRect(radius: 24))
                    .zIndex(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 310 : cardSize)
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandedCard != .litter else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = .litter }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExpanded)
    }

    private func triggerLitterAnim(for id: UUID, origin: CGPoint? = nil) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { litterAnim[id] = true }
        litterDrops[id] = (0..<3).map { _ in UUID() }
        launchCoconutParticles(from: origin)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { litterAnim[id] = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { litterDrops[id] = nil }
    }

    // MARK: – Expenses Card (coin pop-up + expanded breakdown)
    private func expensesCard(pet: Pet, isExpanded: Bool) -> some View {
        let isAnim = expenseAnim[pet.id] == true
        let categories: [(String, Double, Color)] = [
            ("食物", 62, Color(hex: "FF9500")),
            ("医疗", 22, Color(hex: "FF3B30")),
            ("美容", 10, Color(hex: "AF52DE")),
            ("用品", 6,  Color(hex: "5856D6"))
        ]
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(surface)

            if !isExpanded && isAnim {
                Circle().fill(Color(hex: "FFCC00"))
                    .frame(width: 26, height: 26)
                    .overlay(Text("$").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "B38F00")))
                    .shadow(color: Color(hex: "FFCC00").opacity(0.5), radius: 6, x: 0, y: 2)
                    .offset(x: -50, y: -52)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 18).padding(.top, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isExpanded {
                // — Expanded: category breakdown + quick add —
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Circle().fill(Color(hex: "F2F2F7")).frame(width: 48, height: 48)
                            .overlay(Image(systemName: "creditcard.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: "5856D6")))
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = nil }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                                .frame(width: 32, height: 32).background(surf2, in: Circle())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$120").font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("/ 本月").font(.system(size: 13)).foregroundStyle(textSec)
                    }

                    // Category bars
                    VStack(spacing: 8) {
                        ForEach(categories, id: \.0) { name, pct, color in
                            HStack(spacing: 8) {
                                Text(name).font(.system(size: 12, weight: .semibold)).frame(width: 36, alignment: .leading)
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(surf2).frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4).fill(color)
                                            .frame(width: g.size.width * pct / 100, height: 8)
                                    }
                                }.frame(height: 8)
                                Text("\(Int(pct))%").font(.system(size: 11)).foregroundStyle(textSec).frame(width: 32, alignment: .trailing)
                            }
                        }
                    }

                    // Quick add
                    HStack(spacing: 8) {
                        TextField("金额", text: $quickExpenseAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(surf2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .frame(maxWidth: .infinity)
                        Button {
                            showAddExpense = true
                            quickExpenseAmount = ""
                        } label: {
                            Text("记账")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 18).padding(.vertical, 8)
                                .background(Color(hex: "5856D6"), in: Capsule())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(20)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Circle().fill(Color(hex: "F2F2F7")).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "creditcard.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "5856D6")))
                            .scaleEffect(isAnim ? 1.12 : 1.0)
                            .offset(y: isAnim ? 4 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.35), value: isAnim)
                        Spacer()
                        Button { showAddExpense = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                                .frame(width: 32, height: 32).background(surf2, in: Circle())
                        }.buttonStyle(ScaleButtonStyle())
                    }.padding(.horizontal, 18).padding(.top, 18)
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isAnim ? "+ $15" : "$120")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(isAnim ? Color(hex: "34C759") : .primary)
                                .animation(.easeIn(duration: 0.2), value: isAnim)
                            Text("This Month").font(.system(size: 12)).foregroundStyle(textSec)
                        }
                        Spacer()
                    }.padding(.horizontal, 18).padding(.bottom, 18)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 360 : cardSize)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandedCard != .expenses else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = .expenses }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExpanded)
    }

    // MARK: – Weight Card (collapsed + expanded chart)
    private func weightCard(pet: Pet, isExpanded: Bool) -> some View {
        let logs = pet.weightLogs.sorted(by: { $0.date < $1.date })
        let latestWeight = logs.last?.weight
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(surface)

            if isExpanded {
                // — Expanded: 6-point chart + log entry —
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Circle().fill(Color(hex: "F4F8E6")).frame(width: 48, height: 48)
                            .overlay(Image(systemName: "scalemass.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: "8BC34A")))
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = nil }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                                .frame(width: 32, height: 32).background(surf2, in: Circle())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let w = latestWeight {
                            Text(String(format: "%.1f", w))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("kg").font(.system(size: 16)).foregroundStyle(textSec)
                        } else {
                            Text("暂无数据").font(.system(size: 20, weight: .bold)).foregroundStyle(textSec)
                        }
                    }

                    if logs.count >= 2 {
                        let recent = Array(logs.suffix(6))
                        Chart {
                            ForEach(Array(recent.enumerated()), id: \.offset) { i, log in
                                LineMark(
                                    x: .value("次数", i),
                                    y: .value("kg", log.weight)
                                )
                                .foregroundStyle(Color(hex: "8BC34A"))
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                                AreaMark(
                                    x: .value("次数", i),
                                    y: .value("kg", log.weight)
                                )
                                .foregroundStyle(Color(hex: "8BC34A").opacity(0.15))
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { _ in AxisValueLabel().font(.system(size: 10)).foregroundStyle(textSec) }
                        }
                        .frame(height: 100)
                    } else {
                        Text("添加更多记录后显示趋势")
                            .font(.system(size: 13)).foregroundStyle(textSec)
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                            .background(surf2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button { showAddWeight = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus"); Text("记录体重")
                        }
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(hex: "8BC34A"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }.buttonStyle(ScaleButtonStyle())
                }
                .padding(20)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Circle().fill(Color(hex: "F4F8E6")).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "scalemass.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "8BC34A")))
                        Spacer()
                        Button { showAddWeight = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                                .frame(width: 32, height: 32).background(surf2, in: Circle())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 18).padding(.top, 18)
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Weight").font(.system(size: 16, weight: .semibold, design: .rounded))
                            if let w = latestWeight {
                                Text(String(format: "%.1f kg", w))
                                    .font(.system(size: 12)).foregroundStyle(textSec)
                            } else {
                                Text("No data").font(.system(size: 12)).foregroundStyle(textSec)
                            }
                        }
                        Spacer()
                    }.padding(.horizontal, 18).padding(.bottom, 18)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 320 : cardSize)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandedCard != .weight else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = .weight }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExpanded)
    }

    // MARK: – Walk Card (3D flip + expandedCard integration)
    private func walkCard(pet: Pet) -> some View {
        let isWalkExpanded = expandedCard == .walk && !isWalkActive
        let cardH: CGFloat = isWalkExpanded ? 340 : (isWalkActive ? 300 : cardSize)
        return ZStack {
            if isWalkExpanded {
                // Expanded: Walk History
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(surface)
                walkHistoryContent
            } else {
                // Compact: front/back 3D flip
                ZStack {
                    walkFrontFace
                        .opacity(isWalkActive ? 0 : 1)
                        .rotation3DEffect(.degrees(isWalkActive ? -180 : 0), axis: (1, 0, 0), perspective: 0.8)
                    walkBackFace(pet: pet)
                        .opacity(isWalkActive ? 1 : 0)
                        .rotation3DEffect(.degrees(isWalkActive ? 0 : 180), axis: (1, 0, 0), perspective: 0.8)
                }
                .animation(.easeInOut(duration: 0.7), value: isWalkActive)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardH)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isWalkActive else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                expandedCard = expandedCard == .walk ? nil : .walk
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: expandedCard)
    }

    // Front face of walk card
    private var walkFrontFace: some View {
        ZStack {
            Color(hex: "FF5A00")
            // Decorative footprints (background decoration)
            Image(systemName: "figure.walk")
                .resizable().scaledToFit().frame(width: 110)
                .foregroundStyle(.white.opacity(0.1))
                .rotationEffect(.degrees(-15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(10)

            if showWalkSummary {
                // Walk complete summary
                VStack(spacing: 10) {
                    Circle().fill(.white.opacity(0.2)).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.white))
                    Text("Walk Complete!")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    HStack(spacing: 20) {
                        Text("Time: \(formatTime(lastWalkTime))").font(.system(size: 13)).foregroundStyle(.white.opacity(0.9))
                        Text(String(format: "Dist: %.2f km", Double(lastWalkTime) * 0.0015))
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.9))
                    }
                    Button {
                        showWalkSummary = false
                    } label: {
                        Text("Done").font(.system(size: 14, weight: .bold)).foregroundStyle(accent)
                            .padding(.horizontal, 24).padding(.vertical, 8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }.buttonStyle(ScaleButtonStyle())
                }
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Circle().fill(.white.opacity(0.2)).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "figure.walk").font(.system(size: 17)).foregroundStyle(.white))
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()                            
                            walkPausedElapsed = 0
                            walkStartDate     = Date()
                            isWalkActive = true
                            isWalking    = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                                Text("Start").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(accent)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(.white, in: Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                        }.buttonStyle(ScaleButtonStyle())
                    }.padding(.horizontal, 20).padding(.top, 18)
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Walk & Activity")
                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            Text("Goal: \(walkGoalMins)m  •  Last: 2h ago")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                    }.padding(.horizontal, 20).padding(.bottom, 18)
                }
            }
        }
    }

    // Back face of walk card (active walk session — live map + compact controls)
    private func walkBackFace(pet: Pet) -> some View {
        ZStack {
            Color(hex: "FF5A00")
            VStack(spacing: 0) {
                // Top: live map
                Map(interactionModes: []) {
                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(MatTopRoundedRect(radius: 24))
                .overlay(alignment: .topLeading) {
                    // Timer overlay on map
                    // TimelineView isolates per-second updates to this node only
                    TimelineView(.periodic(from: .now, by: 1)) { tl in
                        let elapsed = walkPausedElapsed + (walkStartDate.map { Int(tl.date.timeIntervalSince($0)) } ?? 0)
                        HStack(spacing: 6) {
                            if isWalking {
                                Circle().fill(.red).frame(width: 7, height: 7)
                                    .opacity(elapsed % 2 == 0 ? 1 : 0.3)
                            }
                            Text(formatTime(elapsed))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    TimelineView(.periodic(from: .now, by: 1)) { tl in
                        let elapsed = walkPausedElapsed + (walkStartDate.map { Int(tl.date.timeIntervalSince($0)) } ?? 0)
                        Text(String(format: "%.2f km", Double(elapsed) * 0.0015))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(12)
                    }
                }

                // Bottom: compact controls row
                HStack(spacing: 8) {
                    // Pause/Resume
                    Button {
                        isWalking.toggle()
                        if isWalking {
                            walkStartDate = Date()   // resume
                        } else {
                            // pause: accumulate elapsed
                            if let s = walkStartDate {
                                walkPausedElapsed += Int(Date().timeIntervalSince(s))
                            }
                            walkStartDate = nil
                        }
                    } label: {
                        Image(systemName: isWalking ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 32)
                            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }.buttonStyle(ScaleButtonStyle())

                    // Poop recorder
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        walkPoopCount[pet.id, default: 0] += 1
                    } label: {
                        HStack(spacing: 4) {
                            Text("💩").font(.system(size: 14))
                            Text("\(walkPoopCount[pet.id, default: 0])")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3), value: walkPoopCount[pet.id])
                        }
                        .frame(height: 32).padding(.horizontal, 12)
                        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }.buttonStyle(ScaleButtonStyle())

                    Spacer()

                    // Stop
                    Button {
                        if let s = walkStartDate {
                            lastWalkTime = walkPausedElapsed + Int(Date().timeIntervalSince(s))
                        } else {
                            lastWalkTime = walkPausedElapsed
                        }
                        walkStartDate = nil; walkPausedElapsed = 0
                        isWalking = false; isWalkActive = false
                        walkPoopCount[pet.id] = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showWalkSummary = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill").font(.system(size: 12, weight: .bold))
                            Text("结束").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(height: 32).padding(.horizontal, 12)
                        .background(Color(hex: "FF3B30"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }.buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(hex: "FF5A00"))
            }
        }
    }

    // Walk history (expanded view)
    private var walkHistoryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle().fill(Color(hex: "FFF0E5")).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(accent))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { expandedCard = nil }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(textSec)
                        .frame(width: 32, height: 32).background(surf2, in: Circle())
                }.buttonStyle(ScaleButtonStyle())
            }
            Text("Walk History").font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Recent activity").font(.system(size: 14)).foregroundStyle(textSec)

            VStack(spacing: 10) {
                walkHistoryRow(date: "Today, 08:30 AM",    distance: "2.4 km", duration: "45m", poops: 2)
                walkHistoryRow(date: "Yesterday, 18:15",   distance: "1.8 km", duration: "32m", poops: 1)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                walkPausedElapsed = 0; walkStartDate = Date()
                isWalkActive = true; isWalking = true; expandedCard = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Start New Walk")
                }
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
    }

    private func walkHistoryRow(date: String, distance: String, duration: String, poops: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date).font(.system(size: 12)).foregroundStyle(textSec)
                Text(distance).font(.system(size: 18, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 6) {
                Label(duration, systemImage: "clock").font(.system(size: 12, weight: .medium))
                Text("💩×\(poops)").font(.system(size: 12))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(surf2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(textSec)
        }
        .padding(14)
        .background(surf2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: – Global Overview Carousel
    private var globalOverviewSection: some View {
        let cardW = UIScreen.main.bounds.width * 0.85
        return VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Global Overview")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button { } label: {
                    HStack(spacing: 3) {
                        Text("Details")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(textSec)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textSec)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    overviewWalkCard(width: cardW)
                    overviewExpensesCard(width: cardW)
                    overviewCoconutCard(width: cardW)
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    // MARK: Card 1 – Walk & Activity
    private func overviewWalkCard(width: CGFloat) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        // Build 7-day walk data from activePet (real) or mock fallback
        struct WalkDay: Identifiable { let id: Int; let label: String; let dist: Double }
        var days: [WalkDay] = (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: i - 6, to: today)!
            let dayStart = cal.startOfDay(for: date)
            let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let dist = (activePet?.walkLogs ?? [])
                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                .reduce(0) { $0 + $1.distanceMeters / 1000 }
            let wd = (cal.component(.weekday, from: date) + 5) % 7
            return WalkDay(id: i, label: dayLabels[wd], dist: dist)
        }
        // Fallback mock if no real data
        let mockDist = [0.8, 2.4, 0.0, 3.1, 1.5, 4.2, 2.7]
        if days.allSatisfy({ $0.dist == 0 }) {
            days = (0..<7).map { i in
                let date = cal.date(byAdding: .day, value: i - 6, to: today)!
                let wd = (cal.component(.weekday, from: date) + 5) % 7
                return WalkDay(id: i, label: dayLabels[wd], dist: mockDist[i])
            }
        }
        let totalKm = days.reduce(0) { $0 + $1.dist }

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(surface)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weekly Overview")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", totalKm))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("km")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
                            .padding(.bottom, 2)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                            Text("Walk & Activity")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(accent)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.top, 24).padding(.horizontal, 24)

                // Area chart
                Chart {
                    ForEach(days) { d in
                        AreaMark(x: .value("Day", d.label), y: .value("km", d.dist))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent.opacity(0.35), accent.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Day", d.label), y: .value("km", d.dist))
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Day", d.label), y: .value("km", d.dist))
                            .foregroundStyle(accent)
                            .symbolSize(d.dist > 0 ? 30 : 0)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { val in
                        AxisValueLabel()
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(content: {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                })
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
                .frame(height: 130)
            }
        }
        .frame(width: width, height: 220)
    }

    // MARK: Card 2 – Island Expenses
    private func overviewExpensesCard(width: CGFloat) -> some View {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let logs = (activePet?.expenseLogs ?? []).filter { $0.date >= monthStart }
        let total = logs.reduce(0) { $0 + $1.amount }

        // Category breakdown
        let catColors: [ExpenseCategory: Color] = [
            .food: accent, .treats: Color(hex: "FF9500"),
            .medical: Color(hex: "FF3B30"), .grooming: Color(hex: "C084FC"),
            .toys: Color(hex: "30D158"), .other: Color(hex: "4A90E2")
        ]
        struct CatEntry: Identifiable {
            let id: String; let cat: ExpenseCategory; let val: Double; let col: Color
        }
        var catTotals: [CatEntry] = ExpenseCategory.allCases.compactMap { cat in
            let sum = logs.filter { $0.category == cat.rawValue }.reduce(0) { $0 + $1.amount }
            guard sum > 0 else { return nil }
            return CatEntry(id: cat.rawValue, cat: cat, val: sum, col: catColors[cat] ?? textSec)
        }.sorted { $0.val > $1.val }
        // Mock fallback
        if catTotals.isEmpty {
            catTotals = [
                CatEntry(id: "食物",  cat: .food,     val: 620, col: accent),
                CatEntry(id: "医疗",  cat: .medical,  val: 380, col: Color(hex: "FF3B30")),
                CatEntry(id: "美容",  cat: .grooming, val: 180, col: Color(hex: "C084FC")),
                CatEntry(id: "其他",  cat: .other,    val: 100, col: Color(hex: "4A90E2"))
            ]
        }
        let displayTotal = total > 0 ? total : catTotals.reduce(0) { $0 + $1.val }
        let topCat = catTotals.first
        let topPct = topCat.map { Int(($0.val / max(1, displayTotal)) * 100) } ?? 0
        let topLabel = topCat?.cat.rawValue ?? "-"

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(surface)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly Expenses")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("¥")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.7))
                        Text(String(format: "%.0f", displayTotal))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: displayTotal)
                    }
                }
                .padding(.top, 24).padding(.horizontal, 24)

                // Horizontal stacked bar
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(catTotals.prefix(4)) { e in
                                let w = max(6, geo.size.width * CGFloat(e.val / max(1, displayTotal)))
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(e.col)
                                    .frame(width: w)
                            }
                        }
                    }
                    .frame(height: 14)
                    .clipShape(Capsule())

                    // Legend chips
                    HStack(spacing: 8) {
                        ForEach(catTotals.prefix(3)) { e in
                            HStack(spacing: 4) {
                                Circle().fill(e.col).frame(width: 6, height: 6)
                                Text(e.cat.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Bottom insight
                if let _ = topCat {
                    Text("\(topLabel) 占本月总开销的 \(topPct)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.75))
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: 220)
    }

    // MARK: Card 3 – Coconut Wealth Leaderboard
    private func overviewCoconutCard(width: CGFloat) -> some View {
        // Merge pets + humans into leaderboard entries
        struct WealthEntry: Identifiable {
            let id: UUID; let name: String; let emoji: String
            let balance: Int; let color: Color
        }
        var entries: [WealthEntry] = []
        for h in humans {
            let col = h.themeColor.count == 6 ? Color(hex: h.themeColor) : Color.goPrimary
            entries.append(WealthEntry(id: h.id, name: h.name, emoji: h.avatarEmoji.isEmpty ? "👤" : h.avatarEmoji, balance: h.coconutBalance, color: col))
        }
        for p in pets {
            let col = p.themeColorHex.isEmpty ? accent : Color(hex: p.themeColorHex)
            entries.append(WealthEntry(id: p.id, name: p.name, emoji: p.avatarEmoji.isEmpty ? "🐾" : p.avatarEmoji, balance: p.coconutBalance, color: col))
        }
        entries.sort { $0.balance > $1.balance }
        let maxBalance = max(1, entries.first?.balance ?? 1)
        let islandTotal = QuestManager.shared.coconutCount

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(surface)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 14) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coconut Wealth")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(islandTotal)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: islandTotal)
                        Text("🥥 total")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
                            .padding(.bottom, 2)
                    }
                }
                .padding(.top, 24).padding(.horizontal, 24)

                // Leaderboard bars
                VStack(spacing: 8) {
                    ForEach(entries.prefix(3)) { e in
                        HStack(spacing: 10) {
                            Text(e.emoji).font(.system(size: 16)).frame(width: 24)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(surf2)
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(e.color)
                                        .frame(width: max(8, geo.size.width * CGFloat(e.balance) / CGFloat(maxBalance)))
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: e.balance)
                                }
                            }
                            .frame(height: 10)
                            Text("\(e.balance)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.85))
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: 220)
    }

    // MARK: – Empty State
    private var matEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill").resizable().scaledToFit().frame(width: 56)
                .foregroundStyle(textSec.opacity(0.35))
            VStack(spacing: 8) {
                Text("No pets yet").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Add your first pet to get started")
                    .font(.system(size: 15)).foregroundStyle(textSec)
            }
            Button { showAddEntity = true } label: {
                HStack(spacing: 6) { Image(systemName: "plus"); Text("Add Pet") }
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(accent, in: Capsule())
            }.buttonStyle(ScaleButtonStyle())
        }
        .padding(40).frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    // MARK: – Bottom Navigation
    private var matBottomNav: some View {
        HStack(spacing: 0) {
            matNavItem(icon: "house.fill", index: 0)
            matNavItem(icon: "camera.macro", index: 1)
            // Center FAB: Add
            Button { showAddEntity = true } label: {
                Circle()
                    .fill(accent)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white))
                    .shadow(color: accent.opacity(0.4), radius: 10, x: 0, y: 4)
                    .overlay(Circle().strokeBorder(bg, lineWidth: 4))
            }
            .buttonStyle(ScaleButtonStyle())
            .offset(y: -20)
            .padding(.horizontal, 6)
            matNavItem(icon: "calendar",   index: 2)
            matNavItem(icon: "leaf.fill",  index: 3)
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func matNavItem(icon: String, index: Int) -> some View {
        let active = activeTab == index
        let inactiveTint = colorScheme == .light ? Color.black.opacity(0.55) : Color(hex: "8E8E93")
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { activeTab = index }
        } label: {
            ZStack {
                if active {
                    Circle().fill(Color(hex: "F5F5F7")).frame(width: 44, height: 44)
                }
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(active ? Color(hex: "1C1C1E") : inactiveTint)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
    }

    // MARK: – Helpers
    private func triggerCardStagger() {
        // Reset any expanded card on pet switch
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedCard = nil }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { cardVisible = Array(repeating: false, count: 6) }
        for i in 0..<6 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(i) * 0.05)) {
                cardVisible[i] = true
            }
        }
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: – Life Tree Widget
    private var lifeTreeWidget: some View {
        let tree = OasisTreeManager.shared
        let level = tree.treeLevel
        let progress = tree.progressToNextLevel
        let canInject = QuestManager.shared.coconutCount >= 5

        return HStack(spacing: 16) {
            // Tree icon evolves with level
            ZStack {
                Circle().fill(level.glowColor.opacity(0.15)).frame(width: 56, height: 56)
                Text(treeEmoji(level)).font(.system(size: 30))
            }

            // Level info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(level.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Lv.\(level.rawValue)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(accent.opacity(0.12), in: Capsule())
                }
                Text("\(tree.totalEnergy) 能量 · 下级 \(tree.nextLevelThreshold)")
                    .font(.system(size: 12)).foregroundStyle(textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Progress ring + inject FAB
            ZStack {
                Circle()
                    .stroke(surf2, lineWidth: 4)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                    .animation(.spring(response: 0.6), value: progress)

                Button {
                    guard canInject else { return }
                    if OasisTreeManager.shared.injectEnergy(cost: 10) {
                        OasisTreeManager.shared.checkAndRewardLevelUp()
                        launchCoconutParticles()
                    }
                } label: {
                    Image(systemName: canInject ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canInject ? .white : textSec)
                        .frame(width: 32, height: 32)
                        .background(canInject ? accent : surf2, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .scaleEffect(treeInjectPressing ? 1.15 : 1)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .onChanged { _ in treeInjectPressing = true }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                treeInjectPressing = false
                            }
                        }
                )
            }
        }
        .padding(18)
        .background(surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private func treeEmoji(_ level: TreeLevel) -> String {
        switch level {
        case .lv1:  return "🌱"
        case .lv2:  return "🌿"
        case .lv3:  return "🪴"
        case .lv4:  return "🌳"
        case .lv5:  return "🌴"
        case .lv6:  return "🌴"
        case .lv7:  return "🏝️"
        case .lv8:  return "🌲"
        case .lv9:  return "🌏"
        case .lv10: return "✨"
        }
    }

    // MARK: – SmartTask urgent + island quest completion (Material home)

    private func matTodayWalkDone(for pet: Pet) -> Bool {
        pet.walkLogs.contains { Calendar.current.isDateInToday($0.startDate) }
    }

    private func matWaterChangeDoneToday(for pet: Pet) -> Bool {
        if let d = lastWaterChangeDates[pet.id] {
            return Calendar.current.isDateInToday(d)
        }
        return false
    }

    private func matLitterDoneToday(for pet: Pet) -> Bool {
        pet.careLogs.contains {
            $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date)
        }
    }

    private func matWeightRecordedThisWeek(for pet: Pet) -> Bool {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return pet.weightLogs.contains { $0.date > weekAgo }
    }

    private func matBentoUrgent(type: MatCardType, pet: Pet) -> Bool {
        let task = SmartTaskEngine.topTask(pets: pets, reminders: pendingReminders, plants: plants)
        switch task.actionTarget {
        case .pet(let tp) where tp.id == pet.id:
            let t = task.title
            let s = task.subtitle
            let al = task.actionLabel
            switch type {
            case .feeding:
                return task.emoji == "🛒" || t.contains("补粮")
            case .walk:
                return al.contains("遛") || t.contains("出门") || task.emoji == "🌅" || task.emoji == "🌇"
            case .waterChange:
                return t.contains("换水") || (t.contains("水") && !t.contains("浇水") && !t.contains("植物"))
            case .litter:
                return t.contains("砂") || s.contains("砂") || al.contains("砂")
                    || t.contains("排泄") || t.contains("便便")
            case .weight:
                return task.emoji == "💉" || t.contains("疫苗") || t.contains("健康")
            case .expenses:
                return false
            }
        default:
            return false
        }
    }

    private func matShouldPulseUrgent(type: MatCardType, pet: Pet) -> Bool {
        guard matBentoUrgent(type: type, pet: pet) else { return false }
        switch type {
        case .feeding:     return !fedPets.contains(pet.id)
        case .waterChange: return !matWaterChangeDoneToday(for: pet)
        case .litter:      return !matLitterDoneToday(for: pet) && !pet.pottyLogs.contains { Calendar.current.isDateInToday($0.date) }
        case .weight:      return !matWeightRecordedThisWeek(for: pet)
        case .expenses, .walk:
            return false
        }
    }

    @MainActor
    private func matCompleteIslandQuest(_ quest: IslandQuest) {
        switch quest.id {
        case "q_walk":
            if let id = quest.targetPetId, let idx = pets.firstIndex(where: { $0.id == id }) {
                activePetIndex = idx
                selectedPet = pets[idx]
                walkPausedElapsed = 0
                walkStartDate = Date()
                isWalkActive = true
                isWalking = true
                expandedCard = nil
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        case "q_potty":
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) {
                let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: p, executorId: eid)
                modelContext.insert(log)
                _ = QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: p, context: modelContext)
                modelContext.safeSave()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        case "q_water_plant":
            if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                matCompletePlantWatering(pl)
            }
        case "q_fertilize_plant":
            if let id = quest.targetPlantId, let pl = plants.first(where: { $0.id == id }) {
                matCompletePlantFertilizing(pl)
            }
        case "q_visit":
            IslandQuestEngine.markVisited()
            if let id = quest.targetPetId, let p = pets.first(where: { $0.id == id }) {
                selectedPet = p
            } else if let p = pets.first {
                selectedPet = p
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "q_reminder":
            activeTab = 2
            calendarAddEventTrigger.toggle()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        default:
            if let mid = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
                for p in pets {
                    if let med = p.medications.first(where: { $0.id == mid }) {
                        PetMedicationDoseLogging.recordDose(medication: med, pet: p, modelContext: modelContext)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        break
                    }
                }
            }
        }
        let amt = IslandQuestEngine.coconutReward(forQuestId: quest.id)
        if amt > 0 {
            matQuestCoconutAmount = amt
            matQuestCoconutReward = true
            launchCoconutParticles()
        }
    }

    @MainActor
    private func matCompletePlantWatering(_ plant: Plant) {
        plant.lastWateredDate = Date()
        let log = PlantCareLog(date: Date(), careType: .watering)
        log.plant = plant
        modelContext.insert(log)
        let event = Event(
            title: "💧 给 \(plant.name) 浇水",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    private func matCompletePlantFertilizing(_ plant: Plant) {
        plant.lastFertilizedDate = Date()
        let log = PlantCareLog(date: Date(), careType: .fertilizing)
        log.plant = plant
        modelContext.insert(log)
        let event = Event(
            title: "🌿 给 \(plant.name) 施肥",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.fertilizing.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: – Suck-in Coin Particles
    func launchCoconutParticles(from origin: CGPoint? = nil) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let sw = UIScreen.main.bounds.width
        let sh = UIScreen.main.bounds.height
        let startX = origin?.x ?? sw / 2
        let startY = origin?.y ?? sh * 0.55
        let newParticles = (0..<4).map { _ in
            MatCoinParticle(x: startX + CGFloat.random(in: -30...30),
                            y: startY + CGFloat.random(in: -15...15),
                            targetX: coconutBtnOrigin.x,
                            targetY: coconutBtnOrigin.y)
        }
        coinParticles.append(contentsOf: newParticles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let ids = Set(newParticles.map { $0.id })
            coinParticles.removeAll { ids.contains($0.id) }
        }
    }
}

// MARK: – Coin Particle Model + View

struct MatCoinParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
}

private struct MatCoinParticleView: View {
    let particle: MatCoinParticle
    @State private var flying = false

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "FF5A00"))
                .frame(width: 14, height: 14)
                .overlay(
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 7)).foregroundStyle(.white)
                )
                .shadow(color: Color(hex: "FF5A00").opacity(0.6), radius: 6)
        }
        .scaleEffect(flying ? 0.2 : 1)
        .opacity(flying ? 0 : 1)
        .position(
            x: flying ? particle.targetX : particle.x,
            y: flying ? particle.targetY : particle.y
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double.random(in: 0...0.12))) {
                flying = true
            }
        }
    }
}

// MARK: – Custom Shapes

struct MatTopRoundedRect: Shape {
    var radius: CGFloat = 24
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, rect.width / 2, rect.height)
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        p.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: r), control: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct MatBottomRoundedRect: Shape {
    var radius: CGFloat = 24
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, rect.width / 2, rect.height)
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: r, y: rect.maxY), control: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - r), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.closeSubpath()
        return p
    }
}

struct MatTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: – Particle Views

struct FoodParticleView: View {
    @State private var opacity: Double = 0
    @State private var yOff: CGFloat   = -20
    private let delay = Double.random(in: 0...0.4)
    private let xOff  = CGFloat.random(in: -40...40)

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: "8B4513"))
            .frame(width: 10, height: 10)
            .offset(x: xOff, y: yOff)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6).delay(delay)) {
                    opacity = 1; yOff = 90
                }
                withAnimation(.easeIn(duration: 0.35).delay(delay + 0.6)) {
                    opacity = 0
                }
            }
    }
}

struct WaterParticleView: View {
    @State private var opacity: Double = 0
    @State private var yOff: CGFloat   = -20
    private let delay = Double.random(in: 0...0.4)
    private let xOff  = CGFloat.random(in: -35...35)

    var body: some View {
        Capsule()
            .fill(Color(hex: "4A90E2").opacity(0.75))
            .frame(width: 6, height: 14)
            .offset(x: xOff, y: yOff)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6).delay(delay)) {
                    opacity = 1; yOff = 110
                }
                withAnimation(.easeIn(duration: 0.35).delay(delay + 0.6)) {
                    opacity = 0
                }
            }
    }
}

struct PoopParticleView: View {
    @State private var opacity: Double = 0
    @State private var yOff: CGFloat   = -20
    @State private var angle: Double   = 0
    private let delay = Double.random(in: 0...0.4)
    private let xOff  = CGFloat.random(in: -30...30)

    var body: some View {
        Text("💩").font(.system(size: 18))
            .rotationEffect(.degrees(angle))
            .offset(x: xOff, y: yOff)
            .opacity(opacity)
            .onAppear {
                angle = Double.random(in: -60...60)
                withAnimation(.easeIn(duration: 0.6).delay(delay)) {
                    opacity = 1; yOff = 90
                }
                withAnimation(.easeIn(duration: 0.35).delay(delay + 0.6)) {
                    opacity = 0
                }
            }
    }
}

// MARK: – Wave Views

struct MatWaveView: View {
    var isRising: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                MatWaveShape(phase: phase + .pi)
                    .fill(Color(hex: "4A90E2").opacity(0.18))
                    .frame(height: isRising ? geo.size.height * 0.55 : 0)
                MatWaveShape(phase: phase)
                    .fill(Color(hex: "4A90E2").opacity(0.28))
                    .frame(height: isRising ? geo.size.height * 0.45 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.easeInOut(duration: 0.8), value: isRising)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct MatWaveShape: Shape {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase } set { phase = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let amplitude: CGFloat = 8
        let wavelength: CGFloat = rect.width / 1.5
        p.move(to: CGPoint(x: 0, y: rect.midY))
        for x in stride(from: CGFloat(0), through: rect.width, by: 2) {
            let y = rect.midY + amplitude * sin((x / wavelength) * .pi * 2 + phase)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: – Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
