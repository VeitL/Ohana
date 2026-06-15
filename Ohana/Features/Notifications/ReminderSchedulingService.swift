//
//  ReminderSchedulingService.swift
//  Ohana
//
//  Productized reminder scheduling with deduplication and ledger visibility.
//

import Foundation
import SwiftData

enum ReminderSchedulingService {
    private static let windowDays = 14

    @MainActor
    @discardableResult
    static func scheduleIfNeeded(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource = .service,
        existingNotificationIds: Set<String>? = nil,
        operation: String = "schedule",
        saveLedger: Bool = true,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        policyDecision providedPolicyDecision: NotificationDeliveryDecision? = nil
    ) async -> ReminderNotificationScheduleResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        if reminder.event == nil {
            let result = ReminderNotificationScheduleResult.missingEvent
            recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context, save: saveLedger, careLedger: careLedger)
            return result
        }
        if reminder.scheduledAt <= Date() {
            let result = ReminderNotificationScheduleResult.skippedPastDue
            recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context, save: saveLedger, careLedger: careLedger)
            return result
        }
        let policyDecision = providedPolicyDecision ?? NotificationDeliveryPolicy.plan(reminders: [reminder])[reminder.id]
        if let policyDecision {
            switch policyDecision {
            case .skippedBudget:
                let result = ReminderNotificationScheduleResult.skippedBudget(policyDecision.metadataJSON)
                recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context, save: saveLedger, careLedger: careLedger)
                return result
            case .merged:
                let result = ReminderNotificationScheduleResult.skippedMerged(policyDecision.metadataJSON)
                recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context, save: saveLedger, careLedger: careLedger)
                return result
            case .skippedUserDisabled:
                let result = ReminderNotificationScheduleResult.skippedUserDisabled(policyDecision.metadataJSON)
                recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context, save: saveLedger, careLedger: careLedger)
                return result
            case .deliver:
                break
            }
        }
        let deliveryDate = policyDecision?.deliveryDate
        let shouldRecordDeferred = policyDecision?.isDeferred == true
        let existingIds: Set<String> = if let existingNotificationIds {
            existingNotificationIds
        } else {
            await OhanaNotifications.current.pendingNotificationIds()
        }
        let result = await withCheckedContinuation { continuation in
            OhanaNotifications.current.schedule(
                reminder: reminder,
                deliveryDate: deliveryDate,
                existingNotificationIds: existingIds
            ) { result in
                continuation.resume(returning: result)
            }
        }
        let finalResult: ReminderNotificationScheduleResult = if result == .scheduled,
                                                                 shouldRecordDeferred,
                                                                 let metadata = policyDecision?.metadataJSON {
            .deferred(metadata)
        } else {
            result
        }
        recordScheduleResult(finalResult, reminder: reminder, source: source, operation: operation, context: context, save: saveLedger, careLedger: careLedger)
        return finalResult
    }

    @MainActor
    static func scheduleManyIfNeeded(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource = .service,
        careLedger: CareLedgerRecording? = nil
    ) async {
        await scheduleBatch(reminders: reminders, context: context, source: source, operation: "schedule", careLedger: careLedger)
    }

    @MainActor
    static func cancelAndReschedule(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource = .service,
        careLedger: CareLedgerRecording? = nil
    ) async {
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        await scheduleIfNeeded(reminder: reminder, context: context, source: source, careLedger: careLedger)
    }

    @MainActor
    static func refillMissingPendingNotifications(
        reminders: [Reminder],
        context: ModelContext,
        careLedger: CareLedgerRecording? = nil
    ) async {
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: windowDays, to: now) ?? now.addingTimeInterval(14 * 86400)
        let windowReminders = reminders.filter { reminder in
            reminder.isPending && reminder.scheduledAt > now && reminder.scheduledAt <= windowEnd
        }
        await scheduleBatch(reminders: windowReminders, context: context, source: .service, operation: "refill", careLedger: careLedger)
    }

    @MainActor
    static func compensate(reminders: [Reminder], context: ModelContext, careLedger providedCareLedger: CareLedgerRecording? = nil) {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let now = Date()
        for reminder in reminders {
            guard reminder.isPending, reminder.scheduledAt < now else { continue }
            let actionType: String
            if reminder.event?.eventType == EventType.foodChange.rawValue {
                reminder.statusEnum = .failed
                actionType = "compensateFailed"
            } else {
                reminder.statusEnum = .skipped
                actionType = "compensateSkipped"
            }
            reminder.completedAt = nil
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            careLedger.recordReminderState(
                reminder: reminder,
                actionType: actionType,
                actorId: nil,
                source: .service,
                context: context,
                save: true
            )
        }
        context.safeSave()
    }

    @MainActor
    static func deduplicate(reminders: [Reminder], context: ModelContext, careLedger providedCareLedger: CareLedgerRecording? = nil) -> [Reminder] {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let now = Date()
        var seen: Set<String> = []
        var kept: [Reminder] = []
        var didChange = false
        for reminder in reminders.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = dedupeKey(for: reminder)
            if seen.contains(key) {
                OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
                careLedger.recordReminderState(
                    reminder: reminder,
                    actionType: "dedupeRemoved",
                    actorId: nil,
                    source: .service,
                    context: context,
                    save: false
                )
                CloudSyncMutationRecorder.markDeleted(reminder, context: context, deletedAt: now)
                context.delete(reminder)
                didChange = true
            } else {
                seen.insert(key)
                kept.append(reminder)
            }
        }
        if didChange {
            context.safeSave()
        }
        return kept
    }

    @MainActor
    private static func recordScheduleResult(
        _ result: ReminderNotificationScheduleResult,
        reminder: Reminder,
        source: CareLedgerSource,
        operation: String,
        context: ModelContext,
        save: Bool = true,
        careLedger: CareLedgerRecording
    ) {
        let subject = subjectInfo(from: reminder.event)
        careLedger.record(
            occurredAt: Date(),
            actorKind: .unknown,
            actorId: nil,
            subjectKind: subject.kind,
            subjectId: subject.id,
            eventKind: .reminder,
            actionType: ledgerActionType(for: result, operation: operation),
            amountValue: 0,
            amountUnit: "",
            note: reminder.event?.title ?? "",
            source: source,
            sourceEventId: reminder.event?.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            legacyModelName: "Reminder",
            legacyModelId: reminder.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: result.metadataJSON,
            context: context,
            save: save
        )
    }

    @MainActor
    private static func scheduleBatch(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource,
        operation: String,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) async {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let remindersToKeep = deduplicate(reminders: reminders, context: context, careLedger: careLedger)
        guard !remindersToKeep.isEmpty else { return }

        let policyDecisions = NotificationDeliveryPolicy.plan(reminders: remindersToKeep)
        var knownNotificationIds = await OhanaNotifications.current.pendingNotificationIds()
        for (index, reminder) in remindersToKeep.enumerated() {
            guard !Task.isCancelled else {
                context.safeSave()
                return
            }
            let result = await scheduleIfNeeded(
                reminder: reminder,
                context: context,
                source: source,
                existingNotificationIds: knownNotificationIds,
                operation: operation,
                saveLedger: false,
                careLedger: careLedger,
                policyDecision: policyDecisions[reminder.id]
            )
            if result.didRegisterNotification {
                knownNotificationIds.insert(reminder.notificationId)
            }
            if index > 0, index.isMultiple(of: 8) {
                await Task.yield()
            }
        }
        context.safeSave()
    }

    private static func dedupeKey(for reminder: Reminder) -> String {
        let eventId = reminder.event?.id.uuidString ?? "no-event"
        let minute = Int(reminder.scheduledAt.timeIntervalSince1970 / 60)
        return "\(eventId):\(minute)"
    }

    private static func ledgerActionType(for result: ReminderNotificationScheduleResult, operation: String) -> String {
        guard operation == "refill" else { return result.ledgerActionType }
        switch result {
        case .scheduled: return "refillSuccess"
        case .deferred: return "refillDeferred"
        case .skippedDuplicate: return "refillSkippedExisting"
        case .skippedPastDue: return "refillSkippedPastDue"
        case .missingEvent: return "refillMissingEvent"
        case .skippedBudget: return "refillSkippedBudget"
        case .skippedMerged: return "refillMerged"
        case .skippedUserDisabled: return "refillUserDisabled"
        case .failed: return "refillFailed"
        }
    }

    private static func subjectInfo(from event: Event?) -> (kind: CareLedgerSubjectKind, id: String?) {
        guard let event else { return (.system, nil) }
        switch event.relatedEntityType.lowercased() {
        case "pet":
            return (.pet, event.relatedEntityId)
        case "human":
            return (.human, event.relatedEntityId)
        case "plant":
            return (.plant, event.relatedEntityId)
        default:
            return (.unknown, event.relatedEntityId.isEmpty ? nil : event.relatedEntityId)
        }
    }
}
