//
//  SharedCareUndoReceipt.swift
//  Ohana
//
//  Local-only crash-recovery state for the short shared-care undo window.
//

import Foundation
import SwiftData

nonisolated enum SharedCareUndoReceiptState: String, Codable, CaseIterable, Sendable {
    case pendingUndo
    case finalizingCore
    case externalEffectsPending
    case finalized
    case undone
}

nonisolated struct SharedCareUndoExternalEffectFlags: OptionSet, Equatable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let userDefaults = Self(rawValue: 1 << 0)
    static let notifications = Self(rawValue: 1 << 1)
    static let runtimeFeedback = Self(rawValue: 1 << 2)
}

nonisolated struct SharedCareUndoReminderOccurrence: Codable, Equatable, Sendable {
    let targetPetId: UUID
    let reminderId: UUID
    let occurrenceAt: Date
}

@Model
final class SharedCareUndoReceipt {
    #Index<SharedCareUndoReceipt>(
        [\.sharedSessionId],
        [\.stateRaw, \.undoDeadline],
        [\.sourcePetId],
        [\.executorId],
        [\.nextRetryAt]
    )

    var id: UUID
    var sharedSessionId: UUID
    var sourcePetId: UUID
    var targetPetIdsRaw: String
    var executorId: String?
    var actionKindRaw: String
    var occurredAt: Date
    var createdAt: Date
    var undoDeadline: Date
    var stateRaw: String

    /// Immutable reminder occurrences selected when the shared-care fact is recorded.
    /// Finalization must not search for a newer "nearest" reminder after the undo window.
    var reminderOccurrencesJSON: String

    /// Versioned, immutable inputs needed by the SwiftData finalization transaction.
    var corePayloadJSON: String

    /// Versioned absolute-value writes and stable notification IDs safe to replay after commit.
    var externalEffectsPayloadJSON: String
    var completedExternalEffectsRaw: Int

    var attemptCount: Int
    var lastError: String?
    var nextRetryAt: Date?
    var finalizedAt: Date?
    var undoneAt: Date?

    init(
        id: UUID = UUID(),
        sharedSessionId: UUID,
        sourcePetId: UUID,
        targetPetIds: [UUID],
        executorId: String? = nil,
        actionKind: SharedCareActionKind,
        occurredAt: Date,
        createdAt: Date = Date(),
        undoDeadline: Date,
        state: SharedCareUndoReceiptState = .pendingUndo,
        reminderOccurrences: [SharedCareUndoReminderOccurrence] = [],
        corePayloadJSON: String = "{}",
        externalEffectsPayloadJSON: String = "{}",
        completedExternalEffects: SharedCareUndoExternalEffectFlags = [],
        attemptCount: Int = 0,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        finalizedAt: Date? = nil,
        undoneAt: Date? = nil
    ) {
        self.id = id
        self.sharedSessionId = sharedSessionId
        self.sourcePetId = sourcePetId
        self.targetPetIdsRaw = Self.encodePetIds(targetPetIds)
        self.executorId = executorId
        self.actionKindRaw = actionKind.rawValue
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.undoDeadline = undoDeadline
        self.stateRaw = state.rawValue
        self.reminderOccurrencesJSON = Self.encodeReminderOccurrences(reminderOccurrences)
        self.corePayloadJSON = corePayloadJSON
        self.externalEffectsPayloadJSON = externalEffectsPayloadJSON
        self.completedExternalEffectsRaw = completedExternalEffects.rawValue
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.finalizedAt = finalizedAt
        self.undoneAt = undoneAt
    }

    var state: SharedCareUndoReceiptState {
        get { SharedCareUndoReceiptState(rawValue: stateRaw) ?? .pendingUndo }
        set { stateRaw = newValue.rawValue }
    }

    var actionKind: SharedCareActionKind? {
        SharedCareActionKind(rawValue: actionKindRaw)
    }

    var targetPetIds: [UUID] {
        Self.decodePetIds(targetPetIdsRaw)
    }

    var reminderOccurrences: [SharedCareUndoReminderOccurrence] {
        get { Self.decodeReminderOccurrences(reminderOccurrencesJSON) }
        set { reminderOccurrencesJSON = Self.encodeReminderOccurrences(newValue) }
    }

    var completedExternalEffects: SharedCareUndoExternalEffectFlags {
        get { SharedCareUndoExternalEffectFlags(rawValue: completedExternalEffectsRaw) }
        set { completedExternalEffectsRaw = newValue.rawValue }
    }

    func isUndoAvailable(at date: Date = Date()) -> Bool {
        state == .pendingUndo && date < undoDeadline
    }

    private static func encodePetIds(_ ids: [UUID]) -> String {
        var seen = Set<UUID>()
        return ids
            .filter { seen.insert($0).inserted }
            .map(\.uuidString)
            .joined(separator: "|")
    }

    private static func decodePetIds(_ raw: String) -> [UUID] {
        raw
            .split(separator: "|")
            .compactMap { UUID(uuidString: String($0)) }
    }

    private static func encodeReminderOccurrences(
        _ occurrences: [SharedCareUndoReminderOccurrence]
    ) -> String {
        guard let data = try? JSONEncoder().encode(occurrences),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return encoded
    }

    private static func decodeReminderOccurrences(
        _ raw: String
    ) -> [SharedCareUndoReminderOccurrence] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(
                  [SharedCareUndoReminderOccurrence].self,
                  from: data
              ) else {
            return []
        }
        return decoded
    }
}
