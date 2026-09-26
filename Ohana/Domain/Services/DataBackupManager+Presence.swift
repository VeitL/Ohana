//
//  DataBackupManager+Presence.swift
//  Ohana
//
//  V32 restricted backup projection for durable Zen presence facts.
//

import Foundation
import SwiftData

nonisolated extension DataBackupManager {
    func encodePresenceCheckIn(_ value: PresenceCheckIn) -> PresenceCheckInBackup {
        PresenceCheckInBackup(
            id: value.id.uuidString,
            uniqueKey: value.uniqueKey,
            subjectKindRaw: value.subjectKindRaw,
            subjectIdRaw: value.subjectIdRaw,
            ownerHumanIdRaw: value.ownerHumanIdRaw,
            isOwner: value.isOwner,
            dayKey: value.dayKey,
            timeZoneIdentifier: value.timeZoneIdentifier,
            checkedInAt: iso.string(from: value.checkedInAt),
            sourceRaw: value.sourceRaw,
            statusRaw: value.statusRaw,
            batchIdRaw: value.batchIdRaw,
            operatorHumanIdRaw: value.operatorHumanIdRaw,
            isLegacy: value.isLegacy,
            createdAt: iso.string(from: value.createdAt),
            updatedAt: iso.string(from: value.updatedAt)
        )
    }

    func encodePresenceParticipationPeriod(
        _ value: PresenceParticipationPeriod
    ) -> PresenceParticipationPeriodBackup {
        PresenceParticipationPeriodBackup(
            id: value.id.uuidString,
            periodKey: value.periodKey,
            ownerHumanIdRaw: value.ownerHumanIdRaw,
            startedAt: iso.string(from: value.startedAt),
            startedDayKey: value.startedDayKey,
            startedTimeZoneIdentifier: value.startedTimeZoneIdentifier,
            endedAt: value.endedAt.map { iso.string(from: $0) },
            lastParticipatingDayKey: value.lastParticipatingDayKey,
            endedTimeZoneIdentifier: value.endedTimeZoneIdentifier,
            sourceRaw: value.sourceRaw,
            createdAt: iso.string(from: value.createdAt),
            updatedAt: iso.string(from: value.updatedAt)
        )
    }

    func encodePresenceRewardReceipt(
        _ value: PresenceRewardReceipt
    ) -> PresenceRewardReceiptBackup {
        PresenceRewardReceiptBackup(
            id: value.id.uuidString,
            receiptKey: value.receiptKey,
            ownerHumanIdRaw: value.ownerHumanIdRaw,
            rewardKindRaw: value.rewardKindRaw,
            dayKey: value.dayKey,
            milestoneDays: value.milestoneDays,
            requestedAmount: value.requestedAmount,
            awardedAmount: value.awardedAmount,
            walletTransactionKey: value.walletTransactionKey,
            relatedCheckInId: value.relatedCheckInId?.uuidString,
            isLegacy: value.isLegacy,
            awardedAt: iso.string(from: value.awardedAt),
            createdAt: iso.string(from: value.createdAt)
        )
    }

    func decodePresenceCheckInSnapshot(
        _ value: PresenceCheckInBackup
    ) throws -> PresenceCheckInRehydrateSnapshot {
        guard let id = UUID(uuidString: value.id),
              let subjectID = UUID(uuidString: value.subjectIdRaw),
              let ownerID = UUID(uuidString: value.ownerHumanIdRaw),
              let subjectKind = PresenceSubjectKind(rawValue: value.subjectKindRaw),
              let source = PresenceCheckInSource(rawValue: value.sourceRaw),
              let checkedInAt = iso.date(from: value.checkedInAt),
              let createdAt = iso.date(from: value.createdAt),
              let updatedAt = iso.date(from: value.updatedAt),
              value.statusRaw == nil || PresenceStatus(rawValue: value.statusRaw!) != nil,
              let batchID = optionalUUID(value.batchIdRaw),
              let operatorID = optionalUUID(value.operatorHumanIdRaw)
        else {
            throw BackupError.invalidRestoreData(.identity)
        }
        let subject = PresenceSubjectRef(kind: subjectKind, id: subjectID)
        guard let parsedDay = PresenceDayKeyPolicy.parse(value.dayKey),
              PresenceDayKeyPolicy.key(for: parsedDay, timeZone: .gmt) == value.dayKey,
              value.uniqueKey == "presence:check-in:\(subject.stableKey):\(value.dayKey)",
              value.isOwner == (subjectKind == .human && subjectID == ownerID),
              TimeZone(identifier: value.timeZoneIdentifier) != nil
        else {
            throw BackupError.invalidRestoreData(.identity)
        }
        return PresenceCheckInRehydrateSnapshot(
            id: id,
            uniqueKey: value.uniqueKey,
            subject: subject,
            ownerHumanID: ownerID,
            isOwner: value.isOwner,
            dayKey: value.dayKey,
            timeZoneIdentifier: value.timeZoneIdentifier,
            checkedInAt: checkedInAt,
            source: source,
            status: value.statusRaw.flatMap(PresenceStatus.init(rawValue:)),
            batchID: batchID,
            operatorHumanID: operatorID,
            isLegacy: value.isLegacy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func decodePresenceParticipationPeriodSnapshot(
        _ value: PresenceParticipationPeriodBackup
    ) throws -> PresenceParticipationPeriodRehydrateSnapshot {
        guard let id = UUID(uuidString: value.id),
              let ownerID = UUID(uuidString: value.ownerHumanIdRaw),
              let source = PresenceParticipationSource(rawValue: value.sourceRaw),
              let startedAt = iso.date(from: value.startedAt),
              let createdAt = iso.date(from: value.createdAt),
              let updatedAt = iso.date(from: value.updatedAt),
              let endedAt = optionalDate(value.endedAt),
              let parsedStartedDay = PresenceDayKeyPolicy.parse(value.startedDayKey),
              PresenceDayKeyPolicy.key(for: parsedStartedDay, timeZone: .gmt) == value.startedDayKey,
              value.lastParticipatingDayKey == nil || canonicalDayKey(value.lastParticipatingDayKey!),
              TimeZone(identifier: value.startedTimeZoneIdentifier) != nil,
              value.endedTimeZoneIdentifier == nil || TimeZone(identifier: value.endedTimeZoneIdentifier!) != nil
        else {
            throw BackupError.invalidRestoreData(.identity)
        }
        return PresenceParticipationPeriodRehydrateSnapshot(
            id: id,
            periodKey: value.periodKey,
            ownerHumanID: ownerID,
            startedAt: startedAt,
            startedDayKey: value.startedDayKey,
            startedTimeZoneIdentifier: value.startedTimeZoneIdentifier,
            endedAt: endedAt,
            lastParticipatingDayKey: value.lastParticipatingDayKey,
            endedTimeZoneIdentifier: value.endedTimeZoneIdentifier,
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// An active interval is device runtime state, while mode selection is
    /// deliberately excluded from backup. Close imported active intervals at
    /// the export boundary so restoring on a Standard-mode device cannot turn
    /// the time after that backup into an unbounded missed-check-in interval.
    func normalizeActivePresenceParticipationForRestore(
        _ snapshot: PresenceParticipationPeriodRehydrateSnapshot,
        exportedAt: Date,
        checkIns: [PresenceCheckInBackup]
    ) -> PresenceParticipationPeriodRehydrateSnapshot {
        guard snapshot.endedAt == nil else { return snapshot }
        let cutoff = max(exportedAt, snapshot.startedAt)
        let timeZone = TimeZone(identifier: snapshot.startedTimeZoneIdentifier) ?? .gmt
        let cutoffDayKey = PresenceDayKeyPolicy.key(for: cutoff, timeZone: timeZone)
        let ownerID = snapshot.ownerHumanID.uuidString.lowercased()
        let checkedInOnCutoffDay = checkIns.contains { value in
            value.isOwner &&
                value.subjectKindRaw == PresenceSubjectKind.human.rawValue &&
                value.subjectIdRaw.lowercased() == ownerID &&
                value.ownerHumanIdRaw.lowercased() == ownerID &&
                value.dayKey == cutoffDayKey
        }
        return PresenceParticipationPeriodRehydrateSnapshot(
            id: snapshot.id,
            periodKey: snapshot.periodKey,
            ownerHumanID: snapshot.ownerHumanID,
            startedAt: snapshot.startedAt,
            startedDayKey: snapshot.startedDayKey,
            startedTimeZoneIdentifier: snapshot.startedTimeZoneIdentifier,
            endedAt: cutoff,
            lastParticipatingDayKey: checkedInOnCutoffDay
                ? cutoffDayKey
                : PresenceDayKeyPolicy.addingDays(-1, to: cutoffDayKey),
            endedTimeZoneIdentifier: timeZone.identifier,
            source: snapshot.source,
            createdAt: snapshot.createdAt,
            updatedAt: max(snapshot.updatedAt, cutoff)
        )
    }

    func decodePresenceRewardReceiptSnapshot(
        _ value: PresenceRewardReceiptBackup
    ) throws -> PresenceRewardReceiptRehydrateSnapshot {
        guard let id = UUID(uuidString: value.id),
              let ownerID = UUID(uuidString: value.ownerHumanIdRaw),
              let kind = PresenceRewardKind(rawValue: value.rewardKindRaw),
              let relatedCheckInID = optionalUUID(value.relatedCheckInId),
              let awardedAt = iso.date(from: value.awardedAt),
              let createdAt = iso.date(from: value.createdAt)
        else {
            throw BackupError.invalidRestoreData(.identity)
        }
        return PresenceRewardReceiptRehydrateSnapshot(
            id: id,
            receiptKey: value.receiptKey,
            ownerHumanID: ownerID,
            rewardKind: kind,
            dayKey: value.dayKey,
            milestoneDays: value.milestoneDays,
            requestedAmount: value.requestedAmount,
            awardedAmount: value.awardedAmount,
            walletTransactionKey: value.walletTransactionKey,
            relatedCheckInID: relatedCheckInID,
            isLegacy: value.isLegacy,
            awardedAt: awardedAt,
            createdAt: createdAt
        )
    }

    private func optionalUUID(_ raw: String?) -> UUID?? {
        guard let raw else { return .some(nil) }
        guard let value = UUID(uuidString: raw) else { return nil }
        return .some(value)
    }

    private func optionalDate(_ raw: String?) -> Date?? {
        guard let raw else { return .some(nil) }
        guard let value = iso.date(from: raw) else { return nil }
        return .some(value)
    }

    private func canonicalDayKey(_ value: String) -> Bool {
        guard let parsed = PresenceDayKeyPolicy.parse(value) else { return false }
        return PresenceDayKeyPolicy.key(for: parsed, timeZone: .gmt) == value
    }
}

nonisolated struct PresenceCheckInRehydrateSnapshot: Sendable {
    let id: UUID
    let uniqueKey: String
    let subject: PresenceSubjectRef
    let ownerHumanID: UUID
    let isOwner: Bool
    let dayKey: String
    let timeZoneIdentifier: String
    let checkedInAt: Date
    let source: PresenceCheckInSource
    let status: PresenceStatus?
    let batchID: UUID?
    let operatorHumanID: UUID?
    let isLegacy: Bool
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct PresenceParticipationPeriodRehydrateSnapshot: Sendable {
    let id: UUID
    let periodKey: String
    let ownerHumanID: UUID
    let startedAt: Date
    let startedDayKey: String
    let startedTimeZoneIdentifier: String
    let endedAt: Date?
    let lastParticipatingDayKey: String?
    let endedTimeZoneIdentifier: String?
    let source: PresenceParticipationSource
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct PresenceRewardReceiptRehydrateSnapshot: Sendable {
    let id: UUID
    let receiptKey: String
    let ownerHumanID: UUID
    let rewardKind: PresenceRewardKind
    let dayKey: String?
    let milestoneDays: Int
    let requestedAmount: Int
    let awardedAmount: Int
    let walletTransactionKey: String?
    let relatedCheckInID: UUID?
    let isLegacy: Bool
    let awardedAt: Date
    let createdAt: Date
}

@MainActor
enum PresenceRehydrateWriter {
    static func upsert(
        _ snapshot: PresenceCheckInRehydrateSnapshot,
        context: ModelContext
    ) throws {
        let key = snapshot.uniqueKey
        var descriptor = FetchDescriptor<PresenceCheckIn>(
            predicate: #Predicate { $0.uniqueKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.subjectKindRaw = snapshot.subject.kind.rawValue
            existing.subjectIdRaw = snapshot.subject.id.uuidString
            existing.ownerHumanIdRaw = snapshot.ownerHumanID.uuidString
            existing.isOwner = snapshot.isOwner
            existing.dayKey = snapshot.dayKey
            existing.timeZoneIdentifier = snapshot.timeZoneIdentifier
            existing.checkedInAt = snapshot.checkedInAt
            existing.sourceRaw = snapshot.source.rawValue
            existing.statusRaw = snapshot.status?.rawValue
            existing.batchIdRaw = snapshot.batchID?.uuidString
            existing.operatorHumanIdRaw = snapshot.operatorHumanID?.uuidString
            existing.isLegacy = snapshot.isLegacy
            existing.createdAt = min(existing.createdAt, snapshot.createdAt)
            existing.updatedAt = max(existing.updatedAt, snapshot.updatedAt)
            return
        }
        context.insert(PresenceCheckIn(
            id: snapshot.id,
            uniqueKey: snapshot.uniqueKey,
            subject: snapshot.subject,
            ownerHumanId: snapshot.ownerHumanID,
            isOwner: snapshot.isOwner,
            dayKey: snapshot.dayKey,
            timeZoneIdentifier: snapshot.timeZoneIdentifier,
            checkedInAt: snapshot.checkedInAt,
            source: snapshot.source,
            status: snapshot.status,
            batchId: snapshot.batchID,
            operatorHumanId: snapshot.operatorHumanID,
            isLegacy: snapshot.isLegacy,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        ))
    }

    static func upsert(
        _ snapshot: PresenceParticipationPeriodRehydrateSnapshot,
        context: ModelContext
    ) throws {
        let key = snapshot.periodKey
        var descriptor = FetchDescriptor<PresenceParticipationPeriod>(
            predicate: #Predicate { $0.periodKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.ownerHumanIdRaw = snapshot.ownerHumanID.uuidString
            existing.startedAt = snapshot.startedAt
            existing.startedDayKey = snapshot.startedDayKey
            existing.startedTimeZoneIdentifier = snapshot.startedTimeZoneIdentifier
            existing.endedAt = snapshot.endedAt
            existing.lastParticipatingDayKey = snapshot.lastParticipatingDayKey
            existing.endedTimeZoneIdentifier = snapshot.endedTimeZoneIdentifier
            existing.sourceRaw = snapshot.source.rawValue
            existing.createdAt = min(existing.createdAt, snapshot.createdAt)
            existing.updatedAt = max(existing.updatedAt, snapshot.updatedAt)
            return
        }
        context.insert(PresenceParticipationPeriod(
            id: snapshot.id,
            periodKey: snapshot.periodKey,
            ownerHumanId: snapshot.ownerHumanID,
            startedAt: snapshot.startedAt,
            startedDayKey: snapshot.startedDayKey,
            startedTimeZoneIdentifier: snapshot.startedTimeZoneIdentifier,
            endedAt: snapshot.endedAt,
            lastParticipatingDayKey: snapshot.lastParticipatingDayKey,
            endedTimeZoneIdentifier: snapshot.endedTimeZoneIdentifier,
            source: snapshot.source,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        ))
    }

    static func upsert(
        _ snapshot: PresenceRewardReceiptRehydrateSnapshot,
        context: ModelContext
    ) throws {
        let key = snapshot.receiptKey
        var descriptor = FetchDescriptor<PresenceRewardReceipt>(
            predicate: #Predicate { $0.receiptKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            // Restoring a receipt never executes its reward. Preserve the
            // greater already-observed award if merging into a non-empty store.
            existing.ownerHumanIdRaw = snapshot.ownerHumanID.uuidString
            existing.rewardKindRaw = snapshot.rewardKind.rawValue
            existing.dayKey = snapshot.dayKey
            existing.milestoneDays = snapshot.milestoneDays
            existing.requestedAmount = max(existing.requestedAmount, snapshot.requestedAmount)
            existing.awardedAmount = max(existing.awardedAmount, snapshot.awardedAmount)
            existing.walletTransactionKey = existing.walletTransactionKey ?? snapshot.walletTransactionKey
            existing.relatedCheckInId = existing.relatedCheckInId ?? snapshot.relatedCheckInID
            existing.isLegacy = existing.isLegacy || snapshot.isLegacy
            existing.awardedAt = min(existing.awardedAt, snapshot.awardedAt)
            existing.createdAt = min(existing.createdAt, snapshot.createdAt)
            return
        }
        context.insert(PresenceRewardReceipt(
            id: snapshot.id,
            receiptKey: snapshot.receiptKey,
            ownerHumanId: snapshot.ownerHumanID,
            rewardKind: snapshot.rewardKind,
            dayKey: snapshot.dayKey,
            milestoneDays: snapshot.milestoneDays,
            requestedAmount: snapshot.requestedAmount,
            awardedAmount: snapshot.awardedAmount,
            walletTransactionKey: snapshot.walletTransactionKey,
            relatedCheckInId: snapshot.relatedCheckInID,
            isLegacy: snapshot.isLegacy,
            awardedAt: snapshot.awardedAt,
            createdAt: snapshot.createdAt
        ))
    }
}
