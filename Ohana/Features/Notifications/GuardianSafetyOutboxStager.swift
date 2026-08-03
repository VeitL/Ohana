//
//  GuardianSafetyOutboxStager.swift
//  Ohana
//
//  Stages the minimum owner safety signal inside the same SwiftData transaction
//  as the Presence fact. It never uploads a score or another subject's data.
//

import Foundation
import SwiftData

@MainActor
protocol GuardianSafetyOutboxStaging {
    func stageOwnerCheckIn(_ checkIn: PresenceCheckIn, context: ModelContext) throws
    @discardableResult
    func stageExistingExplicitOwnerCheckInForCurrentDay(
        ownerHumanId: UUID,
        now: Date,
        timeZone: TimeZone,
        context: ModelContext
    ) throws -> Bool
    func stageOwnerUndo(_ checkIn: PresenceCheckIn, occurredAt: Date, context: ModelContext) throws
    func stageMonitoringStopped(
        ownerHumanId: UUID,
        reason: GuardianSafetyStopReason,
        occurredAt: Date,
        timeZone: TimeZone,
        context: ModelContext
    ) throws
}

@MainActor
struct LiveGuardianSafetyOutboxStager: GuardianSafetyOutboxStaging {
    func stageOwnerCheckIn(_ checkIn: PresenceCheckIn, context: ModelContext) throws {
        guard checkIn.isOwner,
              checkIn.source != .retrospectiveStatus,
              let ownerHumanId = checkIn.ownerHumanId,
              let policy = try activePolicy(ownerHumanId: ownerHumanId, context: context)
        else { return }
        let timeZone = TimeZone(identifier: policy.timeZoneIdentifier) ?? .current

        _ = try insertIfNeeded(
            GuardianSafetySyncOutbox(
                eventKey: "guardian-safety:check-in:\(checkIn.id.uuidString.lowercased())",
                eventKind: .ownerCheckIn,
                ownerHumanId: ownerHumanId,
                dayKey: PresenceDayKeyPolicy.key(for: checkIn.checkedInAt, timeZone: timeZone),
                occurredAt: checkIn.checkedInAt,
                timeZoneIdentifier: timeZone.identifier,
                checkInSource: checkIn.source
            ),
            context: context
        )
    }

    @discardableResult
    func stageExistingExplicitOwnerCheckInForCurrentDay(
        ownerHumanId: UUID,
        now: Date,
        timeZone: TimeZone,
        context: ModelContext
    ) throws -> Bool {
        guard let policy = try activePolicy(ownerHumanId: ownerHumanId, context: context) else {
            return false
        }
        let guardTimeZone = TimeZone(identifier: policy.timeZoneIdentifier) ?? timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = guardTimeZone
        let dayStart = calendar.startOfDay(for: now)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        let ownerID = ownerHumanId.uuidString
        let humanKind = PresenceSubjectKind.human.rawValue
        let cardSource = PresenceCheckInSource.card.rawValue
        let notificationSource = PresenceCheckInSource.notificationAction.rawValue
        var descriptor = FetchDescriptor<PresenceCheckIn>(
            predicate: #Predicate {
                $0.ownerHumanIdRaw == ownerID
                    && $0.subjectKindRaw == humanKind
                    && $0.subjectIdRaw == ownerID
                    && $0.isOwner
                    && $0.checkedInAt >= dayStart
                    && $0.checkedInAt < nextDayStart
                    && ($0.sourceRaw == cardSource || $0.sourceRaw == notificationSource)
            },
            sortBy: [SortDescriptor(\.checkedInAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let checkIn = try context.fetch(descriptor).first else { return false }
        return try insertIfNeeded(
            GuardianSafetySyncOutbox(
                eventKey: "guardian-safety:check-in:\(checkIn.id.uuidString.lowercased())",
                eventKind: .ownerCheckIn,
                ownerHumanId: ownerHumanId,
                dayKey: PresenceDayKeyPolicy.key(for: checkIn.checkedInAt, timeZone: guardTimeZone),
                occurredAt: checkIn.checkedInAt,
                timeZoneIdentifier: guardTimeZone.identifier,
                checkInSource: checkIn.source
            ),
            context: context
        )
    }

    func stageOwnerUndo(
        _ checkIn: PresenceCheckIn,
        occurredAt: Date,
        context: ModelContext
    ) throws {
        guard checkIn.isOwner,
              let ownerHumanId = checkIn.ownerHumanId,
              let policy = try activePolicy(ownerHumanId: ownerHumanId, context: context)
        else { return }
        let timeZone = TimeZone(identifier: policy.timeZoneIdentifier) ?? .current

        _ = try insertIfNeeded(
            GuardianSafetySyncOutbox(
                eventKey: "guardian-safety:undo:\(checkIn.id.uuidString.lowercased())",
                eventKind: .ownerUndo,
                ownerHumanId: ownerHumanId,
                dayKey: PresenceDayKeyPolicy.key(for: checkIn.checkedInAt, timeZone: timeZone),
                occurredAt: occurredAt,
                timeZoneIdentifier: timeZone.identifier,
                checkInSource: checkIn.source
            ),
            context: context
        )
    }

    func stageMonitoringStopped(
        ownerHumanId: UUID,
        reason: GuardianSafetyStopReason,
        occurredAt: Date,
        timeZone: TimeZone,
        context: ModelContext
    ) throws {
        guard let policy = try activePolicy(ownerHumanId: ownerHumanId, context: context) else { return }
        let revision = policy.scheduleRevision + 1
        _ = try insertIfNeeded(
            GuardianSafetySyncOutbox(
                eventKey: "guardian-safety:stop:\(ownerHumanId.uuidString.lowercased()):\(revision)",
                eventKind: .monitoringStopped,
                ownerHumanId: ownerHumanId,
                occurredAt: occurredAt,
                timeZoneIdentifier: timeZone.identifier,
                stopReason: reason
            ),
            context: context
        )
        policy.isEnabled = false
        policy.status = .stopped
        policy.scheduleRevision = revision
        policy.pauseUntil = nil
        policy.updatedAt = occurredAt
    }

    private func activePolicy(
        ownerHumanId: UUID,
        context: ModelContext
    ) throws -> GuardianSafetyPolicyProjection? {
        let key = GuardianSafetyPolicyProjection.key(ownerHumanId: ownerHumanId)
        var descriptor = FetchDescriptor<GuardianSafetyPolicyProjection>(
            predicate: #Predicate { $0.policyKey == key && $0.isEnabled }
        )
        descriptor.fetchLimit = 1
        guard let policy = try context.fetch(descriptor).first,
              policy.serverPolicyId != nil,
              policy.status != .stopped
        else { return nil }
        return policy
    }

    private func insertIfNeeded(
        _ event: GuardianSafetySyncOutbox,
        context: ModelContext
    ) throws -> Bool {
        let key = event.eventKey
        var descriptor = FetchDescriptor<GuardianSafetySyncOutbox>(
            predicate: #Predicate { $0.eventKey == key }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return false }
        context.insert(event)
        return true
    }
}

@MainActor
struct DisabledGuardianSafetyOutboxStager: GuardianSafetyOutboxStaging {
    func stageOwnerCheckIn(_: PresenceCheckIn, context _: ModelContext) throws {}
    func stageExistingExplicitOwnerCheckInForCurrentDay(
        ownerHumanId _: UUID,
        now _: Date,
        timeZone _: TimeZone,
        context _: ModelContext
    ) throws -> Bool { false }
    func stageOwnerUndo(_: PresenceCheckIn, occurredAt _: Date, context _: ModelContext) throws {}
    func stageMonitoringStopped(
        ownerHumanId _: UUID,
        reason _: GuardianSafetyStopReason,
        occurredAt _: Date,
        timeZone _: TimeZone,
        context _: ModelContext
    ) throws {}
}
