//
//  FeedHomeController.swift
//  Ohana
//
//  View-state controller for the feeding home surface.
//

import Combine
import Foundation
import os
import SwiftUI

struct FeedHomeTaskViewState {
    let manualPlanEvents: [Event]
    let autoFeederEvents: [Event]
    let todayMainFoodGrams: Double
    let todayAutoFeedCount: Int
    let hasNextManualReminder: Bool
    let hasMissedManualPlan: Bool
    let lastExpiredManualPlanDate: Date?
    let todayManualPlanCompletionText: String
    let autoDailyTotalGrams: Double
    let latestAutoFeedDate: Date?
    let nextAutoFeedDate: Date?
}

struct FeedHomeMetricsViewState {
    let todayDryFoodGrams: Double
    let todayWetFoodGrams: Double
    let todayTreatGrams: Double
    let todayTreatCount: Int
    let dryStockRemainingGrams: Double?
    let dryStockRemainingDays: Int?
    let wetStockRemainingGrams: Double?
    let wetStockRemainingDays: Int?
}

struct FeedHomeStockBadgeViewState {
    let remainingDays: Int?
}

enum FeedHomePrimaryActionState: Equatable {
    case openFeedingOverview
    case setupManualAmount
    case manualFeed
    case completeManualPlan
    case openModeHistory
}

struct FeedHomeViewState {
    let mode: FeedOperatingMode
    let task: FeedHomeTaskViewState
    let metrics: FeedHomeMetricsViewState
    let chartPoints: [OhanaMinimalChartPoint]
    let stockBadge: FeedHomeStockBadgeViewState
    let primaryActionState: FeedHomePrimaryActionState
    let isRefreshing: Bool

    static func placeholder(mode: FeedOperatingMode, isRefreshing: Bool = true) -> FeedHomeViewState {
        FeedHomeViewState(
            mode: mode,
            task: FeedHomeTaskViewState(
                manualPlanEvents: [],
                autoFeederEvents: [],
                todayMainFoodGrams: 0,
                todayAutoFeedCount: 0,
                hasNextManualReminder: false,
                hasMissedManualPlan: false,
                lastExpiredManualPlanDate: nil,
                todayManualPlanCompletionText: "0/1",
                autoDailyTotalGrams: 0,
                latestAutoFeedDate: nil,
                nextAutoFeedDate: nil
            ),
            metrics: FeedHomeMetricsViewState(
                todayDryFoodGrams: 0,
                todayWetFoodGrams: 0,
                todayTreatGrams: 0,
                todayTreatCount: 0,
                dryStockRemainingGrams: nil,
                dryStockRemainingDays: nil,
                wetStockRemainingGrams: nil,
                wetStockRemainingDays: nil
            ),
            chartPoints: [],
            stockBadge: FeedHomeStockBadgeViewState(remainingDays: nil),
            primaryActionState: .openFeedingOverview,
            isRefreshing: isRefreshing
        )
    }

    static func make(
        mode: FeedOperatingMode,
        snapshot: QuickFeedHomeSnapshot,
        pet: Pet,
        isRefreshing: Bool
    ) -> FeedHomeViewState {
        let task = FeedHomeTaskViewState(
            manualPlanEvents: snapshot.manualPlanEvents,
            autoFeederEvents: snapshot.autoFeederEvents,
            todayMainFoodGrams: snapshot.todayMainFoodGrams,
            todayAutoFeedCount: snapshot.todayAutoFeedCount,
            hasNextManualReminder: snapshot.hasNextManualReminder,
            hasMissedManualPlan: snapshot.hasMissedManualPlan,
            lastExpiredManualPlanDate: snapshot.lastExpiredManualPlanDate,
            todayManualPlanCompletionText: snapshot.todayManualPlanCompletionText,
            autoDailyTotalGrams: snapshot.autoDailyTotalGrams,
            latestAutoFeedDate: snapshot.latestAutoFeedDate,
            nextAutoFeedDate: snapshot.nextAutoFeedDate
        )
        let metrics = FeedHomeMetricsViewState(
            todayDryFoodGrams: snapshot.todayDryFoodGrams,
            todayWetFoodGrams: snapshot.todayWetFoodGrams,
            todayTreatGrams: snapshot.todayTreatGrams,
            todayTreatCount: snapshot.todayTreatCount,
            dryStockRemainingGrams: snapshot.dryStockRemainingGrams,
            dryStockRemainingDays: snapshot.dryStockRemainingDays,
            wetStockRemainingGrams: snapshot.wetStockRemainingGrams,
            wetStockRemainingDays: snapshot.wetStockRemainingDays
        )
        return FeedHomeViewState(
            mode: mode,
            task: task,
            metrics: metrics,
            chartPoints: snapshot.guidedSevenDayMainFoodPoints,
            stockBadge: FeedHomeStockBadgeViewState(remainingDays: snapshot.stockCardRemainingDays),
            primaryActionState: primaryActionState(mode: mode, snapshot: snapshot, pet: pet),
            isRefreshing: isRefreshing
        )
    }

    func replacingMode(_ mode: FeedOperatingMode, pet: Pet) -> FeedHomeViewState {
        FeedHomeViewState(
            mode: mode,
            task: task,
            metrics: metrics,
            chartPoints: chartPoints,
            stockBadge: stockBadge,
            primaryActionState: FeedHomeViewState.primaryActionState(mode: mode, task: task, pet: pet),
            isRefreshing: isRefreshing
        )
    }

    private static func primaryActionState(
        mode: FeedOperatingMode,
        snapshot: QuickFeedHomeSnapshot,
        pet: Pet
    ) -> FeedHomePrimaryActionState {
        let task = FeedHomeTaskViewState(
            manualPlanEvents: snapshot.manualPlanEvents,
            autoFeederEvents: snapshot.autoFeederEvents,
            todayMainFoodGrams: snapshot.todayMainFoodGrams,
            todayAutoFeedCount: snapshot.todayAutoFeedCount,
            hasNextManualReminder: snapshot.hasNextManualReminder,
            hasMissedManualPlan: snapshot.hasMissedManualPlan,
            lastExpiredManualPlanDate: snapshot.lastExpiredManualPlanDate,
            todayManualPlanCompletionText: snapshot.todayManualPlanCompletionText,
            autoDailyTotalGrams: snapshot.autoDailyTotalGrams,
            latestAutoFeedDate: snapshot.latestAutoFeedDate,
            nextAutoFeedDate: snapshot.nextAutoFeedDate
        )
        return primaryActionState(mode: mode, task: task, pet: pet)
    }

    private static func primaryActionState(
        mode: FeedOperatingMode,
        task: FeedHomeTaskViewState,
        pet: Pet
    ) -> FeedHomePrimaryActionState {
        guard !pet.hasPassedAway else { return .openFeedingOverview }
        switch mode {
        case .manual:
            return pet.dailyPortionGrams > 0 ? .manualFeed : .setupManualAmount
        case .manualReminder:
            return task.hasNextManualReminder ? .completeManualPlan : .openModeHistory
        case .autoFeeder:
            return .openModeHistory
        }
    }
}

struct FeedHomeSnapshotRevision: Equatable {
    let careLogRevision: Int
    let feedingLedgerRevision: Int?
    let foodRecordRevision: Int
    let sharedSessionRevision: Int
    let eventRevision: Int
    let modeRevision: Int
    let petRevision: Int
    let timeRevision: Int

    static func make(
        pet: Pet,
        events: [Event],
        careLogs: [PetCareLog],
        feedingLedgerEntries: [QuickFeedLedgerEntry]?,
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession],
        mode: FeedOperatingMode,
        now: Date
    ) -> FeedHomeSnapshotRevision {
        FeedHomeSnapshotRevision(
            careLogRevision: hashCareLogs(careLogs),
            feedingLedgerRevision: hashFeedingLedgerEntries(feedingLedgerEntries),
            foodRecordRevision: hashFoodRecords(foodRecords),
            sharedSessionRevision: hashSharedSessions(sharedCareSessions),
            eventRevision: hashEvents(events),
            modeRevision: mode.rawValue.hashValue,
            petRevision: hashPetSettings(pet),
            timeRevision: Int(now.timeIntervalSince1970 / 60)
        )
    }

    private static func hashCareLogs(_ logs: [PetCareLog]) -> Int {
        hash { hasher in
            hasher.combine(logs.count)
            for log in logs.prefix(90) {
                hasher.combine(log.id)
                hasher.combine(log.date.timeIntervalSince1970)
                hasher.combine(log.type)
                hasher.combine(log.amountGrams)
                hasher.combine(log.foodKindRaw)
                hasher.combine(log.treatKindRaw)
                hasher.combine(log.note)
            }
        }
    }

    private static func hashFeedingLedgerEntries(_ entries: [QuickFeedLedgerEntry]?) -> Int? {
        guard let entries else { return nil }
        return hash { hasher in
            hasher.combine(entries.count)
            for entry in entries.prefix(180) {
                hasher.combine(entry.id)
                hasher.combine(entry.petId)
                hasher.combine(entry.date.timeIntervalSince1970)
                hasher.combine(entry.amountGrams)
                hasher.combine(entry.source.rawValue)
                hasher.combine(entry.foodKind.rawValue)
                hasher.combine(entry.treatKind?.rawValue)
                hasher.combine(entry.legacyModelId)
                hasher.combine(entry.sharedSessionId)
                hasher.combine(entry.sourceEventId)
                hasher.combine(entry.sourceReminderId)
            }
        }
    }

    private static func hashFoodRecords(_ records: [PetFoodRecord]) -> Int {
        hash { hasher in
            hasher.combine(records.count)
            for record in records.prefix(40) {
                hasher.combine(record.id)
                hasher.combine(record.startDate.timeIntervalSince1970)
                hasher.combine(record.purchaseDate?.timeIntervalSince1970 ?? 0)
                hasher.combine(record.totalGrams)
                hasher.combine(record.dailyGrams)
                hasher.combine(record.foodKindRaw)
                hasher.combine(record.notes)
                hasher.combine(record.remainingCorrectionGrams ?? -1)
                hasher.combine(record.remainingCorrectionDate?.timeIntervalSince1970 ?? 0)
            }
        }
    }

    private static func hashSharedSessions(_ sessions: [SharedCareSession]) -> Int {
        hash { hasher in
            hasher.combine(sessions.count)
            for session in sessions.prefix(90) {
                hasher.combine(session.id)
                hasher.combine(session.date.timeIntervalSince1970)
                hasher.combine(session.actionKindRaw)
                hasher.combine(session.stockOwnerPetId)
                hasher.combine(session.totalAmountGrams)
            }
        }
    }

    private static func hashEvents(_ events: [Event]) -> Int {
        hash { hasher in
            hasher.combine(events.count)
            for event in events.prefix(40) {
                hasher.combine(event.id)
                hasher.combine(event.startDate.timeIntervalSince1970)
                hasher.combine(event.recurrenceDays)
                hasher.combine(event.recurrenceEndDate?.timeIntervalSince1970 ?? 0)
                hasher.combine(event.feedRuleKindRaw)
                hasher.combine(event.foodKindRaw)
                hasher.combine(event.feedAmountGrams)
                hasher.combine(event.reminders.count)
                for reminder in event.reminders.prefix(30) {
                    hasher.combine(reminder.id)
                    hasher.combine(reminder.scheduledAt.timeIntervalSince1970)
                    hasher.combine(reminder.status)
                    hasher.combine(reminder.completedAt?.timeIntervalSince1970 ?? 0)
                }
            }
        }
    }

    private static func hashPetSettings(_ pet: Pet) -> Int {
        hash { hasher in
            hasher.combine(pet.id)
            hasher.combine(pet.hasPassedAway)
            hasher.combine(pet.dailyPortionGrams)
            hasher.combine(pet.mainFoodKind.rawValue)
            hasher.combine(pet.foodReminderEnabled)
            hasher.combine(pet.foodReminderAdvanceDays)
        }
    }

    private static func hash(_ body: (inout Hasher) -> Void) -> Int {
        var hasher = Hasher()
        body(&hasher)
        return hasher.finalize()
    }
}

enum FeedHomePerformance {
    private static let logger = Logger(subsystem: "Ohana", category: "FeedHome")

    @discardableResult
    static func measure<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let result = try body()
        let elapsed = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
        logger.debug("\(name, privacy: .private) \(String(format: "%.1f", elapsed), privacy: .public)ms")
        return result
    }

    static func mark(_ name: String) {
        logger.debug("\(name, privacy: .private)")
    }
}

@MainActor
final class FeedHomeController: ObservableObject {
    @Published private(set) var displayedMode: FeedOperatingMode
    @Published private(set) var renderSnapshot: QuickFeedHomeSnapshot?
    @Published private(set) var viewState: FeedHomeViewState
    @Published private(set) var modeTransition: FeedModeTransitionRenderState?
    @Published private(set) var isAuxiliaryReady = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var pendingModeCommit: FeedOperatingMode?
    @Published private(set) var lastComputedRevision: FeedHomeSnapshotRevision?

    init(initialMode: FeedOperatingMode) {
        self.displayedMode = initialMode
        self.viewState = FeedHomeViewState.placeholder(mode: initialMode)
    }

    var renderViewState: FeedHomeViewState {
        modeTransition?.viewState ?? viewState
    }

    func setAuxiliaryReady(_ isReady: Bool, animated: Bool = false) {
        guard isAuxiliaryReady != isReady else { return }
        if animated {
            withAnimation(GoMotion.quick) {
                isAuxiliaryReady = isReady
            }
        } else {
            isAuxiliaryReady = isReady
        }
    }

    func syncDisplayedMode(_ resolvedMode: FeedOperatingMode, pet: Pet, animated: Bool = false, force: Bool = false) {
        guard force || modeTransition == nil else { return }
        guard displayedMode != resolvedMode else { return }
        displayedMode = resolvedMode
        let nextState = viewState.replacingMode(resolvedMode, pet: pet)
        if animated {
            withAnimation(GoMotion.quick) {
                viewState = nextState
            }
        } else {
            viewState = nextState
        }
    }

    func rebuild(input: FeedHomeSnapshotInput, mode: FeedOperatingMode? = nil, force: Bool = false) {
        let targetMode = mode ?? displayedMode
        let revision = FeedHomeSnapshotRevision.make(
            pet: input.pet,
            events: input.allEvents,
            careLogs: input.careLogs,
            feedingLedgerEntries: input.feedingLedgerEntries,
            foodRecords: input.foodRecords,
            sharedCareSessions: input.sharedCareSessions,
            mode: targetMode,
            now: input.now
        )
        guard force || revision != lastComputedRevision || renderSnapshot == nil else { return }

        isRefreshing = true
        let snapshot = FeedHomePerformance.measure("snapshot.build") {
            FeedHomeSnapshotBuilder.build(input: input)
        }
        renderSnapshot = snapshot
        lastComputedRevision = revision
        isRefreshing = false
        guard modeTransition == nil || force else { return }
        viewState = FeedHomeViewState.make(
            mode: targetMode,
            snapshot: snapshot,
            pet: input.pet,
            isRefreshing: false
        )
    }

    func setModeImmediately(_ mode: FeedOperatingMode, pet: Pet) {
        displayedMode = mode
        viewState = viewState.replacingMode(mode, pet: pet)
    }

    func beginOptimisticModeTransition(to targetMode: FeedOperatingMode, pet: Pet) -> UUID? {
        let fromMode = displayedMode
        guard fromMode != targetMode else { return nil }
        let frozenState = viewState
        let transition = FeedModeTransitionRenderState(
            id: UUID(),
            fromMode: fromMode,
            toMode: targetMode,
            progress: 0,
            viewState: frozenState
        )
        FeedHomePerformance.mark("mode.optimistic \(fromMode.rawValue)->\(targetMode.rawValue)")
        displayedMode = targetMode
        pendingModeCommit = targetMode
        modeTransition = transition
        viewState = frozenState.replacingMode(targetMode, pet: pet)
        return transition.id
    }

    func updateModeTransition(id: UUID, progress: CGFloat) {
        guard modeTransition?.id == id else { return }
        modeTransition?.progress = progress
    }

    func finishModeTransition(id: UUID) {
        guard modeTransition?.id == id else { return }
        modeTransition = nil
        pendingModeCommit = nil
    }

    func cancelModeTransition() {
        modeTransition = nil
        pendingModeCommit = nil
    }

    func cancel() {
        cancelModeTransition()
    }
}
