//
//  PresenceModels.swift
//  Ohana
//
//  Durable facts for the lightweight Zen presence check-in experience.
//

import Foundation
import SwiftData

nonisolated enum PresenceSubjectKind: String, Codable, CaseIterable, Sendable {
    case human
    case pet
    case plant
}

nonisolated enum PresenceStatus: String, Codable, CaseIterable, Sendable {
    case great
    case okay
    case needsAttention
    case poor
    case score1
    case score2
    case score3
    case score4
    case score5
    case score6
    case score7
    case score8
    case score9
    case score10

    init(score: Int) {
        switch min(max(score, 1), 10) {
        case 1: self = .score1
        case 2: self = .score2
        case 3: self = .score3
        case 4: self = .score4
        case 5: self = .score5
        case 6: self = .score6
        case 7: self = .score7
        case 8: self = .score8
        case 9: self = .score9
        default: self = .score10
        }
    }

    /// Legacy four-state facts remain byte-for-byte intact. Their score is a
    /// presentation bridge, not a migration or a new reward-triggering write.
    var score: Int {
        switch self {
        case .poor: 2
        case .needsAttention: 4
        case .okay: 7
        case .great: 9
        case .score1: 1
        case .score2: 2
        case .score3: 3
        case .score4: 4
        case .score5: 5
        case .score6: 6
        case .score7: 7
        case .score8: 8
        case .score9: 9
        case .score10: 10
        }
    }
}

nonisolated enum PresenceCheckInSource: String, Codable, CaseIterable, Sendable {
    case automaticForeground
    case card
    case checkAll
    case notificationAction
    /// A score remembered for a past missed day. This remains a distinct fact
    /// source so reads can exclude it from check-ins, streaks, and rewards.
    case retrospectiveStatus
    case legacy
    case legacyMakeup
    case restore
}

nonisolated enum PresenceParticipationSource: String, Codable, CaseIterable, Sendable {
    case onboarding
    case settings
    case legacyMigration
    case restore
}

nonisolated enum PresenceRewardKind: String, Codable, CaseIterable, Sendable {
    case ownerDaily
    case dailyStatus
    case allComplete
    case streakMilestone
}

nonisolated struct PresenceSubjectRef: Codable, Equatable, Hashable, Sendable {
    let kind: PresenceSubjectKind
    let id: UUID

    init(kind: PresenceSubjectKind, id: UUID) {
        self.kind = kind
        self.id = id
    }

    var stableKey: String {
        "\(kind.rawValue):\(id.uuidString.lowercased())"
    }
}

@Model
final class PresenceCheckIn {
    #Index<PresenceCheckIn>(
        [\.dayKey],
        [\.subjectKindRaw, \.subjectIdRaw, \.dayKey],
        [\.ownerHumanIdRaw, \.dayKey],
        [\.checkedInAt]
    )

    var id: UUID
    @Attribute(.unique) var uniqueKey: String
    var subjectKindRaw: String
    var subjectIdRaw: String
    var ownerHumanIdRaw: String
    var isOwner: Bool
    var dayKey: String
    var timeZoneIdentifier: String
    var checkedInAt: Date
    var sourceRaw: String
    var statusRaw: String?
    var batchIdRaw: String?
    var operatorHumanIdRaw: String?
    var isLegacy: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        uniqueKey: String,
        subject: PresenceSubjectRef,
        ownerHumanId: UUID,
        isOwner: Bool,
        dayKey: String,
        timeZoneIdentifier: String,
        checkedInAt: Date,
        source: PresenceCheckInSource,
        status: PresenceStatus? = nil,
        batchId: UUID? = nil,
        operatorHumanId: UUID? = nil,
        isLegacy: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.uniqueKey = uniqueKey
        subjectKindRaw = subject.kind.rawValue
        subjectIdRaw = subject.id.uuidString
        ownerHumanIdRaw = ownerHumanId.uuidString
        self.isOwner = isOwner
        self.dayKey = dayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.checkedInAt = checkedInAt
        sourceRaw = source.rawValue
        statusRaw = status?.rawValue
        batchIdRaw = batchId?.uuidString
        operatorHumanIdRaw = operatorHumanId?.uuidString
        self.isLegacy = isLegacy
        self.createdAt = createdAt ?? checkedInAt
        self.updatedAt = updatedAt ?? checkedInAt
    }

    var subject: PresenceSubjectRef? {
        guard let id = UUID(uuidString: subjectIdRaw),
              let kind = PresenceSubjectKind(rawValue: subjectKindRaw)
        else { return nil }
        return PresenceSubjectRef(kind: kind, id: id)
    }

    var ownerHumanId: UUID? { UUID(uuidString: ownerHumanIdRaw) }
    var source: PresenceCheckInSource { PresenceCheckInSource(rawValue: sourceRaw) ?? .legacy }

    var status: PresenceStatus? {
        get { statusRaw.flatMap(PresenceStatus.init(rawValue:)) }
        set { statusRaw = newValue?.rawValue }
    }
}

@Model
final class PresenceParticipationPeriod {
    #Index<PresenceParticipationPeriod>(
        [\.ownerHumanIdRaw, \.startedAt],
        [\.ownerHumanIdRaw, \.endedAt],
        [\.startedDayKey]
    )

    var id: UUID
    @Attribute(.unique) var periodKey: String
    var ownerHumanIdRaw: String
    var startedAt: Date
    var startedDayKey: String
    var startedTimeZoneIdentifier: String
    var endedAt: Date?
    /// Inclusive final date that counts toward Streak. It may be earlier than
    /// `startedDayKey` when the user leaves Zen mode before checking in on the
    /// activation day; that represents a zero-day participation period.
    var lastParticipatingDayKey: String?
    var endedTimeZoneIdentifier: String?
    var sourceRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        periodKey: String? = nil,
        ownerHumanId: UUID,
        startedAt: Date,
        startedDayKey: String,
        startedTimeZoneIdentifier: String,
        endedAt: Date? = nil,
        lastParticipatingDayKey: String? = nil,
        endedTimeZoneIdentifier: String? = nil,
        source: PresenceParticipationSource,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.periodKey = periodKey ?? "presence-period:\(id.uuidString.lowercased())"
        ownerHumanIdRaw = ownerHumanId.uuidString
        self.startedAt = startedAt
        self.startedDayKey = startedDayKey
        self.startedTimeZoneIdentifier = startedTimeZoneIdentifier
        self.endedAt = endedAt
        self.lastParticipatingDayKey = lastParticipatingDayKey
        self.endedTimeZoneIdentifier = endedTimeZoneIdentifier
        sourceRaw = source.rawValue
        self.createdAt = createdAt ?? startedAt
        self.updatedAt = updatedAt ?? endedAt ?? startedAt
    }

    var ownerHumanId: UUID? { UUID(uuidString: ownerHumanIdRaw) }
    var source: PresenceParticipationSource { PresenceParticipationSource(rawValue: sourceRaw) ?? .settings }
    var isActive: Bool { endedAt == nil }
}

@Model
final class PresenceRewardReceipt {
    #Index<PresenceRewardReceipt>(
        [\.ownerHumanIdRaw, \.dayKey],
        [\.rewardKindRaw, \.dayKey],
        [\.milestoneDays],
        [\.awardedAt]
    )

    var id: UUID
    @Attribute(.unique) var receiptKey: String
    var ownerHumanIdRaw: String
    var rewardKindRaw: String
    var dayKey: String?
    var milestoneDays: Int
    var requestedAmount: Int
    var awardedAmount: Int
    var walletTransactionKey: String?
    var relatedCheckInId: UUID?
    var isLegacy: Bool
    var awardedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        receiptKey: String,
        ownerHumanId: UUID,
        rewardKind: PresenceRewardKind,
        dayKey: String? = nil,
        milestoneDays: Int = 0,
        requestedAmount: Int,
        awardedAmount: Int,
        walletTransactionKey: String? = nil,
        relatedCheckInId: UUID? = nil,
        isLegacy: Bool = false,
        awardedAt: Date,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.receiptKey = receiptKey
        ownerHumanIdRaw = ownerHumanId.uuidString
        rewardKindRaw = rewardKind.rawValue
        self.dayKey = dayKey
        self.milestoneDays = milestoneDays
        self.requestedAmount = requestedAmount
        self.awardedAmount = awardedAmount
        self.walletTransactionKey = walletTransactionKey
        self.relatedCheckInId = relatedCheckInId
        self.isLegacy = isLegacy
        self.awardedAt = awardedAt
        self.createdAt = createdAt ?? awardedAt
    }

    var ownerHumanId: UUID? { UUID(uuidString: ownerHumanIdRaw) }
    var rewardKind: PresenceRewardKind { PresenceRewardKind(rawValue: rewardKindRaw) ?? .ownerDaily }
}

@Model
final class SafetyContact {
    #Index<SafetyContact>([\.sortOrder], [\.updatedAt])

    var id: UUID
    var name: String
    var phoneNumber: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        sortOrder: Int = 0,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
