//
//  GuardianSafetyModels.swift
//  Ohana
//
//  Device-local projections and a reliable outbox for the optional Family
//  guardian service. The server remains authoritative for invitations,
//  relationships, incidents, device endpoints, and entitlement enforcement.
//

import Foundation
import SwiftData

nonisolated enum GuardianSafetyPolicyStatus: String, Codable, CaseIterable, Sendable {
    case inactive
    case arming
    case monitoring
    case paused
    case unreachable
    case stopped
}

nonisolated enum GuardianRelationshipStatus: String, Codable, CaseIterable, Sendable {
    case invited
    case accepted
    case revoked
}

nonisolated enum GuardianNotificationReachability: String, Codable, CaseIterable, Sendable {
    case unknown
    case active
    case notificationsDisabled
    case unreachable
    case revoked
}

/// Last server-observed state for this guardian relationship. `submitted`
/// means SNS/APNs accepted a request; it is deliberately not called delivered.
nonisolated enum GuardianNotificationAttemptState: String, Codable, CaseIterable, Sendable {
    case submitted
    case opened
    case acknowledged
    case unreachable
}

nonisolated enum GuardianIncidentStatus: String, Codable, CaseIterable, Sendable {
    case monitoring
    case initialSubmitted
    case followUpSubmitted
    case acknowledged
    case recovered
    case closed
}

nonisolated enum GuardianSafetySyncEventKind: String, Codable, CaseIterable, Sendable {
    case ownerCheckIn
    case ownerUndo
    case monitoringStopped
    case policyChanged
    case deviceEndpointChanged
}

nonisolated enum GuardianSafetySyncState: String, Codable, CaseIterable, Sendable {
    case pending
    case sending
    case sent
    case failed
}

nonisolated enum GuardianSafetyStopReason: String, Codable, CaseIterable, Sendable {
    case leftZenMode
    case ownerChanged
    case ownerUnavailable
    case policyDisabled
    case entitlementLost
    case accountDeleted
}

@Model
final class GuardianSafetyPolicyProjection {
    #Index<GuardianSafetyPolicyProjection>(
        [\.ownerHumanIdRaw],
        [\.isEnabled, \.statusRaw],
        [\.updatedAt]
    )

    var id: UUID
    @Attribute(.unique) var policyKey: String
    var serverPolicyIdRaw: String?
    var ownerHumanIdRaw: String
    var isEnabled: Bool
    var statusRaw: String
    /// Calendar weekday values separated by commas: Sunday = 1 ... Saturday = 7.
    var weekdaysCSV: String
    var deadlineHour: Int
    var deadlineMinute: Int
    var gracePeriodMinutes: Int
    var pauseUntil: Date?
    var timeZoneIdentifier: String
    var scheduleRevision: Int
    var acceptedGuardianCount: Int
    var reachableGuardianCount: Int
    var lastErrorCode: String?
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        policyKey: String? = nil,
        serverPolicyId: String? = nil,
        ownerHumanId: UUID,
        isEnabled: Bool = false,
        status: GuardianSafetyPolicyStatus = .inactive,
        weekdays: Set<Int> = Set(1 ... 7),
        deadlineHour: Int = 20,
        deadlineMinute: Int = 0,
        gracePeriodMinutes: Int = 60,
        pauseUntil: Date? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        scheduleRevision: Int = 1,
        acceptedGuardianCount: Int = 0,
        reachableGuardianCount: Int = 0,
        lastErrorCode: String? = nil,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.policyKey = policyKey ?? Self.key(ownerHumanId: ownerHumanId)
        serverPolicyIdRaw = serverPolicyId
        ownerHumanIdRaw = ownerHumanId.uuidString
        self.isEnabled = isEnabled
        statusRaw = status.rawValue
        weekdaysCSV = Self.encodeWeekdays(weekdays)
        self.deadlineHour = min(max(deadlineHour, 0), 23)
        self.deadlineMinute = min(max(deadlineMinute, 0), 59)
        self.gracePeriodMinutes = min(max(gracePeriodMinutes, 15), 180)
        self.pauseUntil = pauseUntil
        self.timeZoneIdentifier = timeZoneIdentifier
        self.scheduleRevision = max(1, scheduleRevision)
        self.acceptedGuardianCount = max(0, acceptedGuardianCount)
        self.reachableGuardianCount = max(0, reachableGuardianCount)
        self.lastErrorCode = lastErrorCode
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var ownerHumanId: UUID? { UUID(uuidString: ownerHumanIdRaw) }

    var serverPolicyId: String? {
        get { serverPolicyIdRaw }
        set { serverPolicyIdRaw = newValue }
    }

    var status: GuardianSafetyPolicyStatus {
        get { GuardianSafetyPolicyStatus(rawValue: statusRaw) ?? .inactive }
        set { statusRaw = newValue.rawValue }
    }

    var weekdays: Set<Int> {
        get { Self.decodeWeekdays(weekdaysCSV) }
        set { weekdaysCSV = Self.encodeWeekdays(newValue) }
    }

    static func key(ownerHumanId: UUID) -> String {
        "guardian-safety:policy:\(ownerHumanId.uuidString.lowercased())"
    }

    private static func encodeWeekdays(_ weekdays: Set<Int>) -> String {
        weekdays.filter { (1 ... 7).contains($0) }.sorted().map(String.init).joined(separator: ",")
    }

    private static func decodeWeekdays(_ rawValue: String) -> Set<Int> {
        Set(rawValue.split(separator: ",").compactMap { raw in
            guard let value = Int(raw), (1 ... 7).contains(value) else { return nil }
            return value
        })
    }
}

@Model
final class GuardianRelationshipProjection {
    #Index<GuardianRelationshipProjection>(
        [\.ownerHumanIdRaw, \.statusRaw],
        [\.reachabilityRaw],
        [\.updatedAt]
    )

    var id: UUID
    @Attribute(.unique) var serverRelationshipId: String
    var ownerHumanIdRaw: String?
    var displayName: String
    var statusRaw: String
    var reachabilityRaw: String
    var currentUserIsGuardian: Bool
    var acceptedAt: Date?
    var revokedAt: Date?
    var lastOpenedAt: Date?
    var lastAcknowledgedAt: Date?
    var latestNotificationStateRaw: String?
    var latestNotificationUpdatedAt: Date?
    var protectedPolicyStatusRaw: String?
    var protectedPauseUntil: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        serverRelationshipId: String,
        ownerHumanId: UUID? = nil,
        displayName: String,
        status: GuardianRelationshipStatus,
        reachability: GuardianNotificationReachability = .unknown,
        currentUserIsGuardian: Bool = false,
        acceptedAt: Date? = nil,
        revokedAt: Date? = nil,
        lastOpenedAt: Date? = nil,
        lastAcknowledgedAt: Date? = nil,
        latestNotificationState: GuardianNotificationAttemptState? = nil,
        latestNotificationUpdatedAt: Date? = nil,
        protectedPolicyStatus: GuardianSafetyPolicyStatus? = nil,
        protectedPauseUntil: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.serverRelationshipId = serverRelationshipId
        ownerHumanIdRaw = ownerHumanId?.uuidString
        self.displayName = displayName
        statusRaw = status.rawValue
        reachabilityRaw = reachability.rawValue
        self.currentUserIsGuardian = currentUserIsGuardian
        self.acceptedAt = acceptedAt
        self.revokedAt = revokedAt
        self.lastOpenedAt = lastOpenedAt
        self.lastAcknowledgedAt = lastAcknowledgedAt
        latestNotificationStateRaw = latestNotificationState?.rawValue
        self.latestNotificationUpdatedAt = latestNotificationUpdatedAt
        protectedPolicyStatusRaw = protectedPolicyStatus?.rawValue
        self.protectedPauseUntil = protectedPauseUntil
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var ownerHumanId: UUID? { ownerHumanIdRaw.flatMap(UUID.init(uuidString:)) }

    var status: GuardianRelationshipStatus {
        get { GuardianRelationshipStatus(rawValue: statusRaw) ?? .revoked }
        set { statusRaw = newValue.rawValue }
    }

    var reachability: GuardianNotificationReachability {
        get { GuardianNotificationReachability(rawValue: reachabilityRaw) ?? .unknown }
        set { reachabilityRaw = newValue.rawValue }
    }

    var latestNotificationState: GuardianNotificationAttemptState? {
        get { latestNotificationStateRaw.flatMap(GuardianNotificationAttemptState.init(rawValue:)) }
        set { latestNotificationStateRaw = newValue?.rawValue }
    }

    var protectedPolicyStatus: GuardianSafetyPolicyStatus? {
        get { protectedPolicyStatusRaw.flatMap(GuardianSafetyPolicyStatus.init(rawValue:)) }
        set { protectedPolicyStatusRaw = newValue?.rawValue }
    }
}

@Model
final class GuardianIncidentProjection {
    #Index<GuardianIncidentProjection>(
        [\.ownerHumanIdRaw, \.statusRaw],
        [\.lastGuardDayKey],
        [\.updatedAt]
    )

    var id: UUID
    @Attribute(.unique) var serverIncidentId: String
    var serverPolicyId: String
    var ownerHumanIdRaw: String?
    var statusRaw: String
    var lastGuardDayKey: String
    var consecutiveMisses: Int
    var initialSubmittedAt: Date?
    var followUpSubmittedAt: Date?
    var acknowledgedAt: Date?
    var recoveredAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        serverIncidentId: String,
        serverPolicyId: String,
        ownerHumanId: UUID? = nil,
        status: GuardianIncidentStatus,
        lastGuardDayKey: String,
        consecutiveMisses: Int,
        initialSubmittedAt: Date? = nil,
        followUpSubmittedAt: Date? = nil,
        acknowledgedAt: Date? = nil,
        recoveredAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.serverIncidentId = serverIncidentId
        self.serverPolicyId = serverPolicyId
        ownerHumanIdRaw = ownerHumanId?.uuidString
        statusRaw = status.rawValue
        self.lastGuardDayKey = lastGuardDayKey
        self.consecutiveMisses = max(0, consecutiveMisses)
        self.initialSubmittedAt = initialSubmittedAt
        self.followUpSubmittedAt = followUpSubmittedAt
        self.acknowledgedAt = acknowledgedAt
        self.recoveredAt = recoveredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var ownerHumanId: UUID? { ownerHumanIdRaw.flatMap(UUID.init(uuidString:)) }

    var status: GuardianIncidentStatus {
        get { GuardianIncidentStatus(rawValue: statusRaw) ?? .monitoring }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class GuardianSafetySyncOutbox {
    #Index<GuardianSafetySyncOutbox>(
        [\.stateRaw, \.nextAttemptAt],
        [\.ownerHumanIdRaw, \.occurredAt],
        [\.createdAt]
    )

    var id: UUID
    @Attribute(.unique) var eventKey: String
    var eventKindRaw: String
    var ownerHumanIdRaw: String
    var dayKey: String?
    var occurredAt: Date
    var timeZoneIdentifier: String
    var checkInSourceRaw: String?
    var stopReasonRaw: String?
    var payloadJSON: Data?
    var stateRaw: String
    var attemptCount: Int
    var nextAttemptAt: Date
    var lastErrorCode: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        eventKey: String,
        eventKind: GuardianSafetySyncEventKind,
        ownerHumanId: UUID,
        dayKey: String? = nil,
        occurredAt: Date,
        timeZoneIdentifier: String,
        checkInSource: PresenceCheckInSource? = nil,
        stopReason: GuardianSafetyStopReason? = nil,
        payloadJSON: Data? = nil,
        state: GuardianSafetySyncState = .pending,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.eventKey = eventKey
        eventKindRaw = eventKind.rawValue
        ownerHumanIdRaw = ownerHumanId.uuidString
        self.dayKey = dayKey
        self.occurredAt = occurredAt
        self.timeZoneIdentifier = timeZoneIdentifier
        checkInSourceRaw = checkInSource?.rawValue
        stopReasonRaw = stopReason?.rawValue
        self.payloadJSON = payloadJSON
        stateRaw = state.rawValue
        self.attemptCount = max(0, attemptCount)
        self.nextAttemptAt = nextAttemptAt ?? occurredAt
        self.lastErrorCode = lastErrorCode
        self.createdAt = createdAt ?? occurredAt
        self.updatedAt = updatedAt ?? occurredAt
    }

    var eventKind: GuardianSafetySyncEventKind {
        GuardianSafetySyncEventKind(rawValue: eventKindRaw) ?? .policyChanged
    }

    var ownerHumanId: UUID? { UUID(uuidString: ownerHumanIdRaw) }
    var checkInSource: PresenceCheckInSource? { checkInSourceRaw.flatMap(PresenceCheckInSource.init(rawValue:)) }
    var stopReason: GuardianSafetyStopReason? { stopReasonRaw.flatMap(GuardianSafetyStopReason.init(rawValue:)) }

    var state: GuardianSafetySyncState {
        get { GuardianSafetySyncState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
}
