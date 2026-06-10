//
//  FocusHomeAuxiliaryViews.swift
//  Ohana
//
//  Small rendering-only helpers used by the home flow.
//

import SwiftUI

nonisolated struct TodayFocusPetSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let currentStreak: Int
    let coconutBalance: Int
    let hasPassedAway: Bool

    init(pet: Pet) {
        id = pet.id
        name = pet.name
        currentStreak = pet.currentStreak
        coconutBalance = pet.coconutBalance
        hasPassedAway = pet.hasPassedAway
    }
}

nonisolated struct TodayFocusPlantSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let lastWateredDate: Date?
    let lastFertilizedDate: Date?

    init(plant: Plant) {
        id = plant.id
        name = plant.name
        wateringIntervalDays = plant.wateringIntervalDays
        fertilizingIntervalDays = plant.fertilizingIntervalDays
        lastWateredDate = plant.lastWateredDate
        lastFertilizedDate = plant.lastFertilizedDate
    }
}

nonisolated struct TodayFocusHumanSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let coconutBalance: Int

    init(human: Human) {
        id = human.id
        name = human.name
        coconutBalance = human.coconutBalance
    }
}

nonisolated struct TodayFocusFamilyTaskSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let statusRaw: String
    let status: FamilyCollaborationTaskStatus
    let createdByName: String
    let assignedToId: String?
    let assignedToName: String?
    let claimedById: String?
    let claimedByName: String?
    let completedByName: String?
    let rewardCoconuts: Int
    let dueAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let emoji: String
    let hasReward: Bool

    init(task: FamilyCollaborationTask) {
        id = task.id
        title = task.title
        statusRaw = task.statusRaw
        status = task.status
        createdByName = task.createdByName
        assignedToId = task.assignedToId
        assignedToName = task.assignedToName
        claimedById = task.claimedById
        claimedByName = task.claimedByName
        completedByName = task.completedByName
        rewardCoconuts = task.rewardCoconuts
        dueAt = task.dueAt
        createdAt = task.createdAt
        updatedAt = task.updatedAt
        emoji = task.emoji
        hasReward = task.hasReward
    }
}

nonisolated struct TodayFocusExchangeRequestSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let senderName: String
    let receiverId: String
    let coconutCost: Int
    let currencyCode: String
    let localAmount: Double
    let statusRaw: String
    let status: CoconutExchangeRequestStatus
    let createdAt: Date
    let updatedAt: Date

    init(request: CoconutExchangeRequest) {
        id = request.id
        senderName = request.senderName
        receiverId = request.receiverId
        coconutCost = request.coconutCost
        currencyCode = request.currencyCode
        localAmount = request.localAmount
        statusRaw = request.statusRaw
        status = request.status
        createdAt = request.createdAt
        updatedAt = request.updatedAt
    }
}

nonisolated struct TodayFocusSnapshot: Equatable, Sendable {
    let pets: [TodayFocusPetSnapshot]
    let plants: [TodayFocusPlantSnapshot]
    let humans: [TodayFocusHumanSnapshot]
    let refreshedQuests: [IslandQuest]
    let assignedFamilyTasks: [TodayFocusFamilyTaskSnapshot]
    let pendingExchangeRequests: [TodayFocusExchangeRequestSnapshot]
    let negativeSignals: [IslandNegativeSignal]

    static let empty = TodayFocusSnapshot(
        pets: [],
        plants: [],
        humans: [],
        refreshedQuests: [],
        assignedFamilyTasks: [],
        pendingExchangeRequests: [],
        negativeSignals: []
    )

    @MainActor
    static func make(
        pets: [Pet],
        plants: [Plant],
        reminders: [Reminder],
        events: [Event],
        humans: [Human],
        activeHumanId: String,
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        todayFocus: TodayFocusManaging,
        healthAlerts: PetHealthAlerting
    ) -> TodayFocusSnapshot {
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: plants,
            events: events,
            humans: humans
        )
        let refreshedQuests = todayFocus.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: .current,
            now: Date()
        )
        let assignedTasks: [FamilyCollaborationTask]
        if activeHumanId.isEmpty {
            assignedTasks = []
        } else {
            assignedTasks = familyTasks
                .filter {
                    !$0.isFinished &&
                    (($0.status == .pendingReview && $0.createdById == activeHumanId) ||
                     ($0.status != .pendingReview && ($0.assignedToId == activeHumanId || $0.claimedById == activeHumanId)))
                }
                .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
        }
        let pendingExchanges: [CoconutExchangeRequest]
        if activeHumanId.isEmpty {
            pendingExchanges = []
        } else {
            pendingExchanges = exchangeRequests
                .filter { $0.status == .pending && $0.receiverId == activeHumanId }
                .sorted { $0.createdAt < $1.createdAt }
        }
        return make(
            pets: pets,
            plants: plants,
            humans: humans,
            refreshedQuests: refreshedQuests,
            assignedTasks: assignedTasks,
            pendingExchanges: pendingExchanges,
            negativeSignals: IslandNegativeFeedback.signals(
                pets: pets,
                plants: plants,
                healthAlerts: healthAlerts
            )
        )
    }

    static func make(
        pets: [Pet],
        plants: [Plant],
        reminders: [Reminder],
        events: [Event],
        humans: [Human],
        activeHumanId: String,
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        questManager: QuestManager,
        clinicalAlerts: [HealthAlert]
    ) -> TodayFocusSnapshot {
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: plants,
            events: events,
            humans: humans,
            questManager: questManager
        )
        let refreshedQuests = TodayFocusQuestRefresher().refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: .current,
            now: Date(),
            questManager: questManager
        )
        let assignedTasks: [FamilyCollaborationTask]
        if activeHumanId.isEmpty {
            assignedTasks = []
        } else {
            assignedTasks = familyTasks
                .filter {
                    !$0.isFinished &&
                    (($0.status == .pendingReview && $0.createdById == activeHumanId) ||
                     ($0.status != .pendingReview && ($0.assignedToId == activeHumanId || $0.claimedById == activeHumanId)))
                }
                .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
        }
        let pendingExchanges: [CoconutExchangeRequest]
        if activeHumanId.isEmpty {
            pendingExchanges = []
        } else {
            pendingExchanges = exchangeRequests
                .filter { $0.status == .pending && $0.receiverId == activeHumanId }
                .sorted { $0.createdAt < $1.createdAt }
        }
        return make(
            pets: pets,
            plants: plants,
            humans: humans,
            refreshedQuests: refreshedQuests,
            assignedTasks: assignedTasks,
            pendingExchanges: pendingExchanges,
            negativeSignals: IslandNegativeFeedback.signals(
                pets: pets,
                plants: plants,
                clinicalAlerts: clinicalAlerts
            )
        )
    }

    private static func make(
        pets: [Pet],
        plants: [Plant],
        humans: [Human],
        refreshedQuests: [IslandQuest],
        assignedTasks: [FamilyCollaborationTask],
        pendingExchanges: [CoconutExchangeRequest],
        negativeSignals: [IslandNegativeSignal]
    ) -> TodayFocusSnapshot {
        TodayFocusSnapshot(
            pets: pets.map(TodayFocusPetSnapshot.init),
            plants: plants.map(TodayFocusPlantSnapshot.init),
            humans: humans.map(TodayFocusHumanSnapshot.init),
            refreshedQuests: refreshedQuests,
            assignedFamilyTasks: assignedTasks.map(TodayFocusFamilyTaskSnapshot.init),
            pendingExchangeRequests: pendingExchanges.map(TodayFocusExchangeRequestSnapshot.init),
            negativeSignals: negativeSignals
        )
    }
}

struct TodayFocusQuestCardHost: View {
    let snapshot: TodayFocusSnapshot
    let isLive: Bool
    var presentation: TodayFocusCardPresentation = .board
    var onOpenQuest: (IslandQuest) -> Void
    var onCompleteQuest: (IslandQuest) -> Void
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void
    var onTapOasis: () -> Void
    var onTapFamilyTask: (TodayFocusFamilyTaskSnapshot) -> Void
    var onConfirmExchange: (TodayFocusExchangeRequestSnapshot) -> Void = { _ in }

    @State private var renderSnapshot = TodayFocusSnapshot.empty
    @State private var renderSnapshotRefreshKey: SnapshotRefreshKey?

    init(
        snapshot: TodayFocusSnapshot,
        isLive: Bool = true,
        presentation: TodayFocusCardPresentation = .board,
        onOpenQuest: @escaping (IslandQuest) -> Void,
        onCompleteQuest: @escaping (IslandQuest) -> Void,
        onTapNegativeSignal: @escaping (IslandNegativeSignal) -> Void,
        onTapOasis: @escaping () -> Void,
        onTapFamilyTask: @escaping (TodayFocusFamilyTaskSnapshot) -> Void,
        onConfirmExchange: @escaping (TodayFocusExchangeRequestSnapshot) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.isLive = isLive
        self.presentation = presentation
        self.onOpenQuest = onOpenQuest
        self.onCompleteQuest = onCompleteQuest
        self.onTapNegativeSignal = onTapNegativeSignal
        self.onTapOasis = onTapOasis
        self.onTapFamilyTask = onTapFamilyTask
        self.onConfirmExchange = onConfirmExchange
        _renderSnapshot = State(initialValue: snapshot)
        _renderSnapshotRefreshKey = State(initialValue: SnapshotRefreshKey(snapshot: snapshot))
    }

    var body: some View {
        TodayFocusCard(
            snapshot: renderSnapshot,
            presentation: presentation,
            onOpenQuest: onOpenQuest,
            onCompleteQuest: onCompleteQuest,
            onTapNegativeSignal: onTapNegativeSignal,
            onTapOasis: onTapOasis,
            onTapFamilyTask: onTapFamilyTask,
            onConfirmExchange: onConfirmExchange,
            freezesToFrontCard: !isLive,
            allowsAmbientMotion: isLive && presentation == .board
        )
        .task(id: snapshotTaskKey) {
            guard case .live(let key) = snapshotTaskKey else { return }
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 96)
            guard !Task.isCancelled else { return }
            refreshSnapshotIfNeeded(for: key)
        }
    }

    private enum SnapshotTaskKey: Equatable, Sendable {
        case live(SnapshotRefreshKey)
        case frozen
    }

    private struct SnapshotRefreshKey: Equatable, Sendable {
        let language: String
        let pets: Int
        let plants: Int
        let humans: Int
        let quests: Int
        let familyTasks: Int
        let exchangeRequests: Int
        let negativeSignals: Int

        init(snapshot: TodayFocusSnapshot) {
            language = AppLanguage.code
            pets = Self.token(snapshot.pets.prefix(12)) { pet in
                Self.combine(
                    pet.id.hashValue,
                    pet.name.hashValue,
                    pet.currentStreak,
                    pet.coconutBalance,
                    pet.hasPassedAway ? 1 : 0
                )
            }
            plants = Self.token(snapshot.plants.prefix(12)) { plant in
                Self.combine(
                    plant.id.hashValue,
                    plant.name.hashValue,
                    plant.wateringIntervalDays,
                    plant.fertilizingIntervalDays,
                    Self.timestampValue(plant.lastWateredDate),
                    Self.timestampValue(plant.lastFertilizedDate)
                )
            }
            humans = Self.token(snapshot.humans.prefix(12)) { human in
                Self.combine(
                    human.id.hashValue,
                    human.name.hashValue,
                    human.coconutBalance
                )
            }
            quests = Self.token(snapshot.refreshedQuests) { quest in
                Self.combine(
                    quest.id.hashValue,
                    quest.title.hashValue,
                    quest.subtitle.hashValue,
                    quest.isCompleted ? 1 : 0,
                    quest.targetPetId?.hashValue ?? 0,
                    quest.targetPlantId?.hashValue ?? 0
                )
            }
            familyTasks = Self.token(snapshot.assignedFamilyTasks.prefix(12)) { task in
                Self.combine(
                    task.id.hashValue,
                    task.statusRaw.hashValue,
                    (task.assignedToId ?? "").hashValue,
                    (task.claimedById ?? "").hashValue,
                    Self.timestampValue(task.updatedAt)
                )
            }
            exchangeRequests = Self.token(snapshot.pendingExchangeRequests.prefix(12)) { request in
                Self.combine(
                    request.id.hashValue,
                    request.statusRaw.hashValue,
                    request.receiverId.hashValue,
                    Self.timestampValue(request.updatedAt)
                )
            }
            negativeSignals = Self.token(snapshot.negativeSignals) { signal in
                Self.combine(
                    signal.title.hashValue,
                    signal.detail.hashValue,
                    signal.petId?.hashValue ?? 0
                )
            }
        }

        private static func token<S: Sequence>(_ items: S, token: (S.Element) -> Int) -> Int {
            items.reduce(0) { partial, item in
                combine(partial, token(item))
            }
        }

        private static func combine(_ values: Int...) -> Int {
            values.reduce(17) { partial, value in
                partial &* 31 &+ value
            }
        }

        private static func timestampValue(_ date: Date) -> Int {
            Int(date.timeIntervalSince1970)
        }

        private static func timestampValue(_ date: Date?) -> Int {
            guard let date else { return 0 }
            return timestampValue(date)
        }
    }

    private var snapshotTaskKey: SnapshotTaskKey {
        isLive ? .live(snapshotRefreshKey) : .frozen
    }

    private var snapshotRefreshKey: SnapshotRefreshKey {
        SnapshotRefreshKey(snapshot: snapshot)
    }

    private func refreshSnapshotIfNeeded(for key: SnapshotRefreshKey) {
        guard key != renderSnapshotRefreshKey else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            renderSnapshot = snapshot
            renderSnapshotRefreshKey = key
        }
    }
}

struct WalkLaunchBurst: View {
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
                Image(systemName: "figure.walk.motion") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 20, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text("开始巡岛")
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.goPrimary, in: Capsule())
            .scaleEffect(animate ? 1 : 0.72)
            .opacity(animate ? 1 : 0)

            ForEach(paws.indices, id: \.self) { index in
                Image(systemName: "pawprint.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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

struct FocusHumanPortrait: View {
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
