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
        operation: String = "schedule"
    ) async -> ReminderNotificationScheduleResult {
        if reminder.event == nil {
            let result = ReminderNotificationScheduleResult.missingEvent
            recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context)
            return result
        }
        if reminder.scheduledAt <= Date() {
            let result = ReminderNotificationScheduleResult.skippedPastDue
            recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context)
            return result
        }
        let existingIds: Set<String>
        if let existingNotificationIds {
            existingIds = existingNotificationIds
        } else {
            existingIds = await NotificationManager.shared.pendingNotificationIds()
        }
        let result = await withCheckedContinuation { continuation in
            NotificationManager.shared.schedule(
                reminder: reminder,
                existingNotificationIds: existingIds
            ) { result in
                continuation.resume(returning: result)
            }
        }
        recordScheduleResult(result, reminder: reminder, source: source, operation: operation, context: context)
        return result
    }

    @MainActor
    static func scheduleManyIfNeeded(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource = .service
    ) async {
        let remindersToKeep = deduplicate(reminders: reminders, context: context)
        let existingIds = await NotificationManager.shared.pendingNotificationIds()
        for reminder in remindersToKeep {
            await scheduleIfNeeded(reminder: reminder, context: context, source: source, existingNotificationIds: existingIds)
        }
    }

    @MainActor
    static func cancelAndReschedule(reminder: Reminder, context: ModelContext, source: CareLedgerSource = .service) async {
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        await scheduleIfNeeded(reminder: reminder, context: context, source: source)
    }

    @MainActor
    static func refillMissingPendingNotifications(
        reminders: [Reminder],
        context: ModelContext
    ) async {
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: windowDays, to: now) ?? now.addingTimeInterval(14 * 86_400)
        let windowReminders = reminders.filter { reminder in
            reminder.isPending && reminder.scheduledAt > now && reminder.scheduledAt <= windowEnd
        }
        let remindersToKeep = deduplicate(reminders: windowReminders, context: context)
        let existingIds = await NotificationManager.shared.pendingNotificationIds()
        for reminder in remindersToKeep {
            await scheduleIfNeeded(
                reminder: reminder,
                context: context,
                source: .service,
                existingNotificationIds: existingIds,
                operation: "refill"
            )
        }
    }

    @MainActor
    static func compensate(reminders: [Reminder], context: ModelContext) {
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
            NotificationManager.shared.cancel(notificationId: reminder.notificationId)
            CareLedgerService.recordReminderState(
                reminder: reminder,
                actionType: actionType,
                actorId: nil,
                source: .service,
                context: context
            )
        }
        context.safeSave()
    }

    @MainActor
    static func deduplicate(reminders: [Reminder], context: ModelContext) -> [Reminder] {
        var seen: Set<String> = []
        var kept: [Reminder] = []
        for reminder in reminders.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = dedupeKey(for: reminder)
            if seen.contains(key) {
                NotificationManager.shared.cancel(notificationId: reminder.notificationId)
                CareLedgerService.recordReminderState(
                    reminder: reminder,
                    actionType: "dedupeRemoved",
                    actorId: nil,
                    source: .service,
                    context: context
                )
                context.delete(reminder)
            } else {
                seen.insert(key)
                kept.append(reminder)
            }
        }
        context.safeSave()
        return kept
    }

    @MainActor
    private static func recordScheduleResult(
        _ result: ReminderNotificationScheduleResult,
        reminder: Reminder,
        source: CareLedgerSource,
        operation: String,
        context: ModelContext
    ) {
        let subject = CareLedgerService.subjectInfo(from: reminder.event)
        CareLedgerService.record(
            occurredAt: Date(),
            subjectKind: subject.kind,
            subjectId: subject.id,
            eventKind: .reminder,
            actionType: ledgerActionType(for: result, operation: operation),
            note: reminder.event?.title ?? "",
            source: source,
            sourceEventId: reminder.event?.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            legacyModelName: "Reminder",
            legacyModelId: reminder.id.uuidString,
            metadataJSON: result.metadataJSON,
            context: context
        )
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
        case .skippedDuplicate: return "refillSkippedExisting"
        case .skippedPastDue: return "refillSkippedPastDue"
        case .missingEvent: return "refillMissingEvent"
        case .failed: return "refillFailed"
        }
    }
}
