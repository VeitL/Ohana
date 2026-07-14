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
    let id: String
    let taskCenterItem: TaskCenterItemSnapshot
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

    init(item: TaskCenterItemSnapshot, familyTask: FamilyCollaborationTask?) {
        id = item.id
        taskCenterItem = item
        title = item.title
        statusRaw = familyTask?.statusRaw ?? item.workflowStatus.rawValue
        status = familyTask?.status ?? Self.collaborationStatus(item.workflowStatus)
        createdByName = familyTask?.createdByName ?? item.subjectName ?? ""
        assignedToId = familyTask?.assignedToId
        assignedToName = familyTask?.assignedToName
        claimedById = familyTask?.claimedById
        claimedByName = familyTask?.claimedByName
        completedByName = familyTask?.completedByName
        rewardCoconuts = familyTask?.rewardCoconuts ?? 0
        dueAt = item.dueAt
        createdAt = familyTask?.createdAt ?? item.scheduledAt
        updatedAt = familyTask?.updatedAt ?? item.scheduledAt
        emoji = familyTask?.emoji ?? item.eventType?.emoji ?? "📌"
        hasReward = familyTask?.hasReward ?? false
    }

    var primaryAction: TaskCenterAvailableAction? {
        let preferred: [TaskCenterAvailableAction] = [
            .approve,
            .claim,
            .submitForReview,
            .complete
        ]
        return preferred.first { taskCenterItem.availableActions.contains($0) }
    }

    private static func collaborationStatus(
        _ status: TaskCenterWorkflowStatus
    ) -> FamilyCollaborationTaskStatus {
        switch status {
        case .scheduled, .active: .active
        case .claimed: .claimed
        case .pendingReview: .pendingReview
        case .completed: .completed
        case .cancelled: .cancelled
        }
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
    let dayToken: Int
    let pets: [TodayFocusPetSnapshot]
    let plants: [TodayFocusPlantSnapshot]
    let humans: [TodayFocusHumanSnapshot]
    let refreshedQuests: [IslandQuest]
    let assignedFamilyTasks: [TodayFocusFamilyTaskSnapshot]
    let pendingExchangeRequests: [TodayFocusExchangeRequestSnapshot]
    let negativeSignals: [IslandNegativeSignal]

    static let empty = TodayFocusSnapshot(
        dayToken: 0,
        pets: [],
        plants: [],
        humans: [],
        refreshedQuests: [],
        assignedFamilyTasks: [],
        pendingExchangeRequests: [],
        negativeSignals: []
    )

    static func dayToken(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    @MainActor
    static func make(
        pets: [Pet],
        plants: [Plant],
        reminders: [Reminder],
        events: [Event],
        humans: [Human],
        humanMedications: [HumanMedication] = [],
        activeHumanId: String,
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        todayFocus: TodayFocusManaging,
        healthAlerts: PetHealthAlerting,
        now: Date = Date()
    ) -> TodayFocusSnapshot {
        let visiblePlants = PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel) ? plants : []
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: visiblePlants,
            events: events,
            humans: humans,
            humanMedications: humanMedications,
            careLedgerEntries: careLedgerEntries,
            careLedgerSnapshotAvailable: true,
            now: now
        )
        let refreshedQuests = todayFocus.refreshedQuests(
            quests,
            pets: pets,
            plants: visiblePlants,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: .current,
            now: now
        )
        let assignedTasks = prioritizedTaskItems(
            TaskCenterSnapshotBuilder.make(
                events: events,
                allEvents: events,
                pets: pets,
                humans: humans,
                plants: visiblePlants,
                humanMedications: humanMedications,
                reminders: reminders,
                familyTasks: familyTasks,
                activeHumanId: activeHumanId,
                now: now
            )
        )
        let pendingExchanges: [CoconutExchangeRequest] = if activeHumanId.isEmpty || !CoconutExchangeFeatureGate.isEnabled {
            []
        } else {
            exchangeRequests
                .filter { $0.status == .pending && $0.receiverId == activeHumanId }
                .sorted { $0.createdAt < $1.createdAt }
        }
        return make(
            pets: pets,
            plants: visiblePlants,
            humans: humans,
            refreshedQuests: refreshedQuests,
            assignedTasks: taskSnapshots(assignedTasks, familyTasks: familyTasks),
            pendingExchanges: pendingExchanges,
            negativeSignals: IslandNegativeFeedback.signals(
                pets: pets,
                plants: visiblePlants,
                healthAlerts: healthAlerts,
                careLedgerEntries: negativeCareLedgerEntries(from: careLedgerEntries)
            ),
            dayToken: dayToken(for: now)
        )
    }

    static func make(
        pets: [Pet],
        plants: [Plant],
        reminders: [Reminder],
        events: [Event],
        humans: [Human],
        humanMedications: [HumanMedication] = [],
        activeHumanId: String,
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        questProgress: TodayFocusQuestProgress,
        clinicalAlerts: [HealthAlert],
        now: Date = Date()
    ) -> TodayFocusSnapshot {
        let visiblePlants = PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel) ? plants : []
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: visiblePlants,
            events: events,
            humans: humans,
            humanMedications: humanMedications,
            careLedgerEntries: careLedgerEntries,
            careLedgerSnapshotAvailable: true,
            now: now,
            questProgress: questProgress
        )
        let refreshedQuests = TodayFocusQuestRefresher().refreshedQuests(
            quests,
            pets: pets,
            plants: visiblePlants,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: .current,
            now: now,
            questProgress: questProgress
        )
        let assignedTasks = prioritizedTaskItems(
            TaskCenterSnapshotBuilder.make(
                events: events,
                allEvents: events,
                pets: pets,
                humans: humans,
                plants: visiblePlants,
                humanMedications: humanMedications,
                reminders: reminders,
                familyTasks: familyTasks,
                activeHumanId: activeHumanId,
                now: now
            )
        )
        let pendingExchanges: [CoconutExchangeRequest] = if activeHumanId.isEmpty || !CoconutExchangeFeatureGate.isEnabled {
            []
        } else {
            exchangeRequests
                .filter { $0.status == .pending && $0.receiverId == activeHumanId }
                .sorted { $0.createdAt < $1.createdAt }
        }
        return make(
            pets: pets,
            plants: visiblePlants,
            humans: humans,
            refreshedQuests: refreshedQuests,
            assignedTasks: taskSnapshots(assignedTasks, familyTasks: familyTasks),
            pendingExchanges: pendingExchanges,
            negativeSignals: IslandNegativeFeedback.signals(
                pets: pets,
                plants: visiblePlants,
                clinicalAlerts: clinicalAlerts,
                careLedgerEntries: negativeCareLedgerEntries(from: careLedgerEntries)
            ),
            dayToken: dayToken(for: now)
        )
    }

    private static func negativeCareLedgerEntries(
        from entries: [TodayFocusCareLedgerEntry]
    ) -> [IslandNegativeCareLedgerEntry] {
        entries.map {
            IslandNegativeCareLedgerEntry(
                petId: $0.petId,
                eventKind: $0.eventKind,
                actionType: $0.actionType,
                date: $0.date,
                amountValue: $0.amountValue
            )
        }
    }

    private static func prioritizedTaskItems(
        _ snapshot: TaskCenterSnapshot
    ) -> [TaskCenterItemSnapshot] {
        let currentMemberIDs = snapshot.memberFilterContext.currentMemberItemIDs
        let canAct: (TaskCenterItemSnapshot) -> Bool = { item in
            guard !item.availableActions.isEmpty else { return false }
            guard snapshot.showsMemberFilters, item.familyTaskID == nil else { return true }
            return item.participantHumanIDs.isEmpty || currentMemberIDs.contains(item.id)
        }
        var seen: Set<String> = []
        var result: [TaskCenterItemSnapshot] = []
        for item in snapshot.overdue + snapshot.today where canAct(item) {
            guard seen.insert(item.id).inserted else { continue }
            result.append(item)
        }
        for item in snapshot.allItems where item.workflowStatus == .pendingReview && canAct(item) {
            guard seen.insert(item.id).inserted else { continue }
            result.append(item)
        }
        return result
    }

    private static func taskSnapshots(
        _ items: [TaskCenterItemSnapshot],
        familyTasks: [FamilyCollaborationTask]
    ) -> [TodayFocusFamilyTaskSnapshot] {
        let familyTasksByID = Dictionary(uniqueKeysWithValues: familyTasks.map { ($0.id, $0) })
        return items.map { item in
            TodayFocusFamilyTaskSnapshot(
                item: item,
                familyTask: item.familyTaskID.flatMap { familyTasksByID[$0] }
            )
        }
    }

    private static func make(
        pets: [Pet],
        plants: [Plant],
        humans: [Human],
        refreshedQuests: [IslandQuest],
        assignedTasks: [TodayFocusFamilyTaskSnapshot],
        pendingExchanges: [CoconutExchangeRequest],
        negativeSignals: [IslandNegativeSignal],
        dayToken: Int
    ) -> TodayFocusSnapshot {
        let visiblePlants = PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel) ? plants : []
        return TodayFocusSnapshot(
            dayToken: dayToken,
            pets: pets.map(TodayFocusPetSnapshot.init),
            plants: visiblePlants.map(TodayFocusPlantSnapshot.init),
            humans: humans.map(TodayFocusHumanSnapshot.init),
            refreshedQuests: refreshedQuests,
            assignedFamilyTasks: assignedTasks,
            pendingExchangeRequests: pendingExchanges.map(TodayFocusExchangeRequestSnapshot.init),
            negativeSignals: negativeSignals
        )
    }
}
