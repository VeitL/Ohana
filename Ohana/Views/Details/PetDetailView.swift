//
//  PetDetailView.swift
//  Ohana
//
//  HUD 瀑布流仪表盘 — Phase 26 重构
//

import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

// MARK: - Tab 兼容保留（ContentView 仍引用此 enum）
enum PetDetailTab: String, CaseIterable {
    case overview = "概览"
    case health   = "健康"
    case records  = "记录"

    var icon: String {
        switch self {
        case .overview: return "pawprint.fill"
        case .health:   return "heart.text.clipboard"
        case .records:  return "list.clipboard"
        }
    }
}

// MARK: - Main View
struct PetDetailView: View {
    let pet: Pet
    var initialTab: PetDetailTab = .overview   // 保留兼容
    var openHealthOnAppear: Bool = false       // 任务3：Quick Access health路由

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet      = false
    @State private var showingCalendar       = false
    @State private var showingWeightHistory  = false
    @State private var showingExpenseHistory = false
    @State private var showingPetInfo        = false
    @State private var showingSitterCard     = false
    @State private var showingAchievements   = false
    @State private var showingPottyOverview  = false
    @State private var showingWalkSummary    = false
    @State private var showingDocuments      = false
    @State private var showingAddWeight      = false
    @State private var quickWeightInput      = ""
    @State private var healthRecordType: HealthLogType? = nil
    @State private var showingFoodManagement   = false
    @State private var showingHealthDetail     = false
    @State private var showingQuickPotty       = false
    @State private var showingQuickExpense     = false
    @State private var showingCoconutLog       = false
    @State private var showingMilestones       = false
    @State private var showingMedications        = false
    @State private var showingMomentsHub         = false
    @State private var showingHygieneDetail      = false
    @State private var showingAllFeatures        = false
    @State private var pressedActionId: String?  = nil
    // Quick-action detail sheets (long press)
    @State private var showingQuickFeedDetail    = false
    @State private var showingQuickWaterDetail   = false
    @State private var quickWaterDetailModeRaw: String? = nil
    @State private var showingQuickPlayDetail    = false
    @State private var showingQuickPottyDetail   = false
    @State private var showingQuickWeight        = false
    @State private var showingMomentSheet        = false
    // Edit mode for quick action grid
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @State private var isQAEditMode    = false
    @State private var qaJiggle        = false
    @State private var qaEditItems: [QuickActionItem] = []
    @State private var showingQAQuickAdd = false

    // Dynamic Island safe area
    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 44
    }

    private var themeGradientTop: Color {
        WalletPetCardTheme.gradientPair(for: pet.themeColorHex).0
    }

    private var themeGradientBottom: Color {
        WalletPetCardTheme.gradientPair(for: pet.themeColorHex).1
    }

    // Outer bg card radius; pet card uses (bgCardRadius − innerMargin) for concentric corners
    private let bgCardRadius: CGFloat = 32
    private let innerMargin:  CGFloat = 12   // bg card → pet card gap

    var body: some View {
        ZStack {
            // ① Dark base — visible in the Dynamic Island strip above bg card
            ArkBackgroundView()

            // ② Pet-theme background card — top edge aligns with Dynamic Island bottom
            VStack(spacing: 0) {
                Spacer().frame(height: safeAreaTop)
                LinearGradient(
                    colors: [themeGradientTop, themeGradientBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(
                    .rect(
                        topLeadingRadius:     bgCardRadius,
                        bottomLeadingRadius:  0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius:    bgCardRadius
                    )
                )
            }
            .ignoresSafeArea(edges: .bottom)

            ScrollView(.vertical, showsIndicators: false) {
                petDetailHeroSection
            }
            .ignoresSafeArea(.container, edges: .top)

            // Back button (floats over Dynamic Island safe area)
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    CoconutBalanceCapsule { showingCoconutLog = true }
                }
                .padding(.horizontal, 16)
                .padding(.top, safeAreaTop + 8)
                Spacer()
            }
        } // ZStack
        .onAppear {
            IslandQuestEngine.markVisited()
            if openHealthOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showingHealthDetail = true
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingHygieneDetail)    { NavigationStack { PetHygieneDetailView(pet: pet) }.presentationDetents([.large]) }
        .sheet(isPresented: $showingEditSheet)        { EditPetSheet(pet: pet) }
        .sheet(isPresented: $showingCalendar)         { CalendarView(preselectedPetId: pet.id.uuidString) }
        .sheet(isPresented: $showingSitterCard)       { SitterCardPreviewSheet(pet: pet) }
        .sheet(isPresented: $showingAchievements)     { AchievementWallView(pet: pet) }
        .sheet(isPresented: $showingPottyOverview)    { PottyOverviewView(pet: pet) }
        .sheet(isPresented: $showingWalkSummary)      { WalkSummarySheet(pet: pet) }
        .sheet(isPresented: $showingFoodManagement)   { PetFoodManagementView(pet: pet) }
        .sheet(isPresented: $showingMedications)       { PetMedicationView(pet: pet) }
        .sheet(isPresented: $showingMomentsHub) {
            PetMomentsHubView(pet: pet)
        }
        .sheet(isPresented: $showingQuickPotty)       { QuickPottySheet(pet: pet).presentationDetents([.height(320)]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showingQuickExpense)     { AddExpenseSheet(pet: pet) }
        .sheet(isPresented: $showingCoconutLog)       { CoconutLogView() }
        .sheet(isPresented: $showingAllFeatures)      { PetAllFeaturesSheet(pet: pet).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(item: $healthRecordType)               { AddHealthRecordSheet(pet: pet, type: $0) }
        .navigationDestination(isPresented: $showingWeightHistory)  { WeightHistoryView(pet: pet) }
        .navigationDestination(isPresented: $showingExpenseHistory) { ExpenseHistoryView(pet: pet) }
        .navigationDestination(isPresented: $showingMilestones)      { PetMilestoneListView(pet: pet) }
        .navigationDestination(isPresented: $showingPetInfo)        { PetBasicInfoDetailView(pet: pet) }
        .sheet(isPresented: $showingHealthDetail) {
            NavigationStack {
                PetHealthDetailView(pet: pet, isModal: true, onFullDismiss: { dismiss() })
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Quick-action detail sheets (long press from grid)
        .sheet(isPresented: $showingQuickFeedDetail) {
            QuickFeedDetailSheet(pet: pet) { showingQuickFeedDetail = false }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showingQuickWaterDetail) {
            QuickWaterDetailSheet(
                pet: pet,
                initialModeRaw: quickWaterDetailModeRaw,
                lockedModeRaw: quickWaterDetailModeRaw
            ) {
                showingQuickWaterDetail = false
                quickWaterDetailModeRaw = nil
            }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .onDisappear { quickWaterDetailModeRaw = nil }
        }
        .sheet(isPresented: $showingQuickPlayDetail) {
            QuickPlayDetailSheet(pet: pet) { showingQuickPlayDetail = false }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showingQuickPottyDetail) {
            QuickPottyDetailSheet(pet: pet) { showingQuickPottyDetail = false }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showingQuickWeight) {
            GenericWeightEntrySheet(target: .pet(pet))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $showingMomentSheet) {
            NavigationStack {
                QuickMomentSheet(pet: pet, onRemove: nil)
                    .navigationTitle("记录时刻").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { showingMomentSheet = false }
                        }
                    }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    // MARK: - Hero Section (top of detail, below Dynamic Island)

    private var petDetailHeroSection: some View {
        // Concentric corner geometry:
        //   bgCardRadius (32) − innerMargin (12) = petCardRadius (20)
        let petR = bgCardRadius - innerMargin
        let cardW = ScreenCompat.width - innerMargin * 2
        let cardH = cardW * 1.1  // slightly portrait — fills ~55% of screen

        return VStack(spacing: 0) {
            // Land innerMargin below the bg card's top edge (which is at safeAreaTop)
            Spacer().frame(height: safeAreaTop + innerMargin)

            // ── Pet card ──
            Button { showingPetInfo = true } label: {
                WalletPetCardFront(pet: pet, cornerRadius: petR)
                    .frame(width: cardW, height: cardH)
                    .overlay(
                        RoundedRectangle(cornerRadius: petR, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
            .shadow(color: themeGradientTop.opacity(0.25), radius: 10, y: -3)

            // ── Name + species ──
            ZStack {
                VStack(spacing: 5) {
                    Text(pet.name)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text((pet.species.isEmpty ? "PET" : pet.species).uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.40))
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    Button { showingAllFeatures = true } label: {
                        Label("全部", systemImage: "square.grid.2x2")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, innerMargin)
                }
            }
            .padding(.top, 20)

            // ── Quick actions grid ──
            petQuickActionGrid
                .padding(.horizontal, innerMargin)
                .padding(.top, 20)
                .padding(.bottom, 8)
        }
    }

    private var petQuickActionGrid: some View {
        let avatar   = pet.avatarImageData.flatMap { UIImage(data: $0) }
        let themeHex = pet.themeColorHex.isEmpty ? nil : pet.themeColorHex
        let displayItems = isQAEditMode ? qaEditItems : petQuickActionItems

        return VStack(spacing: 12) {
            // ── Header ──
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("快捷操作")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("QUICK ACTIONS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(2.5)
                }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isQAEditMode { exitQAEditMode() } else { enterQAEditMode() }
                } label: {
                    Image(systemName: isQAEditMode ? "checkmark.circle.fill" : "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isQAEditMode ? Color.goLime : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            // ── Grid ──
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                    qaGridItem(idx: idx, item: item, avatar: avatar, themeHex: themeHex)
                }

                if isQAEditMode {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingQAQuickAdd = true
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(Color(hex: "E8EEFF")).frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "6B82C4"))
                            }
                            Text("添加").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: "6B82C4"))
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color(hex: "B8C8F0"), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingQAQuickAdd, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                        QAQuickAddPopoverContent(pet: pet, existingItems: qaEditItems) { newItem in
                            withAnimation(.spring(response: 0.3)) {
                                if QuickActionLimit.count(for: pet, in: qaEditItems) < QuickActionLimit.maxItemsPerEntity {
                                    qaEditItems.append(newItem)
                                }
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: displayItems.map(\.id))
        }
    }

    @ViewBuilder
    private func qaGridItem(idx: Int, item: QuickActionItem, avatar: UIImage?, themeHex: String?) -> some View {
        ZStack {
            GoQuickActionCard(
                item: item,
                isPressed: !isQAEditMode && pressedActionId == item.id,
                petAvatar: avatar,
                petThemeColorHex: themeHex,
                countText: isQAEditMode ? nil : qaCountText(item.actionType),
                isCompletedToday: !isQAEditMode && qaCompleted(item.actionType),
                prefersLightForeground: true,
                onTap: {
                    guard !isQAEditMode else { return }
                    pressedActionId = item.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        pressedActionId = nil
                        handleTapAction(item: item)
                    }
                },
                onLongPress: isQAEditMode ? nil : { handleLongPressAction(item: item) },
                onGroomCheckIn: (!isQAEditMode && item.actionType == "groom") ? { raw in applyGroomCheckIn(raw) } : nil,
                onPottySelect:  (!isQAEditMode && item.actionType == "potty") ? { raw in applyPottyCheckIn(raw) } : nil,
                onHealthSelect: (!isQAEditMode && item.actionType == "health") ? { raw in applyHealthCheckIn(raw) } : nil
            )
            .allowsHitTesting(!isQAEditMode)

            if isQAEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeHex)
            }
        }
        .rotationEffect(.degrees(isQAEditMode ? (qaJiggle ? -2.5 : 2.5) : 0))
        .animation(
            isQAEditMode
            ? .easeInOut(duration: 0.12 + Double(idx % 4) * 0.015).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.2),
            value: qaJiggle
        )
        .overlay(alignment: .topLeading) {
            if isQAEditMode {
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    withAnimation(.spring(response: 0.3)) { qaEditItems.removeAll { $0.id == item.id } }
                } label: {
                    ZStack {
                        Circle().fill(Color.goRed).frame(width: 20, height: 20)
                        Image(systemName: "minus").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
            }
        }
        .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(targetItem: item, items: $qaEditItems))
    }

    private func handleTapAction(item: QuickActionItem) {
        switch item.actionType {
        case "feed":         applyDirectAction("feed")
        case "walk":         applyDirectAction("walk")
        case "water":        applyDirectAction("water")
        case "waterChange":  applyDirectAction("waterChange")
        case "play":         applyDirectAction("play")
        case "litter":       applyDirectAction("litter")
        case "filterClean":  applyDirectAction("filterClean")
        case "weight":       showingQuickWeight  = true
        case "expense":      showingQuickExpense  = true
        case "moment":       showingMomentSheet   = true
        case "medication":   showingMedications   = true
        // groom/potty/health handled internally by GoQuickActionCard popovers
        default: break
        }
    }

    private func handleLongPressAction(item: QuickActionItem) {
        switch item.actionType {
        case "feed":         showingQuickFeedDetail   = true
        case "walk":         showingWalkSummary        = true
        case "water":
            quickWaterDetailModeRaw = QuickWaterDetailSheet.WaterMode.drink.rawValue
            showingQuickWaterDetail = true
        case "waterChange":
            quickWaterDetailModeRaw = QuickWaterDetailSheet.WaterMode.change.rawValue
            showingQuickWaterDetail = true
        case "play":         showingQuickPlayDetail    = true
        case "potty":        showingQuickPottyDetail   = true
        case "litter":       showingQuickPottyDetail   = true
        case "groom":        showingHygieneDetail      = true
        case "filterClean":  showingHygieneDetail      = true
        case "health":       showingHealthDetail        = true
        case "weight":       showingWeightHistory       = true
        case "expense":      showingExpenseHistory      = true
        case "moment":       showingMomentsHub          = true
        case "medication":   showingMedications         = true
        default: break
        }
    }

    private func applyDirectAction(_ actionType: String) {
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        switch actionType {
        case "feed":
            CareEventService.recordManualFeed(pet: pet, amountGrams: pet.dailyPortionGrams, context: modelContext, executorId: uid)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "walk":
            if case .idle = PetWalkingManager.shared.phase { PetWalkingManager.shared.start(pet: pet) }
        case "water":
            CareEventService.recordCare(pet: pet, type: .watering, amountMl: 250, context: modelContext, executorId: uid, reward: .water)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "waterChange":
            CareEventService.recordCare(pet: pet, type: .waterChange, context: modelContext, executorId: uid, reward: .general(humanReward: 15, petReward: 20, emoji: CareType.waterChange.emoji, title: "\(pet.name) 换水奖励"))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "play":
            CareEventService.recordCare(pet: pet, type: .play, context: modelContext, executorId: uid, reward: .general(humanReward: 2, petReward: 3, emoji: "🎾", title: "\(pet.name) 玩耍"))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "litter":
            CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: uid, reward: .potty(isLitter: true))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "filterClean":
            CareEventService.recordCare(pet: pet, type: .filterClean, context: modelContext, executorId: uid, reward: .general(humanReward: 25, petReward: 40, emoji: CareType.filterClean.emoji, title: "\(pet.name) 清理滤材报酬"))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            break
        }
    }

    private func qaCompleted(_ actionType: String) -> Bool {
        let cal = Calendar.current
        switch actionType {
        case "feed":        return pet.careLogs.contains { $0.careType == .feeding && cal.isDateInToday($0.date) }
        case "walk":        return pet.walkLogs.contains { cal.isDateInToday($0.startDate) }
        case "potty":       return pet.pottyLogs.contains { cal.isDateInToday($0.date) }
        case "groom":       return pet.hygieneLogs.contains { cal.isDateInToday($0.date) }
        case "play":        return pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
        case "water":       return pet.careLogs.contains { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }
        case "waterChange": return pet.careLogs.contains { $0.type == CareType.waterChange.rawValue && cal.isDateInToday($0.date) }
        case "litter":      return pet.careLogs.contains { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }
        case "filterClean": return pet.careLogs.contains { $0.type == CareType.filterClean.rawValue && cal.isDateInToday($0.date) }
        default:            return false
        }
    }

    // MARK: - Edit Mode Persistence

    private var savedQuickActionItems: [QuickActionItem] {
        guard !quickActionItemsJSON.isEmpty,
              let data = quickActionItemsJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return defaultActionsForPet }
        return items
    }

    private var petQuickActionItems: [QuickActionItem] {
        let petItems = savedQuickActionItems.filter { $0.petId == pet.id && $0.entityKind != .human }
        return petItems.isEmpty ? defaultActionsForPet : petItems
    }

    private var defaultActionsForPet: [QuickActionItem] {
        let isDog  = pet.species.contains("狗") || pet.species.lowercased().contains("dog")
        let isCat  = pet.species.contains("猫") || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")
        var items: [QuickActionItem] = []
        items.append(QuickActionItem(label: "喂食", icon: "fork.knife", colorHex: "FF8C00", petId: pet.id, actionType: "feed", entityId: pet.id, entityKind: .pet))
        if isFish {
            items.append(QuickActionItem(label: "换水", icon: "drop.circle.fill", colorHex: "4ECDC4", petId: pet.id, actionType: "waterChange", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "清滤", icon: "wrench.and.screwdriver.fill", colorHex: "A78BFA", petId: pet.id, actionType: "filterClean", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "体重", icon: "scalemass.fill", colorHex: "16A34A", petId: pet.id, actionType: "weight", entityId: pet.id, entityKind: .pet))
        } else if isDog {
            items.append(QuickActionItem(label: "遛狗", icon: "figure.walk", colorHex: "0EA5E9", petId: pet.id, actionType: "walk", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "便便", icon: "allergens", colorHex: "D97706", petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "健康", icon: "cross.fill", colorHex: "EF4444", petId: pet.id, actionType: "health", entityId: pet.id, entityKind: .pet))
        } else if isCat {
            items.append(QuickActionItem(label: "铲屎", icon: "trash.fill", colorHex: "5B6AFF", petId: pet.id, actionType: "litter", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "便便", icon: "allergens", colorHex: "D97706", petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "健康", icon: "cross.fill", colorHex: "EF4444", petId: pet.id, actionType: "health", entityId: pet.id, entityKind: .pet))
        } else {
            items.append(QuickActionItem(label: "护理", icon: "bubbles.and.sparkles.fill", colorHex: "06B6D4", petId: pet.id, actionType: "groom", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "便便", icon: "allergens", colorHex: "D97706", petId: pet.id, actionType: "potty", entityId: pet.id, entityKind: .pet))
            items.append(QuickActionItem(label: "体重", icon: "scalemass.fill", colorHex: "16A34A", petId: pet.id, actionType: "weight", entityId: pet.id, entityKind: .pet))
        }
        return items
    }

    private func enterQAEditMode() {
        qaEditItems = petQuickActionItems
        withAnimation(.spring(response: 0.3)) { isQAEditMode = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation(nil) { qaJiggle = true } }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func exitQAEditMode() {
        saveQAEditItems(qaEditItems)
        withAnimation(.spring(response: 0.3)) { isQAEditMode = false }
        withAnimation(nil) { qaJiggle = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveQAEditItems(_ edited: [QuickActionItem]) {
        var saved = savedQuickActionItems
        let petItemIds = Set(petQuickActionItems.map { $0.id })
        let insertionIdx = saved.firstIndex(where: { petItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { petItemIds.contains($0.id) }
        saved.insert(contentsOf: Array(edited.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        if let data = try? JSONEncoder().encode(saved), let str = String(data: data, encoding: .utf8) {
            quickActionItemsJSON = str
        }
    }

    private func qaCountText(_ actionType: String) -> String? {
        let cal = Calendar.current
        switch actionType {
        case "feed":
            let n = pet.careLogs.filter { $0.careType == .feeding && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日\(n)次" : nil
        case "walk":
            let n = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
            return n > 0 ? "今日\(n)次" : nil
        case "potty":
            let n = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日\(n)次" : nil
        case "weight":
            if let last = pet.weightLogs.sorted(by: { $0.date < $1.date }).last {
                return "\(last.weight)kg"
            }
            return nil
        case "expense":
            let total = pet.expenseLogs
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                .reduce(0.0) { $0 + $1.amount }
            return total > 0 ? "¥\(Int(total))" : nil
        default:
            return nil
        }
    }

    private func applyGroomCheckIn(_ raw: String) {
        let type: HygieneType
        switch raw {
        case "bath":     type = .bath
        case "teeth":    type = .teeth
        case "nails":    type = .nails
        case "brushing": type = .brushing
        case "ears":     type = .ears
        default:         return
        }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet, executorId: executorId)
        modelContext.insert(log); modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
    }

    private func applyPottyCheckIn(_ raw: String) {
        let type = PottyType(rawValue: raw) ?? .perfectPoop
        let uid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordPotty(pet: pet, type: type, context: modelContext, executorId: uid)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func applyHealthCheckIn(_ raw: String) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        switch raw {
        case "symptom":
            healthRecordType = .general
        case "vaccine":
            modelContext.insert(PetHealthLog(date: Date(), type: .vaccine, note: "快速打卡", pet: pet, executorId: executorId))
            modelContext.safeSave()
        case "deworming":
            modelContext.insert(PetHealthLog(date: Date(), type: .dewormingExternal, note: "快速打卡", pet: pet, executorId: executorId))
            modelContext.safeSave()
        case "visit":
            modelContext.insert(PetHealthLog(date: Date(), type: .checkup, note: "快速打卡", pet: pet, executorId: executorId))
            modelContext.safeSave()
        case "heatCycle":
            healthRecordType = .general
        default:
            break
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L1 Hero Row
// ═══════════════════════════════════════════════════════════════
private struct PetHeroRow: View {
    let pet: Pet
    let onTap: () -> Void

    /// 人类等价年龄
    private var humanEquivalentAge: String? {
        guard let bday = pet.birthday else { return nil }
        let cal = Calendar.current
        let ageYears = cal.dateComponents([.year], from: bday, to: Date()).year ?? 0
        let ageMonths = cal.dateComponents([.month], from: bday, to: Date()).month ?? 0
        let petAge = Double(ageMonths) / 12.0
        guard petAge > 0 else { return nil }
        let humanAge: Int
        switch pet.species {
        case "狗":
            if petAge <= 2 { humanAge = Int(petAge * 12) }
            else { humanAge = 24 + Int((petAge - 2) * 5) }
        case "猫":
            if petAge <= 2 { humanAge = Int(petAge * 12.5) }
            else { humanAge = 25 + Int((petAge - 2) * 4) }
        case "兔子": humanAge = Int(petAge * 8)
        case "仓鼠": humanAge = Int(petAge * 26)
        case "龙猫": humanAge = Int(petAge * 4.5)
        case "豚鼠": humanAge = Int(petAge * 10)
        default: humanAge = Int(petAge * 7)
        }
        return "≈ \(humanAge)岁人类"
    }

    var body: some View {
        let themeColor = pet.themeColorHex.isEmpty ? Color.goCardBlue : Color(hex: pet.themeColorHex)
        let isTransparent = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false

        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // 渐变底色（匹配首页卡片风格）
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.6), Color.goDarkBlue],
                        startPoint: .topLeading, endPoint: .bottomTrailing))

                // 头像区域
                if let data = pet.avatarImageData, let img = UIImage(data: data), !isTransparent {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 130, height: 130)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.3),
                                    .init(color: .black, location: 0.5),
                                    .init(color: .clear, location: 0.85)
                                ]),
                                center: UnitPoint(x: 0.5, y: 0.5),
                                startRadius: 10,
                                endRadius: 75
                            )
                        )
                        .offset(x: 8, y: -8)
                        .allowsHitTesting(false)
                } else if isTransparent, let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(height: 110)
                        .offset(x: 8, y: -8)
                        .allowsHitTesting(false)
                } else {
                    // 没有头像 → 使用 PetSilhouetteView 作为 fallback
                    PetSilhouetteView(
                        species: pet.species,
                        coatColor: pet.coatColor.isEmpty ? Color(hex: "E8C49A") : Color(hex: pet.coatColor),
                        eyeColor: pet.eyeColor.isEmpty ? Color(hex: "6B3A2A") : Color(hex: pet.eyeColor)
                    )
                    .scaleEffect(0.5)
                    .frame(width: 110, height: 110)
                    .offset(x: 8, y: -6)
                    .allowsHitTesting(false)
                }

                // 信息覆盖层（右侧）
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(pet.name)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 5) {
                            if !pet.breed.isEmpty {
                                heroTag("\(pet.species) · \(pet.breed)")
                            } else {
                                heroTag(pet.species)
                            }
                            heroTag(pet.genderSymbol)
                            if pet.isNeutered { heroTag("已绝育") }
                        }
                        Spacer().frame(height: 4)
                        VStack(alignment: .trailing, spacing: 4) {
                            heroStat(value: "\(pet.daysTogether)", label: "同行天", accent: .goPrimary)
                            HStack(spacing: 8) {
                                heroStat(value: pet.ageText, label: "年龄", accent: .goTeal)
                                if let hAge = humanEquivalentAge {
                                    Text(hAge)
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                    }
                    .padding(.trailing, 14)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.vertical, 14)
            }
            .frame(height: 152)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            // 第二行：出生/到家/体重
                HStack(spacing: 0) {
                    if pet.birthday != nil {
                        heroInfoCell(icon: "birthday.cake.fill", label: "生日",
                                     value: pet.birthday?.formatted(.dateTime.month().day()) ?? "--",
                                     accent: .goYellow)
                        Divider().frame(height: 28).opacity(0.15)
                    }
                    if pet.homeDate != nil {
                        heroInfoCell(icon: "house.fill", label: "到家",
                                     value: pet.homeDate?.formatted(.dateTime.year().month().day()) ?? "--",
                                     accent: .goTeal)
                    }
                    if let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                        Divider().frame(height: 28).opacity(0.15)
                        heroInfoCell(icon: "scalemass.fill", label: "体重",
                                     value: String(format: "%.1f kg", w.weight),
                                     accent: .goPrimary)
                    }
                }
                .padding(.top, 4)

            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func heroTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
    }

    private func heroStat(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(accent)
        }
    }

    private func heroInfoCell(icon: String, label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// MARK: - L2 Smart Alert Scroll Section
// ═══════════════════════════════════════════════════════════════
private struct PetAlertScrollSection: View {
    let pet: Pet

    private var alerts: [(String, String, Color)] {
        var list: [(String, String, Color)] = []
        if pet.remainingFoodDays > 0 && pet.remainingFoodDays <= 3 {
            list.append(("⚠️", "即将断粮 · 仅剩 \(pet.remainingFoodDays) 天", .goOrange))
        }
        let now = Date()
        for doc in pet.documents {
            if let exp = doc.expiryDate, exp.timeIntervalSinceNow < 86400 * 14 && exp > now {
                let days = Calendar.current.dateComponents([.day], from: now, to: exp).day ?? 0
                list.append(("📄", "\(doc.title) 将在 \(days) 天到期", .goOrange))
            }
        }
        for log in pet.healthLogs.filter({ $0.type == "疫苗" }) {
            if let exp = log.expirationDate, exp.timeIntervalSinceNow < 86400 * 21 && exp > now {
                let days = Calendar.current.dateComponents([.day], from: now, to: exp).day ?? 0
                list.append(("💉", "\(log.type) 疫苗 \(days) 天后到期", .goRed))
            }
        }
        return list
    }

    var body: some View {
        if alerts.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                        HStack(spacing: 10) {
                            Text(alert.0).font(.system(size: 20))
                            Text(alert.1)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(alert.2.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(alert.2.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L3 Health Action Row
// ═══════════════════════════════════════════════════════════════
private struct PetHealthActionRow: View {
    let pet: Pet
    let onRecord: (HealthLogType) -> Void

    private let actions: [(String, String, Color, HealthLogType)] = [
        ("💉", "疫苗", .goCardCyan, .vaccine),
        ("🛡️", "驱虫", .goTeal,    .medication),
        ("🩺", "体检", .goYellow,  .checkup),
        ("🏥", "就诊", .goRed,     .surgery),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions, id: \.1) { emoji, label, accent, type in
                Button { onRecord(type) } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(accent.opacity(0.15)).frame(width: 46, height: 46)
                            Text(emoji).font(.system(size: 22))
                        }
                        Text(label)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .ohanaStandardCard(cornerRadius: 20)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L3 Health Hub Card（快动作 + 疫苗本入口 + 免疫状态）
// ═══════════════════════════════════════════════════════════════
private struct PetHealthHubCard: View {
    let pet: Pet
    let onRecord: (HealthLogType) -> Void
    var onViewDetail: (() -> Void)? = nil

    private var immunityRows: [(emoji: String, label: String, lastDate: Date?, expiryDate: Date?)] {
        let v = pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.sorted { $0.date > $1.date }.first
        let d = pet.healthLogs.filter { $0.type == HealthLogType.medication.rawValue }.sorted { $0.date > $1.date }.first
        let c = pet.healthLogs.filter { $0.type == HealthLogType.checkup.rawValue }.sorted { $0.date > $1.date }.first
        let s = pet.healthLogs.filter { $0.type == HealthLogType.surgery.rawValue }.sorted { $0.date > $1.date }.first
        return [
            ("💉", "疫苗", v?.date, v.flatMap { Calendar.current.date(byAdding: .year, value: 1, to: $0.date) }),
            ("🛡️", "驱虫", d?.date, d.flatMap { Calendar.current.date(byAdding: .month, value: 3, to: $0.date) }),
            ("🩺", "体检", c?.date, c.flatMap { Calendar.current.date(byAdding: .year, value: 1, to: $0.date) }),
            ("🏥", "就诊", s?.date, nil),
        ].filter { $0.lastDate != nil } // only show items with records
    }

    private var vaccineCount: Int { pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── 标题行
            Button { onViewDetail?() } label: {
                HStack(spacing: 8) {
                    Text("💉").font(.system(size: 16))
                    Text("免疫健康")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.25))
                }
            }
            .buttonStyle(.plain)

            // ── 有记录的项目 + 有效期
            if immunityRows.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
                    .padding(.vertical, 4)
            } else {
                ForEach(immunityRows, id: \.label) { row in
                    HStack(spacing: 8) {
                        Text(row.emoji).font(.system(size: 14))
                        Text(row.label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.8))
                        Spacer()
                        if let exp = row.expiryDate {
                            let isExpired = exp < Date()
                            let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
                            Text(isExpired ? "已过期" : "有效至 \(exp.formatted(.dateTime.month().day()))")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(isExpired ? Color.goRed : (daysLeft < 30 ? Color.goYellow : Color.goTeal))
                        } else if row.lastDate != nil {
                            Text(row.lastDate!.formatted(.dateTime.month().day()))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L4 Bento Grid
// ═══════════════════════════════════════════════════════════════
private struct PetBentoGrid: View {
    let pet: Pet
    let onWeight:  () -> Void
    let onWalk:    () -> Void
    let onPotty:   () -> Void
    let onExpense: () -> Void
    let onAddWeight: () -> Void
    @Binding var showingAddWeight: Bool
    @Binding var quickWeightInput: String
    let modelContext: ModelContext

    private var latestWeight: PetWeightLog? {
        pet.weightLogs.sorted { $0.date > $1.date }.first
    }
    private var monthTotal: Double {
        pet.expenseLogs.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    private var todayPotty: Int {
        pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
    }
    private var lastWalk: PetWalkLog? {
        pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // ── 体重（宽卡）──
                Button(action: onWeight) {
                    bentoWeightCard
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // ── 花费（方卡）──
                Button(action: onExpense) {
                    bentoExpenseCard
                }
                .buttonStyle(.plain)
                .frame(width: 130)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                // ── 遛狗（宽卡，仅狗）──
                if pet.species == "狗" {
                    Button(action: onWalk) { bentoWalkCard }
                        .buttonStyle(.plain).frame(maxWidth: .infinity)
                } else {
                    // 余粮（宽卡，非狗品种）
                    bentoFoodCard.frame(maxWidth: .infinity)
                }

                // ── 噗噗（方卡）──
                Button(action: onPotty) { bentoPottyCard }
                    .buttonStyle(.plain).frame(width: 130)
            }
            .padding(.horizontal, 16)

            // ── 余粮（仅狗显示，独立全宽）──
            if pet.species == "狗" && pet.dailyPortionGrams > 0 {
                bentoFoodCard.padding(.horizontal, 16)
            }
        }
    }

    // 体重卡
    private var bentoWeightCard: some View {
        UltimateGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("体重", systemImage: "scalemass")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goTeal)
                    Spacer()
                    Button {
                        showingAddWeight.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
                if let w = latestWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", w.weight))
                            .font(OhanaFont.metric(size: 32))
                            .foregroundStyle(.primary)
                        Text("kg").font(OhanaFont.caption(.bold)).foregroundStyle(Color.goTeal)
                    }
                } else {
                    Text("--").font(OhanaFont.metric(size: 32)).foregroundStyle(.primary.opacity(0.3))
                }
                if showingAddWeight {
                    HStack(spacing: 8) {
                        TextField("0.0", text: $quickWeightInput)
                            .keyboardType(.decimalPad)
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .goGlassBackground(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Button {
                            if let w = Double(quickWeightInput.replacingOccurrences(of: ",", with: ".")) {
                                let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                                    .flatMap { $0.isEmpty ? nil : $0 }
                                let log = PetWeightLog(date: Date(), weight: w, pet: pet, executorId: executorId)
                                modelContext.insert(log)
                                modelContext.safeSave()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            quickWeightInput = ""
                            showingAddWeight = false
                        } label: {
                            Text("存").font(OhanaFont.caption(.black)).foregroundStyle(.black)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.goPrimary, in: Capsule())
                        }
                    }
                }
                // mini weight chart
                let sorted = pet.weightLogs.sorted { $0.date < $1.date }
                if sorted.count >= 2 {
                    WeightLineChart(logs: Array(sorted.suffix(8))).frame(height: 40)
                }
            }
            .padding(14)
        }
    }

    // 花费卡
    private var bentoExpenseCard: some View {
        UltimateGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("花费", systemImage: "yensign.circle")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goYellow)
                Text("¥\(Int(monthTotal))")
                    .font(OhanaFont.metric(size: 26))
                    .foregroundStyle(.primary).minimumScaleFactor(0.6).lineLimit(1)
                Text("本月")
                    .font(OhanaFont.caption2(.medium)).foregroundStyle(.primary.opacity(0.35))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.primary.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .frame(minHeight: 130)
        }
    }

    // 遛狗卡
    private var bentoWalkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("巡岛", systemImage: "figure.walk")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Spacer()
                Text("查看 →").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.goPrimary.opacity(0.6))
            }
            if let w = lastWalk {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("距离").font(.system(size: 9, weight: .semibold)).foregroundStyle(.primary.opacity(0.4))
                        Text(w.distanceText).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.primary)
                    }
                    Rectangle().fill(.primary.opacity(0.1)).frame(width: 1, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("时长").font(.system(size: 9, weight: .semibold)).foregroundStyle(.primary.opacity(0.4))
                        Text(w.durationText).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.primary)
                    }
                }
            } else {
                Text("暂无记录").font(.system(size: 13, weight: .medium)).foregroundStyle(.primary.opacity(0.3))
            }
            Text("\(pet.walkLogs.count) 次巡岛").font(.system(size: 10, weight: .medium)).foregroundStyle(.primary.opacity(0.3))
        }
        .padding(14)
        .background(LinearGradient(colors: [Color.goPrimary.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.goPrimary.opacity(0.2), lineWidth: 1))
    }

    // 噗噗卡
    private var bentoPottyCard: some View {
        UltimateGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("噗噗", systemImage: "drop.fill")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goOrange)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(todayPotty)").font(OhanaFont.metric(size: 28)).foregroundStyle(.primary)
                    Text("次").font(OhanaFont.caption(.bold)).foregroundStyle(Color.goOrange)
                }
                Text("今日").font(OhanaFont.caption2(.medium)).foregroundStyle(.primary.opacity(0.35))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundStyle(.primary.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .frame(minHeight: 130)
        }
    }

    // 粮仓卡
    private var bentoFoodCard: some View {
        UltimateGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("粮仓", systemImage: "fork.knife")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goOrange)
                    Spacer()
                    if pet.remainingFoodDays > 0 && pet.remainingFoodDays <= 7 {
                        Text("⚠️ 仅剩 \(pet.remainingFoodDays) 天")
                            .font(OhanaFont.caption(.bold)).foregroundStyle(Color.goRed)
                    }
                }
                if pet.remainingFoodDays > 0 {
                    ProgressView(value: pet.remainingFoodPercent)
                        .tint(pet.remainingFoodDays <= 7 ? Color.goRed : Color.goTeal)
                    HStack {
                        Text("\(Int(pet.remainingFoodGrams))g 剩余")
                        Spacer()
                        Text("\(pet.remainingFoodDays) 天")
                    }
                    .font(OhanaFont.caption(.medium)).foregroundStyle(.primary.opacity(0.4))
                } else {
                    Text("未设置粮食库存").font(OhanaFont.caption(.medium)).foregroundStyle(.primary.opacity(0.3))
                }
            }
            .padding(14)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Weight Line Chart（保留供 Bento 使用）
// ═══════════════════════════════════════════════════════════════
struct WeightLineChart: View {
    let logs: [PetWeightLog]

    private var weights: [Double] { logs.map { $0.weight } }
    private var minW: Double { (weights.min() ?? 0) - 0.2 }
    private var maxW: Double { (weights.max() ?? 1) + 0.2 }
    private var range: Double { max(maxW - minW, 0.1) }

    private func xPos(_ i: Int, w: CGFloat) -> CGFloat {
        logs.count <= 1 ? w / 2 : CGFloat(i) / CGFloat(logs.count - 1) * w
    }
    private func yPos(_ v: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((v - minW) / range) * h
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if logs.count >= 2 {
                    Path { p in
                        p.move(to: CGPoint(x: xPos(0, w: w), y: h))
                        p.addLine(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(weights[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            p.addCurve(to: curr,
                                       control1: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: prev.y),
                                       control2: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: curr.y))
                        }
                        p.addLine(to: CGPoint(x: xPos(logs.count-1, w: w), y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.goTeal.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))

                    Path { p in
                        p.move(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(weights[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            p.addCurve(to: curr,
                                       control1: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: prev.y),
                                       control2: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: curr.y))
                        }
                    }
                    .stroke(Color.goTeal, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }
}

// MARK: - task4: 饮食排泄卡片（内联快速打卡）
private struct DietCardWithQuickActions: View {
    let pet: Pet
    let onOpenDetail: () -> Void
    @Environment(\.modelContext) private var modelContext

    private var isCatLike: Bool {
        ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
    }
    private var todayFeed: Int {
        pet.careLogs.filter { $0.type == CareType.feeding.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }
    private var todayWater: Int {
        pet.careLogs.filter { $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }
    private var todayPotty: Int {
        if isCatLike {
            return pet.careLogs.filter { $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date) }.count
        } else {
            return pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpenDetail) {
                HStack(spacing: 6) {
                    Text("🍽️").font(.system(size: 14))
                    Text("饮食排泄")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            VStack(spacing: 8) {
                Button {
                    CareEventService.recordManualFeed(pet: pet, amountGrams: pet.dailyPortionGrams, context: modelContext)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dietActionCell(
                        emoji: "🍗", label: "喂食", countLabel: "\(todayFeed) 次",
                        accent: Color.goOrange
                    )
                }
                .buttonStyle(.plain)

                Button {
                    CareEventService.recordCare(pet: pet, type: .watering, amountMl: 250, context: modelContext, reward: .water)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dietActionCell(
                        emoji: "💧", label: "喂水", countLabel: "\(todayWater) 次",
                        accent: Color.goCardCyan
                    )
                }
                .buttonStyle(.plain)

                Button {
                    let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
                    if isCatLike {
                        CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: eid, reward: .potty(isLitter: true))
                    } else {
                        CareEventService.recordPotty(pet: pet, context: modelContext, executorId: eid)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dietActionCell(
                        emoji: isCatLike ? "🧹" : "💩",
                        label: isCatLike ? "铲砂" : "便便",
                        countLabel: "\(todayPotty) 次",
                        accent: isCatLike ? Color(hex: "5B6AFF") : Color(hex: "FF8C42")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4).padding(.vertical, 8)
        }
        .padding(.horizontal, 4)
    }

    private func dietActionCell(emoji: String, label: String, countLabel: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(countLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(accent)
            }
            Spacer()
            Text("+")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(accent.opacity(0.6))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
