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
              try activePolicy(ownerHumanId: ownerHumanId, context: context) != nil
        else { return }

        try insertIfNeeded(
            GuardianSafetySyncOutbox(
                eventKey: "guardian-safety:check-in:\(checkIn.id.uuidString.lowercased())",
                eventKind: .ownerCheckIn,
                ownerHumanId: ownerHumanId,
                dayKey: checkIn.dayKey,
                occurredAt: checkIn.checkedInAt,
                timeZoneIdentifier: checkIn.timeZoneIdentifier,
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
              try activePolicy(ownerHumanId: ownerHumanId, context: context) != nil
        else { return }

        try insertIfNeeded(
            GuardianSafetySyncOutbox(
                eventKey: "guardian-safety:undo:\(checkIn.id.uuidString.lowercased())",
                eventKind: .ownerUndo,
                ownerHumanId: ownerHumanId,
                dayKey: checkIn.dayKey,
                occurredAt: occurredAt,
                timeZoneIdentifier: checkIn.timeZoneIdentifier,
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
        try insertIfNeeded(
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
    ) throws {
        let key = event.eventKey
        var descriptor = FetchDescriptor<GuardianSafetySyncOutbox>(
            predicate: #Predicate { $0.eventKey == key }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(event)
    }
}

@MainActor
struct DisabledGuardianSafetyOutboxStager: GuardianSafetyOutboxStaging {
    func stageOwnerCheckIn(_: PresenceCheckIn, context _: ModelContext) throws {}
    func stageOwnerUndo(_: PresenceCheckIn, occurredAt _: Date, context _: ModelContext) throws {}
    func stageMonitoringStopped(
        ownerHumanId _: UUID,
        reason _: GuardianSafetyStopReason,
        occurredAt _: Date,
        timeZone _: TimeZone,
        context _: ModelContext
    ) throws {}
}
