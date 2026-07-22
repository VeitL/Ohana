//
//  PresenceCheckInCommandService.swift
//  Ohana
//
//  The single persistent write boundary for Zen presence facts and rewards.
//

import Foundation
import SwiftData

nonisolated protocol PresenceOwnerSelecting {
    var ownerHumanId: UUID? { get }
}

nonisolated protocol PresenceOwnerUpdating: PresenceOwnerSelecting {
    func setOwnerHumanId(_ id: UUID?)
}

final nonisolated class UserDefaultsPresenceOwnerSelection: PresenceOwnerUpdating {
    static let ownerKey = AppExperienceMode.zenOwnerHumanIDKey

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var ownerHumanId: UUID? {
        defaults.string(forKey: Self.ownerKey).flatMap(UUID.init(uuidString:))
    }

    func setOwnerHumanId(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: Self.ownerKey)
        } else {
            defaults.removeObject(forKey: Self.ownerKey)
        }
    }
}

nonisolated struct PresenceCheckInFactSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let subject: PresenceSubjectRef
    let dayKey: String
    let status: PresenceStatus?
    let source: PresenceCheckInSource
    let checkedInAt: Date
    let isOwner: Bool
}

nonisolated struct PresenceRewardOutcome: Equatable, Sendable {
    let kind: PresenceRewardKind
    let requestedAmount: Int
    let awardedAmount: Int
    let milestoneDays: Int
}

nonisolated struct PresenceCheckInCommandResult: Equatable, Sendable {
    let checkIns: [PresenceCheckInFactSnapshot]
    let rewards: [PresenceRewardOutcome]
    let didCreateCheckIn: Bool
    let didChangeStatus: Bool

    var awardedCoconuts: Int { rewards.reduce(0) { $0 + $1.awardedAmount } }
}

/// Undo intentionally removes only today's presence fact. Any coconut already
/// earned remains represented by its durable receipt, so checking in again on
/// the same natural day can never award the same reward twice.
nonisolated struct PresenceUndoCheckInResult: Equatable, Sendable {
    let removedCheckIn: PresenceCheckInFactSnapshot
}

/// A remembered score for a past missed day. It intentionally has no reward
/// payload because this command never enters the economy pipeline.
nonisolated struct PresenceRetrospectiveStatusResult: Equatable, Sendable {
    let fact: PresenceCheckInFactSnapshot
    let didCreate: Bool
    let didChangeStatus: Bool
}

nonisolated struct PresenceParticipationSnapshot: Equatable, Sendable {
    let id: UUID
    let ownerHumanId: UUID
    let startedAt: Date
    let endedAt: Date?
    let startedDayKey: String
    let lastParticipatingDayKey: String?
}

nonisolated enum PresenceCheckInCommandError: LocalizedError, Equatable, Sendable {
    case missingOwner
    case inactiveOwner
    case notParticipating
    case missingSubject(PresenceSubjectRef)
    case inactiveSubject(PresenceSubjectRef)
    case missingTodayCheckIn(PresenceSubjectRef)
    case invalidHistoricalDay
    case historicalDayMustBePast
    case historicalDayNotParticipating
    case subjectNotActiveOnHistoricalDay(PresenceSubjectRef)
    case historicalDayAlreadyCheckedIn(PresenceSubjectRef)
    case rewardPersistenceFailed(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingOwner:
            "Choose who represents you before checking in."
        case .inactiveOwner:
            "The selected owner is no longer active."
        case .notParticipating:
            "Zen mode is not currently active."
        case .missingSubject:
            "The selected check-in card no longer exists."
        case .inactiveSubject:
            "Memorial or archived cards cannot be checked in."
        case .missingTodayCheckIn:
            "Check in this card before choosing today's status."
        case .invalidHistoricalDay:
            "The selected calendar day is invalid."
        case .historicalDayMustBePast:
            "Only a past missed day can receive a remembered status."
        case .historicalDayNotParticipating:
            "Statuses can only be remembered for days that participated in Zen mode."
        case .subjectNotActiveOnHistoricalDay:
            "This card was not active on the selected day."
        case .historicalDayAlreadyCheckedIn:
            "This day already has a real check-in."
        case let .rewardPersistenceFailed(message), let .persistenceFailed(message):
            message
        }
    }
}

nonisolated struct PresenceRewardRequest: Equatable, Sendable {
    let receiptKey: String
    let kind: PresenceRewardKind
    let requestedAmount: Int
    let dayKey: String?
    let milestoneDays: Int
    let relatedCheckInId: UUID?
    let isBudgeted: Bool
}

struct PresenceStagedReward {
    let request: PresenceRewardRequest
    let awardedAmount: Int
    let walletTransactionKey: String?
    let budgetResult: EconomyRewardResult?
}

@MainActor
protocol PresenceRewardAwarding {
    func stage(
        _ request: PresenceRewardRequest,
        owner: Human,
        context: ModelContext,
        now: Date
    ) throws -> PresenceStagedReward

    func didCommit(_ rewards: [PresenceStagedReward], owner: Human, context: ModelContext, now: Date)
    func didRollback(context: ModelContext)
}

@MainActor
final class PresenceEconomyRewardAdapter: PresenceRewardAwarding {
    private let wallet: CoconutWalletManaging
    private weak var projectionManager: CoconutProjectionManaging?
    private var hasStagedLegacyWalletBootstrap = false

    init(
        wallet: CoconutWalletManaging? = nil,
        projectionManager: CoconutProjectionManaging? = nil
    ) {
        self.wallet = wallet ?? SwiftDataCoconutWalletManager()
        self.projectionManager = projectionManager
    }

    func stage(
        _ request: PresenceRewardRequest,
        owner: Human,
        context: ModelContext,
        now: Date
    ) throws -> PresenceStagedReward {
        if !hasStagedLegacyWalletBootstrap {
            try wallet.stageLegacyBootstrapIfNeeded(context: context)
            hasStagedLegacyWalletBootstrap = true
        }
        guard EconomyWalletWritePolicy.canWrite(owner) else {
            throw PresenceCheckInCommandError.inactiveOwner
        }
        let awardedAmount: Int
        let budgetResult: EconomyRewardResult?
        if request.isBudgeted {
            let snapshot = EconomyDailyBudgetStore.snapshot(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: owner.id.uuidString,
                careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
                date: now,
                context: context
            )
            awardedAmount = min(max(0, request.requestedAmount), snapshot.remainingFatigueCoconuts)
            let stage: EconomyBudgetStage = if awardedAmount == 0 {
                .recordOnly
            } else if awardedAmount < request.requestedAmount || snapshot.budgetStage != .normal {
                .fatigue
            } else {
                .normal
            }
            let result = EconomyRewardResult(
                growthXP: 0,
                humanCoconuts: awardedAmount,
                petCoconuts: 0,
                bonusCoconuts: 0,
                luckyCoconuts: 0,
                budgetMultiplier: stage == .normal ? 1 : 0.5,
                budgetStage: stage,
                reason: stage.reason,
                actionKey: "presence_\(request.kind.rawValue)",
                isOnCooldown: false,
                baseGrowthXP: 0,
                baseCoconuts: awardedAmount,
                luck: .none
            )
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: owner.id.uuidString,
                date: now,
                context: context,
                save: false,
                writeDefaults: false
            )
            budgetResult = result
        } else {
            awardedAmount = max(0, request.requestedAmount)
            budgetResult = nil
        }

        let transactionKey = awardedAmount > 0 ? "presence:\(request.receiptKey)" : nil
        if let transactionKey {
            let title = rewardTitle(for: request)
            let delta = CoconutWalletDelta.human(
                owner,
                delta: awardedAmount,
                entryKind: .reward,
                source: .service,
                title: title,
                emoji: request.kind == .streakMilestone ? "🔥" : "🥥",
                actorId: owner.id.uuidString,
                actorName: owner.name,
                subjectKind: request.kind == .streakMilestone ? .household : .human,
                subjectId: owner.id.uuidString,
                sourceModelName: "PresenceRewardReceipt",
                sourceModelId: request.receiptKey,
                metadataJSON: budgetResult?.metadataJSON ?? "{\"presenceReward\":\"\(request.kind.rawValue)\"}",
                occurredAt: now,
                transactionKey: transactionKey
            )
            _ = try wallet.apply(
                deltas: [delta],
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: false,
                projectionManager: nil
            )
        }
        return PresenceStagedReward(
            request: request,
            awardedAmount: awardedAmount,
            walletTransactionKey: transactionKey,
            budgetResult: budgetResult
        )
    }

    func didCommit(_ rewards: [PresenceStagedReward], owner: Human, context: ModelContext, now: Date) {
        for reward in rewards {
            guard let result = reward.budgetResult else { continue }
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: owner.id.uuidString,
                date: now,
                context: nil,
                save: false,
                writeDefaults: true
            )
        }
        wallet.refreshQuestProjection(context: context, manager: projectionManager)
    }

    func didRollback(context _: ModelContext) {
        hasStagedLegacyWalletBootstrap = false
    }

    private func rewardTitle(for request: PresenceRewardRequest) -> String {
        switch request.kind {
        case .ownerDaily:
            "每日平安打卡"
        case .dailyStatus:
            "记录今日状态"
        case .allComplete:
            "全员今日已打卡"
        case .streakMilestone:
            "连续打卡 \(request.milestoneDays) 天"
        }
    }
}

@MainActor
final class PresenceCheckInCommandService {
    static let milestoneRewards: [(days: Int, amount: Int)] = [
        (3, 3), (7, 10), (14, 25), (30, 60), (60, 150), (100, 300), (365, 1000)
    ]

    private let context: ModelContext
    private let ownerSelection: PresenceOwnerSelecting
    private let rewardAwarder: PresenceRewardAwarding
    private let guardianSafetyOutbox: GuardianSafetyOutboxStaging
    private let timeZoneProvider: () -> TimeZone
    private let migratesLegacyBeforeCommands: Bool

    init(
        context: ModelContext,
        ownerSelection: PresenceOwnerSelecting = UserDefaultsPresenceOwnerSelection(),
        rewardAwarder: PresenceRewardAwarding? = nil,
        wallet: CoconutWalletManaging? = nil,
        projectionManager: CoconutProjectionManaging? = nil,
        guardianSafetyOutbox: GuardianSafetyOutboxStaging? = nil,
        migratesLegacyBeforeCommands: Bool = true,
        timeZoneProvider: @escaping () -> TimeZone = { .current }
    ) {
        self.context = context
        self.ownerSelection = ownerSelection
        self.rewardAwarder = rewardAwarder ?? PresenceEconomyRewardAdapter(
            wallet: wallet,
            projectionManager: projectionManager
        )
        self.guardianSafetyOutbox = guardianSafetyOutbox ?? LiveGuardianSafetyOutboxStager()
        self.migratesLegacyBeforeCommands = migratesLegacyBeforeCommands
        self.timeZoneProvider = timeZoneProvider
    }

    @discardableResult
    func startParticipation(
        ownerHumanId: UUID,
        source: PresenceParticipationSource,
        now: Date = Date()
    ) throws -> PresenceParticipationSnapshot {
        guard try activeHuman(id: ownerHumanId) != nil else {
            throw PresenceCheckInCommandError.inactiveOwner
        }
        if migratesLegacyBeforeCommands {
            _ = try PresenceLegacyMigrationService.migrateIfNeeded(
                context: context,
                ownerHumanId: ownerHumanId,
                now: now,
                timeZone: timeZoneProvider()
            )
        }
        let active = try activeParticipationPeriods()
        if let matching = active.first(where: { $0.ownerHumanId == ownerHumanId }) {
            (ownerSelection as? PresenceOwnerUpdating)?.setOwnerHumanId(ownerHumanId)
            return participationSnapshot(matching)
        }
        for period in active {
            if let previousOwnerID = period.ownerHumanId {
                try guardianSafetyOutbox.stageMonitoringStopped(
                    ownerHumanId: previousOwnerID,
                    reason: .ownerChanged,
                    occurredAt: now,
                    timeZone: timeZoneProvider(),
                    context: context
                )
            }
            try closeParticipation(period, now: now)
        }
        let timeZone = timeZoneProvider()
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        let period = PresenceParticipationPeriod(
            ownerHumanId: ownerHumanId,
            startedAt: now,
            startedDayKey: dayKey,
            startedTimeZoneIdentifier: timeZone.identifier,
            source: source
        )
        context.insert(period)
        try save()
        (ownerSelection as? PresenceOwnerUpdating)?.setOwnerHumanId(ownerHumanId)
        return participationSnapshot(period)
    }

    @discardableResult
    func endParticipation(
        reason: GuardianSafetyStopReason = .leftZenMode,
        now: Date = Date()
    ) throws -> [PresenceParticipationSnapshot] {
        let active = try activeParticipationPeriods()
        guard !active.isEmpty else { return [] }
        for period in active {
            if let ownerID = period.ownerHumanId {
                try guardianSafetyOutbox.stageMonitoringStopped(
                    ownerHumanId: ownerID,
                    reason: reason,
                    occurredAt: now,
                    timeZone: timeZoneProvider(),
                    context: context
                )
            }
            try closeParticipation(period, now: now)
        }
        try save()
        return active.map(participationSnapshot)
    }

    @discardableResult
    func autoCheckInOwner(now: Date = Date()) throws -> PresenceCheckInCommandResult {
        let owner = try requireOwner()
        try requireActiveParticipation(ownerHumanId: owner.id)
        let ownerSubject = PresenceSubjectRef(kind: .human, id: owner.id)
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZoneProvider())

        // A durable daily receipt with no matching fact means the user
        // explicitly withdrew today's automatic check-in. Keep that choice
        // stable across subsequent foreground entries; a card tap can still
        // create the fact again without duplicating its reward.
        if try fetchCheckIn(subject: ownerSubject, dayKey: dayKey) == nil,
           try fetchReceipt(key: Self.ownerDailyReceiptKey(dayKey: dayKey)) != nil {
            return PresenceCheckInCommandResult(
                checkIns: [],
                rewards: [],
                didCreateCheckIn: false,
                didChangeStatus: false
            )
        }

        return try performCheckIn(
            subjects: [ownerSubject],
            status: nil,
            source: .automaticForeground,
            now: now,
            owner: owner,
            batchId: nil
        )
    }

    @discardableResult
    func checkInOwner(
        source: PresenceCheckInSource,
        now: Date = Date()
    ) throws -> PresenceCheckInCommandResult {
        let owner = try requireOwner()
        return try performCheckIn(
            subjects: [PresenceSubjectRef(kind: .human, id: owner.id)],
            status: nil,
            source: source,
            now: now,
            owner: owner,
            batchId: nil
        )
    }

    @discardableResult
    func checkIn(
        subject: PresenceSubjectRef,
        status: PresenceStatus? = nil,
        source: PresenceCheckInSource = .card,
        now: Date = Date()
    ) throws -> PresenceCheckInCommandResult {
        let owner = try requireOwner()
        return try performCheckIn(
            subjects: [subject],
            status: status,
            source: source,
            now: now,
            owner: owner,
            batchId: nil
        )
    }

    @discardableResult
    func checkInAll(now: Date = Date()) throws -> PresenceCheckInCommandResult {
        let owner = try requireOwner()
        try requireActiveParticipation(ownerHumanId: owner.id)
        let subjects = try PresenceCheckInReadService.activeSubjects(
            context: context,
            ownerHumanId: owner.id
        ).map(\.subject)
        return try performCheckIn(
            subjects: subjects,
            status: nil,
            source: .checkAll,
            now: now,
            owner: owner,
            batchId: UUID()
        )
    }

    @discardableResult
    func updateTodayStatus(
        subject: PresenceSubjectRef,
        status: PresenceStatus?,
        now: Date = Date()
    ) throws -> PresenceCheckInCommandResult {
        let owner = try requireOwner()
        try requireActiveParticipation(ownerHumanId: owner.id)
        try validateActiveSubject(subject)
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZoneProvider())
        guard let checkIn = try fetchCheckIn(subject: subject, dayKey: dayKey) else {
            throw PresenceCheckInCommandError.missingTodayCheckIn(subject)
        }
        let didChange = checkIn.status != status
        if didChange {
            checkIn.status = status
            checkIn.updatedAt = now
        }
        var requests: [PresenceRewardRequest] = []
        if status != nil,
           try fetchReceipt(key: Self.statusReceiptKey(dayKey: dayKey)) == nil {
            requests.append(Self.statusRewardRequest(dayKey: dayKey, relatedCheckInId: checkIn.id))
        }
        let staged = try stageRewards(requests, owner: owner, now: now)
        if didChange || !staged.isEmpty {
            try persist(stagedRewards: staged, owner: owner, now: now)
        }
        return PresenceCheckInCommandResult(
            checkIns: [factSnapshot(checkIn)],
            rewards: staged.map(Self.rewardOutcome),
            didCreateCheckIn: false,
            didChangeStatus: didChange
        )
    }

    /// Records or updates a score for a past missed day without converting it
    /// into a check-in. This deliberately bypasses every reward and streak
    /// write path; projections distinguish it through its source.
    @discardableResult
    func recordRetrospectiveStatus(
        subject: PresenceSubjectRef,
        dayKey: String,
        status: PresenceStatus,
        now: Date = Date()
    ) throws -> PresenceRetrospectiveStatusResult {
        let owner = try requireOwner()
        try requireActiveParticipation(ownerHumanId: owner.id)
        let stableTimeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let parsedDay = PresenceDayKeyPolicy.parse(dayKey),
              PresenceDayKeyPolicy.key(for: parsedDay, timeZone: stableTimeZone) == dayKey
        else {
            throw PresenceCheckInCommandError.invalidHistoricalDay
        }

        let timeZone = timeZoneProvider()
        let todayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        guard dayKey < todayKey else {
            throw PresenceCheckInCommandError.historicalDayMustBePast
        }
        try requireHistoricalParticipation(
            ownerHumanId: owner.id,
            subject: subject,
            dayKey: dayKey,
            through: todayKey
        )
        try validateSubject(subject, activeOn: dayKey, timeZone: timeZone)

        if let existing = try fetchCheckIn(subject: subject, dayKey: dayKey) {
            guard existing.source == .retrospectiveStatus else {
                throw PresenceCheckInCommandError.historicalDayAlreadyCheckedIn(subject)
            }
            let didChange = existing.status != status
            if didChange {
                existing.status = status
                existing.updatedAt = now
                try save()
            }
            return PresenceRetrospectiveStatusResult(
                fact: factSnapshot(existing),
                didCreate: false,
                didChangeStatus: didChange
            )
        }

        let fact = PresenceCheckIn(
            uniqueKey: Self.checkInKey(subject: subject, dayKey: dayKey),
            subject: subject,
            ownerHumanId: owner.id,
            isOwner: subject == PresenceSubjectRef(kind: .human, id: owner.id),
            dayKey: dayKey,
            timeZoneIdentifier: timeZone.identifier,
            checkedInAt: now,
            source: .retrospectiveStatus,
            status: status,
            operatorHumanId: owner.id
        )
        context.insert(fact)
        do {
            try save()
        } catch {
            context.rollback()
            if let presenceError = error as? PresenceCheckInCommandError {
                throw presenceError
            }
            throw PresenceCheckInCommandError.persistenceFailed(error.localizedDescription)
        }
        return PresenceRetrospectiveStatusResult(
            fact: factSnapshot(fact),
            didCreate: true,
            didChangeStatus: true
        )
    }

    @discardableResult
    func undoTodayCheckIn(
        subject: PresenceSubjectRef,
        now: Date = Date()
    ) throws -> PresenceUndoCheckInResult {
        let owner = try requireOwner()
        try requireActiveParticipation(ownerHumanId: owner.id)
        try validateActiveSubject(subject)
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZoneProvider())
        guard let checkIn = try fetchCheckIn(subject: subject, dayKey: dayKey) else {
            throw PresenceCheckInCommandError.missingTodayCheckIn(subject)
        }
        let removed = factSnapshot(checkIn)
        try guardianSafetyOutbox.stageOwnerUndo(checkIn, occurredAt: now, context: context)
        context.delete(checkIn) // derived-state: allow local-only fact; outbox records undo and bounded reads rebuild streaks
        do {
            try save()
        } catch {
            context.rollback()
            if let presenceError = error as? PresenceCheckInCommandError {
                throw presenceError
            }
            throw PresenceCheckInCommandError.persistenceFailed(error.localizedDescription)
        }
        return PresenceUndoCheckInResult(removedCheckIn: removed)
    }

    private func performCheckIn(
        subjects: [PresenceSubjectRef],
        status: PresenceStatus?,
        source: PresenceCheckInSource,
        now: Date,
        owner: Human,
        batchId: UUID?
    ) throws -> PresenceCheckInCommandResult {
        try requireActiveParticipation(ownerHumanId: owner.id)
        let uniqueSubjects = Array(Set(subjects))
        for subject in uniqueSubjects {
            try validateActiveSubject(subject)
        }
        let timeZone = timeZoneProvider()
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        var checkIns: [PresenceCheckIn] = []
        var createdCheckIns: [PresenceCheckIn] = []
        var didChangeStatus = false

        for subject in uniqueSubjects {
            if let existing = try fetchCheckIn(subject: subject, dayKey: dayKey) {
                if let status, existing.status != status {
                    existing.status = status
                    existing.updatedAt = now
                    didChangeStatus = true
                }
                checkIns.append(existing)
                continue
            }
            let isOwner = subject == PresenceSubjectRef(kind: .human, id: owner.id)
            let checkIn = PresenceCheckIn(
                uniqueKey: Self.checkInKey(subject: subject, dayKey: dayKey),
                subject: subject,
                ownerHumanId: owner.id,
                isOwner: isOwner,
                dayKey: dayKey,
                timeZoneIdentifier: timeZone.identifier,
                checkedInAt: now,
                source: source,
                status: status,
                batchId: batchId,
                operatorHumanId: owner.id
            )
            context.insert(checkIn)
            checkIns.append(checkIn)
            createdCheckIns.append(checkIn)
        }

        if let ownerCheckIn = createdCheckIns.first(where: \.isOwner) {
            try guardianSafetyOutbox.stageOwnerCheckIn(ownerCheckIn, context: context)
        }

        var requests: [PresenceRewardRequest] = []
        if let ownerCheckIn = createdCheckIns.first(where: \.isOwner),
           try fetchReceipt(key: Self.ownerDailyReceiptKey(dayKey: dayKey)) == nil {
            requests.append(Self.ownerDailyRewardRequest(dayKey: dayKey, relatedCheckInId: ownerCheckIn.id))
        }
        if status != nil,
           try fetchReceipt(key: Self.statusReceiptKey(dayKey: dayKey)) == nil,
           let related = checkIns.first {
            requests.append(Self.statusRewardRequest(dayKey: dayKey, relatedCheckInId: related.id))
        }
        if try shouldAwardAllComplete(ownerHumanId: owner.id, dayKey: dayKey),
           try fetchReceipt(key: Self.allCompleteReceiptKey(dayKey: dayKey)) == nil {
            requests.append(Self.allCompleteRewardRequest(dayKey: dayKey, relatedCheckInId: checkIns.first?.id))
        }
        if createdCheckIns.contains(where: \.isOwner) {
            requests += try milestoneRewardRequests(ownerHumanId: owner.id, now: now)
        }

        let staged = try stageRewards(requests, owner: owner, now: now)
        if !createdCheckIns.isEmpty || didChangeStatus || !staged.isEmpty {
            try persist(stagedRewards: staged, owner: owner, now: now)
        }
        return PresenceCheckInCommandResult(
            checkIns: checkIns.map(factSnapshot),
            rewards: staged.map(Self.rewardOutcome),
            didCreateCheckIn: !createdCheckIns.isEmpty,
            didChangeStatus: didChangeStatus
        )
    }

    private func stageRewards(
        _ requests: [PresenceRewardRequest],
        owner: Human,
        now: Date
    ) throws -> [PresenceStagedReward] {
        do {
            return try requests.map { request in
                let staged = try rewardAwarder.stage(request, owner: owner, context: context, now: now)
                context.insert(
                    PresenceRewardReceipt(
                        receiptKey: request.receiptKey,
                        ownerHumanId: owner.id,
                        rewardKind: request.kind,
                        dayKey: request.dayKey,
                        milestoneDays: request.milestoneDays,
                        requestedAmount: request.requestedAmount,
                        awardedAmount: staged.awardedAmount,
                        walletTransactionKey: staged.walletTransactionKey,
                        relatedCheckInId: request.relatedCheckInId,
                        awardedAt: now
                    )
                )
                return staged
            }
        } catch {
            context.rollback()
            rewardAwarder.didRollback(context: context)
            if let presenceError = error as? PresenceCheckInCommandError {
                throw presenceError
            }
            throw PresenceCheckInCommandError.rewardPersistenceFailed(error.localizedDescription)
        }
    }

    private func persist(stagedRewards: [PresenceStagedReward], owner: Human, now: Date) throws {
        do {
            try save()
            rewardAwarder.didCommit(stagedRewards, owner: owner, context: context, now: now)
        } catch {
            context.rollback()
            rewardAwarder.didRollback(context: context)
            if let presenceError = error as? PresenceCheckInCommandError {
                throw presenceError
            }
            throw PresenceCheckInCommandError.persistenceFailed(error.localizedDescription)
        }
    }

    private func save() throws {
        let result = context.safeSaveResult(publishFailureEvent: true)
        guard result.didSave else {
            context.rollback()
            throw PresenceCheckInCommandError.persistenceFailed(
                result.errorDescription ?? "Unable to save presence check-in changes."
            )
        }
    }

    private func requireOwner() throws -> Human {
        guard let id = ownerSelection.ownerHumanId else {
            throw PresenceCheckInCommandError.missingOwner
        }
        guard let owner = try activeHuman(id: id) else {
            throw PresenceCheckInCommandError.inactiveOwner
        }
        if migratesLegacyBeforeCommands {
            _ = try PresenceLegacyMigrationService.migrateIfNeeded(
                context: context,
                ownerHumanId: id,
                timeZone: timeZoneProvider()
            )
        }
        return owner
    }

    private func activeHuman(id: UUID) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate { $0.id == id && $0.passedAwayDate == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func validateActiveSubject(_ subject: PresenceSubjectRef) throws {
        switch subject.kind {
        case .human:
            var descriptor = FetchDescriptor<Human>(predicate: #Predicate { $0.id == subject.id })
            descriptor.fetchLimit = 1
            guard let human = try context.fetch(descriptor).first else {
                throw PresenceCheckInCommandError.missingSubject(subject)
            }
            guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
                throw PresenceCheckInCommandError.inactiveSubject(subject)
            }
        case .pet:
            var descriptor = FetchDescriptor<Pet>(predicate: #Predicate { $0.id == subject.id })
            descriptor.fetchLimit = 1
            guard let pet = try context.fetch(descriptor).first else {
                throw PresenceCheckInCommandError.missingSubject(subject)
            }
            guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
                throw PresenceCheckInCommandError.inactiveSubject(subject)
            }
        case .plant:
            var descriptor = FetchDescriptor<Plant>(predicate: #Predicate { $0.id == subject.id })
            descriptor.fetchLimit = 1
            guard let plant = try context.fetch(descriptor).first else {
                throw PresenceCheckInCommandError.missingSubject(subject)
            }
            guard !plant.isArchived else { throw PresenceCheckInCommandError.inactiveSubject(subject) }
        }
    }

    private func validateSubject(
        _ subject: PresenceSubjectRef,
        activeOn dayKey: String,
        timeZone: TimeZone
    ) throws {
        func requireActiveInterval(createdAt: Date, inactiveAt: Date?) throws {
            let createdDayKey = PresenceDayKeyPolicy.key(for: createdAt, timeZone: timeZone)
            guard createdDayKey <= dayKey else {
                throw PresenceCheckInCommandError.subjectNotActiveOnHistoricalDay(subject)
            }
            if let inactiveAt {
                let inactiveDayKey = PresenceDayKeyPolicy.key(for: inactiveAt, timeZone: timeZone)
                guard dayKey <= inactiveDayKey else {
                    throw PresenceCheckInCommandError.subjectNotActiveOnHistoricalDay(subject)
                }
            }
        }

        switch subject.kind {
        case .human:
            var descriptor = FetchDescriptor<Human>(predicate: #Predicate { $0.id == subject.id })
            descriptor.fetchLimit = 1
            guard let human = try context.fetch(descriptor).first else {
                throw PresenceCheckInCommandError.missingSubject(subject)
            }
            try requireActiveInterval(createdAt: human.createdAt, inactiveAt: human.passedAwayDate)
        case .pet:
            var descriptor = FetchDescriptor<Pet>(predicate: #Predicate { $0.id == subject.id })
            descriptor.fetchLimit = 1
            guard let pet = try context.fetch(descriptor).first else {
                throw PresenceCheckInCommandError.missingSubject(subject)
            }
            try requireActiveInterval(createdAt: pet.createdAt, inactiveAt: pet.passedAwayDate)
        case .plant:
            var descriptor = FetchDescriptor<Plant>(predicate: #Predicate { $0.id == subject.id })
            descriptor.fetchLimit = 1
            guard let plant = try context.fetch(descriptor).first else {
                throw PresenceCheckInCommandError.missingSubject(subject)
            }
            try requireActiveInterval(createdAt: plant.createdAt, inactiveAt: plant.archivedAt)
        }
    }

    private func requireHistoricalParticipation(
        ownerHumanId: UUID,
        subject: PresenceSubjectRef,
        dayKey: String,
        through todayKey: String
    ) throws {
        let ownerSubject = PresenceSubjectRef(kind: .human, id: ownerHumanId)
        let periods = if subject == ownerSubject {
            try PresenceCheckInReadService.participationPeriods(
                context: context,
                ownerHumanId: ownerHumanId
            )
        } else {
            try PresenceCheckInReadService.participationPeriods(context: context)
        }
        let calculatorPeriods = periods.map {
            PresenceStreakCalculator.Period(
                startedDayKey: $0.startedDayKey,
                lastParticipatingDayKey: $0.lastParticipatingDayKey,
                isActive: $0.isActive
            )
        }
        let participatingDays = PresenceStreakCalculator.participatingDays(
            periods: calculatorPeriods,
            through: todayKey
        )
        guard participatingDays.contains(dayKey) else {
            throw PresenceCheckInCommandError.historicalDayNotParticipating
        }
    }

    private func requireActiveParticipation(ownerHumanId: UUID) throws {
        let ownerRaw = ownerHumanId.uuidString
        var descriptor = FetchDescriptor<PresenceParticipationPeriod>(
            predicate: #Predicate { $0.ownerHumanIdRaw == ownerRaw && $0.endedAt == nil }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).first != nil else {
            throw PresenceCheckInCommandError.notParticipating
        }
    }

    private func activeParticipationPeriods() throws -> [PresenceParticipationPeriod] {
        try context.fetch(
            FetchDescriptor<PresenceParticipationPeriod>(
                predicate: #Predicate { $0.endedAt == nil },
                sortBy: [SortDescriptor(\.startedAt)]
            )
        )
    }

    private func closeParticipation(_ period: PresenceParticipationPeriod, now: Date) throws {
        let timeZone = timeZoneProvider()
        let todayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        let owner = PresenceSubjectRef(kind: .human, id: period.ownerHumanId ?? UUID())
        let checkedToday = period.ownerHumanId == nil
            ? false
            : try fetchCheckIn(subject: owner, dayKey: todayKey) != nil
        period.endedAt = now
        period.endedTimeZoneIdentifier = timeZone.identifier
        period.lastParticipatingDayKey = checkedToday
            ? todayKey
            : PresenceDayKeyPolicy.addingDays(-1, to: todayKey)
        period.updatedAt = now
    }

    private func fetchCheckIn(subject: PresenceSubjectRef, dayKey: String) throws -> PresenceCheckIn? {
        let key = Self.checkInKey(subject: subject, dayKey: dayKey)
        var descriptor = FetchDescriptor<PresenceCheckIn>(predicate: #Predicate { $0.uniqueKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchReceipt(key: String) throws -> PresenceRewardReceipt? {
        var descriptor = FetchDescriptor<PresenceRewardReceipt>(predicate: #Predicate { $0.receiptKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func shouldAwardAllComplete(ownerHumanId: UUID, dayKey: String) throws -> Bool {
        let subjects = try PresenceCheckInReadService.activeSubjects(context: context, ownerHumanId: ownerHumanId)
        guard subjects.contains(where: { !$0.isOwner }) else { return false }
        for subject in subjects {
            guard try fetchCheckIn(subject: subject.subject, dayKey: dayKey) != nil else { return false }
        }
        return true
    }

    private func milestoneRewardRequests(ownerHumanId: UUID, now: Date) throws -> [PresenceRewardRequest] {
        let snapshot = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: ownerHumanId,
            subject: .init(kind: .human, id: ownerHumanId),
            now: now,
            timeZone: timeZoneProvider()
        )
        var requests: [PresenceRewardRequest] = []
        for milestone in Self.milestoneRewards where snapshot.currentStreak >= milestone.days {
            let key = Self.milestoneReceiptKey(days: milestone.days)
            guard try fetchReceipt(key: key) == nil else { continue }
            requests.append(
                PresenceRewardRequest(
                    receiptKey: key,
                    kind: .streakMilestone,
                    requestedAmount: milestone.amount,
                    dayKey: nil,
                    milestoneDays: milestone.days,
                    relatedCheckInId: nil,
                    isBudgeted: false
                )
            )
        }
        return requests
    }

    private func participationSnapshot(_ period: PresenceParticipationPeriod) -> PresenceParticipationSnapshot {
        PresenceParticipationSnapshot(
            id: period.id,
            ownerHumanId: period.ownerHumanId ?? UUID(),
            startedAt: period.startedAt,
            endedAt: period.endedAt,
            startedDayKey: period.startedDayKey,
            lastParticipatingDayKey: period.lastParticipatingDayKey
        )
    }

    private func factSnapshot(_ checkIn: PresenceCheckIn) -> PresenceCheckInFactSnapshot {
        PresenceCheckInFactSnapshot(
            id: checkIn.id,
            subject: checkIn.subject ?? PresenceSubjectRef(kind: .human, id: UUID()),
            dayKey: checkIn.dayKey,
            status: checkIn.status,
            source: checkIn.source,
            checkedInAt: checkIn.checkedInAt,
            isOwner: checkIn.isOwner
        )
    }

    private static func rewardOutcome(_ staged: PresenceStagedReward) -> PresenceRewardOutcome {
        PresenceRewardOutcome(
            kind: staged.request.kind,
            requestedAmount: staged.request.requestedAmount,
            awardedAmount: staged.awardedAmount,
            milestoneDays: staged.request.milestoneDays
        )
    }

    static func checkInKey(subject: PresenceSubjectRef, dayKey: String) -> String {
        "presence:check-in:\(subject.stableKey):\(dayKey)"
    }

    static func ownerDailyReceiptKey(dayKey: String) -> String { "presence:reward:owner-daily:\(dayKey)" }
    static func statusReceiptKey(dayKey: String) -> String { "presence:reward:status-daily:\(dayKey)" }
    static func allCompleteReceiptKey(dayKey: String) -> String { "presence:reward:all-complete:\(dayKey)" }
    static func milestoneReceiptKey(days: Int) -> String { "presence:reward:streak:\(days)" }

    private static func ownerDailyRewardRequest(dayKey: String, relatedCheckInId: UUID) -> PresenceRewardRequest {
        PresenceRewardRequest(
            receiptKey: ownerDailyReceiptKey(dayKey: dayKey),
            kind: .ownerDaily,
            requestedAmount: 1,
            dayKey: dayKey,
            milestoneDays: 0,
            relatedCheckInId: relatedCheckInId,
            isBudgeted: true
        )
    }

    private static func statusRewardRequest(dayKey: String, relatedCheckInId: UUID) -> PresenceRewardRequest {
        PresenceRewardRequest(
            receiptKey: statusReceiptKey(dayKey: dayKey),
            kind: .dailyStatus,
            requestedAmount: 1,
            dayKey: dayKey,
            milestoneDays: 0,
            relatedCheckInId: relatedCheckInId,
            isBudgeted: true
        )
    }

    private static func allCompleteRewardRequest(dayKey: String, relatedCheckInId: UUID?) -> PresenceRewardRequest {
        PresenceRewardRequest(
            receiptKey: allCompleteReceiptKey(dayKey: dayKey),
            kind: .allComplete,
            requestedAmount: 2,
            dayKey: dayKey,
            milestoneDays: 0,
            relatedCheckInId: relatedCheckInId,
            isBudgeted: true
        )
    }
}
