//
//  TodayFocusCard.swift
//  Ohana
//
//  首页简化 · 岛屿三层重构（P0）
//  替换原先的 HomeHighlightDeck 水平滑动卡组：
//  按优先级智能选出"今天最该做的 1 件事"，单卡呈现 + 微动效。
//
//  优先级：异常趋势/医疗风险 > 未完成委托 > 记忆碎片 > 全部完成庆祝 > 岛屿探访
//
//  v2 实时响应：内部 @Query 监听 PetCareLog / PetWalkLog / PetPottyLog，
//  用户在对应打卡/记录页保存后无需父视图手动刷新。
//

import SwiftUI
import SwiftData

enum TodayFocusCardPresentation {
    case board
    case compactStack
}

// MARK: - TodayFocusCard

struct TodayFocusCard: View {
    let pets: [Pet]
    let plants: [Plant]
    let quests: [IslandQuest]        // passed from parent; isCompleted may be stale
    let humans: [Human]
    let activePet: Pet?
    let presentation: TodayFocusCardPresentation
    var onOpenQuest: (IslandQuest) -> Void = { _ in }
    var onCompleteQuest: (IslandQuest) -> Void = { _ in }
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void = { _ in }
    var onTapMemory: () -> Void = {}
    var onTapOasis: () -> Void = {}
    var onTapFamilyTask: (FamilyCollaborationTask) -> Void = { _ in }

    // Live @Query arrays — scoped to today so the home card does not hydrate
    // the full care history on every launch.
    @Query(sort: \PetCareLog.date, order: .reverse) private var liveCare: [PetCareLog]
    @Query(sort: \PetWalkLog.startDate, order: .reverse) private var liveWalks: [PetWalkLog]
    @Query(sort: \PetPottyLog.date, order: .reverse) private var livePotty: [PetPottyLog]
    @Query(sort: \HumanWeightLog.date, order: .reverse) private var liveHumanWeights: [HumanWeightLog]
    @Query(sort: \FamilyCollaborationTask.updatedAt, order: .reverse) private var familyTasks: [FamilyCollaborationTask]
    @Query(sort: \CoconutExchangeRequest.createdAt, order: .reverse) private var exchangeRequests: [CoconutExchangeRequest]

    @State private var bounceEmoji = false
    @State private var pulse: CGFloat = 0
    @State private var selectedFocusIndex = 0
    @State private var skippedFocusKeys: Set<String> = TodayFocusCard.loadSkippedFocusKeys()
    @State private var closedNegativeKeys: Set<String> = TodayFocusCard.loadClosedNegativeKeys()
    @GestureState private var focusDragY: CGFloat = 0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    init(
        pets: [Pet],
        plants: [Plant],
        quests: [IslandQuest],
        humans: [Human],
        activePet: Pet?,
        presentation: TodayFocusCardPresentation = .board,
        onOpenQuest: @escaping (IslandQuest) -> Void = { _ in },
        onCompleteQuest: @escaping (IslandQuest) -> Void = { _ in },
        onTapNegativeSignal: @escaping (IslandNegativeSignal) -> Void = { _ in },
        onTapMemory: @escaping () -> Void = {},
        onTapOasis: @escaping () -> Void = {},
        onTapFamilyTask: @escaping (FamilyCollaborationTask) -> Void = { _ in }
    ) {
        self.pets = pets
        self.plants = plants
        self.quests = quests
        self.humans = humans
        self.activePet = activePet
        self.presentation = presentation
        self.onOpenQuest = onOpenQuest
        self.onCompleteQuest = onCompleteQuest
        self.onTapNegativeSignal = onTapNegativeSignal
        self.onTapMemory = onTapMemory
        self.onTapOasis = onTapOasis
        self.onTapFamilyTask = onTapFamilyTask

        let todayStart = Calendar.current.startOfDay(for: Date())
        _liveCare = Query(
            filter: #Predicate<PetCareLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _liveWalks = Query(
            filter: #Predicate<PetWalkLog> { $0.startDate >= todayStart },
            sort: \.startDate,
            order: .reverse
        )
        _livePotty = Query(
            filter: #Predicate<PetPottyLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _liveHumanWeights = Query(
            filter: #Predicate<HumanWeightLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
    }

    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.ambientMotionBudget(isVisible: true) == .static
    }

    private var refreshedQuests: [IslandQuest] {
        TodayFocusService.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            careLogs: liveCare,
            walkLogs: liveWalks,
            pottyLogs: livePotty,
            humanWeightLogs: liveHumanWeights
        )
    }

    private var pendingQuests: [IslandQuest] {
        refreshedQuests.filter { !$0.isCompleted && !skippedFocusKeys.contains(questSkipKey($0)) }
    }

    private var assignedFamilyTasks: [FamilyCollaborationTask] {
        guard !activeHumanId.isEmpty else { return [] }
        return familyTasks
            .filter {
                !$0.isFinished &&
                (($0.status == .pendingReview && $0.createdById == activeHumanId) ||
                 ($0.status != .pendingReview && ($0.assignedToId == activeHumanId || $0.claimedById == activeHumanId))) &&
                !skippedFocusKeys.contains(familyTaskSkipKey($0))
            }
            .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
    }

    private var pendingExchangeRequests: [CoconutExchangeRequest] {
        guard !activeHumanId.isEmpty else { return [] }
        return exchangeRequests
            .filter {
                $0.status == .pending &&
                $0.receiverId == activeHumanId &&
                !skippedFocusKeys.contains(exchangeSkipKey($0))
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var negativeSignals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(pets: pets, plants: plants)
            .filter { !closedNegativeKeys.contains(negativeSkipKey($0)) }
    }

    private var focusCards: [TodayFocusService.Content] {
        if !negativeSignals.isEmpty {
                return negativeSignals.prefix(2).map { .negative($0) } +
                assignedFamilyTasks.map { .familyTask($0) } +
                pendingExchangeRequests.map { .coconutExchange($0) } +
                pendingQuests.map { .quest($0) }
        }
        if !assignedFamilyTasks.isEmpty {
            return assignedFamilyTasks.map { .familyTask($0) } +
                pendingExchangeRequests.map { .coconutExchange($0) } +
                pendingQuests.map { .quest($0) }
        }
        if !pendingExchangeRequests.isEmpty {
            return pendingExchangeRequests.map { .coconutExchange($0) } + pendingQuests.map { .quest($0) }
        }
        if !pendingQuests.isEmpty {
            return pendingQuests.map { .quest($0) }
        }
        if !refreshedQuests.isEmpty || !pets.isEmpty || !plants.isEmpty || !humans.isEmpty {
            return [.celebrate(pets: pets)]
        }
        return [.welcome]
    }

    private var content: TodayFocusService.Content {
        let cards = focusCards
        guard !cards.isEmpty else { return .welcome }
        return cards[min(selectedFocusIndex, cards.count - 1)]
    }

    private var focusStatusText: String {
        switch content {
        case .quest(let quest):
            return indexedStatus(
                current: pendingQuests.firstIndex { questSkipKey($0) == questSkipKey(quest) },
                total: pendingQuests.count,
                zh: "个任务",
                en: "tasks",
                de: "Aufgaben"
            )
        case .familyTask(let task):
            return indexedStatus(
                current: assignedFamilyTasks.firstIndex { familyTaskSkipKey($0) == familyTaskSkipKey(task) },
                total: assignedFamilyTasks.count,
                zh: "协作",
                en: "collab",
                de: "Team"
            )
        case .coconutExchange(let request):
            return indexedStatus(
                current: pendingExchangeRequests.firstIndex { exchangeSkipKey($0) == exchangeSkipKey(request) },
                total: pendingExchangeRequests.count,
                zh: "待收款",
                en: "to confirm",
                de: "offen"
            )
        case .negative, .memory, .celebrate, .welcome:
            return TodayFocusService.statusText(for: content)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch presentation {
            case .board:
                boardBody
            case .compactStack:
                compactBody
            }
        }
        .onAppear {
            startAmbientPulseIfNeeded()
        }
        .onChange(of: shouldReduceWork) { _, reduced in
            if reduced {
                pulse = 0
                bounceEmoji = false
            } else {
                startAmbientPulseIfNeeded()
            }
        }
        .onChange(of: focusCards.count) { _, count in
            if selectedFocusIndex >= count {
                selectedFocusIndex = max(0, count - 1)
            }
        }
        .animation(GoMotion.hero, value: contentIdentity)
    }

    private var boardBody: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "今日", en: "TODAY", de: "HEUTE"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.36))
                            .todayFocusReadableShadow(strength: 0.8)
                        Text(l.tr(zh: "任务盘", en: "Task board", de: "Aufgabenbrett"))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
                            .todayFocusReadableShadow()
                    }
                    Spacer()
                    Text(focusStatusText)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.ohanaControlFill, in: Capsule())
                        .contentTransition(.numericText())
                        .animation(GoMotion.feedback, value: focusStatusText)
                        .todayFocusReadableShadow(strength: 0.75)
                    if case .quest(let q) = content {
                        rewardChip(IslandQuestEngine.coconutReward(forQuestId: q.id))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 4)

                card(showsPageIndicator: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                    .id(contentIdentity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
    }

    private var compactBody: some View {
        card(showsPageIndicator: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .id(contentIdentity)
    }

    private func startAmbientPulseIfNeeded() {
        guard !shouldReduceWork else { return }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = 1 } // ui-v4: allow Today Focus ambient pulse micro-motion
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounceEmoji = true } // ui-v4: allow Today Focus celebration bounce micro-motion
    }

    // MARK: - Card switcher

    private struct FocusDeckCard: Identifiable {
        let id: String
        let content: TodayFocusService.Content
    }

    private var focusDeckCards: [FocusDeckCard] {
        focusCards.map { FocusDeckCard(id: contentKey($0), content: $0) }
    }

    @ViewBuilder
    private func card(showsPageIndicator: Bool) -> some View {
        let cards = focusCards
        if presentation == .compactStack {
            physicalStackCard(cards: focusDeckCards)
        } else if cards.count > 1 {
            legacySwitchingCard(cards: cards, showsPageIndicator: showsPageIndicator)
        } else {
            cardContent(cards.first ?? .welcome)
        }
    }

    @ViewBuilder
    private func physicalStackCard(cards: [FocusDeckCard]) -> some View {
        if cards.count > 1 {
            GeometryReader { geo in
                let width = max(298, min(geo.size.width, 390))
                VerticalGlassCardStack(
                    cards: cards,
                    activeIndex: $selectedFocusIndex,
                    cardSize: CGSize(width: width, height: 92),
                    visibleBackCardCount: min(3, max(cards.count - 1, 0)),
                    backCardSpacing: 9,
                    swipeThreshold: 54,
                    wraps: true,
                    onIndexChanged: { _ in OhanaFeedback.light() }
                ) { item, _ in
                    cardContent(item.content)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 128)
            .onChange(of: cards.count) { _, count in
                if selectedFocusIndex >= count {
                    selectedFocusIndex = max(0, count - 1)
                }
            }
        } else {
            cardContent(cards.first?.content ?? .welcome)
                .frame(height: 92)
        }
    }

    @ViewBuilder
    private func legacySwitchingCard(cards: [TodayFocusService.Content], showsPageIndicator: Bool) -> some View {
        if cards.count > 1 {
            VStack(spacing: 4) {
                ZStack {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, item in
                        let relative = focusRelativeIndex(for: index, count: cards.count)
                        cardContent(item)
                            .padding(.horizontal, 2)
                            .offset(y: focusItemOffset(relative: relative))
                            .scaleEffect(focusItemScale(relative: relative))
                            .opacity(focusItemOpacity(relative: relative))
                            .allowsHitTesting(relative == 0)
                            .accessibilityHidden(relative != 0)
                    }
                }
                .frame(height: 112)
                .clipped()
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .highPriorityGesture(focusSwipeGesture(count: cards.count))

                if showsPageIndicator {
                    focusPageIndicator(count: cards.count, selected: selectedFocusIndex)
                }
            }
        } else {
            cardContent(cards.first ?? .welcome)
        }
    }

    private func focusSwipeGesture(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($focusDragY) { value, state, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                state = max(-76, min(76, value.translation.height))
            }
            .onEnded { value in
                let vertical = value.translation.height
                guard abs(vertical) > abs(value.translation.width) else { return }
                let predicted = value.predictedEndTranslation.height
                guard abs(vertical) > 44 || abs(predicted) > 92 else { return }
                shiftFocus(vertical < 0 ? 1 : -1, count: count)
            }
    }

    private func focusRelativeIndex(for index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let forward = (index - selectedFocusIndex + count) % count
        let backward = (selectedFocusIndex - index + count) % count
        return forward <= backward ? forward : -backward
    }

    private func focusItemOffset(relative: Int) -> CGFloat {
        CGFloat(relative) * 58 + focusDragY
    }

    private func focusItemScale(relative: Int) -> CGFloat {
        let dragProgress = min(1, abs(focusDragY) / 76)
        return relative == 0 ? (1 - dragProgress * 0.025) : (0.96 + dragProgress * 0.04)
    }

    private func focusItemOpacity(relative: Int) -> Double {
        let dragProgress = min(1, abs(focusDragY) / 76)
        if relative == 0 {
            return Double(1 - dragProgress * 0.34)
        }
        let isIncoming = (focusDragY < 0 && relative == 1) || (focusDragY > 0 && relative == -1)
        return isIncoming ? Double(dragProgress) : 0
    }

    private func shiftFocus(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        OhanaFeedback.light()
        withAnimation(GoMotion.selection) {
            selectedFocusIndex = (selectedFocusIndex + delta + count) % count
        }
    }

    @ViewBuilder
    private func cardContent(_ content: TodayFocusService.Content) -> some View {
        switch content {
        case .quest(let q):      questCard(q)
        case .familyTask(let t): familyTaskCard(t)
        case .coconutExchange(let request): exchangeCard(request)
        case .negative(let s):   negativeCard(s)
        case .memory(let m):     memoryCard(m)
        case .celebrate:         celebrateCard
        case .welcome:           welcomeCard
        }
    }

    // MARK: - Quest card

    private func questCard(_ q: IslandQuest) -> some View {
        let accent = Color.goPrimary
        return HStack(spacing: 14) {
            Button {
                OhanaFeedback.light()
                onOpenQuest(q)
            } label: {
                HStack(spacing: 14) {
                    iconBubble(emoji: q.emoji, accent: accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(q.title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .todayFocusReadableShadow(strength: 1.08)
                        questMetaRow(q)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 6) {
                Button {
                    OhanaFeedback.medium()
                    onCompleteQuest(q)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                        Text(l.tr(zh: "打卡", en: "Check in", de: "Abhaken"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .quest(q), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    private func familyTaskCard(_ task: FamilyCollaborationTask) -> some View {
        let accent = task.hasReward ? Color.goTeal : Color.goPurple
        let rewardText = task.rewardCoconuts > 0 ? " · +\(task.rewardCoconuts)🥥" : ""
        let performer = task.completedByName ?? l.tr(zh: "对方", en: "Someone", de: "Jemand")
        let actionTitle = task.status == .pendingReview
            ? l.tr(zh: "去确认", en: "Review", de: "Prüfen")
            : l.tr(zh: "去处理", en: "Open", de: "Öffnen")
        return HStack(spacing: 14) {
            Button {
                OhanaFeedback.light()
                onTapFamilyTask(task)
            } label: {
                HStack(spacing: 14) {
                    iconBubble(emoji: task.emoji, accent: accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .todayFocusReadableShadow(strength: 1.08)
                        Text(taskStatusLine(task, performer: performer, rewardText: rewardText))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 0.82)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 6) {
                Button {
                    OhanaFeedback.medium()
                    onTapFamilyTask(task)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .black))
                        Text(actionTitle)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .familyTask(task), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
        .ohanaPing(trigger: task.statusRaw, accent: Color.goYellow, isEnabled: task.status == .pendingReview && task.hasReward)
        .ohanaShine(trigger: task.statusRaw, cornerRadius: 20, isEnabled: task.status == .pendingReview)
    }

    private func exchangeCard(_ request: CoconutExchangeRequest) -> some View {
        let accent = Color.goYellow
        let amount = CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)
        return HStack(spacing: 14) {
            iconBubble(emoji: "💱", accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "确认线下收款", en: "Confirm cash received", de: "Zahlung bestätigen"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 1.08)
                Text("\(request.senderName) → \(amount) · \(request.coconutCost)🥥")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 0.82)
            }

            Spacer(minLength: 6)

            VStack(spacing: 6) {
                Button {
                    confirmExchange(request)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                        Text(l.tr(zh: "已收到", en: "Received", de: "Erhalten"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .coconutExchange(request), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    @ViewBuilder
    private func questMetaRow(_ quest: IslandQuest) -> some View {
        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            let tokens = refreshedQuests.filter { IslandQuestEngine.isOasisBuildQuest($0.id) }.prefix(3)
            HStack(spacing: 5) {
                ForEach(Array(tokens), id: \.id) { token in
                    HStack(spacing: 4) {
                        Text(token.emoji)
                            .font(.system(size: 10))
                        Image(systemName: token.isCompleted ? "checkmark" : "circle.fill")
                            .font(.system(size: token.isCompleted ? 8 : 5, weight: .black))
                    }
                    .foregroundStyle(token.isCompleted ? Color.goPrimary : Color.ohanaSecondaryText)
                    .frame(width: 36, height: 20)
                    .background(Color.ohanaControlFill, in: Capsule())
                }
            }
            .accessibilityLabel(l.tr(zh: "岛屿建设任务", en: "Oasis build quests", de: "Oase-Aufgaben"))
        } else if let name = questTargetName(quest) {
            compactMetaChip(icon: "person.crop.circle.fill", text: name, tint: Color.goPrimary)
        } else {
            compactMetaChip(icon: "clock.fill", text: l.tr(zh: "今天", en: "Today", de: "Heute"), tint: Color.goPrimary)
        }
    }

    private func compactMetaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))

            Text(text)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .todayFocusReadableShadow(strength: 0.55)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private func questTargetName(_ quest: IslandQuest) -> String? {
        if let petId = quest.targetPetId,
           let pet = pets.first(where: { $0.id == petId }) {
            return pet.name
        }
        if let plantId = quest.targetPlantId,
           let plant = plants.first(where: { $0.id == plantId }) {
            return plant.name
        }
        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           let human = humans.first(where: { $0.id == humanId }) {
            return human.name
        }
        return nil
    }

    private func taskStatusLine(_ task: FamilyCollaborationTask, performer: String, rewardText: String) -> String {
        if task.status == .pendingReview {
            return l.tr(
                zh: "\(performer) 待确认\(rewardText)",
                en: "\(performer) · review\(rewardText)",
                de: "\(performer) · prüfen\(rewardText)"
            )
        }
        let target = task.assignedToName ?? task.claimedByName ?? l.tr(zh: "全家", en: "Open", de: "Offen")
        return "\(task.createdByName) → \(target)\(rewardText)"
    }

    // MARK: - Negative signal card

    private func negativeCard(_ s: IslandNegativeSignal) -> some View {
        let accent = s.severity == .critical ? Color.goRed : Color.goYellow
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + pulse * 0.08)
                Image(systemName: s.iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(s.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .todayFocusReadableShadow(strength: 1.08)
                Text(negativeStatusText(for: s))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .todayFocusReadableShadow(strength: 0.82)
            }

            Spacer(minLength: 6)

            VStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTapNegativeSignal(s)
                } label: {
                    Text(negativeActionTitle(for: s))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .negative(s), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    private func negativeActionTitle(for signal: IslandNegativeSignal) -> String {
        switch signal.healthAlertType {
        case .weightGainAlert, .weightLossAlert:
            return l.tr(zh: "趋势", en: "Trend", de: "Trend")
        case .drinkingWeightAlert:
            return l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .none:
            return signal.severity == .critical ? l.tr(zh: "处理", en: "Act", de: "Los") : l.tr(zh: "查看", en: "Open", de: "Öffnen")
        default:
            return signal.severity == .critical ? l.tr(zh: "处理", en: "Act", de: "Los") : l.tr(zh: "查看", en: "Open", de: "Öffnen")
        }
    }

    private func negativeStatusText(for signal: IslandNegativeSignal) -> String {
        signal.severity == .critical
            ? l.tr(zh: "紧急", en: "Urgent", de: "Dringend")
            : l.tr(zh: "关注", en: "Watch", de: "Achten")
    }

    // MARK: - Memory fragment card

    private func memoryCard(_ m: MemoryFragment) -> some View {
        let accent = m.accentColor
        return HStack(spacing: 14) {
            iconBubble(emoji: m.emoji, accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(m.headline)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 1.08)
                Text(m.subline)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 0.82)
            }

            Spacer(minLength: 6)

            Button { onTapMemory() } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.15), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Celebrate card

    private var celebrateCard: some View {
        let accent = Color.goYellow
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + pulse * 0.1)
                Text("🎉")
                    .font(.system(size: 30))
                    .scaleEffect(bounceEmoji ? 1.1 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(skippedFocusKeys.isEmpty
                     ? l.tr(zh: "今日清空", en: "All clear", de: "Alles klar")
                     : l.tr(zh: "已暂时跳过", en: "Skipped today", de: "Heute übersprungen"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .todayFocusReadableShadow(strength: 1.08)
            }

            Spacer(minLength: 6)

            Button {
                if skippedFocusKeys.isEmpty {
                    onTapOasis()
                } else {
                    restoreSkippedFocusCards()
                }
            } label: {
                Text(skippedFocusKeys.isEmpty
                     ? l.tr(zh: "绿洲", en: "Oasis", de: "Oase")
                     : l.tr(zh: "恢复", en: "Restore", de: "Zurück"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Welcome card

    private var welcomeCard: some View {
        let accent = Color.goPrimary
        return HStack(spacing: 14) {
            iconBubble(emoji: "🏝️", accent: accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "岛屿欢迎你", en: "Welcome home", de: "Willkommen"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .todayFocusReadableShadow(strength: 1.08)
            }
            Spacer()
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func iconBubble(emoji: String, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 52, height: 52)
                .scaleEffect(1 + pulse * 0.06)
            Text(emoji)
                .font(.system(size: 28))
                .offset(y: pulse * 0.8 - 0.4)
        }
    }

    private func rewardChip(_ amount: Int) -> some View {
        HStack(spacing: 3) {
            Text("+\(amount)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.goYellow)
                .contentTransition(.numericText())
                .animation(GoMotion.feedback, value: amount)
                .todayFocusReadableShadow(strength: 0.9)
            Text("🥥")
                .font(.system(size: 10))
                .ohanaSymbolPulse(trigger: amount)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.goYellow.opacity(0.15), in: Capsule())
    }

    private func focusPageIndicator(count: Int, selected: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(idx == selected ? Color.goPrimary : Color.ohanaControlFill)
                    .frame(width: idx == selected ? 16 : 5, height: 5)
                    .animation(GoMotion.feedback, value: selected)
                    .ohanaPhasePop(trigger: selected, enabled: idx == selected)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("今日任务 \(min(selected + 1, count)) / \(count)")
    }

    private func indexedStatus(current: Int?, total: Int, zh: String, en: String, de: String) -> String {
        guard total > 0 else { return TodayFocusService.statusText(for: content) }
        let position = (current ?? 0) + 1
        return l.tr(
            zh: "\(position)/\(total) \(zh)",
            en: "\(position)/\(total) \(en)",
            de: "\(position)/\(total) \(de)"
        )
    }

    private var contentIdentity: String {
        [
            focusCards.map(contentKey).joined(separator: "|"),
            "skipped:\(skippedFocusKeys.sorted().joined(separator: ","))",
            "closed:\(closedNegativeKeys.sorted().joined(separator: ","))"
        ].joined(separator: "|")
    }

    private func confirmExchange(_ request: CoconutExchangeRequest) {
        guard let receiver = humans.first(where: { $0.id.uuidString == activeHumanId }) else { return }
        do {
            try CoconutExchangeService.confirm(request, by: receiver, context: modelContext)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func contentKey(_ content: TodayFocusService.Content) -> String {
        switch content {
        case .quest(let q): return questSkipKey(q)
        case .familyTask(let task): return familyTaskSkipKey(task)
        case .coconutExchange(let request): return exchangeSkipKey(request)
        case .negative(let s): return negativeSkipKey(s)
        case .memory(let m): return "memory:\(m.headline)"
        case .celebrate: return "celebrate"
        case .welcome: return "welcome"
        }
    }

    private func questSkipKey(_ quest: IslandQuest) -> String {
        "quest:\(quest.id)"
    }

    private func familyTaskSkipKey(_ task: FamilyCollaborationTask) -> String {
        "familyTask:\(task.id.uuidString)"
    }

    private func exchangeSkipKey(_ request: CoconutExchangeRequest) -> String {
        "coconutExchange:\(request.id.uuidString)"
    }

    private func negativeSkipKey(_ signal: IslandNegativeSignal) -> String {
        if let petId = signal.petId, let alertType = signal.healthAlertType {
            return "negative:health:\(petId.uuidString):\(alertType.rawValue)"
        }
        return "negative:\(signal.title)|\(signal.detail)"
    }

    private func skipButton(for content: TodayFocusService.Content, accent: Color) -> some View {
        let isNegative: Bool = {
            if case .negative = content { return true }
            return false
        }()
        return Button {
            skipFocusCard(content)
        } label: {
            Text(isNegative ? l.tr(zh: "关闭", en: "Close", de: "Schließen") : l.tr(zh: "跳过", en: "Skip", de: "Überspringen"))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.58))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.ohanaControlFill, in: Capsule())
                .overlay(Capsule().strokeBorder(accent.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isNegative ? l.tr(zh: "关闭这条提醒", en: "Close this alert", de: "Hinweis schließen") : l.tr(zh: "跳过这张卡", en: "Skip this card", de: "Karte überspringen"))
    }

    private func skipFocusCard(_ content: TodayFocusService.Content) {
        let key = contentKey(content)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(GoMotion.hero) {
            switch content {
            case .negative:
                _ = closedNegativeKeys.insert(key)
            default:
                _ = skippedFocusKeys.insert(key)
            }
        }
        persistHiddenFocusKeys()
        let nextCount = focusCards.count
        if selectedFocusIndex >= nextCount {
            selectedFocusIndex = max(0, nextCount - 1)
        }
    }

    private func restoreSkippedFocusCards() {
        withAnimation(GoMotion.hero) {
            skippedFocusKeys.removeAll()
            selectedFocusIndex = 0
        }
        UserDefaults.standard.removeObject(forKey: Self.skippedStorageKey())
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func persistHiddenFocusKeys() {
        UserDefaults.standard.set(Array(skippedFocusKeys), forKey: Self.skippedStorageKey())
        UserDefaults.standard.set(Array(closedNegativeKeys), forKey: Self.closedNegativeStorageKey())
    }

    private static func loadSkippedFocusKeys() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: skippedStorageKey()) ?? [])
    }

    private static func loadClosedNegativeKeys() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: closedNegativeStorageKey()) ?? [])
    }

    private static func skippedStorageKey() -> String {
        let day = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        return "todayFocus.skipped.\(day)"
    }

    private static func closedNegativeStorageKey() -> String {
        "todayFocus.closedNegativeSignals"
    }

    @ViewBuilder
    private func cardBackground(_ accent: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if presentation == .compactStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            accent.mix(with: .white, by: 0.22).opacity(0.96),
                            accent.mix(with: .black, by: 0.10).opacity(0.96),
                            Color.arkInk.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    shape
                        .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
                }
                .clipShape(shape)
                .compositingGroup()
        } else {
            ZStack {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive(false), in: shape) // ui-v4: allow Today Focus card glass preview
                    .ohanaBreathingGlow(accent: accent, isActive: !shouldReduceWork)
            }
            .clipShape(shape)
            .compositingGroup()
        }
    }
}

private extension View {
    func todayFocusReadableShadow(strength: Double = 1) -> some View {
        self
            .shadow(color: Color.arkInk.opacity(0.32 * strength), radius: 2.4 * strength, x: 0, y: 1.2) // ui-v4: allow requested Today Focus text readability shadow
            .shadow(color: Color.arkInk.opacity(0.16 * strength), radius: 8 * strength, x: 0, y: 3) // ui-v4: allow requested Today Focus text readability shadow
    }
}
