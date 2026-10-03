//
//  PresenceLegacyMigrationService.swift
//  Ohana
//
//  Idempotent post-container-open migration from the UserDefaults streak store.
//

import Foundation
import SwiftData

nonisolated struct PresenceLegacyMigrationSummary: Equatable, Sendable {
    let ownerHumanId: UUID?
    let migratedCheckInCount: Int
    let migratedMilestoneReceiptCount: Int
    let didCreateParticipationPeriod: Bool
    let didComplete: Bool

    static let deferred = PresenceLegacyMigrationSummary(
        ownerHumanId: nil,
        migratedCheckInCount: 0,
        migratedMilestoneReceiptCount: 0,
        didCreateParticipationPeriod: false,
        didComplete: false
    )
}

nonisolated struct PresenceLegacyStreakSnapshot: Equatable, Sendable {
    let checkedDates: Set<String>
    let makeupDates: Set<String>
    let claimedMilestone: Int
}

@MainActor
protocol PresenceLegacyStreakReading {
    func snapshot(ownerHumanId: UUID) -> PresenceLegacyStreakSnapshot
}

@MainActor
struct UserDefaultsPresenceLegacyStreakReader: PresenceLegacyStreakReading {
    func snapshot(ownerHumanId: UUID) -> PresenceLegacyStreakSnapshot {
        PresenceLegacyStreakSnapshot(
            checkedDates: CheckInStreakStore.checkedInDates(for: ownerHumanId.uuidString),
            makeupDates: CheckInStreakStore.makeupDates(for: ownerHumanId.uuidString),
            claimedMilestone: CheckInStreakStore.lastClaimedMilestone(for: ownerHumanId.uuidString)
        )
    }
}

@MainActor
enum PresenceLegacyMigrationService {
    private static let markerPrefix = "presence.legacy-streak-migration.v1"

    @discardableResult
    static func migrateIfNeeded(
        context: ModelContext,
        ownerSelection: PresenceOwnerSelecting = UserDefaultsPresenceOwnerSelection(),
        legacyReader providedLegacyReader: PresenceLegacyStreakReading? = nil,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) throws -> PresenceLegacyMigrationSummary {
        guard let ownerId = try resolveOwner(
            context: context,
            selectedOwnerId: ownerSelection.ownerHumanId,
            defaults: defaults
        ) else { return .deferred }
        let legacyReader = providedLegacyReader ?? UserDefaultsPresenceLegacyStreakReader()
        return try migrateIfNeeded(
            context: context,
            ownerHumanId: ownerId,
            legacyReader: legacyReader,
            defaults: defaults,
            now: now,
            timeZone: timeZone
        )
    }

    @discardableResult
    static func migrateIfNeeded(
        context: ModelContext,
        ownerHumanId: UUID,
        legacyReader providedLegacyReader: PresenceLegacyStreakReading? = nil,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) throws -> PresenceLegacyMigrationSummary {
        let markerKey = "\(markerPrefix).\(ownerHumanId.uuidString.lowercased())"
        if defaults.bool(forKey: markerKey) {
            return PresenceLegacyMigrationSummary(
                ownerHumanId: ownerHumanId,
                migratedCheckInCount: 0,
                migratedMilestoneReceiptCount: 0,
                didCreateParticipationPeriod: false,
                didComplete: true
            )
        }

        // This first performs CheckInStreakStore's own one-time move from its
        // unscoped keys to the selected Human. Reads are intentionally retained
        // for one compatibility version; all new Presence writes use SwiftData.
        let legacyReader = providedLegacyReader ?? UserDefaultsPresenceLegacyStreakReader()
        let legacy = legacyReader.snapshot(ownerHumanId: ownerHumanId)
        let checkedDates = legacy.checkedDates
        let makeupDates = legacy.makeupDates
        let claimedMilestone = legacy.claimedMilestone
        let subject = PresenceSubjectRef(kind: .human, id: ownerHumanId)

        var insertedCheckInCount = 0
        for dayKey in checkedDates.sorted() where PresenceDayKeyPolicy.parse(dayKey) != nil {
            let uniqueKey = PresenceCheckInCommandService.checkInKey(subject: subject, dayKey: dayKey)
            guard try fetchCheckIn(key: uniqueKey, context: context) == nil else { continue }
            let occurredAt = legacyOccurrence(dayKey: dayKey, timeZone: timeZone) ?? now
            context.insert(
                PresenceCheckIn(
                    uniqueKey: uniqueKey,
                    subject: subject,
                    ownerHumanId: ownerHumanId,
                    isOwner: true,
                    dayKey: dayKey,
                    timeZoneIdentifier: timeZone.identifier,
                    checkedInAt: occurredAt,
                    source: makeupDates.contains(dayKey) ? .legacyMakeup : .legacy,
                    operatorHumanId: ownerHumanId,
                    isLegacy: true,
                    createdAt: occurredAt,
                    updatedAt: occurredAt
                )
            )
            insertedCheckInCount += 1
        }

        var didCreatePeriod = false
        if let firstDay = checkedDates.min(),
           let lastDay = checkedDates.max(),
           PresenceDayKeyPolicy.parse(firstDay) != nil,
           PresenceDayKeyPolicy.parse(lastDay) != nil {
            let periodKey = "presence-period:legacy:\(ownerHumanId.uuidString.lowercased())"
            if try fetchParticipationPeriod(key: periodKey, context: context) == nil {
                let startedAt = legacyOccurrence(dayKey: firstDay, timeZone: timeZone) ?? now
                let endedAt = legacyOccurrence(dayKey: lastDay, timeZone: timeZone)?.addingTimeInterval(12 * 60 * 60) ?? now
                context.insert(
                    PresenceParticipationPeriod(
                        periodKey: periodKey,
                        ownerHumanId: ownerHumanId,
                        startedAt: startedAt,
                        startedDayKey: firstDay,
                        startedTimeZoneIdentifier: timeZone.identifier,
                        endedAt: endedAt,
                        lastParticipatingDayKey: lastDay,
                        endedTimeZoneIdentifier: timeZone.identifier,
                        source: .legacyMigration,
                        createdAt: startedAt,
                        updatedAt: endedAt
                    )
                )
                didCreatePeriod = true
            }
        }

        var insertedReceiptCount = 0
        for milestone in PresenceCheckInCommandService.milestoneRewards where milestone.days <= claimedMilestone {
            let receiptKey = PresenceCheckInCommandService.milestoneReceiptKey(days: milestone.days)
            guard try fetchRewardReceipt(key: receiptKey, context: context) == nil else { continue }
            context.insert(
                PresenceRewardReceipt(
                    receiptKey: receiptKey,
                    ownerHumanId: ownerHumanId,
                    rewardKind: .streakMilestone,
                    milestoneDays: milestone.days,
                    requestedAmount: milestone.amount,
                    awardedAmount: 0,
                    isLegacy: true,
                    awardedAt: now
                )
            )
            insertedReceiptCount += 1
        }

        if insertedCheckInCount > 0 || insertedReceiptCount > 0 || didCreatePeriod {
            let result = context.safeSaveResult(publishFailureEvent: true)
            guard result.didSave else {
                context.rollback()
                throw PresenceCheckInCommandError.persistenceFailed(
                    result.errorDescription ?? "Unable to migrate legacy check-ins."
                )
            }
        }
        // Marker is deliberately written only after the SwiftData transaction
        // succeeds. A crash before this line simply replays unique-key upserts.
        defaults.set(true, forKey: markerKey)
        return PresenceLegacyMigrationSummary(
            ownerHumanId: ownerHumanId,
            migratedCheckInCount: insertedCheckInCount,
            migratedMilestoneReceiptCount: insertedReceiptCount,
            didCreateParticipationPeriod: didCreatePeriod,
            didComplete: true
        )
    }

    private static func resolveOwner(
        context: ModelContext,
        selectedOwnerId: UUID?,
        defaults: UserDefaults
    ) throws -> UUID? {
        if let selectedOwnerId, try isActiveHuman(selectedOwnerId, context: context) {
            return selectedOwnerId
        }
        if let activeRaw = defaults.string(forKey: "currentActiveHumanId"),
           let activeId = UUID(uuidString: activeRaw),
           try isActiveHuman(activeId, context: context) {
            return activeId
        }
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate { $0.passedAwayDate == nil })
        descriptor.fetchLimit = 2
        let humans = try context.fetch(descriptor)
        return humans.count == 1 ? humans[0].id : nil
    }

    private static func isActiveHuman(_ id: UUID, context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate { $0.id == id && $0.passedAwayDate == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first != nil
    }

    private static func fetchCheckIn(key: String, context: ModelContext) throws -> PresenceCheckIn? {
        var descriptor = FetchDescriptor<PresenceCheckIn>(predicate: #Predicate { $0.uniqueKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchParticipationPeriod(
        key: String,
        context: ModelContext
    ) throws -> PresenceParticipationPeriod? {
        var descriptor = FetchDescriptor<PresenceParticipationPeriod>(predicate: #Predicate { $0.periodKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchRewardReceipt(
        key: String,
        context: ModelContext
    ) throws -> PresenceRewardReceipt? {
        var descriptor = FetchDescriptor<PresenceRewardReceipt>(predicate: #Predicate { $0.receiptKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func legacyOccurrence(dayKey: String, timeZone: TimeZone) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
        )
    }
}
