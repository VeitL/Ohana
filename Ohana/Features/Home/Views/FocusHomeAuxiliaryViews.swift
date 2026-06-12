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
        activeHumanId: String,
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        todayFocus: TodayFocusManaging,
        healthAlerts: PetHealthAlerting,
        now: Date = Date()
    ) -> TodayFocusSnapshot {
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: plants,
            events: events,
            humans: humans,
            careLedgerEntries: careLedgerEntries,
            now: now
        )
        let refreshedQuests = todayFocus.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: .current,
            now: now
        )
        let assignedTasks: [FamilyCollaborationTask] = if activeHumanId.isEmpty {
            []
        } else {
            familyTasks
                .filter {
                    !$0.isFinished &&
                        (($0.status == .pendingReview && $0.createdById == activeHumanId) ||
                            ($0.status != .pendingReview && ($0.assignedToId == activeHumanId || $0.claimedById == activeHumanId)))
                }
                .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
        }
        let pendingExchanges: [CoconutExchangeRequest] = if activeHumanId.isEmpty || !CoconutExchangeFeatureGate.isEnabled {
            []
        } else {
            exchangeRequests
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
        activeHumanId: String,
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        questProgress: TodayFocusQuestProgress,
        clinicalAlerts: [HealthAlert],
        now: Date = Date()
    ) -> TodayFocusSnapshot {
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: plants,
            events: events,
            humans: humans,
            careLedgerEntries: careLedgerEntries,
            now: now,
            questProgress: questProgress
        )
        let refreshedQuests = TodayFocusQuestRefresher().refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: .current,
            now: now,
            questProgress: questProgress
        )
        let assignedTasks: [FamilyCollaborationTask] = if activeHumanId.isEmpty {
            []
        } else {
            familyTasks
                .filter {
                    !$0.isFinished &&
                        (($0.status == .pendingReview && $0.createdById == activeHumanId) ||
                            ($0.status != .pendingReview && ($0.assignedToId == activeHumanId || $0.claimedById == activeHumanId)))
                }
                .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
        }
        let pendingExchanges: [CoconutExchangeRequest] = if activeHumanId.isEmpty || !CoconutExchangeFeatureGate.isEnabled {
            []
        } else {
            exchangeRequests
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
            ),
            dayToken: dayToken(for: now)
        )
    }

    private static func make(
        pets: [Pet],
        plants: [Plant],
        humans: [Human],
        refreshedQuests: [IslandQuest],
        assignedTasks: [FamilyCollaborationTask],
        pendingExchanges: [CoconutExchangeRequest],
        negativeSignals: [IslandNegativeSignal],
        dayToken: Int
    ) -> TodayFocusSnapshot {
        TodayFocusSnapshot(
            dayToken: dayToken,
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
