//
//  SharedCareUndoFinalizationService.swift
//  Ohana
//
//  Crash-recoverable settlement for short shared-care undo receipts.
//

import Foundation
import SwiftData

nonisolated enum SharedCareUndoFinalizationDisposition: Equatable, Sendable {
    case notDue
    case finalized
    case externalEffectsPending
    case alreadySettled
}

nonisolated struct SharedCareUndoFinalizationResult: Equatable, Sendable {
    let receiptID: UUID
    let sessionID: UUID
    let targetPetIDs: [UUID]
    let notificationReminderIDs: [UUID]
    let rewardDelta: Int
    let disposition: SharedCareUndoFinalizationDisposition
}

private nonisolated struct SharedCareUndoExternalEffectsPayload: Codable, Equatable, Sendable {
    let version: Int
    let reminderIDs: [UUID]

    init(reminderIDs: [UUID]) {
        version = 1
        self.reminderIDs = reminderIDs
    }
}

@MainActor
enum SharedCareUndoFinalizationService {
    static func settleRecoverable(
        context: ModelContext,
        now: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) -> [SharedCareUndoFinalizationResult] {
        recoverableReceipts(context: context, now: now).compactMap { receipt in
            do {
                return try finalize(
                    receiptID: receipt.id,
                    context: context,
                    now: now,
                    dependencies: dependencies
                )
            } catch {
                noteFailure(receipt: receipt, error: error, context: context, now: now)
                return nil
            }
        }
    }

    static func finalize(
        receiptID: UUID,
        context: ModelContext,
        now: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) throws -> SharedCareUndoFinalizationResult {
        guard let receipt = try fetchReceipt(id: receiptID, context: context) else {
            throw SharedCareDeferredFinalizationError.missingSession
        }
        if receipt.state == .undone || receipt.state == .finalized {
            return result(
                receipt: receipt,
                notificationReminderIDs: externalReminderIDs(receipt),
                rewardDelta: 0,
                disposition: .alreadySettled
            )
        }
        if receipt.state == .pendingUndo, now < receipt.undoDeadline {
            return result(
                receipt: receipt,
                notificationReminderIDs: [],
                rewardDelta: 0,
                disposition: .notDue
            )
        }

        var rewardDelta = 0
        if receipt.state == .pendingUndo || receipt.state == .finalizingCore {
            receipt.state = .finalizingCore
            receipt.attemptCount += 1
            receipt.lastError = nil
            receipt.nextRetryAt = nil
            try save(context: context)

            let core = try SharedPetActionRecorder.finalizeDeferredLitterScoop(
                receipt: receipt,
                context: context,
                dependencies: dependencies
            )
            rewardDelta = core.coconutDelta
            receipt.state = .externalEffectsPending
            try save(context: context)
        }

        let reminderIDs = try applyPlanAndSettings(receipt: receipt, context: context)
        var flags = receipt.completedExternalEffects
        flags.insert(.userDefaults)
        if reminderIDs.isEmpty {
            flags.insert(.notifications)
        }
        receipt.completedExternalEffects = flags
        receipt.externalEffectsPayloadJSON = encodeExternalPayload(reminderIDs: reminderIDs)
        if flags.contains(.notifications), flags.contains(.runtimeFeedback) {
            receipt.state = .finalized
            receipt.finalizedAt = now
        } else {
            receipt.state = .externalEffectsPending
        }
        receipt.lastError = nil
        receipt.nextRetryAt = nil
        try save(context: context)
        return result(
            receipt: receipt,
            notificationReminderIDs: reminderIDs,
            rewardDelta: rewardDelta,
            disposition: receipt.state == .finalized ? .finalized : .externalEffectsPending
        )
    }

    static func markExternalEffectsSettled(
        receiptID: UUID,
        context: ModelContext,
        runtimeEffectsSettled: Bool,
        notificationsSettled: Bool,
        settledAt: Date = Date()
    ) throws {
        guard let receipt = try fetchReceipt(id: receiptID, context: context),
              receipt.state != .undone else { return }
        var flags = receipt.completedExternalEffects
        if runtimeEffectsSettled { flags.insert(.runtimeFeedback) }
        if notificationsSettled { flags.insert(.notifications) }
        receipt.completedExternalEffects = flags
        if flags.contains(.runtimeFeedback), flags.contains(.notifications) {
            receipt.state = .finalized
            receipt.finalizedAt = settledAt
            receipt.nextRetryAt = nil
        } else {
            receipt.state = .externalEffectsPending
            receipt.attemptCount += 1
            receipt.nextRetryAt = settledAt.addingTimeInterval(
                min(60, Double(max(1, receipt.attemptCount)) * 5)
            )
        }
        receipt.lastError = nil
        try save(context: context)
    }

    static func pendingUndoTokens(
        context: ModelContext,
        now: Date = Date()
    ) -> [SharedCareUndoToken] {
        fetchAllReceipts(context: context)
            .filter { $0.state == .pendingUndo && $0.undoDeadline > now }
            .sorted { $0.undoDeadline < $1.undoDeadline }
            .map {
                SharedCareUndoToken(
                    sessionID: $0.sharedSessionId,
                    sourcePetID: $0.sourcePetId,
                    receiptID: $0.id,
                    undoDeadline: $0.undoDeadline
                )
            }
    }

    static func nextRecoveryDate(
        context: ModelContext,
        now: Date = Date()
    ) -> Date? {
        fetchAllReceipts(context: context).compactMap { receipt in
            switch receipt.state {
            case .pendingUndo:
                receipt.undoDeadline
            case .finalizingCore:
                receipt.nextRetryAt ?? now
            case .externalEffectsPending:
                // The coordinator settles notifications/Oasis asynchronously.
                // Avoid replaying the same external stage before it checkpoints.
                receipt.nextRetryAt ?? now.addingTimeInterval(5)
            case .finalized, .undone:
                nil
            }
        }.min()
    }

    private static func recoverableReceipts(
        context: ModelContext,
        now: Date
    ) -> [SharedCareUndoReceipt] {
        fetchAllReceipts(context: context)
            .filter { receipt in
                switch receipt.state {
                case .pendingUndo:
                    receipt.undoDeadline <= now
                case .finalizingCore, .externalEffectsPending:
                    receipt.nextRetryAt.map { $0 <= now } ?? true
                case .finalized, .undone:
                    false
                }
            }
            .sorted { $0.undoDeadline < $1.undoDeadline }
    }

    private static func applyPlanAndSettings(
        receipt: SharedCareUndoReceipt,
        context: ModelContext
    ) throws -> [UUID] {
        guard let data = receipt.corePayloadJSON.data(using: .utf8),
              let plan = try? JSONDecoder().decode(SharedLitterScoopPlanSnapshot.self, from: data),
              plan.version == SharedLitterScoopPlanSnapshot.currentVersion else {
            return externalReminderIDs(receipt)
        }
        var reminderIDs: [UUID] = []
        for targetID in receipt.targetPetIds {
            var descriptor = FetchDescriptor<Pet>(
                predicate: #Predicate<Pet> { $0.id == targetID }
            )
            descriptor.fetchLimit = 1
            guard let target = try context.fetch(descriptor).first,
                  EconomyWalletWritePolicy.canWrite(target) else {
                throw SharedCareDeferredFinalizationError.missingTargets
            }
            LitterCareSettingsStore.saveScoopSettings(
                petKey: target.id.uuidString,
                intervalDays: plan.intervalDays,
                anchorDate: plan.anchorDate,
                reminderOn: plan.reminderOn
            )
            let syncResult = CarePlanCalendarSync.syncScoopPlanResult(
                pet: target,
                context: context,
                intervalDays: plan.intervalDays,
                enabled: plan.reminderOn,
                anchor: plan.anchorDate,
                preferredEventID: stablePlanEventID(
                    receiptID: receipt.id,
                    targetID: target.id
                )
            )
            guard syncResult.didPersist else {
                throw SharedCareDeferredFinalizationError.carePlanPersistenceFailed
            }
            if let event = syncResult.event {
                guard !plan.reminderOn || !event.reminders.isEmpty else {
                    throw SharedCareDeferredFinalizationError.carePlanPersistenceFailed
                }
                reminderIDs.append(contentsOf: event.reminders.map(\.id))
            }
        }
        return Array(Set(reminderIDs)).sorted { $0.uuidString < $1.uuidString }
    }

    private static func externalReminderIDs(_ receipt: SharedCareUndoReceipt) -> [UUID] {
        guard let data = receipt.externalEffectsPayloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(
                  SharedCareUndoExternalEffectsPayload.self,
                  from: data
              ) else { return [] }
        return payload.reminderIDs
    }

    private nonisolated static func stablePlanEventID(receiptID: UUID, targetID: UUID) -> UUID {
        let lhs = receiptID.uuid
        let rhs = targetID.uuid
        return UUID(uuid: (
            lhs.0 ^ rhs.0 ^ 0xA5, lhs.1 ^ rhs.1, lhs.2 ^ rhs.2, lhs.3 ^ rhs.3,
            lhs.4 ^ rhs.4, lhs.5 ^ rhs.5, lhs.6 ^ rhs.6, lhs.7 ^ rhs.7,
            lhs.8 ^ rhs.8, lhs.9 ^ rhs.9, lhs.10 ^ rhs.10, lhs.11 ^ rhs.11,
            lhs.12 ^ rhs.12, lhs.13 ^ rhs.13, lhs.14 ^ rhs.14, lhs.15 ^ rhs.15
        ))
    }

    private static func encodeExternalPayload(reminderIDs: [UUID]) -> String {
        let payload = SharedCareUndoExternalEffectsPayload(reminderIDs: reminderIDs)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    private static func result(
        receipt: SharedCareUndoReceipt,
        notificationReminderIDs: [UUID],
        rewardDelta: Int,
        disposition: SharedCareUndoFinalizationDisposition
    ) -> SharedCareUndoFinalizationResult {
        SharedCareUndoFinalizationResult(
            receiptID: receipt.id,
            sessionID: receipt.sharedSessionId,
            targetPetIDs: receipt.targetPetIds,
            notificationReminderIDs: notificationReminderIDs,
            rewardDelta: rewardDelta,
            disposition: disposition
        )
    }

    private static func noteFailure(
        receipt: SharedCareUndoReceipt,
        error: Error,
        context: ModelContext,
        now: Date
    ) {
        receipt.attemptCount += 1
        receipt.lastError = error.localizedDescription
        receipt.nextRetryAt = now.addingTimeInterval(min(60, Double(max(1, receipt.attemptCount)) * 5))
        _ = context.safeSaveResult(publishFailureEvent: true)
    }

    private static func fetchAllReceipts(context: ModelContext) -> [SharedCareUndoReceipt] {
        (try? context.fetch(FetchDescriptor<SharedCareUndoReceipt>())) ?? []
    }

    private static func fetchReceipt(
        id: UUID,
        context: ModelContext
    ) throws -> SharedCareUndoReceipt? {
        var descriptor = FetchDescriptor<SharedCareUndoReceipt>(
            predicate: #Predicate<SharedCareUndoReceipt> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func save(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw SharedCareSessionUndoError.persistenceFailed(
                saveResult.errorDescription ?? "Unknown persistence error"
            )
        }
    }
}
