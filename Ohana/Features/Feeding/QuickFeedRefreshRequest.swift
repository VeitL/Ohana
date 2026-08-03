//
//  QuickFeedRefreshRequest.swift
//  Ohana
//
//  Coalesced refresh flags for the feeding sheet's route-scoped read models.
//

import Combine
import Foundation
import SwiftData

nonisolated enum QuickFeedModelReadability {
    nonisolated static func isReadable<Model: PersistentModel>(_ model: Model) -> Bool {
        guard !model.isDeleted else { return false }
        return model.modelContext != nil || model.persistentModelID.storeIdentifier == nil
    }

    nonisolated static func readableEvents(_ events: [Event]) -> [Event] {
        events.filter(isReadable)
    }
}

struct QuickFeedRouteReminderSignature: Equatable {
    let id: UUID
    let occurrenceAt: Date?
    let scheduledAt: Date
    let status: String
    let completedAt: Date?
    let completedBy: String
    let notificationId: String
    let createdAt: Date

    init(_ reminder: Reminder) {
        id = reminder.id
        occurrenceAt = reminder.occurrenceAt
        scheduledAt = reminder.scheduledAt
        status = reminder.status
        completedAt = reminder.completedAt
        completedBy = reminder.completedBy
        notificationId = reminder.notificationId
        createdAt = reminder.createdAt
    }
}

struct QuickFeedRouteEventSignature: Equatable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let eventType: String
    let relatedEntityType: String
    let relatedEntityId: String
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let createdAt: Date
    let assigneeId: String?
    let feedRuleKindRaw: String
    let foodKindRaw: String
    let feedAmountGrams: Double
    let feedPlanGroupId: String
    let reminders: [QuickFeedRouteReminderSignature]

    @MainActor
    init(_ event: Event) {
        id = event.id
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        eventType = event.eventType
        relatedEntityType = event.relatedEntityType
        relatedEntityId = event.relatedEntityId
        recurrenceDays = event.recurrenceDays
        recurrenceEndDate = event.recurrenceEndDate
        createdAt = event.createdAt
        assigneeId = event.assigneeId
        feedRuleKindRaw = event.feedRuleKindRaw
        foodKindRaw = event.foodKindRaw
        feedAmountGrams = FeedRuleMetadata.amountGrams(from: event)
        feedPlanGroupId = event.feedPlanGroupId
        let liveReminders = event.reminders.filter(QuickFeedModelReadability.isReadable)
        var reminderSignatures: [QuickFeedRouteReminderSignature] = []
        reminderSignatures.reserveCapacity(liveReminders.count)
        for reminder in liveReminders {
            reminderSignatures.append(QuickFeedRouteReminderSignature(reminder))
        }
        reminders = reminderSignatures.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    var petID: UUID? {
        let link = DomainEntityLink(rawType: relatedEntityType, rawId: relatedEntityId)
        let role = DomainEntityLinkRegistry.role(for: link)
        return DomainEntityLinkRegistry.affectedEntityId(for: link, role: role)
    }

    var ruleKind: FeedRuleKind? {
        FeedRuleMetadata.ruleKind(
            eventType: eventType,
            link: DomainEntityLink(rawType: relatedEntityType, rawId: relatedEntityId),
            feedRuleKindRaw: feedRuleKindRaw,
            title: title
        )
    }

    var foodKind: FeedFoodKind {
        FeedFoodKind(rawValue: foodKindRaw) ?? .dry
    }

    func matches(petID: UUID, kind: FeedRuleKind) -> Bool {
        self.petID == petID && ruleKind == kind
    }
}

struct QuickFeedRouteRevision: Equatable {
    let events: [QuickFeedRouteEventSignature]

    @MainActor
    init(events: [Event]) {
        self.events = events
            .filter(QuickFeedModelReadability.isReadable)
            .filter(FeedRuleMetadata.isFeedRuleEvent)
            .map(QuickFeedRouteEventSignature.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

private struct QuickFeedRuleEventReceipt: Equatable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let eventType: String
    let relatedEntityType: String
    let relatedEntityId: String
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let createdAt: Date
    let assigneeId: String?
    let feedRuleKindRaw: String
    let foodKindRaw: String
    let feedAmountGrams: Double
    let feedPlanGroupId: String
    let reminderIDs: [UUID]

    init(_ event: QuickFeedRouteEventSignature) {
        id = event.id
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        eventType = event.eventType
        relatedEntityType = event.relatedEntityType
        relatedEntityId = event.relatedEntityId
        recurrenceDays = event.recurrenceDays
        recurrenceEndDate = event.recurrenceEndDate
        createdAt = event.createdAt
        assigneeId = event.assigneeId
        feedRuleKindRaw = event.feedRuleKindRaw
        foodKindRaw = event.foodKindRaw
        feedAmountGrams = event.feedAmountGrams
        feedPlanGroupId = event.feedPlanGroupId
        reminderIDs = event.reminders
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }
    }
}

private struct QuickFeedRuleWriteOverride {
    let affectedPetIDs: Set<UUID>
    let authoritativeRuleSnapshots: [QuickFeedRouteEventSignature]
    let expectedModes: [UUID: FeedOperatingMode]
    let receipt: [QuickFeedRuleEventReceipt]

    @MainActor
    init(
        affectedPetIDs: Set<UUID>,
        authoritativeRuleSnapshots: [QuickFeedRouteEventSignature],
        expectedModes: [UUID: FeedOperatingMode]
    ) {
        self.affectedPetIDs = affectedPetIDs
        self.authoritativeRuleSnapshots = authoritativeRuleSnapshots
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.startDate < rhs.startDate
            }
        self.expectedModes = expectedModes
        receipt = Self.receipt(for: authoritativeRuleSnapshots, affectedPetIDs: affectedPetIDs)
    }

    @MainActor
    func mergingRuleSnapshots(routeEvents: [Event]) -> [QuickFeedRouteEventSignature] {
        let unrelatedRuleSnapshots = routeEvents
            .filter(QuickFeedModelReadability.isReadable)
            .filter(FeedRuleMetadata.isFeedRuleEvent)
            .map(QuickFeedRouteEventSignature.init)
            .filter { snapshot in
                snapshot.petID.map(affectedPetIDs.contains) != true
            }
        return (unrelatedRuleSnapshots + authoritativeRuleSnapshots).sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.startDate < rhs.startDate
        }
    }

    @MainActor
    func isAcknowledged(by routeEvents: [Event]) -> Bool {
        Self.receipt(for: routeEvents, affectedPetIDs: affectedPetIDs) == receipt
    }

    @MainActor
    private static func receipt(
        for events: [Event],
        affectedPetIDs: Set<UUID>
    ) -> [QuickFeedRuleEventReceipt] {
        let snapshots = events
            .filter(QuickFeedModelReadability.isReadable)
            .filter { FeedRuleMetadata.isFeedRuleEvent($0, petIDs: affectedPetIDs) }
            .map(QuickFeedRouteEventSignature.init)
        return receipt(for: snapshots, affectedPetIDs: affectedPetIDs)
    }

    @MainActor
    private static func receipt(
        for snapshots: [QuickFeedRouteEventSignature],
        affectedPetIDs: Set<UUID>
    ) -> [QuickFeedRuleEventReceipt] {
        snapshots
            .filter { snapshot in
                snapshot.petID.map(affectedPetIDs.contains) == true
            }
            .map(QuickFeedRuleEventReceipt.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

struct QuickFeedRefreshRequest: OptionSet {
    let rawValue: Int

    static let reloadFullCareLogsIfLoaded = QuickFeedRefreshRequest(rawValue: 1 << 0)
    static let reloadFullFoodRecordsIfLoaded = QuickFeedRefreshRequest(rawValue: 1 << 1)
    static let reloadSnapshots = QuickFeedRefreshRequest(rawValue: 1 << 2)
    static let refreshFeedHomeSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 3)
    static let forceFeedHomeSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 4)
    static let refreshOverviewSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 5)
    static let forceOverviewSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 6)
    static let syncDisplayedMode = QuickFeedRefreshRequest(rawValue: 1 << 7)
    static let forceDisplayedMode = QuickFeedRefreshRequest(rawValue: 1 << 8)
    static let ensurePlanReminders = QuickFeedRefreshRequest(rawValue: 1 << 9)
    static let refreshPlanCalendarSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 10)
    static let forcePlanCalendarSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 11)
    static let refreshTreatSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 12)
    static let forceTreatSnapshot = QuickFeedRefreshRequest(rawValue: 1 << 13)
}

@MainActor
final class QuickFeedRuntimeState: ObservableObject {
    @Published var clockTick = Date()
    @Published var overviewChartProgress: Double = 1

    var feedDetailDataTask: Task<Void, Never>?
    var didApplyInitialSheet = false
    var didScheduleBootstrapMaintenance = false
    var feedModeTransitionTask: Task<Void, Never>?
    var feedModeMaintenanceTask: Task<Void, Never>?
    var feedRefreshTask: Task<Void, Never>?
    var feedPlanSaveTask: Task<Void, Never>?
    var feedPlanReminderSchedulingTask: Task<Void, Never>?
    var feedStockReminderSchedulingTask: Task<Void, Never>?
    var pendingFeedRefreshRequest = QuickFeedRefreshRequest()
    private var pendingRuleWrite: QuickFeedRuleWriteOverride?
    var lastFeedClockMinute = -1

    var hasPendingRuleWrite: Bool {
        pendingRuleWrite != nil
    }

    var pendingRuleWritePetIDs: Set<UUID> {
        pendingRuleWrite?.affectedPetIDs ?? []
    }

    func ruleSnapshotsMergingPendingWrite(with routeEvents: [Event]) -> [QuickFeedRouteEventSignature] {
        let liveRouteEvents = routeEvents.filter(QuickFeedModelReadability.isReadable)
        if let pendingRuleWrite {
            return pendingRuleWrite.mergingRuleSnapshots(routeEvents: liveRouteEvents)
        }
        return liveRouteEvents
            .filter(FeedRuleMetadata.isFeedRuleEvent)
            .map(QuickFeedRouteEventSignature.init)
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.startDate < rhs.startDate
            }
    }

    func expectedModeDuringPendingRuleWrite(for petID: UUID) -> FeedOperatingMode? {
        pendingRuleWrite?.expectedModes[petID]
    }

    func installSuccessfulRuleWrite(
        events: [Event],
        affectedPetIDs: Set<UUID>,
        mode: FeedOperatingMode
    ) {
        guard !affectedPetIDs.isEmpty else { return }

        let previousPetIDs = pendingRuleWrite?.affectedPetIDs ?? []
        let preservedPetIDs = previousPetIDs.subtracting(affectedPetIDs)
        let newRuleSnapshots = events
            .filter(QuickFeedModelReadability.isReadable)
            .filter { FeedRuleMetadata.isFeedRuleEvent($0, petIDs: affectedPetIDs) }
            .map(QuickFeedRouteEventSignature.init)
        let preservedRuleSnapshots = pendingRuleWrite?.authoritativeRuleSnapshots.filter { snapshot in
            snapshot.petID.map(preservedPetIDs.contains) == true
        } ?? []

        var expectedModes = pendingRuleWrite?.expectedModes ?? [:]
        for petID in affectedPetIDs {
            expectedModes[petID] = mode
        }
        let combinedPetIDs = previousPetIDs.union(affectedPetIDs)
        pendingRuleWrite = QuickFeedRuleWriteOverride(
            affectedPetIDs: combinedPetIDs,
            authoritativeRuleSnapshots: preservedRuleSnapshots + newRuleSnapshots,
            expectedModes: expectedModes
        )
    }

    @discardableResult
    func acknowledgePendingRuleWriteIfRouteCaughtUp(with routeEvents: [Event]) -> Bool {
        guard let pendingRuleWrite else { return true }
        guard pendingRuleWrite.isAcknowledged(by: routeEvents) else { return false }
        self.pendingRuleWrite = nil
        return true
    }

    func resetPendingFeedRefresh() {
        feedRefreshTask?.cancel()
        feedRefreshTask = nil
        pendingFeedRefreshRequest = QuickFeedRefreshRequest()
    }

    func cancelTasks() {
        feedModeTransitionTask?.cancel()
        feedModeMaintenanceTask?.cancel()
        feedDetailDataTask?.cancel()
        resetPendingFeedRefresh()
        feedPlanSaveTask?.cancel()
        feedPlanReminderSchedulingTask?.cancel()
        feedStockReminderSchedulingTask?.cancel()

        feedModeTransitionTask = nil
        feedModeMaintenanceTask = nil
        feedDetailDataTask = nil
        feedPlanSaveTask = nil
        feedPlanReminderSchedulingTask = nil
        feedStockReminderSchedulingTask = nil
    }
}
