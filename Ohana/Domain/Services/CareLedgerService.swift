//
//  CareLedgerService.swift
//  Ohana
//
//  Write helpers for the canonical care ledger.
//

import Foundation
import SwiftData

nonisolated enum CareLedgerMetadata {
    static let autoFeedDedupKey = "autoFeedDedupKey"
    static let feedFoodKind = "feedFoodKind"
    static let feedTreatKind = "feedTreatKind"
    static let sharedSessionId = "sharedSessionId"
    private static let legacyMetadataKey = "legacyMetadata"

    static func stringValue(named name: String, in metadataJSON: String) -> String? {
        let trimmed = metadataJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object[name] as? String
        else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func addingString(_ name: String, value: String?, to metadataJSON: String) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return metadataJSON }

        let trimmed = metadataJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        var object: [String: Any] = [:]
        if !trimmed.isEmpty,
           let data = trimmed.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = decoded
        } else if !trimmed.isEmpty {
            object[legacyMetadataKey] = metadataJSON
        }

        object[name] = value
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let encoded = String(data: data, encoding: .utf8)
        else { return metadataJSON }
        return encoded
    }

    static func addingFeedingLogMetadata(from log: PetCareLog, to metadataJSON: String) -> String {
        guard log.careType == .feeding else { return metadataJSON }
        let withFoodKind = addingString(feedFoodKind, value: log.foodKind.rawValue, to: metadataJSON)
        let withTreatKind = addingString(feedTreatKind, value: log.treatKind?.rawValue, to: withFoodKind)
        return addingString(sharedSessionId, value: log.sharedSessionId, to: withTreatKind)
    }
}

nonisolated struct CareLedgerSubjectInfo: Equatable {
    let kind: CareLedgerSubjectKind
    let id: String?
}

final nonisolated class CareLedgerService {
    init() {}

    /// Isolation-agnostic: only performs ModelContext writes, so it is safe to
    /// call from the main actor or from a background @ModelActor (e.g. backfill).
    @discardableResult
    static func record(
        occurredAt: Date = Date(),
        actorKind: CareLedgerActorKind = .unknown,
        actorId: String? = nil,
        subjectKind: CareLedgerSubjectKind,
        subjectId: String?,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double = 0,
        amountUnit: String = "",
        note: String = "",
        source: CareLedgerSource = .service,
        sourceEventId: String? = nil,
        sourceReminderId: String? = nil,
        legacyModelName: String? = nil,
        legacyModelId: String? = nil,
        coconutDelta: Int = 0,
        rewardLogId: String? = nil,
        privacyFieldRaw: String? = nil,
        metadataJSON: String = "",
        context: ModelContext,
        save: Bool = true
    ) -> CareLedgerEvent {
        let event = CareLedgerEvent(
            occurredAt: occurredAt,
            actorKind: actorKind,
            actorId: actorId,
            subjectKind: subjectKind,
            subjectId: subjectId,
            eventKind: eventKind,
            actionType: actionType,
            amountValue: amountValue,
            amountUnit: amountUnit,
            note: note,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            coconutDelta: coconutDelta,
            rewardLogId: rewardLogId,
            privacyFieldRaw: privacyFieldRaw,
            metadataJSON: metadataJSON
        )
        context.insert(event)
        markModifiedForCloudSync(event, context: context, modifiedAt: occurredAt)
        if save {
            context.safeSave()
        }
        return event
    }

    private static func markModifiedForCloudSync(
        _ event: CareLedgerEvent,
        context: ModelContext,
        modifiedAt: Date
    ) {
        let entityName = String(describing: CareLedgerEvent.self)
        guard CloudSyncEntityRegistry.descriptor(for: entityName)?.uploadsToCloudKit == true else {
            return
        }
        do {
            try CloudSyncMetadataService.markModified(
                entityName: entityName,
                localRecordId: event.id,
                householdId: sharedHouseholdId(context: context, now: modifiedAt) ?? event.id,
                modifiedAt: modifiedAt,
                context: context
            )
        } catch {
            OhanaLog.warning(
                "CareLedgerService failed to mark ledger event dirty: \(error.localizedDescription)",
                category: "CloudSync"
            )
        }
    }

    private static func sharedHouseholdId(context: ModelContext, now: Date) -> UUID? {
        do {
            var descriptor = FetchDescriptor<Household>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            descriptor.fetchLimit = 1
            if let household = try context.fetch(descriptor).first {
                return household.id
            }

            let household = Household()
            household.createdAt = now
            context.insert(household)
            try CloudSyncMetadataService.markModified(
                entityName: String(describing: Household.self),
                localRecordId: household.id,
                householdId: household.id,
                modifiedAt: now,
                context: context
            )
            return household.id
        } catch {
            OhanaLog.warning(
                "CareLedgerService failed to resolve CloudSync household: \(error.localizedDescription)",
                category: "CloudSync"
            )
            return nil
        }
    }

    @MainActor
    static func recordPetCare(
        log: PetCareLog,
        pet: Pet,
        source: CareLedgerSource,
        sourceEventId: String? = nil,
        sourceReminderId: String? = nil,
        coconutDelta: Int = 0,
        metadataJSON: String = "",
        context: ModelContext
    ) {
        let amount: (Double, String) = {
            if log.careType == .feeding { return (log.amountGrams, "g") }
            if log.careType == .watering { return (log.amountMl, "ml") }
            return (0, "")
        }()
        let feedMetadataJSON = CareLedgerMetadata.addingFeedingLogMetadata(from: log, to: metadataJSON)
        let ledgerMetadataJSON = CareLedgerMetadata.addingString(
            CareLedgerMetadata.autoFeedDedupKey,
            value: log.autoFeedDedupKey,
            to: feedMetadataJSON
        )
        record(
            occurredAt: log.date,
            actorKind: log.executorId == nil ? .unknown : .human,
            actorId: log.executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: log.careType.rawValue,
            amountValue: amount.0,
            amountUnit: amount.1,
            note: log.note,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            metadataJSON: ledgerMetadataJSON,
            context: context
        )
    }

    @MainActor
    static func recordPetPotty(
        log: PetPottyLog,
        pet: Pet,
        source: CareLedgerSource,
        coconutDelta: Int = 0,
        metadataJSON: String = "",
        context: ModelContext
    ) {
        record(
            occurredAt: log.date,
            actorKind: log.executorId == nil ? .unknown : .human,
            actorId: log.executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: log.pottyType.rawValue,
            source: source,
            legacyModelName: "PetPottyLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            metadataJSON: metadataJSON,
            context: context
        )
    }

    @MainActor
    static func recordReminderState(
        reminder: Reminder,
        actionType: String,
        actorId: String?,
        source: CareLedgerSource,
        context: ModelContext,
        save: Bool = true
    ) {
        let subject = subjectInfo(from: reminder.event, context: context)
        record(
            occurredAt: Date(),
            actorKind: actorId == nil ? .unknown : .human,
            actorId: actorId,
            subjectKind: subject.kind,
            subjectId: subject.id,
            eventKind: .reminder,
            actionType: actionType,
            note: reminder.event?.title ?? "",
            source: source,
            sourceEventId: reminder.event?.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            legacyModelName: "Reminder",
            legacyModelId: reminder.id.uuidString,
            context: context,
            save: save
        )
    }

    @MainActor
    static func recordCoconut(
        delta: Int,
        title: String,
        actorId: String?,
        actorName: String?,
        source: CareLedgerSource,
        context: ModelContext
    ) {
        record(
            actorKind: actorId == nil ? .system : .human,
            actorId: actorId,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "coconutDelta",
            note: actorName.map { "\($0) · \(title)" } ?? title,
            source: source,
            coconutDelta: delta,
            context: context
        )
    }

    static func subjectInfo(from event: Event?, context: ModelContext) -> CareLedgerSubjectInfo {
        guard let event else { return CareLedgerSubjectInfo(kind: .system, id: nil) }
        let link = DomainEntityLink(event: event)
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        )
        if let target = resolution.displayTarget {
            return subjectInfo(for: target)
        }
        switch resolution.role {
        case .directPlant, .plantScoped:
            return CareLedgerSubjectInfo(
                kind: .plant,
                id: DomainEntityLinkRegistry.plantId(for: link)?.uuidString ?? nonEmptyId(link.trimmedId)
            )
        case .unscoped where link.trimmedId.isEmpty:
            return CareLedgerSubjectInfo(kind: .system, id: nil)
        default:
            return CareLedgerSubjectInfo(kind: .unknown, id: nonEmptyId(link.trimmedId))
        }
    }

    private static func subjectInfo(for reference: DomainMemberReference) -> CareLedgerSubjectInfo {
        switch reference {
        case let .pet(id):
            CareLedgerSubjectInfo(kind: .pet, id: id.uuidString)
        case let .human(id):
            CareLedgerSubjectInfo(kind: .human, id: id.uuidString)
        }
    }

    private static func nonEmptyId(_ rawId: String) -> String? {
        let trimmed = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func rewardDelta(_ reward: (humanGot: Int, petGot: Int)?) -> Int {
        guard let reward else { return 0 }
        return max(0, reward.humanGot) + max(0, reward.petGot)
    }

    @MainActor
    static func rewardMetadata(_ reward: (humanGot: Int, petGot: Int)?) -> String {
        guard let reward else { return "" }
        return """
        {"humanCoconuts":\(max(0, reward.humanGot)),"petCoconuts":\(max(0, reward.petGot)),"economy":"humanWallet_petBond"}
        """
    }
}
